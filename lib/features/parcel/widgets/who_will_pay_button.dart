import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/expandable_bottom_sheet.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';

class WhoWillPayButton extends StatefulWidget {
  final GlobalKey<ExpandableBottomSheetState> expandableKey;

  const WhoWillPayButton({super.key, required this.expandableKey});

  @override
  State<WhoWillPayButton> createState() => _WhoWillPayButtonState();
}

class _WhoWillPayButtonState extends State<WhoWillPayButton> {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<ParcelController>(builder: (parcelController) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Dimensions.radiusOverLarge),
          color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          Dimensions.paddingSizeDefault,
          4,
          4,
          4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Image.asset(
                    Images.parcel,
                    width: 14,
                  ),
                  const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                  Flexible(
                    child: Text(
                      'who_will_pay'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeExtraSmall),
            Row(
              children: [
                InkWell(
                  onTap: () {
                    parcelController.updatePaymentPerson(false);
                    parcelController.focusOnBottomSheet(widget.expandableKey);
                  },
                  borderRadius:
                      BorderRadius.circular(Dimensions.radiusOverLarge),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(Dimensions.radiusOverLarge),
                      color: parcelController.payReceiver
                          ? Theme.of(context).cardColor
                          : Theme.of(context).primaryColor,
                      border: Border.all(
                        color: parcelController.payReceiver
                            ? Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.18)
                            : Theme.of(context).primaryColor,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeDefault,
                      vertical: Dimensions.paddingSizeSeven,
                    ),
                    child: Text(
                      'Eu vou pagar',
                      style: textBold.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: parcelController.payReceiver
                            ? Theme.of(context).primaryColor
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                InkWell(
                  onTap: () {
                    widget.expandableKey.currentState?.expand();
                    parcelController.updatePaymentPerson(true);
                  },
                  borderRadius:
                      BorderRadius.circular(Dimensions.radiusOverLarge),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(Dimensions.radiusOverLarge),
                      color: parcelController.payReceiver
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).cardColor,
                      border: Border.all(
                        color: parcelController.payReceiver
                            ? Theme.of(context).primaryColor
                            : Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.18),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeDefault,
                      vertical: Dimensions.paddingSizeSeven,
                    ),
                    child: Text(
                      'Destinatário paga',
                      style: textBold.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: parcelController.payReceiver
                            ? Colors.white
                            : Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
