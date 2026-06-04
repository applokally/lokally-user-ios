import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/notification/domain/models/notification_model.dart';
import 'package:ride_sharing_user_app/features/notification/domain/services/notification_service_interface.dart';

class NotificationController extends GetxController implements GetxService {
  final NotificationServiceInterface notificationServiceInterface;
  NotificationController({required this.notificationServiceInterface});

  bool isLoading = false;
  bool isDeleting = false;
  String selectedReadStatus = 'all';
  NotificationsModel? notificationModel;

  Future<void> getNotificationList(
    int offset, {
    bool reload = false,
    String? readStatus,
  }) async {
    if (readStatus != null && readStatus.isNotEmpty) {
      selectedReadStatus = readStatus;
    }

    isLoading = true;

    if (offset == 1 && reload) {
      notificationModel = null;
    }

    update();

    Response response = await notificationServiceInterface.getList(
      offset: offset,
      readStatus: selectedReadStatus,
    );

    if (response.statusCode == 200) {
      final NotificationsModel responseModel =
          NotificationsModel.fromJson(response.body);

      if (offset == 1) {
        notificationModel = responseModel;
      } else {
        notificationModel?.data ??= <Notifications>[];
        notificationModel?.data!
            .addAll(responseModel.data ?? <Notifications>[]);
        notificationModel?.offset = responseModel.offset;
        notificationModel?.totalSize = responseModel.totalSize;
      }

      isLoading = false;
    } else {
      isLoading = false;
      ApiChecker.checkApi(response);
    }

    update();
  }

  Future<void> changeReadStatusFilter(String readStatus) async {
    selectedReadStatus = readStatus;
    await getNotificationList(1, reload: true, readStatus: readStatus);
  }

  Future<void> sendReadStatus(int notificationId, int index) async {
    Response response =
        await notificationServiceInterface.sendReadStatus(notificationId);

    if (response.statusCode == 200) {
      if (index >= 0 && (notificationModel?.data?.length ?? 0) > index) {
        notificationModel?.data?[index].isRead = true;
      }
    } else {
      ApiChecker.checkApi(response);
    }

    update();
  }

  Future<bool> deleteNotification(int notificationId, int index) async {
    isDeleting = true;
    update();

    Response response =
        await notificationServiceInterface.deleteNotification(notificationId);

    isDeleting = false;

    if (response.statusCode == 200) {
      if (index >= 0 && (notificationModel?.data?.length ?? 0) > index) {
        notificationModel?.data?.removeAt(index);

        final int currentTotal = notificationModel?.totalSize ?? 0;
        notificationModel?.totalSize = currentTotal > 0 ? currentTotal - 1 : 0;
      }

      update();
      return true;
    }

    ApiChecker.checkApi(response);
    update();
    return false;
  }
}
