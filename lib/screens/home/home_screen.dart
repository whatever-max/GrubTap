// lib/screens/home/home_screen.dart
import 'dart:async'; // For Timer
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:intl/intl.dart'; // <<< Added for DateFormat

// Model imports
import '../../models/food_model.dart'; // Ensure this path is correct

// Widget/Shared imports
import '../../shared/custom_drawer.dart'; // Ensure this path is correct
import '../../services/session_service.dart'; // Import SessionService to get role

class HomeScreen extends StatefulWidget {
  // Using a simple string literal for routeName
  static const String routeName = '/home'; // This is correct from your clean version

  const HomeScreen({super.key}); // This is correct

  @override
  State<HomeScreen> createState() => _HomeScreenState(); // This is correct
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  String? _currentUserRole;
  // <<< ADDED for business logic >>>
  String? _currentUsername;
  String? _currentUserId;
  List<FoodModel> _filteredFoodsForDropdown = []; // For visual filtering

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

  // <<< ADDED: Constants for business logic >>>
  static const String _superAdminId = "ddbf93e1-f6bd-4295-a3a6-6348fe6fdf96";
  static const List<String> _specialUsernames = ["Emtera", "Gerald"];
  static const double _priceLimitGeneral = 3000.0;


  @override
  void initState() {
    super.initState();
    debugPrint('[HomeScreen] initState called.');
    // Modified to fetch full user context
    _fetchUserContextAndThenLoadFoods();
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // <<< MODIFIED: To fetch full user context >>>
  Future<void> _fetchUserContextAndThenLoadFoods() async {
    debugPrint('[HomeScreen] _fetchUserContextAndThenLoadFoods: Fetching user context...');
    if (!mounted) return;

    // Set loading true at the beginning
    setStateIfMounted(() {
      _isLoadingFoods = true;
      _foodListErrorMessage = null;
    });

    final user = supabase.auth.currentUser;
    if (user == null) {
      debugPrint('[HomeScreen] User is null. Defaulting values.');
      setStateIfMounted(() {
        _currentUserRole = 'user';
        _currentUsername = null;
        _currentUserId = null;
        // _isLoadingFoods will be set to false in _loadAllFoods if it also fails or completes
      });
      await _loadAllFoods(); // Still try to load foods, rules might apply or show error
      return;
    }

    _currentUserId = user.id;
    // Fetch username directly from user metadata if SessionService.getUsername() doesn't exist
    // Prioritize 'username', then 'user_name' from metadata.
    if (user.userMetadata != null) {
      _currentUsername = user.userMetadata!['username'] as String? ?? user.userMetadata!['user_name'] as String?;
    } else {
      _currentUsername = null;
    }
    _currentUserRole = await SessionService.getUserRole();

    // Default role if null or empty after fetching
    if (_currentUserRole == null || _currentUserRole!.isEmpty) {
      _currentUserRole = 'user';
      debugPrint('[HomeScreen] Fetched role was null/empty from SessionService, defaulting to "user".');
    }

    debugPrint('[HomeScreen] UserContext: ID=$_currentUserId, Username=$_currentUsername, Role=$_currentUserRole');

    if (!mounted) {
      debugPrint('[HomeScreen] Component unmounted after user context fetch.');
      return;
    }
    // No explicit setStateIfMounted needed here for _currentUserId, _currentUsername, _currentUserRole
    // because _loadAllFoods will trigger a rebuild when it completes or if it changes _isLoadingFoods.
    await _loadAllFoods();
  }


  @override
  void dispose() {
    debugPrint('[HomeScreen] dispose called.');
    _foodDropdownController.dispose();
    _cancelTimer?.cancel();
    super.dispose();
  }

  // <<< ADDED: Helper methods for business logic >>>
  bool _isSuperAdmin() {
    return _currentUserId == _superAdminId;
  }

  bool _isSpecialUserPriceExempt() {
    if (_currentUsername == null) return false;
    return _specialUsernames.contains(_currentUsername);
  }

  bool _isOrderingTimeAllowed() {
    if (_isSuperAdmin()) return true; // Super admin always allowed

    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;

    // Disallowed period: 10:31 AM up to and including 15:30 PM
    if ((hour == 10 && minute >= 31) || // From 10:31 to 10:59
        (hour > 10 && hour < 15) ||      // Hours 11, 12, 13, 14
        (hour == 15 && minute <= 30)) {  // From 15:00 to 15:30
      return false; // Within the restricted time
    }
    return true; // Allowed time
  }

  int _currentDayOfWeek() {
    return DateTime.now().weekday; // Monday = 1, ..., Sunday = 7
  }

  Future<void> _loadAllFoods() async {
    debugPrint('[HomeScreen] _loadAllFoods: Starting to load foods...');
    if (!mounted) {
      debugPrint('[HomeScreen] _loadAllFoods: Unmounted. Aborting food load.');
      return;
    }
    // Ensure loading state is set if called from refresh or if not already set
    if (!_isLoadingFoods) {
      setStateIfMounted(() {
        _isLoadingFoods = true;
        _foodListErrorMessage = null;
      });
    }
    _allFoods.clear(); // Clear previous lists
    _filteredFoodsForDropdown.clear();


    try {
      final response = await supabase
          .from('foods')
          .select('id, name, price, description, image_url, company_id')
          .not('availability', 'eq', 'unavailable') // Assuming you add this filter
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
        // IMPORTANT: Apply filters after loading all foods
        _applyFoodFilters();
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

  // <<< ADDED: Method to apply food filters based on rules >>>
  void _applyFoodFilters() {
    // Super Admin and Special Price Exempt Users (Emtera, Gerald) have NO price filtering.
    if (_isSuperAdmin() || _isSpecialUserPriceExempt()) {
      _filteredFoodsForDropdown = List.from(_allFoods);
    } else {
      // General user price filtering
      final dayOfWeek = _currentDayOfWeek();
      bool applyPriceLimitToday;

      if (dayOfWeek == DateTime.friday) {
        applyPriceLimitToday = false; // No price limit on Friday for general users
      } else {
        // Monday-Thursday AND Saturday-Sunday, price limit applies
        applyPriceLimitToday = true;
      }

      if (applyPriceLimitToday) {
        _filteredFoodsForDropdown = _allFoods.where((food) => food.price <= _priceLimitGeneral).toList();
      } else {
        _filteredFoodsForDropdown = List.from(_allFoods); // No price limit this day
      }
    }

    // If a selected food is no longer in the filtered list, clear selection.
    // This handles cases where filters change (e.g., time passes into restricted period).
    if (_selectedFoodForOrder != null && !_filteredFoodsForDropdown.any((f) => f.id == _selectedFoodForOrder!.id)) {
      _clearOrderDetails(); // This calls setState
    } else {
      // If _clearOrderDetails wasn't called, we still might need to update if the list changed
      // This setState is crucial to update the dropdown with the new _filteredFoodsForDropdown.
      if (mounted) {
        setState(() {});
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

    // --- APPLY CORRECTED BUSINESS LOGIC CHECKS ---
    final String foodName = _selectedFoodForOrder!.name;
    final double foodPrice = _selectedFoodForOrder!.price;

    // Rule 1: Time Restriction (Applies to General Users AND Emtera/Gerald)
    // Super Admin is exempt from this by _isOrderingTimeAllowed() itself.
    if (!_isOrderingTimeAllowed()) {
      final now = DateTime.now();
      String currentFormattedTime = DateFormat('HH:mm').format(now);
      String message = "Ordering is currently closed (Time: $currentFormattedTime).\n"
          "Available: 15:31 - 10:30 AM daily.";
      if (mounted) {
        setStateIfMounted(() => _orderProcessingErrorMessage = message);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 5)));
      }
      return;
    }

    // Rule 2 & 3: Price Restriction (Applies ONLY to General Users)
    // Super Admin and Special Users (Emtera/Gerald) are EXEMPT from price restrictions.
    if (!_isSuperAdmin() && !_isSpecialUserPriceExempt()) {
      final dayOfWeek = _currentDayOfWeek();
      bool applyPriceLimitToday;

      if (dayOfWeek == DateTime.friday) {
        applyPriceLimitToday = false; // No price limit on Friday
      } else {
        // Monday-Thursday AND Saturday-Sunday, price limit applies
        applyPriceLimitToday = true;
      }

      if (applyPriceLimitToday && foodPrice > _priceLimitGeneral) {
        String dayMessagePart = "";
        if (dayOfWeek >= DateTime.monday && dayOfWeek <= DateTime.thursday) {
          dayMessagePart = "(Mon-Thu)";
        } else if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
          dayMessagePart = "(Sat-Sun)";
        }
        String message = "'$foodName' (TSh ${foodPrice.toStringAsFixed(0)}) exceeds TSh ${_priceLimitGeneral.toStringAsFixed(0)} limit $dayMessagePart.";
        if (mounted) {
          setStateIfMounted(() => _orderProcessingErrorMessage = message);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 5)));
        }
        return;
      }
    }
    // --- END BUSINESS LOGIC CHECKS ---


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

      // Ensure food_id is also part of the main order data if your schema has it
      final mainOrderData = {
        'user_id': user.id,
        'company_id': _selectedFoodForOrder!.profileId, // From FoodModel
        'status': 'sent',
        'order_time': DateTime.now().toUtc().toIso8601String(),
        'food_id': _selectedFoodForOrder!.id, // Link to the primary food item
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

  static const double _kMobileBreakpoint = 600;
  static const double _kTabletBreakpoint = 900;

  bool _isMobile(BuildContext context) => MediaQuery.of(context).size.width < _kMobileBreakpoint;
  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= _kMobileBreakpoint &&
          MediaQuery.of(context).size.width < _kTabletBreakpoint;

  Widget _buildFoodDropdown(BuildContext context) {
    final theme = Theme.of(context);

    // Initial loading state for the whole dropdown section
    if (_isLoadingFoods && _filteredFoodsForDropdown.isEmpty && _foodListErrorMessage == null) {
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: CircularProgressIndicator(key: ValueKey("FoodDropdownLoading")),
      ));
    }

    // Error state after trying to load foods
    if (_foodListErrorMessage != null && _filteredFoodsForDropdown.isEmpty) { // Check filtered list as well
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
                // Retry should fetch user context again as role/username might affect filters
                onPressed: _fetchUserContextAndThenLoadFoods,
                style: theme.elevatedButtonTheme.style,
              )
            ],
          ),
        ),
      );
    }

    // Time restriction message (applies to general & special users, not super admin)
    if (!_isOrderingTimeAllowed()) {
      final now = DateTime.now();
      String currentFormattedTime = DateFormat('HH:mm').format(now);
      String orderingDisabledMessage = "Ordering is currently closed (Time: $currentFormattedTime).\nAvailable: 15:31 - 10:30 AM daily.";
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_off_outlined, color: theme.colorScheme.primary, size: 48),
              const SizedBox(height: 10),
              Text(
                orderingDisabledMessage,
                style: TextStyle(fontSize: 16, color: theme.colorScheme.primary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // No items available based on current filters (and not loading, no error)
    if (!_isLoadingFoods && _filteredFoodsForDropdown.isEmpty && _foodListErrorMessage == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Text(
            "No food items are currently available to order based on current conditions.",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Display the dropdown if there are items and ordering is allowed by time
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
        // Use _filteredFoodsForDropdown
        dropdownMenuEntries: _filteredFoodsForDropdown.map<DropdownMenuEntry<FoodModel>>((FoodModel food) {
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
                    onPressed: (_isProcessingOrder || !_isOrderingTimeAllowed()) ? null : _sendOrder, // Also disable button if time restricted
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
    double horizontalPadding = _isMobile(context) ? 16.0 : (_isTablet(context) ? 32.0 : 64.0);
    double verticalPadding = _isMobile(context) ? 16.0 : 24.0;
    final String? roleForDrawer = _currentUserRole;

    // Enhanced loading condition: show loading if role isn't determined OR if foods are genuinely still loading
    if ((_currentUserRole == null && _currentUserId == null) || // If user context not yet fetched
        (_isLoadingFoods && _allFoods.isEmpty && _foodListErrorMessage == null)) {
      debugPrint('[HomeScreen] Showing main loading Scaffold (user context null or initial food list loading).');
      return Scaffold(
        key: const ValueKey("HomeScreenLoadingScaffold"),
        appBar: AppBar(title: const Text('GrubTap Loading...')),
        body: const Center(child: CircularProgressIndicator(key: ValueKey("HomeScreenLoadingIndicator"))),
      );
    }

    Widget? activeDrawer;
    if (roleForDrawer != null && roleForDrawer.isNotEmpty) {
      activeDrawer = CustomDrawer(userRole: roleForDrawer);
    } else if (roleForDrawer == null) {
      debugPrint('[HomeScreen] Drawer is NULL because roleForDrawer is null. This indicates user context might not be fully loaded or error occurred.');
      // Potentially show a more specific loading/error state for the drawer if this is an issue.
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text('GrubTap'),
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      drawer: activeDrawer,
      body: SafeArea(
        child: RefreshIndicator(
          // On refresh, re-fetch user context which then re-fetches foods and applies filters
          onRefresh: _fetchUserContextAndThenLoadFoods,
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
