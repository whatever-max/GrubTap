// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For PlatformException
import 'package:provider/provider.dart' as app_provider;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';

import 'constants.dart';
// Screen Imports
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart'; // Ensure this uses the updated version
import 'screens/auth/force_change_password_screen.dart';
import 'screens/auth/invite_accept_screen.dart';
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

// Service and Provider Imports
import 'providers/theme_provider.dart';
import 'services/session_service.dart';

enum AuthStatus { unknown, authenticatedNoRole, authenticatedWithRole, unauthenticated }

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
  );
  debugPrint("Supabase initialized successfully.");

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
      onGenerateInitialRoutes: (initialRouteName) {
        debugPrint("[onGenerateInitialRoutes] Initial route name received: $initialRouteName");
        return [
          MaterialPageRoute(
            builder: (_) => const AuthWrapper(),
            settings: RouteSettings(name: initialRouteName),
          ),
        ];
      },
      onGenerateRoute: (settings) {
        debugPrint("[onGenerateRoute] Received route settings: Name: ${settings.name}, Args: ${settings.arguments}");
        Uri uri;
        try {
          uri = Uri.parse(settings.name ?? AuthWrapper.routeName);
        } catch (e) {
          debugPrint("[onGenerateRoute] Error parsing settings.name ('${settings.name}') as URI: $e. Using path directly.");
          uri = Uri(path: settings.name ?? AuthWrapper.routeName);
        }
        debugPrint("[onGenerateRoute] Parsed URI. Path: '${uri.path}', Query: ${uri.queryParameters}, Fragment: '${uri.fragment}', HasAbsolutePath: ${uri.hasAbsolutePath}");

        // Pass any URI with a code or fragment to AuthWrapper to handle first
        if (uri.queryParameters.containsKey('code') || (uri.fragment.isNotEmpty && (uri.fragment.contains('access_token') || uri.fragment.contains('type=')))) {
          debugPrint("[onGenerateRoute] Auth-related link (code/fragment) found. Routing to AuthWrapper: ${settings.name}");
          return MaterialPageRoute(builder: (_) => AuthWrapper(key: UniqueKey()), settings: RouteSettings(name: settings.name, arguments: settings.arguments));
        }

        // Handle specific path-based deep links if they aren't auth related (or if AuthWrapper is intended to handle them)
        if (uri.scheme == 'myapp' && uri.host == 'password-reset' && uri.queryParameters.containsKey('code')) {
          debugPrint("[onGenerateRoute] Specific 'myapp://password-reset?code=...' link. Routing to AuthWrapper.");
          return MaterialPageRoute(builder: (_) => AuthWrapper(key: UniqueKey()), settings: RouteSettings(name: settings.name, arguments: settings.arguments));
        }


        String routePath = uri.path;
        if (routePath.isEmpty && (settings.name == null || settings.name == "/" || settings.name == "")) {
          routePath = AuthWrapper.routeName;
        } else if (routePath.isNotEmpty && !routePath.startsWith('/')) {
          routePath = '/$routePath';
        }
        debugPrint("[onGenerateRoute] Evaluating named route path for switch: '$routePath'");

        switch (routePath) {
          case AuthWrapper.routeName: return MaterialPageRoute(builder: (_) => const AuthWrapper(), settings: settings);
          case LoginScreen.routeName: return MaterialPageRoute(builder: (_) => const LoginScreen(), settings: settings);
          case SignupScreen.routeName: return MaterialPageRoute(builder: (_) => const SignupScreen(), settings: settings);
          case ForgotPasswordScreen.routeName: return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen(), settings: settings);
          case ResetPasswordScreen.routeName: // ResetPasswordScreen will get args if _handleDeepLink sends them
            return MaterialPageRoute(builder: (_) => const ResetPasswordScreen(), settings: settings);
          case InviteAcceptScreen.routeName:  // InviteAcceptScreen will get args if _handleDeepLink sends them
            return MaterialPageRoute(builder: (_) => const InviteAcceptScreen(), settings: settings);
          case ForceChangePasswordScreen.routeName: return MaterialPageRoute(builder: (_) => const ForceChangePasswordScreen(comesFromTempPassword: false), settings: settings);
          case HomeScreen.routeName: return MaterialPageRoute(builder: (_) => const HomeScreen(), settings: settings);
          case AdminDashboardScreen.routeName: return MaterialPageRoute(builder: (_) => const AdminDashboardScreen(), settings: settings);
          case CompanyDashboardScreen.routeName: return MaterialPageRoute(builder: (_) => const CompanyDashboardScreen(), settings: settings);
          case AdminInviteUserScreen.routeName: return MaterialPageRoute(builder: (_) => const AdminInviteUserScreen(), settings: settings);
          case AdminManageUsersScreen.routeName: return MaterialPageRoute(builder: (_) => const AdminManageUsersScreen(), settings: settings);
          case AdminManageCompaniesScreen.routeName: return MaterialPageRoute(builder: (_) => const AdminManageCompaniesScreen(), settings: settings);
          case AdminPermissionsScreen.routeName: return MaterialPageRoute(builder: (_) => const AdminPermissionsScreen(), settings: settings);
          case AdminManageFoodsScreen.routeName: return MaterialPageRoute(builder: (_) => const AdminManageFoodsScreen(), settings: settings);
          case AdminManageOrdersScreen.routeName: return MaterialPageRoute(builder: (_) => const AdminManageOrdersScreen(), settings: settings);
          case AdminAnalyticsScreen.routeName: return MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen(), settings: settings);
          case ManageFoodsScreen.routeName: return MaterialPageRoute(builder: (_) => const ManageFoodsScreen(), settings: settings);
          case CompanyOrdersScreen.routeName: return MaterialPageRoute(builder: (_) => const CompanyOrdersScreen(), settings: settings);
          case OrderHistoryScreen.routeName: return MaterialPageRoute(builder: (_) => const OrderHistoryScreen(), settings: settings);
          default:
            debugPrint("[onGenerateRoute] Switch case: Path '$routePath' (from settings.name: '${settings.name}') did not match. Navigating to UndefinedView.");
            return MaterialPageRoute(builder: (_) => UndefinedView(name: settings.name));
        }
      },
      onUnknownRoute: (settings) {
        debugPrint("[onUnknownRoute] Truly unknown route: ${settings.name}");
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
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    SessionService.initializeSessionListener(
      onSessionRestored: (User? user) {
        debugPrint("[AuthWrapper] SessionService.onSessionRestored. User: ${user?.id}");
        _evaluateSessionAndRole();
      },
      onSessionExpiredOrSignedOut: () {
        debugPrint("[AuthWrapper] SessionService.onSessionExpiredOrSignedOut.");
        if (mounted) {
          setState(() {
            _authStatus = AuthStatus.unauthenticated;
            _currentRole = null;
          });
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint("[AuthWrapper] addPostFrameCallback: Evaluating initial state.");
      final routeSettings = ModalRoute.of(context)?.settings;
      final String? initialRouteNameFromFlutter = routeSettings?.name;
      debugPrint("[AuthWrapper] Initial route name from ModalRoute: '$initialRouteNameFromFlutter'");

      bool initialLinkHandledByModalRoute = false;
      if (initialRouteNameFromFlutter != null &&
          initialRouteNameFromFlutter != AuthWrapper.routeName &&
          initialRouteNameFromFlutter.isNotEmpty) {
        try {
          Uri initialUriFromRoute = Uri.parse(initialRouteNameFromFlutter);
          if (initialUriFromRoute.hasFragment ||
              initialUriFromRoute.queryParameters.containsKey('code') ||
              initialUriFromRoute.scheme.isNotEmpty) {
            debugPrint("[AuthWrapper] Initial URI from ModalRoute ('$initialUriFromRoute') looks like a deep link. Handling...");
            _handleDeepLink(initialUriFromRoute);
            initialLinkHandledByModalRoute = true;
          } else {
            debugPrint("[AuthWrapper] Initial URI ('$initialUriFromRoute') not a deep link for _handleDeepLink. Checking session.");
          }
        } catch (e) {
          debugPrint("[AuthWrapper] Error parsing initial URI ('$initialRouteNameFromFlutter') from ModalRoute: $e. Checking session.");
        }
      }

      if (!initialLinkHandledByModalRoute) {
        _checkSupabaseSession();
      }
      _initAppLinks(initialLinkPotentiallyHandled: initialLinkHandledByModalRoute, initialUriStringFromRoute: initialRouteNameFromFlutter);
    });
  }

  void _checkSupabaseSession() {
    debugPrint("[AuthWrapper] _checkSupabaseSession. Current session: ${supabase.auth.currentSession != null}, AuthStatus: $_authStatus");
    if (supabase.auth.currentSession != null && _authStatus == AuthStatus.unknown) {
      _evaluateSessionAndRole();
    } else if (supabase.auth.currentSession == null && _authStatus == AuthStatus.unknown) {
      if (mounted) setState(() => _authStatus = AuthStatus.unauthenticated);
    }
  }

  Future<void> _initAppLinks({bool initialLinkPotentiallyHandled = false, String? initialUriStringFromRoute}) async {
    _appLinks = AppLinks();
    if (!initialLinkPotentiallyHandled) {
      try {
        final initialUriFromAppLinksPkg = await _appLinks.getInitialAppLink();
        if (initialUriFromAppLinksPkg != null && mounted) {
          debugPrint("[AuthWrapper] _initAppLinks: Initial deep link from app_links package: $initialUriFromAppLinksPkg");
          if (initialUriStringFromRoute != initialUriFromAppLinksPkg.toString()) {
            debugPrint("[AuthWrapper] _initAppLinks: Handling initial URI from app_links.");
            _handleDeepLink(initialUriFromAppLinksPkg);
          } else {
            debugPrint("[AuthWrapper] _initAppLinks: app_links URI same as ModalRoute, likely processed.");
          }
        } else {
          debugPrint("[AuthWrapper] _initAppLinks: No initial deep link from app_links package.");
        }
      } catch (e) {
        debugPrint("[AuthWrapper] _initAppLinks: Error getting initial deep link: $e");
      }
    } else {
      debugPrint("[AuthWrapper] _initAppLinks: Skipping app_links.getInitialAppLink().");
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      if (mounted) {
        debugPrint("[AuthWrapper] Subsequent deep link from stream: $uri. Handling...");
        _handleDeepLink(uri);
      }
    }, onError: (err) {
      debugPrint("[AuthWrapper] Error listening to app_links stream: $err");
    });
  }

  // Updated _handleDeepLink to pass 'recoveryCode' as argument
  void _handleDeepLink(Uri uri) {
    debugPrint("----------------------------------------------------");
    debugPrint("[AuthWrapper] _handleDeepLink: START PROCESSING URI: $uri");
    debugPrint("[AuthWrapper] _handleDeepLink: Scheme: '${uri.scheme}', Host: '${uri.host}', Path: '${uri.path}'");
    debugPrint("[AuthWrapper] _handleDeepLink: QueryParams: ${uri.queryParameters}");
    debugPrint("[AuthWrapper] _handleDeepLink: Fragment: '${uri.fragment}'");
    debugPrint("----------------------------------------------------");

    final NavigatorState? nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint("[AuthWrapper] _handleDeepLink: Navigator state NULL. CANNOT NAVIGATE.");
      return;
    }

    final fragment = uri.fragment;
    final queryParams = uri.queryParameters;

    // --- NEW: PRIORITIZE HOST AND PATH FOR PASSWORD RESET WITH ?code= ---
    // This condition is now at the top to catch `myapp://password-reset?code=...`
    if (uri.scheme == 'myapp' && uri.host == 'password-reset' && queryParams.containsKey('code') && fragment.isEmpty) {
      final String? recoveryCode = queryParams['code'];
      debugPrint("[AuthWrapper] _handleDeepLink: Detected 'myapp://password-reset?code=$recoveryCode'. Navigating to ResetPasswordScreen with code.");
      WidgetsBinding.instance.addPostFrameCallback((_) { // Ensure navigation happens after current build cycle
        if (mounted && navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushNamedAndRemoveUntil(
            ResetPasswordScreen.routeName,
                (route) => false,
            arguments: {'recoveryCode': recoveryCode}, // Pass the code
          );
          debugPrint("[AuthWrapper] _handleDeepLink: Navigation to ResetPasswordScreen with recoveryCode PUSHED.");
        } else {
          debugPrint("[AuthWrapper] _handleDeepLink (password-reset?code=): CANNOT NAVIGATE. Mounted: $mounted");
        }
      });
      // Even though we navigated, the Supabase client might be processing this code.
      // Call _evaluateSessionAndRole after a delay to reflect any session changes.
      Future.delayed(const Duration(milliseconds: 300), (){
        if(mounted) {
          debugPrint("[AuthWrapper] _handleDeepLink (password-reset?code=): Triggering _evaluateSessionAndRole after navigation attempt.");
          _evaluateSessionAndRole();
        }
      });
      return; // Handled this specific password reset case
    }
    // --- END OF NEW LOGIC for myapp://password-reset?code=... ---


    // Existing logic for fragment-based auth (invites, standard recovery if it ever sends fragment)
    if (fragment.isNotEmpty) {
      final params = Uri.splitQueryString(fragment);
      final String? type = params['type'];
      debugPrint("[AuthWrapper] _handleDeepLink: Parsed fragment type: '$type'");

      if (type == 'recovery') {
        debugPrint("[AuthWrapper] _handleDeepLink: TYPE IS 'recovery' from fragment. Scheduling navigation to ResetPasswordScreen (standard flow).");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted && navigatorKey.currentState != null) {
              final currentUser = supabase.auth.currentUser;
              debugPrint("[AuthWrapper] _handleDeepLink (fragment recovery): Navigating. Supabase currentUser: ${currentUser?.id}");
              if (currentUser != null) {
                navigatorKey.currentState!.pushNamedAndRemoveUntil(
                    ResetPasswordScreen.routeName, (route) => false);
                debugPrint("[AuthWrapper] _handleDeepLink (fragment recovery): Navigation PUSHED.");
              } else {
                debugPrint("[AuthWrapper] _handleDeepLink (fragment recovery): Supabase currentUser is NULL. SKIPPING navigation.");
                if(mounted) _evaluateSessionAndRole();
              }
            }
          });
        });
        return;
      } else if (type == 'invite') {
        debugPrint("[AuthWrapper] _handleDeepLink: TYPE IS 'invite' from fragment. Scheduling navigation to InviteAcceptScreen.");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && navigatorKey.currentState != null) {
            String? inviteTokenForScreen = params['invite_token'];
            navigatorKey.currentState!.pushNamedAndRemoveUntil(
                InviteAcceptScreen.routeName, (route) => false,
                arguments: {'token': inviteTokenForScreen});
            debugPrint("[AuthWrapper] _handleDeepLink: Navigation to InviteAcceptScreen PUSHED.");
          }
        });
        return;
      } else if (fragment.contains('access_token') && !fragment.contains('error_description')) {
        debugPrint("[AuthWrapper] _handleDeepLink: Generic 'access_token' in fragment. Supabase client handles session.");
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) _evaluateSessionAndRole();
        });
        return;
      } else if (fragment.contains('error_description')) {
        final String? errorDescription = params['error_description'];
        debugPrint("[AuthWrapper] _handleDeepLink: Auth error in fragment: $errorDescription");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Auth error: ${errorDescription ?? 'Unknown'}"), backgroundColor: Colors.red),
          );
        }
        if(mounted) _evaluateSessionAndRole();
        return;
      }
    }

    // Fallback for other ?code= query parameters that are NOT 'myapp://password-reset?code=...'
    // This ensures general OAuth codes (if you use them elsewhere) are still processed.
    if (queryParams.containsKey('code') && !uri.hasFragment) {
      // This condition is now implicitly met if the specific `myapp://password-reset?code=` was not caught above.
      debugPrint("[AuthWrapper] _handleDeepLink: URI has generic '?code=' (no fragment, and not the specific password-reset?code= case). Supabase client handles. Evaluating session.");
      Future.delayed(const Duration(milliseconds: 250), () {
        if(mounted) _evaluateSessionAndRole();
      });
      return;
    }

    // Default action if no specific auth pattern matched
    debugPrint("[AuthWrapper] _handleDeepLink: No specific auth action taken by link, or not an auth link. Evaluating current session state. URI: $uri");
    if (mounted) _evaluateSessionAndRole();
  }

  Future<void> _evaluateSessionAndRole() async {
    if (!mounted) {
      debugPrint("[AuthWrapper] _evaluateSessionAndRole: Not mounted.");
      return;
    }
    debugPrint("[AuthWrapper] _evaluateSessionAndRole: Evaluating. Current AuthStatus: $_authStatus");

    final currentUser = SessionService.getCurrentUser();
    debugPrint("[AuthWrapper] _evaluateSessionAndRole: User from SessionService: ${currentUser?.id}, Email: ${currentUser?.email}");

    AuthStatus newAuthStatus;
    String? newCurrentRole;

    if (currentUser != null) {
      final role = await SessionService.getUserRole();
      final userMetadata = SessionService.getCachedUserMetadata() ?? {};
      final bool requiresPasswordChange = userMetadata['requires_password_change'] == true ||
          userMetadata['temp_password_active'] == true;
      debugPrint("[AuthWrapper] _evaluateSessionAndRole: User authenticated. Role: '$role', RequiresPassChange: $requiresPasswordChange");

      if (requiresPasswordChange) {
        newAuthStatus = AuthStatus.authenticatedWithRole;
        newCurrentRole = role ?? 'user';
      } else if (role == null || role.isEmpty) {
        newAuthStatus = AuthStatus.authenticatedNoRole;
        newCurrentRole = null;
      } else {
        newAuthStatus = AuthStatus.authenticatedWithRole;
        newCurrentRole = role;
      }
    } else {
      debugPrint("[AuthWrapper] _evaluateSessionAndRole: No user session found.");
      newAuthStatus = AuthStatus.unauthenticated;
      newCurrentRole = null;
    }

    if (_authStatus != newAuthStatus || _currentRole != newCurrentRole) {
      debugPrint("[AuthWrapper] _evaluateSessionAndRole: State changing to $newAuthStatus, Role: $newCurrentRole");
      setStateIfMounted(() {
        _authStatus = newAuthStatus;
        _currentRole = newCurrentRole;
      });
    } else {
      debugPrint("[AuthWrapper] _evaluateSessionAndRole: State ($newAuthStatus, $newCurrentRole) is already current.");
    }
    debugPrint("[AuthWrapper] _evaluateSessionAndRole: Finished. Final AuthStatus: $_authStatus");
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  @override
  void dispose() {
    debugPrint("[AuthWrapper] dispose called.");
    _linkSubscription?.cancel();
    SessionService.disposeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget screenToShow;
    debugPrint("[AuthWrapper] Building UI with Auth Status: $_authStatus, Role: $_currentRole");

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
                      "Your account is missing role information or is not fully verified. Contact support.",
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        onPressed: () async {
                          await SessionService.logout();
                        },
                        child: const Text("Logout")),
                  ]))),
        );
        break;
      case AuthStatus.authenticatedWithRole:
        final userMetadata = SessionService.getCachedUserMetadata() ?? {};
        final bool requiresPasswordChange = userMetadata['requires_password_change'] == true ||
            userMetadata['temp_password_active'] == true;

        if (requiresPasswordChange) {
          debugPrint("[AuthWrapper] User requires password change. Showing ForceChangePasswordScreen.");
          screenToShow = const ForceChangePasswordScreen(comesFromTempPassword: true);
        } else {
          debugPrint("[AuthWrapper] User authenticated ('$_currentRole'). Showing role-based screen.");
          screenToShow = SessionService.getInitialRouteWidgetForRole(_currentRole);
        }
        break;
    }
    return screenToShow;
  }
}

class UndefinedView extends StatelessWidget {
  final String? name;
  const UndefinedView({super.key, this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error - Route Not Found')),
      body: Center(child: Text('Route for "$name" is not defined.')),
    );
  }
}
