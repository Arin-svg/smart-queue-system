class Room {
  const Room({
    required this.id,
    required this.name,
    required this.departmentId,
    required this.isActive,
  });
  final int id;
  final String name;
  final int departmentId;
  final bool isActive;
}
