import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreSellerProductsScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProduct;

  const StoreSellerProductsScreen({
    super.key,
    this.initialProduct,
  });

  @override
  State<StoreSellerProductsScreen> createState() =>
      _StoreSellerProductsScreenState();
}

class _StoreSellerProductsScreenState extends State<StoreSellerProductsScreen> {
  static const String storeCategoriesUri = '/api/store/categories';
  static const String storeProductCreateUri = '/api/customer/store/product';

  static String storeProductUpdateUri(String productId) {
    return '/api/customer/store/product/$productId/update';
  }

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController promotionalPriceController =
      TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController shortDescriptionController =
      TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController skuController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController costPriceController = TextEditingController();
  final TextEditingController minStockController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController brandController = TextEditingController();
  final TextEditingController validityController = TextEditingController();
  final TextEditingController genderController = TextEditingController();
  final TextEditingController shippingWidthController = TextEditingController();
  final TextEditingController shippingLengthController =
      TextEditingController();
  final TextEditingController shippingDepthController = TextEditingController();
  final TextEditingController shippingWeightController =
      TextEditingController();

  bool isLoadingCategories = false;
  bool isSubmitting = false;

  String selectedAvailabilityType = 'immediate';
  String selectedConditionType = 'new';
  String selectedCommissionPlanSlug = '';
  bool deliveryImmediate = true;
  bool deliveryFull24h = false;
  bool deliveryLokallyBr = false;
  bool manageStock = true;
  bool acceptedTerms = false;
  String selectedWeightUnit = 'g';

  List<StoreCategoryOption> categories = [];
  StoreCategoryOption? selectedMainCategory;
  StoreCategoryOption? selectedSubcategory;
  XFile? selectedImage;
  final List<XFile> selectedGalleryImages = <XFile>[];
  List<StoreProductGalleryImageData> existingGalleryImages =
      <StoreProductGalleryImageData>[];
  String? existingImageUrl;
  String? editingCategoryId;
  String? editingSubcategoryId;

  @override
  void initState() {
    super.initState();
    applyInitialProduct();
    loadCategories();
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    promotionalPriceController.dispose();
    stockController.dispose();
    shortDescriptionController.dispose();
    descriptionController.dispose();
    skuController.dispose();
    barcodeController.dispose();
    costPriceController.dispose();
    minStockController.dispose();
    unitController.dispose();
    brandController.dispose();
    validityController.dispose();
    genderController.dispose();
    shippingWidthController.dispose();
    shippingLengthController.dispose();
    shippingDepthController.dispose();
    shippingWeightController.dispose();
    super.dispose();
  }

  bool get isEditMode {
    final Map<String, dynamic>? product = widget.initialProduct;

    if (product == null) {
      return false;
    }

    return '${product['id'] ?? ''}'.trim().isNotEmpty;
  }

  String get editingProductId {
    return '${widget.initialProduct?['id'] ?? ''}'.trim();
  }

  String get primaryAvailabilityType {
    if (deliveryImmediate) {
      return 'immediate';
    }

    if (deliveryFull24h) {
      return 'within_24h';
    }

    if (deliveryLokallyBr) {
      return 'lokally_br';
    }

    return 'immediate';
  }

  void applyInitialProduct() {
    final Map<String, dynamic>? product = widget.initialProduct;

    if (product == null) {
      return;
    }

    nameController.text = '${product['name'] ?? ''}'.trim();
    skuController.text = '${product['sku'] ?? ''}'.trim();
    barcodeController.text = '${product['barcode'] ?? ''}'.trim();
    priceController.text = formatMoneyForInput(product['price']);
    promotionalPriceController.text = formatMoneyForInput(product['old_price']);
    costPriceController.text = formatMoneyForInput(product['cost_price']);
    stockController.text = '${product['stock'] ?? ''}'.trim();
    minStockController.text = '${product['min_stock'] ?? ''}'.trim();
    unitController.text = '${product['unit'] ?? 'unidade'}'.trim();
    shortDescriptionController.text =
        '${product['short_description'] ?? ''}'.trim();
    descriptionController.text = '${product['description'] ?? ''}'.trim();
    brandController.text =
        '${product['brand'] ?? product['marca'] ?? ''}'.trim();
    validityController.text =
        '${product['validity'] ?? product['validade'] ?? ''}'.trim();
    genderController.text =
        '${product['gender'] ?? product['genero'] ?? ''}'.trim();
    shippingWidthController.text = formatDecimalForInput(
      product['package_width_cm'] ??
          product['shipping_width_cm'] ??
          product['width_cm'],
    );
    shippingLengthController.text = formatDecimalForInput(
      product['package_length_cm'] ??
          product['shipping_length_cm'] ??
          product['length_cm'],
    );
    shippingDepthController.text = formatDecimalForInput(
      product['package_height_cm'] ??
          product['shipping_height_cm'] ??
          product['shipping_depth_cm'] ??
          product['depth_cm'],
    );

    final double? packageWeightKg = parseFlexibleDouble(
      product['package_weight_kg'] ??
          product['shipping_weight'] ??
          product['weight'],
    );

    if (packageWeightKg != null && packageWeightKg > 0) {
      if (packageWeightKg < 1) {
        selectedWeightUnit = 'g';
        shippingWeightController.text =
            formatDecimalForInput(packageWeightKg * 1000, forceInteger: true);
      } else {
        selectedWeightUnit = 'kg';
        shippingWeightController.text = formatDecimalForInput(packageWeightKg);
      }
    } else {
      selectedWeightUnit = 'g';
      shippingWeightController.text = '';
    }

    final String availability =
        '${product['availability_type'] ?? 'immediate'}'.trim();

    deliveryImmediate = parseBool(
          product['allow_pickup'] ?? product['delivery_immediate'],
        ) ||
        availability == 'immediate';
    deliveryFull24h = parseBool(
          product['allow_lokally_shipping'] ?? product['delivery_full_24h'],
        ) ||
        availability == 'within_24h';
    deliveryLokallyBr = parseBool(
          product['allow_national_shipping'] ?? product['delivery_lokally_br'],
        ) ||
        availability == 'lokally_br';

    if (!deliveryImmediate && !deliveryFull24h && !deliveryLokallyBr) {
      deliveryImmediate = true;
    }

    manageStock = parseBool(product['manage_stock'], fallback: true);

    selectedAvailabilityType = primaryAvailabilityType;

    final String conditionType =
        '${product['condition_type'] ?? 'new'}'.trim().toLowerCase();
    selectedConditionType = conditionType == 'used' ? 'used' : 'new';

    selectedCommissionPlanSlug =
        '${product['marketplace_sale_fee_type'] ?? product['marketplace_ad_plan_slug'] ?? ''}'
            .trim();

    acceptedTerms = true;

    final String imageUrl = '${product['main_image_url'] ?? ''}'.trim();
    existingImageUrl = imageUrl.isNotEmpty ? imageUrl : null;

    existingGalleryImages = parseExistingGalleryImages(product);

    final String categoryId = '${product['category_id'] ?? ''}'.trim();
    final String subcategoryId = '${product['subcategory_id'] ?? ''}'.trim();
    editingCategoryId = categoryId.isNotEmpty ? categoryId : null;
    editingSubcategoryId = subcategoryId.isNotEmpty ? subcategoryId : null;
  }

  List<StoreProductGalleryImageData> parseExistingGalleryImages(
    Map<String, dynamic> product,
  ) {
    final dynamic imagesValue = product['images'] ?? product['gallery'];

    if (imagesValue is! List) {
      return <StoreProductGalleryImageData>[];
    }

    final List<StoreProductGalleryImageData> parsed =
        <StoreProductGalleryImageData>[];

    for (final dynamic item in imagesValue) {
      if (item is Map) {
        final StoreProductGalleryImageData image =
            StoreProductGalleryImageData.fromMap(
                Map<String, dynamic>.from(item));

        if (image.url.isNotEmpty) {
          parsed.add(image);
        }
        continue;
      }

      final String url = '$item'.trim();
      if (url.isNotEmpty) {
        parsed.add(
            StoreProductGalleryImageData(id: '', url: url, isPrimary: false));
      }
    }

    return parsed;
  }

  bool isBlockedProductCategoryName(String value) {
    final String normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('é', 'e')
        .replaceAll('á', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('õ', 'o');

    if (normalized.isEmpty) {
      return true;
    }

    return normalized == 'todos' ||
        normalized == 'todo' ||
        normalized.contains('servico') ||
        normalized.contains('imovel') ||
        normalized.contains('veiculo') ||
        normalized.contains('carro') ||
        normalized.contains('moto');
  }

  List<StoreCategoryOption> get productMainCategories {
    return categories.where((category) {
      return category.parentId == null &&
          !isBlockedProductCategoryName(category.name) &&
          !isBlockedProductCategoryName(category.slug);
    }).toList();
  }

  List<StoreCategoryOption> get availableSubcategories {
    final StoreCategoryOption? mainCategory = selectedMainCategory;

    if (mainCategory == null) {
      return <StoreCategoryOption>[];
    }

    return categories.where((category) {
      return category.parentId == mainCategory.id &&
          !isBlockedProductCategoryName(category.name) &&
          !isBlockedProductCategoryName(category.slug);
    }).toList();
  }

  String formatMoneyForInput(dynamic value) {
    final double? amount = parseFlexibleDouble(value);

    if (amount == null || amount <= 0) {
      return '';
    }

    return formatDecimalForInput(amount, decimalPlaces: 2);
  }

  double? parseFlexibleDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    String cleanValue = '$value'.trim();

    if (cleanValue.isEmpty || cleanValue == 'null') {
      return null;
    }

    cleanValue = cleanValue.replaceAll('R\$', '').replaceAll(' ', '');
    cleanValue = cleanValue.replaceAll(RegExp(r'[^0-9,.-]'), '');

    if (cleanValue.contains(',') && cleanValue.contains('.')) {
      cleanValue = cleanValue.replaceAll('.', '').replaceAll(',', '.');
    } else if (cleanValue.contains(',')) {
      cleanValue = cleanValue.replaceAll('.', '').replaceAll(',', '.');
    }

    return double.tryParse(cleanValue);
  }

  bool parseBool(dynamic value, {bool fallback = false}) {
    if (value == null) {
      return fallback;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final String normalized = '$value'.trim().toLowerCase();

    if (normalized.isEmpty || normalized == 'null') {
      return fallback;
    }

    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'sim' ||
        normalized == 'yes' ||
        normalized == 'on';
  }

  String formatDecimalForInput(
    dynamic value, {
    int decimalPlaces = 2,
    bool forceInteger = false,
  }) {
    final double? amount = parseFlexibleDouble(value);

    if (amount == null || amount <= 0) {
      return '';
    }

    if (forceInteger || amount == amount.roundToDouble()) {
      return amount.round().toString();
    }

    String formatted =
        amount.toStringAsFixed(decimalPlaces).replaceAll('.', ',');

    while (formatted.contains(',') && formatted.endsWith('0')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }

    if (formatted.endsWith(',')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }

    return formatted;
  }

  Future<void> loadCategories() async {
    if (isLoadingCategories) {
      return;
    }

    setState(() {
      isLoadingCategories = true;
    });

    final Response response =
        await Get.find<ApiClient>().getData(storeCategoriesUri);

    if (!mounted) {
      return;
    }

    setState(() {
      isLoadingCategories = false;
    });

    final dynamic body = response.body;

    if (response.statusCode != 200 || body is! Map || body['status'] != true) {
      showStoreMessage('store_product_categories_load_error'.tr);
      return;
    }

    final dynamic dataValue = body['data'];
    final List<dynamic> data = dataValue is List ? dataValue : <dynamic>[];

    final List<StoreCategoryOption> parsed = <StoreCategoryOption>[];

    for (final dynamic item in data) {
      if (item is! Map) {
        continue;
      }

      final Map<String, dynamic> parentMap = Map<String, dynamic>.from(item);
      final StoreCategoryOption parent = StoreCategoryOption.fromMap(parentMap);

      if (parent.id.isEmpty ||
          isBlockedProductCategoryName(parent.name) ||
          isBlockedProductCategoryName(parent.slug)) {
        continue;
      }

      parsed.add(parent);

      final dynamic subcategoriesValue = item['subcategories'];
      final List<dynamic> subcategories =
          subcategoriesValue is List ? subcategoriesValue : <dynamic>[];

      for (final dynamic subItem in subcategories) {
        if (subItem is! Map) {
          continue;
        }

        final StoreCategoryOption subcategory = StoreCategoryOption.fromMap(
          Map<String, dynamic>.from(subItem),
          parentName: parent.name,
          parentId: parent.id,
        );

        if (subcategory.id.isEmpty ||
            isBlockedProductCategoryName(subcategory.name) ||
            isBlockedProductCategoryName(subcategory.slug)) {
          continue;
        }

        parsed.add(subcategory);
      }
    }

    StoreCategoryOption? matchedMainCategory;
    StoreCategoryOption? matchedSubcategory;

    if (editingSubcategoryId != null && editingSubcategoryId!.isNotEmpty) {
      for (final StoreCategoryOption category in parsed) {
        if (category.id == editingSubcategoryId && category.parentId != null) {
          matchedSubcategory = category;
          break;
        }
      }
    }

    if (matchedSubcategory != null) {
      for (final StoreCategoryOption category in parsed) {
        if (category.id == matchedSubcategory.parentId) {
          matchedMainCategory = category;
          break;
        }
      }
    } else if (editingCategoryId != null && editingCategoryId!.isNotEmpty) {
      for (final StoreCategoryOption category in parsed) {
        if (category.id == editingCategoryId) {
          if (category.parentId == null) {
            matchedMainCategory = category;
          } else {
            matchedSubcategory = category;
            for (final StoreCategoryOption parent in parsed) {
              if (parent.id == category.parentId) {
                matchedMainCategory = parent;
                break;
              }
            }
          }
          break;
        }
      }
    }

    setState(() {
      categories = parsed;
      selectedMainCategory = matchedMainCategory;
      selectedSubcategory = matchedSubcategory;
    });
  }

  Future<void> pickProductImage() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );

    if (image == null) {
      return;
    }

    setState(() {
      selectedImage = image;
    });
  }

  Future<void> pickProductGalleryImages() async {
    final int remaining = 10 - selectedGalleryImages.length;

    if (remaining <= 0) {
      showStoreMessage('store_extra_images_limit_reached'.tr);
      return;
    }

    final List<XFile> images = await ImagePicker().pickMultiImage(
      imageQuality: 82,
    );

    if (images.isEmpty) {
      return;
    }

    setState(() {
      selectedGalleryImages.addAll(images.take(remaining));
    });

    if (images.length > remaining) {
      showStoreMessage(
          'store_extra_images_added_limit'.trParams({'count': '$remaining'}));
    }
  }

  void removeSelectedGalleryImage(int index) {
    if (index < 0 || index >= selectedGalleryImages.length) {
      return;
    }

    setState(() {
      selectedGalleryImages.removeAt(index);
    });
  }

  Future<void> openMainCategorySelector() async {
    if (productMainCategories.isEmpty) {
      showStoreMessage('store_no_main_product_category_available'.tr);
      return;
    }

    final StoreCategoryOption? chosenCategory = await showCategorySelectorSheet(
      title: 'store_main_category'.tr,
      hint: 'store_main_category_search_hint'.tr,
      options: productMainCategories,
      selected: selectedMainCategory,
    );

    if (!mounted || chosenCategory == null) {
      return;
    }

    setState(() {
      selectedMainCategory = chosenCategory;
      selectedSubcategory = null;
      editingCategoryId = chosenCategory.id;
      editingSubcategoryId = null;
    });
  }

  Future<void> openSubcategorySelector() async {
    if (selectedMainCategory == null) {
      showStoreMessage('store_select_main_category_first'.tr);
      return;
    }

    final List<StoreCategoryOption> options = availableSubcategories;

    if (options.isEmpty) {
      showStoreMessage('store_category_has_no_subcategories'.tr);
      return;
    }

    final StoreCategoryOption? chosenCategory = await showCategorySelectorSheet(
      title: 'store_product_subcategory'.tr,
      hint: 'store_product_subcategory_search_hint'.tr,
      options: options,
      selected: selectedSubcategory,
    );

    if (!mounted || chosenCategory == null) {
      return;
    }

    setState(() {
      selectedSubcategory = chosenCategory;
      editingSubcategoryId = chosenCategory.id;
    });
  }

  Future<StoreCategoryOption?> showCategorySelectorSheet({
    required String title,
    required String hint,
    required List<StoreCategoryOption> options,
    required StoreCategoryOption? selected,
  }) async {
    List<StoreCategoryOption> filteredCategories = List.from(options);

    return showModalBottomSheet<StoreCategoryOption>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        final Color primaryColor = Theme.of(context).primaryColor;

        return StatefulBuilder(
          builder: (context, modalSetState) {
            void filterCategories(String value) {
              final String search = value.trim().toLowerCase();

              modalSetState(() {
                if (search.isEmpty) {
                  filteredCategories = List.from(options);
                  return;
                }

                filteredCategories = options.where((category) {
                  return category.fullName.toLowerCase().contains(search) ||
                      category.name.toLowerCase().contains(search) ||
                      category.slug.toLowerCase().contains(search) ||
                      (category.parentName ?? '')
                          .toLowerCase()
                          .contains(search);
                }).toList();
              });
            }

            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
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
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: filterCategories,
                      style: textMedium.copyWith(
                        color: Colors.black87,
                        fontSize: 13.5,
                      ),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: textRegular.copyWith(
                          color: Colors.grey.shade500,
                          fontSize: 12.8,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: primaryColor,
                          size: 21,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 13,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: primaryColor, width: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.54,
                      child: filteredCategories.isEmpty
                          ? Center(
                              child: Text(
                                'store_no_option_found'.tr,
                                style: textMedium.copyWith(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredCategories.length,
                              itemBuilder: (context, index) {
                                final StoreCategoryOption category =
                                    filteredCategories[index];
                                final bool isSelected =
                                    selected?.id == category.id;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Material(
                                    color: isSelected
                                        ? primaryColor.withValues(alpha: 0.10)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(18),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () =>
                                          Navigator.of(context).pop(category),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            12, 11, 12, 11),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: primaryColor.withValues(
                                                    alpha: 0.10),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Icon(
                                                category.parentId == null
                                                    ? Icons.category_outlined
                                                    : Icons.sell_outlined,
                                                color: primaryColor,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (category.parentName !=
                                                      null) ...[
                                                    Text(
                                                      category.parentName!,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          textRegular.copyWith(
                                                        color: Colors
                                                            .grey.shade600,
                                                        fontSize: 11.6,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                  ],
                                                  Text(
                                                    category.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: textBold.copyWith(
                                                      color: Colors.black87,
                                                      fontSize: 13.8,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isSelected)
                                              Icon(
                                                Icons.check_circle_rounded,
                                                color: primaryColor,
                                                size: 22,
                                              ),
                                          ],
                                        ),
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
          },
        );
      },
    );
  }

  Future<void> submitProduct() async {
    if (isSubmitting) {
      return;
    }

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (selectedMainCategory == null) {
      showStoreMessage('store_select_product_main_category'.tr);
      return;
    }

    if (availableSubcategories.isNotEmpty && selectedSubcategory == null) {
      showStoreMessage('store_select_product_subcategory'.tr);
      return;
    }

    if (!isEditMode && selectedImage == null) {
      showStoreMessage('store_select_product_main_image'.tr);
      return;
    }

    if (isEditMode &&
        selectedImage == null &&
        (existingImageUrl == null || existingImageUrl!.isEmpty)) {
      showStoreMessage('store_select_product_main_image'.tr);
      return;
    }

    if (!deliveryImmediate && !deliveryFull24h && !deliveryLokallyBr) {
      showStoreMessage('store_activate_delivery_or_pickup'.tr);
      return;
    }

    if (deliveryLokallyBr &&
        (shippingWidthController.text.trim().isEmpty ||
            shippingLengthController.text.trim().isEmpty ||
            shippingDepthController.text.trim().isEmpty ||
            shippingWeightController.text.trim().isEmpty)) {
      showStoreMessage('store_dimensions_weight_required_lokally_br'.tr);
      return;
    }

    if (deliveryLokallyBr) {
      final double? width = parseFlexibleDouble(shippingWidthController.text);
      final double? length = parseFlexibleDouble(shippingLengthController.text);
      final double? height = parseFlexibleDouble(shippingDepthController.text);
      final double? weight = parseFlexibleDouble(shippingWeightController.text);

      if (width == null ||
          width <= 0 ||
          length == null ||
          length <= 0 ||
          height == null ||
          height <= 0 ||
          weight == null ||
          weight <= 0) {
        showStoreMessage(
            'store_valid_dimensions_weight_required_national_shipping'.tr);
        return;
      }
    }

    if (!acceptedTerms) {
      showStoreMessage('store_confirm_lokally_shop_terms'.tr);
      return;
    }

    if (selectedCommissionPlanSlug.isEmpty) {
      final String? chosenPlan = await showProductCommissionPlanModal();

      if (!mounted || chosenPlan == null || chosenPlan.isEmpty) {
        return;
      }

      setState(() {
        selectedCommissionPlanSlug = chosenPlan;
      });
    }

    setState(() {
      isSubmitting = true;
    });

    selectedAvailabilityType = primaryAvailabilityType;

    final Map<String, String> fields = {
      'category_id': selectedMainCategory!.id,
      if (selectedSubcategory != null)
        'subcategory_id': selectedSubcategory!.id,
      'name': nameController.text.trim(),
      'sku': skuController.text.trim(),
      'barcode': barcodeController.text.trim(),
      'price': normalizeMoney(priceController.text),
      'availability_type': selectedAvailabilityType,
      'product_type': 'physical',
      'condition_type': selectedConditionType,
      'marketplace_sale_fee_type': selectedCommissionPlanSlug,
      'plan_id': selectedCommissionPlanSlug,
      'marketplace_ad_plan_id': selectedCommissionPlanSlug,
      'manage_stock': manageStock ? '1' : '0',
      'stock': stockController.text.trim().isEmpty
          ? '0'
          : stockController.text.trim(),
      'min_stock': minStockController.text.trim().isEmpty
          ? '0'
          : minStockController.text.trim(),
      'unit': unitController.text.trim().isEmpty
          ? 'unidade'
          : unitController.text.trim(),
      'service_delivery_type': '',
      'delivery_immediate': deliveryImmediate ? '1' : '0',
      'delivery_full_24h': deliveryFull24h ? '1' : '0',
      'delivery_lokally_br': deliveryLokallyBr ? '1' : '0',
      'allow_pickup': deliveryImmediate ? '1' : '0',
      'allow_lokally_shipping': deliveryFull24h ? '1' : '0',
      'allow_national_shipping': deliveryLokallyBr ? '1' : '0',
      'terms_accepted': acceptedTerms ? '1' : '0',
    };

    if (costPriceController.text.trim().isNotEmpty) {
      fields['cost_price'] = normalizeMoney(costPriceController.text);
    }

    if (deliveryLokallyBr) {
      final String width = normalizeDecimal(shippingWidthController.text);
      final String length = normalizeDecimal(shippingLengthController.text);
      final String height = normalizeDecimal(shippingDepthController.text);
      final String weightKg = normalizeWeightToKg(
        shippingWeightController.text,
        selectedWeightUnit,
      );

      fields['package_width_cm'] = width;
      fields['package_length_cm'] = length;
      fields['package_height_cm'] = height;
      fields['package_weight_kg'] = weightKg;
      fields['package_weight_unit'] = selectedWeightUnit;
      fields['shipping_width_cm'] = width;
      fields['shipping_length_cm'] = length;
      fields['shipping_depth_cm'] = height;
      fields['shipping_height_cm'] = height;
      fields['shipping_weight'] = weightKg;
    }

    if (brandController.text.trim().isNotEmpty) {
      fields['brand'] = brandController.text.trim();
    }

    if (validityController.text.trim().isNotEmpty) {
      fields['validity'] = validityController.text.trim();
    }

    if (genderController.text.trim().isNotEmpty) {
      fields['gender'] = genderController.text.trim();
    }

    if (promotionalPriceController.text.trim().isNotEmpty) {
      fields['old_price'] = normalizeMoney(promotionalPriceController.text);
    }

    if (shortDescriptionController.text.trim().isNotEmpty) {
      fields['short_description'] = shortDescriptionController.text.trim();
    }

    if (descriptionController.text.trim().isNotEmpty) {
      fields['description'] = descriptionController.text.trim();
    }

    final List<MultipartBody> galleryMultipart = selectedGalleryImages
        .map((image) => MultipartBody('images[]', image))
        .toList();

    final bool hasMultipart =
        selectedImage != null || galleryMultipart.isNotEmpty;

    final Response response;

    if (isEditMode) {
      final String uri = storeProductUpdateUri(editingProductId);

      if (!hasMultipart) {
        response = await Get.find<ApiClient>().postData(uri, fields);
      } else {
        response = await Get.find<ApiClient>().postMultipartData(
          uri,
          fields,
          MultipartBody('main_image', selectedImage),
          galleryMultipart,
        );
      }
    } else {
      response = await Get.find<ApiClient>().postMultipartData(
        storeProductCreateUri,
        fields,
        MultipartBody('main_image', selectedImage),
        galleryMultipart,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      isSubmitting = false;
    });

    final dynamic body = response.body;

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        body is Map &&
        body['status'] == true) {
      if (isEditMode) {
        showStoreMessage('store_product_updated_sent_approval'.tr);
        Get.back();
        return;
      }

      clearForm();
      showStoreMessage('store_product_created_sent_approval'.tr);
      return;
    }

    String message = isEditMode
        ? 'store_product_update_error'.tr
        : 'store_product_create_error'.tr;

    if (body is Map && body['message'] != null) {
      message = body['message'].toString();
    }

    showStoreMessage(message);
  }

  String normalizeMoney(String value) {
    final double? amount = parseFlexibleDouble(value);

    if (amount == null) {
      return '';
    }

    return amount.toStringAsFixed(2);
  }

  String normalizeDecimal(String value, {int decimalPlaces = 2}) {
    final double? amount = parseFlexibleDouble(value);

    if (amount == null) {
      return '';
    }

    return amount.toStringAsFixed(decimalPlaces);
  }

  String normalizeWeightToKg(String value, String unit) {
    final double? amount = parseFlexibleDouble(value);

    if (amount == null) {
      return '';
    }

    final double weightKg = unit == 'g' ? amount / 1000 : amount;

    return weightKg.toStringAsFixed(3);
  }

  void clearForm() {
    nameController.clear();
    priceController.clear();
    promotionalPriceController.clear();
    stockController.clear();
    shortDescriptionController.clear();
    descriptionController.clear();
    skuController.clear();
    barcodeController.clear();
    costPriceController.clear();
    minStockController.clear();
    unitController.clear();
    brandController.clear();
    validityController.clear();
    genderController.clear();
    shippingWidthController.clear();
    shippingLengthController.clear();
    shippingDepthController.clear();
    shippingWeightController.clear();

    setState(() {
      selectedMainCategory = null;
      selectedSubcategory = null;
      selectedImage = null;
      selectedGalleryImages.clear();
      existingGalleryImages = <StoreProductGalleryImageData>[];
      existingImageUrl = null;
      editingCategoryId = null;
      editingSubcategoryId = null;
      selectedAvailabilityType = 'immediate';
      selectedConditionType = 'new';
      selectedCommissionPlanSlug = '';
      deliveryImmediate = true;
      deliveryFull24h = false;
      deliveryLokallyBr = false;
      manageStock = true;
      selectedWeightUnit = 'g';
      acceptedTerms = false;
    });
  }

  Future<String?> showProductCommissionPlanModal() async {
    final Color primaryColor = Theme.of(context).primaryColor;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'store_choose_product_ad_payment'.tr,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 18,
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
                StoreProductCommissionPlanOption(
                  primaryColor: primaryColor,
                  title: 'store_product_commission_15_title',
                  description: 'store_product_commission_15_description',
                  onTap: () =>
                      Navigator.of(context).pop('product-commission-15'),
                ),
                const SizedBox(height: 10),
                StoreProductCommissionPlanOption(
                  primaryColor: primaryColor,
                  title: 'store_product_commission_18_title',
                  description: 'store_product_commission_18_description',
                  onTap: () =>
                      Navigator.of(context).pop('product-commission-18'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showProductTermsModal() {
    final Color primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'store_lokally_shop_terms_title'.tr,
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
                const SizedBox(height: 12),
                Text(
                  'store_lokally_shop_terms_description'.tr,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.38,
                  ),
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
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'store_understood'.tr,
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

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          StoreProductsTopBar(
            primaryColor: primaryColor,
            title: isEditMode ? 'store_edit_product' : 'store_register_product',
            onBackTap: () => Get.back(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Dimensions.paddingSizeDefault,
                22,
                Dimensions.paddingSizeDefault,
                30,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StoreImagePickerCard(
                      primaryColor: primaryColor,
                      selectedImage: selectedImage,
                      selectedGalleryImages: selectedGalleryImages,
                      existingImageUrl: existingImageUrl,
                      existingGalleryImages: existingGalleryImages,
                      onMainImageTap: pickProductImage,
                      onAddGalleryTap: pickProductGalleryImages,
                      onRemoveGalleryImage: removeSelectedGalleryImage,
                    ),
                    const SizedBox(height: 14),
                    StoreSellerFormCard(
                      primaryColor: primaryColor,
                      children: [
                        StoreTextInput(
                          label: 'store_product_name',
                          hint: 'store_product_name_hint',
                          controller: nameController,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'store_product_name_required'.tr;
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        StoreCategorySelectorField(
                          primaryColor: primaryColor,
                          label: 'store_main_category',
                          placeholder: 'store_main_category_product_hint',
                          selectedCategory: selectedMainCategory,
                          isLoading: isLoadingCategories,
                          onTap: openMainCategorySelector,
                        ),
                        const SizedBox(height: 12),
                        StoreCategorySelectorField(
                          primaryColor: primaryColor,
                          label: 'store_product_subcategory',
                          placeholder: selectedMainCategory == null
                              ? 'store_choose_main_category_first'
                              : 'store_product_subcategory_hint',
                          selectedCategory: selectedSubcategory,
                          isLoading: isLoadingCategories,
                          onTap: openSubcategorySelector,
                        ),
                        const SizedBox(height: 12),
                        StoreConditionSelector(
                          primaryColor: primaryColor,
                          selectedConditionType: selectedConditionType,
                          onChanged: (value) {
                            setState(() {
                              selectedConditionType = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StoreTextInput(
                                label: 'SKU',
                                hint: 'store_internal_code',
                                controller: skuController,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StoreTextInput(
                                label: 'store_barcode',
                                hint: 'store_optional',
                                controller: barcodeController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StoreTextInput(
                                label: 'store_sale_price',
                                hint: '89,90',
                                controller: priceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'store_price_required'.tr;
                                  }

                                  final double? parsed = double.tryParse(
                                    normalizeMoney(value),
                                  );

                                  if (parsed == null || parsed <= 0) {
                                    return 'store_invalid_price'.tr;
                                  }

                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StoreTextInput(
                                label: 'store_promotional_price',
                                hint: '79,90',
                                controller: promotionalPriceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        StoreTextInput(
                          label: 'store_internal_cost',
                          hint: 'store_optional',
                          controller: costPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StoreAvailabilitySelector(
                          primaryColor: primaryColor,
                          deliveryImmediate: deliveryImmediate,
                          deliveryFull24h: deliveryFull24h,
                          deliveryLokallyBr: deliveryLokallyBr,
                          onImmediateChanged: (value) {
                            setState(() {
                              deliveryImmediate = value;
                            });
                          },
                          onFull24hChanged: (value) {
                            setState(() {
                              deliveryFull24h = value;
                            });
                          },
                          onLokallyBrChanged: (value) {
                            setState(() {
                              deliveryLokallyBr = value;
                            });
                          },
                        ),
                        if (deliveryLokallyBr) ...[
                          const SizedBox(height: 12),
                          StoreLokallyBrDimensionsFields(
                            widthController: shippingWidthController,
                            lengthController: shippingLengthController,
                            depthController: shippingDepthController,
                            weightController: shippingWeightController,
                            selectedWeightUnit: selectedWeightUnit,
                            onWeightUnitChanged: (value) {
                              setState(() {
                                selectedWeightUnit = value;
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StoreTextInput(
                                label: 'store_available_stock',
                                hint: '10',
                                controller: stockController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StoreTextInput(
                                label: 'store_minimum_stock',
                                hint: '0',
                                controller: minStockController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        StoreTextInput(
                          label: 'store_unit',
                          hint: 'store_unit_hint',
                          controller: unitController,
                        ),
                        const SizedBox(height: 12),
                        StoreManageStockSwitch(
                          primaryColor: primaryColor,
                          enabled: manageStock,
                          onChanged: (value) {
                            setState(() {
                              manageStock = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        StoreTextInput(
                          label: 'store_short_description',
                          hint: 'store_product_short_description_hint',
                          controller: shortDescriptionController,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        StoreProductCharacteristicsFields(
                          brandController: brandController,
                          validityController: validityController,
                          genderController: genderController,
                        ),
                        const SizedBox(height: 12),
                        StoreTextInput(
                          label: 'store_full_description',
                          hint: 'store_product_full_description_hint',
                          controller: descriptionController,
                          maxLines: 5,
                        ),
                        const SizedBox(height: 14),
                        StoreTermsAgreement(
                          primaryColor: primaryColor,
                          accepted: acceptedTerms,
                          onChanged: (value) {
                            setState(() {
                              acceptedTerms = value;
                            });
                          },
                          onOpenTerms: showProductTermsModal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StoreSubmitProductButton(
                      primaryColor: primaryColor,
                      isLoading: isSubmitting,
                      buttonText: selectedCommissionPlanSlug.isEmpty
                          ? 'store_choose_listing_plan'
                          : isEditMode
                              ? 'store_resend_for_review'
                              : 'store_send_for_approval',
                      onTap: submitProduct,
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

class StoreProductsTopBar extends StatelessWidget {
  final Color primaryColor;
  final String title;
  final VoidCallback onBackTap;

  const StoreProductsTopBar({
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
              title.tr,
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

class StoreProductIntroCard extends StatelessWidget {
  final Color primaryColor;
  final bool isEditMode;

  const StoreProductIntroCard({
    super.key,
    required this.primaryColor,
    required this.isEditMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        isEditMode
            ? 'store_product_edit_intro_description'.tr
            : 'store_product_create_intro_description'.tr,
        style: textRegular.copyWith(
          color: Colors.grey.shade700,
          fontSize: 14,
          height: 1.35,
        ),
      ),
    );
  }
}

class StoreImagePickerCard extends StatelessWidget {
  final Color primaryColor;
  final XFile? selectedImage;
  final List<XFile> selectedGalleryImages;
  final String? existingImageUrl;
  final List<StoreProductGalleryImageData> existingGalleryImages;
  final VoidCallback onMainImageTap;
  final VoidCallback onAddGalleryTap;
  final ValueChanged<int> onRemoveGalleryImage;

  const StoreImagePickerCard({
    super.key,
    required this.primaryColor,
    required this.selectedImage,
    required this.selectedGalleryImages,
    required this.existingImageUrl,
    required this.existingGalleryImages,
    required this.onMainImageTap,
    required this.onAddGalleryTap,
    required this.onRemoveGalleryImage,
  });

  bool get hasExistingImage {
    return existingImageUrl != null && existingImageUrl!.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final int savedExtras =
        existingGalleryImages.where((image) => !image.isPrimary).length;
    final int totalExtras = savedExtras + selectedGalleryImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'store_product_images'.tr,
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 18,
                ),
              ),
            ),
            Text(
              'store_extra_images_count'.trParams({
                'count': '$totalExtras',
              }),
              style: textBold.copyWith(
                color: primaryColor,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'store_product_images_description'.tr,
          style: textRegular.copyWith(
            color: Colors.grey.shade600,
            fontSize: 13,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 13),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onMainImageTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: selectedImage == null && !hasExistingImage
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: primaryColor,
                          size: 38,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'store_add_main_image'.tr,
                          style: textBold.copyWith(
                            color: Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'store_product_cover_note'.tr,
                          style: textRegular.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: selectedImage != null
                                ? Image.file(File(selectedImage!.path),
                                    fit: BoxFit.cover)
                                : Image.network(
                                    existingImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) {
                                      return Container(
                                        color: primaryColor.withValues(
                                            alpha: 0.08),
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: primaryColor,
                                          size: 34,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: StoreImageOverlayLabel(
                              primaryColor: primaryColor,
                              text: 'store_change_cover',
                              icon: Icons.photo_camera_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            ...existingGalleryImages.where((image) => !image.isPrimary).map(
                  (image) => StoreExistingGalleryThumb(
                    image: image,
                    primaryColor: primaryColor,
                  ),
                ),
            ...List.generate(selectedGalleryImages.length, (index) {
              return StoreSelectedGalleryThumb(
                image: selectedGalleryImages[index],
                primaryColor: primaryColor,
                onRemove: () => onRemoveGalleryImage(index),
              );
            }),
            StoreAddGalleryImageButton(
              primaryColor: primaryColor,
              onTap: onAddGalleryTap,
            ),
          ],
        ),
      ],
    );
  }
}

class StoreImageOverlayLabel extends StatelessWidget {
  final Color primaryColor;
  final String text;
  final IconData icon;

  const StoreImageOverlayLabel({
    super.key,
    required this.primaryColor,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primaryColor, size: 15),
          const SizedBox(width: 5),
          Text(
            text.tr,
            style: textBold.copyWith(color: primaryColor, fontSize: 11.3),
          ),
        ],
      ),
    );
  }
}

class StoreExistingGalleryThumb extends StatelessWidget {
  final StoreProductGalleryImageData image;
  final Color primaryColor;

  const StoreExistingGalleryThumb({
    super.key,
    required this.image,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                image.url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: primaryColor.withValues(alpha: 0.08),
                    child: Icon(Icons.image_not_supported_outlined,
                        color: primaryColor, size: 22),
                  );
                },
              ),
            ),
            Positioned(
              left: 5,
              bottom: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'store_saved'.tr,
                  style: textBold.copyWith(color: Colors.white, fontSize: 9.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreSelectedGalleryThumb extends StatelessWidget {
  final XFile image;
  final Color primaryColor;
  final VoidCallback onRemove;

  const StoreSelectedGalleryThumb({
    super.key,
    required this.image,
    required this.primaryColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          children: [
            Positioned.fill(
                child: Image.file(File(image.path), fit: BoxFit.cover)),
            Positioned(
              right: 4,
              top: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreAddGalleryImageButton extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreAddGalleryImageButton({
    super.key,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primaryColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: primaryColor.withValues(alpha: 0.20)),
          ),
          child: Icon(Icons.add_photo_alternate_outlined,
              color: primaryColor, size: 25),
        ),
      ),
    );
  }
}

class StoreSellerFormCard extends StatelessWidget {
  final Color primaryColor;
  final List<Widget> children;

  const StoreSellerFormCard({
    super.key,
    required this.primaryColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class StoreTextInput extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  const StoreTextInput({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.tr,
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 14.2,
          ),
        ),
        const SizedBox(height: 9),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: textMedium.copyWith(
            color: Colors.black87,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint.tr,
            hintStyle: textRegular.copyWith(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 1.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ),
      ],
    );
  }
}

class StoreCategorySelectorField extends StatelessWidget {
  final Color primaryColor;
  final String label;
  final String placeholder;
  final StoreCategoryOption? selectedCategory;
  final bool isLoading;
  final VoidCallback onTap;

  const StoreCategorySelectorField({
    super.key,
    required this.primaryColor,
    required this.label,
    required this.placeholder,
    required this.selectedCategory,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String value =
        selectedCategory == null ? placeholder : selectedCategory!.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.tr,
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 14.2,
          ),
        ),
        const SizedBox(height: 9),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.category_outlined,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      isLoading ? 'store_loading_categories'.tr : value.tr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textMedium.copyWith(
                        color: selectedCategory == null
                            ? Colors.grey.shade500
                            : Colors.black87,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade600,
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

class StoreProductCommissionPlanOption extends StatelessWidget {
  final Color primaryColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  const StoreProductCommissionPlanOption({
    super.key,
    required this.primaryColor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primaryColor.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: primaryColor.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child:
                    Icon(Icons.percent_rounded, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.tr,
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description.tr,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade700,
                        fontSize: 12.2,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: primaryColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreConditionSelector extends StatelessWidget {
  final Color primaryColor;
  final String selectedConditionType;
  final ValueChanged<String> onChanged;

  const StoreConditionSelector({
    super.key,
    required this.primaryColor,
    required this.selectedConditionType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StoreCompactToggleSection(
      title: 'store_product_condition',
      children: [
        StoreCompactToggleOption(
          primaryColor: primaryColor,
          title: 'store_new',
          value: 'new',
          selectedValue: selectedConditionType,
          onTap: onChanged,
        ),
        StoreCompactToggleOption(
          primaryColor: primaryColor,
          title: 'store_used',
          value: 'used',
          selectedValue: selectedConditionType,
          onTap: onChanged,
        ),
      ],
    );
  }
}

class StoreServiceDeliverySelector extends StatelessWidget {
  final Color primaryColor;
  final String selectedServiceDeliveryType;
  final ValueChanged<String> onChanged;

  const StoreServiceDeliverySelector({
    super.key,
    required this.primaryColor,
    required this.selectedServiceDeliveryType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StoreOptionSelectorSection(
      title: 'store_service_format',
      children: [
        StoreAvailabilityOption(
          primaryColor: primaryColor,
          title: 'store_online',
          description: 'store_online_service_description',
          value: 'online',
          selectedValue: selectedServiceDeliveryType,
          onTap: onChanged,
        ),
        StoreAvailabilityOption(
          primaryColor: primaryColor,
          title: 'store_download',
          description: 'store_download_service_description',
          value: 'download',
          selectedValue: selectedServiceDeliveryType,
          onTap: onChanged,
        ),
        StoreAvailabilityOption(
          primaryColor: primaryColor,
          title: 'store_presential',
          description: 'store_presential_service_description',
          value: 'presential',
          selectedValue: selectedServiceDeliveryType,
          onTap: onChanged,
        ),
        StoreAvailabilityOption(
          primaryColor: primaryColor,
          title: 'store_home_office',
          description: 'store_remote_service_description',
          value: 'home_office',
          selectedValue: selectedServiceDeliveryType,
          onTap: onChanged,
        ),
      ],
    );
  }
}

class StoreOptionSelectorSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const StoreOptionSelectorSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    const double gap = 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.tr,
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 12.8,
          ),
        ),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (context, constraints) {
            final double itemWidth = (constraints.maxWidth - gap) / 2;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: children
                  .map(
                    (child) => SizedBox(
                      width: itemWidth,
                      child: child,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class StoreAvailabilitySelector extends StatelessWidget {
  final Color primaryColor;
  final bool deliveryImmediate;
  final bool deliveryFull24h;
  final bool deliveryLokallyBr;
  final ValueChanged<bool> onImmediateChanged;
  final ValueChanged<bool> onFull24hChanged;
  final ValueChanged<bool> onLokallyBrChanged;

  const StoreAvailabilitySelector({
    super.key,
    required this.primaryColor,
    required this.deliveryImmediate,
    required this.deliveryFull24h,
    required this.deliveryLokallyBr,
    required this.onImmediateChanged,
    required this.onFull24hChanged,
    required this.onLokallyBrChanged,
  });

  void showInfo(BuildContext context, String title, String description) {
    final Color primaryColor = Theme.of(context).primaryColor;

    showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
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
                Icon(
                  Icons.info_outline_rounded,
                  color: primaryColor,
                  size: 30,
                ),
                const SizedBox(height: 10),
                Text(
                  title.tr,
                  textAlign: TextAlign.center,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description.tr,
                  textAlign: TextAlign.center,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      'store_understood'.tr,
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
    return StoreCompactToggleSection(
      title: 'store_activate_delivery_or_pickup_options',
      children: [
        StoreCompactMultiToggleOption(
          primaryColor: primaryColor,
          title: 'store_immediate',
          selected: deliveryImmediate,
          onTap: () => onImmediateChanged(!deliveryImmediate),
          onInfoTap: () => showInfo(
            context,
            'store_immediate',
            'store_immediate_option_description',
          ),
        ),
        StoreCompactMultiToggleOption(
          primaryColor: primaryColor,
          title: 'store_full_24h',
          selected: deliveryFull24h,
          onTap: () => onFull24hChanged(!deliveryFull24h),
          onInfoTap: () => showInfo(
            context,
            'store_full_24h',
            'store_full_24h_description',
          ),
        ),
        StoreCompactMultiToggleOption(
          primaryColor: primaryColor,
          title: 'Lokally BR',
          selected: deliveryLokallyBr,
          onTap: () => onLokallyBrChanged(!deliveryLokallyBr),
          onInfoTap: () => showInfo(
            context,
            'Lokally BR',
            'store_lokally_br_description',
          ),
        ),
      ],
    );
  }
}

class StoreCompactToggleSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const StoreCompactToggleSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.tr,
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 12.8,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
      ],
    );
  }
}

class StoreCompactToggleOption extends StatelessWidget {
  final Color primaryColor;
  final String title;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onTap;

  const StoreCompactToggleOption({
    super.key,
    required this.primaryColor,
    required this.title,
    required this.value,
    required this.selectedValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = value == selectedValue;

    return Material(
      color: isSelected
          ? primaryColor.withValues(alpha: 0.10)
          : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 40,
          constraints: const BoxConstraints(minWidth: 104),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey.shade200,
              width: isSelected ? 1.3 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected ? primaryColor : Colors.grey.shade500,
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                title.tr,
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreCompactMultiToggleOption extends StatelessWidget {
  final Color primaryColor;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const StoreCompactMultiToggleOption({
    super.key,
    required this.primaryColor,
    required this.title,
    required this.selected,
    required this.onTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? primaryColor.withValues(alpha: 0.10) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 42,
          padding: const EdgeInsets.only(left: 13, right: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? primaryColor : Colors.grey.shade200,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? primaryColor : Colors.grey.shade500,
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                title.tr,
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 12.8,
                ),
              ),
              const SizedBox(width: 5),
              GestureDetector(
                onTap: onInfoTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 23,
                  height: 23,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    Icons.question_mark_rounded,
                    color: primaryColor,
                    size: 14,
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

class StoreLokallyBrDimensionsFields extends StatelessWidget {
  final TextEditingController widthController;
  final TextEditingController lengthController;
  final TextEditingController depthController;
  final TextEditingController weightController;
  final String selectedWeightUnit;
  final ValueChanged<String> onWeightUnitChanged;

  const StoreLokallyBrDimensionsFields({
    super.key,
    required this.widthController,
    required this.lengthController,
    required this.depthController,
    required this.weightController,
    required this.selectedWeightUnit,
    required this.onWeightUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'store_lokally_shipping_br_dimensions'.tr,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 12.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'store_lokally_shipping_br_dimensions_description'.tr,
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 11.8,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StoreTextInput(
                  label: 'store_width',
                  hint: 'cm',
                  controller: widthController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StoreTextInput(
                  label: 'store_length',
                  hint: 'cm',
                  controller: lengthController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StoreTextInput(
                  label: 'store_height',
                  hint: 'cm',
                  controller: depthController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StoreTextInput(
                      label: 'store_weight',
                      hint: selectedWeightUnit == 'g' ? 'Ex: 10' : 'Ex: 0,5',
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: StoreWeightUnitOption(
                            primaryColor: primaryColor,
                            label: 'g',
                            value: 'g',
                            selectedValue: selectedWeightUnit,
                            onTap: onWeightUnitChanged,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: StoreWeightUnitOption(
                            primaryColor: primaryColor,
                            label: 'kg',
                            value: 'kg',
                            selectedValue: selectedWeightUnit,
                            onTap: onWeightUnitChanged,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StoreWeightUnitOption extends StatelessWidget {
  final Color primaryColor;
  final String label;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onTap;

  const StoreWeightUnitOption({
    super.key,
    required this.primaryColor,
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = value == selectedValue;

    return Material(
      color: isSelected ? primaryColor.withValues(alpha: 0.10) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey.shade300,
              width: isSelected ? 1.3 : 1,
            ),
          ),
          child: Text(
            label,
            style: textBold.copyWith(
              color: isSelected ? primaryColor : Colors.grey.shade700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}

class StoreProductCharacteristicsFields extends StatelessWidget {
  final TextEditingController brandController;
  final TextEditingController validityController;
  final TextEditingController genderController;

  const StoreProductCharacteristicsFields({
    super.key,
    required this.brandController,
    required this.validityController,
    required this.genderController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'store_characteristics'.tr,
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 12.8,
          ),
        ),
        const SizedBox(height: 8),
        StoreTextInput(
          label: 'store_brand',
          hint: 'store_brand_hint',
          controller: brandController,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StoreTextInput(
                label: 'store_validity',
                hint: 'Ex: 12/2028',
                controller: validityController,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StoreTextInput(
                label: 'store_gender',
                hint: 'store_gender_hint',
                controller: genderController,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class StoreManageStockSwitch extends StatelessWidget {
  final Color primaryColor;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const StoreManageStockSwitch({
    super.key,
    required this.primaryColor,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          enabled ? primaryColor.withValues(alpha: 0.08) : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onChanged(!enabled),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? primaryColor : Colors.grey.shade200,
              width: enabled ? 1.3 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                enabled
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: enabled ? primaryColor : Colors.grey.shade500,
                size: 21,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'store_manage_product_stock'.tr,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 12.8,
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

class StoreTermsAgreement extends StatelessWidget {
  final Color primaryColor;
  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;

  const StoreTermsAgreement({
    super.key,
    required this.primaryColor,
    required this.accepted,
    required this.onChanged,
    required this.onOpenTerms,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          accepted ? primaryColor.withValues(alpha: 0.08) : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onChanged(!accepted),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accepted ? primaryColor : Colors.grey.shade200,
              width: accepted ? 1.3 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                accepted
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: accepted ? primaryColor : Colors.grey.shade500,
                size: 21,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Wrap(
                  children: [
                    Text(
                      'store_product_terms_accept_prefix'.tr,
                      style: textMedium.copyWith(
                        color: Colors.black87,
                        fontSize: 12.4,
                        height: 1.32,
                      ),
                    ),
                    GestureDetector(
                      onTap: onOpenTerms,
                      child: Text(
                        'store_lokally_shop_terms_title'.tr,
                        style: textBold.copyWith(
                          color: primaryColor,
                          fontSize: 12.4,
                          height: 1.32,
                          decoration: TextDecoration.underline,
                          decorationColor: primaryColor,
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

class StoreAvailabilityOption extends StatelessWidget {
  final Color primaryColor;
  final String title;
  final String description;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onTap;

  const StoreAvailabilityOption({
    super.key,
    required this.primaryColor,
    required this.title,
    required this.description,
    required this.value,
    required this.selectedValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = value == selectedValue;

    return Material(
      color: isSelected
          ? primaryColor.withValues(alpha: 0.10)
          : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey.shade200,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected ? primaryColor : Colors.grey.shade500,
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                  fontSize: 10.8,
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

class StoreSubmitProductButton extends StatelessWidget {
  final Color primaryColor;
  final bool isLoading;
  final String buttonText;
  final VoidCallback onTap;

  const StoreSubmitProductButton({
    super.key,
    required this.primaryColor,
    required this.isLoading,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primaryColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : Text(
                    buttonText.tr,
                    style: textBold.copyWith(
                      color: Colors.white,
                      fontSize: 14.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class StoreCategoryOption {
  final String id;
  final String name;
  final String slug;
  final String? parentName;
  final String? parentId;

  StoreCategoryOption({
    required this.id,
    required this.name,
    required this.slug,
    required this.parentName,
    required this.parentId,
  });

  factory StoreCategoryOption.fromMap(
    Map<String, dynamic> map, {
    String? parentName,
    String? parentId,
  }) {
    return StoreCategoryOption(
      id: '${map['id'] ?? ''}'.trim(),
      name: '${map['name'] ?? ''}'.trim(),
      slug: '${map['slug'] ?? ''}'.trim(),
      parentName: parentName,
      parentId: parentId,
    );
  }

  String get fullName {
    if (parentName == null || parentName!.trim().isEmpty) {
      return name;
    }

    return '$parentName > $name';
  }
}

class StoreProductGalleryImageData {
  final String id;
  final String url;
  final bool isPrimary;

  StoreProductGalleryImageData({
    required this.id,
    required this.url,
    required this.isPrimary,
  });

  factory StoreProductGalleryImageData.fromMap(Map<String, dynamic> map) {
    return StoreProductGalleryImageData(
      id: '${map['id'] ?? ''}'.trim(),
      url: '${map['image_url'] ?? map['url'] ?? map['full_url'] ?? ''}'.trim(),
      isPrimary: '${map['is_primary'] ?? ''}' == '1' ||
          map['is_primary'] == true ||
          '${map['type'] ?? ''}'.toLowerCase() == 'primary',
    );
  }
}
