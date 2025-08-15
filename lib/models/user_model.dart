class UserModel {
  final String id;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String phone;
  final String role;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.role,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      email: map['email'],
      username: map['username'],
      firstName: map['first_name'],
      lastName: map['last_name'],
      phone: map['phone'],
      role: map['role'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'role': role,
    };
  }
}
