// lib/screens/main_navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:grubtap/screens/home/home_screen.dart'; // Ensure this path is correct
import 'package:grubtap/screens/chat/chat_screen.dart'; // Ensure this path is correct
import 'package:grubtap/screens/order/order_history_screen.dart'; // Ensure this path is correct
import 'package:grubtap/screens/order/order_now_screen.dart'; // Ensure this path is correct

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 1; // Default to Home screen
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const ChatScreen(), // Index 0
      HomeScreen(key: _homeScreenKey), // Index 1
      const OrderHistoryScreen(), // Index 2
    ];
  }

  void _onItemTapped(int index) {
    // If tapping the currently selected "Home" tab, refresh its content
    if (_selectedIndex == index && index == 1) {
      _homeScreenKey.currentState?.refreshData();
    }
    setState(() => _selectedIndex = index);
  }

  void _onOrderNowTapped() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrderNowScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onOrderNowTapped,
        child: const Icon(Icons.restaurant), // Fork and knife icon
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 6,
        tooltip: 'Order Now', // Accessibility
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).bottomAppBarTheme.color ?? Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        // shape: const CircularNotchedRectangle(), // Uncomment if you want a notch for a centered FAB
        // clipBehavior: Clip.antiAlias, // Useful with notch
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(Icons.chat_bubble_outline, 'Chat', 0),
            _buildNavItem(Icons.home_outlined, 'Home', 1),
            _buildNavItem(Icons.receipt_long_outlined, 'My Orders', 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    final itemColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey[600];
    final iconSize = isSelected ? 24.0 : 22.0;
    final fontSize = isSelected ? 11.0 : 10.0;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(20), // Adjust for hit area visuals
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0), // Reduced padding
          child: Column(
            mainAxisSize: MainAxisSize.min, // Important for BottomAppBar
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: itemColor, size: iconSize),
              // const SizedBox(height: 2), // Add back if needed for spacing, else remove
              Text(
                label,
                style: TextStyle(
                  color: itemColor,
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
