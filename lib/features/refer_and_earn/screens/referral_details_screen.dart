import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/controllers/refer_and_earn_controller.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/widgets/referral_earn_bottomsheet_widget.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:share_plus/share_plus.dart';

class ReferralDetailsScreen extends StatelessWidget {
  const ReferralDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: GetBuilder<ReferAndEarnController>(
        builder: (referAndEarnController) {
          return (Get.find<ConfigController>().config?.referralEarningStatus ??
                  false)
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      Image.asset(
                        Images.homeReferralIcon,
                        height: 120,
                        width: 120,
                      ),
                      const SizedBox(height: Dimensions.paddingSizeSmall),
                      Text(
                        'Convide e ganhe pontos',
                        style: textSemiBold.copyWith(
                          color: Get.isDarkMode
                              ? Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .color!
                                  .withValues(alpha: 0.9)
                              : null,
                        ),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeSmall),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeSignUp,
                        ),
                        child: Text(
                          'Compartilhe seu código de indicação com amigos e familiares. '
                          'Quando seu indicado se cadastrar e concluir corridas elegíveis, '
                          'vocês poderão ganhar pontos no Clube de Pontos Lokally.',
                          textAlign: TextAlign.center,
                          style: textRegular.copyWith(
                            color:
                                Theme.of(context).colorScheme.secondaryFixedDim,
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: Dimensions.paddingSizeExtremeLarge,
                      ),
                      IntrinsicHeight(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Container(
                              width: Get.width * 0.25,
                              padding: const EdgeInsets.only(
                                left: Dimensions.paddingSizeSmall,
                                right: Dimensions.paddingSizeSmall,
                                bottom: Dimensions.paddingSizeSmall,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .highlightColor
                                    .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(
                                  Dimensions.paddingSizeSmall,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .cardColor
                                            .withValues(alpha: 0.75),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(
                                        Dimensions.paddingSizeExtraSmall,
                                      ),
                                      child: const Text('1'),
                                    ),
                                  ),
                                  Image.asset(
                                    Images.referralIcon1,
                                    height: 24,
                                    width: 24,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color!
                                        .withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(
                                    height: Dimensions.paddingSizeSmall,
                                  ),
                                  Text(
                                    'Compartilhe seu código',
                                    textAlign: TextAlign.center,
                                    style: textRegular.copyWith(
                                      fontSize: Dimensions.fontSizeExtraSmall,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryFixedDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: Get.width * 0.25,
                              padding: const EdgeInsets.only(
                                left: Dimensions.paddingSizeSmall,
                                right: Dimensions.paddingSizeSmall,
                                bottom: Dimensions.paddingSizeSmall,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .highlightColor
                                    .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(
                                  Dimensions.paddingSizeSmall,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .cardColor
                                            .withValues(alpha: 0.75),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(
                                        Dimensions.paddingSizeExtraSmall,
                                      ),
                                      child: const Text('2'),
                                    ),
                                  ),
                                  Image.asset(
                                    Images.referralIcon2,
                                    height: 24,
                                    width: 24,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color!
                                        .withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(
                                    height: Dimensions.paddingSizeSmall,
                                  ),
                                  Text(
                                    'Seu amigo se cadastra',
                                    textAlign: TextAlign.center,
                                    style: textRegular.copyWith(
                                      fontSize: Dimensions.fontSizeExtraSmall,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryFixedDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: Get.width * 0.25,
                              padding: const EdgeInsets.only(
                                left: Dimensions.paddingSizeSmall,
                                right: Dimensions.paddingSizeSmall,
                                bottom: Dimensions.paddingSizeSmall,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .highlightColor
                                    .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(
                                  Dimensions.paddingSizeSmall,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .cardColor
                                            .withValues(alpha: 0.75),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(
                                        Dimensions.paddingSizeExtraSmall,
                                      ),
                                      child: const Text('3'),
                                    ),
                                  ),
                                  Image.asset(
                                    Images.referralIcon3,
                                    height: 24,
                                    width: 24,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color!
                                        .withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(
                                    height: Dimensions.paddingSizeSmall,
                                  ),
                                  Text(
                                    'Ganhem pontos no Clube',
                                    textAlign: TextAlign.center,
                                    style: textRegular.copyWith(
                                      fontSize: Dimensions.fontSizeExtraSmall,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryFixedDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: Dimensions.paddingSizeExtremeLarge,
                      ),
                      Container(
                        width: Get.width * 0.9,
                        padding: const EdgeInsets.only(
                          left: Dimensions.paddingSizeDefault,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                          border: Border.all(
                            color: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                referAndEarnController.referralLink,
                                style: textBold,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: referAndEarnController.referralLink,
                                  ),
                                ).then((_) {
                                  showCustomSnackBar(
                                    'Código copiado com sucesso.',
                                    isError: false,
                                  );
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Dimensions.paddingSizeDefault,
                                  vertical: Dimensions.paddingSizeSmall,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .highlightColor
                                      .withValues(alpha: 0.2),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(
                                        Dimensions.radiusDefault),
                                    bottomRight: Radius.circular(
                                        Dimensions.radiusDefault),
                                  ),
                                ),
                                child: Icon(
                                  Icons.copy_rounded,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeLarge),
                      ButtonWidget(
                        onPressed: () {
                          final params = ShareParams(
                            text: referAndEarnController.referralShareText,
                          );

                          SharePlus.instance.share(params);
                        },
                        width: Get.width * 0.5,
                        buttonText: 'invite_friends'.tr,
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),
                      InkWell(
                        onTap: () => Get.bottomSheet(
                          const ReferralEarnBottomsheetWidget(),
                          isDismissible: false,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'how_it_works'.tr,
                              style: textRegular.copyWith(
                                decoration: TextDecoration.underline,
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainer,
                                decorationColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainer,
                              ),
                            ),
                            const SizedBox(width: Dimensions.paddingSizeSmall),
                            const Icon(Icons.help_outline, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    const SizedBox(height: Dimensions.topSpace),
                    Image.asset(
                      Images.homeReferralIcon,
                      height: 140,
                      width: 140,
                    ),
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    Text(
                      'stay_tuned_to_earn_big'.tr,
                      style: textSemiBold.copyWith(
                        color: Get.isDarkMode
                            ? Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .color!
                                .withValues(alpha: 0.9)
                            : null,
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeExtremeLarge,
                      ),
                      child: Text(
                        'our_refer_and_earn_program_is_temporarily_paused'.tr,
                        textAlign: TextAlign.center,
                        style: textRegular.copyWith(
                          color:
                              Theme.of(context).colorScheme.secondaryFixedDim,
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                      ),
                    ),
                  ],
                );
        },
      ),
    );
  }
}
