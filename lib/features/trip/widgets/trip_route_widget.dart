import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/divider_widget.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';

class TripRouteWidget extends StatelessWidget {
  final String pickupAddress;
  final String destinationAddress;
  final String? extraOne;
  final String? extraTwo;
  final String? entrance;
  final bool fromCard;

  const TripRouteWidget({
    super.key,
    required this.pickupAddress,
    required this.destinationAddress,
    this.extraOne,
    this.extraTwo,
    this.entrance,
    this.fromCard = false,
  });

  String _localizedText({
    required String pt,
    required String en,
    required String es,
  }) {
    final String languageCode = Get.locale?.languageCode.toLowerCase() ?? 'pt';

    if (languageCode == 'es') {
      return es;
    }

    if (languageCode == 'en') {
      return en;
    }

    return pt;
  }

  Widget _routeMarker({
    required BuildContext context,
    required String image,
    bool applyColor = true,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      child: Image.asset(
        image,
        width: Dimensions.iconSizeMedium,
        color: applyColor ? Theme.of(context).primaryColor : null,
      ),
    );
  }

  Widget _routeDivider({double height = 34}) {
    return SizedBox(
      height: height,
      width: 10,
      child: const CustomDivider(
        height: 2,
        dashWidth: 1,
        axis: Axis.vertical,
      ),
    );
  }

  Widget _addressBlock({
    required BuildContext context,
    required String title,
    required String address,
    bool isPrimary = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textSemiBold.copyWith(
            fontSize: Dimensions.fontSizeDefault,
            color: isPrimary
                ? Theme.of(context).primaryColor
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Text(
          address,
          maxLines: fromCard ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: textRegular.copyWith(
            fontSize: Dimensions.fontSizeSmall,
            color: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.color
                ?.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasExtraOne = extraOne != null && extraOne!.isNotEmpty;
    final bool hasExtraTwo = extraTwo != null && extraTwo!.isNotEmpty;
    final bool hasAnyExtra = hasExtraOne || hasExtraTwo;
    final bool hasEntrance = entrance != null && entrance!.isNotEmpty;

    return GetBuilder<RideController>(
      builder: (_) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: Dimensions.paddingSizeExtraSmall,
                right: Dimensions.paddingSizeSmall,
              ),
              child: Column(
                children: [
                  _routeMarker(
                    context: context,
                    image: Images.currentLocation,
                  ),
                  _routeDivider(height: hasAnyExtra ? 26 : 42),
                  if (hasAnyExtra) ...[
                    _routeMarker(
                      context: context,
                      image: Images.customerRouteIcon,
                      applyColor: false,
                    ),
                    _routeDivider(height: hasExtraTwo ? 24 : 30),
                  ],
                  _routeMarker(
                    context: context,
                    image: Images.customerDestinationIcon,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _addressBlock(
                    context: context,
                    title: _localizedText(
                      pt: 'Local de embarque',
                      en: 'Pickup location',
                      es: 'Lugar de embarque',
                    ),
                    address: pickupAddress,
                    isPrimary: true,
                  ),
                  SizedBox(
                    height: hasAnyExtra
                        ? Dimensions.paddingSizeDefault
                        : Dimensions.paddingSizeExtraLarge,
                  ),
                  if (hasExtraOne) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        left: Dimensions.paddingSizeExtraSmall,
                      ),
                      child: Text(
                        extraOne!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textRegular.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.75),
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                      ),
                    ),
                    if (hasExtraTwo)
                      const Padding(
                        padding: EdgeInsets.only(
                          left: Dimensions.paddingSizeExtraSmall,
                        ),
                        child: SizedBox(
                          height: 18,
                          width: 10,
                          child: CustomDivider(
                            height: 2,
                            dashWidth: 1,
                            axis: Axis.vertical,
                          ),
                        ),
                      ),
                  ],
                  if (hasExtraTwo) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        left: Dimensions.paddingSizeExtraSmall,
                      ),
                      child: Text(
                        extraTwo!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textRegular.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.75),
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                  ],
                  Padding(
                    padding: EdgeInsets.only(
                      top: fromCard ? Dimensions.paddingSizeSmall : 0,
                    ),
                    child: _addressBlock(
                      context: context,
                      title: _localizedText(
                        pt: 'Destino',
                        en: 'Destination',
                        es: 'Destino',
                      ),
                      address: destinationAddress,
                    ),
                  ),
                  if (hasEntrance) ...[
                    Divider(
                      color:
                          Theme.of(context).hintColor.withValues(alpha: 0.25),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 25,
                          child: Image.asset(Images.curvedArrow),
                        ),
                        const SizedBox(width: Dimensions.paddingSizeSmall),
                        Container(
                          transform: Matrix4.translationValues(0, 8, 0),
                          child: Text(
                            entrance!,
                            style: textRegular.copyWith(
                              fontSize: Dimensions.fontSizeDefault,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
