import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/auth/domain/enums/verification_from_enum.dart';
import 'package:ride_sharing_user_app/features/auth/screens/otp_log_in_screen.dart';
import 'package:ride_sharing_user_app/features/auth/screens/sign_in_screen.dart';
import 'package:ride_sharing_user_app/features/auth/screens/sign_up_screen.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/location/view/access_location_screen.dart';
import 'package:ride_sharing_user_app/features/maintainance_mode/maintainance_screen.dart';
import 'package:ride_sharing_user_app/features/realtime_location_trac/screens/live_location_screen.dart';
import 'package:ride_sharing_user_app/features/payment/controllers/payment_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/refund_request/controllers/refund_request_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/splash/domain/models/config_model.dart';
import 'package:ride_sharing_user_app/features/splash/screens/app_version_warning_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_home_screen.dart';
import 'package:ride_sharing_user_app/features/trip/controllers/trip_controller.dart';
import 'package:ride_sharing_user_app/helper/firebase_helper.dart';
import 'package:ride_sharing_user_app/helper/notification_helper.dart';
import 'package:ride_sharing_user_app/helper/pusher_helper.dart';
import 'package:ride_sharing_user_app/localization/language_selection_screen.dart';
import 'package:ride_sharing_user_app/localization/localization_controller.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class LoginHelper {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _appLinkSubscription;

  void handleIncomingLinks(Map<String, dynamic>? notificationData) async {
    Get.find<TripController>().getRideCancellationReasonList();
    Get.find<TripController>().getParcelCancellationReasonList();
    Get.find<RefundRequestController>().getParcelRefundReasonList();
    Get.find<PaymentController>().getPaymentGetWayList();
    FirebaseHelper().subscribeFirebaseTopic();
    _listenReferralLinks();

    final LokallyIncomingLink? incomingLink = await initDynamicLinks();

    Get.find<ConfigController>().getConfigData().then((value) {
      if (_isForceUpdate(Get.find<ConfigController>().config)) {
        Get.offAll(() => const AppVersionWarningScreen());
      } else {
        if (incomingLink?.referralCode != null &&
            incomingLink!.referralCode!.isNotEmpty) {
          _openReferralRegistration(
            incomingLink.referralCode!,
            notificationData,
          );
        } else if (incomingLink?.trackingPath != null &&
            incomingLink!.trackingPath!.isNotEmpty) {
          Get.offAll(
            () => LiveLocationScreen(trackingUrl: incomingLink.trackingPath!),
          );
        } else {
          route(notificationData);
        }
      }
    });
  }

  Future<LokallyIncomingLink?> initDynamicLinks() async {
    final Uri? uri = await _appLinks.getInitialLink();

    if (uri == null) {
      return null;
    }

    return _parseIncomingLink(uri);
  }

  void _listenReferralLinks() {
    _appLinkSubscription ??= _appLinks.uriLinkStream.listen((Uri uri) {
      final LokallyIncomingLink? incomingLink = _parseIncomingLink(uri);

      if (incomingLink?.referralCode != null &&
          incomingLink!.referralCode!.isNotEmpty) {
        _openReferralRegistration(incomingLink.referralCode!, null);
      } else if (incomingLink?.trackingPath != null &&
          incomingLink!.trackingPath!.isNotEmpty) {
        Get.to(
          () => LiveLocationScreen(trackingUrl: incomingLink.trackingPath!),
        );
      }
    });
  }

  LokallyIncomingLink? _parseIncomingLink(Uri uri) {
    final String? referralCode = _referralCodeFromUri(uri);

    if (referralCode != null && referralCode.isNotEmpty) {
      return LokallyIncomingLink(referralCode: referralCode);
    }

    final String trackingPath = uri.path.trim();

    if (trackingPath.isEmpty || trackingPath == '/') {
      return null;
    }

    return LokallyIncomingLink(trackingPath: trackingPath);
  }

  String? _referralCodeFromUri(Uri uri) {
    for (final String key in <String>[
      'referral_code',
      'referralCode',
      'ref',
      'code',
      'invite',
    ]) {
      final String? value = uri.queryParameters[key]?.trim();

      if (_isReferralCodeCandidate(value)) {
        return value;
      }
    }

    final List<String> segments = uri.pathSegments
        .map((segment) => Uri.decodeComponent(segment).trim())
        .where((segment) => segment.isNotEmpty)
        .toList();

    if (uri.scheme == 'lokally') {
      if (_isReferralCodeCandidate(uri.host)) {
        return uri.host.trim();
      }

      if ((uri.host == 'r' ||
              uri.host == 'referral' ||
              uri.host == 'invite' ||
              uri.host == 'convite') &&
          segments.isNotEmpty &&
          _isReferralCodeCandidate(segments.first)) {
        return segments.first;
      }
    }

    if (segments.length >= 2 &&
        <String>{'r', 'referral', 'invite', 'convite'}
            .contains(segments.first.toLowerCase()) &&
        _isReferralCodeCandidate(segments[1])) {
      return segments[1];
    }

    if (segments.length == 1 && _isReferralCodeCandidate(segments.first)) {
      return segments.first;
    }

    return null;
  }

  bool _isReferralCodeCandidate(String? value) {
    final String code = value?.trim() ?? '';

    if (code.isEmpty) {
      return false;
    }

    final String lowerCode = code.toLowerCase();

    if (<String>{
      'admin',
      'api',
      'about-us',
      'customer-app-download',
      'driver-app-download',
      'blog',
      'privacy-policy',
      'terms-and-conditions',
      'contact-us',
      'storage',
      'login',
      'register',
      'registration',
      'r',
      'referral',
      'invite',
      'convite',
    }.contains(lowerCode)) {
      return false;
    }

    return RegExp(r'^[A-Za-z0-9_-]{5,40}$').hasMatch(code);
  }

  void _openReferralRegistration(
    String referralCode,
    Map<String, dynamic>? notificationData,
  ) {
    Get.find<AuthController>().referralCodeController.text =
        referralCode.trim();

    if (Get.find<AuthController>().isLoggedIn()) {
      route(notificationData);
      return;
    }

    if (Get.find<ConfigController>().config!.maintenanceMode != null &&
        Get.find<ConfigController>()
                .config!
                .maintenanceMode!
                .maintenanceStatus ==
            1 &&
        Get.find<ConfigController>()
                .config!
                .maintenanceMode!
                .selectedMaintenanceSystem!
                .userApp ==
            1) {
      Get.offAll(() => const MaintenanceScreen());
      return;
    }

    if (Get.find<LocalizationController>().haveLocalLanguageCode()) {
      Get.offAll(() => const SignUpScreen());
    } else {
      Get.offAll(
        () => LanguageSelectionScreen(notificationData: notificationData),
      );
    }
  }

  bool _isForceUpdate(ConfigModel? config) {
    double minimumVersion = Platform.isAndroid
        ? config?.androidAppMinimumVersion ?? 0
        : Platform.isIOS
            ? config?.iosAppMinimumVersion ?? 0
            : 0;

    return minimumVersion > 0 && minimumVersion > AppConstants.appVersion;
  }

  void route(Map<String, dynamic>? notificationData) async {
    if (Get.find<AuthController>().getUserToken().isNotEmpty) {
      PusherHelper.initializePusher();
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (Get.find<AuthController>().isLoggedIn()) {
        if (Get.find<LocalizationController>().haveLocalLanguageCode()) {
          forLoginUserRoute(notificationData);
        } else {
          Get.offAll(() =>
              LanguageSelectionScreen(notificationData: notificationData));
        }
      } else {
        forNotLoginUserRoute(notificationData);
      }
    });
  }

  void forNotLoginUserRoute(Map<String, dynamic>? notificationData) {
    if (Get.find<ConfigController>().config!.maintenanceMode != null &&
        Get.find<ConfigController>()
                .config!
                .maintenanceMode!
                .maintenanceStatus ==
            1 &&
        Get.find<ConfigController>()
                .config!
                .maintenanceMode!
                .selectedMaintenanceSystem!
                .userApp ==
            1) {
      Get.offAll(() => const MaintenanceScreen());
    } else {
      if (Get.find<LocalizationController>().haveLocalLanguageCode()) {
        if (Get.find<LocationController>().getUserAddress() != null &&
            Get.find<LocationController>().getUserAddress()!.address != null &&
            Get.find<LocationController>()
                .getUserAddress()!
                .address!
                .isNotEmpty) {
          Get.offAll(() => const StoreHomeScreen());
        } else {
          Get.offAll(() => const AccessLocationScreen());
        }
      } else {
        Get.offAll(
            () => LanguageSelectionScreen(notificationData: notificationData));
      }
    }
  }

  void forLoginUserRoute(Map<String, dynamic>? notificationData) {
    if (notificationData != null) {
      NotificationHelper.notificationRouteCheck(notificationData,
          formSplash: true, userName: notificationData['user_name']);
    } else if (Get.find<LocationController>().getUserAddress() != null &&
        Get.find<LocationController>().getUserAddress()!.address != null &&
        Get.find<LocationController>().getUserAddress()!.address!.isNotEmpty) {
      Get.find<ProfileController>().getProfileInfo().then((value) {
        if (value.statusCode == 200) {
          Get.find<AuthController>().updateToken();
          Get.find<AuthController>().remainingFindingRideTime();
          Get.offAll(() => const DashboardScreen());
        }
      });
    } else {
      Get.offAll(() => const AccessLocationScreen());
    }
  }

  static void checkLoginMedium() {
    final bool isManualLogin = Get.find<ConfigController>()
            .config
            ?.customerLoginOptions
            ?.manualLogin ??
        false;
    if (isManualLogin) {
      Get.offAll(() => const SignInScreen());
    } else {
      Get.offAll(() => const OtpLoginScreen(from: VerificationForm.login));
    }
  }
}

class LokallyIncomingLink {
  final String? referralCode;
  final String? trackingPath;

  const LokallyIncomingLink({
    this.referralCode,
    this.trackingPath,
  });
}
