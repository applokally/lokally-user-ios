import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/payment/widget/payment_item_info_widget.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/features/trip/screens/schedule_trip_map_view.dart';
import 'package:ride_sharing_user_app/features/trip/widgets/rider_info.dart';
import 'package:ride_sharing_user_app/features/trip/widgets/trip_route_widget.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class TripDetailWidget extends StatelessWidget {
  final TripDetails tripDetails;

  const TripDetailWidget({
    super.key,
    required this.tripDetails,
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

  String _paymentLabel(String? paymentMethod) {
    final String lokallyLabel =
        (tripDetails.lokallyPaymentMethodLabel ?? '').trim();

    if (lokallyLabel.isNotEmpty) {
      return lokallyLabel;
    }

    final String method =
        (tripDetails.lokallyPaymentMethod ?? paymentMethod ?? '').toLowerCase();

    if (method == 'digital' || method == 'lokally_pay' || method == 'online') {
      return _localizedText(
        pt: 'Lokally Pay',
        en: 'Lokally Pay',
        es: 'Lokally Pay',
      );
    }

    if (method == 'wallet') {
      return _localizedText(
        pt: 'Carteira Lokally',
        en: 'Lokally Wallet',
        es: 'Billetera Lokally',
      );
    }

    if (method == 'machine_debit') {
      return _localizedText(
        pt: 'Maquininha Débito',
        en: 'Debit card machine',
        es: 'Datáfono débito',
      );
    }

    if (method == 'machine_credit') {
      return _localizedText(
        pt: 'Maquininha Crédito',
        en: 'Credit card machine',
        es: 'Datáfono crédito',
      );
    }

    if (method == 'pix') {
      return 'PIX';
    }

    return _localizedText(
      pt: 'Dinheiro',
      en: 'Cash payment',
      es: 'Efectivo',
    );
  }

  @override
  Widget build(BuildContext context) {
    String firstRoute = '';
    String secondRoute = '';
    List<dynamic> extraRoute = [];

    if (tripDetails.intermediateAddresses != null &&
        tripDetails.intermediateAddresses != '[[, ]]') {
      extraRoute = jsonDecode(tripDetails.intermediateAddresses!);

      if (extraRoute.isNotEmpty) {
        firstRoute = extraRoute[0];
      }

      if (extraRoute.isNotEmpty && extraRoute.length > 1) {
        secondRoute = extraRoute[1];
      }
    }

    final bool isEstimatedTrip =
        tripDetails.type == AppConstants.scheduleRequest &&
            (tripDetails.currentStatus == AppConstants.pending ||
                tripDetails.currentStatus == AppConstants.accepted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Dimensions.paddingSizeDefault,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _localizedText(
                      pt: 'Detalhes da viagem',
                      en: 'Trip details',
                      es: 'Detalles del viaje',
                    ),
                    style: textBold.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  if (isEstimatedTrip)
                    InkWell(
                      onTap: () => Get.to(
                        () => ScheduleTripMapView(tripDetails: tripDetails),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            Dimensions.paddingSizeExtraSmall,
                          ),
                          border: Border.all(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: Dimensions.paddingSizeExtraSmall,
                          horizontal: Dimensions.paddingSizeSmall,
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              Images.routeIcon,
                              height: 16,
                              width: 16,
                            ),
                            const SizedBox(
                              width: Dimensions.paddingSizeSmall,
                            ),
                            Text(
                              _localizedText(
                                pt: 'Mapa',
                                en: 'Map',
                                es: 'Mapa',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    Dimensions.paddingSizeSmall,
                  ),
                  border: Border.all(
                    color: Theme.of(context).hintColor.withValues(alpha: 0.2),
                  ),
                ),
                padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                child: TripRouteWidget(
                  pickupAddress: tripDetails.pickupAddress!,
                  destinationAddress: tripDetails.destinationAddress!,
                  extraOne: firstRoute,
                  extraTwo: secondRoute,
                  entrance: tripDetails.entrance,
                ),
              ),
            ],
          ),
        ),
        if (tripDetails.driver != null) ...[
          RiderInfo(tripDetails: tripDetails),
          const SizedBox(height: Dimensions.paddingSizeSmall),
        ],
        Row(
          children: [
            Text(
              _localizedText(
                pt: 'Resumo da cobrança',
                en: 'Billing Summary',
                es: 'Resumen de cobro',
              ),
              style: textSemiBold.copyWith(
                fontSize: Dimensions.fontSizeDefault,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            if (isEstimatedTrip) ...[
              const SizedBox(width: Dimensions.paddingSizeExtraSmall),
              Text(
                '(${_localizedText(
                  pt: 'estimado',
                  en: 'estimated',
                  es: 'estimado',
                )})',
                style: textRegular.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            border: Border.all(
              color: Theme.of(context).hintColor.withValues(alpha: 0.16),
            ),
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          child: Column(
            children: [
              PaymentItemInfoWidget(
                icon: Images.farePrice,
                title: _localizedText(
                  pt: 'Valor da tarifa',
                  en: 'Fare price',
                  es: 'Valor de la tarifa',
                ),
                amount: tripDetails.distanceWiseFare ?? 0,
              ),
              PaymentItemInfoWidget(
                icon: Images.idleHourIcon,
                title: _localizedText(
                  pt: 'Taxa de inatividade',
                  en: 'Idle Fee',
                  es: 'Tarifa de inactividad',
                ),
                amount: tripDetails.idleFee ?? 0,
              ),
              PaymentItemInfoWidget(
                icon: Images.waitingPrice,
                title: _localizedText(
                  pt: 'Taxa de atraso',
                  en: 'Delay Fee',
                  es: 'Tarifa por retraso',
                ),
                amount: tripDetails.delayFee ?? 0,
              ),
              PaymentItemInfoWidget(
                icon: Images.idleHourIcon,
                title: _localizedText(
                  pt: 'Taxa de cancelamento',
                  en: 'Cancellation Fee',
                  es: 'Tarifa de cancelación',
                ),
                amount: tripDetails.cancellationFee ?? 0,
              ),
              PaymentItemInfoWidget(
                icon: Images.coupon,
                title: _localizedText(
                  pt: 'Cupom',
                  en: 'Coupon',
                  es: 'Cupón',
                ),
                amount: tripDetails.couponAmount ?? 0,
                discount: true,
              ),
              PaymentItemInfoWidget(
                icon: Images.discount,
                title: _localizedText(
                  pt: 'Desconto',
                  en: 'Discount',
                  es: 'Descuento',
                ),
                amount: tripDetails.discountAmount ?? 0,
                discount: true,
              ),
              PaymentItemInfoWidget(
                icon: Images.farePrice,
                title: _localizedText(
                  pt: 'Gorjeta',
                  en: 'Tips',
                  es: 'Propina',
                ),
                amount: tripDetails.tips ?? 0,
              ),
              Divider(
                color: Theme.of(context).hintColor.withValues(alpha: 0.15),
              ),
              PaymentItemInfoWidget(
                title: _localizedText(
                  pt: 'Subtotal',
                  en: 'Sub Total',
                  es: 'Subtotal',
                ),
                amount: isEstimatedTrip
                    ? tripDetails.distanceWiseFare ?? 0
                    : tripDetails.paidFare ?? 0,
                isSubTotal: true,
              ),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeSmall,
                  vertical: Dimensions.paddingSizeExtraSmall,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).hintColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          Images.profileMyWallet,
                          height: 15,
                          width: 15,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: Dimensions.paddingSizeSmall),
                        Text(
                          _localizedText(
                            pt: 'Pagamento',
                            en: 'Payment',
                            es: 'Pago',
                          ),
                          style: textMedium.copyWith(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        _paymentLabel(tripDetails.paymentMethod),
                        style: textMedium.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
