// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as app_provider;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import 'constants.dart';

// --- Screen Imports for Routes ---
// Auth
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
// import 'screens/auth/role_selector_screen.dart'; // No longer needed here if not a named route

// User Role Specific Dashboards/Home
import 'screens/home/home_screen.dart';
import 'screens/company/company_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

// Company Specific Screens
import 'screens/company/manage_foods_screen.dart';
import 'screens/company/company_orders_screen.dart';

// General Screens
import 'screens/history/order_history_screen.dart';

// Admin Specific Management Screens
import 'screens/admin/admin_invite_user_screen.dart';
import 'screens/admin/management/admin_manage_users_screen.dart';
import 'screens/admin/management/admin_manage_companies_screen.dart';
import 'screens/admin/admin_permissions_screen.dart';
import 'screens/admin/management/admin_manage_foods_screen.dart';
import 'screens/admin/management/admin_manage_orders_screen.dart';
import 'screens/admin/admin_analytics_screen.dart';

// Providers
import 'providers/theme_provider.dart';
import 'services/session_service.dart';

enum AuthStatus { unknown, authenticatedNoRole, authenticatedWithRole, unauthenticated }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
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

    final baseLightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorSchemeSeed: Colors.deepPurple,
      appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0.5,
          foregroundColor: Colors.black87,
          iconTheme: const IconThemeData(color: Colors.black87),
          titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w500)
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withOpacity(0.95),
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      dialogBackgroundColor: Colors.white.withOpacity(0.97),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12.0)),
        ),
        filled: true,
        fillColor: Color(0xFFF0F0F0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );

    final baseDarkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.white, // Uniform white background
      colorSchemeSeed: Colors.deepPurple,
      appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0.5,
          foregroundColor: Colors.black87,
          iconTheme: const IconThemeData(color: Colors.black87),
          titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w500)
      ),
      cardTheme: CardThemeData(
        color: Colors.grey[100]!,
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      dialogBackgroundColor: Colors.white.withOpacity(0.97),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12.0)),
        ),
        filled: true,
        fillColor: Color(0xFFF0F0F0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: Typography.material2021(platform: defaultTargetPlatform).black,
      iconTheme: const IconThemeData(color: Colors.black54),
    );

    return MaterialApp(
      title: 'GrubTap',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: baseLightTheme,
      darkTheme: baseDarkTheme,
      home: const AuthWrapper(),
      routes: {
        // Auth Routes
        LoginScreen.routeName: (context) => const LoginScreen(),
        SignupScreen.routeName: (context) => const SignupScreen(),
        // RoleSelectorScreen.routeName is NOT defined here as it's not a direct named route

        // Role-Specific Home/Dashboard Routes
        HomeScreen.routeName: (context) => const HomeScreen(),
        AdminDashboardScreen.routeName: (context) => const AdminDashboardScreen(),
        CompanyDashboardScreen.routeName: (context) => const CompanyDashboardScreen(),

        // Admin Specific Management Routes
        AdminInviteUserScreen.routeName: (context) => const AdminInviteUserScreen(),
        AdminManageUsersScreen.routeName: (context) => const AdminManageUsersScreen(),
        AdminManageCompaniesScreen.routeName: (context) => const AdminManageCompaniesScreen(),
        AdminPermissionsScreen.routeName: (context) => const AdminPermissionsScreen(),
        AdminManageFoodsScreen.routeName: (context) => const AdminManageFoodsScreen(),
        AdminManageOrdersScreen.routeName: (context) => const AdminManageOrdersScreen(),
        AdminAnalyticsScreen.routeName: (context) => const AdminAnalyticsScreen(),

        // Company Specific Routes
        ManageFoodsScreen.routeName: (context) => const ManageFoodsScreen(),
        CompanyOrdersScreen.routeName: (context) => const CompanyOrdersScreen(),

        // General User Routes
        OrderHistoryScreen.routeName: (context) => const OrderHistoryScreen(),
      },
    );
  }
}

// --- AuthWrapper (Handles session and role-based navigation) ---
// This class definition remains the same.
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
    // debugPrint("[AuthWrapper] initState called."); // Keep if useful
    SessionService.initializeSessionListener(
      onSessionRestored: (User? user) {
        // debugPrint("[AuthWrapper] onSessionRestored (User: ${user?.id}). Evaluating session and role.");
        _evaluateSessionAndRole();
      },
      onSessionExpiredOrSignedOut: () {
        // debugPrint("[AuthWrapper] onSessionExpiredOrSignedOut. Setting state to unauthenticated.");
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
    if (_authStatus != AuthStatus.unknown && SessionService.getCurrentUser() == null) {
      if (_authStatus != AuthStatus.unauthenticated) {
        setStateIfMounted(() {
          _authStatus = AuthStatus.unauthenticated;
          _currentRole = null;
        });
      }
      return;
    }

    setStateIfMounted(() => _authStatus = AuthStatus.unknown);
    final currentUser = SessionService.getCurrentUser();
    // debugPrint("[AuthWrapper] _evaluateSessionAndRole: Current Auth User from SessionService: ${currentUser?.id}");

    if (currentUser != null) {
      final role = await SessionService.getUserRole();
      if (!mounted) return;
      // debugPrint("[AuthWrapper] Role fetched via SessionService.getUserRole(): '$role' for user ${currentUser.id}");
      setStateIfMounted(() {
        _currentRole = role;
        if (_currentRole == null || _currentRole!.isEmpty) {
          _authStatus = AuthStatus.authenticatedNoRole;
          // debugPrint("[AuthWrapper] User ${currentUser.id} is Authenticated, but NO VALID ROLE in profiles. Status: authenticatedNoRole.");
        } else {
          _authStatus = AuthStatus.authenticatedWithRole;
          // debugPrint("[AuthWrapper] User ${currentUser.id} is Authenticated WITH ROLE '$_currentRole'. Status: authenticatedWithRole.");
        }
      });
    } else {
      setStateIfMounted(() {
        _authStatus = AuthStatus.unauthenticated;
        _currentRole = null;
        // debugPrint("[AuthWrapper] User is Unauthenticated. Status: unauthenticated.");
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
    // debugPrint("[AuthWrapper] dispose called.");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // debugPrint("[AuthWrapper] build: AuthStatus: $_authStatus, CurrentRole: '$_currentRole'");
    Widget screenToShow;
    switch (_authStatus) {
      case AuthStatus.unknown:
        screenToShow = const Scaffold(body: Center(child: CircularProgressIndicator()));
        break;
      case AuthStatus.unauthenticated:
        screenToShow = const LoginScreen();
        break;
      case AuthStatus.authenticatedNoRole:
      // debugPrint("[AuthWrapper] In authenticatedNoRole state. Showing error/guidance.");
        screenToShow = Scaffold(
          appBar: AppBar(title: const Text("Account Issue")),
          body: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 16),
            const Text(
              "Your account is missing essential role information or is not yet fully verified. Please check your email for a verification link if you just signed up, or contact support.",
              textAlign: TextAlign.center, style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () async { await SessionService.logout(); _evaluateSessionAndRole(); }, child: const Text("Logout and Try Again")),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                // debugPrint("Contact support pressed from AuthNoRole state.");
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please contact support for assistance with your account role.")));
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
          // debugPrint("[AuthWrapper] Authenticated but has an UNHANDLED role: '$_currentRole'. Showing error/guidance.");
            screenToShow = Scaffold(
              appBar: AppBar(title: const Text("Account Role Issue")),
              body: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 50),
                const SizedBox(height: 16),
                Text(
                  "Your account has an unrecognized role ('$_currentRole'). Please contact support.",
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: () async { await SessionService.logout(); _evaluateSessionAndRole(); }, child: const Text("Logout")),
              ]))),
            );
        }
        break;
    }
    return screenToShow;
  }
}
