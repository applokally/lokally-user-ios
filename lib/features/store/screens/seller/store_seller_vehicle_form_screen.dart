import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreSellerVehicleFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialVehicle;

  const StoreSellerVehicleFormScreen({super.key, this.initialVehicle});

  @override
  State<StoreSellerVehicleFormScreen> createState() =>
      _StoreSellerVehicleFormScreenState();
}

class _StoreSellerVehicleFormScreenState
    extends State<StoreSellerVehicleFormScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController plateController = TextEditingController();
  final TextEditingController brandController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController yearController = TextEditingController();
  final TextEditingController versionController = TextEditingController();
  final TextEditingController mileageController = TextEditingController();
  final TextEditingController colorController = TextEditingController();
  final TextEditingController fuelController = TextEditingController();
  final TextEditingController doorsController = TextEditingController();
  final TextEditingController steeringController = TextEditingController();
  final TextEditingController transmissionController = TextEditingController();
  final TextEditingController tractionController = TextEditingController();
  final TextEditingController engineController = TextEditingController();
  final TextEditingController bodyTypeController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController cityController = TextEditingController();

  static const String vehicleTypesUri = '/api/store/vehicle-marketplace/types';
  static const String vehiclePlansUri = '/api/store/ad-plans';
  static const String vehicleStoreUri = '/api/customer/store/vehicle-ad';

  static String vehicleUpdateUri(String id) {
    return '/api/customer/store/vehicle-ad/$id/update';
  }

  static String vehicleBrandsUri(String vehicleTypeId) {
    return '/api/store/vehicle-marketplace/brands?vehicle_type_id=$vehicleTypeId';
  }

  static String vehicleModelsUri(String brandId) {
    return '/api/store/vehicle-marketplace/models?brand_id=$brandId';
  }

  static const String coverPhotoKey = 'store_vehicle_cover_photo';

  final List<String> photoLabels = const [
    coverPhotoKey,
    'store_vehicle_front_photo',
    'store_vehicle_rear_photo',
    'store_vehicle_left_side_photo',
    'store_vehicle_right_side_photo',
    'store_vehicle_interior_photo',
    'store_vehicle_seats_photo',
    'store_vehicle_engine_photo',
    'store_vehicle_details_photo',
    'store_vehicle_mileage_photo',
  ];

  bool isLoadingVehicleTypes = false;
  bool isLoadingVehicleBrands = false;
  bool isLoadingVehicleModels = false;
  bool isLoadingVehiclePlans = false;
  bool isSubmittingVehicleAd = false;

  List<StoreVehicleTypeOption> vehicleTypes = <StoreVehicleTypeOption>[];
  List<StoreVehicleBrandOption> vehicleBrands = <StoreVehicleBrandOption>[];
  List<StoreVehicleModelOption> vehicleModels = <StoreVehicleModelOption>[];
  List<StoreVehicleAdPlanOption> vehiclePlans = <StoreVehicleAdPlanOption>[];

  StoreVehicleTypeOption? selectedVehicleType;
  StoreVehicleBrandOption? selectedVehicleBrand;
  StoreVehicleModelOption? selectedVehicleModel;

  String selectedCondition = 'store_condition_used';
  String selectedOnlyOwner = 'no';
  String selectedPlan = '';
  int availableAdCredits = 0;
  bool hasUnlimitedAdPlan = false;
  String unlimitedAdPlanExpiresAt = '';
  final Map<String, XFile> selectedPhotos = <String, XFile>{};

  String get editingVehicleId => cleanInitialValue('id');
  bool get isEditingVehicle => editingVehicleId.isNotEmpty;

  String cleanInitialValue(String key) {
    final dynamic value = widget.initialVehicle?[key];

    if (value == null) {
      return '';
    }

    final String text = value.toString().trim();

    return text == 'null' ? '' : text;
  }

  bool parseInitialBool(String key) {
    final dynamic value = widget.initialVehicle?[key];

    if (value is bool) {
      return value;
    }

    final String text = value?.toString().trim().toLowerCase() ?? '';

    return text == '1' || text == 'true' || text == 'sim' || text == 'yes';
  }

  @override
  void initState() {
    super.initState();
    applyInitialVehicleData();
    loadVehicleTypes();
    loadVehiclePlans();
  }

  void applyInitialVehicleData() {
    if (widget.initialVehicle == null) {
      return;
    }

    plateController.text = cleanInitialValue('plate').toUpperCase();
    yearController.text = cleanInitialValue('year');
    versionController.text = cleanInitialValue('version');
    mileageController.text = cleanInitialValue('mileage');
    colorController.text = cleanInitialValue('color');
    fuelController.text = cleanInitialValue('fuel_type');
    doorsController.text = cleanInitialValue('doors');
    steeringController.text = cleanInitialValue('steering');
    transmissionController.text = cleanInitialValue('transmission');
    tractionController.text = cleanInitialValue('traction_control');
    engineController.text = cleanInitialValue('engine');
    bodyTypeController.text = cleanInitialValue('body_type');
    descriptionController.text = cleanInitialValue('description');
    priceController.text = cleanInitialValue('price');
    stateController.text = cleanInitialValue('state');
    cityController.text = cleanInitialValue('city');
    brandController.text = cleanInitialValue('brand_name');
    modelController.text = cleanInitialValue('model_name');
    selectedCondition = cleanInitialValue('condition_type') == 'new'
        ? 'store_condition_new'
        : 'store_condition_used';
    selectedOnlyOwner = parseInitialBool('single_owner') ? 'yes' : 'no';

    final String planSlug = cleanInitialValue('plan_slug');
    if (planSlug.isNotEmpty) {
      selectedPlan = planSlug;
    }
  }

  @override
  void dispose() {
    plateController.dispose();
    brandController.dispose();
    modelController.dispose();
    yearController.dispose();
    versionController.dispose();
    mileageController.dispose();
    colorController.dispose();
    fuelController.dispose();
    doorsController.dispose();
    steeringController.dispose();
    transmissionController.dispose();
    tractionController.dispose();
    engineController.dispose();
    bodyTypeController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    stateController.dispose();
    cityController.dispose();
    super.dispose();
  }

  String get selectedVehicleTypeLabel {
    if (selectedVehicleType != null) {
      return selectedVehicleType!.name;
    }

    return isLoadingVehicleTypes
        ? 'store_loading_vehicle_types'.tr
        : 'store_select_vehicle_type'.tr;
  }

  String get selectedVehicleBrandLabel {
    if (selectedVehicleBrand != null) {
      return selectedVehicleBrand!.name;
    }

    return isLoadingVehicleBrands
        ? 'store_loading_vehicle_brands'.tr
        : 'store_select_vehicle_brand'.tr;
  }

  String get selectedVehicleModelLabel {
    if (selectedVehicleModel != null) {
      return selectedVehicleModel!.name;
    }

    return isLoadingVehicleModels
        ? 'store_loading_vehicle_models'.tr
        : 'store_select_vehicle_model'.tr;
  }

  StoreVehicleTypeOption? findVehicleTypeById(String id) {
    for (final StoreVehicleTypeOption item in vehicleTypes) {
      if (item.id == id) {
        return item;
      }
    }

    return null;
  }

  StoreVehicleBrandOption? findVehicleBrandById(String id) {
    for (final StoreVehicleBrandOption item in vehicleBrands) {
      if (item.id == id) {
        return item;
      }
    }

    return null;
  }

  StoreVehicleModelOption? findVehicleModelById(String id) {
    for (final StoreVehicleModelOption item in vehicleModels) {
      if (item.id == id) {
        return item;
      }
    }

    return null;
  }

  Future<void> loadVehicleTypes() async {
    if (isLoadingVehicleTypes) {
      return;
    }

    setState(() {
      isLoadingVehicleTypes = true;
    });

    final Response response =
        await Get.find<ApiClient>().getData(vehicleTypesUri);

    if (!mounted) {
      return;
    }

    final dynamic body = response.body;
    final List<dynamic> data = body is Map && body['data'] is List
        ? body['data'] as List
        : <dynamic>[];

    final List<StoreVehicleTypeOption> parsed = data
        .whereType<Map>()
        .map(StoreVehicleTypeOption.fromMap)
        .where((item) => item.id.isNotEmpty)
        .toList();

    setState(() {
      vehicleTypes = parsed;
      isLoadingVehicleTypes = false;

      final StoreVehicleTypeOption? initialType =
          findVehicleTypeById(cleanInitialValue('vehicle_type_id'));

      if (initialType != null) {
        selectedVehicleType = initialType;
      } else if (selectedVehicleType == null && vehicleTypes.isNotEmpty) {
        selectedVehicleType = vehicleTypes.first;
      }
    });

    if (selectedVehicleType != null) {
      await loadVehicleBrands(selectedVehicleType!.id);
    }
  }

  Future<void> loadVehicleBrands(String vehicleTypeId) async {
    if (vehicleTypeId.trim().isEmpty) {
      return;
    }

    setState(() {
      isLoadingVehicleBrands = true;
      vehicleBrands = <StoreVehicleBrandOption>[];
      vehicleModels = <StoreVehicleModelOption>[];
      selectedVehicleBrand = null;
      selectedVehicleModel = null;
      brandController.clear();
      modelController.clear();
    });

    final Response response =
        await Get.find<ApiClient>().getData(vehicleBrandsUri(vehicleTypeId));

    if (!mounted) {
      return;
    }

    final dynamic body = response.body;
    final List<dynamic> data = body is Map && body['data'] is List
        ? body['data'] as List
        : <dynamic>[];

    final List<StoreVehicleBrandOption> parsed = data
        .whereType<Map>()
        .map(StoreVehicleBrandOption.fromMap)
        .where((item) => item.id.isNotEmpty)
        .toList();

    setState(() {
      vehicleBrands = parsed;
      isLoadingVehicleBrands = false;

      final StoreVehicleBrandOption? initialBrand =
          findVehicleBrandById(cleanInitialValue('brand_id'));

      if (initialBrand != null) {
        selectedVehicleBrand = initialBrand;
        brandController.text = initialBrand.name;
      }
    });

    if (selectedVehicleBrand != null) {
      await loadVehicleModels(selectedVehicleBrand!.id);
    }
  }

  Future<void> loadVehicleModels(String brandId) async {
    if (brandId.trim().isEmpty) {
      return;
    }

    setState(() {
      isLoadingVehicleModels = true;
      vehicleModels = <StoreVehicleModelOption>[];
      selectedVehicleModel = null;
      modelController.clear();
    });

    final Response response =
        await Get.find<ApiClient>().getData(vehicleModelsUri(brandId));

    if (!mounted) {
      return;
    }

    final dynamic body = response.body;
    final List<dynamic> data = body is Map && body['data'] is List
        ? body['data'] as List
        : <dynamic>[];

    final List<StoreVehicleModelOption> parsed = data
        .whereType<Map>()
        .map(StoreVehicleModelOption.fromMap)
        .where((item) => item.id.isNotEmpty)
        .toList();

    setState(() {
      vehicleModels = parsed;
      isLoadingVehicleModels = false;

      final StoreVehicleModelOption? initialModel =
          findVehicleModelById(cleanInitialValue('model_id'));

      if (initialModel != null) {
        selectedVehicleModel = initialModel;
        modelController.text = initialModel.name;
      }
    });
  }

  Future<void> loadVehiclePlans() async {
    if (isLoadingVehiclePlans) {
      return;
    }

    setState(() {
      isLoadingVehiclePlans = true;
    });

    final Response response =
        await Get.find<ApiClient>().getData(vehiclePlansUri);

    if (!mounted) {
      return;
    }

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
          data['vehicle_ad_plans'] ??
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

    final List<StoreVehicleAdPlanOption> parsed = planRows
        .whereType<Map>()
        .map(StoreVehicleAdPlanOption.fromMap)
        .where((item) => item.id.isNotEmpty)
        .toList();

    setState(() {
      vehiclePlans = parsed;
      availableAdCredits = parsedAvailableCredits;
      hasUnlimitedAdPlan = parsedUnlimitedActive;
      unlimitedAdPlanExpiresAt = parsedUnlimitedExpiresAt;
      isLoadingVehiclePlans = false;

      if (selectedPlan.isNotEmpty &&
          !vehiclePlans.any((plan) => plan.slug == selectedPlan)) {
        selectedPlan = '';
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

  void showSelectionSheet({
    required String title,
    required List<String> options,
    required ValueChanged<String> onSelected,
    String? selectedValue,
    bool allowSearch = false,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    String query = '';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final List<String> filteredOptions = query.trim().isEmpty
                ? options
                : options
                    .where(
                      (item) => item
                          .toLowerCase()
                          .contains(query.trim().toLowerCase()),
                    )
                    .toList();

            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalContext).size.height * 0.78,
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
                          onTap: () => Navigator.of(modalContext).pop(),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.grey.shade700,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    if (allowSearch) ...[
                      const SizedBox(height: 12),
                      Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          onChanged: (value) {
                            setModalState(() {
                              query = value;
                            });
                          },
                          style: textRegular.copyWith(
                            color: Colors.black87,
                            fontSize: 13.4,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            icon: Icon(
                              Icons.search_rounded,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            hintText: 'store_search'.tr,
                            hintStyle: textRegular.copyWith(
                              color: Colors.grey.shade500,
                              fontSize: 13.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredOptions.length,
                        separatorBuilder: (_, __) => Divider(
                          color: Colors.grey.shade200,
                          height: 1,
                        ),
                        itemBuilder: (_, index) {
                          final String option = filteredOptions[index];
                          final bool selected = option == selectedValue;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              onSelected(option);
                              Navigator.of(modalContext).pop();
                            },
                            title: Text(
                              option,
                              style: textMedium.copyWith(
                                color: Colors.black87,
                                fontSize: 13.8,
                              ),
                            ),
                            trailing: selected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: Theme.of(context).primaryColor,
                                    size: 22,
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
      },
    );
  }

  Future<void> handlePhotoTap(String label) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final String? action = await showModalBottomSheet<String>(
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
                        label,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.grey.shade700,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                StoreSellerVehiclePhotoActionTile(
                  icon: Icons.photo_camera_rounded,
                  title: 'store_take_photo'.tr,
                  onTap: () => Navigator.of(context).pop('camera'),
                ),
                const SizedBox(height: 8),
                StoreSellerVehiclePhotoActionTile(
                  icon: Icons.photo_library_rounded,
                  title: 'store_choose_from_gallery'.tr,
                  onTap: () => Navigator.of(context).pop('gallery'),
                ),
                if (selectedPhotos.containsKey(label)) ...[
                  const SizedBox(height: 8),
                  StoreSellerVehiclePhotoActionTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'store_remove_photo'.tr,
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

    if (action == null) {
      return;
    }

    if (action == 'remove') {
      setState(() {
        selectedPhotos.remove(label);
      });
      return;
    }

    final ImageSource source =
        action == 'camera' ? ImageSource.camera : ImageSource.gallery;

    final XFile? image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      selectedPhotos[label] = image;
    });
  }

  String normalizeVehicleNumberInput(String value) {
    String normalized = value.trim();

    if (normalized.contains(',')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }

    return normalized;
  }

  StoreVehicleAdPlanOption? get selectedVehiclePlan {
    if (vehiclePlans.isEmpty || selectedPlan.trim().isEmpty) {
      return null;
    }

    for (final StoreVehicleAdPlanOption plan in vehiclePlans) {
      if (plan.slug == selectedPlan) {
        return plan;
      }
    }

    return null;
  }

  bool get hasCreditsToPublishVehicleAd {
    return hasUnlimitedAdPlan || availableAdCredits > 0;
  }

  bool get mustChooseVehicleAdPlan {
    return !isEditingVehicle && !hasCreditsToPublishVehicleAd;
  }

  Future<void> showVehiclePlanSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (isLoadingVehiclePlans) {
      showStoreMessage('store_loading_listing_plans_wait'.tr);
      return;
    }

    if (vehiclePlans.isEmpty) {
      showStoreMessage('store_listing_plans_load_error'.tr);
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
                        'store_choose_vehicle_ad_payment'.tr,
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
                  'store_vehicle_ad_credit_explanation'.tr,
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
                    itemCount: vehiclePlans.length,
                    itemBuilder: (_, index) {
                      final StoreVehicleAdPlanOption plan = vehiclePlans[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: StoreSellerVehiclePlanOption(
                          primaryColor: Theme.of(context).primaryColor,
                          selected: selectedPlan == plan.slug,
                          title: plan.name,
                          price: plan.formattedPrice,
                          description: plan.fullDescription,
                          onTap: () {
                            setState(() {
                              selectedPlan = plan.slug;
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
    if (isSubmittingVehicleAd) {
      return;
    }

    if (!formKey.currentState!.validate()) {
      return;
    }

    if (selectedVehicleType == null) {
      showStoreMessage('store_select_vehicle_type_required'.tr);
      return;
    }

    if (selectedVehicleBrand == null) {
      showStoreMessage('store_select_vehicle_brand_required'.tr);
      return;
    }

    if (selectedVehicleModel == null) {
      showStoreMessage('store_select_vehicle_model_required'.tr);
      return;
    }

    final List<String> missingPhotos = photoLabels
        .where((String label) => !selectedPhotos.containsKey(label))
        .toList();

    if (!isEditingVehicle && missingPhotos.isNotEmpty) {
      showStoreMessage(
        'store_required_vehicle_photos_missing'.trParams({
          'photos': missingPhotos.map((label) => label.tr).join(', '),
        }),
      );
      return;
    }

    final StoreVehicleAdPlanOption? plan = selectedVehiclePlan;

    if (mustChooseVehicleAdPlan && (plan == null || plan.id.trim().isEmpty)) {
      showStoreMessage('store_choose_credit_plan_to_publish'.tr);
      await showVehiclePlanSheet();
      return;
    }

    final Map<String, String> body = <String, String>{
      'vehicle_type_id': selectedVehicleType!.id,
      'brand_id': selectedVehicleBrand!.id,
      'model_id': selectedVehicleModel!.id,
      if (mustChooseVehicleAdPlan && plan != null) 'plan_id': plan.id,
      if (mustChooseVehicleAdPlan && plan != null) 'ad_plan_id': plan.id,
      if (mustChooseVehicleAdPlan && plan != null)
        'marketplace_ad_plan_id': plan.id,
      'plate': plateController.text.trim().toUpperCase(),
      'title': buildVehicleAdTitle(),
      'year': yearController.text.trim(),
      'version': versionController.text.trim(),
      'mileage': normalizeOnlyNumbers(mileageController.text),
      'color': colorController.text.trim(),
      'fuel_type': fuelController.text.trim(),
      'doors': normalizeOnlyNumbers(doorsController.text),
      'condition_type':
          selectedCondition == 'store_condition_new' ? 'new' : 'used',
      'steering': steeringController.text.trim(),
      'transmission': transmissionController.text.trim(),
      'traction_control': tractionController.text.trim(),
      'engine': engineController.text.trim(),
      'body_type': bodyTypeController.text.trim(),
      'single_owner': selectedOnlyOwner == 'yes' ? '1' : '0',
      'description': descriptionController.text.trim(),
      'price': normalizeVehicleNumberInput(priceController.text),
      'state': stateController.text.trim().toUpperCase(),
      'city': cityController.text.trim(),
    };

    body.removeWhere((_, String value) => value.trim().isEmpty);

    final XFile? coverPhoto = selectedPhotos[coverPhotoKey];
    final List<MultipartBody> additionalPhotos = <MultipartBody>[];

    for (final String label in photoLabels) {
      if (label == coverPhotoKey) {
        continue;
      }

      final XFile? photo = selectedPhotos[label];

      if (photo != null) {
        additionalPhotos.add(MultipartBody('images[]', photo));
      }
    }

    setState(() {
      isSubmittingVehicleAd = true;
    });

    try {
      final Response response = isEditingVehicle
          ? await Get.find<ApiClient>().postData(
              vehicleUpdateUri(editingVehicleId),
              body,
            )
          : await Get.find<ApiClient>().postMultipartData(
              vehicleStoreUri,
              body,
              MultipartBody('images[]', coverPhoto!),
              additionalPhotos,
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
                  ? isEditingVehicle
                      ? 'store_vehicle_ad_updated_sent_approval'.tr
                      : 'store_vehicle_ad_created_sent_approval'.tr
                  : isEditingVehicle
                      ? 'store_vehicle_ad_update_error'.tr
                      : 'store_vehicle_ad_create_error'.tr;

      showStoreMessage(message);

      if (success) {
        await Future<void>.delayed(const Duration(milliseconds: 850));

        if (mounted) {
          Get.back(result: true);
        }
      }
    } catch (_) {
      if (mounted) {
        showStoreMessage('store_listing_submit_try_again_error'.tr);
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmittingVehicleAd = false;
        });
      }
    }
  }

  String normalizeOnlyNumbers(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String buildVehicleAdTitle() {
    final List<String> parts = <String>[
      selectedVehicleBrand?.name ?? '',
      selectedVehicleModel?.name ?? '',
      versionController.text.trim(),
      yearController.text.trim(),
    ];

    return parts.where((String item) => item.trim().isNotEmpty).join(' ');
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

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          StoreSellerVehicleTopBar(
            primaryColor: primaryColor,
            title: isEditingVehicle
                ? 'store_edit_vehicle'.tr
                : 'store_register_vehicle'.tr,
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
                    StoreSellerVehicleSection(
                      title: 'store_main_data'.tr,
                      children: [
                        StoreSellerVehicleTextInput(
                          label: 'store_license_plate'.tr,
                          hint: 'ABC1D23',
                          controller: plateController,
                          textCapitalization: TextCapitalization.characters,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'store_license_plate_required'.tr;
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        StoreSellerVehicleSelectField(
                          label: 'store_vehicle_type'.tr,
                          value: selectedVehicleTypeLabel,
                          primaryColor: primaryColor,
                          isLoading: isLoadingVehicleTypes,
                          onTap: () {
                            if (vehicleTypes.isEmpty) {
                              showStoreMessage(
                                  'store_no_vehicle_type_available'.tr);
                              return;
                            }

                            showSelectionSheet(
                              title: 'store_vehicle_type'.tr,
                              options: vehicleTypes
                                  .map((item) => item.name)
                                  .toList(),
                              selectedValue: selectedVehicleType?.name,
                              onSelected: (value) {
                                final StoreVehicleTypeOption type =
                                    vehicleTypes.firstWhere(
                                  (item) => item.name == value,
                                );

                                setState(() {
                                  selectedVehicleType = type;
                                });

                                loadVehicleBrands(type.id);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        StoreSellerVehicleSelectField(
                          label: 'store_brand'.tr,
                          value: selectedVehicleBrandLabel,
                          primaryColor: primaryColor,
                          isLoading: isLoadingVehicleBrands,
                          onTap: () {
                            if (selectedVehicleType == null) {
                              showStoreMessage(
                                  'store_select_vehicle_type_first'.tr);
                              return;
                            }

                            if (vehicleBrands.isEmpty) {
                              showStoreMessage(
                                  'store_no_brand_available_for_type'.tr);
                              return;
                            }

                            showSelectionSheet(
                              title: 'store_brand'.tr,
                              options: vehicleBrands
                                  .map((item) => item.name)
                                  .toList(),
                              selectedValue: selectedVehicleBrand?.name,
                              allowSearch: true,
                              onSelected: (value) {
                                final StoreVehicleBrandOption brand =
                                    vehicleBrands.firstWhere(
                                  (item) => item.name == value,
                                );

                                setState(() {
                                  selectedVehicleBrand = brand;
                                  brandController.text = brand.name;
                                });

                                loadVehicleModels(brand.id);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        StoreSellerVehicleSelectField(
                          label: 'store_model'.tr,
                          value: selectedVehicleModelLabel,
                          primaryColor: primaryColor,
                          isLoading: isLoadingVehicleModels,
                          onTap: () {
                            if (selectedVehicleBrand == null) {
                              showStoreMessage(
                                  'store_select_vehicle_brand_first'.tr);
                              return;
                            }

                            if (vehicleModels.isEmpty) {
                              showStoreMessage(
                                  'store_no_model_available_for_brand'.tr);
                              return;
                            }

                            showSelectionSheet(
                              title: 'store_model'.tr,
                              options: vehicleModels
                                  .map((item) => item.name)
                                  .toList(),
                              selectedValue: selectedVehicleModel?.name,
                              allowSearch: true,
                              onSelected: (value) {
                                final StoreVehicleModelOption model =
                                    vehicleModels.firstWhere(
                                  (item) => item.name == value,
                                );

                                setState(() {
                                  selectedVehicleModel = model;
                                  modelController.text = model.name;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StoreSellerVehicleTextInput(
                                label: 'store_year'.tr,
                                hint: '2024',
                                controller: yearController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StoreSellerVehicleTextInput(
                                label: 'store_mileage'.tr,
                                hint: '28.000',
                                controller: mileageController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        StoreSellerVehicleTextInput(
                          label: 'store_version'.tr,
                          hint: 'store_vehicle_version_hint'.tr,
                          controller: versionController,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    StoreSellerVehicleSection(
                      title: 'store_vehicle_photos'.tr,
                      children: [
                        Text(
                          'store_vehicle_photos_required_note'.tr,
                          style: textRegular.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 12.5,
                            height: 1.32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StoreSellerVehiclePhotoGrid(
                          primaryColor: primaryColor,
                          labels: photoLabels,
                          selectedPhotos: selectedPhotos,
                          onPhotoTap: handlePhotoTap,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    StoreSellerVehicleSection(
                      title: 'store_more_information'.tr,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: StoreSellerVehicleTextInput(
                                label: 'store_color'.tr,
                                hint: 'store_black_hint'.tr,
                                controller: colorController,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StoreSellerVehicleTextInput(
                                label: 'store_fuel'.tr,
                                hint: 'Flex',
                                controller: fuelController,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StoreSellerVehicleTextInput(
                                label: 'store_doors'.tr,
                                hint: '4',
                                controller: doorsController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StoreSellerVehicleSegmentedField(
                                label: 'store_condition'.tr,
                                options: const [
                                  'store_condition_new',
                                  'store_condition_used'
                                ],
                                selectedValue: selectedCondition,
                                primaryColor: primaryColor,
                                onChanged: (value) {
                                  setState(() {
                                    selectedCondition = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StoreSellerVehicleTextInput(
                                label: 'store_steering'.tr,
                                hint: 'store_electric_hint'.tr,
                                controller: steeringController,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StoreSellerVehicleTextInput(
                                label: 'store_transmission'.tr,
                                hint: 'store_automatic_hint'.tr,
                                controller: transmissionController,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StoreSellerVehicleTextInput(
                                label: 'store_traction_control'.tr,
                                hint: 'yes'.tr,
                                controller: tractionController,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StoreSellerVehicleTextInput(
                                label: 'store_engine'.tr,
                                hint: '1.0 Turbo',
                                controller: engineController,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        StoreSellerVehicleTextInput(
                          label: 'store_body_type'.tr,
                          hint: 'store_body_type_hint'.tr,
                          controller: bodyTypeController,
                        ),
                        const SizedBox(height: 12),
                        StoreSellerVehicleSegmentedField(
                          label: 'store_single_owner'.tr,
                          options: const ['yes', 'no'],
                          selectedValue: selectedOnlyOwner,
                          primaryColor: primaryColor,
                          onChanged: (value) {
                            setState(() {
                              selectedOnlyOwner = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        StoreSellerVehicleTextInput(
                          label: 'store_main_details'.tr,
                          hint: 'store_vehicle_main_details_hint'.tr,
                          controller: descriptionController,
                          maxLines: 5,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    StoreSellerVehicleSection(
                      title: 'store_price_and_location'.tr,
                      children: [
                        StoreSellerVehicleTextInput(
                          label: 'store_price'.tr,
                          hint: '89.900,00',
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [
                            BrazilianCurrencyInputFormatter(),
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'store_price_required'.tr;
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StoreSellerVehicleTextInput(
                                label: 'store_state'.tr,
                                hint: 'MG',
                                controller: stateController,
                                textCapitalization:
                                    TextCapitalization.characters,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StoreSellerVehicleTextInput(
                                label: 'store_city'.tr,
                                hint: 'Três Corações',
                                controller: cityController,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    StoreSellerVehiclePricingCard(
                      primaryColor: primaryColor,
                      isLoading: isLoadingVehiclePlans,
                      isEditingVehicle: isEditingVehicle,
                      availableCredits: availableAdCredits,
                      hasUnlimitedPlan: hasUnlimitedAdPlan,
                      unlimitedPlanExpiresAt: unlimitedAdPlanExpiresAt,
                      selectedPlan: selectedVehiclePlan,
                      onChoosePlanTap: showVehiclePlanSheet,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSubmittingVehicleAd ? null : handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: isSubmittingVehicleAd
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                isEditingVehicle
                                    ? 'store_resend_for_review'.tr
                                    : 'store_send_listing_for_review'.tr,
                                style: textBold.copyWith(
                                  color: Colors.white,
                                  fontSize: 14.8,
                                ),
                              ),
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

class BrazilianCurrencyInputFormatter extends TextInputFormatter {
  const BrazilianCurrencyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final int cents = int.tryParse(digits) ?? 0;
    final int reais = cents ~/ 100;
    final int centavos = cents % 100;
    final String reaisFormatted = _formatThousands(reais);
    final String formatted =
        '$reaisFormatted,${centavos.toString().padLeft(2, '0')}';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatThousands(int value) {
    final String raw = value.toString();
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < raw.length; i++) {
      final int remaining = raw.length - i;
      buffer.write(raw[i]);

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }

    return buffer.toString();
  }
}

class StoreSellerVehicleTopBar extends StatelessWidget {
  final Color primaryColor;
  final String title;
  final VoidCallback onBackTap;

  const StoreSellerVehicleTopBar({
    super.key,
    required this.primaryColor,
    required this.title,
    required this.onBackTap,
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
            onTap: onBackTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: textBold.copyWith(
                color: Colors.white,
                fontSize: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerVehiclePricingCard extends StatelessWidget {
  final Color primaryColor;
  final bool isLoading;
  final bool isEditingVehicle;
  final int availableCredits;
  final bool hasUnlimitedPlan;
  final String unlimitedPlanExpiresAt;
  final StoreVehicleAdPlanOption? selectedPlan;
  final VoidCallback onChoosePlanTap;

  const StoreSellerVehiclePricingCard({
    super.key,
    required this.primaryColor,
    required this.isLoading,
    required this.isEditingVehicle,
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
        !isEditingVehicle && !hasUnlimitedPlan && !hasCredits;
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

    return StoreSellerVehicleCardBase(
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
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        const Icon(
                          Icons.payments_outlined,
                          color: Colors.white,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                      ],
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
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'store_listing_plans_current_note'.tr,
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 11.6,
              height: 1.30,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerVehiclePlanOption extends StatelessWidget {
  final Color primaryColor;
  final bool selected;
  final String title;
  final String price;
  final String description;
  final VoidCallback onTap;

  const StoreSellerVehiclePlanOption({
    super.key,
    required this.primaryColor,
    required this.selected,
    required this.title,
    required this.price,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? primaryColor.withValues(alpha: 0.08)
          : const Color(0xFFF8F9F9),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? primaryColor : Colors.grey.shade200,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? primaryColor : Colors.grey.shade500,
                size: 22,
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
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11.8,
                        height: 1.22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                price,
                textAlign: TextAlign.right,
                style: textBold.copyWith(
                  color: primaryColor,
                  fontSize: 13.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreSellerVehicleCardBase extends StatelessWidget {
  final Widget child;

  const StoreSellerVehicleCardBase({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      child: child,
    );
  }
}

class StoreSellerVehicleSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const StoreSellerVehicleSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
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
              color: Theme.of(context).primaryColor.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          ...children,
          const SizedBox(height: 18),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.shade200,
          ),
        ],
      ),
    );
  }
}

class StoreSellerVehicleTextInput extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  const StoreSellerVehicleTextInput({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.sentences,
    this.validator,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(17);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 12.6,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          validator: validator,
          style: textMedium.copyWith(
            color: Colors.black87,
            fontSize: 13.4,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: textRegular.copyWith(
              color: Colors.grey.shade500,
              fontSize: 13.2,
            ),
            filled: true,
            fillColor: const Color(0xFFF7F8F8),
            contentPadding: EdgeInsets.fromLTRB(
              14,
              maxLines > 1 ? 14 : 0,
              14,
              maxLines > 1 ? 14 : 0,
            ),
            constraints: maxLines == 1
                ? const BoxConstraints(minHeight: 50, maxHeight: 50)
                : null,
            border: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 1.4,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ),
      ],
    );
  }
}

class StoreSellerVehicleSelectField extends StatelessWidget {
  final String label;
  final String value;
  final Color primaryColor;
  final bool isLoading;
  final VoidCallback onTap;

  const StoreSellerVehicleSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.primaryColor,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String normalizedValue = value.trim().toLowerCase();
    final bool hasValue = normalizedValue.isNotEmpty &&
        !normalizedValue.startsWith('selecionar') &&
        !normalizedValue.startsWith('select') &&
        !normalizedValue.startsWith('seleccionar') &&
        !normalizedValue.startsWith('carregando') &&
        !normalizedValue.startsWith('loading') &&
        !normalizedValue.startsWith('cargando');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 12.6,
          ),
        ),
        const SizedBox(height: 7),
        Material(
          color: const Color(0xFFF7F8F8),
          borderRadius: BorderRadius.circular(17),
          child: InkWell(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              onTap();
            },
            borderRadius: BorderRadius.circular(17),
            child: Container(
              height: 50,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: primaryColor,
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textMedium.copyWith(
                        color: hasValue ? Colors.black87 : Colors.grey.shade500,
                        fontSize: 13.4,
                      ),
                    ),
                  ),
                  if (isLoading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryColor,
                      ),
                    )
                  else
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey.shade700,
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class StoreSellerVehicleSegmentedField extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selectedValue;
  final Color primaryColor;
  final ValueChanged<String> onChanged;

  const StoreSellerVehicleSegmentedField({
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
        Text(
          label,
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 12.6,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8F8),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: options.map((option) {
              final bool selected = option == selectedValue;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      option.tr,
                      style: textBold.copyWith(
                        color: selected ? Colors.white : Colors.grey.shade700,
                        fontSize: 12.4,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class StoreSellerVehiclePhotoGrid extends StatelessWidget {
  final Color primaryColor;
  final List<String> labels;
  final Map<String, XFile> selectedPhotos;
  final ValueChanged<String> onPhotoTap;

  const StoreSellerVehiclePhotoGrid({
    super.key,
    required this.primaryColor,
    required this.labels,
    required this.selectedPhotos,
    required this.onPhotoTap,
  });

  IconData iconForLabel(String label) {
    final String normalized = label.toLowerCase();

    if (normalized.contains('cover') || normalized.contains('capa')) {
      return Icons.directions_car_filled_outlined;
    }

    if (normalized.contains('front') || normalized.contains('frente')) {
      return Icons.car_repair_rounded;
    }

    if (normalized.contains('rear') || normalized.contains('traseira')) {
      return Icons.directions_car_rounded;
    }

    if (normalized.contains('left') ||
        normalized.contains('right') ||
        normalized.contains('esquerdo') ||
        normalized.contains('direito')) {
      return Icons.car_rental_rounded;
    }

    if (normalized.contains('interior') ||
        normalized.contains('seats') ||
        normalized.contains('bancos')) {
      return Icons.airline_seat_recline_normal_rounded;
    }

    if (normalized.contains('engine') || normalized.contains('motor')) {
      return Icons.settings_rounded;
    }

    if (normalized.contains('mileage') ||
        normalized.contains('quilometragem')) {
      return Icons.speed_rounded;
    }

    if (normalized.contains('details') || normalized.contains('detalhes')) {
      return Icons.manage_search_rounded;
    }

    return Icons.directions_car_outlined;
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
        mainAxisExtent: 112,
      ),
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
                  width: selected ? 1.3 : 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image != null)
                    Image.file(
                      File(image.path),
                      fit: BoxFit.cover,
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          iconForLabel(label),
                          color: Colors.grey.shade500,
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Text(
                            label.tr,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: textMedium.copyWith(
                              color: Colors.grey.shade700,
                              fontSize: 11.2,
                              height: 1.12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (image != null) ...[
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0),
                              Colors.black.withValues(alpha: 0.58),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 7,
                      child: Text(
                        label.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 10.8,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
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

class StoreSellerVehiclePhotoActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool destructive;
  final VoidCallback onTap;

  const StoreSellerVehiclePhotoActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.destructive = false,
    required this.onTap,
  });

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
          child: Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: textBold.copyWith(
                    color: color,
                    fontSize: 13.4,
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

class StoreVehicleTypeOption {
  final String id;
  final String name;
  final String slug;

  const StoreVehicleTypeOption({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory StoreVehicleTypeOption.fromMap(Map<dynamic, dynamic> map) {
    return StoreVehicleTypeOption(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      slug: '${map['slug'] ?? ''}',
    );
  }
}

class StoreVehicleBrandOption {
  final String id;
  final String vehicleTypeId;
  final String name;
  final String slug;

  const StoreVehicleBrandOption({
    required this.id,
    required this.vehicleTypeId,
    required this.name,
    required this.slug,
  });

  factory StoreVehicleBrandOption.fromMap(Map<dynamic, dynamic> map) {
    return StoreVehicleBrandOption(
      id: '${map['id'] ?? ''}',
      vehicleTypeId: '${map['vehicle_type_id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      slug: '${map['slug'] ?? ''}',
    );
  }
}

class StoreVehicleModelOption {
  final String id;
  final String vehicleTypeId;
  final String brandId;
  final String name;
  final String slug;

  const StoreVehicleModelOption({
    required this.id,
    required this.vehicleTypeId,
    required this.brandId,
    required this.name,
    required this.slug,
  });

  factory StoreVehicleModelOption.fromMap(Map<dynamic, dynamic> map) {
    return StoreVehicleModelOption(
      id: '${map['id'] ?? ''}',
      vehicleTypeId: '${map['vehicle_type_id'] ?? ''}',
      brandId: '${map['brand_id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      slug: '${map['slug'] ?? ''}',
    );
  }
}

class StoreVehicleAdPlanOption {
  final String id;
  final String name;
  final String slug;
  final double price;
  final int credits;
  final int billingCycleDays;
  final int adDurationDays;
  final String description;
  final bool unlimited;

  const StoreVehicleAdPlanOption({
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

    if (billingCycleDays >= 170) {
      return 'R\$$value ${'store_semiannual'.tr}';
    }

    if (billingCycleDays >= 360) {
      return 'R\$$value ${'store_yearly'.tr}';
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

  factory StoreVehicleAdPlanOption.fromMap(Map<dynamic, dynamic> map) {
    final String rawName = '${map['name'] ?? ''}'.trim();
    final String rawSlug = '${map['slug'] ?? ''}'.trim();
    final int adLimit = parseIntValue(
      map['ad_limit'] ??
          map['credits'] ??
          map['credit_amount'] ??
          map['vehicle_limit'] ??
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

    return StoreVehicleAdPlanOption(
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
