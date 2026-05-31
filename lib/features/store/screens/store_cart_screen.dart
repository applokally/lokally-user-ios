import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/address/controllers/address_controller.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/address/screens/add_new_address.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/wallet/screens/wallet_screen.dart';
import 'package:ride_sharing_user_app/helper/login_helper.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:url_launcher/url_launcher.dart';

enum StoreCartDeliveryMode {
  pickup,
  lokallyShipping,
  nationalShipping,
}

enum StoreCartPaymentMode {
  appBalance,
  mercadoPago,
}

class StoreShippingPreview {
  final bool hasValue;
  final double itemsSubtotal;
  final double shippingAmount;
  final double shippingDiscount;
  final double shippingTotal;
  final double total;

  StoreShippingPreview({
    required this.hasValue,
    required this.itemsSubtotal,
    required this.shippingAmount,
    required this.shippingDiscount,
    required this.shippingTotal,
    required this.total,
  });

  factory StoreShippingPreview.empty() {
    return StoreShippingPreview(
      hasValue: false,
      itemsSubtotal: 0,
      shippingAmount: 0,
      shippingDiscount: 0,
      shippingTotal: 0,
      total: 0,
    );
  }

  factory StoreShippingPreview.fromMap(Map<String, dynamic> map) {
    return StoreShippingPreview(
      hasValue: true,
      itemsSubtotal: StoreCartCurrency.parseDouble(map['items_subtotal']),
      shippingAmount: StoreCartCurrency.parseDouble(map['shipping_amount']),
      shippingDiscount: StoreCartCurrency.parseDouble(map['shipping_discount']),
      shippingTotal: StoreCartCurrency.parseDouble(map['shipping_total']),
      total: StoreCartCurrency.parseDouble(map['total']),
    );
  }
}

class StoreNationalShippingOption {
  final String storeSellerId;
  final String serviceCode;
  final String serviceName;
  final String label;
  final String carrier;
  final double price;
  final int deliveryDays;
  final Map<String, dynamic> rawData;

  StoreNationalShippingOption({
    required this.storeSellerId,
    required this.serviceCode,
    required this.serviceName,
    required this.label,
    required this.carrier,
    required this.price,
    required this.deliveryDays,
    required this.rawData,
  });

  String get displayName {
    if (label.trim().isNotEmpty) {
      return label.trim();
    }

    if (serviceName.trim().isNotEmpty) {
      return serviceName.trim();
    }

    if (carrier.trim().isNotEmpty) {
      return carrier.trim();
    }

    return 'store_shipping_option'.tr;
  }

  String get deliveryDescription {
    final String priceText = StoreCartCurrency.format(price);

    if (deliveryDays > 0) {
      return 'store_shipping_deadline_days'.trParams({
        'price': priceText,
        'days': '$deliveryDays',
      });
    }

    return 'store_shipping_deadline_by_carrier'.trParams({'price': priceText});
  }

  factory StoreNationalShippingOption.fromMap(
    Map<String, dynamic> map, {
    String fallbackStoreSellerId = '',
  }) {
    final String serviceCode =
        '${map['service_code'] ?? map['serviceCode'] ?? map['shipping_service_code'] ?? map['ShippingServiceCode'] ?? map['code'] ?? map['id'] ?? ''}'
            .trim();

    final String serviceName =
        '${map['service_name'] ?? map['serviceName'] ?? map['ShippingServiceDescription'] ?? map['name'] ?? ''}'
            .trim();

    final String label =
        '${map['label'] ?? map['title'] ?? map['display_name'] ?? map['displayName'] ?? ''}'
            .trim();

    final String carrier =
        '${map['carrier'] ?? map['carrier_name'] ?? map['company'] ?? map['transportadora'] ?? ''}'
            .trim();

    final dynamic deliveryValue = map['delivery_days'] ??
        map['deliveryDays'] ??
        map['DeliveryTime'] ??
        map['deadline'] ??
        map['prazo'];

    return StoreNationalShippingOption(
      storeSellerId:
          '${map['store_seller_id'] ?? map['seller_id'] ?? fallbackStoreSellerId}'
              .trim(),
      serviceCode: serviceCode,
      serviceName: serviceName,
      label: label,
      carrier: carrier,
      price: StoreCartCurrency.parseDouble(
        map['price'] ??
            map['amount'] ??
            map['shipping_amount'] ??
            map['ShippingPrice'] ??
            map['value'],
      ),
      deliveryDays: int.tryParse('$deliveryValue') ?? 0,
      rawData: map,
    );
  }

  static List<StoreNationalShippingOption> listFromResponse(
    Map<String, dynamic> data,
  ) {
    final List<StoreNationalShippingOption> options =
        <StoreNationalShippingOption>[];

    void readOptions(dynamic value, {String fallbackStoreSellerId = ''}) {
      if (value is! List) {
        return;
      }

      for (final dynamic item in value) {
        if (item is! Map) {
          continue;
        }

        final Map<String, dynamic> optionMap = Map<String, dynamic>.from(item);
        final StoreNationalShippingOption option =
            StoreNationalShippingOption.fromMap(
          optionMap,
          fallbackStoreSellerId: fallbackStoreSellerId,
        );

        if (option.serviceCode.isNotEmpty && option.price > 0) {
          options.add(option);
        }
      }
    }

    readOptions(data['options']);
    readOptions(data['shipping_options']);
    readOptions(data['national_shipping_options']);
    readOptions(data['available_options']);
    readOptions(data['services']);
    readOptions(data['quotes']);

    final dynamic storesValue = data['stores'] ?? data['store_quotes'];
    if (storesValue is List) {
      for (final dynamic storeItem in storesValue) {
        if (storeItem is! Map) {
          continue;
        }

        final Map<String, dynamic> storeMap =
            Map<String, dynamic>.from(storeItem);
        final String storeSellerId =
            '${storeMap['store_seller_id'] ?? storeMap['seller_id'] ?? storeMap['id'] ?? ''}';

        readOptions(
          storeMap['options'] ??
              storeMap['shipping_options'] ??
              storeMap['national_shipping_options'] ??
              storeMap['services'],
          fallbackStoreSellerId: storeSellerId,
        );
      }
    }

    final Set<String> seen = <String>{};
    return options.where((option) {
      final String key =
          '${option.storeSellerId}:${option.serviceCode}:${option.price}';

      if (seen.contains(key)) {
        return false;
      }

      seen.add(key);
      return true;
    }).toList();
  }
}

class StoreMarketplaceDeliveryContext {
  static bool isActive = false;
  static bool freeShippingApplied = false;
  static String storeId = '';
  static String storeName = '';
  static double marketplaceShippingValue = 0;

  static void configure({
    required bool freeShipping,
    required String selectedStoreId,
    required String selectedStoreName,
    required double shippingValue,
  }) {
    isActive = true;
    freeShippingApplied = freeShipping;
    storeId = selectedStoreId;
    storeName = selectedStoreName;
    marketplaceShippingValue = shippingValue;
  }

  static void clear() {
    isActive = false;
    freeShippingApplied = false;
    storeId = '';
    storeName = '';
    marketplaceShippingValue = 0;
  }
}

class StoreCartSession {
  static final List<StoreCartItemData> items = <StoreCartItemData>[];
  static final ValueNotifier<int> cartRevision = ValueNotifier<int>(0);

  static int get totalQuantity {
    return items.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
  }

  static void notifyChanged() {
    cartRevision.value++;
  }

  static void addProductMap(
    Map<String, dynamic> productMap,
    int quantity,
  ) {
    final StoreCartProductData product = StoreCartProductData.fromMap(
      productMap,
    );

    if (product.id.isEmpty) {
      return;
    }

    addProduct(product, quantity);
  }

  static void addProduct(
    StoreCartProductData product,
    int quantity,
  ) {
    final int safeQuantity = quantity <= 0 ? 1 : quantity;
    final int index = items.indexWhere((item) {
      return item.product.cartKey == product.cartKey;
    });

    if (index >= 0) {
      items[index].quantity += safeQuantity;
      notifyChanged();
      return;
    }

    items.add(
      StoreCartItemData(
        product: product,
        quantity: safeQuantity,
      ),
    );
    notifyChanged();
  }

  static void removeItem(StoreCartItemData item) {
    items.remove(item);
    notifyChanged();
  }

  static void clear() {
    items.clear();
    notifyChanged();
  }
}

class StoreCartScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProduct;
  final int initialQuantity;

  const StoreCartScreen({
    super.key,
    this.initialProduct,
    this.initialQuantity = 0,
  });

  @override
  State<StoreCartScreen> createState() => _StoreCartScreenState();
}

class _StoreCartScreenState extends State<StoreCartScreen> {
  StoreCartDeliveryMode deliveryMode = StoreCartDeliveryMode.pickup;
  StoreCartPaymentMode paymentMode = StoreCartPaymentMode.appBalance;
  Address? selectedDeliveryAddress;

  final TextEditingController nationalCepController = TextEditingController();
  final TextEditingController nationalRecipientNameController =
      TextEditingController();
  final TextEditingController nationalRecipientPhoneController =
      TextEditingController();
  final TextEditingController nationalStreetController =
      TextEditingController();
  final TextEditingController nationalNumberController =
      TextEditingController();
  final TextEditingController nationalComplementController =
      TextEditingController();
  final TextEditingController nationalDistrictController =
      TextEditingController();
  final TextEditingController nationalCityController = TextEditingController();
  final TextEditingController nationalStateController = TextEditingController();
  final List<StoreCartItemData> cartItems = StoreCartSession.items;

  bool isShippingPreviewLoading = false;
  String shippingPreviewError = '';
  StoreShippingPreview shippingPreview = StoreShippingPreview.empty();
  List<StoreNationalShippingOption> nationalShippingOptions =
      <StoreNationalShippingOption>[];
  StoreNationalShippingOption? selectedNationalShippingOption;
  int shippingPreviewRequestId = 0;
  Timer? nationalCepTypingTimer;

  double get appBalance {
    if (!Get.isRegistered<ProfileController>()) {
      return 0;
    }

    return Get.find<ProfileController>()
            .profileModel
            ?.data
            ?.wallet
            ?.walletBalance ??
        0;
  }

  bool get isCustomerLoggedIn {
    return Get.isRegistered<AuthController>() &&
        Get.find<AuthController>().isLoggedIn();
  }

  @override
  void initState() {
    super.initState();

    final Map<String, dynamic>? initialProduct = widget.initialProduct;

    if (initialProduct != null) {
      StoreCartSession.addProductMap(
        initialProduct,
        widget.initialQuantity,
      );
    }

    nationalCepController.addListener(handleNationalCepTyping);

    if (isCustomerLoggedIn && Get.isRegistered<ProfileController>()) {
      Get.find<ProfileController>().getProfileInfo();
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        prefillNationalRecipientFromProfile();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ensureDeliveryModeIsAvailable();
    });
  }

  @override
  void dispose() {
    nationalCepTypingTimer?.cancel();
    nationalCepController.removeListener(handleNationalCepTyping);
    nationalCepController.dispose();
    nationalRecipientNameController.dispose();
    nationalRecipientPhoneController.dispose();
    nationalStreetController.dispose();
    nationalNumberController.dispose();
    nationalComplementController.dispose();
    nationalDistrictController.dispose();
    nationalCityController.dispose();
    nationalStateController.dispose();
    super.dispose();
  }

  List<StoreCartStoreGroup> get storeGroups {
    final Map<String, StoreCartStoreGroup> groups =
        <String, StoreCartStoreGroup>{};

    for (final StoreCartItemData item in cartItems) {
      final String storeKey = item.product.storeId.isEmpty
          ? item.product.storeName
          : item.product.storeId;

      groups.putIfAbsent(
        storeKey,
        () => StoreCartStoreGroup(
          storeId: item.product.storeId,
          storeName: item.product.storeName,
          storeLogoUrl: item.product.storeLogoUrl,
          items: <StoreCartItemData>[],
        ),
      );

      groups[storeKey]!.items.add(item);
    }

    return groups.values.toList();
  }

  int get storeCount => storeGroups.length;

  List<StoreCartItemData> get physicalCartItems {
    return cartItems.where((item) => !item.product.isService).toList();
  }

  bool get hasPhysicalItems {
    return physicalCartItems.isNotEmpty;
  }

  bool get hasOnlyServiceItems {
    return cartItems.isNotEmpty && !hasPhysicalItems;
  }

  bool get canUsePickup {
    return physicalCartItems.isNotEmpty &&
        physicalCartItems.every((item) => item.product.allowPickup);
  }

  bool get canUseLokallyShipping {
    return physicalCartItems.isNotEmpty &&
        physicalCartItems.every((item) => item.product.allowLokallyShipping);
  }

  bool get canUseNationalShipping {
    return physicalCartItems.isNotEmpty &&
        physicalCartItems.every((item) => item.product.allowNationalShipping);
  }

  bool get isLokallyShippingMode {
    return deliveryMode == StoreCartDeliveryMode.lokallyShipping;
  }

  bool get isNationalShippingMode {
    return deliveryMode == StoreCartDeliveryMode.nationalShipping;
  }

  String get primaryStoreCityLabel {
    for (final StoreCartItemData item in physicalCartItems) {
      final String city = item.product.storeCity.trim();

      if (city.isNotEmpty) {
        return city;
      }
    }

    return 'store_city_of_store'.tr;
  }

  String get nationalRecipientPostalCode {
    return onlyDigits(nationalCepController.text);
  }

  double get nationalShippingTotal {
    return selectedNationalShippingOption?.price ?? 0;
  }

  double get itemsSubtotal {
    return cartItems.fold<double>(
      0,
      (total, item) => total + item.total,
    );
  }

  double get shippingBaseValue {
    if (!hasPhysicalItems || deliveryMode == StoreCartDeliveryMode.pickup) {
      return 0;
    }

    if (deliveryMode == StoreCartDeliveryMode.nationalShipping) {
      return nationalShippingTotal;
    }

    if (shippingPreview.hasValue) {
      return shippingPreview.shippingAmount;
    }

    return 0;
  }

  bool get hasMultiStoreShippingDiscount {
    return hasPhysicalItems &&
        deliveryMode == StoreCartDeliveryMode.lokallyShipping &&
        shippingPreview.hasValue &&
        storeCount >= 2 &&
        shippingPreview.shippingDiscount > 0;
  }

  double get shippingDiscount {
    if (!hasPhysicalItems || deliveryMode == StoreCartDeliveryMode.pickup) {
      return 0;
    }

    if (deliveryMode == StoreCartDeliveryMode.nationalShipping) {
      return 0;
    }

    if (shippingPreview.hasValue) {
      return shippingPreview.shippingDiscount;
    }

    return 0;
  }

  double get shippingTotal {
    if (!hasPhysicalItems || deliveryMode == StoreCartDeliveryMode.pickup) {
      return 0;
    }

    if (deliveryMode == StoreCartDeliveryMode.nationalShipping) {
      return nationalShippingTotal;
    }

    if (shippingPreview.hasValue) {
      return shippingPreview.shippingTotal;
    }

    return 0;
  }

  double get orderTotal {
    if (hasPhysicalItems &&
        deliveryMode == StoreCartDeliveryMode.lokallyShipping &&
        shippingPreview.hasValue) {
      return shippingPreview.total;
    }

    return itemsSubtotal + shippingTotal;
  }

  StoreCartStoreGroup? get firstStore {
    if (storeGroups.isEmpty) {
      return null;
    }

    return storeGroups.first;
  }

  Map<String, dynamic> buildShippingPreviewPayload() {
    final String deliveryType = deliveryMode == StoreCartDeliveryMode.pickup
        ? 'pickup'
        : deliveryMode == StoreCartDeliveryMode.nationalShipping
            ? 'national_shipping'
            : 'lokally_shipping';

    final Map<String, dynamic> payload = <String, dynamic>{
      'delivery_type': deliveryType,
      'items': physicalCartItems.map((item) {
        return {
          'product_id': item.product.id,
          'quantity': item.quantity,
        };
      }).toList(),
    };

    if (deliveryMode == StoreCartDeliveryMode.nationalShipping) {
      payload['recipient_postal_code'] = nationalRecipientPostalCode;
      payload['destination_postal_code'] = nationalRecipientPostalCode;
      payload['cep'] = nationalRecipientPostalCode;
    }

    return payload;
  }

  void clearShippingPreview() {
    shippingPreviewRequestId++;

    setState(() {
      isShippingPreviewLoading = false;
      shippingPreviewError = '';
      shippingPreview = StoreShippingPreview.empty();
      nationalShippingOptions = <StoreNationalShippingOption>[];
      selectedNationalShippingOption = null;
    });
  }

  Future<void> loadShippingPreview() async {
    if (!hasPhysicalItems ||
        deliveryMode == StoreCartDeliveryMode.pickup ||
        cartItems.isEmpty) {
      clearShippingPreview();
      return;
    }

    if (!isCustomerLoggedIn) {
      clearShippingPreview();
      return;
    }

    if (deliveryMode == StoreCartDeliveryMode.nationalShipping &&
        nationalRecipientPostalCode.length != 8) {
      shippingPreviewRequestId++;

      setState(() {
        isShippingPreviewLoading = false;
        shippingPreviewError =
            'store_enter_valid_zipcode_lokally_shipping_br'.tr;
        shippingPreview = StoreShippingPreview.empty();
        nationalShippingOptions = <StoreNationalShippingOption>[];
        selectedNationalShippingOption = null;
      });
      return;
    }

    if (!Get.isRegistered<ApiClient>()) {
      setState(() {
        isShippingPreviewLoading = false;
        shippingPreviewError = 'store_server_connection_error'.tr;
        shippingPreview = StoreShippingPreview.empty();
        nationalShippingOptions = <StoreNationalShippingOption>[];
        selectedNationalShippingOption = null;
      });
      return;
    }

    final int requestId = ++shippingPreviewRequestId;

    setState(() {
      isShippingPreviewLoading = true;
      shippingPreviewError = '';
    });

    try {
      final Response response = await Get.find<ApiClient>().postData(
        '/api/customer/store/shipping-preview',
        buildShippingPreviewPayload(),
      );

      if (!mounted || requestId != shippingPreviewRequestId) {
        return;
      }

      final dynamic responseBody = response.body;
      final dynamic dataValue =
          responseBody is Map ? responseBody['data'] : null;

      final bool success =
          (response.statusCode == 200 || response.statusCode == 201) &&
              responseBody is Map &&
              responseBody['status'] == true &&
              dataValue is Map;

      if (!success) {
        final String message = responseBody is Map
            ? '${responseBody['message'] ?? response.statusText ?? 'store_shipping_calculate_error'.tr}'
            : response.statusText ?? 'store_shipping_calculate_error'.tr;

        setState(() {
          isShippingPreviewLoading = false;
          shippingPreviewError = message;
          shippingPreview = StoreShippingPreview.empty();
          nationalShippingOptions = <StoreNationalShippingOption>[];
          selectedNationalShippingOption = null;
        });
        return;
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(dataValue);

      if (deliveryMode == StoreCartDeliveryMode.nationalShipping) {
        final List<StoreNationalShippingOption> options =
            StoreNationalShippingOption.listFromResponse(data);

        if (options.isEmpty) {
          setState(() {
            isShippingPreviewLoading = false;
            shippingPreviewError =
                'store_no_national_shipping_option_for_zipcode'.tr;
            shippingPreview = StoreShippingPreview.empty();
            nationalShippingOptions = <StoreNationalShippingOption>[];
            selectedNationalShippingOption = null;
          });
          return;
        }

        final String previousServiceCode =
            selectedNationalShippingOption?.serviceCode ?? '';

        StoreNationalShippingOption selectedOption = options.first;

        if (previousServiceCode.isNotEmpty) {
          selectedOption = options.firstWhere(
            (option) => option.serviceCode == previousServiceCode,
            orElse: () => options.first,
          );
        }

        setState(() {
          isShippingPreviewLoading = false;
          shippingPreviewError = '';
          nationalShippingOptions = options;
          selectedNationalShippingOption = selectedOption;
          shippingPreview = StoreShippingPreview(
            hasValue: true,
            itemsSubtotal: itemsSubtotal,
            shippingAmount: selectedOption.price,
            shippingDiscount: 0,
            shippingTotal: selectedOption.price,
            total: itemsSubtotal + selectedOption.price,
          );
        });
        return;
      }

      setState(() {
        isShippingPreviewLoading = false;
        shippingPreviewError = '';
        nationalShippingOptions = <StoreNationalShippingOption>[];
        selectedNationalShippingOption = null;
        shippingPreview = StoreShippingPreview.fromMap(data);
      });
    } catch (_) {
      if (!mounted || requestId != shippingPreviewRequestId) {
        return;
      }

      setState(() {
        isShippingPreviewLoading = false;
        shippingPreviewError = 'store_shipping_calculate_error'.tr;
        shippingPreview = StoreShippingPreview.empty();
        nationalShippingOptions = <StoreNationalShippingOption>[];
        selectedNationalShippingOption = null;
      });
    }
  }

  void refreshShippingPreviewIfNeeded() {
    if (hasPhysicalItems && deliveryMode != StoreCartDeliveryMode.pickup) {
      loadShippingPreview();
    }
  }

  void ensureDeliveryModeIsAvailable() {
    if (!hasPhysicalItems) {
      return;
    }

    final bool currentModeAvailable =
        deliveryMode == StoreCartDeliveryMode.pickup
            ? canUsePickup
            : deliveryMode == StoreCartDeliveryMode.lokallyShipping
                ? canUseLokallyShipping
                : canUseNationalShipping;

    if (currentModeAvailable) {
      return;
    }

    setState(() {
      if (canUsePickup) {
        deliveryMode = StoreCartDeliveryMode.pickup;
      } else if (canUseLokallyShipping) {
        deliveryMode = StoreCartDeliveryMode.lokallyShipping;
      } else if (canUseNationalShipping) {
        deliveryMode = StoreCartDeliveryMode.nationalShipping;
      }
    });

    refreshShippingPreviewIfNeeded();
  }

  String onlyDigits(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void prefillNationalRecipientFromProfile() {
    if (!mounted || !Get.isRegistered<ProfileController>()) {
      return;
    }

    final ProfileController profileController = Get.find<ProfileController>();
    final String name = profileController.customerName().trim();
    final String phone = profileController.profileModel?.data?.phone ?? '';

    if (nationalRecipientNameController.text.trim().isEmpty &&
        name.isNotEmpty) {
      nationalRecipientNameController.text = name;
    }

    if (nationalRecipientPhoneController.text.trim().isEmpty &&
        phone.trim().isNotEmpty) {
      nationalRecipientPhoneController.text = phone.trim();
    }
  }

  String get nationalRecipientName {
    return nationalRecipientNameController.text.trim();
  }

  String get nationalRecipientPhone {
    return nationalRecipientPhoneController.text.trim();
  }

  String get nationalStreet {
    return nationalStreetController.text.trim();
  }

  String get nationalNumber {
    return nationalNumberController.text.trim();
  }

  String get nationalComplement {
    return nationalComplementController.text.trim();
  }

  String get nationalDistrict {
    return nationalDistrictController.text.trim();
  }

  String get nationalCity {
    return nationalCityController.text.trim();
  }

  String get nationalState {
    return nationalStateController.text.trim().toUpperCase();
  }

  String get nationalDeliveryAddressText {
    final List<String> lines = <String>[
      'store_recipient_with_value'
          .trParams({'value': nationalRecipientName}),
      'store_phone_with_value'.trParams({'value': nationalRecipientPhone}),
      'store_zipcode_with_value'
          .trParams({'value': nationalRecipientPostalCode}),
      'store_address_with_value'
          .trParams({'value': '$nationalStreet, $nationalNumber'}),
      if (nationalComplement.isNotEmpty)
        'store_complement_with_value'.trParams({'value': nationalComplement}),
      'store_district_with_value'.trParams({'value': nationalDistrict}),
      'store_city_state_with_value'
          .trParams({'value': '$nationalCity - $nationalState'}),
      if (selectedNationalShippingOption != null)
        'store_shipping_company_with_value'
            .trParams({'value': selectedNationalShippingOption!.displayName}),
    ];

    return lines.join('\n');
  }

  bool get hasCompleteNationalDeliveryAddress {
    return nationalRecipientPostalCode.length == 8 &&
        nationalRecipientName.isNotEmpty &&
        nationalRecipientPhone.isNotEmpty &&
        nationalStreet.isNotEmpty &&
        nationalNumber.isNotEmpty &&
        nationalDistrict.isNotEmpty &&
        nationalCity.isNotEmpty &&
        RegExp(r'^[A-Z]{2}$').hasMatch(nationalState);
  }

  String postalCodeFromAddress(Address? address) {
    if (address == null) {
      return '';
    }

    final String rawAddress = address.address ?? '';
    final RegExpMatch? cepMatch =
        RegExp(r'(\d{5})[-\s]?(\d{3})').firstMatch(rawAddress);

    if (cepMatch == null) {
      return '';
    }

    return '${cepMatch.group(1)}${cepMatch.group(2)}';
  }

  void updateNationalPostalCodeFromAddress(Address? address) {
    final String cep = postalCodeFromAddress(address);

    if (cep.length == 8 && nationalCepController.text != cep) {
      nationalCepController.text = cep;
    }
  }

  void handleNationalCepTyping() {
    if (deliveryMode != StoreCartDeliveryMode.nationalShipping) {
      return;
    }

    nationalCepTypingTimer?.cancel();

    nationalCepTypingTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) {
        return;
      }

      if (nationalRecipientPostalCode.length == 8) {
        loadShippingPreview();
      }
    });
  }

  void selectNationalShippingOption(StoreNationalShippingOption option) {
    setState(() {
      selectedNationalShippingOption = option;
      shippingPreview = StoreShippingPreview(
        hasValue: true,
        itemsSubtotal: itemsSubtotal,
        shippingAmount: option.price,
        shippingDiscount: 0,
        shippingTotal: option.price,
        total: itemsSubtotal + option.price,
      );
    });
  }

  void increaseQuantity(StoreCartItemData item) {
    setState(() {
      item.quantity++;
    });
    StoreCartSession.notifyChanged();
    refreshShippingPreviewIfNeeded();
  }

  void decreaseQuantity(StoreCartItemData item) {
    if (item.quantity <= 1) {
      return;
    }

    setState(() {
      item.quantity--;
    });
    StoreCartSession.notifyChanged();
    refreshShippingPreviewIfNeeded();
  }

  void removeItem(StoreCartItemData item) {
    setState(() {
      StoreCartSession.removeItem(item);
    });

    if (cartItems.isEmpty) {
      Get.back();
      return;
    }

    refreshShippingPreviewIfNeeded();
  }

  Future<void> loadCustomerAddresses() async {
    if (deliveryMode == StoreCartDeliveryMode.nationalShipping) {
      return;
    }

    if (!isCustomerLoggedIn || !Get.isRegistered<AddressController>()) {
      return;
    }

    await Get.find<AddressController>().getAddressList(1);

    final List<Address>? addresses = Get.find<AddressController>().addressList;

    if (!mounted || addresses == null || addresses.isEmpty) {
      return;
    }

    selectedDeliveryAddress ??= addresses.first;
    setState(() {});
  }

  Future<void> openAddNewDeliveryAddress() async {
    if (!isCustomerLoggedIn) {
      showCheckoutLoginRequiredDialog();
      return;
    }

    await Get.to(() => const AddNewAddress());

    if (!mounted) {
      return;
    }

    await loadCustomerAddresses();
  }

  void selectDeliveryAddress(Address address) {
    setState(() {
      selectedDeliveryAddress = address;
    });

    refreshShippingPreviewIfNeeded();
  }

  void continueShopping() {
    if (Navigator.of(context).canPop()) {
      Get.back();
    }

    if (Navigator.of(context).canPop()) {
      Get.back();
    }
  }

  void openWalletRecharge() {
    if (!isCustomerLoggedIn) {
      showCheckoutLoginRequiredDialog();
      return;
    }

    Get.to(() => const WalletScreen());
  }

  void showCheckoutLoginRequiredDialog() {
    if (Get.isDialogOpen ?? false) {
      return;
    }

    final Color primaryColor = Theme.of(context).primaryColor;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 14),
                blurRadius: 34,
                color: Colors.black.withValues(alpha: 0.18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.shopping_cart_checkout_rounded,
                  color: primaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'store_registration_required'.tr,
                textAlign: TextAlign.center,
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'store_login_required_to_checkout'.tr,
                textAlign: TextAlign.center,
                style: textRegular.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: TextButton(
                        onPressed: () => Get.back(),
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: primaryColor.withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                        child: Text(
                          'store_continue_browsing'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textBold.copyWith(
                            color: primaryColor,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          LoginHelper.checkLoginMedium();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'store_login_or_register'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textBold.copyWith(
                            color: Colors.white,
                            fontSize: 12.5,
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
      ),
      barrierDismissible: true,
    );
  }

  void closeOrder() {
    if (cartItems.isEmpty) {
      showCartMessage('store_cart_empty'.tr);
      return;
    }

    if (!isCustomerLoggedIn) {
      showCheckoutLoginRequiredDialog();
      return;
    }

    if (hasPhysicalItems &&
        deliveryMode == StoreCartDeliveryMode.lokallyShipping &&
        selectedDeliveryAddress == null) {
      showCartMessage(
        'store_select_delivery_address_home'.tr,
      );
      return;
    }

    if (hasPhysicalItems &&
        deliveryMode == StoreCartDeliveryMode.lokallyShipping &&
        ((selectedDeliveryAddress?.latitude ?? 0) == 0 ||
            (selectedDeliveryAddress?.longitude ?? 0) == 0)) {
      showCartMessage(
        'store_select_valid_map_delivery_address'.tr,
      );
      return;
    }

    if (hasPhysicalItems &&
        deliveryMode == StoreCartDeliveryMode.nationalShipping &&
        nationalRecipientPostalCode.length != 8) {
      showCartMessage(
        'store_enter_valid_zipcode_lokally_shipping_br'.tr,
      );
      return;
    }

    if (hasPhysicalItems &&
        deliveryMode != StoreCartDeliveryMode.pickup &&
        isShippingPreviewLoading) {
      showCartMessage('store_wait_marketplace_shipping_calculation'.tr);
      return;
    }

    if (hasPhysicalItems &&
        deliveryMode == StoreCartDeliveryMode.lokallyShipping &&
        !shippingPreview.hasValue) {
      showCartMessage(
        shippingPreviewError.isNotEmpty
            ? shippingPreviewError
            : 'store_calculating_marketplace_shipping_try_again'.tr,
      );
      loadShippingPreview();
      return;
    }

    if (hasPhysicalItems &&
        deliveryMode == StoreCartDeliveryMode.nationalShipping &&
        selectedNationalShippingOption == null) {
      showCartMessage(
        shippingPreviewError.isNotEmpty
            ? shippingPreviewError
            : 'store_calculate_select_lokally_shipping_br'.tr,
      );
      loadShippingPreview();
      return;
    }

    if (hasPhysicalItems &&
        deliveryMode == StoreCartDeliveryMode.nationalShipping &&
        !hasCompleteNationalDeliveryAddress) {
      showCartMessage(
        'store_fill_full_address_lokally_shipping_br'.tr,
      );
      return;
    }

    if (paymentMode == StoreCartPaymentMode.appBalance &&
        appBalance < orderTotal) {
      showCartMessage(
        'store_insufficient_balance_recharge_or_mp'.tr,
      );
      return;
    }

    Get.to(
      () => StoreCheckoutScreen(
        cartItems: cartItems
            .map((item) => StoreCartItemData(
                  product: item.product,
                  quantity: item.quantity,
                ))
            .toList(),
        deliveryMode: deliveryMode,
        paymentMode: paymentMode,
        deliveryAddress: deliveryMode == StoreCartDeliveryMode.nationalShipping
            ? null
            : selectedDeliveryAddress,
        selectedNationalShippingOption: selectedNationalShippingOption,
        recipientPostalCode: nationalRecipientPostalCode,
        nationalDeliveryAddress:
            deliveryMode == StoreCartDeliveryMode.nationalShipping
                ? nationalDeliveryAddressText
                : '',
        itemsSubtotal: itemsSubtotal,
        shippingBaseValue: shippingBaseValue,
        shippingDiscount: shippingDiscount,
        shippingTotal: shippingTotal,
        orderTotal: orderTotal,
        hasPhysicalItems: hasPhysicalItems,
      ),
    );
  }

  void showCartMessage(String message) {
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
    final StoreCartStoreGroup? headerStore = firstStore;

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            StoreCartHeader(
              primaryColor: primaryColor,
              storeName: storeCount > 1
                  ? 'store_stores_in_order'.trParams({
                      'count': '$storeCount',
                    })
                  : headerStore?.storeName ?? 'store_store'.tr,
              storeLogoUrl:
                  storeCount > 1 ? '' : headerStore?.storeLogoUrl ?? '',
              onBackTap: () => Get.back(),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF4F6F6),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StoreCartSectionTitle(
                                title: 'store_products_in_cart'.tr),
                            const SizedBox(height: 12),
                            ...storeGroups.map((group) {
                              return StoreCartStoreGroupView(
                                group: group,
                                primaryColor: primaryColor,
                                onDecrease: decreaseQuantity,
                                onIncrease: increaseQuantity,
                                onRemove: removeItem,
                              );
                            }),
                            if (hasPhysicalItems) ...[
                              const SizedBox(height: 18),
                              StoreCartDeliverySelector(
                                primaryColor: primaryColor,
                                deliveryMode: deliveryMode,
                                storeCityLabel: primaryStoreCityLabel,
                                showPickup: canUsePickup,
                                showLokallyShipping: canUseLokallyShipping,
                                showNationalShipping: canUseNationalShipping,
                                onChanged: (value) {
                                  setState(() {
                                    deliveryMode = value;

                                    if (value == StoreCartDeliveryMode.pickup ||
                                        value ==
                                            StoreCartDeliveryMode
                                                .nationalShipping) {
                                      selectedDeliveryAddress = null;
                                    }

                                    if (value !=
                                        StoreCartDeliveryMode
                                            .nationalShipping) {
                                      nationalShippingOptions =
                                          <StoreNationalShippingOption>[];
                                      selectedNationalShippingOption = null;
                                    }
                                  });

                                  if (value ==
                                      StoreCartDeliveryMode.lokallyShipping) {
                                    loadCustomerAddresses();
                                    loadShippingPreview();
                                  } else if (value ==
                                      StoreCartDeliveryMode.nationalShipping) {
                                    loadShippingPreview();
                                  } else {
                                    clearShippingPreview();
                                  }
                                },
                              ),
                            ],
                            if (hasPhysicalItems &&
                                deliveryMode ==
                                    StoreCartDeliveryMode.lokallyShipping) ...[
                              const SizedBox(height: 18),
                              StoreCartDeliveryAddressSelector(
                                primaryColor: primaryColor,
                                selectedAddress: selectedDeliveryAddress,
                                onSelectAddress: selectDeliveryAddress,
                                onAddNewAddress: openAddNewDeliveryAddress,
                              ),
                              if (shippingPreviewError.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  shippingPreviewError,
                                  style: textMedium.copyWith(
                                    color: Colors.redAccent,
                                    fontSize: 12.2,
                                  ),
                                ),
                              ],
                            ],
                            if (hasPhysicalItems &&
                                deliveryMode ==
                                    StoreCartDeliveryMode.nationalShipping) ...[
                              const SizedBox(height: 18),
                              StoreCartNationalShippingSelector(
                                primaryColor: primaryColor,
                                cepController: nationalCepController,
                                selectedOption: selectedNationalShippingOption,
                                options: nationalShippingOptions,
                                isLoading: isShippingPreviewLoading,
                                onCalculate: loadShippingPreview,
                                onSelectOption: selectNationalShippingOption,
                              ),
                              if (shippingPreviewError.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  shippingPreviewError,
                                  style: textMedium.copyWith(
                                    color: Colors.redAccent,
                                    fontSize: 12.2,
                                  ),
                                ),
                              ],
                              if (selectedNationalShippingOption != null) ...[
                                const SizedBox(height: 18),
                                StoreCartNationalDeliveryAddressForm(
                                  primaryColor: primaryColor,
                                  recipientNameController:
                                      nationalRecipientNameController,
                                  recipientPhoneController:
                                      nationalRecipientPhoneController,
                                  cepController: nationalCepController,
                                  streetController: nationalStreetController,
                                  numberController: nationalNumberController,
                                  complementController:
                                      nationalComplementController,
                                  districtController:
                                      nationalDistrictController,
                                  cityController: nationalCityController,
                                  stateController: nationalStateController,
                                ),
                              ],
                            ],
                            const SizedBox(height: 18),
                            StoreCartPaymentSelector(
                              primaryColor: primaryColor,
                              paymentMode: paymentMode,
                              appBalance: appBalance,
                              orderTotal: orderTotal,
                              onWalletRechargeTap: openWalletRecharge,
                              onChanged: (value) {
                                setState(() {
                                  paymentMode = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    StoreCartBottomBar(
                      primaryColor: primaryColor,
                      itemsSubtotal: itemsSubtotal,
                      shippingTotal: shippingTotal,
                      orderTotal: orderTotal,
                      isShippingPreviewLoading: isShippingPreviewLoading,
                      showShippingLine: hasPhysicalItems,
                      onContinueShopping: continueShopping,
                      onCloseOrder: closeOrder,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreCartHeader extends StatelessWidget {
  final Color primaryColor;
  final String storeName;
  final String storeLogoUrl;
  final VoidCallback onBackTap;

  const StoreCartHeader({
    super.key,
    required this.primaryColor,
    required this.storeName,
    required this.storeLogoUrl,
    required this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: primaryColor,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
          StoreCartStoreLogo(
            primaryColor: primaryColor,
            logoUrl: storeLogoUrl,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              storeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textBold.copyWith(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreCartStoreLogo extends StatelessWidget {
  final Color primaryColor;
  final String logoUrl;

  const StoreCartStoreLogo({
    super.key,
    required this.primaryColor,
    required this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: logoUrl.isEmpty
            ? Icon(
                Icons.storefront_rounded,
                color: primaryColor,
                size: 24,
              )
            : Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Icon(
                    Icons.storefront_rounded,
                    color: primaryColor,
                    size: 24,
                  );
                },
              ),
      ),
    );
  }
}

class StoreCartSectionTitle extends StatelessWidget {
  final String title;

  const StoreCartSectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title.tr,
      style: textBold.copyWith(
        color: Colors.black87,
        fontSize: 18,
      ),
    );
  }
}

class StoreCartStoreGroupView extends StatelessWidget {
  final StoreCartStoreGroup group;
  final Color primaryColor;
  final ValueChanged<StoreCartItemData> onDecrease;
  final ValueChanged<StoreCartItemData> onIncrease;
  final ValueChanged<StoreCartItemData> onRemove;

  const StoreCartStoreGroupView({
    super.key,
    required this.group,
    required this.primaryColor,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.storeName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 10),
          ...group.items.map((item) {
            return StoreCartItemRow(
              item: item,
              primaryColor: primaryColor,
              onDecrease: () => onDecrease(item),
              onIncrease: () => onIncrease(item),
              onRemove: () => onRemove(item),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'store_this_store_total'.tr,
                  style: textMedium.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 12.8,
                  ),
                ),
              ),
              Text(
                StoreCartCurrency.format(group.subtotal),
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StoreCartItemRow extends StatelessWidget {
  final StoreCartItemData item;
  final Color primaryColor;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  const StoreCartItemRow({
    super.key,
    required this.item,
    required this.primaryColor,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 72,
              height: 72,
              child: item.product.mainImageUrl.isEmpty
                  ? Container(
                      color: primaryColor.withValues(alpha: 0.08),
                      child: Icon(
                        Icons.image_outlined,
                        color: primaryColor,
                        size: 26,
                      ),
                    )
                  : Image.network(
                      item.product.mainImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: primaryColor.withValues(alpha: 0.08),
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: primaryColor,
                            size: 26,
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 14,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  StoreCartCurrency.format(item.product.finalPrice),
                  style: textBold.copyWith(
                    color: primaryColor,
                    fontSize: 14.2,
                  ),
                ),
                if (item.product.isService) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.product.serviceDeliverySummary.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textMedium.copyWith(
                      color: Colors.grey.shade700,
                      fontSize: 11.6,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    StoreCartQuantityButton(
                      icon: Icons.remove_rounded,
                      primaryColor: primaryColor,
                      onTap: onDecrease,
                    ),
                    SizedBox(
                      width: 34,
                      child: Text(
                        item.quantity.toString(),
                        textAlign: TextAlign.center,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    StoreCartQuantityButton(
                      icon: Icons.add_rounded,
                      primaryColor: primaryColor,
                      onTap: onIncrease,
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onRemove,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            StoreCartCurrency.format(item.total),
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 13.6,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreCartQuantityButton extends StatelessWidget {
  final IconData icon;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreCartQuantityButton({
    super.key,
    required this.icon,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: primaryColor,
          size: 18,
        ),
      ),
    );
  }
}

class StoreCartDeliverySelector extends StatelessWidget {
  final Color primaryColor;
  final StoreCartDeliveryMode deliveryMode;
  final String storeCityLabel;
  final bool showPickup;
  final bool showLokallyShipping;
  final bool showNationalShipping;
  final ValueChanged<StoreCartDeliveryMode> onChanged;

  const StoreCartDeliverySelector({
    super.key,
    required this.primaryColor,
    required this.deliveryMode,
    required this.storeCityLabel,
    required this.showPickup,
    required this.showLokallyShipping,
    required this.showNationalShipping,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> options = <Widget>[];

    if (showPickup) {
      options.add(
        StoreCartSelectableLine(
          primaryColor: primaryColor,
          selected: deliveryMode == StoreCartDeliveryMode.pickup,
          title: 'store_free_pickup'.tr,
          description: 'store_pickup_description'.trParams({
            'city': storeCityLabel,
          }),
          onTap: () => onChanged(StoreCartDeliveryMode.pickup),
        ),
      );
    }

    if (showLokallyShipping) {
      if (options.isNotEmpty) {
        options.add(const SizedBox(height: 10));
      }

      options.add(
        StoreCartSelectableLine(
          primaryColor: primaryColor,
          selected: deliveryMode == StoreCartDeliveryMode.lokallyShipping,
          title: 'Lokally Envios',
          description: 'store_lokally_shipping_description'.trParams({
            'city': storeCityLabel,
          }),
          onTap: () => onChanged(StoreCartDeliveryMode.lokallyShipping),
        ),
      );
    }

    if (showNationalShipping) {
      if (options.isNotEmpty) {
        options.add(const SizedBox(height: 10));
      }

      options.add(
        StoreCartSelectableLine(
          primaryColor: primaryColor,
          selected: deliveryMode == StoreCartDeliveryMode.nationalShipping,
          title: 'Lokally Envios BR',
          description: 'store_lokally_shipping_br_description'.tr,
          onTap: () => onChanged(StoreCartDeliveryMode.nationalShipping),
        ),
      );
    }

    if (options.isEmpty) {
      options.add(
        Text(
          'store_no_delivery_option_active'.tr,
          style: textRegular.copyWith(
            color: Colors.grey.shade700,
            fontSize: 12.5,
            height: 1.3,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StoreCartSectionTitle(title: 'store_delivery_options'.tr),
        const SizedBox(height: 10),
        ...options,
      ],
    );
  }
}

class StoreCartDeliveryAddressSelector extends StatelessWidget {
  final Color primaryColor;
  final Address? selectedAddress;
  final ValueChanged<Address> onSelectAddress;
  final VoidCallback onAddNewAddress;

  const StoreCartDeliveryAddressSelector({
    super.key,
    required this.primaryColor,
    required this.selectedAddress,
    required this.onSelectAddress,
    required this.onAddNewAddress,
  });

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AddressController>()) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StoreCartSectionTitle(title: 'store_delivery_address'.tr),
          const SizedBox(height: 10),
          StoreCartAddressAddButton(
            primaryColor: primaryColor,
            onTap: onAddNewAddress,
          ),
        ],
      );
    }

    return GetBuilder<AddressController>(
      builder: (addressController) {
        final List<Address> addresses =
            addressController.addressList ?? <Address>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StoreCartSectionTitle(title: 'store_delivery_address'.tr),
            const SizedBox(height: 10),
            if (addresses.isEmpty) ...[
              Text(
                'store_choose_or_add_delivery_address'.tr,
                style: textRegular.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 12.5,
                  height: 1.30,
                ),
              ),
              const SizedBox(height: 10),
              StoreCartAddressAddButton(
                primaryColor: primaryColor,
                onTap: onAddNewAddress,
              ),
            ] else ...[
              ...addresses.map((address) {
                final bool selected =
                    selectedAddress?.id?.toString() == address.id?.toString();

                return StoreCartAddressOption(
                  primaryColor: primaryColor,
                  address: address,
                  selected: selected,
                  onTap: () => onSelectAddress(address),
                );
              }),
              const SizedBox(height: 10),
              StoreCartAddressAddButton(
                primaryColor: primaryColor,
                onTap: onAddNewAddress,
              ),
            ],
          ],
        );
      },
    );
  }
}

class StoreCartAddressOption extends StatelessWidget {
  final Color primaryColor;
  final Address address;
  final bool selected;
  final VoidCallback onTap;

  const StoreCartAddressOption({
    super.key,
    required this.primaryColor,
    required this.address,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String rawLabel = '${address.addressLabel ?? ''}'.trim();
    final String label = rawLabel.isEmpty ? 'store_address'.tr : rawLabel.tr;
    final String addressText = address.address ?? '';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: selected ? primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: selected ? primaryColor : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textBold.copyWith(
                      color: selected ? primaryColor : Colors.black87,
                      fontSize: 14.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    addressText,
                    style: textRegular.copyWith(
                      color: Colors.grey.shade700,
                      fontSize: 12.2,
                      height: 1.28,
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

class StoreCartAddressAddButton extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreCartAddressAddButton({
    super.key,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: BorderSide(color: primaryColor),
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(
        'store_add_new_address'.tr,
        style: textBold.copyWith(
          color: primaryColor,
          fontSize: 12.6,
        ),
      ),
    );
  }
}

class StoreCartNationalShippingSelector extends StatelessWidget {
  final Color primaryColor;
  final TextEditingController cepController;
  final StoreNationalShippingOption? selectedOption;
  final List<StoreNationalShippingOption> options;
  final bool isLoading;
  final VoidCallback onCalculate;
  final ValueChanged<StoreNationalShippingOption> onSelectOption;

  const StoreCartNationalShippingSelector({
    super.key,
    required this.primaryColor,
    required this.cepController,
    required this.selectedOption,
    required this.options,
    required this.isLoading,
    required this.onCalculate,
    required this.onSelectOption,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StoreCartSectionTitle(title: 'store_calculate_national_shipping'.tr),
        const SizedBox(height: 6),
        Text(
          'store_calculate_national_shipping_description'.tr,
          style: textRegular.copyWith(
            color: Colors.grey.shade700,
            fontSize: 12.2,
            height: 1.28,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: cepController,
                keyboardType: TextInputType.number,
                maxLength: 9,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'store_enter_delivery_zipcode'.tr,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                ),
                style: textMedium.copyWith(
                  color: Colors.black87,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: isLoading ? null : onCalculate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'store_calculate'.tr,
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 12.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
        if (options.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...options.map((option) {
            final bool selected =
                selectedOption?.serviceCode == option.serviceCode &&
                    selectedOption?.price == option.price;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StoreCartSelectableLine(
                primaryColor: primaryColor,
                selected: selected,
                title: option.displayName,
                description: option.deliveryDescription,
                onTap: () => onSelectOption(option),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class StoreCartNationalDeliveryAddressForm extends StatelessWidget {
  final Color primaryColor;
  final TextEditingController recipientNameController;
  final TextEditingController recipientPhoneController;
  final TextEditingController cepController;
  final TextEditingController streetController;
  final TextEditingController numberController;
  final TextEditingController complementController;
  final TextEditingController districtController;
  final TextEditingController cityController;
  final TextEditingController stateController;

  const StoreCartNationalDeliveryAddressForm({
    super.key,
    required this.primaryColor,
    required this.recipientNameController,
    required this.recipientPhoneController,
    required this.cepController,
    required this.streetController,
    required this.numberController,
    required this.complementController,
    required this.districtController,
    required this.cityController,
    required this.stateController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StoreCartSectionTitle(title: 'store_delivery_address'.tr),
        const SizedBox(height: 6),
        Text(
          'store_fill_shipping_address_description'.tr,
          style: textRegular.copyWith(
            color: Colors.grey.shade700,
            fontSize: 12.2,
            height: 1.28,
          ),
        ),
        const SizedBox(height: 12),
        StoreCartNationalAddressTextField(
          controller: recipientNameController,
          primaryColor: primaryColor,
          label: 'store_recipient_name'.tr,
          hintText: 'store_who_will_receive_order'.tr,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 10),
        StoreCartNationalAddressTextField(
          controller: recipientPhoneController,
          primaryColor: primaryColor,
          label: 'store_recipient_phone'.tr,
          hintText: 'store_phone_area_code_hint'.tr,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        StoreCartNationalAddressTextField(
          controller: cepController,
          primaryColor: primaryColor,
          label: 'store_zipcode'.tr,
          hintText: 'store_shipping_zipcode_hint'.tr,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          maxLength: 9,
        ),
        const SizedBox(height: 10),
        StoreCartNationalAddressTextField(
          controller: streetController,
          primaryColor: primaryColor,
          label: 'store_street_or_avenue'.tr,
          hintText: 'store_street_example'.tr,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: StoreCartNationalAddressTextField(
                controller: numberController,
                primaryColor: primaryColor,
                label: 'store_number'.tr,
                hintText: '1114',
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: StoreCartNationalAddressTextField(
                controller: complementController,
                primaryColor: primaryColor,
                label: 'store_complement'.tr,
                hintText: 'store_optional'.tr,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StoreCartNationalAddressTextField(
          controller: districtController,
          primaryColor: primaryColor,
          label: 'store_district'.tr,
          hintText: 'store_district_example'.tr,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: StoreCartNationalAddressTextField(
                controller: cityController,
                primaryColor: primaryColor,
                label: 'store_city'.tr,
                hintText: 'store_city_example'.tr,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StoreCartNationalAddressTextField(
                controller: stateController,
                primaryColor: primaryColor,
                label: 'store_state_abbreviation'.tr,
                hintText: 'MG',
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class StoreCartNationalAddressTextField extends StatelessWidget {
  final TextEditingController controller;
  final Color primaryColor;
  final String label;
  final String hintText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final int? maxLength;

  const StoreCartNationalAddressTextField({
    super.key,
    required this.controller,
    required this.primaryColor,
    required this.label,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.tr,
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 12.8,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLength: maxLength,
          decoration: InputDecoration(
            counterText: '',
            hintText: hintText.tr,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primaryColor),
            ),
          ),
          style: textMedium.copyWith(
            color: Colors.black87,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class StoreCartPaymentSelector extends StatelessWidget {
  final Color primaryColor;
  final StoreCartPaymentMode paymentMode;
  final double appBalance;
  final double orderTotal;
  final VoidCallback onWalletRechargeTap;
  final ValueChanged<StoreCartPaymentMode> onChanged;

  const StoreCartPaymentSelector({
    super.key,
    required this.primaryColor,
    required this.paymentMode,
    required this.appBalance,
    required this.orderTotal,
    required this.onWalletRechargeTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasEnoughBalance = appBalance >= orderTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StoreCartSectionTitle(title: 'store_payment'.tr),
        const SizedBox(height: 10),
        StoreCartSelectableContentLine(
          primaryColor: primaryColor,
          selected: paymentMode == StoreCartPaymentMode.appBalance,
          title: 'store_pay_in_app_with_balance'.tr,
          onTap: () => onChanged(StoreCartPaymentMode.appBalance),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'store_balance_available_for_order'.trParams({
                  'value': StoreCartCurrency.format(appBalance),
                }),
                style: textRegular.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 12.2,
                  height: 1.28,
                ),
              ),
              if (!hasEnoughBalance) ...[
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'store_insufficient_balance_prefix'.tr,
                        style: textRegular.copyWith(
                          color: Colors.grey.shade700,
                          fontSize: 12.2,
                          height: 1.28,
                        ),
                      ),
                      TextSpan(
                        text: 'store_clicking_here'.tr,
                        style: textBold.copyWith(
                          color: primaryColor,
                          fontSize: 12.2,
                          height: 1.28,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = onWalletRechargeTap,
                      ),
                      TextSpan(
                        text: 'store_or_select_another_payment'.tr,
                        style: textRegular.copyWith(
                          color: Colors.grey.shade700,
                          fontSize: 12.2,
                          height: 1.28,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        StoreCartSelectableLine(
          primaryColor: primaryColor,
          selected: paymentMode == StoreCartPaymentMode.mercadoPago,
          title: 'store_pay_with_mercado_pago'.tr,
          description: 'store_pay_with_mercado_pago_description'.tr,
          onTap: () => onChanged(StoreCartPaymentMode.mercadoPago),
        ),
      ],
    );
  }
}

class StoreCartSelectableContentLine extends StatelessWidget {
  final Color primaryColor;
  final bool selected;
  final String title;
  final Widget content;
  final VoidCallback onTap;

  const StoreCartSelectableContentLine({
    super.key,
    required this.primaryColor,
    required this.selected,
    required this.title,
    required this.content,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: selected ? primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: selected ? primaryColor : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.tr,
                  style: textBold.copyWith(
                    color: selected ? primaryColor : Colors.black87,
                    fontSize: 14.2,
                  ),
                ),
                const SizedBox(height: 3),
                content,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StoreCartSelectableLine extends StatelessWidget {
  final Color primaryColor;
  final bool selected;
  final String title;
  final String description;
  final VoidCallback onTap;

  const StoreCartSelectableLine({
    super.key,
    required this.primaryColor,
    required this.selected,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: selected ? primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: selected ? primaryColor : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.tr,
                  style: textBold.copyWith(
                    color: selected ? primaryColor : Colors.black87,
                    fontSize: 14.2,
                  ),
                ),
                const SizedBox(height: 3),
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
        ],
      ),
    );
  }
}

class StoreCartRulesSummary extends StatelessWidget {
  final Color primaryColor;
  final int storeCount;
  final double itemsSubtotal;
  final double shippingBaseValue;
  final double shippingDiscount;
  final double shippingTotal;
  final StoreCartDeliveryMode deliveryMode;

  const StoreCartRulesSummary({
    super.key,
    required this.primaryColor,
    required this.storeCount,
    required this.itemsSubtotal,
    required this.shippingBaseValue,
    required this.shippingDiscount,
    required this.shippingTotal,
    required this.deliveryMode,
  });

  @override
  Widget build(BuildContext context) {
    if (deliveryMode == StoreCartDeliveryMode.pickup) {
      return Text(
        'store_pickup_rules_summary'.tr,
        style: textRegular.copyWith(
          color: Colors.grey.shade700,
          fontSize: 12.4,
          height: 1.32,
        ),
      );
    }

    final bool hasSingleStoreFreeShipping =
        storeCount == 1 && itemsSubtotal >= 200;
    final bool hasMultiStoreDiscount =
        storeCount >= 2 && itemsSubtotal >= 200 && shippingDiscount > 0;

    String message = 'store_shipping_rules_summary'.tr;

    if (hasSingleStoreFreeShipping) {
      message = 'store_free_shipping_applied_summary'.tr;
    } else if (hasMultiStoreDiscount) {
      message = 'store_shipping_discount_applied_summary'.tr;
    }

    return Text(
      message,
      style: textRegular.copyWith(
        color: Colors.grey.shade700,
        fontSize: 12.4,
        height: 1.32,
      ),
    );
  }
}

class StoreCartBottomBar extends StatelessWidget {
  final Color primaryColor;
  final double itemsSubtotal;
  final double shippingTotal;
  final double orderTotal;
  final bool isShippingPreviewLoading;
  final bool showShippingLine;
  final VoidCallback onContinueShopping;
  final VoidCallback onCloseOrder;

  const StoreCartBottomBar({
    super.key,
    required this.primaryColor,
    required this.itemsSubtotal,
    required this.shippingTotal,
    required this.orderTotal,
    required this.isShippingPreviewLoading,
    required this.showShippingLine,
    required this.onContinueShopping,
    required this.onCloseOrder,
  });

  @override
  Widget build(BuildContext context) {
    final String shippingText = isShippingPreviewLoading
        ? 'store_calculating'.tr
        : shippingTotal <= 0
            ? 'store_free'.tr
            : StoreCartCurrency.format(shippingTotal);

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, -8),
              blurRadius: 24,
              color: Colors.black.withValues(alpha: 0.10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StoreCartTotalLine(
              label: 'store_products'.tr,
              value: StoreCartCurrency.format(itemsSubtotal),
            ),
            if (showShippingLine) ...[
              const SizedBox(height: 5),
              StoreCartTotalLine(
                label: 'store_delivery'.tr,
                value: shippingText,
              ),
            ],
            const SizedBox(height: 7),
            StoreCartTotalLine(
              label: 'store_order_total'.tr,
              value: StoreCartCurrency.format(orderTotal),
              primaryColor: primaryColor,
              highlight: true,
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onContinueShopping,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      minimumSize: const Size(0, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: Text(
                      'store_continue_shopping'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: textBold.copyWith(
                        color: primaryColor,
                        fontSize: 12.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onCloseOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 45),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: Text(
                      'store_close_order'.tr,
                      style: textBold.copyWith(
                        color: Colors.white,
                        fontSize: 12.7,
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
  }
}

class StoreCartTotalLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? primaryColor;
  final bool highlight;

  const StoreCartTotalLine({
    super.key,
    required this.label,
    required this.value,
    this.primaryColor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label.tr,
            style: (highlight ? textBold : textMedium).copyWith(
              color: Colors.black87,
              fontSize: highlight ? 14.5 : 12.8,
            ),
          ),
        ),
        Text(
          value,
          style: textBold.copyWith(
            color: highlight ? primaryColor : Colors.black87,
            fontSize: highlight ? 16.5 : 13.2,
          ),
        ),
      ],
    );
  }
}

class StoreCheckoutScreen extends StatefulWidget {
  final List<StoreCartItemData> cartItems;
  final StoreCartDeliveryMode deliveryMode;
  final StoreCartPaymentMode paymentMode;
  final Address? deliveryAddress;
  final StoreNationalShippingOption? selectedNationalShippingOption;
  final String recipientPostalCode;
  final String nationalDeliveryAddress;
  final double itemsSubtotal;
  final double shippingBaseValue;
  final double shippingDiscount;
  final double shippingTotal;
  final double orderTotal;
  final bool hasPhysicalItems;

  const StoreCheckoutScreen({
    super.key,
    required this.cartItems,
    required this.deliveryMode,
    required this.paymentMode,
    required this.deliveryAddress,
    required this.selectedNationalShippingOption,
    required this.recipientPostalCode,
    required this.nationalDeliveryAddress,
    required this.itemsSubtotal,
    required this.shippingBaseValue,
    required this.shippingDiscount,
    required this.shippingTotal,
    required this.orderTotal,
    required this.hasPhysicalItems,
  });

  @override
  State<StoreCheckoutScreen> createState() => _StoreCheckoutScreenState();
}

class _StoreCheckoutScreenState extends State<StoreCheckoutScreen> {
  bool paymentApproved = false;
  bool isSubmittingOrder = false;
  late final String fallbackOrderNumber =
      StoreMarketplaceOrderNumber.generate();
  List<Map<String, dynamic>> backendOrders = <Map<String, dynamic>>[];

  List<StoreCartStoreGroup> get storeGroups {
    final Map<String, StoreCartStoreGroup> groups =
        <String, StoreCartStoreGroup>{};

    for (final StoreCartItemData item in widget.cartItems) {
      final String storeKey = item.product.storeId.isEmpty
          ? item.product.storeName
          : item.product.storeId;

      groups.putIfAbsent(
        storeKey,
        () => StoreCartStoreGroup(
          storeId: item.product.storeId,
          storeName: item.product.storeName,
          storeLogoUrl: item.product.storeLogoUrl,
          items: <StoreCartItemData>[],
        ),
      );

      groups[storeKey]!.items.add(item);
    }

    return groups.values.toList();
  }

  double get checkoutShippingTotal {
    if (backendOrders.isEmpty) {
      return widget.shippingTotal;
    }

    return backendOrders.fold<double>(0, (total, order) {
      final double shippingAmount =
          StoreCartCurrency.parseDouble(order['shipping_amount']);
      final double shippingDiscount =
          StoreCartCurrency.parseDouble(order['shipping_discount']);

      final double value = shippingAmount - shippingDiscount;
      return total + (value < 0 ? 0 : value);
    });
  }

  double get checkoutOrderTotal {
    if (backendOrders.isEmpty) {
      return widget.orderTotal;
    }

    return backendOrders.fold<double>(0, (total, order) {
      return total + StoreCartCurrency.parseDouble(order['total']);
    });
  }

  String get customerName {
    if (!Get.isRegistered<ProfileController>()) {
      return 'store_customer'.tr;
    }

    return Get.find<ProfileController>().customerName().trim().isEmpty
        ? 'store_customer'.tr
        : Get.find<ProfileController>().customerName();
  }

  String get customerPhone {
    if (!Get.isRegistered<ProfileController>()) {
      return '';
    }

    return Get.find<ProfileController>().profileModel?.data?.phone ?? '';
  }

  String get paymentLabel {
    return widget.paymentMode == StoreCartPaymentMode.appBalance
        ? 'store_pay_in_app_with_balance'
        : 'store_pay_with_mercado_pago';
  }

  String get deliveryLabel {
    if (!widget.hasPhysicalItems) {
      return 'store_service';
    }

    if (widget.deliveryMode == StoreCartDeliveryMode.pickup) {
      return 'store_free_pickup';
    }

    if (widget.deliveryMode == StoreCartDeliveryMode.nationalShipping) {
      return 'Lokally Envios BR';
    }

    return 'Lokally Envios';
  }

  bool get isLokallyShipping {
    return widget.hasPhysicalItems &&
        widget.deliveryMode == StoreCartDeliveryMode.lokallyShipping;
  }

  bool get isNationalShipping {
    return widget.hasPhysicalItems &&
        widget.deliveryMode == StoreCartDeliveryMode.nationalShipping;
  }

  bool get hasFreeMarketplaceShipping {
    return isLokallyShipping && checkoutShippingTotal <= 0;
  }

  String get mainOrderNumber {
    if (backendOrders.isNotEmpty) {
      return '${backendOrders.first['order_number'] ?? fallbackOrderNumber}';
    }

    return fallbackOrderNumber;
  }

  String orderNumberForGroup(StoreCartStoreGroup group) {
    final Map<String, dynamic>? order = backendOrderForGroup(group);

    if (order == null) {
      return mainOrderNumber;
    }

    return '${order['order_number'] ?? mainOrderNumber}';
  }

  Map<String, dynamic>? backendOrderForGroup(StoreCartStoreGroup group) {
    for (final Map<String, dynamic> order in backendOrders) {
      final dynamic sellerValue = order['seller'];
      final Map<String, dynamic> seller = sellerValue is Map
          ? Map<String, dynamic>.from(sellerValue)
          : <String, dynamic>{};

      final String sellerId = '${seller['id'] ?? ''}';
      final String sellerName = '${seller['name'] ?? ''}';

      if (sellerId == group.storeId || sellerName == group.storeName) {
        return order;
      }
    }

    return null;
  }

  Map<String, dynamic> buildOrderPayload() {
    final String deliveryType = !widget.hasPhysicalItems ||
            widget.deliveryMode == StoreCartDeliveryMode.pickup
        ? 'pickup'
        : widget.deliveryMode == StoreCartDeliveryMode.nationalShipping
            ? 'national_shipping'
            : 'lokally_shipping';

    final Map<String, dynamic> payload = <String, dynamic>{
      'delivery_type': deliveryType,
      'payment_method': widget.paymentMode == StoreCartPaymentMode.appBalance
          ? 'app_balance'
          : 'mercadopago',
      'payment_status': widget.paymentMode == StoreCartPaymentMode.appBalance
          ? 'approved'
          : 'pending',
      'delivery_address': widget.deliveryAddress?.address,
      'delivery_latitude': widget.deliveryAddress?.latitude,
      'delivery_longitude': widget.deliveryAddress?.longitude,
      'items': widget.cartItems.map((item) {
        return {
          'product_id': item.product.id,
          'quantity': item.quantity,
        };
      }).toList(),
    };

    if (deliveryType == 'national_shipping') {
      payload['delivery_address'] = widget.nationalDeliveryAddress;
      payload['delivery_latitude'] = null;
      payload['delivery_longitude'] = null;
      payload['recipient_postal_code'] = widget.recipientPostalCode;
      payload['destination_postal_code'] = widget.recipientPostalCode;
      payload['cep'] = widget.recipientPostalCode;
      payload['national_shipping_service_code'] =
          widget.selectedNationalShippingOption?.serviceCode;

      final StoreNationalShippingOption? selectedOption =
          widget.selectedNationalShippingOption;

      if (selectedOption != null && selectedOption.storeSellerId.isNotEmpty) {
        payload['national_shipping_options'] = [
          {
            'store_seller_id': selectedOption.storeSellerId,
            'service_code': selectedOption.serviceCode,
          },
        ];
      }
    }

    return payload;
  }

  Future<void> approvePayment() async {
    if (isSubmittingOrder || paymentApproved) {
      return;
    }

    if (!Get.isRegistered<ApiClient>()) {
      showCheckoutMessage('store_server_connection_error'.tr);
      return;
    }

    setState(() {
      isSubmittingOrder = true;
    });

    final Response response = await Get.find<ApiClient>().postData(
      '/api/customer/store/orders',
      buildOrderPayload(),
    );

    if (!mounted) {
      return;
    }

    final dynamic responseBody = response.body;
    final bool success =
        (response.statusCode == 200 || response.statusCode == 201) &&
            responseBody is Map &&
            responseBody['status'] == true;

    if (!success) {
      setState(() {
        isSubmittingOrder = false;
      });

      final String message = responseBody is Map
          ? '${responseBody['message'] ?? response.statusText ?? 'store_order_create_error'.tr}'
          : response.statusText ?? 'store_order_create_error'.tr;

      showCheckoutMessage(message);
      return;
    }

    final dynamic dataValue = responseBody['data'];
    final Map<String, dynamic> data = dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : <String, dynamic>{};

    final dynamic ordersValue = data['orders'];
    final List<dynamic> ordersList =
        ordersValue is List ? ordersValue : <dynamic>[];

    final dynamic paymentValue = data['payment'];
    final Map<String, dynamic> payment = paymentValue is Map
        ? Map<String, dynamic>.from(paymentValue)
        : <String, dynamic>{};

    final String paymentUrl = '${payment['payment_url'] ?? ''}';
    final bool requiresExternalPayment = payment['requires_external_payment'] ==
            true ||
        '${payment['requires_external_payment'] ?? ''}' == '1' ||
        '${payment['requires_external_payment'] ?? ''}'.toLowerCase() == 'true';

    final List<Map<String, dynamic>> parsedOrders = ordersList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (widget.paymentMode == StoreCartPaymentMode.mercadoPago ||
        requiresExternalPayment) {
      setState(() {
        backendOrders = parsedOrders;
        paymentApproved = false;
        isSubmittingOrder = false;
      });

      StoreCartSession.clear();

      if (paymentUrl.isEmpty) {
        showCheckoutMessage(
          'store_order_created_checkout_open_error'.tr,
        );
        return;
      }

      final bool? returnedFromCheckout = await Get.to(
        () => StoreMarketplaceMercadoPagoWebViewScreen(
          paymentUrl: paymentUrl,
          primaryColor: Theme.of(context).primaryColor,
        ),
      );

      if (!mounted) {
        return;
      }

      if (returnedFromCheckout == true) {
        showCheckoutMessage(
          'store_payment_sent_follow_orders'.tr,
        );
      } else {
        showCheckoutMessage(
          'store_order_created_finish_mp_payment'.tr,
        );
      }
      return;
    }

    setState(() {
      backendOrders = parsedOrders;
      paymentApproved = true;
      isSubmittingOrder = false;
    });

    StoreCartSession.clear();
  }

  void showCheckoutMessage(String message) {
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
      backgroundColor: primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            StoreCheckoutHeader(
              primaryColor: primaryColor,
              onBackTap: () => Get.back(),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF4F6F6),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StoreCheckoutSectionTitle(title: 'store_customer_data'.tr),
                      const SizedBox(height: 10),
                      StoreCheckoutSimpleLine(
                        label: 'store_order_number'.tr,
                        value: mainOrderNumber,
                        highlight: true,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 6),
                      StoreCheckoutSimpleLine(
                        label: 'store_name'.tr,
                        value: customerName,
                      ),
                      if (customerPhone.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        StoreCheckoutSimpleLine(
                          label: 'store_phone'.tr,
                          value: customerPhone,
                        ),
                      ],
                      const StoreCheckoutDivider(),
                      StoreCheckoutSectionTitle(title: 'store_order_summary'.tr),
                      const SizedBox(height: 10),
                      ...storeGroups.map((group) {
                        return StoreCheckoutStoreSummary(
                          group: group,
                          primaryColor: primaryColor,
                          paymentApproved: paymentApproved,
                          deliveryMode: widget.deliveryMode,
                          hasPhysicalItems: widget.hasPhysicalItems,
                          orderNumber: orderNumberForGroup(group),
                          paymentLabel: paymentLabel,
                        );
                      }),
                      if (widget.hasPhysicalItems) ...[
                        const StoreCheckoutDivider(),
                        StoreCheckoutSectionTitle(title: 'store_delivery'.tr),
                        const SizedBox(height: 10),
                        StoreCheckoutSimpleLine(
                          label: 'store_selected_option'.tr,
                          value: deliveryLabel,
                        ),
                        if (isLokallyShipping) ...[
                          const SizedBox(height: 6),
                          StoreCheckoutSimpleLine(
                            label: 'store_delivery_address'.tr,
                            value: widget.deliveryAddress?.address ?? '-',
                          ),
                          const SizedBox(height: 6),
                          StoreCheckoutSimpleLine(
                            label: 'store_shipping'.tr,
                            value: checkoutShippingTotal <= 0
                                ? 'store_free'.tr
                                : StoreCartCurrency.format(
                                    checkoutShippingTotal,
                                  ),
                          ),
                        ],
                        if (isNationalShipping) ...[
                          const SizedBox(height: 6),
                          StoreCheckoutSimpleLine(
                            label: 'store_delivery_zipcode'.tr,
                            value: widget.recipientPostalCode,
                          ),
                          const SizedBox(height: 6),
                          StoreCheckoutMultilineInfo(
                            label: 'store_delivery_address'.tr,
                            value: widget.nationalDeliveryAddress,
                          ),
                          const SizedBox(height: 6),
                          StoreCheckoutSimpleLine(
                            label: 'store_shipping_company'.tr,
                            value: widget.selectedNationalShippingOption
                                    ?.displayName ??
                                '-',
                          ),
                          const SizedBox(height: 6),
                          StoreCheckoutSimpleLine(
                            label: 'store_shipping'.tr,
                            value: checkoutShippingTotal <= 0
                                ? 'store_free'.tr
                                : StoreCartCurrency.format(
                                    checkoutShippingTotal,
                                  ),
                          ),
                        ],
                      ],
                      const StoreCheckoutDivider(),
                      StoreCheckoutSectionTitle(title: 'store_payment'.tr),
                      const SizedBox(height: 10),
                      StoreCheckoutSimpleLine(
                        label: 'store_payment_method'.tr,
                        value: paymentLabel,
                      ),
                      const SizedBox(height: 6),
                      StoreCheckoutSimpleLine(
                        label: 'store_total'.tr,
                        value: StoreCartCurrency.format(checkoutOrderTotal),
                        highlight: true,
                        primaryColor: primaryColor,
                      ),
                      if (paymentApproved) ...[
                        const SizedBox(height: 14),
                        StoreCheckoutApprovedMessage(
                          primaryColor: primaryColor,
                          deliveryMode: widget.deliveryMode,
                          hasPhysicalItems: widget.hasPhysicalItems,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            StoreCheckoutBottomBar(
              primaryColor: primaryColor,
              paymentApproved: paymentApproved,
              isSubmittingOrder: isSubmittingOrder,
              paymentMode: widget.paymentMode,
              onPayTap: approvePayment,
            ),
          ],
        ),
      ),
    );
  }
}

class StoreCheckoutHeader extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onBackTap;

  const StoreCheckoutHeader({
    super.key,
    required this.primaryColor,
    required this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: primaryColor,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
              'store_checkout'.tr,
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

class StoreCheckoutSectionTitle extends StatelessWidget {
  final String title;

  const StoreCheckoutSectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title.tr,
      style: textBold.copyWith(
        color: Colors.black87,
        fontSize: 18,
      ),
    );
  }
}

class StoreCheckoutSimpleLine extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final Color? primaryColor;

  const StoreCheckoutSimpleLine({
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

class StoreCheckoutMultilineInfo extends StatelessWidget {
  final String label;
  final String value;

  const StoreCheckoutMultilineInfo({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.tr,
          style: textMedium.copyWith(
            color: Colors.grey.shade700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            value.isEmpty ? '-' : value,
            style: textMedium.copyWith(
              color: Colors.black87,
              fontSize: 12.6,
              height: 1.28,
            ),
          ),
        ),
      ],
    );
  }
}

class StoreCheckoutStoreSummary extends StatelessWidget {
  final StoreCartStoreGroup group;
  final Color primaryColor;
  final bool paymentApproved;
  final StoreCartDeliveryMode deliveryMode;
  final bool hasPhysicalItems;
  final String orderNumber;
  final String paymentLabel;

  const StoreCheckoutStoreSummary({
    super.key,
    required this.group,
    required this.primaryColor,
    required this.paymentApproved,
    required this.deliveryMode,
    required this.hasPhysicalItems,
    required this.orderNumber,
    required this.paymentLabel,
  });

  bool get isLokallyShipping {
    return hasPhysicalItems &&
        deliveryMode == StoreCartDeliveryMode.lokallyShipping;
  }

  bool get isNationalShipping {
    return hasPhysicalItems &&
        deliveryMode == StoreCartDeliveryMode.nationalShipping;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StoreCartStoreLogo(
                primaryColor: primaryColor,
                logoUrl: group.storeLogoUrl,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group.storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                StoreCartCurrency.format(group.subtotal),
                style: textBold.copyWith(
                  color: primaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...group.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: StoreCheckoutSimpleLine(
                label: '${item.quantity}x ${item.product.title}',
                value: StoreCartCurrency.format(item.total),
              ),
            );
          }),
          if (paymentApproved && hasPhysicalItems) ...[
            const SizedBox(height: 10),
            if (isNationalShipping)
              StoreCheckoutNationalShippingInfo(primaryColor: primaryColor)
            else if (isLokallyShipping)
              StoreCheckoutLokallyShippingInfo(primaryColor: primaryColor)
            else
              StoreCheckoutPickupInfo(
                group: group,
                orderNumber: orderNumber,
                paymentLabel: paymentLabel,
                primaryColor: primaryColor,
              ),
          ],
        ],
      ),
    );
  }
}

class StoreCheckoutPickupInfo extends StatelessWidget {
  final StoreCartStoreGroup group;
  final String orderNumber;
  final String paymentLabel;
  final Color primaryColor;

  const StoreCheckoutPickupInfo({
    super.key,
    required this.group,
    required this.orderNumber,
    required this.paymentLabel,
    required this.primaryColor,
  });

  String get whatsappPhone {
    final String onlyNumbers = group.storePhone.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (onlyNumbers.isEmpty) {
      return '';
    }

    if (onlyNumbers.startsWith('55')) {
      return onlyNumbers;
    }

    if (onlyNumbers.length == 10 || onlyNumbers.length == 11) {
      return '55$onlyNumbers';
    }

    return onlyNumbers;
  }

  String get whatsappMessage {
    final String productsText = group.items.map((item) {
      final String photoText = item.product.mainImageUrl.isNotEmpty
          ? '\nFoto: ${item.product.mainImageUrl}'
          : '';

      return '- ${item.quantity}x ${item.product.title}'
          '$photoText'
          '\n${'store_unit_price_with_value'.trParams({
            'value': StoreCartCurrency.format(item.product.finalPrice),
          })}'
          '\n${'store_item_total_with_value'.trParams({
            'value': StoreCartCurrency.format(item.total),
          })}';
    }).join('\n\n');

    return 'store_pickup_whatsapp_message'.trParams({
      'store': group.storeName,
      'order': orderNumber,
      'payment': paymentLabel.tr,
      'total': StoreCartCurrency.format(group.subtotal),
      'products': productsText,
    });
  }

  Future<void> openWhatsApp(BuildContext context) async {
    if (whatsappPhone.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'store_shop_whatsapp_unavailable'.tr,
            style: textMedium.copyWith(
              color: Colors.white,
              fontSize: 12.8,
            ),
          ),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      return;
    }

    final Uri url = Uri.parse(
      'https://wa.me/$whatsappPhone?text=${Uri.encodeComponent(whatsappMessage)}',
    );

    final bool opened = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'store_shop_whatsapp_open_error'.tr,
            style: textMedium.copyWith(
              color: Colors.white,
              fontSize: 12.8,
            ),
          ),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAddress = group.storeAddress.isNotEmpty;
    final bool hasPhone = group.storePhone.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'store_pickup_released'.tr,
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'store_show_order_to_seller_on_pickup'.trParams({
            'order': orderNumber,
          }),
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 12.5,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'store_pickup_business_hours'.tr,
          style: textRegular.copyWith(
            color: Colors.grey.shade700,
            fontSize: 12.5,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hasAddress
              ? group.storeAddress
              : 'store_pickup_address_sent_by_store'.tr,
          style: textRegular.copyWith(
            color: Colors.grey.shade700,
            fontSize: 12.5,
            height: 1.25,
          ),
        ),
        if (hasPhone) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: () => openWhatsApp(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'store_contact_store_whatsapp'.tr,
                style: textBold.copyWith(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class StoreCheckoutLokallyShippingInfo extends StatelessWidget {
  final Color primaryColor;

  const StoreCheckoutLokallyShippingInfo({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      'store_order_approved_lokally_shipping_info'.tr,
      style: textBold.copyWith(
        color: primaryColor,
        fontSize: 13.2,
        height: 1.25,
      ),
    );
  }
}

class StoreCheckoutNationalShippingInfo extends StatelessWidget {
  final Color primaryColor;

  const StoreCheckoutNationalShippingInfo({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      'store_order_approved_national_shipping_info'.tr,
      style: textBold.copyWith(
        color: primaryColor,
        fontSize: 13.2,
        height: 1.25,
      ),
    );
  }
}

class StoreCheckoutApprovedMessage extends StatelessWidget {
  final Color primaryColor;
  final StoreCartDeliveryMode deliveryMode;
  final bool hasPhysicalItems;

  const StoreCheckoutApprovedMessage({
    super.key,
    required this.primaryColor,
    required this.deliveryMode,
    required this.hasPhysicalItems,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      !hasPhysicalItems
          ? 'store_payment_approved_service_info_sent'.tr
          : deliveryMode == StoreCartDeliveryMode.pickup
              ? 'store_payment_approved_pickup_info_released'.tr
              : deliveryMode == StoreCartDeliveryMode.nationalShipping
                  ? 'store_payment_approved_national_shipping'.tr
                  : 'store_payment_approved_lokally_shipping'.tr,
      style: textBold.copyWith(
        color: primaryColor,
        fontSize: 13.2,
        height: 1.25,
      ),
    );
  }
}

class StoreCheckoutDivider extends StatelessWidget {
  const StoreCheckoutDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(
        height: 1,
        width: double.infinity,
        color: Colors.black.withValues(alpha: 0.08),
      ),
    );
  }
}

class StoreCheckoutBottomBar extends StatelessWidget {
  final Color primaryColor;
  final bool paymentApproved;
  final bool isSubmittingOrder;
  final StoreCartPaymentMode paymentMode;
  final Future<void> Function() onPayTap;

  const StoreCheckoutBottomBar({
    super.key,
    required this.primaryColor,
    required this.paymentApproved,
    required this.isSubmittingOrder,
    required this.paymentMode,
    required this.onPayTap,
  });

  @override
  Widget build(BuildContext context) {
    if (paymentApproved) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: Colors.white,
          child: Text(
            'store_order_approved'.tr,
            textAlign: TextAlign.center,
            style: textBold.copyWith(
              color: primaryColor,
              fontSize: 14.5,
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        color: Colors.white,
        child: SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: isSubmittingOrder ? null : () => onPayTap(),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
            child: isSubmittingOrder
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    paymentMode == StoreCartPaymentMode.appBalance
                        ? 'store_pay_with_balance'.tr
                        : 'store_pay_with_mercado_pago'.tr,
                    style: textBold.copyWith(
                      color: Colors.white,
                      fontSize: 13.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class StoreMarketplaceMercadoPagoWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final Color primaryColor;

  const StoreMarketplaceMercadoPagoWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.primaryColor,
  });

  @override
  State<StoreMarketplaceMercadoPagoWebViewScreen> createState() =>
      _StoreMarketplaceMercadoPagoWebViewScreenState();
}

class _StoreMarketplaceMercadoPagoWebViewScreenState
    extends State<StoreMarketplaceMercadoPagoWebViewScreen> {
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

class StoreMarketplaceOrderNumber {
  static String generate() {
    final DateTime now = DateTime.now();
    final String year = now.year.toString();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    final String hour = now.hour.toString().padLeft(2, '0');
    final String minute = now.minute.toString().padLeft(2, '0');
    final String second = now.second.toString().padLeft(2, '0');

    return 'LOK-$year$month$day-$hour$minute$second';
  }
}

class StoreCartProductData {
  final String id;
  final String sellerId;
  final String title;
  final double finalPrice;
  final String mainImageUrl;
  final String storeId;
  final String storeName;
  final String storeLogoUrl;
  final String storeAddress;
  final String storePhone;
  final String storeEmail;
  final String storeCity;
  final String storeState;
  final bool allowPickup;
  final bool allowLokallyShipping;
  final bool allowNationalShipping;
  final String productType;
  final String serviceDeliveryType;

  StoreCartProductData({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.finalPrice,
    required this.mainImageUrl,
    required this.storeId,
    required this.storeName,
    required this.storeLogoUrl,
    required this.storeAddress,
    required this.storePhone,
    required this.storeEmail,
    required this.storeCity,
    required this.storeState,
    required this.allowPickup,
    required this.allowLokallyShipping,
    required this.allowNationalShipping,
    required this.productType,
    required this.serviceDeliveryType,
  });

  factory StoreCartProductData.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> store = map['store'] is Map
        ? Map<String, dynamic>.from(map['store'])
        : <String, dynamic>{};

    final String sellerId = '${map['seller_id'] ?? ''}';
    final String storeId = '${store['id'] ?? sellerId}';
    final bool hasAnyDeliveryFlag = map.containsKey('allow_pickup') ||
        map.containsKey('allow_lokally_shipping') ||
        map.containsKey('allow_national_shipping') ||
        map.containsKey('delivery_immediate') ||
        map.containsKey('delivery_full_24h') ||
        map.containsKey('delivery_lokally_br');

    final bool allowPickup = hasAnyDeliveryFlag
        ? parseBool(map['allow_pickup'] ?? map['delivery_immediate'])
        : true;
    final bool allowLokallyShipping = hasAnyDeliveryFlag
        ? parseBool(map['allow_lokally_shipping'] ?? map['delivery_full_24h'])
        : true;
    final bool allowNationalShipping = parseBool(
      map['allow_national_shipping'] ??
          map['delivery_lokally_br'] ??
          map['national_shipping_enabled'] ??
          store['national_shipping_enabled'],
    );

    final String storeCity = firstNotEmpty(<dynamic>[
      store['shipping_origin_city'],
      store['origin_city'],
      store['city'],
      store['city_name'],
      map['shipping_origin_city'],
      map['seller_shipping_origin_city'],
      map['store_shipping_origin_city'],
      map['store_city'],
      map['seller_city'],
      map['origin_city'],
      map['city'],
    ]);

    final String storeState = firstNotEmpty(<dynamic>[
      store['shipping_origin_state'],
      store['origin_state'],
      store['state'],
      map['shipping_origin_state'],
      map['seller_shipping_origin_state'],
      map['store_shipping_origin_state'],
      map['store_state'],
      map['seller_state'],
      map['origin_state'],
      map['state'],
    ]);

    return StoreCartProductData(
      id: '${map['id'] ?? ''}',
      sellerId: sellerId,
      title: '${map['name'] ?? ''}',
      finalPrice: StoreCartCurrency.parseDouble(
        map['final_price'] ?? map['price'],
      ),
      mainImageUrl: '${map['main_image_url'] ?? ''}',
      storeId: storeId,
      storeName: '${store['name'] ?? 'store_store'.tr}',
      storeLogoUrl: '${store['logo_url'] ?? ''}',
      storeAddress:
          '${store['address'] ?? store['store_address'] ?? store['full_address'] ?? ''}',
      storePhone:
          '${store['phone'] ?? store['contact_phone'] ?? store['business_phone'] ?? store['mobile'] ?? ''}',
      storeEmail: '${store['email'] ?? store['business_email'] ?? ''}',
      storeCity: storeCity,
      storeState: storeState,
      allowPickup: allowPickup,
      allowLokallyShipping: allowLokallyShipping,
      allowNationalShipping: allowNationalShipping,
      productType: '${map['product_type'] ?? ''}'.trim().toLowerCase(),
      serviceDeliveryType:
          '${map['service_delivery_type'] ?? ''}'.trim().toLowerCase(),
    );
  }

  String get storeCityLabel {
    if (storeCity.isNotEmpty && storeState.isNotEmpty) {
      return '$storeCity - $storeState';
    }

    if (storeCity.isNotEmpty) {
      return storeCity;
    }

    return storeState;
  }

  static bool parseBool(dynamic value) {
    if (value == null) {
      return false;
    }

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
        normalized == 'yes' ||
        normalized == 'ativo' ||
        normalized == 'active';
  }

  static String firstNotEmpty(List<dynamic> values) {
    for (final dynamic value in values) {
      final String text = '$value'.trim();

      if (text.isNotEmpty && text != 'null') {
        return text;
      }
    }

    return '';
  }

  bool get isService {
    if (productType == 'service') {
      return true;
    }

    final String text = '$title $serviceDeliveryType'.toLowerCase();
    return text.contains('serviÃ§o') ||
        text.contains('redes sociais') ||
        text.contains('marketing digital') ||
        text.contains('online') ||
        text.contains('download') ||
        text.contains('presencial') ||
        text.contains('home office');
  }

  String get serviceDeliveryLabel {
    switch (serviceDeliveryType) {
      case 'download':
        return 'store_download';
      case 'presential':
      case 'presencial':
        return 'store_presential';
      case 'home_office':
      case 'homeoffice':
        return 'store_home_office';
      case 'online':
      case 'digital':
      default:
        return 'store_online';
    }
  }

  String get serviceDeliverySummary {
    switch (serviceDeliveryType) {
      case 'download':
        return 'store_format_download';
      case 'presential':
      case 'presencial':
        return 'store_format_presential';
      case 'home_office':
      case 'homeoffice':
        return 'store_format_home_office';
      case 'online':
      case 'digital':
      default:
        return 'store_format_online';
    }
  }

  String get cartKey {
    if (id.isNotEmpty) {
      return id;
    }

    return '$storeId:$title';
  }
}

class StoreCartItemData {
  final StoreCartProductData product;
  int quantity;

  StoreCartItemData({
    required this.product,
    required this.quantity,
  });

  double get total => product.finalPrice * quantity;
}

class StoreCartStoreGroup {
  final String storeId;
  final String storeName;
  final String storeLogoUrl;
  final List<StoreCartItemData> items;

  StoreCartStoreGroup({
    required this.storeId,
    required this.storeName,
    required this.storeLogoUrl,
    required this.items,
  });

  double get subtotal {
    return items.fold<double>(
      0,
      (total, item) => total + item.total,
    );
  }

  StoreCartProductData? get firstProduct {
    if (items.isEmpty) {
      return null;
    }

    return items.first.product;
  }

  String get storeAddress => firstProduct?.storeAddress ?? '';

  String get storePhone => firstProduct?.storePhone ?? '';

  String get storeEmail => firstProduct?.storeEmail ?? '';

  String get storeCity => firstProduct?.storeCity ?? '';

  String get storeState => firstProduct?.storeState ?? '';
}

class StoreCartCurrency {
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

