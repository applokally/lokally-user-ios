import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/controllers/refer_and_earn_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:share_plus/share_plus.dart';

class HomeReferralViewWidget extends StatelessWidget {
  const HomeReferralViewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Get.width,
      margin: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeDefault,
        horizontal: Dimensions.paddingSizeLarge,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text(
                  'Compartilhe seu código e participe do Clube de Pontos Lokally.',
                  style: textRegular.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                    color: Get.isDarkMode
                        ? Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .color!
                            .withValues(alpha: 0.8)
                        : null,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                GetBuilder<ReferAndEarnController>(
                  builder: (referAndEarnController) {
                    return referAndEarnController.isLoading
                        ? SpinKitCircle(
                            color: Theme.of(context).primaryColor,
                            size: 30.0,
                          )
                        : InkWell(
                            onTap: () {
                              Get.find<ReferAndEarnController>()
                                  .getReferralDetails()
                                  .then((value) {
                                Get.bottomSheet(
                                  const ReferralViewBottomSheetWidget(),
                                  backgroundColor:
                                      Theme.of(Get.context!).cardColor,
                                  isDismissible: false,
                                );
                              });
                            },
                            borderRadius: BorderRadius.circular(
                              Dimensions.paddingSizeOverLarge,
                            ),
                            child: Container(
                              height: 28,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(
                                  Dimensions.paddingSizeOverLarge,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'invite_friends'.tr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textRegular.copyWith(
                                    color: Get.isDarkMode
                                        ? Theme.of(context)
                                            .textTheme
                                            .bodyMedium!
                                            .color!
                                            .withValues(alpha: 0.9)
                                        : Theme.of(context).cardColor,
                                    fontSize: Dimensions.fontSizeSmall,
                                  ),
                                ),
                              ),
                            ),
                          );
                  },
                ),
              ],
            ),
          ),
          Image.asset(
            Images.homeReferralIcon,
            height: 110,
            width: 120,
          ),
        ],
      ),
    );
  }
}

class ReferralViewBottomSheetWidget extends StatelessWidget {
  const ReferralViewBottomSheetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: GetBuilder<ReferAndEarnController>(
        builder: (referAndEarnController) {
          return Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(Dimensions.paddingSizeLarge),
                topLeft: Radius.circular(Dimensions.paddingSizeLarge),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  InkWell(
                    onTap: () => Get.back(),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .hintColor
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeExtraSmall,
                        ),
                        child: Image.asset(
                          Images.crossIcon,
                          height: 10,
                          width: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Image.asset(
                    Images.homeReferralIcon,
                    height: 120,
                    width: 120,
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Text(
                    'Convide e ganhe pontos',
                    style: textBold.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
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
                        color: Theme.of(context).colorScheme.secondaryFixedDim,
                        fontSize: Dimensions.fontSizeSmall,
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  Container(
                    width: Get.width * 0.82,
                    padding: const EdgeInsets.only(
                      left: Dimensions.paddingSizeDefault,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).highlightColor.withValues(
                            alpha: 0.2,
                          ),
                      borderRadius:
                          BorderRadius.circular(Dimensions.radiusDefault),
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
                                topRight:
                                    Radius.circular(Dimensions.radiusDefault),
                                bottomRight:
                                    Radius.circular(Dimensions.radiusDefault),
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
