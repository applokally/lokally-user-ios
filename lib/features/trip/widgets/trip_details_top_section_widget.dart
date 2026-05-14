import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/features/ride/widgets/fare_widget.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/trip/widgets/parcel_return_time_show_widget.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class TripDetailsTopSectionWidget extends StatelessWidget {
  final TripDetails? tripDetails;

  const TripDetailsTopSectionWidget({
    super.key,
    required this.tripDetails,
  });

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  DateTime? _parseServerDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final String normalized = value.trim().replaceFirst(' ', 'T');

    try {
      final DateTime parsed = DateTime.parse(normalized);

      final bool hasExplicitTimezone = normalized.endsWith('Z') ||
          RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(normalized);

      if (hasExplicitTimezone) {
        return parsed.toUtc().subtract(const Duration(hours: 3));
      }

      return parsed;
    } catch (_) {
      return null;
    }
  }

  String _formatBrazilDateTime(String? value) {
    final DateTime? date = _parseServerDate(value);

    if (date == null) {
      return value ?? '';
    }

    return '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year} às ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
  }

  String _formatBrazilTimeOnly(String? value) {
    final DateTime? date = _parseServerDate(value);

    if (date == null) {
      return value ?? '';
    }

    return '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
  }

  Widget _categoryImage(BuildContext context) {
    final bool isParcel = tripDetails?.type == AppConstants.parcel;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 108,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                child: isParcel
                    ? Container(
                        width: 76,
                        height: 76,
                        alignment: Alignment.center,
                        child: Image.asset(
                          Images.parcel,
                          height: 74,
                          width: 74,
                          fit: BoxFit.contain,
                        ),
                      )
                    : ImageWidget(
                        width: 76,
                        height: 76,
                        image:
                            '${Get.find<ConfigController>().config!.imageBaseUrl!.vehicleCategory!}/${tripDetails?.vehicleCategory?.image!}',
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
              Text(
                isParcel
                    ? 'parcel'.tr
                    : tripDetails?.vehicleCategory != null
                        ? tripDetails?.vehicleCategory?.name ?? ''
                        : '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textMedium.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .color!
                      .withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -4,
          right: 17,
          child: Container(
            height: 20,
            width: 20,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: tripDetails?.currentStatus == AppConstants.cancelled
                  ? Theme.of(context).colorScheme.error.withValues(alpha: 0.15)
                  : tripDetails?.currentStatus == AppConstants.completed
                      ? Theme.of(context)
                          .colorScheme
                          .surfaceTint
                          .withValues(alpha: 0.15)
                      : tripDetails?.currentStatus == AppConstants.returning
                          ? Theme.of(context)
                              .colorScheme
                              .surfaceContainer
                              .withValues(alpha: 0.15)
                          : tripDetails?.currentStatus == AppConstants.returned
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceTint
                                  .withValues(alpha: 0.15)
                              : Theme.of(context)
                                  .colorScheme
                                  .tertiaryContainer
                                  .withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: tripDetails?.currentStatus == AppConstants.cancelled
                ? Image.asset(
                    Images.crossIcon,
                    color: Theme.of(context).colorScheme.error,
                  )
                : tripDetails?.currentStatus == AppConstants.completed
                    ? Image.asset(
                        Images.selectedIcon,
                        color: Theme.of(context).colorScheme.surfaceTint,
                      )
                    : tripDetails?.currentStatus == AppConstants.returning
                        ? Image.asset(
                            Images.returnIcon,
                            color:
                                Theme.of(context).colorScheme.surfaceContainer,
                          )
                        : tripDetails?.currentStatus == AppConstants.returned
                            ? Image.asset(
                                Images.returnIcon,
                                color:
                                    Theme.of(context).colorScheme.surfaceTint,
                              )
                            : Image.asset(
                                Images.ongoingMarkerIcon,
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiaryContainer,
                              ),
          ),
        ),
      ],
    );
  }

  Widget _tripStatusText(BuildContext context) {
    final String prefix = 'your_trip_has_been'.tr.trim();
    final String status = (tripDetails?.currentStatus ?? '').tr.trim();

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          text: '$prefix ',
          style: textRegular.copyWith(
            color: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.color
                ?.withValues(alpha: 0.7),
          ),
          children: [
            TextSpan(
              text: status,
              style: textRegular.copyWith(
                color: _choseStatusColor(
                  tripDetails?.currentStatus,
                  context,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? pickupTime = tripDetails?.type == AppConstants.parcel
        ? tripDetails?.parcelStartTime
        : tripDetails?.rideStartTime;

    final String? dropOfTime = tripDetails?.type == AppConstants.parcel
        ? tripDetails?.parcelCompleteTime
        : tripDetails?.rideCompleteTime;

    return Column(
      children: [
        Container(
          width: Get.width,
          margin: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeSmall,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: Dimensions.paddingSizeDefault,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(Dimensions.paddingSizeDefault),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).hintColor.withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _categoryImage(context),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              if (tripDetails?.type == AppConstants.parcel &&
                  tripDetails?.parcelInformation?.parcelCategoryName != null)
                Text(
                  tripDetails?.parcelInformation?.parcelCategoryName ?? '',
                  style: textRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .color!
                        .withValues(alpha: 0.8),
                  ),
                ),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
              Text(
                _formatBrazilDateTime(tripDetails?.createdAt),
                style: textRegular.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
              if (tripDetails?.type == AppConstants.scheduleRequest &&
                  tripDetails?.currentStatus == AppConstants.pending)
                RichText(
                  text: TextSpan(
                    text: 'your_scheduled_trip_has_been'.tr,
                    children: [
                      TextSpan(
                        text: ' ${'created'.tr}. ',
                        style: textSemiBold.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium!.color,
                        ),
                      ),
                      TextSpan(text: 'please_wait_for_a_driver_to_start'.tr),
                    ],
                    style: textRegular.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .color!
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  textAlign: TextAlign.center,
                )
              else
                _tripStatusText(context),
              if (tripDetails?.currentStatus == AppConstants.returning &&
                  tripDetails?.returnTime != null) ...[
                ParcelReturnTimeShowWidget(tripDetails: tripDetails),
              ],
            ],
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        Text(
          _isShownPaidFare(tripDetails)
              ? 'your_trip_cost'.tr
              : 'estimated_trip_cost'.tr,
          style: textSemiBold.copyWith(
            color: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.color
                ?.withValues(alpha: 0.7),
            fontSize: Dimensions.fontSizeSmall,
          ),
        ),
        Text(
          PriceConverter.convertPrice(
            _isShownPaidFare(tripDetails)
                ? tripDetails!.paidFare!
                : (tripDetails!.discountActualFare! > 0
                    ? tripDetails!.discountActualFare!
                    : tripDetails!.actualFare!),
          ),
          style: textSemiBold.copyWith(
            color: Theme.of(context).primaryColor,
            fontSize: Dimensions.fontSizeOverLarge,
          ),
        ),
        if (tripDetails?.type == AppConstants.scheduleRequest &&
            (tripDetails?.currentStatus == AppConstants.pending ||
                tripDetails?.currentStatus == AppConstants.accepted))
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).hintColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Dimensions.paddingSizeThree),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeSmall,
              vertical: Dimensions.paddingSizeThree,
            ),
            child: Text(
              '${'pickup_time'.tr}: ${_formatBrazilDateTime(tripDetails?.scheduledAt)}',
              style: textRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.7),
              ),
            ),
          ),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        if (pickupTime != null || dropOfTime != null)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              color: Theme.of(context).hintColor.withValues(alpha: 0.08),
            ),
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            child: IntrinsicHeight(
              child: dropOfTime != null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (pickupTime != null) ...[
                          FareWidget(
                            title: 'pickup_time'.tr,
                            value: _formatBrazilTimeOnly(pickupTime),
                          ),
                          VerticalDivider(
                            color: Theme.of(context)
                                .hintColor
                                .withValues(alpha: 0.5),
                          ),
                        ],
                        FareWidget(
                          title: 'drop_off_time'.tr,
                          value: _formatBrazilTimeOnly(dropOfTime),
                        ),
                      ],
                    )
                  : Text(
                      '${'pickup_time'.tr}: ${_formatBrazilDateTime(pickupTime)}',
                    ),
            ),
          ),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: Dimensions.iconSizeMedium,
              child: Image.asset(
                Images.distanceCalculated,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeExtraSmall),
            Text(
              _isShownPaidFare(tripDetails)
                  ? 'total_distance'.tr
                  : 'estimated_distance'.tr,
              style: textRegular.copyWith(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.7),
              ),
            ),
            Text(
              ' - ${_isShownPaidFare(tripDetails) ? tripDetails?.actualDistance : tripDetails?.estimatedDistance} km',
              style: textRegular.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
        if (tripDetails?.type == AppConstants.parcel &&
            tripDetails?.returnFee != null &&
            tripDetails?.currentStatus == AppConstants.returning) ...[
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              color: Theme.of(context).hintColor.withValues(alpha: 0.08),
            ),
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'you_will_pay_return_fee'.tr,
                  style: textRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                  ),
                ),
                Text(
                  PriceConverter.convertPrice(tripDetails?.returnFee ?? 0),
                  style: textRobotoBold.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (tripDetails?.cancellationReason != null) ...[
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Container(
            width: Get.width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              color: Theme.of(context).hintColor.withValues(alpha: 0.08),
            ),
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'cancellation_reason'.tr,
                  style: textRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeThree),
                Row(
                  children: [
                    const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                    Container(
                      height: 3,
                      width: 3,
                      decoration: BoxDecoration(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeThree),
                    Flexible(
                      child: Text(
                        tripDetails?.cancellationReason ?? '',
                        style: textMedium.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

Color? _choseStatusColor(String? currentStatus, BuildContext context) {
  if (currentStatus == AppConstants.cancelled ||
      currentStatus == AppConstants.returning) {
    return Theme.of(context).colorScheme.error;
  } else if (currentStatus == AppConstants.returned) {
    return Colors.green;
  } else {
    return Theme.of(context).textTheme.bodyMedium?.color;
  }
}

bool _isShownPaidFare(TripDetails? tripDetails) {
  return (tripDetails?.currentStatus == AppConstants.cancelled ||
          tripDetails?.currentStatus == AppConstants.completed ||
          (tripDetails?.parcelInformation?.payer == 'sender' &&
              tripDetails?.currentStatus == AppConstants.ongoing) ||
          tripDetails?.currentStatus == AppConstants.returning ||
          tripDetails?.currentStatus == AppConstants.returned)
      ? true
      : false;
}
