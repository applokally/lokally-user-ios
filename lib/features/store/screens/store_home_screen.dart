import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/store/screens/seller/store_seller_dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_seller_registration_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_product_details_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_cart_screen.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_marketplace_header.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreHomeScreen extends StatefulWidget {
  const StoreHomeScreen({super.key});

  @override
  State<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class _StoreHomeScreenState extends State<StoreHomeScreen> {
  static const String sellerLastStatusSignatureKey =
      'lokally_store_seller_last_status_signature';
  static const String marketplaceZoneCacheIdKey =
      'lokally_store_marketplace_zone_id';
  static const String marketplaceZoneCacheLatKey =
      'lokally_store_marketplace_zone_latitude';
  static const String marketplaceZoneCacheLngKey =
      'lokally_store_marketplace_zone_longitude';
  static const String marketplaceZoneCacheCheckedAtKey =
      'lokally_store_marketplace_zone_checked_at';

  static const double marketplaceZoneCacheDistanceMeters = 1000;
  static const Duration marketplaceZoneCacheDuration = Duration(minutes: 15);

  static const String publicCategoriesUri = '/api/store/public-categories';
  static const String publicProductsUri = '/api/store/products';
  static const String marketplaceSettingsUri = '/api/store/settings';
  static const String marketplaceBannersUri = '/api/store/banners';
  static const String boostedProductsUri = '/api/store/boosted-products';
  static const String boostedCategoriesUri = '/api/store/boosted-categories';
  static const String boostInsightUri = '/api/store/boost-insight';

  int selectedMainCategoryIndex = 0;
  String selectedSubcategoryId = '';
  String searchQuery = '';
  int selectedMarketplaceBannerIndex = 0;
  int selectedBoostedProductIndex = 0;

  bool isCheckingSellerStatus = false;
  bool isApprovedSeller = false;
  bool isLoadingPublicStore = false;
  bool hasLoadedPublicStore = false;
  bool isLoadingMarketplaceSettings = false;
  bool hasLoadedMarketplaceSettings = false;
  bool isLoadingMarketplaceBanners = false;
  bool hasLoadedMarketplaceBanners = false;
  bool isLoadingBoostedProducts = false;
  bool hasLoadedBoostedProducts = false;
  bool isLoadingBoostedCategories = false;
  bool hasLoadedBoostedCategories = false;
  bool isPreparingMarketplaceInitialLayout = true;
  bool isRefreshingMarketplaceZoneInBackground = false;
  String? currentMarketplaceZoneId;

  StoreMarketplaceSettings marketplaceSettings =
      StoreMarketplaceSettings.defaults();

  final ScrollController welcomeCarouselController = ScrollController();
  final PageController marketplaceBannerPageController = PageController();
  final PageController boostedProductsPageController = PageController(
    viewportFraction: 0.94,
  );
  Timer? welcomeCarouselTimer;
  Timer? marketplaceBannerTimer;
  Timer? boostedProductsTimer;
  final Set<String> trackedBoostViewIds = <String>{};
  final Set<String> trackedBoostCategoryViewIds = <String>{};

  List<StoreCategoryData> mainCategories = <StoreCategoryData>[
    StoreCategoryData.all(),
  ];

  List<StoreProductData> products = <StoreProductData>[];
  List<StoreProductData> boostedProducts = <StoreProductData>[];
  List<StoreBoostedCategoryData> boostedCategories =
      <StoreBoostedCategoryData>[];
  List<StoreMarketplaceBannerData> marketplaceBanners =
      <StoreMarketplaceBannerData>[];

  @override
  void initState() {
    super.initState();
    startWelcomeCarousel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadPublicStore();
    });
  }

  @override
  void dispose() {
    welcomeCarouselTimer?.cancel();
    marketplaceBannerTimer?.cancel();
    boostedProductsTimer?.cancel();
    welcomeCarouselController.dispose();
    marketplaceBannerPageController.dispose();
    boostedProductsPageController.dispose();
    super.dispose();
  }

  String? normalizeMarketplaceZoneId(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is List) {
      for (final dynamic item in value) {
        final String? itemZoneId = normalizeMarketplaceZoneId(item);

        if (itemZoneId != null && itemZoneId.isNotEmpty) {
          return itemZoneId;
        }
      }

      return null;
    }

    if (value is Map) {
      for (final String key in <String>[
        'zone_id',
        'zoneId',
        'zone',
        'id',
      ]) {
        if (value.containsKey(key)) {
          final String? itemZoneId = normalizeMarketplaceZoneId(value[key]);

          if (itemZoneId != null && itemZoneId.isNotEmpty) {
            return itemZoneId;
          }
        }
      }

      return null;
    }

    final String rawValue = value.toString().trim();

    if (rawValue.isEmpty ||
        rawValue == 'null' ||
        rawValue == '[]' ||
        rawValue == '{}') {
      return null;
    }

    if (rawValue.startsWith('[') || rawValue.startsWith('{')) {
      try {
        return normalizeMarketplaceZoneId(jsonDecode(rawValue));
      } catch (_) {
        return null;
      }
    }

    return rawValue;
  }

  double? parseMarketplaceDouble(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  String? resolveSavedMarketplaceZoneId() {
    try {
      final ApiClient apiClient = Get.find<ApiClient>();

      final String? savedZoneId =
          apiClient.sharedPreferences.getString(AppConstants.zoneId);

      final String? normalizedSavedZoneId =
          normalizeMarketplaceZoneId(savedZoneId);

      if (normalizedSavedZoneId != null && normalizedSavedZoneId.isNotEmpty) {
        return normalizedSavedZoneId;
      }

      final String? savedAddress =
          apiClient.sharedPreferences.getString(AppConstants.userAddress);

      final String? normalizedAddressZoneId =
          normalizeMarketplaceZoneId(savedAddress);

      if (normalizedAddressZoneId != null &&
          normalizedAddressZoneId.isNotEmpty) {
        return normalizedAddressZoneId;
      }
    } catch (_) {}

    return null;
  }

  String? resolveImmediateMarketplaceZoneId() {
    final String? savedZoneId = resolveSavedMarketplaceZoneId();

    if (savedZoneId != null && savedZoneId.isNotEmpty) {
      return savedZoneId;
    }

    try {
      final ApiClient apiClient = Get.find<ApiClient>();
      final String? cachedZoneId = normalizeMarketplaceZoneId(
        apiClient.sharedPreferences.getString(marketplaceZoneCacheIdKey),
      );
      final int? cachedCheckedAt = int.tryParse(
        apiClient.sharedPreferences
                .getString(marketplaceZoneCacheCheckedAtKey) ??
            '',
      );

      if (cachedZoneId == null ||
          cachedZoneId.isEmpty ||
          cachedCheckedAt == null) {
        return null;
      }

      final Duration cacheAge = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(cachedCheckedAt),
      );

      if (cacheAge <= marketplaceZoneCacheDuration) {
        return cachedZoneId;
      }
    } catch (_) {}

    return null;
  }

  Future<String?> resolveMarketplaceZoneId() async {
    final ApiClient apiClient = Get.find<ApiClient>();
    final String? savedZoneId = resolveSavedMarketplaceZoneId();

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return savedZoneId;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return savedZoneId;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 6),
        ),
      );

      final double currentLat = position.latitude;
      final double currentLng = position.longitude;

      final String? cachedZoneId =
          apiClient.sharedPreferences.getString(marketplaceZoneCacheIdKey);
      final double? cachedLat = parseMarketplaceDouble(
        apiClient.sharedPreferences.getString(marketplaceZoneCacheLatKey),
      );
      final double? cachedLng = parseMarketplaceDouble(
        apiClient.sharedPreferences.getString(marketplaceZoneCacheLngKey),
      );
      final int? cachedCheckedAt = int.tryParse(
        apiClient.sharedPreferences
                .getString(marketplaceZoneCacheCheckedAtKey) ??
            '',
      );

      if (cachedZoneId != null &&
          cachedZoneId.isNotEmpty &&
          cachedLat != null &&
          cachedLng != null &&
          cachedCheckedAt != null) {
        final Duration cacheAge = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(cachedCheckedAt),
        );
        final double movedDistance = Geolocator.distanceBetween(
          cachedLat,
          cachedLng,
          currentLat,
          currentLng,
        );

        if (cacheAge <= marketplaceZoneCacheDuration &&
            movedDistance <= marketplaceZoneCacheDistanceMeters) {
          return cachedZoneId;
        }
      }

      final Response response = await apiClient.getData(
        '${AppConstants.getZone}?lat=$currentLat&lng=$currentLng',
      );

      final dynamic responseBody = response.body;
      String? resolvedZoneId;

      if (response.statusCode == 200 && responseBody is Map) {
        final dynamic dataValue = responseBody['data'];

        if (dataValue is Map) {
          resolvedZoneId = normalizeMarketplaceZoneId(dataValue['id']);
        }
      }

      await apiClient.sharedPreferences.setString(
        marketplaceZoneCacheLatKey,
        currentLat.toString(),
      );
      await apiClient.sharedPreferences.setString(
        marketplaceZoneCacheLngKey,
        currentLng.toString(),
      );
      await apiClient.sharedPreferences.setString(
        marketplaceZoneCacheCheckedAtKey,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

      if (resolvedZoneId != null && resolvedZoneId.isNotEmpty) {
        await apiClient.sharedPreferences.setString(
          marketplaceZoneCacheIdKey,
          resolvedZoneId,
        );

        return resolvedZoneId;
      }

      await apiClient.sharedPreferences.remove(marketplaceZoneCacheIdKey);
      return null;
    } catch (_) {
      return savedZoneId;
    }
  }

  Future<void> refreshMarketplaceZoneInBackground() async {
    if (isRefreshingMarketplaceZoneInBackground) {
      return;
    }

    isRefreshingMarketplaceZoneInBackground = true;

    try {
      final String? previousZoneId = currentMarketplaceZoneId;
      final String? refreshedZoneId = await resolveMarketplaceZoneId();

      if (!mounted ||
          refreshedZoneId == null ||
          refreshedZoneId.isEmpty ||
          refreshedZoneId == previousZoneId) {
        return;
      }

      setState(() {
        currentMarketplaceZoneId = refreshedZoneId;
        selectedMainCategoryIndex = 0;
        selectedSubcategoryId = '';
        selectedMarketplaceBannerIndex = 0;
        selectedBoostedProductIndex = 0;
      });

      await Future.wait<void>(<Future<void>>[
        loadPublicCategories(),
        loadMarketplaceBanners(),
        loadPublicProducts(),
      ]);

      unawaited(loadBoostedProducts());
      unawaited(loadBoostedCategories());
    } finally {
      isRefreshingMarketplaceZoneInBackground = false;
    }
  }

  String uriWithMarketplaceZone(String uri) {
    final String? zoneId = currentMarketplaceZoneId;

    if (zoneId == null || zoneId.isEmpty) {
      return uri;
    }

    final String separator = uri.contains('?') ? '&' : '?';

    return '$uri${separator}zone_id=${Uri.encodeComponent(zoneId)}';
  }

  void clearPublicStoreForUnavailableZone() {
    stopMarketplaceBannerCarousel();
    stopBoostedProductsCarousel();

    setState(() {
      products = <StoreProductData>[];
      boostedProducts = <StoreProductData>[];
      boostedCategories = <StoreBoostedCategoryData>[];
      marketplaceBanners = <StoreMarketplaceBannerData>[];
      selectedMarketplaceBannerIndex = 0;
      selectedBoostedProductIndex = 0;
      mainCategories = <StoreCategoryData>[StoreCategoryData.all()];
      selectedMainCategoryIndex = 0;
      selectedSubcategoryId = '';
      searchQuery = '';
      isLoadingPublicStore = false;
      hasLoadedPublicStore = true;
      isLoadingMarketplaceBanners = false;
      hasLoadedMarketplaceBanners = true;
      isLoadingBoostedProducts = false;
      hasLoadedBoostedProducts = true;
      isLoadingBoostedCategories = false;
      hasLoadedBoostedCategories = true;
    });
  }

  void startWelcomeCarousel() {
    welcomeCarouselTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !welcomeCarouselController.hasClients) {
        return;
      }

      final double maxScroll =
          welcomeCarouselController.position.maxScrollExtent;
      final double currentScroll = welcomeCarouselController.offset;
      final double nextScroll = currentScroll + 190;

      welcomeCarouselController.animateTo(
        nextScroll >= maxScroll ? 0 : nextScroll,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOut,
      );
    });
  }

  void stopMarketplaceBannerCarousel() {
    marketplaceBannerTimer?.cancel();
    marketplaceBannerTimer = null;
  }

  void restartMarketplaceBannerCarousel() {
    stopMarketplaceBannerCarousel();

    if (marketplaceBanners.length <= 1) {
      return;
    }

    marketplaceBannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !marketplaceBannerPageController.hasClients) {
        return;
      }

      if (marketplaceBanners.length <= 1) {
        return;
      }

      int nextIndex = selectedMarketplaceBannerIndex + 1;

      if (nextIndex >= marketplaceBanners.length) {
        nextIndex = 0;
      }

      marketplaceBannerPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOut,
      );
    });
  }

  void stopBoostedProductsCarousel() {
    boostedProductsTimer?.cancel();
    boostedProductsTimer = null;
  }

  void restartBoostedProductsCarousel() {
    stopBoostedProductsCarousel();

    if (boostedProducts.length <= 1) {
      return;
    }

    boostedProductsTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !boostedProductsPageController.hasClients) {
        return;
      }

      if (boostedProducts.length <= 1) {
        return;
      }

      int nextIndex = selectedBoostedProductIndex + 1;

      if (nextIndex >= boostedProducts.length) {
        nextIndex = 0;
      }

      boostedProductsPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> loadPublicStore() async {
    final bool hasNoVisibleStoreContent = products.isEmpty &&
        marketplaceBanners.isEmpty &&
        mainCategories.length <= 1;

    if (hasNoVisibleStoreContent && mounted) {
      setState(() {
        isPreparingMarketplaceInitialLayout = true;
      });
    }

    try {
      final Future<StoreMarketplaceSettings> settingsFuture =
          loadMarketplaceSettings();
      String? resolvedZoneId = resolveImmediateMarketplaceZoneId();

      if (resolvedZoneId != null && resolvedZoneId.isNotEmpty && mounted) {
        setState(() {
          currentMarketplaceZoneId = resolvedZoneId;
        });
      }

      final StoreMarketplaceSettings settings = await settingsFuture;

      if (!settings.marketplaceEnabled) {
        if (!mounted) {
          return;
        }

        stopMarketplaceBannerCarousel();
        stopBoostedProductsCarousel();

        setState(() {
          products = <StoreProductData>[];
          boostedProducts = <StoreProductData>[];
          boostedCategories = <StoreBoostedCategoryData>[];
          marketplaceBanners = <StoreMarketplaceBannerData>[];
          selectedMarketplaceBannerIndex = 0;
          mainCategories = <StoreCategoryData>[StoreCategoryData.all()];
          selectedMainCategoryIndex = 0;
          selectedSubcategoryId = '';
          searchQuery = '';
          isLoadingPublicStore = false;
          hasLoadedPublicStore = true;
          isLoadingMarketplaceBanners = false;
          hasLoadedMarketplaceBanners = true;
          isLoadingBoostedProducts = false;
          hasLoadedBoostedProducts = true;
          isLoadingBoostedCategories = false;
          hasLoadedBoostedCategories = true;
          selectedBoostedProductIndex = 0;
          isPreparingMarketplaceInitialLayout = false;
        });
        return;
      }

      if (resolvedZoneId == null || resolvedZoneId.isEmpty) {
        resolvedZoneId = await resolveMarketplaceZoneId();

        if (mounted) {
          setState(() {
            currentMarketplaceZoneId = resolvedZoneId;
          });
        }
      } else {
        unawaited(refreshMarketplaceZoneInBackground());
      }

      if (resolvedZoneId == null || resolvedZoneId.isEmpty) {
        if (!mounted) {
          return;
        }

        clearPublicStoreForUnavailableZone();
        return;
      }

      if (mounted) {
        setState(() {
          isPreparingMarketplaceInitialLayout = false;
        });
      }

      await Future.wait<void>(<Future<void>>[
        loadPublicCategories(),
        loadMarketplaceBanners(),
        loadPublicProducts(),
      ]);

      unawaited(loadBoostedProducts());
      unawaited(loadBoostedCategories());
      unawaited(checkSellerStatusOnOpen());
    } finally {
      if (mounted) {
        setState(() {
          isPreparingMarketplaceInitialLayout = false;
        });
      }
    }
  }

  String get marketplaceBannerRequestUri {
    final StoreCategoryData selected = selectedMainCategory;

    if (selected.isAll) {
      return uriWithMarketplaceZone('$marketplaceBannersUri?placement=home');
    }

    return uriWithMarketplaceZone(
      '$marketplaceBannersUri?placement=category&category_id=${Uri.encodeComponent(selected.id)}',
    );
  }

  Future<void> loadMarketplaceBanners() async {
    if (isLoadingMarketplaceBanners) {
      return;
    }

    if (mounted) {
      setState(() {
        isLoadingMarketplaceBanners = true;

        if (marketplaceBanners.isEmpty) {
          hasLoadedMarketplaceBanners = false;
        }
      });
    }

    try {
      final Response response = await Get.find<ApiClient>().getData(
        marketplaceBannerRequestUri,
      );

      if (!mounted) {
        return;
      }

      final dynamic responseBody = response.body;

      if (response.statusCode != 200 ||
          responseBody is! Map ||
          responseBody['status'] != true) {
        stopMarketplaceBannerCarousel();

        setState(() {
          marketplaceBanners = <StoreMarketplaceBannerData>[];
          selectedMarketplaceBannerIndex = 0;
          isLoadingMarketplaceBanners = false;
          hasLoadedMarketplaceBanners = true;
        });
        return;
      }

      final dynamic dataValue = responseBody['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic bannersValue = data['banners'];
      final List<dynamic> bannerList =
          bannersValue is List ? bannersValue : <dynamic>[];

      final List<StoreMarketplaceBannerData> loadedBanners = bannerList
          .whereType<Map>()
          .map((item) => StoreMarketplaceBannerData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((banner) => banner.imageUrl.isNotEmpty)
          .toList();

      setState(() {
        marketplaceBanners = loadedBanners;
        selectedMarketplaceBannerIndex = 0;
        isLoadingMarketplaceBanners = false;
        hasLoadedMarketplaceBanners = true;
      });

      if (marketplaceBannerPageController.hasClients &&
          marketplaceBanners.isNotEmpty) {
        marketplaceBannerPageController.jumpToPage(0);
      }

      restartMarketplaceBannerCarousel();
    } catch (_) {
      if (mounted) {
        stopMarketplaceBannerCarousel();

        setState(() {
          marketplaceBanners = <StoreMarketplaceBannerData>[];
          selectedMarketplaceBannerIndex = 0;
          isLoadingMarketplaceBanners = false;
          hasLoadedMarketplaceBanners = true;
        });
      }
    }
  }

  Future<StoreMarketplaceSettings> loadMarketplaceSettings() async {
    if (isLoadingMarketplaceSettings) {
      return marketplaceSettings;
    }

    if (mounted) {
      setState(() {
        isLoadingMarketplaceSettings = true;
      });
    }

    try {
      final Response response =
          await Get.find<ApiClient>().getData(marketplaceSettingsUri);

      final dynamic responseBody = response.body;

      if (response.statusCode != 200 ||
          responseBody is! Map ||
          responseBody['status'] != true) {
        if (mounted) {
          setState(() {
            isLoadingMarketplaceSettings = false;
            hasLoadedMarketplaceSettings = true;
          });
        }

        return marketplaceSettings;
      }

      final StoreMarketplaceSettings loadedSettings =
          StoreMarketplaceSettings.fromResponseBody(
        Map<String, dynamic>.from(responseBody),
      );

      if (mounted) {
        setState(() {
          marketplaceSettings = loadedSettings;
          isLoadingMarketplaceSettings = false;
          hasLoadedMarketplaceSettings = true;
        });
      }

      return loadedSettings;
    } catch (_) {
      if (mounted) {
        setState(() {
          isLoadingMarketplaceSettings = false;
          hasLoadedMarketplaceSettings = true;
        });
      }

      return marketplaceSettings;
    }
  }

  Future<void> loadPublicCategories() async {
    try {
      final Response response = await Get.find<ApiClient>().getData(
        uriWithMarketplaceZone(publicCategoriesUri),
      );

      if (!mounted) {
        return;
      }

      final dynamic responseBody = response.body;

      if (response.statusCode != 200 ||
          responseBody is! Map ||
          responseBody['status'] != true) {
        showStoreMessage('Não foi possível carregar as categorias da loja.');
        return;
      }

      final dynamic dataValue = responseBody['data'];
      final List<dynamic> data = dataValue is List ? dataValue : <dynamic>[];

      final List<StoreCategoryData> loadedCategories = <StoreCategoryData>[
        StoreCategoryData.all(),
      ];

      loadedCategories.addAll(
        data.whereType<Map>().map((item) {
          return StoreCategoryData.fromMap(
            Map<String, dynamic>.from(item),
          );
        }).where((category) {
          return category.id.isNotEmpty;
        }),
      );

      setState(() {
        mainCategories = loadedCategories;

        if (selectedMainCategoryIndex >= mainCategories.length) {
          selectedMainCategoryIndex = 0;
          selectedSubcategoryId = '';
        }
      });
    } catch (_) {
      if (mounted) {
        showStoreMessage('Não foi possível carregar as categorias da loja.');
      }
    }
  }

  Future<void> loadPublicProducts() async {
    if (isLoadingPublicStore) {
      return;
    }

    setState(() {
      isLoadingPublicStore = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().getData(
        uriWithMarketplaceZone(publicProductsUri),
      );

      if (!mounted) {
        return;
      }

      final dynamic responseBody = response.body;

      if (response.statusCode != 200 ||
          responseBody is! Map ||
          responseBody['status'] != true) {
        setState(() {
          isLoadingPublicStore = false;
          hasLoadedPublicStore = true;
        });
        showStoreMessage('Não foi possível carregar os produtos da loja.');
        return;
      }

      final dynamic dataValue = responseBody['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic productsValue = data['products'];
      final List<dynamic> productList =
          productsValue is List ? productsValue : <dynamic>[];

      setState(() {
        products = productList
            .whereType<Map>()
            .map((item) => StoreProductData.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .where((product) => product.id.isNotEmpty)
            .toList();
        isLoadingPublicStore = false;
        hasLoadedPublicStore = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          isLoadingPublicStore = false;
          hasLoadedPublicStore = true;
        });
        showStoreMessage('Não foi possível carregar os produtos da loja.');
      }
    }
  }

  Future<void> loadBoostedProducts() async {
    if (isLoadingBoostedProducts) {
      return;
    }

    if (mounted) {
      setState(() {
        isLoadingBoostedProducts = true;
      });
    }

    try {
      final Response response = await Get.find<ApiClient>().getData(
        uriWithMarketplaceZone('$boostedProductsUri?boost_type=product_home'),
      );

      if (!mounted) {
        return;
      }

      final dynamic responseBody = response.body;

      if (response.statusCode != 200 ||
          responseBody is! Map ||
          responseBody['status'] != true) {
        setState(() {
          boostedProducts = <StoreProductData>[];
          isLoadingBoostedProducts = false;
          hasLoadedBoostedProducts = true;
          selectedBoostedProductIndex = 0;
        });
        stopBoostedProductsCarousel();
        return;
      }

      final dynamic dataValue = responseBody['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic productsValue = data['products'];
      final List<dynamic> productList =
          productsValue is List ? productsValue : <dynamic>[];

      final List<StoreProductData> loadedProducts = productList
          .whereType<Map>()
          .map((item) => StoreProductData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where(
              (product) => product.id.isNotEmpty && product.boostId.isNotEmpty)
          .toList();

      setState(() {
        boostedProducts = loadedProducts;
        isLoadingBoostedProducts = false;
        hasLoadedBoostedProducts = true;
        selectedBoostedProductIndex = 0;
      });

      if (boostedProductsPageController.hasClients) {
        boostedProductsPageController.jumpToPage(0);
      }

      if (loadedProducts.isEmpty) {
        stopBoostedProductsCarousel();
      } else {
        restartBoostedProductsCarousel();
      }

      trackBoostViews(loadedProducts);
    } catch (_) {
      if (mounted) {
        setState(() {
          boostedProducts = <StoreProductData>[];
          isLoadingBoostedProducts = false;
          hasLoadedBoostedProducts = true;
        });
        stopBoostedProductsCarousel();
      }
    }
  }

  Future<void> loadBoostedCategories() async {
    if (isLoadingBoostedCategories) {
      return;
    }

    if (mounted) {
      setState(() {
        isLoadingBoostedCategories = true;
      });
    }

    try {
      final Response response = await Get.find<ApiClient>().getData(
        uriWithMarketplaceZone(boostedCategoriesUri),
      );

      if (!mounted) {
        return;
      }

      final dynamic responseBody = response.body;

      if (response.statusCode != 200 ||
          responseBody is! Map ||
          responseBody['status'] != true) {
        setState(() {
          boostedCategories = <StoreBoostedCategoryData>[];
          isLoadingBoostedCategories = false;
          hasLoadedBoostedCategories = true;
        });
        return;
      }

      final dynamic dataValue = responseBody['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic categoriesValue = data['categories'];
      final List<dynamic> categoryList =
          categoriesValue is List ? categoriesValue : <dynamic>[];

      final List<StoreBoostedCategoryData> loadedCategories = categoryList
          .whereType<Map>()
          .map((item) => StoreBoostedCategoryData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((category) =>
              category.boostId.isNotEmpty && category.categoryId.isNotEmpty)
          .toList();

      setState(() {
        boostedCategories = loadedCategories;
        isLoadingBoostedCategories = false;
        hasLoadedBoostedCategories = true;
      });

      trackBoostedCategoryViews(visibleBoostedCategories);
    } catch (_) {
      if (mounted) {
        setState(() {
          boostedCategories = <StoreBoostedCategoryData>[];
          isLoadingBoostedCategories = false;
          hasLoadedBoostedCategories = true;
        });
      }
    }
  }

  Future<void> trackBoostViews(List<StoreProductData> productsToTrack) async {
    for (final StoreProductData product in productsToTrack) {
      if (product.boostId.isEmpty ||
          trackedBoostViewIds.contains(product.boostId)) {
        continue;
      }

      trackedBoostViewIds.add(product.boostId);
      unawaited(trackBoostInsight(product, 'view'));
    }
  }

  void trackBoostedCategoryViews(
    List<StoreBoostedCategoryData> categoriesToTrack,
  ) {
    for (final StoreBoostedCategoryData category in categoriesToTrack) {
      if (category.boostId.isEmpty ||
          trackedBoostCategoryViewIds.contains(category.boostId)) {
        continue;
      }

      trackedBoostCategoryViewIds.add(category.boostId);
      unawaited(trackBoostCategoryInsight(category, 'view'));
    }
  }

  Future<void> trackBoostCategoryInsight(
    StoreBoostedCategoryData category,
    String eventType,
  ) async {
    if (category.boostId.isEmpty) {
      return;
    }

    try {
      await Get.find<ApiClient>().postData(
        boostInsightUri,
        <String, String>{
          'boost_id': category.boostId,
          'event_type': eventType,
          'source': 'marketplace_category',
          'session_id': 'category-${category.boostId}',
        },
      );
    } catch (_) {}
  }

  Future<void> trackBoostInsight(
    StoreProductData product,
    String eventType,
  ) async {
    if (product.boostId.isEmpty) {
      return;
    }

    try {
      await Get.find<ApiClient>().postData(
        boostInsightUri,
        <String, String>{
          'boost_id': product.boostId,
          'event_type': eventType,
          'source': 'marketplace_home',
          'session_id': 'home-${product.boostId}',
        },
      );
    } catch (_) {}
  }

  Future<void> handleBoostedProductTap(StoreProductData product) async {
    unawaited(trackBoostInsight(product, 'click'));
    handleProductTap(product);
  }

  Future<void> handleBoostedCategoryTap(
    StoreBoostedCategoryData category,
  ) async {
    unawaited(trackBoostCategoryInsight(category, 'click'));

    final String mainCategoryId =
        category.parentId.isNotEmpty ? category.parentId : category.categoryId;

    final int categoryIndex = mainCategories.indexWhere(
      (mainCategory) => mainCategory.id == mainCategoryId,
    );

    if (categoryIndex < 0) {
      return;
    }

    setState(() {
      selectedMainCategoryIndex = categoryIndex;
      selectedSubcategoryId =
          category.parentId.isNotEmpty ? category.categoryId : '';
      searchQuery = '';
    });

    await loadMarketplaceBanners();
  }

  Future<void> checkSellerStatusOnOpen() async {
    if (!marketplaceSettings.marketplaceEnabled) {
      return;
    }

    try {
      final ApiClient apiClient = Get.find<ApiClient>();

      final Response response =
          await apiClient.getData(AppConstants.storeSellerStatus);

      if (!mounted) {
        return;
      }

      final dynamic responseBody = response.body;

      if (response.statusCode != 200 || responseBody is! Map) {
        setState(() {
          isApprovedSeller = false;
        });
        return;
      }

      final dynamic dataValue = responseBody['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final bool hasSellerRequest = data['has_seller_request'] == true;

      if (!hasSellerRequest) {
        await apiClient.sharedPreferences.setString(
          sellerLastStatusSignatureKey,
          'no_seller_request',
        );

        setState(() {
          isApprovedSeller = false;
        });
        return;
      }

      final String approvalStatus = '${data['approval_status'] ?? ''}';
      final bool canCreateProducts = data['can_create_products'] == true;
      final bool sellerApproved =
          approvalStatus == 'approved' && canCreateProducts;

      setState(() {
        isApprovedSeller = sellerApproved;
      });

      final dynamic sellerValue = data['seller'];
      final Map<String, dynamic> seller = sellerValue is Map
          ? Map<String, dynamic>.from(sellerValue)
          : <String, dynamic>{};

      final String sellerId = '${seller['id'] ?? 'seller'}';
      final String currentSignature =
          '$sellerId:$approvalStatus:$canCreateProducts';

      final String? lastSignature = apiClient.sharedPreferences.getString(
        sellerLastStatusSignatureKey,
      );

      if (lastSignature == currentSignature) {
        return;
      }

      await apiClient.sharedPreferences.setString(
        sellerLastStatusSignatureKey,
        currentSignature,
      );

      if (!mounted) {
        return;
      }

      if (sellerApproved) {
        showSellerStatusSheet(
          title: 'Cadastro aprovado',
          description:
              'Parabéns, o seu cadastro foi aprovado e você já pode vender em nosso marketplace.',
          actionLabel: 'Abrir painel',
          onAction: () {
            Navigator.of(context).pop();
            openSellerDashboardScreen();
          },
        );
        return;
      }

      if (approvalStatus == 'rejected') {
        showSellerStatusSheet(
          title: 'Cadastro não aprovado',
          description:
              'Seu cadastro não foi aprovado. Entre em contato com o nosso suporte para mais informações.',
          actionLabel: 'Falar com suporte',
          onAction: () {
            Navigator.of(context).pop();
            openSellerSupportWhatsApp();
          },
        );
        return;
      }

      if (approvalStatus == 'suspended' ||
          (approvalStatus == 'approved' && !canCreateProducts)) {
        showSellerStatusSheet(
          title: 'Cadastro bloqueado',
          description:
              'Seu cadastro está temporariamente bloqueado, entre em contato com o nosso suporte.',
          actionLabel: 'Falar com suporte',
          onAction: () {
            Navigator.of(context).pop();
            openSellerSupportWhatsApp();
          },
        );
      }
    } catch (_) {}
  }

  StoreCategoryData get selectedMainCategory {
    if (mainCategories.isEmpty ||
        selectedMainCategoryIndex >= mainCategories.length) {
      return StoreCategoryData.all();
    }

    return mainCategories[selectedMainCategoryIndex];
  }

  List<StoreCategoryData> get activeSubcategories {
    if (selectedMainCategory.isAll) {
      return <StoreCategoryData>[];
    }

    return selectedMainCategory.subcategories;
  }

  List<StoreBoostedCategoryData> get visibleBoostedCategories {
    final StoreCategoryData selected = selectedMainCategory;

    if (selected.isAll) {
      return <StoreBoostedCategoryData>[];
    }

    if (selectedSubcategoryId.isNotEmpty) {
      return boostedCategories.where((category) {
        return category.categoryId == selectedSubcategoryId;
      }).toList();
    }

    return boostedCategories.where((category) {
      if (category.categoryId == selected.id) {
        return true;
      }

      return category.parentId == selected.id;
    }).toList();
  }

  List<StoreProductData> get visibleProducts {
    final StoreCategoryData selected = selectedMainCategory;

    if (selected.isAll) {
      return products;
    }

    if (selectedSubcategoryId.isNotEmpty) {
      return products.where((product) {
        return product.categoryId == selectedSubcategoryId;
      }).toList();
    }

    final Set<String> subcategoryIds = selected.subcategories
        .map((subcategory) => subcategory.id)
        .where((id) => id.isNotEmpty)
        .toSet();

    return products.where((product) {
      return product.categoryId == selected.id ||
          subcategoryIds.contains(product.categoryId);
    }).toList();
  }

  List<StoreProductData> get welcomeProducts {
    final List<StoreProductData> baseProducts = visibleProducts;
    final List<StoreProductData> promotionalProducts =
        baseProducts.where((product) => product.hasPromotion).take(8).toList();

    if (promotionalProducts.isNotEmpty) {
      return promotionalProducts;
    }

    return baseProducts.take(8).toList();
  }

  List<StoreProductData> get searchResults {
    final String query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return <StoreProductData>[];
    }

    return products.where((product) {
      return product.title.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query) ||
          product.storeName.toLowerCase().contains(query);
    }).toList();
  }

  StoreMarketplaceBannerData? get selectedMarketplaceBanner {
    if (marketplaceBanners.isEmpty) {
      return null;
    }

    if (selectedMarketplaceBannerIndex < 0 ||
        selectedMarketplaceBannerIndex >= marketplaceBanners.length) {
      return marketplaceBanners.first;
    }

    return marketplaceBanners[selectedMarketplaceBannerIndex];
  }

  Future<void> handleMarketplaceBannerTap(
    StoreMarketplaceBannerData banner,
  ) async {
    if (banner.clickType == 'product' && banner.productId.isNotEmpty) {
      for (final StoreProductData product in products) {
        if (product.id == banner.productId) {
          handleProductTap(product);
          return;
        }
      }

      return;
    }

    if (banner.clickType == 'category' && banner.categoryId.isNotEmpty) {
      final int categoryIndex = mainCategories.indexWhere(
        (category) => category.id == banner.categoryId,
      );

      if (categoryIndex >= 0) {
        handleMainCategorySelected(categoryIndex);
      }
      return;
    }

    if (banner.clickType == 'subcategory' && banner.subcategoryId.isNotEmpty) {
      for (int index = 0; index < mainCategories.length; index++) {
        final StoreCategoryData category = mainCategories[index];
        final bool hasSubcategory = category.subcategories.any(
          (subcategory) => subcategory.id == banner.subcategoryId,
        );

        if (hasSubcategory) {
          setState(() {
            selectedMainCategoryIndex = index;
            selectedSubcategoryId = banner.subcategoryId;
            searchQuery = '';
          });

          unawaited(loadMarketplaceBanners());
          trackBoostedCategoryViews(visibleBoostedCategories);
          return;
        }
      }
      return;
    }

    if (banner.clickType == 'external_url' && banner.externalUrl.isNotEmpty) {
      final Uri? url = Uri.tryParse(banner.externalUrl);

      if (url != null) {
        final bool opened = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );

        if (!opened && mounted) {
          showStoreMessage('Não foi possível abrir o link do banner.');
        }
      }
    }
  }

  void handleProductTap(StoreProductData product) {
    Get.to(
      () => StoreProductDetailsScreen(
        initialProduct: product.toMap(),
      ),
    );
  }

  void handleSimpleTap() {}

  void openCartScreen() {
    Get.to(() => const StoreCartScreen());
  }

  void openSellerDashboardScreen() {
    Get.to(() => const StoreSellerDashboardScreen());
  }

  Future<void> openSellerRegistrationScreen() async {
    if (!marketplaceSettings.sellerRegistrationEnabled) {
      showSellerStatusSheet(
        title: 'Cadastro de lojistas indisponível',
        description:
            'No momento, o cadastro de novos vendedores está temporariamente fechado no Marketplace da Lokally.',
        actionLabel:
            marketplaceSettings.hasSupportWhatsapp ? 'Falar com suporte' : null,
        onAction: marketplaceSettings.hasSupportWhatsapp
            ? () {
                Navigator.of(context).pop();
                openSellerSupportWhatsApp();
              }
            : null,
      );
      return;
    }

    final dynamic result = await Get.to(
      () => const StoreSellerRegistrationScreen(),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      final ApiClient apiClient = Get.find<ApiClient>();
      await apiClient.sharedPreferences.setString(
        sellerLastStatusSignatureKey,
        'seller_request_pending_local',
      );

      showSellerStatusSheet(
        title: 'Cadastro enviado',
        description:
            'Seu cadastro de vendedor foi enviado e está aguardando aprovação do ADM. Assim que for aprovado, você poderá vender em nosso marketplace.',
      );
    }
  }

  Future<void> handleSellButtonTap() async {
    if (isCheckingSellerStatus) {
      return;
    }

    if (!marketplaceSettings.marketplaceEnabled) {
      showStoreMessage('Marketplace temporariamente indisponível.');
      return;
    }

    if (isApprovedSeller) {
      openSellerDashboardScreen();
      return;
    }

    setState(() {
      isCheckingSellerStatus = true;
    });

    final Response response =
        await Get.find<ApiClient>().getData(AppConstants.storeSellerStatus);

    if (!mounted) {
      return;
    }

    setState(() {
      isCheckingSellerStatus = false;
    });

    final dynamic responseBody = response.body;

    if (response.statusCode != 200 || responseBody is! Map) {
      showStoreMessage(
        'Não foi possível verificar seu cadastro de vendedor agora.',
      );
      return;
    }

    final dynamic dataValue = responseBody['data'];
    final Map<String, dynamic> data = dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : <String, dynamic>{};

    final bool hasSellerRequest = data['has_seller_request'] == true;
    final String approvalStatus = '${data['approval_status'] ?? ''}';
    final bool canCreateProducts = data['can_create_products'] == true;

    if (!hasSellerRequest) {
      setState(() {
        isApprovedSeller = false;
      });

      if (!marketplaceSettings.sellerRegistrationEnabled) {
        showSellerStatusSheet(
          title: 'Cadastro de lojistas indisponível',
          description:
              'No momento, o cadastro de novos vendedores está temporariamente fechado no Marketplace da Lokally.',
          actionLabel: marketplaceSettings.hasSupportWhatsapp
              ? 'Falar com suporte'
              : null,
          onAction: marketplaceSettings.hasSupportWhatsapp
              ? () {
                  Navigator.of(context).pop();
                  openSellerSupportWhatsApp();
                }
              : null,
        );
        return;
      }

      showSellerStatusSheet(
        title: 'Venda na Lokally',
        description:
            'Você ainda não tem uma loja em nosso marketplace, clique abaixo e faça o seu cadastro.',
        actionLabel: 'Fazer cadastro',
        onAction: () {
          Navigator.of(context).pop();
          openSellerRegistrationScreen();
        },
      );
      return;
    }

    if (canCreateProducts && approvalStatus == 'approved') {
      setState(() {
        isApprovedSeller = true;
      });
      openSellerDashboardScreen();
      return;
    }

    setState(() {
      isApprovedSeller = false;
    });

    if (approvalStatus == 'pending') {
      showSellerStatusSheet(
        title: 'Cadastro em análise',
        description:
            'Seu cadastro de vendedor foi enviado e está aguardando aprovação do ADM. Assim que for aprovado, você poderá vender em nosso marketplace.',
      );
      return;
    }

    if (approvalStatus == 'rejected') {
      showSellerStatusSheet(
        title: 'Cadastro não aprovado',
        description:
            'Seu cadastro não foi aprovado. Entre em contato com o nosso suporte para mais informações.',
        actionLabel: 'Falar com suporte',
        onAction: () {
          Navigator.of(context).pop();
          openSellerSupportWhatsApp();
        },
      );
      return;
    }

    if (approvalStatus == 'suspended' ||
        (approvalStatus == 'approved' && !canCreateProducts)) {
      showSellerStatusSheet(
        title: 'Cadastro bloqueado',
        description:
            'Seu cadastro está temporariamente bloqueado, entre em contato com o nosso suporte.',
        actionLabel: 'Falar com suporte',
        onAction: () {
          Navigator.of(context).pop();
          openSellerSupportWhatsApp();
        },
      );
      return;
    }

    showSellerStatusSheet(
      title: 'Status do vendedor',
      description:
          'Seu cadastro está temporariamente bloqueado, entre em contato com o nosso suporte.',
      actionLabel: 'Falar com suporte',
      onAction: () {
        Navigator.of(context).pop();
        openSellerSupportWhatsApp();
      },
    );
  }

  Future<void> openSellerSupportWhatsApp() async {
    final String message = Uri.encodeComponent(
      'Olá, sou vendedor e o meu cadastro está bloqueado, preciso de ajuda.',
    );

    final String supportNumber =
        marketplaceSettings.supportWhatsappDigits.isNotEmpty
            ? marketplaceSettings.supportWhatsappDigits
            : '5535991284648';

    final Uri url = Uri.parse(
      'https://wa.me/$supportNumber?text=$message',
    );

    final bool opened = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      showStoreMessage('Não foi possível abrir o WhatsApp do suporte.');
    }
  }

  void showStoreMessage(String message) {
    final Color primaryColor = Theme.of(context).primaryColor;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: textMedium.copyWith(
            color: Colors.white,
            fontSize: 12.8,
          ),
        ),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void showSellerStatusSheet({
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final Color primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 10),
                  blurRadius: 26,
                  color: Colors.black.withValues(alpha: 0.14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.grey.shade700,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  description,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 13.8,
                    height: 1.35,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: onAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        actionLabel,
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void handleMainCategorySelected(int index) {
    setState(() {
      selectedMainCategoryIndex = index;
      selectedSubcategoryId = '';
      searchQuery = '';
    });

    unawaited(loadMarketplaceBanners());
    trackBoostedCategoryViews(visibleBoostedCategories);
  }

  void handleSubcategorySelected(String subcategoryId) {
    setState(() {
      selectedSubcategoryId = subcategoryId;
      searchQuery = '';
    });

    trackBoostedCategoryViews(visibleBoostedCategories);
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final List<StoreProductData> welcomeProductsForView = welcomeProducts;
    final List<StoreProductData> boostedProductsForView =
        selectedMainCategory.isAll ? boostedProducts : <StoreProductData>[];
    final List<StoreBoostedCategoryData> boostedCategoriesForView =
        visibleBoostedCategories;
    final List<StoreProductData> productsForView = visibleProducts;
    final bool marketplaceAvailable = marketplaceSettings.marketplaceEnabled;
    final bool showMarketplaceUnavailable =
        hasLoadedMarketplaceSettings && !marketplaceAvailable;
    final bool shouldShowInitialMarketplaceLoading = false;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 360,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      primaryColor,
                      primaryColor.withValues(alpha: 0.92),
                      primaryColor.withValues(alpha: 0.58),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.38, 0.75, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              StoreMarketplaceHeader(
                primaryColor: primaryColor,
                showSellButton: marketplaceAvailable && !isApprovedSeller,
                sellButtonLabel: 'Vender',
                isSellButtonLoading: isCheckingSellerStatus,
                onSellTap: marketplaceAvailable
                    ? handleSellButtonTap
                    : () => showStoreMessage(
                          'Marketplace temporariamente indisponível.',
                        ),
                onSearchChanged: (value) {
                  if (!marketplaceAvailable) {
                    return;
                  }

                  setState(() {
                    searchQuery = value;
                  });
                },
                onCartTap: marketplaceAvailable
                    ? openCartScreen
                    : () => showStoreMessage(
                          'Marketplace temporariamente indisponível.',
                        ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: primaryColor,
                  onRefresh: loadPublicStore,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      Dimensions.paddingSizeDefault,
                      10,
                      Dimensions.paddingSizeDefault,
                      150,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showMarketplaceUnavailable) ...[
                          StoreMarketplaceUnavailableBlock(
                            primaryColor: primaryColor,
                            supportWhatsappAvailable:
                                marketplaceSettings.hasSupportWhatsapp,
                            onSupportTap: marketplaceSettings.hasSupportWhatsapp
                                ? openSellerSupportWhatsApp
                                : null,
                          ),
                        ] else if (shouldShowInitialMarketplaceLoading) ...[
                          StoreMarketplaceInitialLoadingBlock(
                            primaryColor: primaryColor,
                          ),
                        ] else ...[
                          if (searchQuery.trim().isNotEmpty) ...[
                            StoreSearchResultsList(
                              products: searchResults,
                              primaryColor: primaryColor,
                              onProductTap: handleProductTap,
                            ),
                            const SizedBox(height: 14),
                          ],
                          StoreMainCategoryMenu(
                            categories: mainCategories,
                            selectedIndex: selectedMainCategoryIndex,
                            primaryColor: primaryColor,
                            onSelected: handleMainCategorySelected,
                          ),
                          if (activeSubcategories.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            StoreSubcategoryMenu(
                              subcategories: activeSubcategories,
                              selectedSubcategoryId: selectedSubcategoryId,
                              primaryColor: primaryColor,
                              onSelected: handleSubcategorySelected,
                            ),
                          ],
                          const SizedBox(height: 14),
                          if (marketplaceBanners.isNotEmpty) ...[
                            StoreStableBannerSlot(
                              primaryColor: primaryColor,
                              child: StoreBannerCarousel(
                                banners: marketplaceBanners,
                                selectedIndex: selectedMarketplaceBannerIndex,
                                pageController: marketplaceBannerPageController,
                                primaryColor: primaryColor,
                                onPageChanged: (index) {
                                  setState(() {
                                    selectedMarketplaceBannerIndex = index;
                                  });
                                },
                                onBannerTap: handleMarketplaceBannerTap,
                              ),
                            ),
                            const SizedBox(height: 18),
                          ] else if (isLoadingMarketplaceBanners ||
                              !hasLoadedMarketplaceBanners) ...[
                            StoreStableBannerSlot(
                              primaryColor: primaryColor,
                              child: StoreBannerLoading(
                                primaryColor: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                          if (selectedMainCategory.isAll &&
                              isLoadingBoostedProducts &&
                              !hasLoadedBoostedProducts) ...[
                            StoreBoostedProductsLoading(
                              primaryColor: primaryColor,
                            ),
                            const SizedBox(height: 18),
                          ] else if (boostedProductsForView.isNotEmpty) ...[
                            StoreBoostedProductsSection(
                              products: boostedProductsForView,
                              primaryColor: primaryColor,
                              pageController: boostedProductsPageController,
                              selectedIndex: selectedBoostedProductIndex,
                              onPageChanged: (index) {
                                setState(() {
                                  selectedBoostedProductIndex = index;
                                });
                              },
                              onProductTap: handleBoostedProductTap,
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (!selectedMainCategory.isAll &&
                              boostedCategoriesForView.isNotEmpty) ...[
                            StoreBoostedCategoriesSection(
                              categories: boostedCategoriesForView,
                              primaryColor: primaryColor,
                              onCategoryTap: handleBoostedCategoryTap,
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (isLoadingPublicStore ||
                              !hasLoadedPublicStore) ...[
                            StorePublicLoadingBlock(primaryColor: primaryColor),
                          ] else if (products.isEmpty) ...[
                            StoreEmptyPublicProducts(
                                primaryColor: primaryColor),
                          ] else ...[
                            if (welcomeProductsForView.isNotEmpty) ...[
                              StoreSectionHeader(
                                title: 'Ofertas de boas-vindas',
                                badge: 'Selecionados',
                                primaryColor: primaryColor,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 372,
                                child: ListView.builder(
                                  controller: welcomeCarouselController,
                                  scrollDirection: Axis.horizontal,
                                  itemCount: welcomeProductsForView.length,
                                  itemBuilder: (context, index) {
                                    return WelcomeOfferCard(
                                      product: welcomeProductsForView[index],
                                      primaryColor: primaryColor,
                                      onTap: () => handleProductTap(
                                        welcomeProductsForView[index],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            Text(
                              selectedMainCategory.isAll
                                  ? 'Produtos em destaque'
                                  : selectedSubcategoryId.isEmpty
                                      ? selectedMainCategory.name
                                      : activeSubcategories
                                          .firstWhere(
                                            (subcategory) =>
                                                subcategory.id ==
                                                selectedSubcategoryId,
                                            orElse: () => selectedMainCategory,
                                          )
                                          .name,
                              style: textBold.copyWith(
                                color: textColor,
                                fontSize: 21,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GridView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: productsForView.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 14,
                                mainAxisExtent: 372,
                              ),
                              itemBuilder: (context, index) {
                                final StoreProductData product =
                                    productsForView[index];

                                return StoreProductCard(
                                  product: product,
                                  primaryColor: primaryColor,
                                  onTap: () => handleProductTap(product),
                                );
                              },
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StoreHeader extends StatelessWidget {
  final Color primaryColor;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCartTap;

  const StoreHeader({
    super.key,
    required this.primaryColor,
    required this.onSearchChanged,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: primaryColor,
      padding: const EdgeInsets.fromLTRB(14, 48, 14, 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Image.asset(
              'assets/image/loja.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StoreHeaderSearchField(
              onChanged: onSearchChanged,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onCartTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreHeaderSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const StoreHeaderSearchField({
    super.key,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: textRegular.copyWith(
          color: Colors.black87,
          fontSize: 13.5,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: const EdgeInsets.only(top: 10),
          icon: Icon(
            Icons.search_rounded,
            color: Colors.grey.shade600,
            size: 20,
          ),
          hintText: 'Buscar produtos',
          hintStyle: textRegular.copyWith(
            color: Colors.grey.shade500,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

class StoreSearchResultsList extends StatelessWidget {
  final List<StoreProductData> products;
  final Color primaryColor;
  final ValueChanged<StoreProductData> onProductTap;

  const StoreSearchResultsList({
    super.key,
    required this.products,
    required this.primaryColor,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Nenhum produto encontrado.',
          style: textMedium.copyWith(
            color: Colors.grey.shade700,
            fontSize: 13,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 6),
            blurRadius: 18,
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Column(
        children: products.map((product) {
          return StoreSearchResultTile(
            product: product,
            primaryColor: primaryColor,
            onTap: () => onProductTap(product),
          );
        }).toList(),
      ),
    );
  }
}

class StoreSearchResultTile extends StatelessWidget {
  final StoreProductData product;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreSearchResultTile({
    super.key,
    required this.product,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            StoreProductImageBox(
              imageUrl: product.mainImageUrl,
              primaryColor: primaryColor,
              width: 54,
              height: 54,
              radius: 12,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(
                      color: Colors.black87,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vendido por: ${product.storeName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 11.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ProductPriceInline(
                    product: product,
                    primaryColor: primaryColor,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade500,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class StoreMainCategoryMenu extends StatelessWidget {
  final List<StoreCategoryData> categories;
  final int selectedIndex;
  final Color primaryColor;
  final ValueChanged<int> onSelected;

  const StoreMainCategoryMenu({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.primaryColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return StoreCategoryTextItem(
            category: categories[index],
            isSelected: index == selectedIndex,
            primaryColor: primaryColor,
            onTap: () => onSelected(index),
          );
        },
      ),
    );
  }
}

class StoreSubcategoryMenu extends StatelessWidget {
  final List<StoreCategoryData> subcategories;
  final String selectedSubcategoryId;
  final Color primaryColor;
  final ValueChanged<String> onSelected;

  const StoreSubcategoryMenu({
    super.key,
    required this.subcategories,
    required this.selectedSubcategoryId,
    required this.primaryColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final List<StoreCategoryData> items = subcategories;

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final StoreCategoryData item = items[index];
          final bool selected = selectedSubcategoryId == item.id;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(item.id),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? primaryColor.withValues(alpha: 0.10)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? primaryColor : Colors.grey.shade200,
                  ),
                ),
                child: Center(
                  child: Text(
                    item.name,
                    style: textBold.copyWith(
                      color: selected ? primaryColor : Colors.grey.shade700,
                      fontSize: 12.0,
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
}

class StoreCategoryTextItem extends StatelessWidget {
  final StoreCategoryData category;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreCategoryTextItem({
    super.key,
    required this.category,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String? localIconAsset = category.localIconAsset;
    final bool hasNetworkIcon = category.iconUrl.isNotEmpty;
    final bool hasIcon = localIconAsset != null || hasNetworkIcon;
    final Color labelColor =
        Colors.white.withValues(alpha: isSelected ? 1 : 0.94);

    Widget iconWidget() {
      if (!hasIcon) {
        return SizedBox(
          width: 58,
          height: 58,
          child: Icon(
            category.isAll ? Icons.apps_rounded : Icons.storefront_rounded,
            color: Colors.white.withValues(alpha: 0.92),
            size: 36,
          ),
        );
      }

      final Widget image = localIconAsset != null
          ? Image.asset(
              localIconAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return Icon(
                  category.isAll
                      ? Icons.apps_rounded
                      : Icons.storefront_rounded,
                  color: Colors.white.withValues(alpha: 0.92),
                  size: 36,
                );
              },
            )
          : Image.network(
              category.iconUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return Icon(
                  category.isAll
                      ? Icons.apps_rounded
                      : Icons.storefront_rounded,
                  color: Colors.white.withValues(alpha: 0.92),
                  size: 36,
                );
              },
            );

      return SizedBox(
        width: 58,
        height: 58,
        child: image,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 88,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.only(top: 2, bottom: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget(),
            const SizedBox(height: 3),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: (isSelected ? textBold : textMedium).copyWith(
                color: labelColor,
                fontSize: category.isAll ? 12.8 : 12.0,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isSelected ? 30 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreBanner extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onTap;
  final Color primaryColor;
  final bool showFallbackWhenEmpty;

  const StoreBanner({
    super.key,
    required this.imageUrl,
    required this.onTap,
    required this.primaryColor,
    this.showFallbackWhenEmpty = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget fallback() {
      if (!showFallbackWhenEmpty) {
        return Container(
          color: Colors.grey.shade50,
        );
      }

      return Image.asset(
        'assets/image/produto.webp',
        fit: BoxFit.cover,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 142,
          width: double.infinity,
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return StoreBannerLoading(
                      primaryColor: Theme.of(context).primaryColor,
                    );
                  },
                  errorBuilder: (_, __, ___) {
                    return fallback();
                  },
                )
              : fallback(),
        ),
      ),
    );
  }
}

class StoreStableBannerSlot extends StatelessWidget {
  final Color primaryColor;
  final Widget child;

  const StoreStableBannerSlot({
    super.key,
    required this.primaryColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: Align(
        alignment: Alignment.topCenter,
        child: child,
      ),
    );
  }
}

class StoreBannerCarousel extends StatelessWidget {
  final List<StoreMarketplaceBannerData> banners;
  final int selectedIndex;
  final PageController pageController;
  final Color primaryColor;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<StoreMarketplaceBannerData> onBannerTap;

  const StoreBannerCarousel({
    super.key,
    required this.banners,
    required this.selectedIndex,
    required this.pageController,
    required this.primaryColor,
    required this.onPageChanged,
    required this.onBannerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 142,
          width: double.infinity,
          child: PageView.builder(
            controller: pageController,
            itemCount: banners.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final StoreMarketplaceBannerData banner = banners[index];

              return StoreBanner(
                imageUrl: banner.bestImageUrl,
                onTap: () => onBannerTap(banner),
                primaryColor: primaryColor,
                showFallbackWhenEmpty: false,
              );
            },
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(banners.length, (index) {
              final bool selected = index == selectedIndex;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: selected ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: selected
                      ? primaryColor
                      : primaryColor.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class StoreBannerLoading extends StatelessWidget {
  final Color primaryColor;

  const StoreBannerLoading({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 142,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: primaryColor,
              strokeWidth: 2.4,
            ),
          ),
        ),
      ),
    );
  }
}

class StoreSectionHeader extends StatelessWidget {
  final String title;
  final String badge;
  final Color primaryColor;

  const StoreSectionHeader({
    super.key,
    required this.title,
    required this.badge,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: textBold.copyWith(
              color: Theme.of(context).textTheme.bodyLarge?.color ??
                  Colors.black87,
              fontSize: 21,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            badge,
            style: textBold.copyWith(
              color: primaryColor,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class WelcomeOfferCard extends StatelessWidget {
  final StoreProductData product;
  final Color primaryColor;
  final VoidCallback onTap;

  const WelcomeOfferCard({
    super.key,
    required this.product,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 182,
      margin: const EdgeInsets.only(right: 12),
      child: StoreProductCard(
        product: product,
        primaryColor: primaryColor,
        onTap: onTap,
      ),
    );
  }
}

class StoreBoostedProductsSection extends StatelessWidget {
  final List<StoreProductData> products;
  final Color primaryColor;
  final PageController pageController;
  final int selectedIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<StoreProductData> onProductTap;

  const StoreBoostedProductsSection({
    super.key,
    required this.products,
    required this.primaryColor,
    required this.pageController,
    required this.selectedIndex,
    required this.onPageChanged,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lokally Indica',
          style: textBold.copyWith(
            color:
                Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
            fontSize: 21,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 146,
          child: PageView.builder(
            controller: pageController,
            itemCount: products.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final StoreProductData product = products[index];

              return Padding(
                padding: EdgeInsets.only(
                  right: index == products.length - 1 ? 0 : 10,
                ),
                child: StoreBoostedProductCard(
                  product: product,
                  primaryColor: primaryColor,
                  onTap: () => onProductTap(product),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class StoreBoostedProductCard extends StatelessWidget {
  final StoreProductData product;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreBoostedProductCard({
    super.key,
    required this.product,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final String normalizedDiscount =
        product.discountLabel.replaceAll('OFF', '').replaceAll('-', '').trim();
    final String discountText =
        normalizedDiscount.isNotEmpty ? '- $normalizedDiscount' : 'OFERTA';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 372,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 132,
                    child: StoreProductImageBox(
                      imageUrl: product.mainImageUrl,
                      primaryColor: primaryColor,
                      width: double.infinity,
                      height: double.infinity,
                      radius: 0,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              right: product.hasPromotion ? 78 : 0,
                            ),
                            child: Text(
                              product.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textBold.copyWith(
                                color: textColor,
                                fontSize: 13.8,
                                height: 1.12,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.hasPromotion)
                                Text(
                                  'De ${product.formattedPrice}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textRegular.copyWith(
                                    color: Colors.red,
                                    fontSize: 12.8,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.red,
                                    height: 1,
                                  ),
                                ),
                              Text(
                                'Por ${product.formattedFinalPrice}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textBold.copyWith(
                                  color: primaryColor,
                                  fontSize: 15.8,
                                  height: 1.06,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            width: 118,
                            height: 32,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  'SAIBA MAIS',
                                  style: textBold.copyWith(
                                    color: Colors.white,
                                    fontSize: 11.6,
                                    letterSpacing: 0.18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (product.hasPromotion)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 88),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF2D2D),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Text(
                      discountText,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(
                        color: Colors.white,
                        fontSize: 12.5,
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
}

class StoreBoostedCategoriesSection extends StatelessWidget {
  final List<StoreBoostedCategoryData> categories;
  final Color primaryColor;
  final ValueChanged<StoreBoostedCategoryData> onCategoryTap;

  const StoreBoostedCategoriesSection({
    super.key,
    required this.categories,
    required this.primaryColor,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lokally Indica',
          style: textBold.copyWith(
            color:
                Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
            fontSize: 21,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final StoreBoostedCategoryData category = categories[index];

              return StoreBoostedCategoryCard(
                category: category,
                primaryColor: primaryColor,
                onTap: () => onCategoryTap(category),
              );
            },
          ),
        ),
      ],
    );
  }
}

class StoreBoostedCategoryCard extends StatelessWidget {
  final StoreBoostedCategoryData category;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreBoostedCategoryCard({
    super.key,
    required this.category,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: primaryColor.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                height: double.infinity,
                child: StoreProductImageBox(
                  imageUrl: category.imageUrl,
                  primaryColor: primaryColor,
                  width: double.infinity,
                  height: double.infinity,
                  radius: 0,
                  fit: BoxFit.cover,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        category.categoryName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 14.5,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        category.storeName.isNotEmpty
                            ? category.storeName
                            : 'Categoria em destaque',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textMedium.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 11.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: Text(
                            'VER AGORA',
                            style: textBold.copyWith(
                              color: Colors.white,
                              fontSize: 11.2,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class StoreBoostedProductsLoading extends StatelessWidget {
  final Color primaryColor;

  const StoreBoostedProductsLoading({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 142,
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primaryColor.withValues(alpha: 0.12)),
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: primaryColor,
          strokeWidth: 2.4,
        ),
      ),
    );
  }
}

class StoreProductCard extends StatelessWidget {
  final StoreProductData product;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreProductCard({
    super.key,
    required this.product,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 5),
              blurRadius: 13,
              color: Colors.black.withValues(alpha: 0.04),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: StoreProductHeroImage(
                      imageUrl: product.mainImageUrl,
                      primaryColor: primaryColor,
                    ),
                  ),
                  if (product.hasPromotion)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: StoreDiscountBadge(
                        discountLabel: product.discountLabel,
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.clip,
                        softWrap: true,
                        style: textBold.copyWith(
                          color: textColor,
                          fontSize: 13.0,
                          height: 1.10,
                        ),
                      ),
                      const SizedBox(height: 5),
                      ProductPriceColumn(
                        product: product,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 5),
                      StoreDeliveryInfo(
                        product: product,
                        primaryColor: primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
              StoreBottomActionStrip(
                primaryColor: primaryColor,
                label: product.actionLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreDiscountBadge extends StatelessWidget {
  final String discountLabel;

  const StoreDiscountBadge({
    super.key,
    required this.discountLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 10,
            color: Colors.black.withValues(alpha: 0.14),
          ),
        ],
      ),
      child: Center(
        child: Text(
          discountLabel,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: textBold.copyWith(
            color: Colors.white,
            fontSize: discountLabel.length > 5 ? 9.3 : 10.8,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class StoreProductHeroImage extends StatelessWidget {
  final String imageUrl;
  final Color primaryColor;

  const StoreProductHeroImage({
    super.key,
    required this.imageUrl,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Container(
        color: Colors.white,
        child: Image.asset(
          'assets/image/produto.webp',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    return Image.network(
      imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (_, __, ___) {
        return Container(
          color: Colors.white,
          child: Image.asset(
            'assets/image/produto.webp',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}

class StoreProductImageBox extends StatelessWidget {
  final String imageUrl;
  final Color primaryColor;
  final double width;
  final double height;
  final double radius;
  final BoxFit fit;

  const StoreProductImageBox({
    super.key,
    required this.imageUrl,
    required this.primaryColor,
    required this.width,
    required this.height,
    required this.radius,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Image.asset(
          'assets/image/produto.webp',
          fit: BoxFit.contain,
        ),
      ),
    );

    if (imageUrl.isEmpty) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) {
          return fallback;
        },
      ),
    );
  }
}

class ProductPriceColumn extends StatelessWidget {
  final StoreProductData product;
  final Color primaryColor;

  const ProductPriceColumn({
    super.key,
    required this.product,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (product.hasPromotion) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'De ${product.formattedPrice}',
              maxLines: 1,
              style: textMedium.copyWith(
                color: Colors.redAccent,
                fontSize: 11.4,
                decoration: TextDecoration.lineThrough,
                decorationColor: Colors.redAccent,
                decorationThickness: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Por ${product.formattedFinalPrice}',
              maxLines: 1,
              style: textBold.copyWith(
                color: primaryColor,
                fontSize: 15.2,
              ),
            ),
          ),
        ],
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        'Por ${product.formattedFinalPrice}',
        maxLines: 1,
        style: textBold.copyWith(
          color: primaryColor,
          fontSize: 16,
        ),
      ),
    );
  }
}

class ProductPriceInline extends StatelessWidget {
  final StoreProductData product;
  final Color primaryColor;

  const ProductPriceInline({
    super.key,
    required this.product,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (product.hasPromotion) {
      return Row(
        children: [
          Text(
            'De ${product.formattedPrice}',
            maxLines: 1,
            style: textMedium.copyWith(
              color: Colors.redAccent,
              fontSize: 11,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.redAccent,
              decorationThickness: 1.4,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Por ${product.formattedFinalPrice}',
            maxLines: 1,
            style: textBold.copyWith(
              color: primaryColor,
              fontSize: 12.5,
            ),
          ),
        ],
      );
    }

    return Text(
      'Por ${product.formattedFinalPrice}',
      maxLines: 1,
      style: textBold.copyWith(
        color: primaryColor,
        fontSize: 12.5,
      ),
    );
  }
}

class StoreDeliveryInfo extends StatelessWidget {
  final StoreProductData product;
  final Color primaryColor;

  const StoreDeliveryInfo({
    super.key,
    required this.product,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final String label = product.isService ? 'Formato do serviço' : 'Entrega';
    final String value = product.isService
        ? product.compactServiceDeliveryLabel
        : 'Retire grátis ou receba em casa';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: textMedium.copyWith(
            color: Colors.grey.shade600,
            fontSize: 9.2,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.clip,
          style: textBold.copyWith(
            color: primaryColor,
            fontSize: 10.4,
            height: 1.08,
          ),
        ),
      ],
    );
  }
}

class StoreBottomActionStrip extends StatelessWidget {
  final Color primaryColor;
  final String label;

  const StoreBottomActionStrip({
    super.key,
    required this.primaryColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 7),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: textBold.copyWith(
            color: Colors.white,
            fontSize: 11.8,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class StoreMarketplaceInitialLoadingBlock extends StatelessWidget {
  final Color primaryColor;

  const StoreMarketplaceInitialLoadingBlock({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 94,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 20),
            itemBuilder: (context, index) {
              final String label = index == 0
                  ? 'Todos'
                  : index == 1
                      ? 'Beleza'
                      : 'Serviços';

              return SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(
                        color: Colors.white,
                        fontSize: 11.8,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        StoreStableBannerSlot(
          primaryColor: primaryColor,
          child: StoreBannerLoading(primaryColor: primaryColor),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 104,
              height: 28,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 372,
          child: Row(
            children: List.generate(2, (index) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index == 0 ? 12 : 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(18),
                              topRight: Radius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 12,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 12,
                              width: 90,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 16,
                              width: 104,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class StorePublicLoadingBlock extends StatelessWidget {
  final Color primaryColor;

  const StorePublicLoadingBlock({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: primaryColor,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}

class StoreEmptyPublicProducts extends StatelessWidget {
  final Color primaryColor;

  const StoreEmptyPublicProducts({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.storefront_rounded,
            color: primaryColor,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhum produto disponível',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 15.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Assim que os vendedores tiverem produtos disponíveis, eles aparecerão aqui.',
            textAlign: TextAlign.center,
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 12.8,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreMarketplaceUnavailableBlock extends StatelessWidget {
  final Color primaryColor;
  final bool supportWhatsappAvailable;
  final VoidCallback? onSupportTap;

  const StoreMarketplaceUnavailableBlock({
    super.key,
    required this.primaryColor,
    required this.supportWhatsappAvailable,
    required this.onSupportTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: primaryColor,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Marketplace temporariamente indisponível',
            textAlign: TextAlign.center,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'A Loja da Lokally está pausada no momento. Assim que o ADM liberar novamente, os produtos e vendedores aparecerão aqui.',
            textAlign: TextAlign.center,
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          if (supportWhatsappAvailable && onSupportTap != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: onSupportTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Falar com suporte',
                  style: textBold.copyWith(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StoreFloatingSellButton extends StatelessWidget {
  final Color primaryColor;
  final bool isLoading;
  final bool isApprovedSeller;
  final VoidCallback onTap;

  const StoreFloatingSellButton({
    super.key,
    required this.primaryColor,
    required this.isLoading,
    required this.isApprovedSeller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 8),
                blurRadius: 18,
                color: Colors.black.withValues(alpha: 0.18),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ] else ...[
                Icon(
                  isApprovedSeller
                      ? Icons.store_mall_directory_rounded
                      : Icons.storefront_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
              const SizedBox(width: 7),
              Text(
                isLoading
                    ? 'Verificando'
                    : isApprovedSeller
                        ? 'Ver minha loja'
                        : 'Vender',
                style: textBold.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreMarketplaceBannerData {
  final String id;
  final String title;
  final String subtitle;
  final String placement;
  final String categoryId;
  final String subcategoryId;
  final String imageUrl;
  final String mobileImageUrl;
  final String clickType;
  final String productId;
  final String externalUrl;
  final int sortOrder;

  StoreMarketplaceBannerData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.placement,
    required this.categoryId,
    required this.subcategoryId,
    required this.imageUrl,
    required this.mobileImageUrl,
    required this.clickType,
    required this.productId,
    required this.externalUrl,
    required this.sortOrder,
  });

  factory StoreMarketplaceBannerData.fromMap(Map<String, dynamic> map) {
    final dynamic targetValue = map['target'];
    final Map<String, dynamic> target = targetValue is Map
        ? Map<String, dynamic>.from(targetValue)
        : <String, dynamic>{};

    return StoreMarketplaceBannerData(
      id: '${map['id'] ?? ''}',
      title: '${map['title'] ?? ''}',
      subtitle: '${map['subtitle'] ?? ''}',
      placement: '${map['placement'] ?? 'home'}',
      categoryId: '${map['category_id'] ?? target['category_id'] ?? ''}',
      subcategoryId:
          '${map['subcategory_id'] ?? target['subcategory_id'] ?? ''}',
      imageUrl: '${map['image_url'] ?? ''}',
      mobileImageUrl: '${map['mobile_image_url'] ?? ''}',
      clickType: '${map['click_type'] ?? 'none'}',
      productId: '${map['product_id'] ?? target['product_id'] ?? ''}',
      externalUrl: '${map['external_url'] ?? target['external_url'] ?? ''}',
      sortOrder: int.tryParse('${map['sort_order'] ?? 0}') ?? 0,
    );
  }

  String get bestImageUrl {
    if (mobileImageUrl.isNotEmpty) {
      return mobileImageUrl;
    }

    return imageUrl;
  }
}

class StoreBoostedCategoryData {
  final String boostId;
  final String requestNumber;
  final String categoryId;
  final String parentId;
  final String categoryName;
  final String storeSellerId;
  final String storeName;
  final String imageUrl;
  final int productsCount;

  StoreBoostedCategoryData({
    required this.boostId,
    required this.requestNumber,
    required this.categoryId,
    required this.parentId,
    required this.categoryName,
    required this.storeSellerId,
    required this.storeName,
    required this.imageUrl,
    required this.productsCount,
  });

  factory StoreBoostedCategoryData.fromMap(Map<String, dynamic> map) {
    return StoreBoostedCategoryData(
      boostId: '${map['boost_id'] ?? ''}',
      requestNumber: '${map['request_number'] ?? ''}',
      categoryId: '${map['category_id'] ?? ''}',
      parentId: '${map['parent_id'] ?? ''}',
      categoryName: '${map['category_name'] ?? map['title'] ?? ''}',
      storeSellerId: '${map['store_seller_id'] ?? map['seller_id'] ?? ''}',
      storeName: '${map['store_name'] ?? ''}',
      imageUrl: '${map['image_url'] ?? ''}',
      productsCount: int.tryParse('${map['products_count'] ?? 0}') ?? 0,
    );
  }
}

class StoreMarketplaceSettings {
  final bool marketplaceEnabled;
  final bool sellerRegistrationEnabled;
  final bool productApprovalRequired;
  final bool manualPayoutEnabled;
  final int maxProductImages;
  final int lokallyShippingSellerDeadlineHours;
  final String marketplaceSupportWhatsapp;
  final String defaultPickupMessage;
  final String defaultPayoutObservation;

  StoreMarketplaceSettings({
    required this.marketplaceEnabled,
    required this.sellerRegistrationEnabled,
    required this.productApprovalRequired,
    required this.manualPayoutEnabled,
    required this.maxProductImages,
    required this.lokallyShippingSellerDeadlineHours,
    required this.marketplaceSupportWhatsapp,
    required this.defaultPickupMessage,
    required this.defaultPayoutObservation,
  });

  factory StoreMarketplaceSettings.defaults() {
    return StoreMarketplaceSettings(
      marketplaceEnabled: true,
      sellerRegistrationEnabled: true,
      productApprovalRequired: true,
      manualPayoutEnabled: true,
      maxProductImages: 6,
      lokallyShippingSellerDeadlineHours: 24,
      marketplaceSupportWhatsapp: '',
      defaultPickupMessage:
          'Apresente o número do pedido ao lojista para retirar sua compra.',
      defaultPayoutObservation:
          'Repasse registrado manualmente pelo ADM Marketplace.',
    );
  }

  factory StoreMarketplaceSettings.fromResponseBody(
    Map<String, dynamic> responseBody,
  ) {
    final dynamic dataValue = responseBody['data'];
    final Map<String, dynamic> data = dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : <String, dynamic>{};

    final dynamic settingsValue = data['settings'];
    final Map<String, dynamic> settings = settingsValue is Map
        ? Map<String, dynamic>.from(settingsValue)
        : <String, dynamic>{};

    return StoreMarketplaceSettings(
      marketplaceEnabled: parseBool(
        settings['marketplace_enabled'],
        fallback: true,
      ),
      sellerRegistrationEnabled: parseBool(
        settings['seller_registration_enabled'],
        fallback: true,
      ),
      productApprovalRequired: parseBool(
        settings['product_approval_required'],
        fallback: true,
      ),
      manualPayoutEnabled: parseBool(
        settings['manual_payout_enabled'],
        fallback: true,
      ),
      maxProductImages: parseInt(settings['max_product_images'], fallback: 6),
      lokallyShippingSellerDeadlineHours: parseInt(
        settings['lokally_shipping_seller_deadline_hours'],
        fallback: 24,
      ),
      marketplaceSupportWhatsapp:
          '${settings['marketplace_support_whatsapp'] ?? ''}',
      defaultPickupMessage:
          '${settings['default_pickup_message'] ?? 'Apresente o número do pedido ao lojista para retirar sua compra.'}',
      defaultPayoutObservation:
          '${settings['default_payout_observation'] ?? 'Repasse registrado manualmente pelo ADM Marketplace.'}',
    );
  }

  bool get hasSupportWhatsapp => supportWhatsappDigits.isNotEmpty;

  String get supportWhatsappDigits {
    return marketplaceSupportWhatsapp.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static bool parseBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value == 1;
    }

    final String text = '$value'.trim().toLowerCase();

    if (text == '1' || text == 'true' || text == 'yes' || text == 'sim') {
      return true;
    }

    if (text == '0' || text == 'false' || text == 'no' || text == 'não') {
      return false;
    }

    return fallback;
  }

  static int parseInt(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse('$value') ?? fallback;
  }
}

class StoreCategoryData {
  final String id;
  final String parentId;
  final String name;
  final String slug;
  final String imageUrl;
  final String iconUrl;
  final List<StoreCategoryData> subcategories;

  StoreCategoryData({
    required this.id,
    required this.parentId,
    required this.name,
    required this.slug,
    required this.imageUrl,
    this.iconUrl = '',
    this.subcategories = const <StoreCategoryData>[],
  });

  factory StoreCategoryData.all() {
    return StoreCategoryData(
      id: '',
      parentId: '',
      name: 'Todos',
      slug: 'all',
      imageUrl: '',
      iconUrl: '',
    );
  }

  factory StoreCategoryData.allSubcategory() {
    return StoreCategoryData(
      id: '',
      parentId: '',
      name: 'Todas',
      slug: 'all_subcategories',
      imageUrl: '',
      iconUrl: '',
    );
  }

  factory StoreCategoryData.fromMap(Map<String, dynamic> map) {
    final dynamic subcategoriesValue = map['subcategories'];
    final List<dynamic> subcategoryList =
        subcategoriesValue is List ? subcategoriesValue : <dynamic>[];

    final String imageUrl = '${map['image_url'] ?? ''}';
    final String iconUrl =
        '${map['icon_url'] ?? map['icon_image_url'] ?? map['icon'] ?? imageUrl}';

    return StoreCategoryData(
      id: '${map['id'] ?? ''}',
      parentId: '${map['parent_id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      slug: '${map['slug'] ?? ''}',
      imageUrl: imageUrl,
      iconUrl: iconUrl,
      subcategories: subcategoryList
          .whereType<Map>()
          .map((item) => StoreCategoryData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((subcategory) => subcategory.id.isNotEmpty)
          .toList(),
    );
  }

  bool get isAll => id.isEmpty;

  String get normalizedIdentifier {
    return '$name $slug'
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ã', 'a')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u');
  }

  String? get localIconAsset {
    final String normalized = normalizedIdentifier;

    if (isAll || normalized.contains('todos') || normalized.contains('all')) {
      return 'assets/image/todos.png';
    }

    if (normalized.contains('beleza')) {
      return 'assets/image/beleza_icon.png';
    }

    if (normalized.contains('servico') ||
        normalized.contains('service') ||
        normalized.contains('servicos')) {
      return 'assets/image/servicos_icon.png';
    }

    return null;
  }
}

class StoreProductData {
  final String id;
  final String sellerId;
  final String title;
  final String slug;
  final String shortDescription;
  final double price;
  final double? promotionalPrice;
  final double finalPrice;
  final bool hasPromotion;
  final int stock;
  final String unit;
  final String categoryId;
  final String category;
  final String mainImageUrl;
  final String storeName;
  final String storeLogoUrl;
  final String storeCoverImageUrl;
  final String availabilityType;
  final String availabilityLabel;
  final String productType;
  final String conditionType;
  final String serviceDeliveryType;
  final String boostId;
  final String boostBadge;
  final bool isBoosted;

  StoreProductData({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.slug,
    required this.shortDescription,
    required this.price,
    required this.promotionalPrice,
    required this.finalPrice,
    required this.hasPromotion,
    required this.stock,
    required this.unit,
    required this.categoryId,
    required this.category,
    required this.mainImageUrl,
    required this.storeName,
    required this.storeLogoUrl,
    required this.storeCoverImageUrl,
    required this.availabilityType,
    required this.availabilityLabel,
    required this.productType,
    required this.conditionType,
    required this.serviceDeliveryType,
    this.boostId = '',
    this.boostBadge = '',
    this.isBoosted = false,
  });

  factory StoreProductData.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> store = map['store'] is Map
        ? Map<String, dynamic>.from(map['store'])
        : <String, dynamic>{};

    final double regularPrice = parseDouble(map['regular_price']);
    final double price =
        regularPrice > 0 ? regularPrice : parseDouble(map['price']);
    final double promotionalPrice = parseDouble(
      map['promotional_price'] ?? map['old_price'],
    );
    final double finalPriceFromApi = parseDouble(map['final_price']);
    final double finalPrice = finalPriceFromApi > 0
        ? finalPriceFromApi
        : (promotionalPrice > 0 ? promotionalPrice : parseDouble(map['price']));
    final bool apiPromotion = map['has_promotion'] == true;
    final bool boostedPromotion =
        promotionalPrice > 0 && price > 0 && promotionalPrice < price;
    final bool hasPromotion = apiPromotion || boostedPromotion;

    return StoreProductData(
      id: '${map['id'] ?? ''}',
      sellerId: '${map['seller_id'] ?? map['store_seller_id'] ?? ''}',
      title: '${map['name'] ?? ''}',
      slug: '${map['slug'] ?? ''}',
      shortDescription: '${map['short_description'] ?? ''}',
      price: price,
      promotionalPrice: promotionalPrice > 0 ? promotionalPrice : null,
      finalPrice: finalPrice > 0 ? finalPrice : price,
      hasPromotion: hasPromotion,
      stock: int.tryParse('${map['stock'] ?? 0}') ?? 0,
      unit: '${map['unit'] ?? 'unidade'}',
      categoryId: '${map['category_id'] ?? ''}',
      category: '${map['category_name'] ?? ''}',
      mainImageUrl: '${map['main_image_url'] ?? map['image_url'] ?? ''}',
      storeName: '${store['name'] ?? map['store_name'] ?? ''}',
      storeLogoUrl: '${store['logo_url'] ?? map['seller_logo_url'] ?? ''}',
      storeCoverImageUrl: '${store['cover_image_url'] ?? ''}',
      availabilityType: '${map['availability_type'] ?? 'immediate'}',
      availabilityLabel: '${map['availability_label'] ?? 'Imediata'}',
      productType: '${map['product_type'] ?? 'physical'}'.trim().toLowerCase(),
      conditionType: '${map['condition_type'] ?? 'new'}'.trim().toLowerCase(),
      serviceDeliveryType:
          '${map['service_delivery_type'] ?? ''}'.trim().toLowerCase(),
      boostId: '${map['boost_id'] ?? ''}',
      boostBadge: '${map['boost_badge'] ?? ''}',
      isBoosted: map['is_boosted'] == true ||
          '${map['is_boosted'] ?? ''}' == '1' ||
          '${map['is_boosted'] ?? ''}'.toLowerCase() == 'true',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'seller_id': sellerId,
      'name': title,
      'slug': slug,
      'short_description': shortDescription,
      'price': price,
      'promotional_price': promotionalPrice,
      'final_price': finalPrice,
      'has_promotion': hasPromotion,
      'stock': stock,
      'unit': unit,
      'category_id': categoryId,
      'category_name': category,
      'main_image_url': mainImageUrl,
      'availability_type': availabilityType,
      'availability_label': availabilityLabel,
      'product_type': productType,
      'condition_type': conditionType,
      'service_delivery_type': serviceDeliveryType,
      'boost_id': boostId,
      'boost_badge': boostBadge,
      'is_boosted': isBoosted,
      'store': <String, dynamic>{
        'id': sellerId,
        'name': storeName,
        'logo_url': storeLogoUrl,
        'cover_image_url': storeCoverImageUrl,
      },
    };
  }

  String get formattedPrice => formatCurrency(price);

  String get formattedPromotionalPrice {
    if (promotionalPrice == null || promotionalPrice! <= 0) {
      return '';
    }

    return formatCurrency(promotionalPrice!);
  }

  String get formattedFinalPrice => formatCurrency(finalPrice);

  String get discountLabel {
    if (!hasPromotion || price <= 0) {
      return '';
    }

    final double discount = ((price - finalPrice) / price) * 100;
    final int wholePart = discount.floor();
    final double decimalPart = discount - wholePart;

    final String formatted =
        decimalPart >= 0.5 ? '${wholePart.toString()},5' : wholePart.toString();

    return '-$formatted%';
  }

  bool get isService => productType == 'service';

  String get compactServiceDeliveryLabel {
    switch (serviceDeliveryType) {
      case 'download':
        return 'Digital com download';
      case 'home_office':
      case 'homeoffice':
        return 'Home office';
      case 'digital':
      case 'online':
        return 'Digital';
      case 'presential':
      case 'presencial':
        return 'Presencial';
      default:
        return 'Serviço';
    }
  }

  String get serviceDeliveryLabel {
    switch (serviceDeliveryType) {
      case 'download':
        return 'Download';
      case 'presential':
      case 'presencial':
        return 'Presencial';
      case 'home_office':
      case 'homeoffice':
        return 'Home Office';
      case 'digital':
      case 'online':
        return 'Digital';
      default:
        return 'Serviço';
    }
  }

  String get serviceDeliveryDescription {
    switch (serviceDeliveryType) {
      case 'download':
        return 'Entrega digital após confirmação do pedido.';
      case 'presential':
      case 'presencial':
        return 'Atendimento presencial combinado com o vendedor.';
      case 'home_office':
      case 'homeoffice':
        return 'Atendimento remoto em formato Home Office.';
      case 'digital':
      case 'online':
        return 'Serviço digital realizado de forma online.';
      default:
        return 'Serviço contratado pelo Marketplace Lokally.';
    }
  }

  String get actionLabel {
    return isService ? 'Ver serviço' : 'Ver oferta';
  }

  static double parseDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse('$value') ?? 0;
  }

  static String formatCurrency(double value) {
    final String fixed = value.toStringAsFixed(2);
    final List<String> parts = fixed.split('.');
    String integer = parts.first;
    final String decimal = parts.length > 1 ? parts.last : '00';

    final RegExp regex = RegExp(r'(\d+)(\d{3})');

    while (regex.hasMatch(integer)) {
      integer = integer.replaceAllMapped(
        regex,
        (match) => '${match.group(1)}.${match.group(2)}',
      );
    }

    return 'R\$$integer,$decimal';
  }
}
