import '../model/notification.dart';

abstract interface class NotificationService {
  Future<List<AppNotification>> fetchNotifications();
  Future<void> markAsRead(int notificationId);
}
