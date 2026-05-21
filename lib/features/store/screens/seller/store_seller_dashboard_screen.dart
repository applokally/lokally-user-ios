import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/message/controllers/message_controller.dart';
import 'package:ride_sharing_user_app/features/message/screens/message_list.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const String storeSellerDashboardUri =
      '/api/customer/store/seller/dashboard';

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  String storeName = 'Moments Paris';
  String? logoUrl;
  String? coverImageUrl;
  StoreSellerProfileData sellerProfile = StoreSellerProfileData.empty();

  StoreSellerDashboardKpis sellerKpis = StoreSellerDashboardKpis.empty();
  StoreSellerDeliverySettings sellerDeliverySettings =
      StoreSellerDeliverySettings.empty();
  List<StoreSellerSaleData> latestSellerSales = <StoreSellerSaleData>[];
  List<StoreSellerSalesChartData> sellerSalesChart =
      <StoreSellerSalesChartData>[];
  String selectedDashboardPeriod = 'today';

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

    final Response response = await Get.find<ApiClient>().getData(
      '$storeSellerDashboardUri?period=$selectedDashboardPeriod',
    );

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

    final dynamic kpisValue = data['kpis'];
    final Map<String, dynamic> kpis =
        kpisValue is Map ? Map<String, dynamic>.from(kpisValue) : data;

    final dynamic deliveryValue = data['delivery_settings'];
    final Map<String, dynamic> deliverySettings = deliveryValue is Map
        ? Map<String, dynamic>.from(deliveryValue)
        : <String, dynamic>{};

    final dynamic latestOrdersValue = data['latest_orders'];
    final List<dynamic> latestOrders =
        latestOrdersValue is List ? latestOrdersValue : <dynamic>[];

    final dynamic chartValue = data['sales_chart'];
    final List<dynamic> chartRows =
        chartValue is List ? chartValue : <dynamic>[];

    updateSellerStateFromMap(seller);

    if (!mounted) {
      return;
    }

    setState(() {
      sellerKpis = StoreSellerDashboardKpis.fromMap(kpis);
      sellerDeliverySettings =
          StoreSellerDeliverySettings.fromMap(deliverySettings);
      latestSellerSales = latestOrders
          .whereType<Map>()
          .map((item) => StoreSellerSaleData.fromDashboardOrder(
                Map<String, dynamic>.from(item),
              ))
          .toList();
      sellerSalesChart = chartRows
          .whereType<Map>()
          .map((item) => StoreSellerSalesChartData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    });
  }

  void updateSellerStateFromMap(Map<String, dynamic> seller) {
    final String newStoreName = '${seller['store_name'] ?? ''}'.trim();
    final String newLogoUrl = '${seller['logo_url'] ?? ''}'.trim();
    final String newCoverUrl = '${seller['cover_image_url'] ?? ''}'.trim();
    final StoreSellerProfileData updatedProfile =
        StoreSellerProfileData.fromMap(seller);

    setState(() {
      if (newStoreName.isNotEmpty) {
        storeName = newStoreName;
      }

      logoUrl = newLogoUrl.isNotEmpty ? newLogoUrl : null;
      coverImageUrl = newCoverUrl.isNotEmpty ? newCoverUrl : null;
      sellerProfile = updatedProfile;
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

    if (title == 'Ofertas' || title == 'Ofertas e promoções') {
      Get.to(() => const StoreSellerOffersScreen());
      return;
    }

    if (title == 'Entrega e retirada') {
      Get.to(
        () => StoreSellerDeliverySettingsScreen(
          initialSettings: sellerDeliverySettings,
          onSettingsSaved: (settings) {
            setState(() {
              sellerDeliverySettings = settings;
            });
            loadSellerData();
          },
        ),
      );
      return;
    }

    if (title == 'Plano da loja') {
      Get.to(() => const StoreSellerBillingScreen());
      return;
    }

    if (title == 'Financeiro' ||
        title == 'Repasse a receber' ||
        title == 'Repasses feitos' ||
        title == 'Vendas') {
      Get.to(() => const StoreSellerFinanceScreen());
      return;
    }

    if (title == 'Dados da loja') {
      Get.to(
        () => StoreSellerProfileScreen(
          initialProfile: sellerProfile,
          onProfileSaved: (seller) {
            updateSellerStateFromMap(seller);
            loadSellerData();
          },
        ),
      );
      return;
    }

    if (title == 'Falar com a Lokally') {
      handleSellerSupport(context);
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

    if (title == 'Ofertas' || title == 'Ofertas e promoções') {
      Get.to(() => const StoreSellerOffersScreen());
      return;
    }

    if (title == 'Entrega e retirada') {
      Get.to(
        () => StoreSellerDeliverySettingsScreen(
          initialSettings: sellerDeliverySettings,
          onSettingsSaved: (settings) {
            setState(() {
              sellerDeliverySettings = settings;
            });
            loadSellerData();
          },
        ),
      );
      return;
    }

    if (title == 'Falar com a Lokally') {
      handleSellerSupport(context);
      return;
    }

    handleComingSoon(context, title);
  }

  void changeDashboardPeriod(String period) {
    if (selectedDashboardPeriod == period) {
      return;
    }

    setState(() {
      selectedDashboardPeriod = period;
    });

    loadSellerData();
  }

  void handleComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title será criado no próximo passo.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void handleSellerSupport(BuildContext _) {
    Get.to(
      () => const MessageListScreen(
        supportContext: 'seller',
        title: 'Atendimento Lokally',
        showRideChats: false,
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
                        StoreSellerPeriodSelector(
                          primaryColor: primaryColor,
                          selectedPeriod: selectedDashboardPeriod,
                          onChanged: changeDashboardPeriod,
                        ),
                        const SizedBox(height: 14),
                        StoreSellerMainKpiGrid(
                          primaryColor: primaryColor,
                          kpis: sellerKpis,
                          onKpiTap: (title) =>
                              openSellerSection(context, title),
                        ),
                        const SizedBox(height: 16),
                        StoreSellerSalesChart(
                          primaryColor: primaryColor,
                          chart: sellerSalesChart,
                        ),
                        const SizedBox(height: 16),
                        StoreSellerFinancialCard(
                          primaryColor: primaryColor,
                          kpis: sellerKpis,
                          onTap: () => openSellerSection(context, 'Financeiro'),
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
                          sales: latestSellerSales,
                          onTapSale: (title) =>
                              handleComingSoon(context, 'Venda: $title'),
                          onViewAllTap: () =>
                              openSellerSection(context, 'Pedidos'),
                        ),
                        const SizedBox(height: 16),
                        StoreSellerOperationalSummary(
                          primaryColor: primaryColor,
                          kpis: sellerKpis,
                          deliverySettings: sellerDeliverySettings,
                          onItemTap: (title) =>
                              openSellerSection(context, title),
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

class StoreSellerPeriodSelector extends StatelessWidget {
  final Color primaryColor;
  final String selectedPeriod;
  final ValueChanged<String> onChanged;

  const StoreSellerPeriodSelector({
    super.key,
    required this.primaryColor,
    required this.selectedPeriod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<StoreSellerPeriodOption> periods = <StoreSellerPeriodOption>[
      StoreSellerPeriodOption(key: 'today', label: 'Hoje'),
      StoreSellerPeriodOption(key: 'week', label: '7 dias'),
      StoreSellerPeriodOption(key: 'fifteen', label: '15 dias'),
      StoreSellerPeriodOption(key: 'month', label: 'Mensal'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((period) {
          final bool selected = period.key == selectedPeriod;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onChanged(period.key),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? primaryColor : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  period.label,
                  style: textBold.copyWith(
                    color: selected ? Colors.white : Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class StoreSellerPeriodOption {
  final String key;
  final String label;

  StoreSellerPeriodOption({
    required this.key,
    required this.label,
  });
}

class StoreSellerMainKpiGrid extends StatelessWidget {
  final Color primaryColor;
  final StoreSellerDashboardKpis kpis;
  final ValueChanged<String> onKpiTap;

  const StoreSellerMainKpiGrid({
    super.key,
    required this.primaryColor,
    required this.kpis,
    required this.onKpiTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<StoreSellerKpiData> items = [
      StoreSellerKpiData(
        title: 'Vendas',
        value: kpis.formattedPeriodSales,
        icon: Icons.payments_outlined,
      ),
      StoreSellerKpiData(
        title: 'Pedidos',
        value: '${kpis.periodOrders}',
        icon: Icons.receipt_long_outlined,
      ),
      StoreSellerKpiData(
        title: 'Produtos ativos',
        value: '${kpis.approvedProducts}',
        icon: Icons.inventory_2_outlined,
      ),
      StoreSellerKpiData(
        title: 'Repasses feitos',
        value: kpis.formattedPayoutPaidTotal,
        icon: Icons.check_circle_outline_rounded,
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
  final List<StoreSellerSalesChartData> chart;

  const StoreSellerSalesChart({
    super.key,
    required this.primaryColor,
    required this.chart,
  });

  @override
  Widget build(BuildContext context) {
    final List<StoreSellerSalesChartData> rows = chart.isNotEmpty
        ? chart
        : <StoreSellerSalesChartData>[
            StoreSellerSalesChartData.empty(''),
            StoreSellerSalesChartData.empty(''),
            StoreSellerSalesChartData.empty(''),
            StoreSellerSalesChartData.empty(''),
            StoreSellerSalesChartData.empty(''),
            StoreSellerSalesChartData.empty(''),
            StoreSellerSalesChartData.empty(''),
          ];
    final double maxValue = rows.fold<double>(0, (max, row) {
      return row.salesTotal > max ? row.salesTotal : max;
    });

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
              children: List.generate(rows.length, (index) {
                final StoreSellerSalesChartData row = rows[index];
                final double ratio =
                    maxValue <= 0 ? 0 : row.salesTotal / maxValue;
                final double height = 18 + (ratio * 102);
                final bool hasSale = row.salesTotal > 0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          row.ordersCount > 0 ? '${row.ordersCount}' : '',
                          style: textBold.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          height: height,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: hasSale
                                ? primaryColor
                                : primaryColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          row.label.isNotEmpty ? row.label : '-',
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
  final StoreSellerDashboardKpis kpis;
  final VoidCallback onTap;

  const StoreSellerFinancialCard({
    super.key,
    required this.primaryColor,
    required this.kpis,
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
                kpis.formattedPayoutPendingTotal,
                style: textBold.copyWith(
                  color: Colors.white,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Valor pendente de transferência pela Lokally, conforme pedidos liberados e regras de repasse.',
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
                      title: 'Repasses feitos',
                      value: kpis.formattedPayoutPaidTotal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StoreSellerMiniDarkInfo(
                      title: 'A receber',
                      value: kpis.formattedPayoutPendingTotal,
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
      StoreSellerMenuData(
        title: 'Falar com a Lokally',
        description: 'Atendimento para sua loja',
        icon: Icons.support_agent_outlined,
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
  final List<StoreSellerSaleData> sales;
  final ValueChanged<String> onTapSale;
  final VoidCallback onViewAllTap;

  const StoreSellerLatestSales({
    super.key,
    required this.primaryColor,
    required this.sales,
    required this.onTapSale,
    required this.onViewAllTap,
  });

  @override
  Widget build(BuildContext context) {
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
          if (sales.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: Text(
                'Nenhuma venda registrada até o momento.',
                style: textRegular.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 12.4,
                ),
              ),
            )
          else
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
  final StoreSellerDashboardKpis kpis;
  final StoreSellerDeliverySettings deliverySettings;
  final ValueChanged<String> onItemTap;

  const StoreSellerOperationalSummary({
    super.key,
    required this.primaryColor,
    required this.kpis,
    required this.deliverySettings,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final String deliveryValue = deliverySettings.mainDeliveryStatusLabel;
    final String deliveryDescription = deliverySettings.mainDeliveryDescription;

    return Row(
      children: [
        Expanded(
          child: StoreSellerOperationalCard(
            title: 'Pendentes',
            value: '${kpis.pendingOrders}',
            description: 'Pedidos aguardando pagamento',
            icon: Icons.hourglass_bottom_outlined,
            primaryColor: primaryColor,
            alertColor: Colors.orange.shade700,
            onTap: () => onItemTap('Pedidos pendentes'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StoreSellerOperationalCard(
            title: 'Entrega e serviços',
            value: deliveryValue,
            description: deliveryDescription,
            icon: Icons.local_shipping_outlined,
            primaryColor: primaryColor,
            onTap: () => onItemTap('Entrega e retirada'),
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
        title: 'Plano da loja',
        description: 'Mensalidade ou comissão',
        icon: Icons.price_change_outlined,
      ),
      StoreSellerMenuData(
        title: 'Financeiro',
        description: 'Taxas, repasses e bloqueios',
        icon: Icons.account_balance_wallet_outlined,
      ),
      StoreSellerMenuData(
        title: 'Falar com a Lokally',
        description: 'Atendimento para sua loja',
        icon: Icons.support_agent_outlined,
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

class StoreSellerProfileScreen extends StatefulWidget {
  final StoreSellerProfileData initialProfile;
  final ValueChanged<Map<String, dynamic>> onProfileSaved;

  const StoreSellerProfileScreen({
    super.key,
    required this.initialProfile,
    required this.onProfileSaved,
  });

  @override
  State<StoreSellerProfileScreen> createState() =>
      _StoreSellerProfileScreenState();
}

class _StoreSellerProfileScreenState extends State<StoreSellerProfileScreen> {
  static const String updateProfileUri = '/api/customer/store/seller/profile';

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late final TextEditingController storeNameController;
  late final TextEditingController ownerNameController;
  late final TextEditingController descriptionController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController addressController;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    storeNameController =
        TextEditingController(text: widget.initialProfile.storeName);
    ownerNameController =
        TextEditingController(text: widget.initialProfile.ownerName);
    descriptionController =
        TextEditingController(text: widget.initialProfile.description);
    phoneController = TextEditingController(text: widget.initialProfile.phone);
    emailController = TextEditingController(text: widget.initialProfile.email);
    addressController =
        TextEditingController(text: widget.initialProfile.address);
  }

  @override
  void dispose() {
    storeNameController.dispose();
    ownerNameController.dispose();
    descriptionController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    if (isSaving) {
      return;
    }

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().postData(
        updateProfileUri,
        <String, String>{
          'store_name': storeNameController.text.trim(),
          'owner_name': ownerNameController.text.trim(),
          'description': descriptionController.text.trim(),
          'phone': phoneController.text.trim(),
          'email': emailController.text.trim(),
          'address': addressController.text.trim(),
        },
      );

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;
      String message = response.statusCode == 200
          ? 'Dados da loja atualizados com sucesso.'
          : 'Não foi possível atualizar os dados da loja.';

      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }

      if (response.statusCode == 200 && body is Map && body['status'] == true) {
        final dynamic dataValue = body['data'];
        final Map<String, dynamic> data = dataValue is Map
            ? Map<String, dynamic>.from(dataValue)
            : <String, dynamic>{};
        final dynamic sellerValue = data['seller'];
        final Map<String, dynamic> seller = sellerValue is Map
            ? Map<String, dynamic>.from(sellerValue)
            : <String, dynamic>{};

        widget.onProfileSaved(seller);
        showProfileMessage(message);
        return;
      }

      showProfileMessage(message);
    } catch (_) {
      if (mounted) {
        showProfileMessage('Não foi possível atualizar os dados da loja.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void showProfileMessage(String message) {
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          'Dados da loja',
          style: textBold.copyWith(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Dimensions.paddingSizeDefault,
          16,
          Dimensions.paddingSizeDefault,
          28,
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informações da loja',
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Atualize os dados principais do seu perfil comercial.',
                style: textRegular.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 12.8,
                  height: 1.32,
                ),
              ),
              const SizedBox(height: 18),
              StoreSellerProfileForm(
                primaryColor: primaryColor,
                storeNameController: storeNameController,
                ownerNameController: ownerNameController,
                descriptionController: descriptionController,
                phoneController: phoneController,
                emailController: emailController,
                addressController: addressController,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isSaving ? null : saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.3,
                          ),
                        )
                      : Text(
                          'Salvar dados da loja',
                          style: textBold.copyWith(
                            color: Colors.white,
                            fontSize: 14.2,
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

class StoreSellerProfileForm extends StatelessWidget {
  final Color primaryColor;
  final TextEditingController storeNameController;
  final TextEditingController ownerNameController;
  final TextEditingController descriptionController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController addressController;

  const StoreSellerProfileForm({
    super.key,
    required this.primaryColor,
    required this.storeNameController,
    required this.ownerNameController,
    required this.descriptionController,
    required this.phoneController,
    required this.emailController,
    required this.addressController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informações principais',
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 16.5,
          ),
        ),
        const SizedBox(height: 13),
        StoreSellerProfileField(
          controller: storeNameController,
          label: 'Nome da loja',
          hint: 'Ex: Optima Creative',
          icon: Icons.storefront_outlined,
          requiredField: true,
        ),
        const SizedBox(height: 12),
        StoreSellerProfileField(
          controller: ownerNameController,
          label: 'Responsável pela loja',
          hint: 'Nome do responsável pela loja',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 12),
        StoreSellerProfileField(
          controller: descriptionController,
          label: 'Descrição da loja',
          hint: 'Descreva sua loja, produtos ou serviços',
          icon: Icons.description_outlined,
          minLines: 4,
          maxLines: 7,
        ),
        const SizedBox(height: 18),
        Text(
          'Contato e localização',
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 16.5,
          ),
        ),
        const SizedBox(height: 13),
        StoreSellerProfileField(
          controller: phoneController,
          label: 'Telefone ou WhatsApp',
          hint: 'Ex: +55 35 99999-9999',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        StoreSellerProfileField(
          controller: emailController,
          label: 'E-mail',
          hint: 'Ex: contato@sualoja.com.br',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          emailField: true,
        ),
        const SizedBox(height: 12),
        StoreSellerProfileField(
          controller: addressController,
          label: 'Endereço',
          hint: 'Endereço da loja ou ponto de atendimento',
          icon: Icons.location_on_outlined,
          minLines: 3,
          maxLines: 5,
        ),
      ],
    );
  }
}

class StoreSellerProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool requiredField;
  final bool emailField;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;

  const StoreSellerProfileField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.requiredField = false,
    this.emailField = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      validator: (value) {
        final String fieldValue = value?.trim() ?? '';

        if (requiredField && fieldValue.isEmpty) {
          return 'Preencha este campo.';
        }

        if (emailField &&
            fieldValue.isNotEmpty &&
            !GetUtils.isEmail(fieldValue)) {
          return 'Digite um e-mail válido.';
        }

        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryColor),
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: const Color(0xFFF8FAFA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primaryColor, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

class StoreSellerDeliverySettingsScreen extends StatefulWidget {
  final StoreSellerDeliverySettings initialSettings;
  final ValueChanged<StoreSellerDeliverySettings> onSettingsSaved;

  const StoreSellerDeliverySettingsScreen({
    super.key,
    required this.initialSettings,
    required this.onSettingsSaved,
  });

  @override
  State<StoreSellerDeliverySettingsScreen> createState() =>
      _StoreSellerDeliverySettingsScreenState();
}

class _StoreSellerDeliverySettingsScreenState
    extends State<StoreSellerDeliverySettingsScreen> {
  static const String updateDeliverySettingsUri =
      '/api/customer/store/seller/delivery-settings';

  late bool pickupEnabled;
  late bool ownDeliveryEnabled;
  late bool lokallyDeliveryEnabled;
  late bool onlineEnabled;
  late bool downloadEnabled;
  late bool presentialEnabled;
  late bool homeOfficeEnabled;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    pickupEnabled = widget.initialSettings.pickupEnabled;
    ownDeliveryEnabled = widget.initialSettings.ownDeliveryEnabled;
    lokallyDeliveryEnabled = widget.initialSettings.lokallyDeliveryEnabled;
    onlineEnabled = widget.initialSettings.onlineEnabled;
    downloadEnabled = widget.initialSettings.downloadEnabled;
    presentialEnabled = widget.initialSettings.presentialEnabled;
    homeOfficeEnabled = widget.initialSettings.homeOfficeEnabled;
  }

  Future<void> saveDeliverySettings() async {
    if (isSaving) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().postData(
        updateDeliverySettingsUri,
        <String, String>{
          'pickup_enabled': pickupEnabled ? '1' : '0',
          'own_delivery_enabled': ownDeliveryEnabled ? '1' : '0',
          'lokally_delivery_enabled': lokallyDeliveryEnabled ? '1' : '0',
          'online_enabled': onlineEnabled ? '1' : '0',
          'download_enabled': downloadEnabled ? '1' : '0',
          'presential_enabled': presentialEnabled ? '1' : '0',
          'home_office_enabled': homeOfficeEnabled ? '1' : '0',
          'own_delivery_base_fee':
              widget.initialSettings.ownDeliveryBaseFee.toStringAsFixed(2),
          'lokally_delivery_base_fee':
              widget.initialSettings.lokallyDeliveryBaseFee.toStringAsFixed(2),
        },
      );

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;
      String message = response.statusCode == 200
          ? 'Entrega e retirada atualizadas com sucesso.'
          : 'Não foi possível atualizar entrega e retirada.';

      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }

      if (response.statusCode == 200 && body is Map && body['status'] == true) {
        final dynamic dataValue = body['data'];
        final Map<String, dynamic> data = dataValue is Map
            ? Map<String, dynamic>.from(dataValue)
            : <String, dynamic>{};
        final dynamic settingsValue = data['delivery_settings'];
        final Map<String, dynamic> settings = settingsValue is Map
            ? Map<String, dynamic>.from(settingsValue)
            : <String, dynamic>{};

        final StoreSellerDeliverySettings updatedSettings =
            StoreSellerDeliverySettings.fromMap(settings);

        widget.onSettingsSaved(updatedSettings);
        showDeliveryMessage(message);
        return;
      }

      showDeliveryMessage(message);
    } catch (_) {
      if (mounted) {
        showDeliveryMessage('Não foi possível atualizar entrega e retirada.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void showDeliveryMessage(String message) {
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          'Entrega e retirada',
          style: textBold.copyWith(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Dimensions.paddingSizeDefault,
          16,
          Dimensions.paddingSizeDefault,
          28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Produtos físicos',
              style: textBold.copyWith(
                color: Colors.black87,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Defina como os produtos físicos poderão ser retirados ou entregues.',
              style: textRegular.copyWith(
                color: Colors.grey.shade600,
                fontSize: 12.8,
                height: 1.32,
              ),
            ),
            const SizedBox(height: 14),
            StoreSellerDeliverySwitchTile(
              title: 'Retirada',
              description:
                  'Permitir que o cliente retire o pedido conforme combinado.',
              value: pickupEnabled,
              primaryColor: primaryColor,
              onChanged: (value) => setState(() => pickupEnabled = value),
            ),
            StoreSellerDeliverySwitchTile(
              title: 'Entrega própria',
              description: 'Permitir entrega feita pela própria loja.',
              value: ownDeliveryEnabled,
              primaryColor: primaryColor,
              onChanged: (value) => setState(() => ownDeliveryEnabled = value),
            ),
            StoreSellerDeliverySwitchTile(
              title: 'Lokally Envios',
              description:
                  'Permitir entrega usando parceiros de entrega da Lokally.',
              value: lokallyDeliveryEnabled,
              primaryColor: primaryColor,
              onChanged: (value) =>
                  setState(() => lokallyDeliveryEnabled = value),
            ),
            const SizedBox(height: 24),
            Text(
              'Serviços',
              style: textBold.copyWith(
                color: Colors.black87,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Defina os formatos disponíveis para serviços cadastrados na sua loja.',
              style: textRegular.copyWith(
                color: Colors.grey.shade600,
                fontSize: 12.8,
                height: 1.32,
              ),
            ),
            const SizedBox(height: 14),
            StoreSellerDeliverySwitchTile(
              title: 'Online',
              description: 'Serviço digital realizado online.',
              value: onlineEnabled,
              primaryColor: primaryColor,
              onChanged: (value) => setState(() => onlineEnabled = value),
            ),
            StoreSellerDeliverySwitchTile(
              title: 'Download',
              description: 'Serviço digital entregue por arquivo ou download.',
              value: downloadEnabled,
              primaryColor: primaryColor,
              onChanged: (value) => setState(() => downloadEnabled = value),
            ),
            StoreSellerDeliverySwitchTile(
              title: 'Presencial',
              description: 'Serviço realizado presencialmente.',
              value: presentialEnabled,
              primaryColor: primaryColor,
              onChanged: (value) => setState(() => presentialEnabled = value),
            ),
            StoreSellerDeliverySwitchTile(
              title: 'Home Office',
              description: 'Serviço remoto combinado entre loja e cliente.',
              value: homeOfficeEnabled,
              primaryColor: primaryColor,
              onChanged: (value) => setState(() => homeOfficeEnabled = value),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSaving ? null : saveDeliverySettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.3,
                        ),
                      )
                    : Text(
                        'Salvar entrega e retirada',
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 14.2,
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

class StoreSellerDeliverySwitchTile extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final Color primaryColor;
  final ValueChanged<bool> onChanged;

  const StoreSellerDeliverySwitchTile({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 12.2,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            activeThumbColor: primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class StoreSellerOffersScreen extends StatefulWidget {
  const StoreSellerOffersScreen({super.key});

  @override
  State<StoreSellerOffersScreen> createState() =>
      _StoreSellerOffersScreenState();
}

class _StoreSellerOffersScreenState extends State<StoreSellerOffersScreen> {
  static const String sellerOffersUri = '/api/customer/store/seller/offers';

  bool isLoading = false;
  bool isActionLoading = false;

  List<StoreSellerOfferData> offers = <StoreSellerOfferData>[];
  List<StoreSellerOfferProductOptionData> products =
      <StoreSellerOfferProductOptionData>[];
  List<StoreSellerOfferCategoryOptionData> categories =
      <StoreSellerOfferCategoryOptionData>[];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadOffers();
    });
  }

  Future<void> loadOffers() async {
    if (isLoading) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final Response response =
          await Get.find<ApiClient>().getData(sellerOffersUri);

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if (response.statusCode != 200 ||
          body is! Map ||
          body['status'] != true) {
        showOfferMessage('Não foi possível carregar suas ofertas.');
        return;
      }

      final dynamic dataValue = body['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic offersValue = data['offers'];
      final List<dynamic> offerList =
          offersValue is List ? offersValue : <dynamic>[];

      final dynamic productsValue = data['products'];
      final List<dynamic> productList =
          productsValue is List ? productsValue : <dynamic>[];

      final dynamic categoriesValue = data['categories'];
      final List<dynamic> categoryList =
          categoriesValue is List ? categoriesValue : <dynamic>[];

      setState(() {
        offers = offerList
            .whereType<Map>()
            .map((item) => StoreSellerOfferData.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList();

        products = productList
            .whereType<Map>()
            .map((item) => StoreSellerOfferProductOptionData.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .where((product) => product.id.isNotEmpty)
            .toList();

        categories = categoryList
            .whereType<Map>()
            .map((item) => StoreSellerOfferCategoryOptionData.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .where((category) => category.id.isNotEmpty)
            .toList();
      });
    } catch (_) {
      if (mounted) {
        showOfferMessage('Não foi possível carregar suas ofertas.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> openOfferForm({StoreSellerOfferData? offer}) async {
    if (products.isEmpty) {
      showOfferMessage(
          'Cadastre e aprove um produto antes de criar uma oferta.');
      return;
    }

    final bool? saved = await Get.to<bool>(
      () => StoreSellerOfferFormScreen(
        offer: offer,
        products: products,
        categories: categories,
      ),
    );

    if (saved == true) {
      await loadOffers();
    }
  }

  Future<void> toggleOffer(StoreSellerOfferData offer) async {
    if (isActionLoading) {
      return;
    }

    setState(() {
      isActionLoading = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().postData(
        '$sellerOffersUri/${offer.id}/toggle',
        <String, String>{},
      );

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;
      String message = offer.isActive
          ? 'Oferta desativada com sucesso.'
          : 'Oferta ativada com sucesso.';

      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }

      showOfferMessage(message);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await loadOffers();
      }
    } catch (_) {
      if (mounted) {
        showOfferMessage('Não foi possível alterar esta oferta.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isActionLoading = false;
        });
      }
    }
  }

  Future<void> deleteOffer(StoreSellerOfferData offer) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir oferta'),
          content: Text('Deseja excluir "${offer.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || isActionLoading) {
      return;
    }

    setState(() {
      isActionLoading = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().postData(
        '$sellerOffersUri/${offer.id}/delete',
        <String, String>{},
      );

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;
      String message = 'Oferta excluída com sucesso.';

      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }

      showOfferMessage(message);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await loadOffers();
      }
    } catch (_) {
      if (mounted) {
        showOfferMessage('Não foi possível excluir esta oferta.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isActionLoading = false;
        });
      }
    }
  }

  void showOfferMessage(String message) {
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          'Ofertas e promoções',
          style: textBold.copyWith(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadOffers,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: loadOffers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            Dimensions.paddingSizeDefault,
            16,
            Dimensions.paddingSizeDefault,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ofertas do lojista',
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Crie promoções para produto, categoria ou loja inteira.',
                style: textRegular.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 12.8,
                  height: 1.32,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isLoading || isActionLoading
                      ? null
                      : () => openOfferForm(),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    'Criar oferta',
                    style: textBold.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: CircularProgressIndicator(
                      color: primaryColor,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else if (offers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nenhuma oferta cadastrada até o momento.',
                    style: textRegular.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                ...offers.map(
                  (offer) => StoreSellerOfferTile(
                    offer: offer,
                    primaryColor: primaryColor,
                    isActionLoading: isActionLoading,
                    onEdit: () => openOfferForm(offer: offer),
                    onToggle: () => toggleOffer(offer),
                    onDelete: () => deleteOffer(offer),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreSellerOfferTile extends StatelessWidget {
  final StoreSellerOfferData offer;
  final Color primaryColor;
  final bool isActionLoading;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const StoreSellerOfferTile({
    super.key,
    required this.offer,
    required this.primaryColor,
    required this.isActionLoading,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = offer.isActive ? primaryColor : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              offer.isActive
                  ? Icons.local_offer_outlined
                  : Icons.pause_circle_outline_rounded,
              color: statusColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        offer.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 14.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      offer.isActive ? 'Ativa' : 'Pausada',
                      style: textBold.copyWith(
                        color: statusColor,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${offer.scopeLabel} • ${offer.targetLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 12.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  offer.discountLabel,
                  style: textBold.copyWith(
                    color: primaryColor,
                    fontSize: 12.8,
                  ),
                ),
                if (offer.periodLabel.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    offer.periodLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 11.4,
                      height: 1.22,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            enabled: !isActionLoading,
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              }
              if (value == 'toggle') {
                onToggle();
              }
              if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem<String>(
                value: 'edit',
                child: Text('Editar'),
              ),
              PopupMenuItem<String>(
                value: 'toggle',
                child: Text(offer.isActive ? 'Pausar' : 'Ativar'),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Excluir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StoreSellerOfferFormScreen extends StatefulWidget {
  final StoreSellerOfferData? offer;
  final List<StoreSellerOfferProductOptionData> products;
  final List<StoreSellerOfferCategoryOptionData> categories;

  const StoreSellerOfferFormScreen({
    super.key,
    required this.offer,
    required this.products,
    required this.categories,
  });

  @override
  State<StoreSellerOfferFormScreen> createState() =>
      _StoreSellerOfferFormScreenState();
}

class _StoreSellerOfferFormScreenState
    extends State<StoreSellerOfferFormScreen> {
  static const String sellerOffersUri = '/api/customer/store/seller/offers';

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController discountValueController = TextEditingController();
  final TextEditingController priorityController = TextEditingController();

  late String scopeType;
  late String discountType;
  String selectedProductId = '';
  String selectedCategoryId = '';
  DateTime? startsAt;
  DateTime? endsAt;
  bool isActive = true;
  bool isSaving = false;

  bool get isEditing => widget.offer != null;

  @override
  void initState() {
    super.initState();

    final StoreSellerOfferData? offer = widget.offer;
    titleController.text = offer?.title ?? '';
    descriptionController.text = offer?.description ?? '';
    discountValueController.text = offer == null || offer.discountValue <= 0
        ? ''
        : offer.discountValue.toStringAsFixed(2).replaceAll('.', ',');
    priorityController.text = '${offer?.priority ?? 0}';
    scopeType = offer?.scopeType ?? 'product';
    discountType = offer?.discountType ?? 'percentage';
    selectedProductId = offer?.productId ?? '';
    selectedCategoryId = offer?.categoryId ?? '';
    startsAt = StoreSellerOfferDateHelper.parse(offer?.startsAt);
    endsAt = StoreSellerOfferDateHelper.parse(offer?.endsAt);
    isActive = offer?.isActive ?? true;

    if (selectedProductId.isEmpty && widget.products.isNotEmpty) {
      selectedProductId = widget.products.first.id;
    }

    if (selectedCategoryId.isEmpty && widget.categories.isNotEmpty) {
      selectedCategoryId = widget.categories.first.id;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    discountValueController.dispose();
    priorityController.dispose();
    super.dispose();
  }

  Future<void> pickDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = isStart
        ? startsAt ?? now
        : endsAt ?? startsAt ?? now.add(const Duration(days: 1));

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (date == null || !mounted) {
      return;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (time == null || !mounted) {
      return;
    }

    setState(() {
      final DateTime selected = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

      if (isStart) {
        startsAt = selected;
        if (endsAt != null && endsAt!.isBefore(startsAt!)) {
          endsAt = startsAt!.add(const Duration(days: 1));
        }
      } else {
        endsAt = selected;
      }
    });
  }

  Future<void> saveOffer() async {
    if (isSaving || !(formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (scopeType == 'product' && selectedProductId.isEmpty) {
      showFormMessage('Selecione um produto.');
      return;
    }

    if (scopeType == 'category' && selectedCategoryId.isEmpty) {
      showFormMessage('Selecione uma categoria.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    final Map<String, String> body = <String, String>{
      'title': titleController.text.trim(),
      'description': descriptionController.text.trim(),
      'scope_type': scopeType,
      'discount_type': discountType,
      'discount_value': discountValueController.text
          .trim()
          .replaceAll('.', '')
          .replaceAll(',', '.'),
      'is_active': isActive ? '1' : '0',
      'priority': priorityController.text.trim().isEmpty
          ? '0'
          : priorityController.text.trim(),
    };

    if (scopeType == 'product') {
      body['product_id'] = selectedProductId;
    }

    if (scopeType == 'category') {
      body['category_id'] = selectedCategoryId;
    }

    if (startsAt != null) {
      body['starts_at'] = StoreSellerOfferDateHelper.toPayload(startsAt!);
    }

    if (endsAt != null) {
      body['ends_at'] = StoreSellerOfferDateHelper.toPayload(endsAt!);
    }

    final String endpoint =
        isEditing ? '$sellerOffersUri/${widget.offer!.id}' : sellerOffersUri;

    try {
      final Response response = await Get.find<ApiClient>().postData(
        endpoint,
        body,
      );

      if (!mounted) {
        return;
      }

      final dynamic responseBody = response.body;
      String message = isEditing
          ? 'Oferta atualizada com sucesso.'
          : 'Oferta criada com sucesso.';

      if (responseBody is Map && responseBody['message'] != null) {
        message = responseBody['message'].toString();
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        showFormMessage(message);
        Get.back(result: true);
        return;
      }

      showFormMessage(message);
    } catch (_) {
      if (mounted) {
        showFormMessage('Não foi possível salvar esta oferta.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void showFormMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String? selectedDropdownProductId() {
    if (scopeType != 'product') {
      return null;
    }

    final bool exists =
        widget.products.any((product) => product.id == selectedProductId);
    return exists ? selectedProductId : null;
  }

  String? selectedDropdownCategoryId() {
    if (scopeType != 'category') {
      return null;
    }

    final bool exists =
        widget.categories.any((category) => category.id == selectedCategoryId);
    return exists ? selectedCategoryId : null;
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          isEditing ? 'Editar oferta' : 'Criar oferta',
          style: textBold.copyWith(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Dimensions.paddingSizeDefault,
            16,
            Dimensions.paddingSizeDefault,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StoreSellerOfferTextField(
                controller: titleController,
                label: 'Título da oferta',
                hint: 'Ex: Semana especial',
                icon: Icons.local_offer_outlined,
                requiredField: true,
              ),
              const SizedBox(height: 14),
              StoreSellerOfferTextField(
                controller: descriptionController,
                label: 'Descrição',
                hint: 'Detalhe a condição da promoção',
                icon: Icons.notes_outlined,
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              StoreSellerOfferDropdown<String>(
                label: 'Aplicar em',
                value: scopeType,
                icon: Icons.tune_outlined,
                items: const [
                  DropdownMenuItem(value: 'product', child: Text('Produto')),
                  DropdownMenuItem(value: 'category', child: Text('Categoria')),
                  DropdownMenuItem(value: 'store', child: Text('Loja inteira')),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    scopeType = value;
                  });
                },
              ),
              if (scopeType == 'product') ...[
                const SizedBox(height: 14),
                StoreSellerOfferDropdown<String>(
                  label: 'Produto',
                  value: selectedDropdownProductId(),
                  icon: Icons.shopping_bag_outlined,
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
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      selectedProductId = value;
                    });
                  },
                ),
              ],
              if (scopeType == 'category') ...[
                const SizedBox(height: 14),
                StoreSellerOfferDropdown<String>(
                  label: 'Categoria',
                  value: selectedDropdownCategoryId(),
                  icon: Icons.category_outlined,
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
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      selectedCategoryId = value;
                    });
                  },
                ),
              ],
              const SizedBox(height: 16),
              StoreSellerOfferDropdown<String>(
                label: 'Tipo de promoção',
                value: discountType,
                icon: Icons.percent_outlined,
                items: const [
                  DropdownMenuItem(
                    value: 'percentage',
                    child: Text('Desconto em porcentagem'),
                  ),
                  DropdownMenuItem(
                    value: 'fixed_amount',
                    child: Text('Desconto em valor'),
                  ),
                  DropdownMenuItem(
                    value: 'promotional_price',
                    child: Text('Preço promocional'),
                  ),
                  DropdownMenuItem(
                    value: 'label_only',
                    child: Text('Destaque sem desconto'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    discountType = value;
                    if (discountType == 'label_only') {
                      discountValueController.text = '';
                    }
                  });
                },
              ),
              if (discountType != 'label_only') ...[
                const SizedBox(height: 14),
                StoreSellerOfferTextField(
                  controller: discountValueController,
                  label: discountType == 'percentage'
                      ? 'Percentual'
                      : discountType == 'fixed_amount'
                          ? 'Valor do desconto'
                          : 'Preço promocional',
                  hint: discountType == 'percentage' ? 'Ex: 10' : 'Ex: 89,90',
                  icon: Icons.sell_outlined,
                  requiredField: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              StoreSellerOfferDateRow(
                label: 'Início',
                value: startsAt,
                primaryColor: primaryColor,
                onPick: () => pickDate(isStart: true),
                onClear: startsAt == null
                    ? null
                    : () => setState(() => startsAt = null),
              ),
              const SizedBox(height: 10),
              StoreSellerOfferDateRow(
                label: 'Fim',
                value: endsAt,
                primaryColor: primaryColor,
                onPick: () => pickDate(isStart: false),
                onClear:
                    endsAt == null ? null : () => setState(() => endsAt = null),
              ),
              const SizedBox(height: 16),
              StoreSellerOfferTextField(
                controller: priorityController,
                label: 'Prioridade',
                hint: '0',
                icon: Icons.sort_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              StoreSellerDeliverySwitchTile(
                title: 'Oferta ativa',
                description: 'Desative quando não quiser exibir esta promoção.',
                value: isActive,
                primaryColor: primaryColor,
                onChanged: (value) => setState(() => isActive = value),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isSaving ? null : saveOffer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.3,
                          ),
                        )
                      : Text(
                          isEditing ? 'Salvar oferta' : 'Criar oferta',
                          style: textBold.copyWith(
                            color: Colors.white,
                            fontSize: 14.2,
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

class StoreSellerOfferTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool requiredField;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;

  const StoreSellerOfferTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.requiredField = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      validator: (value) {
        final String fieldValue = value?.trim() ?? '';

        if (requiredField && fieldValue.isEmpty) {
          return 'Preencha este campo.';
        }

        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryColor),
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: const Color(0xFFF8FAFA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primaryColor, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

class StoreSellerOfferDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const StoreSellerOfferDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      items: items,
      onChanged: items.isEmpty ? null : onChanged,
      validator: (selected) {
        if (items.isNotEmpty && selected == null) {
          return 'Selecione uma opção.';
        }

        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        filled: true,
        fillColor: const Color(0xFFF8FAFA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primaryColor, width: 1.4),
        ),
      ),
    );
  }
}

class StoreSellerOfferDateRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final Color primaryColor;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  const StoreSellerOfferDateRow({
    super.key,
    required this.label,
    required this.value,
    required this.primaryColor,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 14.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value == null
                      ? 'Não definido'
                      : StoreSellerOfferDateHelper.format(value!),
                  style: textRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 12.2,
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            TextButton(
              onPressed: onClear,
              child: const Text('Limpar'),
            ),
          TextButton(
            onPressed: onPick,
            child: Text(
              'Definir',
              style: textBold.copyWith(color: primaryColor),
            ),
          ),
        ],
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

      final bool success =
          response.statusCode == 200 || response.statusCode == 201;

      if (!success) {
        return;
      }

      final dynamic dataValue =
          responseBody is Map ? responseBody['data'] : null;
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};
      final dynamic paymentValue = data['payment'];
      final Map<String, dynamic> payment = paymentValue is Map
          ? Map<String, dynamic>.from(paymentValue)
          : <String, dynamic>{};

      final String paymentUrl = '${payment['payment_url'] ?? ''}'.trim();
      final bool requiresExternalPayment =
          payment['requires_external_payment'] == true ||
              '${payment['requires_external_payment'] ?? ''}' == '1' ||
              '${payment['requires_external_payment'] ?? ''}'.toLowerCase() ==
                  'true';

      await loadBoostData();

      if (selection.paymentMethod == 'mercadopago' || requiresExternalPayment) {
        if (paymentUrl.isEmpty) {
          showBoostMessage(
            'Solicitação criada, mas não foi possível abrir o Mercado Pago.',
          );
          return;
        }

        final bool opened = await launchUrl(
          Uri.parse(paymentUrl),
          mode: LaunchMode.externalApplication,
        );

        if (!opened) {
          showBoostMessage('Não foi possível abrir o Mercado Pago.');
          return;
        }

        showBoostMessage(
          'Finalize o pagamento no Mercado Pago. Após a aprovação, a equipe Lokally iniciará a produção.',
        );
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
                      value: 'mercadopago',
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
                if (selectedPaymentMethod == 'mercadopago') ...[
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
                          : 'Continuar com Mercado Pago',
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

class StoreSellerProfileData {
  final String storeName;
  final String ownerName;
  final String description;
  final String phone;
  final String email;
  final String address;

  StoreSellerProfileData({
    required this.storeName,
    required this.ownerName,
    required this.description,
    required this.phone,
    required this.email,
    required this.address,
  });

  factory StoreSellerProfileData.empty() {
    return StoreSellerProfileData(
      storeName: '',
      ownerName: '',
      description: '',
      phone: '',
      email: '',
      address: '',
    );
  }

  factory StoreSellerProfileData.fromMap(Map<String, dynamic> map) {
    return StoreSellerProfileData(
      storeName: '${map['store_name'] ?? ''}'.trim(),
      ownerName: '${map['owner_name'] ?? ''}'.trim(),
      description: '${map['description'] ?? ''}'.trim(),
      phone: '${map['phone'] ?? ''}'.trim(),
      email: '${map['email'] ?? ''}'.trim(),
      address: '${map['address'] ?? ''}'.trim(),
    );
  }
}

class StoreSellerBillingScreen extends StatefulWidget {
  const StoreSellerBillingScreen({super.key});

  @override
  State<StoreSellerBillingScreen> createState() =>
      _StoreSellerBillingScreenState();
}

class _StoreSellerBillingScreenState extends State<StoreSellerBillingScreen> {
  static const String billingOptionsUri =
      '/api/customer/store/seller/billing-options';
  static const String monthlyBillingUri =
      '/api/customer/store/seller/monthly-billing';

  bool isLoading = false;
  bool isUploadingReceipt = false;
  String currentBillingModel = '';
  String storeZoneName = '';
  List<StoreSellerBillingOptionData> billingOptions =
      <StoreSellerBillingOptionData>[];
  StoreSellerMonthlyBillingData? monthlyBilling;
  StoreSellerMonthlyBillingData? lastPaidBilling;
  String nextMonthlyDueLabel = '';
  int generateInvoiceBeforeDays = 5;

  StoreSellerBillingOptionData? get currentOption {
    for (final StoreSellerBillingOptionData option in billingOptions) {
      if (option.key == currentBillingModel) {
        return option;
      }
    }

    if (currentBillingModel.isNotEmpty) {
      return StoreSellerBillingOptionData(
        key: currentBillingModel,
        title: StoreSellerBillingOptionData.defaultTitleForKey(
          currentBillingModel,
        ),
        priceLabel: StoreSellerBillingOptionData.defaultPriceForKey(
          currentBillingModel,
        ),
      );
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    loadBillingOptions();
  }

  Future<void> loadBillingOptions() async {
    if (isLoading) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final Response response =
          await Get.find<ApiClient>().getData(billingOptionsUri);

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if (response.statusCode != 200 || body is! Map) {
        setState(() {
          billingOptions = <StoreSellerBillingOptionData>[];
          currentBillingModel = '';
          monthlyBilling = null;
          lastPaidBilling = null;
          nextMonthlyDueLabel = '';
          generateInvoiceBeforeDays = 5;
          isLoading = false;
        });
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

      final dynamic optionsValue = data['options'];
      final List<dynamic> options =
          optionsValue is List ? optionsValue : <dynamic>[];

      final List<StoreSellerBillingOptionData> loadedOptions = options
          .whereType<Map>()
          .map((item) => StoreSellerBillingOptionData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((option) => option.key.isNotEmpty)
          .toList();

      final String currentModel =
          '${data['current_billing_model'] ?? ''}'.trim();

      StoreSellerMonthlyBillingState loadedMonthlyState =
          StoreSellerMonthlyBillingState.empty();

      if (currentModel == 'monthly') {
        loadedMonthlyState = await loadMonthlyBillingData();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        billingOptions = loadedOptions;
        currentBillingModel = currentModel;
        storeZoneName = '${seller['zone_name'] ?? ''}'.trim();
        monthlyBilling = loadedMonthlyState.openBilling;
        lastPaidBilling = loadedMonthlyState.lastPaidBilling;
        nextMonthlyDueLabel = loadedMonthlyState.nextDueLabel;
        generateInvoiceBeforeDays =
            loadedMonthlyState.generateInvoiceBeforeDays;
        isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          billingOptions = <StoreSellerBillingOptionData>[];
          currentBillingModel = '';
          monthlyBilling = null;
          lastPaidBilling = null;
          nextMonthlyDueLabel = '';
          generateInvoiceBeforeDays = 5;
          isLoading = false;
        });
      }
    }
  }

  Future<StoreSellerMonthlyBillingState> loadMonthlyBillingData() async {
    try {
      final Response response =
          await Get.find<ApiClient>().getData(monthlyBillingUri);

      final dynamic body = response.body;

      if (response.statusCode != 200 ||
          body is! Map ||
          body['status'] != true) {
        return StoreSellerMonthlyBillingState.empty();
      }

      final dynamic dataValue = body['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic openBillingValue = data['monthly_billing'];
      final dynamic lastPaidBillingValue = data['last_paid_billing'];

      final StoreSellerMonthlyBillingData? openBilling = openBillingValue is Map
          ? StoreSellerMonthlyBillingData.fromMap(
              Map<String, dynamic>.from(openBillingValue),
            )
          : null;

      final StoreSellerMonthlyBillingData? paidBilling =
          lastPaidBillingValue is Map
              ? StoreSellerMonthlyBillingData.fromMap(
                  Map<String, dynamic>.from(lastPaidBillingValue),
                )
              : null;

      return StoreSellerMonthlyBillingState(
        openBilling: openBilling,
        lastPaidBilling: paidBilling,
        nextDueLabel: '${data['next_due_label'] ?? ''}'.trim(),
        generateInvoiceBeforeDays:
            int.tryParse('${data['generate_invoice_before_days'] ?? '5'}') ?? 5,
      );
    } catch (_) {
      return StoreSellerMonthlyBillingState.empty();
    }
  }

  Future<void> copyPixCode(String pixCode) async {
    if (pixCode.trim().isEmpty) {
      showBillingMessage('PIX copia e cola não disponível.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: pixCode));
    showBillingMessage('PIX copia e cola copiado.');
  }

  Future<void> pickAndUploadReceipt(
      StoreSellerMonthlyBillingData billing) async {
    if (isUploadingReceipt) {
      return;
    }

    final XFile? pickedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: AppConstants.imageQuality,
    );

    if (pickedImage == null) {
      return;
    }

    setState(() {
      isUploadingReceipt = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().postMultipartData(
        '$monthlyBillingUri/${billing.id}/receipt',
        <String, String>{},
        MultipartBody('receipt_file', pickedImage),
        <MultipartBody>[],
      );

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;
      String message = response.statusCode == 200
          ? 'Comprovante enviado com sucesso.'
          : 'Não foi possível enviar o comprovante.';

      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }

      showBillingMessage(message);

      if (response.statusCode == 200 && body is Map && body['status'] == true) {
        await loadBillingOptions();
      }
    } catch (_) {
      if (mounted) {
        showBillingMessage('Não foi possível enviar o comprovante.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isUploadingReceipt = false;
        });
      }
    }
  }

  void showBillingMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void openPaidBillingDetails(StoreSellerMonthlyBillingData billing) {
    final Color primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.green.shade700,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mensalidade Marketplace paga',
                            style: textBold.copyWith(
                              color: Colors.black87,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            billing.statusLabel.isNotEmpty
                                ? billing.statusLabel
                                : 'Pagamento confirmado',
                            style: textRegular.copyWith(
                              color: Colors.green.shade700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                StoreSellerBillingDetailLine(
                  label: 'Valor',
                  value: billing.amountLabel,
                ),
                StoreSellerBillingDetailLine(
                  label: 'Pago em',
                  value: billing.paidLabel.isNotEmpty
                      ? billing.paidLabel
                      : 'Pagamento confirmado',
                ),
                StoreSellerBillingDetailLine(
                  label: 'Vencimento original',
                  value: billing.dueLabel.replaceFirst('Vencimento: ', ''),
                ),
                if (nextMonthlyDueLabel.isNotEmpty)
                  StoreSellerBillingDetailLine(
                    label: 'Próximo vencimento',
                    value: nextMonthlyDueLabel,
                  ),
                if (billing.hasReceipt)
                  StoreSellerBillingDetailLine(
                    label: 'Comprovante',
                    value: billing.receiptUploadedAt.isNotEmpty
                        ? 'Enviado em ${StoreSellerMonthlyBillingData.formatDateTime(billing.receiptUploadedAt)}'
                        : 'Comprovante enviado',
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Entendi',
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final StoreSellerBillingOptionData? activeOption = currentOption;
    final StoreSellerMonthlyBillingData? activeMonthlyBilling = monthlyBilling;
    final StoreSellerMonthlyBillingData? activeLastPaidBilling =
        lastPaidBilling;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          'Plano da loja',
          style: textBold.copyWith(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: loadBillingOptions,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            Dimensions.paddingSizeDefault,
            16,
            Dimensions.paddingSizeDefault,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plano da loja',
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                storeZoneName.isNotEmpty
                    ? 'Confira o plano ativo para $storeZoneName.'
                    : 'Confira o plano ativo da sua loja.',
                style: textRegular.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 12.8,
                  height: 1.32,
                ),
              ),
              const SizedBox(height: 18),
              if (isLoading) ...[
                StoreSellerBillingLoading(primaryColor: primaryColor),
              ] else if (activeOption == null) ...[
                StoreSellerBillingEmpty(primaryColor: primaryColor),
              ] else ...[
                StoreSellerBillingOptionCard(
                  option: activeOption,
                  primaryColor: primaryColor,
                ),
                if (activeOption.key == 'monthly') ...[
                  const SizedBox(height: 16),
                  if (activeMonthlyBilling != null)
                    StoreSellerMonthlyBillingCard(
                      billing: activeMonthlyBilling,
                      primaryColor: primaryColor,
                      isUploadingReceipt: isUploadingReceipt,
                      onCopyPix: () => copyPixCode(
                        activeMonthlyBilling.pixCopyPaste,
                      ),
                      onUploadReceipt: () =>
                          pickAndUploadReceipt(activeMonthlyBilling),
                    )
                  else ...[
                    if (activeLastPaidBilling != null)
                      StoreSellerMonthlyPaidBillingCard(
                        billing: activeLastPaidBilling,
                        primaryColor: primaryColor,
                        onTap: () => openPaidBillingDetails(
                          activeLastPaidBilling,
                        ),
                      )
                    else
                      StoreSellerMonthlyBillingEmpty(
                        primaryColor: primaryColor,
                        generateInvoiceBeforeDays: generateInvoiceBeforeDays,
                      ),
                    if (nextMonthlyDueLabel.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      StoreSellerMonthlyNextDueCard(
                        primaryColor: primaryColor,
                        nextDueLabel: nextMonthlyDueLabel,
                        generateInvoiceBeforeDays: generateInvoiceBeforeDays,
                      ),
                    ],
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class StoreSellerBillingOptionCard extends StatelessWidget {
  final StoreSellerBillingOptionData option;
  final Color primaryColor;

  const StoreSellerBillingOptionCard({
    super.key,
    required this.option,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.28),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 16.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  option.priceLabel,
                  style: textBold.copyWith(
                    color: primaryColor,
                    fontSize: 18.5,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  option.shortDescription,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 12.4,
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

class StoreSellerMonthlyBillingCard extends StatelessWidget {
  final StoreSellerMonthlyBillingData billing;
  final Color primaryColor;
  final bool isUploadingReceipt;
  final VoidCallback onCopyPix;
  final VoidCallback onUploadReceipt;

  const StoreSellerMonthlyBillingCard({
    super.key,
    required this.billing,
    required this.primaryColor,
    required this.isUploadingReceipt,
    required this.onCopyPix,
    required this.onUploadReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = billing.isPaid
        ? Colors.green.shade700
        : billing.isWaitingReview
            ? Colors.blue.shade700
            : billing.isOverdue
                ? Colors.redAccent
                : Colors.orange.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 8),
            blurRadius: 20,
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  billing.isWaitingReview
                      ? Icons.receipt_long_outlined
                      : Icons.qr_code_2_rounded,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mensalidade Marketplace',
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 16.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      billing.statusLabel,
                      style: textBold.copyWith(
                        color: statusColor,
                        fontSize: 12.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  billing.amountLabel,
                  style: textBold.copyWith(
                    color: primaryColor,
                    fontSize: 25,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  billing.dueLabel,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 12.4,
                  ),
                ),
                if (billing.graceLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    billing.graceLabel,
                    style: textRegular.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 11.8,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          StoreSellerBillingInfoRow(
            icon: Icons.account_balance_outlined,
            title: 'Recebedor',
            value: billing.receiverLabel,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 10),
          StoreSellerBillingInfoRow(
            icon: Icons.copy_rounded,
            title: 'PIX copia e cola',
            value: billing.shortPixCode,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: billing.pixCopyPaste.isEmpty ? null : onCopyPix,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(
                'Copiar PIX copia e cola',
                style: textBold.copyWith(
                  color: Colors.white,
                  fontSize: 13.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed:
                  billing.isPaid || isUploadingReceipt ? null : onUploadReceipt,
              icon: isUploadingReceipt
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: primaryColor,
                        strokeWidth: 2.2,
                      ),
                    )
                  : const Icon(Icons.upload_file_rounded, size: 19),
              label: Text(
                isUploadingReceipt
                    ? 'Enviando comprovante...'
                    : billing.hasReceipt
                        ? 'Enviar novo comprovante'
                        : 'Enviar comprovante',
                style: textBold.copyWith(
                  color: billing.isPaid ? Colors.grey : primaryColor,
                  fontSize: 13.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(
                  color: billing.isPaid
                      ? Colors.grey.shade300
                      : primaryColor.withValues(alpha: 0.55),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (billing.hasReceipt) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.16)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      billing.receiptUploadedAt.isNotEmpty
                          ? 'Comprovante enviado em ${billing.receiptUploadedAt}. Aguarde análise da Lokally.'
                          : 'Comprovante enviado. Aguarde análise da Lokally.',
                      style: textRegular.copyWith(
                        color: Colors.blue.shade800,
                        fontSize: 12.1,
                        height: 1.28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Após enviar o comprovante, o pagamento ficará aguardando análise. A loja só será liberada quando a Lokally confirmar o recebimento no ADM.',
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 12.2,
              height: 1.32,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerMonthlyPaidBillingCard extends StatelessWidget {
  final StoreSellerMonthlyBillingData billing;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreSellerMonthlyPaidBillingCard({
    super.key,
    required this.billing,
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
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.green.withValues(alpha: 0.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.green.shade700,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mensalidade Marketplace paga',
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 15.8,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${billing.amountLabel} • ${billing.paidLabel.isNotEmpty ? billing.paidLabel : 'pagamento confirmado'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade700,
                        fontSize: 12.2,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toque para ver detalhes',
                      style: textBold.copyWith(
                        color: primaryColor,
                        fontSize: 12.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_right_rounded,
                color: primaryColor,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreSellerMonthlyNextDueCard extends StatelessWidget {
  final Color primaryColor;
  final String nextDueLabel;
  final int generateInvoiceBeforeDays;

  const StoreSellerMonthlyNextDueCard({
    super.key,
    required this.primaryColor,
    required this.nextDueLabel,
    required this.generateInvoiceBeforeDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_available_outlined,
            color: primaryColor,
            size: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Próximo vencimento: $nextDueLabel',
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 14.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A nova fatura será liberada $generateInvoiceBeforeDays dias antes do vencimento.',
                  style: textRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 12.1,
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

class StoreSellerBillingDetailLine extends StatelessWidget {
  final String label;
  final String value;

  const StoreSellerBillingDetailLine({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: textRegular.copyWith(
                color: Colors.grey.shade600,
                fontSize: 12.2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: textBold.copyWith(
                color: Colors.black87,
                fontSize: 12.8,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerBillingInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color primaryColor;

  const StoreSellerBillingInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: primaryColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value.isNotEmpty ? value : '-',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: textRegular.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 11.8,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StoreSellerMonthlyBillingEmpty extends StatelessWidget {
  final Color primaryColor;
  final int generateInvoiceBeforeDays;

  const StoreSellerMonthlyBillingEmpty({
    super.key,
    required this.primaryColor,
    this.generateInvoiceBeforeDays = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            color: Colors.orange.shade700,
            size: 26,
          ),
          const SizedBox(height: 10),
          Text(
            'Nenhuma fatura aberta no momento',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Quando chegar o período de pagamento, a fatura será liberada $generateInvoiceBeforeDays dias antes do vencimento.',
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerBillingLoading extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerBillingLoading({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
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

class StoreSellerBillingEmpty extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerBillingEmpty({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primaryColor.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: primaryColor,
            size: 26,
          ),
          const SizedBox(height: 10),
          Text(
            'Plano indisponível no momento',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Tente novamente mais tarde.',
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerMonthlyBillingState {
  final StoreSellerMonthlyBillingData? openBilling;
  final StoreSellerMonthlyBillingData? lastPaidBilling;
  final String nextDueLabel;
  final int generateInvoiceBeforeDays;

  StoreSellerMonthlyBillingState({
    required this.openBilling,
    required this.lastPaidBilling,
    required this.nextDueLabel,
    required this.generateInvoiceBeforeDays,
  });

  factory StoreSellerMonthlyBillingState.empty() {
    return StoreSellerMonthlyBillingState(
      openBilling: null,
      lastPaidBilling: null,
      nextDueLabel: '',
      generateInvoiceBeforeDays: 5,
    );
  }
}

class StoreSellerBillingOptionData {
  final String key;
  final String title;
  final String priceLabel;

  StoreSellerBillingOptionData({
    required this.key,
    required this.title,
    required this.priceLabel,
  });

  factory StoreSellerBillingOptionData.fromMap(Map<String, dynamic> map) {
    final String key = '${map['key'] ?? ''}'.trim();
    final String title = '${map['title'] ?? ''}'.trim();
    final String priceLabel = '${map['price_label'] ?? ''}'.trim();

    return StoreSellerBillingOptionData(
      key: key,
      title: title.isNotEmpty ? title : defaultTitleForKey(key),
      priceLabel: priceLabel.isNotEmpty ? priceLabel : defaultPriceForKey(key),
    );
  }

  String get shortDescription {
    if (key == 'monthly') {
      return 'Mensalidade fixa para vender com mais previsibilidade. Nesta modalidade você assume taxas de cartão, boleto, débito, crédito e parcelamento em até 3 vezes sem juros no Mercado Pago.';
    }

    if (key == 'commission') {
      return 'Sem mensalidade, com taxa aplicada por venda aprovada. Nesta modalidade a Lokally assume taxas de cartão, boleto, débito, crédito e parcelamento em até 3 vezes sem juros no Mercado Pago.';
    }

    return 'Plano disponível para sua loja.';
  }

  static String defaultTitleForKey(String key) {
    if (key == 'monthly') {
      return 'Venda Livremente';
    }

    if (key == 'commission') {
      return 'Comissão por venda';
    }

    return 'Plano da loja';
  }

  static String defaultPriceForKey(String key) {
    if (key == 'monthly') {
      return 'Mensalidade';
    }

    if (key == 'commission') {
      return 'Por venda';
    }

    return '';
  }
}

class StoreSellerMonthlyBillingData {
  final String id;
  final double amount;
  final String amountLabel;
  final String status;
  final String statusLabel;
  final bool isOverdue;
  final String dueAt;
  final String graceUntil;
  final String paidAt;
  final String pixReceiverName;
  final String pixReceiverDocument;
  final String pixBank;
  final String pixCopyPaste;
  final String receiptFile;
  final String receiptUrl;
  final String receiptUploadedAt;
  final String receiptNote;

  StoreSellerMonthlyBillingData({
    required this.id,
    required this.amount,
    required this.amountLabel,
    required this.status,
    required this.statusLabel,
    required this.isOverdue,
    required this.dueAt,
    required this.graceUntil,
    required this.paidAt,
    required this.pixReceiverName,
    required this.pixReceiverDocument,
    required this.pixBank,
    required this.pixCopyPaste,
    required this.receiptFile,
    required this.receiptUrl,
    required this.receiptUploadedAt,
    required this.receiptNote,
  });

  factory StoreSellerMonthlyBillingData.fromMap(Map<String, dynamic> map) {
    final dynamic pixValue = map['pix'];
    final Map<String, dynamic> pix = pixValue is Map
        ? Map<String, dynamic>.from(pixValue)
        : <String, dynamic>{};

    final dynamic receiptValue = map['receipt'];
    final Map<String, dynamic> receipt = receiptValue is Map
        ? Map<String, dynamic>.from(receiptValue)
        : <String, dynamic>{};

    final String amountLabel = '${map['amount_label'] ?? ''}'.trim();
    final double amount = double.tryParse('${map['amount'] ?? '0'}') ?? 0;

    return StoreSellerMonthlyBillingData(
      id: '${map['id'] ?? ''}'.trim(),
      amount: amount,
      amountLabel: amountLabel.isNotEmpty
          ? amountLabel
          : 'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}',
      status: '${map['status'] ?? ''}'.trim(),
      statusLabel: '${map['status_label'] ?? ''}'.trim(),
      isOverdue: map['is_overdue'] == true,
      dueAt: '${map['due_at'] ?? ''}'.trim(),
      graceUntil: '${map['grace_until'] ?? ''}'.trim(),
      paidAt: '${map['paid_at'] ?? ''}'.trim(),
      pixReceiverName: '${pix['receiver_name'] ?? ''}'.trim(),
      pixReceiverDocument: '${pix['receiver_document'] ?? ''}'.trim(),
      pixBank: '${pix['bank'] ?? ''}'.trim(),
      pixCopyPaste: '${pix['copy_paste'] ?? ''}'.trim(),
      receiptFile: '${receipt['file'] ?? ''}'.trim(),
      receiptUrl: '${receipt['url'] ?? ''}'.trim(),
      receiptUploadedAt: '${receipt['uploaded_at'] ?? ''}'.trim(),
      receiptNote: '${receipt['note'] ?? ''}'.trim(),
    );
  }

  bool get isPaid => status == 'paid';

  bool get isWaitingReview => status == 'waiting_review';

  bool get hasReceipt =>
      receiptFile.isNotEmpty ||
      receiptUrl.isNotEmpty ||
      receiptUploadedAt.isNotEmpty;

  String get paidLabel {
    if (paidAt.isEmpty) {
      return '';
    }

    return 'Pago em ${formatDateTime(paidAt)}';
  }

  String get dueLabel {
    if (dueAt.isEmpty) {
      return 'Vencimento não informado.';
    }

    return 'Vencimento: ${formatDateTime(dueAt)}';
  }

  String get graceLabel {
    if (graceUntil.isEmpty) {
      return '';
    }

    return 'Prazo de tolerância: ${formatDateTime(graceUntil)}';
  }

  String get receiverLabel {
    final List<String> parts = <String>[];

    if (pixReceiverName.isNotEmpty) {
      parts.add(pixReceiverName);
    }

    if (pixReceiverDocument.isNotEmpty) {
      parts.add(pixReceiverDocument);
    }

    if (pixBank.isNotEmpty) {
      parts.add(pixBank);
    }

    return parts.join(' • ');
  }

  String get shortPixCode {
    if (pixCopyPaste.isEmpty) {
      return '';
    }

    if (pixCopyPaste.length <= 64) {
      return pixCopyPaste;
    }

    return '${pixCopyPaste.substring(0, 42)}...${pixCopyPaste.substring(pixCopyPaste.length - 12)}';
  }

  static String formatDateTime(String value) {
    if (value.isEmpty) {
      return '';
    }

    final DateTime? parsed = DateTime.tryParse(value);

    if (parsed == null) {
      return value;
    }

    final String day = parsed.day.toString().padLeft(2, '0');
    final String month = parsed.month.toString().padLeft(2, '0');
    final String year = parsed.year.toString();
    final String hour = parsed.hour.toString().padLeft(2, '0');
    final String minute = parsed.minute.toString().padLeft(2, '0');

    return '$day/$month/$year às $hour:$minute';
  }
}

class StoreSellerFinanceScreen extends StatefulWidget {
  const StoreSellerFinanceScreen({super.key});

  @override
  State<StoreSellerFinanceScreen> createState() =>
      _StoreSellerFinanceScreenState();
}

class _StoreSellerFinanceScreenState extends State<StoreSellerFinanceScreen> {
  static const String financeUri = '/api/customer/store/seller/finance';
  static const String payoutSettingsUri =
      '/api/customer/store/seller/finance/payout-settings';

  bool isLoading = false;
  bool isSavingPayoutSettings = false;
  String selectedFinancePeriod = 'today';
  StoreSellerFinanceData financeData = StoreSellerFinanceData.empty();
  String selectedPayoutMethod = 'pix';
  final TextEditingController pixKeyTypeController = TextEditingController();
  final TextEditingController pixKeyController = TextEditingController();
  final TextEditingController bankNameController = TextEditingController();
  final TextEditingController bankAgencyController = TextEditingController();
  final TextEditingController bankAccountController = TextEditingController();
  final TextEditingController bankAccountDigitController =
      TextEditingController();
  final TextEditingController bankAccountTypeController =
      TextEditingController();
  final TextEditingController bankHolderNameController =
      TextEditingController();
  final TextEditingController bankHolderDocumentController =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadFinanceData();
    });
  }

  @override
  void dispose() {
    pixKeyTypeController.dispose();
    pixKeyController.dispose();
    bankNameController.dispose();
    bankAgencyController.dispose();
    bankAccountController.dispose();
    bankAccountDigitController.dispose();
    bankAccountTypeController.dispose();
    bankHolderNameController.dispose();
    bankHolderDocumentController.dispose();
    super.dispose();
  }

  Future<void> loadFinanceData() async {
    if (isLoading) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().getData(
        '$financeUri?period=$selectedFinancePeriod',
      );

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if (response.statusCode == 200 && body is Map && body['status'] == true) {
        final dynamic dataValue = body['data'];
        final Map<String, dynamic> data = dataValue is Map
            ? Map<String, dynamic>.from(dataValue)
            : <String, dynamic>{};

        setState(() {
          financeData = StoreSellerFinanceData.fromMap(data);
        });
        syncPayoutSettingsControllers(financeData.payoutSettings);
      } else {
        String message = 'Não foi possível carregar o financeiro da loja.';

        if (body is Map && body['message'] != null) {
          message = body['message'].toString();
        }

        showFinanceMessage(message);
      }
    } catch (_) {
      if (mounted) {
        showFinanceMessage(
            'Não foi possível carregar o financeiro da loja agora.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void syncPayoutSettingsControllers(StoreSellerPayoutSettingsData settings) {
    if (!mounted) {
      return;
    }

    selectedPayoutMethod =
        settings.payoutMethod.isNotEmpty ? settings.payoutMethod : 'pix';
    pixKeyTypeController.text = settings.pixKeyType;
    pixKeyController.text = settings.pixKey;
    bankNameController.text = settings.bankName;
    bankAgencyController.text = settings.bankAgency;
    bankAccountController.text = settings.bankAccount;
    bankAccountDigitController.text = settings.bankAccountDigit;
    bankAccountTypeController.text = settings.bankAccountType;
    bankHolderNameController.text = settings.bankHolderName;
    bankHolderDocumentController.text = settings.bankHolderDocument;
  }

  void changeFinancePeriod(String period) {
    if (selectedFinancePeriod == period) {
      return;
    }

    setState(() {
      selectedFinancePeriod = period;
    });

    loadFinanceData();
  }

  Future<void> savePayoutSettings() async {
    if (isSavingPayoutSettings) {
      return;
    }

    setState(() {
      isSavingPayoutSettings = true;
    });

    final Map<String, String> payload = <String, String>{
      'payout_method': selectedPayoutMethod,
      'pix_key_type': pixKeyTypeController.text.trim(),
      'pix_key': pixKeyController.text.trim(),
      'bank_name': bankNameController.text.trim(),
      'bank_agency': bankAgencyController.text.trim(),
      'bank_account': bankAccountController.text.trim(),
      'bank_account_digit': bankAccountDigitController.text.trim(),
      'bank_account_type': bankAccountTypeController.text.trim(),
      'bank_holder_name': bankHolderNameController.text.trim(),
      'bank_holder_document': bankHolderDocumentController.text.trim(),
    };

    try {
      final Response response =
          await Get.find<ApiClient>().postData(payoutSettingsUri, payload);

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body is Map &&
          body['status'] == true) {
        final Map<String, dynamic> data = body['data'] is Map
            ? Map<String, dynamic>.from(body['data'])
            : <String, dynamic>{};
        final StoreSellerPayoutSettingsData settings =
            StoreSellerPayoutSettingsData.fromMap(
          StoreSellerFinanceParser.readMap(data['payout_settings']),
        );

        setState(() {
          financeData = financeData.copyWith(payoutSettings: settings);
        });
        syncPayoutSettingsControllers(settings);
        showFinanceMessage('Dados de repasse atualizados com sucesso.');
        return;
      }

      String message = 'Não foi possível salvar os dados de repasse.';
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
      showFinanceMessage(message);
    } catch (_) {
      if (mounted) {
        showFinanceMessage(
            'Não foi possível salvar os dados de repasse agora.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isSavingPayoutSettings = false;
        });
      }
    }
  }

  void showFinanceMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> openReceipt(String url) async {
    if (url.trim().isEmpty) {
      return;
    }

    final bool opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      showFinanceMessage('Não foi possível abrir o comprovante.');
    }
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
          'Financeiro',
          style: textBold.copyWith(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadFinanceData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: loadFinanceData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            Dimensions.paddingSizeDefault,
            18,
            Dimensions.paddingSizeDefault,
            30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StoreSellerPeriodSelector(
                primaryColor: primaryColor,
                selectedPeriod: selectedFinancePeriod,
                onChanged: changeFinancePeriod,
              ),
              const SizedBox(height: 18),
              StoreSellerFinanceHeader(
                primaryColor: primaryColor,
                summary: financeData.summary,
                isLoading: isLoading,
              ),
              const SizedBox(height: 22),
              StoreSellerFinanceOverview(
                primaryColor: primaryColor,
                summary: financeData.summary,
              ),
              const SizedBox(height: 24),
              StoreSellerFinanceOrderSection(
                title: 'Aguardando repasse',
                description:
                    'Pedidos autorizados ou liberados para pagamento manual pela Lokally.',
                emptyText: 'Nenhum valor aguardando repasse.',
                orders: financeData.pendingOrders,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 24),
              StoreSellerFinanceOrderSection(
                title: 'Bloqueados ou em análise',
                description:
                    'Valores bloqueados, em disputa ou aguardando uma decisão operacional.',
                emptyText: 'Nenhum valor bloqueado no momento.',
                orders: financeData.blockedOrders,
                primaryColor: primaryColor,
                highlightBlocked: true,
              ),
              const SizedBox(height: 24),
              StoreSellerFinancePayoutSection(
                payouts: financeData.recentPayouts,
                primaryColor: primaryColor,
                onOpenReceipt: openReceipt,
              ),
              const SizedBox(height: 24),
              StoreSellerFinanceOrderSection(
                title: 'Pedidos pagos',
                description:
                    'Histórico de pedidos que já tiveram repasse registrado.',
                emptyText: 'Nenhum repasse pago ainda.',
                orders: financeData.paidOrders,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 24),
              StoreSellerFinanceMovementSection(
                movements: financeData.latestMovements,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 24),
              StoreSellerPayoutSettingsSection(
                primaryColor: primaryColor,
                selectedMethod: selectedPayoutMethod,
                isSaving: isSavingPayoutSettings,
                onMethodChanged: (value) {
                  setState(() {
                    selectedPayoutMethod = value;
                  });
                },
                pixKeyTypeController: pixKeyTypeController,
                pixKeyController: pixKeyController,
                bankNameController: bankNameController,
                bankAgencyController: bankAgencyController,
                bankAccountController: bankAccountController,
                bankAccountDigitController: bankAccountDigitController,
                bankAccountTypeController: bankAccountTypeController,
                bankHolderNameController: bankHolderNameController,
                bankHolderDocumentController: bankHolderDocumentController,
                onSave: savePayoutSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreSellerFinanceHeader extends StatelessWidget {
  final Color primaryColor;
  final StoreSellerFinanceSummary summary;
  final bool isLoading;

  const StoreSellerFinanceHeader({
    super.key,
    required this.primaryColor,
    required this.summary,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Saldo a receber',
                style: textMedium.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: primaryColor,
                  strokeWidth: 2,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          summary.pendingTotalFormatted,
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 34,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Valores aguardando transferência manual pela Lokally.',
          style: textRegular.copyWith(
            color: Colors.grey.shade600,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class StoreSellerFinanceOverview extends StatelessWidget {
  final Color primaryColor;
  final StoreSellerFinanceSummary summary;

  const StoreSellerFinanceOverview({
    super.key,
    required this.primaryColor,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final List<StoreSellerFinanceMetricData> metrics = [
      StoreSellerFinanceMetricData(
        title: 'Total vendido',
        value: summary.totalCollectedFormatted,
      ),
      StoreSellerFinanceMetricData(
        title: 'Taxas Lokally',
        value: summary.platformFeeTotalFormatted,
      ),
      StoreSellerFinanceMetricData(
        title: 'Pago',
        value: summary.paidTotalFormatted,
      ),
      StoreSellerFinanceMetricData(
        title: 'Bloqueado',
        value: summary.blockedTotalFormatted,
      ),
      StoreSellerFinanceMetricData(
        title: 'Em disputa',
        value: summary.disputedTotalFormatted,
      ),
      StoreSellerFinanceMetricData(
        title: 'Pedidos',
        value: '${summary.ordersCount}',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumo',
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 10),
        ...metrics.map((metric) => StoreSellerFinanceMetricRow(
              metric: metric,
              primaryColor: primaryColor,
            )),
      ],
    );
  }
}

class StoreSellerFinanceMetricRow extends StatelessWidget {
  final StoreSellerFinanceMetricData metric;
  final Color primaryColor;

  const StoreSellerFinanceMetricRow({
    super.key,
    required this.metric,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              metric.title,
              style: textRegular.copyWith(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            metric.value,
            style: textBold.copyWith(
              color: metric.title == 'Bloqueado' || metric.title == 'Em disputa'
                  ? Colors.orange.shade800
                  : Colors.black87,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerFinanceOrderSection extends StatelessWidget {
  final String title;
  final String description;
  final String emptyText;
  final List<StoreSellerFinanceOrderData> orders;
  final Color primaryColor;
  final bool highlightBlocked;

  const StoreSellerFinanceOrderSection({
    super.key,
    required this.title,
    required this.description,
    required this.emptyText,
    required this.orders,
    required this.primaryColor,
    this.highlightBlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: textRegular.copyWith(
            color: Colors.grey.shade600,
            fontSize: 12.2,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        if (orders.isEmpty)
          StoreSellerFinanceEmptyLine(text: emptyText)
        else
          ...orders.map(
            (order) => StoreSellerFinanceOrderTile(
              order: order,
              primaryColor: primaryColor,
              highlightBlocked: highlightBlocked,
            ),
          ),
      ],
    );
  }
}

class StoreSellerFinanceOrderTile extends StatelessWidget {
  final StoreSellerFinanceOrderData order;
  final Color primaryColor;
  final bool highlightBlocked;

  const StoreSellerFinanceOrderTile({
    super.key,
    required this.order,
    required this.primaryColor,
    required this.highlightBlocked,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor =
        highlightBlocked ? Colors.orange.shade800 : primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 13.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.orderStatusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    order.pendingAmount > 0
                        ? order.pendingAmountFormatted
                        : order.payoutAmountFormatted,
                    style: textBold.copyWith(
                      color: Colors.black87,
                      fontSize: 13.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.payoutStatusLabel,
                    style: textMedium.copyWith(
                      color: statusColor,
                      fontSize: 11.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Vendido: ${order.totalCollectedFormatted}',
                  style: textRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 11.3,
                  ),
                ),
              ),
              Text(
                'Taxa: ${order.platformFeeAmountFormatted}',
                style: textRegular.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 11.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StoreSellerFinancePayoutSection extends StatelessWidget {
  final List<StoreSellerFinancePayoutData> payouts;
  final Color primaryColor;
  final ValueChanged<String> onOpenReceipt;

  const StoreSellerFinancePayoutSection({
    super.key,
    required this.payouts,
    required this.primaryColor,
    required this.onOpenReceipt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repasses registrados',
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Histórico de pagamentos registrados pela Lokally.',
          style: textRegular.copyWith(
            color: Colors.grey.shade600,
            fontSize: 12.2,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        if (payouts.isEmpty)
          const StoreSellerFinanceEmptyLine(
              text: 'Nenhum repasse registrado ainda.')
        else
          ...payouts.map(
            (payout) => StoreSellerFinancePayoutTile(
              payout: payout,
              primaryColor: primaryColor,
              onOpenReceipt: onOpenReceipt,
            ),
          ),
      ],
    );
  }
}

class StoreSellerFinancePayoutTile extends StatelessWidget {
  final StoreSellerFinancePayoutData payout;
  final Color primaryColor;
  final ValueChanged<String> onOpenReceipt;

  const StoreSellerFinancePayoutTile({
    super.key,
    required this.payout,
    required this.primaryColor,
    required this.onOpenReceipt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payout.batchNumber.isNotEmpty
                      ? payout.batchNumber
                      : 'Repasse',
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 13.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${payout.statusLabel} • ${payout.ordersCount} pedido(s)',
                  style: textRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 11.8,
                  ),
                ),
                if (payout.receiptUrl.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  GestureDetector(
                    onTap: () => onOpenReceipt(payout.receiptUrl),
                    child: Text(
                      'Abrir comprovante',
                      style: textBold.copyWith(
                        color: primaryColor,
                        fontSize: 11.8,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            payout.payoutAmountFormatted,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 13.6,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerFinanceMovementSection extends StatelessWidget {
  final List<StoreSellerFinanceMovementData> movements;
  final Color primaryColor;

  const StoreSellerFinanceMovementSection({
    super.key,
    required this.movements,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Movimentações',
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Últimos registros financeiros do Marketplace.',
          style: textRegular.copyWith(
            color: Colors.grey.shade600,
            fontSize: 12.2,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        if (movements.isEmpty)
          const StoreSellerFinanceEmptyLine(
              text: 'Nenhuma movimentação registrada ainda.')
        else
          ...movements.map(
            (movement) => StoreSellerFinanceMovementTile(
              movement: movement,
              primaryColor: primaryColor,
            ),
          ),
      ],
    );
  }
}

class StoreSellerFinanceMovementTile extends StatelessWidget {
  final StoreSellerFinanceMovementData movement;
  final Color primaryColor;

  const StoreSellerFinanceMovementTile({
    super.key,
    required this.movement,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 13.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  movement.statusLabel,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            movement.amountFormatted,
            style: textBold.copyWith(
              color:
                  movement.direction == 'out' ? Colors.redAccent : primaryColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerFinanceEmptyLine extends StatelessWidget {
  final String text;

  const StoreSellerFinanceEmptyLine({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Text(
        text,
        style: textRegular.copyWith(
          color: Colors.grey.shade600,
          fontSize: 12.4,
        ),
      ),
    );
  }
}

class StoreSellerPayoutSettingsSection extends StatelessWidget {
  final Color primaryColor;
  final String selectedMethod;
  final bool isSaving;
  final ValueChanged<String> onMethodChanged;
  final TextEditingController pixKeyTypeController;
  final TextEditingController pixKeyController;
  final TextEditingController bankNameController;
  final TextEditingController bankAgencyController;
  final TextEditingController bankAccountController;
  final TextEditingController bankAccountDigitController;
  final TextEditingController bankAccountTypeController;
  final TextEditingController bankHolderNameController;
  final TextEditingController bankHolderDocumentController;
  final VoidCallback onSave;

  const StoreSellerPayoutSettingsSection({
    super.key,
    required this.primaryColor,
    required this.selectedMethod,
    required this.isSaving,
    required this.onMethodChanged,
    required this.pixKeyTypeController,
    required this.pixKeyController,
    required this.bankNameController,
    required this.bankAgencyController,
    required this.bankAccountController,
    required this.bankAccountDigitController,
    required this.bankAccountTypeController,
    required this.bankHolderNameController,
    required this.bankHolderDocumentController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPix = selectedMethod == 'pix';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dados de repasse',
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Cadastre como a Lokally deve realizar os repasses da sua loja.',
          style: textRegular.copyWith(
            color: Colors.grey.shade600,
            fontSize: 12.2,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: StoreSellerPayoutMethodButton(
                label: 'PIX',
                selected: isPix,
                primaryColor: primaryColor,
                onTap: () => onMethodChanged('pix'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StoreSellerPayoutMethodButton(
                label: 'Conta corrente',
                selected: selectedMethod == 'bank',
                primaryColor: primaryColor,
                onTap: () => onMethodChanged('bank'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (isPix) ...[
          StoreSellerFinanceInput(
            label: 'Tipo de chave PIX',
            controller: pixKeyTypeController,
            hint: 'CPF, CNPJ, telefone, e-mail ou aleatória',
          ),
          const SizedBox(height: 12),
          StoreSellerFinanceInput(
            label: 'Chave PIX',
            controller: pixKeyController,
            hint: 'Digite a chave PIX',
          ),
        ] else ...[
          StoreSellerFinanceInput(
            label: 'Banco',
            controller: bankNameController,
            hint: 'Nome do banco',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StoreSellerFinanceInput(
                  label: 'Agência',
                  controller: bankAgencyController,
                  hint: '0000',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StoreSellerFinanceInput(
                  label: 'Conta',
                  controller: bankAccountController,
                  hint: '000000',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StoreSellerFinanceInput(
                  label: 'Dígito',
                  controller: bankAccountDigitController,
                  hint: '0',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StoreSellerFinanceInput(
                  label: 'Tipo de conta',
                  controller: bankAccountTypeController,
                  hint: 'Corrente ou poupança',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StoreSellerFinanceInput(
            label: 'Titular da conta',
            controller: bankHolderNameController,
            hint: 'Nome completo ou razão social',
          ),
          const SizedBox(height: 12),
          StoreSellerFinanceInput(
            label: 'CPF ou CNPJ do titular',
            controller: bankHolderDocumentController,
            hint: 'Documento do titular',
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isSaving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Salvar dados de repasse',
                    style: textBold.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class StoreSellerPayoutMethodButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreSellerPayoutMethodButton({
    super.key,
    required this.label,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: textBold.copyWith(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class StoreSellerFinanceInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const StoreSellerFinanceInput({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textMedium.copyWith(
            color: Colors.grey.shade800,
            fontSize: 12.2,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
          ),
        ),
      ],
    );
  }
}

class StoreSellerFinanceData {
  final StoreSellerFinanceSummary summary;
  final StoreSellerPayoutSettingsData payoutSettings;
  final List<StoreSellerFinanceOrderData> pendingOrders;
  final List<StoreSellerFinanceOrderData> paidOrders;
  final List<StoreSellerFinanceOrderData> blockedOrders;
  final List<StoreSellerFinancePayoutData> recentPayouts;
  final List<StoreSellerFinanceMovementData> latestMovements;

  StoreSellerFinanceData({
    required this.summary,
    required this.payoutSettings,
    required this.pendingOrders,
    required this.paidOrders,
    required this.blockedOrders,
    required this.recentPayouts,
    required this.latestMovements,
  });

  factory StoreSellerFinanceData.empty() {
    return StoreSellerFinanceData(
      summary: StoreSellerFinanceSummary.empty(),
      payoutSettings: StoreSellerPayoutSettingsData.empty(),
      pendingOrders: <StoreSellerFinanceOrderData>[],
      paidOrders: <StoreSellerFinanceOrderData>[],
      blockedOrders: <StoreSellerFinanceOrderData>[],
      recentPayouts: <StoreSellerFinancePayoutData>[],
      latestMovements: <StoreSellerFinanceMovementData>[],
    );
  }

  StoreSellerFinanceData copyWith({
    StoreSellerFinanceSummary? summary,
    StoreSellerPayoutSettingsData? payoutSettings,
    List<StoreSellerFinanceOrderData>? pendingOrders,
    List<StoreSellerFinanceOrderData>? paidOrders,
    List<StoreSellerFinanceOrderData>? blockedOrders,
    List<StoreSellerFinancePayoutData>? recentPayouts,
    List<StoreSellerFinanceMovementData>? latestMovements,
  }) {
    return StoreSellerFinanceData(
      summary: summary ?? this.summary,
      payoutSettings: payoutSettings ?? this.payoutSettings,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      paidOrders: paidOrders ?? this.paidOrders,
      blockedOrders: blockedOrders ?? this.blockedOrders,
      recentPayouts: recentPayouts ?? this.recentPayouts,
      latestMovements: latestMovements ?? this.latestMovements,
    );
  }

  factory StoreSellerFinanceData.fromMap(Map<String, dynamic> map) {
    return StoreSellerFinanceData(
      summary: StoreSellerFinanceSummary.fromMap(
        StoreSellerFinanceParser.readMap(map['summary']),
      ),
      payoutSettings: StoreSellerPayoutSettingsData.fromMap(
        StoreSellerFinanceParser.readMap(map['payout_settings']),
      ),
      pendingOrders: StoreSellerFinanceParser.readList(map['pending_orders'])
          .map(StoreSellerFinanceOrderData.fromMap)
          .toList(),
      paidOrders: StoreSellerFinanceParser.readList(map['paid_orders'])
          .map(StoreSellerFinanceOrderData.fromMap)
          .toList(),
      blockedOrders: StoreSellerFinanceParser.readList(map['blocked_orders'])
          .map(StoreSellerFinanceOrderData.fromMap)
          .toList(),
      recentPayouts: StoreSellerFinanceParser.readList(map['recent_payouts'])
          .map(StoreSellerFinancePayoutData.fromMap)
          .toList(),
      latestMovements:
          StoreSellerFinanceParser.readList(map['latest_movements'])
              .map(StoreSellerFinanceMovementData.fromMap)
              .toList(),
    );
  }
}

class StoreSellerPayoutSettingsData {
  final String payoutMethod;
  final String payoutMethodLabel;
  final String pixKeyType;
  final String pixKey;
  final String bankName;
  final String bankAgency;
  final String bankAccount;
  final String bankAccountDigit;
  final String bankAccountType;
  final String bankHolderName;
  final String bankHolderDocument;
  final bool hasPayoutSettings;

  StoreSellerPayoutSettingsData({
    required this.payoutMethod,
    required this.payoutMethodLabel,
    required this.pixKeyType,
    required this.pixKey,
    required this.bankName,
    required this.bankAgency,
    required this.bankAccount,
    required this.bankAccountDigit,
    required this.bankAccountType,
    required this.bankHolderName,
    required this.bankHolderDocument,
    required this.hasPayoutSettings,
  });

  factory StoreSellerPayoutSettingsData.empty() {
    return StoreSellerPayoutSettingsData(
      payoutMethod: 'pix',
      payoutMethodLabel: 'PIX',
      pixKeyType: '',
      pixKey: '',
      bankName: '',
      bankAgency: '',
      bankAccount: '',
      bankAccountDigit: '',
      bankAccountType: '',
      bankHolderName: '',
      bankHolderDocument: '',
      hasPayoutSettings: false,
    );
  }

  factory StoreSellerPayoutSettingsData.fromMap(Map<String, dynamic> map) {
    final String method =
        StoreSellerFinanceParser.readString(map['payout_method'], 'pix');

    return StoreSellerPayoutSettingsData(
      payoutMethod: method.isNotEmpty ? method : 'pix',
      payoutMethodLabel: StoreSellerFinanceParser.readString(
          map['payout_method_label'], 'PIX'),
      pixKeyType: StoreSellerFinanceParser.readString(map['pix_key_type'], ''),
      pixKey: StoreSellerFinanceParser.readString(map['pix_key'], ''),
      bankName: StoreSellerFinanceParser.readString(map['bank_name'], ''),
      bankAgency: StoreSellerFinanceParser.readString(map['bank_agency'], ''),
      bankAccount: StoreSellerFinanceParser.readString(map['bank_account'], ''),
      bankAccountDigit:
          StoreSellerFinanceParser.readString(map['bank_account_digit'], ''),
      bankAccountType:
          StoreSellerFinanceParser.readString(map['bank_account_type'], ''),
      bankHolderName:
          StoreSellerFinanceParser.readString(map['bank_holder_name'], ''),
      bankHolderDocument:
          StoreSellerFinanceParser.readString(map['bank_holder_document'], ''),
      hasPayoutSettings:
          StoreSellerFinanceParser.readBool(map['has_payout_settings']),
    );
  }
}

class StoreSellerFinanceSummary {
  final int ordersCount;
  final String totalCollectedFormatted;
  final String sellerReceivableTotalFormatted;
  final String platformFeeTotalFormatted;
  final String payoutTotalFormatted;
  final String paidTotalFormatted;
  final String pendingTotalFormatted;
  final String blockedTotalFormatted;
  final String disputedTotalFormatted;

  StoreSellerFinanceSummary({
    required this.ordersCount,
    required this.totalCollectedFormatted,
    required this.sellerReceivableTotalFormatted,
    required this.platformFeeTotalFormatted,
    required this.payoutTotalFormatted,
    required this.paidTotalFormatted,
    required this.pendingTotalFormatted,
    required this.blockedTotalFormatted,
    required this.disputedTotalFormatted,
  });

  factory StoreSellerFinanceSummary.empty() {
    return StoreSellerFinanceSummary(
      ordersCount: 0,
      totalCollectedFormatted: 'R\$0,00',
      sellerReceivableTotalFormatted: 'R\$0,00',
      platformFeeTotalFormatted: 'R\$0,00',
      payoutTotalFormatted: 'R\$0,00',
      paidTotalFormatted: 'R\$0,00',
      pendingTotalFormatted: 'R\$0,00',
      blockedTotalFormatted: 'R\$0,00',
      disputedTotalFormatted: 'R\$0,00',
    );
  }

  factory StoreSellerFinanceSummary.fromMap(Map<String, dynamic> map) {
    return StoreSellerFinanceSummary(
      ordersCount: StoreSellerFinanceParser.readInt(map['orders_count']),
      totalCollectedFormatted: StoreSellerFinanceParser.readString(
          map['total_collected_formatted'], 'R\$0,00'),
      sellerReceivableTotalFormatted: StoreSellerFinanceParser.readString(
          map['seller_receivable_total_formatted'], 'R\$0,00'),
      platformFeeTotalFormatted: StoreSellerFinanceParser.readString(
          map['platform_fee_total_formatted'], 'R\$0,00'),
      payoutTotalFormatted: StoreSellerFinanceParser.readString(
          map['payout_total_formatted'], 'R\$0,00'),
      paidTotalFormatted: StoreSellerFinanceParser.readString(
          map['paid_total_formatted'], 'R\$0,00'),
      pendingTotalFormatted: StoreSellerFinanceParser.readString(
          map['pending_total_formatted'], 'R\$0,00'),
      blockedTotalFormatted: StoreSellerFinanceParser.readString(
          map['blocked_total_formatted'], 'R\$0,00'),
      disputedTotalFormatted: StoreSellerFinanceParser.readString(
          map['disputed_total_formatted'], 'R\$0,00'),
    );
  }
}

class StoreSellerFinanceMetricData {
  final String title;
  final String value;

  StoreSellerFinanceMetricData({
    required this.title,
    required this.value,
  });
}

class StoreSellerFinanceOrderData {
  final String id;
  final String storeOrderId;
  final String orderNumber;
  final String paymentStatusLabel;
  final String orderStatusLabel;
  final double totalCollected;
  final String totalCollectedFormatted;
  final double sellerReceivableAmount;
  final String sellerReceivableAmountFormatted;
  final double platformFeeAmount;
  final String platformFeeAmountFormatted;
  final double payoutAmount;
  final String payoutAmountFormatted;
  final double paidAmount;
  final String paidAmountFormatted;
  final double pendingAmount;
  final String pendingAmountFormatted;
  final String payoutStatus;
  final String payoutStatusLabel;
  final String disputeStatusLabel;
  final String createdAt;

  StoreSellerFinanceOrderData({
    required this.id,
    required this.storeOrderId,
    required this.orderNumber,
    required this.paymentStatusLabel,
    required this.orderStatusLabel,
    required this.totalCollected,
    required this.totalCollectedFormatted,
    required this.sellerReceivableAmount,
    required this.sellerReceivableAmountFormatted,
    required this.platformFeeAmount,
    required this.platformFeeAmountFormatted,
    required this.payoutAmount,
    required this.payoutAmountFormatted,
    required this.paidAmount,
    required this.paidAmountFormatted,
    required this.pendingAmount,
    required this.pendingAmountFormatted,
    required this.payoutStatus,
    required this.payoutStatusLabel,
    required this.disputeStatusLabel,
    required this.createdAt,
  });

  factory StoreSellerFinanceOrderData.fromMap(Map<String, dynamic> map) {
    return StoreSellerFinanceOrderData(
      id: StoreSellerFinanceParser.readString(map['id'], ''),
      storeOrderId:
          StoreSellerFinanceParser.readString(map['store_order_id'], ''),
      orderNumber:
          StoreSellerFinanceParser.readString(map['order_number'], 'Pedido'),
      paymentStatusLabel:
          StoreSellerFinanceParser.readString(map['payment_status_label'], ''),
      orderStatusLabel:
          StoreSellerFinanceParser.readString(map['order_status_label'], ''),
      totalCollected:
          StoreSellerFinanceParser.readDouble(map['total_collected']),
      totalCollectedFormatted: StoreSellerFinanceParser.readString(
          map['total_collected_formatted'], 'R\$0,00'),
      sellerReceivableAmount:
          StoreSellerFinanceParser.readDouble(map['seller_receivable_amount']),
      sellerReceivableAmountFormatted: StoreSellerFinanceParser.readString(
          map['seller_receivable_amount_formatted'], 'R\$0,00'),
      platformFeeAmount:
          StoreSellerFinanceParser.readDouble(map['platform_fee_amount']),
      platformFeeAmountFormatted: StoreSellerFinanceParser.readString(
          map['platform_fee_amount_formatted'], 'R\$0,00'),
      payoutAmount: StoreSellerFinanceParser.readDouble(map['payout_amount']),
      payoutAmountFormatted: StoreSellerFinanceParser.readString(
          map['payout_amount_formatted'], 'R\$0,00'),
      paidAmount: StoreSellerFinanceParser.readDouble(map['paid_amount']),
      paidAmountFormatted: StoreSellerFinanceParser.readString(
          map['paid_amount_formatted'], 'R\$0,00'),
      pendingAmount: StoreSellerFinanceParser.readDouble(map['pending_amount']),
      pendingAmountFormatted: StoreSellerFinanceParser.readString(
          map['pending_amount_formatted'], 'R\$0,00'),
      payoutStatus:
          StoreSellerFinanceParser.readString(map['payout_status'], ''),
      payoutStatusLabel:
          StoreSellerFinanceParser.readString(map['payout_status_label'], ''),
      disputeStatusLabel:
          StoreSellerFinanceParser.readString(map['dispute_status_label'], ''),
      createdAt: StoreSellerFinanceParser.readString(map['created_at'], ''),
    );
  }
}

class StoreSellerFinancePayoutData {
  final String id;
  final String batchNumber;
  final String statusLabel;
  final int ordersCount;
  final double payoutAmount;
  final String payoutAmountFormatted;
  final String paymentMethod;
  final String paymentReference;
  final String receiptUrl;
  final String paidAt;
  final String createdAt;

  StoreSellerFinancePayoutData({
    required this.id,
    required this.batchNumber,
    required this.statusLabel,
    required this.ordersCount,
    required this.payoutAmount,
    required this.payoutAmountFormatted,
    required this.paymentMethod,
    required this.paymentReference,
    required this.receiptUrl,
    required this.paidAt,
    required this.createdAt,
  });

  factory StoreSellerFinancePayoutData.fromMap(Map<String, dynamic> map) {
    return StoreSellerFinancePayoutData(
      id: StoreSellerFinanceParser.readString(map['id'], ''),
      batchNumber: StoreSellerFinanceParser.readString(map['batch_number'], ''),
      statusLabel: StoreSellerFinanceParser.readString(map['status_label'], ''),
      ordersCount: StoreSellerFinanceParser.readInt(map['orders_count']),
      payoutAmount: StoreSellerFinanceParser.readDouble(map['payout_amount']),
      payoutAmountFormatted: StoreSellerFinanceParser.readString(
          map['payout_amount_formatted'], 'R\$0,00'),
      paymentMethod:
          StoreSellerFinanceParser.readString(map['payment_method'], ''),
      paymentReference:
          StoreSellerFinanceParser.readString(map['payment_reference'], ''),
      receiptUrl: StoreSellerFinanceParser.readString(map['receipt_url'], ''),
      paidAt: StoreSellerFinanceParser.readString(map['paid_at'], ''),
      createdAt: StoreSellerFinanceParser.readString(map['created_at'], ''),
    );
  }
}

class StoreSellerFinanceMovementData {
  final String id;
  final String title;
  final String direction;
  final double amount;
  final String amountFormatted;
  final String statusLabel;
  final String notes;
  final String occurredAt;

  StoreSellerFinanceMovementData({
    required this.id,
    required this.title,
    required this.direction,
    required this.amount,
    required this.amountFormatted,
    required this.statusLabel,
    required this.notes,
    required this.occurredAt,
  });

  factory StoreSellerFinanceMovementData.fromMap(Map<String, dynamic> map) {
    return StoreSellerFinanceMovementData(
      id: StoreSellerFinanceParser.readString(map['id'], ''),
      title: StoreSellerFinanceParser.readString(
          map['title'], 'Movimento financeiro'),
      direction: StoreSellerFinanceParser.readString(map['direction'], ''),
      amount: StoreSellerFinanceParser.readDouble(map['amount']),
      amountFormatted: StoreSellerFinanceParser.readString(
          map['amount_formatted'], 'R\$0,00'),
      statusLabel: StoreSellerFinanceParser.readString(map['status_label'], ''),
      notes: StoreSellerFinanceParser.readString(map['notes'], ''),
      occurredAt: StoreSellerFinanceParser.readString(map['occurred_at'], ''),
    );
  }
}

class StoreSellerFinanceParser {
  static String readString(dynamic value, String fallback) {
    final String text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  static int readInt(dynamic value) {
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  static double readDouble(dynamic value) {
    return double.tryParse('${value ?? 0}') ?? 0;
  }

  static bool readBool(dynamic value) {
    final String normalized = '${value ?? ''}'.trim().toLowerCase();
    return value == true ||
        value == 1 ||
        normalized == '1' ||
        normalized == 'true';
  }

  static Map<String, dynamic> readMap(dynamic value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> readList(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

class StoreSellerOfferData {
  final String id;
  final String sellerId;
  final String title;
  final String description;
  final String scopeType;
  final String scopeLabel;
  final String categoryId;
  final String categoryName;
  final String productId;
  final String productName;
  final String discountType;
  final String discountTypeLabel;
  final double discountValue;
  final String discountLabel;
  final String startsAt;
  final String endsAt;
  final bool isActive;
  final int priority;
  final String createdAt;
  final String updatedAt;

  StoreSellerOfferData({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.scopeType,
    required this.scopeLabel,
    required this.categoryId,
    required this.categoryName,
    required this.productId,
    required this.productName,
    required this.discountType,
    required this.discountTypeLabel,
    required this.discountValue,
    required this.discountLabel,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoreSellerOfferData.fromMap(Map<String, dynamic> map) {
    return StoreSellerOfferData(
      id: '${map['id'] ?? ''}'.trim(),
      sellerId: '${map['seller_id'] ?? ''}'.trim(),
      title: '${map['title'] ?? ''}'.trim(),
      description: '${map['description'] ?? ''}'.trim(),
      scopeType: '${map['scope_type'] ?? ''}'.trim(),
      scopeLabel: '${map['scope_label'] ?? ''}'.trim(),
      categoryId: '${map['category_id'] ?? ''}'.trim(),
      categoryName: '${map['category_name'] ?? ''}'.trim(),
      productId: '${map['product_id'] ?? ''}'.trim(),
      productName: '${map['product_name'] ?? ''}'.trim(),
      discountType: '${map['discount_type'] ?? ''}'.trim(),
      discountTypeLabel: '${map['discount_type_label'] ?? ''}'.trim(),
      discountValue: double.tryParse('${map['discount_value'] ?? 0}') ?? 0,
      discountLabel: '${map['discount_label'] ?? ''}'.trim(),
      startsAt: '${map['starts_at'] ?? ''}'.trim(),
      endsAt: '${map['ends_at'] ?? ''}'.trim(),
      isActive: StoreSellerOfferParser.readBool(map['is_active']),
      priority: int.tryParse('${map['priority'] ?? 0}') ?? 0,
      createdAt: '${map['created_at'] ?? ''}'.trim(),
      updatedAt: '${map['updated_at'] ?? ''}'.trim(),
    );
  }

  String get targetLabel {
    if (scopeType == 'product') {
      return productName.isNotEmpty ? productName : 'Produto';
    }

    if (scopeType == 'category') {
      return categoryName.isNotEmpty ? categoryName : 'Categoria';
    }

    if (scopeType == 'store') {
      return 'Loja inteira';
    }

    return 'Oferta';
  }

  String get periodLabel {
    final DateTime? start = StoreSellerOfferDateHelper.parse(startsAt);
    final DateTime? end = StoreSellerOfferDateHelper.parse(endsAt);

    if (start == null && end == null) {
      return '';
    }

    if (start != null && end != null) {
      return 'De ${StoreSellerOfferDateHelper.format(start)} até ${StoreSellerOfferDateHelper.format(end)}';
    }

    if (start != null) {
      return 'Início: ${StoreSellerOfferDateHelper.format(start)}';
    }

    return 'Fim: ${StoreSellerOfferDateHelper.format(end!)}';
  }
}

class StoreSellerOfferProductOptionData {
  final String id;
  final String categoryId;
  final String name;
  final double price;
  final double? oldPrice;
  final String productType;

  StoreSellerOfferProductOptionData({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    required this.oldPrice,
    required this.productType,
  });

  factory StoreSellerOfferProductOptionData.fromMap(Map<String, dynamic> map) {
    return StoreSellerOfferProductOptionData(
      id: '${map['id'] ?? ''}'.trim(),
      categoryId: '${map['category_id'] ?? ''}'.trim(),
      name: '${map['name'] ?? ''}'.trim(),
      price: double.tryParse('${map['price'] ?? 0}') ?? 0,
      oldPrice: map['old_price'] == null
          ? null
          : double.tryParse('${map['old_price'] ?? 0}'),
      productType: '${map['product_type'] ?? ''}'.trim(),
    );
  }
}

class StoreSellerOfferCategoryOptionData {
  final String id;
  final String name;

  StoreSellerOfferCategoryOptionData({
    required this.id,
    required this.name,
  });

  factory StoreSellerOfferCategoryOptionData.fromMap(Map<String, dynamic> map) {
    return StoreSellerOfferCategoryOptionData(
      id: '${map['id'] ?? ''}'.trim(),
      name: '${map['name'] ?? ''}'.trim(),
    );
  }
}

class StoreSellerOfferParser {
  static bool readBool(dynamic value) {
    final String normalized = '${value ?? ''}'.trim().toLowerCase();
    return value == true ||
        value == 1 ||
        normalized == '1' ||
        normalized == 'true';
  }
}

class StoreSellerOfferDateHelper {
  static DateTime? parse(String? value) {
    final String raw = '${value ?? ''}'.trim();

    if (raw.isEmpty || raw == 'null') {
      return null;
    }

    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }

  static String twoDigits(int value) => value.toString().padLeft(2, '0');

  static String format(DateTime date) {
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} ${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  static String toPayload(DateTime date) {
    return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)} ${twoDigits(date.hour)}:${twoDigits(date.minute)}:00';
  }
}

class StoreSellerSalesChartData {
  final String date;
  final String label;
  final int ordersCount;
  final double salesTotal;
  final String salesTotalFormatted;

  StoreSellerSalesChartData({
    required this.date,
    required this.label,
    required this.ordersCount,
    required this.salesTotal,
    required this.salesTotalFormatted,
  });

  factory StoreSellerSalesChartData.empty(String label) {
    return StoreSellerSalesChartData(
      date: '',
      label: label,
      ordersCount: 0,
      salesTotal: 0,
      salesTotalFormatted: 'R\$0,00',
    );
  }

  factory StoreSellerSalesChartData.fromMap(Map<String, dynamic> map) {
    return StoreSellerSalesChartData(
      date: '${map['date'] ?? ''}'.trim(),
      label: '${map['label'] ?? ''}'.trim(),
      ordersCount: int.tryParse('${map['orders_count'] ?? 0}') ?? 0,
      salesTotal: double.tryParse('${map['sales_total'] ?? 0}') ?? 0,
      salesTotalFormatted:
          '${map['sales_total_formatted'] ?? 'R\$0,00'}'.trim(),
    );
  }
}

class StoreSellerDashboardKpis {
  final String formattedSalesToday;
  final int ordersToday;
  final String formattedPeriodSales;
  final int periodOrders;
  final int approvedOrders;
  final int pendingOrders;
  final int failedOrders;
  final int readyPickupOrders;
  final int lokallyShippingOrders;
  final int completedOrders;
  final String formattedGrossPaidAmount;
  final String formattedPayoutPendingTotal;
  final String formattedPayoutPaidTotal;
  final String formattedPayoutBlockedTotal;
  final int totalProducts;
  final int approvedProducts;
  final int pendingProducts;
  final int activeBoosts;
  final int openBoosts;

  StoreSellerDashboardKpis({
    required this.formattedSalesToday,
    required this.ordersToday,
    required this.formattedPeriodSales,
    required this.periodOrders,
    required this.approvedOrders,
    required this.pendingOrders,
    required this.failedOrders,
    required this.readyPickupOrders,
    required this.lokallyShippingOrders,
    required this.completedOrders,
    required this.formattedGrossPaidAmount,
    required this.formattedPayoutPendingTotal,
    required this.formattedPayoutPaidTotal,
    required this.formattedPayoutBlockedTotal,
    required this.totalProducts,
    required this.approvedProducts,
    required this.pendingProducts,
    required this.activeBoosts,
    required this.openBoosts,
  });

  factory StoreSellerDashboardKpis.empty() {
    return StoreSellerDashboardKpis(
      formattedSalesToday: 'R\$0,00',
      ordersToday: 0,
      formattedPeriodSales: 'R\$0,00',
      periodOrders: 0,
      approvedOrders: 0,
      pendingOrders: 0,
      failedOrders: 0,
      readyPickupOrders: 0,
      lokallyShippingOrders: 0,
      completedOrders: 0,
      formattedGrossPaidAmount: 'R\$0,00',
      formattedPayoutPendingTotal: 'R\$0,00',
      formattedPayoutPaidTotal: 'R\$0,00',
      formattedPayoutBlockedTotal: 'R\$0,00',
      totalProducts: 0,
      approvedProducts: 0,
      pendingProducts: 0,
      activeBoosts: 0,
      openBoosts: 0,
    );
  }

  factory StoreSellerDashboardKpis.fromMap(Map<String, dynamic> map) {
    final String salesToday =
        '${map['sales_today'] ?? map['formatted_sales_today'] ?? 'R\$0,00'}'
            .trim();
    final String periodSales = '${map['period_sales'] ?? salesToday}'.trim();
    final String grossPaid =
        '${map['gross_paid_amount'] ?? map['formatted_gross_paid_amount'] ?? 'R\$0,00'}'
            .trim();

    return StoreSellerDashboardKpis(
      formattedSalesToday: salesToday,
      ordersToday: int.tryParse('${map['orders_today'] ?? 0}') ?? 0,
      formattedPeriodSales: periodSales,
      periodOrders:
          int.tryParse('${map['period_orders'] ?? map['orders_today'] ?? 0}') ??
              0,
      approvedOrders: int.tryParse('${map['approved_orders'] ?? 0}') ?? 0,
      pendingOrders: int.tryParse('${map['pending_orders'] ?? 0}') ?? 0,
      failedOrders: int.tryParse('${map['failed_orders'] ?? 0}') ?? 0,
      readyPickupOrders:
          int.tryParse('${map['ready_pickup_orders'] ?? 0}') ?? 0,
      lokallyShippingOrders:
          int.tryParse('${map['lokally_shipping_orders'] ?? 0}') ?? 0,
      completedOrders: int.tryParse('${map['completed_orders'] ?? 0}') ?? 0,
      formattedGrossPaidAmount: grossPaid,
      formattedPayoutPendingTotal:
          '${map['payout_pending_total'] ?? grossPaid}'.trim(),
      formattedPayoutPaidTotal:
          '${map['payout_paid_total'] ?? 'R\$0,00'}'.trim(),
      formattedPayoutBlockedTotal:
          '${map['payout_blocked_total'] ?? 'R\$0,00'}'.trim(),
      totalProducts: int.tryParse('${map['total_products'] ?? 0}') ?? 0,
      approvedProducts: int.tryParse('${map['approved_products'] ?? 0}') ?? 0,
      pendingProducts: int.tryParse('${map['pending_products'] ?? 0}') ?? 0,
      activeBoosts: int.tryParse('${map['active_boosts'] ?? 0}') ?? 0,
      openBoosts: int.tryParse('${map['open_boosts'] ?? 0}') ?? 0,
    );
  }
}

class StoreSellerDeliverySettings {
  final bool pickupEnabled;
  final bool ownDeliveryEnabled;
  final bool lokallyDeliveryEnabled;
  final bool onlineEnabled;
  final bool downloadEnabled;
  final bool presentialEnabled;
  final bool homeOfficeEnabled;
  final double ownDeliveryBaseFee;
  final double lokallyDeliveryBaseFee;

  StoreSellerDeliverySettings({
    required this.pickupEnabled,
    required this.ownDeliveryEnabled,
    required this.lokallyDeliveryEnabled,
    required this.onlineEnabled,
    required this.downloadEnabled,
    required this.presentialEnabled,
    required this.homeOfficeEnabled,
    required this.ownDeliveryBaseFee,
    required this.lokallyDeliveryBaseFee,
  });

  factory StoreSellerDeliverySettings.empty() {
    return StoreSellerDeliverySettings(
      pickupEnabled: false,
      ownDeliveryEnabled: false,
      lokallyDeliveryEnabled: false,
      onlineEnabled: false,
      downloadEnabled: false,
      presentialEnabled: false,
      homeOfficeEnabled: false,
      ownDeliveryBaseFee: 0,
      lokallyDeliveryBaseFee: 0,
    );
  }

  factory StoreSellerDeliverySettings.fromMap(Map<String, dynamic> map) {
    bool readBool(String key) {
      final dynamic value = map[key];
      return value == true || value == 1 || '${value ?? ''}' == '1';
    }

    return StoreSellerDeliverySettings(
      pickupEnabled: readBool('pickup_enabled'),
      ownDeliveryEnabled: readBool('own_delivery_enabled'),
      lokallyDeliveryEnabled: readBool('lokally_delivery_enabled'),
      onlineEnabled: readBool('online_enabled'),
      downloadEnabled: readBool('download_enabled'),
      presentialEnabled: readBool('presential_enabled'),
      homeOfficeEnabled: readBool('home_office_enabled'),
      ownDeliveryBaseFee:
          double.tryParse('${map['own_delivery_base_fee'] ?? 0}') ?? 0,
      lokallyDeliveryBaseFee:
          double.tryParse('${map['lokally_delivery_base_fee'] ?? 0}') ?? 0,
    );
  }

  String get mainDeliveryStatusLabel {
    if (lokallyDeliveryEnabled) {
      return 'Lokally';
    }

    if (onlineEnabled ||
        downloadEnabled ||
        homeOfficeEnabled ||
        presentialEnabled) {
      return 'Serviços';
    }

    if (pickupEnabled) {
      return 'Retirada';
    }

    if (ownDeliveryEnabled) {
      return 'Própria';
    }

    return 'Configurar';
  }

  String get mainDeliveryDescription {
    final List<String> enabled = <String>[];

    if (pickupEnabled) {
      enabled.add('retirada');
    }
    if (lokallyDeliveryEnabled) {
      enabled.add('Lokally Envios');
    }
    if (onlineEnabled) {
      enabled.add('online');
    }
    if (downloadEnabled) {
      enabled.add('download');
    }
    if (presentialEnabled) {
      enabled.add('presencial');
    }
    if (homeOfficeEnabled) {
      enabled.add('Home Office');
    }

    if (enabled.isEmpty) {
      return 'Configure entrega e formatos de serviço';
    }

    return enabled.join(' • ');
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

  factory StoreSellerSaleData.fromDashboardOrder(Map<String, dynamic> map) {
    final String orderNumber = '${map['order_number'] ?? ''}'.trim();
    final String paymentStatus = '${map['payment_status'] ?? ''}'.trim();
    final String paymentStatusLabel =
        '${map['payment_status_label'] ?? 'Pedido recebido'}'.trim();
    final String deliveryTypeLabel =
        '${map['delivery_type_label'] ?? ''}'.trim();

    return StoreSellerSaleData(
      product:
          orderNumber.isEmpty ? 'Pedido marketplace' : 'Pedido $orderNumber',
      status: deliveryTypeLabel.isEmpty
          ? paymentStatusLabel
          : '$paymentStatusLabel • $deliveryTypeLabel',
      value: '${map['formatted_total'] ?? 'R\$0,00'}'.trim(),
      time: StoreSellerSaleData.compactDateLabel('${map['created_at'] ?? ''}'),
      isCancelled: paymentStatus == 'failed' ||
          paymentStatus == 'cancelled' ||
          paymentStatus == 'rejected',
    );
  }

  static String compactDateLabel(String rawDate) {
    if (rawDate.isEmpty) {
      return 'Agora';
    }

    final DateTime? parsed = DateTime.tryParse(rawDate);

    if (parsed == null) {
      return rawDate;
    }

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime dateOnly = DateTime(parsed.year, parsed.month, parsed.day);

    if (dateOnly == today) {
      return 'Hoje';
    }

    if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Ontem';
    }

    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}';
  }
}
