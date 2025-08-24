// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  User? getCurrentAuthUser() {
    return _supabase.auth.currentUser;
  }

  // This is the primary method for new user registration.
  // It's called by RoleSelectorScreen AFTER the user has chosen a role.
  Future<AuthResponse> completeSignupAndCreateProfile({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String username,
    required String role, // The role selected by the user
    // Optional: for auth.users.user_metadata if you want to store some data there too
    Map<String, dynamic>? userMetaDataForAuth,
  }) async {
    try {
      // Step 1: Sign up the user with Supabase auth.
      // It's good practice to also put critical identifiers like role in user_metadata
      // as it can trigger onAuthStateChange more explicitly for some listeners/scenarios.
      final Map<String, dynamic> authDataPayload = {
        ...(userMetaDataForAuth ?? {}), // Spread any existing metadata
        'role': role,
        'username': username, // Storing username in metadata can be useful
        'first_name': firstName,
        'last_name': lastName,
      };

      final AuthResponse authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: authDataPayload, // Pass data for user_metadata
      );

      // Step 2: If auth.signUp is successful, create the record in your 'public.users' table.
      if (authResponse.user != null) {
        debugPrint('[AuthService] Supabase auth user created: ${authResponse.user!.id} during completeSignup.');

        final profileDataToInsert = {
          'id': authResponse.user!.id, // Link to auth.users table
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'username': username,
          'role': role, // <<< ROLE IS NOW PROVIDED AND INSERTED
          // 'created_at' and 'profile_picture_url' will use DB defaults or be updated later.
        };

        try {
          // Assuming your profiles table is named 'users' as per your schema
          await _supabase.from('users').insert(profileDataToInsert);
          debugPrint('[AuthService] Profile created in "users" table with role "$role" for ${authResponse.user!.id}');
        } catch (e) {
          debugPrint('[AuthService] Error inserting profile into "users" table during completeSignup: $e');
          // This is a critical state. User exists in auth but not in your profiles table.
          // For a production app, you'd want robust error handling here,
          // potentially trying to delete the auth user or alerting an admin.
          // Example: (Requires admin privileges, use with extreme caution)
          // try { await _supabase.auth.admin.deleteUser(authResponse.user!.id); } catch (_) {}
          throw Exception('User authentication successful, but profile creation with role failed. Please contact support or try again.');
        }
      } else {
        // This case would be unusual if auth.signUp didn't throw an AuthException
        // but also didn't return a user.
        debugPrint('[AuthService] completeSignupAndCreateProfile: auth.signUp did not return a user object.');
        throw AuthException('Signup failed: No user object returned from authentication process.');
      }
      return authResponse;
    } on AuthException catch (e) {
      debugPrint('[AuthService] completeSignupAndCreateProfile AuthException: ${e.message}');
      // Check for specific error messages like "User already registered"
      if (e.message.toLowerCase().contains('user already registered')) {
        throw AuthException('This email is already registered. Please login or use a different email.');
      }
      rethrow; // Rethrow other AuthExceptions to be handled by the UI
    } catch (e) {
      debugPrint('[AuthService] completeSignupAndCreateProfile Generic Error: $e');
      rethrow; // Rethrow other generic errors
    }
  }

  Future<AuthResponse> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      debugPrint('[AuthService] Login successful for: $email');
      return res;
    } on AuthException catch (e) {
      debugPrint('[AuthService] loginUser AuthException: ${e.message}');
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        throw AuthException('Invalid email or password. Please check your credentials.');
      }
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] loginUser Generic Error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      debugPrint('[AuthService] User signed out.');
    } catch (e) {
      debugPrint('[AuthService] signOut Error: $e');
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      debugPrint('[AuthService] Password reset email sent to $email');
    } catch (e) {
      debugPrint('[AuthService] sendPasswordResetEmail Error: $e');
      rethrow;
    }
  }

  // ... (getCurrentUserProfileData, updateUserProfileData can remain as they were if correct for 'users' table)

  Future<Map<String, dynamic>?> getCurrentUserProfileData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('[AuthService] getCurrentUserProfileData: No authenticated user.');
      return null;
    }
    try {
      final response = await _supabase
          .from('users') // Your profiles table
          .select()
          .eq('id', user.id)
          .maybeSingle();
      return response as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[AuthService] Error fetching user profile data: $e');
      return null;
    }
  }

  Future<void> updateUserProfileData(Map<String, dynamic> profileData) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw AuthException('User not authenticated. Cannot update profile.');
    }
    try {
      await _supabase
          .from('users') // Your profiles table
          .update(profileData)
          .eq('id', user.id);
      debugPrint('[AuthService] User profile data updated for user ${user.id}.');
      // Trigger a metadata update to ensure AuthStateChange listeners are notified
      await _supabase.auth.updateUser(UserAttributes(data: {'profile_updated_at': DateTime.now().toIso8601String()}));

    } catch (e) {
      debugPrint('[AuthService] Error updating user profile data: $e');
      rethrow;
    }
  }
}
