import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../stripe.dart';
import 'models.dart';
import 'progress_bar.dart';
import 'screens/payment_methods_screen.dart';
import 'stores/payment_method_store.dart';

@Deprecated('Experimental')
class CheckoutScreen extends StatefulWidget {
  final Iterable<CheckoutItem> items;
  final String title;
  final Future<IntentResponse> Function(int amount) createPaymentIntent;

  CheckoutScreen(
      {Key key,
      @required this.title,
      @required this.items,
      PaymentMethodStore paymentMethods,
      @required this.createPaymentIntent})
      : super(key: key);

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

// ignore: deprecated_member_use_from_same_package
class _CheckoutScreenState extends State<CheckoutScreen> {
  final PaymentMethodStore paymentMethodStore = PaymentMethodStore.instance;

  String _selectedPaymentMethod;
  Future<IntentResponse> _createIntentResponse;
  int _total;

  @override
  void initState() {
    _total = widget.items.fold(0, (value, item) => value + item.price * item.count);
    _createIntentResponse = widget.createPaymentIntent(_total);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ignore: deprecated_member_use_from_same_package
          Container(child: CheckoutItemList(items: widget.items, total: _total)),
          SizedBox(
            height: 40,
          ),
          Center(
            child: PaymentMethodSelector(
                paymentMethodStore: paymentMethodStore,
                selectedPaymentMethodId: null,
                onChanged: (value) => setState(() {
                      _selectedPaymentMethod = value;
                    })),
          ),
          Center(
//            child: LoadStuffButton(),

            child: RaisedButton(
              onPressed: () async {
                showProgressDialog(context);
                final intentResponse = await _createIntentResponse;
                try {
                  final confirmationResponse = await Stripe.instance
                      .confirmPayment(intentResponse.clientSecret, paymentMethodId: _selectedPaymentMethod);
                  hideProgressDialog(context);
                  if (confirmationResponse['status'] == 'succeeded') {
                    await showGeneralDialog(
                        barrierColor: Colors.black.withOpacity(0.5),
                        transitionBuilder: (context, a1, a2, widget) {
                          return Transform.scale(
                            scale: a1.value,
                            child: Opacity(
                              opacity: a1.value,
                              child: AlertDialog(
                                shape: OutlineInputBorder(borderRadius: BorderRadius.circular(16.0)),
                                title: Text('Success'),
                                content: Text('Payment successfully completed!'),
                              ),
                            ),
                          );
                        },
                        transitionDuration: Duration(milliseconds: 200),
                        barrierDismissible: true,
                        barrierLabel: '',
                        context: context,
                        pageBuilder: (context, animation1, animation2) {
                          return null;
                        });
                    return;
                  }
                } catch (e) {
                  hideProgressDialog(context);
                }
              },
              child: Text('Pay ${(_total / 100).toStringAsFixed(2)}'),
            ),
          )
        ],
      ),
    );
  }
}

@Deprecated('Experimental')
class CheckoutItemList extends StatelessWidget {
  final List<CheckoutItem> items;
  final int total;

  const CheckoutItemList({Key key, @required this.items, @required this.total}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final list = List<Widget>.from(items);
    list.add(CheckoutSumItem(total: total));
    return ListView(
      children: list,
      shrinkWrap: true,
    );
  }
}

class CheckoutSumItem extends StatelessWidget {
  final int total;

  const CheckoutSumItem({Key key, @required this.total}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('Total'),
      trailing: Text((total / 100).toStringAsFixed(2)),
    );
  }
}

class CheckoutItem extends StatelessWidget {
  final String name;
  final int price;
  final String currency;
  final int count;

  const CheckoutItem({Key key, @required this.name, @required this.price, @required this.currency, this.count = 1})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: false,
      title: Text(name),
      subtitle: Text('x $count'),
      trailing: Text((price / 100).toStringAsFixed(2)),
    );
  }
}

class PaymentMethodSelector extends StatefulWidget {
  PaymentMethodSelector(
      {Key key, @required this.paymentMethodStore, @required this.selectedPaymentMethodId, @required this.onChanged})
      : super(key: key);

  final String selectedPaymentMethodId;
  final void Function(String) onChanged;
  final PaymentMethodStore paymentMethodStore;

  @override
  _PaymentMethodSelectorState createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  Iterable<PaymentMethod> paymentMethods;
  String _selectedPaymentMethodId;

  @override
  Widget build(BuildContext context) {
    PaymentMethod selectedPaymentMethod;
    if (_selectedPaymentMethodId != null) {
      selectedPaymentMethod =
          paymentMethods?.singleWhere((item) => item.id == _selectedPaymentMethodId, orElse: () => null);
    } else {
      selectedPaymentMethod = paymentMethods?.first;
    }
    return Container(
//      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: DropdownButton(
        underline: Container(),
        isExpanded: false,
        value: selectedPaymentMethod?.id,
        items: paymentMethods
            ?.map((item) => DropdownMenuItem(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text('${item.brand.toUpperCase()} **** **** **** ${item.last4}'),
                  ),
                  value: item.id,
                ))
            ?.toList(),
        onChanged: (value) {
          widget.onChanged(value);
          setState(() {
            _selectedPaymentMethodId = value;
          });
        },
      ),
    );
  }

  @override
  void initState() {
    widget.paymentMethodStore.addListener(listener);
    super.initState();
  }

  @override
  void dispose() {
    widget.paymentMethodStore.removeListener(listener);
    super.dispose();
  }

  void listener() {
    setState(() {
      paymentMethods = widget.paymentMethodStore.paymentMethods;
    });
  }
}
