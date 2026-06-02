import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/store/screens/lokally_meeting_screen.dart';
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
  static const String storeSellerServiceRequestsUri =
      '/api/customer/store/seller/service-requests';

  bool isLoading = false;
  bool isLoadingServiceRequests = false;
  String? startingServiceRequestChannelId;
  String selectedFilter = 'all';

  List<StoreSellerOrderItem> orders = <StoreSellerOrderItem>[];
  List<StoreSellerServiceRequestItem> serviceRequests =
      <StoreSellerServiceRequestItem>[];
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
      refreshOrdersAndRequests();
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

  Future<void> refreshOrdersAndRequests() async {
    await Future.wait(<Future<void>>[
      loadServiceRequests(),
      loadOrders(),
    ]);
  }

  Future<void> loadServiceRequests() async {
    if (isLoadingServiceRequests) {
      return;
    }

    setState(() {
      isLoadingServiceRequests = true;
    });

    final Response response = await Get.find<ApiClient>().getData(
      '$storeSellerServiceRequestsUri?limit=30&offset=0',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      isLoadingServiceRequests = false;
    });

    final dynamic body = response.body;

    if (response.statusCode != 200 || body is! Map || body['status'] != true) {
      showStoreMessage(
          'Não foi possível carregar as solicitações de serviços.');
      return;
    }

    final dynamic dataValue = body['data'];
    final Map<String, dynamic> data = dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : <String, dynamic>{};

    final dynamic requestsValue = data['requests'];
    final List<dynamic> requestList =
        requestsValue is List ? requestsValue : <dynamic>[];

    setState(() {
      serviceRequests = requestList
          .whereType<Map>()
          .map(
            (item) => StoreSellerServiceRequestItem.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.channelId.isNotEmpty)
          .toList();
    });

    loadServiceRequestProgress();
  }

  Future<void> loadServiceRequestProgress() async {
    final List<StoreSellerServiceRequestItem> currentRequests =
        List<StoreSellerServiceRequestItem>.from(serviceRequests);

    if (currentRequests.isEmpty) {
      return;
    }

    final List<StoreSellerServiceRequestItem> updatedRequests =
        <StoreSellerServiceRequestItem>[];

    for (final StoreSellerServiceRequestItem request in currentRequests) {
      if (request.orderId.isEmpty) {
        updatedRequests.add(request);
        continue;
      }

      try {
        final Response response = await Get.find<ApiClient>().getData(
          '/api/customer/store/service-chat/order/${request.orderId}',
        );

        final dynamic body = response.body;

        if (response.statusCode == 200 &&
            body is Map &&
            body['status'] == true) {
          final dynamic dataValue = body['data'];
          final Map<String, dynamic> data = dataValue is Map
              ? Map<String, dynamic>.from(dataValue)
              : <String, dynamic>{};
          final dynamic threadValue = data['thread'];

          if (threadValue is Map) {
            final Map<String, dynamic> threadMap =
                Map<String, dynamic>.from(threadValue);
            updatedRequests.add(
              request.copyWith(
                serviceProgress: StoreSellerServiceProgressData.fromMap(
                  threadMap['service_progress'] is Map
                      ? Map<String, dynamic>.from(threadMap['service_progress'])
                      : <String, dynamic>{},
                ),
              ),
            );
            continue;
          }
        }
      } catch (_) {
        // Mantém o item original caso o progresso ainda não carregue.
      }

      updatedRequests.add(request);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      serviceRequests = updatedRequests;
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

  Future<void> startServiceRequest(
    StoreSellerServiceRequestItem request,
  ) async {
    if (startingServiceRequestChannelId != null) {
      return;
    }

    setState(() {
      startingServiceRequestChannelId = request.channelId;
    });

    final Response response = await Get.find<ApiClient>().postData(
      '$storeSellerServiceRequestsUri/${request.channelId}/start',
      <String, dynamic>{},
    );

    if (!mounted) {
      return;
    }

    setState(() {
      startingServiceRequestChannelId = null;
    });

    final dynamic body = response.body;

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        body is Map &&
        body['status'] == true) {
      StoreSellerServiceRequestItem requestForChat = request;

      final dynamic dataValue = body['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      if (data.isNotEmpty) {
        requestForChat = request.copyWith(
          orderId: '${data['order_id'] ?? request.orderId}',
          orderNumber: '${data['order_number'] ?? request.orderNumber}',
          channelId:
              '${data['thread_id'] ?? data['channel_id'] ?? request.channelId}',
        );
      }

      await Get.to(
        () => StoreServiceChatScreen(
          order: requestForChat.toServiceOrderItem(),
        ),
      );

      if (mounted) {
        await refreshOrdersAndRequests();
      }

      return;
    }

    showStoreMessage(
      body is Map && body['message'] != null
          ? body['message'].toString()
          : 'Não foi possível iniciar esta solicitação.',
    );
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
      backgroundColor: Colors.white,
      body: Column(
        children: [
          StoreSellerOrderListTopBar(
            primaryColor: primaryColor,
            onBackTap: () => Get.back(),
          ),
          Expanded(
            child: RefreshIndicator(
              color: primaryColor,
              onRefresh: () => refreshOrdersAndRequests(),
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
                  if (isLoadingServiceRequests ||
                      serviceRequests.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    StoreSellerServiceRequestsSection(
                      primaryColor: primaryColor,
                      isLoading: isLoadingServiceRequests,
                      startingChannelId: startingServiceRequestChannelId,
                      requests: serviceRequests,
                      onStartRequest: startServiceRequest,
                    ),
                  ],
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

class StoreSellerServiceRequestsSection extends StatelessWidget {
  final Color primaryColor;
  final bool isLoading;
  final String? startingChannelId;
  final List<StoreSellerServiceRequestItem> requests;
  final ValueChanged<StoreSellerServiceRequestItem> onStartRequest;

  const StoreSellerServiceRequestsSection({
    super.key,
    required this.primaryColor,
    required this.isLoading,
    required this.startingChannelId,
    required this.requests,
    required this.onStartRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.handshake_outlined,
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
                      'Solicitações de serviços',
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Clientes interessados nos seus anúncios.',
                      style: textRegular.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11.8,
                      ),
                    ),
                  ],
                ),
              ),
              if (requests.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${requests.length}',
                    style: textBold.copyWith(
                      color: primaryColor,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          if (isLoading)
            SizedBox(
              height: 74,
              child: Center(
                child: CircularProgressIndicator(
                  color: primaryColor,
                  strokeWidth: 2.3,
                ),
              ),
            )
          else
            ...requests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: StoreSellerServiceRequestTile(
                  request: request,
                  primaryColor: primaryColor,
                  isStarting: startingChannelId == request.channelId,
                  onStartTap: () => onStartRequest(request),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StoreSellerServiceRequestTile extends StatelessWidget {
  final StoreSellerServiceRequestItem request;
  final Color primaryColor;
  final bool isStarting;
  final VoidCallback onStartTap;

  const StoreSellerServiceRequestTile({
    super.key,
    required this.request,
    required this.primaryColor,
    required this.isStarting,
    required this.onStartTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasUnread = request.unreadCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: hasUnread
                ? primaryColor.withValues(alpha: 0.24)
                : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.serviceTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 13.8,
                    height: 1.18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                request.servicePriceLabel,
                style: textBold.copyWith(
                  color: primaryColor,
                  fontSize: 13.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                color: Colors.grey.shade600,
                size: 16,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  request.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textMedium.copyWith(
                    color: Colors.grey.shade800,
                    fontSize: 12,
                  ),
                ),
              ),
              if (request.statusLabel.isNotEmpty)
                Text(
                  request.statusLabel,
                  style: textBold.copyWith(
                    color: hasUnread ? primaryColor : Colors.grey.shade600,
                    fontSize: 10.8,
                  ),
                ),
            ],
          ),
          if (request.initialMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.initialMessage,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textRegular.copyWith(
                color: Colors.grey.shade700,
                fontSize: 11.6,
                height: 1.28,
              ),
            ),
          ],
          const SizedBox(height: 11),
          StoreServiceProgressMiniBar(
            progress: request.serviceProgress,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: Text(
                  request.requestedAt.isEmpty
                      ? 'Solicitação recebida'
                      : request.requestedAt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade500,
                    fontSize: 10.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: primaryColor,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  onTap: isStarting ? null : onStartTap,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isStarting)
                          SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        else
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          'Falar com o cliente',
                          style: textBold.copyWith(
                            color: Colors.white,
                            fontSize: 11.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
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
      decoration: const BoxDecoration(
        color: Colors.transparent,
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
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Repasse',
                    style: textRegular.copyWith(
                      color: Colors.grey.shade500,
                      fontSize: 10.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    StoreSellerOrderCurrency.format(order.payoutAmount),
                    style: textBold.copyWith(
                      color: primaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
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
          StoreSellerOrderFinancialSummaryBlock(
            order: order,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 9),
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
            if (canMarkReadyForPickup) ...[
              StoreSellerOrderActionButton(
                primaryColor: primaryColor,
                label: 'Liberar retirada',
                icon: Icons.inventory_2_outlined,
                onTap: onReadyForPickupTap,
              ),
              if (canRequestLokallyShipping ||
                  canCompleteOrder ||
                  canUseServiceFlow)
                const SizedBox(height: 8),
            ],
            if (canRequestLokallyShipping) ...[
              StoreSellerOrderActionButton(
                primaryColor: primaryColor,
                label: lokallyShippingButtonLabel,
                icon: Icons.local_shipping_outlined,
                onTap: onRequestLokallyShippingTap,
              ),
              if (canCompleteOrder || canUseServiceFlow)
                const SizedBox(height: 8),
            ],
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

class StoreSellerOrderFinancialSummaryBlock extends StatelessWidget {
  final StoreSellerOrderItem order;
  final Color primaryColor;

  const StoreSellerOrderFinancialSummaryBlock({
    super.key,
    required this.order,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: primaryColor.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StoreSellerOrderFinancialInfo(
                  title: 'Produto vendido',
                  value: StoreSellerOrderCurrency.format(order.productsAmount),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: StoreSellerOrderFinancialInfo(
                  title: 'Taxa Lokally',
                  value:
                      StoreSellerOrderCurrency.format(order.platformFeeAmount),
                  valueColor: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: StoreSellerOrderFinancialInfo(
                  title: 'Repasse líquido',
                  value: StoreSellerOrderCurrency.format(order.payoutAmount),
                  valueColor: primaryColor,
                  strong: true,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: StoreSellerOrderFinancialInfo(
                  title: 'Total cliente',
                  value: StoreSellerOrderCurrency.format(order.total),
                ),
              ),
            ],
          ),
          if (order.shippingNetAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.grey.shade600,
                  size: 15,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Frete pago pelo cliente: ${StoreSellerOrderCurrency.format(order.shippingNetAmount)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(
                      color: Colors.grey.shade700,
                      fontSize: 10.8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class StoreSellerOrderFinancialInfo extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;
  final bool strong;

  const StoreSellerOrderFinancialInfo({
    super.key,
    required this.title,
    required this.value,
    this.valueColor,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textRegular.copyWith(
            color: Colors.grey.shade600,
            fontSize: 10.7,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textBold.copyWith(
            color: valueColor ?? Colors.black87,
            fontSize: strong ? 12.8 : 12.2,
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
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
          const SizedBox(height: 8),
          StoreSellerOrderMiniSummaryRow(
            label: 'Repasse líquido',
            value: StoreSellerOrderCurrency.format(order.payoutAmount),
            valueColor: Theme.of(context).primaryColor,
            strong: true,
          ),
          const SizedBox(height: 4),
          StoreSellerOrderMiniSummaryRow(
            label: 'Taxa Lokally',
            value: StoreSellerOrderCurrency.format(order.platformFeeAmount),
            valueColor: Colors.orange.shade800,
          ),
          const SizedBox(height: 4),
          StoreSellerOrderMiniSummaryRow(
            label: 'Total cliente',
            value: StoreSellerOrderCurrency.format(order.total),
          ),
        ],
      ),
    );
  }
}

class StoreSellerOrderMiniSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool strong;

  const StoreSellerOrderMiniSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 11.2,
            ),
          ),
        ),
        Text(
          value,
          style: textBold.copyWith(
            color: valueColor ?? Colors.black87,
            fontSize: strong ? 12.8 : 12,
          ),
        ),
      ],
    );
  }
}

class StoreSellerServiceProgressStepData {
  final String key;
  final String label;
  final String actionGroup;
  final bool completed;

  const StoreSellerServiceProgressStepData({
    required this.key,
    required this.label,
    required this.actionGroup,
    required this.completed,
  });

  factory StoreSellerServiceProgressStepData.fromMap(Map<String, dynamic> map) {
    return StoreSellerServiceProgressStepData(
      key: '${map['key'] ?? ''}',
      label: '${map['label'] ?? ''}',
      actionGroup: '${map['action_group'] ?? ''}',
      completed: StoreSellerOrderParser.parseBool(map['completed']),
    );
  }
}

class StoreSellerServiceProgressData {
  final List<String> steps;
  final List<StoreSellerServiceProgressStepData> definitions;
  final int completedActions;
  final int totalActions;
  final int percent;
  final bool completed;
  final String statusLabel;

  const StoreSellerServiceProgressData({
    required this.steps,
    required this.definitions,
    required this.completedActions,
    required this.totalActions,
    required this.percent,
    required this.completed,
    required this.statusLabel,
  });

  static const List<StoreSellerServiceProgressStepData> defaultDefinitions = [
    StoreSellerServiceProgressStepData(
        key: 'atendimento_iniciado',
        label: 'Atendimento iniciado',
        actionGroup: 'atendimento_iniciado',
        completed: false),
    StoreSellerServiceProgressStepData(
        key: 'cliente_efetuou_pagamento',
        label: 'Cliente efetuou pagamento',
        actionGroup: 'cliente_efetuou_pagamento',
        completed: false),
    StoreSellerServiceProgressStepData(
        key: 'informacoes_coletadas',
        label: 'Informações coletadas',
        actionGroup: 'informacoes_coletadas',
        completed: false),
    StoreSellerServiceProgressStepData(
        key: 'enviado_para_aprovacao',
        label: 'Enviado para aprovação',
        actionGroup: 'enviado_para_aprovacao',
        completed: false),
    StoreSellerServiceProgressStepData(
        key: 'reajuste_1',
        label: 'Reajuste 1',
        actionGroup: 'reajustes',
        completed: false),
    StoreSellerServiceProgressStepData(
        key: 'reajuste_2',
        label: 'Reajuste 2',
        actionGroup: 'reajustes',
        completed: false),
    StoreSellerServiceProgressStepData(
        key: 'reajuste_3',
        label: 'Reajuste 3',
        actionGroup: 'reajustes',
        completed: false),
    StoreSellerServiceProgressStepData(
        key: 'cliente_aprovou',
        label: 'Cliente aprovou',
        actionGroup: 'cliente_aprovou',
        completed: false),
    StoreSellerServiceProgressStepData(
        key: 'entrega_dos_arquivos',
        label: 'Entrega dos arquivos',
        actionGroup: 'entrega_dos_arquivos',
        completed: false),
    StoreSellerServiceProgressStepData(
        key: 'servico_concluido',
        label: 'Serviço concluído',
        actionGroup: 'servico_concluido',
        completed: false),
  ];

  factory StoreSellerServiceProgressData.empty() {
    return const StoreSellerServiceProgressData(
      steps: <String>[],
      definitions: defaultDefinitions,
      completedActions: 0,
      totalActions: 8,
      percent: 0,
      completed: false,
      statusLabel: 'Aguardando início',
    );
  }

  factory StoreSellerServiceProgressData.fromMap(Map<String, dynamic> map) {
    final dynamic stepsValue = map['steps'];
    final List<String> parsedSteps = stepsValue is List
        ? stepsValue
            .map((item) => '$item')
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];

    final dynamic definitionsValue = map['definitions'];
    final List<StoreSellerServiceProgressStepData> parsedDefinitions =
        definitionsValue is List
            ? definitionsValue
                .whereType<Map>()
                .map((item) => StoreSellerServiceProgressStepData.fromMap(
                    Map<String, dynamic>.from(item)))
                .toList()
            : defaultDefinitions;

    return StoreSellerServiceProgressData(
      steps: parsedSteps,
      definitions: parsedDefinitions,
      completedActions:
          StoreSellerOrderParser.parseInt(map['completed_actions']),
      totalActions: StoreSellerOrderParser.parseInt(map['total_actions']) == 0
          ? 8
          : StoreSellerOrderParser.parseInt(map['total_actions']),
      percent: StoreSellerOrderParser.parseInt(map['percent']),
      completed: StoreSellerOrderParser.parseBool(map['completed']),
      statusLabel: '${map['status_label'] ?? 'Aguardando início'}',
    );
  }
}

class StoreServiceProgressMiniBar extends StatelessWidget {
  final StoreSellerServiceProgressData progress;
  final Color primaryColor;

  const StoreServiceProgressMiniBar({
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
              style: textBold.copyWith(
                color: primaryColor,
                fontSize: 11.8,
              ),
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
                style: textBold.copyWith(
                  color: primaryColor,
                  fontSize: 11.6,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class StoreSellerServiceRequestItem {
  final String id;
  final String channelId;
  final String threadId;
  final String orderId;
  final String orderNumber;
  final String serviceId;
  final String serviceTitle;
  final double servicePrice;
  final String servicePriceLabel;
  final String categoryName;
  final String customerId;
  final String customerName;
  final String status;
  final String statusLabel;
  final String paymentStatus;
  final String requestedAt;
  final String updatedAt;
  final int unreadCount;
  final String initialMessage;
  final String lastMessage;
  final String lastMessageAt;
  final String actionLabel;
  final StoreSellerServiceProgressData serviceProgress;

  StoreSellerServiceRequestItem({
    required this.id,
    required this.channelId,
    required this.threadId,
    required this.orderId,
    required this.orderNumber,
    required this.serviceId,
    required this.serviceTitle,
    required this.servicePrice,
    required this.servicePriceLabel,
    required this.categoryName,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.statusLabel,
    required this.paymentStatus,
    required this.requestedAt,
    required this.updatedAt,
    required this.unreadCount,
    required this.initialMessage,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.actionLabel,
    required this.serviceProgress,
  });

  factory StoreSellerServiceRequestItem.fromMap(Map<String, dynamic> map) {
    final String threadId =
        '${map['thread_id'] ?? map['channel_id'] ?? map['id'] ?? ''}';
    final String channelId = '${map['channel_id'] ?? threadId}';
    final double price = StoreSellerOrderParser.parseDouble(
      map['service_price'],
    );
    final String priceLabel = '${map['service_price_label'] ?? ''}'.trim();
    final String orderNumber = '${map['order_number'] ?? ''}'.trim();

    return StoreSellerServiceRequestItem(
      id: '${map['id'] ?? threadId}',
      channelId: channelId,
      threadId: threadId,
      orderId: '${map['order_id'] ?? ''}',
      orderNumber: orderNumber.isEmpty ? 'Solicitação de serviço' : orderNumber,
      serviceId: '${map['service_id'] ?? ''}',
      serviceTitle: '${map['service_title'] ?? 'Serviço solicitado'}',
      servicePrice: price,
      servicePriceLabel: priceLabel.isNotEmpty
          ? priceLabel
          : StoreSellerOrderCurrency.format(price),
      categoryName: '${map['category_name'] ?? ''}',
      customerId: '${map['customer_id'] ?? ''}',
      customerName: '${map['customer_name'] ?? 'Cliente Lokally'}',
      status: '${map['status'] ?? ''}',
      statusLabel: '${map['status_label'] ?? ''}',
      paymentStatus: '${map['payment_status'] ?? 'pending'}',
      requestedAt: '${map['requested_at'] ?? ''}',
      updatedAt: '${map['updated_at'] ?? ''}',
      unreadCount: StoreSellerOrderParser.parseInt(map['unread_count']),
      initialMessage: '${map['initial_message'] ?? ''}',
      lastMessage: '${map['last_message'] ?? ''}',
      lastMessageAt: '${map['last_message_at'] ?? ''}',
      actionLabel: 'Falar com o cliente',
      serviceProgress: StoreSellerServiceProgressData.fromMap(
        map['service_progress'] is Map
            ? Map<String, dynamic>.from(map['service_progress'])
            : <String, dynamic>{},
      ),
    );
  }

  StoreSellerServiceRequestItem copyWith({
    String? id,
    String? channelId,
    String? threadId,
    String? orderId,
    String? orderNumber,
    String? serviceId,
    String? serviceTitle,
    double? servicePrice,
    String? servicePriceLabel,
    String? categoryName,
    String? customerId,
    String? customerName,
    String? status,
    String? statusLabel,
    String? paymentStatus,
    String? requestedAt,
    String? updatedAt,
    int? unreadCount,
    String? initialMessage,
    String? lastMessage,
    String? lastMessageAt,
    String? actionLabel,
    StoreSellerServiceProgressData? serviceProgress,
  }) {
    return StoreSellerServiceRequestItem(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      threadId: threadId ?? this.threadId,
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      serviceId: serviceId ?? this.serviceId,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      servicePrice: servicePrice ?? this.servicePrice,
      servicePriceLabel: servicePriceLabel ?? this.servicePriceLabel,
      categoryName: categoryName ?? this.categoryName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      requestedAt: requestedAt ?? this.requestedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      initialMessage: initialMessage ?? this.initialMessage,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      actionLabel: actionLabel ?? this.actionLabel,
      serviceProgress: serviceProgress ?? this.serviceProgress,
    );
  }

  StoreSellerOrderItem toServiceOrderItem() {
    return StoreSellerOrderItem(
      id: orderId,
      orderNumber: orderNumber,
      deliveryType: 'service',
      deliveryTypeLabel: 'Serviço digital',
      containsServiceItems: true,
      containsPhysicalItems: false,
      isServiceOrder: true,
      isMixedOrder: false,
      serviceDeliveryType: 'download',
      serviceDeliveryLabel: 'Serviço digital',
      serviceDeliveryDescription:
          'Solicitação de serviço pelo Chat seguro Lokally.',
      serviceActionLabel: 'Abrir Chat Lokally',
      serviceChatAvailable: true,
      lokallyGuaranteeMessage:
          'Mantenha a negociação, arquivos e combinados dentro do Chat Lokally.',
      releaseStatus: '',
      releaseStatusLabel: '',
      sellerCompletedAt: '',
      releaseRequestedAt: '',
      releaseAutoAuthorizeAt: '',
      payoutAuthorizedAt: '',
      payoutAuthorizedBy: '',
      disputeOpenedAt: '',
      disputeReason: '',
      disputeStatus: '',
      disputeStatusLabel: '',
      disputeResolutionTarget: '',
      disputeResolutionTargetLabel: '',
      disputeResolutionMessage: '',
      disputeResolvedAt: '',
      isDisputeResolved: false,
      canAuthorizePayout: false,
      canOpenDispute: false,
      paymentMethod: 'chat',
      paymentMethodLabel: 'A combinar pelo chat',
      paymentStatus: paymentStatus,
      paymentStatusLabel: 'Solicitação enviada',
      orderStatus: status.isEmpty ? 'service_requested' : status,
      orderStatusLabel: statusLabel.isEmpty ? 'Nova solicitação' : statusLabel,
      subtotal: servicePrice,
      shippingAmount: 0,
      shippingDiscount: 0,
      total: servicePrice,
      productsAmount: servicePrice,
      sellerReceivableAmount: servicePrice,
      platformFeeAmount: 0,
      payoutAmount: servicePrice,
      payoutStatus: '',
      customerName: customerName,
      customerPhone: '',
      deliveryAddress: '',
      deliveryLatitude: 0,
      deliveryLongitude: 0,
      pickupAddress: '',
      pickupLatitude: 0,
      pickupLongitude: 0,
      sellerName: '',
      sellerPhone: '',
      storeName: '',
      parcelRequestId: '',
      items: <StoreSellerOrderProductItem>[
        StoreSellerOrderProductItem(
          id: serviceId,
          productId: serviceId,
          productName: serviceTitle,
          productImageUrl: '',
          quantity: 1,
          unitPrice: servicePrice,
          total: servicePrice,
          productType: 'service',
          conditionType: '',
          serviceDeliveryType: 'download',
          serviceDeliveryLabel: 'Serviço digital',
          serviceDeliveryDescription:
              'Solicitação de serviço pelo Chat seguro Lokally.',
          isService: true,
        ),
      ],
      createdAt: requestedAt,
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
  final double productsAmount;
  final double sellerReceivableAmount;
  final double platformFeeAmount;
  final double payoutAmount;
  final String payoutStatus;
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
    required this.productsAmount,
    required this.sellerReceivableAmount,
    required this.platformFeeAmount,
    required this.payoutAmount,
    required this.payoutStatus,
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

  double get shippingNetAmount {
    final double value = shippingAmount - shippingDiscount;
    return value > 0 ? value : 0;
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

    final dynamic financialValue = map['financial'];
    final Map<String, dynamic> financial = financialValue is Map
        ? Map<String, dynamic>.from(financialValue)
        : <String, dynamic>{};

    final double parsedSubtotal =
        StoreSellerOrderParser.parseDouble(map['subtotal']);
    final double parsedShippingAmount =
        StoreSellerOrderParser.parseDouble(map['shipping_amount']);
    final double parsedShippingDiscount =
        StoreSellerOrderParser.parseDouble(map['shipping_discount']);
    final double parsedTotal = StoreSellerOrderParser.parseDouble(map['total']);
    final double parsedProductsAmount = StoreSellerOrderParser.parseDouble(
      financial['products_amount'] ?? map['products_amount'] ?? parsedSubtotal,
    );
    final double parsedSellerReceivableAmount =
        StoreSellerOrderParser.parseDouble(
      financial['seller_receivable_amount'] ??
          map['seller_receivable_amount'] ??
          parsedProductsAmount,
    );
    final double parsedPlatformFeeAmount = StoreSellerOrderParser.parseDouble(
      financial['platform_fee_amount'] ?? map['platform_fee_amount'],
    );
    final bool hasPayoutAmount = financial.containsKey('payout_amount') ||
        map.containsKey('payout_amount');
    final double calculatedPayoutAmount =
        parsedSellerReceivableAmount - parsedPlatformFeeAmount;
    final double parsedPayoutAmount = hasPayoutAmount
        ? StoreSellerOrderParser.parseDouble(
            financial['payout_amount'] ?? map['payout_amount'],
          )
        : calculatedPayoutAmount > 0
            ? calculatedPayoutAmount
            : 0;

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
      subtotal: parsedSubtotal,
      shippingAmount: parsedShippingAmount,
      shippingDiscount: parsedShippingDiscount,
      total: parsedTotal,
      productsAmount: parsedProductsAmount,
      sellerReceivableAmount: parsedSellerReceivableAmount,
      platformFeeAmount: parsedPlatformFeeAmount,
      payoutAmount: parsedPayoutAmount,
      payoutStatus:
          '${financial['payout_status'] ?? map['payout_status'] ?? ''}',
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
    'mp3',
    'mp4',
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
      backgroundColor: Colors.white,
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

class StoreSellerServiceRequestChatScreen extends StatefulWidget {
  final StoreSellerServiceRequestItem request;

  const StoreSellerServiceRequestChatScreen({
    super.key,
    required this.request,
  });

  @override
  State<StoreSellerServiceRequestChatScreen> createState() =>
      _StoreSellerServiceRequestChatScreenState();
}

class _StoreSellerServiceRequestChatScreenState
    extends State<StoreSellerServiceRequestChatScreen> {
  static const String conversationUri = '/api/customer/chat/conversation';
  static const String sendMessageUri =
      '/api/customer/chat/send-message-to-admin';

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool isLoading = false;
  bool isSending = false;
  List<StoreSellerServiceRequestMessageData> messages =
      <StoreSellerServiceRequestMessageData>[];

  @override
  void initState() {
    super.initState();

    messages = StoreSellerServiceRequestMessageData.initialMessages(
      widget.request,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadMessages();
    });
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> loadMessages() async {
    if (isLoading) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final String channelId = Uri.encodeComponent(widget.request.channelId);
      final Response response = await Get.find<ApiClient>().getData(
        '$conversationUri?channel_id=$channelId&limit=100&offset=0',
      );

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if (response.statusCode == 200 && body is Map) {
        final List<dynamic> messageList = extractConversationList(body);

        if (messageList.isNotEmpty) {
          setState(() {
            messages = messageList
                .whereType<Map>()
                .map(
                  (item) => StoreSellerServiceRequestMessageData.fromMap(
                    Map<String, dynamic>.from(item),
                    customerId: widget.request.customerId,
                  ),
                )
                .toList();
          });
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToBottom();
      });
    } catch (_) {
      if (mounted) {
        showChatMessage('Não foi possível atualizar a conversa agora.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<dynamic> extractConversationList(Map<dynamic, dynamic> body) {
    final dynamic contentValue = body['content'];

    if (contentValue is List) {
      return contentValue;
    }

    final dynamic dataValue = body['data'];

    if (dataValue is List) {
      return dataValue;
    }

    if (dataValue is Map) {
      final dynamic nestedData = dataValue['data'];
      final dynamic conversations = dataValue['conversations'];
      final dynamic messagesValue = dataValue['messages'];

      if (nestedData is List) {
        return nestedData;
      }

      if (conversations is List) {
        return conversations;
      }

      if (messagesValue is List) {
        return messagesValue;
      }
    }

    return <dynamic>[];
  }

  Future<void> sendMessage() async {
    final String message = messageController.text.trim();

    if (message.isEmpty || isSending) {
      return;
    }

    setState(() {
      isSending = true;
    });

    final Response response = await Get.find<ApiClient>().putData(
      sendMessageUri,
      <String, dynamic>{
        'channel_id': widget.request.channelId,
        'message': message,
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      isSending = false;
    });

    final dynamic body = response.body;

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        body is Map) {
      messageController.clear();
      await loadMessages();
      return;
    }

    showChatMessage(
      body is Map && body['message'] != null
          ? body['message'].toString()
          : 'Não foi possível enviar sua mensagem.',
    );
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
        backgroundColor: Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
          Container(
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
                  onTap: () => Get.back(),
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
                    'Chat do serviço',
                    style: textBold.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
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
                  widget.request.serviceTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 15,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cliente: ${widget.request.customerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textRegular.copyWith(
                          color: Colors.grey.shade700,
                          fontSize: 12.2,
                        ),
                      ),
                    ),
                    Text(
                      widget.request.servicePriceLabel,
                      style: textBold.copyWith(
                        color: primaryColor,
                        fontSize: 13.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading && messages.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                      color: primaryColor,
                      strokeWidth: 2.4,
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final StoreSellerServiceRequestMessageData message =
                          messages[index];

                      return StoreSellerServiceRequestMessageBubble(
                        message: message,
                        primaryColor: primaryColor,
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Responder cliente...',
                        hintStyle: textRegular.copyWith(
                          color: Colors.grey.shade500,
                          fontSize: 12.5,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
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
                    onTap: isSending ? null : sendMessage,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: isSending
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
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

class StoreSellerServiceRequestMessageBubble extends StatelessWidget {
  final StoreSellerServiceRequestMessageData message;
  final Color primaryColor;

  const StoreSellerServiceRequestMessageBubble({
    super.key,
    required this.message,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMine = !message.isFromCustomer;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: isMine ? primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 5),
            bottomRight: Radius.circular(isMine ? 5 : 18),
          ),
          border: isMine ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.senderName,
              style: textBold.copyWith(
                color: isMine ? Colors.white70 : Colors.grey.shade600,
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              message.message,
              style: textRegular.copyWith(
                color: isMine ? Colors.white : Colors.black87,
                fontSize: 12.7,
                height: 1.34,
              ),
            ),
            if (message.createdAt.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                message.createdAt,
                style: textRegular.copyWith(
                  color: isMine ? Colors.white70 : Colors.grey.shade500,
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

class StoreSellerServiceRequestMessageData {
  final String id;
  final String senderUserId;
  final String senderName;
  final String message;
  final String createdAt;
  final bool isFromCustomer;

  StoreSellerServiceRequestMessageData({
    required this.id,
    required this.senderUserId,
    required this.senderName,
    required this.message,
    required this.createdAt,
    required this.isFromCustomer,
  });

  factory StoreSellerServiceRequestMessageData.fromMap(
    Map<String, dynamic> map, {
    required String customerId,
  }) {
    final dynamic userValue = map['user'];
    final Map<String, dynamic> user = userValue is Map
        ? Map<String, dynamic>.from(userValue)
        : <String, dynamic>{};

    final String senderId = '${map['user_id'] ?? user['id'] ?? ''}';
    String senderName = '${user['full_name'] ?? ''}'.trim();

    if (senderName.isEmpty) {
      senderName =
          '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    }

    if (senderName.isEmpty) {
      senderName = senderId == customerId ? 'Cliente' : 'Você';
    }

    return StoreSellerServiceRequestMessageData(
      id: '${map['id'] ?? ''}',
      senderUserId: senderId,
      senderName: senderName,
      message: '${map['message'] ?? ''}',
      createdAt: '${map['created_at'] ?? ''}',
      isFromCustomer: senderId == customerId,
    );
  }

  static List<StoreSellerServiceRequestMessageData> initialMessages(
    StoreSellerServiceRequestItem request,
  ) {
    if (request.initialMessage.trim().isEmpty) {
      return <StoreSellerServiceRequestMessageData>[];
    }

    return <StoreSellerServiceRequestMessageData>[
      StoreSellerServiceRequestMessageData(
        id: 'initial_${request.channelId}',
        senderUserId: request.customerId,
        senderName: request.customerName,
        message: request.initialMessage,
        createdAt: request.requestedAt,
        isFromCustomer: true,
      ),
    ];
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
    'mp3',
    'mp4',
  ];

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool isLoading = false;
  bool isSending = false;
  bool isUpdatingProgress = false;
  bool isSchedulingMeeting = false;
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

      final List<StoreServiceChatMessageData> parsedMessages = messageList
          .whereType<Map>()
          .map((item) => StoreServiceChatMessageData.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList();

      setState(() {
        thread = StoreServiceChatThreadData.fromMap(threadMap);
        safetyNotice = StoreServiceChatSafetyNotice.fromMap(safetyMap);
        messages = normalizeMeetingMessagesForSeller(parsedMessages);
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

  List<StoreServiceChatMessageData> normalizeMeetingMessagesForSeller(
    List<StoreServiceChatMessageData> rawMessages,
  ) {
    final Set<String> renderedMeetingKeys = <String>{};
    final List<StoreServiceChatMessageData> normalizedMessages =
        <StoreServiceChatMessageData>[];

    for (final StoreServiceChatMessageData message in rawMessages) {
      if (!message.isLokallyMeetingMessage) {
        normalizedMessages.add(message);
        continue;
      }

      final String meetingKey = message.meetingDedupKey;

      if (meetingKey.isNotEmpty && renderedMeetingKeys.contains(meetingKey)) {
        continue;
      }

      if (meetingKey.isNotEmpty) {
        renderedMeetingKeys.add(meetingKey);
      }

      normalizedMessages.add(message);
    }

    return normalizedMessages;
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

  String twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String formatMeetingDateTime(DateTime value) {
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  String formatMeetingDateTimeForApi(DateTime value) {
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} ${twoDigits(value.hour)}:${twoDigits(value.minute)}:00';
  }

  Future<StoreServiceMeetingScheduleDraft?> showScheduleMeetingModal() async {
    final Color primaryColor = Theme.of(context).primaryColor;
    final TextEditingController titleController =
        TextEditingController(text: 'Lokally Meeting');
    final TextEditingController noteController = TextEditingController();

    DateTime selectedDateTime = DateTime.now().add(const Duration(hours: 1));
    selectedDateTime = DateTime(
      selectedDateTime.year,
      selectedDateTime.month,
      selectedDateTime.day,
      selectedDateTime.hour,
      selectedDateTime.minute,
    );

    final StoreServiceMeetingScheduleDraft? result =
        await showModalBottomSheet<StoreServiceMeetingScheduleDraft>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickDate() async {
              final DateTime now = DateTime.now();
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate:
                    selectedDateTime.isBefore(now) ? now : selectedDateTime,
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
              );

              if (picked == null) {
                return;
              }

              setModalState(() {
                selectedDateTime = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  selectedDateTime.hour,
                  selectedDateTime.minute,
                );
              });
            }

            Future<void> pickTime() async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(selectedDateTime),
              );

              if (picked == null) {
                return;
              }

              setModalState(() {
                selectedDateTime = DateTime(
                  selectedDateTime.year,
                  selectedDateTime.month,
                  selectedDateTime.day,
                  picked.hour,
                  picked.minute,
                );
              });
            }

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
                  child: SingleChildScrollView(
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
                                Icons.video_call_rounded,
                                color: primaryColor,
                                size: 25,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Agendar Lokally Meeting',
                                    style: textBold.copyWith(
                                      color: Colors.black87,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Envie um convite de videochamada para o cliente.',
                                    style: textRegular.copyWith(
                                      color: Colors.grey.shade600,
                                      fontSize: 11.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            labelText: 'Título',
                            hintText: 'Lokally Meeting',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: noteController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Observação',
                            hintText:
                                'Ex: reunião para alinhar detalhes do serviço.',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Data e horário',
                                style: textBold.copyWith(
                                  color: Colors.black87,
                                  fontSize: 12.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      formatMeetingDateTime(selectedDateTime),
                                      style: textBold.copyWith(
                                        color: primaryColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _StoreServiceMeetingSmallButton(
                                    label: 'Data',
                                    icon: Icons.calendar_month_outlined,
                                    primaryColor: primaryColor,
                                    onTap: pickDate,
                                  ),
                                  const SizedBox(width: 6),
                                  _StoreServiceMeetingSmallButton(
                                    label: 'Hora',
                                    icon: Icons.schedule_rounded,
                                    primaryColor: primaryColor,
                                    onTap: pickTime,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Material(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(17),
                          child: InkWell(
                            onTap: () {
                              if (selectedDateTime.isBefore(DateTime.now())) {
                                showChatMessage(
                                  'Escolha uma data e horário futuros.',
                                );
                                return;
                              }

                              Navigator.of(context).pop(
                                StoreServiceMeetingScheduleDraft(
                                  scheduledAt: selectedDateTime,
                                  title: titleController.text.trim().isEmpty
                                      ? 'Lokally Meeting'
                                      : titleController.text.trim(),
                                  note: noteController.text.trim(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(17),
                            child: Container(
                              height: 48,
                              width: double.infinity,
                              alignment: Alignment.center,
                              child: Text(
                                'Enviar convite',
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
                            onTap: () => Navigator.of(context).pop(),
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
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    noteController.dispose();

    return result;
  }

  Future<void> scheduleLokallyMeeting() async {
    if (isSchedulingMeeting || isSending) {
      return;
    }

    final StoreServiceMeetingScheduleDraft? draft =
        await showScheduleMeetingModal();

    if (draft == null) {
      return;
    }

    setState(() {
      isSchedulingMeeting = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().postData(
        '$chatBaseUri/meeting',
        <String, dynamic>{
          'scheduled_at': formatMeetingDateTimeForApi(draft.scheduledAt),
          'timezone': 'America/Sao_Paulo',
          'title': draft.title,
          'note': draft.note,
        },
      );

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body is Map &&
          body['status'] == true) {
        await loadChat();
        showChatMessage('Convite do Lokally Meeting enviado.');
        return;
      }

      showChatMessage(
        body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Não foi possível agendar o Lokally Meeting.',
      );
    } catch (_) {
      if (mounted) {
        showChatMessage('Não foi possível agendar o Lokally Meeting.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isSchedulingMeeting = false;
        });
      }
    }
  }

  Future<void> openLokallyMeetingApp(
    StoreServiceChatMessageData message,
  ) async {
    final String meetingId = message.meetingId.trim();

    if (meetingId.isEmpty) {
      showChatMessage('Lokally Meeting não encontrado para este serviço.');
      return;
    }

    await Get.to(
      () => LokallyMeetingScreen(
        orderId: widget.order.id,
        meetingId: meetingId,
        isHost: true,
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
    StoreServiceChatMessageData message,
  ) async {
    final String meetingId = message.meetingId.trim();

    if (meetingId.isEmpty) {
      showChatMessage('Lokally Meeting não encontrado para este serviço.');
      return;
    }

    try {
      final Response response = await Get.find<ApiClient>().postData(
        '$chatBaseUri/meeting/$meetingId/link',
        <String, dynamic>{'device_type': 'web'},
      );

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if ((response.statusCode != 200 && response.statusCode != 201) ||
          body is! Map ||
          body['status'] != true) {
        showChatMessage(
          body is Map && body['message'] != null
              ? body['message'].toString()
              : 'Não foi possível gerar o link do Lokally Meeting.',
        );
        return;
      }

      final dynamic dataValue = body['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};
      final String accessUrl = '${data['access_url'] ?? ''}'.trim();

      if (accessUrl.isEmpty) {
        showChatMessage('O link do Lokally Meeting não foi retornado.');
        return;
      }

      await Clipboard.setData(ClipboardData(text: accessUrl));

      if (!mounted) {
        return;
      }

      await showLokallyMeetingDesktopLinkSheet(accessUrl);
    } catch (_) {
      if (mounted) {
        showChatMessage('Não foi possível gerar o link do Lokally Meeting.');
      }
    }
  }

  Future<void> showLokallyMeetingDesktopLinkSheet(String accessUrl) async {
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
                        size: 23,
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
                  'O link do Lokally Meeting foi copiado. Abra no computador ou notebook para participar pelo navegador.',
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 12.7,
                    height: 1.34,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    accessUrl,
                    style: textRegular.copyWith(
                      color: Colors.grey.shade800,
                      fontSize: 11.4,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: primaryColor,
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
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'Abrir no navegador',
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
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      height: 44,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'Fechar',
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
  }

  Future<void> showUpdateProgressModal() async {
    final StoreSellerServiceProgressData currentProgress =
        thread?.serviceProgress ?? StoreSellerServiceProgressData.empty();
    final Set<String> selectedSteps = currentProgress.steps.toSet();
    final Color primaryColor = Theme.of(context).primaryColor;

    final Set<String>? result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
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
                            Icons.checklist_rounded,
                            color: primaryColor,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'Atualizar status do serviço',
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
                      'Marque as etapas já concluídas. Reajuste 1, 2 e 3 contam juntos como uma única etapa na barra de progresso.',
                      style: textRegular.copyWith(
                        color: Colors.grey.shade700,
                        fontSize: 12.4,
                        height: 1.32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: currentProgress.definitions
                            .map(
                              (step) => CheckboxListTile(
                                value: selectedSteps.contains(step.key),
                                onChanged: (value) {
                                  setModalState(() {
                                    if (value == true) {
                                      selectedSteps.add(step.key);
                                    } else {
                                      selectedSteps.remove(step.key);
                                    }
                                  });
                                },
                                activeColor: primaryColor,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  step.label,
                                  style: textMedium.copyWith(
                                    color: Colors.black87,
                                    fontSize: 12.8,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(17),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(selectedSteps),
                        borderRadius: BorderRadius.circular(17),
                        child: Container(
                          height: 46,
                          width: double.infinity,
                          alignment: Alignment.center,
                          child: Text(
                            'Salvar status',
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
      },
    );

    if (result == null) {
      return;
    }

    await updateProgress(result.toList());
  }

  Future<void> updateProgress(List<String> steps) async {
    if (isUpdatingProgress) {
      return;
    }

    setState(() {
      isUpdatingProgress = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().postData(
        '$chatBaseUri/progress',
        <String, dynamic>{'steps': steps},
      );

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body is Map &&
          body['status'] == true) {
        await loadChat();
        showChatMessage('Status do serviço atualizado.');
        return;
      }

      showChatMessage(
        body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Não foi possível atualizar o status.',
      );
    } catch (_) {
      if (mounted) {
        showChatMessage('Não foi possível atualizar o status.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isUpdatingProgress = false;
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
      backgroundColor: Colors.white,
      body: Column(
        children: [
          StoreServiceChatTopBar(
            primaryColor: primaryColor,
            orderNumber: widget.order.orderNumber,
            serviceLabel: widget.order.serviceDeliveryLabel,
            onBackTap: () => Get.back(),
          ),
          StoreServiceChatOrderSummary(
            order: widget.order,
            primaryColor: primaryColor,
            progress: thread?.serviceProgress ??
                StoreSellerServiceProgressData.empty(),
            isUpdatingProgress: isUpdatingProgress,
            onUpdateProgressTap: showUpdateProgressModal,
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
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final StoreServiceChatMessageData message =
                          messages[index];

                      return StoreServiceChatBubble(
                        message: message,
                        isMine: message.senderType == 'seller',
                        primaryColor: primaryColor,
                        onOpenMeetingApp: openLokallyMeetingApp,
                        onGenerateMeetingLink:
                            generateLokallyMeetingDesktopLink,
                      );
                    },
                  ),
          ),
          StoreServiceChatInputBar(
            primaryColor: primaryColor,
            controller: messageController,
            isSending: isSending,
            isSchedulingMeeting: isSchedulingMeeting,
            onMeetingTap: scheduleLokallyMeeting,
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
  final StoreSellerServiceProgressData progress;
  final bool isUpdatingProgress;
  final VoidCallback onUpdateProgressTap;

  const StoreServiceChatOrderSummary({
    super.key,
    required this.order,
    required this.primaryColor,
    required this.progress,
    required this.isUpdatingProgress,
    required this.onUpdateProgressTap,
  });

  @override
  Widget build(BuildContext context) {
    final String serviceName = order.items.isNotEmpty
        ? order.items.first.productName
        : order.orderNumber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            serviceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 13.4,
            ),
          ),
          const SizedBox(height: 7),
          StoreServiceProgressMiniBar(
            progress: progress,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: primaryColor,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                onTap: isUpdatingProgress ? null : onUpdateProgressTap,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  child: isUpdatingProgress
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Atualizar status',
                          style: textBold.copyWith(
                            color: Colors.white,
                            fontSize: 12.3,
                          ),
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

class StoreServiceChatBubble extends StatelessWidget {
  final StoreServiceChatMessageData message;
  final bool isMine;
  final Color primaryColor;
  final ValueChanged<StoreServiceChatMessageData>? onOpenMeetingApp;
  final ValueChanged<StoreServiceChatMessageData>? onGenerateMeetingLink;

  const StoreServiceChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.primaryColor,
    this.onOpenMeetingApp,
    this.onGenerateMeetingLink,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isLokallyMeetingMessage) {
      return StoreServiceMeetingCard(
        message: message,
        isMine: isMine,
        primaryColor: primaryColor,
        onOpenMeetingApp: onOpenMeetingApp,
        onGenerateMeetingLink: onGenerateMeetingLink,
      );
    }

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

class StoreServiceMeetingCard extends StatelessWidget {
  final StoreServiceChatMessageData message;
  final bool isMine;
  final Color primaryColor;
  final ValueChanged<StoreServiceChatMessageData>? onOpenMeetingApp;
  final ValueChanged<StoreServiceChatMessageData>? onGenerateMeetingLink;

  const StoreServiceMeetingCard({
    super.key,
    required this.message,
    required this.isMine,
    required this.primaryColor,
    this.onOpenMeetingApp,
    this.onGenerateMeetingLink,
  });

  Color get statusColor {
    switch (message.meeting?.status) {
      case 'accepted':
      case 'started':
        return primaryColor;
      case 'ended':
        return Colors.grey;
      case 'declined':
        return Colors.redAccent;
      default:
        return Colors.orange.shade800;
    }
  }

  IconData get statusIcon {
    switch (message.meeting?.status) {
      case 'accepted':
        return Icons.check_circle_outline_rounded;
      case 'started':
        return Icons.video_camera_front_rounded;
      case 'ended':
        return Icons.call_end_outlined;
      case 'declined':
        return Icons.cancel_outlined;
      default:
        return Icons.schedule_rounded;
    }
  }

  String get statusLabel {
    switch (message.meeting?.status) {
      case 'accepted':
        return 'Aceito pelo cliente';
      case 'started':
        return 'Meeting iniciado';
      case 'ended':
        return 'Meeting encerrado';
      case 'declined':
        return 'Recusado pelo cliente';
      default:
        return 'Aguardando resposta';
    }
  }

  String get helperText {
    if (message.messageType == 'lokally_meeting_accepted') {
      return 'O cliente aceitou este Lokally Meeting.';
    }

    if (message.messageType == 'lokally_meeting_declined') {
      final String reason = message.meeting?.declineReason ?? '';

      return reason.isEmpty
          ? 'O cliente recusou este Lokally Meeting.'
          : 'Motivo: $reason';
    }

    return message.meeting?.status == 'accepted'
        ? 'Reunião confirmada no chat do serviço.'
        : message.meeting?.status == 'declined'
            ? 'Este convite foi recusado pelo cliente.'
            : 'O cliente poderá aceitar ou recusar pelo chat.';
  }

  @override
  Widget build(BuildContext context) {
    final StoreServiceChatMeetingData? meeting = message.meeting;
    final String title =
        meeting?.title.isNotEmpty == true ? meeting!.title : 'Lokally Meeting';
    final String scheduledAt = meeting?.displayScheduledAt ?? '';
    final String note = meeting?.note ?? '';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMine ? 20 : 5),
            bottomRight: Radius.circular(isMine ? 5 : 20),
          ),
          border: Border.all(color: primaryColor.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 5),
              blurRadius: 16,
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.video_call_rounded,
                    color: primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 14.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lokally Meeting',
                        style: textRegular.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 10.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (scheduledAt.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: primaryColor,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      scheduledAt,
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 12.8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                note,
                style: textRegular.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 11.8,
                  height: 1.32,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    statusIcon,
                    color: statusColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      statusLabel,
                      style: textBold.copyWith(
                        color: statusColor,
                        fontSize: 11.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              helperText,
              style: textRegular.copyWith(
                color: Colors.grey.shade600,
                fontSize: 10.8,
                height: 1.28,
              ),
            ),
            if (meeting != null &&
                (meeting.status == 'accepted' || meeting.status == 'started') &&
                onOpenMeetingApp != null &&
                onGenerateMeetingLink != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StoreServiceMeetingSmallButton(
                    label: meeting.status == 'started'
                        ? 'Entrar pelo app'
                        : 'Iniciar pelo app',
                    icon: Icons.video_camera_front_rounded,
                    primaryColor: primaryColor,
                    onTap: () => onOpenMeetingApp?.call(message),
                  ),
                  _StoreServiceMeetingSmallButton(
                    label: 'Link computador',
                    icon: Icons.computer_rounded,
                    primaryColor: primaryColor,
                    onTap: () => onGenerateMeetingLink?.call(message),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${message.senderLabel} • ${message.createdAt}',
              style: textRegular.copyWith(
                color: Colors.grey.shade500,
                fontSize: 10.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreServiceMeetingSmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color primaryColor;
  final VoidCallback onTap;

  const _StoreServiceMeetingSmallButton({
    required this.label,
    required this.icon,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primaryColor.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: primaryColor,
                size: 15,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: textBold.copyWith(
                  color: primaryColor,
                  fontSize: 10.8,
                ),
              ),
            ],
          ),
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
  final bool isSchedulingMeeting;
  final VoidCallback? onMeetingTap;
  final VoidCallback onAttachTap;
  final VoidCallback onSendTap;

  const StoreServiceChatInputBar({
    super.key,
    required this.primaryColor,
    required this.controller,
    required this.isSending,
    this.isSchedulingMeeting = false,
    this.onMeetingTap,
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
          if (onMeetingTap != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: isSending || isSchedulingMeeting ? null : onMeetingTap,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: isSchedulingMeeting
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          color: primaryColor,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        Icons.video_call_rounded,
                        color: primaryColor,
                        size: 22,
                      ),
              ),
            ),
          ],
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
  final StoreSellerServiceProgressData serviceProgress;

  StoreServiceChatThreadData({
    required this.id,
    required this.orderId,
    required this.safetyNoticeAccepted,
    required this.serviceProgress,
  });

  factory StoreServiceChatThreadData.fromMap(Map<String, dynamic> map) {
    return StoreServiceChatThreadData(
      id: '${map['id'] ?? ''}',
      orderId: '${map['store_order_id'] ?? ''}',
      safetyNoticeAccepted: StoreSellerOrderParser.parseBool(
        map['safety_notice_accepted'],
      ),
      serviceProgress: StoreSellerServiceProgressData.fromMap(
        map['service_progress'] is Map
            ? Map<String, dynamic>.from(map['service_progress'])
            : <String, dynamic>{},
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
  final String meetingId;
  final StoreServiceChatMeetingData? meeting;
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
    required this.meetingId,
    required this.meeting,
    required this.createdAt,
  });

  bool get hasFile => fileUrl.isNotEmpty || fileOriginalName.isNotEmpty;

  bool get isLokallyMeetingMessage {
    return messageType.startsWith('lokally_meeting');
  }

  String get meetingDedupKey {
    final String meetingObjectId = meeting?.id.trim() ?? '';

    if (meetingObjectId.isNotEmpty) {
      return meetingObjectId;
    }

    if (meetingId.trim().isNotEmpty) {
      return meetingId.trim();
    }

    return '';
  }

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
      meetingId: '${map['meeting_id'] ?? ''}',
      meeting: StoreServiceChatMeetingData.fromDynamic(map['meeting']),
      createdAt: '${map['created_at'] ?? ''}',
    );
  }
}

class StoreServiceMeetingScheduleDraft {
  final DateTime scheduledAt;
  final String title;
  final String note;

  StoreServiceMeetingScheduleDraft({
    required this.scheduledAt,
    required this.title,
    required this.note,
  });
}

class StoreServiceChatMeetingData {
  final String id;
  final String status;
  final String title;
  final String note;
  final String scheduledAt;
  final String timezone;
  final String declineReason;
  final String roomKey;

  StoreServiceChatMeetingData({
    required this.id,
    required this.status,
    required this.title,
    required this.note,
    required this.scheduledAt,
    required this.timezone,
    required this.declineReason,
    required this.roomKey,
  });

  static StoreServiceChatMeetingData? fromDynamic(dynamic value) {
    if (value is! Map) {
      return null;
    }

    return StoreServiceChatMeetingData.fromMap(
      Map<String, dynamic>.from(value),
    );
  }

  factory StoreServiceChatMeetingData.fromMap(Map<String, dynamic> map) {
    return StoreServiceChatMeetingData(
      id: '${map['id'] ?? ''}',
      status: '${map['status'] ?? ''}',
      title: '${map['title'] ?? ''}',
      note: '${map['note'] ?? ''}',
      scheduledAt: '${map['scheduled_at'] ?? ''}',
      timezone: '${map['timezone'] ?? ''}',
      declineReason: '${map['decline_reason'] ?? ''}',
      roomKey: '${map['room_key'] ?? ''}',
    );
  }

  String get displayScheduledAt {
    final String clean = scheduledAt.trim();

    if (clean.length >= 16 && clean.contains('-')) {
      final String datePart = clean.substring(0, 10);
      final String timePart = clean.substring(11, 16);
      final List<String> datePieces = datePart.split('-');

      if (datePieces.length == 3) {
        return '${datePieces[2]}/${datePieces[1]}/${datePieces[0]} às $timePart';
      }
    }

    return clean;
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
