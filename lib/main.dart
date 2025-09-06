// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as app_provider;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import 'constants.dart'; // Make sure this file exists and supabaseUrl/supabaseAnonKey are defined

// --- Screen Imports for Routes ---
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/company/company_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/company/manage_foods_screen.dart';
import 'screens/company/company_orders_screen.dart';
import 'screens/history/order_history_screen.dart';
import 'screens/admin/admin_invite_user_screen.dart';
import 'screens/admin/management/admin_manage_users_screen.dart';
import 'screens/admin/management/admin_manage_companies_screen.dart';
import 'screens/admin/admin_permissions_screen.dart';
import 'screens/admin/management/admin_manage_foods_screen.dart';
import 'screens/admin/management/admin_manage_orders_screen.dart';
import 'screens/admin/admin_analytics_screen.dart';

// Providers
import 'providers/theme_provider.dart'; // Make sure this file exists
import 'services/session_service.dart';  // Make sure this file exists

enum AuthStatus { unknown, authenticatedNoRole, authenticatedWithRole, unauthenticated }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,    // From constants.dart
    anonKey: supabaseAnonKey, // From constants.dart
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
  );
  debugPrint("Supabase initialized.");

  runApp(
    app_provider.MultiProvider(
      providers: [
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
    // primarySeedColor is Colors.deepPurple, which is a MaterialColor, so .shadeXXX is valid.
    const MaterialColor primarySeedColor = Colors.deepPurple;

    // --- Light Theme ---
    final baseLightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: primarySeedColor,
      scaffoldBackgroundColor: Colors.grey[50],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0.8,
        foregroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
            color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1.5,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogBackgroundColor: Colors.white,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12.0)),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12.0)),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12.0)),
          borderSide: BorderSide(color: primarySeedColor, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIconColor: Colors.grey.shade600,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primarySeedColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primarySeedColor,
          )
      ),
      iconTheme: IconThemeData(color: Colors.grey.shade700),
      textTheme: Typography.material2021(platform: defaultTargetPlatform).black.copyWith(
        bodyLarge: TextStyle(color: Colors.grey.shade800),
        bodyMedium: TextStyle(color: Colors.grey.shade700),
        titleMedium: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        headlineSmall: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
      ),
      dividerColor: Colors.grey.shade300,
    );

    // --- Dark Theme ---
    final baseDarkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: primarySeedColor,
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0.5,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white70),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 1.5,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogBackgroundColor: const Color(0xFF1E1E1E),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12.0)),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12.0)),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12.0)),
          // Ensure primarySeedColor is a MaterialColor to use .shadeXXX
          borderSide: BorderSide(color: primarySeedColor.shade300, width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIconColor: Colors.grey.shade400,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primarySeedColor.shade300,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primarySeedColor.shade300,
          )
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
      textTheme: Typography.material2021(platform: defaultTargetPlatform).white.copyWith(
        bodyLarge: TextStyle(color: Colors.grey.shade300),
        bodyMedium: TextStyle(color: Colors.grey.shade400),
        titleMedium: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        headlineSmall: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      dividerColor: Colors.grey.shade800,
    );

    return MaterialApp(
      title: 'GrubTap',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: baseLightTheme,
      darkTheme: baseDarkTheme,
      home: const AuthWrapper(),
      routes: {
        LoginScreen.routeName: (context) => const LoginScreen(),
        SignupScreen.routeName: (context) => const SignupScreen(),
        HomeScreen.routeName: (context) => const HomeScreen(),
        AdminDashboardScreen.routeName: (context) => const AdminDashboardScreen(),
        CompanyDashboardScreen.routeName: (context) => const CompanyDashboardScreen(),
        AdminInviteUserScreen.routeName: (context) => const AdminInviteUserScreen(),
        AdminManageUsersScreen.routeName: (context) => const AdminManageUsersScreen(),
        AdminManageCompaniesScreen.routeName: (context) => const AdminManageCompaniesScreen(),
        AdminPermissionsScreen.routeName: (context) => const AdminPermissionsScreen(),
        AdminManageFoodsScreen.routeName: (context) => const AdminManageFoodsScreen(),
        AdminManageOrdersScreen.routeName: (context) => const AdminManageOrdersScreen(),
        AdminAnalyticsScreen.routeName: (context) => const AdminAnalyticsScreen(),
        ManageFoodsScreen.routeName: (context) => const ManageFoodsScreen(),
        CompanyOrdersScreen.routeName: (context) => const CompanyOrdersScreen(),
        OrderHistoryScreen.routeName: (context) => const OrderHistoryScreen(),
      },
    );
  }
}

// --- AuthWrapper (Handles session and role-based navigation) ---
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  AuthStatus _authStatus = AuthStatus.unknown;
  String? _currentRole;

  @override
  void initState() {
    super.initState();
    SessionService.initializeSessionListener(
      onSessionRestored: (User? user) {
        _evaluateSessionAndRole();
      },
      onSessionExpiredOrSignedOut: () {
        if (mounted) {
          setState(() {
            _authStatus = AuthStatus.unauthenticated;
            _currentRole = null;
          });
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Supabase.instance.client.auth.currentSession != null && _authStatus == AuthStatus.unknown) {
        _evaluateSessionAndRole();
      } else if (Supabase.instance.client.auth.currentSession == null && _authStatus == AuthStatus.unknown) {
        if (mounted) {
          setState(() {
            _authStatus = AuthStatus.unauthenticated;
          });
        }
      }
    });
  }

  Future<void> _evaluateSessionAndRole() async {
    if (!mounted) return;
    // Optimization: If already unauthenticated and trying to evaluate again with no current user, skip.
    if (_authStatus == AuthStatus.unauthenticated && SessionService.getCurrentUser() == null) return;


    // If auth status is unknown OR if there's a current user (even if previously auth'd with role)
    // we should re-evaluate because role might have changed or session restored.
    if (_authStatus != AuthStatus.unknown && SessionService.getCurrentUser() == null) {
      // This case handles explicit sign out where current user becomes null
      // but status wasn't yet unknown.
      if (_authStatus != AuthStatus.unauthenticated) {
        setStateIfMounted(() {
          _authStatus = AuthStatus.unauthenticated;
          _currentRole = null;
        });
      }
      return;
    }


    setStateIfMounted(() => _authStatus = AuthStatus.unknown); // Show loading
    final currentUser = SessionService.getCurrentUser();

    if (currentUser != null) {
      final role = await SessionService.getUserRole(); // This now correctly gets from user_metadata
      if (!mounted) return;
      setStateIfMounted(() {
        _currentRole = role;
        if (_currentRole == null || _currentRole!.isEmpty) {
          _authStatus = AuthStatus.authenticatedNoRole;
        } else {
          _authStatus = AuthStatus.authenticatedWithRole;
        }
      });
    } else {
      setStateIfMounted(() {
        _authStatus = AuthStatus.unauthenticated;
        _currentRole = null;
      });
    }
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  @override
  void dispose() {
    // It's good practice to cancel any active listeners or timers here.
    // SessionService.disposeListener(); // If SessionService had such a method
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget screenToShow;
    switch (_authStatus) {
      case AuthStatus.unknown:
        screenToShow = const Scaffold(body: Center(child: CircularProgressIndicator()));
        break;
      case AuthStatus.unauthenticated:
        screenToShow = const LoginScreen();
        break;
      case AuthStatus.authenticatedNoRole:
        screenToShow = Scaffold(
          appBar: AppBar(title: const Text("Account Issue")),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 50),
                    const SizedBox(height: 16),
                    const Text(
                      "Your account is missing essential role information or is not yet fully verified. Please check your email for a verification link if you just signed up, or contact support.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        onPressed: () async {
                          await SessionService.logout();
                          // _evaluateSessionAndRole(); // Called by listener
                        },
                        child: const Text("Logout and Try Again")),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text("Please contact support for assistance with your account role.")));
                      },
                      child: const Text("Contact Support"),
                    )
                  ]))),
        );
        break;
      case AuthStatus.authenticatedWithRole:
        switch (_currentRole) {
          case 'user':
            screenToShow = const HomeScreen();
            break;
          case 'company':
            screenToShow = const CompanyDashboardScreen();
            break;
          case 'admin':
            screenToShow = const AdminDashboardScreen();
            break;
          default:
            screenToShow = Scaffold(
              appBar: AppBar(title: const Text("Account Role Issue")),
              body: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 50),
                        const SizedBox(height: 16),
                        Text(
                          "Your account has an unrecognized role ('$_currentRole'). Please contact support.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                            onPressed: () async {
                              await SessionService.logout();
                              // _evaluateSessionAndRole(); // Called by listener
                            },
                            child: const Text("Logout")),
                      ]))),
            );
        }
        break;
    }
    return screenToShow;
  }
}

