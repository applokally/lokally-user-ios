abstract class NotificationServiceInterface {
  Future<dynamic> getList({
    int? offset = 1,
    String readStatus = 'all',
  });

  Future<dynamic> sendReadStatus(int notificationId);

  Future<dynamic> deleteNotification(int notificationId);
}
