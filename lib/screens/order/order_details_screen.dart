/*// lib/screens/order/order_details_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String foodId; // This is UUID from foods table
  final String foodName;
  final double price; // This is item_price for one unit
  final String? foodProviderProfileId; // This is company_id from foods table
  // final String? foodImageUrl; // Optional: if you want to display image here

  const OrderDetailsScreen({
    super.key,
    required this.foodId,
    required this.foodName,
    required this.price,
    this.foodProviderProfileId, // This is the company_id associated with the food
    // this.foodImageUrl,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final supabase = Supabase.instance.client;
  bool _isProcessingOrder = false;
  String? _errorMessage;
  int _quantity = 1;

  Timer? _cancelTimer;
  int _cancelTimeRemaining = 180; // 3 minutes in seconds
  bool _canCancel = false;
  String? _orderIdForCancellation; // Holds the ID of the main order record
  bool _orderSuccessfullyPlaced = false;
  bool _orderWasCancelledByUser = false;

  @override
  void dispose() {
    _cancelTimer?.cancel();
    super.dispose();
  }

  void _startCancelTimer(String orderId) {
    _orderIdForCancellation = orderId;
    _canCancel = true;
    _orderSuccessfullyPlaced = false;
    _orderWasCancelledByUser = false;
    _cancelTimeRemaining = 180;

    if (!mounted) return;
    setState(() {});

    _cancelTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_cancelTimeRemaining > 0) {
          _cancelTimeRemaining--;
        } else {
          _canCancel = false;
          _orderSuccessfullyPlaced = true;
          _cancelTimer?.cancel();
          // Consider auto-navigating or showing persistent success message
        }
      });
    });
  }

  Future<void> _sendOrder() async {
    setState(() {
      _isProcessingOrder = true;
      _errorMessage = null;
      _orderSuccessfullyPlaced = false;
      _orderWasCancelledByUser = false;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception("You must be logged in to send an order.");
      }

      // 1. Create the main order record in 'orders' table
      final mainOrderData = {
        'user_id': user.id,
        // 'food_id' is NOT directly in 'orders' table as per your new schema. It's in 'order_items'.
        // 'company_id' in 'orders' table should be the foodProviderProfileId
        'company_id': widget.foodProviderProfileId,
        'status': 'sent', // Or 'pending' if cancellation updates it to 'sent'
        'order_time': DateTime.now().toUtc().toIso8601String(),
      };

      final List<dynamic> orderResponse = await supabase
          .from('orders')
          .insert(mainOrderData)
          .select('id');

      if (orderResponse.isEmpty || orderResponse.first['id'] == null) {
        throw Exception('Failed to create main order record. No ID returned.');
      }
      final String newOrderId = orderResponse.first['id'].toString();

      // 2. Create the order item in 'order_items' table
      final orderItemData = {
        'order_id': newOrderId,
        'food_id': widget.foodId, // foodId from the selected food
        'quantity': _quantity,
        'item_price': widget.price, // Price per item
        // created_at in order_items has a default in DB, so not strictly needed here
      };

      await supabase.from('order_items').insert(orderItemData);

      // Successfully created order and order item
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order sent successfully! You can cancel shortly.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _startCancelTimer(newOrderId); // Start cancellation timer with the main order ID
      }
    } on PostgrestException catch (e) {
      debugPrint("OrderDetailsScreen: Supabase Error sending order: ${e.code} - ${e.message}");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to send order: ${e.message}";
        });
      }
    } catch (e) {
      debugPrint("OrderDetailsScreen: Generic Error sending order: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "An unexpected error occurred: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingOrder = false;
        });
      }
    }
  }

  Future<void> _cancelOrder() async {
    if (_orderIdForCancellation == null) {
      if (mounted) {
        setState(() => _errorMessage = "No order ID found to cancel.");
      }
      return;
    }

    // Note: Your schema has 'id' in 'orders' as UUID.
    // Supabase client typically handles UUIDs as strings.
    // No need to parse to int here if it's a UUID.

    setState(() {
      _isProcessingOrder = true;
      _errorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not found. Cannot cancel order.");

      // Update status in the 'orders' table.
      // order_items are typically not deleted on cancellation, but the order status reflects it.
      // If you need to move to junk_orders, that's a different operation.
      await supabase
          .from('orders')
          .update({
        'status': 'cancelled',
        // 'updated_at': DateTime.now().toUtc().toIso8601String(), // 'orders' table doesn't have updated_at
      })
          .eq('id', _orderIdForCancellation!) // Use the UUID string
          .eq('user_id', user.id);

      if (mounted) {
        _cancelTimer?.cancel();
        setState(() {
          _canCancel = false;
          _orderWasCancelledByUser = true;
          _orderSuccessfullyPlaced = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && ModalRoute.of(context)?.isCurrent == true) {
            Navigator.pop(context); // Go back to home/menu
          }
        });
      }
    } on PostgrestException catch (e) {
      debugPrint("OrderDetailsScreen: Supabase Error cancelling order: ${e.message}");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to cancel order: ${e.message}";
        });
      }
    } catch (e) {
      debugPrint("OrderDetailsScreen: Generic Error cancelling order: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Error cancelling order: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingOrder = false;
        });
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final totalPrice = widget.price * _quantity;

    final bool showSendButton = _orderIdForCancellation == null && !_orderSuccessfullyPlaced && !_orderWasCancelledByUser;
    final bool showCancelButton = _orderIdForCancellation != null && _canCancel && !_orderWasCancelledByUser;
    final bool showOrderPlacedMessage = _orderIdForCancellation != null && _orderSuccessfullyPlaced && !_canCancel && !_orderWasCancelledByUser;
    final bool showOrderCancelledMessage = _orderIdForCancellation != null && _orderWasCancelledByUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Order'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Optional: Display food image if passed
            // if (widget.foodImageUrl != null && widget.foodImageUrl!.isNotEmpty)
            //   Center(
            //     child: Container(
            //       height: 180,
            //       width: double.infinity,
            //       margin: const EdgeInsets.only(bottom: 20),
            //       decoration: BoxDecoration(
            //         borderRadius: BorderRadius.circular(12.0),
            //         image: DecorationImage(
            //           image: NetworkImage(widget.foodImageUrl!),
            //           fit: BoxFit.cover,
            //         ),
            //       ),
            //     ),
            //   )
            // else
            Center(
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Icon(Icons.fastfood_outlined,
                    size: 80, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.foodName,
              style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: theme.colorScheme.primary, size: 28),
                  onPressed: _isProcessingOrder || _orderIdForCancellation != null
                      ? null
                      : () {
                    if (_quantity > 1) {
                      setState(() => _quantity--);
                    }
                  },
                ),
                Text('$_quantity', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: theme.colorScheme.primary, size: 28),
                  onPressed: _isProcessingOrder || _orderIdForCancellation != null
                      ? null
                      : () => setState(() => _quantity++),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Total: \$${totalPrice.toStringAsFixed(2)}',
                style: textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            // Removed redundant SizedBox here
            if (showSendButton)
              ElevatedButton.icon(
                icon: _isProcessingOrder ? const SizedBox.shrink() : const Icon(Icons.send_rounded),
                label: _isProcessingOrder
                    ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : const Text('Send Order'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: _isProcessingOrder ? null : _sendOrder,
              )
            else if (showCancelButton)
              Column(
                children: [
                  Text(
                    'Order sent! You can cancel within:',
                    style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _formatDuration(_cancelTimeRemaining),
                    style: textTheme.headlineMedium?.copyWith(color: theme.colorScheme.secondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: _isProcessingOrder ? const SizedBox.shrink() : const Icon(Icons.cancel_outlined),
                    label: _isProcessingOrder
                        ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('Cancel Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isProcessingOrder ? null : _cancelOrder,
                  ),
                ],
              )
            else if (showOrderPlacedMessage)
                Column(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green[700], size: 50),
                    const SizedBox(height: 8),
                    Text(
                      'Order successfully placed!',
                      style: textTheme.titleMedium?.copyWith(color: Colors.green[700], fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      child: const Text('Back to Menu'),
                      onPressed: () {
                        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
                          Navigator.pop(context); // Go back to menu
                        }
                      },
                    )
                  ],
                )
              else if (showOrderCancelledMessage)
                  Column(
                    children: [
                      Icon(Icons.cancel_outlined, color: theme.colorScheme.error, size: 50),
                      const SizedBox(height: 8),
                      Text(
                        'Order has been cancelled.',
                        style: textTheme.titleMedium?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        child: const Text('Back to Menu'),
                        onPressed: () {
                          if (mounted && ModalRoute.of(context)?.isCurrent == true) {
                            Navigator.pop(context); // Go back to menu
                          }
                        },
                      )
                    ],
                  ),
            const SizedBox(height: 20), // Padding at the bottom
          ],
        ),
      ),
    );
  }
}
*/