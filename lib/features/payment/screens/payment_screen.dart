import 'dart:convert';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/route_widget.dart';
import 'package:ride_sharing_user_app/features/payment/screens/digital_payment_screen.dart';
import 'package:ride_sharing_user_app/features/payment/widget/apply_coupon.dart';
import 'package:ride_sharing_user_app/features/payment/widget/digital_card_payment_widget.dart';
import 'package:ride_sharing_user_app/features/payment/widget/payment_type_item_widget.dart';
import 'package:ride_sharing_user_app/features/payment/widget/tips_widget.dart';
import 'package:ride_sharing_user_app/features/ride/widgets/trip_fare_summery.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/localization/localization_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/coupon/controllers/coupon_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/payment/controllers/payment_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';

class PaymentScreen extends StatefulWidget {
  final bool fromParcel;
  const PaymentScreen({super.key, this.fromParcel = false});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  bool collapsed = false;
  TextEditingController tipsAmountController = TextEditingController();

  bool _isPayToDriverPayment() {
    return Get.find<RideController>().tripDetails?.isPayToDriverPayment ??
        false;
  }

  String _displayPaymentMethod() {
    return Get.find<RideController>().tripDetails?.displayPaymentMethod ??
        'cash'.tr;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Get.find<ProfileController>().profileModel?.data?.wallet == null) {
      Get.find<ProfileController>().getProfileInfo();
    }
    Get.find<PaymentController>().initPayment();
    Get.find<PaymentController>().getPaymentGetWayList();
    Get.find<PaymentController>().setPaymentByName(
        Get.find<RideController>().tripDetails?.paymentMethod ?? 'cash');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      Get.find<RideController>()
          .getRideDetails(Get.find<RideController>().currentTripDetails!.id!)
          .then((value) {
        if (Get.find<RideController>().currentTripDetails!.paymentStatus ==
            'paid') {
          Get.offAll(() => const DashboardScreen());
        } else {
          Get.find<RideController>()
              .getFinalFare(Get.find<RideController>().currentTripDetails!.id!);
          Get.find<PaymentController>().initPayment();
          Get.find<PaymentController>().getPaymentGetWayList();
          Get.find<PaymentController>().setPaymentByName(
              Get.find<RideController>().tripDetails?.paymentMethod ?? 'cash');
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tipsAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, val) async {
          Get.find<BottomMenuController>().navigateToDashboard();
          return;
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: false,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.white,
            child: GetBuilder<PaymentController>(
              builder: (paymentController) {
                tipsAmountController.text =
                    '${'tips'.tr}-${'\$${paymentController.tipAmount}'}';

                return Column(
                  children: [
                    AppBarWidget(
                      title: 'payment'.tr,
                      onBackPressed: () => Get.find<BottomMenuController>()
                          .navigateToDashboard(),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.white,
                        child: GetBuilder<CouponController>(
                          builder: (couponController) {
                            return ScrollConfiguration(
                              behavior: const _LokallyNoOverscrollBehavior(),
                              child: GetBuilder<RideController>(
                                builder: (rideController) {
                                  String firstRoute = '';
                                  String secondRoute = '';
                                  List<dynamic> extraRoute = [];

                                  if (rideController.tripDetails
                                              ?.intermediateAddresses !=
                                          null &&
                                      rideController.tripDetails
                                              ?.intermediateAddresses !=
                                          '["",""]') {
                                    extraRoute = jsonDecode(
                                      rideController
                                          .tripDetails!.intermediateAddresses!,
                                    );

                                    if (extraRoute.isNotEmpty) {
                                      firstRoute = extraRoute[0];
                                    }
                                    if (extraRoute.isNotEmpty &&
                                        extraRoute.length > 1) {
                                      secondRoute = extraRoute[1];
                                    }
                                  }

                                  final bool isPayToDriverPayment =
                                      rideController.tripDetails
                                              ?.isPayToDriverPayment ??
                                          false;
                                  final String displayPaymentMethod =
                                      rideController.tripDetails
                                              ?.displayPaymentMethod ??
                                          paymentController.paymentType.tr;

                                  return CustomScrollView(
                                    physics: const ClampingScrollPhysics(),
                                    keyboardDismissBehavior:
                                        ScrollViewKeyboardDismissBehavior
                                            .onDrag,
                                    slivers: [
                                      SliverToBoxAdapter(
                                        child: Container(
                                          width: double.infinity,
                                          color: Colors.white,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: Dimensions
                                                      .paddingSizeDefault,
                                                  vertical: Dimensions
                                                      .paddingSizeExtraLarge,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'payment'.tr,
                                                      style:
                                                          textSemiBold.copyWith(
                                                        color: Theme.of(context)
                                                            .primaryColor,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: Dimensions
                                                            .paddingSizeExtraSmall,
                                                        vertical: Dimensions
                                                            .paddingSizeThree,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .primaryColor
                                                            .withValues(
                                                              alpha: .2,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          Dimensions
                                                              .paddingSizeExtraSmall,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Text(
                                                            displayPaymentMethod,
                                                            style: textMedium
                                                                .copyWith(
                                                              color: Theme.of(
                                                                context,
                                                              ).primaryColor,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: Dimensions
                                                                .paddingSizeExtraSmall,
                                                          ),
                                                          SizedBox(
                                                            width: Dimensions
                                                                .iconSizeSmall,
                                                            child: Image.asset(
                                                              Images
                                                                  .paymentTypeIcon,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (isPayToDriverPayment)
                                                Container(
                                                  margin: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: Dimensions
                                                        .paddingSizeDefault,
                                                    vertical: Dimensions
                                                        .paddingSizeSmall,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    Dimensions
                                                        .paddingSizeDefault,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .primaryColor
                                                        .withValues(
                                                          alpha: 0.10,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      Dimensions.radiusLarge,
                                                    ),
                                                    border: Border.all(
                                                      color: Theme.of(context)
                                                          .primaryColor
                                                          .withValues(
                                                            alpha: 0.25,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Text(
                                                        'Aguardando confirmação do pagamento',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: textSemiBold
                                                            .copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                          fontSize: Dimensions
                                                              .fontSizeDefault,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: Dimensions
                                                            .paddingSizeSmall,
                                                      ),
                                                      Text(
                                                        'O motorista precisa confirmar o recebimento do pagamento para finalizar esta etapa.',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: textRegular
                                                            .copyWith(
                                                          color: Theme.of(
                                                            context,
                                                          )
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.color,
                                                          fontSize: Dimensions
                                                              .fontSizeSmall,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: Dimensions
                                                            .paddingSizeExtraSmall,
                                                      ),
                                                      Text(
                                                        'Forma escolhida: $displayPaymentMethod',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style:
                                                            textMedium.copyWith(
                                                          color: Theme.of(
                                                            context,
                                                          )
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.color,
                                                          fontSize: Dimensions
                                                              .fontSizeSmall,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text('this_trip_is'.tr),
                                                  const SizedBox(
                                                    width: Dimensions
                                                        .paddingSizeExtraSmall,
                                                  ),
                                                  if (rideController
                                                              .finalFare !=
                                                          null &&
                                                      rideController.finalFare!
                                                              .currentStatus !=
                                                          null)
                                                    Text(
                                                      rideController
                                                          .finalFare!
                                                          .currentStatus!
                                                          .capitalize!,
                                                      style:
                                                          textSemiBold.copyWith(
                                                        color: Theme.of(context)
                                                            .primaryColor,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              (rideController.finalFare != null)
                                                  ? Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        vertical: Dimensions
                                                            .paddingSizeDefault,
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            PriceConverter
                                                                .convertPrice(
                                                              rideController
                                                                      .finalFare!
                                                                      .paidFare! +
                                                                  double.parse(
                                                                    paymentController
                                                                        .tipAmount,
                                                                  ),
                                                            ),
                                                            style:
                                                                textRobotoMedium
                                                                    .copyWith(
                                                              fontSize: Dimensions
                                                                  .fontSizeOverLarge,
                                                              color: Theme.of(
                                                                context,
                                                              )
                                                                  .textTheme
                                                                  .bodyMedium!
                                                                  .color,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: Dimensions
                                                                .paddingSizeSmall,
                                                          ),
                                                          if (double.parse(
                                                                paymentController
                                                                    .tipAmount,
                                                              ) >
                                                              0)
                                                            Text(
                                                              '( ${'tips_added'.tr} )',
                                                            ),
                                                        ],
                                                      ),
                                                    )
                                                  : const SizedBox(),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'your'.tr,
                                                    style: textMedium.copyWith(
                                                      color: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium!
                                                          .color,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    width: Dimensions
                                                        .paddingSizeExtraSmall,
                                                  ),
                                                  Text(
                                                    'total_fare'.tr,
                                                    style:
                                                        textSemiBold.copyWith(
                                                      color: Theme.of(context)
                                                          .primaryColor,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    width: Dimensions
                                                        .paddingSizeExtraSmall,
                                                  ),
                                                  Text(
                                                    'for_this_trip'.tr,
                                                    style: textMedium.copyWith(
                                                      color: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium!
                                                          .color,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (!isPayToDriverPayment)
                                                Row(
                                                  crossAxisAlignment:
                                                      paymentController
                                                                  .paymentTypeIndex ==
                                                              2
                                                          ? CrossAxisAlignment
                                                              .end
                                                          : CrossAxisAlignment
                                                              .center,
                                                  children: [
                                                    Expanded(
                                                      child: ListView.builder(
                                                        shrinkWrap: true,
                                                        physics:
                                                            const NeverScrollableScrollPhysics(),
                                                        itemCount:
                                                            paymentController
                                                                .paymentTypeList
                                                                .length,
                                                        itemBuilder:
                                                            (context, index) {
                                                          return PaymentTypeItem(
                                                            title: paymentController
                                                                    .paymentTypeList[
                                                                index],
                                                            index: index,
                                                            selectedIndex:
                                                                paymentController
                                                                    .paymentTypeIndex,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    paymentController
                                                                .paymentTypeIndex ==
                                                            2
                                                        ? GetBuilder<
                                                            ProfileController>(
                                                            builder:
                                                                (profileController) {
                                                              return Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                  Dimensions
                                                                      .paddingSizeDefault,
                                                                ),
                                                                child:
                                                                    Text.rich(
                                                                  TextSpan(
                                                                    children: [
                                                                      TextSpan(
                                                                        text:
                                                                            '${'available'.tr}: ',
                                                                        style: textRegular
                                                                            .copyWith(
                                                                          color:
                                                                              Theme.of(
                                                                            context,
                                                                          ).hintColor,
                                                                        ),
                                                                      ),
                                                                      TextSpan(
                                                                        text: PriceConverter
                                                                            .convertPrice(
                                                                          profileController.profileModel?.data?.wallet?.walletBalance ??
                                                                              0,
                                                                        ),
                                                                        style: textRobotoMedium
                                                                            .copyWith(
                                                                          color:
                                                                              Theme.of(
                                                                            context,
                                                                          ).hintColor,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          )
                                                        : const SizedBox(),
                                                  ],
                                                ),
                                              if (!isPayToDriverPayment)
                                                paymentController
                                                            .paymentTypeIndex ==
                                                        1
                                                    ? Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                          left: Dimensions
                                                              .paddingSizeLarge,
                                                        ),
                                                        child: SizedBox(
                                                          height: 105,
                                                          child:
                                                              ListView.builder(
                                                            itemCount:
                                                                paymentController
                                                                    .paymentGateways
                                                                    ?.length,
                                                            padding:
                                                                EdgeInsets.zero,
                                                            scrollDirection:
                                                                Axis.horizontal,
                                                            itemBuilder:
                                                                (context,
                                                                    index) {
                                                              return DigitalCardPaymentWidget(
                                                                digitalPaymentModel:
                                                                    paymentController
                                                                            .paymentGateways![
                                                                        index],
                                                                index: index,
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      )
                                                    : const SizedBox(),
                                              if (!isPayToDriverPayment)
                                                paymentController
                                                            .paymentTypeIndex ==
                                                        1
                                                    ? Container(
                                                        width: MediaQuery.of(
                                                                context)
                                                            .size
                                                            .width,
                                                        margin: const EdgeInsets
                                                            .only(
                                                          left: Dimensions
                                                              .paddingSizeDefault,
                                                          right: Dimensions
                                                              .paddingSizeDefault,
                                                          bottom: Dimensions
                                                              .paddingSizeDefault,
                                                          top: Dimensions
                                                              .paddingSizeExtraSmall,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                            Dimensions
                                                                .paddingSizeExtraSmall,
                                                          ),
                                                          border: Border.all(
                                                            width: .5,
                                                            color: Theme.of(
                                                              context,
                                                            )
                                                                .primaryColor
                                                                .withValues(
                                                                  alpha: .9,
                                                                ),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: SizedBox(
                                                                child: Padding(
                                                                  padding:
                                                                      EdgeInsets
                                                                          .only(
                                                                    left: Get.find<LocalizationController>()
                                                                            .isLtr
                                                                        ? Dimensions
                                                                            .paddingSizeExtraSmall
                                                                        : 0,
                                                                    right: Get.find<LocalizationController>()
                                                                            .isLtr
                                                                        ? 0
                                                                        : Dimensions
                                                                            .paddingSizeExtraSmall,
                                                                  ),
                                                                  child:
                                                                      Padding(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                      horizontal:
                                                                          Dimensions
                                                                              .iconSizeSmall,
                                                                      vertical:
                                                                          Dimensions
                                                                              .paddingSizeSmall,
                                                                    ),
                                                                    child: Text(
                                                                      (paymentController.tipAmount == '0' ||
                                                                              paymentController.tipAmount.isEmpty)
                                                                          ? 'give_tips'.tr
                                                                          : '${'tips'.tr}: ${PriceConverter.convertPrice(double.parse(paymentController.tipAmount))}',
                                                                      style: textRobotoMedium
                                                                          .copyWith(
                                                                        color: Theme
                                                                            .of(
                                                                          context,
                                                                        ).primaryColorDark,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: Dimensions
                                                                  .paddingSizeSmall,
                                                            ),
                                                            InkWell(
                                                              onTap: () =>
                                                                  showDialog(
                                                                barrierDismissible:
                                                                    false,
                                                                context:
                                                                    context,
                                                                builder: (_) =>
                                                                    const TipsWidget(),
                                                              ),
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                  horizontal:
                                                                      Dimensions
                                                                          .paddingSizeSmall,
                                                                  vertical:
                                                                      Dimensions
                                                                          .paddingSizeSmall,
                                                                ),
                                                                margin:
                                                                    const EdgeInsets
                                                                        .all(
                                                                  Dimensions
                                                                      .paddingSizeSmall,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Theme
                                                                          .of(
                                                                    context,
                                                                  )
                                                                      .primaryColor
                                                                      .withValues(
                                                                        alpha:
                                                                            .35,
                                                                      ),
                                                                  borderRadius:
                                                                      const BorderRadius
                                                                          .all(
                                                                    Radius
                                                                        .circular(
                                                                      Dimensions
                                                                          .paddingSizeSmall,
                                                                    ),
                                                                  ),
                                                                ),
                                                                child: Center(
                                                                  child: Text(
                                                                    (paymentController.tipAmount ==
                                                                                '0' ||
                                                                            paymentController
                                                                                .tipAmount.isEmpty)
                                                                        ? 'add_tips'
                                                                            .tr
                                                                        : 'change'
                                                                            .tr,
                                                                    style: textBold
                                                                        .copyWith(
                                                                      color: Theme
                                                                          .of(
                                                                        context,
                                                                      ).primaryColorDark,
                                                                      fontSize:
                                                                          Dimensions
                                                                              .fontSizeDefault,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                    : const SizedBox(),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: Dimensions
                                                      .paddingSizeDefault,
                                                ),
                                                child: Theme(
                                                  data: Theme.of(context)
                                                      .copyWith(
                                                    dividerColor:
                                                        Colors.transparent,
                                                  ),
                                                  child: ExpansionTile(
                                                    initiallyExpanded: true,
                                                    tilePadding: collapsed
                                                        ? EdgeInsets.zero
                                                        : const EdgeInsets
                                                            .symmetric(
                                                            horizontal: Dimensions
                                                                .paddingSizeSmall,
                                                          ),
                                                    backgroundColor:
                                                        Colors.white,
                                                    collapsedBackgroundColor:
                                                        Colors.white,
                                                    collapsedShape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        10,
                                                      ),
                                                    ),
                                                    title: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          'trip_details'.tr,
                                                          style: textMedium
                                                              .copyWith(
                                                            color: Theme.of(
                                                              context,
                                                            ).primaryColor,
                                                            fontSize: Dimensions
                                                                .fontSizeLarge,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    onExpansionChanged:
                                                        (bool expanded) {
                                                      setState(() {
                                                        collapsed = expanded;
                                                      });
                                                    },
                                                    children: [
                                                      const SizedBox(
                                                        height: Dimensions
                                                            .paddingSizeSmall,
                                                      ),
                                                      if (rideController
                                                              .tripDetails !=
                                                          null)
                                                        Container(
                                                          width:
                                                              double.infinity,
                                                          color: Colors.white,
                                                          child: RouteWidget(
                                                            totalDistance: rideController
                                                                    .finalFare
                                                                    ?.actualDistance
                                                                    ?.toString() ??
                                                                '0',
                                                            fromAddress:
                                                                rideController
                                                                    .tripDetails!
                                                                    .pickupAddress!,
                                                            toAddress: rideController
                                                                .tripDetails!
                                                                .destinationAddress!,
                                                            extraOneAddress:
                                                                firstRoute,
                                                            extraTwoAddress:
                                                                secondRoute,
                                                            entrance: rideController
                                                                    .tripDetails!
                                                                    .entrance ??
                                                                '',
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              if (rideController.finalFare !=
                                                  null)
                                                Container(
                                                  width: double.infinity,
                                                  color: Colors.white,
                                                  child: Column(
                                                    children: [
                                                      TripFareSummery(
                                                        fromPayment: true,
                                                        tripFare: rideController
                                                            .finalFare!
                                                            .paidFare!,
                                                        fromParcel:
                                                            widget.fromParcel,
                                                      ),
                                                      if (!rideController
                                                          .tripDetails!
                                                          .isPayToDriverPayment)
                                                        ApplyCoupon(
                                                          tripId: rideController
                                                              .finalFare!.id!,
                                                        ),
                                                      _LokallyPointsVoucherSelector(
                                                        tripId: rideController
                                                            .finalFare!.id!,
                                                        fromParcel:
                                                            widget.fromParcel,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SliverFillRemaining(
                                        hasScrollBody: false,
                                        fillOverscroll: true,
                                        child: ColoredBox(
                                          color: Colors.white,
                                          child: SizedBox.expand(),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          bottomNavigationBar: Container(
            width: double.infinity,
            color: Colors.white,
            child: GetBuilder<PaymentController>(
              builder: (paymentController) {
                if (_isPayToDriverPayment()) {
                  return Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeDefault,
                      vertical: Dimensions.paddingSizeDefault,
                    ),
                    child: SafeArea(
                      top: false,
                      child: Container(
                        padding:
                            const EdgeInsets.all(Dimensions.paddingSizeDefault),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.10),
                          borderRadius:
                              BorderRadius.circular(Dimensions.radiusLarge),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.hourglass_bottom_rounded,
                              color: Theme.of(context).primaryColor,
                              size: 22,
                            ),
                            const SizedBox(
                              width: Dimensions.paddingSizeSmall,
                            ),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Aguardando o motorista',
                                    style: textSemiBold.copyWith(
                                      color: Theme.of(context).primaryColor,
                                      fontSize: Dimensions.fontSizeDefault,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: Dimensions.paddingSizeExtraSmall,
                                  ),
                                  Text(
                                    'Confirmação do pagamento: ${_displayPaymentMethod()}',
                                    style: textRegular.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color,
                                      fontSize: Dimensions.fontSizeSmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SafeArea(
                  top: false,
                  child: Container(
                    color: Colors.white,
                    height: 80,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeDefault,
                      vertical: Dimensions.paddingSizeDefault,
                    ),
                    child: paymentController.isLoading
                        ? Center(
                            child: SpinKitCircle(
                              color: Theme.of(context).primaryColor,
                              size: 40.0,
                            ),
                          )
                        : ButtonWidget(
                            buttonText: 'pay_now'.tr,
                            onPressed: () {
                              if (paymentController.paymentTypeIndex == 1 &&
                                  paymentController.paymentGatewayIndex != -1) {
                                Get.to(
                                  () => DigitalPaymentScreen(
                                    tripId: Get.find<RideController>()
                                        .finalFare!
                                        .id!,
                                    paymentMethod: paymentController.gateWay,
                                    fromParcel: widget.fromParcel,
                                    tips: paymentController.tipAmount,
                                  ),
                                );
                              }
                              if (paymentController.paymentTypeIndex == 1 &&
                                  paymentController.paymentGatewayIndex == -1) {
                                showCustomSnackBar(
                                  'select_payment_method'.tr,
                                );
                              } else if (paymentController.paymentTypeIndex ==
                                      0 ||
                                  paymentController.paymentTypeIndex == 2) {
                                if (Get.find<RideController>().finalFare !=
                                    null) {
                                  paymentController.paymentSubmit(
                                    Get.find<RideController>().finalFare!.id!,
                                    paymentController.paymentTypeList[
                                        paymentController.paymentTypeIndex],
                                    fromParcel: widget.fromParcel,
                                  );
                                }
                              }
                            },
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LokallyPointsVoucherSelector extends StatefulWidget {
  final String tripId;
  final bool fromParcel;

  const _LokallyPointsVoucherSelector({
    required this.tripId,
    required this.fromParcel,
  });

  @override
  State<_LokallyPointsVoucherSelector> createState() =>
      _LokallyPointsVoucherSelectorState();
}

class _LokallyPointsVoucherSelectorState
    extends State<_LokallyPointsVoucherSelector> {
  bool _isLoading = false;
  bool _hasLoaded = false;
  List<_LokallyPointsVoucher> _vouchers = [];

  String get _expectedRewardType =>
      widget.fromParcel ? 'parcel_coupon' : 'ride_coupon';

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
      final List<_LokallyPointsVoucher> parsed = rawItems
          .whereType<Map>()
          .map((item) => _LokallyPointsVoucher.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where(
            (voucher) =>
                voucher.status == 'available' &&
                voucher.rewardType == _expectedRewardType &&
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

  Future<void> _applyVoucher(_LokallyPointsVoucher voucher) async {
    final RideController rideController = Get.find<RideController>();

    rideController.setLokallyPointsVoucherForFinalFare(
      voucherId: voucher.id,
      voucherCode: voucher.code,
      amount: voucher.amount,
      rewardType: voucher.rewardType,
    );

    Navigator.of(context).pop();

    final response = await rideController.getFinalFare(
      widget.tripId,
      lokallyPointsVoucherId: voucher.id,
      lokallyPointsVoucherCode: voucher.code,
    );

    if (response.statusCode == 200) {
      showCustomSnackBar(
        'Resgate do Clube aplicado com sucesso.',
        isError: false,
      );
    }
  }

  void _openVoucherModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (modalContext) {
        final double bottomPadding = MediaQuery.of(modalContext).padding.bottom;

        return SafeArea(
          top: false,
          bottom: false,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(modalContext).size.height * 0.82,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(Dimensions.radiusLarge),
                topRight: Radius.circular(Dimensions.radiusLarge),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                Dimensions.paddingSizeDefault,
                Dimensions.paddingSizeDefault,
                Dimensions.paddingSizeDefault,
                bottomPadding + Dimensions.paddingSizeExtraLarge,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).hintColor.withValues(alpha: 0.18),
                      borderRadius:
                          BorderRadius.circular(Dimensions.radiusOverLarge),
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
                    widget.fromParcel
                        ? 'Escolha um resgate disponível para aplicar nesta entrega.'
                        : 'Escolha um resgate disponível para aplicar nesta corrida.',
                    textAlign: TextAlign.center,
                    style: textRegular.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  ..._vouchers.map(
                    (voucher) => _LokallyPointsVoucherTile(
                      voucher: voucher,
                      onTap: () => _applyVoucher(voucher),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideController>(
      builder: (rideController) {
        final double appliedAmount =
            rideController.finalFare?.lokallyPointsVoucherAmount ?? 0;
        final String? appliedCode =
            rideController.finalFare?.lokallyPointsVoucherCode;

        if (appliedAmount > 0) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(
              left: Dimensions.paddingSizeDefault,
              right: Dimensions.paddingSizeDefault,
              bottom: Dimensions.paddingSizeDefault,
            ),
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              border: Border.all(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  ),
                  child: Icon(
                    Icons.stars_rounded,
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
                        'Resgate Clube de Pontos aplicado',
                        style: textSemiBold.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: Dimensions.fontSizeDefault,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if ((appliedCode ?? '').isNotEmpty) appliedCode!,
                          PriceConverter.convertPrice(appliedAmount),
                        ].join(' • '),
                        style: textRobotoRegular.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.check_circle_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 22,
                ),
              ],
            ),
          );
        }

        if (_isLoading && !_hasLoaded) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(
              left: Dimensions.paddingSizeDefault,
              right: Dimensions.paddingSizeDefault,
              bottom: Dimensions.paddingSizeDefault,
            ),
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
            margin: const EdgeInsets.only(
              left: Dimensions.paddingSizeDefault,
              right: Dimensions.paddingSizeDefault,
              bottom: Dimensions.paddingSizeDefault,
            ),
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              border: Border.all(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
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
                        Theme.of(context).primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  ),
                  child: Icon(
                    Icons.stars_rounded,
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
                        'Usar resgate do Clube',
                        style: textSemiBold.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: Dimensions.fontSizeDefault,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_vouchers.length} resgate${_vouchers.length == 1 ? '' : 's'} disponível${_vouchers.length == 1 ? '' : 'is'}',
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
                  size: 24,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LokallyPointsVoucherTile extends StatelessWidget {
  final _LokallyPointsVoucher voucher;
  final VoidCallback onTap;

  const _LokallyPointsVoucherTile({
    required this.voucher,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).hintColor.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(
          color: Theme.of(context).hintColor.withValues(alpha: 0.10),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                ),
                child: Icon(
                  Icons.confirmation_number_rounded,
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
      ),
    );
  }
}

class _LokallyPointsVoucher {
  final String id;
  final String code;
  final String title;
  final String rewardType;
  final String status;
  final double amount;

  const _LokallyPointsVoucher({
    required this.id,
    required this.code,
    required this.title,
    required this.rewardType,
    required this.status,
    required this.amount,
  });

  factory _LokallyPointsVoucher.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> reward =
        json['reward'] is Map ? Map<String, dynamic>.from(json['reward']) : {};

    final String rewardType =
        (json['reward_type'] ?? json['type'] ?? reward['reward_type'] ?? '')
            .toString();

    final String title = (json['reward_title'] ??
            json['title'] ??
            reward['title'] ??
            'Resgate Clube de Pontos')
        .toString();

    return _LokallyPointsVoucher(
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
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    }

    return 0;
  }
}

class _LokallyNoOverscrollBehavior extends ScrollBehavior {
  const _LokallyNoOverscrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
