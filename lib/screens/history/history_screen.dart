import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  final List<Map<String, String>> history = const [
    {'company': 'Awesome Foods Ltd', 'food': 'Burger', 'time': '2025-08-13 10:00'},
    {'company': 'Pizza Hut', 'food': 'Pepperoni Pizza', 'time': '2025-08-12 14:30'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order History')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        itemBuilder: (_, index) {
          final order = history[index];
          return ListTile(
            leading: const Icon(Icons.receipt_long),
            title: Text(order['food']!),
            subtitle: Text('${order['company']} • ${order['time']}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Option to reorder
            },
          );
        },
      ),
    );
  }
}
