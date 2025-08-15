// lib/screens/auth/role_selector_screen.dart

import 'package:flutter/material.dart';
import 'package:grubtap/services/session_service.dart';
import 'package:grubtap/main.dart'; // To reload AuthWrapper

class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Role')),
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                await SessionService.saveUserRole("user");
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthWrapper()),
                        (route) => false,
                  );
                }
              },
              child: const Text("Continue as User"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await SessionService.saveUserRole("company");
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthWrapper()),
                        (route) => false,
                  );
                }
              },
              child: const Text("Food Company"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await SessionService.saveUserRole("admin");
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthWrapper()),
                        (route) => false,
                  );
                }
              },
              child: const Text("Admin"),
            ),
          ],
        ),
      ),
    );
  }
}
