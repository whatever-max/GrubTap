import 'package:supabase_flutter/supabase_flutter.dart';

// Custom Exception class omitted for brevity

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  User? getCurrentUser() {
    try {
      return _supabase.auth.currentUser;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  Future<AuthResponse> signUpUser({
    required String email,
    required String password,
    Map<String, dynamic>? userData,
  }) async {
    final authResponse = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    if (authResponse.user != null && userData != null && userData.isNotEmpty) {
      await _supabase.from('users').insert({
        'id': authResponse.user!.id,
        ...userData,
      });
    }
    return authResponse;
  }

  Future<AuthResponse> loginUser({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  Future<UserResponse> updateUserPassword(String newPassword) async {
    return await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> logoutUser() async {
    await _supabase.auth.signOut();
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final result = await _supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (result is Map<String, dynamic>) {
      return result;
    }
    return null;
  }

  Future<void> updateUserProfile(Map<String, dynamic> profileData) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    await _supabase
        .from('users')
        .update(profileData)
        .eq('id', user.id);
  }
}
