import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as app_provider;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'constants.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/role_selector_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'providers/background_provider.dart';
import 'providers/theme_provider.dart';
import 'services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final bgProvider = BackgroundProvider();
  await bgProvider.loadBackground();

  runApp(
    app_provider.MultiProvider(
      providers: [
        app_provider.ChangeNotifierProvider(create: (_) => bgProvider),
        app_provider.ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = app_provider.Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'GrubTap',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        primaryColor: Colors.deepPurple,
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        primaryColor: Colors.deepPurple,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _currentRole;
  bool _isLoading = true;
  late final StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _initializeSessionAndListen();
  }

  Future<void> _initializeSessionAndListen() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      final savedRole = await SessionService.getUserRole();
      if (mounted) {
        setState(() {
          _currentRole = savedRole;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _currentRole = null;
          _isLoading = false;
        });
      }
    }

    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final Session? session = data.session;
      final AuthChangeEvent event = data.event;

      if (event == AuthChangeEvent.signedIn) {
        if (session != null) {
          final savedRole = await SessionService.getUserRole();
          if (mounted) {
            setState(() {
              _currentRole = savedRole;
              if (_isLoading) _isLoading = false;
            });
          }
        } else {
          await SessionService.clearUserRole();
          if (mounted) {
            setState(() {
              _currentRole = null;
              if (_isLoading) _isLoading = false;
            });
          }
        }
      } else if (event == AuthChangeEvent.signedOut) {
        await SessionService.clearUserRole();
        if (mounted) {
          setState(() {
            _currentRole = null;
            if (_isLoading) _isLoading = false;
          });
        }
      } else if (event == AuthChangeEvent.tokenRefreshed || event == AuthChangeEvent.userUpdated) {
        if (session == null && mounted) {
          await SessionService.clearUserRole();
          setState(() {
            _currentRole = null;
          });
        } else if (session != null && _currentRole == null && mounted) {
          final savedRole = await SessionService.getUserRole();
          if (mounted) {
            setState(() {
              _currentRole = savedRole;
            });
          }
        }

        if (_isLoading && mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser != null) {
      if (_currentRole == 'user') {
        return const MainNavigationScreen(); // Entry point for authenticated users
      } else if (_currentRole == 'company') {
        return const RoleSelectorScreen();
      } else if (_currentRole == 'admin') {
        return const RoleSelectorScreen();
      } else {
        return const RoleSelectorScreen();
      }
    } else {
      return const LoginScreen();
    }
  }
}
