import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/home/domain/models/categoty_model.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/set_destination/screens/set_destination_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class CategoryWidget extends StatelessWidget {
  final Category category;
  final bool? isSelected;
  final bool fromSelect;
  final int index;
  final Function(void)? onTap;

  const CategoryWidget({
    super.key,
    required this.category,
    this.isSelected,
    this.fromSelect = false,
    required this.index,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = isSelected ?? false;

    final String imageUrl =
        '${Get.find<ConfigController>().config?.imageBaseUrl?.vehicleCategory}/${category.image}';

    return Padding(
      padding: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Get.find<RideController>().setRideCategoryIndex(index);

          if (fromSelect) {
            onTap?.call(null);
          }

          if (!fromSelect) {
            Get.to(() => const SetDestinationScreen());
          }
        },
        child: SizedBox(
          width: 75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: selected
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).primaryColor
                        : Colors.transparent,
                    width: selected ? 2.4 : 0,
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
                margin: EdgeInsets.zero,
                padding: EdgeInsets.all(selected ? 3 : 0),
                clipBehavior: Clip.antiAlias,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(selected ? 11 : 10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      category.id == '0'
                          ? Image.asset(
                              category.image ?? '',
                              fit: BoxFit.cover,
                            )
                          : ImageWidget(
                              image: imageUrl,
                              fit: BoxFit.cover,
                            ),
                      if (selected)
                        Container(
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.10),
                        ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Image.asset(
                          Images.offerIcon,
                          height: 16,
                          width: 16,
                          color: selected ? Theme.of(context).cardColor : null,
                        ),
                      ),
                      if (selected)
                        Positioned(
                          right: 5,
                          bottom: 5,
                          child: Container(
                            width: 19,
                            height: 19,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).cardColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              color: Theme.of(context).cardColor,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 75,
                child: Text(
                  category.name ?? '',
                  style: textSemiBold.copyWith(
                    color: selected
                        ? Theme.of(context).primaryColor
                        : Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.8),
                    fontSize: Dimensions.fontSizeSmall,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
