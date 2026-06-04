import 'package:ride_sharing_user_app/features/notification/domain/repositories/notification_repository_interface.dart';
import 'package:ride_sharing_user_app/features/notification/domain/services/notification_service_interface.dart';

class NotificationService implements NotificationServiceInterface {
  final NotificationRepositoryInterface notificationRepositoryInterface;

  NotificationService({required this.notificationRepositoryInterface});

  @override
  Future<dynamic> getList({
    int? offset = 1,
    String readStatus = 'all',
  }) async {
    return await notificationRepositoryInterface.getList(
      offset: offset,
      readStatus: readStatus,
    );
  }

  @override
  Future<dynamic> sendReadStatus(int notificationId) async {
    return await notificationRepositoryInterface.sendReadStatus(notificationId);
  }

  @override
  Future<dynamic> deleteNotification(int notificationId) async {
    return await notificationRepositoryInterface.deleteNotification(
      notificationId,
    );
  }
}
