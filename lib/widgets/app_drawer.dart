/*import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/history/history_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/auth/login_screen.dart';
import '../services/session_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    await SessionService.clearUserRole();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.deepPurple),
            ),
            accountName: Text(user?.userMetadata?['username'] ?? 'User'),
            accountEmail: Text(user?.email ?? ''),
            decoration: const BoxDecoration(color: Colors.deepPurple),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Order History'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log Out'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
*/