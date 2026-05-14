import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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
      case 'payout_authorized':
      case 'auto_payout_authorized':
        return primaryColor;
      case 'cancelled':
      case 'dispute_opened':
        return Colors.redAccent;
      case 'lokally_shipping_pending':
      case 'payment_approved':
      case 'preparing':
      case 'awaiting_customer_release':
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }

  IconData get deliveryIcon {
    if (order.isServiceOrder) {
      return Icons.support_agent_outlined;
    }

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

class StoreCustomerOrderDetailsScreen extends StatefulWidget {
  final StoreCustomerOrderItem order;

  const StoreCustomerOrderDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  State<StoreCustomerOrderDetailsScreen> createState() =>
      _StoreCustomerOrderDetailsScreenState();
}

class _StoreCustomerOrderDetailsScreenState
    extends State<StoreCustomerOrderDetailsScreen> {
  late StoreCustomerOrderItem order;

  @override
  void initState() {
    super.initState();
    order = widget.order;
  }

  Color paymentStatusColor(Color primaryColor) {
    switch (order.paymentStatus) {
      case 'approved':
        return primaryColor;
      case 'failed':
      case 'cancelled':
      case 'rejected':
        return Colors.redAccent;
      case 'pending':
      default:
        return Colors.orangeAccent;
    }
  }

  Color orderStatusColor(Color primaryColor) {
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

  IconData orderIcon() {
    if (order.isServiceOrder) {
      return Icons.support_agent_outlined;
    }

    return order.deliveryType == 'pickup'
        ? Icons.storefront_rounded
        : Icons.local_shipping_outlined;
  }

  void openServiceChat() {
    Get.to(() => StoreCustomerServiceChatScreen(order: order));
  }

  void openDisputeTicket() {
    Get.to(() => StoreCustomerDisputeTicketScreen(order: order));
  }

  void showDetailsMessage(BuildContext context, String message) {
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

  Future<bool> confirmSimpleAction({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final Color primaryColor = Theme.of(context).primaryColor;

    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  message,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 12.8,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Material(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(true),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      height: 46,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        confirmLabel,
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 13.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Material(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(false),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      height: 44,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'Cancelar',
                        style: textBold.copyWith(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
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

    return result == true;
  }

  Future<void> authorizePayout(BuildContext context) async {
    if (!order.canAuthorizePayout) {
      showDetailsMessage(context,
          'Este pedido ainda não está aguardando autorização de repasse.');
      return;
    }

    final bool confirmed = await confirmSimpleAction(
      context: context,
      title: 'Autorizar repasse',
      message:
          'Confirme somente se você recebeu o produto ou serviço corretamente. Após autorizar, o repasse será liberado para o vendedor.',
      confirmLabel: 'AUTORIZAR REPASSE',
    );

    if (!confirmed) {
      return;
    }

    final Response response = await Get.find<ApiClient>().postData(
      '/api/customer/store/orders/${order.id}/authorize-payout',
      <String, dynamic>{},
    );

    final dynamic body = response.body;

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        body is Map &&
        body['status'] == true) {
      final dynamic dataValue = body['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};
      final dynamic orderValue = data['order'];

      if (orderValue is Map) {
        final StoreCustomerOrderItem updatedOrder =
            StoreCustomerOrderItem.fromMap(
          Map<String, dynamic>.from(orderValue),
        );

        if (mounted) {
          setState(() {
            order = updatedOrder;
          });
        }
      }

      showDetailsMessage(context, 'Repasse autorizado com sucesso.');
      return;
    }

    showDetailsMessage(
      context,
      body is Map && body['message'] != null
          ? body['message'].toString()
          : 'Não foi possível autorizar o repasse.',
    );
  }

  Future<void> openDispute(BuildContext context) async {
    if (!order.canOpenDispute) {
      showDetailsMessage(
          context, 'Este pedido ainda não permite abertura de disputa.');
      return;
    }

    final TextEditingController reasonController = TextEditingController();
    final Color primaryColor = Theme.of(context).primaryColor;

    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Abrir disputa',
                    style: textBold.copyWith(
                      color: Colors.black87,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Explique o que não foi entregue corretamente. A equipe Lokally irá analisar o pedido.',
                    style: textRegular.copyWith(
                      color: Colors.grey.shade700,
                      fontSize: 12.6,
                      height: 1.34,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Descreva o problema encontrado...',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(17),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(true),
                      borderRadius: BorderRadius.circular(17),
                      child: Container(
                        height: 46,
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Text(
                          'ABRIR DISPUTA',
                          style: textBold.copyWith(
                            color: Colors.white,
                            fontSize: 13.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Material(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(17),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(false),
                      borderRadius: BorderRadius.circular(17),
                      child: Container(
                        height: 44,
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Text(
                          'Cancelar',
                          style: textBold.copyWith(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true) {
      reasonController.dispose();
      return;
    }

    final String reason = reasonController.text.trim();
    reasonController.dispose();

    final Response response = await Get.find<ApiClient>().postData(
      '/api/customer/store/orders/${order.id}/dispute',
      <String, dynamic>{
        'dispute_reason': reason,
      },
    );

    final dynamic body = response.body;

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        body is Map &&
        body['status'] == true) {
      final dynamic dataValue = body['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};
      final dynamic orderValue = data['order'];

      if (orderValue is Map) {
        final StoreCustomerOrderItem updatedOrder =
            StoreCustomerOrderItem.fromMap(
          Map<String, dynamic>.from(orderValue),
        );

        if (mounted) {
          setState(() {
            order = updatedOrder;
          });
        }
      }

      showDetailsMessage(context, 'Disputa aberta com sucesso.');
      return;
    }

    showDetailsMessage(
      context,
      body is Map && body['message'] != null
          ? body['message'].toString()
          : 'Não foi possível abrir a disputa.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final bool isPickup = order.deliveryType == 'pickup';
    final bool showOrderStatusLine = order.orderStatusLabel.isNotEmpty &&
        order.orderStatusLabel != order.paymentStatusLabel;

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
                          icon: orderIcon(),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.isServiceOrder
                                    ? 'Pedido de serviço'
                                    : order.sellerName.isEmpty
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
                      label: order.paymentStatusLabel,
                      color: paymentStatusColor(primaryColor),
                    ),
                    const SizedBox(height: 14),
                    StoreCustomerSimpleLine(
                      label: order.isServiceOrder ? 'Formato' : 'Entrega',
                      value: order.isServiceOrder
                          ? order.serviceDeliveryLabel
                          : order.deliveryTypeLabel,
                    ),
                    const SizedBox(height: 6),
                    StoreCustomerSimpleLine(
                      label: 'Pagamento',
                      value: order.paymentMethodLabel,
                    ),
                    if (showOrderStatusLine) ...[
                      const SizedBox(height: 6),
                      StoreCustomerSimpleLine(
                        label: 'Situação do pedido',
                        value: order.orderStatusLabel,
                      ),
                    ],
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
              if (order.shouldShowServiceChatBlock)
                StoreCustomerServiceOrderDetails(
                  order: order,
                  primaryColor: primaryColor,
                  onOpenChatTap: openServiceChat,
                )
              else if (!order.isServiceOrder && isPickup)
                StoreCustomerPickupDetails(
                  order: order,
                  primaryColor: primaryColor,
                )
              else if (!order.isServiceOrder)
                StoreCustomerShippingDetails(
                  order: order,
                  primaryColor: primaryColor,
                ),
              if (order.shouldShowReleaseBlock) ...[
                const SizedBox(height: 14),
                StoreCustomerReleaseActionBlock(
                  order: order,
                  primaryColor: primaryColor,
                  onAuthorizeTap: () => authorizePayout(context),
                  onDisputeTap: () => openDispute(context),
                ),
              ],
              if (order.isDisputed) ...[
                const SizedBox(height: 14),
                StoreCustomerDisputeShortcutBlock(
                  order: order,
                  primaryColor: primaryColor,
                  onTap: openDisputeTicket,
                ),
              ],
              const SizedBox(height: 14),
              StoreCustomerSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.isServiceOrder ? 'Serviços' : 'Produtos',
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

class StoreCustomerServiceOrderDetails extends StatelessWidget {
  final StoreCustomerOrderItem order;
  final Color primaryColor;
  final VoidCallback onOpenChatTap;

  const StoreCustomerServiceOrderDetails({
    super.key,
    required this.order,
    required this.primaryColor,
    required this.onOpenChatTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool paymentApproved = order.paymentStatus == 'approved';
    final bool chatAvailable = paymentApproved &&
        order.serviceChatAvailable &&
        !order.isReleaseClosed &&
        !order.isDisputeFinalized;
    final bool finalFlow = order.isReleaseClosed || order.isDisputeFinalized;

    return StoreCustomerSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Serviço ${order.serviceDeliveryLabel}',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            order.serviceDeliveryDescription.isEmpty
                ? 'Acompanhe as informações do serviço contratado.'
                : order.serviceDeliveryDescription,
            style: textRegular.copyWith(
              color: Colors.grey.shade700,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (!chatAvailable && !finalFlow)
            StoreCustomerInfoBlock(
              icon: Icons.lock_clock_outlined,
              title: 'Chat Lokally',
              value: paymentApproved
                  ? 'O Chat Lokally ainda não está disponível para este pedido.'
                  : 'O chat do serviço será liberado assim que o pagamento for aprovado.',
            )
          else if (chatAvailable) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: primaryColor.withValues(alpha: 0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Garantia Lokally',
                          style: textBold.copyWith(
                            color: Colors.black87,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          order.lokallyGuaranteeMessage.isEmpty
                              ? 'Mantenha a conversa pelo Chat Lokally e não confirme recebimento antes de receber o serviço.'
                              : order.lokallyGuaranteeMessage,
                          style: textRegular.copyWith(
                            color: Colors.grey.shade700,
                            fontSize: 11.6,
                            height: 1.28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: primaryColor,
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                onTap: onOpenChatTap,
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  height: 46,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Abrir Chat Lokally',
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 13.1,
                        ),
                      ),
                    ],
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

class StoreCustomerServiceChatScreen extends StatefulWidget {
  final StoreCustomerOrderItem order;

  const StoreCustomerServiceChatScreen({
    super.key,
    required this.order,
  });

  @override
  State<StoreCustomerServiceChatScreen> createState() =>
      _StoreCustomerServiceChatScreenState();
}

class _StoreCustomerServiceChatScreenState
    extends State<StoreCustomerServiceChatScreen> {
  static const List<String> allowedFileExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'svg',
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'csv',
    'zip',
    'rar',
    '7z',
    'psd',
    'ai',
    'eps',
    'cdr',
  ];

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool isLoading = false;
  bool isSending = false;
  bool noticeModalShown = false;

  StoreCustomerServiceChatThread? thread;
  StoreCustomerServiceChatSafetyNotice? safetyNotice;
  List<StoreCustomerServiceChatMessage> messages =
      <StoreCustomerServiceChatMessage>[];

  String get chatUri =>
      '/api/customer/store/service-chat/order/${widget.order.id}';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadChat();
    });
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> loadChat() async {
    if (isLoading) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    final Response response = await Get.find<ApiClient>().getData(chatUri);

    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = false;
    });

    final dynamic body = response.body;

    if (response.statusCode != 200 || body is! Map || body['status'] != true) {
      showChatMessage(
        body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Não foi possível abrir o Chat Lokally.',
      );
      return;
    }

    final dynamic dataValue = body['data'];
    final Map<String, dynamic> data = dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : <String, dynamic>{};

    final dynamic threadValue = data['thread'];
    final dynamic noticeValue = data['safety_notice'];
    final dynamic messagesValue = data['messages'];

    setState(() {
      thread = threadValue is Map
          ? StoreCustomerServiceChatThread.fromMap(
              Map<String, dynamic>.from(threadValue),
            )
          : null;
      safetyNotice = noticeValue is Map
          ? StoreCustomerServiceChatSafetyNotice.fromMap(
              Map<String, dynamic>.from(noticeValue),
            )
          : null;
      messages = messagesValue is List
          ? messagesValue
              .whereType<Map>()
              .map(
                (item) => StoreCustomerServiceChatMessage.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : <StoreCustomerServiceChatMessage>[];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToEnd();
      final StoreCustomerServiceChatThread? currentThread = thread;
      if (currentThread != null &&
          !currentThread.safetyNoticeAccepted &&
          !noticeModalShown) {
        noticeModalShown = true;
        showSafetyNoticeModal();
      }
    });
  }

  Future<void> acceptSafetyNotice() async {
    final Response response = await Get.find<ApiClient>().postData(
      '$chatUri/safety-notice',
      <String, dynamic>{},
    );

    final dynamic body = response.body;

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        body is Map &&
        body['status'] == true) {
      final dynamic dataValue = body['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};
      final dynamic threadValue = data['thread'];

      if (threadValue is Map) {
        setState(() {
          thread = StoreCustomerServiceChatThread.fromMap(
            Map<String, dynamic>.from(threadValue),
          );
        });
      }
    }
  }

  String get allowedFileExtensionsText {
    return allowedFileExtensions
        .map((extension) => extension.toUpperCase())
        .join(', ');
  }

  Future<void> sendTextMessage() async {
    final String message = messageController.text.trim();

    if (message.isEmpty || isSending) {
      return;
    }

    messageController.clear();
    await sendMessage(message: message);
  }

  Future<bool> showFileAttachmentInstructions() async {
    final Color primaryColor = Theme.of(context).primaryColor;

    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
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
                        color: primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.attach_file_rounded,
                        color: primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Anexar arquivo ao serviço',
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Você pode enviar arquivos para o vendedor executar o serviço, como marca, briefing, imagens, documentos e arquivos de criação.',
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 12.6,
                    height: 1.34,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Formatos permitidos: $allowedFileExtensionsText. Limite por arquivo: até 50 MB.',
                    style: textMedium.copyWith(
                      color: primaryColor,
                      fontSize: 11.6,
                      height: 1.28,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(true),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      height: 46,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'Selecionar arquivo',
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 13.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Material(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(false),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      height: 44,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'Cancelar',
                        style: textBold.copyWith(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
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

    return confirmed == true;
  }

  Future<void> pickAndSendFile() async {
    if (isSending) {
      return;
    }

    final bool canPick = await showFileAttachmentInstructions();

    if (!canPick) {
      return;
    }

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedFileExtensions,
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final PlatformFile selectedFile = result.files.single;
    final String? path = selectedFile.path;

    if (path == null || path.trim().isEmpty) {
      showChatMessage('Não foi possível acessar o arquivo selecionado.');
      return;
    }

    final String message = messageController.text.trim();
    messageController.clear();

    await sendMessage(
      message: message,
      file: XFile(path, name: selectedFile.name),
    );
  }

  Future<void> sendMessage({
    required String message,
    XFile? file,
  }) async {
    if ((message.trim().isEmpty && file == null) || isSending) {
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      Response response;

      if (file != null) {
        response = await Get.find<ApiClient>().postMultipartData(
          '$chatUri/message',
          <String, String>{
            'message': message,
            'file_original_name': file.name,
            'file_extension': StoreChatFileHelper.extensionFromName(file.name),
          },
          MultipartBody('file', file),
          <MultipartBody>[],
        );
      } else {
        response = await Get.find<ApiClient>().postData(
          '$chatUri/message',
          <String, dynamic>{
            'message': message,
          },
        );
      }

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body is Map &&
          body['status'] == true) {
        final dynamic dataValue = body['data'];
        final Map<String, dynamic> data = dataValue is Map
            ? Map<String, dynamic>.from(dataValue)
            : <String, dynamic>{};
        final dynamic messageValue = data['message'];

        if (messageValue is Map) {
          setState(() {
            messages.add(
              StoreCustomerServiceChatMessage.fromMap(
                Map<String, dynamic>.from(messageValue),
              ),
            );
          });
        }

        scrollToEnd();
        return;
      }

      showChatMessage(
        body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Não foi possível enviar a mensagem.',
      );
    } catch (_) {
      if (mounted) {
        showChatMessage('Não foi possível enviar a mensagem.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  void scrollToEnd() {
    if (!scrollController.hasClients) {
      return;
    }

    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void showChatMessage(String message) {
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

  Future<void> showSafetyNoticeModal() async {
    final StoreCustomerServiceChatSafetyNotice notice =
        safetyNotice ?? StoreCustomerServiceChatSafetyNotice.defaultNotice();
    final Color primaryColor = Theme.of(context).primaryColor;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
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
                        color: primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: primaryColor,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        notice.title,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  notice.message,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 12.8,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                ...notice.details.map(
                  (detail) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            detail,
                            style: textRegular.copyWith(
                              color: Colors.grey.shade700,
                              fontSize: 11.8,
                              height: 1.28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () async {
                      await acceptSafetyNotice();
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 48,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'Entendi e quero continuar',
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 13.4,
                        ),
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

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F6),
        body: BodyWidget(
          appBar: AppBarWidget(title: 'Chat Lokally'.tr),
          body: Column(
            children: [
              Expanded(
                child: isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: primaryColor,
                          strokeWidth: 2.4,
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        children: [
                          StoreCustomerSurface(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Atendimento do serviço',
                                  style: textBold.copyWith(
                                    color: Colors.black87,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${widget.order.orderNumber} • ${widget.order.serviceDeliveryLabel}',
                                  style: textRegular.copyWith(
                                    color: Colors.grey.shade600,
                                    fontSize: 12.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (messages.isEmpty)
                            StoreCustomerSurface(
                              child: Text(
                                'Envie uma mensagem para combinar os detalhes do serviço com segurança pelo Chat Lokally.',
                                style: textRegular.copyWith(
                                  color: Colors.grey.shade700,
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                            )
                          else
                            ...messages.map(
                              (message) => StoreCustomerServiceChatBubble(
                                message: message,
                                primaryColor: primaryColor,
                              ),
                            ),
                        ],
                      ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  12,
                  10,
                  12,
                  MediaQuery.of(context).padding.bottom + 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: isSending ? null : pickAndSendFile,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.attach_file_rounded,
                          color: primaryColor,
                          size: 21,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Escreva sua mensagem...',
                          filled: true,
                          fillColor: const Color(0xFFF4F6F6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: isSending ? null : sendTextMessage,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: isSending
                            ? const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.2,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 21,
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

class StoreCustomerServiceChatBubble extends StatelessWidget {
  final StoreCustomerServiceChatMessage message;
  final Color primaryColor;

  const StoreCustomerServiceChatBubble({
    super.key,
    required this.message,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMine = message.senderType == 'customer';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMine ? primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: isMine ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.message.isNotEmpty)
              Text(
                message.message,
                style: textRegular.copyWith(
                  color: isMine ? Colors.white : Colors.black87,
                  fontSize: 12.8,
                  height: 1.3,
                ),
              ),
            if (message.hasFile) ...[
              if (message.message.isNotEmpty) const SizedBox(height: 8),
              StoreServiceChatFilePreview(
                fileName: message.fileDisplayName,
                fileUrl: message.fileUrl,
                isMine: isMine,
                primaryColor: primaryColor,
              ),
            ],
          ],
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

class StoreCustomerReleaseActionBlock extends StatelessWidget {
  final StoreCustomerOrderItem order;
  final Color primaryColor;
  final VoidCallback onAuthorizeTap;
  final VoidCallback onDisputeTap;

  const StoreCustomerReleaseActionBlock({
    super.key,
    required this.order,
    required this.primaryColor,
    required this.onAuthorizeTap,
    required this.onDisputeTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool waitingAuthorization =
        order.releaseStatus == 'pending_customer_authorization';
    final bool disputed = order.releaseStatus == 'disputed';
    final bool disputeFinalized = order.isDisputeFinalized;
    final bool authorized = !disputeFinalized &&
        (order.releaseStatus == 'authorized' ||
            order.releaseStatus == 'auto_authorized');

    final String title = disputeFinalized
        ? 'Disputa encerrada pela Lokally'
        : authorized
            ? 'Pedido finalizado'
            : disputed
                ? 'Disputa aberta'
                : order.releaseStatusLabel.isEmpty
                    ? 'Liberação de repasse'
                    : order.releaseStatusLabel;

    final String disputeFinalMessage = order.disputeResolutionMessage.trim();
    final String message = disputeFinalized
        ? (disputeFinalMessage.isNotEmpty
            ? disputeFinalMessage
            : 'A disputa foi encerrada pela Lokally.')
        : waitingAuthorization
            ? 'O vendedor informou que o pedido foi entregue. Autorize o repasse somente se recebeu tudo corretamente. Se houver problema, abra uma disputa.'
            : disputed
                ? 'A disputa foi aberta e será analisada pela equipe Lokally.'
                : 'O repasse foi autorizado com sucesso. Este pedido foi finalizado.';

    final Color blockColor = disputeFinalized
        ? Colors.orangeAccent
        : disputed
            ? Colors.redAccent
            : authorized
                ? primaryColor
                : Colors.orangeAccent;

    return StoreCustomerSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                disputeFinalized
                    ? Icons.gavel_outlined
                    : disputed
                        ? Icons.report_problem_outlined
                        : authorized
                            ? Icons.verified_outlined
                            : Icons.payments_outlined,
                color: blockColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 15.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (disputeFinalized &&
                        order.disputeResolutionTargetLabel.isNotEmpty) ...[
                      Text(
                        order.disputeResolutionTargetLabel,
                        style: textBold.copyWith(
                          color: Colors.orange.shade900,
                          fontSize: 12.2,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      message,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade700,
                        fontSize: 12.2,
                        height: 1.34,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (order.releaseAutoAuthorizeAt.isNotEmpty &&
              waitingAuthorization) ...[
            const SizedBox(height: 10),
            StoreCustomerInfoBlock(
              icon: Icons.schedule_outlined,
              title: 'Prazo de resposta',
              value:
                  'Você tem até 24h para autorizar o repasse ou abrir disputa. Após esse prazo, o sistema poderá liberar automaticamente.',
            ),
          ],
          if (waitingAuthorization) ...[
            const SizedBox(height: 12),
            Material(
              color: primaryColor,
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                onTap: onAuthorizeTap,
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  height: 46,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Text(
                    'AUTORIZAR REPASSE',
                    style: textBold.copyWith(
                      color: Colors.white,
                      fontSize: 13.1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Material(
              color: Colors.redAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                onTap: onDisputeTap,
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  height: 44,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Text(
                    'ABRIR DISPUTA',
                    style: textBold.copyWith(
                      color: Colors.redAccent,
                      fontSize: 13,
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

class StoreCustomerDisputeShortcutBlock extends StatelessWidget {
  final StoreCustomerOrderItem order;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreCustomerDisputeShortcutBlock({
    super.key,
    required this.order,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StoreCustomerSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.support_agent_outlined,
                color: Colors.redAccent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disputa Lokally',
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 15.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A disputa será tratada entre você e a equipe Lokally. O vendedor responde para a Lokally em uma linha separada da tratativa.',
                      style: textRegular.copyWith(
                        color: Colors.grey.shade700,
                        fontSize: 12.2,
                        height: 1.34,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StoreCustomerInfoBlock(
            icon: Icons.schedule_outlined,
            title: 'Prazo da análise',
            value:
                'A análise da disputa pode levar até 7 dias. Acompanhe as solicitações e respostas pela timeline da disputa.',
          ),
          const SizedBox(height: 12),
          Material(
            color: primaryColor,
            borderRadius: BorderRadius.circular(17),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(17),
              child: Container(
                height: 46,
                width: double.infinity,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.timeline_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Acompanhar disputa',
                      style: textBold.copyWith(
                        color: Colors.white,
                        fontSize: 13.1,
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

class StoreCustomerDisputeTicketScreen extends StatefulWidget {
  final StoreCustomerOrderItem order;

  const StoreCustomerDisputeTicketScreen({
    super.key,
    required this.order,
  });

  @override
  State<StoreCustomerDisputeTicketScreen> createState() =>
      _StoreCustomerDisputeTicketScreenState();
}

class _StoreCustomerDisputeTicketScreenState
    extends State<StoreCustomerDisputeTicketScreen> {
  static const List<String> allowedFileExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'svg',
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'csv',
    'zip',
    'rar',
    '7z',
    'psd',
    'ai',
    'eps',
    'cdr',
  ];

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool isLoading = false;
  bool isSending = false;

  StoreCustomerOrderDispute? dispute;
  List<StoreCustomerOrderDisputeMessage> messages =
      <StoreCustomerOrderDisputeMessage>[];

  String get disputeUri =>
      '/api/customer/store/order-disputes/${widget.order.id}';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadDispute();
    });
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  String get allowedFileExtensionsText {
    return allowedFileExtensions
        .map((extension) => extension.toUpperCase())
        .join(', ');
  }

  Future<void> loadDispute() async {
    if (isLoading) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    final Response response = await Get.find<ApiClient>().getData(disputeUri);

    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = false;
    });

    final dynamic body = response.body;

    if (response.statusCode != 200 || body is! Map || body['status'] != true) {
      showDisputeMessage(
        body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Não foi possível carregar a disputa.',
      );
      return;
    }

    final dynamic dataValue = body['data'];
    final Map<String, dynamic> data = dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : <String, dynamic>{};

    final dynamic disputeValue = data['dispute'];
    final dynamic messagesValue = data['messages'];

    setState(() {
      dispute = disputeValue is Map
          ? StoreCustomerOrderDispute.fromMap(
              Map<String, dynamic>.from(disputeValue),
            )
          : null;
      messages = messagesValue is List
          ? messagesValue
              .whereType<Map>()
              .map(
                (item) => StoreCustomerOrderDisputeMessage.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : <StoreCustomerOrderDisputeMessage>[];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToEnd();
    });
  }

  Future<void> sendTextMessage() async {
    final String message = messageController.text.trim();

    if (message.isEmpty || isSending) {
      return;
    }

    messageController.clear();
    await sendMessage(message: message);
  }

  Future<bool> showFileAttachmentInstructions() async {
    final Color primaryColor = Theme.of(context).primaryColor;

    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
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
                        color: primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.attach_file_rounded,
                        color: primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Anexar arquivo à disputa',
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Envie comprovantes, imagens, briefing, documentos ou arquivos que ajudem a equipe Lokally a analisar a disputa.',
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 12.6,
                    height: 1.34,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Formatos permitidos: $allowedFileExtensionsText. Limite por arquivo: até 50 MB.',
                    style: textMedium.copyWith(
                      color: primaryColor,
                      fontSize: 11.6,
                      height: 1.28,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(true),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      height: 46,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'Selecionar arquivo',
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 13.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Material(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(false),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      height: 44,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'Cancelar',
                        style: textBold.copyWith(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
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

    return confirmed == true;
  }

  Future<void> pickAndSendFile() async {
    if (isSending) {
      return;
    }

    final bool canPick = await showFileAttachmentInstructions();

    if (!canPick) {
      return;
    }

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedFileExtensions,
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final PlatformFile selectedFile = result.files.single;
    final String? path = selectedFile.path;

    if (path == null || path.trim().isEmpty) {
      showDisputeMessage('Não foi possível acessar o arquivo selecionado.');
      return;
    }

    final String message = messageController.text.trim();
    messageController.clear();

    await sendMessage(
      message: message,
      file: XFile(path, name: selectedFile.name),
    );
  }

  Future<void> sendMessage({
    required String message,
    XFile? file,
  }) async {
    if ((message.trim().isEmpty && file == null) || isSending) {
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      Response response;

      if (file != null) {
        response = await Get.find<ApiClient>().postMultipartData(
          '$disputeUri/message',
          <String, String>{
            'message': message,
            'file_original_name': file.name,
            'file_extension': StoreChatFileHelper.extensionFromName(file.name),
          },
          MultipartBody('file', file),
          <MultipartBody>[],
        );
      } else {
        response = await Get.find<ApiClient>().postData(
          '$disputeUri/message',
          <String, dynamic>{
            'message': message,
          },
        );
      }

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body is Map &&
          body['status'] == true) {
        final dynamic dataValue = body['data'];
        final Map<String, dynamic> data = dataValue is Map
            ? Map<String, dynamic>.from(dataValue)
            : <String, dynamic>{};
        final dynamic messageValue = data['message'];

        if (messageValue is Map) {
          setState(() {
            messages.add(
              StoreCustomerOrderDisputeMessage.fromMap(
                Map<String, dynamic>.from(messageValue),
              ),
            );
          });
        }

        scrollToEnd();
        return;
      }

      showDisputeMessage(
        body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Não foi possível enviar a mensagem.',
      );
    } catch (_) {
      if (mounted) {
        showDisputeMessage('Não foi possível enviar a mensagem.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  void scrollToEnd() {
    if (!scrollController.hasClients) {
      return;
    }

    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void showDisputeMessage(String message) {
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
    final StoreCustomerOrderDispute? currentDispute = dispute;

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F6),
        body: BodyWidget(
          appBar: AppBarWidget(title: 'Disputa Lokally'.tr),
          body: Column(
            children: [
              Expanded(
                child: isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: primaryColor,
                          strokeWidth: 2.4,
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        children: [
                          StoreCustomerSurface(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent
                                            .withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: const Icon(
                                        Icons.report_problem_outlined,
                                        color: Colors.redAccent,
                                        size: 23,
                                      ),
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ticket de disputa',
                                            style: textBold.copyWith(
                                              color: Colors.black87,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            widget.order.orderNumber,
                                            style: textRegular.copyWith(
                                              color: Colors.grey.shade600,
                                              fontSize: 12.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                StoreCustomerInfoBlock(
                                  icon: Icons.support_agent_outlined,
                                  title: currentDispute?.statusLabel ??
                                      'Disputa aberta',
                                  value:
                                      'A tratativa acontece entre você e a equipe Lokally. O lojista responde para a Lokally em uma timeline separada.',
                                ),
                                const SizedBox(height: 10),
                                StoreCustomerInfoBlock(
                                  icon: Icons.schedule_outlined,
                                  title: 'Prazo de análise',
                                  value:
                                      'A análise pode levar até 7 dias. ${currentDispute?.deadlineAt.isNotEmpty == true ? 'Prazo estimado: ${currentDispute!.deadlineAt}.' : ''}',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (messages.isEmpty)
                            StoreCustomerSurface(
                              child: Text(
                                'A equipe Lokally irá responder por aqui. Envie detalhes e comprovantes que ajudem na análise da disputa.',
                                style: textRegular.copyWith(
                                  color: Colors.grey.shade700,
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                            )
                          else
                            ...messages.map(
                              (message) => StoreCustomerDisputeTimelineItem(
                                message: message,
                                primaryColor: primaryColor,
                              ),
                            ),
                        ],
                      ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  12,
                  10,
                  12,
                  MediaQuery.of(context).padding.bottom + 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: isSending ? null : pickAndSendFile,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.attach_file_rounded,
                          color: primaryColor,
                          size: 21,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Responder à Lokally...',
                          filled: true,
                          fillColor: const Color(0xFFF4F6F6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: isSending ? null : sendTextMessage,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: isSending
                            ? const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.2,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 21,
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

class StoreCustomerDisputeTimelineItem extends StatelessWidget {
  final StoreCustomerOrderDisputeMessage message;
  final Color primaryColor;

  const StoreCustomerDisputeTimelineItem({
    super.key,
    required this.message,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMine = message.senderType == 'customer';
    final bool isLokally = message.senderType == 'lokally';
    final Color bubbleColor = isMine
        ? primaryColor
        : isLokally
            ? Colors.white
            : Colors.orangeAccent.withValues(alpha: 0.10);
    final Color borderColor =
        isLokally ? primaryColor.withValues(alpha: 0.20) : Colors.grey.shade200;
    final Color textColor = isMine ? Colors.white : Colors.black87;
    final Color helperColor =
        isMine ? Colors.white.withValues(alpha: 0.76) : Colors.grey.shade600;
    final String senderLabel = isMine
        ? 'Você'
        : isLokally
            ? 'Lokally'
            : 'Atualização';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: isMine ? null : Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              senderLabel,
              style: textBold.copyWith(
                color: isMine ? Colors.white : primaryColor,
                fontSize: 11.2,
              ),
            ),
            if (message.message.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                message.message,
                style: textRegular.copyWith(
                  color: textColor,
                  fontSize: 12.8,
                  height: 1.3,
                ),
              ),
            ],
            if (message.hasFile) ...[
              const SizedBox(height: 8),
              StoreServiceChatFilePreview(
                fileName: message.fileDisplayName,
                fileUrl: message.fileUrl,
                isMine: isMine,
                primaryColor: primaryColor,
              ),
            ],
            if (message.createdAt.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                message.createdAt,
                style: textRegular.copyWith(
                  color: helperColor,
                  fontSize: 9.8,
                ),
              ),
            ],
          ],
        ),
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
  final bool containsServiceItems;
  final bool containsPhysicalItems;
  final bool isServiceOrder;
  final bool isMixedOrder;
  final String serviceDeliveryType;
  final String serviceDeliveryLabel;
  final String serviceDeliveryDescription;
  final String serviceActionLabel;
  final bool serviceChatAvailable;
  final String lokallyGuaranteeMessage;
  final String releaseStatus;
  final String releaseStatusLabel;
  final String sellerCompletedAt;
  final String releaseRequestedAt;
  final String releaseAutoAuthorizeAt;
  final String payoutAuthorizedAt;
  final String payoutAuthorizedBy;
  final String disputeOpenedAt;
  final String disputeReason;
  final String disputeStatus;
  final String disputeStatusLabel;
  final String disputeResolutionTarget;
  final String disputeResolutionTargetLabel;
  final String disputeResolutionMessage;
  final String disputeResolvedAt;
  final bool isDisputeResolved;
  final bool canAuthorizePayout;
  final bool canOpenDispute;
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
    required this.containsServiceItems,
    required this.containsPhysicalItems,
    required this.isServiceOrder,
    required this.isMixedOrder,
    required this.serviceDeliveryType,
    required this.serviceDeliveryLabel,
    required this.serviceDeliveryDescription,
    required this.serviceActionLabel,
    required this.serviceChatAvailable,
    required this.lokallyGuaranteeMessage,
    required this.releaseStatus,
    required this.releaseStatusLabel,
    required this.sellerCompletedAt,
    required this.releaseRequestedAt,
    required this.releaseAutoAuthorizeAt,
    required this.payoutAuthorizedAt,
    required this.payoutAuthorizedBy,
    required this.disputeOpenedAt,
    required this.disputeReason,
    required this.disputeStatus,
    required this.disputeStatusLabel,
    required this.disputeResolutionTarget,
    required this.disputeResolutionTargetLabel,
    required this.disputeResolutionMessage,
    required this.disputeResolvedAt,
    required this.isDisputeResolved,
    required this.canAuthorizePayout,
    required this.canOpenDispute,
    required this.items,
  });

  bool get isPaymentApproved => paymentStatus == 'approved';

  bool get isPayoutAuthorized {
    return releaseStatus == 'authorized' ||
        releaseStatus == 'auto_authorized' ||
        orderStatus == 'payout_authorized' ||
        orderStatus == 'auto_payout_authorized' ||
        payoutAuthorizedAt.isNotEmpty;
  }

  bool get isDisputed {
    return releaseStatus == 'disputed' || orderStatus == 'dispute_opened';
  }

  bool get isDisputeFinalized {
    return isDisputeResolved ||
        disputeResolvedAt.isNotEmpty ||
        disputeStatus == 'resolved' ||
        disputeStatus == 'resolved_customer' ||
        disputeStatus == 'resolved_seller' ||
        disputeStatus == 'closed' ||
        releaseStatus == 'dispute_resolved_customer' ||
        releaseStatus == 'dispute_resolved_seller' ||
        orderStatus == 'dispute_resolved_customer' ||
        orderStatus == 'dispute_resolved_seller';
  }

  bool get isReleaseClosed {
    return isPayoutAuthorized || isDisputed || isDisputeFinalized;
  }

  bool get shouldShowServiceChatBlock {
    return isServiceOrder && !isReleaseClosed;
  }

  bool get shouldShowReleaseBlock {
    return releaseStatus.isNotEmpty || canAuthorizePayout || canOpenDispute;
  }

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
      sellerPhone: '${pickup['seller_phone'] ?? pickup['phone'] ?? ''}',
      sellerName: '${seller['name'] ?? ''}',
      sellerLogoUrl: '${seller['logo_url'] ?? ''}',
      createdAt: '${map['created_at'] ?? ''}',
      containsServiceItems:
          StoreCustomerOrderCurrency.parseBool(map['contains_service_items']),
      containsPhysicalItems:
          StoreCustomerOrderCurrency.parseBool(map['contains_physical_items']),
      isServiceOrder:
          StoreCustomerOrderCurrency.parseBool(map['is_service_order']),
      isMixedOrder: StoreCustomerOrderCurrency.parseBool(map['is_mixed_order']),
      serviceDeliveryType: '${map['service_delivery_type'] ?? ''}',
      serviceDeliveryLabel: '${map['service_delivery_label'] ?? 'Serviço'}',
      serviceDeliveryDescription:
          '${map['service_delivery_description'] ?? ''}',
      serviceActionLabel: '${map['service_action_label'] ?? ''}',
      serviceChatAvailable:
          StoreCustomerOrderCurrency.parseBool(map['service_chat_available']),
      lokallyGuaranteeMessage: '${map['lokally_guarantee_message'] ?? ''}',
      releaseStatus: '${map['release_status'] ?? ''}',
      releaseStatusLabel: '${map['release_status_label'] ?? ''}',
      sellerCompletedAt: '${map['seller_completed_at'] ?? ''}',
      releaseRequestedAt: '${map['release_requested_at'] ?? ''}',
      releaseAutoAuthorizeAt: '${map['release_auto_authorize_at'] ?? ''}',
      payoutAuthorizedAt: '${map['payout_authorized_at'] ?? ''}',
      payoutAuthorizedBy: '${map['payout_authorized_by'] ?? ''}',
      disputeOpenedAt: '${map['dispute_opened_at'] ?? ''}',
      disputeReason: '${map['dispute_reason'] ?? ''}',
      disputeStatus: '${map['dispute_status'] ?? ''}',
      disputeStatusLabel: '${map['dispute_status_label'] ?? ''}',
      disputeResolutionTarget: '${map['dispute_resolution_target'] ?? ''}',
      disputeResolutionTargetLabel:
          '${map['dispute_resolution_target_label'] ?? ''}',
      disputeResolutionMessage: '${map['dispute_resolution_message'] ?? ''}',
      disputeResolvedAt: '${map['dispute_resolved_at'] ?? ''}',
      isDisputeResolved:
          StoreCustomerOrderCurrency.parseBool(map['is_dispute_resolved']),
      canAuthorizePayout:
          StoreCustomerOrderCurrency.parseBool(map['can_authorize_payout']),
      canOpenDispute:
          StoreCustomerOrderCurrency.parseBool(map['can_open_dispute']),
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
  final String productType;
  final String conditionType;
  final String serviceDeliveryType;
  final String serviceDeliveryLabel;
  final String serviceDeliveryDescription;
  final bool isService;

  StoreCustomerOrderProductItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.total,
    required this.productType,
    required this.conditionType,
    required this.serviceDeliveryType,
    required this.serviceDeliveryLabel,
    required this.serviceDeliveryDescription,
    required this.isService,
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
      productType: '${map['product_type'] ?? 'physical'}',
      conditionType: '${map['condition_type'] ?? 'new'}',
      serviceDeliveryType: '${map['service_delivery_type'] ?? ''}',
      serviceDeliveryLabel: '${map['service_delivery_label'] ?? ''}',
      serviceDeliveryDescription:
          '${map['service_delivery_description'] ?? ''}',
      isService: StoreCustomerOrderCurrency.parseBool(map['is_service']) ||
          '${map['product_type'] ?? ''}' == 'service',
    );
  }
}

class StoreCustomerServiceChatThread {
  final String id;
  final String storeOrderId;
  final String status;
  final bool safetyNoticeAccepted;

  StoreCustomerServiceChatThread({
    required this.id,
    required this.storeOrderId,
    required this.status,
    required this.safetyNoticeAccepted,
  });

  factory StoreCustomerServiceChatThread.fromMap(Map<String, dynamic> map) {
    return StoreCustomerServiceChatThread(
      id: '${map['id'] ?? ''}',
      storeOrderId: '${map['store_order_id'] ?? ''}',
      status: '${map['status'] ?? ''}',
      safetyNoticeAccepted:
          StoreCustomerOrderCurrency.parseBool(map['safety_notice_accepted']),
    );
  }
}

class StoreCustomerServiceChatSafetyNotice {
  final String title;
  final String message;
  final List<String> details;

  StoreCustomerServiceChatSafetyNotice({
    required this.title,
    required this.message,
    required this.details,
  });

  factory StoreCustomerServiceChatSafetyNotice.fromMap(
    Map<String, dynamic> map,
  ) {
    final dynamic detailsValue = map['details'];

    return StoreCustomerServiceChatSafetyNotice(
      title: '${map['title'] ?? 'Garantia Lokally'}',
      message: '${map['message'] ?? ''}',
      details: detailsValue is List
          ? detailsValue.map((item) => item.toString()).toList()
          : <String>[],
    );
  }

  factory StoreCustomerServiceChatSafetyNotice.defaultNotice() {
    return StoreCustomerServiceChatSafetyNotice(
      title: 'Garantia Lokally',
      message:
          'Você tem a Garantia Lokally. Não troque informações de contato nem confirme recebimento antes de receber seu produto ou serviço.',
      details: const [
        'Mantenha as conversas e arquivos dentro do Chat Lokally sempre que possível.',
        'O pagamento fica protegido até a confirmação do recebimento do produto ou serviço.',
        'Não libere o recebimento se o serviço não foi entregue conforme combinado.',
      ],
    );
  }
}

class StoreServiceChatFilePreview extends StatelessWidget {
  final String fileName;
  final String fileUrl;
  final bool isMine;
  final Color primaryColor;

  const StoreServiceChatFilePreview({
    super.key,
    required this.fileName,
    required this.fileUrl,
    required this.isMine,
    required this.primaryColor,
  });

  Future<void> openFile() async {
    if (fileUrl.trim().isEmpty) {
      return;
    }

    final Uri? uri = Uri.tryParse(fileUrl);

    if (uri == null) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isMine
        ? Colors.white.withValues(alpha: 0.14)
        : primaryColor.withValues(alpha: 0.08);
    final Color iconColor = isMine ? Colors.white : primaryColor;
    final Color textColor = isMine ? Colors.white : Colors.black87;
    final Color helperColor =
        isMine ? Colors.white.withValues(alpha: 0.76) : Colors.grey.shade600;
    final String extension = StoreChatFileHelper.extensionFromName(fileName);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: fileUrl.trim().isEmpty ? null : openFile,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                StoreChatFileHelper.iconForExtension(extension),
                color: iconColor,
                size: 18,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName.isEmpty ? 'Arquivo anexado' : fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(
                        color: textColor,
                        fontSize: 11.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileUrl.trim().isEmpty
                          ? 'Arquivo sem link'
                          : 'Baixar / abrir',
                      style: textRegular.copyWith(
                        color: helperColor,
                        fontSize: 10.2,
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

class StoreChatFileHelper {
  static String extensionFromName(String name) {
    final String cleanName = name.split('?').first.trim();
    final int dotIndex = cleanName.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == cleanName.length - 1) {
      return '';
    }

    return cleanName.substring(dotIndex + 1).toLowerCase();
  }

  static String displayName({
    required String originalName,
    required String fileUrl,
    required String fallback,
  }) {
    final String cleanOriginal = originalName.trim();
    final String originalExtension = extensionFromName(cleanOriginal);
    final String urlExtension = extensionFromName(fileUrl);

    if (cleanOriginal.isEmpty) {
      return urlExtension.isEmpty ? fallback : '$fallback.$urlExtension';
    }

    if (urlExtension.isNotEmpty &&
        originalExtension.isNotEmpty &&
        originalExtension != urlExtension) {
      final int dotIndex = cleanOriginal.lastIndexOf('.');
      final String baseName =
          dotIndex == -1 ? cleanOriginal : cleanOriginal.substring(0, dotIndex);

      return '$baseName.$urlExtension';
    }

    return cleanOriginal;
  }

  static IconData iconForExtension(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
      case 'svg':
        return Icons.image_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
      case 'txt':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive_outlined;
      case 'psd':
      case 'ai':
      case 'eps':
      case 'cdr':
        return Icons.design_services_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}

class StoreCustomerServiceChatMessage {
  final String id;
  final String senderType;
  final String messageType;
  final String message;
  final String fileUrl;
  final String fileOriginalName;
  final String fileMimeType;
  final int? fileSize;
  final String createdAt;

  StoreCustomerServiceChatMessage({
    required this.id,
    required this.senderType,
    required this.messageType,
    required this.message,
    required this.fileUrl,
    required this.fileOriginalName,
    required this.fileMimeType,
    required this.fileSize,
    required this.createdAt,
  });

  bool get hasFile => fileUrl.isNotEmpty || fileOriginalName.isNotEmpty;

  String get fileDisplayName {
    return StoreChatFileHelper.displayName(
      originalName: fileOriginalName,
      fileUrl: fileUrl,
      fallback: 'Arquivo anexado',
    );
  }

  factory StoreCustomerServiceChatMessage.fromMap(Map<String, dynamic> map) {
    return StoreCustomerServiceChatMessage(
      id: '${map['id'] ?? ''}',
      senderType: '${map['sender_type'] ?? ''}',
      messageType: '${map['message_type'] ?? ''}',
      message: '${map['message'] ?? ''}',
      fileUrl: '${map['file_url'] ?? ''}',
      fileOriginalName: '${map['file_original_name'] ?? ''}',
      fileMimeType: '${map['file_mime_type'] ?? ''}',
      fileSize: int.tryParse('${map['file_size'] ?? ''}'),
      createdAt: '${map['created_at'] ?? ''}',
    );
  }
}

class StoreCustomerOrderDispute {
  final String id;
  final String storeOrderId;
  final String status;
  final String statusLabel;
  final String openedBy;
  final String openedAt;
  final String deadlineAt;
  final String resolvedAt;
  final String resolutionTarget;
  final String resolutionMessage;

  StoreCustomerOrderDispute({
    required this.id,
    required this.storeOrderId,
    required this.status,
    required this.statusLabel,
    required this.openedBy,
    required this.openedAt,
    required this.deadlineAt,
    required this.resolvedAt,
    required this.resolutionTarget,
    required this.resolutionMessage,
  });

  factory StoreCustomerOrderDispute.fromMap(Map<String, dynamic> map) {
    return StoreCustomerOrderDispute(
      id: '${map['id'] ?? ''}',
      storeOrderId: '${map['store_order_id'] ?? ''}',
      status: '${map['status'] ?? ''}',
      statusLabel: '${map['status_label'] ?? 'Disputa aberta'}',
      openedBy: '${map['opened_by'] ?? ''}',
      openedAt: '${map['opened_at'] ?? ''}',
      deadlineAt: '${map['deadline_at'] ?? ''}',
      resolvedAt: '${map['resolved_at'] ?? ''}',
      resolutionTarget: '${map['resolution_target'] ?? ''}',
      resolutionMessage: '${map['resolution_message'] ?? ''}',
    );
  }
}

class StoreCustomerOrderDisputeMessage {
  final String id;
  final String senderType;
  final String channel;
  final String messageType;
  final String message;
  final String fileUrl;
  final String fileOriginalName;
  final String fileMimeType;
  final int? fileSize;
  final String createdAt;

  StoreCustomerOrderDisputeMessage({
    required this.id,
    required this.senderType,
    required this.channel,
    required this.messageType,
    required this.message,
    required this.fileUrl,
    required this.fileOriginalName,
    required this.fileMimeType,
    required this.fileSize,
    required this.createdAt,
  });

  bool get hasFile => fileUrl.isNotEmpty || fileOriginalName.isNotEmpty;

  String get fileDisplayName {
    return StoreChatFileHelper.displayName(
      originalName: fileOriginalName,
      fileUrl: fileUrl,
      fallback: 'Arquivo da disputa',
    );
  }

  factory StoreCustomerOrderDisputeMessage.fromMap(Map<String, dynamic> map) {
    return StoreCustomerOrderDisputeMessage(
      id: '${map['id'] ?? ''}',
      senderType: '${map['sender_type'] ?? ''}',
      channel: '${map['channel'] ?? ''}',
      messageType: '${map['message_type'] ?? ''}',
      message: '${map['message'] ?? ''}',
      fileUrl: '${map['file_url'] ?? ''}',
      fileOriginalName: '${map['file_original_name'] ?? ''}',
      fileMimeType: '${map['file_mime_type'] ?? ''}',
      fileSize: int.tryParse('${map['file_size'] ?? ''}'),
      createdAt: '${map['created_at'] ?? ''}',
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

  static bool parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final String text = '$value'.toLowerCase().trim();

    return text == '1' || text == 'true' || text == 'yes' || text == 'sim';
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
