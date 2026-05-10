import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

import 'store_seller_product_list_screen.dart';
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

    handleComingSoon(context, title);
  }

  void openCreateProductScreen(BuildContext context, String title) {
    if (title == 'Produtos') {
      Get.to(() => const StoreSellerProductsScreen());
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
                          onKpiTap: (title) => handleComingSoon(context, title),
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
                              handleComingSoon(context, 'Todas as vendas'),
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
    return Material(
      color: primaryColor.withValues(alpha: 0.06),
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
                color: primaryColor,
                size: 24,
              ),
              const Spacer(),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 13.6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textRegular.copyWith(
                  color: Colors.grey.shade600,
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

                  return ListTile(
                    onTap: () => onMenuTap(item.title),
                    minLeadingWidth: 36,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Icon(
                      item.icon,
                      color: primaryColor,
                      size: 22,
                    ),
                    title: Text(
                      item.title,
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: Text(
                      item.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11.2,
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

  StoreSellerMenuData({
    required this.title,
    required this.description,
    required this.icon,
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
