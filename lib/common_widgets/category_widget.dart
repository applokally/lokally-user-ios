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
    final String imageUrl =
        '${Get.find<ConfigController>().config?.imageBaseUrl?.vehicleCategory}/${category.image}';

    return Padding(
      padding: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Get.find<RideController>().setRideCategoryIndex(index);
          if (!fromSelect) {
            Get.to(() => const SetDestinationScreen());
          }
        },
        child: SizedBox(
          width: 75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.transparent,
                ),
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
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
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Image.asset(
                        Images.offerIcon,
                        height: 16,
                        width: 16,
                        color: (isSelected ?? false)
                            ? Theme.of(context).cardColor
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 75,
                child: Text(
                  category.name ?? '',
                  style: textSemiBold.copyWith(
                    color: Theme.of(context)
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
