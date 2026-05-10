import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/store/screens/seller/store_seller_dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_seller_registration_screen.dart';
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

  int selectedCategoryIndex = 0;
  String searchQuery = '';
  bool isCheckingSellerStatus = false;

  final ScrollController welcomeCarouselController = ScrollController();
  Timer? welcomeCarouselTimer;

  final List<String> categories = const [
    'Todos',
    'Beleza',
    'Para casa',
    'Para escritório',
    'Brinquedos',
    'Vestuário',
    'Eletrônicos',
  ];

  final List<StoreProductData> welcomeProducts = [
    StoreProductData(
      title: 'Perfume Premium Local',
      price: '89,90',
      oldPrice: '129,90',
      city: 'Três Corações',
      category: 'Beleza',
      hasFlashOffer: true,
    ),
    StoreProductData(
      title: 'Kit Beleza',
      price: '59,90',
      oldPrice: '89,90',
      city: 'Três Corações',
      category: 'Beleza',
      hasFlashOffer: true,
    ),
    StoreProductData(
      title: 'Body Splash',
      price: '49,90',
      oldPrice: '79,90',
      city: 'Três Corações',
      category: 'Beleza',
      hasFlashOffer: false,
    ),
  ];

  final List<StoreProductData> products = [
    StoreProductData(
      title: 'Perfume Premium Local',
      price: '89,90',
      oldPrice: '129,90',
      city: 'Três Corações',
      category: 'Beleza',
      hasFlashOffer: true,
    ),
    StoreProductData(
      title: 'Camiseta Estilo Premium',
      price: '59,90',
      oldPrice: '89,90',
      city: 'Três Corações',
      category: 'Vestuário',
      hasFlashOffer: false,
    ),
    StoreProductData(
      title: 'Kit Beleza e Cuidados',
      price: '74,90',
      oldPrice: '109,90',
      city: 'Três Corações',
      category: 'Beleza',
      hasFlashOffer: true,
    ),
    StoreProductData(
      title: 'Acessório Tech',
      price: '149,00',
      oldPrice: '229,00',
      city: 'Três Corações',
      category: 'Eletrônicos',
      hasFlashOffer: false,
    ),
    StoreProductData(
      title: 'Item Casa & Decoração',
      price: '69,90',
      oldPrice: '99,90',
      city: 'Três Corações',
      category: 'Para casa',
      hasFlashOffer: false,
    ),
    StoreProductData(
      title: 'Produto Escritório',
      price: '39,90',
      oldPrice: '59,90',
      city: 'Três Corações',
      category: 'Para escritório',
      hasFlashOffer: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    startWelcomeCarousel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      final double nextScroll = currentScroll + 180;

      welcomeCarouselController.animateTo(
        nextScroll >= maxScroll ? 0 : nextScroll,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOut,
      );
    });
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
        return;
      }

      final String approvalStatus = '${data['approval_status'] ?? ''}';
      final bool canCreateProducts = data['can_create_products'] == true;

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

      if (approvalStatus == 'approved' && canCreateProducts) {
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

  List<StoreProductData> get visibleProducts {
    final String selectedCategory = categories[selectedCategoryIndex];

    if (selectedCategory == 'Todos') {
      return products;
    }

    return products
        .where((product) => product.category == selectedCategory)
        .toList();
  }

  List<StoreProductData> get searchResults {
    final String query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return [];
    }

    return products.where((product) {
      return product.title.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
    }).toList();
  }

  void handleProductTap(StoreProductData product) {}

  void handleSimpleTap() {}

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              StoreHeader(
                primaryColor: primaryColor,
                onSearchChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                onCartTap: handleSimpleTap,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    Dimensions.paddingSizeDefault,
                    14,
                    Dimensions.paddingSizeDefault,
                    150,
                  ),
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
                      StoreCategoryMenu(
                        categories: categories,
                        selectedIndex: selectedCategoryIndex,
                        primaryColor: primaryColor,
                        onSelected: (index) {
                          setState(() {
                            selectedCategoryIndex = index;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      StoreBanner(
                        onTap: handleSimpleTap,
                      ),
                      const SizedBox(height: 18),
                      StoreSectionHeader(
                        title: 'Ofertas de boas-vindas',
                        badge: 'Até 30% OFF',
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 334,
                        child: ListView.builder(
                          controller: welcomeCarouselController,
                          scrollDirection: Axis.horizontal,
                          itemCount: welcomeProducts.length,
                          itemBuilder: (context, index) {
                            return WelcomeOfferCard(
                              product: welcomeProducts[index],
                              primaryColor: primaryColor,
                              onTap: () =>
                                  handleProductTap(welcomeProducts[index]),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Produtos em destaque',
                        style: textBold.copyWith(
                          color: textColor,
                          fontSize: 21,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: visibleProducts.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 334,
                        ),
                        itemBuilder: (context, index) {
                          final StoreProductData product =
                              visibleProducts[index];

                          return StoreProductCard(
                            product: product,
                            primaryColor: primaryColor,
                            onTap: () => handleProductTap(product),
                          );
                        },
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
            child: StoreFloatingSellButton(
              primaryColor: primaryColor,
              isLoading: isCheckingSellerStatus,
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
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'assets/image/produto.webp',
                fit: BoxFit.contain,
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
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        'De R\$${product.oldPrice}',
                        maxLines: 1,
                        style: textMedium.copyWith(
                          color: Colors.redAccent,
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Por R\$${product.price}',
                        maxLines: 1,
                        style: textBold.copyWith(
                          color: primaryColor,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
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

class StoreCategoryMenu extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final Color primaryColor;
  final ValueChanged<int> onSelected;

  const StoreCategoryMenu({
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
          return StoreCategoryItem(
            label: categories[index],
            isSelected: index == selectedIndex,
            primaryColor: primaryColor,
            onTap: () => onSelected(index),
          );
        },
      ),
    );
  }
}

class StoreCategoryItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreCategoryItem({
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
  final VoidCallback onTap;

  const StoreBanner({
    super.key,
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
          child: Image.asset(
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
      width: 168,
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
              SizedBox(
                height: 122,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                  child: Image.asset(
                    'assets/image/produto.webp',
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 33,
                        child: Text(
                          product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textBold.copyWith(
                            color: textColor,
                            fontSize: 14.3,
                            height: 1.12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      StorePriceAndRatingBlock(
                        oldPrice: product.oldPrice,
                        price: product.price,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 10),
                      StoreDeliveryInfo(
                        city: product.city,
                        primaryColor: primaryColor,
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              StoreBottomActionStrip(
                primaryColor: primaryColor,
                label:
                    product.hasFlashOffer ? 'OFERTA RELÂMPAGO' : 'SAIBA MAIS',
                isFlashOffer: product.hasFlashOffer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StorePriceAndRatingBlock extends StatelessWidget {
  final String oldPrice;
  final String price;
  final Color primaryColor;

  const StorePriceAndRatingBlock({
    super.key,
    required this.oldPrice,
    required this.price,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'De R\$$oldPrice',
                  maxLines: 1,
                  style: textMedium.copyWith(
                    color: Colors.redAccent,
                    fontSize: 11.2,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Por R\$$price',
                  maxLines: 1,
                  style: textBold.copyWith(
                    color: primaryColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const StoreRatingBadge(),
      ],
    );
  }
}

class StoreRatingBadge extends StatelessWidget {
  const StoreRatingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.star_rounded,
            color: Color(0xFFFFC400),
            size: 15,
          ),
          const SizedBox(width: 3),
          Text(
            '4.5',
            style: textBold.copyWith(
              color: const Color(0xFF5E4A00),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreDeliveryInfo extends StatelessWidget {
  final String city;
  final Color primaryColor;

  const StoreDeliveryInfo({
    super.key,
    required this.city,
    required this.primaryColor,
  });

  String _firstPart() {
    final List<String> parts = city.trim().split(' ');
    if (parts.isEmpty) {
      return city;
    }
    return parts.first;
  }

  String _remainingPart() {
    final List<String> parts = city.trim().split(' ');
    if (parts.length <= 1) {
      return '';
    }
    return parts.sublist(1).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final String firstPart = _firstPart();
    final String remainingPart = _remainingPart();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'RETIRE GRÁTIS',
                style: textBold.copyWith(
                  color: primaryColor,
                  fontSize: 11.2,
                  height: 1.12,
                ),
              ),
              TextSpan(
                text: ' em $firstPart',
                style: textMedium.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 11.2,
                  height: 1.12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Text(
          remainingPart.isNotEmpty ? '$remainingPart ou...' : 'ou...',
          style: textMedium.copyWith(
            color: Colors.grey.shade700,
            fontSize: 11.2,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 1),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'RECEBA EM CASA',
                style: textBold.copyWith(
                  color: primaryColor,
                  fontSize: 11.0,
                  height: 1.12,
                ),
              ),
              TextSpan(
                text: ' à',
                style: textMedium.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 11.0,
                  height: 1.12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'partir de ',
                style: textMedium.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 11.0,
                  height: 1.12,
                ),
              ),
              TextSpan(
                text: 'R\$8,00',
                style: textBold.copyWith(
                  color: Colors.grey.shade800,
                  fontSize: 11.0,
                  height: 1.12,
                ),
              ),
              TextSpan(
                text: ' o FRETE',
                style: textMedium.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 11.0,
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
  final bool isFlashOffer;

  const StoreBottomActionStrip({
    super.key,
    required this.primaryColor,
    required this.label,
    required this.isFlashOffer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: EdgeInsets.symmetric(
        horizontal: isFlashOffer ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: isFlashOffer
          ? Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFFFD400),
                  size: 16,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    'OFERTA RELÂMPAGO',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.visible,
                    style: textBold.copyWith(
                      color: Colors.white,
                      fontSize: 11.2,
                      letterSpacing: 0.05,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFFFD400),
                  size: 16,
                ),
              ],
            )
          : Center(
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: textBold.copyWith(
                  color: Colors.white,
                  fontSize: 11.2,
                  letterSpacing: 0.2,
                ),
              ),
            ),
    );
  }
}

class StoreFloatingSellButton extends StatelessWidget {
  final Color primaryColor;
  final bool isLoading;
  final VoidCallback onTap;

  const StoreFloatingSellButton({
    super.key,
    required this.primaryColor,
    required this.isLoading,
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
                const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
              const SizedBox(width: 7),
              Text(
                isLoading ? 'Verificando' : 'Vender',
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

class StoreProductData {
  final String title;
  final String price;
  final String oldPrice;
  final String city;
  final String category;
  final bool hasFlashOffer;

  StoreProductData({
    required this.title,
    required this.price,
    required this.oldPrice,
    required this.city,
    required this.category,
    this.hasFlashOffer = false,
  });
}
