import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_cart_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/categories/store_product_category_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_home_screen.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_marketplace_header.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StorePhysicalProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> initialProduct;

  const StorePhysicalProductDetailsScreen({
    super.key,
    required this.initialProduct,
  });

  @override
  State<StorePhysicalProductDetailsScreen> createState() =>
      _StorePhysicalProductDetailsScreenState();
}

class _StorePhysicalProductDetailsScreenState
    extends State<StorePhysicalProductDetailsScreen> {
  StorePhysicalProductDetailsData? product;
  List<StorePhysicalProductDetailsData> relatedProducts =
      <StorePhysicalProductDetailsData>[];
  List<StorePhysicalProductReviewData> reviews =
      <StorePhysicalProductReviewData>[];
  List<StorePhysicalProductCategoryData> mainCategories =
      <StorePhysicalProductCategoryData>[
    StorePhysicalProductCategoryData.all()
  ];

  final ScrollController scrollController = ScrollController();
  final ScrollController relatedController = ScrollController();

  bool isLoading = true;
  bool isLoadingHeaderCategories = false;
  int selectedMainCategoryIndex = 0;
  int quantity = 1;
  int selectedImageIndex = 0;
  Timer? relatedTimer;

  @override
  void initState() {
    super.initState();

    product = StorePhysicalProductDetailsData.fromMap(widget.initialProduct);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadMarketplaceHeaderData();
      loadProductDetails();
    });
  }

  @override
  void dispose() {
    relatedTimer?.cancel();
    relatedController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  StorePhysicalProductCategoryData get selectedMainCategory {
    if (mainCategories.isEmpty ||
        selectedMainCategoryIndex < 0 ||
        selectedMainCategoryIndex >= mainCategories.length) {
      return StorePhysicalProductCategoryData.all();
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

  Future<void> loadMarketplaceHeaderData() async {
    if (isLoadingHeaderCategories) {
      return;
    }

    setState(() {
      isLoadingHeaderCategories = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().getData(
        '/api/store/public-categories',
      );

      if (!mounted) {
        return;
      }

      final dynamic responseBody = response.body;

      if (response.statusCode != 200 ||
          responseBody is! Map ||
          responseBody['status'] != true) {
        setState(() {
          isLoadingHeaderCategories = false;
        });
        return;
      }

      final dynamic dataValue = responseBody['data'];
      final List<dynamic> data = dataValue is List ? dataValue : <dynamic>[];
      final List<StorePhysicalProductCategoryData> apiCategories = data
          .whereType<Map>()
          .map((item) => StorePhysicalProductCategoryData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((category) => category.id.isNotEmpty)
          .toList();

      StorePhysicalProductCategoryData? admAllCategory;
      final List<StorePhysicalProductCategoryData> regularCategories =
          <StorePhysicalProductCategoryData>[];
      final Set<String> addedCategoryKeys = <String>{};

      for (final StorePhysicalProductCategoryData category in apiCategories) {
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

      final List<StorePhysicalProductCategoryData> loadedCategories =
          <StorePhysicalProductCategoryData>[
        StorePhysicalProductCategoryData.all(
          imageUrl: admAllCategory?.primaryIconUrl ?? '',
          iconUrl: admAllCategory?.primaryIconUrl ?? '',
        ),
        ...regularCategories,
      ];

      final int resolvedIndex = resolveSelectedMainCategoryIndex(
        loadedCategories,
      );

      setState(() {
        mainCategories = loadedCategories;
        selectedMainCategoryIndex = resolvedIndex;
        isLoadingHeaderCategories = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingHeaderCategories = false;
      });
    }
  }

  int resolveSelectedMainCategoryIndex(
    List<StorePhysicalProductCategoryData> loadedCategories,
  ) {
    final StorePhysicalProductDetailsData? currentProduct = product;

    if (currentProduct == null) {
      return 0;
    }

    final String productCategoryId = currentProduct.categoryId.trim();
    final String productCategoryName =
        currentProduct.category.trim().toLowerCase();

    if (productCategoryId.isNotEmpty) {
      final int byId = loadedCategories.indexWhere(
        (category) =>
            category.id == productCategoryId ||
            category.subcategories
                .any((subcategory) => subcategory.id == productCategoryId),
      );

      if (byId >= 0) {
        return byId;
      }
    }

    if (productCategoryName.isNotEmpty) {
      final int byName = loadedCategories.indexWhere(
        (category) =>
            category.name.toLowerCase() == productCategoryName ||
            category.subcategories.any(
              (subcategory) =>
                  subcategory.name.toLowerCase() == productCategoryName,
            ),
      );

      if (byName >= 0) {
        return byName;
      }
    }

    return 0;
  }

  void handleMainCategorySelected(int index) {
    if (index < 0 || index >= mainCategories.length) {
      return;
    }

    final StorePhysicalProductCategoryData category = mainCategories[index];

    setState(() {
      selectedMainCategoryIndex = index;
    });

    if (category.isAll) {
      Get.off(() => const StoreHomeScreen());
      return;
    }

    Get.to(
      () => StoreProductCategoryScreen(
        initialCategoryId: category.id,
        initialCategoryName: category.name,
        initialCategorySlug: category.slug,
      ),
    );
  }

  Future<void> loadProductDetails() async {
    final StorePhysicalProductDetailsData? currentProduct = product;

    if (currentProduct == null || currentProduct.id.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final Response response = await Get.find<ApiClient>().getData(
        '/api/store/products/${currentProduct.id}',
      );

      if (!mounted) {
        return;
      }

      final dynamic responseBody = response.body;

      if (response.statusCode != 200 ||
          responseBody is! Map ||
          responseBody['status'] != true) {
        setState(() {
          isLoading = false;
        });
        showMessage('Não foi possível carregar os detalhes do produto.');
        return;
      }

      final dynamic dataValue = responseBody['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic productValue = data['product'];
      final Map<String, dynamic> productMap = productValue is Map
          ? Map<String, dynamic>.from(productValue)
          : widget.initialProduct;

      final dynamic relatedValue = data['related_products'];
      final List<dynamic> relatedList =
          relatedValue is List ? relatedValue : <dynamic>[];

      final dynamic reviewsValue = data['reviews'];
      final List<dynamic> reviewList =
          reviewsValue is List ? reviewsValue : <dynamic>[];

      setState(() {
        product = StorePhysicalProductDetailsData.fromMap(productMap);
        relatedProducts = relatedList
            .whereType<Map>()
            .map((item) => StorePhysicalProductDetailsData.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .where((item) => item.id.isNotEmpty && item.isPhysicalProduct)
            .toList();
        reviews = reviewList
            .whereType<Map>()
            .map((item) => StorePhysicalProductReviewData.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList();
        quantity = 1;
        selectedImageIndex = 0;
        isLoading = false;
      });

      restartRelatedCarousel();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      showMessage('Não foi possível carregar os detalhes do produto.');
    }
  }

  void restartRelatedCarousel() {
    relatedTimer?.cancel();

    if (relatedProducts.length <= 2) {
      return;
    }

    relatedTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !relatedController.hasClients) {
        return;
      }

      final double maxScroll = relatedController.position.maxScrollExtent;
      final double currentScroll = relatedController.offset;
      final double nextScroll = currentScroll + 190;

      relatedController.animateTo(
        nextScroll >= maxScroll ? 0 : nextScroll,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOut,
      );
    });
  }

  void showMessage(String message) {
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

  void increaseQuantity() {
    final StorePhysicalProductDetailsData? currentProduct = product;

    if (currentProduct == null) {
      return;
    }

    if (currentProduct.stock > 0 && quantity >= currentProduct.stock) {
      showMessage('Quantidade máxima disponível em estoque.');
      return;
    }

    setState(() {
      quantity++;
    });
  }

  void decreaseQuantity() {
    if (quantity <= 1) {
      return;
    }

    setState(() {
      quantity--;
    });
  }

  void addToCart() {
    final StorePhysicalProductDetailsData? currentProduct = product;

    if (currentProduct == null) {
      return;
    }

    if (currentProduct.stock <= 0) {
      showMessage('Produto indisponível no momento.');
      return;
    }

    StoreCartSession.addProductMap(
      currentProduct.toCartMap(),
      quantity,
    );

    showMessage('${currentProduct.title} adicionado ao carrinho.');
    Get.to(() => const StoreCartScreen());
  }

  void openCartScreen() {
    Get.to(() => const StoreCartScreen());
  }

  void openRelatedProduct(StorePhysicalProductDetailsData item) {
    relatedTimer?.cancel();

    setState(() {
      product = item;
      relatedProducts = <StorePhysicalProductDetailsData>[];
      reviews = <StorePhysicalProductReviewData>[];
      quantity = 1;
      selectedImageIndex = 0;
      isLoading = true;
    });

    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    }

    loadProductDetails();
  }

  @override
  Widget build(BuildContext context) {
    final StorePhysicalProductDetailsData? currentProduct = product;
    final Color primaryColor = Theme.of(context).primaryColor;

    if (currentProduct == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Text(
              'Produto não encontrado.',
              style: textBold.copyWith(
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F6),
      body: Stack(
        children: [
          RefreshIndicator(
            color: primaryColor,
            onRefresh: loadProductDetails,
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 158),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PhysicalProductImageGallery(
                    product: currentProduct,
                    primaryColor: primaryColor,
                    selectedIndex: selectedImageIndex,
                    fullTop: true,
                    onBackTap: () => Get.back(),
                    onImageChanged: (index) {
                      setState(() {
                        selectedImageIndex = index;
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Dimensions.paddingSizeDefault,
                      16,
                      Dimensions.paddingSizeDefault,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PhysicalProductInfoSection(
                          product: currentProduct,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(height: 22),
                        PhysicalProductDeliverySection(
                          product: currentProduct,
                          primaryColor: primaryColor,
                        ),
                        const PhysicalProductSectionDivider(),
                        PhysicalProductSellerSection(
                          product: currentProduct,
                          primaryColor: primaryColor,
                        ),
                        const PhysicalProductSectionDivider(),
                        PhysicalProductGuaranteeSection(
                          primaryColor: primaryColor,
                        ),
                        const PhysicalProductSectionDivider(),
                        PhysicalProductDescriptionSection(
                          product: currentProduct,
                        ),
                        const PhysicalProductSectionDivider(),
                        PhysicalProductReviewsSection(
                          reviews: reviews,
                          primaryColor: primaryColor,
                        ),
                        if (relatedProducts.isNotEmpty) ...[
                          const PhysicalProductSectionDivider(),
                          PhysicalProductRelatedSection(
                            products: relatedProducts,
                            primaryColor: primaryColor,
                            controller: relatedController,
                            onProductTap: openRelatedProduct,
                          ),
                        ],
                        if (isLoading) ...[
                          const SizedBox(height: 20),
                          Center(
                            child: CircularProgressIndicator(
                              color: primaryColor,
                              strokeWidth: 2.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PhysicalProductBottomBar(
              product: currentProduct,
              primaryColor: primaryColor,
              quantity: quantity,
              onDecrease: decreaseQuantity,
              onIncrease: increaseQuantity,
              onAddToCart: addToCart,
            ),
          ),
        ],
      ),
    );
  }
}

class PhysicalProductBackBar extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onBackTap;

  const PhysicalProductBackBar({
    super.key,
    required this.primaryColor,
    required this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: GestureDetector(
        onTap: onBackTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_rounded,
              color: primaryColor,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              'Voltar para loja',
              style: textBold.copyWith(
                color: primaryColor,
                fontSize: 12.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PhysicalProductHeaderGradient extends StatelessWidget {
  final Color primaryColor;

  const PhysicalProductHeaderGradient({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primaryColor,
            Color.lerp(primaryColor, Colors.white, 0.18) ?? primaryColor,
            const Color(0xFFE9FAF6),
          ],
          stops: const [0.0, 0.62, 1.0],
        ),
      ),
    );
  }
}

class PhysicalProductMainCategoryMenu extends StatelessWidget {
  final List<StoreMarketplaceCategoryViewData> categories;
  final int selectedIndex;
  final Color primaryColor;
  final ValueChanged<int> onSelected;

  const PhysicalProductMainCategoryMenu({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.primaryColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor =
        Color.lerp(primaryColor, Colors.black, 0.34) ?? const Color(0xFF06433A);

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 20),
      itemBuilder: (context, index) {
        final StoreMarketplaceCategoryViewData category = categories[index];
        final bool selected = index == selectedIndex;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelected(index),
          child: SizedBox(
            width: 78,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color:
                        Colors.white.withValues(alpha: selected ? 0.72 : 0.36),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? primaryColor.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.34),
                      width: selected ? 1.4 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.16),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: PhysicalProductCategoryIcon(
                      category: category,
                      primaryColor: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: (selected ? textBold : textMedium).copyWith(
                    color: textColor,
                    fontSize: selected ? 12.1 : 11.8,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 28 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PhysicalProductCategoryIcon extends StatelessWidget {
  final StoreMarketplaceCategoryViewData category;
  final Color primaryColor;

  const PhysicalProductCategoryIcon({
    super.key,
    required this.category,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if ((category.localIconAsset ?? '').isNotEmpty) {
      return Image.asset(
        category.localIconAsset!,
        fit: BoxFit.contain,
      );
    }

    if (category.primaryIconUrl.trim().isNotEmpty) {
      return Image.network(
        category.primaryIconUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return Icon(
            fallbackIcon,
            color: primaryColor,
            size: 28,
          );
        },
      );
    }

    return Icon(
      fallbackIcon,
      color: primaryColor,
      size: 28,
    );
  }

  IconData get fallbackIcon {
    final String identifier = category.normalizedIdentifier.toLowerCase();

    if (category.isAll ||
        identifier.contains('home') ||
        identifier.contains('all')) {
      return Icons.storefront_rounded;
    }

    if (identifier.contains('beleza') || identifier.contains('cosmet')) {
      return Icons.spa_rounded;
    }

    if (identifier.contains('imove') || identifier.contains('real')) {
      return Icons.home_rounded;
    }

    if (identifier.contains('serv')) {
      return Icons.room_service_rounded;
    }

    if (identifier.contains('veicul') || identifier.contains('carro')) {
      return Icons.directions_car_rounded;
    }

    return Icons.category_rounded;
  }
}

class PhysicalProductSectionDivider extends StatelessWidget {
  const PhysicalProductSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Container(
        height: 1,
        width: double.infinity,
        color: Colors.black.withValues(alpha: 0.08),
      ),
    );
  }
}

class PhysicalProductImageGallery extends StatefulWidget {
  final StorePhysicalProductDetailsData product;
  final Color primaryColor;
  final int selectedIndex;
  final ValueChanged<int> onImageChanged;
  final bool fullTop;
  final VoidCallback? onBackTap;

  const PhysicalProductImageGallery({
    super.key,
    required this.product,
    required this.primaryColor,
    required this.selectedIndex,
    required this.onImageChanged,
    this.fullTop = false,
    this.onBackTap,
  });

  @override
  State<PhysicalProductImageGallery> createState() =>
      _PhysicalProductImageGalleryState();
}

class _PhysicalProductImageGalleryState
    extends State<PhysicalProductImageGallery> {
  late final PageController pageController;

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: widget.selectedIndex);
  }

  @override
  void didUpdateWidget(covariant PhysicalProductImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedIndex != widget.selectedIndex &&
        pageController.hasClients) {
      pageController.animateToPage(
        widget.selectedIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void goToImage(int index, int total) {
    if (total <= 0) {
      return;
    }

    final int safeIndex = index < 0
        ? 0
        : index >= total
            ? total - 1
            : index;

    if (pageController.hasClients) {
      pageController.animateToPage(
        safeIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }

    widget.onImageChanged(safeIndex);
  }

  Widget buildIndicators(List<String> images) {
    if (images.length <= 1) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(images.length, (index) {
        final bool active = index == widget.selectedIndex;

        return GestureDetector(
          onTap: () => goToImage(index, images.length),
          child: Container(
            width: active ? 20 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: active
                  ? widget.primaryColor
                  : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget buildBackButton(BuildContext context) {
    final VoidCallback? onBackTap = widget.onBackTap;

    if (onBackTap == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onBackTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.black87,
            size: 25,
          ),
        ),
      ),
    );
  }

  Widget buildImagePage(String imageUrl, BoxFit fit) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: imageUrl.isEmpty
          ? Icon(
              Icons.image_outlined,
              color: widget.primaryColor,
              size: 42,
            )
          : Image.network(
              imageUrl,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) {
                return Icon(
                  Icons.broken_image_outlined,
                  color: widget.primaryColor,
                  size: 42,
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = widget.product.galleryImages.isEmpty
        ? <String>[widget.product.mainImageUrl]
        : widget.product.galleryImages;
    final bool hasMultipleImages = images.length > 1;

    if (widget.fullTop) {
      final double topHeight = (MediaQuery.of(context).size.width * 0.82) +
          MediaQuery.of(context).padding.top;

      return SizedBox(
        height: topHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: pageController,
              itemCount: images.length,
              onPageChanged: widget.onImageChanged,
              itemBuilder: (context, index) {
                return buildImagePage(images[index], BoxFit.cover);
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.18),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.10),
                  ],
                  stops: const [0.0, 0.36, 1.0],
                ),
              ),
            ),
            if (hasMultipleImages) ...[
              PhysicalGalleryArrowButton(
                alignment: Alignment.centerLeft,
                icon: Icons.chevron_left_rounded,
                onTap: () => goToImage(widget.selectedIndex - 1, images.length),
              ),
              PhysicalGalleryArrowButton(
                alignment: Alignment.centerRight,
                icon: Icons.chevron_right_rounded,
                onTap: () => goToImage(widget.selectedIndex + 1, images.length),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 17,
                child: buildIndicators(images),
              ),
            ],
            buildBackButton(context),
          ],
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: pageController,
                  itemCount: images.length,
                  onPageChanged: widget.onImageChanged,
                  itemBuilder: (context, index) {
                    return buildImagePage(images[index], BoxFit.contain);
                  },
                ),
                if (hasMultipleImages) ...[
                  PhysicalGalleryArrowButton(
                    alignment: Alignment.centerLeft,
                    icon: Icons.chevron_left_rounded,
                    onTap: () =>
                        goToImage(widget.selectedIndex - 1, images.length),
                  ),
                  PhysicalGalleryArrowButton(
                    alignment: Alignment.centerRight,
                    icon: Icons.chevron_right_rounded,
                    onTap: () =>
                        goToImage(widget.selectedIndex + 1, images.length),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (hasMultipleImages) ...[
          const SizedBox(height: 10),
          buildIndicators(images),
        ],
      ],
    );
  }
}

class PhysicalGalleryArrowButton extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final VoidCallback onTap;

  const PhysicalGalleryArrowButton({
    super.key,
    required this.alignment,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 42,
          height: double.infinity,
          alignment: Alignment.center,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class PhysicalProductInfoSection extends StatelessWidget {
  final StorePhysicalProductDetailsData product;
  final Color primaryColor;

  const PhysicalProductInfoSection({
    super.key,
    required this.product,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.title,
          style: textBold.copyWith(
            color: textColor,
            fontSize: 22,
            height: 1.13,
          ),
        ),
        if (product.shortDescription.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            product.shortDescription,
            style: textRegular.copyWith(
              color: Colors.grey.shade700,
              fontSize: 13.2,
              height: 1.3,
            ),
          ),
        ],
        const SizedBox(height: 14),
        PhysicalProductPriceBlock(
          product: product,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            PhysicalProductInfoPill(
              icon: Icons.inventory_2_outlined,
              title: 'Estoque',
              value: product.stockLabel,
              primaryColor: primaryColor,
            ),
            const SizedBox(width: 8),
            PhysicalProductInfoPill(
              icon: Icons.verified_rounded,
              title: 'Vendedor',
              value: 'Verificado',
              primaryColor: primaryColor,
            ),
          ],
        ),
      ],
    );
  }
}

class PhysicalProductPriceBlock extends StatelessWidget {
  final StorePhysicalProductDetailsData product;
  final Color primaryColor;

  const PhysicalProductPriceBlock({
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
          Text(
            'De ${product.formattedPrice}',
            style: textMedium.copyWith(
              color: Colors.redAccent,
              fontSize: 13,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.redAccent,
              decorationThickness: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Por ${product.formattedFinalPrice}',
            style: textBold.copyWith(
              color: primaryColor,
              fontSize: 26,
            ),
          ),
        ],
      );
    }

    return Text(
      product.formattedFinalPrice,
      style: textBold.copyWith(
        color: primaryColor,
        fontSize: 26,
      ),
    );
  }
}

class PhysicalProductInfoPill extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color primaryColor;

  const PhysicalProductInfoPill({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: 19,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 12.6,
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

class PhysicalProductDeliverySection extends StatelessWidget {
  final StorePhysicalProductDetailsData product;
  final Color primaryColor;

  const PhysicalProductDeliverySection({
    super.key,
    required this.product,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final List<PhysicalProductDeliveryOptionData> options =
        product.deliveryOptions;

    if (options.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhysicalProductSectionTitle(title: 'Opções de entrega'),
          const SizedBox(height: 10),
          Text(
            'As opções de entrega deste produto serão confirmadas no carrinho.',
            style: textRegular.copyWith(
              color: Colors.grey.shade700,
              fontSize: 12.8,
              height: 1.32,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhysicalProductSectionTitle(title: 'Opções de entrega'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: List.generate(options.length, (index) {
              final PhysicalProductDeliveryOptionData option = options[index];
              final bool isLast = index == options.length - 1;

              return PhysicalProductDeliveryRow(
                option: option,
                primaryColor: primaryColor,
                showDivider: !isLast,
              );
            }),
          ),
        ),
      ],
    );
  }
}

class PhysicalProductDeliveryRow extends StatelessWidget {
  final PhysicalProductDeliveryOptionData option;
  final Color primaryColor;
  final bool showDivider;

  const PhysicalProductDeliveryRow({
    super.key,
    required this.option,
    required this.primaryColor,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              )
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              option.icon,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.title,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  option.description,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 12.2,
                    height: 1.3,
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

class PhysicalProductSellerSection extends StatelessWidget {
  final StorePhysicalProductDetailsData product;
  final Color primaryColor;

  const PhysicalProductSellerSection({
    super.key,
    required this.product,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhysicalProductSectionTitle(title: 'Vendido por'),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.16),
                ),
              ),
              child: ClipOval(
                child: product.storeLogoUrl.isEmpty
                    ? Icon(
                        Icons.storefront_rounded,
                        color: primaryColor,
                        size: 26,
                      )
                    : Image.network(
                        product.storeLogoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Icon(
                            Icons.storefront_rounded,
                            color: primaryColor,
                            size: 26,
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.storeName.isEmpty
                        ? 'Loja parceira'
                        : product.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(
                      color: Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: primaryColor,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Vendedor verificado',
                        style: textBold.copyWith(
                          color: primaryColor,
                          fontSize: 11.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        PhysicalSellerReputationBlock(primaryColor: primaryColor),
      ],
    );
  }
}

class PhysicalTrustBar extends StatelessWidget {
  final Color primaryColor;

  const PhysicalTrustBar({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PhysicalTrustItem(
          icon: Icons.verified_user_outlined,
          label: 'Compra segura',
          primaryColor: primaryColor,
        ),
        const SizedBox(width: 8),
        PhysicalTrustItem(
          icon: Icons.receipt_long_outlined,
          label: 'Pedido registrado',
          primaryColor: primaryColor,
        ),
        const SizedBox(width: 8),
        PhysicalTrustItem(
          icon: Icons.local_shipping_outlined,
          label: 'Entrega configurada',
          primaryColor: primaryColor,
        ),
      ],
    );
  }
}

class PhysicalTrustItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color primaryColor;

  const PhysicalTrustItem({
    super.key,
    required this.icon,
    required this.label,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: primaryColor,
              size: 18,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textMedium.copyWith(
                color: Colors.black87,
                fontSize: 10.5,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PhysicalSellerReputationBlock extends StatelessWidget {
  final Color primaryColor;

  const PhysicalSellerReputationBlock({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star_rounded,
                color: primaryColor,
                size: 18,
              ),
              const SizedBox(width: 5),
              Text(
                'Loja verificada pela Lokally',
                style: textBold.copyWith(
                  color: primaryColor,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              PhysicalSellerRatingBar(
                label: 'Atendimento',
                color: primaryColor,
                flex: 10,
              ),
              const SizedBox(width: 7),
              PhysicalSellerRatingBar(
                label: 'Entrega',
                color: primaryColor,
                flex: 10,
              ),
              const SizedBox(width: 7),
              PhysicalSellerRatingBar(
                label: 'Qualidade',
                color: primaryColor,
                flex: 10,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PhysicalSellerRatingBar extends StatelessWidget {
  final String label;
  final Color color;
  final int flex;

  const PhysicalSellerRatingBar({
    super.key,
    required this.label,
    required this.color,
    required this.flex,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 6,
              color: Colors.grey.shade200,
              child: Row(
                children: [
                  Expanded(
                    flex: flex,
                    child: Container(color: color),
                  ),
                  if (flex < 10)
                    Expanded(
                      flex: 10 - flex,
                      child: const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textMedium.copyWith(
              color: Colors.grey.shade700,
              fontSize: 10.4,
            ),
          ),
        ],
      ),
    );
  }
}

class PhysicalProductGuaranteeSection extends StatelessWidget {
  final Color primaryColor;

  const PhysicalProductGuaranteeSection({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Garantia Lokally',
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 15.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'A Lokally garante a entrega do seu pedido. O pagamento fica retido na Lokally até a comprovação de entrega.',
                  style: textRegular.copyWith(
                    color: Colors.grey.shade800,
                    fontSize: 12.5,
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

class PhysicalProductDescriptionSection extends StatelessWidget {
  final StorePhysicalProductDetailsData product;

  const PhysicalProductDescriptionSection({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final String description = product.description.trim().isNotEmpty
        ? product.description.trim()
        : product.shortDescription.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhysicalProductSectionTitle(title: 'Descrição do produto'),
        const SizedBox(height: 10),
        Text(
          description.isEmpty
              ? 'O vendedor ainda não adicionou uma descrição completa para este produto.'
              : description,
          style: textRegular.copyWith(
            color: Colors.grey.shade800,
            fontSize: 13.2,
            height: 1.42,
          ),
        ),
      ],
    );
  }
}

class PhysicalProductReviewsSection extends StatelessWidget {
  final List<StorePhysicalProductReviewData> reviews;
  final Color primaryColor;

  const PhysicalProductReviewsSection({
    super.key,
    required this.reviews,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhysicalProductSectionTitle(title: 'Depoimentos'),
          const SizedBox(height: 10),
          Text(
            'Este produto ainda não possui depoimentos.',
            style: textRegular.copyWith(
              color: Colors.grey.shade700,
              fontSize: 12.8,
              height: 1.32,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhysicalProductSectionTitle(title: 'Depoimentos'),
        const SizedBox(height: 12),
        ...reviews.take(3).map((review) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PhysicalProductReviewCard(
              review: review,
              primaryColor: primaryColor,
            ),
          );
        }),
      ],
    );
  }
}

class PhysicalProductReviewCard extends StatelessWidget {
  final StorePhysicalProductReviewData review;
  final Color primaryColor;

  const PhysicalProductReviewCard({
    super.key,
    required this.review,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (index) {
                final bool selected = review.rating > index;

                return Icon(
                  selected ? Icons.star_rounded : Icons.star_border_rounded,
                  color:
                      selected ? Colors.amber.shade700 : Colors.grey.shade400,
                  size: 17,
                );
              }),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  review.customerName.isEmpty
                      ? 'Cliente Lokally'
                      : review.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 12.4,
                  ),
                ),
              ),
            ],
          ),
          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment.trim(),
              style: textRegular.copyWith(
                color: Colors.grey.shade700,
                fontSize: 12.4,
                height: 1.32,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PhysicalProductRelatedSection extends StatelessWidget {
  final List<StorePhysicalProductDetailsData> products;
  final Color primaryColor;
  final ScrollController controller;
  final ValueChanged<StorePhysicalProductDetailsData> onProductTap;

  const PhysicalProductRelatedSection({
    super.key,
    required this.products,
    required this.primaryColor,
    required this.controller,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhysicalProductSectionTitle(title: 'Mais produtos desta loja'),
        const SizedBox(height: 12),
        SizedBox(
          height: 292,
          child: ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return PhysicalRelatedProductCard(
                product: products[index],
                primaryColor: primaryColor,
                onTap: () => onProductTap(products[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class PhysicalRelatedProductCard extends StatelessWidget {
  final StorePhysicalProductDetailsData product;
  final Color primaryColor;
  final VoidCallback onTap;

  const PhysicalRelatedProductCard({
    super.key,
    required this.product,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade200),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: product.mainImageUrl.isEmpty
                      ? Icon(
                          Icons.image_outlined,
                          color: primaryColor,
                          size: 32,
                        )
                      : Image.network(
                          product.mainImageUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) {
                            return Icon(
                              Icons.broken_image_outlined,
                              color: primaryColor,
                              size: 32,
                            );
                          },
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 12.4,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      product.formattedFinalPrice,
                      style: textBold.copyWith(
                        color: primaryColor,
                        fontSize: 13.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.primaryDeliveryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 10.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 32,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Ver Oferta',
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 11.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhysicalProductSectionTitle extends StatelessWidget {
  final String title;

  const PhysicalProductSectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: textBold.copyWith(
        color: Colors.black87,
        fontSize: 18,
      ),
    );
  }
}

class PhysicalProductBottomBar extends StatelessWidget {
  final StorePhysicalProductDetailsData product;
  final Color primaryColor;
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onAddToCart;

  const PhysicalProductBottomBar({
    super.key,
    required this.product,
    required this.primaryColor,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAvailable = product.stock > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        12,
        14,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -8),
            blurRadius: 24,
            color: Colors.black.withValues(alpha: 0.10),
          ),
        ],
      ),
      child: Row(
        children: [
          PhysicalBottomProductThumb(
            product: product,
            primaryColor: primaryColor,
          ),
          const SizedBox(width: 9),
          PhysicalQuantityControl(
            quantity: quantity,
            primaryColor: primaryColor,
            onDecrease: onDecrease,
            onIncrease: onIncrease,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: isAvailable ? primaryColor : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: isAvailable ? onAddToCart : null,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  child: Text(
                    isAvailable ? 'Adicionar ao carrinho' : 'Indisponível',
                    style: textBold.copyWith(
                      color: Colors.white,
                      fontSize: 13.8,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PhysicalBottomProductThumb extends StatelessWidget {
  final StorePhysicalProductDetailsData product;
  final Color primaryColor;

  const PhysicalBottomProductThumb({
    super.key,
    required this.product,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: product.mainImageUrl.isEmpty
          ? Icon(
              Icons.image_outlined,
              color: primaryColor,
              size: 24,
            )
          : Image.network(
              product.mainImageUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) {
                return Icon(
                  Icons.broken_image_outlined,
                  color: primaryColor,
                  size: 24,
                );
              },
            ),
    );
  }
}

class PhysicalQuantityControl extends StatelessWidget {
  final int quantity;
  final Color primaryColor;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const PhysicalQuantityControl({
    super.key,
    required this.quantity,
    required this.primaryColor,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onDecrease,
            child: SizedBox(
              width: 40,
              height: 52,
              child: Icon(
                Icons.remove_rounded,
                color: primaryColor,
                size: 20,
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              quantity.toString(),
              textAlign: TextAlign.center,
              style: textBold.copyWith(
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          GestureDetector(
            onTap: onIncrease,
            child: SizedBox(
              width: 40,
              height: 52,
              child: Icon(
                Icons.add_rounded,
                color: primaryColor,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PhysicalProductDeliveryOptionData {
  final IconData icon;
  final String title;
  final String description;

  PhysicalProductDeliveryOptionData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class StorePhysicalProductDetailsData {
  final String id;
  final String sellerId;
  final String title;
  final String slug;
  final String shortDescription;
  final String description;
  final double price;
  final double finalPrice;
  final bool hasPromotion;
  final int stock;
  final String unit;
  final String categoryId;
  final String category;
  final String mainImageUrl;
  final List<String> galleryImages;
  final String storeName;
  final String storeLogoUrl;
  final String storeAddress;
  final String storeCity;
  final String storeState;
  final String availabilityType;
  final String availabilityLabel;
  final String productType;
  final String conditionType;
  final bool allowPickup;
  final bool allowLokallyShipping;
  final bool allowNationalShipping;
  final double lokallyShippingStartingPrice;

  StorePhysicalProductDetailsData({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.slug,
    required this.shortDescription,
    required this.description,
    required this.price,
    required this.finalPrice,
    required this.hasPromotion,
    required this.stock,
    required this.unit,
    required this.categoryId,
    required this.category,
    required this.mainImageUrl,
    required this.galleryImages,
    required this.storeName,
    required this.storeLogoUrl,
    required this.storeAddress,
    required this.storeCity,
    required this.storeState,
    required this.availabilityType,
    required this.availabilityLabel,
    required this.productType,
    required this.conditionType,
    required this.allowPickup,
    required this.allowLokallyShipping,
    required this.allowNationalShipping,
    required this.lokallyShippingStartingPrice,
  });

  factory StorePhysicalProductDetailsData.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> store = firstMapValue(<dynamic>[
      map['store'],
      map['seller'],
      map['store_seller'],
      map['seller_info'],
      map['shop'],
      map['vendor'],
    ]);

    final dynamic galleryValue = map['gallery'] ?? map['images'];
    final List<dynamic> galleryList =
        galleryValue is List ? galleryValue : <dynamic>[];

    final List<String> galleryImages = galleryList
        .map((item) {
          if (item is Map) {
            return '${item['image_url'] ?? item['url'] ?? item['main_image_url'] ?? ''}';
          }

          return '$item';
        })
        .where((imageUrl) => imageUrl.trim().isNotEmpty)
        .toList();

    final String mainImageUrl =
        '${map['main_image_url'] ?? map['image_url'] ?? map['image'] ?? map['thumbnail'] ?? ''}';

    final double price = parseDouble(map['price']);
    final double finalPrice = parseDouble(map['final_price']);
    final double oldPrice = parseDouble(map['old_price']);
    final double promotionalPrice = parseDouble(map['promotional_price']);

    double displayPrice = price;
    double displayFinalPrice = finalPrice > 0 ? finalPrice : price;
    bool hasPromotion = map['has_promotion'] == true &&
        displayFinalPrice > 0 &&
        displayPrice > displayFinalPrice;

    if (!hasPromotion && oldPrice > 0 && oldPrice > price) {
      displayPrice = oldPrice;
      displayFinalPrice = price;
      hasPromotion = true;
    }

    if (!hasPromotion && promotionalPrice > 0 && promotionalPrice < price) {
      displayFinalPrice = promotionalPrice;
      hasPromotion = true;
    }

    final String categoryText =
        '${map['category_name'] ?? ''} ${map['category_slug'] ?? ''} ${map['category'] ?? ''}'
            .toLowerCase();
    final String rawProductType =
        '${map['product_type'] ?? ''}'.trim().toLowerCase();
    final bool looksLikeService = categoryText.contains('servi') ||
        categoryText.contains('marketing') ||
        categoryText.contains('publicidade') ||
        categoryText.contains('tecnologia') ||
        categoryText.contains('download') ||
        categoryText.contains('digital');
    final String normalizedProductType = rawProductType.isNotEmpty
        ? rawProductType
        : looksLikeService
            ? 'service'
            : 'physical';

    final bool hasAnyDeliveryFlag = map.containsKey('allow_pickup') ||
        map.containsKey('allow_lokally_shipping') ||
        map.containsKey('allow_national_shipping') ||
        map.containsKey('delivery_immediate') ||
        map.containsKey('delivery_full_24h') ||
        map.containsKey('delivery_lokally_br') ||
        map.containsKey('national_shipping_enabled') ||
        map.containsKey('is_national_shipping_enabled') ||
        map.containsKey('has_national_shipping') ||
        map.containsKey('allow_br_shipping') ||
        map.containsKey('allow_brazil_shipping') ||
        store.containsKey('national_shipping_enabled') ||
        store.containsKey('allow_national_shipping');

    bool allowPickup = parseBool(firstNotEmpty(<dynamic>[
      map['allow_pickup'],
      map['delivery_immediate'],
      map['pickup_enabled'],
      map['allow_store_pickup'],
    ]));
    bool allowLokallyShipping = parseBool(firstNotEmpty(<dynamic>[
      map['allow_lokally_shipping'],
      map['delivery_full_24h'],
      map['local_shipping_enabled'],
      map['lokally_shipping_enabled'],
    ]));
    bool allowNationalShipping = parseBool(firstNotEmpty(<dynamic>[
      map['allow_national_shipping'],
      map['delivery_lokally_br'],
      map['national_shipping_enabled'],
      map['is_national_shipping_enabled'],
      map['has_national_shipping'],
      map['allow_br_shipping'],
      map['allow_brazil_shipping'],
      store['allow_national_shipping'],
      store['national_shipping_enabled'],
    ]));

    if (!allowNationalShipping &&
        parseDouble(map['package_weight_kg']) > 0 &&
        parseDouble(map['package_height_cm']) > 0 &&
        parseDouble(map['package_width_cm']) > 0 &&
        parseDouble(map['package_length_cm']) > 0) {
      allowNationalShipping = true;
    }

    if (!hasAnyDeliveryFlag) {
      allowPickup = true;
      allowLokallyShipping = true;
      allowNationalShipping = false;
    }

    final String storeAddress = firstNotEmpty(<dynamic>[
      store['address'],
      store['store_address'],
      store['full_address'],
      store['shipping_origin_address'],
      map['store_address'],
      map['seller_address'],
      map['shipping_origin_address'],
      map['address'],
    ]);

    final String rawCity = firstNotEmpty(<dynamic>[
      store['shipping_origin_city'],
      store['origin_city'],
      store['city'],
      store['zone_name'],
      store['city_name'],
      map['shipping_origin_city'],
      map['seller_shipping_origin_city'],
      map['store_shipping_origin_city'],
      map['store_city'],
      map['seller_city'],
      map['origin_city'],
      map['city'],
    ]);

    final String city =
        rawCity.isNotEmpty ? rawCity : extractCityFromAddress(storeAddress);

    final String state = firstNotEmpty(<dynamic>[
      store['shipping_origin_state'],
      store['origin_state'],
      store['state'],
      store['state_code'],
      map['shipping_origin_state'],
      map['seller_shipping_origin_state'],
      map['store_shipping_origin_state'],
      map['store_state'],
      map['seller_state'],
      map['origin_state'],
      map['state'],
    ]);

    final double configuredShipping = parseDouble(
      map['lokally_shipping_price'] ??
          map['marketplace_shipping_value'] ??
          map['shipping_value'] ??
          map['local_shipping_price'],
    );

    return StorePhysicalProductDetailsData(
      id: '${map['id'] ?? ''}',
      sellerId: '${map['seller_id'] ?? store['id'] ?? ''}',
      title: '${map['name'] ?? map['title'] ?? ''}',
      slug: '${map['slug'] ?? ''}',
      shortDescription: '${map['short_description'] ?? ''}',
      description: '${map['description'] ?? ''}',
      price: displayPrice,
      finalPrice: displayFinalPrice > 0 ? displayFinalPrice : displayPrice,
      hasPromotion: hasPromotion,
      stock: int.tryParse('${map['stock'] ?? 0}') ?? 0,
      unit: '${map['unit'] ?? 'unidade'}',
      categoryId: '${map['category_id'] ?? ''}',
      category: '${map['category_name'] ?? map['category'] ?? ''}',
      mainImageUrl: mainImageUrl,
      galleryImages: galleryImages.isEmpty && mainImageUrl.isNotEmpty
          ? <String>[mainImageUrl]
          : galleryImages,
      storeName: '${store['name'] ?? map['store_name'] ?? ''}',
      storeLogoUrl: '${store['logo_url'] ?? map['store_logo_url'] ?? ''}',
      storeAddress: storeAddress,
      storeCity: city,
      storeState: state,
      availabilityType: '${map['availability_type'] ?? 'immediate'}',
      availabilityLabel: '${map['availability_label'] ?? 'Imediata'}',
      productType: normalizedProductType,
      conditionType: '${map['condition_type'] ?? 'new'}'.trim().toLowerCase(),
      allowPickup: allowPickup,
      allowLokallyShipping: allowLokallyShipping,
      allowNationalShipping: allowNationalShipping,
      lokallyShippingStartingPrice:
          configuredShipping > 0 ? configuredShipping : 8.50,
    );
  }

  bool get isPhysicalProduct {
    return productType != 'service' &&
        productType != 'vehicle' &&
        productType != 'vehicle_ad' &&
        productType != 'real_estate' &&
        productType != 'real_estate_ad' &&
        productType != 'imovel' &&
        productType != 'imóvel';
  }

  String get formattedPrice => formatCurrency(price);

  String get formattedFinalPrice => formatCurrency(finalPrice);

  String get stockLabel {
    if (stock <= 0) {
      return 'Indisponível';
    }

    return '$stock $unit';
  }

  String get storeCityLabel {
    if (storeCity.isEmpty && storeState.isEmpty) {
      return '';
    }

    if (storeCity.isNotEmpty && storeState.isNotEmpty) {
      return '$storeCity - $storeState';
    }

    return storeCity.isNotEmpty ? storeCity : storeState;
  }

  String get cityForDeliveryText {
    if (storeCity.isEmpty) {
      return 'cidade da loja';
    }

    return storeCity;
  }

  String get primaryDeliveryLabel {
    if (allowPickup) {
      return 'Retire Grátis Hoje';
    }

    if (allowLokallyShipping) {
      return 'Lokally Envios';
    }

    if (allowNationalShipping) {
      return 'Lokally Envios BR';
    }

    return 'Entrega no carrinho';
  }

  List<PhysicalProductDeliveryOptionData> get deliveryOptions {
    final List<PhysicalProductDeliveryOptionData> options =
        <PhysicalProductDeliveryOptionData>[];

    if (allowPickup) {
      options.add(
        PhysicalProductDeliveryOptionData(
          icon: Icons.storefront_rounded,
          title: 'Retire Grátis',
          description:
              'Retire o seu pedido dentro do horário comercial em $cityForDeliveryText.',
        ),
      );
    }

    if (allowLokallyShipping) {
      options.add(
        PhysicalProductDeliveryOptionData(
          icon: Icons.delivery_dining_rounded,
          title: 'Lokally Envios',
          description:
              'Receba o seu pedido em até 24h, entregue por um parceiro Lokally em $cityForDeliveryText.',
        ),
      );
    }

    if (allowNationalShipping) {
      options.add(
        PhysicalProductDeliveryOptionData(
          icon: Icons.local_shipping_outlined,
          title: 'Lokally Envios BR',
          description:
              'Receba o seu pedido em sua casa, entrega em todo o Brasil.',
        ),
      );
    }

    return options;
  }

  Map<String, dynamic> toCartMap() {
    return <String, dynamic>{
      'id': id,
      'seller_id': sellerId,
      'name': title,
      'slug': slug,
      'short_description': shortDescription,
      'description': description,
      'price': price,
      'final_price': finalPrice,
      'has_promotion': hasPromotion,
      'stock': stock,
      'unit': unit,
      'category_id': categoryId,
      'category_name': category,
      'main_image_url': mainImageUrl,
      'gallery': galleryImages
          .map((imageUrl) => <String, dynamic>{
                'image_url': imageUrl,
              })
          .toList(),
      'availability_type': availabilityType,
      'availability_label': availabilityLabel,
      'product_type': productType,
      'condition_type': conditionType,
      'allow_pickup': allowPickup,
      'allow_lokally_shipping': allowLokallyShipping,
      'allow_national_shipping': allowNationalShipping,
      'delivery_immediate': allowPickup,
      'delivery_full_24h': allowLokallyShipping,
      'delivery_lokally_br': allowNationalShipping,
      'lokally_shipping_price': lokallyShippingStartingPrice,
      'store_city': storeCity,
      'store_state': storeState,
      'store_address': storeAddress,
      'store': <String, dynamic>{
        'id': sellerId,
        'name': storeName,
        'logo_url': storeLogoUrl,
        'address': storeAddress,
        'city': storeCity,
        'state': storeState,
      },
    };
  }

  static double parseDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    String cleanValue = '$value'
        .trim()
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('\u00A0', '');

    if (cleanValue.contains(',') && cleanValue.contains('.')) {
      cleanValue = cleanValue.replaceAll('.', '').replaceAll(',', '.');
    } else if (cleanValue.contains(',')) {
      cleanValue = cleanValue.replaceAll(',', '.');
    }

    return double.tryParse(cleanValue) ?? 0;
  }

  static bool parseBool(dynamic value) {
    if (value == null) {
      return false;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final String normalized = '$value'.trim().toLowerCase();

    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'sim' ||
        normalized == 'yes' ||
        normalized == 'ativo' ||
        normalized == 'active';
  }

  static Map<String, dynamic> firstMapValue(List<dynamic> values) {
    for (final dynamic value in values) {
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }

    return <String, dynamic>{};
  }

  static String extractCityFromAddress(String address) {
    final String cleanAddress = address.trim();

    if (cleanAddress.isEmpty) {
      return '';
    }

    final RegExp cityStatePattern = RegExp(
      r',\s*([^,]+?)\s*[-/]\s*[A-Z]{2}(?:\s|,|$)',
      caseSensitive: false,
    );
    final Iterable<RegExpMatch> cityStateMatches =
        cityStatePattern.allMatches(cleanAddress);

    if (cityStateMatches.isNotEmpty) {
      return cityStateMatches.last.group(1)?.trim() ?? '';
    }

    final RegExp commaStatePattern = RegExp(
      r',\s*([^,]+?),\s*[A-Z]{2}(?:\s|,|$)',
      caseSensitive: false,
    );
    final Iterable<RegExpMatch> commaStateMatches =
        commaStatePattern.allMatches(cleanAddress);

    if (commaStateMatches.isNotEmpty) {
      return commaStateMatches.last.group(1)?.trim() ?? '';
    }

    return '';
  }

  static String firstNotEmpty(List<dynamic> values) {
    for (final dynamic value in values) {
      final String text = '$value'.trim();

      if (text.isNotEmpty && text != 'null') {
        return text;
      }
    }

    return '';
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

class StorePhysicalProductCategoryData {
  final String id;
  final String name;
  final String slug;
  final String primaryIconUrl;
  final String? localIconAsset;
  final bool isAll;
  final String normalizedIdentifier;
  final List<StorePhysicalProductCategoryData> subcategories;

  StorePhysicalProductCategoryData({
    required this.id,
    required this.name,
    required this.slug,
    required this.primaryIconUrl,
    required this.localIconAsset,
    required this.isAll,
    required this.normalizedIdentifier,
    this.subcategories = const <StorePhysicalProductCategoryData>[],
  });

  factory StorePhysicalProductCategoryData.all({
    String imageUrl = '',
    String iconUrl = '',
  }) {
    return StorePhysicalProductCategoryData(
      id: 'all',
      name: 'Home',
      slug: 'all',
      primaryIconUrl: imageUrl.isNotEmpty ? imageUrl : iconUrl,
      localIconAsset: null,
      isAll: true,
      normalizedIdentifier: 'all',
    );
  }

  factory StorePhysicalProductCategoryData.fromMap(Map<String, dynamic> map) {
    final dynamic subcategoriesValue = map['subcategories'];
    final List<dynamic> subcategoryList =
        subcategoriesValue is List ? subcategoriesValue : <dynamic>[];

    final String name = '${map['name'] ?? map['title'] ?? ''}'.trim();
    final String slug = '${map['slug'] ?? ''}'.trim();
    final String imageUrl = firstNotEmpty(<dynamic>[
      map['image_url'],
      map['icon_url'],
      map['primary_icon_url'],
      map['image'],
      map['icon'],
    ]);

    return StorePhysicalProductCategoryData(
      id: '${map['id'] ?? ''}',
      name: name,
      slug: slug,
      primaryIconUrl: imageUrl,
      localIconAsset: null,
      isAll: false,
      normalizedIdentifier: normalizeIdentifier('$name $slug'),
      subcategories: subcategoryList
          .whereType<Map>()
          .map((item) => StorePhysicalProductCategoryData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((category) => category.id.isNotEmpty)
          .toList(),
    );
  }

  bool get representsAllCategory {
    return isAll ||
        normalizedIdentifier == 'todos' ||
        normalizedIdentifier == 'all' ||
        slug.toLowerCase() == 'todos' ||
        slug.toLowerCase() == 'all';
  }

  String get deduplicationKey {
    if (normalizedIdentifier.isNotEmpty) {
      return normalizedIdentifier;
    }

    return id;
  }

  static String firstNotEmpty(List<dynamic> values) {
    for (final dynamic value in values) {
      final String text = '$value'.trim();

      if (text.isNotEmpty && text != 'null') {
        return text;
      }
    }

    return '';
  }

  static String normalizeIdentifier(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[áàãâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòõôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}

class StorePhysicalProductReviewData {
  final String id;
  final String customerName;
  final String comment;
  final int rating;

  StorePhysicalProductReviewData({
    required this.id,
    required this.customerName,
    required this.comment,
    required this.rating,
  });

  factory StorePhysicalProductReviewData.fromMap(Map<String, dynamic> map) {
    return StorePhysicalProductReviewData(
      id: '${map['id'] ?? ''}',
      customerName: '${map['customer_name'] ?? ''}',
      comment: '${map['comment'] ?? ''}',
      rating: int.tryParse('${map['rating'] ?? 0}') ?? 0,
    );
  }
}
