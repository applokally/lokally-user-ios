import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

import 'store_seller_product_list_screen.dart';
import 'store_seller_order_list_screen.dart';
import 'store_seller_products_screen.dart';

class StoreSellerDashboardScreen extends StatefulWidget {
  const StoreSellerDashboardScreen({super.key});

  @override
  State<StoreSellerDashboardScreen> createState() =>
      _StoreSellerDashboardScreenState();
}

class _StoreSellerDashboardScreenState
    extends State<StoreSellerDashboardScreen> {
  static const String storeSellerMediaUri = '/api/customer/store/seller/media';

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  String storeName = 'Moments Paris';
  String? logoUrl;
  String? coverImageUrl;

  bool isLoadingSeller = false;
  bool isUploadingLogo = false;
  bool isUploadingCover = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadSellerData();
    });
  }

  Future<void> loadSellerData() async {
    if (isLoadingSeller) {
      return;
    }

    setState(() {
      isLoadingSeller = true;
    });

    final Response response =
        await Get.find<ApiClient>().getData(AppConstants.storeSellerStatus);

    if (!mounted) {
      return;
    }

    setState(() {
      isLoadingSeller = false;
    });

    final dynamic body = response.body;

    if (response.statusCode != 200 || body is! Map) {
      return;
    }

    final dynamic dataValue = body['data'];
    final Map<String, dynamic> data = dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : <String, dynamic>{};

    final dynamic sellerValue = data['seller'];
    final Map<String, dynamic> seller = sellerValue is Map
        ? Map<String, dynamic>.from(sellerValue)
        : <String, dynamic>{};

    updateSellerStateFromMap(seller);
  }

  void updateSellerStateFromMap(Map<String, dynamic> seller) {
    final String newStoreName = '${seller['store_name'] ?? ''}'.trim();
    final String newLogoUrl = '${seller['logo_url'] ?? ''}'.trim();
    final String newCoverUrl = '${seller['cover_image_url'] ?? ''}'.trim();

    setState(() {
      if (newStoreName.isNotEmpty) {
        storeName = newStoreName;
      }

      logoUrl = newLogoUrl.isNotEmpty ? newLogoUrl : null;
      coverImageUrl = newCoverUrl.isNotEmpty ? newCoverUrl : null;
    });
  }

  Future<void> pickAndUploadStoreMedia({required bool isCover}) async {
    final XFile? pickedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: AppConstants.imageQuality,
    );

    if (pickedImage == null) {
      return;
    }

    setState(() {
      if (isCover) {
        isUploadingCover = true;
      } else {
        isUploadingLogo = true;
      }
    });

    final Response response = await Get.find<ApiClient>().postMultipartData(
      storeSellerMediaUri,
      <String, String>{},
      MultipartBody(isCover ? 'cover_image' : 'logo', pickedImage),
      <MultipartBody>[],
    );

    if (!mounted) {
      return;
    }

    setState(() {
      if (isCover) {
        isUploadingCover = false;
      } else {
        isUploadingLogo = false;
      }
    });

    final dynamic body = response.body;

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        body is Map &&
        body['status'] == true) {
      final dynamic dataValue = body['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic sellerValue = data['seller'];
      final Map<String, dynamic> seller = sellerValue is Map
          ? Map<String, dynamic>.from(sellerValue)
          : <String, dynamic>{};

      updateSellerStateFromMap(seller);

      showStoreMessage(
        isCover
            ? 'Capa da loja atualizada com sucesso.'
            : 'Logo da loja atualizada com sucesso.',
      );
      return;
    }

    String message = isCover
        ? 'Não foi possível atualizar a capa da loja.'
        : 'Não foi possível atualizar a logo da loja.';

    if (body is Map && body['message'] != null) {
      message = body['message'].toString();
    }

    showStoreMessage(message);
  }

  void openSellerSection(BuildContext context, String title) {
    if (title == 'Produtos') {
      Get.to(() => const StoreSellerProductListScreen());
      return;
    }

    if (title == 'Impulsionar') {
      Get.to(() => const StoreSellerBoostScreen());
      return;
    }

    if (title == 'Pedidos') {
      Get.to(() => const StoreSellerOrderListScreen());
      return;
    }

    handleComingSoon(context, title);
  }

  void openCreateProductScreen(BuildContext context, String title) {
    if (title == 'Produtos') {
      Get.to(() => const StoreSellerProductsScreen());
      return;
    }

    if (title == 'Impulsionar') {
      Get.to(() => const StoreSellerBoostScreen());
      return;
    }

    if (title == 'Pedidos') {
      Get.to(() => const StoreSellerOrderListScreen());
      return;
    }

    handleComingSoon(context, title);
  }

  void handleComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title será criado no próximo passo.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void showStoreMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFFF4F6F6),
      drawer: StoreSellerDrawer(
        primaryColor: primaryColor,
        storeName: storeName,
        onMenuTap: (title) {
          Navigator.of(context).pop();

          if (title == 'Dashboard') {
            return;
          }

          if (title == 'Voltar para a Loja') {
            Get.back();
            return;
          }

          openSellerSection(context, title);
        },
      ),
      body: Column(
        children: [
          StoreSellerTopBar(
            primaryColor: primaryColor,
            onMenuTap: () => scaffoldKey.currentState?.openDrawer(),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  StoreSellerProfileHeader(
                    primaryColor: primaryColor,
                    storeName: storeName,
                    logoUrl: logoUrl,
                    coverImageUrl: coverImageUrl,
                    isUploadingCover: isUploadingCover,
                    isUploadingLogo: isUploadingLogo,
                    onCoverTap: () => pickAndUploadStoreMedia(isCover: true),
                    onLogoTap: () => pickAndUploadStoreMedia(isCover: false),
                    onBackToStoreTap: () => Get.back(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Dimensions.paddingSizeDefault,
                      16,
                      Dimensions.paddingSizeDefault,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StoreSellerMainKpiGrid(
                          primaryColor: primaryColor,
                          onKpiTap: (title) =>
                              openSellerSection(context, title),
                        ),
                        const SizedBox(height: 16),
                        StoreSellerSalesChart(primaryColor: primaryColor),
                        const SizedBox(height: 16),
                        StoreSellerFinancialCard(
                          primaryColor: primaryColor,
                          onTap: () => handleComingSoon(
                            context,
                            'Detalhes de repasse',
                          ),
                        ),
                        const SizedBox(height: 16),
                        StoreSellerQuickMenu(
                          primaryColor: primaryColor,
                          onMenuTap: (title) =>
                              openCreateProductScreen(context, title),
                        ),
                        const SizedBox(height: 16),
                        StoreSellerLatestSales(
                          primaryColor: primaryColor,
                          onTapSale: (title) =>
                              handleComingSoon(context, 'Venda: $title'),
                          onViewAllTap: () =>
                              openSellerSection(context, 'Pedidos'),
                        ),
                        const SizedBox(height: 16),
                        StoreSellerOperationalSummary(
                          primaryColor: primaryColor,
                          onItemTap: (title) =>
                              handleComingSoon(context, title),
                        ),
                      ],
                    ),
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

class StoreSellerTopBar extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onMenuTap;

  const StoreSellerTopBar({
    super.key,
    required this.primaryColor,
    required this.onMenuTap,
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
            onTap: onMenuTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.menu_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Painel do vendedor',
              style: textBold.copyWith(
                color: Colors.white,
                fontSize: 19,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerProfileHeader extends StatelessWidget {
  final Color primaryColor;
  final String storeName;
  final String? logoUrl;
  final String? coverImageUrl;
  final bool isUploadingCover;
  final bool isUploadingLogo;
  final VoidCallback onCoverTap;
  final VoidCallback onLogoTap;
  final VoidCallback onBackToStoreTap;

  const StoreSellerProfileHeader({
    super.key,
    required this.primaryColor,
    required this.storeName,
    required this.logoUrl,
    required this.coverImageUrl,
    required this.isUploadingCover,
    required this.isUploadingLogo,
    required this.onCoverTap,
    required this.onLogoTap,
    required this.onBackToStoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              GestureDetector(
                onTap: isUploadingCover ? null : onCoverTap,
                child: SizedBox(
                  width: double.infinity,
                  height: 178,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: StoreSellerCoverView(
                          primaryColor: primaryColor,
                          coverImageUrl: coverImageUrl,
                        ),
                      ),
                      Positioned(
                        right: -18,
                        top: -18,
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 128,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      Positioned(
                        right: 16,
                        top: 18,
                        child: StoreSellerMediaButton(
                          label: isUploadingCover ? 'Enviando' : 'Capa',
                          icon: isUploadingCover
                              ? Icons.hourglass_empty_rounded
                              : Icons.photo_camera_outlined,
                          primaryColor: primaryColor,
                        ),
                      ),
                      if (isUploadingCover)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.22),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.4,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 56, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(0, 8),
                      blurRadius: 20,
                      color: Colors.black.withValues(alpha: 0.04),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 19,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: primaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Aprovada',
                                style: textBold.copyWith(
                                  color: primaryColor,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: onBackToStoreTap,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back_rounded,
                                color: primaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Voltar para a loja',
                                style: textBold.copyWith(
                                  color: primaryColor,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 18,
            top: 134,
            child: GestureDetector(
              onTap: isUploadingLogo ? null : onLogoTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                          color: Colors.black.withValues(alpha: 0.14),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: StoreSellerLogoView(
                            primaryColor: primaryColor,
                            logoUrl: logoUrl,
                            isUploadingLogo: isUploadingLogo,
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryColor,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        isUploadingLogo
                            ? Icons.hourglass_empty_rounded
                            : Icons.photo_camera_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
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

class StoreSellerCoverView extends StatelessWidget {
  final Color primaryColor;
  final String? coverImageUrl;

  const StoreSellerCoverView({
    super.key,
    required this.primaryColor,
    required this.coverImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (coverImageUrl != null && coverImageUrl!.isNotEmpty) {
      return Image.network(
        coverImageUrl!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return StoreSellerCoverFallback(primaryColor: primaryColor);
        },
      );
    }

    return StoreSellerCoverFallback(primaryColor: primaryColor);
  }
}

class StoreSellerCoverFallback extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerCoverFallback({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withValues(alpha: 0.72),
            const Color(0xFF0B4B45),
          ],
        ),
      ),
    );
  }
}

class StoreSellerLogoView extends StatelessWidget {
  final Color primaryColor;
  final String? logoUrl;
  final bool isUploadingLogo;

  const StoreSellerLogoView({
    super.key,
    required this.primaryColor,
    required this.logoUrl,
    required this.isUploadingLogo,
  });

  @override
  Widget build(BuildContext context) {
    if (isUploadingLogo) {
      return ClipOval(
        child: Container(
          color: primaryColor.withValues(alpha: 0.10),
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 2.4,
              ),
            ),
          ),
        ),
      );
    }

    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          logoUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) {
            return StoreSellerLogoFallback(primaryColor: primaryColor);
          },
        ),
      );
    }

    return StoreSellerLogoFallback(primaryColor: primaryColor);
  }
}

class StoreSellerLogoFallback extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerLogoFallback({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        color: primaryColor.withValues(alpha: 0.10),
        child: Icon(
          Icons.storefront_rounded,
          color: primaryColor,
          size: 38,
        ),
      ),
    );
  }
}

class StoreSellerMediaButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color primaryColor;

  const StoreSellerMediaButton({
    super.key,
    required this.label,
    required this.icon,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: primaryColor,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: textBold.copyWith(
              color: primaryColor,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerMainKpiGrid extends StatelessWidget {
  final Color primaryColor;
  final ValueChanged<String> onKpiTap;

  const StoreSellerMainKpiGrid({
    super.key,
    required this.primaryColor,
    required this.onKpiTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<StoreSellerKpiData> items = [
      StoreSellerKpiData(
        title: 'Vendas hoje',
        value: 'R\$0,00',
        icon: Icons.payments_outlined,
      ),
      StoreSellerKpiData(
        title: 'Pedidos',
        value: '0',
        icon: Icons.receipt_long_outlined,
      ),
      StoreSellerKpiData(
        title: 'Cancelados',
        value: '0',
        icon: Icons.cancel_outlined,
      ),
      StoreSellerKpiData(
        title: 'Repasse',
        value: 'R\$0,00',
        icon: Icons.account_balance_wallet_outlined,
      ),
    ];

    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 104,
      ),
      itemBuilder: (context, index) {
        final StoreSellerKpiData item = items[index];

        return StoreSellerKpiCard(
          item: item,
          primaryColor: primaryColor,
          onTap: () => onKpiTap(item.title),
        );
      },
    );
  }
}

class StoreSellerKpiCard extends StatelessWidget {
  final StoreSellerKpiData item;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreSellerKpiCard({
    super.key,
    required this.item,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  item.icon,
                  color: primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 16.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11.6,
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

class StoreSellerSalesChart extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerSalesChart({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final List<int> values = [18, 32, 24, 44, 36, 58, 42];
    final List<String> labels = [
      'Seg',
      'Ter',
      'Qua',
      'Qui',
      'Sex',
      'Sáb',
      'Dom'
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StoreSellerSectionHeader(
            title: 'Gráfico de vendas',
            action: '7 dias',
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 6),
          Text(
            'Acompanhe a evolução das vendas da sua loja.',
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 12.3,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (index) {
                final int value = values[index];
                final double height = 32 + (value * 1.25);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: height,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: index == 5
                                ? primaryColor
                                : primaryColor.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          labels[index],
                          style: textMedium.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 10.5,
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
      ),
    );
  }
}

class StoreSellerFinancialCard extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreSellerFinancialCard({
    super.key,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0D3D38),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 10),
                blurRadius: 22,
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StoreSellerSectionHeader(
                title: 'Repasse a receber',
                action: 'Lokally Pay',
                primaryColor: Colors.white,
                isDark: true,
              ),
              const SizedBox(height: 10),
              Text(
                'R\$0,00',
                style: textBold.copyWith(
                  color: Colors.white,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Valores pagos pelo cliente via app com Lokally Pay e que serão repassados ao vendedor após o fechamento.',
                style: textRegular.copyWith(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: StoreSellerMiniDarkInfo(
                      title: 'Disponível',
                      value: 'R\$0,00',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StoreSellerMiniDarkInfo(
                      title: 'Em análise',
                      value: 'R\$0,00',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreSellerMiniDarkInfo extends StatelessWidget {
  final String title;
  final String value;

  const StoreSellerMiniDarkInfo({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: textBold.copyWith(
              color: Colors.white,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: textRegular.copyWith(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerQuickMenu extends StatelessWidget {
  final Color primaryColor;
  final ValueChanged<String> onMenuTap;

  const StoreSellerQuickMenu({
    super.key,
    required this.primaryColor,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<StoreSellerMenuData> items = [
      StoreSellerMenuData(
        title: 'Produtos',
        description: 'Cadastrar e editar produtos',
        icon: Icons.add_box_outlined,
      ),
      StoreSellerMenuData(
        title: 'Impulsionar',
        description: 'Destaque sua loja e produtos',
        icon: Icons.rocket_launch_outlined,
        highlighted: true,
      ),
      StoreSellerMenuData(
        title: 'Pedidos',
        description: 'Acompanhar vendas recebidas',
        icon: Icons.shopping_bag_outlined,
      ),
      StoreSellerMenuData(
        title: 'Ofertas',
        description: 'Criar promoções e destaques',
        icon: Icons.local_offer_outlined,
      ),
      StoreSellerMenuData(
        title: 'Entrega e retirada',
        description: 'Frete, retirada e Frete Lokally',
        icon: Icons.delivery_dining_outlined,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          StoreSellerSectionHeader(
            title: 'Atalhos da loja',
            action: 'Menu',
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 12),
          GridView.builder(
            padding: EdgeInsets.zero,
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 118,
            ),
            itemBuilder: (context, index) {
              final StoreSellerMenuData item = items[index];

              return StoreSellerShortcutCard(
                item: item,
                primaryColor: primaryColor,
                onTap: () => onMenuTap(item.title),
              );
            },
          ),
        ],
      ),
    );
  }
}

class StoreSellerShortcutCard extends StatelessWidget {
  final StoreSellerMenuData item;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreSellerShortcutCard({
    super.key,
    required this.item,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool highlighted = item.highlighted;
    final Color backgroundColor =
        highlighted ? primaryColor : primaryColor.withValues(alpha: 0.06);
    final Color iconColor = highlighted ? Colors.white : primaryColor;
    final Color titleColor = highlighted ? Colors.white : Colors.black87;
    final Color descriptionColor = highlighted
        ? Colors.white.withValues(alpha: 0.80)
        : Colors.grey.shade600;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: primaryColor.withValues(alpha: 0.10),
        highlightColor: primaryColor.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.icon,
                color: iconColor,
                size: highlighted ? 26 : 24,
              ),
              const Spacer(),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textBold.copyWith(
                  color: titleColor,
                  fontSize: 13.6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textRegular.copyWith(
                  color: descriptionColor,
                  fontSize: 11.2,
                  height: 1.18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreSellerLatestSales extends StatelessWidget {
  final Color primaryColor;
  final ValueChanged<String> onTapSale;
  final VoidCallback onViewAllTap;

  const StoreSellerLatestSales({
    super.key,
    required this.primaryColor,
    required this.onTapSale,
    required this.onViewAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<StoreSellerSaleData> sales = [
      StoreSellerSaleData(
        product: 'Perfume Premium Local',
        status: 'Pago no app',
        value: 'R\$89,90',
        time: 'Hoje',
      ),
      StoreSellerSaleData(
        product: 'Kit Beleza e Cuidados',
        status: 'Aguardando retirada',
        value: 'R\$74,90',
        time: 'Ontem',
      ),
      StoreSellerSaleData(
        product: 'Acessório Tech',
        status: 'Cancelado',
        value: 'R\$149,00',
        time: 'Ontem',
        isCancelled: true,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          StoreSellerSectionHeader(
            title: 'Últimas vendas',
            action: 'Ver todas',
            primaryColor: primaryColor,
            onActionTap: onViewAllTap,
          ),
          const SizedBox(height: 10),
          ...sales.map(
            (sale) => StoreSellerSaleTile(
              sale: sale,
              primaryColor: primaryColor,
              onTap: () => onTapSale(sale.product),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerSaleTile extends StatelessWidget {
  final StoreSellerSaleData sale;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreSellerSaleTile({
    super.key,
    required this.sale,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor =
        sale.isCancelled ? Colors.redAccent : primaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade100),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  sale.isCancelled
                      ? Icons.cancel_outlined
                      : Icons.shopping_bag_outlined,
                  color: statusColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.product,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 13.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${sale.status} • ${sale.time}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                sale.value,
                style: textBold.copyWith(
                  color: sale.isCancelled ? Colors.redAccent : Colors.black87,
                  fontSize: 12.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreSellerOperationalSummary extends StatelessWidget {
  final Color primaryColor;
  final ValueChanged<String> onItemTap;

  const StoreSellerOperationalSummary({
    super.key,
    required this.primaryColor,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StoreSellerOperationalCard(
            title: 'Cancelados',
            value: '0',
            description: 'Pedidos cancelados',
            icon: Icons.remove_shopping_cart_outlined,
            primaryColor: primaryColor,
            alertColor: Colors.redAccent,
            onTap: () => onItemTap('Cancelados'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StoreSellerOperationalCard(
            title: 'Frete Lokally',
            value: 'Ativo',
            description: 'Entrega via rede Lokally',
            icon: Icons.local_shipping_outlined,
            primaryColor: primaryColor,
            onTap: () => onItemTap('Frete Lokally'),
          ),
        ),
      ],
    );
  }
}

class StoreSellerOperationalCard extends StatelessWidget {
  final String title;
  final String value;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color? alertColor;
  final VoidCallback onTap;

  const StoreSellerOperationalCard({
    super.key,
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.onTap,
    this.alertColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = alertColor ?? primaryColor;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 134),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 16.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 12.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textRegular.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 11.2,
                  height: 1.22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreSellerSectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final Color primaryColor;
  final bool isDark;
  final VoidCallback? onActionTap;

  const StoreSellerSectionHeader({
    super.key,
    required this.title,
    required this.action,
    required this.primaryColor,
    this.isDark = false,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: textBold.copyWith(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16.5,
            ),
          ),
        ),
        GestureDetector(
          onTap: onActionTap,
          child: Text(
            action,
            style: textBold.copyWith(
              color:
                  isDark ? Colors.white.withValues(alpha: 0.80) : primaryColor,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class StoreSellerDrawer extends StatelessWidget {
  final Color primaryColor;
  final String storeName;
  final ValueChanged<String> onMenuTap;

  const StoreSellerDrawer({
    super.key,
    required this.primaryColor,
    required this.storeName,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<StoreSellerMenuData> drawerItems = [
      StoreSellerMenuData(
        title: 'Dashboard',
        description: 'Visão geral da loja',
        icon: Icons.dashboard_outlined,
      ),
      StoreSellerMenuData(
        title: 'Produtos',
        description: 'Cadastrar e editar produtos',
        icon: Icons.inventory_2_outlined,
      ),
      StoreSellerMenuData(
        title: 'Impulsionar',
        description: 'Anuncie loja, produtos ou categoria',
        icon: Icons.rocket_launch_outlined,
        highlighted: true,
      ),
      StoreSellerMenuData(
        title: 'Pedidos',
        description: 'Pedidos e status de venda',
        icon: Icons.receipt_long_outlined,
      ),
      StoreSellerMenuData(
        title: 'Ofertas e promoções',
        description: 'Promoções, cupons e destaques',
        icon: Icons.local_offer_outlined,
      ),
      StoreSellerMenuData(
        title: 'Entrega e retirada',
        description: 'Retirada, entrega própria e Frete Lokally',
        icon: Icons.delivery_dining_outlined,
      ),
      StoreSellerMenuData(
        title: 'Dados da loja',
        description: 'Logo, capa e perfil comercial',
        icon: Icons.store_mall_directory_outlined,
      ),
      StoreSellerMenuData(
        title: 'Financeiro',
        description: 'Taxas, repasses e bloqueios',
        icon: Icons.account_balance_wallet_outlined,
      ),
      StoreSellerMenuData(
        title: 'Voltar para a Loja',
        description: 'Retornar ao marketplace',
        icon: Icons.arrow_back_rounded,
      ),
    ];

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: primaryColor,
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textBold.copyWith(
                            color: Colors.white,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Painel do vendedor',
                          style: textRegular.copyWith(
                            color: Colors.white.withValues(alpha: 0.80),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: drawerItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final StoreSellerMenuData item = drawerItems[index];

                  final bool highlighted = item.highlighted;
                  final Color tileColor = highlighted
                      ? primaryColor.withValues(alpha: 0.10)
                      : Colors.transparent;
                  final Color iconColor =
                      highlighted ? primaryColor : primaryColor;
                  final Color titleColor =
                      highlighted ? primaryColor : Colors.black87;

                  return Container(
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(16),
                      border: highlighted
                          ? Border.all(
                              color: primaryColor.withValues(alpha: 0.22))
                          : null,
                    ),
                    child: ListTile(
                      onTap: () => onMenuTap(item.title),
                      minLeadingWidth: 36,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: Icon(
                        item.icon,
                        color: iconColor,
                        size: highlighted ? 24 : 22,
                      ),
                      title: Text(
                        item.title,
                        style: textBold.copyWith(
                          color: titleColor,
                          fontSize: 13.5,
                        ),
                      ),
                      subtitle: Text(
                        item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textRegular.copyWith(
                          color: highlighted
                              ? primaryColor.withValues(alpha: 0.78)
                              : Colors.grey.shade600,
                          fontSize: 11.2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreSellerBoostScreen extends StatefulWidget {
  const StoreSellerBoostScreen({super.key});

  @override
  State<StoreSellerBoostScreen> createState() => _StoreSellerBoostScreenState();
}

class _StoreSellerBoostScreenState extends State<StoreSellerBoostScreen> {
  static const String boostPlansUri = '/api/customer/store/boost/plans';
  static const String boostOptionsUri = '/api/customer/store/boost/options';
  static const String boostRequestsUri = '/api/customer/store/boost/requests';
  static const String boostCreateRequestUri =
      '/api/customer/store/boost/request';

  bool isLoading = false;
  bool isActionLoading = false;

  List<StoreSellerBoostPlanData> mainBannerPlans = <StoreSellerBoostPlanData>[];
  List<StoreSellerBoostPlanData> productPlans = <StoreSellerBoostPlanData>[];
  List<StoreSellerBoostPlanData> categoryPlans = <StoreSellerBoostPlanData>[];
  List<StoreSellerBoostRequestData> boostRequests =
      <StoreSellerBoostRequestData>[];
  List<StoreSellerBoostProductOptionData> boostProducts =
      <StoreSellerBoostProductOptionData>[];
  List<StoreSellerBoostCategoryOptionData> boostCategories =
      <StoreSellerBoostCategoryOptionData>[];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadBoostData();
    });
  }

  Future<void> loadBoostData() async {
    if (isLoading) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    await Future.wait([
      loadBoostPlans(),
      loadBoostOptions(),
      loadBoostRequests(),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> loadBoostPlans() async {
    try {
      final Response response =
          await Get.find<ApiClient>().getData(boostPlansUri);

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if (response.statusCode != 200 ||
          body is! Map ||
          body['status'] != true) {
        setFallbackPlans();
        return;
      }

      final dynamic dataValue = body['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic plansValue = data['plans'];
      final List<dynamic> planList =
          plansValue is List ? plansValue : <dynamic>[];

      final List<StoreSellerBoostPlanData> loadedPlans = planList
          .whereType<Map>()
          .map((item) => StoreSellerBoostPlanData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList();

      setState(() {
        mainBannerPlans = loadedPlans
            .where((plan) => plan.boostType == 'main_banner')
            .toList();
        productPlans = loadedPlans
            .where((plan) => plan.boostType == 'product_home')
            .toList();
        categoryPlans = loadedPlans
            .where((plan) => plan.boostType == 'category_featured')
            .toList();
      });

      if (mainBannerPlans.isEmpty &&
          productPlans.isEmpty &&
          categoryPlans.isEmpty) {
        setFallbackPlans();
      }
    } catch (_) {
      if (mounted) {
        setFallbackPlans();
      }
    }
  }

  Future<void> loadBoostOptions() async {
    try {
      final Response response =
          await Get.find<ApiClient>().getData(boostOptionsUri);

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if (response.statusCode != 200 ||
          body is! Map ||
          body['status'] != true) {
        setState(() {
          boostProducts = <StoreSellerBoostProductOptionData>[];
          boostCategories = <StoreSellerBoostCategoryOptionData>[];
        });
        return;
      }

      final dynamic dataValue = body['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic productsValue = data['products'];
      final List<dynamic> productList =
          productsValue is List ? productsValue : <dynamic>[];

      final dynamic categoriesValue = data['categories'];
      final List<dynamic> categoryList =
          categoriesValue is List ? categoriesValue : <dynamic>[];

      setState(() {
        boostProducts = productList
            .whereType<Map>()
            .map((item) => StoreSellerBoostProductOptionData.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .where((product) => product.id.isNotEmpty)
            .toList();

        boostCategories = categoryList
            .whereType<Map>()
            .map((item) => StoreSellerBoostCategoryOptionData.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .where((category) => category.id.isNotEmpty)
            .toList();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          boostProducts = <StoreSellerBoostProductOptionData>[];
          boostCategories = <StoreSellerBoostCategoryOptionData>[];
        });
      }
    }
  }

  Future<void> loadBoostRequests() async {
    try {
      final Response response =
          await Get.find<ApiClient>().getData(boostRequestsUri);

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if (response.statusCode != 200 ||
          body is! Map ||
          body['status'] != true) {
        setState(() {
          boostRequests = <StoreSellerBoostRequestData>[];
        });
        return;
      }

      final dynamic dataValue = body['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic requestsValue = data['requests'];
      final List<dynamic> requestList =
          requestsValue is List ? requestsValue : <dynamic>[];

      setState(() {
        boostRequests = requestList
            .whereType<Map>()
            .map((item) => StoreSellerBoostRequestData.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          boostRequests = <StoreSellerBoostRequestData>[];
        });
      }
    }
  }

  void setFallbackPlans() {
    setState(() {
      mainBannerPlans = [
        StoreSellerBoostPlanData(
          id: '',
          title: 'Banner principal',
          duration: '24 horas',
          price: 'R\$49,90',
          description:
              'Sua loja aparece no banner principal da Home do Marketplace.',
          icon: Icons.view_carousel_outlined,
          boostType: 'main_banner',
        ),
        StoreSellerBoostPlanData(
          id: '',
          title: 'Banner principal',
          duration: '72 horas',
          price: 'R\$79,90',
          description:
              'Mais tempo de exposição para campanhas, datas e lançamentos.',
          icon: Icons.campaign_outlined,
          boostType: 'main_banner',
          recommended: true,
        ),
        StoreSellerBoostPlanData(
          id: '',
          title: 'Banner principal',
          duration: '7 dias',
          price: 'R\$199,90',
          description:
              'Plano semanal para loja com maior destaque no Marketplace.',
          icon: Icons.workspace_premium_outlined,
          boostType: 'main_banner',
        ),
      ];

      productPlans = [
        StoreSellerBoostPlanData(
          id: '',
          title: 'Produto indicado',
          duration: '1 dia',
          price: 'R\$9,90',
          description:
              'Um produto selecionado aparece na Home em Indicado pela Lokally.',
          icon: Icons.shopping_bag_outlined,
          boostType: 'product_home',
        ),
        StoreSellerBoostPlanData(
          id: '',
          title: 'Produto indicado',
          duration: '3 dias',
          price: 'R\$14,90',
          description:
              'Mais visibilidade para um produto específico da sua loja.',
          icon: Icons.local_offer_outlined,
          boostType: 'product_home',
          recommended: true,
        ),
        StoreSellerBoostPlanData(
          id: '',
          title: 'Produto indicado',
          duration: '7 dias',
          price: 'R\$39,90',
          description:
              'Destaque semanal para produto com alto potencial de venda.',
          icon: Icons.star_border_rounded,
          boostType: 'product_home',
        ),
      ];

      categoryPlans = [
        StoreSellerBoostPlanData(
          id: '',
          title: 'Categoria em destaque',
          duration: '7 dias',
          price: 'R\$299,90',
          description:
              'Uma categoria de produtos da sua loja aparece como Lokally Indica.',
          icon: Icons.category_outlined,
          boostType: 'category_featured',
          recommended: true,
        ),
      ];
    });
  }

  List<StoreSellerBoostRequestData> get waitingApprovalRequests {
    return boostRequests
        .where((request) => request.sellerCanApproveMaterial)
        .toList();
  }

  Future<void> approveMaterial(StoreSellerBoostRequestData request) async {
    await performBoostAction(
      endpoint:
          '/api/customer/store/boost/request/${request.id}/approve-material',
      body: <String, String>{
        'seller_notes': 'Material aprovado pelo lojista no app.',
      },
      successMessage:
          'Material aprovado. A campanha agora aguarda programação da equipe Lokally.',
    );
  }

  Future<void> rejectMaterial(StoreSellerBoostRequestData request) async {
    final TextEditingController reasonController = TextEditingController();

    final String? reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        final Color primaryColor = Theme.of(context).primaryColor;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              bottom: MediaQuery.of(context).viewInsets.bottom + 14,
              top: 14,
            ),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Solicitar ajuste',
                    style: textBold.copyWith(
                      color: Colors.black87,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Explique o que precisa ser ajustado no material enviado pela equipe Lokally.',
                    style: textRegular.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 12.6,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText:
                          'Ex: trocar foto, ajustar texto, alterar cor...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            final String value = reasonController.text.trim();

                            if (value.isEmpty) {
                              return;
                            }

                            Navigator.of(context).pop(value);
                          },
                          child: const Text('Enviar ajuste'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    reasonController.dispose();

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    await performBoostAction(
      endpoint:
          '/api/customer/store/boost/request/${request.id}/reject-material',
      body: <String, String>{
        'rejection_reason': reason.trim(),
      },
      successMessage:
          'Solicitação de ajuste enviada. A equipe Lokally irá revisar o material.',
    );
  }

  Future<void> performBoostAction({
    required String endpoint,
    required Map<String, String> body,
    required String successMessage,
  }) async {
    if (isActionLoading) {
      return;
    }

    setState(() {
      isActionLoading = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().postData(
        endpoint,
        body,
      );

      if (!mounted) {
        return;
      }

      final dynamic responseBody = response.body;
      String message = successMessage;

      if (responseBody is Map && responseBody['message'] != null) {
        message = responseBody['message'].toString();
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        showBoostMessage(message);
        await loadBoostRequests();
      } else {
        showBoostMessage(message);
      }
    } catch (_) {
      if (mounted) {
        showBoostMessage('Não foi possível concluir esta ação agora.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isActionLoading = false;
        });
      }
    }
  }

  Future<void> openBoostPurchase(StoreSellerBoostPlanData plan) async {
    if (plan.id.isEmpty) {
      showBoostMessage(
          'Plano indisponível no momento. Atualize e tente novamente.');
      return;
    }

    if (plan.requiresProduct && boostProducts.isEmpty) {
      showBoostMessage(
          'Cadastre e aprove ao menos um produto antes de contratar este destaque.');
      return;
    }

    if (plan.requiresCategory && boostCategories.isEmpty) {
      showBoostMessage(
          'Cadastre produtos aprovados em uma categoria antes de contratar este destaque.');
      return;
    }

    final StoreSellerBoostPurchaseSelection? selection =
        await showModalBottomSheet<StoreSellerBoostPurchaseSelection>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StoreSellerBoostPurchaseSheet(
          plan: plan,
          products: boostProducts,
          categories: boostCategories,
          primaryColor: Theme.of(context).primaryColor,
        );
      },
    );

    if (selection == null) {
      return;
    }

    await purchaseBoostPlan(selection);
  }

  Future<void> purchaseBoostPlan(
    StoreSellerBoostPurchaseSelection selection,
  ) async {
    if (isActionLoading) {
      return;
    }

    setState(() {
      isActionLoading = true;
    });

    final Map<String, String> body = <String, String>{
      'plan_id': selection.plan.id,
      'payment_method': selection.paymentMethod,
      'seller_notes': selection.notes,
    };

    if (selection.productId.isNotEmpty) {
      body['product_id'] = selection.productId;
    }

    if (selection.categoryId.isNotEmpty) {
      body['category_id'] = selection.categoryId;
    }

    try {
      final Response response = await Get.find<ApiClient>().postData(
        boostCreateRequestUri,
        body,
      );

      if (!mounted) {
        return;
      }

      final dynamic responseBody = response.body;
      String message = response.statusCode == 201
          ? 'Impulsionamento contratado com sucesso.'
          : 'Não foi possível contratar este impulsionamento.';

      if (responseBody is Map && responseBody['message'] != null) {
        message = responseBody['message'].toString();
      }

      showBoostMessage(message);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await loadBoostData();
      }
    } catch (_) {
      if (mounted) {
        showBoostMessage(
            'Não foi possível contratar este impulsionamento agora.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isActionLoading = false;
        });
      }
    }
  }

  void showBoostMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          'Impulsionar',
          style: textBold.copyWith(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadBoostData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: loadBoostData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Dimensions.paddingSizeDefault,
            16,
            Dimensions.paddingSizeDefault,
            28,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StoreSellerBoostHero(primaryColor: primaryColor),
              const SizedBox(height: 16),
              StoreSellerBoostFlow(primaryColor: primaryColor),
              const SizedBox(height: 18),
              if (isLoading) ...[
                StoreSellerBoostLoading(primaryColor: primaryColor),
                const SizedBox(height: 18),
              ] else ...[
                if (waitingApprovalRequests.isNotEmpty) ...[
                  StoreSellerBoostApprovalSection(
                    requests: waitingApprovalRequests,
                    primaryColor: primaryColor,
                    isActionLoading: isActionLoading,
                    onApprove: approveMaterial,
                    onReject: rejectMaterial,
                  ),
                  const SizedBox(height: 18),
                ],
                if (boostRequests.isNotEmpty) ...[
                  StoreSellerBoostRequestHistory(
                    requests: boostRequests,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 18),
                ],
              ],
              StoreSellerBoostSection(
                title: 'Banner principal da Loja',
                description:
                    'A equipe Lokally cria o material, envia para sua aprovação e ativa no período contratado.',
                plans: mainBannerPlans,
                primaryColor: primaryColor,
                onPlanTap: openBoostPurchase,
              ),
              const SizedBox(height: 18),
              StoreSellerBoostSection(
                title: 'Produto indicado na Home',
                description:
                    'Escolha um produto para aparecer em área de indicação dentro da Home do Marketplace.',
                plans: productPlans,
                primaryColor: primaryColor,
                onPlanTap: openBoostPurchase,
              ),
              const SizedBox(height: 18),
              StoreSellerBoostSection(
                title: 'Categoria Lokally Indica',
                description:
                    'Escolha uma categoria de produtos da sua loja para receber destaque especial.',
                plans: categoryPlans,
                primaryColor: primaryColor,
                onPlanTap: openBoostPurchase,
              ),
              const SizedBox(height: 18),
              StoreSellerBoostImportantNotice(primaryColor: primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreSellerBoostPurchaseSheet extends StatefulWidget {
  final StoreSellerBoostPlanData plan;
  final List<StoreSellerBoostProductOptionData> products;
  final List<StoreSellerBoostCategoryOptionData> categories;
  final Color primaryColor;

  const StoreSellerBoostPurchaseSheet({
    super.key,
    required this.plan,
    required this.products,
    required this.categories,
    required this.primaryColor,
  });

  @override
  State<StoreSellerBoostPurchaseSheet> createState() =>
      _StoreSellerBoostPurchaseSheetState();
}

class _StoreSellerBoostPurchaseSheetState
    extends State<StoreSellerBoostPurchaseSheet> {
  late String selectedProductId;
  late String selectedCategoryId;
  String selectedPaymentMethod = 'app_balance';
  final TextEditingController notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedProductId =
        widget.plan.requiresProduct && widget.products.isNotEmpty
            ? widget.products.first.id
            : '';
    selectedCategoryId =
        widget.plan.requiresCategory && widget.categories.isNotEmpty
            ? widget.categories.first.id
            : '';
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  String get placementLabel {
    if (widget.plan.boostType == 'main_banner') {
      return 'Exibição: Banner principal do Marketplace';
    }

    if (widget.plan.boostType == 'product_home') {
      return 'Exibição: Home do Marketplace em Lokally Indica';
    }

    if (widget.plan.boostType == 'category_featured') {
      return 'Exibição: Categoria em destaque / Lokally Indica';
    }

    return 'Exibição definida pela Lokally';
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = widget.primaryColor;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 14,
          top: 14,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.plan.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.plan.title,
                            style: textBold.copyWith(
                              color: Colors.black87,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.plan.duration} • ${widget.plan.price}',
                            style: textMedium.copyWith(
                              color: primaryColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    placementLabel,
                    style: textBold.copyWith(
                      color: primaryColor,
                      fontSize: 12.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (widget.plan.requiresProduct) ...[
                  Text(
                    'Produto que será impulsionado',
                    style: textBold.copyWith(
                      color: Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedProductId.isEmpty ? null : selectedProductId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: widget.products
                        .map(
                          (product) => DropdownMenuItem<String>(
                            value: product.id,
                            child: Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedProductId = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                if (widget.plan.requiresCategory) ...[
                  Text(
                    'Categoria que será impulsionada',
                    style: textBold.copyWith(
                      color: Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value:
                        selectedCategoryId.isEmpty ? null : selectedCategoryId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: widget.categories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category.id,
                            child: Text(
                              category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedCategoryId = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  'Forma de pagamento',
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedPaymentMethod,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem<String>(
                      value: 'app_balance',
                      child: Text('Saldo Lokally'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'stripe_card',
                      child: Text('Cartão de crédito'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedPaymentMethod = value;
                      });
                    }
                  },
                ),
                if (selectedPaymentMethod == 'stripe_card') ...[
                  const SizedBox(height: 8),
                  Text(
                    'No cartão, a campanha só será enviada ao ADM após confirmação do pagamento.',
                    style: textRegular.copyWith(
                      color: Colors.orange.shade800,
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'Observação opcional para a equipe Lokally criar a campanha',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      if (widget.plan.requiresProduct &&
                          selectedProductId.isEmpty) {
                        return;
                      }

                      if (widget.plan.requiresCategory &&
                          selectedCategoryId.isEmpty) {
                        return;
                      }

                      Navigator.of(context).pop(
                        StoreSellerBoostPurchaseSelection(
                          plan: widget.plan,
                          productId: selectedProductId,
                          categoryId: selectedCategoryId,
                          paymentMethod: selectedPaymentMethod,
                          notes: notesController.text.trim(),
                        ),
                      );
                    },
                    child: Text(
                      selectedPaymentMethod == 'app_balance'
                          ? 'Contratar e pagar com saldo'
                          : 'Continuar com cartão',
                      style: textBold.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StoreSellerBoostHero extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerBoostHero({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            const Color(0xFF0D3D38),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 12),
            blurRadius: 24,
            color: primaryColor.withValues(alpha: 0.22),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Icon(
              Icons.rocket_launch_rounded,
              color: Colors.white.withValues(alpha: 0.08),
              size: 120,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Impulsione sua loja no Marketplace',
                style: textBold.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Contrate destaque para loja, produto ou categoria. A equipe Lokally prepara o material, envia para aprovação e ativa a campanha após sua autorização.',
                style: textRegular.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 13,
                  height: 1.36,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StoreSellerBoostFlow extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerBoostFlow({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> steps = [
      'Escolha o modelo',
      'Pague com saldo ou cartão',
      'Equipe Lokally cria o material',
      'Você aprova e começa a rodar',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Como funciona',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(steps.length, (index) {
            return Padding(
              padding:
                  EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 10),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: textBold.copyWith(
                          color: primaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      steps[index],
                      style: textMedium.copyWith(
                        color: Colors.black87,
                        fontSize: 12.8,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class StoreSellerBoostSection extends StatelessWidget {
  final String title;
  final String description;
  final List<StoreSellerBoostPlanData> plans;
  final Color primaryColor;
  final ValueChanged<StoreSellerBoostPlanData> onPlanTap;

  const StoreSellerBoostSection({
    super.key,
    required this.title,
    required this.description,
    required this.plans,
    required this.primaryColor,
    required this.onPlanTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 16.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 12.2,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 13),
          ...plans.map(
            (plan) => StoreSellerBoostPlanCard(
              plan: plan,
              primaryColor: primaryColor,
              onTap: () => onPlanTap(plan),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerBoostPlanCard extends StatelessWidget {
  final StoreSellerBoostPlanData plan;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreSellerBoostPlanCard({
    super.key,
    required this.plan,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardColor =
        plan.recommended ? primaryColor.withValues(alpha: 0.08) : Colors.white;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: plan.recommended
                  ? primaryColor.withValues(alpha: 0.24)
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  plan.icon,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            plan.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textBold.copyWith(
                              color: Colors.black87,
                              fontSize: 13.8,
                            ),
                          ),
                        ),
                        if (plan.recommended) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Mais usado',
                              style: textBold.copyWith(
                                color: Colors.white,
                                fontSize: 9.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11.1,
                        height: 1.20,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.duration,
                    style: textMedium.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 10.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    plan.price,
                    style: textBold.copyWith(
                      color: primaryColor,
                      fontSize: 13.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreSellerBoostImportantNotice extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerBoostImportantNotice({
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primaryColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: primaryColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Após o pagamento, sua solicitação fica em produção. A campanha só começa após aprovação do material pelo lojista e liberação da equipe Lokally.',
              style: textMedium.copyWith(
                color: Colors.black87,
                fontSize: 12.3,
                height: 1.32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerBoostApprovalSection extends StatelessWidget {
  final List<StoreSellerBoostRequestData> requests;
  final Color primaryColor;
  final bool isActionLoading;
  final ValueChanged<StoreSellerBoostRequestData> onApprove;
  final ValueChanged<StoreSellerBoostRequestData> onReject;

  const StoreSellerBoostApprovalSection({
    super.key,
    required this.requests,
    required this.primaryColor,
    required this.isActionLoading,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFC857).withValues(alpha: 0.38),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC857).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.pending_actions_rounded,
                  color: Colors.orange.shade800,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aguardando sua aprovação',
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 16.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'A equipe Lokally enviou material para revisão. Aprove para liberar a ativação ou solicite ajustes.',
            style: textRegular.copyWith(
              color: Colors.grey.shade700,
              fontSize: 12.3,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          ...requests.map(
            (request) => StoreSellerBoostApprovalCard(
              request: request,
              primaryColor: primaryColor,
              isActionLoading: isActionLoading,
              onApprove: () => onApprove(request),
              onReject: () => onReject(request),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerBoostApprovalCard extends StatelessWidget {
  final StoreSellerBoostRequestData request;
  final Color primaryColor;
  final bool isActionLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const StoreSellerBoostApprovalCard({
    super.key,
    required this.request,
    required this.primaryColor,
    required this.isActionLoading,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasMaterial = request.materialPreviewUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StoreSellerBoostRequestHeader(
            request: request,
            primaryColor: primaryColor,
          ),
          if (hasMaterial) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: Image.network(
                  request.materialPreviewUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      color: primaryColor.withValues(alpha: 0.08),
                      child: Center(
                        child: Icon(
                          Icons.insert_drive_file_outlined,
                          color: primaryColor,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isActionLoading ? null : onReject,
                  child: const Text('Solicitar ajuste'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: isActionLoading ? null : onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: isActionLoading
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Aprovar material'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StoreSellerBoostRequestHistory extends StatelessWidget {
  final List<StoreSellerBoostRequestData> requests;
  final Color primaryColor;

  const StoreSellerBoostRequestHistory({
    super.key,
    required this.requests,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final List<StoreSellerBoostRequestData> visibleRequests =
        requests.take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Minhas campanhas',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 16.5,
            ),
          ),
          const SizedBox(height: 10),
          ...visibleRequests.map(
            (request) => StoreSellerBoostHistoryTile(
              request: request,
              primaryColor: primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerBoostHistoryTile extends StatelessWidget {
  final StoreSellerBoostRequestData request;
  final Color primaryColor;

  const StoreSellerBoostHistoryTile({
    super.key,
    required this.request,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: StoreSellerBoostRequestHeader(
        request: request,
        primaryColor: primaryColor,
      ),
    );
  }
}

class StoreSellerBoostRequestHeader extends StatelessWidget {
  final StoreSellerBoostRequestData request;
  final Color primaryColor;

  const StoreSellerBoostRequestHeader({
    super.key,
    required this.request,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final String imageUrl = request.productImageUrl;
    final bool hasImage = imageUrl.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: hasImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Icon(
                        Icons.rocket_launch_outlined,
                        color: primaryColor,
                        size: 22,
                      );
                    },
                  ),
                )
              : Icon(
                  Icons.rocket_launch_outlined,
                  color: primaryColor,
                  size: 22,
                ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 13.6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                request.targetDescription,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textRegular.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 11.4,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StoreSellerBoostStatusChip(
                    label: request.statusLabel,
                    primaryColor: primaryColor,
                  ),
                  StoreSellerBoostStatusChip(
                    label: request.formattedAmount,
                    primaryColor: primaryColor,
                    soft: true,
                  ),
                  StoreSellerBoostInsightsButton(
                    request: request,
                    primaryColor: primaryColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StoreSellerBoostInsightsButton extends StatelessWidget {
  final StoreSellerBoostRequestData request;
  final Color primaryColor;

  const StoreSellerBoostInsightsButton({
    super.key,
    required this.request,
    required this.primaryColor,
  });

  void openInsights(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StoreSellerBoostInsightsSheet(
        request: request,
        primaryColor: primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primaryColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => openInsights(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: primaryColor,
                size: 13,
              ),
              const SizedBox(width: 4),
              Text(
                'Ver insights',
                style: textBold.copyWith(
                  color: primaryColor,
                  fontSize: 9.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreSellerBoostInsightsSheet extends StatefulWidget {
  final StoreSellerBoostRequestData request;
  final Color primaryColor;

  const StoreSellerBoostInsightsSheet({
    super.key,
    required this.request,
    required this.primaryColor,
  });

  @override
  State<StoreSellerBoostInsightsSheet> createState() =>
      _StoreSellerBoostInsightsSheetState();
}

class _StoreSellerBoostInsightsSheetState
    extends State<StoreSellerBoostInsightsSheet> {
  bool isLoading = true;
  String errorMessage = '';
  StoreSellerBoostInsightData? insightData;

  @override
  void initState() {
    super.initState();
    loadInsights();
  }

  Future<void> loadInsights() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final String endpoint =
          '/api/customer/store/boost/request/${widget.request.id}/insights';
      final Response response = await Get.find<ApiClient>().getData(endpoint);

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;
      if (response.statusCode != 200 ||
          body is! Map ||
          body['status'] != true) {
        setState(() {
          errorMessage = body is Map && body['message'] != null
              ? body['message'].toString()
              : 'Não foi possível carregar os insights agora.';
          isLoading = false;
        });
        return;
      }

      final dynamic dataValue = body['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      setState(() {
        insightData = StoreSellerBoostInsightData.fromMap(data);
        isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          errorMessage = 'Não foi possível carregar os insights agora.';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = widget.primaryColor;

    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.76,
        minChildSize: 0.48,
        maxChildSize: 0.93,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF4F6F6),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Insights da campanha',
                              style: textBold.copyWith(
                                color: Colors.black87,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.request.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textRegular.copyWith(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isLoading)
                    StoreSellerBoostInsightsLoading(primaryColor: primaryColor)
                  else if (errorMessage.isNotEmpty)
                    StoreSellerBoostInsightsError(
                      message: errorMessage,
                      primaryColor: primaryColor,
                      onRetry: loadInsights,
                    )
                  else if (insightData != null)
                    StoreSellerBoostInsightsContent(
                      data: insightData!,
                      primaryColor: primaryColor,
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

class StoreSellerBoostInsightsContent extends StatelessWidget {
  final StoreSellerBoostInsightData data;
  final Color primaryColor;

  const StoreSellerBoostInsightsContent({
    super.key,
    required this.data,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final StoreSellerBoostInsightSummary summary = data.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Período da campanha',
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: StoreSellerBoostPeriodTile(
                      label: 'Início',
                      value: data.startsAtLabel,
                      primaryColor: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StoreSellerBoostPeriodTile(
                      label: 'Fim',
                      value: data.endsAtLabel,
                      primaryColor: primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.55,
          children: [
            StoreSellerBoostMetricCard(
              title: 'Visualizações',
              value: '${summary.views}',
              icon: Icons.visibility_outlined,
              primaryColor: primaryColor,
            ),
            StoreSellerBoostMetricCard(
              title: 'Cliques',
              value: '${summary.clicks}',
              icon: Icons.ads_click_rounded,
              primaryColor: primaryColor,
            ),
            StoreSellerBoostMetricCard(
              title: 'Conversões',
              value: '${summary.conversions}',
              icon: Icons.shopping_bag_outlined,
              primaryColor: primaryColor,
            ),
            StoreSellerBoostMetricCard(
              title: 'Valor convertido',
              value: summary.formattedConversionAmount,
              icon: Icons.payments_outlined,
              primaryColor: primaryColor,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Expanded(
                child: StoreSellerBoostRateTile(
                  label: 'CTR',
                  value: '${summary.ctrPercent.toStringAsFixed(2)}%',
                  hint: 'Cliques sobre visualizações',
                  primaryColor: primaryColor,
                ),
              ),
              Container(
                width: 1,
                height: 52,
                color: primaryColor.withValues(alpha: 0.12),
              ),
              Expanded(
                child: StoreSellerBoostRateTile(
                  label: 'Conversão',
                  value: '${summary.conversionRatePercent.toStringAsFixed(2)}%',
                  hint: 'Conversões sobre cliques',
                  primaryColor: primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Resumo diário',
          style: textBold.copyWith(color: Colors.black87, fontSize: 15.5),
        ),
        const SizedBox(height: 10),
        if (data.daily.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Ainda não existem dados diários para esta campanha.',
              style: textRegular.copyWith(
                color: Colors.grey.shade600,
                fontSize: 12.5,
              ),
            ),
          )
        else
          ...data.daily.map(
            (daily) => StoreSellerBoostDailyTile(
              daily: daily,
              primaryColor: primaryColor,
            ),
          ),
      ],
    );
  }
}

class StoreSellerBoostPeriodTile extends StatelessWidget {
  final String label;
  final String value;
  final Color primaryColor;

  const StoreSellerBoostPeriodTile({
    super.key,
    required this.label,
    required this.value,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: textRegular.copyWith(
                  color: Colors.grey.shade600, fontSize: 11)),
          const SizedBox(height: 3),
          Text(value,
              style: textBold.copyWith(color: primaryColor, fontSize: 12.3)),
        ],
      ),
    );
  }
}

class StoreSellerBoostMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color primaryColor;

  const StoreSellerBoostMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor, size: 22),
          const Spacer(),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textBold.copyWith(color: Colors.black87, fontSize: 17)),
          const SizedBox(height: 2),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textRegular.copyWith(
                  color: Colors.grey.shade600, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class StoreSellerBoostRateTile extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final Color primaryColor;

  const StoreSellerBoostRateTile({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: textBold.copyWith(color: Colors.black87, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text(value,
              style: textBold.copyWith(color: primaryColor, fontSize: 18)),
          const SizedBox(height: 2),
          Text(hint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textRegular.copyWith(
                  color: Colors.grey.shade600, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class StoreSellerBoostDailyTile extends StatelessWidget {
  final StoreSellerBoostDailyInsightData daily;
  final Color primaryColor;

  const StoreSellerBoostDailyTile({
    super.key,
    required this.daily,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.calendar_month_outlined,
                color: primaryColor, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(daily.date,
                    style: textBold.copyWith(
                        color: Colors.black87, fontSize: 12.8)),
                const SizedBox(height: 3),
                Text(
                    '${daily.views} visualizações • ${daily.clicks} cliques • ${daily.conversions} conversões',
                    style: textRegular.copyWith(
                        color: Colors.grey.shade600, fontSize: 11.2)),
              ],
            ),
          ),
          Text(daily.formattedConversionAmount,
              style: textBold.copyWith(color: primaryColor, fontSize: 12.4)),
        ],
      ),
    );
  }
}

class StoreSellerBoostInsightsLoading extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerBoostInsightsLoading(
      {super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Center(
          child:
              CircularProgressIndicator(color: primaryColor, strokeWidth: 2.5)),
    );
  }
}

class StoreSellerBoostInsightsError extends StatelessWidget {
  final String message;
  final Color primaryColor;
  final VoidCallback onRetry;

  const StoreSellerBoostInsightsError({
    super.key,
    required this.message,
    required this.primaryColor,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.red.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.red.shade400, size: 30),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style:
                  textMedium.copyWith(color: Colors.black87, fontSize: 12.5)),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}

class StoreSellerBoostStatusChip extends StatelessWidget {
  final String label;
  final Color primaryColor;
  final bool soft;

  const StoreSellerBoostStatusChip({
    super.key,
    required this.label,
    required this.primaryColor,
    this.soft = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: soft ? primaryColor.withValues(alpha: 0.08) : primaryColor,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: textBold.copyWith(
          color: soft ? primaryColor : Colors.white,
          fontSize: 9.7,
        ),
      ),
    );
  }
}

class StoreSellerBoostLoading extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerBoostLoading({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
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

class StoreSellerBoostPurchaseSelection {
  final StoreSellerBoostPlanData plan;
  final String productId;
  final String categoryId;
  final String paymentMethod;
  final String notes;

  StoreSellerBoostPurchaseSelection({
    required this.plan,
    required this.productId,
    required this.categoryId,
    required this.paymentMethod,
    required this.notes,
  });
}

class StoreSellerBoostProductOptionData {
  final String id;
  final String name;
  final String imageUrl;
  final String priceLabel;

  StoreSellerBoostProductOptionData({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.priceLabel,
  });

  factory StoreSellerBoostProductOptionData.fromMap(
    Map<String, dynamic> map,
  ) {
    final double price =
        double.tryParse('${map['current_price'] ?? map['price'] ?? 0}') ?? 0;

    return StoreSellerBoostProductOptionData(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      imageUrl: '${map['image_url'] ?? ''}',
      priceLabel: 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}',
    );
  }
}

class StoreSellerBoostCategoryOptionData {
  final String id;
  final String name;
  final String parentId;

  StoreSellerBoostCategoryOptionData({
    required this.id,
    required this.name,
    required this.parentId,
  });

  factory StoreSellerBoostCategoryOptionData.fromMap(
    Map<String, dynamic> map,
  ) {
    return StoreSellerBoostCategoryOptionData(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      parentId: '${map['parent_id'] ?? ''}',
    );
  }
}

class StoreSellerBoostPlanData {
  final String id;
  final String title;
  final String duration;
  final String price;
  final String description;
  final IconData icon;
  final bool recommended;
  final String boostType;
  final bool requiresProduct;
  final bool requiresCategory;

  StoreSellerBoostPlanData({
    this.id = '',
    required this.title,
    required this.duration,
    required this.price,
    required this.description,
    required this.icon,
    this.recommended = false,
    this.boostType = '',
    this.requiresProduct = false,
    this.requiresCategory = false,
  });

  factory StoreSellerBoostPlanData.fromMap(Map<String, dynamic> map) {
    final String boostType = '${map['boost_type'] ?? ''}';

    IconData icon = Icons.rocket_launch_outlined;
    if (boostType == 'main_banner') {
      icon = Icons.view_carousel_outlined;
    } else if (boostType == 'product_home') {
      icon = Icons.shopping_bag_outlined;
    } else if (boostType == 'category_featured') {
      icon = Icons.category_outlined;
    }

    final String formattedPrice = '${map['formatted_price'] ?? ''}';
    final String rawPrice = '${map['price'] ?? ''}';
    final String priceLabel =
        formattedPrice.isNotEmpty ? formattedPrice : 'R\$ $rawPrice';
    final String planCode = '${map['plan_code'] ?? ''}';

    return StoreSellerBoostPlanData(
      id: '${map['id'] ?? ''}',
      title: '${map['title'] ?? ''}',
      duration: '${map['duration_label'] ?? ''}',
      price: priceLabel,
      description: '${map['description'] ?? ''}',
      icon: icon,
      boostType: boostType,
      requiresProduct: map['requires_product'] == true,
      requiresCategory: map['requires_category'] == true,
      recommended: planCode.contains('72h') ||
          planCode.contains('3d') ||
          planCode.contains('category_featured'),
    );
  }
}

class StoreSellerBoostRequestData {
  final String id;
  final String requestNumber;
  final String title;
  final String boostType;
  final String targetType;
  final String productName;
  final String productImageUrl;
  final String categoryName;
  final String formattedAmount;
  final String paymentStatus;
  final String requestStatus;
  final String creativeStatus;
  final String materialPreviewUrl;
  final bool sellerCanApproveMaterial;

  StoreSellerBoostRequestData({
    required this.id,
    required this.requestNumber,
    required this.title,
    required this.boostType,
    required this.targetType,
    required this.productName,
    required this.productImageUrl,
    required this.categoryName,
    required this.formattedAmount,
    required this.paymentStatus,
    required this.requestStatus,
    required this.creativeStatus,
    required this.materialPreviewUrl,
    required this.sellerCanApproveMaterial,
  });

  factory StoreSellerBoostRequestData.fromMap(Map<String, dynamic> map) {
    return StoreSellerBoostRequestData(
      id: '${map['id'] ?? ''}',
      requestNumber: '${map['request_number'] ?? ''}',
      title: '${map['title'] ?? ''}',
      boostType: '${map['boost_type'] ?? ''}',
      targetType: '${map['target_type'] ?? ''}',
      productName: '${map['product_name'] ?? ''}',
      productImageUrl: '${map['product_image_url'] ?? ''}',
      categoryName: '${map['category_name'] ?? ''}',
      formattedAmount: '${map['formatted_amount'] ?? ''}',
      paymentStatus: '${map['payment_status'] ?? ''}',
      requestStatus: '${map['request_status'] ?? ''}',
      creativeStatus: '${map['creative_status'] ?? ''}',
      materialPreviewUrl: '${map['material_preview_url'] ?? ''}',
      sellerCanApproveMaterial: map['seller_can_approve_material'] == true,
    );
  }

  String get targetDescription {
    if (productName.isNotEmpty) {
      return productName;
    }

    if (categoryName.isNotEmpty) {
      return 'Categoria: $categoryName';
    }

    if (boostType == 'main_banner') {
      return 'Banner principal da loja';
    }

    return requestNumber;
  }

  String get statusLabel {
    switch (requestStatus) {
      case 'pending_payment':
        return 'Aguardando pagamento';
      case 'paid_waiting_production':
        return 'Pago / aguardando produção';
      case 'in_production':
        return 'Em produção';
      case 'waiting_seller_approval':
        return 'Aguardando aprovação';
      case 'seller_approved_waiting_activation':
      case 'seller_approved_waiting_schedule':
        return 'Aprovado / aguardando programação';
      case 'scheduled':
        return 'Campanha programada';
      case 'material_rejected_by_seller':
        return 'Ajuste solicitado';
      case 'active':
        return 'Ativo';
      case 'finished':
        return 'Finalizado';
      case 'cancelled':
        return 'Cancelado';
    }

    return requestStatus;
  }
}

class StoreSellerBoostInsightData {
  final String requestId;
  final String title;
  final String requestStatus;
  final String startsAt;
  final String endsAt;
  final StoreSellerBoostInsightSummary summary;
  final List<StoreSellerBoostDailyInsightData> daily;

  StoreSellerBoostInsightData({
    required this.requestId,
    required this.title,
    required this.requestStatus,
    required this.startsAt,
    required this.endsAt,
    required this.summary,
    required this.daily,
  });

  factory StoreSellerBoostInsightData.fromMap(Map<String, dynamic> map) {
    final dynamic requestValue = map['request'];
    final Map<String, dynamic> request = requestValue is Map
        ? Map<String, dynamic>.from(requestValue)
        : <String, dynamic>{};

    final dynamic summaryValue = map['summary'];
    final Map<String, dynamic> summary = summaryValue is Map
        ? Map<String, dynamic>.from(summaryValue)
        : <String, dynamic>{};

    final dynamic dailyValue = map['daily'];
    final List<dynamic> dailyList =
        dailyValue is List ? dailyValue : <dynamic>[];

    return StoreSellerBoostInsightData(
      requestId: '${request['id'] ?? ''}',
      title: '${request['title'] ?? ''}',
      requestStatus: '${request['request_status'] ?? ''}',
      startsAt: '${request['starts_at'] ?? ''}',
      endsAt: '${request['ends_at'] ?? ''}',
      summary: StoreSellerBoostInsightSummary.fromMap(summary),
      daily: dailyList
          .whereType<Map>()
          .map((item) => StoreSellerBoostDailyInsightData.fromMap(
              Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  String get startsAtLabel => startsAt.isEmpty ? 'Não iniciado' : startsAt;

  String get endsAtLabel => endsAt.isEmpty ? 'Não definido' : endsAt;
}

class StoreSellerBoostInsightSummary {
  final int views;
  final int clicks;
  final int conversions;
  final double conversionAmount;
  final double ctrPercent;
  final double conversionRatePercent;

  StoreSellerBoostInsightSummary({
    required this.views,
    required this.clicks,
    required this.conversions,
    required this.conversionAmount,
    required this.ctrPercent,
    required this.conversionRatePercent,
  });

  factory StoreSellerBoostInsightSummary.fromMap(Map<String, dynamic> map) {
    return StoreSellerBoostInsightSummary(
      views: int.tryParse('${map['views'] ?? 0}') ?? 0,
      clicks: int.tryParse('${map['clicks'] ?? 0}') ?? 0,
      conversions: int.tryParse('${map['conversions'] ?? 0}') ?? 0,
      conversionAmount:
          double.tryParse('${map['conversion_amount'] ?? 0}') ?? 0,
      ctrPercent: double.tryParse('${map['ctr_percent'] ?? 0}') ?? 0,
      conversionRatePercent:
          double.tryParse('${map['conversion_rate_percent'] ?? 0}') ?? 0,
    );
  }

  String get formattedConversionAmount =>
      'R\$ ${conversionAmount.toStringAsFixed(2).replaceAll('.', ',')}';
}

class StoreSellerBoostDailyInsightData {
  final String date;
  final int views;
  final int clicks;
  final int conversions;
  final double conversionAmount;

  StoreSellerBoostDailyInsightData({
    required this.date,
    required this.views,
    required this.clicks,
    required this.conversions,
    required this.conversionAmount,
  });

  factory StoreSellerBoostDailyInsightData.fromMap(Map<String, dynamic> map) {
    return StoreSellerBoostDailyInsightData(
      date: '${map['date'] ?? ''}',
      views: int.tryParse('${map['views'] ?? 0}') ?? 0,
      clicks: int.tryParse('${map['clicks'] ?? 0}') ?? 0,
      conversions: int.tryParse('${map['conversions'] ?? 0}') ?? 0,
      conversionAmount:
          double.tryParse('${map['conversion_amount'] ?? 0}') ?? 0,
    );
  }

  String get formattedConversionAmount =>
      'R\$ ${conversionAmount.toStringAsFixed(2).replaceAll('.', ',')}';
}

class StoreSellerKpiData {
  final String title;
  final String value;
  final IconData icon;

  StoreSellerKpiData({
    required this.title,
    required this.value,
    required this.icon,
  });
}

class StoreSellerMenuData {
  final String title;
  final String description;
  final IconData icon;
  final bool highlighted;

  StoreSellerMenuData({
    required this.title,
    required this.description,
    required this.icon,
    this.highlighted = false,
  });
}

class StoreSellerSaleData {
  final String product;
  final String status;
  final String value;
  final String time;
  final bool isCancelled;

  StoreSellerSaleData({
    required this.product,
    required this.status,
    required this.value,
    required this.time,
    this.isCancelled = false,
  });
}
