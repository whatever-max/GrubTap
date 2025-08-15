import 'package:flutter/material.dart';

class OrdersTodayScreen extends StatelessWidget {
  const OrdersTodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Orders")),
      body: const Center(
        child: Text("You have no orders today."),
      ),
    );
  }
}
