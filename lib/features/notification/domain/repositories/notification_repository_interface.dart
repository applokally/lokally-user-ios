import 'package:ride_sharing_user_app/interface/repository_interface.dart';

abstract class NotificationRepositoryInterface implements RepositoryInterface {
  @override
  Future<dynamic> getList({
    int? offset = 1,
    String readStatus = 'all',
  });

  Future<dynamic> sendReadStatus(int notificationId);

  Future<dynamic> deleteNotification(int notificationId);
}
