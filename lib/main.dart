// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as app_provider;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import 'constants.dart'; // Ensure supabaseUrl and supabaseAnonKey are defined

// --- Screen Imports for Routes ---
// Auth
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';

// User Role Specific Dashboards/Home
import 'screens/home/home_screen.dart'; // For 'user' role
import 'screens/company/company_dashboard_screen.dart'; // For 'company' role
import 'screens/admin/admin_dashboard_screen.dart';   // For 'admin' role

// Company Specific Screens
import 'screens/company/manage_foods_screen.dart'; // Company managing their own foods
import 'screens/company/company_orders_screen.dart'; // Company viewing their own orders

// General Screens (accessible by 'user' role or potentially others based on context)
import 'screens/history/order_history_screen.dart'; // User's own order history

// Admin Specific Management Screens (New additions)
import 'screens/admin/admin_invite_user_screen.dart';
import 'screens/admin/management/admin_manage_users_screen.dart';       // <<< NEW
import 'screens/admin/management/admin_manage_companies_screen.dart';  // <<< NEW
import 'screens/admin/admin_permissions_screen.dart';                 // <<< NEW
import 'screens/admin/management/admin_manage_foods_screen.dart';     // <<< NEW
import 'screens/admin/management/admin_manage_orders_screen.dart';    // <<< NEW
import 'screens/admin/admin_analytics_screen.dart';                   // <<< NEW


// Shared UI & Providers
import 'shared/global_background.dart';
import 'providers/theme_provider.dart';
import 'services/session_service.dart';
import 'providers/background_provider.dart';

enum AuthStatus { unknown, authenticatedNoRole, authenticatedWithRole, unauthenticated }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
  );
  debugPrint("Supabase initialized.");

  final bgProvider = BackgroundProvider();
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
    final themeProvider = app_provider.Provider.of<ThemeProvider>(context, listen: false);

    // --- ThemeData Definitions (Light & Dark) ---
    // (Your ThemeData definitions remain unchanged here - they are correct)
    final baseLightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: Colors.deepPurple,
      scaffoldBackgroundColor: Colors.transparent,
      cardTheme: CardThemeData(
        color: Colors.white.withOpacity(0.92),
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      dialogBackgroundColor: Colors.white.withOpacity(0.97),
      appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.grey[800],
          titleTextStyle: TextStyle(color: Colors.grey[800], fontSize: 20, fontWeight: FontWeight.w500)
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12.0)),
        ),
        filled: true,
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
      colorSchemeSeed: Colors.deepPurple,
      scaffoldBackgroundColor: Colors.transparent,
      cardTheme: CardThemeData(
        color: Colors.grey[850]!.withOpacity(0.92),
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      dialogBackgroundColor: Colors.grey[850]!.withOpacity(0.97),
      appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12.0)),
        ),
        filled: true,
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
    // --- End of ThemeData Definitions ---


    Widget wrapWithGlobalBackground(Widget child) {
      return GlobalBackground(
        themeMode: themeProvider.themeMode,
        child: child,
      );
    }

    return MaterialApp(
      title: 'GrubTap',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: baseLightTheme,
      darkTheme: baseDarkTheme,
      home: wrapWithGlobalBackground(const AuthWrapper()), // AuthWrapper handles initial screen
      routes: {
        // Auth Routes
        LoginScreen.routeName: (context) => const LoginScreen(), // Typically not wrapped with GlobalBackground
        SignupScreen.routeName: (context) => const SignupScreen(), // Typically not wrapped

        // Role-Specific Home/Dashboard Routes (Wrapped)
        HomeScreen.routeName: (context) => wrapWithGlobalBackground(const HomeScreen()),
        AdminDashboardScreen.routeName: (context) => wrapWithGlobalBackground(const AdminDashboardScreen()),
        CompanyDashboardScreen.routeName: (context) => wrapWithGlobalBackground(const CompanyDashboardScreen()),

        // Admin Specific Management Routes (Wrapped)
        AdminInviteUserScreen.routeName: (context) => wrapWithGlobalBackground(const AdminInviteUserScreen()),
        AdminManageUsersScreen.routeName: (context) => wrapWithGlobalBackground(const AdminManageUsersScreen()),             // <<< NEW & WRAPPED
        AdminManageCompaniesScreen.routeName: (context) => wrapWithGlobalBackground(const AdminManageCompaniesScreen()),   // <<< NEW & WRAPPED
        AdminPermissionsScreen.routeName: (context) => wrapWithGlobalBackground(const AdminPermissionsScreen()),           // <<< NEW & WRAPPED
        AdminManageFoodsScreen.routeName: (context) => wrapWithGlobalBackground(const AdminManageFoodsScreen()),             // <<< NEW & WRAPPED
        AdminManageOrdersScreen.routeName: (context) => wrapWithGlobalBackground(const AdminManageOrdersScreen()),           // <<< NEW & WRAPPED
        AdminAnalyticsScreen.routeName: (context) => wrapWithGlobalBackground(const AdminAnalyticsScreen()),                 // <<< NEW & WRAPPED

        // Company Specific Routes (Wrapped)
        ManageFoodsScreen.routeName: (context) => wrapWithGlobalBackground(const ManageFoodsScreen()), // Company managing own foods
        CompanyOrdersScreen.routeName: (context) => wrapWithGlobalBackground(const CompanyOrdersScreen()), // Company viewing own orders

        // General User Routes (Wrapped)
        OrderHistoryScreen.routeName: (context) => wrapWithGlobalBackground(const OrderHistoryScreen()), // User's order history
      },
    );
  }
}

// --- AuthWrapper (Handles session and role-based navigation) ---
// (Your AuthWrapper class definition remains unchanged here - it is correct)
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
    debugPrint("[AuthWrapper] initState called.");
    SessionService.initializeSessionListener(
      onSessionRestored: (User? user) {
        debugPrint("[AuthWrapper] onSessionRestored (User: ${user?.id}). Evaluating session and role.");
        _evaluateSessionAndRole();
      },
      onSessionExpiredOrSignedOut: () {
        debugPrint("[AuthWrapper] onSessionExpiredOrSignedOut. Setting state to unauthenticated.");
        if (mounted) {
          setState(() {
            _authStatus = AuthStatus.unauthenticated;
            _currentRole = null;
          });
        }
      },
    );
    // Initial evaluation if a session might already exist (e.g. from hot reload or previous run)
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
    // Avoid unnecessary rebuilds if already in a definitive state like unauthenticated
    // and this is called again (e.g. from session listener after a manual logout elsewhere)
    if (_authStatus != AuthStatus.unknown && SessionService.getCurrentUser() == null) {
      if (_authStatus != AuthStatus.unauthenticated) {
        setStateIfMounted(() {
          _authStatus = AuthStatus.unauthenticated;
          _currentRole = null;
        });
      }
      return;
    }


    setStateIfMounted(() => _authStatus = AuthStatus.unknown); // Show loading while evaluating

    final currentUser = SessionService.getCurrentUser();
    debugPrint("[AuthWrapper] _evaluateSessionAndRole: Current Auth User from SessionService: ${currentUser?.id}");

    if (currentUser != null) {
      final role = await SessionService.getUserRole(); // This now correctly handles potential null metadata
      if (!mounted) return;
      debugPrint("[AuthWrapper] Role fetched via SessionService.getUserRole(): '$role' for user ${currentUser.id}");
      setStateIfMounted(() {
        _currentRole = role;
        if (_currentRole == null || _currentRole!.isEmpty) {
          _authStatus = AuthStatus.authenticatedNoRole;
          debugPrint("[AuthWrapper] User ${currentUser.id} is Authenticated, but NO VALID ROLE in profiles. Status: authenticatedNoRole.");
        } else {
          _authStatus = AuthStatus.authenticatedWithRole;
          debugPrint("[AuthWrapper] User ${currentUser.id} is Authenticated WITH ROLE '$_currentRole'. Status: authenticatedWithRole.");
        }
      });
    } else {
      setStateIfMounted(() {
        _authStatus = AuthStatus.unauthenticated;
        _currentRole = null;
        debugPrint("[AuthWrapper] User is Unauthenticated. Status: unauthenticated.");
      });
    }
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // _handleRoleSelectionCompleted might be needed if you have a separate role selection screen post-signup
  // void _handleRoleSelectionCompleted() {
  //   debugPrint("[AuthWrapper] _handleRoleSelectionCompleted: Role selection/signup from RoleSelectorScreen finished. Re-evaluating session.");
  //   _evaluateSessionAndRole();
  // }

  @override
  void dispose() {
    debugPrint("[AuthWrapper] dispose called.");
    // Consider if SessionService needs a method to remove the listener
    // SessionService.disposeSessionListener(); // If you implement such a method
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("[AuthWrapper] build: AuthStatus: $_authStatus, CurrentRole: '$_currentRole'");
    Widget screenToShow;
    switch (_authStatus) {
      case AuthStatus.unknown:
        screenToShow = const Scaffold(key: ValueKey("AuthWrapperLoadingScaffold"), body: Center(child: CircularProgressIndicator(key: ValueKey("AuthWrapperLoadingIndicator"))));
        break;
      case AuthStatus.unauthenticated:
        screenToShow = const LoginScreen(key: ValueKey("AuthWrapperLoginScreen"));
        break;
      case AuthStatus.authenticatedNoRole:
        debugPrint("[AuthWrapper] In authenticatedNoRole state. Showing error/guidance.");
        screenToShow = Scaffold(
          key: const ValueKey("AuthWrapperAuthNoRoleErrorScaffold"),
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
                debugPrint("Contact support pressed from AuthNoRole state.");
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
            screenToShow = const HomeScreen(key: ValueKey("AuthWrapperUserHomeScreen"));
            break;
          case 'company':
            screenToShow = const CompanyDashboardScreen(key: ValueKey("AuthWrapperCompanyDashboard"));
            break;
          case 'admin':
            screenToShow = const AdminDashboardScreen(key: ValueKey("AuthWrapperAdminDashboard"));
            break;
          default:
            debugPrint("[AuthWrapper] Authenticated but has an UNHANDLED role: '$_currentRole'. Showing error/guidance.");
            screenToShow = Scaffold(
              key: const ValueKey("AuthWrapperUnhandledRoleErrorScaffold"),
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
    // The AuthWrapper's content itself (screenToShow) should NOT be wrapped by GlobalBackground again
    // if its children (LoginScreen, HomeScreen, etc.) are already being wrapped or don't need it.
    // The home: wrapWithGlobalBackground(const AuthWrapper()) in MaterialApp handles the initial wrap.
    return screenToShow;
  }
}

