import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/screens/parcel_screen.dart';
import 'package:ride_sharing_user_app/helper/login_helper.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'lokally_digital_service_details_screen.dart';

class LokallyServicesHomeScreen extends StatefulWidget {
  const LokallyServicesHomeScreen({super.key});

  @override
  State<LokallyServicesHomeScreen> createState() =>
      _LokallyServicesHomeScreenState();
}

class _LokallyServicesHomeScreenState extends State<LokallyServicesHomeScreen> {
  static const String serviceCategoriesUri =
      '/api/customer/store/service/categories';
  static const String marketplaceServicesUri = '/api/store/services';
  static const String serviceBannersUri =
      '/api/store/banners?placement=services_home&module=services';

  final ScrollController scrollController = ScrollController();
  final ScrollController serviceCategoryCarouselController = ScrollController();
  final TextEditingController searchController = TextEditingController();
  final PageController serviceBannerPageController = PageController();
  Timer? serviceBannerTimer;
  Timer? serviceCategoryCarouselTimer;

  bool isLoadingCategories = false;
  bool hasLoadedCategories = false;
  bool isLoadingServices = false;
  bool hasLoadedServices = false;
  bool isLoadingBanners = false;
  bool hasLoadedBanners = false;
  bool showBackToTopButton = false;

  int selectedBannerIndex = 0;
  String selectedFormat = 'digital';
  String selectedCategoryId = '';
  String selectedCategoryName = '';
  String searchQuery = '';

  List<LokallyServiceCategoryData> digitalCategories =
      <LokallyServiceCategoryData>[];
  List<LokallyServiceCategoryData> presentialCategories =
      <LokallyServiceCategoryData>[];
  List<LokallyServiceAdData> services = <LokallyServiceAdData>[];
  List<LokallyServicesBannerData> serviceBanners =
      <LokallyServicesBannerData>[];

  @override
  void initState() {
    super.initState();
    scrollController.addListener(handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadInitialData();
    });
  }

  @override
  void dispose() {
    serviceBannerTimer?.cancel();
    serviceCategoryCarouselTimer?.cancel();
    scrollController.removeListener(handleScroll);
    scrollController.dispose();
    serviceCategoryCarouselController.dispose();
    serviceBannerPageController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void handleScroll() {
    if (!scrollController.hasClients) {
      return;
    }

    final bool shouldShow = scrollController.offset > 520;

    if (showBackToTopButton == shouldShow) {
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

  Future<void> loadInitialData() async {
    await Future.wait(<Future<void>>[
      loadServiceBanners(),
      loadServiceCategories(),
      loadServiceAds(),
    ]);

    if (mounted) {
      restartServiceCategoryCarousel();
    }
  }

  void stopServiceBannerCarousel() {
    serviceBannerTimer?.cancel();
    serviceBannerTimer = null;
  }

  void restartServiceBannerCarousel() {
    stopServiceBannerCarousel();

    if (serviceBanners.length <= 1) {
      return;
    }

    serviceBannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !serviceBannerPageController.hasClients) {
        return;
      }

      int nextIndex = selectedBannerIndex + 1;

      if (nextIndex >= serviceBanners.length) {
        nextIndex = 0;
      }

      serviceBannerPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOut,
      );
    });
  }

  List<LokallyServiceCategoryData> get currentFormatCategories {
    return selectedFormat == 'presential'
        ? presentialCategories
        : digitalCategories;
  }

  double get categoryCarouselStep => 158;

  double get categoryCarouselLoopWidth {
    return currentFormatCategories.length * categoryCarouselStep;
  }

  void stopServiceCategoryCarousel() {
    serviceCategoryCarouselTimer?.cancel();
    serviceCategoryCarouselTimer = null;
  }

  void resetServiceCategoryCarouselPosition() {
    if (!serviceCategoryCarouselController.hasClients) {
      return;
    }

    if (currentFormatCategories.length <= 1) {
      serviceCategoryCarouselController.jumpTo(0);
      return;
    }

    serviceCategoryCarouselController.jumpTo(0);
  }

  void scheduleServiceCategoryCarouselReset() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      resetServiceCategoryCarouselPosition();
    });
  }

  void restartServiceCategoryCarousel() {
    stopServiceCategoryCarousel();

    serviceCategoryCarouselTimer =
        Timer.periodic(const Duration(milliseconds: 22), (_) {
      if (!mounted || !serviceCategoryCarouselController.hasClients) {
        return;
      }

      final int categoryCount = currentFormatCategories.length;
      if (categoryCount <= 1) {
        return;
      }

      final double loopWidth = categoryCarouselLoopWidth;
      final double maxScroll =
          serviceCategoryCarouselController.position.maxScrollExtent;

      if (loopWidth <= 0 || maxScroll <= 0) {
        return;
      }

      double currentOffset = serviceCategoryCarouselController.offset;

      if (currentOffset >= loopWidth) {
        final double resetOffset = currentOffset - loopWidth;
        serviceCategoryCarouselController.jumpTo(resetOffset);
        currentOffset = serviceCategoryCarouselController.offset;
      }

      final double nextOffset =
          (currentOffset + 0.82).clamp(0.0, maxScroll).toDouble();
      serviceCategoryCarouselController.jumpTo(nextOffset);
    });
  }

  Future<void> loadServiceBanners() async {
    if (isLoadingBanners) {
      return;
    }

    setState(() {
      isLoadingBanners = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().getData(
        serviceBannersUri,
      );

      if (!mounted) {
        return;
      }

      final dynamic responseBody = response.body;

      if (response.statusCode != 200 ||
          responseBody is! Map ||
          responseBody['status'] != true) {
        setState(() {
          serviceBanners = <LokallyServicesBannerData>[];
          selectedBannerIndex = 0;
          isLoadingBanners = false;
          hasLoadedBanners = true;
        });
        stopServiceBannerCarousel();
        return;
      }

      final dynamic dataValue = responseBody['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};
      final dynamic bannersValue = data['banners'];
      final List<dynamic> bannerList =
          bannersValue is List ? bannersValue : <dynamic>[];

      final List<LokallyServicesBannerData> loadedBanners = bannerList
          .whereType<Map>()
          .map((item) => LokallyServicesBannerData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((banner) =>
              banner.imageUrl.isNotEmpty && banner.isServicesPlacement)
          .toList();

      setState(() {
        serviceBanners = loadedBanners;
        selectedBannerIndex = 0;
        isLoadingBanners = false;
        hasLoadedBanners = true;
      });

      if (serviceBannerPageController.hasClients && serviceBanners.isNotEmpty) {
        serviceBannerPageController.jumpToPage(0);
      }

      restartServiceBannerCarousel();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        serviceBanners = <LokallyServicesBannerData>[];
        selectedBannerIndex = 0;
        isLoadingBanners = false;
        hasLoadedBanners = true;
      });
      stopServiceBannerCarousel();
    }
  }

  Future<void> loadServiceCategories() async {
    if (isLoadingCategories) {
      return;
    }

    setState(() {
      isLoadingCategories = true;
    });

    try {
      final List<LokallyServiceCategoryData> loadedDigital =
          await fetchServiceCategoriesByFormat('digital');
      final List<LokallyServiceCategoryData> loadedPresential =
          await fetchServiceCategoriesByFormat('presential');

      if (!mounted) {
        return;
      }

      setState(() {
        digitalCategories = loadedDigital.isNotEmpty
            ? loadedDigital
            : fallbackDigitalCategories;
        presentialCategories = loadedPresential.isNotEmpty
            ? loadedPresential
            : fallbackPresentialCategories;
        isLoadingCategories = false;
        hasLoadedCategories = true;
      });

      scheduleServiceCategoryCarouselReset();
      restartServiceCategoryCarousel();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        digitalCategories = fallbackDigitalCategories;
        presentialCategories = fallbackPresentialCategories;
        isLoadingCategories = false;
        hasLoadedCategories = true;
      });

      scheduleServiceCategoryCarouselReset();
      restartServiceCategoryCarousel();
    }
  }

  Future<List<LokallyServiceCategoryData>> fetchServiceCategoriesByFormat(
    String format,
  ) async {
    try {
      final Response response = await Get.find<ApiClient>().getData(
        '$serviceCategoriesUri?format=$format',
      );

      final dynamic responseBody = response.body;

      if (response.statusCode != 200 ||
          responseBody is! Map ||
          responseBody['status'] != true) {
        return <LokallyServiceCategoryData>[];
      }

      final dynamic dataValue = responseBody['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic categoriesValue = data['categories'];
      final List<dynamic> categoryList =
          categoriesValue is List ? categoriesValue : <dynamic>[];

      return categoryList
          .whereType<Map>()
          .map((item) => LokallyServiceCategoryData.fromMap(
                Map<String, dynamic>.from(item),
                format: format,
              ))
          .where((category) => category.id.isNotEmpty)
          .toList();
    } catch (_) {
      return <LokallyServiceCategoryData>[];
    }
  }

  Future<void> loadServiceAds() async {
    if (isLoadingServices) {
      return;
    }

    setState(() {
      isLoadingServices = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().getData(
        marketplaceServicesUri,
      );

      if (!mounted) {
        return;
      }

      final dynamic responseBody = response.body;

      if (response.statusCode != 200 ||
          responseBody is! Map ||
          responseBody['status'] != true) {
        setState(() {
          services = <LokallyServiceAdData>[];
          isLoadingServices = false;
          hasLoadedServices = true;
        });
        return;
      }

      final dynamic dataValue = responseBody['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic servicesValue = data['services'] ?? data['products'];
      final List<dynamic> serviceList =
          servicesValue is List ? servicesValue : <dynamic>[];

      final List<LokallyServiceAdData> loadedServices = serviceList
          .whereType<Map>()
          .map((item) => LokallyServiceAdData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((service) =>
              service.id.isNotEmpty &&
              service.isService &&
              service.isApprovedVisible)
          .toList();

      setState(() {
        services = loadedServices;
        isLoadingServices = false;
        hasLoadedServices = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        services = <LokallyServiceAdData>[];
        isLoadingServices = false;
        hasLoadedServices = true;
      });
    }
  }

  bool get isCustomerLoggedIn {
    return Get.isRegistered<AuthController>() &&
        Get.find<AuthController>().isLoggedIn();
  }

  List<LokallyServiceCategoryData> get categoriesForSelectedFormat {
    if (selectedFormat == 'digital') {
      return digitalCategories;
    }

    if (selectedFormat == 'presential') {
      return presentialCategories;
    }

    final Map<String, LokallyServiceCategoryData> merged =
        <String, LokallyServiceCategoryData>{};

    for (final LokallyServiceCategoryData category in presentialCategories) {
      merged[category.normalizedKey] = category.copyWith(format: 'presential');
    }

    for (final LokallyServiceCategoryData category in digitalCategories) {
      final LokallyServiceCategoryData? existing =
          merged[category.normalizedKey];

      if (existing == null) {
        merged[category.normalizedKey] = category.copyWith(format: 'digital');
      } else {
        merged[category.normalizedKey] = existing.copyWith(format: 'both');
      }
    }

    final List<LokallyServiceCategoryData> categories =
        merged.values.toList(growable: false);

    categories.sort((a, b) => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ));

    return categories;
  }

  String normalizeServiceFilterText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  LokallyServiceCategoryData? get selectedServiceCategory {
    if (selectedCategoryId.isEmpty) {
      return null;
    }

    for (final LokallyServiceCategoryData category
        in categoriesForSelectedFormat) {
      if (category.id == selectedCategoryId) {
        return category;
      }
    }

    return null;
  }

  List<String> serviceCategoryKeywords(String normalizedCategory) {
    if (normalizedCategory.contains('design') ||
        normalizedCategory.contains('tecnologia') ||
        normalizedCategory.contains('marketing')) {
      return <String>[
        'design',
        'tecnologia',
        'logo',
        'marca',
        'branding',
        'identidade visual',
        'criacao',
        'cria',
        'site',
        'web',
        'social media',
        'midia',
        'video',
        'edicao',
        'arte',
      ];
    }

    if (normalizedCategory.contains('aula') ||
        normalizedCategory.contains('educacao')) {
      return <String>['aula', 'curso', 'professor', 'ensino', 'educacao'];
    }

    if (normalizedCategory.contains('assistencia')) {
      return <String>['assistencia', 'tecnica', 'conserto', 'manutencao'];
    }

    if (normalizedCategory.contains('consult')) {
      return <String>['consultoria', 'consultor', 'mentoria', 'assessoria'];
    }

    if (normalizedCategory.contains('evento')) {
      return <String>['evento', 'festa', 'cerimonial', 'fotografia'];
    }

    if (normalizedCategory.contains('moda') ||
        normalizedCategory.contains('beleza')) {
      return <String>['moda', 'beleza', 'maquiagem', 'cabelo', 'estetica'];
    }

    if (normalizedCategory.contains('reforma') ||
        normalizedCategory.contains('reparo')) {
      return <String>['reforma', 'reparo', 'obra', 'pedreiro', 'pintura'];
    }

    if (normalizedCategory.contains('saude')) {
      return <String>['saude', 'terapia', 'nutricao', 'bem estar'];
    }

    if (normalizedCategory.contains('domestico')) {
      return <String>['domestico', 'limpeza', 'diarista', 'faxina'];
    }

    if (normalizedCategory.contains('auto') ||
        normalizedCategory.contains('automotivo')) {
      return <String>['auto', 'carro', 'moto', 'automotivo', 'veiculo'];
    }

    return normalizedCategory
        .split(' ')
        .where((word) => word.length >= 4)
        .toList();
  }

  bool serviceMatchesSelectedCategory(LokallyServiceAdData service) {
    if (selectedCategoryId.isEmpty) {
      return true;
    }

    if (service.categoryId == selectedCategoryId) {
      return true;
    }

    final LokallyServiceCategoryData? category = selectedServiceCategory;
    final String selectedText = normalizeServiceFilterText(
      '${category?.name ?? selectedCategoryName} ${category?.slug ?? ''}',
    );

    if (selectedText.isEmpty) {
      return true;
    }

    final String serviceText = normalizeServiceFilterText(
      '${service.title} ${service.category} ${service.description} '
      '${service.providerName} ${service.serviceFormat} '
      '${service.serviceDeliveryType}',
    );

    if (serviceText.contains(selectedText)) {
      return true;
    }

    final List<String> selectedWords =
        selectedText.split(' ').where((word) => word.length >= 4).toList();

    for (final String word in selectedWords) {
      if (serviceText.contains(word)) {
        return true;
      }
    }

    for (final String keyword in serviceCategoryKeywords(selectedText)) {
      if (serviceText.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  List<LokallyServiceAdData> get filteredServices {
    final String query = normalizeServiceFilterText(searchQuery);

    List<LokallyServiceAdData> result = services;

    if (selectedFormat == 'digital') {
      result = result.where((service) => service.isDigital).toList();
    } else if (selectedFormat == 'presential') {
      result = result.where((service) => service.isPresential).toList();
    }

    if (selectedCategoryId.isNotEmpty) {
      result = result.where(serviceMatchesSelectedCategory).toList();
    }

    if (query.isNotEmpty) {
      result = result.where((service) {
        final String serviceText = normalizeServiceFilterText(
          '${service.title} ${service.category} ${service.providerName} '
          '${service.description}',
        );

        return serviceText.contains(query);
      }).toList();
    }

    return result;
  }

  void handleFormatSelected(String format) {
    setState(() {
      selectedFormat = format;
      selectedCategoryId = '';
      selectedCategoryName = '';
    });

    scheduleServiceCategoryCarouselReset();
    restartServiceCategoryCarousel();
  }

  void handleCategorySelected(LokallyServiceCategoryData category) {
    setState(() {
      selectedCategoryId = category.id;
      selectedCategoryName = category.name;

      if (category.format == 'digital' || category.format == 'presential') {
        selectedFormat = category.format;
      }

      searchQuery = '';
      searchController.clear();
    });
  }

  void clearSelectedCategory() {
    setState(() {
      selectedCategoryId = '';
      selectedCategoryName = '';
    });
  }

  void handleSearchChanged(String value) {
    setState(() {
      searchQuery = value;
    });
  }

  void openShoppingScreen() {
    if (Get.isRegistered<BottomMenuController>()) {
      Get.find<BottomMenuController>().setTabIndex(2);
    }

    Get.offAll(() => const DashboardScreen());
  }

  void openTravelScreen() {
    if (!isCustomerLoggedIn) {
      showLoginRequiredDialog(
        message: 'Para solicitar viagens é necessário ser cadastrado.',
      );
      return;
    }

    if (Get.isRegistered<BottomMenuController>()) {
      Get.find<BottomMenuController>().setTabIndex(0);
    }

    Get.offAll(() => const DashboardScreen());
  }

  void openDeliveryScreen() {
    if (!isCustomerLoggedIn) {
      showLoginRequiredDialog(
        message: 'Para solicitar entregas é necessário ser cadastrado.',
      );
      return;
    }

    Get.to(() => const ParcelScreen());
  }

  void showLoginRequiredDialog({
    required String message,
  }) {
    if (Get.isDialogOpen ?? false) {
      return;
    }

    final Color primaryColor = Theme.of(context).primaryColor;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
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
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: primaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cadastro necessário',
                textAlign: TextAlign.center,
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textRegular.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: TextButton(
                        onPressed: () => Get.back(),
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: primaryColor.withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                        child: Text(
                          'Continuar navegando',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textBold.copyWith(
                            color: primaryColor,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textBold.copyWith(
                            color: Colors.white,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  void showServiceMessage(String message) {
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

  void openServiceDetails(LokallyServiceAdData service) {
    if (service.isDigital || !service.isPresential) {
      Get.to(
        () => LokallyDigitalServiceDetailsScreen(
          service: service.toDigitalDetailsMap(),
        ),
      );
      return;
    }

    showServiceMessage(
      'A página de serviço presencial será ajustada na próxima etapa.',
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFFEE75);
    final List<LokallyServiceCategoryData> categories =
        categoriesForSelectedFormat;
    final List<LokallyServiceAdData> servicesForView = filteredServices;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              LokallyServicesModeHeader(
                primaryColor: primaryColor,
                onServicesTap: scrollToTop,
                onShoppingTap: openShoppingScreen,
                onTravelTap: openTravelScreen,
                onDeliveryTap: openDeliveryScreen,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: primaryColor,
                  onRefresh: loadInitialData,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      Dimensions.paddingSizeDefault,
                      10,
                      Dimensions.paddingSizeDefault,
                      132,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -10,
                          left: -Dimensions.paddingSizeDefault,
                          right: -Dimensions.paddingSizeDefault,
                          child: LokallyServicesHeaderGradient(
                            primaryColor: primaryColor,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (serviceBanners.isNotEmpty) ...[
                              LokallyServicesBannerCarousel(
                                banners: serviceBanners,
                                selectedIndex: selectedBannerIndex,
                                pageController: serviceBannerPageController,
                                primaryColor: primaryColor,
                                onPageChanged: (index) {
                                  setState(() {
                                    selectedBannerIndex = index;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                            ] else if (isLoadingBanners &&
                                !hasLoadedBanners) ...[
                              LokallyServicesBannerLoading(
                                primaryColor: primaryColor,
                              ),
                              const SizedBox(height: 12),
                            ],
                            LokallyServicesSearchField(
                              primaryColor: primaryColor,
                              searchController: searchController,
                              onSearchChanged: handleSearchChanged,
                            ),
                            const SizedBox(height: 14),
                            LokallyServicesFormatSelector(
                              selectedFormat: selectedFormat,
                              primaryColor: primaryColor,
                              onSelected: handleFormatSelected,
                            ),
                            const SizedBox(height: 14),
                            LokallyServicesCategorySection(
                              categories: categories,
                              selectedCategoryId: selectedCategoryId,
                              isLoading:
                                  isLoadingCategories && !hasLoadedCategories,
                              primaryColor: primaryColor,
                              categoryScrollController:
                                  serviceCategoryCarouselController,
                              onCategoryTap: handleCategorySelected,
                              onClearCategory: clearSelectedCategory,
                            ),
                            const SizedBox(height: 18),
                            LokallyServicesTrustStrip(
                                primaryColor: primaryColor),
                            const SizedBox(height: 18),
                            LokallyServicesSectionHeader(
                              title: selectedCategoryName.isNotEmpty
                                  ? selectedCategoryName
                                  : 'Serviços em destaque',
                              subtitle: selectedCategoryName.isNotEmpty
                                  ? 'Encontre prestadores para esta categoria.'
                                  : 'Profissionais e serviços disponíveis na Lokally.',
                              primaryColor: primaryColor,
                            ),
                            const SizedBox(height: 12),
                            if (isLoadingServices && !hasLoadedServices) ...[
                              LokallyServicesLoadingList(
                                primaryColor: primaryColor,
                              ),
                            ] else if (servicesForView.isEmpty) ...[
                              LokallyServicesEmptyState(
                                primaryColor: primaryColor,
                                onClear: () {
                                  setState(() {
                                    selectedFormat = 'digital';
                                    selectedCategoryId = '';
                                    selectedCategoryName = '';
                                    searchQuery = '';
                                    searchController.clear();
                                  });
                                },
                              ),
                            ] else ...[
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount: servicesForView.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final LokallyServiceAdData service =
                                      servicesForView[index];

                                  return LokallyServiceCard(
                                    service: service,
                                    primaryColor: primaryColor,
                                    onTap: () => openServiceDetails(service),
                                    onContractTap: () =>
                                        openServiceDetails(service),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (showBackToTopButton)
            Positioned(
              right: 16,
              bottom: 24,
              child: GestureDetector(
                onTap: scrollToTop,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 10),
                        blurRadius: 24,
                        color: primaryColor.withValues(alpha: 0.24),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LokallyServicesModeHeader extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onServicesTap;
  final VoidCallback onShoppingTap;
  final VoidCallback onTravelTap;
  final VoidCallback onDeliveryTap;

  const LokallyServicesModeHeader({
    super.key,
    required this.primaryColor,
    required this.onServicesTap,
    required this.onShoppingTap,
    required this.onTravelTap,
    required this.onDeliveryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: primaryColor,
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.of(context).padding.top + 10,
        12,
        12,
      ),
      child: Container(
        height: 64,
        width: double.infinity,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 8),
              blurRadius: 18,
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: LokallyServicesModeItem(
                label: 'Serviços',
                asset: 'assets/image/servicos_icon.png',
                selected: true,
                primaryColor: primaryColor,
                onTap: onServicesTap,
              ),
            ),
            Expanded(
              flex: 4,
              child: LokallyServicesModeItem(
                label: 'Shop',
                asset: 'assets/image/shopping.png',
                selected: false,
                primaryColor: primaryColor,
                onTap: onShoppingTap,
              ),
            ),
            Expanded(
              flex: 4,
              child: LokallyServicesModeItem(
                label: 'Viagens',
                asset: 'assets/image/viagens.png',
                selected: false,
                primaryColor: primaryColor,
                onTap: onTravelTap,
              ),
            ),
            Expanded(
              flex: 4,
              child: LokallyServicesModeItem(
                label: 'Entregas',
                asset: 'assets/image/entregas.png',
                selected: false,
                primaryColor: primaryColor,
                onTap: onDeliveryTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LokallyServicesModeItem extends StatelessWidget {
  final String label;
  final String asset;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;

  const LokallyServicesModeItem({
    super.key,
    required this.label,
    required this.asset,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor =
        selected ? Colors.black.withValues(alpha: 0.07) : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(26),
          border: selected
              ? Border.all(color: primaryColor.withValues(alpha: 0.18))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              asset,
              width: selected ? 28 : 26,
              height: selected ? 28 : 26,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.apps_rounded,
                color: Colors.black87,
                size: selected ? 24 : 22,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: selected ? 12.2 : 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LokallyServicesHeaderGradient extends StatelessWidget {
  final Color primaryColor;

  const LokallyServicesHeaderGradient({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: 340,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor,
              primaryColor.withValues(alpha: 0.92),
              primaryColor.withValues(alpha: 0.30),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.42, 0.78, 1.0],
          ),
        ),
      ),
    );
  }
}

class LokallyServicesBannerCarousel extends StatelessWidget {
  final List<LokallyServicesBannerData> banners;
  final int selectedIndex;
  final PageController pageController;
  final Color primaryColor;
  final ValueChanged<int> onPageChanged;

  const LokallyServicesBannerCarousel({
    super.key,
    required this.banners,
    required this.selectedIndex,
    required this.pageController,
    required this.primaryColor,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 166,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: pageController,
              itemCount: banners.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                final LokallyServicesBannerData banner = banners[index];

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 12),
                        blurRadius: 24,
                        color: Colors.black.withValues(alpha: 0.10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.network(
                      banner.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: Colors.white,
                          child: Icon(
                            Icons.image_not_supported_rounded,
                            color: Colors.black54,
                            size: 34,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          if (banners.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(banners.length, (index) {
                final bool active = selectedIndex == index;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: active ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? Colors.black87 : Colors.black26,
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class LokallyServicesBannerLoading extends StatelessWidget {
  final Color primaryColor;

  const LokallyServicesBannerLoading({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 144,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(28),
      ),
    );
  }
}

class LokallyServicesSearchField extends StatelessWidget {
  final Color primaryColor;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  const LokallyServicesSearchField({
    super.key,
    required this.primaryColor,
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 10),
            blurRadius: 24,
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        textInputAction: TextInputAction.search,
        style: textRegular.copyWith(
          color: Colors.black87,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: Icon(
            Icons.search_rounded,
            color: Colors.black87,
            size: 28,
          ),
          hintText: 'Qual serviço você precisa?',
          hintStyle: textRegular.copyWith(
            color: Colors.grey.shade500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class LokallyServicesHero extends StatelessWidget {
  final Color primaryColor;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  const LokallyServicesHero({
    super.key,
    required this.primaryColor,
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 14),
            blurRadius: 30,
            color: Colors.black.withValues(alpha: 0.10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Lokally Serviços',
              style: textBold.copyWith(
                color: primaryColor,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Encontre profissionais e serviços com segurança.',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 24,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pesquise, compare, contrate pelo app e combine os detalhes pelo chat após o pedido.',
            style: textRegular.copyWith(
              color: Colors.grey.shade700,
              fontSize: 13.5,
              height: 1.34,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              style: textRegular.copyWith(
                color: Colors.black87,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                icon: Icon(
                  Icons.search_rounded,
                  color: Colors.black87,
                  size: 22,
                ),
                hintText: 'Qual serviço você precisa?',
                hintStyle: textRegular.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LokallyServicesFormatSelector extends StatelessWidget {
  final String selectedFormat;
  final Color primaryColor;
  final ValueChanged<String> onSelected;

  const LokallyServicesFormatSelector({
    super.key,
    required this.selectedFormat,
    required this.primaryColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const List<_ServiceFormatOption> options = <_ServiceFormatOption>[
      _ServiceFormatOption(
        id: 'digital',
        label: 'Digitais',
      ),
      _ServiceFormatOption(
        id: 'presential',
        label: 'Presenciais',
      ),
    ];

    return Row(
      children: options.map((option) {
        final bool selected = selectedFormat == option.id;

        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(option.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(
                right: option == options.last ? 0 : 10,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? Colors.black87 : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? Colors.black87
                      : Colors.black.withValues(alpha: 0.10),
                ),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, 8),
                    blurRadius: 18,
                    color:
                        Colors.black.withValues(alpha: selected ? 0.12 : 0.06),
                  ),
                ],
              ),
              child: Text(
                option.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textBold.copyWith(
                  color: selected ? Colors.white : Colors.black87,
                  fontSize: 13.2,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class LokallyServicesCategorySection extends StatelessWidget {
  final List<LokallyServiceCategoryData> categories;
  final String selectedCategoryId;
  final bool isLoading;
  final Color primaryColor;
  final ScrollController categoryScrollController;
  final ValueChanged<LokallyServiceCategoryData> onCategoryTap;
  final VoidCallback onClearCategory;

  const LokallyServicesCategorySection({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.isLoading,
    required this.primaryColor,
    required this.categoryScrollController,
    required this.onCategoryTap,
    required this.onClearCategory,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: 92,
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Colors.black87,
                strokeWidth: 2.4,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Carregando categorias...',
              style: textMedium.copyWith(
                color: Colors.grey.shade700,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      );
    }

    final List<LokallyServiceCategoryData> visibleCategories = categories;

    if (visibleCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isLooping = visibleCategories.length > 1;
    final List<LokallyServiceCategoryData> renderedCategories = isLooping
        ? List<LokallyServiceCategoryData>.generate(
            visibleCategories.length * 3,
            (index) => visibleCategories[index % visibleCategories.length],
          )
        : visibleCategories;

    return SizedBox(
      height: 98,
      child: ListView.separated(
        controller: categoryScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: renderedCategories.length,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final LokallyServiceCategoryData category = renderedCategories[index];
          final bool selected = selectedCategoryId == category.id;

          return GestureDetector(
            onTap: () => onCategoryTap(category),
            child: SizedBox(
              width: 78,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? primaryColor.withValues(alpha: 0.40)
                          : Colors.black.withValues(alpha: 0.045),
                      border: Border.all(
                        color: selected
                            ? primaryColor
                            : Colors.black.withValues(alpha: 0.035),
                        width: selected ? 1.4 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                offset: const Offset(0, 8),
                                blurRadius: 16,
                                color: primaryColor.withValues(alpha: 0.22),
                              ),
                            ]
                          : null,
                    ),
                    child: LokallyServiceCategoryAssetIcon(
                      category: category,
                      selected: selected,
                      primaryColor: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(
                      color: Colors.black87,
                      fontSize: 11.4,
                      height: 1.06,
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

class LokallyServiceCategoryAssetIcon extends StatelessWidget {
  final LokallyServiceCategoryData category;
  final bool selected;
  final Color primaryColor;

  const LokallyServiceCategoryAssetIcon({
    super.key,
    required this.category,
    required this.selected,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color fallbackColor = selected ? Colors.black87 : Colors.black87;

    if (category.assetIconPath.endsWith('.svg')) {
      return SvgPicture.asset(
        category.assetIconPath,
        width: 28,
        height: 28,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => Icon(
          category.icon,
          color: fallbackColor,
          size: 22,
        ),
      );
    }

    return Image.asset(
      category.assetIconPath,
      width: 29,
      height: 29,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        category.icon,
        color: fallbackColor,
        size: 22,
      ),
    );
  }
}

class LokallyServicesTrustStrip extends StatelessWidget {
  final Color primaryColor;

  const LokallyServicesTrustStrip({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final List<_TrustItem> items = <_TrustItem>[
      const _TrustItem(
        icon: Icons.verified_user_rounded,
        title: 'Prestadores avaliados',
      ),
      const _TrustItem(
        icon: Icons.chat_bubble_rounded,
        title: 'Chat seguro',
      ),
    ];

    return SizedBox(
      height: 48,
      child: Row(
        children: items.map((item) {
          return Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  color: Colors.black87,
                  size: 21,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(
                      color: Colors.black87,
                      fontSize: 12.2,
                      height: 1.08,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class LokallyServicesSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color primaryColor;
  final Widget? trailing;

  const LokallyServicesSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(999),
          ),
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
                  fontSize: 17,
                ),
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textRegular.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class LokallyServiceCard extends StatefulWidget {
  final LokallyServiceAdData service;
  final Color primaryColor;
  final VoidCallback onTap;
  final VoidCallback onContractTap;

  const LokallyServiceCard({
    super.key,
    required this.service,
    required this.primaryColor,
    required this.onTap,
    required this.onContractTap,
  });

  @override
  State<LokallyServiceCard> createState() => _LokallyServiceCardState();
}

class _LokallyServiceCardState extends State<LokallyServiceCard> {
  late final PageController imagePageController;
  Timer? imageCarouselTimer;
  int selectedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    imagePageController = PageController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      restartImageCarousel();
    });
  }

  @override
  void didUpdateWidget(covariant LokallyServiceCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.service.id != widget.service.id ||
        oldWidget.service.imageUrl != widget.service.imageUrl ||
        oldWidget.service.galleryImageUrls.length !=
            widget.service.galleryImageUrls.length) {
      imageCarouselTimer?.cancel();
      selectedImageIndex = 0;

      if (imagePageController.hasClients) {
        imagePageController.jumpToPage(0);
      }

      restartImageCarousel();
    }
  }

  @override
  void dispose() {
    imageCarouselTimer?.cancel();
    imagePageController.dispose();
    super.dispose();
  }

  List<String> get cardImageUrls {
    final List<String> images = widget.service.galleryImageUrls
        .where((image) => image.trim().isNotEmpty)
        .toList();

    if (images.isEmpty && widget.service.imageUrl.trim().isNotEmpty) {
      images.add(widget.service.imageUrl);
    }

    return images;
  }

  void restartImageCarousel() {
    imageCarouselTimer?.cancel();

    if (cardImageUrls.length <= 1) {
      return;
    }

    imageCarouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !imagePageController.hasClients) {
        return;
      }

      final int nextIndex = selectedImageIndex + 1 >= cardImageUrls.length
          ? 0
          : selectedImageIndex + 1;

      imagePageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOut,
      );
    });
  }

  Widget buildServiceImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        color: widget.primaryColor.withValues(alpha: 0.16),
        child: Icon(
          Icons.design_services_rounded,
          color: Colors.black87,
          size: 34,
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          color: widget.primaryColor.withValues(alpha: 0.16),
          child: Icon(
            Icons.design_services_rounded,
            color: Colors.black87,
            size: 34,
          ),
        );
      },
    );
  }

  Widget buildProviderAvatar() {
    final String providerImageUrl = widget.service.providerImageUrl.isNotEmpty
        ? widget.service.providerImageUrl
        : widget.service.imageUrl;

    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 8),
            blurRadius: 16,
            color: Colors.black.withValues(alpha: 0.10),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.primaryColor,
          width: 2.6,
        ),
      ),
      child: ClipOval(
        child: providerImageUrl.isEmpty
            ? Container(
                color: Colors.white,
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.black87,
                  size: 34,
                ),
              )
            : Image.network(
                providerImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: Colors.white,
                    child: Icon(
                      Icons.person_rounded,
                      color: Colors.black87,
                      size: 34,
                    ),
                  );
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String description = widget.service.description.trim();
    final String serviceTitle = widget.service.title.trim().isNotEmpty
        ? widget.service.title.trim()
        : widget.service.providerName.trim();
    final String providerName = widget.service.providerName.trim();
    final String serviceDescription =
        description.toLowerCase() == serviceTitle.toLowerCase()
            ? ''
            : description;
    final String buttonLabel =
        widget.service.isDigital ? 'Contratar agora' : 'Agendar agora';
    final List<String> images = cardImageUrls;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.black.withValues(alpha: 0.055)),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 10),
              blurRadius: 22,
              color: Colors.black.withValues(alpha: 0.045),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final double imageHeight = (constraints.maxWidth * 0.47)
                    .clamp(156.0, 188.0)
                    .toDouble();

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(26),
                        topRight: Radius.circular(26),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: imageHeight,
                        child: images.isEmpty
                            ? buildServiceImage('')
                            : PageView.builder(
                                controller: imagePageController,
                                itemCount: images.length,
                                onPageChanged: (index) {
                                  setState(() {
                                    selectedImageIndex = index;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  return buildServiceImage(images[index]);
                                },
                              ),
                      ),
                    ),
                    if (images.length > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 11,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(images.length, (index) {
                            final bool active = selectedImageIndex == index;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: active ? 15 : 6,
                              height: 6,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: active ? 0.98 : 0.56,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            );
                          }),
                        ),
                      ),
                    Positioned(
                      left: 14,
                      bottom: -24,
                      child: buildProviderAvatar(),
                    ),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 32, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(
                      color: Colors.black87,
                      fontSize: 20.5,
                      height: 1.08,
                    ),
                  ),
                  if (providerName.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Anúncio de: $providerName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textMedium.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 12.4,
                        height: 1.18,
                      ),
                    ),
                  ],
                  if (serviceDescription.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      serviceDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade700,
                        fontSize: 13.0,
                        height: 1.28,
                      ),
                    ),
                  ],
                  const SizedBox(height: 13),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 6,
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: widget.primaryColor,
                                size: 22,
                              ),
                              const SizedBox(width: 4),
                              RichText(
                                maxLines: 1,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: widget.service.ratingLabel,
                                      style: textBold.copyWith(
                                        color: Colors.black87,
                                        fontSize: 15.4,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          ' ${widget.service.reviewCountLabel}',
                                      style: textMedium.copyWith(
                                        color: Colors.grey.shade700,
                                        fontSize: 13.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 4,
                        child: FittedBox(
                          alignment: Alignment.centerRight,
                          fit: BoxFit.scaleDown,
                          child: RichText(
                            maxLines: 1,
                            textAlign: TextAlign.right,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: widget.service.priceValueLabel,
                                  style: textBold.copyWith(
                                    color: Colors.black87,
                                    fontSize: 20.5,
                                  ),
                                ),
                                TextSpan(
                                  text: widget.service.priceUnitLabel,
                                  style: textMedium.copyWith(
                                    color: Colors.grey.shade600,
                                    fontSize: 12.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: widget.onContractTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        buttonLabel,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 15.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LokallyServiceCompactCard extends StatelessWidget {
  final LokallyServiceAdData service;
  final Color primaryColor;
  final VoidCallback onTap;

  const LokallyServiceCompactCard({
    super.key,
    required this.service,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String description = service.description.trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 318,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 8),
              blurRadius: 20,
              color: Colors.black.withValues(alpha: 0.040),
            ),
          ],
        ),
        child: Row(
          children: [
            LokallyServiceImageBox(
              imageUrl: service.imageUrl,
              primaryColor: primaryColor,
              size: 64,
              width: 68,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(
                      color: Colors.black87,
                      fontSize: 13.2,
                      height: 1.08,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    service.priceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(
                      color: const Color(0xFF3A3320),
                      fontSize: 12.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.black87,
                size: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LokallyServiceProviderAvatar extends StatelessWidget {
  final String imageUrl;
  final Color primaryColor;
  final double size;

  const LokallyServiceProviderAvatar({
    super.key,
    required this.imageUrl,
    required this.primaryColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border:
            Border.all(color: primaryColor.withValues(alpha: 0.80), width: 2),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 8),
            blurRadius: 18,
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          color: primaryColor.withValues(alpha: 0.10),
          child: imageUrl.isEmpty
              ? Icon(
                  Icons.person_rounded,
                  color: Colors.black87,
                  size: size * 0.48,
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Icon(
                      Icons.person_rounded,
                      color: Colors.black87,
                      size: size * 0.48,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class LokallyServiceImageBox extends StatelessWidget {
  final String imageUrl;
  final Color primaryColor;
  final double size;
  final double? width;

  const LokallyServiceImageBox({
    super.key,
    required this.imageUrl,
    required this.primaryColor,
    required this.size,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final double imageWidth = width ?? size;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: imageWidth,
        height: size,
        color: primaryColor.withValues(alpha: 0.09),
        child: imageUrl.isEmpty
            ? Icon(
                Icons.handyman_rounded,
                color: const Color(0xFF3A3320),
                size: 34,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Icon(
                    Icons.handyman_rounded,
                    color: const Color(0xFF3A3320),
                    size: 34,
                  );
                },
              ),
      ),
    );
  }
}

class LokallyServiceBadge extends StatelessWidget {
  final String label;
  final Color color;

  const LokallyServiceBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textBold.copyWith(
          color: color,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

class LokallyServiceFeatureChip extends StatelessWidget {
  final String label;
  final Color primaryColor;

  const LokallyServiceFeatureChip({
    super.key,
    required this.label,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.68),
        ),
      ),
      child: Text(
        label,
        style: textBold.copyWith(
          color: Colors.black87,
          fontSize: 10.0,
        ),
      ),
    );
  }
}

class LokallyServicesLoadingList extends StatelessWidget {
  final Color primaryColor;

  const LokallyServicesLoadingList({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(4, (index) {
        return Container(
          height: 126,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
          ),
        );
      }),
    );
  }
}

class LokallyServicesEmptyState extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onClear;

  const LokallyServicesEmptyState({
    super.key,
    required this.primaryColor,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            color: Colors.black87,
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhum serviço encontrado',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tente limpar os filtros ou pesquisar outro serviço.',
            textAlign: TextAlign.center,
            style: textRegular.copyWith(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: onClear,
            child: Text(
              'Limpar filtros',
              style: textBold.copyWith(
                color: Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LokallyServicesBannerData {
  final String id;
  final String imageUrl;
  final String placement;
  final String module;

  const LokallyServicesBannerData({
    required this.id,
    required this.imageUrl,
    required this.placement,
    required this.module,
  });

  factory LokallyServicesBannerData.fromMap(Map<String, dynamic> map) {
    return LokallyServicesBannerData(
      id: '${map['id'] ?? ''}',
      imageUrl: LokallyServiceAdData.normalizeMediaUrl(
        map['image_url'] ??
            map['imageUrl'] ??
            map['image_full_url'] ??
            map['imageFullUrl'] ??
            map['image'] ??
            '',
      ),
      placement: '${map['placement'] ?? ''}'.trim().toLowerCase(),
      module:
          '${map['module'] ?? map['target_module'] ?? map['banner_module'] ?? ''}'
              .trim()
              .toLowerCase(),
    );
  }

  bool get isServicesPlacement {
    final String normalizedPlacement = placement.replaceAll('-', '_');
    final String normalizedModule = module.replaceAll('-', '_');

    return normalizedPlacement == 'services_home' ||
        normalizedPlacement == 'service_home' ||
        normalizedPlacement == 'services' ||
        normalizedPlacement == 'servicos' ||
        normalizedModule == 'services' ||
        normalizedModule == 'servicos';
  }
}

class LokallyServiceCategoryData {
  final String id;
  final String name;
  final String slug;
  final String format;
  final bool hasChildren;

  const LokallyServiceCategoryData({
    required this.id,
    required this.name,
    required this.slug,
    required this.format,
    required this.hasChildren,
  });

  factory LokallyServiceCategoryData.fromMap(
    Map<String, dynamic> map, {
    required String format,
  }) {
    return LokallyServiceCategoryData(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}'.trim(),
      slug: '${map['slug'] ?? ''}'.trim(),
      format: format,
      hasChildren: map['has_children'] == true,
    );
  }

  LokallyServiceCategoryData copyWith({
    String? format,
  }) {
    return LokallyServiceCategoryData(
      id: id,
      name: name,
      slug: slug,
      format: format ?? this.format,
      hasChildren: hasChildren,
    );
  }

  String get normalizedKey {
    final String base = slug.isNotEmpty ? slug : name;

    return base
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áàâãéèêíïóôõöúçñ]+'), '-');
  }

  String get assetIconPath {
    final String value = '$name $slug'
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

    if (value.contains('assistencia')) {
      return 'assets/image/assistencia-tecnica.svg';
    }

    if (value.contains('aula')) {
      return 'assets/image/aulas.svg';
    }

    if (value.contains('autom') ||
        value.contains('auto') ||
        value.contains('carro') ||
        value.contains('moto')) {
      return 'assets/image/autos.svg';
    }

    if (value.contains('consult')) {
      return 'assets/image/consultoria.svg';
    }

    if (value.contains('design') || value.contains('tecnologia')) {
      return 'assets/image/design-e-tecnologia.svg';
    }

    if (value.contains('evento')) {
      return 'assets/image/eventos.svg';
    }

    if (value.contains('moda') || value.contains('beleza')) {
      return 'assets/image/moda-e-beleza.svg';
    }

    if (value.contains('reforma') || value.contains('reparo')) {
      return 'assets/image/reformas-e-reparos.svg';
    }

    if (value.contains('saude')) {
      return 'assets/image/saude.svg';
    }

    if (value.contains('domestico')) {
      return 'assets/image/servicos-domesticos.svg';
    }

    return 'assets/image/servicos_icon.png';
  }

  IconData get icon {
    final String value = '$name $slug'.toLowerCase();

    if (value.contains('aula') || value.contains('educ')) {
      return Icons.school_rounded;
    }

    if (value.contains('saude') || value.contains('saúde')) {
      return Icons.health_and_safety_rounded;
    }

    if (value.contains('design') ||
        value.contains('tecnologia') ||
        value.contains('marketing')) {
      return Icons.design_services_rounded;
    }

    if (value.contains('consult')) {
      return Icons.business_center_rounded;
    }

    if (value.contains('assist')) {
      return Icons.build_circle_rounded;
    }

    if (value.contains('autom')) {
      return Icons.directions_car_filled_rounded;
    }

    if (value.contains('reforma') || value.contains('reparo')) {
      return Icons.handyman_rounded;
    }

    if (value.contains('evento')) {
      return Icons.celebration_rounded;
    }

    if (value.contains('beleza')) {
      return Icons.spa_rounded;
    }

    return Icons.miscellaneous_services_rounded;
  }
}

class LokallyBrazilianCurrency {
  const LokallyBrazilianCurrency._();

  static String format(num value) {
    final double safeValue = value.toDouble();
    final bool isNegative = safeValue < 0;
    final double absoluteValue = safeValue.abs();

    final String fixedValue = absoluteValue.toStringAsFixed(2);
    final List<String> parts = fixedValue.split('.');
    final String integerPart = parts.first;
    final String decimalPart = parts.length > 1 ? parts.last : '00';

    final StringBuffer formattedInteger = StringBuffer();
    int groupCounter = 0;

    for (int index = integerPart.length - 1; index >= 0; index--) {
      if (groupCounter == 3) {
        formattedInteger.write('.');
        groupCounter = 0;
      }

      formattedInteger.write(integerPart[index]);
      groupCounter++;
    }

    final String reversedInteger =
        formattedInteger.toString().split('').reversed.join();
    final String sign = isNegative ? '-' : '';

    return '${sign}R\$ $reversedInteger,$decimalPart';
  }
}

class LokallyServiceAdData {
  final String id;
  final String title;
  final String description;
  final String categoryId;
  final String category;
  final String providerName;
  final String imageUrl;
  final String providerImageUrl;
  final List<String> galleryImageUrls;
  final String productType;
  final String serviceFormat;
  final String serviceDeliveryType;
  final double price;
  final double rating;
  final int jobsCount;
  final String approvalStatus;
  final bool isActive;

  const LokallyServiceAdData({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.category,
    required this.providerName,
    required this.imageUrl,
    required this.providerImageUrl,
    this.galleryImageUrls = const <String>[],
    required this.productType,
    required this.serviceFormat,
    required this.serviceDeliveryType,
    required this.price,
    required this.rating,
    required this.jobsCount,
    required this.approvalStatus,
    required this.isActive,
  });

  factory LokallyServiceAdData.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> store = map['store'] is Map
        ? Map<String, dynamic>.from(map['store'])
        : <String, dynamic>{};
    final Map<String, dynamic> seller = map['seller'] is Map
        ? Map<String, dynamic>.from(map['seller'])
        : <String, dynamic>{};

    final dynamic imagesValue =
        map['images'] ?? map['gallery'] ?? map['product_images'];

    String serviceImage =
        '${map['image_url'] ?? map['main_image'] ?? map['thumbnail'] ?? map['image'] ?? ''}';

    if (serviceImage.isEmpty && imagesValue is List && imagesValue.isNotEmpty) {
      final dynamic firstImage = imagesValue.first;

      if (firstImage is Map) {
        serviceImage =
            '${firstImage['image_url'] ?? firstImage['url'] ?? firstImage['image'] ?? ''}';
      } else {
        serviceImage = '$firstImage';
      }
    }

    final String providerImage =
        '${map['provider_image_url'] ?? map['providerImageUrl'] ?? map['seller_logo_url'] ?? map['sellerLogoUrl'] ?? map['store_logo_url'] ?? map['storeLogoUrl'] ?? map['seller_image_url'] ?? map['sellerImageUrl'] ?? map['profile_image_url'] ?? map['profileImageUrl'] ?? store['logo_url'] ?? store['image_url'] ?? store['photo_url'] ?? ''}'
            .trim();

    final List<String> galleryImageUrls = <String>[];

    void addGalleryImage(dynamic value) {
      final String normalizedImage = normalizeMediaUrl(value);

      if (normalizedImage.isEmpty ||
          galleryImageUrls.contains(normalizedImage)) {
        return;
      }

      galleryImageUrls.add(normalizedImage);
    }

    addGalleryImage(serviceImage);

    if (imagesValue is List) {
      for (final dynamic imageItem in imagesValue) {
        if (imageItem is Map) {
          final Map<String, dynamic> imageMap =
              Map<String, dynamic>.from(imageItem);

          addGalleryImage(
            imageMap['image_url'] ??
                imageMap['url'] ??
                imageMap['image'] ??
                imageMap['path'] ??
                imageMap['file'] ??
                imageMap['thumbnail'],
          );
        } else {
          addGalleryImage(imageItem);
        }
      }
    }

    if (galleryImageUrls.isEmpty) {
      addGalleryImage(providerImage);
    }

    final String approval =
        '${map['approval_status'] ?? map['status'] ?? ''}'.trim().toLowerCase();

    return LokallyServiceAdData(
      id: '${map['id'] ?? ''}',
      title:
          '${map['name'] ?? map['title'] ?? map['product_name'] ?? 'Serviço'}'
              .trim(),
      description:
          '${map['description'] ?? map['short_description'] ?? map['details'] ?? ''}'
              .trim(),
      categoryId: '${map['category_id'] ?? ''}',
      category:
          '${map['category_name'] ?? map['category'] ?? 'Serviço'}'.trim(),
      providerName:
          '${map['store_name'] ?? map['seller_name'] ?? map['provider_name'] ?? store['store_name'] ?? store['name'] ?? seller['store_name'] ?? seller['name'] ?? seller['full_name'] ?? map['seller_full_name'] ?? 'Prestador'}'
              .trim(),
      imageUrl: normalizeMediaUrl(
          serviceImage.isNotEmpty ? serviceImage : providerImage),
      providerImageUrl: normalizeMediaUrl(providerImage),
      galleryImageUrls: galleryImageUrls,
      productType: '${map['product_type'] ?? map['type'] ?? ''}',
      serviceFormat:
          '${map['service_format'] ?? map['format'] ?? map['service_mode'] ?? ''}',
      serviceDeliveryType:
          '${map['service_delivery_type'] ?? map['delivery_type'] ?? map['serviceType'] ?? ''}',
      price: parseDouble(
        map['price'] ?? map['unit_price'] ?? map['sale_price'] ?? map['amount'],
      ),
      rating: parseDouble(map['rating'] ?? map['average_rating']),
      jobsCount: parseInt(map['jobs_count'] ??
          map['completed_jobs_count'] ??
          map['completed_services_count'] ??
          map['total_jobs'] ??
          map['orders_count'] ??
          map['reviews_count']),
      approvalStatus: approval,
      isActive: parseBool(map['is_active'] ?? map['active'] ?? true),
    );
  }

  bool get isService {
    final String normalizedType = productType.toLowerCase();
    final String normalizedFormat = serviceFormat.toLowerCase();

    return normalizedType == 'service' ||
        normalizedType == 'servico' ||
        normalizedType == 'serviço' ||
        normalizedFormat == 'digital' ||
        normalizedFormat == 'presential';
  }

  bool get isApprovedVisible {
    final bool approved = approvalStatus.isEmpty ||
        approvalStatus == 'approved' ||
        approvalStatus == 'aprovado' ||
        approvalStatus == 'active' ||
        approvalStatus == 'ativo';

    return approved && isActive;
  }

  bool get isDigital {
    final String normalized = serviceFormat.toLowerCase();

    final String normalizedDelivery = serviceDeliveryType.toLowerCase();

    return normalized.contains('digital') ||
        normalized.contains('online') ||
        normalized.contains('download') ||
        normalizedDelivery.contains('online') ||
        normalizedDelivery.contains('download');
  }

  bool get isPresential {
    final String normalized = serviceFormat.toLowerCase();

    if (normalized.contains('presential') ||
        normalized.contains('presencial')) {
      return true;
    }

    return !isDigital;
  }

  List<IconData> get highlightIcons {
    return <IconData>[
      isDigital ? Icons.language_rounded : Icons.location_on_rounded,
      Icons.verified_user_rounded,
      Icons.payments_rounded,
      Icons.chat_rounded,
    ];
  }

  List<String> get highlightLabels {
    final List<String> labels = <String>[
      category.isNotEmpty ? category : (isDigital ? 'Digital' : 'Presencial'),
      deliveryTypeLabel,
      'Pagamento no app',
      'Chat liberado',
    ];

    return labels.where((label) => label.trim().isNotEmpty).toList();
  }

  String get deliveryTypeLabel {
    final String normalizedDelivery = serviceDeliveryType.toLowerCase().trim();

    if (normalizedDelivery == 'download') {
      return 'Entrega por download';
    }

    if (normalizedDelivery == 'online') {
      return 'Atendimento online';
    }

    if (isDigital) {
      return 'Atendimento online';
    }

    return 'Atendimento local';
  }

  String get ratingLabel {
    if (rating > 0) {
      return '${rating.toStringAsFixed(1).replaceAll('.', ',')}/5';
    }

    return 'Novo';
  }

  String get reviewCountLabel {
    if (jobsCount <= 0) {
      return '(sem avaliações)';
    }

    return jobsCount == 1 ? '(1 trabalho)' : '($jobsCount trabalhos)';
  }

  String get priceValueLabel {
    if (price <= 0) {
      return 'Sob consulta';
    }

    return LokallyBrazilianCurrency.format(price);
  }

  String get priceUnitLabel {
    if (price <= 0) {
      return '';
    }

    return isPresential ? ' /visita' : ' /serviço';
  }

  String get priceLabel {
    if (price <= 0) {
      return 'Solicitar orçamento';
    }

    return 'A partir de $priceValueLabel';
  }

  Map<String, dynamic> toDigitalDetailsMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'category_id': categoryId,
      'category_name': category,
      'provider_name': providerName,
      'image_url': imageUrl,
      'provider_image_url': providerImageUrl,
      'gallery_image_urls': galleryImageUrls,
      'service_format': serviceFormat,
      'service_delivery_type': serviceDeliveryType,
      'price': price,
      'price_value_label': priceValueLabel,
      'price_unit_label': priceUnitLabel,
      'price_label': priceLabel,
      'rating_label': ratingLabel,
      'review_count_label': reviewCountLabel,
      'delivery_type_label': deliveryTypeLabel,
      'is_digital': isDigital,
      'is_presential': isPresential,
    };
  }

  static String normalizeMediaUrl(dynamic value) {
    final String rawValue = '${value ?? ''}'.trim();

    if (rawValue.isEmpty || rawValue == 'null') {
      return '';
    }

    if (rawValue.startsWith('http://') || rawValue.startsWith('https://')) {
      return rawValue;
    }

    String baseUrl = AppConstants.baseUrl.trim();
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    if (rawValue.startsWith('/storage/')) {
      return '$baseUrl$rawValue';
    }

    if (rawValue.startsWith('storage/')) {
      return '$baseUrl/$rawValue';
    }

    if (rawValue.startsWith('/')) {
      return '$baseUrl$rawValue';
    }

    return '$baseUrl/storage/$rawValue';
  }

  static bool parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final String raw = '${value ?? ''}'.trim().toLowerCase();

    return raw == '1' || raw == 'true' || raw == 'yes' || raw == 'sim';
  }

  static int parseInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    final String raw = value.toString().replaceAll(RegExp(r'[^0-9]'), '');

    return int.tryParse(raw) ?? 0;
  }

  static double parseDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    String raw = value.toString().trim();
    raw = raw.replaceAll(RegExp(r'[^0-9,.-]'), '');

    if (raw.isEmpty) {
      return 0;
    }

    if (raw.contains(',') && raw.contains('.')) {
      if (raw.lastIndexOf(',') > raw.lastIndexOf('.')) {
        raw = raw.replaceAll('.', '').replaceAll(',', '.');
      } else {
        raw = raw.replaceAll(',', '');
      }
    } else if (raw.contains(',')) {
      raw = raw.replaceAll('.', '').replaceAll(',', '.');
    }

    return double.tryParse(raw) ?? 0;
  }
}

class _ServiceFormatOption {
  final String id;
  final String label;

  const _ServiceFormatOption({
    required this.id,
    required this.label,
  });
}

class _TrustItem {
  final IconData icon;
  final String title;

  const _TrustItem({
    required this.icon,
    required this.title,
  });
}

List<LokallyServiceCategoryData> get fallbackDigitalCategories {
  return const <LokallyServiceCategoryData>[
    LokallyServiceCategoryData(
      id: 'fallback-digital-aulas',
      name: 'Aulas',
      slug: 'aulas',
      format: 'digital',
      hasChildren: true,
    ),
    LokallyServiceCategoryData(
      id: 'fallback-digital-consultoria',
      name: 'Consultoria',
      slug: 'consultoria',
      format: 'digital',
      hasChildren: true,
    ),
    LokallyServiceCategoryData(
      id: 'fallback-digital-design',
      name: 'Design e Tecnologia',
      slug: 'design-e-tecnologia',
      format: 'digital',
      hasChildren: true,
    ),
    LokallyServiceCategoryData(
      id: 'fallback-digital-saude',
      name: 'Saúde',
      slug: 'saude',
      format: 'digital',
      hasChildren: true,
    ),
  ];
}

List<LokallyServiceCategoryData> get fallbackPresentialCategories {
  return const <LokallyServiceCategoryData>[
    LokallyServiceCategoryData(
      id: 'fallback-presential-assistencia',
      name: 'Assistência Técnica',
      slug: 'assistencia-tecnica',
      format: 'presential',
      hasChildren: true,
    ),
    LokallyServiceCategoryData(
      id: 'fallback-presential-aulas',
      name: 'Aulas',
      slug: 'aulas',
      format: 'presential',
      hasChildren: true,
    ),
    LokallyServiceCategoryData(
      id: 'fallback-presential-auto',
      name: 'Automóveis',
      slug: 'automoveis',
      format: 'presential',
      hasChildren: true,
    ),
    LokallyServiceCategoryData(
      id: 'fallback-presential-consultoria',
      name: 'Consultoria',
      slug: 'consultoria',
      format: 'presential',
      hasChildren: true,
    ),
    LokallyServiceCategoryData(
      id: 'fallback-presential-eventos',
      name: 'Eventos',
      slug: 'eventos',
      format: 'presential',
      hasChildren: true,
    ),
    LokallyServiceCategoryData(
      id: 'fallback-presential-beleza',
      name: 'Moda e Beleza',
      slug: 'moda-e-beleza',
      format: 'presential',
      hasChildren: true,
    ),
    LokallyServiceCategoryData(
      id: 'fallback-presential-reformas',
      name: 'Reformas e Reparos',
      slug: 'reformas-e-reparos',
      format: 'presential',
      hasChildren: true,
    ),
    LokallyServiceCategoryData(
      id: 'fallback-presential-saude',
      name: 'Saúde',
      slug: 'saude',
      format: 'presential',
      hasChildren: true,
    ),
    LokallyServiceCategoryData(
      id: 'fallback-presential-domesticos',
      name: 'Serviços Domésticos',
      slug: 'servicos-domesticos',
      format: 'presential',
      hasChildren: true,
    ),
  ];
}

List<LokallyServiceAdData> get fallbackServices {
  return const <LokallyServiceAdData>[
    LokallyServiceAdData(
      id: 'fallback-service-1',
      title: 'Aula particular de inglês',
      description:
          'Aulas individuais com foco em conversação, reforço ou preparação para viagens.',
      categoryId: 'fallback-digital-aulas',
      category: 'Aulas',
      providerName: 'Prestador',
      imageUrl: '',
      providerImageUrl: '',
      productType: 'service',
      serviceFormat: 'digital',
      serviceDeliveryType: 'online',
      price: 59.90,
      rating: 4.9,
      jobsCount: 42,
      approvalStatus: 'approved',
      isActive: true,
    ),
    LokallyServiceAdData(
      id: 'fallback-service-2',
      title: 'Eletricista residencial',
      description:
          'Instalações, reparos, manutenção e pequenos ajustes elétricos.',
      categoryId: 'fallback-presential-reformas',
      category: 'Reformas e Reparos',
      providerName: 'Prestador',
      imageUrl: '',
      providerImageUrl: '',
      productType: 'service',
      serviceFormat: 'presential',
      serviceDeliveryType: 'presential',
      price: 120,
      rating: 4.8,
      jobsCount: 28,
      approvalStatus: 'approved',
      isActive: true,
    ),
    LokallyServiceAdData(
      id: 'fallback-service-3',
      title: 'Social media para pequenos negócios',
      description:
          'Planejamento, criação de conteúdo e organização de presença digital.',
      categoryId: 'fallback-digital-design',
      category: 'Design e Tecnologia',
      providerName: 'Prestador',
      imageUrl: '',
      providerImageUrl: '',
      productType: 'service',
      serviceFormat: 'digital',
      serviceDeliveryType: 'download',
      price: 199.90,
      rating: 4.7,
      jobsCount: 31,
      approvalStatus: 'approved',
      isActive: true,
    ),
  ];
}
