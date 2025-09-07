// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' as app_provider;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
// REMOVE uni_links import
// import 'package:uni_links/uni_links.dart' as uni_links;
// ADD app_links import
import 'package:app_links/app_links.dart'; // Import app_links

import 'constants.dart';
// ... (rest of your imports for screens, providers, services remain the same) ...
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/force_change_password_screen.dart';
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
import 'providers/theme_provider.dart';
import 'services/session_service.dart';


enum AuthStatus { unknown, authenticatedNoRole, authenticatedWithRole, unauthenticated }

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // ... (main function remains the same)
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
  // ... (MyApp build method remains the same with themes and MaterialApp setup)
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = app_provider.Provider.of<ThemeProvider>(context);
    const MaterialColor primarySeedColor = Colors.deepPurple;

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
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: baseLightTheme,
      darkTheme: baseDarkTheme,
      initialRoute: AuthWrapper.routeName,
      routes: {
        AuthWrapper.routeName: (context) => const AuthWrapper(),
        LoginScreen.routeName: (context) => const LoginScreen(),
        SignupScreen.routeName: (context) => const SignupScreen(),
        ForgotPasswordScreen.routeName: (context) => const ForgotPasswordScreen(),
        ResetPasswordScreen.routeName: (context) => const ResetPasswordScreen(),
        ForceChangePasswordScreen.routeName: (context) => const ForceChangePasswordScreen(comesFromTempPassword: false),
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
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (_) => UndefinedView(name: settings.name));
      },
    );
  }
}


class AuthWrapper extends StatefulWidget {
  static const String routeName = '/';
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  AuthStatus _authStatus = AuthStatus.unknown;
  String? _currentRole;
  final supabase = Supabase.instance.client;
  // Change StreamSubscription type and AppLinks instance
  late AppLinks _appLinks; // Use AppLinks instance
  StreamSubscription<Uri>? _linkSubscription; // Stream is of Uri

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
      if (supabase.auth.currentSession != null && _authStatus == AuthStatus.unknown) {
        _evaluateSessionAndRole();
      } else if (supabase.auth.currentSession == null && _authStatus == AuthStatus.unknown) {
        if (mounted) setState(() => _authStatus = AuthStatus.unauthenticated);
      }
    });
    _initAppLinks(); // Initialize deep link listener using app_links
  }

  Future<void> _initAppLinks() async {
    _appLinks = AppLinks(); // Initialize AppLinks

    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null && mounted) {
        debugPrint("[AuthWrapper] Initial deep link (app_links): $initialUri");
        _handleDeepLink(initialUri);
      }
    } on PlatformException {
      debugPrint("[AuthWrapper] Failed to get initial deep link (app_links - PlatformException).");
    } on FormatException { // Though getInitialAppLink returns Uri directly
      debugPrint("[AuthWrapper] Failed to parse initial deep link (app_links - FormatException).");
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) { // Listen to uriLinkStream
      if (mounted) {
        debugPrint("[AuthWrapper] Subsequent deep link (app_links): $uri");
        _handleDeepLink(uri);
      }
    }, onError: (err) {
      debugPrint("[AuthWrapper] Error listening to deep links (app_links): $err");
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint("[AuthWrapper] Handling deep link (app_links): $uri");
    final NavigatorState? nav = navigatorKey.currentState;

    if (nav == null) {
      debugPrint("[AuthWrapper] Navigator state is null, cannot handle deep link (app_links).");
      return;
    }

    if (uri.scheme == 'myapp' && uri.host == 'password-reset') {
      bool isAlreadyOnResetScreen = false;
      nav.popUntil((route) {
        if (route.settings.name == ResetPasswordScreen.routeName) {
          isAlreadyOnResetScreen = true;
        }
        return true;
      });

      if (!isAlreadyOnResetScreen) {
        nav.pushNamed(ResetPasswordScreen.routeName);
      } else {
        debugPrint("[AuthWrapper] Already on ResetPasswordScreen (app_links).");
      }
    }
    // Handle other deep links if necessary
  }

  Future<void> _evaluateSessionAndRole() async {
    // ... (This method remains unchanged)
    if (!mounted) return;
    if (_authStatus == AuthStatus.unauthenticated && SessionService.getCurrentUser() == null) return;
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
    if (currentUser != null) {
      final role = await SessionService.getUserRole();
      final userMetadata = SessionService.getCachedUserMetadata();
      final bool requiresPasswordChange = userMetadata?['requires_password_change'] == true;
      if (!mounted) return;
      if (requiresPasswordChange) {
        setStateIfMounted(() {
          _authStatus = AuthStatus.authenticatedWithRole;
          _currentRole = role;
        });
        return;
      }
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
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... (This build method remains unchanged, still calling SessionService.getInitialRouteWidgetForRole)
    Widget screenToShow;
    switch (_authStatus) {
      case AuthStatus.unknown:
        screenToShow = const Scaffold(body: Center(child: CircularProgressIndicator(key: ValueKey("AuthWrapperLoading"))));
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
        final userMetadata = SessionService.getCachedUserMetadata();
        final bool requiresPasswordChange = userMetadata?['requires_password_change'] == true;

        if (requiresPasswordChange) {
          screenToShow = const ForceChangePasswordScreen(comesFromTempPassword: true);
        } else {
          screenToShow = SessionService.getInitialRouteWidgetForRole(_currentRole);
        }
        break;
    }
    return screenToShow;
  }
}

class UndefinedView extends StatelessWidget {
  // ... (UndefinedView remains the same)
  final String? name;
  const UndefinedView({super.key, this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error - Route Not Found')),
      body: Center(child: Text('Route for "$name" is not defined or an error occurred during navigation.')),
    );
  }
}
