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
}
