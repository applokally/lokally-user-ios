import 'dart:async';

import 'package:flutter/material.dart';
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

  static const String publicCategoriesUri = '/api/store/public-categories';
  static const String publicProductsUri = '/api/store/products';

  int selectedMainCategoryIndex = 0;
  String selectedSubcategoryId = '';
  String searchQuery = '';

  bool isCheckingSellerStatus = false;
  bool isApprovedSeller = false;
  bool isLoadingPublicStore = false;
  bool hasLoadedPublicStore = false;

  final ScrollController welcomeCarouselController = ScrollController();
  Timer? welcomeCarouselTimer;

  List<StoreCategoryData> mainCategories = <StoreCategoryData>[
    StoreCategoryData.all(),
  ];

  List<StoreProductData> products = <StoreProductData>[];

  @override
  void initState() {
    super.initState();
    startWelcomeCarousel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadPublicStore();
      checkSellerStatusOnOpen();
    });
  }

  @override
  void dispose() {
    welcomeCarouselTimer?.cancel();
    welcomeCarouselController.dispose();
    super.dispose();
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

  Future<void> loadPublicStore() async {
    await loadPublicCategories();
    await loadPublicProducts();
  }

  Future<void> loadPublicCategories() async {
    try {
      final Response response =
          await Get.find<ApiClient>().getData(publicCategoriesUri);

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
          return category.id.isNotEmpty && category.subcategories.isNotEmpty;
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
        publicProductsUri,
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

  Future<void> checkSellerStatusOnOpen() async {
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
      return subcategoryIds.contains(product.categoryId);
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

    final Uri url = Uri.parse(
      'https://wa.me/5535991284648?text=$message',
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
  }

  void handleSubcategorySelected(String subcategoryId) {
    setState(() {
      selectedSubcategoryId = subcategoryId;
      searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final List<StoreProductData> welcomeProductsForView = welcomeProducts;
    final List<StoreProductData> productsForView = visibleProducts;
    final StoreProductData? bannerProduct = welcomeProductsForView.isNotEmpty
        ? welcomeProductsForView.first
        : productsForView.isNotEmpty
            ? productsForView.first
            : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              StoreMarketplaceHeader(
                primaryColor: primaryColor,
                onSearchChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                onCartTap: openCartScreen,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: primaryColor,
                  onRefresh: loadPublicStore,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      Dimensions.paddingSizeDefault,
                      14,
                      Dimensions.paddingSizeDefault,
                      150,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        StoreBanner(
                          imageUrl: bannerProduct?.mainImageUrl ?? '',
                          onTap: bannerProduct != null
                              ? () => handleProductTap(bannerProduct)
                              : handleSimpleTap,
                        ),
                        const SizedBox(height: 18),
                        if (isLoadingPublicStore && !hasLoadedPublicStore) ...[
                          StorePublicLoadingBlock(primaryColor: primaryColor),
                        ] else if (productsForView.isEmpty) ...[
                          StoreEmptyPublicProducts(primaryColor: primaryColor),
                        ] else ...[
                          if (welcomeProductsForView.isNotEmpty) ...[
                            StoreSectionHeader(
                              title: 'Ofertas de boas-vindas',
                              badge: 'Selecionados',
                              primaryColor: primaryColor,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 432,
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
                              mainAxisExtent: 432,
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
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 92,
            child: StoreFloatingSellButton(
              primaryColor: primaryColor,
              isLoading: isCheckingSellerStatus,
              isApprovedSeller: isApprovedSeller,
              onTap: handleSellButtonTap,
            ),
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
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return StoreCategoryTextItem(
            label: categories[index].name,
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
    final List<StoreCategoryData> items = <StoreCategoryData>[
      StoreCategoryData.allSubcategory(),
      ...subcategories,
    ];

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final StoreCategoryData item = items[index];
          final bool selected = item.id.isEmpty
              ? selectedSubcategoryId.isEmpty
              : selectedSubcategoryId == item.id;

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
                      fontSize: 12.3,
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
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreCategoryTextItem({
    super.key,
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (isSelected ? textBold : textMedium).copyWith(
              color: isSelected ? primaryColor : Colors.grey.shade700,
              fontSize: isSelected ? 15 : 14,
            ),
          ),
        ),
      ),
    );
  }
}

class StoreBanner extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onTap;

  const StoreBanner({
    super.key,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                  errorBuilder: (_, __, ___) {
                    return Image.asset(
                      'assets/image/produto.webp',
                      fit: BoxFit.cover,
                    );
                  },
                )
              : Image.asset(
                  'assets/image/produto.webp',
                  fit: BoxFit.cover,
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
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 6),
              blurRadius: 16,
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 176,
                    width: double.infinity,
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
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 35,
                        child: Text(
                          product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textBold.copyWith(
                            color: textColor,
                            fontSize: 14.2,
                            height: 1.13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Vendido por: ${product.storeName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textRegular.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 11.4,
                        ),
                      ),
                      const SizedBox(height: 7),
                      ProductPriceColumn(
                        product: product,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 8),
                      StoreDeliveryInfo(
                        availabilityLabel: product.availabilityLabel,
                        primaryColor: primaryColor,
                      ),
                      const Spacer(),
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
        color: primaryColor.withValues(alpha: 0.08),
        child: Center(
          child: Image.asset(
            'assets/image/produto.webp',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
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
          color: primaryColor.withValues(alpha: 0.08),
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
                fontSize: 16,
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
        product.formattedFinalPrice,
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
      product.formattedFinalPrice,
      maxLines: 1,
      style: textBold.copyWith(
        color: primaryColor,
        fontSize: 12.5,
      ),
    );
  }
}

class StoreDeliveryInfo extends StatelessWidget {
  final String availabilityLabel;
  final Color primaryColor;

  const StoreDeliveryInfo({
    super.key,
    required this.availabilityLabel,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Opções de entrega',
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 11.4,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'RETIRE GRÁTIS HOJE',
          style: textBold.copyWith(
            color: primaryColor,
            fontSize: 10.8,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 5),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Lokally Envios',
                style: textBold.copyWith(
                  color: primaryColor,
                  fontSize: 10.4,
                  height: 1.12,
                ),
              ),
              TextSpan(
                text: ' em até 24h receba em sua casa, à partir de R\$8,50',
                style: textMedium.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 10.4,
                  height: 1.12,
                ),
              ),
            ],
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
      height: 40,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
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
            fontSize: 12.3,
            letterSpacing: 0.2,
          ),
        ),
      ),
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
              fontSize: 16,
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

class StoreCategoryData {
  final String id;
  final String parentId;
  final String name;
  final String slug;
  final String imageUrl;
  final List<StoreCategoryData> subcategories;

  StoreCategoryData({
    required this.id,
    required this.parentId,
    required this.name,
    required this.slug,
    required this.imageUrl,
    this.subcategories = const <StoreCategoryData>[],
  });

  factory StoreCategoryData.all() {
    return StoreCategoryData(
      id: '',
      parentId: '',
      name: 'Todos',
      slug: 'all',
      imageUrl: '',
    );
  }

  factory StoreCategoryData.allSubcategory() {
    return StoreCategoryData(
      id: '',
      parentId: '',
      name: 'Todas',
      slug: 'all_subcategories',
      imageUrl: '',
    );
  }

  factory StoreCategoryData.fromMap(Map<String, dynamic> map) {
    final dynamic subcategoriesValue = map['subcategories'];
    final List<dynamic> subcategoryList =
        subcategoriesValue is List ? subcategoriesValue : <dynamic>[];

    return StoreCategoryData(
      id: '${map['id'] ?? ''}',
      parentId: '${map['parent_id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      slug: '${map['slug'] ?? ''}',
      imageUrl: '${map['image_url'] ?? ''}',
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
  });

  factory StoreProductData.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> store = map['store'] is Map
        ? Map<String, dynamic>.from(map['store'])
        : <String, dynamic>{};

    final double price = parseDouble(map['price']);
    final double promotionalPrice = parseDouble(map['promotional_price']);
    final double finalPrice = parseDouble(map['final_price']);
    final bool hasPromotion = map['has_promotion'] == true &&
        promotionalPrice > 0 &&
        promotionalPrice < price;

    return StoreProductData(
      id: '${map['id'] ?? ''}',
      sellerId: '${map['seller_id'] ?? ''}',
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
      mainImageUrl: '${map['main_image_url'] ?? ''}',
      storeName: '${store['name'] ?? ''}',
      storeLogoUrl: '${store['logo_url'] ?? ''}',
      storeCoverImageUrl: '${store['cover_image_url'] ?? ''}',
      availabilityType: '${map['availability_type'] ?? 'immediate'}',
      availabilityLabel: '${map['availability_label'] ?? 'Imediata'}',
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

  String get actionLabel {
    return 'Ver oferta';
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
