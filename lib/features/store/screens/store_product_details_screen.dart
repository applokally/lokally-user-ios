import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_cart_screen.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_marketplace_header.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> initialProduct;

  const StoreProductDetailsScreen({
    super.key,
    required this.initialProduct,
  });

  @override
  State<StoreProductDetailsScreen> createState() =>
      _StoreProductDetailsScreenState();
}

class _StoreProductDetailsScreenState extends State<StoreProductDetailsScreen> {
  StoreProductDetailsData? product;
  List<StoreProductDetailsData> relatedProducts = <StoreProductDetailsData>[];
  List<StoreProductReviewData> reviews = <StoreProductReviewData>[];

  bool isLoading = true;
  static const String publicCategoriesUri = '/api/store/public-categories';
  static const String publicProductsUri = '/api/store/products';

  int quantity = 1;
  int selectedImageIndex = 0;

  final ScrollController productScrollController = ScrollController();
  final ScrollController relatedProductsCarouselController = ScrollController();
  Timer? relatedProductsCarouselTimer;
  int selectedMainCategoryIndex = 0;
  String selectedSubcategoryId = '';
  String searchQuery = '';

  List<StoreProductCategoryData> mainCategories = <StoreProductCategoryData>[
    StoreProductCategoryData.all(),
  ];
  List<StoreProductDetailsData> marketplaceProducts =
      <StoreProductDetailsData>[];

  @override
  void initState() {
    super.initState();

    product = StoreProductDetailsData.fromMap(widget.initialProduct);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadProductDetails();
      loadMarketplaceHeaderData();
    });
  }

  @override
  void dispose() {
    relatedProductsCarouselTimer?.cancel();
    relatedProductsCarouselController.dispose();
    productScrollController.dispose();
    super.dispose();
  }

  Future<void> loadProductDetails() async {
    final StoreProductDetailsData? currentProduct = product;

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
        showStoreMessage('Não foi possível carregar os detalhes do produto.');
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
        product = StoreProductDetailsData.fromMap(productMap);
        relatedProducts = relatedList
            .whereType<Map>()
            .map((item) => StoreProductDetailsData.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .where((item) => item.id.isNotEmpty)
            .toList();
        reviews = reviewList
            .whereType<Map>()
            .map((item) => StoreProductReviewData.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList();
        selectedImageIndex = 0;
        isLoading = false;
      });

      restartRelatedProductsCarousel();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      showStoreMessage('Não foi possível carregar os detalhes do produto.');
    }
  }

  Future<void> loadMarketplaceHeaderData() async {
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
        return;
      }

      final dynamic dataValue = responseBody['data'];
      final List<dynamic> data = dataValue is List ? dataValue : <dynamic>[];

      final List<StoreProductCategoryData> loadedCategories =
          <StoreProductCategoryData>[
        StoreProductCategoryData.all(),
      ];

      loadedCategories.addAll(
        data
            .whereType<Map>()
            .map((item) => StoreProductCategoryData.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .where((category) {
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
    } catch (_) {}
  }

  Future<void> loadPublicProducts() async {
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
        marketplaceProducts = productList
            .whereType<Map>()
            .map((item) => StoreProductDetailsData.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .where((item) => item.id.isNotEmpty)
            .toList();
      });
    } catch (_) {}
  }

  void restartRelatedProductsCarousel() {
    relatedProductsCarouselTimer?.cancel();

    if (relatedProducts.length <= 1) {
      return;
    }

    relatedProductsCarouselTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        if (!mounted || !relatedProductsCarouselController.hasClients) {
          return;
        }

        final double maxScroll =
            relatedProductsCarouselController.position.maxScrollExtent;
        final double currentScroll = relatedProductsCarouselController.offset;
        final double nextScroll = currentScroll + 194;

        relatedProductsCarouselController.animateTo(
          nextScroll >= maxScroll ? 0 : nextScroll,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOut,
        );
      },
    );
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

  void increaseQuantity() {
    final StoreProductDetailsData? currentProduct = product;

    if (currentProduct == null) {
      return;
    }

    if (quantity >= currentProduct.stock && currentProduct.stock > 0) {
      showStoreMessage('Quantidade máxima disponível em estoque.');
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
    final StoreProductDetailsData? currentProduct = product;

    if (currentProduct == null) {
      return;
    }

    StoreCartSession.addProductMap(
      currentProduct.toMap(),
      quantity,
    );

    setState(() {});

    showStoreMessage(
      '${currentProduct.title} adicionado ao carrinho.',
    );
    openCartScreen();
  }

  void openCartScreen() {
    Get.to(() => const StoreCartScreen());
  }

  void openRelatedProduct(StoreProductDetailsData item) {
    relatedProductsCarouselTimer?.cancel();

    setState(() {
      product = item;
      relatedProducts = <StoreProductDetailsData>[];
      reviews = <StoreProductReviewData>[];
      quantity = 1;
      selectedImageIndex = 0;
      isLoading = true;
      searchQuery = '';
      selectedMainCategoryIndex = 0;
      selectedSubcategoryId = '';
    });

    if (productScrollController.hasClients) {
      productScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    }

    loadProductDetails();
  }

  StoreProductCategoryData get selectedMainCategory {
    if (mainCategories.isEmpty ||
        selectedMainCategoryIndex >= mainCategories.length) {
      return StoreProductCategoryData.all();
    }

    return mainCategories[selectedMainCategoryIndex];
  }

  List<StoreProductCategoryData> get activeSubcategories {
    if (selectedMainCategory.isAll) {
      return <StoreProductCategoryData>[];
    }

    return selectedMainCategory.subcategories;
  }

  List<StoreProductDetailsData> get visibleMarketplaceProducts {
    final StoreProductCategoryData selected = selectedMainCategory;

    if (selected.isAll) {
      return marketplaceProducts;
    }

    if (selectedSubcategoryId.isNotEmpty) {
      return marketplaceProducts.where((item) {
        return item.categoryId == selectedSubcategoryId;
      }).toList();
    }

    final Set<String> subcategoryIds = selected.subcategories
        .map((subcategory) => subcategory.id)
        .where((id) => id.isNotEmpty)
        .toSet();

    return marketplaceProducts.where((item) {
      return subcategoryIds.contains(item.categoryId);
    }).toList();
  }

  List<StoreProductDetailsData> get searchResults {
    final String query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return <StoreProductDetailsData>[];
    }

    return marketplaceProducts.where((item) {
      return item.title.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.storeName.toLowerCase().contains(query);
    }).toList();
  }

  bool get shouldShowMarketplaceResults {
    return searchQuery.trim().isNotEmpty ||
        selectedMainCategoryIndex != 0 ||
        selectedSubcategoryId.isNotEmpty;
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
    final StoreProductDetailsData? currentProduct = product;
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
              StoreProductMarketplaceNavigation(
                categories: mainCategories,
                selectedIndex: selectedMainCategoryIndex,
                subcategories: activeSubcategories,
                selectedSubcategoryId: selectedSubcategoryId,
                primaryColor: primaryColor,
                onMainCategorySelected: handleMainCategorySelected,
                onSubcategorySelected: handleSubcategorySelected,
                onBackTap: () => Get.back(),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: primaryColor,
                  onRefresh: loadProductDetails,
                  child: SingleChildScrollView(
                    controller: productScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      Dimensions.paddingSizeDefault,
                      12,
                      Dimensions.paddingSizeDefault,
                      158,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (shouldShowMarketplaceResults) ...[
                          StoreProductHeaderResultsList(
                            products: searchQuery.trim().isNotEmpty
                                ? searchResults
                                : visibleMarketplaceProducts,
                            primaryColor: primaryColor,
                            onProductTap: openRelatedProduct,
                          ),
                          const StoreProductSectionDivider(),
                        ],
                        StoreProductHeroGallery(
                          product: currentProduct,
                          primaryColor: primaryColor,
                          selectedIndex: selectedImageIndex,
                          onImageChanged: (index) {
                            setState(() {
                              selectedImageIndex = index;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        StoreProductInfoBlock(
                          product: currentProduct,
                          primaryColor: primaryColor,
                        ),
                        const StoreProductSectionDivider(),
                        StoreProductShopMiniHeader(
                          product: currentProduct,
                          primaryColor: primaryColor,
                        ),
                        const StoreProductSectionDivider(),
                        StoreProductDescriptionBlock(
                          product: currentProduct,
                        ),
                        const StoreProductSectionDivider(),
                        StoreProductReviewsBlock(
                          reviews: reviews,
                          primaryColor: primaryColor,
                        ),
                        const StoreProductSectionDivider(),
                        if (relatedProducts.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          StoreRelatedProductsBlock(
                            products: relatedProducts,
                            primaryColor: primaryColor,
                            carouselController:
                                relatedProductsCarouselController,
                            onProductTap: openRelatedProduct,
                          ),
                        ],
                        if (isLoading) ...[
                          const SizedBox(height: 18),
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
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: StoreProductFixedBottomBar(
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

class StoreProductSectionDivider extends StatelessWidget {
  const StoreProductSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(
        height: 1,
        width: double.infinity,
        color: Colors.black.withValues(alpha: 0.08),
      ),
    );
  }
}

class StoreProductMarketplaceHeader extends StatelessWidget {
  final Color primaryColor;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCartTap;

  const StoreProductMarketplaceHeader({
    super.key,
    required this.primaryColor,
    required this.onSearchChanged,
    required this.onCartTap,
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
            child: StoreProductHeaderSearchField(
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

class StoreProductHeaderSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const StoreProductHeaderSearchField({
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

class StoreProductMarketplaceNavigation extends StatelessWidget {
  final List<StoreProductCategoryData> categories;
  final int selectedIndex;
  final List<StoreProductCategoryData> subcategories;
  final String selectedSubcategoryId;
  final Color primaryColor;
  final ValueChanged<int> onMainCategorySelected;
  final ValueChanged<String> onSubcategorySelected;
  final VoidCallback onBackTap;

  const StoreProductMarketplaceNavigation({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.subcategories,
    required this.selectedSubcategoryId,
    required this.primaryColor,
    required this.onMainCategorySelected,
    required this.onSubcategorySelected,
    required this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return StoreProductHeaderCategoryTextItem(
                  label: categories[index].name,
                  isSelected: index == selectedIndex,
                  primaryColor: primaryColor,
                  onTap: () => onMainCategorySelected(index),
                );
              },
            ),
          ),
          if (subcategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: subcategories.length,
                itemBuilder: (context, index) {
                  final StoreProductCategoryData item = subcategories[index];
                  final bool selected = selectedSubcategoryId == item.id;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onSubcategorySelected(item.id),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? primaryColor.withValues(alpha: 0.10)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color:
                                selected ? primaryColor : Colors.grey.shade200,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            item.name,
                            style: textBold.copyWith(
                              color: selected
                                  ? primaryColor
                                  : Colors.grey.shade700,
                              fontSize: 12.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onBackTap,
            child: Text(
              '← Voltar para loja',
              style: textBold.copyWith(
                color: primaryColor,
                fontSize: 12.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreProductHeaderCategoryTextItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreProductHeaderCategoryTextItem({
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

class StoreProductHeaderResultsList extends StatelessWidget {
  final List<StoreProductDetailsData> products;
  final Color primaryColor;
  final ValueChanged<StoreProductDetailsData> onProductTap;

  const StoreProductHeaderResultsList({
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
          return StoreProductHeaderResultTile(
            product: product,
            primaryColor: primaryColor,
            onTap: () => onProductTap(product),
          );
        }).toList(),
      ),
    );
  }
}

class StoreProductHeaderResultTile extends StatelessWidget {
  final StoreProductDetailsData product;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreProductHeaderResultTile({
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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 54,
                height: 54,
                child: product.mainImageUrl.isEmpty
                    ? Container(
                        color: primaryColor.withValues(alpha: 0.08),
                        child: Icon(
                          Icons.image_outlined,
                          color: primaryColor,
                          size: 24,
                        ),
                      )
                    : Image.network(
                        product.mainImageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            color: primaryColor.withValues(alpha: 0.08),
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: primaryColor,
                              size: 24,
                            ),
                          );
                        },
                      ),
              ),
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
                  ProductDetailsMiniPrice(
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

class StoreProductHeroGallery extends StatelessWidget {
  final StoreProductDetailsData product;
  final Color primaryColor;
  final int selectedIndex;
  final ValueChanged<int> onImageChanged;

  const StoreProductHeroGallery({
    super.key,
    required this.product,
    required this.primaryColor,
    required this.selectedIndex,
    required this.onImageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> images = product.galleryImages.isEmpty
        ? <String>[product.mainImageUrl]
        : product.galleryImages;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: PageView.builder(
              itemCount: images.length,
              onPageChanged: onImageChanged,
              itemBuilder: (context, index) {
                final String imageUrl = images[index];

                return Container(
                  width: double.infinity,
                  color: Colors.white,
                  child: imageUrl.isEmpty
                      ? Icon(
                          Icons.image_outlined,
                          color: primaryColor,
                          size: 42,
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return Icon(
                              Icons.broken_image_outlined,
                              color: primaryColor,
                              size: 42,
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (index) {
              final bool active = index == selectedIndex;

              return Container(
                width: active ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active ? primaryColor : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class StoreProductInfoBlock extends StatelessWidget {
  final StoreProductDetailsData product;
  final Color primaryColor;

  const StoreProductInfoBlock({
    super.key,
    required this.product,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
      child: Column(
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
          const SizedBox(height: 12),
          ProductDetailsPriceBlock(
            product: product,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 14),
          if (product.isService) ...[
            Row(
              children: [
                StoreProductInfoPill(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Tipo',
                  value: 'Serviço',
                  primaryColor: primaryColor,
                ),
                const SizedBox(width: 8),
                StoreProductInfoPill(
                  icon: product.serviceDeliveryIcon,
                  title: 'Formato',
                  value: product.serviceDeliveryLabel,
                  primaryColor: primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              product.serviceDeliveryDescription,
              style: textRegular.copyWith(
                color: Colors.grey.shade700,
                fontSize: 12.6,
                height: 1.28,
              ),
            ),
          ] else ...[
            Row(
              children: [
                StoreProductInfoPill(
                  icon: Icons.inventory_2_outlined,
                  title: 'Estoque',
                  value: '${product.stock} ${product.unit}',
                  primaryColor: primaryColor,
                ),
                const SizedBox(width: 8),
                StoreProductInfoPill(
                  icon: product.availabilityType == 'within_24h'
                      ? Icons.schedule_rounded
                      : Icons.flash_on_rounded,
                  title: 'Disponível',
                  value: product.availabilityLabel,
                  primaryColor: primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            StoreProductDeliveryBox(
              product: product,
              primaryColor: primaryColor,
            ),
          ],
        ],
      ),
    );
  }
}

class ProductDetailsPriceBlock extends StatelessWidget {
  final StoreProductDetailsData product;
  final Color primaryColor;

  const ProductDetailsPriceBlock({
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

class StoreProductInfoPill extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color primaryColor;

  const StoreProductInfoPill({
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

class StoreProductDeliveryBox extends StatelessWidget {
  final StoreProductDetailsData product;
  final Color primaryColor;

  const StoreProductDeliveryBox({
    super.key,
    required this.product,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (product.isService) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Formato do serviço',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  product.serviceDeliveryIcon,
                  color: primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  product.serviceDeliveryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(
                    color: primaryColor,
                    fontSize: 13.4,
                    height: 1.16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            product.serviceDeliveryDescription,
            style: textRegular.copyWith(
              color: Colors.grey.shade700,
              fontSize: 12.2,
              height: 1.30,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Opções de entrega',
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'RETIRE GRÁTIS HOJE',
          style: textBold.copyWith(
            color: primaryColor,
            fontSize: 13.2,
            height: 1.16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Produto disponível para retirada dentro do horário comercial do vendedor.',
          style: textRegular.copyWith(
            color: Colors.grey.shade700,
            fontSize: 12.2,
            height: 1.30,
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Lokally Envios',
                style: textBold.copyWith(
                  color: primaryColor,
                  fontSize: 13.2,
                  height: 1.24,
                ),
              ),
              TextSpan(
                text: ' em até 24h receba em sua casa, à partir de R\$8,50.',
                style: textRegular.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 13.0,
                  height: 1.24,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StoreProductShopMiniHeader extends StatelessWidget {
  final StoreProductDetailsData product;
  final Color primaryColor;

  const StoreProductShopMiniHeader({
    super.key,
    required this.product,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vendido por',
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 12.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: primaryColor,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: product.storeLogoUrl.isEmpty
                      ? Icon(
                          Icons.storefront_rounded,
                          color: primaryColor,
                          size: 27,
                        )
                      : Image.network(
                          product.storeLogoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Icon(
                              Icons.storefront_rounded,
                              color: primaryColor,
                              size: 27,
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  product.storeName.isEmpty
                      ? 'Loja parceira'
                      : product.storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StoreGuaranteedPaymentNotice(primaryColor: primaryColor),
          const SizedBox(height: 18),
          StoreShopTrustBar(primaryColor: primaryColor),
        ],
      ),
    );
  }
}

class StoreGuaranteedPaymentNotice extends StatelessWidget {
  final Color primaryColor;

  const StoreGuaranteedPaymentNotice({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              color: primaryColor,
              size: 17,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entrega garantida pela Lokally',
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 12.4,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Seu pagamento fica bloqueado até a comprovação do recebimento do produto ou serviço.',
                  style: textRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 11.6,
                    height: 1.28,
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

class StoreShopTrustBar extends StatelessWidget {
  final Color primaryColor;

  const StoreShopTrustBar({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '+25 Produtos',
          style: textMedium.copyWith(
            color: Colors.grey.shade700,
            fontSize: 14.5,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: const [
            Expanded(child: StoreTrustSegment(color: Color(0xFFFFECEF))),
            SizedBox(width: 6),
            Expanded(child: StoreTrustSegment(color: Color(0xFFFFF4DF))),
            SizedBox(width: 6),
            Expanded(child: StoreTrustSegment(color: Color(0xFFFFFFC7))),
            SizedBox(width: 6),
            Expanded(child: StoreTrustSegment(color: Color(0xFFE9F8C7))),
            SizedBox(width: 6),
            Expanded(child: StoreTrustSegment(color: Color(0xFF00A957))),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: StoreTrustMetric(
                title: '+100',
                subtitle: 'Vendas',
                primaryColor: primaryColor,
              ),
            ),
            Expanded(
              child: StoreTrustMetric(
                icon: Icons.chat_bubble_outline_rounded,
                subtitle: 'Bom atendimento',
                primaryColor: primaryColor,
              ),
            ),
            Expanded(
              child: StoreTrustMetric(
                icon: Icons.timer_outlined,
                subtitle: 'Entrega no prazo',
                primaryColor: primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class StoreTrustSegment extends StatelessWidget {
  final Color color;

  const StoreTrustSegment({
    super.key,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class StoreTrustMetric extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final String subtitle;
  final Color primaryColor;

  const StoreTrustMetric({
    super.key,
    this.title,
    this.icon,
    required this.subtitle,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (title != null)
          Text(
            title!,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 20,
            ),
          )
        else
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: Colors.black87,
                size: 25,
              ),
              Positioned(
                right: -4,
                bottom: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: textRegular.copyWith(
            color: Colors.grey.shade600,
            fontSize: 11.8,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

class StoreProductDescriptionBlock extends StatelessWidget {
  final StoreProductDetailsData product;

  const StoreProductDescriptionBlock({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final String description = product.description.isNotEmpty
        ? product.description
        : product.shortDescription;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.isService ? 'Descrição do serviço' : 'Descrição do produto',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            description.isEmpty
                ? product.isService
                    ? 'O vendedor ainda não adicionou uma descrição detalhada para este serviço.'
                    : 'O vendedor ainda não adicionou uma descrição detalhada para este produto.'
                : description,
            style: textRegular.copyWith(
              color: Colors.grey.shade700,
              fontSize: 13.3,
              height: 1.38,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreProductReviewsBlock extends StatelessWidget {
  final List<StoreProductReviewData> reviews;
  final Color primaryColor;

  const StoreProductReviewsBlock({
    super.key,
    required this.reviews,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Avaliações e depoimentos',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 9),
          if (reviews.isEmpty) ...[
            Text(
              'As avaliações com fotos e vídeos aparecerão aqui após compra, envio do cliente e aprovação do lojista.',
              style: textRegular.copyWith(
                color: Colors.grey.shade700,
                fontSize: 12.8,
                height: 1.35,
              ),
            ),
          ] else ...[
            ...reviews.map((review) {
              return StoreProductReviewCard(
                review: review,
                primaryColor: primaryColor,
              );
            }),
          ],
        ],
      ),
    );
  }
}

class StoreProductReviewCard extends StatelessWidget {
  final StoreProductReviewData review;
  final Color primaryColor;

  const StoreProductReviewCard({
    super.key,
    required this.review,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        review.comment,
        style: textRegular.copyWith(
          color: Colors.grey.shade700,
          fontSize: 12.8,
          height: 1.35,
        ),
      ),
    );
  }
}

class StoreRelatedProductsBlock extends StatelessWidget {
  final List<StoreProductDetailsData> products;
  final Color primaryColor;
  final ScrollController carouselController;
  final ValueChanged<StoreProductDetailsData> onProductTap;

  const StoreRelatedProductsBlock({
    super.key,
    required this.products,
    required this.primaryColor,
    required this.carouselController,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mais produtos desta loja',
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 432,
          child: ListView.builder(
            controller: carouselController,
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final StoreProductDetailsData product = products[index];

              return StoreRelatedProductCard(
                product: product,
                primaryColor: primaryColor,
                onTap: () => onProductTap(product),
              );
            },
          ),
        ),
      ],
    );
  }
}

class StoreRelatedProductCard extends StatelessWidget {
  final StoreProductDetailsData product;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreRelatedProductCard({
    super.key,
    required this.product,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

    return Container(
      width: 182,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
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
                      child: StoreRelatedProductHeroImage(
                        imageUrl: product.mainImageUrl,
                        primaryColor: primaryColor,
                      ),
                    ),
                    if (product.hasPromotion)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: StoreRelatedDiscountBadge(
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
                        ProductDetailsMiniPrice(
                          product: product,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(height: 8),
                        StoreRelatedDeliveryInfo(
                            product: product, primaryColor: primaryColor),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
                StoreRelatedBottomActionStrip(
                  primaryColor: primaryColor,
                  label: product.actionLabel,
                  onTap: onTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StoreRelatedDiscountBadge extends StatelessWidget {
  final String discountLabel;

  const StoreRelatedDiscountBadge({
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

class StoreRelatedProductHeroImage extends StatelessWidget {
  final String imageUrl;
  final Color primaryColor;

  const StoreRelatedProductHeroImage({
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

class StoreRelatedDeliveryInfo extends StatelessWidget {
  final StoreProductDetailsData product;
  final Color primaryColor;

  const StoreRelatedDeliveryInfo({
    super.key,
    required this.product,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (product.isService) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Formato do serviço',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 11.4,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            product.serviceDeliveryLabel.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textBold.copyWith(
              color: primaryColor,
              fontSize: 10.8,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            product.shortServiceDeliveryDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textMedium.copyWith(
              color: Colors.grey.shade700,
              fontSize: 10.4,
              height: 1.12,
            ),
          ),
        ],
      );
    }

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

class StoreRelatedBottomActionStrip extends StatelessWidget {
  final Color primaryColor;
  final String label;
  final VoidCallback onTap;

  const StoreRelatedBottomActionStrip({
    super.key,
    required this.primaryColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}

class ProductDetailsMiniPrice extends StatelessWidget {
  final StoreProductDetailsData product;
  final Color primaryColor;

  const ProductDetailsMiniPrice({
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

class StoreProductFixedBottomBar extends StatelessWidget {
  final StoreProductDetailsData product;
  final Color primaryColor;
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onAddToCart;

  const StoreProductFixedBottomBar({
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
    final double total = product.finalPrice * quantity;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(26),
          ),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, -8),
              blurRadius: 24,
              color: Colors.black.withValues(alpha: 0.12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: product.mainImageUrl.isEmpty
                        ? Container(
                            color: primaryColor.withValues(alpha: 0.08),
                            child: Icon(
                              Icons.image_outlined,
                              color: primaryColor,
                              size: 24,
                            ),
                          )
                        : Image.network(
                            product.mainImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                color: primaryColor.withValues(alpha: 0.08),
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: primaryColor,
                                  size: 24,
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(width: 9),
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
                          fontSize: 12.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        StoreProductDetailsData.formatCurrency(total),
                        style: textBold.copyWith(
                          color: primaryColor,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                StoreQuantityControl(
                  quantity: quantity,
                  primaryColor: primaryColor,
                  onDecrease: onDecrease,
                  onIncrease: onIncrease,
                ),
              ],
            ),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: onAddToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: Text(
                  'Adicionar ao carrinho',
                  style: textBold.copyWith(
                    color: Colors.white,
                    fontSize: 13.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreQuantityControl extends StatelessWidget {
  final int quantity;
  final Color primaryColor;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const StoreQuantityControl({
    super.key,
    required this.quantity,
    required this.primaryColor,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onDecrease,
            child: SizedBox(
              width: 34,
              height: 36,
              child: Icon(
                Icons.remove_rounded,
                color: primaryColor,
                size: 18,
              ),
            ),
          ),
          SizedBox(
            width: 25,
            child: Text(
              quantity.toString(),
              textAlign: TextAlign.center,
              style: textBold.copyWith(
                color: Colors.black87,
                fontSize: 13.5,
              ),
            ),
          ),
          GestureDetector(
            onTap: onIncrease,
            child: SizedBox(
              width: 34,
              height: 36,
              child: Icon(
                Icons.add_rounded,
                color: primaryColor,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreProductCategoryData {
  final String id;
  final String parentId;
  final String name;
  final String slug;
  final String imageUrl;
  final List<StoreProductCategoryData> subcategories;

  StoreProductCategoryData({
    required this.id,
    required this.parentId,
    required this.name,
    required this.slug,
    required this.imageUrl,
    this.subcategories = const <StoreProductCategoryData>[],
  });

  factory StoreProductCategoryData.all() {
    return StoreProductCategoryData(
      id: '',
      parentId: '',
      name: 'Todos',
      slug: 'all',
      imageUrl: '',
    );
  }

  factory StoreProductCategoryData.allSubcategory() {
    return StoreProductCategoryData(
      id: '',
      parentId: '',
      name: 'Todas',
      slug: 'all_subcategories',
      imageUrl: '',
    );
  }

  factory StoreProductCategoryData.fromMap(Map<String, dynamic> map) {
    final dynamic subcategoriesValue = map['subcategories'];
    final List<dynamic> subcategoryList =
        subcategoriesValue is List ? subcategoriesValue : <dynamic>[];

    return StoreProductCategoryData(
      id: '${map['id'] ?? ''}',
      parentId: '${map['parent_id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      slug: '${map['slug'] ?? ''}',
      imageUrl: '${map['image_url'] ?? ''}',
      subcategories: subcategoryList
          .whereType<Map>()
          .map((item) => StoreProductCategoryData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((subcategory) => subcategory.id.isNotEmpty)
          .toList(),
    );
  }

  bool get isAll => id.isEmpty;
}

class StoreProductDetailsData {
  final String id;
  final String sellerId;
  final String title;
  final String slug;
  final String shortDescription;
  final String description;
  final double price;
  final double? promotionalPrice;
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
  final String storeCoverImageUrl;
  final String storeAddress;
  final String storePhone;
  final String storeEmail;
  final String availabilityType;
  final String availabilityLabel;
  final String productType;
  final String conditionType;
  final String serviceDeliveryType;

  StoreProductDetailsData({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.slug,
    required this.shortDescription,
    required this.description,
    required this.price,
    required this.promotionalPrice,
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
    required this.storeCoverImageUrl,
    required this.storeAddress,
    required this.storePhone,
    required this.storeEmail,
    required this.availabilityType,
    required this.availabilityLabel,
    required this.productType,
    required this.conditionType,
    required this.serviceDeliveryType,
  });

  factory StoreProductDetailsData.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> store = map['store'] is Map
        ? Map<String, dynamic>.from(map['store'])
        : <String, dynamic>{};

    final dynamic galleryValue = map['gallery'];
    final List<dynamic> galleryList =
        galleryValue is List ? galleryValue : <dynamic>[];

    final List<String> galleryImages = galleryList
        .whereType<Map>()
        .map((item) => '${item['image_url'] ?? ''}')
        .where((imageUrl) => imageUrl.isNotEmpty)
        .toList();

    final double price = parseDouble(map['price']);
    final double promotionalPrice = parseDouble(map['promotional_price']);
    final double finalPrice = parseDouble(map['final_price']);
    final bool hasPromotion = map['has_promotion'] == true &&
        promotionalPrice > 0 &&
        promotionalPrice < price;

    final String mainImageUrl = '${map['main_image_url'] ?? ''}';
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

    return StoreProductDetailsData(
      id: '${map['id'] ?? ''}',
      sellerId: '${map['seller_id'] ?? ''}',
      title: '${map['name'] ?? ''}',
      slug: '${map['slug'] ?? ''}',
      shortDescription: '${map['short_description'] ?? ''}',
      description: '${map['description'] ?? ''}',
      price: price,
      promotionalPrice: promotionalPrice > 0 ? promotionalPrice : null,
      finalPrice: finalPrice > 0 ? finalPrice : price,
      hasPromotion: hasPromotion,
      stock: int.tryParse('${map['stock'] ?? 0}') ?? 0,
      unit: '${map['unit'] ?? 'unidade'}',
      categoryId: '${map['category_id'] ?? ''}',
      category: '${map['category_name'] ?? ''}',
      mainImageUrl: mainImageUrl,
      galleryImages: galleryImages.isEmpty && mainImageUrl.isNotEmpty
          ? <String>[mainImageUrl]
          : galleryImages,
      storeName: '${store['name'] ?? ''}',
      storeLogoUrl: '${store['logo_url'] ?? ''}',
      storeCoverImageUrl: '${store['cover_image_url'] ?? ''}',
      storeAddress:
          '${store['address'] ?? store['store_address'] ?? store['full_address'] ?? ''}',
      storePhone:
          '${store['phone'] ?? store['contact_phone'] ?? store['business_phone'] ?? store['mobile'] ?? ''}',
      storeEmail: '${store['email'] ?? store['business_email'] ?? ''}',
      availabilityType: '${map['availability_type'] ?? 'immediate'}',
      availabilityLabel: '${map['availability_label'] ?? 'Imediata'}',
      productType: normalizedProductType,
      conditionType: '${map['condition_type'] ?? 'new'}'.trim().toLowerCase(),
      serviceDeliveryType:
          '${map['service_delivery_type'] ?? ''}'.trim().toLowerCase(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'seller_id': sellerId,
      'name': title,
      'slug': slug,
      'short_description': shortDescription,
      'description': description,
      'price': price,
      'promotional_price': promotionalPrice,
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
      'service_delivery_type': serviceDeliveryType,
      'store': <String, dynamic>{
        'id': sellerId,
        'name': storeName,
        'logo_url': storeLogoUrl,
        'cover_image_url': storeCoverImageUrl,
        'address': storeAddress,
        'phone': storePhone,
        'email': storeEmail,
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

  String get actionLabel => isService ? 'Ver serviço' : 'Ver oferta';

  String get serviceDeliveryLabel {
    switch (serviceDeliveryType) {
      case 'download':
        return 'Download';
      case 'presential':
      case 'presencial':
        return 'Presencial';
      case 'home_office':
      case 'homeoffice':
      case 'remote':
        return 'Home Office';
      case 'online':
        return 'Online';
      case 'digital':
        return 'Digital';
      default:
        return 'Digital';
    }
  }

  String get serviceDeliveryDescription {
    switch (serviceDeliveryType) {
      case 'download':
        return 'Serviço digital, entrega por download.';
      case 'presential':
      case 'presencial':
        return 'Serviço presencial, realizado em loco.';
      case 'home_office':
      case 'homeoffice':
      case 'remote':
        return 'Serviço digital, atendimento Home Office.';
      case 'online':
        return 'Serviço digital, entrega online.';
      case 'digital':
        return 'Serviço digital, entrega online.';
      default:
        return 'Serviço digital, entrega online.';
    }
  }

  String get shortServiceDeliveryDescription {
    switch (serviceDeliveryType) {
      case 'download':
        return 'Serviço digital, entrega por download.';
      case 'presential':
      case 'presencial':
        return 'Serviço presencial, realizado em loco.';
      case 'home_office':
      case 'homeoffice':
      case 'remote':
        return 'Serviço digital, atendimento Home Office.';
      case 'online':
        return 'Serviço digital, entrega online.';
      default:
        return 'Serviço digital, entrega online.';
    }
  }

  IconData get serviceDeliveryIcon {
    switch (serviceDeliveryType) {
      case 'download':
        return Icons.download_rounded;
      case 'presential':
      case 'presencial':
        return Icons.storefront_rounded;
      case 'home_office':
      case 'homeoffice':
      case 'remote':
        return Icons.home_work_outlined;
      case 'online':
      case 'digital':
      default:
        return Icons.language_rounded;
    }
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

class StoreProductReviewData {
  final String id;
  final String customerName;
  final String comment;
  final int rating;
  final List<String> mediaUrls;

  StoreProductReviewData({
    required this.id,
    required this.customerName,
    required this.comment,
    required this.rating,
    required this.mediaUrls,
  });

  factory StoreProductReviewData.fromMap(Map<String, dynamic> map) {
    final dynamic mediaValue = map['media_urls'];
    final List<dynamic> mediaList =
        mediaValue is List ? mediaValue : <dynamic>[];

    return StoreProductReviewData(
      id: '${map['id'] ?? ''}',
      customerName: '${map['customer_name'] ?? ''}',
      comment: '${map['comment'] ?? ''}',
      rating: int.tryParse('${map['rating'] ?? 0}') ?? 0,
      mediaUrls: mediaList.map((item) => '$item').toList(),
    );
  }
}
