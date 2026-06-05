import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class PointToWalletMoneyWidget extends StatelessWidget {
  const PointToWalletMoneyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      surfaceTintColor: Theme.of(context).cardColor,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimensions.paddingSizeDefault),
      ),
      child: Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: () => Get.back(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  padding: const EdgeInsets.all(
                    Dimensions.paddingSizeExtraSmall,
                  ),
                  child: Image.asset(
                    Images.crossIcon,
                    height: Dimensions.paddingSizeSmall,
                    width: Dimensions.paddingSizeSmall,
                    color: Theme.of(context).cardColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Icon(
              Icons.stars_rounded,
              color: Theme.of(context).primaryColor,
              size: 42,
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            Text(
              'Clube de Pontos Lokally',
              textAlign: TextAlign.center,
              style: textSemiBold.copyWith(
                fontSize: Dimensions.fontSizeExtraLarge,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text(
              'Seus pontos agora fazem parte do Clube de Pontos Lokally. Acompanhe seus pontos, benefícios e resgates pela área do Clube no Perfil.',
              textAlign: TextAlign.center,
              style: textRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .color!
                    .withValues(alpha: 0.72),
                height: 1.35,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                  ),
                ),
                child: Text(
                  'Entendi',
                  style: textBold.copyWith(
                    color: Colors.white,
                    fontSize: Dimensions.fontSizeDefault,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
