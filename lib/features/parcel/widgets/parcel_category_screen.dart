import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class ParcelCategoryView extends StatelessWidget {
  final bool isDetails;

  const ParcelCategoryView({
    super.key,
    this.isDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ParcelController>(
      builder: (parcelController) {
        final categories = parcelController.parcelCategoryList;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isDetails) const SizedBox(height: Dimensions.paddingSizeLarge),
            if (!isDetails)
              Text(
                'Selecione o tipo de serviço',
                style: textSemiBold.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontSize: Dimensions.fontSizeDefault,
                ),
              ),
            if (!isDetails) const SizedBox(height: Dimensions.paddingSizeSmall),
            if (categories == null)
              const _CategorySkeletonRow()
            else if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: Dimensions.paddingSizeLarge,
                ),
                child: Center(
                  child: Text(
                    'no_parcel_category_found'.tr,
                    textAlign: TextAlign.center,
                    style: textRegular.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 146,
                width: double.infinity,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final bool selected =
                        parcelController.selectedParcelCategory == index;

                    return _ParcelCategoryCard(
                      name: category.name ?? '',
                      image: category.image ?? '',
                      selected: selected,
                      onTap: () {
                        parcelController.updateParcelCategoryIndex(index);
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ParcelCategoryCard extends StatelessWidget {
  final String name;
  final String image;
  final bool selected;
  final VoidCallback onTap;

  const _ParcelCategoryCard({
    required this.name,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String baseUrl =
        Get.find<ConfigController>().config?.imageBaseUrl?.parcel ?? '';

    final String imageUrl =
        image.startsWith('http://') || image.startsWith('https://')
            ? image
            : '$baseUrl/$image';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      child: SizedBox(
        width: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 104,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).cardColor
                      : Theme.of(context).primaryColor,
                  width: selected ? 3 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  Dimensions.radiusDefault - 2,
                ),
                child: ImageWidget(
                  image: imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 112,
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textMedium.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: selected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySkeletonRow extends StatelessWidget {
  const _CategorySkeletonRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 146,
      child: Row(
        children: List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(
              right: index == 2 ? 0 : Dimensions.paddingSizeDefault,
            ),
            child: Column(
              children: [
                Container(
                  width: 112,
                  height: 104,
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor.withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(Dimensions.radiusDefault),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
