// lib/services/session_service.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class SessionService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static StreamSubscription<AuthState>? _authSubscription;
  static User? _currentUser;
  static String? _currentUserRole; // Local cache for the user's role

  static bool _isListenerInitialized = false;
  static void Function(User? user)? _onSessionRestoredCallback;
  static void Function()? _onSessionExpiredOrSignedOutCallback;

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
    if (_currentUser != null) {
      debugPrint('[SessionService] Initial session found for user: ${_currentUser!.id}');
      Future.microtask(() async {
        await _loadUserRoleFromDatabase(user: _currentUser!); // Changed method name for clarity
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

        debugPrint('[SessionService] AuthChangeEvent: $event, User: ${_currentUser?.id}, Session: ${session != null}');

        if (event == AuthChangeEvent.signedOut || event == AuthChangeEvent.userDeleted) {
          _currentUserRole = null;
          _onSessionExpiredOrSignedOutCallback?.call();
        } else if (_currentUser != null &&
            (event == AuthChangeEvent.signedIn ||
                event == AuthChangeEvent.tokenRefreshed ||
                event == AuthChangeEvent.userUpdated ||
                (event == AuthChangeEvent.initialSession && previousUser?.id != _currentUser?.id))) {
          // On userUpdated, always force a DB query for the role as it might have changed.
          // Also query if the role isn't cached yet.
          bool forceQuery = event == AuthChangeEvent.userUpdated || _currentUserRole == null;
          await _loadUserRoleFromDatabase(user: _currentUser!, forceDbQuery: forceQuery);
          _onSessionRestoredCallback?.call(_currentUser);
        } else if (_currentUser == null && event != AuthChangeEvent.signedOut && event != AuthChangeEvent.userDeleted) {
          // If user becomes null unexpectedly
          _currentUserRole = null;
          _onSessionExpiredOrSignedOutCallback?.call();
        }
      },
      onError: (error) {
        debugPrint('[SessionService] Auth listener error: $error.');
        _currentUser = null;
        _currentUserRole = null;
        _onSessionExpiredOrSignedOutCallback?.call();
      },
    );
    _isListenerInitialized = true;
    debugPrint('[SessionService] Listener initialization complete.');
  }

  static void _notifyCurrentState() {
    if (_currentUser != null) {
      Future.microtask(() async {
        if (_currentUserRole == null) await _loadUserRoleFromDatabase(user: _currentUser!);
        _onSessionRestoredCallback?.call(_currentUser);
      });
    } else {
      _onSessionExpiredOrSignedOutCallback?.call();
    }
  }

  // Renamed for clarity: this method specifically loads from your 'users' (profiles) table.
  static Future<void> _loadUserRoleFromDatabase({required User user, bool forceDbQuery = false}) async {
    // Attempt to load from user_metadata first if not forcing DB query
    // This is useful if saveUserRole also updates metadata, making subsequent checks faster.
    if (!forceDbQuery && user.userMetadata?.containsKey('role') == true) {
      final roleFromMeta = user.userMetadata!['role'] as String?;
      if (roleFromMeta != null && roleFromMeta.isNotEmpty) {
        _currentUserRole = roleFromMeta;
        debugPrint('[SessionService] Role loaded from user_metadata: $_currentUserRole for user ${user.id}');
        return;
      } else {
        debugPrint('[SessionService] Role in user_metadata is null/empty for user ${user.id}. Querying DB.');
      }
    }

    // Query your 'users' table (as per your schema, this is your profiles table)
    debugPrint('[SessionService] Querying "users" (profiles) table for role (User ID: ${user.id}). ForceDB: $forceDbQuery');
    try {
      final response = await _supabase
          .from('users') // <<< YOUR PROFILES TABLE (named 'users' in your provided schema)
          .select('role')
          .eq('id', user.id) // Assumes 'id' in your 'users' table is the FK to auth.users.id
          .maybeSingle();

      if (response != null && response['role'] != null) {
        _currentUserRole = response['role'] as String?;
        debugPrint('[SessionService] Role loaded from DB "users" (profiles) table: $_currentUserRole for user ${user.id}');
      } else {
        _currentUserRole = null; // Explicitly set to null if not found or role field is null
        debugPrint('[SessionService] No role found for user ${user.id} in "users" (profiles) table, or role is null.');
      }
    } catch (e) {
      debugPrint('[SessionService] Error loading role from "users" (profiles) table for user ${user.id}: $e');
      _currentUserRole = null; // Ensure role is null on error
    }
  }

  // Asynchronous method to get user role, will fetch if not cached.
  static Future<String?> getUserRole() async {
    _currentUser ??= _supabase.auth.currentUser; // Ensure current user is populated
    if (_currentUser == null) {
      _currentUserRole = null; // Clear cache if no user
      return null;
    }
    // If role isn't cached or if you always want the freshest from DB (controlled by _loadUserRoleFromDatabase's logic)
    if (_currentUserRole == null) {
      await _loadUserRoleFromDatabase(user: _currentUser!, forceDbQuery: true); // Force DB query to ensure freshness
    }
    return _currentUserRole;
  }

  // Synchronous method to get the currently cached user role.
  // This is useful for immediate checks in UI build methods where async calls are not ideal.
  static String? getCachedUserRole() {
    return _currentUserRole;
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
      // Step 1: Update the role in your 'users' (profiles) table.
      await _supabase
          .from('users') // <<< YOUR PROFILES TABLE (named 'users' in your provided schema)
          .update({'role': newRole})
          .eq('id', _currentUser!.id); // Assumes 'id' in your 'users' table is FK to auth.users.id
      debugPrint("[SessionService] Role updated to '$newRole' in 'users' (profiles) table for user ${_currentUser!.id}.");

      _currentUserRole = newRole; // Update local cache immediately

      // Step 2: Update the user's metadata (auth.users.user_metadata).
      // This is crucial for triggering the AuthChangeEvent.userUpdated event reliably.
      final UserResponse response = await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'role': newRole, // Store the role in metadata as well
            'app_metadata_role_last_set_at': DateTime.now().toIso8601String(), // Ensures user_metadata changes
          },
        ),
      );

      if (response.user != null) {
        _currentUser = response.user; // Update with the user object from the response
        debugPrint("[SessionService] Role update process: DB updated, auth.updateUser called. Listener will refresh state. Cached role: $_currentUserRole for user ${_currentUser!.id}");
        return true;
      } else {
        debugPrint("[SessionService] saveUserRole: auth.updateUser call returned null user. Metadata update might have failed for user ${_currentUser!.id}.");
        // Even if auth.updateUser had issues, the DB role might be updated.
        // Attempt to reload the role to reflect the DB state.
        await _loadUserRoleFromDatabase(user: _currentUser!, forceDbQuery: true);
        return false; // Indicate potential issue with metadata update.
      }
    } catch (e) {
      debugPrint("[SessionService] Error in saveUserRole for user ${_currentUser?.id} with role '$newRole': $e");
      // Attempt to refetch role from DB to ensure local cache reflects the DB state.
      if (_currentUser != null) {
        await _loadUserRoleFromDatabase(user: _currentUser!, forceDbQuery: true);
      }
      return false;
    }
  }

  static Future<void> clearUserRole() async {
    // This typically means clearing the local cache. Logging out handles server-side session.
    _currentUserRole = null;
    debugPrint("[SessionService] Local user role cache cleared.");
    // If you also want to remove it from user_metadata (might not be necessary if logout is preferred):
    // if (_currentUser != null && _currentUser!.userMetadata?.containsKey('role') == true) {
    //   try {
    //     await _supabase.auth.updateUser(UserAttributes(data: {'role': null}));
    //     debugPrint("[SessionService] Role cleared from user_metadata.");
    //   } catch (e) {
    //     debugPrint("[SessionService] Error clearing role from user_metadata: $e");
    //   }
    // }
  }

  static User? getCurrentUser() {
    _currentUser ??= _supabase.auth.currentUser;
    return _currentUser;
  }

  static Future<void> logout() async {
    final String? userId = _currentUser?.id;
    try {
      await _supabase.auth.signOut();
      // _currentUser and _currentUserRole will be set to null by the onAuthStateChange listener
      // when it receives the AuthChangeEvent.signedOut event.
      debugPrint('[SessionService] Logout call successful for user: $userId (if any). Listener will handle state changes.');
    } catch (e) {
      debugPrint('[SessionService] Error during sign out for user $userId (if any): $e');
      // Fallback: Manually clear session state if signOut throws an error and listener doesn't fire.
      _currentUser = null;
      _currentUserRole = null;
      _onSessionExpiredOrSignedOutCallback?.call(); // Manually trigger callback
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
}

