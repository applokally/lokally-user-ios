import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

import 'store_seller_products_screen.dart';

class StoreSellerProductListScreen extends StatefulWidget {
  const StoreSellerProductListScreen({super.key});

  @override
  State<StoreSellerProductListScreen> createState() =>
      _StoreSellerProductListScreenState();
}

class _StoreSellerProductListScreenState
    extends State<StoreSellerProductListScreen> {
  static const String storeProductsUri = '/api/customer/store/products';

  bool isLoading = false;
  String selectedStatus = 'all';

  List<StoreSellerProductItem> products = [];
  StoreSellerProductCounts counts = StoreSellerProductCounts.empty();

  final List<StoreSellerProductStatusFilter> filters = [
    StoreSellerProductStatusFilter(
      keyName: 'all',
      label: 'Todos',
      apiStatus: null,
    ),
    StoreSellerProductStatusFilter(
      keyName: 'pending',
      label: 'Aguardando',
      apiStatus: 'pending',
    ),
    StoreSellerProductStatusFilter(
      keyName: 'approved',
      label: 'Aprovados',
      apiStatus: 'approved',
    ),
    StoreSellerProductStatusFilter(
      keyName: 'rejected',
      label: 'Reprovados',
      apiStatus: 'rejected',
    ),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadProducts();
    });
  }

  Future<void> loadProducts({String? statusKey}) async {
    if (isLoading) {
      return;
    }

    final String nextStatus = statusKey ?? selectedStatus;
    final StoreSellerProductStatusFilter filter = filters.firstWhere(
      (item) => item.keyName == nextStatus,
      orElse: () => filters.first,
    );

    setState(() {
      isLoading = true;
      selectedStatus = nextStatus;
    });

    final String uri = filter.apiStatus == null
        ? storeProductsUri
        : '$storeProductsUri?status=${filter.apiStatus}';

    final Response response = await Get.find<ApiClient>().getData(uri);

    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = false;
    });

    final dynamic body = response.body;

    if (response.statusCode != 200 || body is! Map || body['status'] != true) {
      showStoreMessage('Não foi possível carregar os produtos.');
      return;
    }

    final dynamic dataValue = body['data'];
    final Map<String, dynamic> data = dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : <String, dynamic>{};

    final dynamic countsValue = data['counts'];
    final Map<String, dynamic> countsMap = countsValue is Map
        ? Map<String, dynamic>.from(countsValue)
        : <String, dynamic>{};

    final dynamic productsValue = data['products'];
    final List<dynamic> productList =
        productsValue is List ? productsValue : <dynamic>[];

    setState(() {
      counts = StoreSellerProductCounts.fromMap(countsMap);
      products = productList
          .whereType<Map>()
          .map((item) => StoreSellerProductItem.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    });
  }

  void openCreateProduct() {
    Get.to(() => const StoreSellerProductsScreen())?.then((_) {
      loadProducts();
    });
  }

  void openEditProduct(StoreSellerProductItem product) {
    Get.to(
      () => StoreSellerProductsScreen(
        initialProduct: product.toInitialProductMap(),
      ),
    )?.then((_) {
      loadProducts();
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

  int countForFilter(String keyName) {
    switch (keyName) {
      case 'pending':
        return counts.pending;
      case 'approved':
        return counts.approved;
      case 'rejected':
        return counts.rejected;
      default:
        return counts.all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F6),
      body: Column(
        children: [
          StoreSellerProductListTopBar(
            primaryColor: primaryColor,
            onBackTap: () => Get.back(),
            onAddTap: openCreateProduct,
          ),
          Expanded(
            child: RefreshIndicator(
              color: primaryColor,
              onRefresh: () => loadProducts(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Dimensions.paddingSizeDefault,
                  16,
                  Dimensions.paddingSizeDefault,
                  28,
                ),
                children: [
                  StoreSellerProductListIntro(
                    primaryColor: primaryColor,
                    counts: counts,
                    onCreateTap: openCreateProduct,
                  ),
                  const SizedBox(height: 14),
                  StoreSellerProductStatusFilters(
                    primaryColor: primaryColor,
                    filters: filters,
                    selectedStatus: selectedStatus,
                    countForFilter: countForFilter,
                    onChanged: (status) => loadProducts(statusKey: status),
                  ),
                  const SizedBox(height: 14),
                  if (isLoading)
                    StoreSellerProductsLoading(primaryColor: primaryColor)
                  else if (products.isEmpty)
                    StoreSellerProductsEmpty(
                      primaryColor: primaryColor,
                      selectedStatus: selectedStatus,
                      onCreateTap: openCreateProduct,
                    )
                  else
                    ...products.map(
                      (product) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StoreSellerProductCard(
                          product: product,
                          primaryColor: primaryColor,
                          onEditTap: () => openEditProduct(product),
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

class StoreSellerProductListTopBar extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onBackTap;
  final VoidCallback onAddTap;

  const StoreSellerProductListTopBar({
    super.key,
    required this.primaryColor,
    required this.onBackTap,
    required this.onAddTap,
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
              'Meus produtos',
              style: textBold.copyWith(
                color: Colors.white,
                fontSize: 19,
              ),
            ),
          ),
          GestureDetector(
            onTap: onAddTap,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Novo',
                    style: textBold.copyWith(
                      color: Colors.white,
                      fontSize: 12.5,
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

class StoreSellerProductListIntro extends StatelessWidget {
  final Color primaryColor;
  final StoreSellerProductCounts counts;
  final VoidCallback onCreateTap;

  const StoreSellerProductListIntro({
    super.key,
    required this.primaryColor,
    required this.counts,
    required this.onCreateTap,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Produtos cadastrados',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Acompanhe produtos aguardando aprovação, aprovados e reprovados pelo ADM.',
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StoreSellerProductMiniCount(
                  primaryColor: primaryColor,
                  value: counts.pending.toString(),
                  label: 'Aguardando',
                  icon: Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StoreSellerProductMiniCount(
                  primaryColor: primaryColor,
                  value: counts.approved.toString(),
                  label: 'Aprovados',
                  icon: Icons.verified_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StoreSellerProductMiniCount(
                  primaryColor: Colors.redAccent,
                  value: counts.rejected.toString(),
                  label: 'Reprovados',
                  icon: Icons.error_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: primaryColor,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onCreateTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 48,
                width: double.infinity,
                alignment: Alignment.center,
                child: Text(
                  'Cadastrar novo produto',
                  style: textBold.copyWith(
                    color: Colors.white,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerProductMiniCount extends StatelessWidget {
  final Color primaryColor;
  final String value;
  final String label;
  final IconData icon;

  const StoreSellerProductMiniCount({
    super.key,
    required this.primaryColor,
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: primaryColor,
            size: 19,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 10.8,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerProductStatusFilters extends StatelessWidget {
  final Color primaryColor;
  final List<StoreSellerProductStatusFilter> filters;
  final String selectedStatus;
  final int Function(String keyName) countForFilter;
  final ValueChanged<String> onChanged;

  const StoreSellerProductStatusFilters({
    super.key,
    required this.primaryColor,
    required this.filters,
    required this.selectedStatus,
    required this.countForFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final StoreSellerProductStatusFilter filter = filters[index];
          final bool isSelected = filter.keyName == selectedStatus;

          return Material(
            color: isSelected ? primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: () => onChanged(filter.keyName),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.grey.shade200,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${filter.label} (${countForFilter(filter.keyName)})',
                    style: textBold.copyWith(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class StoreSellerProductCard extends StatelessWidget {
  final StoreSellerProductItem product;
  final Color primaryColor;
  final VoidCallback onEditTap;

  const StoreSellerProductCard({
    super.key,
    required this.product,
    required this.primaryColor,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = product.statusColor(primaryColor);
    final bool canEdit = product.approvalStatus == 'rejected' ||
        product.approvalStatus == 'pending' ||
        product.approvalStatus == 'draft';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StoreSellerProductImage(
            imageUrl: product.mainImageUrl,
            primaryColor: primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StoreSellerProductStatusBadge(
                  label: product.approvalStatusLabel,
                  color: statusColor,
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 14.2,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  product.categoryName.isEmpty
                      ? 'Sem categoria'
                      : product.categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 11.8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: product.hasPromotionalPrice
                      ? [
                          Text(
                            product.formattedPrice,
                            style: textRegular.copyWith(
                              color: Colors.redAccent,
                              fontSize: 11.8,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Colors.redAccent,
                              decorationThickness: 1.4,
                            ),
                          ),
                          Text(
                            product.formattedPromotionalPrice,
                            style: textBold.copyWith(
                              color: primaryColor,
                              fontSize: 14.2,
                            ),
                          ),
                        ]
                      : [
                          Text(
                            product.formattedPrice,
                            style: textBold.copyWith(
                              color: primaryColor,
                              fontSize: 14.2,
                            ),
                          ),
                        ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.grey.shade600,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Estoque: ${product.stock}',
                      style: textRegular.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11.4,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      product.availabilityType == 'within_24h'
                          ? Icons.schedule_rounded
                          : Icons.flash_on_rounded,
                      color: Colors.grey.shade600,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        product.availabilityLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textRegular.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 11.4,
                        ),
                      ),
                    ),
                  ],
                ),
                if (product.approvalStatus == 'rejected' &&
                    product.rejectionNote.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      product.rejectionNote,
                      style: textRegular.copyWith(
                        color: Colors.redAccent,
                        fontSize: 11.4,
                        height: 1.28,
                      ),
                    ),
                  ),
                ],
                if (canEdit) ...[
                  const SizedBox(height: 10),
                  Material(
                    color: product.approvalStatus == 'rejected'
                        ? Colors.redAccent.withValues(alpha: 0.10)
                        : primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      onTap: onEditTap,
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        child: Text(
                          product.approvalStatus == 'rejected'
                              ? 'Editar e reenviar'
                              : 'Editar produto',
                          style: textBold.copyWith(
                            color: product.approvalStatus == 'rejected'
                                ? Colors.redAccent
                                : primaryColor,
                            fontSize: 12.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerProductImage extends StatelessWidget {
  final String imageUrl;
  final Color primaryColor;

  const StoreSellerProductImage({
    super.key,
    required this.imageUrl,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 102,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: imageUrl.isEmpty
          ? Icon(
              Icons.image_outlined,
              color: primaryColor,
              size: 30,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Icon(
                    Icons.broken_image_outlined,
                    color: primaryColor,
                    size: 30,
                  );
                },
              ),
            ),
    );
  }
}

class StoreSellerProductStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StoreSellerProductStatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 27,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            color: color,
            size: 7,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: textBold.copyWith(
              color: color,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerProductsLoading extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerProductsLoading({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
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

class StoreSellerProductsEmpty extends StatelessWidget {
  final Color primaryColor;
  final String selectedStatus;
  final VoidCallback onCreateTap;

  const StoreSellerProductsEmpty({
    super.key,
    required this.primaryColor,
    required this.selectedStatus,
    required this.onCreateTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAll = selectedStatus == 'all';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: primaryColor,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            isAll ? 'Nenhum produto cadastrado' : 'Nenhum produto neste status',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 15.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isAll
                ? 'Cadastre seu primeiro produto para enviar à aprovação do ADM.'
                : 'Quando houver produtos neste status, eles aparecerão aqui.',
            textAlign: TextAlign.center,
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 12.3,
              height: 1.35,
            ),
          ),
          if (isAll) ...[
            const SizedBox(height: 14),
            Material(
              color: primaryColor,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: onCreateTap,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 46,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Text(
                    'Cadastrar produto',
                    style: textBold.copyWith(
                      color: Colors.white,
                      fontSize: 13.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StoreSellerProductItem {
  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final String mainImageUrl;
  final String shortDescription;
  final String description;
  final String approvalStatus;
  final String approvalStatusLabel;
  final String rejectionNote;
  final String availabilityType;
  final String availabilityLabel;
  final int stock;
  final double price;
  final double promotionalPrice;

  StoreSellerProductItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.mainImageUrl,
    required this.shortDescription,
    required this.description,
    required this.approvalStatus,
    required this.approvalStatusLabel,
    required this.rejectionNote,
    required this.availabilityType,
    required this.availabilityLabel,
    required this.stock,
    required this.price,
    required this.promotionalPrice,
  });

  factory StoreSellerProductItem.fromMap(Map<String, dynamic> map) {
    return StoreSellerProductItem(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      categoryId: '${map['category_id'] ?? ''}',
      categoryName: '${map['category_name'] ?? ''}',
      mainImageUrl: '${map['main_image_url'] ?? ''}',
      shortDescription: '${map['short_description'] ?? ''}',
      description: '${map['description'] ?? ''}',
      approvalStatus: '${map['approval_status'] ?? 'pending'}',
      approvalStatusLabel: '${map['approval_status_label'] ?? ''}'.isEmpty
          ? statusLabelFromValue('${map['approval_status'] ?? 'pending'}')
          : '${map['approval_status_label']}',
      rejectionNote: '${map['rejection_note'] ?? ''}',
      availabilityType: '${map['availability_type'] ?? 'immediate'}',
      availabilityLabel: '${map['availability_label'] ?? ''}'.isEmpty
          ? availabilityLabelFromValue(
              '${map['availability_type'] ?? 'immediate'}',
            )
          : '${map['availability_label']}',
      stock: int.tryParse('${map['stock'] ?? 0}') ?? 0,
      price: double.tryParse('${map['price'] ?? 0}') ?? 0,
      promotionalPrice: double.tryParse('${map['old_price'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toInitialProductMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'category_id': categoryId,
      'category_name': categoryName,
      'main_image_url': mainImageUrl,
      'short_description': shortDescription,
      'description': description,
      'approval_status': approvalStatus,
      'approval_status_label': approvalStatusLabel,
      'rejection_note': rejectionNote,
      'availability_type': availabilityType,
      'availability_label': availabilityLabel,
      'stock': stock,
      'price': price,
      'old_price': promotionalPrice,
    };
  }

  Color statusColor(Color primaryColor) {
    switch (approvalStatus) {
      case 'approved':
        return primaryColor;
      case 'rejected':
        return Colors.redAccent;
      case 'suspended':
        return Colors.deepOrange;
      default:
        return const Color(0xFFB7791F);
    }
  }

  bool get hasPromotionalPrice {
    return promotionalPrice > 0;
  }

  String get formattedPrice {
    return formatCurrency(price);
  }

  String get formattedPromotionalPrice {
    if (promotionalPrice <= 0) {
      return '';
    }

    return formatCurrency(promotionalPrice);
  }

  static String statusLabelFromValue(String value) {
    switch (value) {
      case 'approved':
        return 'Aprovado';
      case 'rejected':
        return 'Reprovado';
      case 'suspended':
        return 'Suspenso';
      case 'draft':
        return 'Rascunho';
      default:
        return 'Aguardando aprovação';
    }
  }

  static String availabilityLabelFromValue(String value) {
    if (value == 'within_24h') {
      return 'Em até 24h';
    }

    return 'Imediata';
  }

  static String formatCurrency(double value) {
    final String fixed = value.toStringAsFixed(2);
    final List<String> parts = fixed.split('.');
    String integer = parts.first;
    final String decimal = parts.length > 1 ? parts.last : '00';

    final RegExp regex = RegExp(r'(\d+)(\d{3})');

    while (regex.hasMatch(integer)) {
      integer = integer.replaceAllMapped(
        regex,
        (match) => '${match.group(1)}.${match.group(2)}',
      );
    }

    return 'R\$ $integer,$decimal';
  }
}

class StoreSellerProductCounts {
  final int all;
  final int pending;
  final int approved;
  final int rejected;
  final int suspended;

  StoreSellerProductCounts({
    required this.all,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.suspended,
  });

  factory StoreSellerProductCounts.empty() {
    return StoreSellerProductCounts(
      all: 0,
      pending: 0,
      approved: 0,
      rejected: 0,
      suspended: 0,
    );
  }

  factory StoreSellerProductCounts.fromMap(Map<String, dynamic> map) {
    return StoreSellerProductCounts(
      all: int.tryParse('${map['all'] ?? 0}') ?? 0,
      pending: int.tryParse('${map['pending'] ?? 0}') ?? 0,
      approved: int.tryParse('${map['approved'] ?? 0}') ?? 0,
      rejected: int.tryParse('${map['rejected'] ?? 0}') ?? 0,
      suspended: int.tryParse('${map['suspended'] ?? 0}') ?? 0,
    );
  }
}

class StoreSellerProductStatusFilter {
  final String keyName;
  final String label;
  final String? apiStatus;

  StoreSellerProductStatusFilter({
    required this.keyName,
    required this.label,
    required this.apiStatus,
  });
}
