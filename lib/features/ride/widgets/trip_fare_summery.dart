import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/payment/widget/payment_item_info_widget.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/coupon/controllers/coupon_controller.dart';
import 'package:ride_sharing_user_app/features/payment/controllers/payment_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';

String? _lokallySelectedPaymentLabel;
String? _lokallySelectedPaymentGroupLabel;
int? _lokallySelectedPaymentTypeIndex;

class TripFareSummery extends StatelessWidget {
  final bool fromPayment;
  final bool fromParcel;
  final double? tripFare;
  final double? discountFare;
  final double? discountAmount;

  const TripFareSummery({
    super.key,
    this.fromPayment = false,
    this.tripFare,
    required this.fromParcel,
    this.discountFare,
    this.discountAmount,
  });

  double _currentFareAmount() {
    return discountAmount != null && discountAmount!.toDouble() > 0
        ? discountFare!
        : tripFare!;
  }

  String _currentPaymentLabel(PaymentController paymentController) {
    if (_lokallySelectedPaymentLabel != null &&
        _lokallySelectedPaymentTypeIndex ==
            paymentController.paymentTypeIndex) {
      return _lokallySelectedPaymentLabel!;
    }

    if (paymentController.paymentTypeIndex == 0) {
      return 'cash'.tr;
    }

    if (paymentController.paymentTypeIndex == 1) {
      return 'digital_pay'.tr;
    }

    return 'wallet'.tr;
  }

  String _currentPaymentGroupLabel(PaymentController paymentController) {
    if (_lokallySelectedPaymentGroupLabel != null &&
        _lokallySelectedPaymentTypeIndex ==
            paymentController.paymentTypeIndex) {
      return _lokallySelectedPaymentGroupLabel!;
    }

    if (paymentController.paymentTypeIndex == 1 ||
        paymentController.paymentTypeIndex == 2) {
      return 'pay_in_app'.tr;
    }

    return 'pay_to_driver'.tr;
  }

  IconData _currentPaymentIcon(PaymentController paymentController) {
    final String label = _currentPaymentLabel(paymentController);

    if (label == 'pix'.tr) {
      return Icons.qr_code_2_rounded;
    }

    if (label == 'machine_debit'.tr || label == 'machine_credit'.tr) {
      return Icons.credit_card_rounded;
    }

    if (paymentController.paymentTypeIndex == 1) {
      return Icons.phone_iphone_rounded;
    }

    if (paymentController.paymentTypeIndex == 2) {
      return Icons.account_balance_wallet_rounded;
    }

    return Icons.payments_rounded;
  }

  void _selectPaymentMethod({
    required BuildContext context,
    required PaymentController paymentController,
    required String label,
    required String groupLabel,
    required int paymentTypeIndex,
    required double fareAmount,
  }) {
    if (paymentTypeIndex == 2 &&
        fareAmount >
            Get.find<ProfileController>()
                .profileModel!
                .data!
                .wallet!
                .walletBalance!) {
      showCustomSnackBar(
        'your_wallet_has_insufficient_balance'.tr,
        isError: true,
        subMessage:
            '${'wallet_balance'.tr}: ${PriceConverter.convertPrice(Get.find<ProfileController>().profileModel!.data!.wallet!.walletBalance!)}',
      );
      return;
    }

    _lokallySelectedPaymentLabel = label;
    _lokallySelectedPaymentGroupLabel = groupLabel;
    _lokallySelectedPaymentTypeIndex = paymentTypeIndex;

    paymentController.setPaymentType(paymentTypeIndex);
    Navigator.of(context).pop();
  }

  void _openPaymentMethodModal({
    required BuildContext context,
    required PaymentController paymentController,
    required double fareAmount,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (modalContext) {
        final String selectedLabel = _currentPaymentLabel(paymentController);
        final double bottomPadding = MediaQuery.of(modalContext).padding.bottom;

        return SafeArea(
          top: false,
          bottom: false,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(modalContext).size.height * 0.84,
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
                    'choose_payment_method'.tr,
                    textAlign: TextAlign.center,
                    style: textBold.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  _PaymentGroup(
                    title: 'pay_to_driver'.tr,
                    children: [
                      _PaymentOptionTile(
                        title: 'cash'.tr,
                        icon: Icons.payments_rounded,
                        selected: selectedLabel == 'cash'.tr,
                        onTap: () => _selectPaymentMethod(
                          context: modalContext,
                          paymentController: paymentController,
                          label: 'cash'.tr,
                          groupLabel: 'pay_to_driver'.tr,
                          paymentTypeIndex: 0,
                          fareAmount: fareAmount,
                        ),
                      ),
                      _PaymentOptionTile(
                        title: 'machine_debit'.tr,
                        icon: Icons.credit_card_rounded,
                        selected: selectedLabel == 'machine_debit'.tr,
                        onTap: () => _selectPaymentMethod(
                          context: modalContext,
                          paymentController: paymentController,
                          label: 'machine_debit'.tr,
                          groupLabel: 'pay_to_driver'.tr,
                          paymentTypeIndex: 0,
                          fareAmount: fareAmount,
                        ),
                      ),
                      _PaymentOptionTile(
                        title: 'machine_credit'.tr,
                        icon: Icons.credit_score_rounded,
                        selected: selectedLabel == 'machine_credit'.tr,
                        onTap: () => _selectPaymentMethod(
                          context: modalContext,
                          paymentController: paymentController,
                          label: 'machine_credit'.tr,
                          groupLabel: 'pay_to_driver'.tr,
                          paymentTypeIndex: 0,
                          fareAmount: fareAmount,
                        ),
                      ),
                      _PaymentOptionTile(
                        title: 'pix'.tr,
                        icon: Icons.qr_code_2_rounded,
                        selected: selectedLabel == 'pix'.tr,
                        onTap: () => _selectPaymentMethod(
                          context: modalContext,
                          paymentController: paymentController,
                          label: 'pix'.tr,
                          groupLabel: 'pay_to_driver'.tr,
                          paymentTypeIndex: 0,
                          fareAmount: fareAmount,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                  _PaymentGroup(
                    title: 'pay_in_app'.tr,
                    children: [
                      _PaymentOptionTile(
                        title: 'digital_pay'.tr,
                        icon: Icons.phone_iphone_rounded,
                        selected: selectedLabel == 'digital_pay'.tr,
                        onTap: () => _selectPaymentMethod(
                          context: modalContext,
                          paymentController: paymentController,
                          label: 'digital_pay'.tr,
                          groupLabel: 'pay_in_app'.tr,
                          paymentTypeIndex: 1,
                          fareAmount: fareAmount,
                        ),
                      ),
                      _PaymentOptionTile(
                        title: 'wallet'.tr,
                        icon: Icons.account_balance_wallet_rounded,
                        selected: selectedLabel == 'wallet'.tr,
                        onTap: () => _selectPaymentMethod(
                          context: modalContext,
                          paymentController: paymentController,
                          label: 'wallet'.tr,
                          groupLabel: 'pay_in_app'.tr,
                          paymentTypeIndex: 2,
                          fareAmount: fareAmount,
                        ),
                      ),
                    ],
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
    return GetBuilder<RideController>(builder: (rideController) {
      return GetBuilder<CouponController>(builder: (couponController) {
        return GetBuilder<PaymentController>(builder: (paymentController) {
          double total = 0;
          if (fromPayment) {
            total = rideController.finalFare!.paidFare! +
                double.parse(paymentController.tipAmount);
          } else {
            total = rideController.tripDetails?.paidFare ?? 0;
          }

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              color: fromPayment ? null : Theme.of(context).cardColor,
              border: fromPayment
                  ? null
                  : Border.all(
                      color:
                          Theme.of(context).hintColor.withValues(alpha: 0.10),
                    ),
              boxShadow: fromPayment
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Column(
              children: [
                if (!fromPayment)
                  Row(
                    children: [
                      _SummaryIcon(
                        icon: Icons.receipt_long_rounded,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Expanded(
                        child: Text(
                          'fare_price'.tr,
                          style: textSemiBold.copyWith(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: Dimensions.fontSizeDefault,
                          ),
                        ),
                      ),
                      if (discountAmount != null &&
                          discountAmount!.toDouble() > 0)
                        Padding(
                          padding: const EdgeInsets.only(
                            right: Dimensions.paddingSizeExtraSmall,
                          ),
                          child: Text(
                            PriceConverter.convertPrice(tripFare!),
                            style: textRobotoBold.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: Theme.of(context).hintColor,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Theme.of(context).hintColor,
                            ),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                          border: Border.all(
                            color: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.18),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeDefault,
                          vertical: Dimensions.paddingSizeExtraSmall,
                        ),
                        child: Text(
                          PriceConverter.convertPrice(_currentFareAmount()),
                          style: textRobotoBold.copyWith(
                            fontSize: Dimensions.fontSizeDefault,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (fromPayment) ...[
                  rideController.finalFare!.discountAmount!.toDouble() > 0
                      ? Padding(
                          padding: const EdgeInsets.only(
                            bottom: Dimensions.paddingSizeSmall,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: Dimensions.iconSizeSmall,
                                child: Image.asset(
                                  Images.farePrice,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(
                                width: Dimensions.paddingSizeSmall,
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      'fare_fee'.tr,
                                      style: textMedium.copyWith(
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error
                                            .withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.paddingSizeExtraSmall,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal:
                                            Dimensions.paddingSizeExtraSmall,
                                      ),
                                      margin: const EdgeInsets.only(
                                        left: Dimensions.paddingSizeExtraSmall,
                                      ),
                                      child: Text(
                                        (rideController.finalFare?.discount ==
                                                    null) &&
                                                ((rideController.finalFare
                                                            ?.discountAmount ??
                                                        0) >
                                                    0)
                                            ? '${PriceConverter.convertPrice(rideController.finalFare!.discountAmount!.toDouble())} ${'off'.tr}'
                                            : rideController
                                                        .finalFare!
                                                        .discount!
                                                        .discountAmountType ==
                                                    'percentage'
                                                ? '${rideController.finalFare!.discount!.discountAmount}% ${'off'.tr}'
                                                : '${PriceConverter.convertPrice(rideController.finalFare!.discount!.discountAmount!.toDouble())} ${'off'.tr}',
                                        style: textRobotoRegular.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                PriceConverter.convertPrice(
                                  rideController.finalFare?.distanceWiseFare ??
                                      0,
                                ),
                                style: textRobotoRegular.copyWith(
                                  color: Theme.of(context).hintColor,
                                  decorationColor: Theme.of(context).hintColor,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              Text(
                                ' ${PriceConverter.convertPrice(
                                  rideController.finalFare!.distanceWiseFare! -
                                      rideController.finalFare!.discountAmount!,
                                )}',
                                style: textRobotoRegular.copyWith(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      : PaymentItemInfoWidget(
                          icon: Images.farePrice,
                          title: 'fare_fee'.tr,
                          amount:
                              rideController.finalFare?.distanceWiseFare ?? 0,
                        ),
                ],
                if (fromPayment &&
                    !fromParcel &&
                    rideController.finalFare!.cancellationFee!.toDouble() > 0)
                  PaymentItemInfoWidget(
                    icon: Images.idleHourIcon,
                    title: 'cancellation_price'.tr,
                    amount: rideController.finalFare?.cancellationFee ?? 0,
                  ),
                if (fromPayment &&
                    !fromParcel &&
                    rideController.finalFare!.idleFee!.toDouble() > 0)
                  PaymentItemInfoWidget(
                    icon: Images.idleHourIcon,
                    title: 'idle_price'.tr,
                    amount: rideController.finalFare?.idleFee ?? 0,
                  ),
                if (fromPayment &&
                    !fromParcel &&
                    rideController.finalFare!.delayFee!.toDouble() > 0)
                  PaymentItemInfoWidget(
                    icon: Images.waitingPrice,
                    title: 'delay_price'.tr,
                    amount: rideController.finalFare?.delayFee ?? 0,
                  ),
                if (fromPayment &&
                    rideController.finalFare!.couponAmount!.toDouble() > 0)
                  PaymentItemInfoWidget(
                    icon: Images.profileMyWallet,
                    title: 'coupon_discount'.tr,
                    amount: rideController.finalFare?.couponAmount ?? 0,
                    discount: true,
                  ),
                if (fromPayment &&
                    (rideController.finalFare?.lokallyPointsVoucherAmount ??
                            0) >
                        0)
                  PaymentItemInfoWidget(
                    icon: Images.profileMyWallet,
                    title: 'Resgate Clube de Pontos',
                    amount:
                        rideController.finalFare?.lokallyPointsVoucherAmount ??
                            0,
                    discount: true,
                  ),
                if (fromPayment &&
                    rideController.finalFare!.vatTax!.toDouble() > 0)
                  PaymentItemInfoWidget(
                    icon: Images.farePrice,
                    title: 'vat_tax'.tr,
                    amount: rideController.finalFare?.vatTax ?? 0,
                  ),
                if (fromPayment &&
                    double.parse(paymentController.tipAmount) > 0)
                  PaymentItemInfoWidget(
                    icon: Images.farePrice,
                    title: 'tips'.tr,
                    amount: double.parse(paymentController.tipAmount),
                    toolTipText: 'tips_tooltip',
                  ),
                if (fromPayment)
                  PaymentItemInfoWidget(
                    title: 'sub_total'.tr,
                    amount: total,
                    isSubTotal: true,
                  ),
                if (!fromPayment)
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                if (fromPayment)
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                if (!fromPayment)
                  GetBuilder<ParcelController>(
                    builder: (parcelController) {
                      return !parcelController.payReceiver
                          ? Column(
                              children: [
                                Divider(
                                  height: Dimensions.paddingSizeDefault,
                                  color: Theme.of(context)
                                      .hintColor
                                      .withValues(alpha: 0.12),
                                ),
                                Row(
                                  children: [
                                    _SummaryIcon(
                                      icon: Icons.wallet_rounded,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color,
                                    ),
                                    const SizedBox(
                                      width: Dimensions.paddingSizeSmall,
                                    ),
                                    Expanded(
                                      child: Text(
                                        'payment'.tr,
                                        style: textSemiBold.copyWith(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color,
                                          fontSize: Dimensions.fontSizeDefault,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _openPaymentMethodModal(
                                        context: context,
                                        paymentController: paymentController,
                                        fareAmount: _currentFareAmount(),
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusDefault,
                                      ),
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxWidth: Get.width * 0.46,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal:
                                              Dimensions.paddingSizeSmall,
                                          vertical:
                                              Dimensions.paddingSizeExtraSmall,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .primaryColor
                                              .withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusDefault,
                                          ),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .primaryColor
                                                .withValues(alpha: 0.14),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .primaryColor
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  Dimensions.radiusSmall,
                                                ),
                                              ),
                                              child: Icon(
                                                _currentPaymentIcon(
                                                  paymentController,
                                                ),
                                                color: Theme.of(context)
                                                    .primaryColor,
                                                size: 17,
                                              ),
                                            ),
                                            const SizedBox(
                                              width:
                                                  Dimensions.paddingSizeSmall,
                                            ),
                                            Flexible(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _currentPaymentGroupLabel(
                                                      paymentController,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style:
                                                        textSemiBold.copyWith(
                                                      fontSize: Dimensions
                                                          .fontSizeSmall,
                                                      color: Theme.of(context)
                                                          .primaryColor
                                                          .withValues(
                                                            alpha: 0.92,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 1),
                                                  Text(
                                                    _currentPaymentLabel(
                                                      paymentController,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: textMedium.copyWith(
                                                      fontSize: Dimensions
                                                          .fontSizeDefault,
                                                      color: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.color,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(
                                              width: Dimensions
                                                  .paddingSizeExtraSmall,
                                            ),
                                            Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : const SizedBox();
                    },
                  ),
              ],
            ),
          );
        });
      });
    });
  }
}

class _SummaryIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;

  const _SummaryIcon({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).hintColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }
}

class _PaymentGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _PaymentGroup({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).hintColor.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(
          color: Theme.of(context).hintColor.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.only(left: Dimensions.paddingSizeExtraSmall),
            child: Text(
              title,
              style: textSemiBold.copyWith(
                color: Theme.of(context).primaryColor,
                fontSize: Dimensions.fontSizeDefault,
              ),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          ...children,
        ],
      ),
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOptionTile({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeSmall,
          vertical: Dimensions.paddingSizeSmall,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(
            color: selected
                ? Theme.of(context).primaryColor
                : Theme.of(context).hintColor.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.16)
                    : Theme.of(context).hintColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              ),
              child: Icon(
                icon,
                color: selected
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).textTheme.bodyMedium?.color,
                size: 19,
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(
              child: Text(
                title,
                style: textMedium.copyWith(
                  color: selected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: Dimensions.fontSizeDefault,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).hintColor.withValues(alpha: 0.45),
              size: 21,
            ),
          ],
        ),
      ),
    );
  }
}
