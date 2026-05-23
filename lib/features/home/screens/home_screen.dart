import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/home/widgets/banner_view.dart';
import 'package:ride_sharing_user_app/features/home/widgets/best_offers_widget.dart';
import 'package:ride_sharing_user_app/features/home/widgets/category_view.dart';
import 'package:ride_sharing_user_app/features/home/widgets/coupon_home_widget.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_map_view.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_search_widget.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_referral_view_widget.dart';
import 'package:ride_sharing_user_app/features/home/widgets/visit_to_mart_widget.dart';
import 'package:ride_sharing_user_app/features/my_offer/controller/offer_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/points_club/screens/points_club_home_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/screens/parcel_list_view_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/driver_request_dialog.dart';
import 'package:ride_sharing_user_app/features/ride/screens/ride_list_view_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/splash/domain/models/config_model.dart';
import 'package:ride_sharing_user_app/helper/home_screen_helper.dart';
import 'package:ride_sharing_user_app/helper/pusher_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/address/controllers/address_controller.dart';
import 'package:ride_sharing_user_app/features/home/controllers/banner_controller.dart';
import 'package:ride_sharing_user_app/features/home/controllers/category_controller.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_my_address.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  JustTheController rideShareToolTip = JustTheController();
  JustTheController parcelDeliveryToolTip = JustTheController();
  final ScrollController _scrollController = ScrollController();
  bool _isShowRideIcon = true;
  late final AnimationController _clubLogoAnimationController;
  late final Animation<double> _clubLogoScaleAnimation;

  String greetingMessage() {
    var timeNow = DateTime.now().hour;
    if (timeNow <= 12) {
      return 'good_morning'.tr;
    } else if ((timeNow > 12) && (timeNow <= 16)) {
      return 'good_afternoon'.tr;
    } else if ((timeNow > 16) && (timeNow < 20)) {
      return 'good_evening'.tr;
    } else {
      return 'good_night'.tr;
    }
  }

  @override
  void initState() {
    super.initState();

    _clubLogoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat(reverse: true);

    _clubLogoScaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _clubLogoAnimationController,
      curve: Curves.easeInOut,
    ));

    Get.find<AddressController>().updateLastLocation();

    _scrollController.addListener(() {
      if (_scrollController.offset > 20) {
        setState(() {
          _isShowRideIcon = false;
        });
      } else {
        setState(() {
          _isShowRideIcon = true;
        });
      }
    });

    loadData();
  }

  @override
  void dispose() {
    rideShareToolTip.dispose();
    parcelDeliveryToolTip.dispose();
    _clubLogoAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool clickedMenu = false;
  Future<void> loadData({bool isReload = false}) async {
    if (isReload) {
      Get.find<ConfigController>().getConfigData();
    }

    Get.find<ParcelController>().getUnpaidParcelList();
    Get.find<BannerController>().getBannerList();
    Get.find<CategoryController>().getCategoryList();
    Get.find<AddressController>().getAddressList(1);
    Get.find<CategoryController>().setCouponFilterIndex(0, isUpdate: false);
    Get.find<OfferController>().getOfferList(1);

    if (Get.find<ProfileController>().profileModel == null) {
      Get.find<ProfileController>().getProfileInfo();
    }

    await Get.find<RideController>().getRunningRideList();
    if (Get.find<RideController>().runningRideList?.data != null) {
      for (var element in Get.find<RideController>().runningRideList!.data!) {
        PusherHelper().pusherDriverStatus(element.id!);
      }
    }

    await Get.find<RideController>().getCurrentRegularRide();
    if (Get.find<RideController>().rideDetails != null) {
      Get.find<RideController>()
          .getBiddingList(Get.find<RideController>().rideDetails!.id!, 1);
    } else {
      Get.find<RideController>().clearBiddingList();
    }

    await Get.find<ParcelController>().getRunningParcelList();
    if (Get.find<ParcelController>().parcelListModel!.data!.isNotEmpty) {
      for (var element in Get.find<ParcelController>().parcelListModel!.data!) {
        PusherHelper().pusherDriverStatus(element.id!);
      }
    }

    await Get.find<RideController>().getNearestDriverList(
      Get.find<LocationController>().getUserAddress()!.latitude!.toString(),
      Get.find<LocationController>().getUserAddress()!.longitude!.toString(),
    );

    HomeScreenHelper.checkMaintanceMode();
  }

  @override
  Widget build(BuildContext context) {
    ConfigModel? config = Get.find<ConfigController>().config;

    return Scaffold(
      body: GetBuilder<ProfileController>(builder: (profileController) {
        return GetBuilder<RideController>(builder: (rideController) {
          return GetBuilder<ParcelController>(builder: (parcelController) {
            return BodyWidget(
              appBar: _HomeClubHeaderAppBar(
                headerTitle:
                    '${greetingMessage()}, ${profileController.customerFirstName()}',
                logoScaleAnimation: _clubLogoScaleAnimation,
              ),
              body: RefreshIndicator(
                onRefresh: () async {
                  await loadData(isReload: true);
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                        child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          top: Dimensions.paddingSize,
                          left: Dimensions.paddingSize,
                          right: Dimensions.paddingSize,
                        ),
                        child: Column(children: [
                          const BannerView(),
                          const Padding(
                            padding:
                                EdgeInsets.only(top: Dimensions.paddingSize),
                            child: CategoryView(),
                          ),
                          if ((config?.externalSystem ?? false) &&
                              Get.find<AuthController>().isLoggedIn()) ...[
                            const VisitToMartWidget(),
                            const SizedBox(
                                height: Dimensions.paddingSizeDefault)
                          ],
                          const HomeSearchWidget(),
                        ]),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),
                      Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: Dimensions.paddingSizeDefault),
                          child: HomeMapView(title: 'rider_around_you')),
                      const Padding(
                        padding: EdgeInsets.only(
                          top: Dimensions.paddingSize,
                          left: Dimensions.paddingSize,
                          right: Dimensions.paddingSize,
                        ),
                        child: const HomeMyAddress(),
                      ),
                      if (config?.referralEarningStatus ?? false)
                        Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: Dimensions.paddingSizeDefault),
                            child: const HomeReferralViewWidget()),
                      const BestOfferWidget(),
                      const HomeCouponWidget(),
                      const SizedBox(height: 100)
                    ])),
                  ],
                ),
              ),
            );
          });
        });
      }),
      floatingActionButton:
          GetBuilder<RideController>(builder: (rideController) {
        if (Get.find<ConfigController>().isShowToolTips) {
          showToolTips();
        }
        return Column(mainAxisSize: MainAxisSize.min, children: [
          (Get.find<ParcelController>().parcelListModel?.totalSize ?? 0) > 0 &&
                  _isShowRideIcon
              ? Padding(
                  padding: EdgeInsets.only(
                      bottom: rideController.biddingList.isEmpty &&
                              ((rideController.runningRideList?.data?.length ??
                                      0) ==
                                  0)
                          ? Get.height * 0.08
                          : 0),
                  child: JustTheTooltip(
                    backgroundColor: Get.isDarkMode
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).textTheme.bodyMedium!.color,
                    controller: parcelDeliveryToolTip,
                    preferredDirection: AxisDirection.right,
                    tailLength: 10,
                    tailBaseWidth: 20,
                    content: Container(
                      width: 150,
                      padding:
                          const EdgeInsets.all(Dimensions.paddingSizeSmall),
                      child: Text(
                        'parcel_delivery'.tr,
                        style: textRegular.copyWith(
                          color: Colors.white,
                          fontSize: Dimensions.fontSizeDefault,
                        ),
                      ),
                    ),
                    child: InkWell(
                      onTap: () => Get.to(() => const ParcelListViewScreen(
                          title: 'ongoing_parcel_list')),
                      child: Stack(children: [
                        Container(
                          height: 38,
                          width: 38,
                          padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
                          margin:
                              EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).primaryColor),
                          child: Image.asset(Images.parcelDeliveryIcon),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            height: 20,
                            width: 20,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).cardColor),
                            child: Center(
                              child: Container(
                                height: 18,
                                width: 18,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context).colorScheme.error),
                                child: Center(
                                    child: Text(
                                  '${Get.find<ParcelController>().parcelListModel?.totalSize}',
                                  style: textRegular.copyWith(
                                      color: Theme.of(context).cardColor,
                                      fontSize: Dimensions.fontSizeSmall),
                                )),
                              ),
                            ),
                          ),
                        )
                      ]),
                    ),
                  ),
                )
              : const SizedBox(),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          (rideController.runningRideList?.data?.length ?? 0) > 0 &&
                  _isShowRideIcon
              ? Padding(
                  padding: EdgeInsets.only(
                      bottom: rideController.biddingList.isEmpty
                          ? Get.height * 0.08
                          : 0),
                  child: JustTheTooltip(
                    backgroundColor: Get.isDarkMode
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).textTheme.bodyMedium!.color,
                    controller: rideShareToolTip,
                    preferredDirection: AxisDirection.right,
                    tailLength: 10,
                    tailBaseWidth: 20,
                    content: Container(
                      width: 100,
                      padding:
                          const EdgeInsets.all(Dimensions.paddingSizeSmall),
                      child: Text(
                        'ride_share'.tr,
                        style: textRegular.copyWith(
                          color: Colors.white,
                          fontSize: Dimensions.fontSizeDefault,
                        ),
                      ),
                    ),
                    child: InkWell(
                      onTap: () => Get.to(() => const RideListViewScreen()),
                      child: Stack(children: [
                        Container(
                          height: 38,
                          width: 38,
                          padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
                          margin:
                              EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).primaryColor),
                          child: Image.asset(Images.rideShareIcon),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            height: 20,
                            width: 20,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).cardColor),
                            child: Center(
                              child: Container(
                                height: 18,
                                width: 18,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context).colorScheme.error),
                                child: Center(
                                    child: Text(
                                  '${rideController.runningRideList?.data?.length}',
                                  style: textRegular.copyWith(
                                      color: Theme.of(context).cardColor,
                                      fontSize: Dimensions.fontSizeSmall),
                                )),
                              ),
                            ),
                          ),
                        )
                      ]),
                    ),
                  ),
                )
              : const SizedBox(),
          rideController.biddingList.isNotEmpty && _isShowRideIcon
              ? Padding(
                  padding: EdgeInsets.only(bottom: Get.height * 0.08),
                  child: InkWell(
                    onTap: () {
                      if (!rideController.isLoading) {
                        rideController
                            .getBiddingList(rideController.rideDetails!.id!, 1)
                            .then((value) {
                          if (rideController.biddingList.isNotEmpty) {
                            Get.dialog(
                                barrierDismissible: true,
                                barrierColor:
                                    Colors.black.withValues(alpha: 0.5),
                                transitionDuration:
                                    const Duration(milliseconds: 500),
                                DriverRideRequestDialog(
                                    tripId: Get.find<RideController>()
                                        .rideDetails!
                                        .id!));
                          }
                        });
                      }
                    },
                    child: Stack(children: [
                      Container(
                        height: 38,
                        width: 38,
                        padding: EdgeInsets.all(Dimensions.paddingSizeSeven),
                        margin:
                            EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).primaryColor),
                        child: Image.asset(Images.biddingIcon),
                      ),
                      Positioned(
                        right: 0,
                        top: 6,
                        child: Container(
                          height: 12,
                          width: 12,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).cardColor),
                          child: Center(
                              child: Container(
                            height: 10,
                            width: 10,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.error),
                          )),
                        ),
                      )
                    ]),
                  ),
                )
              : const SizedBox()
        ]);
      }),
    );
  }

  void showToolTips() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1)).then((_) {
        int ridingCount =
            (Get.find<RideController>().runningRideList?.data?.length ?? 0);
        int parcelCount =
            Get.find<ParcelController>().parcelListModel?.totalSize ?? 0;
        if (ridingCount > 0 && _isShowRideIcon) {
          rideShareToolTip.showTooltip();
          Get.find<ConfigController>().hideToolTips();
          Future.delayed(const Duration(seconds: 5)).then((_) {
            rideShareToolTip.hideTooltip();
          });
        }

        if (parcelCount > 0 && _isShowRideIcon) {
          parcelDeliveryToolTip.showTooltip();
          Get.find<ConfigController>().hideToolTips();
          Future.delayed(const Duration(seconds: 5)).then((_) {
            parcelDeliveryToolTip.hideTooltip();
          });
        }
      });
    });
  }
}

class _HomeClubHeaderAppBar extends AppBarWidget {
  final String headerTitle;
  final Animation<double> logoScaleAnimation;

  _HomeClubHeaderAppBar({
    required this.headerTitle,
    required this.logoScaleAnimation,
  }) : super(
          title: headerTitle,
          showBackButton: false,
          isHome: true,
          fontSize: Dimensions.fontSizeLarge,
        );

  @override
  Size get preferredSize => const Size.fromHeight(122);

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color deepGreen = Color.lerp(primaryColor, Colors.black, 0.20)!;
    final String address = _currentAddress();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            deepGreen,
            primaryColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeSmall,
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeDefault,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Image.asset(
                    'assets/image/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.location_on_rounded,
                      color: primaryColor,
                      size: 27,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textMedium.copyWith(
                        color: Colors.white,
                        fontSize: Dimensions.fontSizeLarge,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address.isNotEmpty ? address : 'Localização atual',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textRegular.copyWith(
                              color: Colors.white.withValues(alpha: 0.94),
                              fontSize: Dimensions.fontSizeExtraSmall,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              GestureDetector(
                onTap: () => Get.to(() => const PointsClubHomeScreen()),
                child: ScaleTransition(
                  scale: logoScaleAnimation,
                  child: Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 15,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/image/logo_clube.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.diamond_rounded,
                        color: primaryColor,
                        size: 31,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _currentAddress() {
    try {
      final LocationController locationController =
          Get.find<LocationController>();

      final String savedAddress =
          locationController.getUserAddress()?.address?.trim() ?? '';

      if (savedAddress.isNotEmpty) {
        return savedAddress;
      }

      final String currentAddress = locationController.address.trim();

      if (currentAddress.isNotEmpty) {
        return currentAddress;
      }

      return locationController.pickAddress.trim();
    } catch (_) {
      return '';
    }
  }
}
