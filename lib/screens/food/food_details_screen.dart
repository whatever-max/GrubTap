// lib/screens/food/food_details_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/food_model.dart';
import '../../services/order_service.dart';
import '../../models/order_model.dart';

class FoodDetailsScreen extends StatefulWidget {
  final FoodModel food;

  const FoodDetailsScreen({super.key, required this.food});

  @override
  State<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends State<FoodDetailsScreen> {
  final supabase = Supabase.instance.client;
  late final OrderService _orderService;

  bool _isOrdering = false;
  bool _orderPlaced = false;
  String? _orderId;
  String? _errorMessage;
  Timer? _cancelTimer;
  Duration _timeLeft = const Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    _orderService = OrderService(supabase);
  }

  @override
  void dispose() {
    _cancelTimer?.cancel();
    super.dispose();
  }

  void _startCancelCountdown() {
    _cancelTimer?.cancel();
    _cancelTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft.inSeconds <= 0) {
        timer.cancel();
        setState(() {});
      } else {
        setState(() {
          _timeLeft -= const Duration(seconds: 1);
        });
      }
    });
  }

  Future<void> _handleOrder() async {
    setState(() {
      _isOrdering = true;
      _errorMessage = null;
    });

    final message = await _orderService.placeOrder(
      foodId: widget.food.id,
      companyId: widget.food.companyId,
    );

    if (message != null) {
      setState(() {
        _errorMessage = message;
        _isOrdering = false;
      });
      return;
    }

    final latestOrder = await _orderService.fetchUserLatestOrder(widget.food.id);

    if (latestOrder != null) {
      setState(() {
        _orderId = latestOrder.id;
        _orderPlaced = true;
        _isOrdering = false;
        _timeLeft = const Duration(minutes: 3);
      });
      _startCancelCountdown();
    }
  }

  Future<void> _handleCancel() async {
    if (_orderId == null) return;
    final message = await _orderService.cancelOrder(_orderId!);

    if (message != null) {
      setState(() {
        _errorMessage = message;
      });
    } else {
      setState(() {
        _orderPlaced = false;
        _orderId = null;
        _timeLeft = const Duration(minutes: 0);
      });
      _cancelTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final food = widget.food;

    return Scaffold(
      appBar: AppBar(
        title: Text(food.name),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onBackground,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (food.imageUrl != null && food.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  food.imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              food.name,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              food.description,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              "Price: \$${food.price.toStringAsFixed(2)}",
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (food.companyName != null)
              Text(
                "Restaurant: ${food.companyName!}",
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            const SizedBox(height: 20),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),

            ElevatedButton.icon(
              icon: _isOrdering
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.send),
              label: Text(_orderPlaced ? "Order Placed" : "Send Order"),
              onPressed: _orderPlaced || _isOrdering ? null : _handleOrder,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),

            if (_orderPlaced && _timeLeft.inSeconds > 0)
              Column(
                children: [
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cancel),
                    label: Text("Cancel Order (${_timeLeft.inSeconds}s left)"),
                    onPressed: _handleCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.errorContainer,
                      foregroundColor: theme.colorScheme.onErrorContainer,
                      minimumSize: const Size.fromHeight(45),
                    ),
                  ),
                ],
              ),

            if (_orderPlaced && _timeLeft.inSeconds == 0)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  "Order is now final and being processed.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
