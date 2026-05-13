import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/map/screens/map_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreSellerOrderListScreen extends StatefulWidget {
  const StoreSellerOrderListScreen({super.key});

  @override
  State<StoreSellerOrderListScreen> createState() =>
      _StoreSellerOrderListScreenState();
}

class _StoreSellerOrderListScreenState
    extends State<StoreSellerOrderListScreen> {
  static const String storeSellerOrdersUri =
      '/api/customer/store/seller/orders';

  bool isLoading = false;
  String selectedFilter = 'all';

  List<StoreSellerOrderItem> orders = <StoreSellerOrderItem>[];
  StoreSellerOrderCounts counts = StoreSellerOrderCounts.empty();

  final List<StoreSellerOrderFilter> filters = <StoreSellerOrderFilter>[
    StoreSellerOrderFilter(
      keyName: 'all',
      label: 'Todos',
      apiFilter: 'all',
    ),
    StoreSellerOrderFilter(
      keyName: 'pickup',
      label: 'Retirada',
      apiFilter: 'pickup',
    ),
    StoreSellerOrderFilter(
      keyName: 'lokally_shipping',
      label: 'Lokally Envios',
      apiFilter: 'lokally_shipping',
    ),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadOrders();
    });
  }

  Future<void> loadOrders({String? filterKey}) async {
    if (isLoading) {
      return;
    }

    final String nextFilter = filterKey ?? selectedFilter;
    final StoreSellerOrderFilter filter = filters.firstWhere(
      (item) => item.keyName == nextFilter,
      orElse: () => filters.first,
    );

    setState(() {
      isLoading = true;
      selectedFilter = nextFilter;
    });

    final String uri = filter.apiFilter == 'all'
        ? storeSellerOrdersUri
        : '$storeSellerOrdersUri?filter=${filter.apiFilter}';

    final Response response = await Get.find<ApiClient>().getData(uri);

    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = false;
    });

    final dynamic body = response.body;

    if (response.statusCode != 200 || body is! Map || body['status'] != true) {
      showStoreMessage('Não foi possível carregar os pedidos.');
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
      counts = StoreSellerOrderCounts.fromMap(countsMap);
      orders = orderList
          .whereType<Map>()
          .map(
            (item) => StoreSellerOrderItem.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    });
  }

  Future<StoreSellerOrderItem?> updateOrderStatus(
    StoreSellerOrderItem order,
    String status, {
    bool askConfirmation = true,
    bool reloadAfterSuccess = true,
  }) async {
    final String actionLabel = status == 'ready_for_pickup'
        ? 'liberar retirada'
        : status == 'lokally_shipping_requested'
            ? 'solicitar Lokally Envios'
            : 'atualizar pedido';

    if (askConfirmation) {
      final bool confirmed = await showConfirmActionSheet(
        order: order,
        status: status,
        actionLabel: actionLabel,
      );

      if (!confirmed) {
        return null;
      }
    }

    showStoreMessage('Atualizando pedido...');

    final Response response = await Get.find<ApiClient>().postData(
      '$storeSellerOrdersUri/${order.id}/status',
      <String, dynamic>{
        'status': status,
      },
    );

    final dynamic body = response.body;

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        body is Map &&
        body['status'] == true) {
      StoreSellerOrderItem? updatedOrder;

      final dynamic dataValue = body['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic orderValue = data['order'];

      if (orderValue is Map) {
        updatedOrder = StoreSellerOrderItem.fromMap(
          Map<String, dynamic>.from(orderValue),
        );
      }

      showStoreMessage('Status do pedido atualizado com sucesso.');

      if (reloadAfterSuccess) {
        await loadOrders();
      }

      return updatedOrder ?? order;
    }

    String message = 'Não foi possível atualizar o pedido.';

    if (body is Map && body['message'] != null) {
      message = body['message'].toString();
    }

    showStoreMessage(message);
    return null;
  }

  Future<void> requestLokallyShipping(StoreSellerOrderItem order) async {
    final bool confirmed = await showConfirmActionSheet(
      order: order,
      status: 'lokally_shipping_requested',
      actionLabel: order.orderStatus == 'lokally_shipping_requested'
          ? 'abrir Lokally Envios'
          : 'solicitar Lokally Envios',
    );

    if (!confirmed) {
      return;
    }

    if (!order.hasCompleteLokallyShippingData) {
      showStoreMessage(
        'Este pedido ainda não possui endereço completo de coleta e entrega.',
      );
      return;
    }

    StoreSellerOrderItem orderForShipping = order;

    if (order.orderStatus != 'lokally_shipping_requested') {
      final StoreSellerOrderItem? updatedOrder = await updateOrderStatus(
        order,
        'lokally_shipping_requested',
        askConfirmation: false,
        reloadAfterSuccess: false,
      );

      if (updatedOrder == null) {
        return;
      }

      orderForShipping = updatedOrder;
    }

    await prepareAndOpenMarketplaceParcelFlow(orderForShipping);
    await loadOrders();
  }

  Future<void> prepareAndOpenMarketplaceParcelFlow(
    StoreSellerOrderItem order,
  ) async {
    if (!Get.isRegistered<ParcelController>() ||
        !Get.isRegistered<LocationController>() ||
        !Get.isRegistered<RideController>() ||
        !Get.isRegistered<MapController>()) {
      showStoreMessage('Não foi possível iniciar o fluxo de entrega.');
      return;
    }

    final ParcelController parcelController = Get.find<ParcelController>();
    final LocationController locationController =
        Get.find<LocationController>();
    final RideController rideController = Get.find<RideController>();
    final MapController mapController = Get.find<MapController>();

    if (parcelController.parcelCategoryList == null ||
        parcelController.parcelCategoryList!.isEmpty) {
      await parcelController.getParcelCategoryList(notify: true);
    }

    if (parcelController.parcelCategoryList == null ||
        parcelController.parcelCategoryList!.isEmpty) {
      showStoreMessage('Nenhuma categoria de encomenda encontrada.');
      return;
    }

    rideController.initData();
    locationController.initAddLocationData();
    locationController.initParcelData();
    parcelController.initParcelData();
    mapController.initializeData();

    parcelController.configureMarketplaceShippingContext(
      orderId: order.id,
      orderNumber: order.orderNumber,
      storeName: order.sellerName.isEmpty ? order.storeName : order.sellerName,
      shippingAmount: order.shippingAmount,
      shippingDiscount: order.shippingDiscount,
      notify: false,
    );

    final Address pickupAddress = Address(
      address: order.pickupAddress,
      latitude: order.pickupLatitude,
      longitude: order.pickupLongitude,
      addressLabel: 'others',
    );

    final Address deliveryAddress = Address(
      address: order.deliveryAddress,
      latitude: order.deliveryLatitude,
      longitude: order.deliveryLongitude,
      addressLabel: 'others',
    );

    final String sellerCountryCode = countryCodeForPhone(order.sellerPhone);
    final String customerCountryCode = countryCodeForPhone(order.customerPhone);

    parcelController.onChangeSenderCountryCode(
      sellerCountryCode,
      isUpdate: false,
    );
    parcelController.onChangeReceiverCountryCode(customerCountryCode);

    parcelController.senderContactController.text =
        localPhoneForField(order.sellerPhone, sellerCountryCode);
    parcelController.senderNameController.text =
        order.sellerName.isEmpty ? order.storeName : order.sellerName;
    parcelController.senderAddressController.text = order.pickupAddress;

    parcelController.receiverContactController.text =
        localPhoneForField(order.customerPhone, customerCountryCode);
    parcelController.receiverNameController.text = order.customerName;
    parcelController.receiverAddressController.text = order.deliveryAddress;

    final String productsText = order.items.map((item) {
      return '${item.quantity}x ${item.productName}';
    }).join(', ');

    rideController.pickupNoteController.text =
        'Pedido Marketplace ${order.orderNumber}. Produtos: $productsText';

    locationController.setSenderAddress(pickupAddress);
    locationController.setReceiverAddress(deliveryAddress);

    parcelController.updateTabControllerIndex(0);
    parcelController.updateParcelState(ParcelDeliveryState.initial);

    Get.to(() => const MapScreen(fromScreen: MapScreenType.parcel));
  }

  String onlyNumbers(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String countryCodeForPhone(String phone) {
    final String trimmed = phone.trim();
    final String digits = onlyNumbers(trimmed);

    if (trimmed.startsWith('+') && digits.startsWith('55')) {
      return '+55';
    }

    if (digits.startsWith('55') && digits.length > 11) {
      return '+55';
    }

    return '+55';
  }

  String localPhoneForField(String phone, String countryCode) {
    String digits = onlyNumbers(phone);

    if (countryCode == '+55' && digits.startsWith('55') && digits.length > 11) {
      digits = digits.substring(2);
    }

    return digits;
  }

  Future<bool> showConfirmActionSheet({
    required StoreSellerOrderItem order,
    required String status,
    required String actionLabel,
  }) async {
    final Color primaryColor = Theme.of(context).primaryColor;

    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bool isPickup = status == 'ready_for_pickup';
        final bool isAlreadyRequested =
            status == 'lokally_shipping_requested' &&
                order.orderStatus == 'lokally_shipping_requested';

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
                        isPickup
                            ? Icons.inventory_2_outlined
                            : Icons.local_shipping_outlined,
                        color: primaryColor,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        isPickup
                            ? 'Liberar retirada'
                            : isAlreadyRequested
                                ? 'Abrir Lokally Envios'
                                : 'Enviar com Lokally Envios',
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(false),
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
                const SizedBox(height: 14),
                Text(
                  isPickup
                      ? 'Confirme que o pedido está separado e disponível para o cliente retirar na loja.'
                      : isAlreadyRequested
                          ? 'Este pedido já foi marcado para Lokally Envios. Vamos abrir o fluxo de solicitação de entrega com os endereços preenchidos.'
                          : 'Confirme que você deseja solicitar um parceiro Lokally. No próximo passo, abriremos o fluxo de entrega com coleta e destino preenchidos.',
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 12.8,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                StoreSellerOrderMiniSummary(order: order),
                const SizedBox(height: 15),
                Material(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(true),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 48,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'Confirmar $actionLabel',
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 13.4,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(false),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 46,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'Cancelar',
                        style: textBold.copyWith(
                          color: Colors.grey.shade700,
                          fontSize: 13.2,
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

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F6),
      body: Column(
        children: [
          StoreSellerOrderListTopBar(
            primaryColor: primaryColor,
            onBackTap: () => Get.back(),
          ),
          Expanded(
            child: RefreshIndicator(
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
                  StoreSellerOrderListIntro(
                    primaryColor: primaryColor,
                    counts: counts,
                  ),
                  const SizedBox(height: 14),
                  StoreSellerOrderFilters(
                    primaryColor: primaryColor,
                    filters: filters,
                    selectedFilter: selectedFilter,
                    countForFilter: countForFilter,
                    onChanged: (filter) => loadOrders(filterKey: filter),
                  ),
                  const SizedBox(height: 14),
                  if (isLoading)
                    StoreSellerOrdersLoading(primaryColor: primaryColor)
                  else if (orders.isEmpty)
                    StoreSellerOrdersEmpty(
                      primaryColor: primaryColor,
                      selectedFilter: selectedFilter,
                    )
                  else
                    ...orders.map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StoreSellerOrderCard(
                          order: order,
                          primaryColor: primaryColor,
                          onReadyForPickupTap: () => updateOrderStatus(
                            order,
                            'ready_for_pickup',
                          ),
                          onRequestLokallyShippingTap: () =>
                              requestLokallyShipping(order),
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

class StoreSellerOrderListTopBar extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onBackTap;

  const StoreSellerOrderListTopBar({
    super.key,
    required this.primaryColor,
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
              'Pedidos da loja',
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

class StoreSellerOrderListIntro extends StatelessWidget {
  final Color primaryColor;
  final StoreSellerOrderCounts counts;

  const StoreSellerOrderListIntro({
    super.key,
    required this.primaryColor,
    required this.counts,
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
            'Gestão de pedidos',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Acompanhe pedidos pagos, retiradas e entregas com Lokally Envios.',
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
                child: StoreSellerOrderMiniCount(
                  primaryColor: primaryColor,
                  value: counts.pickup.toString(),
                  label: 'Retirada',
                  icon: Icons.storefront_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StoreSellerOrderMiniCount(
                  primaryColor: primaryColor,
                  value: counts.lokallyShipping.toString(),
                  label: 'Envios',
                  icon: Icons.local_shipping_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StoreSellerOrderMiniCount(
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

class StoreSellerOrderMiniCount extends StatelessWidget {
  final Color primaryColor;
  final String value;
  final String label;
  final IconData icon;

  const StoreSellerOrderMiniCount({
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

class StoreSellerOrderFilters extends StatelessWidget {
  final Color primaryColor;
  final List<StoreSellerOrderFilter> filters;
  final String selectedFilter;
  final int Function(String keyName) countForFilter;
  final ValueChanged<String> onChanged;

  const StoreSellerOrderFilters({
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
          final StoreSellerOrderFilter filter = filters[index];
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

class StoreSellerOrderCard extends StatelessWidget {
  final StoreSellerOrderItem order;
  final Color primaryColor;
  final VoidCallback onReadyForPickupTap;
  final VoidCallback onRequestLokallyShippingTap;

  const StoreSellerOrderCard({
    super.key,
    required this.order,
    required this.primaryColor,
    required this.onReadyForPickupTap,
    required this.onRequestLokallyShippingTap,
  });

  bool get canMarkReadyForPickup {
    return order.deliveryType == 'pickup' &&
        (order.orderStatus == 'payment_approved' ||
            order.orderStatus == 'preparing');
  }

  bool get canRequestLokallyShipping {
    return order.deliveryType == 'lokally_shipping' &&
        (order.orderStatus == 'lokally_shipping_pending' ||
            order.orderStatus == 'lokally_shipping_requested');
  }

  Color get statusColor {
    switch (order.orderStatus) {
      case 'ready_for_pickup':
      case 'completed':
      case 'lokally_shipping_requested':
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

  String get lokallyShippingButtonLabel {
    return order.orderStatus == 'lokally_shipping_requested'
        ? 'Abrir Lokally Envios'
        : 'Enviar com Lokally Envios';
  }

  @override
  Widget build(BuildContext context) {
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  deliveryIcon,
                  color: primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${order.deliveryTypeLabel} • ${order.paymentStatusLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11.6,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                StoreSellerOrderCurrency.format(order.total),
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
              StoreSellerOrderStatusBadge(
                label: order.orderStatusLabel,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.createdAt.isEmpty ? '' : order.createdAt,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade500,
                    fontSize: 10.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          StoreSellerOrderCustomerLine(order: order),
          const SizedBox(height: 11),
          ...order.items.take(3).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: StoreSellerOrderItemLine(item: item),
                ),
              ),
          if (order.items.length > 3)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                '+ ${order.items.length - 3} item(ns)',
                style: textRegular.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 11.6,
                ),
              ),
            ),
          StoreSellerOrderAddressBlock(order: order),
          if (canMarkReadyForPickup || canRequestLokallyShipping) ...[
            const SizedBox(height: 12),
            if (canMarkReadyForPickup)
              StoreSellerOrderActionButton(
                primaryColor: primaryColor,
                label: 'Liberar retirada',
                icon: Icons.inventory_2_outlined,
                onTap: onReadyForPickupTap,
              ),
            if (canRequestLokallyShipping)
              StoreSellerOrderActionButton(
                primaryColor: primaryColor,
                label: lokallyShippingButtonLabel,
                icon: Icons.local_shipping_outlined,
                onTap: onRequestLokallyShippingTap,
              ),
          ],
        ],
      ),
    );
  }
}

class StoreSellerOrderCustomerLine extends StatelessWidget {
  final StoreSellerOrderItem order;

  const StoreSellerOrderCustomerLine({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final String phone =
        order.customerPhone.isEmpty ? '' : ' • ${order.customerPhone}';

    return Row(
      children: [
        Icon(
          Icons.person_outline_rounded,
          color: Colors.grey.shade600,
          size: 17,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${order.customerName}$phone',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textMedium.copyWith(
              color: Colors.black87,
              fontSize: 12.4,
            ),
          ),
        ),
      ],
    );
  }
}

class StoreSellerOrderAddressBlock extends StatelessWidget {
  final StoreSellerOrderItem order;

  const StoreSellerOrderAddressBlock({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPickup = order.deliveryType == 'pickup';
    final String title = isPickup ? 'Retirada' : 'Entrega';
    final String address =
        isPickup ? order.pickupAddress : order.deliveryAddress;

    if (address.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPickup
                ? Icons.store_mall_directory_outlined
                : Icons.location_on_outlined,
            color: Colors.grey.shade600,
            size: 17,
          ),
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
                  address,
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

class StoreSellerOrderItemLine extends StatelessWidget {
  final StoreSellerOrderProductItem item;

  const StoreSellerOrderItemLine({
    super.key,
    required this.item,
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
          child: Text(
            '${item.quantity}x ${item.productName}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textMedium.copyWith(
              color: Colors.black87,
              fontSize: 12.4,
              height: 1.18,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          StoreSellerOrderCurrency.format(item.total),
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 12.2,
          ),
        ),
      ],
    );
  }
}

class StoreSellerOrderStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StoreSellerOrderStatusBadge({
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

class StoreSellerOrderActionButton extends StatelessWidget {
  final Color primaryColor;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const StoreSellerOrderActionButton({
    super.key,
    required this.primaryColor,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primaryColor,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          height: 44,
          width: double.infinity,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: textBold.copyWith(
                  color: Colors.white,
                  fontSize: 13.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreSellerOrdersLoading extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerOrdersLoading({
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

class StoreSellerOrdersEmpty extends StatelessWidget {
  final Color primaryColor;
  final String selectedFilter;

  const StoreSellerOrdersEmpty({
    super.key,
    required this.primaryColor,
    required this.selectedFilter,
  });

  @override
  Widget build(BuildContext context) {
    final String message = selectedFilter == 'pickup'
        ? 'Quando houver pedidos para retirada, eles aparecerão aqui.'
        : selectedFilter == 'lokally_shipping'
            ? 'Quando houver pedidos com Lokally Envios, eles aparecerão aqui.'
            : 'Quando houver pedidos pagos da loja, eles aparecerão aqui.';

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
            Icons.receipt_long_outlined,
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

class StoreSellerOrderMiniSummary extends StatelessWidget {
  final StoreSellerOrderItem order;

  const StoreSellerOrderMiniSummary({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final StoreSellerOrderProductItem? firstItem =
        order.items.isEmpty ? null : order.items.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.orderNumber,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 13.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            firstItem == null
                ? 'Pedido sem itens'
                : '${firstItem.quantity}x ${firstItem.productName}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textRegular.copyWith(
              color: Colors.grey.shade700,
              fontSize: 12.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            StoreSellerOrderCurrency.format(order.total),
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerOrderFilter {
  final String keyName;
  final String label;
  final String apiFilter;

  StoreSellerOrderFilter({
    required this.keyName,
    required this.label,
    required this.apiFilter,
  });
}

class StoreSellerOrderCounts {
  final int all;
  final int pickup;
  final int lokallyShipping;
  final int readyForPickup;
  final int lokallyShippingPending;

  StoreSellerOrderCounts({
    required this.all,
    required this.pickup,
    required this.lokallyShipping,
    required this.readyForPickup,
    required this.lokallyShippingPending,
  });

  factory StoreSellerOrderCounts.empty() {
    return StoreSellerOrderCounts(
      all: 0,
      pickup: 0,
      lokallyShipping: 0,
      readyForPickup: 0,
      lokallyShippingPending: 0,
    );
  }

  factory StoreSellerOrderCounts.fromMap(Map<String, dynamic> map) {
    return StoreSellerOrderCounts(
      all: StoreSellerOrderParser.parseInt(map['all']),
      pickup: StoreSellerOrderParser.parseInt(map['pickup']),
      lokallyShipping: StoreSellerOrderParser.parseInt(map['lokally_shipping']),
      readyForPickup: StoreSellerOrderParser.parseInt(map['ready_for_pickup']),
      lokallyShippingPending:
          StoreSellerOrderParser.parseInt(map['lokally_shipping_pending']),
    );
  }
}

class StoreSellerOrderItem {
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
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String pickupAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final String sellerName;
  final String sellerPhone;
  final String storeName;
  final String parcelRequestId;
  final List<StoreSellerOrderProductItem> items;
  final String createdAt;

  StoreSellerOrderItem({
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
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    required this.pickupAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.sellerName,
    required this.sellerPhone,
    required this.storeName,
    required this.parcelRequestId,
    required this.items,
    required this.createdAt,
  });

  bool get hasCompleteLokallyShippingData {
    return pickupAddress.trim().isNotEmpty &&
        deliveryAddress.trim().isNotEmpty &&
        pickupLatitude != 0 &&
        pickupLongitude != 0 &&
        deliveryLatitude != 0 &&
        deliveryLongitude != 0 &&
        sellerPhone.trim().isNotEmpty &&
        customerPhone.trim().isNotEmpty;
  }

  factory StoreSellerOrderItem.fromMap(Map<String, dynamic> map) {
    final dynamic customerValue = map['customer'];
    final Map<String, dynamic> customer = customerValue is Map
        ? Map<String, dynamic>.from(customerValue)
        : <String, dynamic>{};

    final dynamic deliveryValue = map['delivery'];
    final Map<String, dynamic> delivery = deliveryValue is Map
        ? Map<String, dynamic>.from(deliveryValue)
        : <String, dynamic>{};

    final dynamic pickupValue = map['pickup'];
    final Map<String, dynamic> pickup = pickupValue is Map
        ? Map<String, dynamic>.from(pickupValue)
        : <String, dynamic>{};

    final dynamic sellerValue = map['seller'];
    final Map<String, dynamic> seller = sellerValue is Map
        ? Map<String, dynamic>.from(sellerValue)
        : <String, dynamic>{};

    final dynamic itemsValue = map['items'];
    final List<dynamic> itemsList =
        itemsValue is List ? itemsValue : <dynamic>[];

    final String parsedSellerName =
        '${pickup['seller_name'] ?? seller['name'] ?? ''}';

    return StoreSellerOrderItem(
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
      subtotal: StoreSellerOrderParser.parseDouble(map['subtotal']),
      shippingAmount: StoreSellerOrderParser.parseDouble(
        map['shipping_amount'],
      ),
      shippingDiscount: StoreSellerOrderParser.parseDouble(
        map['shipping_discount'],
      ),
      total: StoreSellerOrderParser.parseDouble(map['total']),
      customerName: '${customer['name'] ?? ''}',
      customerPhone: '${customer['phone'] ?? ''}',
      deliveryAddress: '${delivery['address'] ?? ''}',
      deliveryLatitude: StoreSellerOrderParser.parseDouble(
        delivery['latitude'],
      ),
      deliveryLongitude: StoreSellerOrderParser.parseDouble(
        delivery['longitude'],
      ),
      pickupAddress: '${pickup['address'] ?? ''}',
      pickupLatitude: StoreSellerOrderParser.parseDouble(
        pickup['latitude'],
      ),
      pickupLongitude: StoreSellerOrderParser.parseDouble(
        pickup['longitude'],
      ),
      sellerName: parsedSellerName,
      sellerPhone: '${pickup['phone'] ?? pickup['seller_phone'] ?? ''}',
      storeName: '${seller['name'] ?? parsedSellerName}',
      parcelRequestId: '${map['parcel_request_id'] ?? ''}',
      items: itemsList
          .whereType<Map>()
          .map(
            (item) => StoreSellerOrderProductItem.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      createdAt: '${map['created_at'] ?? ''}',
    );
  }
}

class StoreSellerOrderProductItem {
  final String id;
  final String productId;
  final String productName;
  final String productImageUrl;
  final double unitPrice;
  final int quantity;
  final double total;

  StoreSellerOrderProductItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.total,
  });

  factory StoreSellerOrderProductItem.fromMap(Map<String, dynamic> map) {
    return StoreSellerOrderProductItem(
      id: '${map['id'] ?? ''}',
      productId: '${map['product_id'] ?? ''}',
      productName: '${map['product_name'] ?? ''}',
      productImageUrl: '${map['product_image_url'] ?? ''}',
      unitPrice: StoreSellerOrderParser.parseDouble(map['unit_price']),
      quantity: StoreSellerOrderParser.parseInt(map['quantity']),
      total: StoreSellerOrderParser.parseDouble(map['total']),
    );
  }
}

class StoreSellerOrderParser {
  static double parseDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse('$value') ?? 0;
  }

  static int parseInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse('$value') ?? 0;
  }
}

class StoreSellerOrderCurrency {
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
