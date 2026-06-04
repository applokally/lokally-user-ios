import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/my_offer/screens/my_offer_screen.dart';
import 'package:ride_sharing_user_app/features/notification/controllers/notification_controller.dart';
import 'package:ride_sharing_user_app/features/notification/domain/models/notification_model.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/controllers/refer_and_earn_controller.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/screens/refer_and_earn_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_customer_order_list_screen.dart';
import 'package:ride_sharing_user_app/features/trip/screens/trip_details_screen.dart';
import 'package:ride_sharing_user_app/features/wallet/screens/wallet_screen.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class NotificationCard extends StatelessWidget {
  final Notifications notification;
  final Notifications? previousNotification;
  final Notifications? nextNotification;
  final int? index;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.nextNotification,
    required this.previousNotification,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    final int currentNotificationMinutes =
        calculateMinute(notification.createdAt);
    final bool isRead = notification.isRead ?? false;
    final String actionLabel = _notificationActionLabel(notification);

    return InkWell(
      borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
      onTap: () {
        Get.find<NotificationController>().sendReadStatus(
          notification.id ?? 0,
          index ?? 0,
        );
        _showNotificationDetails(context, actionLabel);
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (previousNotification == null) _dateLabel(context, notification),
        Container(
          decoration: BoxDecoration(
            color: Get.isDarkMode
                ? Theme.of(context).scaffoldBackgroundColor
                : Theme.of(context).hintColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            border: Border.all(
              color: isRead
                  ? Theme.of(context).hintColor.withValues(alpha: 0.08)
                  : Theme.of(context).primaryColor.withValues(alpha: 0.18),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: Dimensions.paddingSizeSmall,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
              decoration: BoxDecoration(
                color: isRead
                    ? Theme.of(context).hintColor.withValues(alpha: 0.10)
                    : Theme.of(context).primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
              child: Image.asset(
                _getIcons(notification.notificationType ?? ''),
                fit: BoxFit.contain,
                color: isRead
                    ? Theme.of(context).hintColor
                    : Theme.of(context).primaryColor,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        notification.title ?? '',
                        style: _noDecoration(
                            (isRead ? textMedium : textBold).copyWith(
                          fontSize: Dimensions.fontSizeDefault,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: isRead ? 0.75 : 0.95),
                        )),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                    Text(
                      currentNotificationMinutes < 1
                          ? 'Agora'
                          : currentNotificationMinutes < 60
                              ? '$currentNotificationMinutes min atrÃ¡s'
                              : _friendlyTime(notification.createdAt),
                      style: _noDecoration(textRegular.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.55),
                      )),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    notification.description ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _noDecoration(textRegular.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      height: 1.25,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: isRead ? 0.45 : 0.72),
                    )),
                  ),
                ],
              ),
            ),
          ]),
        ),
        if (((nextNotification == null) &&
            (previousNotification != null) &&
            (_notificationDate(notification) !=
                _notificationDate(previousNotification!))))
          _dateLabel(context, notification),
        if ((nextNotification != null) &&
            (_notificationDate(notification) !=
                _notificationDate(nextNotification!)))
          _dateLabel(context, nextNotification!),
      ]),
    );
  }

  void _showNotificationDetails(BuildContext context, String actionLabel) {
    Get.bottomSheet(
      Container(
        width: Get.width,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(Dimensions.radiusExtraLarge),
            topRight: Radius.circular(Dimensions.radiusExtraLarge),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeLarge,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: Get.height * 0.82),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).hintColor.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 46,
                      height: 46,
                      padding: const EdgeInsets.all(11),
                      margin: const EdgeInsets.only(
                          right: Dimensions.paddingSizeSmall),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .primaryColor
                            .withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(Dimensions.radiusDefault),
                      ),
                      child: Image.asset(
                        _getIcons(notification.notificationType ?? ''),
                        fit: BoxFit.contain,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title ?? '',
                            style: _noDecoration(textBold.copyWith(
                              fontSize: Dimensions.fontSizeLarge,
                              height: 1.15,
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            )),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _friendlyDateTime(notification.createdAt),
                            style: _noDecoration(textRegular.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.55),
                            )),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                  if (_notificationImageUrl(notification).isNotEmpty) ...[
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(Dimensions.radiusLarge),
                      child: Image.network(
                        _notificationImageUrl(notification),
                        width: Get.width,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeDefault),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      notification.description ?? '',
                      style: _noDecoration(textRegular.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        height: 1.35,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.75),
                      )),
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  Row(children: [
                    if (!(notification.isRead ?? false)) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Get.find<NotificationController>().sendReadStatus(
                              notification.id ?? 0,
                              index ?? 0,
                            );
                            Get.back();
                          },
                          child: Text(
                            'Marcar como lida',
                            style: _noDecoration(textMedium.copyWith(
                              color: Theme.of(context).primaryColor,
                            )),
                          ),
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                    ],
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        onPressed: () async {
                          final bool deleted =
                              await Get.find<NotificationController>()
                                  .deleteNotification(
                            notification.id ?? 0,
                            index ?? 0,
                          );

                          if (deleted && Get.isBottomSheetOpen == true) {
                            Get.back();
                          }
                        },
                        child: Text(
                          'Excluir',
                          style: _noDecoration(textMedium.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          )),
                        ),
                      ),
                    ),
                  ]),
                  if (actionLabel.isNotEmpty) ...[
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    SizedBox(
                      width: Get.width,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: Dimensions.paddingSizeDefault,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(Dimensions.radiusLarge),
                          ),
                        ),
                        onPressed: () => _openNotificationAction(notification),
                        child: Text(
                          actionLabel,
                          style: _noDecoration(
                              textBold.copyWith(color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _dateLabel(BuildContext context, Notifications item) {
    return Padding(
      padding: const EdgeInsets.only(
        top: Dimensions.paddingSizeSmall,
        bottom: Dimensions.paddingSizeExtraSmall,
      ),
      child: Text(
        _friendlyDateLabel(item.createdAt),
        style: _noDecoration(textMedium.copyWith(
          fontSize: Dimensions.fontSizeSmall,
          color: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.color
              ?.withValues(alpha: 0.45),
        )),
      ),
    );
  }
}

TextStyle _noDecoration(TextStyle style) {
  return style.copyWith(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );
}

DateTime _parseNotificationDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return DateTime.now();
  }

  return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _notificationDate(Notifications notification) {
  final DateTime date = _parseNotificationDate(notification.createdAt);
  return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
}

String _friendlyDateLabel(String? createdAt) {
  final DateTime date = _parseNotificationDate(createdAt);
  final DateTime today = DateTime.now();
  final DateTime yesterday = today.subtract(const Duration(days: 1));

  if (date.year == today.year &&
      date.month == today.month &&
      date.day == today.day) {
    return 'Hoje';
  }

  if (date.year == yesterday.year &&
      date.month == yesterday.month &&
      date.day == yesterday.day) {
    return 'Ontem';
  }

  return '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}';
}

String _friendlyTime(String? createdAt) {
  final DateTime date = _parseNotificationDate(createdAt);
  return '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
}

String _friendlyDateTime(String? createdAt) {
  if (createdAt == null || createdAt.trim().isEmpty) {
    return '';
  }

  return '${_friendlyDateLabel(createdAt)} Ã s ${_friendlyTime(createdAt)}';
}

String _notificationImageUrl(Notifications notification) {
  final String image = notification.image?.trim() ?? '';

  if (image.isEmpty || image == 'null') {
    return '';
  }

  if (image.startsWith('http://') || image.startsWith('https://')) {
    return image;
  }

  if (image.startsWith('/')) {
    return '${AppConstants.baseUrl}$image';
  }

  return '${AppConstants.baseUrl}/storage/app/public/push-notification/$image';
}

bool _isStoreServiceNotification(Notifications notification) {
  final String targetRoute = notification.firstValue(['target_route']);
  final String action = notification.firstValue(['action']);
  final String type = notification.firstValue(['type']);
  final String notificationType =
      notification.firstValue(['notification_type']);

  return targetRoute == 'store_service_chat' ||
      action == 'open_store_service_chat' ||
      type == 'store_service_tool' ||
      type == 'store_service_meeting' ||
      notificationType == 'lokally_meeting';
}

String _storeServiceOrderId(Notifications notification) {
  return notification.firstValue([
    'store_order_id',
    'store_service_order_id',
    'order_id',
    'ride_request_id',
    'related_id',
  ]);
}

String _notificationActionLabel(Notifications notification) {
  if (_isStoreServiceNotification(notification)) {
    return 'Abrir atendimento';
  }

  if (notification.action == 'referral_reward_received') {
    return 'Ver ganhos';
  }

  if (notification.action == 'someone_used_your_code' &&
      (Get.find<ConfigController>().config?.referralEarningStatus ?? false)) {
    return 'Ver indicaÃ§Ã£o';
  }

  if (notification.action == 'parcel_refund_request_approved' ||
      notification.action == 'parcel_refund_request_denied') {
    return 'Ver entrega';
  }

  if (notification.action == 'refunded_as_coupon') {
    return 'Ver cupons';
  }

  if (notification.action == 'refunded_to_wallet' ||
      notification.action == 'fund_added_by_admin' ||
      notification.action == 'fund_added_digitally' ||
      notification.notificationType == 'fund' ||
      notification.notificationType == 'withdraw_request') {
    return 'Ver carteira';
  }

  return '';
}

void _openNotificationAction(Notifications notification) {
  if (_isStoreServiceNotification(notification)) {
    final String orderId = _storeServiceOrderId(notification);

    Get.back();
    Get.to(
      () => StoreCustomerOrderListScreen(
        initialOrderId: orderId.isEmpty ? null : orderId,
      ),
    );
    return;
  }

  if (notification.action == 'referral_reward_received') {
    Get.back();
    Get.find<ReferAndEarnController>().updateCurrentTabIndex(1, isUpdate: true);
    Get.to(() => const ReferAndEarnScreen());
  } else if (notification.action == 'someone_used_your_code' &&
      (Get.find<ConfigController>().config?.referralEarningStatus ?? false)) {
    Get.back();
    Get.find<ReferAndEarnController>().updateCurrentTabIndex(0, isUpdate: true);
    Get.to(() => const ReferAndEarnScreen());
  } else if (notification.action == 'parcel_refund_request_approved' ||
      notification.action == 'parcel_refund_request_denied') {
    Get.back();
    Get.to(() => TripDetailsScreen(tripId: notification.rideRequestId ?? ''));
  } else if (notification.action == 'refunded_as_coupon') {
    Get.back();
    Get.to(() => MyOfferScreen(isCoupon: true));
  } else if (notification.action == 'refunded_to_wallet' ||
      notification.action == 'fund_added_by_admin' ||
      notification.action == 'fund_added_digitally' ||
      notification.notificationType == 'fund' ||
      notification.notificationType == 'withdraw_request') {
    Get.back();
    Get.to(() => const WalletScreen());
  }
}

String _getIcons(String notificationType) {
  switch (notificationType) {
    case 'trip':
      return Images.notificationTripIcon;

    case 'parcel':
      return Images.notificationParcelIcon;

    case 'coupon':
      return Images.notificationCouponIcon;

    case 'review':
      return Images.notificationReviewIcon;

    case 'referral_code':
      return Images.notificationReferralIcon;

    case 'safety_alert':
      return Images.notificationSafetyAlertIcon;

    case 'business_page':
      return Images.notificationBusinessIcon;

    case 'chatting':
      return Images.notificationChattingIcon;

    case 'level':
      return Images.notificationLevelIcon;

    case 'fund':
      return Images.notificationFundIcon;

    case 'withdraw_request':
      return Images.notificationWalletIcon;

    case 'store_order':
    case 'tracking':
    case 'quote':
    case 'schedule':
    case 'recurrence':
    case 'lokally_meeting':
      return Images.notificationOthersIcon;

    default:
      return Images.notificationOthersIcon;
  }
}

int calculateMinute(String? isoDateTime) {
  final DateTime dateTime = _parseNotificationDate(isoDateTime);
  return DateTime.now().difference(dateTime).inMinutes;
}
