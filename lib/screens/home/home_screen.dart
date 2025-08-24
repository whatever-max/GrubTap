// lib/screens/home/home_screen.dart
import 'dart:async'; // For Timer
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

// Model imports
import '../../models/food_model.dart'; // Ensure this path is correct

// Widget/Shared imports
import '../../shared/custom_drawer.dart'; // Ensure this path is correct
import '../../services/session_service.dart'; // Import SessionService to get role

// REMOVED: import '../../config/app_routes.dart';

class HomeScreen extends StatefulWidget {
  // Using a simple string literal for routeName
  static const String routeName = '/home'; // <<<<<<< REVERTED

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  String? _currentUserRole;

  List<FoodModel> _allFoods = [];
  bool _isLoadingFoods = true;
  String? _foodListErrorMessage;
  final TextEditingController _foodDropdownController = TextEditingController();

  FoodModel? _selectedFoodForOrder;
  bool _isProcessingOrder = false;
  String? _orderProcessingErrorMessage;
  int _quantity = 1;

  Timer? _cancelTimer;
  int _cancelTimeRemaining = 180;
  bool _canCancelOrder = false;
  String? _orderIdForCancellation;
  bool _orderSuccessfullyPlaced = false;
  bool _orderWasCancelledByUser = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[HomeScreen] initState called.');
    _fetchUserRoleAndThenLoadFoods();
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  Future<void> _fetchUserRoleAndThenLoadFoods() async {
    debugPrint('[HomeScreen] _fetchUserRoleAndThenLoadFoods: Fetching user role...');
    String? fetchedRole = await SessionService.getUserRole();
    if (!mounted) {
      debugPrint('[HomeScreen] Component unmounted after role fetch.');
      return;
    }
    debugPrint('[HomeScreen] _fetchUserRoleAndThenLoadFoods: Raw role fetched from SessionService: "$fetchedRole".');
    setStateIfMounted(() {
      if (fetchedRole == null || fetchedRole.isEmpty) {
        _currentUserRole = 'user'; // Default to 'user'
        debugPrint('[HomeScreen] Fetched role was null or empty, defaulting _currentUserRole to "user".');
      } else {
        _currentUserRole = fetchedRole;
      }
    });
    debugPrint('[HomeScreen] _fetchUserRoleAndThenLoadFoods: _currentUserRole finally set to: "$_currentUserRole". Now loading foods.');
    await _loadAllFoods();
  }

  @override
  void dispose() {
    debugPrint('[HomeScreen] dispose called.');
    _foodDropdownController.dispose();
    _cancelTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllFoods() async {
    debugPrint('[HomeScreen] _loadAllFoods: Starting to load foods...');
    if (!mounted) {
      debugPrint('[HomeScreen] _loadAllFoods: Unmounted. Aborting food load.');
      return;
    }
    setStateIfMounted(() {
      _isLoadingFoods = true;
      _foodListErrorMessage = null;
    });

    try {
      final response = await supabase
          .from('foods')
          .select('id, name, price, description, image_url, company_id')
          .order('name', ascending: true);

      if (!mounted) {
        debugPrint('[HomeScreen] _loadAllFoods: Unmounted after Supabase call.');
        return;
      }

      if (response.isEmpty) {
        _allFoods = [];
        _foodListErrorMessage = "No food items available at the moment.";
      } else {
        _allFoods = response
            .map((item) => FoodModel.fromMap(item as Map<String, dynamic>))
            .toList();
        _foodListErrorMessage = null;
      }
    } on PostgrestException catch (e) {
      debugPrint('[HomeScreen] _loadAllFoods: Supabase Error - ${e.code}: ${e.message}');
      if (mounted) {
        _foodListErrorMessage = 'Failed to load food items: ${e.message}';
      }
    } catch (e) {
      debugPrint('[HomeScreen] _loadAllFoods: Generic Error - $e');
      if (mounted) {
        _foodListErrorMessage = 'An unexpected error occurred: ${e.toString()}';
      }
    } finally {
      if (mounted) {
        setStateIfMounted(() {
          _isLoadingFoods = false;
        });
      }
    }
  }

  void _onFoodSelectedFromDropdown(FoodModel? food) {
    setStateIfMounted(() {
      _selectedFoodForOrder = food;
      if (food != null) {
        _quantity = 1;
        _orderProcessingErrorMessage = null;
        _isProcessingOrder = false;
        _orderSuccessfullyPlaced = false;
        _orderWasCancelledByUser = false;
        _canCancelOrder = false;
        _orderIdForCancellation = null;
        _cancelTimer?.cancel();
      } else {
        _clearOrderDetails();
      }
    });
  }

  void _clearOrderDetails() {
    setStateIfMounted(() {
      _selectedFoodForOrder = null;
      _foodDropdownController.clear();
      _quantity = 1;
      _isProcessingOrder = false;
      _orderProcessingErrorMessage = null;
      _cancelTimer?.cancel();
      _canCancelOrder = false;
      _orderIdForCancellation = null;
      _orderSuccessfullyPlaced = false;
      _orderWasCancelledByUser = false;
    });
  }

  void _startCancelTimer(String orderId) {
    _orderIdForCancellation = orderId;
    _canCancelOrder = true;
    _orderSuccessfullyPlaced = false;
    _orderWasCancelledByUser = false;
    _cancelTimeRemaining = 180;

    if (!mounted) return;
    setStateIfMounted(() {}); // Update UI

    _cancelTimer?.cancel();
    _cancelTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setStateIfMounted(() {
        if (_cancelTimeRemaining > 0) {
          _cancelTimeRemaining--;
        } else {
          _canCancelOrder = false;
          _orderSuccessfullyPlaced = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendOrder() async {
    if (_selectedFoodForOrder == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a food item first.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    setStateIfMounted(() {
      _isProcessingOrder = true;
      _orderProcessingErrorMessage = null;
      _orderSuccessfullyPlaced = false;
      _orderWasCancelledByUser = false;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception("You must be logged in to send an order.");
      }

      final mainOrderData = {
        'user_id': user.id,
        'company_id': _selectedFoodForOrder!.profileId,
        'status': 'sent',
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

      final orderItemData = {
        'order_id': newOrderId,
        'food_id': _selectedFoodForOrder!.id,
        'quantity': _quantity,
        'item_price': _selectedFoodForOrder!.price,
      };

      await supabase.from('order_items').insert(orderItemData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order sent! You can cancel shortly.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _startCancelTimer(newOrderId);
      }
    } on PostgrestException catch (e) {
      debugPrint("[HomeScreen:SendOrder] Supabase Error: ${e.code} - ${e.message}");
      if (mounted) {
        setStateIfMounted(() {
          _orderProcessingErrorMessage = "Failed to send order: ${e.message}. Please try again.";
        });
      }
    } catch (e) {
      debugPrint("[HomeScreen:SendOrder] Generic Error: $e");
      if (mounted) {
        setStateIfMounted(() {
          _orderProcessingErrorMessage = "An unexpected error occurred: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setStateIfMounted(() {
          _isProcessingOrder = false;
        });
      }
    }
  }

  Future<void> _cancelOrder() async {
    if (_orderIdForCancellation == null) {
      if (mounted) {
        setStateIfMounted(() => _orderProcessingErrorMessage = "No order ID found to cancel.");
      }
      return;
    }

    setStateIfMounted(() {
      _isProcessingOrder = true;
      _orderProcessingErrorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not found. Cannot cancel order.");

      await supabase
          .from('orders')
          .update({'status': 'cancelled_by_user'})
          .eq('id', _orderIdForCancellation!)
          .eq('user_id', user.id);

      if (mounted) {
        _cancelTimer?.cancel();
        setStateIfMounted(() {
          _canCancelOrder = false;
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
      }
    } on PostgrestException catch (e) {
      debugPrint("[HomeScreen:CancelOrder] Supabase Error: ${e.message}");
      if (mounted) {
        setStateIfMounted(() {
          _orderProcessingErrorMessage = "Failed to cancel order: ${e.message}";
        });
      }
    } catch (e) {
      debugPrint("[HomeScreen:CancelOrder] Generic Error: $e");
      if (mounted) {
        setStateIfMounted(() {
          _orderProcessingErrorMessage = "Error cancelling order: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setStateIfMounted(() {
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

  // Responsive layout helpers (still useful for content within the page)
  static const double _kMobileBreakpoint = 600;
  static const double _kTabletBreakpoint = 900;

  bool _isMobile(BuildContext context) => MediaQuery.of(context).size.width < _kMobileBreakpoint;
  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= _kMobileBreakpoint &&
          MediaQuery.of(context).size.width < _kTabletBreakpoint;
  // bool _isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= _kTabletBreakpoint; // Not used for drawer decision

  Widget _buildFoodDropdown(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoadingFoods && _allFoods.isEmpty && _foodListErrorMessage == null) {
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: CircularProgressIndicator(key: ValueKey("FoodDropdownLoading")),
      ));
    }
    if (_foodListErrorMessage != null && _allFoods.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 10),
              Text(
                _foodListErrorMessage!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                onPressed: _loadAllFoods,
                style: theme.elevatedButtonTheme.style,
              )
            ],
          ),
        ),
      );
    }
    if (!_isLoadingFoods && _allFoods.isEmpty && _foodListErrorMessage == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Text(
            "No food items are currently available to order.",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    double dropdownWidth = _isMobile(context) ? double.infinity : (_isTablet(context) ? 500 : 600);
    return Container(
      width: dropdownWidth,
      alignment: Alignment.center,
      child: DropdownMenu<FoodModel>(
        controller: _foodDropdownController,
        requestFocusOnTap: true,
        label: const Text('Select Food Item'),
        width: dropdownWidth == double.infinity ? null : dropdownWidth,
        expandedInsets: EdgeInsets.zero,
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          fillColor: theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surfaceVariant.withOpacity(0.5),
        ),
        onSelected: _onFoodSelectedFromDropdown,
        dropdownMenuEntries: _allFoods.map<DropdownMenuEntry<FoodModel>>((FoodModel food) {
          return DropdownMenuEntry<FoodModel>(
            value: food,
            label: "${food.name} - TSh ${food.price.toStringAsFixed(0)}/=",
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrderConfirmationSection(BuildContext context) {
    if (_selectedFoodForOrder == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final totalPrice = _selectedFoodForOrder!.price * _quantity;

    final bool showSendButton = _orderIdForCancellation == null && !_orderSuccessfullyPlaced && !_orderWasCancelledByUser;
    final bool showCancelButtonView = _orderIdForCancellation != null && _canCancelOrder && !_orderWasCancelledByUser;
    final bool showOrderPlacedMessage = _orderIdForCancellation != null && _orderSuccessfullyPlaced && !_canCancelOrder && !_orderWasCancelledByUser;
    final bool showOrderCancelledMessage = _orderIdForCancellation != null && _orderWasCancelledByUser;

    double cardWidth = _isMobile(context) ? double.infinity : (_isTablet(context) ? 500 : 600);
    double imageSize = _isMobile(context) ? 120 : 150;

    Widget imageDisplayWidget;
    if (_selectedFoodForOrder!.imageUrl != null && _selectedFoodForOrder!.imageUrl!.isNotEmpty) {
      imageDisplayWidget = Image.network(
        _selectedFoodForOrder!.imageUrl!,
        height: imageSize,
        width: _isMobile(context) ? double.infinity : imageSize * 1.5,
        fit: BoxFit.cover,
        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: imageSize,
            width: _isMobile(context) ? double.infinity : imageSize * 1.5,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2.0,
                color: theme.colorScheme.primary,
              ),
            ),
          );
        },
        errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
          debugPrint("Error loading image from Image.network: $exception");
          return Container(
            height: imageSize,
            width: _isMobile(context) ? double.infinity : imageSize * 1.5,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(Icons.broken_image_outlined, size: imageSize * 0.6, color: theme.colorScheme.onSurfaceVariant),
          );
        },
      );
    } else {
      imageDisplayWidget = Container(
        height: imageSize,
        width: _isMobile(context) ? double.infinity : imageSize * 1.5,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Icon(Icons.fastfood_outlined, size: imageSize * 0.6, color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return Center(
      child: Container(
        width: cardWidth,
        child: Card(
          margin: EdgeInsets.only(top: 20.0, bottom: 20.0, left: _isMobile(context) ? 0 : 8, right: _isMobile(context) ? 0 : 8),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_orderSuccessfullyPlaced && !_orderWasCancelledByUser && _orderIdForCancellation == null)
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: "Clear Selection",
                      onPressed: _clearOrderDetails,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: imageDisplayWidget,
                    ),
                  ),
                ),
                Text(
                  _selectedFoodForOrder!.name,
                  style: (_isMobile(context) ? textTheme.titleLarge : textTheme.headlineSmall)?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (_selectedFoodForOrder!.description != null && _selectedFoodForOrder!.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Text(
                      _selectedFoodForOrder!.description!,
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                      maxLines: _isMobile(context) ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline, color: theme.colorScheme.primary, size: _isMobile(context) ? 28 : 32),
                      onPressed: _isProcessingOrder || _orderIdForCancellation != null
                          ? null
                          : () {
                        if (_quantity > 1) {
                          setStateIfMounted(() => _quantity--);
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text('$_quantity', style: (_isMobile(context) ? textTheme.titleMedium : textTheme.titleLarge)?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: theme.colorScheme.primary, size: _isMobile(context) ? 28 : 32),
                      onPressed: _isProcessingOrder || _orderIdForCancellation != null
                          ? null
                          : () => setStateIfMounted(() => _quantity++),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Total: TSh ${totalPrice.toStringAsFixed(0)}/=',
                    style: (_isMobile(context) ? textTheme.titleLarge : textTheme.headlineSmall)?.copyWith(
                        color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                if (_orderProcessingErrorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      _orderProcessingErrorMessage!,
                      style: TextStyle(color: theme.colorScheme.error, fontSize: _isMobile(context) ? 13 : 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (showSendButton)
                  ElevatedButton.icon(
                    icon: _isProcessingOrder ? const SizedBox.shrink() : const Icon(Icons.send_rounded),
                    label: _isProcessingOrder
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary)))
                        : const Text('Send Order'),
                    style: theme.elevatedButtonTheme.style,
                    onPressed: _isProcessingOrder ? null : _sendOrder,
                  )
                else if (showCancelButtonView)
                  Column(
                    children: [
                      Text(
                        'Order sent! You can cancel within:',
                        style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: _isMobile(context) ? 13 : 14),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        _formatDuration(_cancelTimeRemaining),
                        style: (_isMobile(context) ? textTheme.headlineSmall : textTheme.headlineMedium)?.copyWith(color: theme.colorScheme.secondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: _isProcessingOrder ? const SizedBox.shrink() : const Icon(Icons.cancel_outlined),
                        label: _isProcessingOrder
                            ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onError)))
                            : const Text('Cancel Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ).merge(theme.elevatedButtonTheme.style),
                        onPressed: _isProcessingOrder ? null : _cancelOrder,
                      ),
                    ],
                  )
                else if (showOrderPlacedMessage)
                    Column(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green[700], size: _isMobile(context) ? 36 : 48),
                        const SizedBox(height: 8),
                        Text(
                          'Order successfully placed!',
                          style: (_isMobile(context) ? textTheme.titleSmall : textTheme.titleMedium)?.copyWith(color: Colors.green[700], fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          child: const Text('Make New Order'),
                          style: theme.elevatedButtonTheme.style?.copyWith(
                            padding: MaterialStateProperty.all(EdgeInsets.symmetric(vertical: _isMobile(context) ? 10 : 12, horizontal: 16)),
                            textStyle: MaterialStateProperty.all(TextStyle(fontSize: _isMobile(context) ? 14 : 15)),
                          ),
                          onPressed: _clearOrderDetails,
                        )
                      ],
                    )
                  else if (showOrderCancelledMessage)
                      Column(
                        children: [
                          Icon(Icons.cancel_outlined, color: theme.colorScheme.error, size: _isMobile(context) ? 36 : 48),
                          const SizedBox(height: 8),
                          Text(
                            'Order has been cancelled.',
                            style: (_isMobile(context) ? textTheme.titleSmall : textTheme.titleMedium)?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            child: const Text('Make New Order'),
                            style: theme.elevatedButtonTheme.style?.copyWith(
                              padding: MaterialStateProperty.all(EdgeInsets.symmetric(vertical: _isMobile(context) ? 10 : 12, horizontal: 16)),
                              textStyle: MaterialStateProperty.all(TextStyle(fontSize: _isMobile(context) ? 14 : 15)),
                            ),
                            onPressed: _clearOrderDetails,
                          )
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use _isMobile and _isTablet for responsive content, not for drawer visibility
    double horizontalPadding = _isMobile(context) ? 16.0 : (_isTablet(context) ? 32.0 : 64.0);
    double verticalPadding = _isMobile(context) ? 16.0 : 24.0;

    // final bool isDesktopMode = _isDesktop(context); // This line is removed/commented for drawer logic
    final String? roleForDrawer = _currentUserRole;

    debugPrint('[HomeScreen] Build Method -- START --');
    debugPrint('[HomeScreen]   Role for Drawer (_currentUserRole): "$roleForDrawer"');
    // debugPrint('[HomeScreen]   Is Desktop Mode: $isDesktopMode'); // No longer used for drawer logic
    debugPrint('[HomeScreen]   Is Loading Foods: $_isLoadingFoods');
    debugPrint('[HomeScreen]   All Foods Empty: ${_allFoods.isEmpty}');
    debugPrint('[HomeScreen]   Food List Error Message: $_foodListErrorMessage');

    if (roleForDrawer == null || (_isLoadingFoods && _allFoods.isEmpty && _foodListErrorMessage == null)) {
      debugPrint('[HomeScreen] Showing main loading Scaffold: Role is "$roleForDrawer", or initial food list is loading.');
      return Scaffold(
        key: const ValueKey("HomeScreenLoadingScaffold"),
        appBar: AppBar(title: const Text('GrubTap Loading...')),
        body: const Center(child: CircularProgressIndicator(key: ValueKey("HomeScreenLoadingIndicator"))),
      );
    }

    Widget? activeDrawer;
    // Drawer is now always assigned if roleForDrawer is valid (non-null and non-empty),
    // to ensure HomeScreen always has a drawer when role is determined.
    if (roleForDrawer.isNotEmpty) {
      activeDrawer = CustomDrawer(userRole: roleForDrawer);
      debugPrint('[HomeScreen] Assigning CustomDrawer to Scaffold. Role: "$roleForDrawer"');
    } else {
      debugPrint('[HomeScreen] Drawer is NULL because roleForDrawer is unexpectedly empty. THIS IS AN ISSUE!');
    }
    debugPrint('[HomeScreen] Build Method -- END --');

    return Scaffold(
      appBar: AppBar(
        title: const Text('GrubTap'),
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      drawer: activeDrawer, // Assign the drawer based on the logic above
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAllFoods,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: _isMobile(context) ? 16.0 : 24.0, top: 8.0),
                  child: Text(
                    'Select Your Meal',
                    style: (_isMobile(context) ? theme.textTheme.headlineSmall : theme.textTheme.headlineMedium)
                        ?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    textAlign: TextAlign.center,
                  ),
                ),
                _buildFoodDropdown(context),
                _buildOrderConfirmationSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
