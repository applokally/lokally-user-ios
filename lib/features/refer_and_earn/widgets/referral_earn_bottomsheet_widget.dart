import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class ReferralEarnBottomsheetWidget extends StatelessWidget {
  const ReferralEarnBottomsheetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(Dimensions.paddingSizeLarge),
              topLeft: Radius.circular(Dimensions.paddingSizeLarge),
            )),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          InkWell(
            onTap: () => Get.back(),
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).hintColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(50),
                ),
                padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                child: Image.asset(Images.crossIcon, height: 10, width: 10),
              ),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text('Como funciona a indicação', style: textBold),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(
            'Veja como convidar amigos e participar do Clube de Pontos Lokally.',
            style: textRegular,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Container(
            width: Get.width,
            decoration: BoxDecoration(
              color: Theme.of(context).hintColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(
                Radius.circular(Dimensions.paddingSizeSmall),
              ),
            ),
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            margin: const EdgeInsets.symmetric(
              vertical: Dimensions.paddingSizeSmall,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _InstructionItem(
                  text:
                      'Compartilhe seu código de indicação com amigos e familiares.',
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                _InstructionItem(
                  text:
                      'Seu indicado deve informar o código no cadastro do app Lokally.',
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                _InstructionItem(
                  text:
                      'Após o cadastro, os pontos são liberados por etapas conforme o indicado conclui corridas elegíveis.',
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                _InstructionItem(
                  text:
                      'Quem indicou pode ganhar até 200 pontos no Clube de Pontos Lokally.',
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                _InstructionItem(
                  text:
                      'Quem foi indicado também pode ganhar pontos ao concluir as primeiras corridas elegíveis.',
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                _InstructionItem(
                  text:
                      'Os pontos aparecem no Clube de Pontos e podem ser acompanhados no histórico do app.',
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _InstructionItem extends StatelessWidget {
  final String text;

  const _InstructionItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
        height: 7,
        width: 7,
        decoration: BoxDecoration(
          color: Get.isDarkMode ? Colors.white : Colors.black,
          borderRadius: const BorderRadius.all(Radius.circular(100)),
        ),
      ),
      Expanded(
        child: Text(
          text,
          style: textRegular.copyWith(
            fontSize: Dimensions.fontSizeSmall,
            color: Theme.of(context).textTheme.bodyMedium!.color,
          ),
        ),
      ),
    ]);
  }
}
