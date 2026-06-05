import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/screens/parcel_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_cart_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_product_details_screen.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_marketplace_footer.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_marketplace_header.dart';
import 'package:ride_sharing_user_app/helper/login_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreProductCategoryScreen extends StatefulWidget {
  final String initialCategoryId;
  final String initialCategoryName;
  final String initialCategorySlug;

  const StoreProductCategoryScreen({
    super.key,
    required this.initialCategoryId,
    required this.initialCategoryName,
    required this.initialCategorySlug,
  });

  @override
  State<StoreProductCategoryScreen> createState() =>
      _StoreProductCategoryScreenState();
}

class _StoreProductCategoryScreenState
    extends State<StoreProductCategoryScreen> {
  static const Color vehicleMarketplaceColor = Color(0xFF2F343A);
  static const Color realEstateMarketplaceColor = Color(0xFF1565C0);
  static const String publicCategoriesUri = '/api/store/public-categories';
  static const String publicProductsUri = '/api/store/products';
  static const String publicVehiclesUri = '/api/store/vehicles';
  static const String publicRealEstateUri = '/api/store/real-estate';
  static const String marketplaceBannersUri = '/api/store/banners';

  final ScrollController scrollController = ScrollController();
  final TextEditingController searchController = TextEditingController();

  bool isLoading = true;
  bool isLoadingBanners = false;
  int selectedMainCategoryIndex = 0;
  String selectedSubcategoryId = '';
  String selectedFilter = 'all';
  String searchQuery = '';
  bool showBackToTopButton = false;

  List<_StoreProductCategoryData> mainCategories = <_StoreProductCategoryData>[
    _StoreProductCategoryData.all(),
  ];
  List<_StoreProductItemData> products = <_StoreProductItemData>[];
  List<_StoreCategoryBannerData> categoryBanners = <_StoreCategoryBannerData>[];

  @override
  void initState() {
    super.initState();
    scrollController.addListener(handleScrollPosition);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadScreenData();
    });
  }

  @override
  void dispose() {
    scrollController.removeListener(handleScrollPosition);
    scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void handleScrollPosition() {
    if (!scrollController.hasClients) {
      return;
    }

    final bool shouldShow = scrollController.offset > 520;

    if (shouldShow == showBackToTopButton) {
      return;
    }

    setState(() {
      showBackToTopButton = shouldShow;
    });
  }

  void scrollToTop() {
    if (!scrollController.hasClients) {
      return;
    }

    scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  bool get isCustomerLoggedIn {
    return Get.isRegistered<AuthController>() &&
        Get.find<AuthController>().isLoggedIn();
  }

  String get initialCategoryFingerprint {
    return _normalizeMarketplaceText(
      '${widget.initialCategoryName} ${widget.initialCategorySlug} ${widget.initialCategoryId}',
    );
  }

  bool get isVehicleFeed {
    final String normalized = initialCategoryFingerprint;

    return normalized.contains('veiculo') ||
        normalized.contains('vehicle') ||
        normalized.contains('auto') ||
        normalized.contains('carro') ||
        normalized.contains('moto');
  }

  bool get isRealEstateFeed {
    final String normalized = initialCategoryFingerprint;

    return normalized.contains('imovel') ||
        normalized.contains('imoveis') ||
        normalized.contains('realestate') ||
        normalized.contains('real estate') ||
        normalized.contains('property') ||
        normalized.contains('imobiliario');
  }

  bool get isClassifiedFeed => isVehicleFeed || isRealEstateFeed;

  Color get currentFeedPrimaryColor {
    if (isVehicleFeed) {
      return vehicleMarketplaceColor;
    }

    if (isRealEstateFeed) {
      return realEstateMarketplaceColor;
    }

    return Theme.of(context).primaryColor;
  }

  String get currentFeedEndpoint {
    if (isVehicleFeed) {
      return publicVehiclesUri;
    }

    if (isRealEstateFeed) {
      return publicRealEstateUri;
    }

    return publicProductsUri;
  }

  String get currentFeedPrimaryListKey {
    if (isVehicleFeed) {
      return 'vehicles';
    }

    if (isRealEstateFeed) {
      return 'real_estate';
    }

    return 'products';
  }

  String get currentFeedFallbackTitle {
    if (isVehicleFeed) {
      return 'Veículos';
    }

    if (isRealEstateFeed) {
      return 'Imóveis';
    }

    return 'Produtos';
  }

  String get currentFeedSingularLabel {
    if (isVehicleFeed) {
      return 'veículo';
    }

    if (isRealEstateFeed) {
      return 'imóvel';
    }

    return 'produto';
  }

  String get currentFeedPluralLabel {
    if (isVehicleFeed) {
      return 'veículos';
    }

    if (isRealEstateFeed) {
      return 'imóveis';
    }

    return 'produtos';
  }

  String get currentFeedSearchTitle {
    if (isVehicleFeed) {
      return 'Buscar em veículos';
    }

    if (isRealEstateFeed) {
      return 'Buscar em imóveis';
    }

    return 'Buscar em produtos';
  }

  String get currentFeedSearchHint {
    if (isVehicleFeed) {
      return 'Digite modelo, marca ou cidade';
    }

    if (isRealEstateFeed) {
      return 'Digite bairro, cidade ou tipo de imóvel';
    }

    return 'Digite o nome do produto';
  }

  String get currentFeedEmptyTitle {
    if (isVehicleFeed) {
      return 'Nenhum veículo encontrado';
    }

    if (isRealEstateFeed) {
      return 'Nenhum imóvel encontrado';
    }

    return 'Nenhum produto encontrado';
  }

  String get currentFeedEmptyDescription {
    if (isVehicleFeed) {
      return 'Tente outra busca ou volte mais tarde para ver novos anúncios.';
    }

    if (isRealEstateFeed) {
      return 'Tente outra busca ou volte mais tarde para ver novos imóveis.';
    }

    return 'Tente outra subcategoria ou remova os filtros aplicados.';
  }

  _StoreProductCategoryData get selectedMainCategory {
    if (mainCategories.isEmpty ||
        selectedMainCategoryIndex >= mainCategories.length) {
      return _StoreProductCategoryData.all();
    }

    return mainCategories[selectedMainCategoryIndex];
  }

  List<StoreMarketplaceCategoryViewData> get marketplaceHeaderCategories {
    return mainCategories.map((category) {
      return StoreMarketplaceCategoryViewData(
        id: category.id,
        name: category.isAll ? 'Home' : category.name,
        primaryIconUrl: category.primaryIconUrl,
        localIconAsset: category.localIconAsset,
        isAll: category.isAll,
        normalizedIdentifier: category.normalizedIdentifier,
      );
    }).toList();
  }

  List<_StoreProductCategoryData> get activeSubcategories {
    if (selectedMainCategory.isAll) {
      return <_StoreProductCategoryData>[];
    }

    return selectedMainCategory.subcategories;
  }

  Future<void> loadScreenData() async {
    setState(() {
      isLoading = true;
    });

    await Future.wait(<Future<void>>[
      loadCategories(),
      loadProducts(),
    ]);

    if (mounted) {
      applyMarketplaceCategoryFilter();
      await loadCategoryBanners();
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> loadCategories() async {
    try {
      final Response response =
          await Get.find<ApiClient>().getData(publicCategoriesUri);

      final dynamic responseBody = response.body;

      if (response.statusCode != 200 ||
          responseBody is! Map ||
          responseBody['status'] != true) {
        return;
      }

      final dynamic dataValue = responseBody['data'];
      final List<dynamic> data = dataValue is List ? dataValue : <dynamic>[];

      final List<_StoreProductCategoryData> apiCategories = data
          .whereType<Map>()
          .map((item) => _StoreProductCategoryData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((category) => category.id.isNotEmpty)
          .toList();

      _StoreProductCategoryData? admAllCategory;
      final List<_StoreProductCategoryData> regularCategories =
          <_StoreProductCategoryData>[];
      final Set<String> addedCategoryKeys = <String>{};

      for (final _StoreProductCategoryData category in apiCategories) {
        if (category.representsAllCategory) {
          admAllCategory ??= category;
          continue;
        }

        final String categoryKey = category.deduplicationKey;

        if (categoryKey.isEmpty || addedCategoryKeys.contains(categoryKey)) {
          continue;
        }

        addedCategoryKeys.add(categoryKey);
        regularCategories.add(category);
      }

      regularCategories.sort((a, b) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      final List<_StoreProductCategoryData> loadedCategories =
          <_StoreProductCategoryData>[
        _StoreProductCategoryData.all(
          imageUrl: admAllCategory?.primaryIconUrl ?? '',
          iconUrl: admAllCategory?.primaryIconUrl ?? '',
        ),
        ...regularCategories,
      ];

      final int initialIndex = resolveInitialCategoryIndex(loadedCategories);

      if (!mounted) {
        return;
      }

      setState(() {
        mainCategories = loadedCategories;
        selectedMainCategoryIndex = initialIndex;
        selectedSubcategoryId = '';
      });
    } catch (_) {}
  }

  int resolveInitialCategoryIndex(
    List<_StoreProductCategoryData> loadedCategories,
  ) {
    if (widget.initialCategoryId.trim().isNotEmpty) {
      final int byId = loadedCategories.indexWhere(
        (category) => category.id == widget.initialCategoryId,
      );

      if (byId >= 0) {
        return byId;
      }
    }

    final String initialSlug = widget.initialCategorySlug.trim().toLowerCase();

    if (initialSlug.isNotEmpty) {
      final int bySlug = loadedCategories.indexWhere(
        (category) => category.slug.toLowerCase() == initialSlug,
      );

      if (bySlug >= 0) {
        return bySlug;
      }
    }

    final String initialName = widget.initialCategoryName.trim().toLowerCase();

    if (initialName.isNotEmpty) {
      final int byName = loadedCategories.indexWhere(
        (category) => category.name.toLowerCase() == initialName,
      );

      if (byName >= 0) {
        return byName;
      }
    }

    return 0;
  }

  Future<void> loadProducts() async {
    try {
      final Response response = await Get.find<ApiClient>()
          .getData('$currentFeedEndpoint?per_page=100&limit=100');

      final dynamic responseBody = response.body;

      if (response.statusCode != 200 ||
          responseBody is! Map ||
          responseBody['status'] != true) {
        return;
      }

      final dynamic dataValue = responseBody['data'];
      final List<dynamic> productList = extractMarketplaceItems(dataValue);

      if (!mounted) {
        return;
      }

      setState(() {
        products = productList
            .whereType<Map>()
            .map((item) => _StoreProductItemData.fromMap(
                  Map<String, dynamic>.from(item),
                  fallbackProductType: isVehicleFeed
                      ? 'vehicle'
                      : (isRealEstateFeed ? 'real_estate' : 'physical'),
                ))
            .where((product) {
          if (product.id.isEmpty) {
            return false;
          }

          if (isVehicleFeed) {
            return product.isVehicle;
          }

          if (isRealEstateFeed) {
            return product.isRealEstate;
          }

          return product.isPhysical;
        }).toList();
      });
    } catch (_) {}
  }

  List<dynamic> extractMarketplaceItems(dynamic dataValue) {
    if (dataValue is List) {
      return dataValue;
    }

    final Map<String, dynamic> data = dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : <String, dynamic>{};

    final List<String> candidateKeys = <String>[
      currentFeedPrimaryListKey,
      'products',
      'items',
      'data',
      'ads',
      'results',
    ];

    for (final String key in candidateKeys) {
      final dynamic value = data[key];

      if (value is List) {
        return value;
      }
    }

    return <dynamic>[];
  }

  bool categoryBelongsToCurrentFeed(_StoreProductCategoryData category) {
    if (category.isAll) {
      return true;
    }

    if (isVehicleFeed) {
      return isVehicleMarketplaceCategory(category);
    }

    if (isRealEstateFeed) {
      return isRealEstateMarketplaceCategory(category);
    }

    return !isExternalMarketplaceCategory(category);
  }

  bool categoryHasCurrentFeedItems(
    _StoreProductCategoryData category,
    Set<String> categoryIds,
  ) {
    if (category.isAll) {
      return true;
    }

    if (!categoryBelongsToCurrentFeed(category)) {
      return false;
    }

    if (categoryIds.contains(category.id)) {
      return true;
    }

    if (category.subcategories.any((subcategory) {
      return categoryHasCurrentFeedItems(subcategory, categoryIds);
    })) {
      return true;
    }

    return isClassifiedFeed && products.isNotEmpty;
  }

  _StoreProductCategoryData categoryWithOnlyCurrentFeedChildren(
    _StoreProductCategoryData category,
    Set<String> categoryIds,
  ) {
    final List<_StoreProductCategoryData> filteredSubcategories =
        category.subcategories.where((subcategory) {
      return categoryHasCurrentFeedItems(subcategory, categoryIds);
    }).map((subcategory) {
      return categoryWithOnlyCurrentFeedChildren(
        subcategory,
        categoryIds,
      );
    }).toList();

    return _StoreProductCategoryData(
      id: category.id,
      parentId: category.parentId,
      name: category.name,
      slug: category.slug,
      imageUrl: category.imageUrl,
      iconUrl: category.iconUrl,
      subcategories: filteredSubcategories,
    );
  }

  void applyMarketplaceCategoryFilter() {
    if (mainCategories.isEmpty) {
      return;
    }

    final Set<String> feedCategoryIds = products
        .where((product) => product.categoryId.isNotEmpty)
        .map((product) => product.categoryId)
        .toSet();

    final _StoreProductCategoryData allCategory = mainCategories.firstWhere(
      (category) => category.isAll,
      orElse: () => _StoreProductCategoryData.all(),
    );

    final List<_StoreProductCategoryData> filteredCategories =
        mainCategories.where((category) => !category.isAll).where((category) {
      return categoryHasCurrentFeedItems(category, feedCategoryIds);
    }).map((category) {
      return categoryWithOnlyCurrentFeedChildren(category, feedCategoryIds);
    }).toList();

    final List<_StoreProductCategoryData> nextCategories =
        <_StoreProductCategoryData>[
      allCategory,
      ...filteredCategories,
    ];

    int nextSelectedIndex = resolveInitialCategoryIndex(nextCategories);

    if (nextSelectedIndex < 0 || nextSelectedIndex >= nextCategories.length) {
      nextSelectedIndex = 0;
    }

    setState(() {
      mainCategories = nextCategories;
      selectedMainCategoryIndex = nextSelectedIndex;
      selectedSubcategoryId = '';
    });
  }

  Future<void> loadCategoryBanners() async {
    final _StoreProductCategoryData selected = selectedMainCategory;

    String bannerUri = '';

    if (isVehicleFeed) {
      bannerUri = '$marketplaceBannersUri?placement=vehicles_home';
    } else if (isRealEstateFeed) {
      bannerUri = '$marketplaceBannersUri?placement=real_estate_home';
    } else if (!selected.isAll && selected.id.isNotEmpty) {
      bannerUri =
          '$marketplaceBannersUri?placement=category&category_id=${Uri.encodeComponent(selected.id)}';
    }

    if (bannerUri.isEmpty) {
      setState(() {
        categoryBanners = <_StoreCategoryBannerData>[];
        isLoadingBanners = false;
      });
      return;
    }

    setState(() {
      isLoadingBanners = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().getData(
        bannerUri,
      );

      final dynamic responseBody = response.body;

      if (response.statusCode != 200 ||
          responseBody is! Map ||
          responseBody['status'] != true) {
        if (mounted) {
          setState(() {
            categoryBanners = <_StoreCategoryBannerData>[];
            isLoadingBanners = false;
          });
        }
        return;
      }

      final dynamic dataValue = responseBody['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};
      final dynamic bannersValue = data['banners'];
      final List<dynamic> bannerList =
          bannersValue is List ? bannersValue : <dynamic>[];

      final List<_StoreCategoryBannerData> loadedBanners = bannerList
          .whereType<Map>()
          .map((item) => _StoreCategoryBannerData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((banner) => banner.imageUrl.isNotEmpty)
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        categoryBanners = loadedBanners;
        isLoadingBanners = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          categoryBanners = <_StoreCategoryBannerData>[];
          isLoadingBanners = false;
        });
      }
    }
  }

  List<_StoreProductItemData> get visibleProducts {
    final _StoreProductCategoryData selected = selectedMainCategory;

    List<_StoreProductItemData> result = products;

    if (!selected.isAll) {
      if (selectedSubcategoryId.isNotEmpty) {
        result = result.where((product) {
          return product.categoryId == selectedSubcategoryId;
        }).toList();
      } else {
        final Set<String> subcategoryIds = selected.subcategories
            .map((subcategory) => subcategory.id)
            .where((id) => id.isNotEmpty)
            .toSet();

        final bool shouldFilterByCategory = !isClassifiedFeed ||
            result.any((product) => product.categoryId.isNotEmpty);

        if (shouldFilterByCategory) {
          result = result.where((product) {
            return product.categoryId == selected.id ||
                subcategoryIds.contains(product.categoryId);
          }).toList();
        }
      }
    }

    final String query = searchQuery.trim().toLowerCase();

    if (query.isNotEmpty) {
      result = result.where((product) {
        return product.title.toLowerCase().contains(query) ||
            product.category.toLowerCase().contains(query) ||
            product.storeName.toLowerCase().contains(query);
      }).toList();
    }

    if (selectedFilter == 'discount') {
      result = result.where((product) => product.hasPromotion).toList();
    } else if (selectedFilter == 'lowest_price') {
      result = List<_StoreProductItemData>.from(result)
        ..sort((a, b) => a.finalPrice.compareTo(b.finalPrice));
    } else if (selectedFilter == 'newest') {
      result = List<_StoreProductItemData>.from(result)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    return result;
  }

  String get screenTitle {
    if (selectedMainCategory.isAll) {
      return currentFeedFallbackTitle;
    }

    if (selectedSubcategoryId.isNotEmpty) {
      return activeSubcategories
          .firstWhere(
            (subcategory) => subcategory.id == selectedSubcategoryId,
            orElse: () => selectedMainCategory,
          )
          .name;
    }

    return selectedMainCategory.name;
  }

  String get screenDescription {
    final int count = visibleProducts.length;
    final String singular = currentFeedSingularLabel;
    final String plural = currentFeedPluralLabel;

    if (selectedSubcategoryId.isNotEmpty) {
      return count == 1
          ? '1 $singular encontrado nesta subcategoria'
          : '$count $plural encontrados nesta subcategoria';
    }

    if (selectedMainCategory.isAll) {
      return count == 1
          ? '1 $singular disponível'
          : '$count $plural disponíveis';
    }

    return count == 1
        ? '1 $singular encontrado nesta categoria'
        : '$count $plural encontrados nesta categoria';
  }

  bool isServicesMarketplaceCategory(_StoreProductCategoryData category) {
    final String normalized = category.normalizedIdentifier;

    return normalized.contains('servico') || normalized.contains('service');
  }

  bool isRealEstateMarketplaceCategory(_StoreProductCategoryData category) {
    final String normalized = category.normalizedIdentifier;

    return normalized.contains('imovel') ||
        normalized.contains('imoveis') ||
        normalized.contains('realestate') ||
        normalized.contains('real estate') ||
        normalized.contains('property') ||
        normalized.contains('imobiliario');
  }

  bool isVehicleMarketplaceCategory(_StoreProductCategoryData category) {
    final String normalized = category.normalizedIdentifier;

    return normalized.contains('veiculo') ||
        normalized.contains('vehicle') ||
        normalized.contains('auto') ||
        normalized.contains('carro') ||
        normalized.contains('moto');
  }

  bool isExternalMarketplaceCategory(_StoreProductCategoryData category) {
    return isServicesMarketplaceCategory(category) ||
        isRealEstateMarketplaceCategory(category) ||
        isVehicleMarketplaceCategory(category);
  }

  Future<void> handleMainCategorySelected(int index) async {
    if (index < 0 || index >= mainCategories.length) {
      return;
    }

    final _StoreProductCategoryData category = mainCategories[index];

    if (category.isAll) {
      Get.back();
      return;
    }

    if (isExternalMarketplaceCategory(category) &&
        !categoryBelongsToCurrentFeed(category)) {
      showStoreMessage(
        'Abra esta categoria pelo menu principal do Marketplace.',
      );
      return;
    }

    setState(() {
      selectedMainCategoryIndex = index;
      selectedSubcategoryId = '';
      selectedFilter = 'all';
      searchQuery = '';
      searchController.clear();
    });

    await loadCategoryBanners();
  }

  void handleSubcategorySelected(String subcategoryId) {
    setState(() {
      selectedSubcategoryId = subcategoryId;
      selectedFilter = 'all';
    });
  }

  void handleFilterSelected(String filter) {
    setState(() {
      selectedFilter = filter;
    });
  }

  void handleProductTap(_StoreProductItemData product) {
    Get.to(
      () => StoreProductDetailsScreen(
        initialProduct: product.toMap(),
      ),
    );
  }

  void openCartScreen() {
    Get.to(() => const StoreCartScreen());
  }

  void handleTravelTap() {
    if (!isCustomerLoggedIn) {
      showLoginRequiredDialog(
        'Para solicitar viagens é necessário ser cadastrado.',
      );
      return;
    }

    if (Get.isRegistered<BottomMenuController>()) {
      Get.find<BottomMenuController>().setTabIndex(0);
    }

    Get.offAll(() => const DashboardScreen());
  }

  void handleDeliveryTap() {
    if (!isCustomerLoggedIn) {
      showLoginRequiredDialog(
        'Para solicitar entregas é necessário ser cadastrado.',
      );
      return;
    }

    Get.to(() => const ParcelScreen());
  }

  void showLoginRequiredDialog(String message) {
    final Color primaryColor = currentFeedPrimaryColor;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 14),
                blurRadius: 34,
                color: Colors.black.withValues(alpha: 0.18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, color: primaryColor, size: 34),
              const SizedBox(height: 12),
              Text(
                'Cadastro necessário',
                style: textBold.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textRegular.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    LoginHelper.checkLoginMedium();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Entrar ou cadastrar',
                    style: textBold.copyWith(
                      color: Colors.white,
                      fontSize: 13,
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

  void showStoreMessage(String message) {
    final Color primaryColor = currentFeedPrimaryColor;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: textMedium.copyWith(color: Colors.white, fontSize: 12.8),
        ),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void showSearchSheet() {
    final Color primaryColor = currentFeedPrimaryColor;
    final TextEditingController modalController = TextEditingController(
      text: searchQuery,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 14,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, 12),
                    blurRadius: 28,
                    color: Colors.black.withValues(alpha: 0.16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentFeedSearchTitle,
                    style: textBold.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: modalController,
                      autofocus: true,
                      onSubmitted: (value) {
                        setState(() {
                          searchQuery = value;
                          searchController.text = value;
                        });
                        Navigator.of(modalContext).pop();
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        icon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey.shade600,
                          size: 21,
                        ),
                        border: InputBorder.none,
                        hintText: currentFeedSearchHint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          searchQuery = modalController.text;
                          searchController.text = modalController.text;
                        });
                        Navigator.of(modalContext).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Buscar',
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(modalController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = currentFeedPrimaryColor;
    final List<_StoreProductItemData> productsForView = visibleProducts;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double availableGridWidth =
        screenWidth - (Dimensions.paddingSizeDefault * 2) - 12;
    final double gridItemWidth =
        (availableGridWidth / 2).clamp(150.0, 320.0).toDouble();
    final bool applyAndroidClassifiedGridFix =
        defaultTargetPlatform == TargetPlatform.android && isClassifiedFeed;
    final double productCardMainAxisExtent = applyAndroidClassifiedGridFix
        ? (gridItemWidth + 156).clamp(348.0, 430.0).toDouble()
        : 348;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              StoreMarketplaceModeSelectorHeader(
                primaryColor: primaryColor,
                onShoppingTap: () {},
                onTravelTap: handleTravelTap,
                onDeliveryTap: handleDeliveryTap,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: primaryColor,
                  onRefresh: loadScreenData,
                  child: CustomScrollView(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: -10,
                              left: -Dimensions.paddingSizeDefault,
                              right: -Dimensions.paddingSizeDefault,
                              child: _ProductCategoryHeaderGradient(
                                primaryColor: primaryColor,
                                isVehicleFeed: isVehicleFeed,
                                isRealEstateFeed: isRealEstateFeed,
                                height: 315,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                Dimensions.paddingSizeDefault,
                                10,
                                Dimensions.paddingSizeDefault,
                                0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StoreMarketplaceMainCategoryMenu(
                                    categories: marketplaceHeaderCategories,
                                    selectedIndex: selectedMainCategoryIndex,
                                    primaryColor: primaryColor,
                                    onSelected: handleMainCategorySelected,
                                  ),
                                  const SizedBox(height: 14),
                                  if (isLoadingBanners) ...[
                                    _ProductCategoryBannerSkeleton(
                                      primaryColor: primaryColor,
                                    ),
                                    const SizedBox(height: 18),
                                  ] else if (categoryBanners.isNotEmpty) ...[
                                    _ProductCategoryBannerCarousel(
                                      banners: categoryBanners,
                                    ),
                                    const SizedBox(height: 18),
                                  ],
                                  if (activeSubcategories.isNotEmpty) ...[
                                    _ProductSubcategoryMenu(
                                      subcategories: activeSubcategories,
                                      selectedSubcategoryId:
                                          selectedSubcategoryId,
                                      primaryColor: primaryColor,
                                      onSelected: handleSubcategorySelected,
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                  Text(
                                    screenTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textBold.copyWith(
                                      color: Colors.black87,
                                      fontSize: 23,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    screenDescription,
                                    style: textRegular.copyWith(
                                      color: Colors.grey.shade600,
                                      fontSize: 13.2,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _ProductFilterChips(
                                    selectedFilter: selectedFilter,
                                    primaryColor: primaryColor,
                                    onSelected: handleFilterSelected,
                                  ),
                                  if (searchQuery.trim().isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    _ActiveSearchChip(
                                      query: searchQuery,
                                      primaryColor: primaryColor,
                                      onClear: () {
                                        setState(() {
                                          searchQuery = '';
                                          searchController.clear();
                                        });
                                      },
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isLoading)
                        SliverToBoxAdapter(
                          child: _ProductGridLoading(
                            primaryColor: primaryColor,
                          ),
                        )
                      else if (productsForView.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyProductCategory(
                            primaryColor: primaryColor,
                            title: currentFeedEmptyTitle,
                            description: currentFeedEmptyDescription,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            Dimensions.paddingSizeDefault,
                            0,
                            Dimensions.paddingSizeDefault,
                            24,
                          ),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final _StoreProductItemData product =
                                    productsForView[index];

                                return _ProductCategoryProductCard(
                                  product: product,
                                  primaryColor: primaryColor,
                                  onTap: () => handleProductTap(product),
                                );
                              },
                              childCount: productsForView.length,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 14,
                              mainAxisExtent: productCardMainAxisExtent,
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 140),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 92,
            child: AnimatedScale(
              scale: showBackToTopButton ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: showBackToTopButton ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: StoreMarketplaceBackToTopButton(
                  primaryColor: primaryColor,
                  onTap: scrollToTop,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: StoreMarketplaceBottomSearchCartBar(
        primaryColor: primaryColor,
        onSearchTap: showSearchSheet,
        onCartTap: openCartScreen,
      ),
    );
  }
}

class _ProductCategoryHeaderGradient extends StatelessWidget {
  final Color primaryColor;
  final bool isVehicleFeed;
  final bool isRealEstateFeed;
  final double height;

  const _ProductCategoryHeaderGradient({
    required this.primaryColor,
    required this.isVehicleFeed,
    required this.isRealEstateFeed,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVehicleFeed && !isRealEstateFeed) {
      return StoreMarketplaceHeaderGradient(
        primaryColor: primaryColor,
        height: height,
      );
    }

    if (isRealEstateFeed) {
      return Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1565C0),
              Color(0xFF2F7FD4),
              Color(0xFFEAF4FF),
              Colors.white,
            ],
            stops: [0.0, 0.36, 0.76, 1.0],
          ),
        ),
      );
    }

    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2F343A),
            Color(0xFF4A525A),
            Color(0xFFF1F3F5),
            Colors.white,
          ],
          stops: [0.0, 0.36, 0.76, 1.0],
        ),
      ),
    );
  }
}

class _ProductSubcategoryMenu extends StatelessWidget {
  final List<_StoreProductCategoryData> subcategories;
  final String selectedSubcategoryId;
  final Color primaryColor;
  final ValueChanged<String> onSelected;

  const _ProductSubcategoryMenu({
    required this.subcategories,
    required this.selectedSubcategoryId,
    required this.primaryColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: subcategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final _StoreProductCategoryData category = subcategories[index];
          final bool selected = selectedSubcategoryId == category.id;

          return GestureDetector(
            onTap: () => onSelected(category.id),
            child: SizedBox(
              width: 68,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    scale: selected ? 1.02 : 1,
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: Center(
                        child: category.primaryIconUrl.isNotEmpty
                            ? Image.network(
                                category.primaryIconUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    _SubcategoryIconFallback(
                                  primaryColor: primaryColor,
                                  category: category,
                                  selected: selected,
                                ),
                              )
                            : _SubcategoryIconFallback(
                                primaryColor: primaryColor,
                                category: category,
                                selected: selected,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: textRegular.copyWith(
                      color: selected ? primaryColor : Colors.black87,
                      fontSize: 10.2,
                      height: 1.02,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: selected ? 18 : 0,
                    height: 2.4,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
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

class _SubcategoryIconFallback extends StatelessWidget {
  final Color primaryColor;
  final _StoreProductCategoryData category;
  final bool selected;

  const _SubcategoryIconFallback({
    required this.primaryColor,
    required this.category,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      category.fallbackIcon,
      color: selected ? primaryColor : Colors.grey.shade700,
      size: 29,
    );
  }
}

class _ProductFilterChips extends StatelessWidget {
  final String selectedFilter;
  final Color primaryColor;
  final ValueChanged<String> onSelected;

  const _ProductFilterChips({
    required this.selectedFilter,
    required this.primaryColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final List<_ProductFilterData> filters = <_ProductFilterData>[
      _ProductFilterData('all', 'Todos', Icons.apps_rounded),
      _ProductFilterData('discount', 'Com desconto', Icons.local_offer_rounded),
      _ProductFilterData(
          'lowest_price', 'Menor preço', Icons.trending_down_rounded),
      _ProductFilterData('newest', 'Mais recentes', Icons.new_releases_rounded),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final _ProductFilterData filter = filters[index];
          final bool selected = selectedFilter == filter.key;

          return GestureDetector(
            onTap: () => onSelected(filter.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: selected ? primaryColor : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? primaryColor : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    filter.icon,
                    color: selected ? Colors.white : Colors.grey.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filter.label,
                    style: textBold.copyWith(
                      color: selected ? Colors.white : Colors.black87,
                      fontSize: 12.2,
                    ),
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

class _ActiveSearchChip extends StatelessWidget {
  final String query;
  final Color primaryColor;
  final VoidCallback onClear;

  const _ActiveSearchChip({
    required this.query,
    required this.primaryColor,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Busca: $query',
            style: textMedium.copyWith(
              color: primaryColor,
              fontSize: 12.2,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close_rounded, color: primaryColor, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ProductCategoryBannerCarousel extends StatelessWidget {
  final List<_StoreCategoryBannerData> banners;

  const _ProductCategoryBannerCarousel({
    required this.banners,
  });

  @override
  Widget build(BuildContext context) {
    if (banners.length == 1) {
      return _ProductCategoryBannerImage(banner: banners.first);
    }

    return SizedBox(
      height: 142,
      child: PageView.builder(
        itemCount: banners.length,
        controller: PageController(viewportFraction: 0.94),
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              right: index == banners.length - 1 ? 0 : 10,
            ),
            child: _ProductCategoryBannerImage(banner: banners[index]),
          );
        },
      ),
    );
  }
}

class _ProductCategoryBannerImage extends StatelessWidget {
  final _StoreCategoryBannerData banner;

  const _ProductCategoryBannerImage({
    required this.banner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 142,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.grey.shade100,
      ),
      child: Image.network(
        banner.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade100,
          alignment: Alignment.center,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}

class _ProductCategoryBannerSkeleton extends StatelessWidget {
  final Color primaryColor;

  const _ProductCategoryBannerSkeleton({
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 142,
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}

class _ProductCategoryProductCard extends StatelessWidget {
  final _StoreProductItemData product;
  final Color primaryColor;
  final VoidCallback onTap;

  const _ProductCategoryProductCard({
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
                    child: _ProductCardHeroImage(
                      imageUrl: product.mainImageUrl,
                      primaryColor: primaryColor,
                    ),
                  ),
                  if (product.hasPromotion)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: _ProductDiscountBadge(
                        discountLabel: product.discountLabel,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 32,
                      width: double.infinity,
                      child: Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: textBold.copyWith(
                          color: textColor,
                          fontSize: 13,
                          height: 1.10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    _ProductPriceColumn(
                      product: product,
                      primaryColor: primaryColor,
                    ),
                    if (!product.isClassified) ...[
                      const SizedBox(height: 5),
                      _ProductDeliveryInfo(
                        product: product,
                        primaryColor: primaryColor,
                      ),
                    ] else ...[
                      const SizedBox(height: 5),
                      _ClassifiedListingInfo(
                        product: product,
                        primaryColor: primaryColor,
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              _ProductBottomActionStrip(
                primaryColor: primaryColor,
                label: product.isClassified ? 'Ver anúncio' : 'Ver produto',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCardHeroImage extends StatelessWidget {
  final String imageUrl;
  final Color primaryColor;

  const _ProductCardHeroImage({
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

class _ProductDiscountBadge extends StatelessWidget {
  final String discountLabel;

  const _ProductDiscountBadge({
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

class _ProductPriceColumn extends StatelessWidget {
  final _StoreProductItemData product;
  final Color primaryColor;

  const _ProductPriceColumn({
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

class _ProductDeliveryInfo extends StatelessWidget {
  final _StoreProductItemData product;
  final Color primaryColor;

  const _ProductDeliveryInfo({
    required this.product,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Entrega',
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          style: textMedium.copyWith(
            color: Colors.grey.shade600,
            fontSize: 10.8,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Retire grátis ou receba em casa',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: textBold.copyWith(
                color: primaryColor,
                fontSize: 12.0,
                height: 1.05,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClassifiedListingInfo extends StatelessWidget {
  final _StoreProductItemData product;
  final Color primaryColor;

  const _ClassifiedListingInfo({
    required this.product,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final String location = product.locationLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.isVehicle ? 'Anúncio verificado' : 'Imóvel verificado',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textBold.copyWith(
            color: primaryColor,
            fontSize: 11.2,
            height: 1.05,
          ),
        ),
        if (location.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textMedium.copyWith(
              color: Colors.grey.shade600,
              fontSize: 10.8,
              height: 1.05,
            ),
          ),
        ],
      ],
    );
  }
}

class _ProductBottomActionStrip extends StatelessWidget {
  final Color primaryColor;
  final String label;

  const _ProductBottomActionStrip({
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

class _ProductGridLoading extends StatelessWidget {
  final Color primaryColor;

  const _ProductGridLoading({
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        0,
        Dimensions.paddingSizeDefault,
        150,
      ),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          mainAxisExtent: 348,
        ),
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyProductCategory extends StatelessWidget {
  final Color primaryColor;
  final String title;
  final String description;

  const _EmptyProductCategory({
    required this.primaryColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 150),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, color: primaryColor, size: 46),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textBold.copyWith(fontSize: 18, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 13.2,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFilterData {
  final String key;
  final String label;
  final IconData icon;

  const _ProductFilterData(this.key, this.label, this.icon);
}

class _StoreCategoryBannerData {
  final String imageUrl;

  _StoreCategoryBannerData({
    required this.imageUrl,
  });

  factory _StoreCategoryBannerData.fromMap(Map<String, dynamic> map) {
    return _StoreCategoryBannerData(
      imageUrl: _normalizeMediaUrl(
        map['image_url'] ??
            map['imageUrl'] ??
            map['image_full_url'] ??
            map['imageFullUrl'] ??
            map['image'] ??
            '',
      ),
    );
  }
}

class _StoreProductCategoryData {
  final String id;
  final String parentId;
  final String name;
  final String slug;
  final String imageUrl;
  final String iconUrl;
  final List<_StoreProductCategoryData> subcategories;

  _StoreProductCategoryData({
    required this.id,
    required this.parentId,
    required this.name,
    required this.slug,
    required this.imageUrl,
    this.iconUrl = '',
    this.subcategories = const <_StoreProductCategoryData>[],
  });

  factory _StoreProductCategoryData.all({
    String imageUrl = '',
    String iconUrl = '',
  }) {
    final String normalizedImageUrl = _normalizeMediaUrl(imageUrl);
    final String normalizedIconUrl = _normalizeMediaUrl(iconUrl);

    return _StoreProductCategoryData(
      id: '',
      parentId: '',
      name: 'Todos',
      slug: 'todos',
      imageUrl: normalizedImageUrl,
      iconUrl:
          normalizedIconUrl.isNotEmpty ? normalizedIconUrl : normalizedImageUrl,
    );
  }

  factory _StoreProductCategoryData.fromMap(Map<String, dynamic> map) {
    final dynamic subcategoriesValue = map['subcategories'];
    final List<dynamic> subcategoryList =
        subcategoriesValue is List ? subcategoriesValue : <dynamic>[];

    final String imageUrl = _normalizeMediaUrl(
      map['image_url'] ??
          map['imageUrl'] ??
          map['image_full_url'] ??
          map['imageFullUrl'] ??
          map['image_path'] ??
          map['imagePath'] ??
          map['image'] ??
          '',
    );
    final String iconUrl = _normalizeMediaUrl(
      map['icon_url'] ??
          map['iconUrl'] ??
          map['icon_image_url'] ??
          map['iconImageUrl'] ??
          map['icon_path'] ??
          map['iconPath'] ??
          map['icon'] ??
          imageUrl,
    );

    return _StoreProductCategoryData(
      id: '${map['id'] ?? ''}',
      parentId: '${map['parent_id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      slug: '${map['slug'] ?? ''}',
      imageUrl: imageUrl,
      iconUrl: iconUrl,
      subcategories: subcategoryList
          .whereType<Map>()
          .map((item) => _StoreProductCategoryData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((subcategory) => subcategory.id.isNotEmpty)
          .toList(),
    );
  }

  bool get isAll => id.isEmpty;

  String get deduplicationKey {
    final String normalizedId = id.trim().toLowerCase();

    if (normalizedId.isNotEmpty) {
      return normalizedId;
    }

    final String normalizedSlug = slug.trim().toLowerCase();

    if (normalizedSlug.isNotEmpty) {
      return normalizedSlug;
    }

    return normalizedIdentifier;
  }

  String get primaryIconUrl {
    if (iconUrl.trim().isNotEmpty) {
      return iconUrl.trim();
    }

    return imageUrl.trim();
  }

  bool get representsAllCategory {
    final String normalizedName = name.trim().toLowerCase();
    final String normalizedSlug = slug.trim().toLowerCase();

    return id.isEmpty ||
        normalizedName == 'todos' ||
        normalizedName == 'all' ||
        normalizedSlug == 'todos' ||
        normalizedSlug == 'all';
  }

  String? get localIconAsset {
    final String normalized = normalizedIdentifier;

    if (isAll || normalized.contains('todos') || normalized.contains('all')) {
      return 'assets/image/store.png';
    }

    if (normalized.contains('beleza') ||
        normalized.contains('perfume') ||
        normalized.contains('cosmetico')) {
      return 'assets/image/beauty.png';
    }

    if (normalized.contains('servico') || normalized.contains('service')) {
      return 'assets/image/services.png';
    }

    if (normalized.contains('imovel') || normalized.contains('imoveis')) {
      return 'assets/image/imóveis.png';
    }

    if (normalized.contains('veiculo') ||
        normalized.contains('veiculos') ||
        normalized.contains('auto') ||
        normalized.contains('carro') ||
        normalized.contains('moto')) {
      return 'assets/image/viagens.png';
    }

    return null;
  }

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

  IconData get fallbackIcon {
    final String normalized = normalizedIdentifier;

    if (isAll || normalized.contains('todos') || normalized.contains('all')) {
      return Icons.apps_rounded;
    }

    if (normalized.contains('beleza') ||
        normalized.contains('perfume') ||
        normalized.contains('cosmetico')) {
      return Icons.spa_rounded;
    }

    if (normalized.contains('servico')) {
      return Icons.handyman_rounded;
    }

    if (normalized.contains('imovel')) {
      return Icons.apartment_rounded;
    }

    if (normalized.contains('veiculo') ||
        normalized.contains('carro') ||
        normalized.contains('moto')) {
      return Icons.directions_car_rounded;
    }

    return Icons.category_rounded;
  }
}

class _StoreProductItemData {
  final String id;
  final String title;
  final String shortDescription;
  final double price;
  final double regularPrice;
  final double promotionalPrice;
  final double finalPrice;
  final bool hasPromotion;
  final String categoryId;
  final String category;
  final String productType;
  final String mainImageUrl;
  final String storeName;
  final bool allowPickup;
  final bool allowLokallyShipping;
  final bool allowNationalShipping;
  final DateTime updatedAt;
  final Map<String, dynamic> rawMap;

  _StoreProductItemData({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.price,
    required this.regularPrice,
    required this.promotionalPrice,
    required this.finalPrice,
    required this.hasPromotion,
    required this.categoryId,
    required this.category,
    required this.productType,
    required this.mainImageUrl,
    required this.storeName,
    required this.allowPickup,
    required this.allowLokallyShipping,
    required this.allowNationalShipping,
    required this.updatedAt,
    required this.rawMap,
  });

  factory _StoreProductItemData.fromMap(
    Map<String, dynamic> map, {
    String fallbackProductType = 'physical',
  }) {
    final double price = _parseDouble(map['price']);
    final double regularPrice = _parseDouble(
      map['regular_price'] ?? map['old_price'] ?? map['oldPrice'] ?? price,
    );
    final double promotionalPrice = _parseDouble(
      map['promotional_price'] ?? map['discount_price'] ?? map['discountPrice'],
    );
    final double finalPrice = _parseDouble(
      map['final_price'] ??
          map['current_price'] ??
          (promotionalPrice > 0 ? promotionalPrice : price),
    );

    return _StoreProductItemData(
      id: '${map['id'] ?? ''}',
      title:
          '${map['title'] ?? map['name'] ?? map['model_name'] ?? map['modelName'] ?? ''}',
      shortDescription:
          '${map['short_description'] ?? map['shortDescription'] ?? ''}',
      price: price,
      regularPrice: regularPrice > 0 ? regularPrice : price,
      promotionalPrice: promotionalPrice,
      finalPrice: finalPrice > 0 ? finalPrice : price,
      hasPromotion: map['has_promotion'] == true ||
          map['hasPromotion'] == true ||
          (regularPrice > 0 && finalPrice > 0 && finalPrice < regularPrice) ||
          (promotionalPrice > 0 && promotionalPrice < price),
      categoryId:
          '${map['category_id'] ?? map['categoryId'] ?? map['vehicle_type_id'] ?? map['vehicleTypeId'] ?? ''}',
      category:
          '${map['category_name'] ?? map['category'] ?? map['vehicle_type'] ?? map['property_type'] ?? ''}',
      productType:
          '${map['product_type'] ?? map['productType'] ?? map['item_type'] ?? fallbackProductType}'
              .toLowerCase(),
      mainImageUrl: _normalizeMediaUrl(
        map['main_image_url'] ??
            map['mainImageUrl'] ??
            map['image_url'] ??
            map['imageUrl'] ??
            map['thumbnail'] ??
            map['main_image'] ??
            map['cover_image_url'] ??
            map['coverImageUrl'] ??
            map['photo_url'] ??
            map['photoUrl'] ??
            _firstImageFromGallery(map) ??
            '',
      ),
      storeName:
          '${map['store_name'] ?? map['storeName'] ?? map['seller_name'] ?? map['sellerName'] ?? ''}',
      allowPickup: map['allow_pickup'] == true ||
          map['allow_pickup'] == 1 ||
          map['allowPickup'] == true,
      allowLokallyShipping: map['allow_lokally_shipping'] == true ||
          map['allow_lokally_shipping'] == 1 ||
          map['allowLokallyShipping'] == true,
      allowNationalShipping: map['allow_national_shipping'] == true ||
          map['allow_national_shipping'] == 1 ||
          map['allowNationalShipping'] == true,
      updatedAt: DateTime.tryParse('${map['updated_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      rawMap: Map<String, dynamic>.from(map),
    );
  }

  bool get isPhysical {
    return productType == 'physical' ||
        productType == 'product' ||
        productType.isEmpty;
  }

  bool get isVehicle {
    return productType == 'vehicle' ||
        productType == 'vehicles' ||
        productType == 'vehicle_ad';
  }

  bool get isRealEstate {
    return productType == 'real_estate' ||
        productType == 'real-estate' ||
        productType == 'property' ||
        productType == 'real_estate_ad';
  }

  bool get isClassified => isVehicle || isRealEstate;

  String get locationLabel {
    final String city = '${rawMap['city'] ?? ''}'.trim();
    final String state = '${rawMap['state'] ?? ''}'.trim();
    final String neighborhood = '${rawMap['neighborhood'] ?? ''}'.trim();

    final List<String> parts = <String>[
      if (neighborhood.isNotEmpty && neighborhood != 'null') neighborhood,
      if (city.isNotEmpty && city != 'null') city,
      if (state.isNotEmpty && state != 'null') state,
    ];

    return parts.join(' • ');
  }

  double get discountPercent {
    if (!hasPromotion || regularPrice <= 0 || finalPrice <= 0) {
      return 0;
    }

    if (finalPrice >= regularPrice) {
      return 0;
    }

    return ((regularPrice - finalPrice) / regularPrice) * 100;
  }

  String get formattedPrice {
    return formatCurrency(price > 0 ? price : regularPrice);
  }

  String get formattedFinalPrice {
    return formatCurrency(finalPrice > 0 ? finalPrice : price);
  }

  String get discountLabel {
    final double percent = discountPercent;

    if (percent <= 0) {
      return '';
    }

    return '-${percent.toStringAsFixed(0)}%';
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = Map<String, dynamic>.from(rawMap);

    map['id'] = id;
    map['title'] = title;
    map['name'] = title;
    map['short_description'] = shortDescription;
    map['price'] = price;
    map['regular_price'] = regularPrice;
    map['promotional_price'] = promotionalPrice;
    map['final_price'] = finalPrice;
    map['has_promotion'] = hasPromotion;
    map['category_id'] = categoryId;
    map['category_name'] = category;
    map['product_type'] = productType;
    map['item_type'] = productType;
    map['main_image_url'] = mainImageUrl;
    map['image_url'] = mainImageUrl;
    map['store_name'] = storeName;
    map['allow_pickup'] = allowPickup;
    map['allow_lokally_shipping'] = allowLokallyShipping;
    map['allow_national_shipping'] = allowNationalShipping;

    return map;
  }

  String formatCurrency(double value) {
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

String _normalizeMarketplaceText(String value) {
  return value
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
      .replaceAll('ú', 'u')
      .replaceAll('-', ' ')
      .replaceAll('_', ' ');
}

dynamic _firstImageFromGallery(Map<String, dynamic> map) {
  final dynamic gallery = map['gallery_images'] ??
      map['galleryImages'] ??
      map['images'] ??
      map['photos'];

  if (gallery is List && gallery.isNotEmpty) {
    final dynamic first = gallery.first;

    if (first is Map) {
      return first['image_url'] ??
          first['imageUrl'] ??
          first['url'] ??
          first['path'] ??
          first['image'];
    }

    return first;
  }

  return null;
}

double _parseDouble(dynamic value) {
  if (value == null) {
    return 0;
  }

  if (value is num) {
    return value.toDouble();
  }

  final String stringValue = value.toString().trim();

  if (stringValue.isEmpty || stringValue == 'null') {
    return 0;
  }

  String normalized = stringValue
      .replaceAll('R\$', '')
      .replaceAll(' ', '')
      .replaceAll(RegExp(r'[^0-9,\.\-]'), '');

  if (normalized.isEmpty || normalized == '-' || normalized == 'null') {
    return 0;
  }

  final bool hasComma = normalized.contains(',');
  final bool hasDot = normalized.contains('.');

  if (hasComma && hasDot) {
    final int lastCommaIndex = normalized.lastIndexOf(',');
    final int lastDotIndex = normalized.lastIndexOf('.');

    if (lastCommaIndex > lastDotIndex) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else {
      normalized = normalized.replaceAll(',', '');
    }
  } else if (hasComma) {
    final int lastCommaIndex = normalized.lastIndexOf(',');
    final int digitsAfterComma = normalized.length - lastCommaIndex - 1;

    if (digitsAfterComma == 2) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else {
      normalized = normalized.replaceAll(',', '');
    }
  } else if (hasDot) {
    final int dotCount = '.'.allMatches(normalized).length;
    final int lastDotIndex = normalized.lastIndexOf('.');
    final int digitsAfterDot = normalized.length - lastDotIndex - 1;

    if (dotCount > 1 || digitsAfterDot == 3) {
      normalized = normalized.replaceAll('.', '');
    }
  }

  return double.tryParse(normalized) ?? 0;
}

String _normalizeMediaUrl(dynamic value) {
  final String rawValue = '${value ?? ''}'.trim();

  if (rawValue.isEmpty || rawValue == 'null') {
    return '';
  }

  if (rawValue.startsWith('http://') || rawValue.startsWith('https://')) {
    return rawValue;
  }

  String path = rawValue.replaceAll('\\', '/');

  while (path.startsWith('/')) {
    path = path.substring(1);
  }

  if (path.isEmpty || path == 'null') {
    return '';
  }

  if (path.startsWith('storage/')) {
    return 'https://admlokally.online/$path';
  }

  if (path.startsWith('public/')) {
    path = path.substring(7);
  }

  return 'https://admlokally.online/storage/$path';
}
