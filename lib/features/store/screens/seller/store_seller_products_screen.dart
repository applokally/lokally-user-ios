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
  final TextEditingController serviceDeliveryTimeController =
      TextEditingController();

  bool isLoadingCategories = false;
  bool isSubmitting = false;

  String selectedAvailabilityType = 'immediate';
  String selectedProductType = 'physical';
  String selectedConditionType = 'new';
  String selectedServiceDeliveryType = 'online';

  List<StoreCategoryOption> categories = [];
  StoreCategoryOption? selectedCategory;
  XFile? selectedImage;
  String? existingImageUrl;
  String? editingCategoryId;

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
    serviceDeliveryTimeController.dispose();
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

  void applyInitialProduct() {
    final Map<String, dynamic>? product = widget.initialProduct;

    if (product == null) {
      return;
    }

    nameController.text = '${product['name'] ?? ''}'.trim();
    priceController.text = formatMoneyForInput(product['price']);
    promotionalPriceController.text = formatMoneyForInput(product['old_price']);
    stockController.text = '${product['stock'] ?? ''}'.trim();
    shortDescriptionController.text =
        '${product['short_description'] ?? ''}'.trim();
    descriptionController.text = '${product['description'] ?? ''}'.trim();

    final String availability =
        '${product['availability_type'] ?? 'immediate'}'.trim();
    selectedAvailabilityType =
        availability == 'within_24h' ? 'within_24h' : 'immediate';

    final String productType =
        '${product['product_type'] ?? 'physical'}'.trim().toLowerCase();
    selectedProductType = productType == 'service' ? 'service' : 'physical';

    final String conditionType =
        '${product['condition_type'] ?? 'new'}'.trim().toLowerCase();
    selectedConditionType = conditionType == 'used' ? 'used' : 'new';

    final String serviceDeliveryType =
        '${product['service_delivery_type'] ?? 'online'}'.trim().toLowerCase();

    if (serviceDeliveryType == 'download') {
      selectedServiceDeliveryType = 'download';
    } else if (serviceDeliveryType == 'presential' ||
        serviceDeliveryType == 'presencial') {
      selectedServiceDeliveryType = 'presential';
    } else if (serviceDeliveryType == 'home_office' ||
        serviceDeliveryType == 'homeoffice') {
      selectedServiceDeliveryType = 'home_office';
    } else {
      selectedServiceDeliveryType = 'online';
    }

    serviceDeliveryTimeController.text =
        ('${product['service_delivery_time'] ?? product['average_delivery_time'] ?? product['delivery_time'] ?? ''}')
            .trim();

    final String imageUrl = '${product['main_image_url'] ?? ''}'.trim();
    existingImageUrl = imageUrl.isNotEmpty ? imageUrl : null;

    final String categoryId = '${product['category_id'] ?? ''}'.trim();
    editingCategoryId = categoryId.isNotEmpty ? categoryId : null;
  }

  String formatMoneyForInput(dynamic value) {
    if (value == null) {
      return '';
    }

    final double? amount = double.tryParse('$value');

    if (amount == null || amount <= 0) {
      return '';
    }

    return amount.toStringAsFixed(2).replaceAll('.', ',');
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
      showStoreMessage('Não foi possível carregar as categorias da loja.');
      return;
    }

    final dynamic dataValue = body['data'];
    final List<dynamic> data = dataValue is List ? dataValue : <dynamic>[];

    final List<StoreCategoryOption> parsed = [];

    for (final dynamic item in data) {
      if (item is! Map) {
        continue;
      }

      final String parentName = '${item['name'] ?? ''}'.trim();
      final dynamic subcategoriesValue = item['subcategories'];
      final List<dynamic> subcategories =
          subcategoriesValue is List ? subcategoriesValue : <dynamic>[];

      if (subcategories.isEmpty) {
        parsed.add(
          StoreCategoryOption(
            id: '${item['id'] ?? ''}',
            name: parentName,
            parentName: null,
          ),
        );
        continue;
      }

      for (final dynamic subItem in subcategories) {
        if (subItem is! Map) {
          continue;
        }

        parsed.add(
          StoreCategoryOption(
            id: '${subItem['id'] ?? ''}',
            name: '${subItem['name'] ?? ''}',
            parentName: parentName,
          ),
        );
      }
    }

    final List<StoreCategoryOption> parsedCategories =
        parsed.where((category) => category.id.isNotEmpty).toList();

    StoreCategoryOption? matchedCategory;

    if (editingCategoryId != null && editingCategoryId!.isNotEmpty) {
      for (final StoreCategoryOption category in parsedCategories) {
        if (category.id == editingCategoryId) {
          matchedCategory = category;
          break;
        }
      }
    }

    setState(() {
      categories = parsedCategories;

      if (matchedCategory != null) {
        selectedCategory = matchedCategory;
      }
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

  Future<void> openCategorySelector() async {
    if (categories.isEmpty) {
      showStoreMessage('Nenhuma categoria disponível no momento.');
      return;
    }

    List<StoreCategoryOption> filteredCategories = List.from(categories);

    final StoreCategoryOption? chosenCategory =
        await showModalBottomSheet<StoreCategoryOption>(
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
                  filteredCategories = List.from(categories);
                  return;
                }

                filteredCategories = categories.where((category) {
                  return category.fullName.toLowerCase().contains(search) ||
                      category.name.toLowerCase().contains(search) ||
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
                            'Escolha a categoria',
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
                        hintText:
                            'Digite para buscar categoria ou subcategoria',
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
                                'Nenhuma categoria encontrada.',
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
                                    selectedCategory?.id == category.id;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Material(
                                    color: isSelected
                                        ? primaryColor.withValues(alpha: 0.10)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(18),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () {
                                        Navigator.of(context).pop(category);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          11,
                                          12,
                                          11,
                                        ),
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
                                                Icons.category_outlined,
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

    if (!mounted || chosenCategory == null) {
      return;
    }

    setState(() {
      selectedCategory = chosenCategory;
      editingCategoryId = chosenCategory.id;
    });
  }

  Future<void> submitProduct() async {
    if (isSubmitting) {
      return;
    }

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (selectedCategory == null) {
      showStoreMessage('Selecione uma categoria para o produto.');
      return;
    }

    if (!isEditMode && selectedImage == null) {
      showStoreMessage('Selecione a imagem principal do produto.');
      return;
    }

    if (isEditMode &&
        selectedImage == null &&
        (existingImageUrl == null || existingImageUrl!.isEmpty)) {
      showStoreMessage('Selecione a imagem principal do produto.');
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    final Map<String, String> fields = {
      'category_id': selectedCategory!.id,
      'name': nameController.text.trim(),
      'price': normalizeMoney(priceController.text),
      'availability_type': selectedAvailabilityType,
      'product_type': selectedProductType,
      'condition_type':
          selectedProductType == 'physical' ? selectedConditionType : 'new',
      'manage_stock': '1',
      'stock': stockController.text.trim().isEmpty
          ? '0'
          : stockController.text.trim(),
      'unit': 'unidade',
    };

    if (selectedProductType == 'service') {
      fields['service_delivery_type'] = selectedServiceDeliveryType;
      fields['service_delivery_time'] =
          serviceDeliveryTimeController.text.trim();
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

    final Response response;

    if (isEditMode) {
      final String uri = storeProductUpdateUri(editingProductId);

      if (selectedImage == null) {
        response = await Get.find<ApiClient>().postData(uri, fields);
      } else {
        response = await Get.find<ApiClient>().postMultipartData(
          uri,
          fields,
          MultipartBody('main_image', selectedImage!),
          <MultipartBody>[],
        );
      }
    } else {
      response = await Get.find<ApiClient>().postMultipartData(
        storeProductCreateUri,
        fields,
        MultipartBody('main_image', selectedImage!),
        <MultipartBody>[],
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
        showStoreMessage(
          'Produto atualizado e reenviado para aprovação do ADM.',
        );
        Get.back();
        return;
      }

      clearForm();

      showStoreMessage(
        'Produto cadastrado e enviado para aprovação do ADM.',
      );
      return;
    }

    String message = isEditMode
        ? 'Não foi possível atualizar o produto.'
        : 'Não foi possível cadastrar o produto.';

    if (body is Map && body['message'] != null) {
      message = body['message'].toString();
    }

    showStoreMessage(message);
  }

  String normalizeMoney(String value) {
    final String cleanValue =
        value.trim().replaceAll('R\$', '').replaceAll(' ', '');

    if (cleanValue.contains(',') && cleanValue.contains('.')) {
      return cleanValue.replaceAll('.', '').replaceAll(',', '.');
    }

    if (cleanValue.contains(',')) {
      return cleanValue.replaceAll('.', '').replaceAll(',', '.');
    }

    return cleanValue;
  }

  void clearForm() {
    nameController.clear();
    priceController.clear();
    promotionalPriceController.clear();
    stockController.clear();
    shortDescriptionController.clear();
    descriptionController.clear();
    serviceDeliveryTimeController.clear();

    setState(() {
      selectedCategory = null;
      selectedImage = null;
      existingImageUrl = null;
      editingCategoryId = null;
      selectedAvailabilityType = 'immediate';
      selectedProductType = 'physical';
      selectedConditionType = 'new';
      selectedServiceDeliveryType = 'online';
    });
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
      backgroundColor: const Color(0xFFF4F6F6),
      body: Column(
        children: [
          StoreProductsTopBar(
            primaryColor: primaryColor,
            title: isEditMode ? 'Editar produto' : 'Cadastrar produto',
            onBackTap: () => Get.back(),
          ),
          Expanded(
            child: SingleChildScrollView(
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
                    StoreProductIntroCard(
                      primaryColor: primaryColor,
                      isEditMode: isEditMode,
                    ),
                    const SizedBox(height: 14),
                    StoreImagePickerCard(
                      primaryColor: primaryColor,
                      selectedImage: selectedImage,
                      existingImageUrl: existingImageUrl,
                      onTap: pickProductImage,
                    ),
                    const SizedBox(height: 14),
                    StoreSellerFormCard(
                      primaryColor: primaryColor,
                      children: [
                        StoreTextInput(
                          label: 'Nome do produto',
                          hint: 'Ex: Perfume premium local',
                          controller: nameController,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe o nome do produto.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        StoreCategorySelectorField(
                          primaryColor: primaryColor,
                          selectedCategory: selectedCategory,
                          isLoading: isLoadingCategories,
                          onTap: openCategorySelector,
                        ),
                        const SizedBox(height: 12),
                        StoreProductTypeSelector(
                          primaryColor: primaryColor,
                          selectedProductType: selectedProductType,
                          onChanged: (value) {
                            setState(() {
                              selectedProductType = value;

                              if (selectedProductType == 'service') {
                                selectedConditionType = 'new';
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        if (selectedProductType == 'physical') ...[
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
                        ] else ...[
                          StoreServiceDeliverySelector(
                            primaryColor: primaryColor,
                            selectedServiceDeliveryType:
                                selectedServiceDeliveryType,
                            onChanged: (value) {
                              setState(() {
                                selectedServiceDeliveryType = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          StoreTextInput(
                            label: 'Prazo médio de entrega',
                            hint: 'Ex: 24 horas, 2 dias úteis ou 5 dias',
                            controller: serviceDeliveryTimeController,
                            validator: (value) {
                              if (selectedProductType == 'service' &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'Informe o prazo médio de entrega.';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: StoreTextInput(
                                label: 'Preço de venda',
                                hint: '89,90',
                                controller: priceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Informe o preço.';
                                  }

                                  final double? parsed = double.tryParse(
                                    normalizeMoney(value),
                                  );

                                  if (parsed == null || parsed <= 0) {
                                    return 'Preço inválido.';
                                  }

                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StoreTextInput(
                                label: 'Preço promocional',
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
                        if (selectedProductType == 'physical') ...[
                          StoreAvailabilitySelector(
                            primaryColor: primaryColor,
                            selectedAvailabilityType: selectedAvailabilityType,
                            onChanged: (value) {
                              setState(() {
                                selectedAvailabilityType = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        StoreTextInput(
                          label: 'Estoque disponível',
                          hint: '10',
                          controller: stockController,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        StoreTextInput(
                          label: 'Resumo curto',
                          hint: 'Texto curto para aparecer no card do produto.',
                          controller: shortDescriptionController,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        StoreTextInput(
                          label: 'Descrição completa',
                          hint:
                              'Detalhes do produto, características, indicação de uso e observações.',
                          controller: descriptionController,
                          maxLines: 5,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StoreSubmitProductButton(
                      primaryColor: primaryColor,
                      isLoading: isSubmitting,
                      buttonText: isEditMode
                          ? 'Reenviar para aprovação'
                          : 'Enviar para aprovação',
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.16),
        ),
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
              isEditMode
                  ? 'Atualize as informações do produto. Ao reenviar, ele voltará para aprovação do ADM antes de aparecer na Loja.'
                  : 'Cadastre o produto com foto, categoria, preço e disponibilidade. Depois do envio, ele ficará aguardando aprovação do ADM antes de aparecer na Loja.',
              style: textMedium.copyWith(
                color: Colors.black87,
                fontSize: 12.6,
                height: 1.34,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreImagePickerCard extends StatelessWidget {
  final Color primaryColor;
  final XFile? selectedImage;
  final String? existingImageUrl;
  final VoidCallback onTap;

  const StoreImagePickerCard({
    super.key,
    required this.primaryColor,
    required this.selectedImage,
    required this.existingImageUrl,
    required this.onTap,
  });

  bool get hasExistingImage {
    return existingImageUrl != null && existingImageUrl!.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
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
                      'Selecionar imagem principal',
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'JPG, PNG ou WEBP até 10MB',
                      style: textRegular.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: selectedImage != null
                            ? Image.file(
                                File(selectedImage!.path),
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                existingImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return Container(
                                    color: primaryColor.withValues(alpha: 0.08),
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
                        right: 12,
                        top: 12,
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.photo_camera_outlined,
                                color: primaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Trocar',
                                style: textBold.copyWith(
                                  color: primaryColor,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: children,
      ),
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
          label,
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 12.8,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: textMedium.copyWith(
            color: Colors.black87,
            fontSize: 13.4,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: textRegular.copyWith(
              color: Colors.grey.shade500,
              fontSize: 13,
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
              borderSide: BorderSide(color: primaryColor, width: 1.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
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
  final StoreCategoryOption? selectedCategory;
  final bool isLoading;
  final VoidCallback onTap;

  const StoreCategorySelectorField({
    super.key,
    required this.primaryColor,
    required this.selectedCategory,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String label = selectedCategory == null
        ? 'Selecionar categoria e subcategoria'
        : selectedCategory!.fullName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categoria do produto',
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 12.8,
          ),
        ),
        const SizedBox(height: 7),
        Material(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
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
                      isLoading ? 'Carregando categorias...' : label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textMedium.copyWith(
                        color: selectedCategory == null
                            ? Colors.grey.shade500
                            : Colors.black87,
                        fontSize: 13.2,
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

class StoreProductTypeSelector extends StatelessWidget {
  final Color primaryColor;
  final String selectedProductType;
  final ValueChanged<String> onChanged;

  const StoreProductTypeSelector({
    super.key,
    required this.primaryColor,
    required this.selectedProductType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StoreOptionSelectorSection(
      title: 'Tipo de cadastro',
      children: [
        StoreAvailabilityOption(
          primaryColor: primaryColor,
          title: 'Produto físico',
          description: 'Item com entrega ou retirada',
          value: 'physical',
          selectedValue: selectedProductType,
          onTap: onChanged,
        ),
        StoreAvailabilityOption(
          primaryColor: primaryColor,
          title: 'Serviço',
          description: 'Online, download ou atendimento',
          value: 'service',
          selectedValue: selectedProductType,
          onTap: onChanged,
        ),
      ],
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
    return StoreOptionSelectorSection(
      title: 'Condição do produto',
      children: [
        StoreAvailabilityOption(
          primaryColor: primaryColor,
          title: 'Novo',
          description: 'Produto novo',
          value: 'new',
          selectedValue: selectedConditionType,
          onTap: onChanged,
        ),
        StoreAvailabilityOption(
          primaryColor: primaryColor,
          title: 'Usado',
          description: 'Produto usado',
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
      title: 'Formato do serviço',
      children: [
        StoreAvailabilityOption(
          primaryColor: primaryColor,
          title: 'Online',
          description: 'Serviço digital online',
          value: 'online',
          selectedValue: selectedServiceDeliveryType,
          onTap: onChanged,
        ),
        StoreAvailabilityOption(
          primaryColor: primaryColor,
          title: 'Download',
          description: 'Arquivo entregue ao cliente',
          value: 'download',
          selectedValue: selectedServiceDeliveryType,
          onTap: onChanged,
        ),
        StoreAvailabilityOption(
          primaryColor: primaryColor,
          title: 'Presencial',
          description: 'Atendimento presencial',
          value: 'presential',
          selectedValue: selectedServiceDeliveryType,
          onTap: onChanged,
        ),
        StoreAvailabilityOption(
          primaryColor: primaryColor,
          title: 'Home Office',
          description: 'Atendimento remoto',
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
          title,
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
  final String selectedAvailabilityType;
  final ValueChanged<String> onChanged;

  const StoreAvailabilitySelector({
    super.key,
    required this.primaryColor,
    required this.selectedAvailabilityType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Disponibilidade para retirada ou entrega',
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 12.8,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: StoreAvailabilityOption(
                primaryColor: primaryColor,
                title: 'Imediata',
                description: 'Produto disponível agora',
                value: 'immediate',
                selectedValue: selectedAvailabilityType,
                onTap: onChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StoreAvailabilityOption(
                primaryColor: primaryColor,
                title: 'Em até 24h',
                description: 'Preparação em até 24h',
                value: 'within_24h',
                selectedValue: selectedAvailabilityType,
                onTap: onChanged,
              ),
            ),
          ],
        ),
      ],
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
                    buttonText,
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
  final String? parentName;

  StoreCategoryOption({
    required this.id,
    required this.name,
    required this.parentName,
  });

  String get fullName {
    if (parentName == null || parentName!.trim().isEmpty) {
      return name;
    }

    return '$parentName > $name';
  }
}
