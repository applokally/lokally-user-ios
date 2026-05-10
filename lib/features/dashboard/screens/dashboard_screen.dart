import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/domain/models/navigation_model.dart';
import 'package:ride_sharing_user_app/features/home/screens/home_screen.dart';
import 'package:ride_sharing_user_app/features/profile/screens/profile_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_home_screen.dart';
import 'package:ride_sharing_user_app/features/trip/screens/trip_screen.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final PageStorageBucket bucket = PageStorageBucket();

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    final List<NavigationModel> item = [
      NavigationModel(
        name: 'home'.tr,
        activeIcon: Images.homeActive,
        inactiveIcon: Images.homeOutline,
        screen: const HomeScreen(),
      ),
      NavigationModel(
        name: 'activity'.tr,
        activeIcon: Images.activityActive,
        inactiveIcon: Images.activityOutline,
        screen: const TripScreen(fromProfile: false),
      ),
      NavigationModel(
        name: 'Loja',
        activeIcon: 'assets/image/loja.png',
        inactiveIcon: 'assets/image/loja.png',
        screen: const StoreHomeScreen(),
      ),
      NavigationModel(
        name: 'profile'.tr,
        activeIcon: Images.profileActive,
        inactiveIcon: Images.profileOutline,
        screen: const ProfileScreen(),
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, val) async {
        if (Get.find<BottomMenuController>().currentTab != 0) {
          Get.find<BottomMenuController>().setTabIndex(0);
          return;
        } else {
          Get.find<BottomMenuController>().exitApp();
        }
      },
      child: GetBuilder<BottomMenuController>(
        builder: (menuController) {
          return SafeArea(
            top: false,
            child: Scaffold(
              extendBody: true,
              resizeToAvoidBottomInset: false,
              body: PageStorage(
                bucket: bucket,
                child: item[menuController.currentTab].screen,
              ),
              bottomNavigationBar: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Container(
                  height: 62,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: primaryColor,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 8),
                        blurRadius: 20,
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ],
                  ),
                  child: Row(
                    children: generateBottomNavigationItems(
                      menuController,
                      item,
                      primaryColor,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> generateBottomNavigationItems(
    BottomMenuController menuController,
    List<NavigationModel> item,
    Color primaryColor,
  ) {
    List<Widget> items = [];

    for (int index = 0; index < item.length; index++) {
      items.add(
        Expanded(
          child: CustomMenuItem(
            isSelected: menuController.currentTab == index,
            name: item[index].name,
            activeIcon: item[index].activeIcon,
            inActiveIcon: item[index].inactiveIcon,
            onTap: () => menuController.setTabIndex(index),
            primaryColor: primaryColor,
          ),
        ),
      );
    }

    return items;
  }
}

class CustomMenuItem extends StatelessWidget {
  final bool isSelected;
  final String name;
  final String activeIcon;
  final String inActiveIcon;
  final VoidCallback onTap;
  final Color primaryColor;

  const CustomMenuItem({
    super.key,
    required this.isSelected,
    required this.name,
    required this.activeIcon,
    required this.inActiveIcon,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final String iconPath = isSelected ? activeIcon : inActiveIcon;
    final double iconSize = isSelected ? 28 : 23;
    const Color inactiveGreen = Color(0xFF006B60);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 30,
              child: Center(
                child: Image.asset(
                  iconPath,
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 70,
              child: Text(
                name.tr,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: (isSelected ? textBold : textMedium).copyWith(
                  color: isSelected ? primaryColor : inactiveGreen,
                  fontSize: isSelected ? 10.2 : 9.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
