// lib/services/session_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // For Widget type
import 'package:grubtap/screens/admin/admin_dashboard_screen.dart';
import 'package:grubtap/screens/company/company_dashboard_screen.dart';
import 'package:grubtap/screens/home/home_screen.dart';
import 'package:grubtap/screens/auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  // ... other static members and existing methods ...
  static User? _currentUser;
  static String? _currentUserRole;
  static Map<String, dynamic>? _currentUserMetadata;
  static bool _isListenerInitialized = false;
  static StreamSubscription<AuthState>? _authSubscription;
  static void Function(User? user)? _onSessionRestoredCallback;
  static void Function()? _onSessionExpiredOrSignedOutCallback;


  // --- Existing methods like initializeSessionListener, _loadUserRoleAndMetadata, etc. ---
  // Ensure all your other SessionService methods are here and correct from our previous discussions.
  // For brevity, I'm omitting them but they MUST be present.
  // Example:
  static void initializeSessionListener({
    required void Function(User? user) onSessionRestored,
    required void Function() onSessionExpiredOrSignedOut,
  }) {
    if (_isListenerInitialized) {
      debugPrint('[SessionService] Listener already initialized. Updating callbacks.');
      _onSessionRestoredCallback = onSessionRestored;
      _onSessionExpiredOrSignedOutCallback = onSessionExpiredOrSignedOut;
      _notifyCurrentState();
      return;
    }

    _authSubscription?.cancel();
    _onSessionRestoredCallback = onSessionRestored;
    _onSessionExpiredOrSignedOutCallback = onSessionExpiredOrSignedOut;

    _currentUser = _supabase.auth.currentUser;
    _currentUserMetadata = _currentUser?.userMetadata;

    if (_currentUser != null) {
      debugPrint('[SessionService] Initial session found for user: ${_currentUser!.id}');
      Future.microtask(() async {
        await _loadUserRoleAndMetadata(user: _currentUser!);
        _onSessionRestoredCallback?.call(_currentUser);
      });
    } else {
      debugPrint('[SessionService] No initial session found.');
      _onSessionExpiredOrSignedOutCallback?.call();
    }

    _authSubscription = _supabase.auth.onAuthStateChange.listen(
          (data) async {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;
        final User? previousUser = _currentUser;

        _currentUser = session?.user;
        _currentUserMetadata = _currentUser?.userMetadata;

        debugPrint('[SessionService] AuthChangeEvent: $event, User: ${_currentUser?.id}, Session: ${session != null}');

        if (event == AuthChangeEvent.signedOut || event == AuthChangeEvent.userDeleted) {
          _currentUserRole = null;
          _currentUserMetadata = null;
          _onSessionExpiredOrSignedOutCallback?.call();
        } else if (_currentUser != null &&
            (event == AuthChangeEvent.signedIn ||
                event == AuthChangeEvent.tokenRefreshed ||
                event == AuthChangeEvent.userUpdated ||
                (event == AuthChangeEvent.mfaChallengeVerified) ||
                (event == AuthChangeEvent.initialSession && previousUser?.id != _currentUser?.id))) {
          bool forceQuery = event == AuthChangeEvent.userUpdated || _currentUserRole == null || _currentUserMetadata == null;
          await _loadUserRoleAndMetadata(user: _currentUser!, forceDbQuery: forceQuery);
          _onSessionRestoredCallback?.call(_currentUser);
        } else if (_currentUser == null && event != AuthChangeEvent.signedOut && event != AuthChangeEvent.userDeleted) {
          _currentUserRole = null;
          _currentUserMetadata = null;
          _onSessionExpiredOrSignedOutCallback?.call();
        }
      },
      onError: (error) {
        debugPrint('[SessionService] Auth listener error: $error.');
        _currentUser = null;
        _currentUserRole = null;
        _currentUserMetadata = null;
        _onSessionExpiredOrSignedOutCallback?.call();
      },
    );
    _isListenerInitialized = true;
    debugPrint('[SessionService] Listener initialization complete.');
  }

  static void _notifyCurrentState() {
    if (_currentUser != null) {
      Future.microtask(() async {
        if (_currentUserRole == null || _currentUserMetadata == null) {
          await _loadUserRoleAndMetadata(user: _currentUser!);
        }
        _onSessionRestoredCallback?.call(_currentUser);
      });
    } else {
      _onSessionExpiredOrSignedOutCallback?.call();
    }
  }

  static Future<void> _loadUserRoleAndMetadata({required User user, bool forceDbQuery = false}) async {
    _currentUserMetadata = user.userMetadata;

    if (!forceDbQuery && _currentUserMetadata?.containsKey('role') == true) {
      final roleFromMeta = _currentUserMetadata!['role'] as String?;
      if (roleFromMeta != null && roleFromMeta.isNotEmpty) {
        _currentUserRole = roleFromMeta;
        debugPrint('[SessionService] Role loaded from user_metadata: $_currentUserRole for user ${user.id}');
        return;
      }
    }

    debugPrint('[SessionService] Querying "users" (profiles) table for role (User ID: ${user.id}). ForceDB: $forceDbQuery');
    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && response['role'] != null) {
        _currentUserRole = response['role'] as String?;
        debugPrint('[SessionService] Role loaded from DB "users" table: $_currentUserRole for user ${user.id}');
        if (_currentUserMetadata != null) {
          _currentUserMetadata!['role'] = _currentUserRole;
        } else {
          _currentUserMetadata = {'role': _currentUserRole};
        }
      } else {
        _currentUserRole = null;
        debugPrint('[SessionService] No role found for user ${user.id} in "users" table, or role is null.');
      }
    } catch (e) {
      debugPrint('[SessionService] Error loading role from "users" table for user ${user.id}: $e');
      _currentUserRole = null;
    }
  }

  static Future<String?> getUserRole() async {
    _currentUser ??= _supabase.auth.currentUser;
    if (_currentUser == null) {
      _currentUserRole = null;
      return null;
    }
    if (_currentUserRole == null || _currentUserMetadata == null) {
      await _loadUserRoleAndMetadata(user: _currentUser!, forceDbQuery: true);
    }
    return _currentUserRole;
  }

  static String? getCachedUserRole() => _currentUserRole;
  static Map<String, dynamic>? getCachedUserMetadata() => _currentUserMetadata;

  static Future<void> updateUserMetadataInCache(Map<String, dynamic> newMetadata) async {
    _currentUserMetadata = newMetadata;
    if (newMetadata.containsKey('role')) {
      _currentUserRole = newMetadata['role'] as String?;
    }
    debugPrint('[SessionService] Local user metadata cache updated: $newMetadata');
  }

  static Future<bool> saveUserRole(String newRole) async {
    _currentUser ??= _supabase.auth.currentUser;
    if (_currentUser == null) {
      debugPrint("[SessionService] saveUserRole: Cannot save role, user is null.");
      return false;
    }
    if (newRole.isEmpty) {
      debugPrint("[SessionService] saveUserRole: Role cannot be empty string.");
      return false;
    }
    try {
      await _supabase
          .from('users')
          .update({'role': newRole})
          .eq('id', _currentUser!.id);
      debugPrint("[SessionService] Role updated to '$newRole' in 'users' (profiles) table for user ${_currentUser!.id}.");

      final Map<String, dynamic> updatedAuthMetadata = Map<String, dynamic>.from(_currentUser!.userMetadata ?? {});
      updatedAuthMetadata['role'] = newRole;
      updatedAuthMetadata['app_metadata_role_last_set_at'] = DateTime.now().toIso8601String();

      final UserResponse response = await _supabase.auth.updateUser(
        UserAttributes(data: updatedAuthMetadata),
      );

      if (response.user != null) {
        _currentUser = response.user;
        _currentUserMetadata = response.user!.userMetadata;
        _currentUserRole = _currentUserMetadata?['role'] as String?;
        debugPrint("[SessionService] Role update process: DB updated, auth.updateUser called. Listener will refresh state. Cached role: $_currentUserRole for user ${_currentUser!.id}");
        return true;
      } else {
        debugPrint("[SessionService] saveUserRole: auth.updateUser call returned null user. Metadata update might have failed for user ${_currentUser!.id}.");
        await _loadUserRoleAndMetadata(user: _currentUser!, forceDbQuery: true);
        return false;
      }
    } catch (e) {
      debugPrint("[SessionService] Error in saveUserRole for user ${_currentUser?.id} with role '$newRole': $e");
      if (_currentUser != null) {
        await _loadUserRoleAndMetadata(user: _currentUser!, forceDbQuery: true);
      }
      return false;
    }
  }

  static Future<void> clearUserRole() async {
    _currentUserRole = null;
    _currentUserMetadata = null;
    debugPrint("[SessionService] Local user role and metadata cache cleared.");
    return Future.value();
  }

  static User? getCurrentUser() {
    _currentUser ??= _supabase.auth.currentUser;
    if (_currentUser != null && _currentUserMetadata == null) {
      _currentUserMetadata = _currentUser?.userMetadata;
    }
    return _currentUser;
  }

  static Future<void> logout() async {
    final String? userId = _currentUser?.id;
    try {
      await _supabase.auth.signOut();
      debugPrint('[SessionService] Logout call successful for user: $userId (if any). Listener will handle state changes.');
    } catch (e) {
      debugPrint('[SessionService] Error during sign out for user $userId (if any): $e');
      _currentUser = null;
      _currentUserRole = null;
      _currentUserMetadata = null;
      _onSessionExpiredOrSignedOutCallback?.call();
    }
  }

  static void disposeListener() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _isListenerInitialized = false;
    _onSessionRestoredCallback = null;
    _onSessionExpiredOrSignedOutCallback = null;
    debugPrint('[SessionService] Auth listener disposed.');
  }


  // --- METHOD MOVED HERE AND MADE STATIC ---
  static Widget getInitialRouteWidgetForRole(String? role) {
    switch (role) {
      case 'user':
        return const HomeScreen();
      case 'company':
        return const CompanyDashboardScreen();
      case 'admin':
        return const AdminDashboardScreen();
      default:
        debugPrint("[SessionService] Unrecognized role for WIDGET: $role. Defaulting to LoginScreen widget.");
        return const LoginScreen(); // Or an error screen widget
    }
  }

  // This method returns a String (route name), keep it if used elsewhere (e.g., ForceChangePasswordScreen)
  static String getInitialRouteForRole(String? role) { // This returns a String (route name)
    switch (role) {
      case 'user':
        return HomeScreen.routeName;
      case 'company':
        return CompanyDashboardScreen.routeName;
      case 'admin':
        return AdminDashboardScreen.routeName;
      default:
        debugPrint("[SessionService] Unrecognized role in getInitialRouteForRole (string): $role. Defaulting to Login.");
        return LoginScreen.routeName;
    }
  }
// --- END OF MOVED METHOD ---

}

// REMOVE THE EXTENSION BLOCK FROM HERE
// extension SessionServiceRouteWidgetHelper on SessionService {
//   static Widget getInitialRouteWidgetForRole(String? role) {
//     // ...
//   }
// }

