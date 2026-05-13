import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreCustomerOrderListScreen extends StatefulWidget {
  final String? initialOrderId;

  const StoreCustomerOrderListScreen({
    super.key,
    this.initialOrderId,
  });

  @override
  State<StoreCustomerOrderListScreen> createState() =>
      _StoreCustomerOrderListScreenState();
}

class _StoreCustomerOrderListScreenState
    extends State<StoreCustomerOrderListScreen> {
  static const String storeCustomerOrdersUri = '/api/customer/store/orders';

  bool isLoading = false;
  String selectedFilter = 'all';

  List<StoreCustomerOrderItem> orders = <StoreCustomerOrderItem>[];
  StoreCustomerOrderCounts counts = StoreCustomerOrderCounts.empty();

  final List<StoreCustomerOrderFilter> filters = <StoreCustomerOrderFilter>[
    StoreCustomerOrderFilter(keyName: 'all', label: 'Todos', apiFilter: 'all'),
    StoreCustomerOrderFilter(
      keyName: 'pickup',
      label: 'Retirada',
      apiFilter: 'pickup',
    ),
    StoreCustomerOrderFilter(
      keyName: 'lokally_shipping',
      label: 'Lokally Envios',
      apiFilter: 'lokally_shipping',
    ),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadOrders();

      final String? initialOrderId = widget.initialOrderId;
      if (initialOrderId != null && initialOrderId.isNotEmpty) {
        openOrderDetailsById(initialOrderId);
      }
    });
  }

  Future<void> loadOrders({String? filterKey}) async {
    if (isLoading) {
      return;
    }

    final String nextFilter = filterKey ?? selectedFilter;
    final StoreCustomerOrderFilter filter = filters.firstWhere(
      (item) => item.keyName == nextFilter,
      orElse: () => filters.first,
    );

    setState(() {
      isLoading = true;
      selectedFilter = nextFilter;
    });

    final String uri = filter.apiFilter == 'all'
        ? storeCustomerOrdersUri
        : '$storeCustomerOrdersUri?filter=${filter.apiFilter}';

    final Response response = await Get.find<ApiClient>().getData(uri);

    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = false;
    });

    final dynamic body = response.body;

    if (response.statusCode != 200 || body is! Map || body['status'] != true) {
      showStoreMessage('Não foi possível carregar seus pedidos da loja.');
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

    final dynamic ordersValue = data['orders'];
    final List<dynamic> orderList =
        ordersValue is List ? ordersValue : <dynamic>[];

    setState(() {
      counts = StoreCustomerOrderCounts.fromMap(countsMap);
      orders = orderList
          .whereType<Map>()
          .map(
            (item) => StoreCustomerOrderItem.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    });
  }

  Future<void> openOrderDetailsById(String orderId) async {
    for (final StoreCustomerOrderItem order in orders) {
      if (order.id == orderId) {
        Get.to(() => StoreCustomerOrderDetailsScreen(order: order));
        return;
      }
    }

    final Response response = await Get.find<ApiClient>().getData(
      '$storeCustomerOrdersUri/$orderId',
    );

    final dynamic body = response.body;

    if (response.statusCode != 200 || body is! Map || body['status'] != true) {
      showStoreMessage('Não foi possível abrir os detalhes do pedido.');
      return;
    }

    final dynamic dataValue = body['data'];
    final Map<String, dynamic> data = dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : <String, dynamic>{};

    final dynamic orderValue = data['order'];

    if (orderValue is! Map) {
      showStoreMessage('Pedido não encontrado.');
      return;
    }

    Get.to(
      () => StoreCustomerOrderDetailsScreen(
        order: StoreCustomerOrderItem.fromMap(
          Map<String, dynamic>.from(orderValue),
        ),
      ),
    );
  }

  void openOrderDetails(StoreCustomerOrderItem order) {
    Get.to(() => StoreCustomerOrderDetailsScreen(order: order));
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
      case 'pickup':
        return counts.pickup;
      case 'lokally_shipping':
        return counts.lokallyShipping;
      default:
        return counts.all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F6),
        body: BodyWidget(
          appBar: AppBarWidget(title: 'Meus pedidos'.tr),
          body: RefreshIndicator(
            color: primaryColor,
            onRefresh: () => loadOrders(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Dimensions.paddingSizeDefault,
                16,
                Dimensions.paddingSizeDefault,
                28,
              ),
              children: [
                StoreCustomerOrderListIntro(
                  primaryColor: primaryColor,
                  counts: counts,
                ),
                const SizedBox(height: 14),
                StoreCustomerOrderFilters(
                  primaryColor: primaryColor,
                  filters: filters,
                  selectedFilter: selectedFilter,
                  countForFilter: countForFilter,
                  onChanged: (filter) => loadOrders(filterKey: filter),
                ),
                const SizedBox(height: 14),
                if (isLoading)
                  StoreCustomerOrdersLoading(primaryColor: primaryColor)
                else if (orders.isEmpty)
                  StoreCustomerOrdersEmpty(
                    primaryColor: primaryColor,
                    selectedFilter: selectedFilter,
                  )
                else
                  ...orders.map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: StoreCustomerOrderCard(
                        order: order,
                        primaryColor: primaryColor,
                        onTap: () => openOrderDetails(order),
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

class StoreCustomerOrderListIntro extends StatelessWidget {
  final Color primaryColor;
  final StoreCustomerOrderCounts counts;

  const StoreCustomerOrderListIntro({
    super.key,
    required this.primaryColor,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return StoreCustomerSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meus pedidos Lokally Marketplace',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Acompanhe suas compras, retiradas na loja e entregas com Lokally Envios.',
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
                child: StoreCustomerOrderMiniCount(
                  primaryColor: primaryColor,
                  value: counts.pickup.toString(),
                  label: 'Retirada',
                  icon: Icons.storefront_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StoreCustomerOrderMiniCount(
                  primaryColor: primaryColor,
                  value: counts.lokallyShipping.toString(),
                  label: 'Envios',
                  icon: Icons.local_shipping_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StoreCustomerOrderMiniCount(
                  primaryColor: Colors.orangeAccent,
                  value: counts.readyForPickup.toString(),
                  label: 'Prontos',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StoreCustomerOrderMiniCount extends StatelessWidget {
  final Color primaryColor;
  final String value;
  final String label;
  final IconData icon;

  const StoreCustomerOrderMiniCount({
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

class StoreCustomerOrderFilters extends StatelessWidget {
  final Color primaryColor;
  final List<StoreCustomerOrderFilter> filters;
  final String selectedFilter;
  final int Function(String keyName) countForFilter;
  final ValueChanged<String> onChanged;

  const StoreCustomerOrderFilters({
    super.key,
    required this.primaryColor,
    required this.filters,
    required this.selectedFilter,
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
          final StoreCustomerOrderFilter filter = filters[index];
          final bool isSelected = filter.keyName == selectedFilter;

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

class StoreCustomerOrderCard extends StatelessWidget {
  final StoreCustomerOrderItem order;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreCustomerOrderCard({
    super.key,
    required this.order,
    required this.primaryColor,
    required this.onTap,
  });

  Color get statusColor {
    switch (order.orderStatus) {
      case 'ready_for_pickup':
      case 'completed':
      case 'lokally_shipping_requested':
      case 'shipped':
        return primaryColor;
      case 'cancelled':
        return Colors.redAccent;
      case 'lokally_shipping_pending':
      case 'payment_approved':
      case 'preparing':
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }

  IconData get deliveryIcon {
    return order.deliveryType == 'pickup'
        ? Icons.storefront_rounded
        : Icons.local_shipping_outlined;
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
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StoreCustomerOrderSellerLogo(
                    primaryColor: primaryColor,
                    logoUrl: order.sellerLogoUrl,
                    icon: deliveryIcon,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.sellerName.isEmpty ? 'Loja' : order.sellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textBold.copyWith(
                            color: Colors.black87,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          order.orderNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textRegular.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 11.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    StoreCustomerOrderCurrency.format(order.total),
                    style: textBold.copyWith(
                      color: primaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  StoreCustomerOrderStatusBadge(
                    label: order.orderStatusLabel,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.deliveryTypeLabel,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...order.items.take(2).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: StoreCustomerOrderItemLine(item: item),
                    ),
                  ),
              if (order.items.length > 2)
                Text(
                  '+ ${order.items.length - 2} item(ns)',
                  style: textRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 11.6,
                  ),
                ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Ver detalhes',
                    style: textBold.copyWith(
                      color: primaryColor,
                      fontSize: 12.6,
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

class StoreCustomerOrderDetailsScreen extends StatelessWidget {
  final StoreCustomerOrderItem order;

  const StoreCustomerOrderDetailsScreen({
    super.key,
    required this.order,
  });

  Color statusColor(Color primaryColor) {
    switch (order.orderStatus) {
      case 'ready_for_pickup':
      case 'completed':
      case 'lokally_shipping_requested':
      case 'shipped':
        return primaryColor;
      case 'cancelled':
        return Colors.redAccent;
      case 'lokally_shipping_pending':
      case 'payment_approved':
      case 'preparing':
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final bool isPickup = order.deliveryType == 'pickup';

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F6),
        body: BodyWidget(
          appBar: AppBarWidget(title: 'Detalhes do pedido'.tr),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault,
              16,
              Dimensions.paddingSizeDefault,
              28,
            ),
            children: [
              StoreCustomerSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StoreCustomerOrderSellerLogo(
                          primaryColor: primaryColor,
                          logoUrl: order.sellerLogoUrl,
                          icon: isPickup
                              ? Icons.storefront_rounded
                              : Icons.local_shipping_outlined,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.sellerName.isEmpty
                                    ? 'Loja'
                                    : order.sellerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textBold.copyWith(
                                  color: Colors.black87,
                                  fontSize: 15.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                order.orderNumber,
                                style: textRegular.copyWith(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    StoreCustomerOrderStatusBadge(
                      label: order.orderStatusLabel,
                      color: statusColor(primaryColor),
                    ),
                    const SizedBox(height: 14),
                    StoreCustomerSimpleLine(
                      label: 'Entrega',
                      value: order.deliveryTypeLabel,
                    ),
                    const SizedBox(height: 6),
                    StoreCustomerSimpleLine(
                      label: 'Pagamento',
                      value: order.paymentMethodLabel,
                    ),
                    const SizedBox(height: 6),
                    StoreCustomerSimpleLine(
                      label: 'Status do pagamento',
                      value: order.paymentStatusLabel,
                    ),
                    const SizedBox(height: 6),
                    StoreCustomerSimpleLine(
                      label: 'Total',
                      value: StoreCustomerOrderCurrency.format(order.total),
                      highlight: true,
                      primaryColor: primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (isPickup)
                StoreCustomerPickupDetails(
                  order: order,
                  primaryColor: primaryColor,
                )
              else
                StoreCustomerShippingDetails(
                  order: order,
                  primaryColor: primaryColor,
                ),
              const SizedBox(height: 14),
              StoreCustomerSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Produtos',
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: StoreCustomerOrderItemLine(
                          item: item,
                          showUnitPrice: true,
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

class StoreCustomerPickupDetails extends StatelessWidget {
  final StoreCustomerOrderItem order;
  final Color primaryColor;

  const StoreCustomerPickupDetails({
    super.key,
    required this.order,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isReady = order.orderStatus == 'ready_for_pickup';

    return StoreCustomerSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isReady ? 'Pedido disponível para retirada' : 'Retirada na loja',
            style: textBold.copyWith(
              color: isReady ? primaryColor : Colors.black87,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isReady
                ? 'Oba! Você já pode retirar o seu pedido na loja. Apresente o número do pedido ao vendedor.'
                : 'Assim que o vendedor liberar a retirada, você será notificado pelo app.',
            style: textRegular.copyWith(
              color: Colors.grey.shade700,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          if (order.pickupAddress.isNotEmpty) ...[
            const SizedBox(height: 12),
            StoreCustomerInfoBlock(
              icon: Icons.store_mall_directory_outlined,
              title: 'Endereço de retirada',
              value: order.pickupAddress,
            ),
          ],
          if (order.sellerPhone.isNotEmpty) ...[
            const SizedBox(height: 10),
            StoreCustomerInfoBlock(
              icon: Icons.phone_outlined,
              title: 'Contato da loja',
              value: order.sellerPhone,
            ),
          ],
        ],
      ),
    );
  }
}

class StoreCustomerShippingDetails extends StatelessWidget {
  final StoreCustomerOrderItem order;
  final Color primaryColor;

  const StoreCustomerShippingDetails({
    super.key,
    required this.order,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return StoreCustomerSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lokally Envios',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            order.orderStatus == 'lokally_shipping_pending'
                ? 'O vendedor tem até 24h para solicitar um parceiro Lokally para enviar o seu pedido.'
                : 'Acompanhe aqui as atualizações do envio do seu pedido.',
            style: textRegular.copyWith(
              color: Colors.grey.shade700,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          if (order.deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: 12),
            StoreCustomerInfoBlock(
              icon: Icons.location_on_outlined,
              title: 'Endereço de entrega',
              value: order.deliveryAddress,
            ),
          ],
        ],
      ),
    );
  }
}

class StoreCustomerInfoBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const StoreCustomerInfoBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 17),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 11.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 11.5,
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

class StoreCustomerSimpleLine extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final Color? primaryColor;

  const StoreCustomerSimpleLine({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textMedium.copyWith(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            textAlign: TextAlign.right,
            style: (highlight ? textBold : textMedium).copyWith(
              color: highlight ? primaryColor : Colors.black87,
              fontSize: highlight ? 16 : 13,
            ),
          ),
        ),
      ],
    );
  }
}

class StoreCustomerOrderItemLine extends StatelessWidget {
  final StoreCustomerOrderProductItem item;
  final bool showUnitPrice;

  const StoreCustomerOrderItemLine({
    super.key,
    required this.item,
    this.showUnitPrice = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            width: 42,
            height: 42,
            child: item.productImageUrl.isEmpty
                ? Container(
                    color: Colors.grey.shade100,
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.grey.shade500,
                      size: 20,
                    ),
                  )
                : Image.network(
                    item.productImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        color: Colors.grey.shade100,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.grey.shade500,
                          size: 20,
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.quantity}x ${item.productName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textMedium.copyWith(
                  color: Colors.black87,
                  fontSize: 12.4,
                  height: 1.18,
                ),
              ),
              if (showUnitPrice) ...[
                const SizedBox(height: 2),
                Text(
                  'Unitário: ${StoreCustomerOrderCurrency.format(item.unitPrice)}',
                  style: textRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 11.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          StoreCustomerOrderCurrency.format(item.total),
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 12.2,
          ),
        ),
      ],
    );
  }
}

class StoreCustomerOrderStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StoreCustomerOrderStatusBadge({
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 7),
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

class StoreCustomerOrderSellerLogo extends StatelessWidget {
  final Color primaryColor;
  final String logoUrl;
  final IconData icon;

  const StoreCustomerOrderSellerLogo({
    super.key,
    required this.primaryColor,
    required this.logoUrl,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: logoUrl.isEmpty
          ? Icon(icon, color: primaryColor, size: 22)
          : ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Icon(icon, color: primaryColor, size: 22);
                },
              ),
            ),
    );
  }
}

class StoreCustomerOrdersLoading extends StatelessWidget {
  final Color primaryColor;

  const StoreCustomerOrdersLoading({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return StoreCustomerSurface(
      child: SizedBox(
        height: 130,
        child: Center(
          child: CircularProgressIndicator(
            color: primaryColor,
            strokeWidth: 2.4,
          ),
        ),
      ),
    );
  }
}

class StoreCustomerOrdersEmpty extends StatelessWidget {
  final Color primaryColor;
  final String selectedFilter;

  const StoreCustomerOrdersEmpty({
    super.key,
    required this.primaryColor,
    required this.selectedFilter,
  });

  @override
  Widget build(BuildContext context) {
    final String message = selectedFilter == 'pickup'
        ? 'Quando você tiver pedidos para retirada, eles aparecerão aqui.'
        : selectedFilter == 'lokally_shipping'
            ? 'Quando você tiver pedidos com Lokally Envios, eles aparecerão aqui.'
            : 'Quando você comprar produtos no Marketplace, seus pedidos aparecerão aqui.';

    return StoreCustomerSurface(
      child: Column(
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            color: primaryColor,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            'Nenhum pedido encontrado',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 15.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 12.3,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreCustomerSurface extends StatelessWidget {
  final Widget child;

  const StoreCustomerSurface({
    super.key,
    required this.child,
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
      child: child,
    );
  }
}

class StoreCustomerOrderItem {
  final String id;
  final String orderNumber;
  final String deliveryType;
  final String deliveryTypeLabel;
  final String paymentMethod;
  final String paymentMethodLabel;
  final String paymentStatus;
  final String paymentStatusLabel;
  final String orderStatus;
  final String orderStatusLabel;
  final double subtotal;
  final double shippingAmount;
  final double shippingDiscount;
  final double total;
  final String deliveryAddress;
  final String pickupAddress;
  final String sellerPhone;
  final String sellerName;
  final String sellerLogoUrl;
  final String createdAt;
  final List<StoreCustomerOrderProductItem> items;

  StoreCustomerOrderItem({
    required this.id,
    required this.orderNumber,
    required this.deliveryType,
    required this.deliveryTypeLabel,
    required this.paymentMethod,
    required this.paymentMethodLabel,
    required this.paymentStatus,
    required this.paymentStatusLabel,
    required this.orderStatus,
    required this.orderStatusLabel,
    required this.subtotal,
    required this.shippingAmount,
    required this.shippingDiscount,
    required this.total,
    required this.deliveryAddress,
    required this.pickupAddress,
    required this.sellerPhone,
    required this.sellerName,
    required this.sellerLogoUrl,
    required this.createdAt,
    required this.items,
  });

  factory StoreCustomerOrderItem.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> delivery = map['delivery'] is Map
        ? Map<String, dynamic>.from(map['delivery'])
        : <String, dynamic>{};

    final Map<String, dynamic> pickup = map['pickup'] is Map
        ? Map<String, dynamic>.from(map['pickup'])
        : <String, dynamic>{};

    final Map<String, dynamic> seller = map['seller'] is Map
        ? Map<String, dynamic>.from(map['seller'])
        : <String, dynamic>{};

    final dynamic itemsValue = map['items'];
    final List<dynamic> rawItems =
        itemsValue is List ? itemsValue : <dynamic>[];

    return StoreCustomerOrderItem(
      id: '${map['id'] ?? ''}',
      orderNumber: '${map['order_number'] ?? ''}',
      deliveryType: '${map['delivery_type'] ?? ''}',
      deliveryTypeLabel: '${map['delivery_type_label'] ?? ''}',
      paymentMethod: '${map['payment_method'] ?? ''}',
      paymentMethodLabel: '${map['payment_method_label'] ?? ''}',
      paymentStatus: '${map['payment_status'] ?? ''}',
      paymentStatusLabel: '${map['payment_status_label'] ?? ''}',
      orderStatus: '${map['order_status'] ?? ''}',
      orderStatusLabel: '${map['order_status_label'] ?? ''}',
      subtotal: StoreCustomerOrderCurrency.parseDouble(map['subtotal']),
      shippingAmount:
          StoreCustomerOrderCurrency.parseDouble(map['shipping_amount']),
      shippingDiscount:
          StoreCustomerOrderCurrency.parseDouble(map['shipping_discount']),
      total: StoreCustomerOrderCurrency.parseDouble(map['total']),
      deliveryAddress: '${delivery['address'] ?? ''}',
      pickupAddress: '${pickup['address'] ?? ''}',
      sellerPhone: '${pickup['seller_phone'] ?? ''}',
      sellerName: '${seller['name'] ?? ''}',
      sellerLogoUrl: '${seller['logo_url'] ?? ''}',
      createdAt: '${map['created_at'] ?? ''}',
      items: rawItems
          .whereType<Map>()
          .map(
            (item) => StoreCustomerOrderProductItem.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}

class StoreCustomerOrderProductItem {
  final String id;
  final String productId;
  final String productName;
  final String productImageUrl;
  final double unitPrice;
  final int quantity;
  final double total;

  StoreCustomerOrderProductItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.total,
  });

  factory StoreCustomerOrderProductItem.fromMap(Map<String, dynamic> map) {
    return StoreCustomerOrderProductItem(
      id: '${map['id'] ?? ''}',
      productId: '${map['product_id'] ?? ''}',
      productName: '${map['product_name'] ?? ''}',
      productImageUrl: '${map['product_image_url'] ?? ''}',
      unitPrice: StoreCustomerOrderCurrency.parseDouble(map['unit_price']),
      quantity: int.tryParse('${map['quantity'] ?? 0}') ?? 0,
      total: StoreCustomerOrderCurrency.parseDouble(map['total']),
    );
  }
}

class StoreCustomerOrderCounts {
  final int all;
  final int pickup;
  final int lokallyShipping;
  final int readyForPickup;
  final int lokallyShippingPending;

  StoreCustomerOrderCounts({
    required this.all,
    required this.pickup,
    required this.lokallyShipping,
    required this.readyForPickup,
    required this.lokallyShippingPending,
  });

  factory StoreCustomerOrderCounts.empty() {
    return StoreCustomerOrderCounts(
      all: 0,
      pickup: 0,
      lokallyShipping: 0,
      readyForPickup: 0,
      lokallyShippingPending: 0,
    );
  }

  factory StoreCustomerOrderCounts.fromMap(Map<String, dynamic> map) {
    return StoreCustomerOrderCounts(
      all: int.tryParse('${map['all'] ?? 0}') ?? 0,
      pickup: int.tryParse('${map['pickup'] ?? 0}') ?? 0,
      lokallyShipping: int.tryParse('${map['lokally_shipping'] ?? 0}') ?? 0,
      readyForPickup: int.tryParse('${map['ready_for_pickup'] ?? 0}') ?? 0,
      lokallyShippingPending:
          int.tryParse('${map['lokally_shipping_pending'] ?? 0}') ?? 0,
    );
  }
}

class StoreCustomerOrderFilter {
  final String keyName;
  final String label;
  final String apiFilter;

  StoreCustomerOrderFilter({
    required this.keyName,
    required this.label,
    required this.apiFilter,
  });
}

class StoreCustomerOrderCurrency {
  static double parseDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse('$value') ?? 0;
  }

  static String format(double value) {
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

    return 'R\$$integer,$decimal';
  }
}
