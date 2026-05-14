import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> openServiceChat(StoreSellerOrderItem order) async {
    if (!order.canOpenServiceChat) {
      showStoreMessage(
          'O Chat Lokally será liberado após a aprovação do pagamento.');
      return;
    }

    await Get.to(
      () => StoreServiceChatScreen(order: order),
    );

    if (mounted) {
      await loadOrders();
    }
  }

  Future<void> sendServiceFile(StoreSellerOrderItem order) async {
    if (!order.canOpenServiceChat) {
      showStoreMessage(
          'O Chat Lokally será liberado após a aprovação do pagamento.');
      return;
    }

    await Get.to(
      () => StoreServiceChatScreen(
        order: order,
        openAttachmentPickerOnStart: true,
      ),
    );

    if (mounted) {
      await loadOrders();
    }
  }

  Future<void> completeOrder(StoreSellerOrderItem order) async {
    if (!order.canCompleteOrder) {
      showStoreMessage('Este pedido ainda não pode ser finalizado.');
      return;
    }

    final bool confirmed = await showCompleteOrderSheet(order);

    if (!confirmed) {
      return;
    }

    showStoreMessage(order.isServiceOrder
        ? 'Finalizando serviço...'
        : 'Finalizando entrega...');

    final Response response = await Get.find<ApiClient>().postData(
      '$storeSellerOrdersUri/${order.id}/complete',
      <String, dynamic>{},
    );

    final dynamic body = response.body;

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        body is Map &&
        body['status'] == true) {
      showStoreMessage(order.isServiceOrder
          ? 'Serviço finalizado. O cliente foi avisado.'
          : 'Entrega finalizada. O cliente foi avisado.');
      await loadOrders();
      return;
    }

    showStoreMessage(
      body is Map && body['message'] != null
          ? body['message'].toString()
          : 'Não foi possível finalizar o pedido.',
    );
  }

  Future<bool> showCompleteOrderSheet(StoreSellerOrderItem order) async {
    final Color primaryColor = Theme.of(context).primaryColor;
    final bool isService = order.isServiceOrder;

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
                        isService
                            ? Icons.task_alt_rounded
                            : Icons.inventory_2_outlined,
                        color: primaryColor,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        isService ? 'Finalizar serviço' : 'Finalizar entrega',
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
                  isService
                      ? 'Confirme apenas se o serviço foi entregue ao cliente. Uma mensagem será enviada no Chat Lokally e o cliente terá 24h para autorizar o repasse ou abrir disputa.'
                      : 'Confirme apenas se o produto foi entregue ao cliente. O cliente terá 24h para autorizar o repasse ou abrir disputa.',
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
                        isService
                            ? 'Confirmar finalização do serviço'
                            : 'Confirmar finalização da entrega',
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

  Future<void> openDisputeTicket(StoreSellerOrderItem order) async {
    if (!order.isDisputedRelease && order.orderStatus != 'dispute_opened') {
      showStoreMessage('Este pedido ainda não possui disputa aberta.');
      return;
    }

    await Get.to(
      () => StoreSellerOrderDisputeScreen(order: order),
    );

    if (mounted) {
      await loadOrders();
    }
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
                          onOpenServiceChatTap: () => openServiceChat(order),
                          onSendServiceFileTap: () => sendServiceFile(order),
                          onCompleteOrderTap: () => completeOrder(order),
                          onOpenDisputeTap: () => openDisputeTicket(order),
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
  final VoidCallback onOpenServiceChatTap;
  final VoidCallback onSendServiceFileTap;
  final VoidCallback onCompleteOrderTap;
  final VoidCallback onOpenDisputeTap;

  const StoreSellerOrderCard({
    super.key,
    required this.order,
    required this.primaryColor,
    required this.onReadyForPickupTap,
    required this.onRequestLokallyShippingTap,
    required this.onOpenServiceChatTap,
    required this.onSendServiceFileTap,
    required this.onCompleteOrderTap,
    required this.onOpenDisputeTap,
  });

  bool get canMarkReadyForPickup {
    return !order.isServiceOrder &&
        order.deliveryType == 'pickup' &&
        (order.orderStatus == 'payment_approved' ||
            order.orderStatus == 'preparing');
  }

  bool get canRequestLokallyShipping {
    return !order.isServiceOrder &&
        order.deliveryType == 'lokally_shipping' &&
        (order.orderStatus == 'lokally_shipping_pending' ||
            order.orderStatus == 'lokally_shipping_requested');
  }

  bool get canUseServiceFlow {
    return order.canOpenServiceChat;
  }

  bool get canCompleteOrder {
    return order.canCompleteOrder;
  }

  bool get canSendServiceFile {
    return order.canOpenServiceChat && order.isDownloadService;
  }

  bool get shouldShowOrderStatusBadge {
    final String orderLabel = order.orderStatusLabel.trim().toLowerCase();
    final String paymentLabel = order.paymentStatusLabel.trim().toLowerCase();

    return orderLabel.isNotEmpty && orderLabel != paymentLabel;
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

  Color get paymentStatusColor {
    switch (order.paymentStatus) {
      case 'approved':
      case 'paid':
        return primaryColor;
      case 'failed':
      case 'cancelled':
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.orangeAccent;
    }
  }

  IconData get deliveryIcon {
    if (order.isServiceOrder) {
      if (order.isDownloadService) {
        return Icons.file_download_outlined;
      }

      if (order.isPresentialService) {
        return Icons.handshake_outlined;
      }

      if (order.isHomeOfficeService) {
        return Icons.home_work_outlined;
      }

      return Icons.chat_bubble_outline_rounded;
    }

    return order.deliveryType == 'pickup'
        ? Icons.storefront_rounded
        : Icons.local_shipping_outlined;
  }

  String get lokallyShippingButtonLabel {
    return order.orderStatus == 'lokally_shipping_requested'
        ? 'Abrir Lokally Envios'
        : 'Enviar com Lokally Envios';
  }

  String get serviceButtonLabel {
    if (order.serviceActionLabel.isNotEmpty) {
      return order.serviceActionLabel;
    }

    return 'Abrir Chat Lokally';
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
                      order.deliveryTypeLabel,
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
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StoreSellerOrderStatusBadge(
                      label: order.paymentStatusLabel,
                      color: paymentStatusColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                order.createdAt.isEmpty ? '' : order.createdAt,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textRegular.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: 10.8,
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
          if (order.isServiceOrder)
            StoreSellerOrderServiceBlock(
              order: order,
              primaryColor: primaryColor,
            )
          else
            StoreSellerOrderAddressBlock(order: order),
          if (order.releaseStatusLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            StoreSellerReleaseStatusBlock(
              order: order,
              primaryColor: primaryColor,
            ),
          ],
          if (canMarkReadyForPickup ||
              canRequestLokallyShipping ||
              canUseServiceFlow ||
              canCompleteOrder ||
              order.isDisputedRelease) ...[
            const SizedBox(height: 12),
            if (order.isDisputedRelease) ...[
              StoreSellerOrderActionButton(
                primaryColor: Colors.redAccent,
                label: 'Acompanhar disputa',
                icon: Icons.timeline_outlined,
                onTap: onOpenDisputeTap,
              ),
              if (canMarkReadyForPickup ||
                  canRequestLokallyShipping ||
                  canCompleteOrder ||
                  canUseServiceFlow)
                const SizedBox(height: 8),
            ],
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
            if (canCompleteOrder) ...[
              StoreSellerOrderActionButton(
                primaryColor: primaryColor,
                label: order.isServiceOrder
                    ? 'Finalizar serviço'
                    : 'Finalizar entrega',
                icon: Icons.task_alt_rounded,
                onTap: onCompleteOrderTap,
              ),
              if (canUseServiceFlow) const SizedBox(height: 8),
            ],
            if (canUseServiceFlow) ...[
              if (canSendServiceFile) ...[
                StoreSellerOrderActionButton(
                  primaryColor: primaryColor,
                  label: 'Enviar arquivo',
                  icon: Icons.upload_file_outlined,
                  onTap: onSendServiceFileTap,
                ),
                const SizedBox(height: 8),
              ],
              StoreSellerOrderActionButton(
                primaryColor: primaryColor,
                label: serviceButtonLabel,
                icon: Icons.chat_bubble_outline_rounded,
                onTap: onOpenServiceChatTap,
              ),
            ],
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
    final String phone = !order.isServiceOrder && order.customerPhone.isNotEmpty
        ? ' • ${order.customerPhone}'
        : '';
    final String helper = order.isServiceOrder && order.canOpenServiceChat
        ? ' • Chat Lokally'
        : '';

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
            '${order.customerName}$phone$helper',
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

class StoreSellerOrderServiceBlock extends StatelessWidget {
  final StoreSellerOrderItem order;
  final Color primaryColor;

  const StoreSellerOrderServiceBlock({
    super.key,
    required this.order,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool chatAvailable = order.canOpenServiceChat;
    final String description = order.serviceDeliveryDescription.isEmpty
        ? 'Serviço contratado pelo Marketplace Lokally.'
        : order.serviceDeliveryDescription;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: primaryColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            chatAvailable
                ? Icons.chat_bubble_outline_rounded
                : Icons.lock_clock_outlined,
            color: primaryColor,
            size: 18,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.serviceDeliveryLabel.isEmpty
                      ? 'Serviço'
                      : 'Serviço ${order.serviceDeliveryLabel}',
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 11.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 11.5,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  chatAvailable
                      ? 'Use o Chat Lokally para alinhar detalhes e enviar materiais do serviço.'
                      : order.releaseStatus.isNotEmpty ||
                              order.orderStatus ==
                                  'awaiting_customer_release' ||
                              order.orderStatus == 'payout_authorized' ||
                              order.orderStatus == 'auto_payout_authorized' ||
                              order.orderStatus == 'dispute_opened' ||
                              order.orderStatus ==
                                  'dispute_resolved_customer' ||
                              order.orderStatus == 'dispute_resolved_seller' ||
                              order.isDisputeFinalized
                          ? 'Chat encerrado após a finalização do pedido pelo lojista.'
                          : 'O Chat Lokally será liberado após a aprovação do pagamento.',
                  style: textMedium.copyWith(
                    color: chatAvailable
                        ? primaryColor
                        : order.releaseStatus.isNotEmpty ||
                                order.orderStatus ==
                                    'awaiting_customer_release' ||
                                order.orderStatus == 'payout_authorized' ||
                                order.orderStatus == 'auto_payout_authorized' ||
                                order.orderStatus == 'dispute_opened' ||
                                order.orderStatus ==
                                    'dispute_resolved_customer' ||
                                order.orderStatus ==
                                    'dispute_resolved_seller' ||
                                order.isDisputeFinalized
                            ? Colors.grey.shade700
                            : Colors.orange.shade800,
                    fontSize: 10.8,
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

class StoreSellerReleaseStatusBlock extends StatelessWidget {
  final StoreSellerOrderItem order;
  final Color primaryColor;

  const StoreSellerReleaseStatusBlock({
    super.key,
    required this.order,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool disputeFinalized = order.isDisputeFinalized;
    final bool disputed = order.isDisputedRelease;
    final bool authorized = order.isAuthorizedRelease;

    final String title = disputeFinalized
        ? 'Disputa encerrada pela Lokally'
        : authorized
            ? 'Repasse autorizado pelo cliente'
            : order.releaseStatusLabel;

    final String finalMessage = order.disputeResolutionMessage.trim();
    final String message = disputeFinalized
        ? (finalMessage.isNotEmpty
            ? finalMessage
            : 'A disputa foi encerrada pela Lokally.')
        : disputed
            ? 'O cliente abriu uma disputa. A tratativa será mediada pela Lokally. Toque em Acompanhar disputa para responder solicitações e enviar comprovantes.'
            : authorized
                ? 'Aguarde que em até 24h o valor será creditado em sua conta, de acordo com as regras e taxas de pagamento Lokally Pay.'
                : 'O cliente foi avisado e tem até 24h para autorizar o repasse ou abrir uma disputa.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: disputeFinalized
            ? Colors.orangeAccent.withValues(alpha: 0.10)
            : disputed
                ? Colors.redAccent.withValues(alpha: 0.08)
                : authorized
                    ? primaryColor.withValues(alpha: 0.07)
                    : Colors.orangeAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: disputeFinalized
              ? Colors.orangeAccent.withValues(alpha: 0.24)
              : disputed
                  ? Colors.redAccent.withValues(alpha: 0.20)
                  : authorized
                      ? primaryColor.withValues(alpha: 0.18)
                      : Colors.orangeAccent.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            disputeFinalized
                ? Icons.gavel_outlined
                : disputed
                    ? Icons.report_problem_outlined
                    : authorized
                        ? Icons.verified_outlined
                        : Icons.schedule_outlined,
            color: disputeFinalized
                ? Colors.orange.shade800
                : disputed
                    ? Colors.redAccent
                    : authorized
                        ? primaryColor
                        : Colors.orange.shade800,
            size: 18,
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
                if (disputeFinalized &&
                    order.disputeResolutionTargetLabel.isNotEmpty) ...[
                  Text(
                    order.disputeResolutionTargetLabel,
                    style: textBold.copyWith(
                      color: Colors.orange.shade900,
                      fontSize: 11.2,
                      height: 1.22,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  message,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 11.2,
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

  bool get isDownloadService => serviceDeliveryType == 'download';

  bool get isPresentialService {
    return serviceDeliveryType == 'presential' ||
        serviceDeliveryType == 'presencial';
  }

  bool get isHomeOfficeService => serviceDeliveryType == 'home_office';

  bool get isPaymentApproved {
    return paymentStatus == 'approved' || paymentStatus == 'paid';
  }

  bool get canOpenServiceChat {
    return isServiceOrder &&
        serviceChatAvailable &&
        isPaymentApproved &&
        releaseStatus.isEmpty &&
        orderStatus != 'awaiting_customer_release' &&
        orderStatus != 'payout_authorized' &&
        orderStatus != 'auto_payout_authorized' &&
        orderStatus != 'dispute_opened' &&
        orderStatus != 'dispute_resolved_customer' &&
        orderStatus != 'dispute_resolved_seller' &&
        !isDisputeFinalized &&
        orderStatus != 'completed' &&
        orderStatus != 'cancelled';
  }

  bool get isReleasePending {
    return releaseStatus == 'pending_customer_authorization';
  }

  bool get isDisputeFinalized {
    return isDisputeResolved ||
        disputeStatus == 'resolved' ||
        disputeStatus == 'resolved_customer' ||
        disputeStatus == 'resolved_seller' ||
        disputeStatus == 'closed' ||
        releaseStatus == 'dispute_resolved_customer' ||
        releaseStatus == 'dispute_resolved_seller' ||
        orderStatus == 'dispute_resolved_customer' ||
        orderStatus == 'dispute_resolved_seller';
  }

  bool get isAuthorizedRelease {
    return !isDisputeFinalized &&
        (releaseStatus == 'authorized' || releaseStatus == 'auto_authorized');
  }

  bool get isDisputedRelease {
    return !isDisputeFinalized && releaseStatus == 'disputed';
  }

  bool get canCompleteOrder {
    return isPaymentApproved &&
        releaseStatus.isEmpty &&
        orderStatus != 'awaiting_customer_release' &&
        orderStatus != 'payout_authorized' &&
        orderStatus != 'dispute_opened' &&
        orderStatus != 'dispute_resolved_customer' &&
        orderStatus != 'dispute_resolved_seller' &&
        !isDisputeFinalized &&
        orderStatus != 'auto_payout_authorized' &&
        orderStatus != 'completed' &&
        orderStatus != 'cancelled';
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

    final List<StoreSellerOrderProductItem> parsedItems = itemsList
        .whereType<Map>()
        .map(
          (item) => StoreSellerOrderProductItem.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();

    final bool containsService = StoreSellerOrderParser.parseBool(
      map['contains_service_items'],
    );
    final bool containsPhysical = StoreSellerOrderParser.parseBool(
      map['contains_physical_items'],
    );
    final bool serviceOrder = StoreSellerOrderParser.parseBool(
      map['is_service_order'],
    );
    final bool mixedOrder = StoreSellerOrderParser.parseBool(
      map['is_mixed_order'],
    );

    final String parsedSellerName =
        '${pickup['seller_name'] ?? seller['name'] ?? ''}';

    return StoreSellerOrderItem(
      id: '${map['id'] ?? ''}',
      orderNumber: '${map['order_number'] ?? ''}',
      deliveryType: '${map['delivery_type'] ?? ''}',
      deliveryTypeLabel: '${map['delivery_type_label'] ?? ''}',
      containsServiceItems:
          containsService || parsedItems.any((item) => item.isService),
      containsPhysicalItems:
          containsPhysical || parsedItems.any((item) => !item.isService),
      isServiceOrder: serviceOrder ||
          (parsedItems.isNotEmpty &&
              parsedItems.every((item) => item.isService)),
      isMixedOrder: mixedOrder,
      serviceDeliveryType: '${map['service_delivery_type'] ?? ''}',
      serviceDeliveryLabel: '${map['service_delivery_label'] ?? ''}',
      serviceDeliveryDescription:
          '${map['service_delivery_description'] ?? ''}',
      serviceActionLabel: '${map['service_action_label'] ?? ''}',
      serviceChatAvailable: StoreSellerOrderParser.parseBool(
        map['service_chat_available'],
      ),
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
          StoreSellerOrderParser.parseBool(map['is_dispute_resolved']),
      canAuthorizePayout:
          StoreSellerOrderParser.parseBool(map['can_authorize_payout']),
      canOpenDispute: StoreSellerOrderParser.parseBool(map['can_open_dispute']),
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
      items: parsedItems,
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
  final String productType;
  final String conditionType;
  final String serviceDeliveryType;
  final String serviceDeliveryLabel;
  final String serviceDeliveryDescription;
  final bool isService;

  StoreSellerOrderProductItem({
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

  factory StoreSellerOrderProductItem.fromMap(Map<String, dynamic> map) {
    final String type = '${map['product_type'] ?? 'physical'}';

    return StoreSellerOrderProductItem(
      id: '${map['id'] ?? ''}',
      productId: '${map['product_id'] ?? ''}',
      productName: '${map['product_name'] ?? ''}',
      productImageUrl: '${map['product_image_url'] ?? ''}',
      unitPrice: StoreSellerOrderParser.parseDouble(map['unit_price']),
      quantity: StoreSellerOrderParser.parseInt(map['quantity']),
      total: StoreSellerOrderParser.parseDouble(map['total']),
      productType: type,
      conditionType: '${map['condition_type'] ?? ''}',
      serviceDeliveryType: '${map['service_delivery_type'] ?? ''}',
      serviceDeliveryLabel: '${map['service_delivery_label'] ?? ''}',
      serviceDeliveryDescription:
          '${map['service_delivery_description'] ?? ''}',
      isService: StoreSellerOrderParser.parseBool(map['is_service']) ||
          type == 'service',
    );
  }
}

class StoreSellerOrderDisputeScreen extends StatefulWidget {
  final StoreSellerOrderItem order;

  const StoreSellerOrderDisputeScreen({
    super.key,
    required this.order,
  });

  @override
  State<StoreSellerOrderDisputeScreen> createState() =>
      _StoreSellerOrderDisputeScreenState();
}

class _StoreSellerOrderDisputeScreenState
    extends State<StoreSellerOrderDisputeScreen> {
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

  StoreSellerOrderDispute? dispute;
  List<StoreSellerOrderDisputeMessage> messages =
      <StoreSellerOrderDisputeMessage>[];

  String get disputeBaseUri {
    return '/api/customer/store/order-disputes/${widget.order.id}';
  }

  String get disputeUri {
    return '$disputeBaseUri?actor_type=seller';
  }

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

    try {
      final Response response = await Get.find<ApiClient>().getData(disputeUri);

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if (response.statusCode != 200 ||
          body is! Map ||
          body['status'] != true) {
        showDisputeMessage(
          body is Map && body['message'] != null
              ? body['message'].toString()
              : 'Não foi possível abrir a Disputa Lokally.',
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
            ? StoreSellerOrderDispute.fromMap(
                Map<String, dynamic>.from(disputeValue),
              )
            : null;
        messages = messagesValue is List
            ? messagesValue
                .whereType<Map>()
                .map(
                  (item) => StoreSellerOrderDisputeMessage.fromMap(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
            : <StoreSellerOrderDisputeMessage>[];
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToBottom();
      });
    } catch (_) {
      if (mounted) {
        showDisputeMessage('Não foi possível abrir a Disputa Lokally.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
                        'Anexar comprovante à disputa',
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
                  'Envie arquivos para a equipe Lokally analisar a disputa, como comprovantes de entrega, arquivos enviados, prints ou documentos do serviço.',
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

  Future<void> sendTextMessage() async {
    final String message = messageController.text.trim();

    if (message.isEmpty || isSending) {
      return;
    }

    messageController.clear();
    await sendMessage(message: message);
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
          '$disputeBaseUri/message',
          <String, String>{
            'message': message,
            'actor_type': 'seller',
            'file_original_name': file.name,
            'file_extension': StoreChatFileHelper.extensionFromName(file.name),
          },
          MultipartBody('file', file),
          <MultipartBody>[],
        );
      } else {
        response = await Get.find<ApiClient>().postData(
          '$disputeBaseUri/message',
          <String, dynamic>{
            'message': message,
            'actor_type': 'seller',
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
        await loadDispute();
        return;
      }

      showDisputeMessage(
        body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Não foi possível enviar a mensagem para a Lokally.',
      );
    } catch (_) {
      if (mounted) {
        showDisputeMessage(
            'Não foi possível enviar a mensagem para a Lokally.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  void scrollToBottom() {
    if (!scrollController.hasClients) {
      return;
    }

    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
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
    final StoreSellerOrderDispute? currentDispute = dispute;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F6),
      body: Column(
        children: [
          StoreSellerDisputeTopBar(
            primaryColor: primaryColor,
            orderNumber: widget.order.orderNumber,
            onBackTap: () => Get.back(),
          ),
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
                      StoreSellerDisputeSurface(
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
                                        'Disputa Lokally',
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
                            StoreSellerDisputeInfoBlock(
                              icon: Icons.support_agent_outlined,
                              title: currentDispute?.statusLabel ??
                                  'Disputa aberta',
                              value:
                                  'A tratativa acontece entre sua loja e a equipe Lokally. O cliente conversa com a Lokally em uma timeline separada.',
                            ),
                            const SizedBox(height: 10),
                            StoreSellerDisputeInfoBlock(
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
                        StoreSellerDisputeSurface(
                          child: Text(
                            'A equipe Lokally irá solicitar informações por aqui. Envie comprovantes e detalhes que ajudem na análise da disputa.',
                            style: textRegular.copyWith(
                              color: Colors.grey.shade700,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        )
                      else
                        ...messages.map(
                          (message) => StoreSellerDisputeTimelineItem(
                            message: message,
                            primaryColor: primaryColor,
                          ),
                        ),
                    ],
                  ),
          ),
          StoreServiceChatInputBar(
            primaryColor: primaryColor,
            controller: messageController,
            isSending: isSending,
            onAttachTap: pickAndSendFile,
            onSendTap: sendTextMessage,
          ),
        ],
      ),
    );
  }
}

class StoreSellerDisputeTopBar extends StatelessWidget {
  final Color primaryColor;
  final String orderNumber;
  final VoidCallback onBackTap;

  const StoreSellerDisputeTopBar({
    super.key,
    required this.primaryColor,
    required this.orderNumber,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Disputa Lokally',
                  style: textBold.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  orderNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11.8,
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

class StoreSellerDisputeSurface extends StatelessWidget {
  final Widget child;

  const StoreSellerDisputeSurface({
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

class StoreSellerDisputeInfoBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const StoreSellerDisputeInfoBlock({
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

class StoreSellerDisputeTimelineItem extends StatelessWidget {
  final StoreSellerOrderDisputeMessage message;
  final Color primaryColor;

  const StoreSellerDisputeTimelineItem({
    super.key,
    required this.message,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMine = message.senderType == 'seller';
    final bool isLokally = message.senderType == 'lokally';
    final Color bubbleColor = isMine
        ? primaryColor
        : isLokally
            ? Colors.white
            : Colors.grey.shade100;
    final Color textColor = isMine ? Colors.white : Colors.black87;
    final String senderLabel = isMine
        ? 'Sua loja'
        : isLokally
            ? 'Equipe Lokally'
            : 'Mensagem';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
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
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.70)
                      : Colors.grey.shade500,
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

class StoreSellerOrderDispute {
  final String id;
  final String storeOrderId;
  final String status;
  final String statusLabel;
  final String openedAt;
  final String deadlineAt;
  final String resolvedAt;
  final String resolutionTarget;
  final String resolutionMessage;

  StoreSellerOrderDispute({
    required this.id,
    required this.storeOrderId,
    required this.status,
    required this.statusLabel,
    required this.openedAt,
    required this.deadlineAt,
    required this.resolvedAt,
    required this.resolutionTarget,
    required this.resolutionMessage,
  });

  factory StoreSellerOrderDispute.fromMap(Map<String, dynamic> map) {
    return StoreSellerOrderDispute(
      id: '${map['id'] ?? ''}',
      storeOrderId: '${map['store_order_id'] ?? ''}',
      status: '${map['status'] ?? ''}',
      statusLabel: '${map['status_label'] ?? ''}',
      openedAt: '${map['opened_at'] ?? ''}',
      deadlineAt: '${map['deadline_at'] ?? ''}',
      resolvedAt: '${map['resolved_at'] ?? ''}',
      resolutionTarget: '${map['resolution_target'] ?? ''}',
      resolutionMessage: '${map['resolution_message'] ?? ''}',
    );
  }
}

class StoreSellerOrderDisputeMessage {
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

  StoreSellerOrderDisputeMessage({
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

  factory StoreSellerOrderDisputeMessage.fromMap(Map<String, dynamic> map) {
    return StoreSellerOrderDisputeMessage(
      id: '${map['id'] ?? ''}',
      senderType: '${map['sender_type'] ?? ''}',
      channel: '${map['channel'] ?? ''}',
      messageType: '${map['message_type'] ?? ''}',
      message: '${map['message'] ?? ''}',
      fileUrl: '${map['file_url'] ?? ''}',
      fileOriginalName: '${map['file_original_name'] ?? ''}',
      fileMimeType: '${map['file_mime_type'] ?? ''}',
      fileSize: StoreSellerOrderParser.parseNullableInt(map['file_size']),
      createdAt: '${map['created_at'] ?? ''}',
    );
  }
}

class StoreServiceChatScreen extends StatefulWidget {
  final StoreSellerOrderItem order;
  final bool openAttachmentPickerOnStart;

  const StoreServiceChatScreen({
    super.key,
    required this.order,
    this.openAttachmentPickerOnStart = false,
  });

  @override
  State<StoreServiceChatScreen> createState() => _StoreServiceChatScreenState();
}

class _StoreServiceChatScreenState extends State<StoreServiceChatScreen> {
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
  bool hasAskedAttachmentOnStart = false;

  StoreServiceChatThreadData? thread;
  StoreServiceChatSafetyNotice safetyNotice =
      StoreServiceChatSafetyNotice.empty();
  List<StoreServiceChatMessageData> messages = <StoreServiceChatMessageData>[];

  String get chatBaseUri {
    return '/api/customer/store/service-chat/order/${widget.order.id}';
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadChat();

      if (widget.openAttachmentPickerOnStart && mounted) {
        hasAskedAttachmentOnStart = true;
        await pickAndSendFile();
      }
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

    try {
      final Response response =
          await Get.find<ApiClient>().getData(chatBaseUri);

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if (response.statusCode != 200 ||
          body is! Map ||
          body['status'] != true) {
        showChatMessage('Não foi possível carregar o Chat Lokally.');
        return;
      }

      final dynamic dataValue = body['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic threadValue = data['thread'];
      final Map<String, dynamic> threadMap = threadValue is Map
          ? Map<String, dynamic>.from(threadValue)
          : <String, dynamic>{};

      final dynamic safetyValue = data['safety_notice'];
      final Map<String, dynamic> safetyMap = safetyValue is Map
          ? Map<String, dynamic>.from(safetyValue)
          : <String, dynamic>{};

      final dynamic messagesValue = data['messages'];
      final List<dynamic> messageList =
          messagesValue is List ? messagesValue : <dynamic>[];

      setState(() {
        thread = StoreServiceChatThreadData.fromMap(threadMap);
        safetyNotice = StoreServiceChatSafetyNotice.fromMap(safetyMap);
        messages = messageList
            .whereType<Map>()
            .map((item) => StoreServiceChatMessageData.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToBottom();
      });

      // O aviso de segurança do cliente não é exibido no painel do vendedor.
      // No painel do vendedor, o chat abre direto após pagamento aprovado.
    } catch (_) {
      if (mounted) {
        showChatMessage('Não foi possível carregar o Chat Lokally.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> showSafetyNoticeModal() async {
    final Color primaryColor = Theme.of(context).primaryColor;

    final bool? accepted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        safetyNotice.title.isEmpty
                            ? 'Chat Lokally'
                            : safetyNotice.title,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  safetyNotice.message.isEmpty
                      ? 'Use o Chat Lokally para combinar detalhes do serviço e manter o histórico do atendimento dentro da plataforma.'
                      : safetyNotice.message,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 12.8,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                ...safetyNotice.details.map(
                  (detail) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            detail,
                            style: textRegular.copyWith(
                              color: Colors.grey.shade700,
                              fontSize: 12.2,
                              height: 1.25,
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
                    onTap: () => Navigator.of(context).pop(true),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 48,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'Entendi e quero usar o Chat Lokally',
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
          ),
        );
      },
    );

    if (accepted == true) {
      await acceptSafetyNotice();
    }
  }

  Future<void> acceptSafetyNotice() async {
    try {
      final Response response = await Get.find<ApiClient>().postData(
        '$chatBaseUri/safety-notice',
        <String, dynamic>{},
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

        final dynamic threadValue = data['thread'];

        if (threadValue is Map) {
          setState(() {
            thread = StoreServiceChatThreadData.fromMap(
              Map<String, dynamic>.from(threadValue),
            );
          });
        }
      }
    } catch (_) {
      if (mounted) {
        showChatMessage(
            'Não foi possível confirmar as orientações do Chat Lokally.');
      }
    }
  }

  Future<void> sendTextMessage() async {
    final String message = messageController.text.trim();

    if (message.isEmpty || isSending) {
      return;
    }

    messageController.clear();
    await sendMessage(message: message);
  }

  String get allowedFileExtensionsText {
    return allowedFileExtensions
        .map((extension) => extension.toUpperCase())
        .join(', ');
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
                  'Use esta opção para enviar arquivos necessários para executar o serviço, como marcas, briefings, imagens, documentos e arquivos de criação.',
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
    if (isSending) {
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      Response response;

      if (file != null) {
        response = await Get.find<ApiClient>().postMultipartData(
          '$chatBaseUri/message',
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
          '$chatBaseUri/message',
          <String, dynamic>{'message': message},
        );
      }

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;
      String feedback = 'Não foi possível enviar a mensagem.';

      if (body is Map && body['message'] != null) {
        feedback = body['message'].toString();
      }

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body is Map &&
          body['status'] == true) {
        await loadChat();
        return;
      }

      showChatMessage(feedback);
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

  void scrollToBottom() {
    if (!scrollController.hasClients) {
      return;
    }

    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
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

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F6),
      body: Column(
        children: [
          StoreServiceChatTopBar(
            primaryColor: primaryColor,
            orderNumber: widget.order.orderNumber,
            serviceLabel: widget.order.serviceDeliveryLabel,
            onBackTap: () => Get.back(),
          ),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: primaryColor,
                      strokeWidth: 2.4,
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    itemCount: messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: StoreServiceChatOrderSummary(
                            order: widget.order,
                            primaryColor: primaryColor,
                          ),
                        );
                      }

                      final StoreServiceChatMessageData message =
                          messages[index - 1];

                      return StoreServiceChatBubble(
                        message: message,
                        isMine: message.senderType == 'seller',
                        primaryColor: primaryColor,
                      );
                    },
                  ),
          ),
          StoreServiceChatInputBar(
            primaryColor: primaryColor,
            controller: messageController,
            isSending: isSending,
            onAttachTap: pickAndSendFile,
            onSendTap: sendTextMessage,
          ),
        ],
      ),
    );
  }
}

class StoreServiceChatTopBar extends StatelessWidget {
  final Color primaryColor;
  final String orderNumber;
  final String serviceLabel;
  final VoidCallback onBackTap;

  const StoreServiceChatTopBar({
    super.key,
    required this.primaryColor,
    required this.orderNumber,
    required this.serviceLabel,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat Lokally',
                  style: textBold.copyWith(
                    color: Colors.white,
                    fontSize: 18.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  serviceLabel.isEmpty
                      ? orderNumber
                      : '$orderNumber • $serviceLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11.6,
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

class StoreServiceChatGuaranteeBanner extends StatelessWidget {
  final Color primaryColor;
  final String message;

  const StoreServiceChatGuaranteeBanner({
    super.key,
    required this.primaryColor,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
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
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message.isEmpty
                    ? 'Chat Lokally: mantenha as informações do serviço dentro deste atendimento.'
                    : message,
                style: textMedium.copyWith(
                  color: primaryColor,
                  fontSize: 11.7,
                  height: 1.28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreServiceChatOrderSummary extends StatelessWidget {
  final StoreSellerOrderItem order;
  final Color primaryColor;

  const StoreServiceChatOrderSummary({
    super.key,
    required this.order,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.orderNumber,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            order.serviceDeliveryDescription.isEmpty
                ? 'Serviço contratado pelo Marketplace Lokally.'
                : order.serviceDeliveryDescription,
            style: textRegular.copyWith(
              color: Colors.grey.shade700,
              fontSize: 12.2,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          ...order.items.take(2).map(
                (item) => Text(
                  '${item.quantity}x ${item.productName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textMedium.copyWith(
                    color: Colors.black87,
                    fontSize: 12.2,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class StoreServiceChatBubble extends StatelessWidget {
  final StoreServiceChatMessageData message;
  final bool isMine;
  final Color primaryColor;

  const StoreServiceChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color bubbleColor = isMine ? primaryColor : Colors.white;
    final Color textColor = isMine ? Colors.white : Colors.black87;
    final Color helperColor =
        isMine ? Colors.white.withValues(alpha: 0.74) : Colors.grey.shade600;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
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
            if (message.message.isNotEmpty) ...[
              Text(
                message.message,
                style: textRegular.copyWith(
                  color: textColor,
                  fontSize: 12.7,
                  height: 1.32,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (message.hasFile)
              StoreServiceChatFilePill(
                message: message,
                isMine: isMine,
                primaryColor: primaryColor,
              ),
            Text(
              '${message.senderLabel} • ${message.createdAt}',
              style: textRegular.copyWith(
                color: helperColor,
                fontSize: 10.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreServiceChatFilePill extends StatelessWidget {
  final StoreServiceChatMessageData message;
  final bool isMine;
  final Color primaryColor;

  const StoreServiceChatFilePill({
    super.key,
    required this.message,
    required this.isMine,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return StoreServiceChatFilePreview(
      fileName: message.fileDisplayName,
      fileUrl: message.fileUrl,
      isMine: isMine,
      primaryColor: primaryColor,
    );
  }
}

class StoreServiceChatInputBar extends StatelessWidget {
  final Color primaryColor;
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onAttachTap;
  final VoidCallback onSendTap;

  const StoreServiceChatInputBar({
    super.key,
    required this.primaryColor,
    required this.controller,
    required this.isSending,
    required this.onAttachTap,
    required this.onSendTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -4),
            blurRadius: 16,
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: isSending ? null : onAttachTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.attach_file_rounded,
                color: primaryColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Escreva uma mensagem...',
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isSending ? null : onSendTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSending ? Colors.grey.shade400 : primaryColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreServiceChatThreadData {
  final String id;
  final String orderId;
  final bool safetyNoticeAccepted;

  StoreServiceChatThreadData({
    required this.id,
    required this.orderId,
    required this.safetyNoticeAccepted,
  });

  factory StoreServiceChatThreadData.fromMap(Map<String, dynamic> map) {
    return StoreServiceChatThreadData(
      id: '${map['id'] ?? ''}',
      orderId: '${map['store_order_id'] ?? ''}',
      safetyNoticeAccepted: StoreSellerOrderParser.parseBool(
        map['safety_notice_accepted'],
      ),
    );
  }
}

class StoreServiceChatSafetyNotice {
  final String title;
  final String message;
  final List<String> details;

  StoreServiceChatSafetyNotice({
    required this.title,
    required this.message,
    required this.details,
  });

  factory StoreServiceChatSafetyNotice.empty() {
    return StoreServiceChatSafetyNotice(
      title: 'Chat Lokally',
      message:
          'Use o Chat Lokally para combinar detalhes do serviço e manter o histórico do atendimento dentro da plataforma.',
      details: <String>[],
    );
  }

  factory StoreServiceChatSafetyNotice.fromMap(Map<String, dynamic> map) {
    final dynamic detailsValue = map['details'];
    final List<dynamic> detailsList =
        detailsValue is List ? detailsValue : <dynamic>[];

    return StoreServiceChatSafetyNotice(
      title: '${map['title'] ?? ''}',
      message: '${map['message'] ?? ''}',
      details: detailsList.map((item) => '$item').toList(),
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

class StoreServiceChatMessageData {
  final String id;
  final String senderType;
  final String messageType;
  final String message;
  final String fileUrl;
  final String fileOriginalName;
  final String fileMimeType;
  final int? fileSize;
  final String createdAt;

  StoreServiceChatMessageData({
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

  String get senderLabel {
    if (senderType == 'seller') {
      return 'Você';
    }

    if (senderType == 'customer') {
      return 'Cliente';
    }

    return 'Lokally';
  }

  factory StoreServiceChatMessageData.fromMap(Map<String, dynamic> map) {
    return StoreServiceChatMessageData(
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

  static bool parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final String normalized = '$value'.trim().toLowerCase();

    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'sim' ||
        normalized == 'yes';
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

  static int? parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toInt();
    }

    final String normalized = '$value'.trim();

    if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
      return null;
    }

    return int.tryParse(normalized);
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
