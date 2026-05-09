import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/map/screens/map_screen.dart';
import 'package:ride_sharing_user_app/features/message/controllers/message_controller.dart';
import 'package:ride_sharing_user_app/features/message/screens/message_screen.dart';
import 'package:ride_sharing_user_app/features/my_level/controller/level_controller.dart';
import 'package:ride_sharing_user_app/features/my_level/widget/level_complete_dialog_widget.dart';
import 'package:ride_sharing_user_app/features/my_offer/screens/my_offer_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/driver_request_dialog.dart';
import 'package:ride_sharing_user_app/features/payment/screens/payment_screen.dart';
import 'package:ride_sharing_user_app/features/payment/screens/review_screen.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/controllers/refer_and_earn_controller.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/screens/refer_and_earn_screen.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/widgets/confirmation_trip_dialog.dart';
import 'package:ride_sharing_user_app/features/safety_setup/controllers/safety_alert_controller.dart';
import 'package:ride_sharing_user_app/features/settings/domain/html_enum_types.dart';
import 'package:ride_sharing_user_app/features/settings/screens/policy_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/trip/screens/trip_details_screen.dart';
import 'package:ride_sharing_user_app/features/wallet/screens/wallet_screen.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/main.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class NotificationHelper {
  static Future<void> initialize(
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
  ) async {
    var androidInitialize =
        const AndroidInitializationSettings('notification_icon');
    var iOSInitialize = const DarwinInitializationSettings();
    var initializationsSettings = InitializationSettings(
      android: androidInitialize,
      iOS: iOSInitialize,
    );

    flutterLocalNotificationsPlugin.initialize(
      settings: initializationsSettings,
      onDidReceiveNotificationResponse: (NotificationResponse payload) async {
        return;
      },
      onDidReceiveBackgroundNotificationResponse: myBackgroundMessageReceiver,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      AndroidInitializationSettings androidInitialize =
          const AndroidInitializationSettings('notification_icon');
      var iOSInitialize = const DarwinInitializationSettings();
      var initializationsSettings = InitializationSettings(
        android: androidInitialize,
        iOS: iOSInitialize,
      );

      flutterLocalNotificationsPlugin.initialize(
        settings: initializationsSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse response) async {
          notificationRouteCheck(message.data);
          return;
        },
        onDidReceiveBackgroundNotificationResponse: myBackgroundMessageReceiver,
      );

      customPrint('onMessage: ${message.data}');

      if (!(_isUserAppInMaintenance()) ||
          Get.find<ConfigController>().haveOngoingRides()) {
        if (Get.find<ConfigController>().pusherConnectionStatus == null ||
            Get.find<ConfigController>().pusherConnectionStatus ==
                'Disconnected') {
          if (message.data['action'] == 'driver_on_the_way') {
            await _openRideAcceptedOrDriverOnWay(message.data);
          } else if (message.data['action'] == "new_message") {
            Get.find<MessageController>()
                .getConversation(message.data['type'], 1);
          } else if (message.data['action'] == 'trip_started' &&
              message.data['type'] == 'ride_request') {
            await _openRideStarted(message.data);
          } else if ((message.data['action'] == 'trip_resumed' ||
                  message.data['action'] == 'trip_paused') &&
              message.data['type'] == 'ride_request') {
            Get.find<RideController>()
                .getRideDetails(message.data['ride_request_id']);
          } else if (message.data['action'] == 'trip_started' &&
              message.data['type'] == AppConstants.parcel) {
            Get.find<MapController>().getPolyline();
            Get.find<ParcelController>()
                .updateParcelState(ParcelDeliveryState.parcelOngoing);

            if (Get.find<RideController>().tripDetails == null) {
              Get.find<RideController>()
                  .getRideDetails(message.data['ride_request_id'])
                  .then((value) {
                if (Get.find<RideController>()
                        .tripDetails!
                        .parcelInformation!
                        .payer ==
                    'sender') {
                  Get.find<RideController>()
                      .getFinalFare(message.data['ride_request_id'])
                      .then((value) {
                    if (value.statusCode == 200) {
                      Get.find<MapController>().notifyMapController();
                      Get.off(() => const PaymentScreen(fromParcel: true));
                    }
                  });
                }
              });
            } else {
              if (Get.find<RideController>()
                      .tripDetails!
                      .parcelInformation!
                      .payer ==
                  'sender') {
                Get.find<RideController>()
                    .getFinalFare(message.data['ride_request_id'])
                    .then((value) {
                  if (value.statusCode == 200) {
                    Get.find<MapController>().notifyMapController();
                    Get.off(() => const PaymentScreen(fromParcel: true));
                  }
                });
              }
            }
          } else if (message.data['action'] == 'payment_successful') {
            await _openPaymentSuccessful(message.data);
          } else if (message.data['action'] == 'trip_completed' &&
              message.data['type'] == 'ride_request') {
            await _openRideCompleted(message.data);
          } else if (message.data['action'] == 'trip_completed' ||
              message.data['action'] == 'parcel_completed') {
            if (message.data['action'] == 'trip_completed') {
              await _openRidePaidReviewOrDashboard(message.data);
            } else {
              Get.find<RideController>().clearRideDetails();

              if (Get.find<ConfigController>().config!.reviewStatus!) {
                Get.offAll(
                    ReviewScreen(tripId: message.data['ride_request_id']));
              } else {
                Get.offAll(const DashboardScreen());
              }
            }
          } else if (message.data['action'] == 'trip_canceled') {
            Get.find<SafetyAlertController>().cancelDriverNeedSafetyStream();
            Get.offAll(const DashboardScreen());
          } else if (message.data['action'] == 'received_new_bid') {
            Get.find<RideController>()
                .getBiddingList(message.data['ride_request_id'], 1)
                .then((value) {
              if (value.statusCode == 200) {
                Get.find<RideController>().biddingList.length != 1
                    ? Get.back()
                    : null;

                Get.dialog(
                  barrierDismissible: true,
                  barrierColor: Colors.black.withValues(alpha: 0.5),
                  transitionDuration: const Duration(milliseconds: 500),
                  DriverRideRequestDialog(
                      tripId: message.data['ride_request_id']),
                );
              }
            });
          } else if (message.data['action'] == 'level_up') {
            Get.find<LevelController>().getProfileLevelInfo();

            showDialog(
              context: Get.context!,
              barrierDismissible: false,
              builder: (_) => LevelCompleteDialogWidget(
                levelName: message.data['next_level'],
                rewardType: message.data['reward_type'],
                reward: message.data['reward_amount'],
              ),
            );
          } else if (message.data['action'] == 'driver_canceled_ride_request') {
            Get.find<RideController>()
                .getBiddingList(message.data['ride_request_id'], 1)
                .then((value) {
              if (value.statusCode == 200) {
                if (Get.find<RideController>().biddingList.isEmpty &&
                    Get.isDialogOpen!) {
                  Get.back();
                }
              }
            });
          } else if (message.data['action'] == 'parcel_canceled') {
            Get.offAll(const DashboardScreen());
          } else if (message.data['action'] == 'parcel_returned') {
            Get.find<RideController>()
                .getRideDetails(message.data['ride_request_id']);
            Get.find<ParcelController>().getRunningParcelList();
          } else if (message.data['action'] == 'referral_reward_received') {
            Get.find<ReferAndEarnController>().getEarningHistoryList(1);
            Get.find<ProfileController>().getProfileInfo();
          } else if (message.data['action'] == 'safety_problem_resolved') {
            Get.find<SafetyAlertController>()
                .getSafetyAlertDetails(message.data['ride_request_id']);
          } else if (message.data['action'] == 'trip_accepted') {
            await _openRideAcceptedOrDriverOnWay(message.data);
          } else if (message.data['action'] ==
              'parcel_canceled_after_trip_started') {
            Get.offAll(const DashboardScreen());
          }
        } else {
          if (message.data['action'] == 'driver_on_the_way') {
            await _openRideAcceptedOrDriverOnWay(message.data);
          } else if (message.data['action'] == 'trip_accepted') {
            await _openRideAcceptedOrDriverOnWay(message.data);
          } else if (message.data['action'] == 'trip_started' &&
              message.data['type'] == 'ride_request') {
            await _openRideStarted(message.data);
          } else if (message.data['action'] == 'trip_completed' &&
              message.data['type'] == 'ride_request') {
            await _openRideCompleted(message.data);
          } else if (message.data['action'] == 'payment_successful') {
            await _openPaymentSuccessful(message.data);
          } else if (message.data['action'] == 'received_new_bid') {
            Get.find<RideController>()
                .getBiddingList(message.data['ride_request_id'], 1)
                .then((value) {
              if (value.statusCode == 200) {
                Get.find<RideController>().biddingList.length != 1
                    ? Get.back()
                    : null;

                Get.dialog(
                  barrierDismissible: true,
                  barrierColor: Colors.black.withValues(alpha: 0.5),
                  transitionDuration: const Duration(milliseconds: 500),
                  DriverRideRequestDialog(
                      tripId: message.data['ride_request_id']),
                );
              }
            });
          } else if ((message.data['action'] == 'trip_resumed' ||
                  message.data['action'] == 'trip_paused') &&
              message.data['type'] == 'ride_request') {
            Get.find<RideController>()
                .getRideDetails(message.data['ride_request_id']);
          } else if (message.data['action'] == 'level_up') {
            Get.find<LevelController>().getProfileLevelInfo();

            showDialog(
              context: Get.context!,
              barrierDismissible: false,
              builder: (_) => LevelCompleteDialogWidget(
                levelName: message.data['next_level'],
                rewardType: message.data['reward_type'],
                reward: message.data['reward_amount'],
              ),
            );
          } else if (message.data['action'] == 'driver_canceled_ride_request') {
            Get.find<RideController>()
                .getBiddingList(message.data['ride_request_id'], 1)
                .then((value) {
              if (value.statusCode == 200) {}
            });
          } else if (message.data['action'] == 'parcel_canceled') {
            Get.offAll(const DashboardScreen());
          } else if (message.data['action'] == 'parcel_returned') {
            Get.find<RideController>()
                .getRideDetails(message.data['ride_request_id']);
            Get.find<ParcelController>().getRunningParcelList();
          } else if (message.data['action'] == 'referral_reward_received') {
            Get.find<ReferAndEarnController>().getEarningHistoryList(1);
            Get.find<ProfileController>().getProfileInfo();
          } else if (message.data['action'] == 'safety_problem_resolved') {
            Get.find<SafetyAlertController>()
                .getSafetyAlertDetails(message.data['ride_request_id']);
          }
        }

        if (!(message.data['type'] == 'maintenance_mode_on' ||
            message.data['type'] == 'maintenance_mode_off')) {
          if (message.data['status'] == '1') {
            NotificationHelper.showNotification(
              message,
              flutterLocalNotificationsPlugin,
              true,
            );
          }
        }
      }

      if (message.data['type'] == 'maintenance_mode_on' ||
          message.data['type'] == 'maintenance_mode_off') {
        Get.find<ConfigController>().getConfigData();
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      customPrint('onOpenApp: ${message.data}');
      notificationRouteCheck(message.data);
    });
  }

  static bool _isUserAppInMaintenance() {
    return Get.find<ConfigController>().config!.maintenanceMode != null &&
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
            1;
  }

  static Future<void> _openRideAcceptedOrDriverOnWay(
      Map<String, dynamic> data) async {
    final String? rideRequestId = data['ride_request_id']?.toString();

    if (rideRequestId == null || rideRequestId.isEmpty) {
      return;
    }

    final Response response =
        await Get.find<RideController>().getRideDetails(rideRequestId);

    if (response.statusCode == 200) {
      if (data['type'] == AppConstants.parcel) {
        Get.find<ParcelController>()
            .updateParcelState(ParcelDeliveryState.acceptRider);
        Get.find<RideController>().startLocationRecord();
        Get.find<MapController>().notifyMapController();

        if (Get.currentRoute != '/MapScreen') {
          Get.offAll(() => const MapScreen(fromScreen: MapScreenType.parcel));
        }
      } else {
        Get.find<RideController>()
            .updateRideCurrentState(RideState.outForPickup);
        Get.find<RideController>().startLocationRecord();
        Get.find<MapController>().notifyMapController();

        if (Get.currentRoute != '/MapScreen') {
          Get.offAll(() => const MapScreen(fromScreen: MapScreenType.ride));
        }
      }
    }
  }

  static Future<void> _openRideStarted(Map<String, dynamic> data) async {
    final String? rideRequestId = data['ride_request_id']?.toString();

    if (rideRequestId == null || rideRequestId.isEmpty) {
      return;
    }

    final Response response =
        await Get.find<RideController>().getRideDetails(rideRequestId);

    if (response.statusCode == 200) {
      Get.find<SafetyAlertController>().checkDriverNeedSafety();
      Get.find<RideController>().updateRideCurrentState(RideState.ongoingRide);
      Get.find<RideController>().startLocationRecord();
      Get.find<MapController>().notifyMapController();

      if (Get.currentRoute != '/MapScreen') {
        Get.offAll(() => const MapScreen(fromScreen: MapScreenType.ride));
      }
    }
  }

  static Future<void> _openRideCompleted(Map<String, dynamic> data) async {
    final String? rideRequestId = data['ride_request_id']?.toString();

    if (rideRequestId == null || rideRequestId.isEmpty) {
      return;
    }

    Get.find<SafetyAlertController>().cancelDriverNeedSafetyStream();

    if (Get.isDialogOpen != true) {
      Get.dialog(
        const ConfirmationTripDialog(isStartedTrip: false),
        barrierDismissible: false,
      );
    }

    final Response response =
        await Get.find<RideController>().getFinalFare(rideRequestId);

    if (response.statusCode == 200) {
      Get.find<RideController>().updateRideCurrentState(RideState.completeRide);
      Get.find<MapController>().notifyMapController();

      if (Get.currentRoute != '/PaymentScreen') {
        Get.off(() => const PaymentScreen());
      }
    }
  }

  static Future<void> _openRidePaidReviewOrDashboard(
      Map<String, dynamic> data) async {
    final String? rideRequestId = data['ride_request_id']?.toString();

    if (rideRequestId == null || rideRequestId.isEmpty) {
      return;
    }

    if (Get.find<ConfigController>().config!.reviewStatus!) {
      Get.offAll(() => ReviewScreen(tripId: rideRequestId));
    } else {
      Get.find<RideController>().clearRideDetails();
      Get.offAll(() => const DashboardScreen());
    }
  }

  static Future<void> _openPaymentSuccessful(Map<String, dynamic> data) async {
    final String? rideRequestId = data['ride_request_id']?.toString();

    if (rideRequestId == null || rideRequestId.isEmpty) {
      return;
    }

    if (data['type'] == 'ride_request') {
      if (Get.find<ConfigController>().config!.reviewStatus!) {
        Get.off(() => ReviewScreen(tripId: rideRequestId));
      } else {
        Get.offAll(() => const DashboardScreen());
        Get.find<RideController>().tripDetails = null;
      }
    } else {
      Get.find<RideController>().getRideDetails(rideRequestId).then((_) {
        if (Get.find<RideController>().tripDetails?.parcelInformation?.payer ==
            'sender') {
          Get.find<ParcelController>()
              .updateParcelState(ParcelDeliveryState.parcelOngoing);
          Get.find<RideController>().startLocationRecord();
          Get.offAll(() => const MapScreen(fromScreen: MapScreenType.parcel));
        } else {
          Get.offAll(() => const DashboardScreen());
          Get.find<RideController>().tripDetails = null;
        }
      });
    }
  }

  static Future<void> hintForBetterServiceLocationTurnOn({String? body}) async {
    BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body ??
          'When your\'re riding with ${AppConstants.appName}, your location is being collected for faster pick-ups and safety features. Manage permissions in your device\'s settings',
      htmlFormatBigText: true,
      contentTitle: 'Faster pick-ups, safer trips',
      htmlFormatContentTitle: true,
    );

    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'hexaride',
      'hexaride',
      channelDescription: 'progress channel description',
      styleInformation: bigTextStyleInformation,
      channelShowBadge: true,
      importance: Importance.max,
      priority: Priority.high,
      onlyAlertOnce: true,
      showProgress: false,
      color: const Color(0xFF00A08D),
    );

    var platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    flutterLocalNotificationsPlugin.show(
      id: 0,
      title: 'Faster pick-ups, safer trips',
      body: body ??
          'When your\'re riding with ${AppConstants.appName}, your location is being collected for faster pick-ups and safety features. Manage permissions in your device\'s settings',
      notificationDetails: platformChannelSpecifics,
      payload: 'item x',
    );
  }

  static Future<void> showNotification(
    RemoteMessage message,
    FlutterLocalNotificationsPlugin fln,
    bool data,
  ) async {
    String title = message.data['title'];
    String body = message.data['body'];
    String? orderID = message.data['order_id'];

    String? image = (message.data['image'] != null &&
            message.data['image'].isNotEmpty)
        ? message.data['image'].startsWith('http')
            ? message.data['image']
            : '${AppConstants.baseUrl}/storage/app/public/notification/${message.data['image']}'
        : null;

    try {
      await showBigPictureNotificationHiddenLargeIcon(
        title,
        body,
        orderID,
        image,
        fln,
      );
    } catch (e) {
      await showBigPictureNotificationHiddenLargeIcon(
        title,
        body,
        orderID,
        null,
        fln,
      );
      customPrint('Failed to show notification: ${e.toString()}');
    }
  }

  static Future<void> showBigPictureNotificationHiddenLargeIcon(
    String title,
    String body,
    String? orderID,
    String? image,
    FlutterLocalNotificationsPlugin fln,
  ) async {
    String? largeIconPath;
    String? bigPicturePath;
    BigPictureStyleInformation? bigPictureStyleInformation;
    BigTextStyleInformation? bigTextStyleInformation;

    if (image != null && !GetPlatform.isWeb) {
      largeIconPath = await _downloadAndSaveFile(image, 'largeIcon');
      bigPicturePath = largeIconPath;

      bigPictureStyleInformation = BigPictureStyleInformation(
        FilePathAndroidBitmap(bigPicturePath),
        hideExpandedLargeIcon: true,
        contentTitle: title,
        htmlFormatContentTitle: true,
        summaryText: body,
        htmlFormatSummaryText: true,
      );
    } else {
      bigTextStyleInformation = BigTextStyleInformation(
        body,
        htmlFormatBigText: true,
        contentTitle: title,
        htmlFormatContentTitle: true,
      );
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'hexaride',
      'hexaride',
      priority: Priority.max,
      importance: Importance.max,
      playSound: true,
      largeIcon:
          largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
      styleInformation: largeIconPath != null
          ? bigPictureStyleInformation
          : bigTextStyleInformation,
      sound: const RawResourceAndroidNotificationSound('notification'),
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await fln.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: orderID,
    );
  }

  static Future<String> _downloadAndSaveFile(
      String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  static void notificationRouteCheck(
    Map<String, dynamic> data, {
    bool formSplash = false,
    String? userName,
  }) {
    if (data['action'] == "new_message") {
      Get.find<MessageController>().getConversation(data['type'], 1);
      _toRoute(
        formSplash,
        MessageScreen(
          channelId: data['type'],
          tripId: data['ride_request_id'],
          userName: userName ?? data['user_name'],
        ),
      );
    } else if (data['action'] == 'driver_on_the_way') {
      notificationToRouteNavigate(data['ride_request_id'], formSplash);
    } else if (data['action'] == 'trip_accepted') {
      notificationToRouteNavigate(data['ride_request_id'], formSplash);
    } else if (data['action'] == 'trip_started' &&
        data['type'] == 'ride_request') {
      notificationToRouteNavigate(data['ride_request_id'], formSplash);
    } else if ((data['action'] == 'trip_resumed' ||
            data['action'] == 'trip_paused') &&
        data['type'] == 'ride_request') {
      notificationToRouteNavigate(data['ride_request_id'], formSplash);
    } else if (data['action'] == 'trip_started' &&
        data['type'] == AppConstants.parcel) {
      notificationToRouteNavigate(data['ride_request_id'], formSplash);
    } else if (data['action'] == 'payment_successful') {
      notificationToRouteNavigate(data['ride_request_id'], formSplash);
    } else if (data['action'] == 'trip_completed' &&
        data['type'] == 'ride_request') {
      notificationToRouteNavigate(data['ride_request_id'], formSplash);
    } else if (data['action'] == 'trip_completed' ||
        data['action'] == 'parcel_completed') {
      notificationToRouteNavigate(data['ride_request_id'], formSplash);
    } else if (data['action'] == 'trip_canceled') {
      notificationToRouteNavigate(data['ride_request_id'], formSplash);
    } else if (data['action'] == 'received_new_bid') {
      Get.find<RideController>().getRideDetails(data['ride_request_id']).then(
            (value) => {
              if (Get.currentRoute != '/MapScreen')
                {
                  Get.find<RideController>()
                      .updateRideCurrentState(RideState.findingRider),
                  _toRoute(formSplash,
                      const MapScreen(fromScreen: MapScreenType.ride)),
                },
              Get.find<RideController>()
                  .getBiddingList(data['ride_request_id'], 1)
                  .then((value) async {
                if (value.statusCode == 200) {
                  Get.dialog(
                    barrierDismissible: true,
                    barrierColor: Colors.black.withValues(alpha: 0.5),
                    transitionDuration: const Duration(milliseconds: 500),
                    DriverRideRequestDialog(tripId: data['ride_request_id']),
                  );
                }
              })
            },
          );
    } else if (data['action'] == 'level_up') {
      Get.find<LevelController>().getProfileLevelInfo();

      if (formSplash) {
        _toRoute(formSplash, const DashboardScreen());
      }

      showDialog(
        context: Get.context!,
        barrierDismissible: false,
        builder: (_) => LevelCompleteDialogWidget(
          levelName: data['next_level'],
          rewardType: data['reward_type'],
          reward: data['reward_amount'],
        ),
      );
    } else if (data['action'] == 'privacy_policy_updated') {
      Get.find<ConfigController>().getConfigData().then((value) {
        _toRoute(
          formSplash,
          PolicyScreen(
            htmlType: HtmlType.privacyPolicy,
            image:
                Get.find<ConfigController>().config?.privacyPolicy?.image ?? '',
          ),
        );
      });
    } else if (data['action'] == 'legal_updated') {
      Get.find<ConfigController>().getConfigData().then((value) {
        _toRoute(
          formSplash,
          PolicyScreen(
            htmlType: HtmlType.legal,
            image: Get.find<ConfigController>().config?.legal?.image ?? '',
          ),
        );
      });
    } else if (data['action'] == 'terms_and_conditions_updated') {
      Get.find<ConfigController>().getConfigData().then((value) {
        _toRoute(
          formSplash,
          PolicyScreen(
            htmlType: HtmlType.termsAndConditions,
            image: Get.find<ConfigController>()
                    .config
                    ?.termsAndConditions
                    ?.image ??
                '',
          ),
        );
      });
    } else if (data['action'] == 'referral_reward_received') {
      Get.find<ReferAndEarnController>().updateCurrentTabIndex(1);
      _toRoute(formSplash, const ReferAndEarnScreen());
    } else if (data['action'] == 'parcel_returned') {
      _toRoute(formSplash, TripDetailsScreen(tripId: data['ride_request_id']));
    } else if (data['action'] == 'someone_used_your_code') {
      _toRoute(formSplash, const ReferAndEarnScreen());
    } else if (data['action'] == 'refund_accepted') {
      _toRoute(formSplash, TripDetailsScreen(tripId: data['ride_request_id']));
    } else if (data['action'] == 'refund_denied') {
      _toRoute(formSplash, TripDetailsScreen(tripId: data['ride_request_id']));
    } else if (data['action'] == 'refunded_to_wallet') {
      _toRoute(formSplash, const WalletScreen());
    } else if (data['action'] == 'refunded_as_coupon') {
      _toRoute(formSplash, MyOfferScreen(isCoupon: true));
    } else if (data['action'] == 'fund_added_by_admin') {
      _toRoute(formSplash, const WalletScreen());
    } else if (data['action'] == 'review_from_driver') {
      _toRoute(formSplash, TripDetailsScreen(tripId: data['ride_request_id']));
    } else if (data['action'] == 'withdraw_request_rejected') {
      _toRoute(formSplash, const WalletScreen());
    } else if (data['action'] == 'withdraw_request_reversed') {
      _toRoute(formSplash, const WalletScreen());
    } else if (data['action'] == 'safety_problem_resolved' &&
        data['type'] == 'safety_alert') {
      notificationToRouteNavigate(data['ride_request_id'], formSplash);
    } else if (data['action'] == 'fund_added_digitally') {
    } else {
      Get.find<BottomMenuController>().setTabIndex(0);
      Get.offAll(const DashboardScreen());
    }
  }

  static void notificationToRouteNavigate(String tripId, bool formSplash) {
    Get.find<RideController>().getRideDetails(tripId).then((value) {
      if (Get.find<RideController>().tripDetails == null) {
        return;
      }

      if (Get.find<RideController>().tripDetails!.type == AppConstants.parcel) {
        if (Get.find<RideController>().tripDetails!.currentStatus ==
                AppConstants.accepted ||
            Get.find<RideController>().tripDetails!.currentStatus ==
                AppConstants.ongoing) {
          if (Get.find<RideController>().tripDetails!.currentStatus ==
              AppConstants.accepted) {
            Get.find<ParcelController>()
                .updateParcelState(ParcelDeliveryState.acceptRider);
          } else {
            Get.find<ParcelController>()
                .updateParcelState(ParcelDeliveryState.parcelOngoing);
          }

          Get.find<MapController>().notifyMapController();

          if (Get.currentRoute != '/MapScreen') {
            _toRoute(
                formSplash, const MapScreen(fromScreen: MapScreenType.parcel));
          }
        } else if (Get.find<RideController>().tripDetails!.currentStatus ==
                AppConstants.cancelled ||
            (Get.find<RideController>().tripDetails!.currentStatus ==
                    AppConstants.completed &&
                Get.find<RideController>().tripDetails!.paymentStatus ==
                    AppConstants.paid)) {
          if (Get.currentRoute != '/TripDetailsScreen') {
            _toRoute(
              formSplash,
              TripDetailsScreen(
                tripId: tripId,
                fromNotification: true,
              ),
            );
          }
        } else if (Get.find<RideController>().tripDetails!.currentStatus ==
                AppConstants.completed &&
            Get.find<RideController>().tripDetails!.paymentStatus ==
                AppConstants.unPaid) {
          if (Get.currentRoute != '/PaymentScreen') {
            Get.find<RideController>().getFinalFare(tripId).then((_) {
              _toRoute(formSplash, const PaymentScreen(fromParcel: false));
            });
          }
        }
      } else {
        if (Get.find<RideController>().tripDetails!.currentStatus ==
                AppConstants.accepted ||
            Get.find<RideController>().tripDetails!.currentStatus ==
                AppConstants.outForPickup ||
            Get.find<RideController>().tripDetails!.currentStatus ==
                AppConstants.ongoing) {
          if (Get.find<RideController>().tripDetails!.currentStatus ==
              AppConstants.ongoing) {
            Get.find<RideController>()
                .updateRideCurrentState(RideState.ongoingRide);
          } else {
            Get.find<RideController>()
                .updateRideCurrentState(RideState.outForPickup);
          }

          Get.find<RideController>().startLocationRecord();
          Get.find<MapController>().notifyMapController();

          if (Get.currentRoute != '/MapScreen') {
            _toRoute(
                formSplash, const MapScreen(fromScreen: MapScreenType.ride));
          }
        } else if (Get.find<RideController>().tripDetails!.currentStatus ==
                AppConstants.cancelled ||
            (Get.find<RideController>().tripDetails!.currentStatus ==
                    AppConstants.completed &&
                Get.find<RideController>().tripDetails!.paymentStatus ==
                    AppConstants.paid)) {
          if (Get.find<RideController>().tripDetails!.currentStatus ==
                  AppConstants.completed &&
              Get.find<RideController>().tripDetails!.paymentStatus ==
                  AppConstants.paid &&
              Get.find<ConfigController>().config!.reviewStatus!) {
            _toRoute(formSplash, ReviewScreen(tripId: tripId));
          } else if (Get.currentRoute != '/TripDetailsScreen') {
            _toRoute(
              formSplash,
              TripDetailsScreen(
                tripId: tripId,
                fromNotification: true,
              ),
            );
          }
        } else if (Get.find<RideController>().tripDetails!.currentStatus ==
                AppConstants.completed &&
            Get.find<RideController>().tripDetails!.paymentStatus ==
                AppConstants.unPaid) {
          if (Get.currentRoute != '/PaymentScreen') {
            Get.find<RideController>().getFinalFare(tripId).then((_) {
              _toRoute(formSplash, const PaymentScreen(fromParcel: false));
            });
          }
        }
      }
    });
  }

  static Future _toRoute(bool formSplash, Widget page) async {
    if (formSplash) {
      await Get.offAll(() => page);
    } else {
      await Get.to(() => page);
    }
  }
}

Future<dynamic> myBackgroundMessageHandler(RemoteMessage remoteMessage) async {
  customPrint('onBackground: ${remoteMessage.data}');
}

Future<dynamic> myBackgroundMessageReceiver(
    NotificationResponse response) async {
  customPrint('onBackgroundClicked: ${response.payload}');
}
