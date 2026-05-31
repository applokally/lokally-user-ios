import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreSellerServiceFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialService;

  const StoreSellerServiceFormScreen({super.key, this.initialService});

  @override
  State<StoreSellerServiceFormScreen> createState() =>
      _StoreSellerServiceFormScreenState();
}

class _StoreSellerServiceFormScreenState
    extends State<StoreSellerServiceFormScreen> {
  static const String serviceCategoriesUri =
      '/api/customer/store/service/categories';
  static const String serviceCreateUri = '/api/customer/store/service';
  static const String serviceAdPlansUri = '/api/store/ad-plans';

  static String serviceUpdateUri(String id) =>
      '/api/customer/store/service/$id/update';

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController skuController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController oldPriceController = TextEditingController();
  final TextEditingController costPriceController = TextEditingController();
  final TextEditingController shortDescriptionController =
      TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController includedController = TextEditingController();
  final TextEditingController excludedController = TextEditingController();
  final TextEditingController requirementsController = TextEditingController();
  final TextEditingController deadlineController = TextEditingController();
  final TextEditingController executionTimeController = TextEditingController();
  final TextEditingController attendanceLocationController =
      TextEditingController();
  final TextEditingController serviceAreaController = TextEditingController();
  final TextEditingController instructionsController = TextEditingController();
  final TextEditingController deliverableController = TextEditingController();
  final TextEditingController categoryRequestNameController =
      TextEditingController();
  final TextEditingController categoryRequestDescriptionController =
      TextEditingController();

  bool isLoadingCategories = false;
  bool isLoadingAdPlans = false;
  bool isSubmitting = false;
  bool needsScheduling = false;
  bool acceptedTerms = false;
  bool requestNewCategory = false;

  static const int maxServiceImages = 5;
  static const int maxServiceImageBytes = 15 * 1024 * 1024;

  String selectedFormat = 'digital';
  String selectedDeliveryType = 'online';
  String selectedAdPlanSlug = '';
  int availableAdCredits = 0;
  bool hasUnlimitedAdPlan = false;
  String unlimitedAdPlanExpiresAt = '';
  String? editingCategoryId;
  StoreServiceCategoryOption? selectedCategory;
  List<XFile> selectedImages = <XFile>[];
  List<String> existingImageUrls = <String>[];
  List<StoreServiceCategoryOption> categories = [];
  List<StoreServiceAdPlanOption> serviceAdPlans = <StoreServiceAdPlanOption>[];

  bool get hasServiceImages =>
      selectedImages.isNotEmpty || existingImageUrls.isNotEmpty;
  int get serviceImagesCount =>
      selectedImages.length + existingImageUrls.length;

  bool get isEditMode =>
      '${widget.initialService?['id'] ?? ''}'.trim().isNotEmpty;
  String get editingServiceId => '${widget.initialService?['id'] ?? ''}'.trim();

  @override
  void initState() {
    super.initState();
    applyInitialService();
    loadCategories();
    loadAdPlans();
  }

  @override
  void dispose() {
    titleController.dispose();
    skuController.dispose();
    priceController.dispose();
    oldPriceController.dispose();
    costPriceController.dispose();
    shortDescriptionController.dispose();
    descriptionController.dispose();
    includedController.dispose();
    excludedController.dispose();
    requirementsController.dispose();
    deadlineController.dispose();
    executionTimeController.dispose();
    attendanceLocationController.dispose();
    serviceAreaController.dispose();
    instructionsController.dispose();
    deliverableController.dispose();
    categoryRequestNameController.dispose();
    categoryRequestDescriptionController.dispose();
    super.dispose();
  }

  void applyInitialService() {
    final Map<String, dynamic>? service = widget.initialService;
    if (service == null) return;

    titleController.text = '${service['name'] ?? ''}'.trim();
    skuController.text = '${service['sku'] ?? ''}'.trim();
    priceController.text = formatMoneyForInput(service['price']);
    oldPriceController.text = formatMoneyForInput(
        service['old_price'] ?? service['promotional_price']);
    costPriceController.text = formatMoneyForInput(service['cost_price']);
    shortDescriptionController.text =
        '${service['short_description'] ?? ''}'.trim();
    descriptionController.text = '${service['description'] ?? ''}'.trim();
    includedController.text = '${service['included_items'] ?? ''}'.trim();
    excludedController.text = '${service['excluded_items'] ?? ''}'.trim();
    requirementsController.text =
        '${service['customer_requirements'] ?? ''}'.trim();
    deadlineController.text = '${service['estimated_deadline'] ?? ''}'.trim();
    executionTimeController.text = '${service['execution_time'] ?? ''}'.trim();
    attendanceLocationController.text =
        '${service['attendance_location'] ?? ''}'.trim();
    serviceAreaController.text = '${service['service_area'] ?? ''}'.trim();
    instructionsController.text =
        '${service['instructions_after_payment'] ?? ''}'.trim();
    deliverableController.text =
        '${service['deliverable_description'] ?? ''}'.trim();
    categoryRequestNameController.text =
        '${service['category_request_name'] ?? ''}'.trim();
    categoryRequestDescriptionController.text =
        '${service['category_request_description'] ?? ''}'.trim();

    final String format =
        '${service['service_format'] ?? ''}'.trim().toLowerCase();
    selectedFormat = format == 'presential' ? 'presential' : 'digital';

    final String delivery =
        '${service['service_delivery_type'] ?? ''}'.trim().toLowerCase();
    selectedDeliveryType = selectedFormat == 'digital'
        ? (delivery == 'download' ? 'download' : 'online')
        : (['client_location', 'provider_location', 'region'].contains(delivery)
            ? delivery
            : 'client_location');

    needsScheduling = parseBool(service['needs_scheduling']);
    acceptedTerms = true;
    requestNewCategory = categoryRequestNameController.text.trim().isNotEmpty;
    editingCategoryId = '${service['category_id'] ?? ''}'.trim().isEmpty
        ? null
        : '${service['category_id'] ?? ''}'.trim();

    final String initialPlanSlug =
        '${service['plan_slug'] ?? service['ad_plan_slug'] ?? service['service_ad_plan_slug'] ?? service['marketplace_ad_plan_slug'] ?? ''}'
            .trim();
    if (initialPlanSlug.isNotEmpty && initialPlanSlug != 'null') {
      selectedAdPlanSlug = initialPlanSlug;
    }

    final String categoryName = '${service['category_name'] ?? ''}'.trim();
    if (editingCategoryId != null && categoryName.isNotEmpty) {
      selectedCategory = StoreServiceCategoryOption(
        id: editingCategoryId!,
        parentId: '',
        name: categoryName,
        slug: '',
        description: 'store_service_current_category_description'.tr,
        imageUrl: null,
        sortOrder: 0,
        hasChildren: false,
        selectable: true,
        isVirtual: false,
        realCategoryId: editingCategoryId,
        sourcePath: '',
      );
    }

    existingImageUrls = extractExistingServiceImageUrls(service);
  }

  List<String> extractExistingServiceImageUrls(Map<String, dynamic> service) {
    final List<String> urls = <String>[];

    void addUrl(dynamic value) {
      final String url = '$value'.trim();
      if (url.isEmpty || url == 'null' || urls.contains(url)) {
        return;
      }

      if (urls.length >= maxServiceImages) {
        return;
      }

      urls.add(url);
    }

    void addFromMap(Map<dynamic, dynamic> value) {
      addUrl(value['main_image_url']);
      addUrl(value['image_url']);
      addUrl(value['url']);
      addUrl(value['full_url']);
      addUrl(value['path']);
    }

    void addFromCollection(dynamic value) {
      if (value is List) {
        for (final dynamic item in value) {
          if (item is Map) {
            addFromMap(item);
          } else {
            addUrl(item);
          }
        }
        return;
      }

      if (value is Map) {
        final dynamic dataValue = value['data'];
        if (dataValue is List) {
          addFromCollection(dataValue);
          return;
        }

        addFromMap(value);
        return;
      }

      final String rawValue = '$value'.trim();
      if (rawValue.isEmpty || rawValue == 'null') {
        return;
      }

      if (rawValue.contains(',')) {
        for (final String item in rawValue.split(',')) {
          addUrl(item);
        }
        return;
      }

      addUrl(rawValue);
    }

    addUrl(service['main_image_url'] ?? service['image_url']);
    addFromCollection(service['images']);
    addFromCollection(service['image_urls']);
    addFromCollection(service['gallery']);
    addFromCollection(service['gallery_images']);
    addFromCollection(service['media']);

    return urls.take(maxServiceImages).toList();
  }

  Future<void> loadCategories() async {
    if (isLoadingCategories) return;

    setState(() => isLoadingCategories = true);
    final List<StoreServiceCategoryOption> parsed =
        await fetchServiceCategories();
    if (!mounted) return;

    StoreServiceCategoryOption? matched;
    if (editingCategoryId != null) {
      for (final StoreServiceCategoryOption category in parsed) {
        if (category.id == editingCategoryId ||
            category.realCategoryId == editingCategoryId) {
          matched = category;
          break;
        }
      }
    }

    setState(() {
      isLoadingCategories = false;
      categories = parsed;
      if (matched != null) selectedCategory = matched;
    });
  }

  Future<void> loadAdPlans() async {
    if (isLoadingAdPlans) {
      return;
    }

    setState(() => isLoadingAdPlans = true);

    final Response response =
        await Get.find<ApiClient>().getData(serviceAdPlansUri);

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
          data['service_ad_plans'] ??
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
            data['service_ad_credit_balance'] ??
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
                seller['service_ad_credit_balance'] ??
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

    final List<StoreServiceAdPlanOption> parsed = planRows
        .whereType<Map>()
        .map(StoreServiceAdPlanOption.fromMap)
        .where((item) => item.id.isNotEmpty)
        .toList();

    setState(() {
      serviceAdPlans = parsed;
      availableAdCredits = parsedAvailableCredits;
      hasUnlimitedAdPlan = parsedUnlimitedActive;
      unlimitedAdPlanExpiresAt = parsedUnlimitedExpiresAt;
      isLoadingAdPlans = false;

      if (selectedAdPlanSlug.isNotEmpty &&
          !serviceAdPlans.any((plan) => plan.slug == selectedAdPlanSlug)) {
        selectedAdPlanSlug = '';
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

    if (text.isEmpty || text == 'null') {
      return 0;
    }

    return int.tryParse(text.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
  }

  bool parseUnifiedBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final String text = '${value ?? ''}'.trim().toLowerCase();

    return text == '1' ||
        text == 'true' ||
        text == 'sim' ||
        text == 'yes' ||
        text == 'on';
  }

  String serviceCategoriesRequestUri({String? parentId}) {
    final Map<String, String> query = <String, String>{
      'format': selectedFormat,
      if (parentId != null && parentId.trim().isNotEmpty)
        'parent_id': parentId.trim(),
    };

    final String queryString = query.entries
        .map((entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');

    return '$serviceCategoriesUri?$queryString';
  }

  Future<List<StoreServiceCategoryOption>> fetchServiceCategories({
    String? parentId,
    bool showError = true,
  }) async {
    final Response response = await Get.find<ApiClient>()
        .getData(serviceCategoriesRequestUri(parentId: parentId));

    final dynamic body = response.body;
    if (response.statusCode != 200 || body is! Map || body['status'] != true) {
      if (showError && mounted) {
        showMessage('store_service_categories_load_error'.tr);
      }
      return <StoreServiceCategoryOption>[];
    }

    final dynamic dataValue = body['data'];
    final Map<String, dynamic> data = dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : <String, dynamic>{};
    final dynamic categoriesValue = data['categories'];
    final List<dynamic> list =
        categoriesValue is List ? categoriesValue : <dynamic>[];

    return list
        .whereType<Map>()
        .map((item) =>
            StoreServiceCategoryOption.fromMap(Map<String, dynamic>.from(item)))
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> pickImages() async {
    final int remainingImages = maxServiceImages - serviceImagesCount;

    if (remainingImages <= 0) {
      showMessage('store_service_images_limit_message'.tr);
      return;
    }

    try {
      final List<XFile> images = await ImagePicker().pickMultiImage(
        imageQuality: 68,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (images.isEmpty) {
        return;
      }

      final Set<String> selectedPaths =
          selectedImages.map((image) => image.path).toSet();
      final List<XFile> newImages = <XFile>[];

      int skippedDuplicated = 0;
      int skippedOversized = 0;

      for (final XFile image in images) {
        if (selectedPaths.contains(image.path)) {
          skippedDuplicated++;
          continue;
        }

        final int imageBytes = await File(image.path).length();

        if (imageBytes > maxServiceImageBytes) {
          skippedOversized++;
          continue;
        }

        newImages.add(image);
        selectedPaths.add(image.path);

        if (newImages.length >= remainingImages) {
          break;
        }
      }

      if (newImages.isEmpty) {
        if (skippedOversized > 0) {
          showMessage('store_image_too_large_15mb'.tr);
          return;
        }

        if (skippedDuplicated > 0) {
          showMessage('store_image_already_added'.tr);
          return;
        }

        showMessage('store_images_add_error'.tr);
        return;
      }

      setState(() {
        selectedImages.addAll(newImages);
      });

      if (images.length > remainingImages) {
        showMessage('store_service_images_added_limit'.trParams(
          {'count': '${newImages.length}'},
        ));
      } else if (skippedOversized > 0) {
        showMessage('store_some_images_too_large'.tr);
      }
    } catch (_) {
      showMessage('store_images_select_error'.tr);
    }
  }

  void removeExistingImage(int index) {
    if (index < 0 || index >= existingImageUrls.length) {
      return;
    }

    setState(() {
      existingImageUrls.removeAt(index);
    });
  }

  void removeSelectedImage(int index) {
    if (index < 0 || index >= selectedImages.length) {
      return;
    }

    setState(() {
      selectedImages.removeAt(index);
    });
  }

  Future<void> openCategorySelector() async {
    if (isLoadingCategories) return;

    if (categories.isEmpty) {
      await loadCategories();
    }

    if (!mounted) return;

    if (categories.isEmpty) {
      showMessage('store_no_service_category_available'.tr);
      return;
    }

    final String rootTitle = selectedFormat == 'digital'
        ? 'store_digital_services'.tr
        : 'store_in_person_services'.tr;

    final Object? result = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        final Color primaryColor = Theme.of(context).primaryColor;
        final List<_CategoryStackEntry> stack = <_CategoryStackEntry>[
          _CategoryStackEntry(
            title: rootTitle,
            parentId: null,
            items: List<StoreServiceCategoryOption>.from(categories),
          ),
        ];
        List<StoreServiceCategoryOption> filtered =
            List<StoreServiceCategoryOption>.from(categories);
        String searchTerm = '';
        bool modalLoading = false;

        return StatefulBuilder(
          builder: (context, modalSetState) {
            final _CategoryStackEntry current = stack.last;

            void applyFilter() {
              final String search = searchTerm.trim().toLowerCase();
              filtered = search.isEmpty
                  ? List<StoreServiceCategoryOption>.from(current.items)
                  : current.items.where((item) {
                      return item.name.toLowerCase().contains(search) ||
                          item.description.toLowerCase().contains(search) ||
                          item.slug.toLowerCase().contains(search) ||
                          item.sourcePath.toLowerCase().contains(search);
                    }).toList();
            }

            Future<void> openChildren(
                StoreServiceCategoryOption category) async {
              if (modalLoading) return;

              modalSetState(() => modalLoading = true);
              final List<StoreServiceCategoryOption> children =
                  await fetchServiceCategories(parentId: category.id);
              if (!mounted) return;

              modalSetState(() {
                modalLoading = false;
                if (children.isNotEmpty) {
                  stack.add(_CategoryStackEntry(
                    title: category.name,
                    parentId: category.id,
                    items: children,
                  ));
                  searchTerm = '';
                  filtered = List<StoreServiceCategoryOption>.from(children);
                }
              });

              if (children.isEmpty && mounted) {
                showMessage('store_no_subcategory_found'.tr);
              }
            }

            void goBackLevel() {
              if (stack.length <= 1) return;
              modalSetState(() {
                stack.removeLast();
                searchTerm = '';
                filtered =
                    List<StoreServiceCategoryOption>.from(stack.last.items);
              });
            }

            applyFilter();

            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (stack.length > 1) ...[
                          GestureDetector(
                            onTap: modalLoading ? null : goBackLevel,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.arrow_back_rounded,
                                  color: Colors.grey.shade700, size: 20),
                            ),
                          ),
                          const SizedBox(width: 9),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(current.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textBold.copyWith(
                                      color: Colors.black87, fontSize: 18)),
                              const SizedBox(height: 3),
                              Text(
                                  selectedFormat == 'digital'
                                      ? 'store_showing_digital_services_only'.tr
                                      : 'store_showing_in_person_services_only'
                                          .tr,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: textRegular.copyWith(
                                      color: Colors.grey.shade600,
                                      fontSize: 11.8,
                                      height: 1.2)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.close_rounded,
                                color: Colors.grey.shade700, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) {
                        modalSetState(() => searchTerm = value);
                      },
                      decoration: InputDecoration(
                        hintText: 'store_search_this_level'.tr,
                        prefixIcon:
                            Icon(Icons.search_rounded, color: primaryColor),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: primaryColor, width: 1.4)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (modalLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: primaryColor),
                            ),
                            const SizedBox(width: 10),
                            Text('store_loading_subcategories'.tr,
                                style: textMedium.copyWith(
                                    color: Colors.grey.shade700,
                                    fontSize: 12.5)),
                          ],
                        ),
                      ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.48,
                      child: filtered.isEmpty
                          ? Center(
                              child: Text('store_no_category_found'.tr,
                                  style: textMedium.copyWith(
                                      color: Colors.grey.shade600)))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final StoreServiceCategoryOption category =
                                    filtered[index];
                                final bool selected =
                                    selectedCategory?.id == category.id;
                                final bool canOpen = category.hasChildren;
                                final bool canSelect = category.selectable ||
                                    (!category.hasChildren &&
                                        !category.isVirtual);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 9),
                                  child: Material(
                                    color: selected
                                        ? primaryColor.withValues(alpha: 0.10)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(18),
                                    child: InkWell(
                                      onTap: modalLoading
                                          ? null
                                          : () async {
                                              if (canOpen) {
                                                await openChildren(category);
                                                return;
                                              }

                                              if (canSelect) {
                                                Navigator.of(context)
                                                    .pop(category);
                                                return;
                                              }

                                              showMessage(
                                                  'store_open_subcategory_before_selecting'
                                                      .tr);
                                            },
                                      borderRadius: BorderRadius.circular(18),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                  color: primaryColor
                                                      .withValues(alpha: 0.10),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          14)),
                                              child: Icon(
                                                  canOpen
                                                      ? Icons
                                                          .folder_open_rounded
                                                      : Icons
                                                          .design_services_outlined,
                                                  color: primaryColor,
                                                  size: 21),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(category.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: textBold.copyWith(
                                                          color: Colors.black87,
                                                          fontSize: 13.8)),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                      canOpen
                                                          ? 'store_tap_to_view_subcategories'
                                                              .tr
                                                          : 'store_final_service_category'
                                                              .tr,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          textRegular.copyWith(
                                                              color: Colors.grey
                                                                  .shade600,
                                                              fontSize: 11.5,
                                                              height: 1.22)),
                                                ],
                                              ),
                                            ),
                                            if (selected)
                                              Icon(Icons.check_circle_rounded,
                                                  color: primaryColor, size: 22)
                                            else
                                              Icon(
                                                  canOpen
                                                      ? Icons
                                                          .chevron_right_rounded
                                                      : Icons
                                                          .check_circle_outline_rounded,
                                                  color: canOpen
                                                      ? Colors.grey.shade500
                                                      : primaryColor,
                                                  size: 23),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: primaryColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        onTap: () =>
                            Navigator.of(context).pop('request_new_category'),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                          child: Row(
                            children: [
                              Icon(Icons.add_circle_outline_rounded,
                                  color: primaryColor, size: 22),
                              const SizedBox(width: 9),
                              Expanded(
                                  child: Text(
                                      'store_request_new_category_cta'.tr,
                                      style: textBold.copyWith(
                                          color: primaryColor, fontSize: 13))),
                            ],
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
      },
    );

    if (!mounted || result == null) return;

    if (result == 'request_new_category') {
      await openNewCategoryRequestModal();
      return;
    }

    if (result is StoreServiceCategoryOption) {
      setState(() {
        selectedCategory = result;
        editingCategoryId = result.realCategoryId ?? result.id;
        requestNewCategory = false;
        categoryRequestNameController.clear();
        categoryRequestDescriptionController.clear();
      });
    }
  }

  void changeFormat(String value) {
    if (selectedFormat == value) return;
    setState(() {
      selectedFormat = value;
      selectedDeliveryType = value == 'digital' ? 'online' : 'client_location';
      selectedCategory = null;
      editingCategoryId = null;
      categories = <StoreServiceCategoryOption>[];
      selectedAdPlanSlug = '';
      requestNewCategory = false;
      categoryRequestNameController.clear();
      categoryRequestDescriptionController.clear();
    });
    loadCategories();
  }

  Future<void> openNewCategoryRequestModal() async {
    final TextEditingController nameDraft = TextEditingController(
      text: categoryRequestNameController.text,
    );
    final TextEditingController descriptionDraft = TextEditingController(
      text: categoryRequestDescriptionController.text,
    );

    bool showNameError = false;

    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        final Color primaryColor = Theme.of(modalContext).primaryColor;

        return StatefulBuilder(
          builder: (context, modalSetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 18),
                        blurRadius: 34,
                        color: Colors.black.withValues(alpha: 0.16),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'store_request_new_category'.tr,
                                style: textBold.copyWith(
                                  color: Colors.black87,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  Navigator.of(modalContext).pop(false),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(13),
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
                        const SizedBox(height: 8),
                        Text(
                          'store_new_category_request_note'.tr,
                          style: textRegular.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameDraft,
                          style: textMedium.copyWith(
                            color: Colors.black87,
                            fontSize: 13.6,
                          ),
                          decoration: InputDecoration(
                            labelText: 'store_new_category_name'.tr,
                            hintText: 'store_new_category_name_hint'.tr,
                            errorText: showNameError
                                ? 'store_category_name_required'.tr
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF7F8F8),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(17),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(17),
                              borderSide: BorderSide(
                                color: primaryColor,
                                width: 1.35,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(17),
                              borderSide:
                                  const BorderSide(color: Colors.redAccent),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(17),
                              borderSide:
                                  const BorderSide(color: Colors.redAccent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionDraft,
                          maxLines: 4,
                          style: textMedium.copyWith(
                            color: Colors.black87,
                            fontSize: 13.6,
                          ),
                          decoration: InputDecoration(
                            labelText: 'store_explain_category'.tr,
                            hintText: 'store_explain_category_hint'.tr,
                            filled: true,
                            fillColor: const Color(0xFFF7F8F8),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(17),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(17),
                              borderSide: BorderSide(
                                color: primaryColor,
                                width: 1.35,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Material(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              if (nameDraft.text.trim().isEmpty) {
                                modalSetState(() {
                                  showNameError = true;
                                });
                                return;
                              }

                              Navigator.of(modalContext).pop(true);
                            },
                            child: Container(
                              width: double.infinity,
                              height: 48,
                              alignment: Alignment.center,
                              child: Text(
                                'store_send_request'.tr,
                                style: textBold.copyWith(
                                  color: Colors.white,
                                  fontSize: 13.6,
                                ),
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
          },
        );
      },
    );

    if (!mounted) {
      nameDraft.dispose();
      descriptionDraft.dispose();
      return;
    }

    if (confirmed == true) {
      setState(() {
        selectedCategory = null;
        editingCategoryId = null;
        requestNewCategory = true;
        categoryRequestNameController.text = nameDraft.text.trim();
        categoryRequestDescriptionController.text =
            descriptionDraft.text.trim();
      });
    }

    nameDraft.dispose();
    descriptionDraft.dispose();
  }

  StoreServiceAdPlanOption? get selectedServiceAdPlan {
    if (serviceAdPlans.isEmpty || selectedAdPlanSlug.trim().isEmpty) {
      return null;
    }

    for (final StoreServiceAdPlanOption plan in serviceAdPlans) {
      if (plan.slug == selectedAdPlanSlug) {
        return plan;
      }
    }

    return null;
  }

  bool get hasCreditsToPublishServiceAd {
    return hasUnlimitedAdPlan || availableAdCredits > 0;
  }

  bool get mustChooseServiceAdPlan {
    return !isEditMode && !hasCreditsToPublishServiceAd;
  }

  Future<void> showServicePlanSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (isLoadingAdPlans) {
      showMessage('store_loading_listing_plans_wait'.tr);
      return;
    }

    if (serviceAdPlans.isEmpty) {
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
                        'store_choose_service_ad_payment'.tr,
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
                  'store_service_ad_credit_explanation'.tr,
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
                    itemCount: serviceAdPlans.length,
                    itemBuilder: (_, index) {
                      final StoreServiceAdPlanOption plan =
                          serviceAdPlans[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ServiceAdPlanOptionTile(
                          primaryColor: Theme.of(context).primaryColor,
                          selected: selectedAdPlanSlug == plan.slug,
                          title: plan.name,
                          price: plan.formattedPrice,
                          description: plan.fullDescription,
                          onTap: () {
                            setState(() {
                              selectedAdPlanSlug = plan.slug;
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

  Future<bool> validateSelectedImageSizes() async {
    for (final XFile image in selectedImages) {
      final int imageBytes = await File(image.path).length();

      if (imageBytes > maxServiceImageBytes) {
        showMessage('store_images_over_15mb_remove'.tr);
        return false;
      }
    }

    return true;
  }

  Future<void> submitService() async {
    if (isSubmitting) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (!await validateSelectedImageSizes()) return;

    final bool hasCategory = selectedCategory != null;
    final bool hasRequest =
        categoryRequestNameController.text.trim().isNotEmpty;

    if (!hasCategory && !hasRequest) {
      showMessage('store_select_or_request_category'.tr);
      return;
    }

    if (!hasServiceImages) {
      showMessage('store_select_service_image_required'.tr);
      return;
    }

    if (!acceptedTerms) {
      showMessage('store_confirm_service_terms'.tr);
      return;
    }

    final StoreServiceAdPlanOption? plan = selectedServiceAdPlan;

    if (mustChooseServiceAdPlan && (plan == null || plan.id.trim().isEmpty)) {
      showMessage('store_choose_credit_plan_to_publish'.tr);
      await showServicePlanSheet();
      return;
    }

    setState(() => isSubmitting = true);

    final Map<String, String> fields = {
      if (selectedCategory != null)
        'category_id': selectedCategory!.realCategoryId ?? selectedCategory!.id,
      if (categoryRequestNameController.text.trim().isNotEmpty)
        'category_request_name': categoryRequestNameController.text.trim(),
      if (categoryRequestDescriptionController.text.trim().isNotEmpty)
        'category_request_description':
            categoryRequestDescriptionController.text.trim(),
      if (mustChooseServiceAdPlan && plan != null) 'plan_id': plan.id,
      if (mustChooseServiceAdPlan && plan != null) 'ad_plan_id': plan.id,
      if (mustChooseServiceAdPlan && plan != null)
        'marketplace_ad_plan_id': plan.id,
      'name': titleController.text.trim(),
      if (skuController.text.trim().isNotEmpty)
        'sku': skuController.text.trim(),
      'price': normalizeMoney(priceController.text),
      if (oldPriceController.text.trim().isNotEmpty)
        'old_price': normalizeMoney(oldPriceController.text),
      if (costPriceController.text.trim().isNotEmpty)
        'cost_price': normalizeMoney(costPriceController.text),
      if (shortDescriptionController.text.trim().isNotEmpty)
        'short_description': shortDescriptionController.text.trim(),
      'description': descriptionController.text.trim(),
      'service_format': selectedFormat,
      'service_delivery_type': selectedDeliveryType,
      if (attendanceLocationController.text.trim().isNotEmpty)
        'attendance_location': attendanceLocationController.text.trim(),
      if (serviceAreaController.text.trim().isNotEmpty)
        'service_area': serviceAreaController.text.trim(),
      if (deadlineController.text.trim().isNotEmpty)
        'estimated_deadline': deadlineController.text.trim(),
      if (executionTimeController.text.trim().isNotEmpty)
        'execution_time': executionTimeController.text.trim(),
      'needs_scheduling': needsScheduling ? '1' : '0',
      if (includedController.text.trim().isNotEmpty)
        'included_items': includedController.text.trim(),
      if (excludedController.text.trim().isNotEmpty)
        'excluded_items': excludedController.text.trim(),
      if (requirementsController.text.trim().isNotEmpty)
        'customer_requirements': requirementsController.text.trim(),
      if (instructionsController.text.trim().isNotEmpty)
        'instructions_after_payment': instructionsController.text.trim(),
      if (deliverableController.text.trim().isNotEmpty)
        'deliverable_description': deliverableController.text.trim(),
    };

    final Response response;
    if (isEditMode) {
      final String uri = serviceUpdateUri(editingServiceId);

      if (selectedImages.isEmpty) {
        response = await Get.find<ApiClient>().postData(uri, fields);
      } else {
        final bool shouldUploadNewCover = existingImageUrls.isEmpty;
        final MultipartBody primaryImage = MultipartBody(
          shouldUploadNewCover ? 'main_image' : 'images[]',
          selectedImages.first,
        );
        final List<MultipartBody> galleryImages = selectedImages
            .skip(1)
            .map((image) => MultipartBody('images[]', image))
            .toList();

        response = await Get.find<ApiClient>().postMultipartData(
          uri,
          fields,
          primaryImage,
          galleryImages,
        );
      }
    } else {
      final MultipartBody coverImage =
          MultipartBody('main_image', selectedImages.first);
      final List<MultipartBody> galleryImages = selectedImages
          .skip(1)
          .map((image) => MultipartBody('images[]', image))
          .toList();

      response = await Get.find<ApiClient>().postMultipartData(
        serviceCreateUri,
        fields,
        coverImage,
        galleryImages,
      );
    }

    if (!mounted) return;
    setState(() => isSubmitting = false);

    final dynamic body = response.body;
    if ((response.statusCode == 200 || response.statusCode == 201) &&
        body is Map &&
        body['status'] == true) {
      if (isEditMode) {
        showMessage('store_service_updated_sent_approval'.tr);
        Get.back();
        return;
      }
      clearForm();
      showMessage('store_service_created_sent_approval'.tr);
      return;
    }

    String message = isEditMode
        ? 'store_service_update_error'.tr
        : 'store_service_create_error'.tr;
    if (body is Map && body['message'] != null) {
      message = body['message'].toString();
    }
    showMessage(message);
  }

  void clearForm() {
    titleController.clear();
    skuController.clear();
    priceController.clear();
    oldPriceController.clear();
    costPriceController.clear();
    shortDescriptionController.clear();
    descriptionController.clear();
    includedController.clear();
    excludedController.clear();
    requirementsController.clear();
    deadlineController.clear();
    executionTimeController.clear();
    attendanceLocationController.clear();
    serviceAreaController.clear();
    instructionsController.clear();
    deliverableController.clear();
    categoryRequestNameController.clear();
    categoryRequestDescriptionController.clear();
    setState(() {
      selectedCategory = null;
      selectedImages = <XFile>[];
      existingImageUrls = <String>[];
      editingCategoryId = null;
      requestNewCategory = false;
      selectedFormat = 'digital';
      selectedDeliveryType = 'online';
      needsScheduling = false;
      acceptedTerms = false;
      categories = <StoreServiceCategoryOption>[];
      selectedAdPlanSlug = '';
    });
    loadCategories();
  }

  double? parseFlexibleDouble(dynamic value) {
    if (value == null) return null;
    String cleanValue = '$value'.trim();
    if (cleanValue.isEmpty || cleanValue == 'null') return null;
    cleanValue = cleanValue.replaceAll('R\$', '').replaceAll(' ', '');
    cleanValue = cleanValue.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (cleanValue.contains(',') && cleanValue.contains('.')) {
      cleanValue = cleanValue.replaceAll('.', '').replaceAll(',', '.');
    } else if (cleanValue.contains(',')) {
      cleanValue = cleanValue.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(cleanValue);
  }

  String formatMoneyForInput(dynamic value) {
    final double? amount = parseFlexibleDouble(value);
    if (amount == null || amount <= 0) return '';
    return amount.toStringAsFixed(2).replaceAll('.', ',');
  }

  String normalizeMoney(String value) {
    final double? amount = parseFlexibleDouble(value);
    if (amount == null) return '';
    return amount.toStringAsFixed(2);
  }

  bool parseBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String normalized = '$value'.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'null') return fallback;
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'sim' ||
        normalized == 'yes' ||
        normalized == 'on';
  }

  void showTermsModal() {
    final Color primaryColor = Theme.of(context).primaryColor;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text('store_service_terms_title'.tr,
                            style: textBold.copyWith(
                                color: Colors.black87, fontSize: 17))),
                    GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(Icons.close_rounded,
                            color: Colors.grey.shade700)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'store_service_terms_description'.tr,
                  style: textRegular.copyWith(
                      color: Colors.grey.shade700, fontSize: 13, height: 1.38),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    child: Text('store_understood'.tr,
                        style: textBold.copyWith(
                            color: Colors.white, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showMessage(String message) {
    final Color primaryColor = Theme.of(context).primaryColor;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: textMedium.copyWith(color: Colors.white, fontSize: 12.8)),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          _TopBar(
              primaryColor: primaryColor,
              title: isEditMode
                  ? 'store_edit_service'.tr
                  : 'store_register_service'.tr,
              onBackTap: () => Get.back()),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault,
                  18, Dimensions.paddingSizeDefault, 28),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    _IntroCard(
                        primaryColor: primaryColor, isEditMode: isEditMode),
                    const SizedBox(height: 14),
                    _ImagePickerCard(
                        primaryColor: primaryColor,
                        selectedImages: selectedImages,
                        existingImageUrls: existingImageUrls,
                        maxImages: maxServiceImages,
                        onAddTap: pickImages,
                        onRemoveExistingImage: removeExistingImage,
                        onRemoveSelectedImage: removeSelectedImage),
                    const SizedBox(height: 14),
                    _Section(title: 'store_service_type'.tr, children: [
                      Row(
                        children: [
                          Expanded(
                              child: _OptionCard(
                                  primaryColor: primaryColor,
                                  selected: selectedFormat == 'digital',
                                  title: 'store_digital'.tr,
                                  subtitle: 'store_online_or_download'.tr,
                                  icon: Icons.laptop_mac_rounded,
                                  onTap: () => changeFormat('digital'))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _OptionCard(
                                  primaryColor: primaryColor,
                                  selected: selectedFormat == 'presential',
                                  title: 'store_in_person'.tr,
                                  subtitle: 'store_local_service'.tr,
                                  icon: Icons.handshake_outlined,
                                  onTap: () => changeFormat('presential'))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...deliveryOptions.map((option) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _LargeOptionCard(
                              primaryColor: primaryColor,
                              selected: selectedDeliveryType == option.value,
                              title: option.title,
                              subtitle: option.subtitle,
                              icon: option.icon,
                              onTap: () => setState(
                                  () => selectedDeliveryType = option.value),
                            ),
                          )),
                    ]),
                    const SizedBox(height: 14),
                    _Section(title: 'store_category'.tr, children: [
                      _CategoryField(
                        primaryColor: primaryColor,
                        category: selectedCategory,
                        isLoading: isLoadingCategories,
                        requestNewCategory: requestNewCategory,
                        requestedCategoryName:
                            categoryRequestNameController.text.trim(),
                        onTap: openCategorySelector,
                        onClear: () => setState(() {
                          selectedCategory = null;
                          editingCategoryId = null;
                          requestNewCategory = false;
                          categoryRequestNameController.clear();
                          categoryRequestDescriptionController.clear();
                        }),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _Section(title: 'store_main_information'.tr, children: [
                      _Input(
                          label: 'store_service_title'.tr,
                          hint: 'store_service_title_hint'.tr,
                          controller: titleController,
                          validator: requiredTitle),
                      const SizedBox(height: 12),
                      _Input(
                          label: 'store_internal_code_sku'.tr,
                          hint: 'store_optional'.tr,
                          controller: skuController),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _Input(
                                label: 'store_value'.tr,
                                hint: '150,00',
                                controller: priceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: requiredMoney)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _Input(
                                label: 'store_promotional_value'.tr,
                                hint: 'store_optional'.tr,
                                controller: oldPriceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true))),
                      ]),
                      const SizedBox(height: 12),
                      _Input(
                          label: 'store_internal_cost'.tr,
                          hint: 'store_internal_cost_hint'.tr,
                          controller: costPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true)),
                      const SizedBox(height: 12),
                      _Input(
                          label: 'store_short_summary'.tr,
                          hint: 'store_service_short_summary_hint'.tr,
                          controller: shortDescriptionController,
                          maxLines: 3),
                      const SizedBox(height: 12),
                      _Input(
                          label: 'store_full_description'.tr,
                          hint: 'store_service_full_description_hint'.tr,
                          controller: descriptionController,
                          maxLines: 6,
                          validator: requiredDescription),
                    ]),
                    const SizedBox(height: 14),
                    _Section(
                        title: selectedFormat == 'digital'
                            ? 'store_digital_delivery'.tr
                            : 'store_in_person_service'.tr,
                        children: [
                          if (selectedFormat == 'digital') ...[
                            _Input(
                                label: selectedDeliveryType == 'download'
                                    ? 'store_service_deliverable_label'.tr
                                    : 'store_service_attendance_label'.tr,
                                hint: selectedDeliveryType == 'download'
                                    ? 'store_service_deliverable_hint'.tr
                                    : 'store_service_attendance_hint'.tr,
                                controller: deliverableController,
                                maxLines: 4),
                            const SizedBox(height: 12),
                            _Input(
                                label: 'store_service_deadline'.tr,
                                hint: 'store_service_deadline_hint'.tr,
                                controller: deadlineController),
                          ] else ...[
                            _Input(
                                label: 'store_service_location'.tr,
                                hint: 'store_service_location_hint'.tr,
                                controller: attendanceLocationController),
                            const SizedBox(height: 12),
                            _Input(
                                label: 'store_service_area'.tr,
                                hint: 'store_service_area_hint'.tr,
                                controller: serviceAreaController,
                                maxLines: 3),
                            const SizedBox(height: 12),
                            _Input(
                                label: 'store_service_execution_time'.tr,
                                hint: 'store_service_execution_time_hint'.tr,
                                controller: executionTimeController),
                            const SizedBox(height: 12),
                            _SwitchLine(
                                primaryColor: primaryColor,
                                value: needsScheduling,
                                onChanged: (value) =>
                                    setState(() => needsScheduling = value)),
                          ],
                          const SizedBox(height: 12),
                          _Input(
                              label: 'store_instructions_after_payment'.tr,
                              hint: 'store_instructions_after_payment_hint'.tr,
                              controller: instructionsController,
                              maxLines: 4),
                        ]),
                    const SizedBox(height: 14),
                    _Section(title: 'store_service_scope'.tr, children: [
                      _Input(
                          label: 'store_included_items'.tr,
                          hint: 'store_included_items_hint'.tr,
                          controller: includedController,
                          maxLines: 5),
                      const SizedBox(height: 12),
                      _Input(
                          label: 'store_excluded_items'.tr,
                          hint: 'store_excluded_items_hint'.tr,
                          controller: excludedController,
                          maxLines: 4),
                      const SizedBox(height: 12),
                      _Input(
                          label: 'store_customer_requirements'.tr,
                          hint: 'store_customer_requirements_hint'.tr,
                          controller: requirementsController,
                          maxLines: 4),
                    ]),
                    const SizedBox(height: 14),
                    _ServiceAdPricingCard(
                      primaryColor: primaryColor,
                      isLoading: isLoadingAdPlans,
                      isEditMode: isEditMode,
                      availableCredits: availableAdCredits,
                      hasUnlimitedPlan: hasUnlimitedAdPlan,
                      unlimitedPlanExpiresAt: unlimitedAdPlanExpiresAt,
                      selectedPlan: selectedServiceAdPlan,
                      onChoosePlanTap: showServicePlanSheet,
                    ),
                    const SizedBox(height: 14),
                    _SecurityCard(primaryColor: primaryColor),
                    const SizedBox(height: 14),
                    _TermsCard(
                        primaryColor: primaryColor,
                        accepted: acceptedTerms,
                        onChanged: (value) =>
                            setState(() => acceptedTerms = value),
                        onOpenTerms: showTermsModal),
                    const SizedBox(height: 16),
                    _SubmitButton(
                        primaryColor: primaryColor,
                        loading: isSubmitting,
                        text: isEditMode
                            ? 'store_update_service'.tr
                            : 'store_send_service_for_approval'.tr,
                        onTap: submitService),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_DeliveryOption> get deliveryOptions {
    if (selectedFormat == 'digital') {
      return [
        _DeliveryOption('online', 'store_online'.tr,
            'store_online_service_description'.tr, Icons.video_call_outlined),
        _DeliveryOption(
            'download',
            'store_download_file'.tr,
            'store_download_file_description'.tr,
            Icons.cloud_download_outlined),
      ];
    }

    return [
      _DeliveryOption(
          'client_location',
          'store_at_customer_address'.tr,
          'store_at_customer_address_description'.tr,
          Icons.home_repair_service_outlined),
      _DeliveryOption(
          'provider_location',
          'store_at_provider_address'.tr,
          'store_at_provider_address_description'.tr,
          Icons.storefront_outlined),
      _DeliveryOption('region', 'store_by_city_or_region'.tr,
          'store_by_city_or_region_description'.tr, Icons.map_outlined),
    ];
  }

  String? requiredTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'store_service_title_required'.tr;
    }
    if (value.trim().length < 6) return 'store_service_title_too_short'.tr;
    return null;
  }

  String? requiredDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'store_service_description_required'.tr;
    }
    if (value.trim().length < 30) {
      return 'store_service_description_too_short'.tr;
    }
    return null;
  }

  String? requiredMoney(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'store_value_required'.tr;
    }
    final double? parsed = double.tryParse(normalizeMoney(value));
    if (parsed == null || parsed <= 0) {
      return 'store_invalid_value'.tr;
    }
    return null;
  }
}

class _TopBar extends StatelessWidget {
  final Color primaryColor;
  final String title;
  final VoidCallback onBackTap;

  const _TopBar(
      {required this.primaryColor,
      required this.title,
      required this.onBackTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: primaryColor,
      padding: EdgeInsets.fromLTRB(
          14, MediaQuery.of(context).padding.top + 12, 14, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBackTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: textBold.copyWith(color: Colors.white, fontSize: 19))),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final Color primaryColor;
  final bool isEditMode;

  const _IntroCard({required this.primaryColor, required this.isEditMode});

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(
              primaryColor: primaryColor,
              icon: isEditMode
                  ? Icons.edit_note_rounded
                  : Icons.design_services_outlined),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isEditMode
                        ? 'store_update_service'.tr
                        : 'store_new_service'.tr,
                    style:
                        textBold.copyWith(color: Colors.black87, fontSize: 18)),
                const SizedBox(height: 7),
                Text(
                  isEditMode
                      ? 'store_service_edit_intro_description'.tr
                      : 'store_service_create_intro_description'.tr,
                  style: textRegular.copyWith(
                      color: Colors.grey.shade700,
                      fontSize: 12.8,
                      height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  final Color primaryColor;
  final List<XFile> selectedImages;
  final List<String> existingImageUrls;
  final int maxImages;
  final VoidCallback onAddTap;
  final ValueChanged<int> onRemoveExistingImage;
  final ValueChanged<int> onRemoveSelectedImage;

  const _ImagePickerCard({
    required this.primaryColor,
    required this.selectedImages,
    required this.existingImageUrls,
    required this.maxImages,
    required this.onAddTap,
    required this.onRemoveExistingImage,
    required this.onRemoveSelectedImage,
  });

  @override
  Widget build(BuildContext context) {
    final List<_ServiceImagePreviewItem> previewItems =
        <_ServiceImagePreviewItem>[
      ...existingImageUrls.asMap().entries.map(
            (entry) => _ServiceImagePreviewItem.existing(
              index: entry.key,
              imageUrl: entry.value,
            ),
          ),
      ...selectedImages.asMap().entries.map(
            (entry) => _ServiceImagePreviewItem.selected(
              index: entry.key,
              image: entry.value,
            ),
          ),
    ];

    final bool hasImages = previewItems.isNotEmpty;
    final bool canAddMore = previewItems.length < maxImages;
    final _ServiceImagePreviewItem? coverImage =
        hasImages ? previewItems.first : null;
    final List<_ServiceImagePreviewItem> secondaryImages = hasImages
        ? previewItems.skip(1).toList()
        : <_ServiceImagePreviewItem>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'store_service_images'.tr,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 15.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${previewItems.length}/$maxImages',
                  style: textBold.copyWith(
                    color: primaryColor,
                    fontSize: 11.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'store_first_image_listing_cover'.tr,
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 12.2,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          if (coverImage == null)
            GestureDetector(
              onTap: onAddTap,
              child: Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.16),
                  ),
                ),
                child: _placeholder(),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: SizedBox(
                width: double.infinity,
                height: 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(coverImage),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.08),
                              Colors.black.withValues(alpha: 0.44),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'store_cover'.tr,
                          style: textBold.copyWith(
                            color: Colors.black87,
                            fontSize: 11.8,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: _RemoveImageButton(
                        onTap: () => _removeImage(coverImage),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              ...secondaryImages.map((item) {
                return SizedBox(
                  width: 72,
                  height: 72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildImage(item),
                        Positioned(
                          right: 5,
                          top: 5,
                          child: _RemoveImageButton(
                            size: 25,
                            iconSize: 15,
                            onTap: () => _removeImage(item),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (canAddMore)
                GestureDetector(
                  onTap: onAddTap,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            color: primaryColor, size: 23),
                        const SizedBox(height: 4),
                        Text(
                          'store_add'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textBold.copyWith(
                            color: primaryColor,
                            fontSize: 9.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImage(_ServiceImagePreviewItem item) {
    if (item.isExisting) {
      return Image.network(
        item.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    return Image.file(
      File(item.image!.path),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  void _removeImage(_ServiceImagePreviewItem item) {
    if (item.isExisting) {
      onRemoveExistingImage(item.index);
      return;
    }

    onRemoveSelectedImage(item.index);
  }

  Widget _placeholder() {
    return Container(
      color: primaryColor.withValues(alpha: 0.06),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, color: primaryColor, size: 36),
            const SizedBox(height: 8),
            Text(
              'store_add_images'.tr,
              style: textBold.copyWith(color: primaryColor, fontSize: 13.8),
            ),
            const SizedBox(height: 4),
            Text(
              'store_choose_up_to_5_service_images'.tr,
              textAlign: TextAlign.center,
              style: textRegular.copyWith(
                color: Colors.grey.shade700,
                fontSize: 11.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoveImageButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const _RemoveImageButton({
    required this.onTap,
    this.size = 30,
    this.iconSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.close_rounded,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

class _ServiceImagePreviewItem {
  final bool isExisting;
  final int index;
  final String? imageUrl;
  final XFile? image;

  const _ServiceImagePreviewItem.existing({
    required this.index,
    required this.imageUrl,
  })  : isExisting = true,
        image = null;

  const _ServiceImagePreviewItem.selected({
    required this.index,
    required this.image,
  })  : isExisting = false,
        imageUrl = null;
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 16.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ...children,
          const SizedBox(height: 17),
          Divider(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;

  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: child,
    );
  }
}

class _IconBox extends StatelessWidget {
  final Color primaryColor;
  final IconData icon;

  const _IconBox({required this.primaryColor, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(17)),
      child: Icon(icon, color: primaryColor, size: 27),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final Color primaryColor;
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _OptionCard(
      {required this.primaryColor,
      required this.selected,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          selected ? primaryColor.withValues(alpha: 0.08) : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 106),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? primaryColor : Colors.grey.shade200,
                  width: selected ? 1.4 : 1)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon,
                color: selected ? primaryColor : Colors.grey.shade600,
                size: 25),
            const SizedBox(height: 10),
            Text(title,
                style:
                    textBold.copyWith(color: Colors.black87, fontSize: 13.8)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: textRegular.copyWith(
                    color: Colors.grey.shade600, fontSize: 11.8, height: 1.2)),
          ]),
        ),
      ),
    );
  }
}

class _LargeOptionCard extends StatelessWidget {
  final Color primaryColor;
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _LargeOptionCard(
      {required this.primaryColor,
      required this.selected,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          selected ? primaryColor.withValues(alpha: 0.08) : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                  color: selected ? primaryColor : Colors.grey.shade200,
                  width: selected ? 1.4 : 1)),
          child: Row(children: [
            Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: primaryColor, size: 22)),
            const SizedBox(width: 11),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: textBold.copyWith(
                          color: Colors.black87, fontSize: 13.7)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: textRegular.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 11.8,
                          height: 1.23)),
                ])),
            if (selected)
              Icon(Icons.check_circle_rounded, color: primaryColor, size: 22),
          ]),
        ),
      ),
    );
  }
}

class _CategoryField extends StatelessWidget {
  final Color primaryColor;
  final StoreServiceCategoryOption? category;
  final bool isLoading;
  final bool requestNewCategory;
  final String requestedCategoryName;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _CategoryField(
      {required this.primaryColor,
      required this.category,
      required this.isLoading,
      required this.requestNewCategory,
      required this.requestedCategoryName,
      required this.onTap,
      required this.onClear});

  @override
  Widget build(BuildContext context) {
    final bool hasCategory = category != null;
    final bool hasRequest =
        requestNewCategory && requestedCategoryName.trim().isNotEmpty;
    final String title = hasCategory
        ? category!.name
        : hasRequest
            ? 'store_new_category_named'.trParams(
                {'name': requestedCategoryName.trim()},
              )
            : 'store_select_service_category'.tr;
    final String subtitle = hasCategory
        ? category!.description
        : hasRequest
            ? 'store_category_request_pending_review'.tr
            : 'store_select_service_category_hint'.tr;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: hasCategory || hasRequest
                      ? primaryColor.withValues(alpha: 0.65)
                      : Colors.grey.shade200)),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16)),
                child: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: primaryColor))
                    : Icon(
                        hasRequest
                            ? Icons.add_business_outlined
                            : Icons.category_outlined,
                        color: primaryColor,
                        size: 23)),
            const SizedBox(width: 11),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(
                          color: Colors.black87, fontSize: 13.7)),
                  const SizedBox(height: 4),
                  Text(
                      subtitle.isEmpty
                          ? 'store_admin_created_service_category'.tr
                          : subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 11.8,
                          height: 1.25)),
                ])),
            if (hasCategory || hasRequest)
              GestureDetector(
                  onTap: onClear,
                  child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.redAccent, size: 18)))
            else
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade500, size: 24),
          ]),
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Input(
      {required this.label,
      required this.hint,
      required this.controller,
      this.keyboardType,
      this.maxLines = 1,
      this.validator});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: textBold.copyWith(color: Colors.black87, fontSize: 12.8)),
      const SizedBox(height: 7),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        style: textMedium.copyWith(color: Colors.black87, fontSize: 13.4),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              textRegular.copyWith(color: Colors.grey.shade500, fontSize: 12.5),
          filled: true,
          fillColor: const Color(0xFFF7F8F8),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primaryColor, width: 1.35)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent)),
        ),
      ),
    ]);
  }
}

class _InfoBox extends StatelessWidget {
  final Color primaryColor;
  final String title;
  final String text;

  const _InfoBox(
      {required this.primaryColor, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primaryColor.withValues(alpha: 0.12))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.rule_folder_outlined, color: primaryColor, size: 22),
        const SizedBox(width: 9),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: textBold.copyWith(color: Colors.black87, fontSize: 13.2)),
          const SizedBox(height: 4),
          Text(text,
              style: textRegular.copyWith(
                  color: Colors.grey.shade700, fontSize: 11.9, height: 1.3)),
        ])),
      ]),
    );
  }
}

class _SwitchLine extends StatelessWidget {
  final Color primaryColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchLine(
      {required this.primaryColor,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(children: [
        Icon(Icons.event_available_outlined, color: primaryColor, size: 23),
        const SizedBox(width: 10),
        Expanded(
            child: Text('store_needs_customer_scheduling'.tr,
                style: textBold.copyWith(color: Colors.black87, fontSize: 13))),
        Switch(value: value, activeColor: primaryColor, onChanged: onChanged),
      ]),
    );
  }
}

class _ServiceAdPricingCard extends StatelessWidget {
  final Color primaryColor;
  final bool isLoading;
  final bool isEditMode;
  final int availableCredits;
  final bool hasUnlimitedPlan;
  final String unlimitedPlanExpiresAt;
  final StoreServiceAdPlanOption? selectedPlan;
  final VoidCallback onChoosePlanTap;

  const _ServiceAdPricingCard({
    required this.primaryColor,
    required this.isLoading,
    required this.isEditMode,
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
        !isEditMode && !hasUnlimitedPlan && !hasCredits;
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
            ? 'store_service_credit_used_after_approval'.tr
            : hasSelectedPlan
                ? selectedPlan!.fullDescription
                : 'store_credit_used_after_approval_generic'.tr;

    return _Section(
      title: 'store_listing_credits'.tr,
      children: [
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
    );
  }
}

class _ServiceAdPlanOptionTile extends StatelessWidget {
  final Color primaryColor;
  final bool selected;
  final String title;
  final String price;
  final String description;
  final VoidCallback onTap;

  const _ServiceAdPlanOptionTile({
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

class StoreServiceAdPlanOption {
  final String id;
  final String name;
  final String slug;
  final double price;
  final int credits;
  final int billingCycleDays;
  final int adDurationDays;
  final String description;
  final bool unlimited;

  const StoreServiceAdPlanOption({
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

    if (unlimited || billingCycleDays >= 360) {
      return 'R\$$value ${'store_yearly'.tr}';
    }

    if (billingCycleDays >= 170) {
      return 'R\$$value ${'store_semiannual'.tr}';
    }

    if (billingCycleDays >= 28) {
      return 'R\$$value ${'store_monthly'.tr}';
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

  factory StoreServiceAdPlanOption.fromMap(Map<dynamic, dynamic> map) {
    final String rawName = '${map['name'] ?? ''}'.trim();
    final String rawSlug = '${map['slug'] ?? ''}'.trim();
    final int adLimit = parseIntValue(
      map['ad_limit'] ??
          map['credits'] ??
          map['credit_amount'] ??
          map['service_limit'] ??
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

    return StoreServiceAdPlanOption(
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

class _SecurityCard extends StatelessWidget {
  final Color primaryColor;

  const _SecurityCard({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: primaryColor.withValues(alpha: 0.12))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.verified_user_outlined,
                color: primaryColor, size: 23)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('store_service_safety_title'.tr,
              style: textBold.copyWith(color: Colors.black87, fontSize: 15)),
          const SizedBox(height: 6),
          Text('store_service_safety_description'.tr,
              style: textRegular.copyWith(
                  color: Colors.grey.shade700, fontSize: 12.4, height: 1.35)),
        ])),
      ]),
    );
  }
}

class _TermsCard extends StatelessWidget {
  final Color primaryColor;
  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;

  const _TermsCard(
      {required this.primaryColor,
      required this.accepted,
      required this.onChanged,
      required this.onOpenTerms});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Checkbox(
            value: accepted,
            activeColor: primaryColor,
            onChanged: (value) => onChanged(value ?? false)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(children: [
              Text('store_terms_accept_prefix'.tr,
                  style: textRegular.copyWith(
                      color: Colors.grey.shade700,
                      fontSize: 12.4,
                      height: 1.28)),
              GestureDetector(
                  onTap: onOpenTerms,
                  child: Text('store_service_terms_title'.tr,
                      style: textBold.copyWith(
                          color: primaryColor, fontSize: 12.4, height: 1.28))),
              Text('store_terms_accept_suffix_lokally'.tr,
                  style: textRegular.copyWith(
                      color: Colors.grey.shade700,
                      fontSize: 12.4,
                      height: 1.28)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final Color primaryColor;
  final bool loading;
  final String text;
  final VoidCallback onTap;

  const _SubmitButton(
      {required this.primaryColor,
      required this.loading,
      required this.text,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primaryColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          height: 52,
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.3, color: Colors.white))
              : Text(text,
                  style:
                      textBold.copyWith(color: Colors.white, fontSize: 14.2)),
        ),
      ),
    );
  }
}

class StoreServiceCategoryOption {
  final String id;
  final String parentId;
  final String name;
  final String slug;
  final String description;
  final String? imageUrl;
  final int sortOrder;
  final bool hasChildren;
  final bool selectable;
  final bool isVirtual;
  final String? realCategoryId;
  final String sourcePath;

  const StoreServiceCategoryOption(
      {required this.id,
      required this.parentId,
      required this.name,
      required this.slug,
      required this.description,
      required this.imageUrl,
      required this.sortOrder,
      required this.hasChildren,
      required this.selectable,
      required this.isVirtual,
      required this.realCategoryId,
      required this.sourcePath});

  factory StoreServiceCategoryOption.fromMap(Map<String, dynamic> map) {
    final String imageUrl = '${map['image_url'] ?? ''}'.trim();
    final String realCategoryId = '${map['real_category_id'] ?? ''}'.trim();

    return StoreServiceCategoryOption(
      id: '${map['id'] ?? ''}'.trim(),
      parentId: '${map['parent_id'] ?? ''}'.trim(),
      name: '${map['name'] ?? ''}'.trim(),
      slug: '${map['slug'] ?? ''}'.trim(),
      description: '${map['description'] ?? ''}'.trim(),
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      sortOrder: int.tryParse('${map['sort_order'] ?? 0}') ?? 0,
      hasChildren: parseMapBool(map['has_children']),
      selectable: parseMapBool(map['selectable'],
          fallback: !parseMapBool(map['has_children'])),
      isVirtual: parseMapBool(map['is_virtual']),
      realCategoryId: realCategoryId.isEmpty ? null : realCategoryId,
      sourcePath: '${map['source_path'] ?? ''}'.trim(),
    );
  }

  static bool parseMapBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String normalized = '$value'.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'null') return fallback;

    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'sim' ||
        normalized == 'yes' ||
        normalized == 'on';
  }
}

class _CategoryStackEntry {
  final String title;
  final String? parentId;
  final List<StoreServiceCategoryOption> items;

  const _CategoryStackEntry({
    required this.title,
    required this.parentId,
    required this.items,
  });
}

class _DeliveryOption {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;

  const _DeliveryOption(this.value, this.title, this.subtitle, this.icon);
}
