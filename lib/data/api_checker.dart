import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/auth/domain/models/error_response.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';

class ApiChecker {
  static void checkApi(
    Response response, {
    bool showUnauthorizedMessage = false,
  }) {
    if (response.statusCode == 401) {
      if (showUnauthorizedMessage) {
        showCustomSnackBar(
          'Sua sessão não pôde ser confirmada agora. Faça login novamente para acessar esta área.',
        );
      }

      return;
    } else if (response.statusCode == 0 || response.statusCode == 1) {
      return;
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
      showCustomSnackBar(
        response.statusText ?? 'Não foi possível concluir a solicitação.',
      );
    } else {
      showCustomSnackBar(
        response.statusText ?? 'Não foi possível concluir a solicitação.',
      );
    }
  }
}
