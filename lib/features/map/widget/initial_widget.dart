import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/custom_text_field.dart';
import 'package:ride_sharing_user_app/common_widgets/expandable_bottom_sheet.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/fare_input_widget.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/route_widget.dart';
import 'package:ride_sharing_user_app/features/payment/controllers/payment_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/widgets/ride_category.dart';
import 'package:ride_sharing_user_app/features/ride/widgets/trip_fare_summery.dart';
import 'package:ride_sharing_user_app/features/set_destination/widget/schedule_date_time_picker_widget.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/trip/screens/trip_details_screen.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/helper/ride_controller_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class InitialWidget extends StatefulWidget {
  final GlobalKey<ExpandableBottomSheetState> expandableKey;
  const InitialWidget({super.key, required this.expandableKey});

  @override
  State<InitialWidget> createState() => _InitialWidgetState();
}

class _InitialWidgetState extends State<InitialWidget> {
//  String? zoneExtraFareReason;

  @override
  void initState() {
    var rideController = Get.find<RideController>();
    if (Get.find<PaymentController>().paymentType == 'wallet' &&
        (rideController.discountAmount.toDouble() > 0
                ? rideController.discountFare
                : rideController.estimatedFare) >
            Get.find<ProfileController>()
                .profileModel!
                .data!
                .wallet!
                .walletBalance!) {
      Get.find<PaymentController>().setPaymentType(0);
    }
    //  zoneExtraFareReason = _getExtraFairReason(Get.find<ConfigController>().config?.zoneExtraFare, Get.find<LocationController>().zoneID);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideController>(builder: (rideController) {
      return GetBuilder<LocationController>(builder: (locationController) {
        return Column(mainAxisSize: MainAxisSize.min, children: [
          RideCategoryWidget(onTap: (value) async {
            if (rideController.isCouponApplicable) {
              await Future.delayed(const Duration(milliseconds: 500));
              widget.expandableKey.currentState?.expand(duration: 1000);
            } else {
              widget.expandableKey.currentState?.contract(duration: 500);
              widget.expandableKey.currentState?.expand(duration: 1000);
            }
          }),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Container(
            decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(Dimensions.paddingSizeSmall)),
            padding: EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeSmall,
                horizontal: Dimensions.paddingSizeDefault),
            child: Row(
                spacing: Dimensions.paddingSizeSmall,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('pickup_time'.tr,
                      style: textRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall)),
                  InkWell(
                    onTap: () {
                      if (Get.find<ConfigController>()
                              .config
                              ?.scheduleTripStatus ??
                          false) {
                        Get.bottomSheet(const ScheduleDateTimePickerWidget(),
                            enableDrag: false, isScrollControlled: true);
                      }
                    },
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width *
                            0.6, // Limit width to 60% of screen
                      ),
                      child: Row(
                          spacing: Dimensions.paddingSizeExtraSmall,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              rideController.rideType == RideType.scheduleRide
                                  ? Images.scheduleCalenderIcon
                                  : Images.clockIcon,
                              height: 14,
                              width: 14,
                            ),
                            Flexible(
                              child: Text(
                                rideController.rideType == RideType.scheduleRide
                                    ? '${'schedule'.tr}: ${DateFormat('d MMM y').format(RideControllerHelper.dateFormatToShow(rideController.scheduleTripDate))}, '
                                        '${DateFormat('hh:mm a').format(RideControllerHelper.timeFormatToShow(rideController.scheduleTripTime))}'
                                    : 'pickup_now'.tr,
                                style: textBold.copyWith(
                                    fontSize: Dimensions.fontSizeSmall,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            if (rideController.rideType == RideType.regularRide)
                              Icon(Icons.keyboard_arrow_down_outlined)
                          ]),
                    ),
                  )
                ]),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          if (rideController.pickupNoteText.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .inverseSurface
                      .withAlpha(10),
                  borderRadius:
                      BorderRadius.circular(Dimensions.paddingSizeSmall)),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    vertical: Dimensions.paddingSizeSmall,
                    horizontal: Dimensions.paddingSizeDefault),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${'pickup_note'.tr}: ',
                          style: textRegular.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .inverseSurface)),
                      Flexible(
                          child: Text(rideController.pickupNoteText,
                              style: textRegular))
                    ]),
              ),
            ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          RouteWidget(
            totalDistance: rideController.fareList.isEmpty
                ? '0'
                : rideController.fareList[rideController.rideCategoryIndex]
                        .estimatedDistance ??
                    '0',
            fromAddress: locationController.fromAddress?.address ?? '',
            extraOneAddress:
                locationController.extraRouteAddress?.address ?? '',
            extraTwoAddress:
                locationController.extraRouteTwoAddress?.address ?? '',
            toAddress: locationController.toAddress?.address ?? '',
            entrance: locationController.entranceController.text,
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          if (rideController
                  .fareList[rideController.rideCategoryIndex].extraFareReason !=
              '') ...[
            Text(
                '${'fares_are_a_bit_higher'.tr}${rideController.fareList[rideController.rideCategoryIndex].extraFareReason}',
                style: textRegular.copyWith(
                    color: Theme.of(context).colorScheme.inverseSurface,
                    fontSize: 11),
                textAlign: TextAlign.center),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          ],
          const SizedBox(height: Dimensions.paddingSizeSmall),
          TripFareSummery(
            tripFare: rideController.estimatedFare,
            fromParcel: false,
            discountFare: rideController.discountFare,
            discountAmount: rideController.discountAmount,
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          if (rideController.isCouponApplicable) ...[
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeSmall,
                    vertical: Dimensions.paddingSizeExtraSmall,
                  ),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(Dimensions.paddingSizeSmall),
                  ),
                  child: Text('coupon_applied'.tr,
                      style: textBold.copyWith(
                          color: Theme.of(context).primaryColor))),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
          ],
          _LokallyPointsPreRideVoucherSelector(
            expectedRewardType: 'ride_coupon',
            onExpandRequested: () async {
              await Future.delayed(const Duration(milliseconds: 250));
              widget.expandableKey.currentState?.expand(duration: 1000);
            },
          ),
          CustomTextField(
            prefix: false,
            borderRadius: Dimensions.radiusSmall,
            hintText: "add_note".tr,
            controller: rideController.noteController,
            onTap: () async {
              await Future.delayed(const Duration(milliseconds: 500));
              widget.expandableKey.currentState?.expand(duration: 1000);
            },
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          rideController.isLoading || rideController.isSubmit
              ? Center(
                  child: SpinKitCircle(
                      color: Theme.of(context).primaryColor, size: 40.0))
              : (Get.find<ConfigController>().config!.bidOnFare! &&
                      rideController.rideType != RideType.scheduleRide)
                  ? FareInputWidget(
                      expandableKey: widget.expandableKey,
                      fromRide: true,
                      fare: rideController.discountAmount.toDouble() > 0
                          ? rideController.discountFare.toString()
                          : rideController.estimatedFare.toString(),
                    )
                  : ButtonWidget(
                      buttonText: "find_rider".tr,
                      onPressed: () {
                        if (rideController.rideType == RideType.regularRide) {
                          _sendFindRiderRequest(rideController);
                        } else {
                          rideController
                              .submitRideRequest(
                                  rideController.noteController.text, false)
                              .then((value) {
                            if (value.statusCode == 200) {
                              Get.find<MapController>().initializeData();
                              showCustomSnackBar(
                                  '${'your_trip'.tr} #${rideController.tripDetails?.refId} ${'has_been_successfully_scheduled'.tr}',
                                  subMessage:
                                      'you_will_be_notified_when_a_driver_start_for_your'
                                          .tr);
                              Get.offAll(() => TripDetailsScreen(
                                  tripId:
                                      rideController.tripDetails?.id ?? ''));
                            }
                          });
                        }
                      }),
        ]);
      });
    });
  }

  // String? _getExtraFairReason(List<ZoneExtraFare>? list, String? zoneId){
  //   for(int i = 0; i < (list?.length ?? 0); i++) {
  //
  //     if(list?[i].zoneId == zoneId || list?[i].zoneId == 'all') {
  //       return list?[i].reason ?? '';
  //     }
  //   }
  //   return null;
  //
  // }

  void _sendFindRiderRequest(RideController rideController) {
    rideController
        .submitRideRequest(rideController.noteController.text, false)
        .then((value) {
      if (value.statusCode == 200) {
        Get.find<AuthController>().saveFindingRideCreatedTime();
        rideController.updateRideCurrentState(RideState.findingRider);
        Get.find<MapController>().initializeData();
        Get.find<MapController>().setOwnCurrentLocation(LatLng(
            Get.find<LocationController>().fromAddress?.latitude ?? 0,
            Get.find<LocationController>().fromAddress?.longitude ?? 0));
        Get.find<MapController>().notifyMapController();
      }
    });
  }
}

class _LokallyPointsPreRideVoucherSelector extends StatefulWidget {
  final String expectedRewardType;
  final Future<void> Function()? onExpandRequested;

  const _LokallyPointsPreRideVoucherSelector({
    required this.expectedRewardType,
    this.onExpandRequested,
  });

  @override
  State<_LokallyPointsPreRideVoucherSelector> createState() =>
      _LokallyPointsPreRideVoucherSelectorState();
}

class _LokallyPointsPreRideVoucherSelectorState
    extends State<_LokallyPointsPreRideVoucherSelector> {
  bool _isLoading = false;
  bool _hasLoaded = false;
  List<_LokallyPointsPreRideVoucher> _vouchers = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadVouchers);
  }

  Future<void> _loadVouchers() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Get.find<ApiClient>().getData(
        '/api/customer/points-club/vouchers',
      );

      final List<dynamic> rawItems = _extractVoucherList(response.body);
      final List<_LokallyPointsPreRideVoucher> parsed = rawItems
          .whereType<Map>()
          .map((item) => _LokallyPointsPreRideVoucher.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where(
            (voucher) =>
                voucher.status == 'available' &&
                voucher.rewardType == widget.expectedRewardType &&
                voucher.amount > 0,
          )
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _vouchers = parsed;
        _hasLoaded = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _vouchers = [];
        _hasLoaded = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> _extractVoucherList(dynamic body) {
    if (body is List) {
      return body;
    }

    if (body is! Map) {
      return [];
    }

    final List<String> listKeys = [
      'items',
      'vouchers',
      'data',
      'content',
      'results',
    ];

    for (final String key in listKeys) {
      final dynamic value = body[key];

      if (value is List) {
        return value;
      }

      if (value is Map) {
        final List<dynamic> nested = _extractVoucherList(value);

        if (nested.isNotEmpty) {
          return nested;
        }
      }
    }

    return [];
  }

  void _openVoucherModal() {
    if (_vouchers.isEmpty) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Dimensions.radiusLarge),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusOverLarge,
                    ),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                Text(
                  'Usar resgate do Clube',
                  textAlign: TextAlign.center,
                  style: textBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Text(
                  'Escolha um resgate disponível. Ele será aplicado automaticamente ao valor final real da corrida.',
                  textAlign: TextAlign.center,
                  style: textRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeLarge),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _vouchers.length,
                    itemBuilder: (context, index) {
                      final voucher = _vouchers[index];

                      return _LokallyPointsPreRideVoucherTile(
                        voucher: voucher,
                        onTap: () => _applyVoucher(voucher),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _applyVoucher(_LokallyPointsPreRideVoucher voucher) async {
    Get.find<RideController>().setLokallyPointsVoucherForFinalFare(
      voucherId: voucher.id,
      voucherCode: voucher.code,
      amount: voucher.amount,
      rewardType: voucher.rewardType,
    );

    Navigator.of(context).pop();

    if (widget.onExpandRequested != null) {
      await widget.onExpandRequested!.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideController>(
      builder: (rideController) {
        final bool hasSelectedVoucher =
            (rideController.selectedLokallyPointsVoucherId ?? '').isNotEmpty ||
                (rideController.selectedLokallyPointsVoucherCode ?? '')
                    .isNotEmpty;

        if (hasSelectedVoucher) {
          final double selectedAmount =
              rideController.selectedLokallyPointsVoucherAmount;

          return Container(
            width: double.infinity,
            margin:
                const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              border: Border.all(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resgate Clube de Pontos selecionado',
                        style: textSemiBold.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: Dimensions.fontSizeDefault,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if ((rideController
                                      .selectedLokallyPointsVoucherCode ??
                                  '')
                              .isNotEmpty)
                            rideController.selectedLokallyPointsVoucherCode!,
                          if (selectedAmount > 0)
                            PriceConverter.convertPrice(selectedAmount),
                        ].join(' • '),
                        style: textRobotoRegular.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Será aplicado automaticamente ao final da corrida.',
                        style: textRegular.copyWith(
                          color: Theme.of(context).hintColor,
                          fontSize: Dimensions.fontSizeExtraSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () =>
                      rideController.clearLokallyPointsVoucherForFinalFare(),
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.close_rounded,
                      color: Theme.of(context).hintColor,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (_isLoading && !_hasLoaded) {
          return Container(
            width: double.infinity,
            margin:
                const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            decoration: BoxDecoration(
              color: Theme.of(context).hintColor.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(
                  child: Text(
                    'Buscando resgates do Clube...',
                    style: textRegular.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: Dimensions.fontSizeSmall,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (_vouchers.isEmpty) {
          return const SizedBox();
        }

        return InkWell(
          onTap: _openVoucherModal,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          child: Container(
            width: double.infinity,
            margin:
                const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              border: Border.all(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                  ),
                  child: Icon(
                    Icons.card_giftcard_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 21,
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Você tem resgate do Clube de Pontos Lokally',
                        style: textSemiBold.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: Dimensions.fontSizeDefault,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_vouchers.length} resgate${_vouchers.length == 1 ? '' : 's'} disponível${_vouchers.length == 1 ? '' : 'is'} para esta corrida',
                        style: textRegular.copyWith(
                          color: Theme.of(context).hintColor,
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_right_rounded,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LokallyPointsPreRideVoucherTile extends StatelessWidget {
  final _LokallyPointsPreRideVoucher voucher;
  final VoidCallback onTap;

  const _LokallyPointsPreRideVoucherTile({
    required this.voucher,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      child: Container(
        margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(
          color: Theme.of(context).hintColor.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(
            color: Theme.of(context).hintColor.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.confirmation_number_rounded,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voucher.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textSemiBold.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: Dimensions.fontSizeDefault,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    voucher.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textRobotoRegular.copyWith(
                      color: Theme.of(context).hintColor,
                      fontSize: Dimensions.fontSizeSmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  PriceConverter.convertPrice(voucher.amount),
                  style: textRobotoBold.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontSize: Dimensions.fontSizeDefault,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Aplicar',
                  style: textSemiBold.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontSize: Dimensions.fontSizeSmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LokallyPointsPreRideVoucher {
  final String id;
  final String code;
  final String title;
  final String rewardType;
  final String status;
  final double amount;

  const _LokallyPointsPreRideVoucher({
    required this.id,
    required this.code,
    required this.title,
    required this.rewardType,
    required this.status,
    required this.amount,
  });

  factory _LokallyPointsPreRideVoucher.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> reward =
        json['reward'] is Map ? Map<String, dynamic>.from(json['reward']) : {};

    final String rewardType =
        (json['reward_type'] ?? json['type'] ?? reward['reward_type'] ?? '')
            .toString()
            .trim();

    final String title = (json['reward_title'] ??
            json['title'] ??
            reward['title'] ??
            'Resgate Clube de Pontos')
        .toString();

    return _LokallyPointsPreRideVoucher(
      id: (json['id'] ?? '').toString(),
      code: (json['voucher_code'] ?? json['code'] ?? '').toString(),
      title: title,
      rewardType: rewardType,
      status: (json['status'] ?? '').toString().trim().toLowerCase(),
      amount: _parseAmount(
        json['reference_value'] ??
            json['amount'] ??
            json['value'] ??
            reward['reference_value'],
      ),
    );
  }

  static double _parseAmount(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }
}
