import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/controllers/refer_and_earn_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class ReferralEarningScreen extends StatelessWidget {
  const ReferralEarningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeSmall,
          horizontal: Dimensions.paddingSizeDefault,
        ),
        child: GetBuilder<ReferAndEarnController>(
          builder: (referAndEarnController) {
            final List<PointsClubReferralItem> referrals =
                referAndEarnController.pointsClubReferrals;

            return RefreshIndicator(
              onRefresh: () async {
                await referAndEarnController.getPointsClubReferrals(0);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          Dimensions.paddingSizeDefault,
                        ),
                        color: Theme.of(context)
                            .highlightColor
                            .withValues(alpha: 0.1),
                        border: Border.all(
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.1),
                        ),
                      ),
                      padding:
                          const EdgeInsets.all(Dimensions.paddingSizeSmall),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Indicações do Clube',
                                  style: textRegular.copyWith(
                                    color: Get.isDarkMode
                                        ? Theme.of(context)
                                            .textTheme
                                            .bodyMedium!
                                            .color!
                                            .withValues(alpha: 0.9)
                                        : null,
                                  ),
                                ),
                                const SizedBox(
                                  height: Dimensions.paddingSizeSmall,
                                ),
                                Text(
                                  'Acompanhe quem se cadastrou com seu código, o progresso das corridas e os pontos liberados.',
                                  style: textRegular.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondaryFixedDim,
                                    fontSize: Dimensions.fontSizeSmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Dimensions.paddingSizeSmall),
                          Image.asset(
                            Images.loyaltyPoint,
                            height: 40,
                            width: 40,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeLarge),
                    Text(
                      'Minhas indicações',
                      style: textBold.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .color!
                            .withValues(alpha: 0.85),
                        fontSize: Dimensions.fontSizeLarge,
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                    Divider(
                      thickness: .25,
                      color: Theme.of(context)
                          .primaryColor
                          .withValues(alpha: 0.25),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeDefault),
                    if (referAndEarnController.isPointsClubReferralLoading &&
                        referrals.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: Dimensions.paddingSizeExtremeLarge,
                        ),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (referrals.isEmpty)
                      _ReferralEmptyState(
                        onRetry: () {
                          referAndEarnController.getPointsClubReferrals(0);
                        },
                      )
                    else
                      ListView.separated(
                        itemCount: referrals.length,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        separatorBuilder: (_, __) => const SizedBox(
                          height: Dimensions.paddingSizeSmall,
                        ),
                        itemBuilder: (context, index) {
                          return _ReferralProgressCard(
                            referral: referrals[index],
                          );
                        },
                      ),
                    const SizedBox(height: Dimensions.paddingSizeLarge),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReferralProgressCard extends StatelessWidget {
  final PointsClubReferralItem referral;

  const _ReferralProgressCard({required this.referral});

  @override
  Widget build(BuildContext context) {
    final double progress = referral.targetSteps > 0
        ? (referral.completedSteps / referral.targetSteps).clamp(0, 1)
        : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(
          color: Theme.of(context).hintColor.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).hintColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      referral.referredName,
                      style: textSemiBold.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium!.color,
                        fontSize: Dimensions.fontSizeDefault,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      referral.locationLabel,
                      style: textRegular.copyWith(
                        color: Theme.of(context).colorScheme.secondaryFixedDim,
                        fontSize: Dimensions.fontSizeExtraSmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeSmall,
                  vertical: Dimensions.paddingSizeExtraSmall,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  referral.statusLabel,
                  style: textSemiBold.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontSize: Dimensions.fontSizeExtraSmall,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                referral.progressLabel,
                style: textSemiBold.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium!.color,
                  fontSize: Dimensions.fontSizeSmall,
                ),
              ),
              Text(
                '${referral.progressPercent.toStringAsFixed(0)}%',
                style: textRegular.copyWith(
                  color: Theme.of(context).colorScheme.secondaryFixedDim,
                  fontSize: Dimensions.fontSizeExtraSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor:
                  Theme.of(context).hintColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          _ReferralStatusRow(
            icon: Icons.flag_rounded,
            text: referral.nextStepLabel,
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          _ReferralStatusRow(
            icon: Icons.calendar_month_rounded,
            text: referral.createdAtLabel != null
                ? 'Cadastro em ${referral.createdAtLabel}'
                : 'Data de cadastro não informada',
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            decoration: BoxDecoration(
              color: Theme.of(context).highlightColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ReferralPointInfo(
                        title: 'Liberados',
                        value: '${referral.referrerPointsReleased}',
                        subtitle: 'pontos',
                      ),
                    ),
                    Container(
                      height: 34,
                      width: 1,
                      color:
                          Theme.of(context).hintColor.withValues(alpha: 0.18),
                    ),
                    Expanded(
                      child: _ReferralPointInfo(
                        title: 'Restantes',
                        value: '${referral.referrerPointsRemaining}',
                        subtitle: 'pontos',
                      ),
                    ),
                    Container(
                      height: 34,
                      width: 1,
                      color:
                          Theme.of(context).hintColor.withValues(alpha: 0.18),
                    ),
                    Expanded(
                      child: _ReferralPointInfo(
                        title: 'Total',
                        value: '${referral.maxReferrerPoints}',
                        subtitle: 'pontos',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralStatusRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ReferralStatusRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: Dimensions.paddingSizeExtraSmall),
        Expanded(
          child: Text(
            text,
            style: textRegular.copyWith(
              color: Theme.of(context).colorScheme.secondaryFixedDim,
              fontSize: Dimensions.fontSizeExtraSmall,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReferralPointInfo extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _ReferralPointInfo({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: textRegular.copyWith(
            color: Theme.of(context).colorScheme.secondaryFixedDim,
            fontSize: Dimensions.fontSizeExtraSmall,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          style: textBold.copyWith(
            color: Theme.of(context).primaryColor,
            fontSize: Dimensions.fontSizeDefault,
          ),
        ),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: textRegular.copyWith(
            color: Theme.of(context).colorScheme.secondaryFixedDim,
            fontSize: Dimensions.fontSizeExtraSmall,
          ),
        ),
      ],
    );
  }
}

class _ReferralEmptyState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ReferralEmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.group_add_rounded,
            color: Theme.of(context).primaryColor,
            size: 36,
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(
            'Nenhuma indicação encontrada',
            textAlign: TextAlign.center,
            style: textSemiBold.copyWith(
              color: Theme.of(context).textTheme.bodyMedium!.color,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text(
            'Quando alguém se cadastrar usando seu código, o progresso aparecerá aqui.',
            textAlign: TextAlign.center,
            style: textRegular.copyWith(
              color: Theme.of(context).colorScheme.secondaryFixedDim,
              fontSize: Dimensions.fontSizeSmall,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
                vertical: Dimensions.paddingSizeSmall,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
              child: Text(
                'Atualizar',
                style: textSemiBold.copyWith(
                  color: Theme.of(context).cardColor,
                  fontSize: Dimensions.fontSizeSmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
