import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/expandable_bottom_sheet.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/fare_input_widget.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/product_details_widget.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/route_widget.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/tolltip_widget.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/user_details_widget.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/who_will_pay_button.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class ParcelInfoDetailsWidget extends StatefulWidget {
  final GlobalKey<ExpandableBottomSheetState> expandableKey;

  const ParcelInfoDetailsWidget({
    super.key,
    required this.expandableKey,
  });

  @override
  State<ParcelInfoDetailsWidget> createState() =>
      _ParcelInfoDetailsWidgetState();
}

class _ParcelInfoDetailsWidgetState extends State<ParcelInfoDetailsWidget> {
  String _lokallyCleanParcelText(String? value) {
    final String text = (value ?? '').trim();

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '';
    }

    return text;
  }
  @override
  Widget build(BuildContext context) {
    return GetBuilder<ParcelController>(
      builder: (parcelController) {
        return GetBuilder<RideController>(
          builder: (rideController) {
            final bool isMarketplaceShipping =
                parcelController.isMarketplaceShippingFlow;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const TollTipWidget(
                      title: "delivery_details",
                      showInsight: false,
                    ),
                    if (!isMarketplaceShipping &&
                        (rideController
                                .parcelEstimatedFare?.data?.couponApplicable ??
                            false))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeSmall,
                          vertical: Dimensions.paddingSizeExtraSmall,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            Dimensions.paddingSizeSmall,
                          ),
                        ),
                        child: Text(
                          'coupon_applied'.tr,
                          style: textBold.copyWith(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                RouteWidget(
                  totalDistance: Get.find<RideController>()
                      .parcelEstimatedFare!
                      .data!
                      .estimatedDistance!
                      .toString(),
                  fromAddress:
                      _lokallyCleanParcelText(Get.find<ParcelController>().senderAddressController.text),
                  toAddress: Get.find<ParcelController>()
                      .receiverAddressController
                      .text,
                  extraOneAddress: '',
                  extraTwoAddress: '',
                  entrance: '',
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                const ProductDetailsWidget(),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                if (!isMarketplaceShipping) ...[
                  WhoWillPayButton(expandableKey: widget.expandableKey),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                ],
                UserDetailsWidget(
                  name: _lokallyCleanParcelText(parcelController.senderNameController.text),
                  contactNumber: _lokallyCleanParcelText(parcelController.senderContactController.text),
                  type: 'sender',
                ),
                UserDetailsWidget(
                  name: _lokallyCleanParcelText(parcelController.receiverNameController.text),
                  contactNumber:
                      _lokallyCleanParcelText(parcelController.receiverContactController.text),
                  type: 'receiver',
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                if (!isMarketplaceShipping &&
                    _lokallyCleanParcelText(rideController.parcelEstimatedFare?.data?.extraFareReason) !=
                        '') ...[
                  Text(
                    '${'fares_are_a_bit_higher'.tr}${_lokallyCleanParcelText(rideController.parcelEstimatedFare?.data?.extraFareReason)}',
                    style: textRegular.copyWith(
                      color: Theme.of(context).colorScheme.inverseSurface,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                ],
                if (rideController.pickupNoteText.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .inverseSurface
                          .withAlpha(10),
                      borderRadius: BorderRadius.circular(
                        Dimensions.paddingSizeSmall,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: Dimensions.paddingSizeSmall,
                        horizontal: Dimensions.paddingSizeDefault,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${'pickup_note'.tr}: ',
                            style: textRegular.copyWith(
                              color:
                                  Theme.of(context).colorScheme.inverseSurface,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              rideController.pickupNoteText,
                              style: textRegular,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isMarketplaceShipping)
                  MarketplaceShippingFareWidget(
                    expandableKey: widget.expandableKey,
                  )
                else
                  FareInputWidget(
                    expandableKey: widget.expandableKey,
                    fromRide: false,
                    fare: (((rideController.parcelEstimatedFare!.data!
                                        .extraFareFee ??
                                    0) >
                                0) ||
                            ((rideController.parcelEstimatedFare!.data!
                                        .surgeMultiplier ??
                                    0) >
                                0))
                        ? rideController
                            .parcelEstimatedFare!.data!.extraEstimatedFare
                            .toString()
                        : rideController
                            .parcelEstimatedFare!.data!.estimatedFare
                            .toString(),
                    discountAmount: (((rideController.parcelEstimatedFare!.data!
                                        .extraFareFee ??
                                    0) >
                                0) ||
                            ((rideController.parcelEstimatedFare!.data!
                                        .surgeMultiplier ??
                                    0) >
                                0))
                        ? rideController
                            .parcelEstimatedFare!.data!.extraDiscountAmount
                        : rideController
                            .parcelEstimatedFare!.data!.discountAmount,
                    discountFare: (((rideController.parcelEstimatedFare!.data!
                                        .extraFareFee ??
                                    0) >
                                0) ||
                            ((rideController.parcelEstimatedFare!.data!
                                        .surgeMultiplier ??
                                    0) >
                                0))
                        ? rideController
                            .parcelEstimatedFare!.data!.extraDiscountFare
                        : rideController
                            .parcelEstimatedFare!.data!.discountFare,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class MarketplaceShippingFareWidget extends StatelessWidget {
  final GlobalKey<ExpandableBottomSheetState> expandableKey;

  const MarketplaceShippingFareWidget({
    super.key,
    required this.expandableKey,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideController>(
      builder: (rideController) {
        return GetBuilder<ParcelController>(
          builder: (parcelController) {
            final double finalFare =
                parcelController.marketplaceShippingFinalFare;
            final bool isFree = parcelController.marketplaceShippingIsFree;

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                (rideController.isSubmit || parcelController.getSuggested)
                    ? Center(
                        child: SpinKitCircle(
                          color: Theme.of(context).primaryColor,
                          size: 40.0,
                        ),
                      )
                    : Expanded(
                        child: Column(
                          children: [
                            Divider(
                              color: Theme.of(context)
                                  .hintColor
                                  .withValues(alpha: 0.5),
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(
                                Dimensions.paddingSizeDefault,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusDefault,
                                ),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withValues(alpha: 0.14),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'PreÃ§o da tarifa',
                                          style: textRegular.copyWith(
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color
                                                ?.withValues(alpha: 0.86),
                                            fontSize:
                                                Dimensions.fontSizeDefault,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        isFree
                                            ? 'Frete GrÃ¡tis'
                                            : PriceConverter.convertPrice(
                                                finalFare,
                                              ),
                                        style: textRobotoMedium.copyWith(
                                          color: Theme.of(context).primaryColor,
                                          fontSize: Dimensions.fontSizeLarge,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: Dimensions.paddingSizeExtraSmall,
                                  ),
                                  Text(
                                    isFree
                                        ? 'Frete gratuito aplicado no pedido Marketplace.'
                                        : 'Pago no pedido pelo cliente.',
                                    style: textMedium.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withValues(alpha: 0.72),
                                      fontSize: Dimensions.fontSizeSmall,
                                    ),
                                  ),
                                  if (parcelController
                                      .marketplaceOrderNumber.isNotEmpty) ...[
                                    const SizedBox(
                                      height: Dimensions.paddingSizeExtraSmall,
                                    ),
                                    Text(
                                      'Pedido ${parcelController.marketplaceOrderNumber}',
                                      style: textRegular.copyWith(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                            ?.withValues(alpha: 0.58),
                                        fontSize: Dimensions.fontSizeExtraSmall,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(
                              height: Dimensions.paddingSizeSmall,
                            ),
                            ButtonWidget(
                              buttonText: 'find_deliveryman'.tr,
                              onPressed: () {
                                parcelController
                                    .getSuggestedCategoryList()
                                    .then((value) {
                                  if (value.statusCode == 200) {
                                    Get.find<AuthController>()
                                        .saveFindingRideCreatedTime();
                                    Get.find<MapController>().getPolyline();
                                    Get.find<ParcelController>()
                                        .updateParcelState(
                                      ParcelDeliveryState.suggestVehicle,
                                    );
                                    Get.find<ParcelController>()
                                        .focusOnBottomSheet(expandableKey);
                                  }
                                });

                                Get.find<MapController>().notifyMapController();
                              },
                              fontSize: Dimensions.fontSizeDefault,
                            ),
                          ],
                        ),
                      ),
              ],
            );
          },
        );
      },
    );
  }
}

