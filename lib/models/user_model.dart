// lib/models/user_model.dart

class UserModel {
  final String id;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String? phone; // Make phone nullable as it is in your DB schema (text, not NOT NULL)
  final String role;
  final Map<String, dynamic>? rawUserMetaData; // For storing auth.users.raw_user_meta_data

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.phone, // Updated to be nullable
    required this.role,
    this.rawUserMetaData, // Added
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      email: map['email'] as String,
      username: map['username'] as String? ?? '', // Handle if username can be null from DB
      firstName: map['first_name'] as String? ?? '', // Handle if first_name can be null
      lastName: map['last_name'] as String? ?? '',   // Handle if last_name can be null
      phone: map['phone'] as String?, // Already nullable which is good
      role: map['role'] as String? ?? 'user', // Default role if null
      // Assuming raw_user_meta_data is NOT directly selected from public.users
      // It would typically come from the Supabase.instance.client.auth.currentUser?.userMetadata
      // For simplicity here, we'll keep it as potentially null from the map if you don't explicitly add it.
      // If you are selecting it from a view or function that joins auth.users, then:
      // rawUserMetaData: map['raw_user_meta_data'] as Map<String, dynamic>?,
      rawUserMetaData: map.containsKey('user_metadata') // Check if 'user_metadata' key exists
          ? map['user_metadata'] as Map<String, dynamic>?
          : (map.containsKey('raw_user_meta_data')
          ? map['raw_user_meta_data'] as Map<String, dynamic>?
          : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      if (phone != null) 'phone': phone, // Only include if not null
      'role': role,
      if (rawUserMetaData != null) 'user_metadata': rawUserMetaData, // Include for convenience
    };
  }
}
