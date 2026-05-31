import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

import 'store_seller_products_screen.dart';
import 'store_seller_real_estate_form_screen.dart';
import 'store_seller_service_form_screen.dart';
import 'store_seller_vehicle_form_screen.dart';

class StoreSellerPublishTypeScreen extends StatelessWidget {
  const StoreSellerPublishTypeScreen({super.key});

  void openPublishFlow(String type) {
    if (type == 'product') {
      Get.to(() => const StoreSellerProductsScreen());
      return;
    }

    if (type == 'vehicle') {
      Get.to(() => const StoreSellerVehicleFormScreen());
      return;
    }

    if (type == 'real_estate') {
      Get.to(() => const StoreSellerRealEstateFormScreen());
      return;
    }

    if (type == 'service') {
      Get.to(() => const StoreSellerServiceFormScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F6),
      body: Column(
        children: [
          StoreSellerPublishTopBar(
            primaryColor: primaryColor,
            title: 'store_publish_new_listing'.tr,
            onBackTap: () => Get.back(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Dimensions.paddingSizeDefault,
                20,
                Dimensions.paddingSizeDefault,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StoreSellerPublishIntroCard(primaryColor: primaryColor),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 0.92,
                    children: [
                      StoreSellerPublishTypeCard(
                        primaryColor: primaryColor,
                        title: 'store_products'.tr,
                        description: 'store_publish_products_description'.tr,
                        icon: Icons.inventory_2_outlined,
                        onTap: () => openPublishFlow('product'),
                      ),
                      StoreSellerPublishTypeCard(
                        primaryColor: primaryColor,
                        title: 'store_vehicles'.tr,
                        description: 'store_publish_vehicles_description'.tr,
                        icon: Icons.directions_car_filled_outlined,
                        onTap: () => openPublishFlow('vehicle'),
                      ),
                      StoreSellerPublishTypeCard(
                        primaryColor: primaryColor,
                        title: 'store_properties'.tr,
                        description: 'store_publish_properties_description'.tr,
                        icon: Icons.home_work_outlined,
                        onTap: () => openPublishFlow('real_estate'),
                      ),
                      StoreSellerPublishTypeCard(
                        primaryColor: primaryColor,
                        title: 'store_services'.tr,
                        description: 'store_publish_services_description'.tr,
                        icon: Icons.design_services_outlined,
                        onTap: () => openPublishFlow('service'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerPublishTopBar extends StatelessWidget {
  final Color primaryColor;
  final String title;
  final VoidCallback onBackTap;

  const StoreSellerPublishTopBar({
    super.key,
    required this.primaryColor,
    required this.title,
    required this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: primaryColor,
      padding: EdgeInsets.fromLTRB(
        14,
        MediaQuery.of(context).padding.top + 12,
        14,
        14,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBackTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: textBold.copyWith(
                color: Colors.white,
                fontSize: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerPublishIntroCard extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerPublishIntroCard({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.add_business_outlined,
              color: primaryColor,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'store_publish_intro_title'.tr,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 20,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'store_publish_intro_subtitle'.tr,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 13.2,
                    height: 1.32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerPublishTypeCard extends StatelessWidget {
  final Color primaryColor;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const StoreSellerPublishTypeCard({
    super.key,
    required this.primaryColor,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 10),
                blurRadius: 22,
                color: Colors.black.withValues(alpha: 0.045),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: primaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 15.3,
                ),
              ),
              const SizedBox(height: 7),
              Expanded(
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 11.2,
                    height: 1.18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
