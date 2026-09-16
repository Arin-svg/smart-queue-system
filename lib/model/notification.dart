// Avoids a name collision with Flutter's Notification class.

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });
  final int id;
  final int userId;
  final String message;
  final DateTime createdAt;
  final bool isRead;
}
