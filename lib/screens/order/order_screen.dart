import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/food_model.dart';
import '../../models/company_model.dart';

class OrderScreen extends StatefulWidget {
  final FoodModel food;
  final CompanyModel company;

  const OrderScreen({
    super.key,
    required this.food,
    required this.company,
  });

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  late Timer _timer;
  int _secondsLeft = 180;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 0) {
        timer.cancel();
        _confirmOrder();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _confirmOrder() {
    // TODO: Add Supabase order submission here
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final company = widget.company;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Order')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Company: ${company.name}", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text("Food: ${food.name}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Price: \$${food.price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 30),
            Text("You have $_secondsLeft seconds to cancel this order."),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _timer.cancel();
                Navigator.pop(context); // Cancel
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cancel Order'),
            ),
          ],
        ),
      ),
    );
  }
}
