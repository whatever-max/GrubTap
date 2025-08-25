// lib/shared/custom_drawer.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:grubtap/services/session_service.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

// --- Screen Imports for Navigation ---
import 'package:grubtap/screens/home/home_screen.dart';
import 'package:grubtap/screens/admin/admin_dashboard_screen.dart';
import 'package:grubtap/screens/admin/admin_invite_user_screen.dart';
import 'package:grubtap/screens/history/order_history_screen.dart';
import 'package:grubtap/screens/company/company_dashboard_screen.dart';
import 'package:grubtap/screens/auth/login_screen.dart';

class CustomDrawer extends StatelessWidget {
  final String userRole;

  const CustomDrawer({
    super.key,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final theme = Theme.of(context);
    final bool isDarkTheme = theme.brightness == Brightness.dark;

    final String username =
        user?.userMetadata?['username'] as String? ??
            user?.email?.split('@').first ??
            'User';
    final String email = user?.email ?? 'No email available';
    final String? avatarUrlFromMeta = user?.userMetadata?['avatar_url'] as String?;
    final String avatarUrl = (avatarUrlFromMeta != null && avatarUrlFromMeta.isNotEmpty)
        ? avatarUrlFromMeta
        : 'https://i.imgur.com/BoN9kdC.png'; // Default placeholder

    // Define colors for drawer elements ensuring readability on a white background
    // If the app theme is dark, text/icons on the white drawer should still be dark.
    final Color drawerTextColor = isDarkTheme ? Colors.black87 : (theme.textTheme.bodyLarge?.color ?? Colors.black87);
    final Color drawerIconColor = isDarkTheme ? theme.colorScheme.primary : theme.colorScheme.primary; // Keep primary for icons or choose a dark one
    final Color drawerHeaderTextColor = theme.colorScheme.onPrimary; // Text on primary color background
    final Color drawerErrorColor = theme.colorScheme.error;


    List<Widget> drawerItems = [];

    drawerItems.add(
      UserAccountsDrawerHeader(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary, // Keep primary color for header background
        ),
        accountName: Text(
          username,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: drawerHeaderTextColor,
          ),
        ),
        accountEmail: Text(
          email,
          style: TextStyle(color: drawerHeaderTextColor.withOpacity(0.8)),
        ),
        currentAccountPicture: CircleAvatar(
          backgroundColor: drawerHeaderTextColor.withOpacity(0.5),
          backgroundImage: NetworkImage(avatarUrl),
          onBackgroundImageError: (exception, stackTrace) {
            debugPrint("[CustomDrawer] Error loading avatar from NetworkImage: $avatarUrl\n$exception");
          },
          child: (avatarUrlFromMeta == null || avatarUrlFromMeta.isEmpty)
              ? Icon(Icons.person, size: 40, color: theme.colorScheme.primary)
              : null,
        ),
      ),
    );

    // --- Common "Home (User View)"/"Home" link ---
    drawerItems.add(
      ListTile(
        leading: Icon(Icons.home_outlined, color: drawerIconColor),
        title: Text(
          (userRole == 'admin' || userRole == 'company') ? 'Home (User View)' : 'Home',
          style: TextStyle(color: drawerTextColor),
        ),
        onTap: () {
          Navigator.pop(context); // Close drawer
          if (ModalRoute.of(context)?.settings.name != HomeScreen.routeName) {
            Navigator.pushNamedAndRemoveUntil(context, HomeScreen.routeName, (route) => false);
          }
        },
      ),
    );

    // --- Admin Specific Items ---
    if (userRole == 'admin') {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.dashboard_customize_outlined, color: drawerIconColor),
          title: Text('Admin Dashboard', style: TextStyle(color: drawerTextColor)),
          onTap: () {
            Navigator.pop(context);
            if (ModalRoute.of(context)?.settings.name != AdminDashboardScreen.routeName) {
              Navigator.pushNamedAndRemoveUntil(context, AdminDashboardScreen.routeName, (route) => false);
            }
          },
        ),
      );
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.person_add_alt_1_outlined, color: drawerIconColor),
          title: Text('Invite User', style: TextStyle(color: drawerTextColor)),
          onTap: () {
            Navigator.pop(context);
            if (ModalRoute.of(context)?.settings.name != AdminInviteUserScreen.routeName) {
              Navigator.pushNamed(context, AdminInviteUserScreen.routeName);
            }
          },
        ),
      );
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.history_outlined, color: drawerIconColor),
          title: Text('Order History (Admin View)', style: TextStyle(color: drawerTextColor)),
          onTap: () {
            Navigator.pop(context);
            if (ModalRoute.of(context)?.settings.name != OrderHistoryScreen.routeName) {
              Navigator.pushNamed(context, OrderHistoryScreen.routeName);
            }
          },
        ),
      );
    }

    // --- User Specific Items ---
    if (userRole == 'user') {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.history_outlined, color: drawerIconColor),
          title: Text('My Order History', style: TextStyle(color: drawerTextColor)),
          onTap: () {
            Navigator.pop(context);
            if (ModalRoute.of(context)?.settings.name != OrderHistoryScreen.routeName) {
              Navigator.pushNamed(context, OrderHistoryScreen.routeName);
            }
          },
        ),
      );
    }

    // --- Company Specific Items ---
    if (userRole == 'company') {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.storefront_outlined, color: drawerIconColor),
          title: Text('Company Dashboard', style: TextStyle(color: drawerTextColor)),
          onTap: () {
            Navigator.pop(context);
            if (ModalRoute.of(context)?.settings.name != CompanyDashboardScreen.routeName) {
              Navigator.pushNamedAndRemoveUntil(context, CompanyDashboardScreen.routeName, (route) => false);
            }
          },
        ),
      );
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.history_outlined, color: drawerIconColor),
          title: Text('My Order History', style: TextStyle(color: drawerTextColor)),
          onTap: () {
            Navigator.pop(context);
            if (ModalRoute.of(context)?.settings.name != OrderHistoryScreen.routeName) {
              Navigator.pushNamed(context, OrderHistoryScreen.routeName);
            }
          },
        ),
      );
    }

    // --- Divider and Logout (Common to all roles) ---
    drawerItems.add(const Divider(thickness: 1.0));
    drawerItems.add(
      ListTile(
        leading: Icon(Icons.logout_outlined, color: drawerErrorColor),
        title: Text('Log Out', style: TextStyle(color: drawerErrorColor)),
        onTap: () async {
          final currentContext = context;
          Navigator.pop(currentContext); // Close drawer first

          try {
            debugPrint("[CustomDrawer] Logout initiated by user.");
            await SessionService.logout();
            if (currentContext.mounted) {
              debugPrint("[CustomDrawer] Navigating to LoginScreen after logout and clearing stack.");
              Navigator.of(currentContext).pushNamedAndRemoveUntil(
                LoginScreen.routeName,
                    (Route<dynamic> route) => false,
              );
            } else {
              debugPrint("[CustomDrawer] Context was unmounted after SessionService.logout(), AuthWrapper should handle navigation.");
            }
          } catch (e) {
            debugPrint("[CustomDrawer] Error during logout process: $e");
            if (currentContext.mounted) {
              ScaffoldMessenger.of(currentContext).showSnackBar(
                SnackBar(
                  content: Text('Error signing out: ${e.toString()}', style: TextStyle(color: theme.colorScheme.onError)),
                  backgroundColor: drawerErrorColor,
                ),
              );
            }
          }
        },
      ),
    );

    return Drawer(
      backgroundColor: Colors.white, // <<< CORE CHANGE: Set drawer background to white
      child: ListView(
        padding: EdgeInsets.zero,
        children: drawerItems,
      ),
    );
  }
}
