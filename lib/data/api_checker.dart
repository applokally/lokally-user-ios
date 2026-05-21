import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/auth/domain/models/error_response.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/login_helper.dart';

class ApiChecker {
  static bool get _isGuestMode {
    try {
      if (Get.isRegistered<ApiClient>()) {
        return Get.find<ApiClient>().token.trim().isEmpty;
      }
    } catch (_) {}

    return true;
  }

  static bool _isGuestAuthNoise(Response response) {
    if (!_isGuestMode) {
      return false;
    }

    final int? statusCode = response.statusCode;
    final String statusText = '${response.statusText ?? ''}'.toLowerCase();
    final String bodyText = '${response.body ?? ''}'.toLowerCase();

    return statusCode == 401 ||
        statusCode == 403 ||
        statusCode == 0 ||
        statusCode == 1 ||
        statusText.contains('unauth') ||
        bodyText.contains('unauth') ||
        statusText.contains('token') ||
        bodyText.contains('token') ||
        statusText.contains('authorization') ||
        bodyText.contains('authorization') ||
        statusText.contains('connection_to_api_server_failed') ||
        bodyText.contains('connection_to_api_server_failed') ||
        statusText.contains('erro com servidor') ||
        bodyText.contains('erro com servidor');
  }

  static void checkApi(Response response) {
    if (_isGuestAuthNoise(response)) {
      return;
    }

    if (response.statusCode == 401) {
      Get.find<ConfigController>().removeSharedData();
      LoginHelper.checkLoginMedium();
    } else if (response.statusCode == 403) {
      ErrorResponse errorResponse;
      errorResponse = ErrorResponse.fromJson(response.body);
      if (errorResponse.errors != null && errorResponse.errors!.isNotEmpty) {
        showCustomSnackBar(errorResponse.errors![0].message!);
      } else {
        showCustomSnackBar(response.body['message']);
      }
    } else if (response.statusCode == 422) {
      ErrorResponse errorResponse;
      errorResponse = ErrorResponse.fromJson(response.body);
      if (errorResponse.errors != null && errorResponse.errors!.isNotEmpty) {
        showCustomSnackBar(errorResponse.errors![0].message!);
      } else {
        showCustomSnackBar(response.body['message']);
      }
    } else if (response.statusCode == 500) {
      if (!_isGuestMode) {
        showCustomSnackBar(response.statusText!);
      }
    } else {
      if (!_isGuestMode) {
        showCustomSnackBar(response.statusText!);
      }
    }
  }
}
