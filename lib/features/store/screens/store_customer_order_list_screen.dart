import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/store/screens/lokally_meeting_screen.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreCustomerOrderListScreen extends StatefulWidget {
  final String? initialOrderId;

  const StoreCustomerOrderListScreen({super.key, this.initialOrderId});

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
    StoreCustomerOrderFilter(
      keyName: 'all',
      label: 'store_all',
      apiFilter: 'all',
    ),
    StoreCustomerOrderFilter(
      keyName: 'pickup',
      label: 'store_pickup',
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
      showStoreMessage('store_customer_orders_load_error'.tr);
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
            (item) =>
                StoreCustomerOrderItem.fromMap(Map<String, dynamic>.from(item)),
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
      showStoreMessage('store_order_details_open_error'.tr);
      return;
    }

    final dynamic dataValue = body['data'];
    final Map<String, dynamic> data = dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : <String, dynamic>{};

    final dynamic orderValue = data['order'];

    if (orderValue is! Map) {
      showStoreMessage('store_order_not_found'.tr);
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
        backgroundColor: Colors.white,
        body: BodyWidget(
          appBar: AppBarWidget(title: 'store_my_orders'.tr),
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
            'store_my_lokally_marketplace_orders'.tr,
            style: textBold.copyWith(color: Colors.black87, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            'store_my_lokally_marketplace_orders_description'.tr,
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
                  label: 'store_pickup'.tr,
                  icon: Icons.storefront_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StoreCustomerOrderMiniCount(
                  primaryColor: primaryColor,
                  value: counts.lokallyShipping.toString(),
                  label: 'store_shipments'.tr,
                  icon: Icons.local_shipping_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StoreCustomerOrderMiniCount(
                  primaryColor: Colors.orangeAccent,
                  value: counts.readyForPickup.toString(),
                  label: 'store_ready_plural'.tr,
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
          Icon(icon, color: primaryColor, size: 19),
          const SizedBox(height: 6),
          Text(
            value,
            style: textBold.copyWith(color: Colors.black87, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            label.tr,
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
                    'store_filter_with_count'.trParams({
                      'label': filter.label.tr,
                      'count': '${countForFilter(filter.keyName)}',
                    }),
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
      case 'service_completed':
        return primaryColor;
      case 'cancelled':
      case 'dispute_opened':
        return Colors.redAccent;
      case 'lokally_shipping_pending':
      case 'payment_approved':
      case 'preparing':
      case 'awaiting_customer_release':
      case 'service_requested':
      case 'service_chat_open':
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }

  IconData get deliveryIcon {
    if (order.isServiceRequestOrder) {
      return Icons.support_agent_outlined;
    }

    return order.deliveryType == 'pickup'
        ? Icons.storefront_rounded
        : Icons.local_shipping_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
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
                          order.sellerName.isEmpty
                              ? 'store_store'.tr
                              : order.sellerName,
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
                    style: textBold.copyWith(color: primaryColor, fontSize: 14),
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
                  'store_more_items_count'.trParams({
                    'count': '${order.items.length - 2}',
                  }),
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
                    'store_view_details'.tr,
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

  const StoreCustomerOrderDetailsScreen({super.key, required this.order});

  @override
  State<StoreCustomerOrderDetailsScreen> createState() =>
      _StoreCustomerOrderDetailsScreenState();
}

class _StoreCustomerOrderDetailsScreenState
    extends State<StoreCustomerOrderDetailsScreen> {
  late StoreCustomerOrderItem order;
  bool isCreatingMercadoPagoPayment = false;
  bool isLoadingServiceProgress = false;
  StoreCustomerServiceProgressData serviceProgress =
      StoreCustomerServiceProgressData.empty();

  @override
  void initState() {
    super.initState();
    order = widget.order;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadServiceProgress();
    });
  }

  Future<void> loadServiceProgress() async {
    if (!order.isServiceOrder || isLoadingServiceProgress) {
      return;
    }

    setState(() {
      isLoadingServiceProgress = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().getData(
        '/api/customer/store/service-chat/order/${order.id}',
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
        final dynamic threadValue = data['thread'];

        if (threadValue is Map) {
          final Map<String, dynamic> threadMap = Map<String, dynamic>.from(
            threadValue,
          );
          setState(() {
            serviceProgress = StoreCustomerServiceProgressData.fromMap(
              threadMap['service_progress'] is Map
                  ? Map<String, dynamic>.from(threadMap['service_progress'])
                  : <String, dynamic>{},
            );
          });
        }
      }
    } catch (_) {
      // Mantém progresso 0% caso o chat ainda não esteja disponível.
    } finally {
      if (mounted) {
        setState(() {
          isLoadingServiceProgress = false;
        });
      }
    }
  }

  void showServiceEvaluationMessage() {
    showDetailsMessage(
      context,
      'Avaliação do serviço será liberada na próxima etapa do fluxo.',
    );
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
      case 'service_requested':
      case 'service_chat_open':
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }

  IconData orderIcon() {
    if (order.isServiceRequestOrder) {
      return Icons.support_agent_outlined;
    }

    return order.deliveryType == 'pickup'
        ? Icons.storefront_rounded
        : Icons.local_shipping_outlined;
  }

  Future<void> openServiceChat() async {
    await Get.to(() => StoreCustomerServiceChatScreen(order: order));

    if (mounted) {
      await loadServiceProgress();
    }
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

  bool get canPayWithMercadoPago {
    final String method = order.paymentMethod.toLowerCase().trim();
    final String status = order.paymentStatus.toLowerCase().trim();
    final String orderStatus = order.orderStatus.toLowerCase().trim();

    return status != 'approved' &&
        (method == 'mercadopago' || method == 'stripe_card') &&
        (orderStatus.isEmpty || orderStatus == 'pending_payment');
  }

  String paymentUrlFromResponse(Map<String, dynamic> data) {
    final dynamic directPaymentUrl = data['payment_url'];

    if (directPaymentUrl != null && '$directPaymentUrl'.trim().isNotEmpty) {
      return '$directPaymentUrl'.trim();
    }

    final dynamic paymentValue = data['payment'];

    if (paymentValue is Map) {
      final Map<String, dynamic> payment = Map<String, dynamic>.from(
        paymentValue,
      );
      final dynamic nestedPaymentUrl = payment['payment_url'];

      if (nestedPaymentUrl != null && '$nestedPaymentUrl'.trim().isNotEmpty) {
        return '$nestedPaymentUrl'.trim();
      }
    }

    return '';
  }

  Future<void> reloadOrderDetails() async {
    final Response response = await Get.find<ApiClient>().getData(
      '/api/customer/store/orders/${order.id}',
    );

    if (!mounted) {
      return;
    }

    final dynamic body = response.body;

    if (response.statusCode != 200 || body is! Map || body['status'] != true) {
      return;
    }

    final dynamic dataValue = body['data'];
    final Map<String, dynamic> data = dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : <String, dynamic>{};
    final dynamic orderValue = data['order'];

    if (orderValue is Map) {
      setState(() {
        order = StoreCustomerOrderItem.fromMap(
          Map<String, dynamic>.from(orderValue),
        );
      });
    }
  }

  Future<void> payPendingMercadoPago(BuildContext context) async {
    if (!canPayWithMercadoPago || isCreatingMercadoPagoPayment) {
      return;
    }

    final Color primaryColor = Theme.of(context).primaryColor;

    setState(() {
      isCreatingMercadoPagoPayment = true;
    });

    final Response response = await Get.find<ApiClient>().postData(
      '/api/customer/store/orders/${order.id}/payment',
      <String, dynamic>{},
    );

    if (!mounted) {
      return;
    }

    setState(() {
      isCreatingMercadoPagoPayment = false;
    });

    final dynamic body = response.body;

    if ((response.statusCode != 200 && response.statusCode != 201) ||
        body is! Map ||
        body['status'] != true) {
      showDetailsMessage(
        context,
        body is Map && body['message'] != null
            ? body['message'].toString()
            : 'store_mercado_pago_payment_create_error'.tr,
      );
      return;
    }

    final dynamic dataValue = body['data'];
    final Map<String, dynamic> data = dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : <String, dynamic>{};
    final String paymentUrl = paymentUrlFromResponse(data);

    if (paymentUrl.isEmpty) {
      showDetailsMessage(context, 'store_mercado_pago_payment_link_missing'.tr);
      return;
    }

    final dynamic result = await Get.to(
      () => StoreCustomerMercadoPagoWebViewScreen(
        paymentUrl: paymentUrl,
        primaryColor: primaryColor,
      ),
    );

    if (!mounted) {
      return;
    }

    await reloadOrderDetails();

    showDetailsMessage(
      context,
      result == true
          ? 'store_payment_finished_order_details_updated'.tr
          : 'store_wait_mercado_pago_confirmation'.tr,
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
                  title.tr,
                  style: textBold.copyWith(color: Colors.black87, fontSize: 17),
                ),
                const SizedBox(height: 9),
                Text(
                  message.tr,
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
                        confirmLabel.tr,
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
                        'store_cancel'.tr,
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
      showDetailsMessage(
        context,
        'store_order_not_waiting_payout_authorization',
      );
      return;
    }

    final bool confirmed = await confirmSimpleAction(
      context: context,
      title: 'store_authorize_payout',
      message: 'store_authorize_payout_confirmation',
      confirmLabel: 'store_authorize_payout_upper',
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

      showDetailsMessage(context, 'store_payout_authorized_success');
      return;
    }

    showDetailsMessage(
      context,
      body is Map && body['message'] != null
          ? body['message'].toString()
          : 'store_payout_authorize_error',
    );
  }

  Future<void> openDispute(BuildContext context) async {
    if (!order.canOpenDispute) {
      showDetailsMessage(context, 'store_order_dispute_not_allowed');
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
                    'store_open_dispute'.tr,
                    style: textBold.copyWith(
                      color: Colors.black87,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'store_open_dispute_description'.tr,
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
                      hintText: 'store_describe_problem_found'.tr,
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
                          'store_open_dispute_upper'.tr,
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
                          'store_cancel'.tr,
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
      <String, dynamic>{'dispute_reason': reason},
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

      showDetailsMessage(context, 'store_dispute_opened_success');
      return;
    }

    showDetailsMessage(
      context,
      body is Map && body['message'] != null
          ? body['message'].toString()
          : 'store_open_dispute_error',
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
        backgroundColor: Colors.white,
        body: BodyWidget(
          appBar: AppBarWidget(title: 'store_order_details'.tr),
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
                                order.isServiceRequestOrder
                                    ? 'Solicitação de serviço'
                                    : order.sellerName.isEmpty
                                        ? 'store_store'.tr
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
                      label: order.serviceHeaderStatusLabel,
                      color: order.isServiceRequestOrder
                          ? orderStatusColor(primaryColor)
                          : paymentStatusColor(primaryColor),
                    ),
                    const SizedBox(height: 14),
                    StoreCustomerSimpleLine(
                      label: order.isServiceRequestOrder
                          ? 'Formato'
                          : 'store_delivery',
                      value: order.isServiceRequestOrder
                          ? order.serviceDeliveryLabel
                          : order.deliveryTypeLabel,
                    ),
                    const SizedBox(height: 6),
                    StoreCustomerSimpleLine(
                      label: 'store_payment',
                      value: order.paymentMethodLabel,
                    ),
                    if (showOrderStatusLine) ...[
                      const SizedBox(height: 6),
                      StoreCustomerSimpleLine(
                        label: 'store_order_status',
                        value: order.orderStatusLabel,
                      ),
                    ],
                    const SizedBox(height: 6),
                    StoreCustomerSimpleLine(
                      label: 'store_total',
                      value: StoreCustomerOrderCurrency.format(order.total),
                      highlight: true,
                      primaryColor: primaryColor,
                    ),
                    if (canPayWithMercadoPago) ...[
                      const SizedBox(height: 14),
                      StoreCustomerPendingMercadoPagoPaymentBlock(
                        primaryColor: primaryColor,
                        isLoading: isCreatingMercadoPagoPayment,
                        onTap: () => payPendingMercadoPago(context),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (order.shouldShowServiceChatBlock)
                StoreCustomerServiceOrderDetails(
                  order: order,
                  primaryColor: primaryColor,
                  progress: serviceProgress,
                  onOpenChatTap: openServiceChat,
                  onEvaluateTap: showServiceEvaluationMessage,
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
                      order.isServiceRequestOrder
                          ? 'Serviço solicitado'
                          : 'store_products'.tr,
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

class StoreCustomerPendingMercadoPagoPaymentBlock extends StatelessWidget {
  final Color primaryColor;
  final bool isLoading;
  final VoidCallback onTap;

  const StoreCustomerPendingMercadoPagoPaymentBlock({
    super.key,
    required this.primaryColor,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryColor.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.payment_rounded, color: primaryColor, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'store_payment_pending'.tr,
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 13.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'store_pending_mp_payment_description'.tr,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade700,
                        fontSize: 11.9,
                        height: 1.30,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: primaryColor,
            borderRadius: BorderRadius.circular(17),
            child: InkWell(
              onTap: isLoading ? null : onTap,
              borderRadius: BorderRadius.circular(17),
              child: Container(
                height: 46,
                width: double.infinity,
                alignment: Alignment.center,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'store_pay_with_mercado_pago'.tr,
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 13.2,
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

class StoreCustomerServiceProgressStepData {
  final String key;
  final String label;
  final String actionGroup;
  final bool completed;

  const StoreCustomerServiceProgressStepData({
    required this.key,
    required this.label,
    required this.actionGroup,
    required this.completed,
  });

  factory StoreCustomerServiceProgressStepData.fromMap(
    Map<String, dynamic> map,
  ) {
    return StoreCustomerServiceProgressStepData(
      key: '${map['key'] ?? ''}',
      label: '${map['label'] ?? ''}',
      actionGroup: '${map['action_group'] ?? ''}',
      completed: StoreCustomerOrderCurrency.parseBool(map['completed']),
    );
  }
}

class StoreCustomerServiceProgressData {
  final List<String> steps;
  final List<StoreCustomerServiceProgressStepData> definitions;
  final int completedActions;
  final int totalActions;
  final int percent;
  final bool completed;
  final String statusLabel;

  const StoreCustomerServiceProgressData({
    required this.steps,
    required this.definitions,
    required this.completedActions,
    required this.totalActions,
    required this.percent,
    required this.completed,
    required this.statusLabel,
  });

  static int parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse('$value') ?? 0;
  }

  static const List<StoreCustomerServiceProgressStepData> defaultDefinitions = [
    StoreCustomerServiceProgressStepData(
      key: 'atendimento_iniciado',
      label: 'Atendimento iniciado',
      actionGroup: 'atendimento_iniciado',
      completed: false,
    ),
    StoreCustomerServiceProgressStepData(
      key: 'cliente_efetuou_pagamento',
      label: 'Cliente efetuou pagamento',
      actionGroup: 'cliente_efetuou_pagamento',
      completed: false,
    ),
    StoreCustomerServiceProgressStepData(
      key: 'informacoes_coletadas',
      label: 'Informações coletadas',
      actionGroup: 'informacoes_coletadas',
      completed: false,
    ),
    StoreCustomerServiceProgressStepData(
      key: 'enviado_para_aprovacao',
      label: 'Enviado para aprovação',
      actionGroup: 'enviado_para_aprovacao',
      completed: false,
    ),
    StoreCustomerServiceProgressStepData(
      key: 'reajuste_1',
      label: 'Reajuste 1',
      actionGroup: 'reajustes',
      completed: false,
    ),
    StoreCustomerServiceProgressStepData(
      key: 'reajuste_2',
      label: 'Reajuste 2',
      actionGroup: 'reajustes',
      completed: false,
    ),
    StoreCustomerServiceProgressStepData(
      key: 'reajuste_3',
      label: 'Reajuste 3',
      actionGroup: 'reajustes',
      completed: false,
    ),
    StoreCustomerServiceProgressStepData(
      key: 'cliente_aprovou',
      label: 'Cliente aprovou',
      actionGroup: 'cliente_aprovou',
      completed: false,
    ),
    StoreCustomerServiceProgressStepData(
      key: 'entrega_dos_arquivos',
      label: 'Entrega dos arquivos',
      actionGroup: 'entrega_dos_arquivos',
      completed: false,
    ),
    StoreCustomerServiceProgressStepData(
      key: 'servico_concluido',
      label: 'Serviço concluído',
      actionGroup: 'servico_concluido',
      completed: false,
    ),
  ];

  factory StoreCustomerServiceProgressData.empty() {
    return const StoreCustomerServiceProgressData(
      steps: <String>[],
      definitions: defaultDefinitions,
      completedActions: 0,
      totalActions: 8,
      percent: 0,
      completed: false,
      statusLabel: 'Aguardando início',
    );
  }

  factory StoreCustomerServiceProgressData.fromMap(Map<String, dynamic> map) {
    final dynamic stepsValue = map['steps'];
    final List<String> parsedSteps = stepsValue is List
        ? stepsValue
            .map((item) => '$item')
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];

    final dynamic definitionsValue = map['definitions'];
    final List<StoreCustomerServiceProgressStepData> parsedDefinitions =
        definitionsValue is List
            ? definitionsValue
                .whereType<Map>()
                .map(
                  (item) => StoreCustomerServiceProgressStepData.fromMap(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
            : defaultDefinitions;

    return StoreCustomerServiceProgressData(
      steps: parsedSteps,
      definitions: parsedDefinitions,
      completedActions: parseInt(map['completed_actions']),
      totalActions: parseInt(map['total_actions']) == 0
          ? 8
          : parseInt(map['total_actions']),
      percent: parseInt(map['percent']),
      completed: StoreCustomerOrderCurrency.parseBool(map['completed']),
      statusLabel: '${map['status_label'] ?? 'Aguardando início'}',
    );
  }
}

class StoreCustomerServiceProgressMiniBar extends StatelessWidget {
  final StoreCustomerServiceProgressData progress;
  final Color primaryColor;

  const StoreCustomerServiceProgressMiniBar({
    super.key,
    required this.progress,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final double factor = progress.percent.clamp(0, 100) / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                progress.completed ? 'Serviço concluído' : progress.statusLabel,
                style: textBold.copyWith(
                  color: progress.completed ? primaryColor : Colors.black87,
                  fontSize: 11.8,
                ),
              ),
            ),
            Text(
              '${progress.percent.clamp(0, 100)}%',
              style: textBold.copyWith(color: primaryColor, fontSize: 11.8),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: factor,
            minHeight: 7,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
        if (progress.completed) ...[
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: primaryColor, size: 16),
              const SizedBox(width: 5),
              Text(
                'Serviço concluído',
                style: textBold.copyWith(color: primaryColor, fontSize: 11.6),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class StoreCustomerServiceOrderDetails extends StatelessWidget {
  final StoreCustomerOrderItem order;
  final Color primaryColor;
  final StoreCustomerServiceProgressData progress;
  final VoidCallback onOpenChatTap;
  final VoidCallback onEvaluateTap;

  const StoreCustomerServiceOrderDetails({
    super.key,
    required this.order,
    required this.primaryColor,
    required this.progress,
    required this.onOpenChatTap,
    required this.onEvaluateTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool paymentApproved = order.paymentStatus == 'approved';
    final bool chatAvailable = order.canOpenServiceChat;
    final bool finalFlow = order.isReleaseClosed || order.isDisputeFinalized;

    return StoreCustomerSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.orderStatus == 'service_requested'
                ? 'Solicitação enviada'
                : order.orderStatus == 'service_chat_open'
                    ? 'Serviço em andamento'
                    : order.orderStatus == 'service_completed'
                        ? 'Serviço concluído'
                        : 'Serviço ${order.serviceDeliveryLabel}',
            style: textBold.copyWith(color: Colors.black87, fontSize: 16),
          ),
          const SizedBox(height: 7),
          Text(
            order.serviceDeliveryDescription.isEmpty
                ? 'Acompanhe sua solicitação, alinhe os detalhes com o prestador e mantenha todo o histórico pelo chat seguro da Lokally.'
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
              title: 'store_lokally_chat',
              value: paymentApproved
                  ? 'store_chat_not_available_for_order'
                  : order.isServiceRequestOrder
                      ? 'Solicitação enviada. Aguarde o prestador iniciar a tratativa pelo chat.'
                      : 'store_service_chat_released_after_payment',
            )
          else if (chatAvailable) ...[
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
                        'store_open_lokally_chat'.tr,
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
          const SizedBox(height: 14),
          StoreCustomerServiceProgressMiniBar(
            progress: progress,
            primaryColor: primaryColor,
          ),
          if (progress.completed) ...[
            const SizedBox(height: 12),
            Material(
              color: primaryColor,
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                onTap: onEvaluateTap,
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  height: 44,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.star_outline_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Avaliar serviço',
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 13,
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

  const StoreCustomerServiceChatScreen({super.key, required this.order});

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
    'mp3',
    'mp4',
  ];

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool isLoading = false;
  bool isSending = false;
  bool isMeetingResponding = false;
  bool noticeModalShown = false;
  late String customerEmail;

  StoreCustomerServiceChatThread? thread;
  StoreCustomerServiceChatSafetyNotice? safetyNotice;
  List<StoreCustomerServiceChatMessage> messages =
      <StoreCustomerServiceChatMessage>[];

  String get chatUri =>
      '/api/customer/store/service-chat/order/${widget.order.id}';

  @override
  void initState() {
    super.initState();
    customerEmail = widget.order.customerEmail.trim();

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
            : 'store_chat_open_error'.tr,
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
                        'store_attach_file_to_service'.tr,
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
                  'store_attach_file_to_service_description'.tr,
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
                    'store_allowed_formats_limit'.trParams({
                      'value': allowedFileExtensionsText,
                    }),
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
                        'store_select_file'.tr,
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
                        'store_cancel'.tr,
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
      showChatMessage('store_selected_file_access_error');
      return;
    }

    final String message = messageController.text.trim();
    messageController.clear();

    await sendMessage(
      message: message,
      file: XFile(path, name: selectedFile.name),
    );
  }

  Future<void> sendMessage({required String message, XFile? file}) async {
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
          <String, dynamic>{'message': message},
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
            : 'store_send_message_error'.tr,
      );
    } catch (_) {
      if (mounted) {
        showChatMessage('store_send_message_error');
      }
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  bool isValidLokallyMeetingEmail(String value) {
    final String email = value.trim();

    if (email.isEmpty) {
      return false;
    }

    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<String?> ensureLokallyMeetingCustomerEmail() async {
    final String currentEmail = customerEmail.trim();

    if (currentEmail.isNotEmpty) {
      return currentEmail;
    }

    return showLokallyMeetingCustomerEmailSheet();
  }

  Future<String?> showLokallyMeetingCustomerEmailSheet() async {
    final TextEditingController emailController = TextEditingController(
      text: customerEmail.trim(),
    );
    final Color primaryColor = Theme.of(context).primaryColor;
    String errorText = '';

    final String? result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                              Icons.alternate_email_rounded,
                              color: primaryColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              'Confirme seu e-mail',
                              style: textBold.copyWith(
                                color: Colors.black87,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Informe um e-mail para receber confirmações, lembretes e avisos importantes do Lokally Meeting.',
                        style: textRegular.copyWith(
                          color: Colors.grey.shade700,
                          fontSize: 12.7,
                          height: 1.34,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          hintText: 'seuemail@exemplo.com',
                          errorText: errorText.isEmpty ? null : errorText,
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
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(17),
                        child: InkWell(
                          onTap: () {
                            final String email = emailController.text.trim();

                            if (!isValidLokallyMeetingEmail(email)) {
                              setModalState(() {
                                errorText =
                                    'Informe um e-mail válido para continuar.';
                              });
                              return;
                            }

                            Navigator.of(context).pop(email);
                          },
                          borderRadius: BorderRadius.circular(17),
                          child: Container(
                            height: 46,
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: Text(
                              'Continuar',
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
                          onTap: () => Navigator.of(context).pop(null),
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
      },
    );

    emailController.dispose();

    return result?.trim();
  }

  Future<void> acceptLokallyMeeting(
    StoreCustomerServiceChatMessage message,
  ) async {
    if (isMeetingResponding || message.meetingId.isEmpty) {
      return;
    }

    final String? email = await ensureLokallyMeetingCustomerEmail();

    if (email == null || email.trim().isEmpty) {
      return;
    }

    setState(() {
      isMeetingResponding = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().postData(
        '$chatUri/meeting/${message.meetingId}/accept',
        <String, dynamic>{
          'customer_email': email.trim(),
        },
      );

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body is Map &&
          body['status'] == true) {
        customerEmail = email.trim();
        showChatMessage('Lokally Meeting aceito com sucesso.');
        await loadChat();
        return;
      }

      showChatMessage(
        body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Não foi possível aceitar o Lokally Meeting.',
      );
    } catch (_) {
      if (mounted) {
        showChatMessage('Não foi possível aceitar o Lokally Meeting.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isMeetingResponding = false;
        });
      }
    }
  }

  Future<void> showDeclineLokallyMeetingSheet(
    StoreCustomerServiceChatMessage message,
  ) async {
    if (isMeetingResponding || message.meetingId.isEmpty) {
      return;
    }

    final TextEditingController reasonController = TextEditingController();
    final TextEditingController emailController = TextEditingController(
      text: customerEmail.trim(),
    );
    final Color primaryColor = Theme.of(context).primaryColor;
    String reasonErrorText = '';
    String emailErrorText = '';

    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bool needsEmail = customerEmail.trim().isEmpty;

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
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.videocam_off_outlined,
                              color: Colors.redAccent,
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              'Recusar Lokally Meeting',
                              style: textBold.copyWith(
                                color: Colors.black87,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Informe ao prestador o motivo da recusa para que ele possa remarcar, se necessário.',
                        style: textRegular.copyWith(
                          color: Colors.grey.shade700,
                          fontSize: 12.7,
                          height: 1.34,
                        ),
                      ),
                      if (needsEmail) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            hintText: 'seuemail@exemplo.com',
                            labelText: 'E-mail para avisos do Meeting',
                            errorText:
                                emailErrorText.isEmpty ? null : emailErrorText,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText:
                              'Ex.: Não consigo participar neste horário.',
                          errorText:
                              reasonErrorText.isEmpty ? null : reasonErrorText,
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
                          onTap: () {
                            final String email = emailController.text.trim();
                            final String reason = reasonController.text.trim();

                            if (needsEmail &&
                                !isValidLokallyMeetingEmail(email)) {
                              setModalState(() {
                                emailErrorText =
                                    'Informe um e-mail válido para continuar.';
                                reasonErrorText = '';
                              });
                              return;
                            }

                            if (reason.isEmpty) {
                              setModalState(() {
                                emailErrorText = '';
                                reasonErrorText = 'Informe o motivo da recusa.';
                              });
                              return;
                            }

                            Navigator.of(context).pop(true);
                          },
                          borderRadius: BorderRadius.circular(17),
                          child: Container(
                            height: 46,
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: Text(
                              'Enviar recusa',
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
      },
    );

    final String reason = reasonController.text.trim();
    final String email = emailController.text.trim();
    reasonController.dispose();
    emailController.dispose();

    if (confirmed != true) {
      return;
    }

    await declineLokallyMeeting(message, reason, email);
  }

  Future<void> declineLokallyMeeting(
    StoreCustomerServiceChatMessage message,
    String reason,
    String email,
  ) async {
    if (isMeetingResponding || message.meetingId.isEmpty) {
      return;
    }

    setState(() {
      isMeetingResponding = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().postData(
        '$chatUri/meeting/${message.meetingId}/decline',
        <String, dynamic>{
          'decline_reason': reason,
          'customer_email': email.trim(),
        },
      );

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body is Map &&
          body['status'] == true) {
        if (email.trim().isNotEmpty) {
          customerEmail = email.trim();
        }

        showChatMessage('Lokally Meeting recusado com sucesso.');
        await loadChat();
        return;
      }

      showChatMessage(
        body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Não foi possível recusar o Lokally Meeting.',
      );
    } catch (_) {
      if (mounted) {
        showChatMessage('Não foi possível recusar o Lokally Meeting.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isMeetingResponding = false;
        });
      }
    }
  }

  Future<void> openLokallyMeetingInApp(
    StoreCustomerServiceChatMessage message,
  ) async {
    if (message.meetingId.isEmpty || isMeetingResponding) {
      return;
    }

    await Get.to(
      () => LokallyMeetingScreen(
        orderId: widget.order.id,
        meetingId: message.meetingId,
        isHost: false,
        title: message.meeting?.title.isNotEmpty == true
            ? message.meeting!.title
            : 'Lokally Meeting',
      ),
    );

    if (mounted) {
      await loadChat();
    }
  }

  Future<void> generateLokallyMeetingDesktopLink(
    StoreCustomerServiceChatMessage message,
  ) async {
    if (message.meetingId.isEmpty || isMeetingResponding) {
      return;
    }

    setState(() {
      isMeetingResponding = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().postData(
        '$chatUri/meeting/${message.meetingId}/link',
        <String, dynamic>{'device_type': 'web'},
      );

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

        final String accessUrl = '${data['access_url'] ?? ''}'.trim();
        final String expiresAt = '${data['expires_at'] ?? ''}'.trim();

        if (accessUrl.isEmpty) {
          showChatMessage('Não foi possível gerar o link do Lokally Meeting.');
          return;
        }

        await Clipboard.setData(ClipboardData(text: accessUrl));

        if (mounted) {
          await showLokallyMeetingDesktopLinkSheet(
            accessUrl: accessUrl,
            expiresAt: expiresAt,
          );
        }
        return;
      }

      showChatMessage(
        body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Não foi possível gerar o link do Lokally Meeting.',
      );
    } catch (_) {
      if (mounted) {
        showChatMessage('Não foi possível gerar o link do Lokally Meeting.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isMeetingResponding = false;
        });
      }
    }
  }

  Future<void> showLokallyMeetingDesktopLinkSheet({
    required String accessUrl,
    required String expiresAt,
  }) async {
    final Color primaryColor = Theme.of(context).primaryColor;

    await showModalBottomSheet<void>(
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
                        Icons.computer_rounded,
                        color: primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Link para computador',
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'O link do Lokally Meeting foi copiado. Abra no navegador do computador ou notebook para participar da reunião.',
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 12.7,
                    height: 1.34,
                  ),
                ),
                if (expiresAt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Válido até: $expiresAt',
                    style: textMedium.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 11.8,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SelectableText(
                    accessUrl,
                    style: textRegular.copyWith(
                      color: Colors.black87,
                      fontSize: 11.8,
                      height: 1.30,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(17),
                        child: InkWell(
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: accessUrl),
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                            showChatMessage('Link copiado.');
                          },
                          borderRadius: BorderRadius.circular(17),
                          child: Container(
                            height: 46,
                            alignment: Alignment.center,
                            child: Text(
                              'Copiar link',
                              style: textBold.copyWith(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Material(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(17),
                        child: InkWell(
                          onTap: () async {
                            final Uri uri = Uri.parse(accessUrl);
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          borderRadius: BorderRadius.circular(17),
                          child: Container(
                            height: 46,
                            alignment: Alignment.center,
                            child: Text(
                              'Abrir',
                              style: textBold.copyWith(
                                color: primaryColor,
                                fontSize: 13,
                              ),
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
        );
      },
    );
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
          message.tr,
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
                        notice.title.tr,
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
                  notice.message.tr,
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
                            detail.tr,
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
                        'store_understand_continue'.tr,
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
        backgroundColor: Colors.white,
        body: BodyWidget(
          appBar: AppBarWidget(title: 'store_lokally_chat'.tr),
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
                                  'store_service_support'.tr,
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
                          StoreCustomerSurface(
                            child: StoreCustomerServiceProgressMiniBar(
                              progress: thread?.serviceProgress ??
                                  StoreCustomerServiceProgressData.empty(),
                              primaryColor: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (messages.isEmpty)
                            StoreCustomerSurface(
                              child: Text(
                                'store_service_chat_empty_description'.tr,
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
                                isMeetingResponding: isMeetingResponding,
                                onAcceptMeeting: () =>
                                    acceptLokallyMeeting(message),
                                onDeclineMeeting: () =>
                                    showDeclineLokallyMeetingSheet(message),
                                onOpenMeetingApp: () =>
                                    openLokallyMeetingInApp(message),
                                onGenerateMeetingLink: () =>
                                    generateLokallyMeetingDesktopLink(message),
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
                          hintText: 'store_write_your_message'.tr,
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
  final bool isMeetingResponding;
  final VoidCallback? onAcceptMeeting;
  final VoidCallback? onDeclineMeeting;
  final VoidCallback? onOpenMeetingApp;
  final VoidCallback? onGenerateMeetingLink;

  const StoreCustomerServiceChatBubble({
    super.key,
    required this.message,
    required this.primaryColor,
    this.isMeetingResponding = false,
    this.onAcceptMeeting,
    this.onDeclineMeeting,
    this.onOpenMeetingApp,
    this.onGenerateMeetingLink,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMine = message.senderType == 'customer';

    if (message.isLokallyMeeting) {
      return StoreCustomerLokallyMeetingChatCard(
        message: message,
        primaryColor: primaryColor,
        isMine: isMine,
        isLoading: isMeetingResponding,
        onAcceptMeeting: onAcceptMeeting,
        onDeclineMeeting: onDeclineMeeting,
        onOpenMeetingApp: onOpenMeetingApp,
        onGenerateMeetingLink: onGenerateMeetingLink,
      );
    }

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

class StoreCustomerLokallyMeetingChatCard extends StatelessWidget {
  final StoreCustomerServiceChatMessage message;
  final Color primaryColor;
  final bool isMine;
  final bool isLoading;
  final VoidCallback? onAcceptMeeting;
  final VoidCallback? onDeclineMeeting;
  final VoidCallback? onOpenMeetingApp;
  final VoidCallback? onGenerateMeetingLink;

  const StoreCustomerLokallyMeetingChatCard({
    super.key,
    required this.message,
    required this.primaryColor,
    required this.isMine,
    required this.isLoading,
    this.onAcceptMeeting,
    this.onDeclineMeeting,
    this.onOpenMeetingApp,
    this.onGenerateMeetingLink,
  });

  Color get statusColor {
    switch (message.meeting?.status ?? '') {
      case 'accepted':
      case 'started':
        return primaryColor;
      case 'ended':
        return Colors.grey;
      case 'declined':
        return Colors.redAccent;
      case 'pending':
      default:
        return Colors.orange.shade800;
    }
  }

  IconData get statusIcon {
    switch (message.meeting?.status ?? '') {
      case 'accepted':
        return Icons.event_available_outlined;
      case 'started':
        return Icons.video_call_rounded;
      case 'ended':
        return Icons.call_end_rounded;
      case 'declined':
        return Icons.event_busy_outlined;
      case 'pending':
      default:
        return Icons.schedule_outlined;
    }
  }

  String get statusLabel {
    switch (message.meeting?.status ?? '') {
      case 'accepted':
        return 'Agendado';
      case 'started':
        return 'Em andamento';
      case 'ended':
        return 'Encerrado';
      case 'declined':
        return 'Recusado';
      case 'pending':
      default:
        return 'Aguardando resposta';
    }
  }

  bool get canRespond {
    return !isMine &&
        message.messageType == 'lokally_meeting_invite' &&
        (message.meeting?.status ?? '') == 'pending';
  }

  bool get canEnterMeeting {
    final String status = message.meeting?.status ?? '';

    return !isMine &&
        message.messageType == 'lokally_meeting_invite' &&
        (status == 'accepted' || status == 'started');
  }

  @override
  Widget build(BuildContext context) {
    final StoreCustomerServiceMeetingData? meeting = message.meeting;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isMine ? 22 : 6),
            bottomRight: Radius.circular(isMine ? 6 : 22),
          ),
          border: Border.all(color: primaryColor.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 16,
              offset: const Offset(0, 8),
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
                    color: primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.videocam_rounded,
                    color: primaryColor,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting?.title.isNotEmpty == true
                            ? meeting!.title
                            : 'Lokally Meeting',
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 14.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Videochamada agendada no Chat Lokally',
                        style: textRegular.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 11.4,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  StoreCustomerLokallyMeetingInfoRow(
                    icon: Icons.calendar_month_outlined,
                    label: 'Data e horário',
                    value: meeting?.scheduledAtLabel.isNotEmpty == true
                        ? meeting!.scheduledAtLabel
                        : 'Horário não informado',
                    valueColor: Colors.black87,
                  ),
                  const SizedBox(height: 7),
                  StoreCustomerLokallyMeetingInfoRow(
                    icon: statusIcon,
                    label: 'Status',
                    value: statusLabel,
                    valueColor: statusColor,
                  ),
                ],
              ),
            ),
            if (meeting?.note.isNotEmpty == true) ...[
              const SizedBox(height: 9),
              Text(
                meeting!.note,
                style: textRegular.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 11.8,
                  height: 1.30,
                ),
              ),
            ],
            if ((meeting?.declineReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Motivo da recusa: ${meeting!.declineReason}',
                  style: textMedium.copyWith(
                    color: Colors.redAccent,
                    fontSize: 11.6,
                    height: 1.28,
                  ),
                ),
              ),
            ],
            if (canRespond) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(15),
                      child: InkWell(
                        onTap: isLoading ? null : onAcceptMeeting,
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          child: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.1,
                                  ),
                                )
                              : Text(
                                  'Aceitar',
                                  style: textBold.copyWith(
                                    color: Colors.white,
                                    fontSize: 12.4,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(15),
                      child: InkWell(
                        onTap: isLoading ? null : onDeclineMeeting,
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          child: Text(
                            'Recusar',
                            style: textBold.copyWith(
                              color: Colors.redAccent,
                              fontSize: 12.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (canEnterMeeting) ...[
              const SizedBox(height: 12),
              Material(
                color: primaryColor,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: isLoading ? null : onOpenMeetingApp,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 44,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.1,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.video_call_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                message.meeting?.status == 'started'
                                    ? 'Entrar no Meeting'
                                    : 'Entrar pelo app',
                                style: textBold.copyWith(
                                  color: Colors.white,
                                  fontSize: 12.8,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: isLoading ? null : onGenerateMeetingLink,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 43,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.computer_rounded,
                          color: primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Gerar link para computador',
                          style: textBold.copyWith(
                            color: primaryColor,
                            fontSize: 12.5,
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
      ),
    );
  }
}

class StoreCustomerLokallyMeetingInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const StoreCustomerLokallyMeetingInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: valueColor, size: 16),
        const SizedBox(width: 7),
        Text(
          '$label: ',
          style: textRegular.copyWith(
            color: Colors.grey.shade600,
            fontSize: 11.3,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textBold.copyWith(
              color: valueColor,
              fontSize: 11.5,
              height: 1.22,
            ),
          ),
        ),
      ],
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
            (isReady ? 'store_order_ready_for_pickup' : 'store_pickup_at_store')
                .tr,
            style: textBold.copyWith(
              color: isReady ? primaryColor : Colors.black87,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isReady
                ? 'store_order_ready_for_pickup_description'.tr
                : 'store_wait_seller_release_pickup'.tr,
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
              title: 'store_pickup_address',
              value: order.pickupAddress,
            ),
          ],
          if (order.sellerPhone.isNotEmpty) ...[
            const SizedBox(height: 10),
            StoreCustomerInfoBlock(
              icon: Icons.phone_outlined,
              title: 'store_store_contact',
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
            style: textBold.copyWith(color: Colors.black87, fontSize: 16),
          ),
          const SizedBox(height: 7),
          Text(
            order.orderStatus == 'lokally_shipping_pending'
                ? 'store_seller_has_24h_request_lokally_shipping'.tr
                : 'store_follow_shipping_updates'.tr,
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
              title: 'store_delivery_address',
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
        ? 'store_dispute_closed_by_lokally'
        : authorized
            ? 'store_order_finished'
            : disputed
                ? 'store_dispute_opened'
                : order.releaseStatusLabel.isEmpty
                    ? 'store_payout_release'
                    : order.releaseStatusLabel;

    final String disputeFinalMessage = order.disputeResolutionMessage.trim();
    final String message = disputeFinalized
        ? (disputeFinalMessage.isNotEmpty
            ? disputeFinalMessage
            : 'store_dispute_closed_by_lokally_message')
        : waitingAuthorization
            ? 'store_authorize_payout_after_delivery_message'
            : disputed
                ? 'store_dispute_opened_analysis_message'
                : 'store_payout_authorized_order_finished_message';

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
                      title.tr,
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
                      message.tr,
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
              title: 'store_response_deadline',
              value: 'store_payout_response_deadline_message',
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
                    'store_authorize_payout_upper'.tr,
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
                    'store_open_dispute_upper'.tr,
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
                      'store_lokally_dispute'.tr,
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 15.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'store_dispute_lokally_description'.tr,
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
            title: 'store_analysis_deadline',
            value: 'store_dispute_analysis_deadline_description',
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
                      'store_track_dispute'.tr,
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

  const StoreCustomerDisputeTicketScreen({super.key, required this.order});

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
            : 'store_dispute_load_error'.tr,
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
                        'store_attach_file_to_dispute'.tr,
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
                  'store_attach_file_to_dispute_description'.tr,
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
                    'store_allowed_formats_limit'.trParams({
                      'value': allowedFileExtensionsText,
                    }),
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
                        'store_select_file'.tr,
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
                        'store_cancel'.tr,
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
      showDisputeMessage('store_selected_file_access_error');
      return;
    }

    final String message = messageController.text.trim();
    messageController.clear();

    await sendMessage(
      message: message,
      file: XFile(path, name: selectedFile.name),
    );
  }

  Future<void> sendMessage({required String message, XFile? file}) async {
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
          <String, dynamic>{'message': message},
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
            : 'store_send_message_error'.tr,
      );
    } catch (_) {
      if (mounted) {
        showDisputeMessage('store_send_message_error');
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
          message.tr,
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

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final StoreCustomerOrderDispute? currentDispute = dispute;

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: BodyWidget(
          appBar: AppBarWidget(title: 'store_lokally_dispute'.tr),
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
                                        color: Colors.redAccent.withValues(
                                          alpha: 0.10,
                                        ),
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
                                            'store_dispute_ticket'.tr,
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
                                      'store_dispute_opened',
                                  value: 'store_dispute_treatment_description',
                                ),
                                const SizedBox(height: 10),
                                StoreCustomerInfoBlock(
                                  icon: Icons.schedule_outlined,
                                  title: 'store_analysis_deadline',
                                  value: currentDispute
                                              ?.deadlineAt.isNotEmpty ==
                                          true
                                      ? 'store_analysis_deadline_with_date'
                                          .trParams({
                                          'value': currentDispute!.deadlineAt,
                                        })
                                      : 'store_analysis_deadline_without_date',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (messages.isEmpty)
                            StoreCustomerSurface(
                              child: Text(
                                'store_dispute_empty_timeline_description'.tr,
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
                          hintText: 'store_reply_to_lokally'.tr,
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
        ? 'store_you'
        : isLokally
            ? 'Lokally'
            : 'store_update';

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
              senderLabel.tr,
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
                style: textRegular.copyWith(color: helperColor, fontSize: 9.8),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
                  title.tr,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 11.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.tr,
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
            label.tr,
            style: textMedium.copyWith(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            (value.isEmpty ? '-' : value).tr,
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
                  'store_unit_price_with_value'.trParams({
                    'value': StoreCustomerOrderCurrency.format(item.unitPrice),
                  }),
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
          style: textBold.copyWith(color: Colors.black87, fontSize: 12.2),
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
          Text(label.tr, style: textBold.copyWith(color: color, fontSize: 11)),
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

  const StoreCustomerOrdersLoading({super.key, required this.primaryColor});

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
        ? 'store_empty_pickup_orders_description'
        : selectedFilter == 'lokally_shipping'
            ? 'store_empty_lokally_shipping_orders_description'
            : 'store_empty_marketplace_orders_description';

    return StoreCustomerSurface(
      child: Column(
        children: [
          Icon(Icons.shopping_bag_outlined, color: primaryColor, size: 42),
          const SizedBox(height: 10),
          Text(
            'store_no_order_found'.tr,
            style: textBold.copyWith(color: Colors.black87, fontSize: 15.5),
          ),
          const SizedBox(height: 5),
          Text(
            message.tr,
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

  const StoreCustomerSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: child,
    );
  }
}

class StoreCustomerMercadoPagoWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final Color primaryColor;

  const StoreCustomerMercadoPagoWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.primaryColor,
  });

  @override
  State<StoreCustomerMercadoPagoWebViewScreen> createState() =>
      _StoreCustomerMercadoPagoWebViewScreenState();
}

class _StoreCustomerMercadoPagoWebViewScreenState
    extends State<StoreCustomerMercadoPagoWebViewScreen> {
  bool isLoading = true;

  bool isFinalMercadoPagoUrl(Uri? uri) {
    if (uri == null) {
      return false;
    }

    final String value = uri.toString().toLowerCase();

    return value.contains('collection_status=approved') ||
        value.contains('status=approved') ||
        value.contains('/success') ||
        value.contains('payment_status=approved') ||
        value.contains('approved');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: widget.primaryColor,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(result: false),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mercado Pago',
                      style: textBold.copyWith(
                        color: Colors.white,
                        fontSize: 19,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Get.back(result: true),
                    child: Text(
                      'store_finish'.tr,
                      style: textBold.copyWith(
                        color: Colors.white,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(widget.paymentUrl),
                    ),
                    onLoadStart: (controller, uri) {
                      if (!mounted) {
                        return;
                      }

                      setState(() {
                        isLoading = true;
                      });

                      if (isFinalMercadoPagoUrl(uri)) {
                        Get.back(result: true);
                      }
                    },
                    onLoadStop: (controller, uri) {
                      if (!mounted) {
                        return;
                      }

                      setState(() {
                        isLoading = false;
                      });

                      if (isFinalMercadoPagoUrl(uri)) {
                        Get.back(result: true);
                      }
                    },
                  ),
                  if (isLoading)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        color: widget.primaryColor,
                        backgroundColor: Colors.white,
                        minHeight: 3,
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
  final String customerEmail;
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
    required this.customerEmail,
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

  bool get isPaymentApproved =>
      paymentStatus == 'approved' || paymentStatus == 'paid';

  bool get isServiceRequestOrder {
    return deliveryType == 'service' ||
        paymentMethod == 'chat' ||
        orderStatus == 'service_requested' ||
        orderStatus == 'service_chat_open' ||
        orderStatus == 'service_completed' ||
        containsServiceItems ||
        isServiceOrder;
  }

  bool get canOpenServiceChat {
    if (!isServiceRequestOrder || isReleaseClosed || isDisputeFinalized) {
      return false;
    }

    if (orderStatus == 'service_requested' ||
        orderStatus == 'service_chat_open') {
      return true;
    }

    return serviceChatAvailable && isPaymentApproved;
  }

  String get serviceHeaderStatusLabel {
    if (!isServiceRequestOrder) {
      return paymentStatusLabel;
    }

    if (orderStatus == 'service_completed') {
      return 'Serviço concluído';
    }

    if (orderStatus == 'service_chat_open') {
      return 'Serviço em andamento';
    }

    if (orderStatus == 'service_requested') {
      return 'Solicitação enviada';
    }

    return orderStatusLabel.isNotEmpty ? orderStatusLabel : paymentStatusLabel;
  }

  bool get normalizedIsServiceOrder => isServiceRequestOrder;

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
    return isServiceRequestOrder && !isReleaseClosed;
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

    final Map<String, dynamic> customer = map['customer'] is Map
        ? Map<String, dynamic>.from(map['customer'])
        : <String, dynamic>{};

    final dynamic itemsValue = map['items'];
    final List<dynamic> rawItems =
        itemsValue is List ? itemsValue : <dynamic>[];

    final List<StoreCustomerOrderProductItem> parsedItems = rawItems
        .whereType<Map>()
        .map(
          (item) => StoreCustomerOrderProductItem.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();

    final String parsedDeliveryType = '${map['delivery_type'] ?? ''}';
    final String parsedPaymentMethod = '${map['payment_method'] ?? ''}';
    final String parsedPaymentStatus = '${map['payment_status'] ?? ''}';
    final String parsedOrderStatus = '${map['order_status'] ?? ''}';
    final bool parsedContainsServiceItems =
        StoreCustomerOrderCurrency.parseBool(map['contains_service_items']) ||
            parsedItems.any((item) => item.isService);
    final bool parsedContainsPhysicalItems =
        StoreCustomerOrderCurrency.parseBool(map['contains_physical_items']) ||
            parsedItems.any((item) => !item.isService);
    final bool parsedIsServiceOrder =
        StoreCustomerOrderCurrency.parseBool(map['is_service_order']) ||
            parsedDeliveryType == 'service' ||
            parsedPaymentMethod == 'chat' ||
            parsedOrderStatus == 'service_requested' ||
            parsedOrderStatus == 'service_chat_open' ||
            parsedOrderStatus == 'service_completed' ||
            (parsedItems.isNotEmpty &&
                parsedItems.every((item) => item.isService));
    final String parsedServiceDeliveryLabel =
        '${map['service_delivery_label'] ?? ''}'.trim().isEmpty
            ? 'Serviço'
            : '${map['service_delivery_label'] ?? ''}';
    final String parsedDeliveryTypeLabel = parsedIsServiceOrder
        ? parsedServiceDeliveryLabel
        : '${map['delivery_type_label'] ?? ''}';
    final String parsedOrderStatusLabel = parsedIsServiceOrder &&
            parsedOrderStatus == 'service_requested'
        ? 'Solicitação enviada'
        : parsedIsServiceOrder && parsedOrderStatus == 'service_chat_open'
            ? 'Serviço em andamento'
            : parsedIsServiceOrder && parsedOrderStatus == 'service_completed'
                ? 'Serviço concluído'
                : '${map['order_status_label'] ?? ''}';
    final String parsedPaymentStatusLabel =
        parsedIsServiceOrder && parsedPaymentMethod == 'chat'
            ? (parsedOrderStatus == 'service_chat_open'
                ? 'Serviço em andamento'
                : parsedOrderStatus == 'service_completed'
                    ? 'Serviço concluído'
                    : 'Solicitação enviada')
            : '${map['payment_status_label'] ?? ''}';
    final bool parsedServiceChatAvailable =
        StoreCustomerOrderCurrency.parseBool(map['service_chat_available']) ||
            parsedOrderStatus == 'service_requested' ||
            parsedOrderStatus == 'service_chat_open';

    return StoreCustomerOrderItem(
      id: '${map['id'] ?? ''}',
      orderNumber: '${map['order_number'] ?? ''}',
      deliveryType: parsedDeliveryType,
      deliveryTypeLabel: parsedDeliveryTypeLabel,
      paymentMethod: parsedPaymentMethod,
      paymentMethodLabel: '${map['payment_method_label'] ?? ''}',
      paymentStatus: parsedPaymentStatus,
      paymentStatusLabel: parsedPaymentStatusLabel,
      orderStatus: parsedOrderStatus,
      orderStatusLabel: parsedOrderStatusLabel,
      subtotal: StoreCustomerOrderCurrency.parseDouble(map['subtotal']),
      shippingAmount: StoreCustomerOrderCurrency.parseDouble(
        map['shipping_amount'],
      ),
      shippingDiscount: StoreCustomerOrderCurrency.parseDouble(
        map['shipping_discount'],
      ),
      total: StoreCustomerOrderCurrency.parseDouble(map['total']),
      deliveryAddress: '${delivery['address'] ?? ''}',
      pickupAddress: '${pickup['address'] ?? ''}',
      sellerPhone: '${pickup['seller_phone'] ?? pickup['phone'] ?? ''}',
      sellerName: '${seller['name'] ?? ''}',
      sellerLogoUrl: '${seller['logo_url'] ?? ''}',
      customerEmail:
          '${map['customer_email'] ?? customer['email'] ?? ''}'.trim(),
      createdAt: '${map['created_at'] ?? ''}',
      containsServiceItems: parsedContainsServiceItems,
      containsPhysicalItems: parsedContainsPhysicalItems,
      isServiceOrder: parsedIsServiceOrder,
      isMixedOrder: StoreCustomerOrderCurrency.parseBool(map['is_mixed_order']),
      serviceDeliveryType: '${map['service_delivery_type'] ?? ''}',
      serviceDeliveryLabel: parsedServiceDeliveryLabel,
      serviceDeliveryDescription:
          '${map['service_delivery_description'] ?? ''}',
      serviceActionLabel: '${map['service_action_label'] ?? ''}',
      serviceChatAvailable: parsedServiceChatAvailable,
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
      isDisputeResolved: StoreCustomerOrderCurrency.parseBool(
        map['is_dispute_resolved'],
      ),
      canAuthorizePayout: StoreCustomerOrderCurrency.parseBool(
        map['can_authorize_payout'],
      ),
      canOpenDispute: StoreCustomerOrderCurrency.parseBool(
        map['can_open_dispute'],
      ),
      items: parsedItems,
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
  final StoreCustomerServiceProgressData serviceProgress;

  StoreCustomerServiceChatThread({
    required this.id,
    required this.storeOrderId,
    required this.status,
    required this.safetyNoticeAccepted,
    required this.serviceProgress,
  });

  factory StoreCustomerServiceChatThread.fromMap(Map<String, dynamic> map) {
    return StoreCustomerServiceChatThread(
      id: '${map['id'] ?? ''}',
      storeOrderId: '${map['store_order_id'] ?? ''}',
      status: '${map['status'] ?? ''}',
      safetyNoticeAccepted: StoreCustomerOrderCurrency.parseBool(
        map['safety_notice_accepted'],
      ),
      serviceProgress: StoreCustomerServiceProgressData.fromMap(
        map['service_progress'] is Map
            ? Map<String, dynamic>.from(map['service_progress'])
            : <String, dynamic>{},
      ),
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
      title: '${map['title'] ?? 'store_lokally_guarantee'}',
      message: '${map['message'] ?? ''}',
      details: detailsValue is List
          ? detailsValue.map((item) => item.toString()).toList()
          : <String>[],
    );
  }

  factory StoreCustomerServiceChatSafetyNotice.defaultNotice() {
    return StoreCustomerServiceChatSafetyNotice(
      title: 'store_lokally_guarantee',
      message: 'store_lokally_guarantee_notice_message',
      details: const [
        'store_lokally_guarantee_notice_detail_chat',
        'store_lokally_guarantee_notice_detail_payment',
        'store_lokally_guarantee_notice_detail_release',
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
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
                      fileName.isEmpty ? 'store_attached_file'.tr : fileName,
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
                          ? 'store_file_without_link'.tr
                          : 'store_download_or_open'.tr,
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
      case 'mp3':
        return Icons.audiotrack_outlined;
      case 'mp4':
        return Icons.video_file_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}

class StoreCustomerServiceChatMessage {
  final String id;
  final String senderType;
  final String messageType;
  final String meetingId;
  final StoreCustomerServiceMeetingData? meeting;
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
    required this.meetingId,
    required this.meeting,
    required this.message,
    required this.fileUrl,
    required this.fileOriginalName,
    required this.fileMimeType,
    required this.fileSize,
    required this.createdAt,
  });

  bool get hasFile => fileUrl.isNotEmpty || fileOriginalName.isNotEmpty;

  bool get isLokallyMeeting {
    return messageType == 'lokally_meeting_invite' ||
        messageType == 'lokally_meeting_accepted' ||
        messageType == 'lokally_meeting_declined';
  }

  String get fileDisplayName {
    return StoreChatFileHelper.displayName(
      originalName: fileOriginalName,
      fileUrl: fileUrl,
      fallback: 'store_attached_file'.tr,
    );
  }

  factory StoreCustomerServiceChatMessage.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> meetingMap = <String, dynamic>{};

    final dynamic meetingValue = map['meeting'];
    if (meetingValue is Map) {
      meetingMap = Map<String, dynamic>.from(meetingValue);
    } else {
      final dynamic metaValue = map['meta_data'];
      if (metaValue is Map) {
        meetingMap = Map<String, dynamic>.from(metaValue);
      }
    }

    final StoreCustomerServiceMeetingData? parsedMeeting = meetingMap.isNotEmpty
        ? StoreCustomerServiceMeetingData.fromMap(meetingMap)
        : null;

    return StoreCustomerServiceChatMessage(
      id: '${map['id'] ?? ''}',
      senderType: '${map['sender_type'] ?? ''}',
      messageType: '${map['message_type'] ?? ''}',
      meetingId: '${map['meeting_id'] ?? parsedMeeting?.id ?? ''}',
      meeting: parsedMeeting,
      message: '${map['message'] ?? ''}',
      fileUrl: '${map['file_url'] ?? ''}',
      fileOriginalName: '${map['file_original_name'] ?? ''}',
      fileMimeType: '${map['file_mime_type'] ?? ''}',
      fileSize: int.tryParse('${map['file_size'] ?? ''}'),
      createdAt: '${map['created_at'] ?? ''}',
    );
  }
}

class StoreCustomerServiceMeetingData {
  final String id;
  final String status;
  final String title;
  final String note;
  final String scheduledAt;
  final String timezone;
  final String declineReason;
  final String roomKey;
  final String acceptedAt;
  final String declinedAt;

  const StoreCustomerServiceMeetingData({
    required this.id,
    required this.status,
    required this.title,
    required this.note,
    required this.scheduledAt,
    required this.timezone,
    required this.declineReason,
    required this.roomKey,
    required this.acceptedAt,
    required this.declinedAt,
  });

  String get scheduledAtLabel {
    return formatDateTime(scheduledAt);
  }

  static String twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  static String formatDateTime(String value) {
    final String normalized = value.trim();

    if (normalized.isEmpty) {
      return '';
    }

    try {
      final DateTime dateTime = DateTime.parse(
        normalized.replaceFirst(' ', 'T'),
      );

      return '${twoDigits(dateTime.day)}/${twoDigits(dateTime.month)}/${dateTime.year} às ${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}';
    } catch (_) {
      return normalized;
    }
  }

  factory StoreCustomerServiceMeetingData.fromMap(Map<String, dynamic> map) {
    return StoreCustomerServiceMeetingData(
      id: '${map['id'] ?? ''}',
      status: '${map['status'] ?? ''}',
      title: '${map['title'] ?? 'Lokally Meeting'}',
      note: '${map['note'] ?? ''}',
      scheduledAt: '${map['scheduled_at'] ?? ''}',
      timezone: '${map['timezone'] ?? 'America/Sao_Paulo'}',
      declineReason: '${map['decline_reason'] ?? ''}',
      roomKey: '${map['room_key'] ?? ''}',
      acceptedAt: '${map['accepted_at'] ?? ''}',
      declinedAt: '${map['declined_at'] ?? ''}',
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
      statusLabel: '${map['status_label'] ?? 'store_dispute_opened'}',
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
      fallback: 'store_dispute_file'.tr,
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
