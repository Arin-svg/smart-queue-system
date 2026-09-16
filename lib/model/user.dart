import 'role.dart';

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
  final int id;
  final String name;
  final String email;
  final Role role;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    role: Role.values.byName(json['role'] as String),
  );
}
