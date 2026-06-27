import 'dart:developer';

import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/map/screens/map_screen.dart';
import 'package:ride_sharing_user_app/features/payment/domain/services/payment_service_interface.dart';
import 'package:ride_sharing_user_app/features/payment/screens/review_screen.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/splash/domain/models/config_model.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/images.dart';

enum PaymentType { cash, digital, wallet }

class PaymentController extends GetxController implements GetxService {
  final PaymentServiceInterface paymentServiceInterface;

  PaymentController({required this.paymentServiceInterface});

  static const Set<String> _directToDriverMethods = {
    'cash',
    'machine_debit',
    'machine_credit',
    'pix',
  };

  static const Map<String, String> _paymentMethodLabels = {
    'cash': 'Dinheiro',
    'machine_debit': 'Maquininha Débito',
    'machine_credit': 'Maquininha Crédito',
    'pix': 'PIX',
    'lokally_pay': 'Lokally Pay',
    'wallet': 'Carteira',
  };

  List<ReviewModel> reviewTypeList = [
    ReviewModel(Images.notGood, 'not_good'),
    ReviewModel(Images.good, 'good'),
    ReviewModel(Images.satisfied, 'satisfied'),
    ReviewModel(Images.lovely, 'lovely'),
    ReviewModel(Images.superb, 'superb'),
  ];

  List<String> paymentTypeList = ['cash', 'digital', 'wallet'];

  bool isLoading = false;
  int reviewTypeSelectedIndex = 4;
  int paymentTypeIndex = 0;
  int paymentGatewayIndex = -1;
  String tipAmount = '0';

  String _directToDriverPaymentMethod = 'cash';

  String get directToDriverPaymentMethod => _directToDriverPaymentMethod;

  String get lokallyPaymentMethodForRideRequest {
    if (paymentTypeIndex == 0) {
      return _directToDriverPaymentMethod;
    }

    if (paymentTypeIndex == 1) {
      return 'lokally_pay';
    }

    return 'wallet';
  }

  String get lokallyPaymentMethodLabelForRideRequest {
    return _paymentMethodLabels[lokallyPaymentMethodForRideRequest] ?? '';
  }

  String get lokallyPaymentFlowForRideRequest {
    return paymentTypeIndex == 0 ? 'direct_to_driver' : 'in_app';
  }

  bool get isDirectToDriverPayment {
    return paymentTypeIndex == 0;
  }

  void initPayment() {
    isLoading = false;
    reviewTypeSelectedIndex = 3;
    paymentGatewayIndex = -1;
    paymentTypeIndex = 0;
    paymentType = 'cash';
    _directToDriverPaymentMethod = 'cash';
    tipAmount = '0';
  }

  void setReviewType(int index) {
    reviewTypeSelectedIndex = index;
    update();
  }

  String paymentType = 'cash';

  void setPaymentType(int index) {
    tipAmount = '0';
    paymentTypeIndex = index;
    paymentType = paymentTypeList[paymentTypeIndex];
    paymentServiceInterface.saveLastPaymentType(paymentType);
    update();
  }

  void setDirectToDriverPaymentMethod(String method) {
    final String normalizedMethod = method.trim().toLowerCase();

    if (!_directToDriverMethods.contains(normalizedMethod)) {
      return;
    }

    tipAmount = '0';
    paymentTypeIndex = 0;
    paymentType = 'cash';
    _directToDriverPaymentMethod = normalizedMethod;
    paymentServiceInterface.saveLastPaymentType(paymentType);
    update();
  }

  void setPaymentByName(String name) {
    final String normalizedName = name.trim().toLowerCase();

    if (_directToDriverMethods.contains(normalizedName)) {
      _directToDriverPaymentMethod = normalizedName;
      paymentTypeIndex = 0;
      paymentType = 'cash';
    } else if (normalizedName == 'wallet') {
      paymentTypeIndex = 2;
      paymentType = paymentTypeList[paymentTypeIndex];
    } else {
      paymentTypeIndex = 1;
      paymentType = paymentTypeList[paymentTypeIndex];
    }

    update();
  }

  String gateWay = '';

  void setDigitalPaymentType(int index, String gateway) {
    paymentGatewayIndex = index;
    gateWay =
        Get.find<ConfigController>().config?.paymentGateways?[index].gateway ??
            'ssl_commerz';
    log('===>44$gateWay');
    paymentServiceInterface.saveLastPaymentMethod(gateWay);
    update();
  }

  void setTipAmount(String amount) {
    if (amount.isNotEmpty) {
      tipAmount = amount;
    } else {
      tipAmount = '0';
    }

    update();
  }

  Future<Response> submitReview(
    String id,
    int ratting,
    String comment,
  ) async {
    isLoading = true;
    update();

    Response response =
        await paymentServiceInterface.submitReview(id, ratting, comment);

    if (response.statusCode == 200) {
      Get.back();
      showCustomSnackBar('review_submitted_successfully'.tr, isError: false);
      Get.find<BottomMenuController>().navigateToDashboard();
      isLoading = false;
    } else {
      isLoading = false;
      ApiChecker.checkApi(response);
    }

    update();
    return response;
  }

  Future<Response> paymentSubmit(
    String tripId,
    String paymentMethod, {
    bool fromParcel = false,
  }) async {
    isLoading = true;
    update();

    Response response =
        await paymentServiceInterface.paymentSubmit(tripId, paymentMethod);

    if (response.statusCode == 200) {
      Get.find<RideController>().clearRideDetails();
      Get.find<ProfileController>().getProfileInfo();
      showCustomSnackBar('payment_successful'.tr, isError: false);

      if (fromParcel) {
        Get.find<RideController>()
            .updateRideCurrentState(RideState.afterAcceptRider);
        Get.find<RideController>().getRideDetails(tripId).then((value) {
          Get.offAll(() => const MapScreen(fromScreen: MapScreenType.parcel));
        });
      } else {
        if (Get.find<ConfigController>().config!.reviewStatus!) {
          Get.offAll(() => ReviewScreen(tripId: tripId));
        } else {
          Get.offAll(() => const DashboardScreen());
        }
      }

      isLoading = false;
    } else {
      isLoading = false;
      ApiChecker.checkApi(response);
    }

    update();
    return response;
  }

  List<PaymentGateways>? paymentGateways = [];

  void getPaymentGetWayList() async {
    paymentGateways = [];
    Response response = await paymentServiceInterface.getPaymentGetWayList();

    if (response.statusCode == 200) {
      response.body.forEach((v) {
        paymentGateways!.add(PaymentGateways.fromJson(v));
      });
      checkPreviousPaymentMethod();
    } else {
      ApiChecker.checkApi(response);
    }

    update();
  }

  void checkPreviousPaymentMethod() {
    String previousPaymentMethod =
        paymentServiceInterface.getLastPaymentMethod();
    String previousPaymentType = paymentServiceInterface.getLastPaymentType();

    for (int i = 0; i < paymentGateways!.length; i++) {
      if (paymentGateways?[i].gateway == previousPaymentMethod) {
        paymentGatewayIndex = i;
        gateWay = paymentGateways![i].gateway!;
      }
    }

    if (_directToDriverMethods.contains(previousPaymentType)) {
      _directToDriverPaymentMethod = previousPaymentType;
      paymentTypeIndex = 0;
      paymentType = 'cash';
      return;
    }

    for (int i = 0; i < paymentTypeList.length; i++) {
      if (paymentTypeList[i] == previousPaymentType) {
        paymentTypeIndex = i;
        paymentType = paymentTypeList[i];
      }
    }
  }
}

class PaymentMethod {
  String name;
  String image;

  PaymentMethod(this.name, this.image);
}

class ReviewModel {
  String? icon;
  String? title;

  ReviewModel(this.icon, this.title);
}
