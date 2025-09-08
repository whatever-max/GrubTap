// lib/main.dart
import 'dart:async';
import 'package:flutter/foundation.dart'; // For mapEquals
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For PlatformException
import 'package:provider/provider.dart' as app_provider;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

import 'constants.dart'; // Assuming supabaseUrl and supabaseAnonKey are here

// Screen Imports
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/force_change_password_screen.dart';
import 'screens/auth/invite_accept_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/company/company_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/company/manage_foods_screen.dart';
import 'screens/company/company_orders_screen.dart';
import 'screens/history/order_history_screen.dart';
import 'screens/edit_order/edit_order_screen.dart'; // <<< ADD THIS IMPORT
import 'screens/admin/admin_invite_user_screen.dart';
import 'screens/admin/management/admin_manage_users_screen.dart';
import 'screens/admin/management/admin_manage_companies_screen.dart';
import 'screens/admin/admin_permissions_screen.dart';
import 'screens/admin/management/admin_manage_foods_screen.dart';
import 'screens/admin/management/admin_manage_orders_screen.dart';
import 'screens/admin/admin_analytics_screen.dart';

// Service and Provider Imports
import 'providers/theme_provider.dart';
import 'services/session_service.dart'; // Assuming this handles role and session logic

// Enum for Auth Status (as you had)
enum AuthStatus { unknown, authenticatedNoRole, authenticatedWithRole, unauthenticated }

// Global Navigator Key (as you had)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
    ),
  );
  debugPrint("Supabase initialized successfully.");

  runApp(
    app_provider.MultiProvider(
      providers: [
        app_provider.ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // Add other global providers if needed
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
    const MaterialColor primarySeedColor = Colors.deepPurple; // Example, use your actual theme

    // --- YOUR THEME DATA (condensed for brevity, use your actual theme definitions) ---
    final baseLightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: primarySeedColor,
      // ... your full light theme properties
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
    );

    final baseDarkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: primarySeedColor,
      // ... your full dark theme properties
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
    );
    // --- END OF THEME DATA ---

    return MaterialApp(
      title: 'GrubTap',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: baseLightTheme,
      darkTheme: baseDarkTheme,
      initialRoute: AuthWrapper.routeName, // Start with AuthWrapper
      onGenerateInitialRoutes: (initialRouteName) {
        // This handles when the app is launched by an external link.
        debugPrint("[onGenerateInitialRoutes] Initial route name from OS: $initialRouteName");
        // We always go to AuthWrapper first, and AuthWrapper will handle the deep link.
        return [
          MaterialPageRoute(
            builder: (_) => const AuthWrapper(), // Key might be needed if state depends on initialRoute
            settings: RouteSettings(name: initialRouteName), // Pass the original link name
          ),
        ];
      },
      onGenerateRoute: (settings) {
        debugPrint("[onGenerateRoute] Received route settings: Name: ${settings.name}, Args: ${settings.arguments}");
        Uri uri;
        try {
          uri = Uri.parse(settings.name ?? AuthWrapper.routeName); // Default to AuthWrapper if name is null
        } catch (e) {
          debugPrint("[onGenerateRoute] Error parsing settings.name ('${settings.name}') as URI: $e. Using path directly.");
          uri = Uri(path: settings.name ?? AuthWrapper.routeName);
        }
        debugPrint("[onGenerateRoute] Parsed URI. Scheme: ${uri.scheme}, Host: ${uri.host}, Path: '${uri.path}', Query: ${uri.queryParameters}, Fragment: '${uri.fragment}'");

        // If it's a deep link with our custom scheme, or a Supabase auth fragment,
        // or has a code query param, let AuthWrapper handle it again with a UniqueKey
        // to ensure it re-evaluates the link, UNLESS it's the exact same route and args already.
        if (uri.scheme == 'myapp' ||
            (uri.fragment.isNotEmpty && (uri.fragment.contains("access_token") || uri.fragment.contains('code='))) || // Some Supabase links use code in fragment
            uri.queryParameters.containsKey('code')) {

          final currentRoute = ModalRoute.of(navigatorKey.currentContext!)?.settings;
          bool isSameRouteAndArgs = currentRoute?.name == settings.name &&
              mapEquals(currentRoute?.arguments as Map?, settings.arguments as Map?);
          // Use mapEquals for argument comparison if they are maps.
          // Adjust if arguments are not always maps.

          if (!isSameRouteAndArgs) {
            debugPrint("[onGenerateRoute] Auth-related link detected: ${settings.name}. Routing to AuthWrapper with UniqueKey.");
            return MaterialPageRoute(
                builder: (_) => AuthWrapper(key: UniqueKey()), // Force AuthWrapper to rebuild and re-check
                settings: settings // Pass original settings
            );
          } else {
            debugPrint("[onGenerateRoute] Auth-related link ${settings.name} is already the current route for AuthWrapper with same args. Allowing standard switch.");
          }
        }

        // Determine the actual path for the switch statement
        String routePath = uri.path;
        if (routePath.isEmpty && (settings.name == null || settings.name == "/" || settings.name == "")) {
          routePath = AuthWrapper.routeName; // Default to AuthWrapper if path is empty
        } else if (routePath.isNotEmpty && !routePath.startsWith('/')) {
          routePath = '/$routePath'; // Ensure path starts with '/'
        }
        debugPrint("[onGenerateRoute] Evaluating named route path for switch: '$routePath'");

        switch (routePath) {
          case AuthWrapper.routeName:
            return MaterialPageRoute(builder: (_) => const AuthWrapper(), settings: settings);
          case LoginScreen.routeName:
            return MaterialPageRoute(builder: (_) => const LoginScreen(), settings: settings);
          case SignupScreen.routeName:
            return MaterialPageRoute(builder: (_) => const SignupScreen(), settings: settings);
          case ForgotPasswordScreen.routeName:
            return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen(), settings: settings);
          case ResetPasswordScreen.routeName:
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(builder: (_) => ResetPasswordScreen(
              recoveryCodeFromArgs: args?['recoveryCode'],
              emailFromArgs: args?['email'],
            ), settings: settings);
          case InviteAcceptScreen.routeName:
          // final args = settings.arguments as Map<String, dynamic>?; // If needed
            return MaterialPageRoute(builder: (_) => const InviteAcceptScreen(), settings: settings);
          case ForceChangePasswordScreen.routeName:
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(builder: (_) => ForceChangePasswordScreen(
                comesFromTempPassword: args?['comesFromTempPassword'] ?? false
            ), settings: settings);
          case HomeScreen.routeName:
            return MaterialPageRoute(builder: (_) => const HomeScreen(), settings: settings);
          case CompanyDashboardScreen.routeName:
            return MaterialPageRoute(builder: (_) => const CompanyDashboardScreen(), settings: settings);
          case AdminDashboardScreen.routeName:
            return MaterialPageRoute(builder: (_) => const AdminDashboardScreen(), settings: settings);
          case ManageFoodsScreen.routeName:
            return MaterialPageRoute(builder: (_) => const ManageFoodsScreen(), settings: settings);
          case CompanyOrdersScreen.routeName:
            return MaterialPageRoute(builder: (_) => const CompanyOrdersScreen(), settings: settings);
          case OrderHistoryScreen.routeName:
            return MaterialPageRoute(builder: (_) => const OrderHistoryScreen(), settings: settings);

        // Route for EditOrderScreen
          case EditOrderScreen.routeName:
            final args = settings.arguments;
            if (args is OrderHistoryDisplayItem) { // Check if argument is the expected type
              return MaterialPageRoute(
                builder: (_) => EditOrderScreen(orderToEdit: args),
                settings: settings,
              );
            }
            // Fallback if args are not correct for EditOrderScreen
            debugPrint("[onGenerateRoute] Error: EditOrderScreen requires OrderHistoryDisplayItem argument. Received: $args");
            return MaterialPageRoute(builder: (_) => UndefinedView(name: "Edit Order - Invalid Arguments"));

          case AdminInviteUserScreen.routeName:
            return MaterialPageRoute(builder: (_) => const AdminInviteUserScreen(), settings: settings);
          case AdminManageUsersScreen.routeName:
            return MaterialPageRoute(builder: (_) => const AdminManageUsersScreen(), settings: settings);
          case AdminManageCompaniesScreen.routeName:
            return MaterialPageRoute(builder: (_) => const AdminManageCompaniesScreen(), settings: settings);
          case AdminPermissionsScreen.routeName:
            return MaterialPageRoute(builder: (_) => const AdminPermissionsScreen(), settings: settings);
          case AdminManageFoodsScreen.routeName:
            return MaterialPageRoute(builder: (_) => const AdminManageFoodsScreen(), settings: settings);
          case AdminManageOrdersScreen.routeName:
            return MaterialPageRoute(builder: (_) => const AdminManageOrdersScreen(), settings: settings);
          case AdminAnalyticsScreen.routeName:
            return MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen(), settings: settings);

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
  static const String routeName = '/'; // Your AuthWrapper is the initial route
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  AuthStatus _authStatus = AuthStatus.unknown;
  String? _currentRole;
  final supabase = Supabase.instance.client;
  late AppLinks _appLinks; // For handling deep links when app is already running
  StreamSubscription<Uri>? _linkSubscription;
  String? _currentlyProcessingLink; // To avoid processing the same link multiple times rapidly

  @override
  void initState() {
    super.initState();
    debugPrint("[AuthWrapper] initState. Key: ${widget.key}. Instance: $hashCode");

    // Initialize session listener from your SessionService
    SessionService.initializeSessionListener(
      onSessionRestored: (User? user) {
        debugPrint("[AuthWrapper][$hashCode] SessionService.onSessionRestored. User: ${user?.id}");
        _evaluateSessionAndRole();
      },
      onSessionExpiredOrSignedOut: () {
        debugPrint("[AuthWrapper][$hashCode] SessionService.onSessionExpiredOrSignedOut.");
        if (mounted) {
          setStateIfMounted(() {
            _authStatus = AuthStatus.unauthenticated;
            _currentRole = null;
          });
        }
      },
    );

    // Using addPostFrameCallback to ensure context is available for ModalRoute
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint("[AuthWrapper][$hashCode] initState: addPostFrameCallback.");

      final routeSettings = ModalRoute.of(context)?.settings;
      final String? initialRouteNameFromFlutter = routeSettings?.name; // This might be the deep link URI
      final dynamic initialRouteArgsFromFlutter = routeSettings?.arguments;
      debugPrint("[AuthWrapper][$hashCode] Initial route from ModalRoute: Name: '$initialRouteNameFromFlutter', Args: $initialRouteArgsFromFlutter");

      bool initialLinkAttemptedByModalRoute = false;
      if (initialRouteNameFromFlutter != null && initialRouteNameFromFlutter.isNotEmpty) {
        try {
          Uri initialUri = Uri.parse(initialRouteNameFromFlutter);
          // Check if it's a deep link that AuthWrapper should process
          if (_isAuthDeepLink(initialUri)) {
            debugPrint("[AuthWrapper][$hashCode] Initial URI from ModalRoute ('$initialUri') is an auth deep link. Processing...");
            _processDeepLinkIfNewUrl(initialUri, initialRouteArgsFromFlutter);
            initialLinkAttemptedByModalRoute = true;
          } else {
            debugPrint("[AuthWrapper][$hashCode] Initial URI ('$initialUri') from ModalRoute not considered auth deep link for direct handling by _processDeepLinkIfNewUrl.");
          }
        } catch (e) {
          // Not a URI, could be a named route like '/reset-password' if onGenerateRoute passed args
          if (initialRouteNameFromFlutter == ResetPasswordScreen.routeName && initialRouteArgsFromFlutter is Map) {
            debugPrint("[AuthWrapper][$hashCode] Initial route is named ResetPasswordScreen with args. Trusting onGenerateRoute and ResetPasswordScreen.initState to handle.");
            initialLinkAttemptedByModalRoute = true;
          } else if (initialRouteNameFromFlutter == EditOrderScreen.routeName && initialRouteArgsFromFlutter is OrderHistoryDisplayItem) {
            debugPrint("[AuthWrapper][$hashCode] Initial route is named EditOrderScreen with args. Trusting onGenerateRoute and EditOrderScreen.initState to handle.");
            initialLinkAttemptedByModalRoute = true;
          } else {
            debugPrint("[AuthWrapper][$hashCode] Error parsing initial URI ('$initialRouteNameFromFlutter') from ModalRoute or not a direct auth link: $e.");
          }
        }
      }

      // Initialize app_links to listen for further deep links
      _initAppLinks(modalRouteAttemptedByModalRoute: initialLinkAttemptedByModalRoute);

      // If no deep link was processed by ModalRoute, and auth status is still unknown, check current Supabase session.
      // This covers normal app starts without a deep link.
      if (!initialLinkAttemptedByModalRoute && _authStatus == AuthStatus.unknown) {
        debugPrint("[AuthWrapper][$hashCode] No initial deep link processed by ModalRoute, checking Supabase session.");
        _checkSupabaseSession();
      } else if (initialLinkAttemptedByModalRoute && _authStatus == AuthStatus.unknown) {
        // If a link was attempted by ModalRoute, give a slight delay for Supabase client to potentially process it
        // (e.g., if it was a fragment link like #access_token=...) before falling back to session check.
        Future.delayed(const Duration(milliseconds: 300), () { // Short delay
          if (mounted && _authStatus == AuthStatus.unknown) { // Check again after delay
            debugPrint("[AuthWrapper][$hashCode] After delay for initial link processing from ModalRoute, checking Supabase session.");
            _checkSupabaseSession();
          }
        });
      }
    });
  }

  // Helper to determine if a URI is one that AuthWrapper should actively parse for navigation
  bool _isAuthDeepLink(Uri uri) {
    bool isMyAppScheme = uri.scheme == 'myapp';
    bool hasCodeQuery = uri.queryParameters.containsKey('code'); // Common in our password reset
    // Supabase client handles fragments like #access_token=... directly, so we might not need to intercept all of them here,
    // but password-reset with code is one we explicitly handle.
    return isMyAppScheme && (uri.host == 'password-reset' || uri.host == 'invite') && hasCodeQuery;
  }

  // Wrapper to prevent processing the same link multiple times in quick succession
  void _processDeepLinkIfNewUrl(Uri uri, [dynamic routeArgs]) {
    String comparableUri = uri.toString(); // Use the full URI string for comparison
    if (_currentlyProcessingLink == comparableUri) {
      debugPrint("[AuthWrapper][$hashCode] _processDeepLinkIfNewUrl: Link $uri already processed or being processed. Skipping.");
      return;
    }
    _currentlyProcessingLink = comparableUri;
    debugPrint("[AuthWrapper][$hashCode] _processDeepLinkIfNewUrl: New link to process: $uri with routeArgs: $routeArgs");

    _handleDeepLink(uri, routeArgs); // Pass the arguments from ModalRoute if available

    // Clear the currently processing link after a timeout to allow reprocessing if needed later (e.g., user clicks same link again)
    Future.delayed(const Duration(seconds: 3), () { // 3 second cooldown
      if (_currentlyProcessingLink == comparableUri) {
        _currentlyProcessingLink = null;
        debugPrint("[AuthWrapper][$hashCode] _processDeepLinkIfNewUrl: Cleared _currentlyProcessingLink for $uri");
      }
    });
  }

  // Initial check of Supabase session if no deep link handled it
  void _checkSupabaseSession() {
    debugPrint("[AuthWrapper][$hashCode] _checkSupabaseSession. Current session: ${supabase.auth.currentSession != null}, AuthStatus: $_authStatus");
    if (_authStatus == AuthStatus.unknown) { // Only if status hasn't been determined by a deep link
      if (supabase.auth.currentSession != null) {
        _evaluateSessionAndRole();
      } else {
        if (mounted) setStateIfMounted(() => _authStatus = AuthStatus.unauthenticated);
      }
    }
  }


  Future<void> _initAppLinks({bool modalRouteAttemptedByModalRoute = false}) async {
    _appLinks = AppLinks();
    debugPrint("[AuthWrapper][$hashCode] _initAppLinks called. modalRouteAttempted: $modalRouteAttemptedByModalRoute");

    // Get the initial link if the app was launched by a deep link
    // and if ModalRoute didn't already try to process a link.
    if (!modalRouteAttemptedByModalRoute) {
      try {
        final initialUriFromAppLinksPkg = await _appLinks.getInitialAppLink();
        if (initialUriFromAppLinksPkg != null && mounted) {
          debugPrint("[AuthWrapper][$hashCode] _initAppLinks: Initial deep link from app_links package: $initialUriFromAppLinksPkg. Handling...");
          _processDeepLinkIfNewUrl(initialUriFromAppLinksPkg); // No explicit routeArgs from here
        } else {
          debugPrint("[AuthWrapper][$hashCode] _initAppLinks: No initial deep link from app_links package.");
        }
      } on PlatformException catch (e) {
        debugPrint("[AuthWrapper][$hashCode] _initAppLinks: Failed to get initial deep link (PlatformException): ${e.message}");
      } catch (e) {
        debugPrint("[AuthWrapper][$hashCode] _initAppLinks: Error getting initial deep link: $e");
      }
    } else {
      debugPrint("[AuthWrapper][$hashCode] _initAppLinks: Skipping app_links.getInitialAppLink() as ModalRoute might have handled initial link.");
    }

    // Listen to further deep links when the app is already running
    _linkSubscription?.cancel(); // Cancel any existing subscription
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      if (mounted) {
        debugPrint("[AuthWrapper][$hashCode] Subsequent deep link from app_links stream: $uri. Handling...");
        _processDeepLinkIfNewUrl(uri); // No explicit routeArgs from here
      }
    }, onError: (err) {
      debugPrint("[AuthWrapper][$hashCode] Error listening to app_links stream: $err");
      if (err is PlatformException) {
        debugPrint("[AuthWrapper][$hashCode] PlatformException from app_links stream: ${err.message}");
      }
    });
  }

  void _handleDeepLink(Uri uri, [dynamic navArgumentsFromModalRoute]) {
    // This method decides what to do based on the URI
    // It might navigate to ResetPasswordScreen, InviteAcceptScreen, etc.
    // It should also handle cases where Supabase client processes the link (e.g. fragment links)
    debugPrint("----------------------------------------------------");
    debugPrint("[AuthWrapper][$hashCode] _handleDeepLink: START PROCESSING URI: $uri");
    debugPrint("[AuthWrapper][$hashCode] _handleDeepLink: Nav Args from ModalRoute: $navArgumentsFromModalRoute");
    debugPrint("----------------------------------------------------");

    final NavigatorState? nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint("[AuthWrapper][$hashCode] _handleDeepLink: Navigator state NULL. CANNOT NAVIGATE.");
      return;
    }

    final queryParams = uri.queryParameters;
    bool navigatedByAuthWrapper = false; // Flag to see if this function initiated navigation

    // --- Password Reset: myapp://password-reset?code=RECOVERY_CODE&email=USER_EMAIL ---
    if (uri.scheme == 'myapp' && uri.host == 'password-reset' && queryParams.containsKey('code')) {
      final String? recoveryCode = queryParams['code'];
      // Email might be in the query from ForgotPasswordScreen or we might need another way if not
      final String? emailForReset = queryParams['email'];

      if (recoveryCode != null && emailForReset != null) {
        final argumentsForScreen = {
          'recoveryCode': recoveryCode,
          'email': emailForReset,
        };
        debugPrint("[AuthWrapper][$hashCode] _handleDeepLink: Detected 'myapp://password-reset?code=...&email=...'. Args: $argumentsForScreen. Navigating to ResetPasswordScreen.");

        // Ensure navigation happens after the current build cycle
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushNamedAndRemoveUntil(
              ResetPasswordScreen.routeName,
                  (route) => false, // Remove all previous routes
              arguments: argumentsForScreen,
            );
            navigatedByAuthWrapper = true;
          }
        });
      } else {
        debugPrint("[AuthWrapper][$hashCode] _handleDeepLink: 'myapp://password-reset' with code, but missing email in query. Code: $recoveryCode, Email from URL: $emailForReset. Cannot proceed with Edge Function automatically.");
        // Potentially navigate to ResetPasswordScreen without email, and let it prompt or show error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushNamedAndRemoveUntil(ResetPasswordScreen.routeName, (route) => false, arguments: {'recoveryCode': recoveryCode});
            navigatedByAuthWrapper = true;
          }
        });
      }
    }
    // --- Invite Link: myapp://invite... (Supabase often uses fragments for this) ---
    else if (uri.scheme == 'myapp' && uri.host == 'invite') {
      debugPrint("[AuthWrapper][$hashCode] _handleDeepLink: Detected 'myapp://invite'. Navigating to InviteAcceptScreen. Fragment: ${uri.fragment}");
      // Supabase client typically handles the fragment with the invite token.
      // We just need to navigate to a screen where the user can complete their profile/set password.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushNamedAndRemoveUntil(
            InviteAcceptScreen.routeName, // Or ResetPasswordScreen if invite implies setting/updating a password
                (route) => false,
            // arguments: { 'inviteToken': tokenFromFragmentIfAny } // If InviteAcceptScreen needs it
          );
          navigatedByAuthWrapper = true;
        }
      });
    }
    // --- Supabase Client Handled Links (e.g., #access_token=..., type=recovery in fragment) ---
    // If Supabase client handles the fragment for session, our session listener will pick it up.
    // If it's a type=recovery in fragment, we might want to navigate to ResetPasswordScreen.
    else if (uri.fragment.isNotEmpty) {
      debugPrint("[AuthWrapper][$hashCode] _handleDeepLink: Detected fragment link: ${uri.fragment}.");
      final paramsInFragment = Uri.splitQueryString(uri.fragment); // Basic parsing
      if (paramsInFragment['type'] == 'recovery' && paramsInFragment.containsKey('access_token')) {
        debugPrint("[AuthWrapper][$hashCode] _handleDeepLink: Fragment is type=recovery. Supabase client should set session. Navigating to ResetPasswordScreen (no args needed).");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushNamedAndRemoveUntil(ResetPasswordScreen.routeName, (route) => false);
            navigatedByAuthWrapper = true;
          }
        });
      } else if (paramsInFragment.containsKey('access_token')) {
        debugPrint("[AuthWrapper][$hashCode] _handleDeepLink: Fragment contains access_token. Supabase client should handle session. Session listener will evaluate.");
        // No immediate navigation needed here; session listener will trigger _evaluateSessionAndRole
      }
    }
    else {
      debugPrint("[AuthWrapper][$hashCode] _handleDeepLink: URI did not match specific auth patterns for direct navigation by AuthWrapper. URI: $uri");
    }

    // After attempting to handle any deep link, or if no specific deep link action was taken,
    // give Supabase a moment (if fragment was involved) and then re-evaluate session.
    // This is especially important if Supabase client processes a fragment link and sets a session.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        debugPrint("[AuthWrapper][$hashCode] _handleDeepLink: Post-processing delay. Triggering _evaluateSessionAndRole. Navigated by AuthWrapper: $navigatedByAuthWrapper");
        _evaluateSessionAndRole();
      }
    });
  }

  Future<void> _evaluateSessionAndRole() async {
    if (!mounted) {
      debugPrint("[AuthWrapper][$hashCode] _evaluateSessionAndRole: Not mounted. Skipping.");
      return;
    }
    debugPrint("[AuthWrapper][$hashCode] _evaluateSessionAndRole: Evaluating. Current AuthStatus: $_authStatus");

    final currentUser = SessionService.getCurrentUser(); // From your service
    debugPrint("[AuthWrapper][$hashCode] _evaluateSessionAndRole: User from SessionService: ${currentUser?.id}, Email: ${currentUser?.email}");

    AuthStatus newAuthStatus;
    String? newCurrentRole;

    if (currentUser != null) {
      newCurrentRole = await SessionService.getUserRole(); // From your service
      final userMetadata = SessionService.getCachedUserMetadata() ?? currentUser.userMetadata ?? {};
      final bool requiresPasswordChange = userMetadata['requires_password_change'] == true || userMetadata['temp_password_active'] == true;
      debugPrint("[AuthWrapper][$hashCode] _evaluateSessionAndRole: User authenticated. Role: '$newCurrentRole', RequiresPassChange: $requiresPasswordChange, Metadata: $userMetadata");

      if (requiresPasswordChange) {
        // Even if role is null, if password change is required, they are "authenticated" but need action.
        newAuthStatus = AuthStatus.authenticatedWithRole;
        newCurrentRole = newCurrentRole ?? 'user'; // Default if role is somehow null but pass change needed
      } else if (newCurrentRole == null || newCurrentRole.isEmpty) {
        newAuthStatus = AuthStatus.authenticatedNoRole;
      } else {
        newAuthStatus = AuthStatus.authenticatedWithRole;
      }
    } else {
      debugPrint("[AuthWrapper][$hashCode] _evaluateSessionAndRole: No user session found.");
      newAuthStatus = AuthStatus.unauthenticated;
      newCurrentRole = null;
    }

    if (!mounted) return;

    // Only update state if there's an actual change to prevent unnecessary rebuilds
    if (_authStatus != newAuthStatus || _currentRole != newCurrentRole) {
      debugPrint("[AuthWrapper][$hashCode] _evaluateSessionAndRole: State changing from ($_authStatus, $_currentRole) to ($newAuthStatus, $newCurrentRole)");
      setStateIfMounted(() {
        _authStatus = newAuthStatus;
        _currentRole = newCurrentRole;
      });
    } else {
      debugPrint("[AuthWrapper][$hashCode] _evaluateSessionAndRole: State ($newAuthStatus, $newCurrentRole) is already current. No UI change required from this evaluation.");
    }
    debugPrint("[AuthWrapper][$hashCode] _evaluateSessionAndRole: Finished. Final AuthStatus: $_authStatus, Role: $_currentRole");
  }

  // Helper to ensure setState is only called if widget is still mounted
  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  @override
  void dispose() {
    debugPrint("[AuthWrapper][$hashCode] dispose called. Key: ${widget.key}. Instance: $hashCode");
    _linkSubscription?.cancel();
    _linkSubscription = null;
    // Consider if SessionService listener needs explicit disposal if not handled by SessionService itself
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("[AuthWrapper][$hashCode] Building UI with Auth Status: $_authStatus, Role: $_currentRole. Key: ${widget.key}");
    Widget screenToShow;

    switch (_authStatus) {
      case AuthStatus.unknown:
        screenToShow = const Scaffold(body: Center(child: CircularProgressIndicator(key: ValueKey("AuthWrapperLoading"))));
        break;
      case AuthStatus.unauthenticated:
        screenToShow = const LoginScreen();
        break;
      case AuthStatus.authenticatedNoRole:
      // This case means user is logged in but role is missing or not determined
        screenToShow = Scaffold(
          appBar: AppBar(title: const Text("Account Issue")),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 50),
                    const SizedBox(height: 16),
                    const Text(
                      "Your account is missing role information or is not fully verified. Please contact support or try logging in again.",
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        onPressed: () async {
                          await SessionService.logout(); // Use your logout method
                        },
                        child: const Text("Logout")),
                  ]))),
        );
        break;
      case AuthStatus.authenticatedWithRole:
        final userMetadata = SessionService.getCachedUserMetadata() ?? Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
        final bool requiresPasswordChange = userMetadata['requires_password_change'] == true || userMetadata['temp_password_active'] == true;

        if (requiresPasswordChange) {
          debugPrint("[AuthWrapper][$hashCode] User requires password change. Showing ForceChangePasswordScreen.");
          screenToShow = const ForceChangePasswordScreen(comesFromTempPassword: true); // Pass appropriate flag
        } else {
          // User is authenticated, has a role, and doesn't need immediate password change
          debugPrint("[AuthWrapper][$hashCode] User authenticated ('$_currentRole'). Showing role-based screen: ${SessionService.getInitialRouteForRole(_currentRole)}");
          screenToShow = SessionService.getInitialRouteWidgetForRole(_currentRole); // From your service
        }
        break;
    }
    return screenToShow;
  }
}

// Fallback widget for undefined routes
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
