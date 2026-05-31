import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/location/view/pick_map_screen.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

import 'store_seller_vehicle_form_screen.dart' as vehicle_ui;

class StoreSellerRealEstateFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialRealEstate;

  const StoreSellerRealEstateFormScreen({super.key, this.initialRealEstate});

  @override
  State<StoreSellerRealEstateFormScreen> createState() =>
      _StoreSellerRealEstateFormScreenState();
}

class _StoreSellerRealEstateFormScreenState
    extends State<StoreSellerRealEstateFormScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  static const String realEstatePlansUri = '/api/store/ad-plans';
  static const String realEstateStoreUri = '/api/customer/store/real-estate-ad';

  static String realEstateUpdateUri(String id) {
    return '/api/customer/store/real-estate-ad/$id/update';
  }

  final TextEditingController registrationController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController totalMonthlyController = TextEditingController();
  final TextEditingController condoController = TextEditingController();
  final TextEditingController taxController = TextEditingController();
  final TextEditingController fireInsuranceController = TextEditingController();
  final TextEditingController serviceFeeController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController complementController = TextEditingController();
  final TextEditingController neighborhoodController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController zipCodeController = TextEditingController();
  final TextEditingController latitudeController = TextEditingController();
  final TextEditingController longitudeController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController bedroomsController = TextEditingController();
  final TextEditingController suitesController = TextEditingController();
  final TextEditingController bathroomsController = TextEditingController();
  final TextEditingController parkingController = TextEditingController();
  final TextEditingController floorController = TextEditingController();

  static const List<String> salePropertyTypes = [
    'Apartamento',
    'Casa',
    'Casa em condomínio',
    'Kitnet',
    'Studio',
    'Cobertura',
    'Prédio',
    'Sala comercial',
    'Loja comercial',
    'Galpão',
    'Terreno',
    'Chácara',
    'Sítio',
    'Fazenda',
  ];

  static const List<String> rentPropertyTypes = [
    'Apartamento',
    'Casa',
    'Casa em condomínio',
    'Kitnet',
    'Studio',
    'Cobertura',
    'Prédio',
    'Sala comercial',
    'Loja comercial',
    'Galpão',
    'Chácara',
    'Sítio',
  ];

  static const List<String> seasonalPropertyTypes = [
    'Apartamento',
    'Casa',
    'Casa em condomínio',
    'Kitnet',
    'Studio',
    'Cobertura',
    'Chácara',
    'Sítio',
    'Fazenda',
  ];

  final List<String> photoLabels = const [
    'Foto de capa',
    'Fachada',
    'Sala',
    'Cozinha',
    'Quarto',
    'Banheiro',
    'Área de serviço',
    'Garagem',
    'Área externa',
    'Detalhes',
  ];

  final List<String> availableOptions = const [
    'Box',
    'Armários no quarto',
    'Armários nos banheiros',
    'Armários na cozinha',
    'Chuveiro a gás',
    'Área de serviço',
    'Varanda',
    'Piscina',
    'Ar-condicionado',
    'Closet',
    'Cozinha americana',
    'Home-office',
    'Jardim',
    'Quintal',
    'Elevador',
    'Portaria',
    'Academia',
    'Churrasqueira',
    'Acessibilidade',
  ];

  final List<String> unavailableOptions = const [
    'Banheira de hidromassagem',
    'Varanda',
    'Piscina privativa',
    'Ar-condicionado',
    'Apartamento cobertura',
    'Fogão incluso',
    'Geladeira inclusa',
    'Banheiro adaptado',
    'Closet',
    'Cozinha americana',
    'Home-office',
    'Jardim',
    'Quintal',
    'Somente uma casa no terreno',
    'Quartos e corredores com portas amplas',
  ];

  bool isLoadingPlans = false;
  bool isSubmitting = false;

  String advertiserType = 'owner';
  String listingType = 'sale';
  String propertyType = 'Apartamento';
  String acceptsPets = 'yes';
  String furnishedType = 'unfurnished';
  String selectedPlanSlug = '';
  int availableAdCredits = 0;
  bool hasUnlimitedAdPlan = false;
  String unlimitedPlanExpiresAt = '';

  String get editingRealEstateId => cleanInitialValue('id');
  bool get isEditingRealEstate => editingRealEstateId.isNotEmpty;

  String cleanInitialValue(String key) {
    final dynamic value = widget.initialRealEstate?[key];

    if (value == null) {
      return '';
    }

    final String text = value.toString().trim();

    return text == 'null' ? '' : text;
  }

  bool parseInitialBool(String key) {
    final dynamic value = widget.initialRealEstate?[key];

    if (value is bool) {
      return value;
    }

    final String text = value?.toString().trim().toLowerCase() ?? '';

    return text == '1' || text == 'true' || text == 'sim' || text == 'yes';
  }

  List<String> parseInitialList(String key) {
    final dynamic value = widget.initialRealEstate?[key];

    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty && item != 'null')
          .toList();
    }

    final String text = value?.toString().trim() ?? '';

    if (text.isEmpty || text == 'null') {
      return <String>[];
    }

    try {
      final dynamic decoded = jsonDecode(text);

      if (decoded is List) {
        return decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty && item != 'null')
            .toList();
      }
    } catch (_) {}

    return text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty && item != 'null')
        .toList();
  }

  List<RealEstatePlanOption> plans = <RealEstatePlanOption>[];
  final Map<String, XFile> selectedPhotos = <String, XFile>{};
  XFile? selectedVideo;
  final Set<String> selectedAvailable = <String>{};
  final Set<String> selectedUnavailable = <String>{};

  @override
  void initState() {
    super.initState();
    addressController.addListener(refreshAddressPreview);
    applyInitialRealEstateData();
    loadPlans();
  }

  void applyInitialRealEstateData() {
    if (widget.initialRealEstate == null) {
      return;
    }

    advertiserType = cleanInitialValue('advertiser_type').isEmpty
        ? advertiserType
        : cleanInitialValue('advertiser_type');
    listingType = cleanInitialValue('listing_type').isEmpty
        ? listingType
        : cleanInitialValue('listing_type');
    propertyType = cleanInitialValue('property_type').isEmpty
        ? propertyType
        : cleanInitialValue('property_type');
    furnishedType = cleanInitialValue('furnished_type').isEmpty
        ? furnishedType
        : cleanInitialValue('furnished_type');
    acceptsPets = parseInitialBool('accepts_pets') ? 'yes' : 'no';

    final String planSlug = cleanInitialValue('plan_slug');
    if (planSlug.isNotEmpty) {
      selectedPlanSlug = planSlug;
    }

    registrationController.text =
        cleanInitialValue('professional_registration');
    titleController.text = cleanInitialValue('title').isEmpty
        ? cleanInitialValue('name')
        : cleanInitialValue('title');
    descriptionController.text = cleanInitialValue('description');
    priceController.text = cleanInitialValue('price');
    totalMonthlyController.text = cleanInitialValue('total_monthly_cost');
    condoController.text = cleanInitialValue('condominium_fee');
    taxController.text = cleanInitialValue('property_tax');
    fireInsuranceController.text = cleanInitialValue('fire_insurance_fee');
    serviceFeeController.text = cleanInitialValue('service_fee');
    addressController.text = cleanInitialValue('address');
    numberController.text = cleanInitialValue('address_number');
    complementController.text = cleanInitialValue('address_complement');
    neighborhoodController.text = cleanInitialValue('neighborhood');
    cityController.text = cleanInitialValue('city');
    stateController.text = cleanInitialValue('state');
    zipCodeController.text = cleanInitialValue('zip_code');
    latitudeController.text = cleanInitialValue('latitude');
    longitudeController.text = cleanInitialValue('longitude');
    areaController.text = cleanInitialValue('area_m2');
    bedroomsController.text = cleanInitialValue('bedrooms');
    suitesController.text = cleanInitialValue('suites');
    bathroomsController.text = cleanInitialValue('bathrooms');
    parkingController.text = cleanInitialValue('parking_spaces');
    floorController.text = cleanInitialValue('floor');

    selectedAvailable
      ..clear()
      ..addAll(parseInitialList('available_items'));
    selectedUnavailable
      ..clear()
      ..addAll(parseInitialList('unavailable_items'));
  }

  void refreshAddressPreview() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  @override
  void dispose() {
    addressController.removeListener(refreshAddressPreview);

    for (final TextEditingController controller in [
      registrationController,
      titleController,
      descriptionController,
      priceController,
      totalMonthlyController,
      condoController,
      taxController,
      fireInsuranceController,
      serviceFeeController,
      addressController,
      numberController,
      complementController,
      neighborhoodController,
      cityController,
      stateController,
      zipCodeController,
      latitudeController,
      longitudeController,
      areaController,
      bedroomsController,
      suitesController,
      bathroomsController,
      parkingController,
      floorController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String get advertiserLabel =>
      advertiserType == 'agency' ? 'Imobiliária' : 'Proprietário';

  List<String> get currentPropertyTypes {
    if (listingType == 'seasonal') {
      return seasonalPropertyTypes;
    }

    if (listingType == 'rent') {
      return rentPropertyTypes;
    }

    return salePropertyTypes;
  }

  bool get isRentListing => listingType == 'rent';
  bool get isSaleListing => listingType == 'sale';
  bool get isSeasonalListing => listingType == 'seasonal';

  bool get isLandProperty => propertyType == 'Terreno';

  bool get isCommercialProperty =>
      propertyType == 'Sala comercial' ||
      propertyType == 'Loja comercial' ||
      propertyType == 'Galpão';

  bool get isRuralProperty =>
      propertyType == 'Chácara' ||
      propertyType == 'Sítio' ||
      propertyType == 'Fazenda';

  bool get showResidentialFields => !isLandProperty && !isCommercialProperty;

  bool get showRoomsAndSuites => showResidentialFields || isRuralProperty;

  bool get showFurnishedAndPets => !isLandProperty && !isCommercialProperty;

  bool get showFloorField =>
      propertyType == 'Apartamento' ||
      propertyType == 'Kitnet' ||
      propertyType == 'Studio' ||
      propertyType == 'Cobertura' ||
      propertyType == 'Prédio';

  String get priceFieldLabel {
    if (isRentListing) {
      return 'store_rent_value'.tr;
    }

    if (isSeasonalListing) {
      return 'store_daily_or_package_value'.tr;
    }

    return 'store_sale_value'.tr;
  }

  String get priceFieldHint {
    if (isSaleListing) {
      return '350.000,00';
    }

    if (isSeasonalListing) {
      return '450,00';
    }

    return '1.490,00';
  }

  String get titleFieldHint {
    if (isRentListing) {
      return 'store_property_rent_title_hint'.tr;
    }

    if (isSeasonalListing) {
      return 'store_property_seasonal_title_hint'.tr;
    }

    return 'store_property_sale_title_hint'.tr;
  }

  void updateListingType(String label) {
    setState(() {
      listingType = label == 'Aluguel'
          ? 'rent'
          : label == 'Temporada'
              ? 'seasonal'
              : 'sale';

      final List<String> allowedTypes = currentPropertyTypes;

      if (!allowedTypes.contains(propertyType)) {
        propertyType = allowedTypes.first;
      }

      if (!showRoomsAndSuites) {
        bedroomsController.clear();
        suitesController.clear();
      }

      if (isLandProperty) {
        bathroomsController.clear();
        parkingController.clear();
      }

      if (!showFloorField) {
        floorController.clear();
      }

      if (!showFurnishedAndPets) {
        acceptsPets = 'no';
        furnishedType = 'unfurnished';
      }
    });
  }

  void updateAdvertiserType(String label) {
    setState(() {
      advertiserType = label == 'Imobiliária' ? 'agency' : 'owner';

      if (advertiserType == 'owner') {
        registrationController.clear();
      }
    });

    loadPlans();
  }

  String get listingLabel {
    if (listingType == 'rent') return 'Aluguel';
    if (listingType == 'seasonal') return 'Temporada';
    return 'Venda';
  }

  String get furnishedLabel {
    if (furnishedType == 'furnished') return 'Mobiliado';
    if (furnishedType == 'semi_furnished') return 'Semi-mobiliado';
    return 'Sem mobília';
  }

  RealEstatePlanOption? get selectedPlan {
    if (plans.isEmpty || selectedPlanSlug.trim().isEmpty) {
      return null;
    }

    for (final RealEstatePlanOption plan in plans) {
      if (plan.slug == selectedPlanSlug) {
        return plan;
      }
    }

    return null;
  }

  bool get hasCreditsToPublishRealEstateAd {
    return hasUnlimitedAdPlan || availableAdCredits > 0;
  }

  bool get mustChooseRealEstateAdPlan {
    return !isEditingRealEstate && !hasCreditsToPublishRealEstateAd;
  }

  Future<void> loadPlans() async {
    if (isLoadingPlans) return;
    setState(() => isLoadingPlans = true);

    final Response response = await Get.find<ApiClient>().getData(
      realEstatePlansUri,
    );

    if (!mounted) return;

    final dynamic body = response.body;
    dynamic dataValue;

    if (body is Map) {
      dataValue = body['data'];
    }

    List<dynamic> planRows = <dynamic>[];
    int parsedAvailableCredits = 0;
    bool parsedUnlimitedActive = false;
    String parsedUnlimitedExpiresAt = '';

    if (dataValue is Map) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(dataValue);

      final dynamic creditPlansValue = data['ad_credit_plans'] ??
          data['real_estate_ad_plans'] ??
          data['plans'] ??
          data['credit_plans'];

      if (creditPlansValue is List) {
        planRows = creditPlansValue;
      }

      final dynamic unlimitedPlanValue = data['unlimited_plan'];
      if (unlimitedPlanValue is Map) {
        planRows = <dynamic>[...planRows, unlimitedPlanValue];
      }

      parsedAvailableCredits = parseUnifiedInt(
        data['seller_ad_credit_balance'] ??
            data['ad_credit_balance'] ??
            data['credit_balance'] ??
            data['available_credits'] ??
            data['valid_credits'] ??
            data['credits_available'],
      );

      parsedUnlimitedActive = parseUnifiedBool(
        data['has_unlimited_plan'] ??
            data['unlimited_plan_active'] ??
            data['seller_has_unlimited_plan'] ??
            data['has_active_unlimited_plan'],
      );

      parsedUnlimitedExpiresAt =
          '${data['unlimited_expires_at'] ?? data['unlimited_plan_expires_at'] ?? ''}'
              .trim();

      final dynamic sellerValue = data['seller'];
      if (sellerValue is Map) {
        final Map<String, dynamic> seller =
            Map<String, dynamic>.from(sellerValue);

        if (parsedAvailableCredits <= 0) {
          parsedAvailableCredits = parseUnifiedInt(
            seller['ad_credit_balance'] ??
                seller['credit_balance'] ??
                seller['available_credits'] ??
                seller['valid_credits'],
          );
        }

        if (!parsedUnlimitedActive) {
          parsedUnlimitedActive = parseUnifiedBool(
            seller['has_unlimited_plan'] ??
                seller['unlimited_plan_active'] ??
                seller['has_active_unlimited_plan'],
          );
        }

        if (parsedUnlimitedExpiresAt.isEmpty) {
          parsedUnlimitedExpiresAt =
              '${seller['unlimited_expires_at'] ?? seller['unlimited_plan_expires_at'] ?? ''}'
                  .trim();
        }
      }
    } else if (dataValue is List) {
      planRows = dataValue;
    }

    final List<RealEstatePlanOption> parsed = planRows
        .whereType<Map>()
        .map(RealEstatePlanOption.fromMap)
        .where((plan) => plan.id.isNotEmpty)
        .toList();

    setState(() {
      plans = parsed;
      availableAdCredits = parsedAvailableCredits;
      hasUnlimitedAdPlan = parsedUnlimitedActive;
      unlimitedPlanExpiresAt = parsedUnlimitedExpiresAt;
      isLoadingPlans = false;

      if (selectedPlanSlug.isNotEmpty &&
          !plans.any((plan) => plan.slug == selectedPlanSlug)) {
        selectedPlanSlug = '';
      }
    });
  }

  int parseUnifiedInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.round();
    }

    final String text = '${value ?? ''}'.trim();

    if (text.isEmpty) {
      return 0;
    }

    return int.tryParse(text.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
  }

  bool parseUnifiedBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final String text = '${value ?? ''}'.trim().toLowerCase();

    return text == '1' ||
        text == 'true' ||
        text == 'sim' ||
        text == 'yes' ||
        text == 'active' ||
        text == 'ativo';
  }

  String normalizeMoney(String value) {
    String normalized = value.trim();
    if (normalized.contains(',')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }
    return normalized;
  }

  String onlyNumbers(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  void showMessage(String message) {
    final Color primaryColor = Theme.of(context).primaryColor;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: textMedium.copyWith(color: Colors.white, fontSize: 12.8),
        ),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void showSelectionSheet({
    required String title,
    required List<String> options,
    required ValueChanged<String> onSelected,
    String? selectedValue,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.78,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 12),
                  blurRadius: 28,
                  color: Colors.black.withValues(alpha: 0.14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.close_rounded,
                          color: Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => Divider(
                      color: Colors.grey.shade200,
                      height: 1,
                    ),
                    itemBuilder: (_, index) {
                      final String option = options[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          onSelected(option);
                          Navigator.of(context).pop();
                        },
                        title: Text(
                          option,
                          style: textMedium.copyWith(
                            color: Colors.black87,
                            fontSize: 13.8,
                          ),
                        ),
                        trailing: option == selectedValue
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: Theme.of(context).primaryColor,
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> openPropertyMapPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();

    try {
      await Get.to(
        () => PickMapScreen(
          type: LocationType.location,
          onLocationPicked: (Position position, String address) {
            if (!mounted) {
              return;
            }

            setState(() {
              latitudeController.text = position.latitude.toString();
              longitudeController.text = position.longitude.toString();

              if (address.trim().isNotEmpty) {
                addressController.text = address.trim();
              } else if (addressController.text.trim().isEmpty) {
                addressController.text =
                    'Local marcado no mapa (${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)})';
              }
            });
          },
        ),
      );
    } catch (_) {
      showMessage('store_open_map_error'.tr);
    }
  }

  Future<void> handlePhotoTap(String label) async {
    final String? action = await showMediaActionSheet(
      title: label,
      hasCurrentFile: selectedPhotos.containsKey(label),
      cameraEnabled: true,
    );
    if (action == null) return;
    if (action == 'remove') {
      setState(() => selectedPhotos.remove(label));
      return;
    }

    final XFile? image = await ImagePicker().pickImage(
      source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 82,
    );
    if (image == null || !mounted) return;
    setState(() => selectedPhotos[label] = image);
  }

  Future<void> handleVideoTap() async {
    final String? action = await showMediaActionSheet(
      title: 'store_property_video'.tr,
      hasCurrentFile: selectedVideo != null,
      cameraEnabled: false,
    );
    if (action == null) return;
    if (action == 'remove') {
      setState(() => selectedVideo = null);
      return;
    }

    final XFile? video = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (video == null || !mounted) return;
    setState(() => selectedVideo = video);
  }

  Future<String?> showMediaActionSheet({
    required String title,
    required bool hasCurrentFile,
    required bool cameraEnabled,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 10),
                  blurRadius: 24,
                  color: Colors.black.withValues(alpha: 0.14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.close_rounded,
                          color: Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (cameraEnabled) ...[
                  RealEstateActionTile(
                    icon: Icons.photo_camera_rounded,
                    title: 'store_take_photo'.tr,
                    onTap: () => Navigator.of(context).pop('camera'),
                  ),
                  const SizedBox(height: 8),
                ],
                RealEstateActionTile(
                  icon: cameraEnabled
                      ? Icons.photo_library_rounded
                      : Icons.video_library_rounded,
                  title: cameraEnabled
                      ? 'store_choose_from_gallery'.tr
                      : 'store_choose_video'.tr,
                  onTap: () => Navigator.of(context).pop('gallery'),
                ),
                if (hasCurrentFile) ...[
                  const SizedBox(height: 8),
                  RealEstateActionTile(
                    icon: Icons.delete_outline_rounded,
                    title: cameraEnabled
                        ? 'store_remove_photo'.tr
                        : 'store_remove_video'.tr,
                    destructive: true,
                    onTap: () => Navigator.of(context).pop('remove'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showRealEstatePlanSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (isLoadingPlans) {
      showMessage('store_loading_listing_plans_wait'.tr);
      return;
    }

    if (plans.isEmpty) {
      showMessage('store_listing_plans_load_error'.tr);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(modalContext).size.height * 0.84,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 12),
                  blurRadius: 28,
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
                    Expanded(
                      child: Text(
                        'store_choose_property_ad_payment'.tr,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 17,
                          height: 1.18,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(modalContext).pop(),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.grey.shade700,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'store_property_ad_credit_explanation'.tr,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 12.6,
                    height: 1.34,
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: plans.length,
                    itemBuilder: (_, index) {
                      final RealEstatePlanOption plan = plans[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: vehicle_ui.StoreSellerVehiclePlanOption(
                          primaryColor: Theme.of(context).primaryColor,
                          selected: selectedPlanSlug == plan.slug,
                          title: plan.name,
                          price: plan.formattedPrice,
                          description: plan.fullDescription,
                          onTap: () {
                            setState(() {
                              selectedPlanSlug = plan.slug;
                            });
                            Navigator.of(modalContext).pop();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> handleSubmit() async {
    if (isSubmitting) {
      return;
    }

    if (!formKey.currentState!.validate()) {
      return;
    }

    if (!isEditingRealEstate && selectedPhotos['Foto de capa'] == null) {
      showMessage('store_property_cover_photo_required'.tr);
      return;
    }

    final RealEstatePlanOption? plan = selectedPlan;
    if (mustChooseRealEstateAdPlan && (plan == null || plan.id.isEmpty)) {
      showMessage('store_choose_property_listing_plan'.tr);
      return;
    }

    if (advertiserType == 'agency' &&
        registrationController.text.trim().isEmpty) {
      showMessage('store_agency_registration_required'.tr);
      return;
    }

    if (addressController.text.trim().isEmpty) {
      showMessage('store_property_address_required'.tr);
      return;
    }

    final Map<String, String> body = <String, String>{
      'advertiser_type': advertiserType,
      'professional_registration': advertiserType == 'agency'
          ? registrationController.text.trim().toUpperCase()
          : '',
      'listing_type': listingType,
      'property_type': propertyType,
      if (plan != null) 'plan_id': plan.id,
      'title': titleController.text.trim(),
      'description': descriptionController.text.trim(),
      'price': normalizeMoney(priceController.text),
      'total_monthly_cost': normalizeMoney(totalMonthlyController.text),
      'condominium_fee': normalizeMoney(condoController.text),
      'property_tax': normalizeMoney(taxController.text),
      'fire_insurance_fee': normalizeMoney(fireInsuranceController.text),
      'service_fee': normalizeMoney(serviceFeeController.text),
      'address': addressController.text.trim(),
      'address_number': numberController.text.trim(),
      'address_complement': complementController.text.trim(),
      'neighborhood': neighborhoodController.text.trim(),
      'city': cityController.text.trim(),
      'state': stateController.text.trim().toUpperCase(),
      'zip_code': zipCodeController.text.trim(),
      'latitude': normalizeMoney(latitudeController.text),
      'longitude': normalizeMoney(longitudeController.text),
      'area_m2': normalizeMoney(areaController.text),
      'bedrooms': onlyNumbers(bedroomsController.text),
      'suites': onlyNumbers(suitesController.text),
      'bathrooms': onlyNumbers(bathroomsController.text),
      'parking_spaces': onlyNumbers(parkingController.text),
      'floor': floorController.text.trim(),
      'accepts_pets': acceptsPets == 'yes' ? '1' : '0',
      'furnished_type': furnishedType,
      'available_items': jsonEncode(selectedAvailable.toList()),
      'unavailable_items': jsonEncode(selectedUnavailable.toList()),
      'features':
          jsonEncode(<String>[propertyType, listingLabel, furnishedLabel]),
    };
    body.removeWhere((_, String value) => value.trim().isEmpty);

    final XFile? cover = selectedPhotos['Foto de capa'];
    final List<MultipartBody> files = <MultipartBody>[];
    for (final String label in photoLabels) {
      if (label == 'Foto de capa') {
        continue;
      }
      final XFile? file = selectedPhotos[label];
      if (file != null) {
        files.add(MultipartBody('images[]', file));
      }
    }
    if (selectedVideo != null) {
      files.add(MultipartBody('video_file', selectedVideo));
    }

    setState(() => isSubmitting = true);
    try {
      final Response response = isEditingRealEstate
          ? await Get.find<ApiClient>().postData(
              realEstateUpdateUri(editingRealEstateId),
              body,
            )
          : await Get.find<ApiClient>().postMultipartData(
              realEstateStoreUri,
              body,
              MultipartBody('images[]', cover!),
              files,
            );
      if (!mounted) {
        return;
      }
      final dynamic responseBody = response.body;
      final bool success =
          response.statusCode == 200 || response.statusCode == 201;
      final String message =
          responseBody is Map && responseBody['message'] != null
              ? '${responseBody['message']}'
              : success
                  ? isEditingRealEstate
                      ? 'store_property_ad_updated_sent_approval'.tr
                      : 'store_property_ad_created_sent_approval'.tr
                  : isEditingRealEstate
                      ? 'store_property_ad_update_error'.tr
                      : 'store_property_ad_create_error'.tr;
      showMessage(message);
      if (success) {
        await Future<void>.delayed(const Duration(milliseconds: 850));
        if (mounted) {
          Get.back(result: true);
        }
      }
    } catch (_) {
      if (mounted) {
        showMessage('store_listing_submit_try_again_error'.tr);
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          vehicle_ui.StoreSellerVehicleTopBar(
            primaryColor: primaryColor,
            title: isEditingRealEstate
                ? 'store_edit_property'.tr
                : 'store_register_property'.tr,
            onBackTap: () => Get.back(),
          ),
          Expanded(
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Dimensions.paddingSizeDefault,
                  18,
                  Dimensions.paddingSizeDefault,
                  30,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    vehicle_ui.StoreSellerVehicleSection(
                      title: 'store_advertiser_type'.tr,
                      children: [
                        RealEstateChoiceCards(
                          label: 'store_who_is_listing'.tr,
                          options: const [
                            RealEstateChoiceOption(
                              title: 'Proprietário',
                              description: 'Anúncio feito pelo dono do imóvel.',
                              icon: Icons.person_outline_rounded,
                            ),
                            RealEstateChoiceOption(
                              title: 'Imobiliária',
                              description:
                                  'Anúncio feito por empresa ou corretor.',
                              icon: Icons.business_center_outlined,
                            ),
                          ],
                          selectedValue: advertiserLabel,
                          primaryColor: primaryColor,
                          onChanged: updateAdvertiserType,
                        ),
                        if (advertiserType == 'agency') ...[
                          const SizedBox(height: 12),
                          vehicle_ui.StoreSellerVehicleTextInput(
                            label: 'store_agency_creci_crea'.tr,
                            hint: 'store_professional_registration_hint'.tr,
                            controller: registrationController,
                            textCapitalization: TextCapitalization.characters,
                            validator: (value) {
                              if (advertiserType == 'agency' &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'store_agency_registration_required'.tr;
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    vehicle_ui.StoreSellerVehicleSection(
                      title: 'store_listing_purpose_and_title'.tr,
                      children: [
                        RealEstateChoiceCards(
                          label: 'store_listing_type'.tr,
                          options: const [
                            RealEstateChoiceOption(
                              title: 'Venda',
                              description: 'Para imóveis colocados à venda.',
                              icon: Icons.sell_outlined,
                            ),
                            RealEstateChoiceOption(
                              title: 'Aluguel',
                              description: 'Para locação mensal ou anual.',
                              icon: Icons.key_outlined,
                            ),
                            RealEstateChoiceOption(
                              title: 'Temporada',
                              description: 'Para estadias curtas e lazer.',
                              icon: Icons.weekend_outlined,
                            ),
                          ],
                          selectedValue: listingLabel,
                          primaryColor: primaryColor,
                          onChanged: updateListingType,
                        ),
                        const SizedBox(height: 12),
                        vehicle_ui.StoreSellerVehicleSelectField(
                          label: 'store_property_type'.tr,
                          value: propertyType,
                          primaryColor: primaryColor,
                          onTap: () => showSelectionSheet(
                            title: 'store_property_type'.tr,
                            options: currentPropertyTypes,
                            selectedValue: propertyType,
                            onSelected: (value) {
                              setState(() {
                                propertyType = value;

                                if (!showRoomsAndSuites) {
                                  bedroomsController.clear();
                                  suitesController.clear();
                                }

                                if (isLandProperty) {
                                  bathroomsController.clear();
                                  parkingController.clear();
                                }

                                if (!showFloorField) {
                                  floorController.clear();
                                }

                                if (!showFurnishedAndPets) {
                                  acceptsPets = 'no';
                                  furnishedType = 'unfurnished';
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        vehicle_ui.StoreSellerVehicleTextInput(
                          label: 'store_listing_title'.tr,
                          hint: titleFieldHint,
                          controller: titleController,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'store_listing_title_required'.tr;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        vehicle_ui.StoreSellerVehicleTextInput(
                          label: 'store_description'.tr,
                          hint: 'store_property_description_hint'.tr,
                          controller: descriptionController,
                          maxLines: 5,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    vehicle_ui.StoreSellerVehicleSection(
                      title: 'store_property_address'.tr,
                      children: [
                        RealEstateMapAddressTile(
                          primaryColor: primaryColor,
                          address: addressController.text.trim(),
                          latitude: latitudeController.text.trim(),
                          longitude: longitudeController.text.trim(),
                          onTap: openPropertyMapPicker,
                        ),
                        const SizedBox(height: 12),
                        vehicle_ui.StoreSellerVehicleTextInput(
                          label: 'store_selected_address'.tr,
                          hint: 'store_type_address_or_select_map'.tr,
                          controller: addressController,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'store_property_address_or_map_required'
                                  .tr;
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        vehicle_ui.StoreSellerVehicleTextInput(
                          label: 'store_note'.tr,
                          hint: 'store_property_address_note_hint'.tr,
                          controller: complementController,
                          maxLines: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    vehicle_ui.StoreSellerVehicleSection(
                      title: 'store_values'.tr,
                      children: [
                        vehicle_ui.StoreSellerVehicleTextInput(
                          label: priceFieldLabel,
                          hint: priceFieldHint,
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [
                            vehicle_ui.BrazilianCurrencyInputFormatter(),
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'store_main_value_required'.tr;
                            }

                            return null;
                          },
                        ),
                        if (!isSeasonalListing) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: vehicle_ui.StoreSellerVehicleTextInput(
                                  label: 'store_condominium'.tr,
                                  hint: '311,00',
                                  controller: condoController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: const [
                                    vehicle_ui
                                        .BrazilianCurrencyInputFormatter(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: vehicle_ui.StoreSellerVehicleTextInput(
                                  label: 'store_property_tax'.tr,
                                  hint: '0,00',
                                  controller: taxController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: const [
                                    vehicle_ui
                                        .BrazilianCurrencyInputFormatter(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (isRentListing) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: vehicle_ui.StoreSellerVehicleTextInput(
                                  label: 'store_fire_insurance'.tr,
                                  hint: '19,00',
                                  controller: fireInsuranceController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: const [
                                    vehicle_ui
                                        .BrazilianCurrencyInputFormatter(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: vehicle_ui.StoreSellerVehicleTextInput(
                                  label: 'store_service_fee'.tr,
                                  hint: '38,00',
                                  controller: serviceFeeController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: const [
                                    vehicle_ui
                                        .BrazilianCurrencyInputFormatter(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          vehicle_ui.StoreSellerVehicleTextInput(
                            label: 'store_total_rent'.tr,
                            hint: '1.858,00',
                            controller: totalMonthlyController,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [
                              vehicle_ui.BrazilianCurrencyInputFormatter(),
                            ],
                          ),
                        ],
                        if (isSeasonalListing) ...[
                          const SizedBox(height: 12),
                          vehicle_ui.StoreSellerVehicleTextInput(
                            label: 'store_cleaning_or_service_fee'.tr,
                            hint: '120,00',
                            controller: serviceFeeController,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [
                              vehicle_ui.BrazilianCurrencyInputFormatter(),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    vehicle_ui.StoreSellerVehicleSection(
                      title: 'store_main_features'.tr,
                      children: [
                        vehicle_ui.StoreSellerVehicleTextInput(
                          label: isLandProperty
                              ? 'store_land_area_m2'.tr
                              : 'store_area_m2'.tr,
                          hint: isLandProperty ? '360' : '47',
                          controller: areaController,
                          keyboardType: TextInputType.number,
                        ),
                        if (showRoomsAndSuites) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: vehicle_ui.StoreSellerVehicleTextInput(
                                  label: 'store_bedrooms'.tr,
                                  hint: '2',
                                  controller: bedroomsController,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: vehicle_ui.StoreSellerVehicleTextInput(
                                  label: 'store_suites'.tr,
                                  hint: '0',
                                  controller: suitesController,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (!isLandProperty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: vehicle_ui.StoreSellerVehicleTextInput(
                                  label: 'store_bathrooms'.tr,
                                  hint: '1',
                                  controller: bathroomsController,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: vehicle_ui.StoreSellerVehicleTextInput(
                                  label: 'store_parking_spaces'.tr,
                                  hint: '1',
                                  controller: parkingController,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          if (showFloorField) ...[
                            const SizedBox(height: 12),
                            vehicle_ui.StoreSellerVehicleTextInput(
                              label: 'store_floor'.tr,
                              hint: propertyType == 'Prédio'
                                  ? 'store_floor_building_hint'.tr
                                  : 'store_floor_hint'.tr,
                              controller: floorController,
                            ),
                          ],
                        ],
                        if (showFurnishedAndPets) ...[
                          const SizedBox(height: 12),
                          vehicle_ui.StoreSellerVehicleSegmentedField(
                            label: 'store_accepts_pets'.tr,
                            options: const ['yes', 'no'],
                            selectedValue: acceptsPets,
                            primaryColor: primaryColor,
                            onChanged: (value) =>
                                setState(() => acceptsPets = value),
                          ),
                          const SizedBox(height: 12),
                          vehicle_ui.StoreSellerVehicleSegmentedField(
                            label: 'store_furniture'.tr,
                            options: const [
                              'Sem mobília',
                              'Semi-mobiliado',
                              'Mobiliado',
                            ],
                            selectedValue: furnishedLabel,
                            primaryColor: primaryColor,
                            onChanged: (value) {
                              setState(() {
                                furnishedType = value == 'Mobiliado'
                                    ? 'furnished'
                                    : value == 'Semi-mobiliado'
                                        ? 'semi_furnished'
                                        : 'unfurnished';
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    vehicle_ui.StoreSellerVehicleSection(
                      title: 'store_photos_and_video'.tr,
                      children: [
                        Text(
                            isEditingRealEstate
                                ? 'store_property_edit_photos_note'.tr
                                : 'store_property_photos_review_note'.tr,
                            style: textRegular.copyWith(
                                color: Colors.grey.shade600,
                                fontSize: 12.5,
                                height: 1.32)),
                        const SizedBox(height: 12),
                        RealEstatePhotoGrid(
                            primaryColor: primaryColor,
                            labels: photoLabels,
                            selectedPhotos: selectedPhotos,
                            onPhotoTap: handlePhotoTap),
                        const SizedBox(height: 12),
                        RealEstateVideoTile(
                            primaryColor: primaryColor,
                            selectedVideo: selectedVideo,
                            onTap: handleVideoTap),
                      ],
                    ),
                    const SizedBox(height: 14),
                    vehicle_ui.StoreSellerVehicleSection(
                      title: 'store_available_items'.tr,
                      children: [
                        RealEstateChipSelector(
                            primaryColor: primaryColor,
                            options: availableOptions,
                            selectedItems: selectedAvailable,
                            onToggle: (item) {
                              setState(() {
                                selectedAvailable.contains(item)
                                    ? selectedAvailable.remove(item)
                                    : selectedAvailable.add(item);
                                selectedUnavailable.remove(item);
                              });
                            }),
                      ],
                    ),
                    const SizedBox(height: 14),
                    vehicle_ui.StoreSellerVehicleSection(
                      title: 'store_unavailable_items'.tr,
                      children: [
                        RealEstateChipSelector(
                            primaryColor: primaryColor,
                            options: unavailableOptions,
                            selectedItems: selectedUnavailable,
                            unavailableStyle: true,
                            onToggle: (item) {
                              setState(() {
                                selectedUnavailable.contains(item)
                                    ? selectedUnavailable.remove(item)
                                    : selectedUnavailable.add(item);
                                selectedAvailable.remove(item);
                              });
                            }),
                      ],
                    ),
                    const SizedBox(height: 18),
                    RealEstatePricingCard(
                      primaryColor: primaryColor,
                      isLoading: isLoadingPlans,
                      isEditingRealEstate: isEditingRealEstate,
                      availableCredits: availableAdCredits,
                      hasUnlimitedPlan: hasUnlimitedAdPlan,
                      unlimitedPlanExpiresAt: unlimitedPlanExpiresAt,
                      selectedPlan: selectedPlan,
                      onChoosePlanTap: showRealEstatePlanSheet,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white)))
                            : Text(
                                isEditingRealEstate
                                    ? 'store_resend_for_review'.tr
                                    : 'store_send_listing_for_review'.tr,
                                style: textBold.copyWith(
                                    color: Colors.white, fontSize: 14.8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RealEstateMapAddressTile extends StatelessWidget {
  final Color primaryColor;
  final String address;
  final String latitude;
  final String longitude;
  final VoidCallback onTap;

  const RealEstateMapAddressTile({
    super.key,
    required this.primaryColor,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.onTap,
  });

  bool get hasAddress => address.trim().isNotEmpty;
  bool get hasMapLocation =>
      latitude.trim().isNotEmpty && longitude.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bool highlighted = hasAddress || hasMapLocation;

    return Material(
      color: highlighted
          ? primaryColor.withValues(alpha: 0.08)
          : const Color(0xFFF7F8F8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted ? primaryColor : Colors.grey.shade200,
              width: highlighted ? 1.3 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: highlighted
                      ? primaryColor.withValues(alpha: 0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  hasMapLocation
                      ? Icons.location_on_rounded
                      : Icons.add_location_alt_outlined,
                  color: highlighted ? primaryColor : Colors.grey.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasMapLocation
                          ? 'store_address_selected_on_map'.tr
                          : hasAddress
                              ? 'store_address_informed'.tr
                              : 'store_select_address'.tr,
                      style: textBold.copyWith(
                        color: highlighted ? primaryColor : Colors.black87,
                        fontSize: 13.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasMapLocation
                          ? address
                          : hasAddress
                              ? 'store_tap_review_exact_location'.tr
                              : 'store_tap_search_or_pin_address'.tr,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade700,
                        fontSize: 12.4,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_right_rounded,
                color: Colors.grey.shade500,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RealEstateInfoNote extends StatelessWidget {
  final Color primaryColor;
  final String text;

  const RealEstateInfoNote(
      {super.key, required this.primaryColor, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined, color: primaryColor, size: 20),
          const SizedBox(width: 9),
          Expanded(
              child: Text(text,
                  style: textRegular.copyWith(
                      color: Colors.grey.shade800,
                      fontSize: 12.2,
                      height: 1.32))),
        ],
      ),
    );
  }
}

class RealEstateChoiceOption {
  final String title;
  final String? description;
  final IconData icon;

  const RealEstateChoiceOption({
    required this.title,
    this.description,
    required this.icon,
  });
}

class RealEstateChoiceCards extends StatelessWidget {
  final String label;
  final List<RealEstateChoiceOption> options;
  final String selectedValue;
  final Color primaryColor;
  final ValueChanged<String> onChanged;
  final bool compact;

  const RealEstateChoiceCards({
    super.key,
    required this.label,
    required this.options,
    required this.selectedValue,
    required this.primaryColor,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = options.length == 2 ? 2 : 3;
        final double spacing = 8;
        final double itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.tr,
              style: textBold.copyWith(
                color: Colors.black87,
                fontSize: 12.6,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: options.map((option) {
                final bool selected = option.title == selectedValue;

                return SizedBox(
                  width: itemWidth,
                  child: Material(
                    color: selected
                        ? primaryColor.withValues(alpha: 0.10)
                        : const Color(0xFFF7F8F8),
                    borderRadius: BorderRadius.circular(17),
                    child: InkWell(
                      onTap: () => onChanged(option.title),
                      borderRadius: BorderRadius.circular(17),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        constraints:
                            BoxConstraints(minHeight: compact ? 56 : 82),
                        padding: EdgeInsets.fromLTRB(
                          compact ? 8 : 10,
                          compact ? 9 : 12,
                          compact ? 8 : 10,
                          compact ? 9 : 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color:
                                selected ? primaryColor : Colors.grey.shade200,
                            width: selected ? 1.35 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              option.icon,
                              color: selected
                                  ? primaryColor
                                  : Colors.grey.shade600,
                              size: compact ? 20 : 24,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              option.title.tr,
                              textAlign: TextAlign.center,
                              maxLines: compact ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: textBold.copyWith(
                                color: selected
                                    ? primaryColor
                                    : Colors.grey.shade800,
                                fontSize: compact ? 11.4 : 12.2,
                              ),
                            ),
                            if (!compact &&
                                (option.description ?? '')
                                    .trim()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                option.description!.tr,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textRegular.copyWith(
                                  color: Colors.grey.shade600,
                                  fontSize: 10.5,
                                  height: 1.16,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

class RealEstateWrappedSegmentedField extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selectedValue;
  final Color primaryColor;
  final ValueChanged<String> onChanged;

  const RealEstateWrappedSegmentedField({
    super.key,
    required this.label,
    required this.options,
    required this.selectedValue,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.tr,
            style: textBold.copyWith(color: Colors.black87, fontSize: 12.6)),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: const Color(0xFFF7F8F8),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.grey.shade200)),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((option) {
              final bool selected = option == selectedValue;
              return GestureDetector(
                onTap: () => onChanged(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: selected ? primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(13)),
                  child: Text(option.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(
                          color: selected ? Colors.white : Colors.grey.shade700,
                          fontSize: 12.2)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class RealEstatePhotoGrid extends StatelessWidget {
  final Color primaryColor;
  final List<String> labels;
  final Map<String, XFile> selectedPhotos;
  final ValueChanged<String> onPhotoTap;

  const RealEstatePhotoGrid(
      {super.key,
      required this.primaryColor,
      required this.labels,
      required this.selectedPhotos,
      required this.onPhotoTap});

  IconData iconForLabel(String label) {
    final String normalized = label.toLowerCase();
    if (normalized.contains('capa') || normalized.contains('fachada')) {
      return Icons.home_work_outlined;
    }
    if (normalized.contains('quarto')) {
      return Icons.bed_outlined;
    }
    if (normalized.contains('banheiro')) {
      return Icons.shower_outlined;
    }
    if (normalized.contains('garagem')) {
      return Icons.directions_car_outlined;
    }
    if (normalized.contains('cozinha')) {
      return Icons.kitchen_outlined;
    }
    if (normalized.contains('sala')) {
      return Icons.chair_outlined;
    }
    if (normalized.contains('serviço')) {
      return Icons.local_laundry_service_outlined;
    }
    return Icons.add_photo_alternate_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: labels.length,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 9,
          mainAxisSpacing: 9,
          mainAxisExtent: 112),
      itemBuilder: (context, index) {
        final String label = labels[index];
        final XFile? image = selectedPhotos[label];
        final bool selected = image != null;
        return Material(
          color: selected ? Colors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () => onPhotoTap(label),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: selected ? primaryColor : Colors.grey.shade300,
                      width: selected ? 1.3 : 1)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image != null)
                    Image.file(File(image.path), fit: BoxFit.cover)
                  else
                    Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(iconForLabel(label),
                              color: Colors.grey.shade500, size: 30),
                          const SizedBox(height: 8),
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              child: Text(label.tr,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: textMedium.copyWith(
                                      color: Colors.grey.shade700,
                                      fontSize: 11.2,
                                      height: 1.12)))
                        ]),
                  if (image != null) ...[
                    Positioned.fill(
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.58)
                        ])))),
                    Positioned(
                        left: 6,
                        right: 6,
                        bottom: 7,
                        child: Text(label.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: textBold.copyWith(
                                color: Colors.white, fontSize: 10.8))),
                    Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(999)),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 16))),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class RealEstateVideoTile extends StatelessWidget {
  final Color primaryColor;
  final XFile? selectedVideo;
  final VoidCallback onTap;

  const RealEstateVideoTile(
      {super.key,
      required this.primaryColor,
      required this.selectedVideo,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool selected = selectedVideo != null;
    final String title = selected
        ? selectedVideo!.path.split('/').last
        : 'store_add_optional_video'.tr;
    return Material(
      color: selected
          ? primaryColor.withValues(alpha: 0.08)
          : const Color(0xFFF7F8F8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: selected ? primaryColor : Colors.grey.shade200,
                  width: selected ? 1.3 : 1)),
          child: Row(children: [
            Icon(
                selected ? Icons.check_circle_rounded : Icons.videocam_outlined,
                color: selected ? primaryColor : Colors.grey.shade600,
                size: 24),
            const SizedBox(width: 10),
            Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(
                        color: selected ? primaryColor : Colors.grey.shade700,
                        fontSize: 13.2))),
            Icon(Icons.keyboard_arrow_right_rounded,
                color: Colors.grey.shade500),
          ]),
        ),
      ),
    );
  }
}

class RealEstateChipSelector extends StatelessWidget {
  final Color primaryColor;
  final List<String> options;
  final Set<String> selectedItems;
  final ValueChanged<String> onToggle;
  final bool unavailableStyle;

  const RealEstateChipSelector(
      {super.key,
      required this.primaryColor,
      required this.options,
      required this.selectedItems,
      required this.onToggle,
      this.unavailableStyle = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 8,
      children: options.map((item) {
        final bool selected = selectedItems.contains(item);
        final Color activeColor =
            unavailableStyle ? Colors.grey.shade800 : primaryColor;
        return GestureDetector(
          onTap: () => onToggle(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
                color: selected
                    ? activeColor.withValues(alpha: 0.10)
                    : const Color(0xFFF7F8F8),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: selected ? activeColor : Colors.grey.shade200,
                    width: selected ? 1.2 : 1)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  selected
                      ? (unavailableStyle
                          ? Icons.block_rounded
                          : Icons.check_rounded)
                      : Icons.add_rounded,
                  color: selected ? activeColor : Colors.grey.shade500,
                  size: 16),
              const SizedBox(width: 5),
              Text(item.tr,
                  style: textBold.copyWith(
                      color: selected ? activeColor : Colors.grey.shade700,
                      fontSize: 11.7))
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class RealEstatePricingCard extends StatelessWidget {
  final Color primaryColor;
  final bool isLoading;
  final bool isEditingRealEstate;
  final int availableCredits;
  final bool hasUnlimitedPlan;
  final String unlimitedPlanExpiresAt;
  final RealEstatePlanOption? selectedPlan;
  final VoidCallback onChoosePlanTap;

  const RealEstatePricingCard({
    super.key,
    required this.primaryColor,
    required this.isLoading,
    required this.isEditingRealEstate,
    required this.availableCredits,
    required this.hasUnlimitedPlan,
    required this.unlimitedPlanExpiresAt,
    required this.selectedPlan,
    required this.onChoosePlanTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasCredits = availableCredits > 0;
    final bool hasSelectedPlan = selectedPlan != null;
    final bool shouldChoosePlan =
        !isEditingRealEstate && !hasUnlimitedPlan && !hasCredits;
    final String statusTitle = hasUnlimitedPlan
        ? 'store_unlimited_plan_active'.tr
        : hasCredits
            ? 'store_available_credits_count'
                .trParams({'count': '$availableCredits'})
            : hasSelectedPlan
                ? selectedPlan!.name
                : 'store_choose_listing_plan'.tr;
    final String statusDescription = hasUnlimitedPlan
        ? unlimitedPlanExpiresAt.isEmpty
            ? 'store_unlimited_plan_active_description'.tr
            : 'store_unlimited_plan_valid_until'.trParams(
                {'date': unlimitedPlanExpiresAt},
              )
        : hasCredits
            ? 'store_listing_credit_used_after_approval'.tr
            : hasSelectedPlan
                ? selectedPlan!.fullDescription
                : 'store_credit_used_after_approval_generic'.tr;

    return vehicle_ui.StoreSellerVehicleCardBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'store_listing_credits'.tr,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 42,
            height: 3,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: primaryColor.withValues(alpha: 0.16)),
            ),
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
                    hasUnlimitedPlan
                        ? Icons.all_inclusive_rounded
                        : hasCredits
                            ? Icons.confirmation_number_outlined
                            : Icons.credit_score_outlined,
                    color: primaryColor,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusDescription,
                        style: textRegular.copyWith(
                          color: Colors.grey.shade700,
                          fontSize: 11.8,
                          height: 1.28,
                        ),
                      ),
                      if (hasSelectedPlan && shouldChoosePlan) ...[
                        const SizedBox(height: 8),
                        Text(
                          selectedPlan!.formattedPrice,
                          style: textBold.copyWith(
                            color: primaryColor,
                            fontSize: 13.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (shouldChoosePlan) ...[
            const SizedBox(height: 12),
            Material(
              color: primaryColor,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: isLoading ? null : onChoosePlanTap,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 50,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLoading) ...[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.credit_score_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          hasSelectedPlan
                              ? 'store_change_listing_plan'.tr
                              : 'store_choose_listing_plan'.tr,
                          style: textBold.copyWith(
                            color: Colors.white,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (!shouldChoosePlan && !isEditingRealEstate) ...[
            const SizedBox(height: 10),
            Text(
              hasUnlimitedPlan
                  ? 'store_no_charge_with_unlimited_plan'.tr
                  : 'store_no_credit_purchase_with_available_credit'.tr,
              style: textMedium.copyWith(
                color: primaryColor,
                fontSize: 11.8,
                height: 1.28,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RealEstateActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool destructive;
  final VoidCallback onTap;

  const RealEstateActionTile(
      {super.key,
      required this.icon,
      required this.title,
      this.destructive = false,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color color = destructive ? Colors.redAccent : Colors.black87;
    return Material(
      color: destructive
          ? Colors.redAccent.withValues(alpha: 0.08)
          : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
            width: double.infinity,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: textBold.copyWith(color: color, fontSize: 13.4)))
            ])),
      ),
    );
  }
}

class RealEstatePlanOption {
  final String id;
  final String name;
  final String slug;
  final double price;
  final int credits;
  final int billingCycleDays;
  final int adDurationDays;
  final String description;
  final bool unlimited;

  const RealEstatePlanOption({
    required this.id,
    required this.name,
    required this.slug,
    required this.price,
    required this.credits,
    required this.billingCycleDays,
    required this.adDurationDays,
    required this.description,
    this.unlimited = false,
  });

  String get formattedPrice {
    final String value = price.toStringAsFixed(2).replaceAll('.', ',');

    if (unlimited) {
      return 'R\$$value ${'store_yearly'.tr}';
    }

    if (billingCycleDays >= 360) {
      return 'R\$$value ${'store_yearly'.tr}';
    }

    if (billingCycleDays >= 170) {
      return 'R\$$value ${'store_semiannual'.tr}';
    }

    return 'R\$$value';
  }

  String get billingLabel {
    if (unlimited || billingCycleDays >= 360) {
      return 'store_billed_yearly'.tr;
    }

    if (billingCycleDays >= 170) {
      return 'store_billed_semiannually'.tr;
    }

    if (billingCycleDays >= 28) {
      return 'store_billed_monthly'.tr;
    }

    return 'store_one_time_charge'.tr;
  }

  String get creditLabel {
    if (unlimited) {
      return 'store_unlimited_listings_paid_period'.tr;
    }

    return credits == 1
        ? 'store_one_listing_credit'.tr
        : 'store_listing_credits_count'.trParams({'count': '$credits'});
  }

  String get fullDescription {
    final String cleanDescription = description.trim();
    if (cleanDescription.isEmpty) {
      return 'store_plan_default_description'.trParams({
        'credits': creditLabel,
        'billing': billingLabel,
      });
    }

    if (cleanDescription.toLowerCase().contains('6 meses') || unlimited) {
      return cleanDescription;
    }

    return '$cleanDescription ${'store_credit_used_after_approval_generic'.tr}';
  }

  static double parseDoubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    String text = '${value ?? ''}'.trim();

    if (text.isEmpty) {
      return 0;
    }

    if (text.contains(',')) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    }

    return double.tryParse(text) ?? 0;
  }

  static int parseIntValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.round();
    }

    final String text = '${value ?? ''}'.trim();

    if (text.isEmpty) {
      return 0;
    }

    return int.tryParse(text.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
  }

  static bool parseBoolValue(dynamic value) {
    if (value is bool) {
      return value;
    }

    final String text = '${value ?? ''}'.trim().toLowerCase();

    return text == '1' || text == 'true' || text == 'sim' || text == 'yes';
  }

  factory RealEstatePlanOption.fromMap(Map<dynamic, dynamic> map) {
    final String rawName = '${map['name'] ?? ''}'.trim();
    final String rawSlug = '${map['slug'] ?? ''}'.trim();
    final int adLimit = parseIntValue(
      map['ad_limit'] ??
          map['credits'] ??
          map['credit_amount'] ??
          map['real_estate_limit'] ??
          map['property_limit'] ??
          map['limit'],
    );
    final double parsedPrice = parseDoubleValue(
      map['price'] ??
          map['amount'] ??
          map['monthly_price'] ??
          map['semiannual_price'] ??
          map['annual_price'],
    );
    final int parsedBillingCycleDays = parseIntValue(
      map['billing_cycle_days'] ?? map['validity_days'] ?? map['cycle_days'],
    );
    final int parsedAdDurationDays = parseIntValue(
      map['ad_duration_days'] ?? map['duration_days'],
    );
    final bool parsedUnlimited = parseBoolValue(map['is_unlimited']) ||
        parseBoolValue(map['unlimited']) ||
        rawSlug.toLowerCase().contains('unlimited') ||
        rawSlug.toLowerCase().contains('ilimit') ||
        rawName.toLowerCase().contains('ilimit');

    return RealEstatePlanOption(
      id: '${map['id'] ?? ''}',
      name: rawName.isNotEmpty
          ? rawName
          : parsedUnlimited
              ? 'store_unlimited'.tr
              : adLimit == 1
                  ? 'store_one_credit'.tr
                  : 'store_credits_count'.trParams({'count': '$adLimit'}),
      slug: rawSlug.isNotEmpty ? rawSlug : '${map['id'] ?? ''}',
      price: parsedPrice,
      credits: parsedUnlimited ? 0 : adLimit,
      billingCycleDays: parsedBillingCycleDays > 0
          ? parsedBillingCycleDays
          : parsedUnlimited
              ? 365
              : 180,
      adDurationDays: parsedAdDurationDays > 0 ? parsedAdDurationDays : 180,
      description: '${map['description'] ?? ''}',
      unlimited: parsedUnlimited,
    );
  }
}
