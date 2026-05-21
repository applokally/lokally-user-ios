import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/confirmation_bottomsheet_widget.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/helper/login_helper.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/location/view/access_location_screen.dart';

class BottomMenuController extends GetxController implements GetxService {
  int _currentTab = 0;
  int get currentTab => _currentTab;

  bool get isCustomerLoggedIn {
    return Get.isRegistered<AuthController>() &&
        Get.find<AuthController>().isLoggedIn();
  }

  bool _isPrivateTab(int index) {
    return index == 1 || index == 3;
  }

  void resetNavBar() {
    _currentTab = 0;
  }

  void setTabIndex(int index) {
    if (_isPrivateTab(index) && !isCustomerLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    _currentTab = index;
    update();
  }

  void navigateToDashboard() {
    _currentTab = 0;
    if (Get.find<LocationController>().getUserAddress() != null) {
      Get.offAll(() => const DashboardScreen());
    } else {
      Get.offAll(const AccessLocationScreen());
    }
  }

  void _showLoginRequiredDialog() {
    if (Get.isDialogOpen ?? false) {
      return;
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Para prosseguir, realize seu cadastro'),
        content: const Text(
          'Crie sua conta ou entre na Lokally para acessar esta \u00e1rea com seguran\u00e7a.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Continuar navegando'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              LoginHelper.openLoginScreen();
            },
            child: const Text('Entrar ou cadastrar'),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  void exitApp() {
    Get.bottomSheet(ConfirmationBottomsheetWidget(
      icon: Images.exitIcon,
      title: 'exit_app'.tr,
      description: 'do_you_want_to_exit_the_app'.tr,
      onYesPressed: () => SystemNavigator.pop(),
      onNoPressed: () => Get.back(),
    ));
  }
}
