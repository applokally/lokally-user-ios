import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/address/controllers/address_controller.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/address/screens/add_new_address.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/wallet/screens/wallet_screen.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:url_launcher/url_launcher.dart';

enum StoreCartDeliveryMode {
  pickup,
  lokallyShipping,
}

enum StoreCartPaymentMode {
  appBalance,
  stripeCard,
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

  final List<StoreCartItemData> cartItems = StoreCartSession.items;
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

    if (Get.isRegistered<ProfileController>()) {
      Get.find<ProfileController>().getProfileInfo();
    }
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

  double get itemsSubtotal {
    return cartItems.fold<double>(
      0,
      (total, item) => total + item.total,
    );
  }

  double get shippingBaseValue {
    if (deliveryMode == StoreCartDeliveryMode.pickup) {
      return 0;
    }

    double total = 0;

    for (final StoreCartStoreGroup group in storeGroups) {
      if (group.subtotal >= 200) {
        continue;
      }

      total += 8.50;
    }

    return total;
  }

  bool get hasMultiStoreShippingDiscount {
    return deliveryMode == StoreCartDeliveryMode.lokallyShipping &&
        storeCount >= 2 &&
        itemsSubtotal >= 200 &&
        shippingBaseValue > 0;
  }

  double get shippingDiscount {
    if (!hasMultiStoreShippingDiscount) {
      return 0;
    }

    return shippingBaseValue * 0.25;
  }

  double get shippingTotal {
    final double value = shippingBaseValue - shippingDiscount;
    return value < 0 ? 0 : value;
  }

  double get orderTotal => itemsSubtotal + shippingTotal;

  StoreCartStoreGroup? get firstStore {
    if (storeGroups.isEmpty) {
      return null;
    }

    return storeGroups.first;
  }

  void increaseQuantity(StoreCartItemData item) {
    setState(() {
      item.quantity++;
    });
    StoreCartSession.notifyChanged();
  }

  void decreaseQuantity(StoreCartItemData item) {
    if (item.quantity <= 1) {
      return;
    }

    setState(() {
      item.quantity--;
    });
    StoreCartSession.notifyChanged();
  }

  void removeItem(StoreCartItemData item) {
    setState(() {
      StoreCartSession.removeItem(item);
    });

    if (cartItems.isEmpty) {
      Get.back();
    }
  }

  Future<void> loadCustomerAddresses() async {
    if (!Get.isRegistered<AddressController>()) {
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
    Get.to(() => const WalletScreen());
  }

  void closeOrder() {
    if (cartItems.isEmpty) {
      showCartMessage('Seu carrinho está vazio.');
      return;
    }

    if (paymentMode == StoreCartPaymentMode.appBalance &&
        appBalance < orderTotal) {
      showCartMessage(
        'Saldo insuficiente. Recarregue seu saldo ou escolha cartão de crédito.',
      );
      return;
    }

    if (deliveryMode == StoreCartDeliveryMode.lokallyShipping &&
        selectedDeliveryAddress == null) {
      showCartMessage(
        'Selecione um endereço de entrega para receber em casa.',
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
        deliveryAddress: selectedDeliveryAddress,
        itemsSubtotal: itemsSubtotal,
        shippingBaseValue: shippingBaseValue,
        shippingDiscount: shippingDiscount,
        shippingTotal: shippingTotal,
        orderTotal: orderTotal,
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
                  ? '$storeCount lojas no pedido'
                  : headerStore?.storeName ?? 'Loja',
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
                                title: 'Produtos no carrinho'),
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
                            const SizedBox(height: 18),
                            StoreCartDeliverySelector(
                              primaryColor: primaryColor,
                              deliveryMode: deliveryMode,
                              onChanged: (value) {
                                setState(() {
                                  deliveryMode = value;

                                  if (value == StoreCartDeliveryMode.pickup) {
                                    selectedDeliveryAddress = null;
                                  }
                                });

                                if (value ==
                                    StoreCartDeliveryMode.lokallyShipping) {
                                  loadCustomerAddresses();
                                }
                              },
                            ),
                            if (deliveryMode ==
                                StoreCartDeliveryMode.lokallyShipping) ...[
                              const SizedBox(height: 18),
                              StoreCartDeliveryAddressSelector(
                                primaryColor: primaryColor,
                                selectedAddress: selectedDeliveryAddress,
                                onSelectAddress: selectDeliveryAddress,
                                onAddNewAddress: openAddNewDeliveryAddress,
                              ),
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
      title,
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
                  'Total desta loja',
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
  final ValueChanged<StoreCartDeliveryMode> onChanged;

  const StoreCartDeliverySelector({
    super.key,
    required this.primaryColor,
    required this.deliveryMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StoreCartSectionTitle(title: 'Opções de entrega'),
        const SizedBox(height: 10),
        StoreCartSelectableLine(
          primaryColor: primaryColor,
          selected: deliveryMode == StoreCartDeliveryMode.pickup,
          title: 'Retire Grátis',
          description:
              'Retire diretamente na loja dentro do horário comercial do vendedor.',
          onTap: () => onChanged(StoreCartDeliveryMode.pickup),
        ),
        const SizedBox(height: 10),
        StoreCartSelectableLine(
          primaryColor: primaryColor,
          selected: deliveryMode == StoreCartDeliveryMode.lokallyShipping,
          title: 'Lokally Envios',
          description: 'Receba em casa com Lokally Envios.',
          onTap: () => onChanged(StoreCartDeliveryMode.lokallyShipping),
        ),
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
          StoreCartSectionTitle(title: 'Endereço de entrega'),
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
            StoreCartSectionTitle(title: 'Endereço de entrega'),
            const SizedBox(height: 10),
            if (addresses.isEmpty) ...[
              Text(
                'Escolha um endereço cadastrado ou adicione um novo endereço para receber o pedido.',
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
    final String label = '${address.addressLabel ?? 'Endereço'}'.tr;
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
        'Adicionar novo endereço',
        style: textBold.copyWith(
          color: primaryColor,
          fontSize: 12.6,
        ),
      ),
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
        StoreCartSectionTitle(title: 'Pagamento'),
        const SizedBox(height: 10),
        StoreCartSelectableContentLine(
          primaryColor: primaryColor,
          selected: paymentMode == StoreCartPaymentMode.appBalance,
          title: 'Pague no APP com saldo',
          onTap: () => onChanged(StoreCartPaymentMode.appBalance),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seu saldo é de ${StoreCartCurrency.format(appBalance)}. Utilize ele para pagar o seu pedido.',
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
                        text:
                            'Seu saldo é insuficiente, para pagar com saldo recarregue ',
                        style: textRegular.copyWith(
                          color: Colors.grey.shade700,
                          fontSize: 12.2,
                          height: 1.28,
                        ),
                      ),
                      TextSpan(
                        text: 'clicando aqui',
                        style: textBold.copyWith(
                          color: primaryColor,
                          fontSize: 12.2,
                          height: 1.28,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = onWalletRechargeTap,
                      ),
                      TextSpan(
                        text: ' ou selecione outra forma de pagamento.',
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
          selected: paymentMode == StoreCartPaymentMode.stripeCard,
          title: 'Cartão de crédito',
          description: 'Pague com cartão de crédito.',
          onTap: () => onChanged(StoreCartPaymentMode.stripeCard),
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
                  title,
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
                  title,
                  style: textBold.copyWith(
                    color: selected ? primaryColor : Colors.black87,
                    fontSize: 14.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
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
        'Pedidos serão separados por loja. Nesta opção, o cliente retira diretamente em cada loja após o pagamento.',
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

    String message =
        'Pedidos serão separados por loja. O Lokally Envios custa R\$8,50 por loja.';

    if (hasSingleStoreFreeShipping) {
      message =
          'Frete grátis aplicado: compra de R\$200,00 ou mais em uma única loja.';
    } else if (hasMultiStoreDiscount) {
      message =
          'Desconto de 25% no Lokally Envios aplicado: compra em 2 ou mais lojas com total mínimo de R\$200,00.';
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
  final VoidCallback onContinueShopping;
  final VoidCallback onCloseOrder;

  const StoreCartBottomBar({
    super.key,
    required this.primaryColor,
    required this.itemsSubtotal,
    required this.shippingTotal,
    required this.orderTotal,
    required this.onContinueShopping,
    required this.onCloseOrder,
  });

  @override
  Widget build(BuildContext context) {
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
              label: 'Produtos',
              value: StoreCartCurrency.format(itemsSubtotal),
            ),
            const SizedBox(height: 5),
            StoreCartTotalLine(
              label: 'Entrega',
              value: shippingTotal <= 0
                  ? 'Grátis'
                  : StoreCartCurrency.format(shippingTotal),
            ),
            const SizedBox(height: 7),
            StoreCartTotalLine(
              label: 'Total do pedido',
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
                      'Continuar comprando',
                      style: textBold.copyWith(
                        color: primaryColor,
                        fontSize: 12.4,
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
                      'Fechar pedido',
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
            label,
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
  final double itemsSubtotal;
  final double shippingBaseValue;
  final double shippingDiscount;
  final double shippingTotal;
  final double orderTotal;

  const StoreCheckoutScreen({
    super.key,
    required this.cartItems,
    required this.deliveryMode,
    required this.paymentMode,
    required this.deliveryAddress,
    required this.itemsSubtotal,
    required this.shippingBaseValue,
    required this.shippingDiscount,
    required this.shippingTotal,
    required this.orderTotal,
  });

  @override
  State<StoreCheckoutScreen> createState() => _StoreCheckoutScreenState();
}

class _StoreCheckoutScreenState extends State<StoreCheckoutScreen> {
  bool paymentApproved = false;
  late final String orderNumber = StoreMarketplaceOrderNumber.generate();

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

  String get customerName {
    if (!Get.isRegistered<ProfileController>()) {
      return 'Cliente';
    }

    return Get.find<ProfileController>().customerName().trim().isEmpty
        ? 'Cliente'
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
        ? 'Pague no APP com saldo'
        : 'Cartão de crédito';
  }

  String get deliveryLabel {
    return widget.deliveryMode == StoreCartDeliveryMode.pickup
        ? 'Retire Grátis'
        : 'Lokally Envios';
  }

  bool get isLokallyShipping {
    return widget.deliveryMode == StoreCartDeliveryMode.lokallyShipping;
  }

  bool get hasFreeMarketplaceShipping {
    return isLokallyShipping && widget.shippingTotal <= 0;
  }

  void approvePayment() {
    setState(() {
      paymentApproved = true;
    });
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
                      StoreCheckoutSectionTitle(title: 'Dados do cliente'),
                      const SizedBox(height: 10),
                      StoreCheckoutSimpleLine(
                        label: 'Número do pedido',
                        value: orderNumber,
                        highlight: true,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 6),
                      StoreCheckoutSimpleLine(
                        label: 'Nome',
                        value: customerName,
                      ),
                      if (customerPhone.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        StoreCheckoutSimpleLine(
                          label: 'Telefone',
                          value: customerPhone,
                        ),
                      ],
                      const StoreCheckoutDivider(),
                      StoreCheckoutSectionTitle(title: 'Resumo do pedido'),
                      const SizedBox(height: 10),
                      ...storeGroups.map((group) {
                        return StoreCheckoutStoreSummary(
                          group: group,
                          primaryColor: primaryColor,
                          paymentApproved: paymentApproved,
                          deliveryMode: widget.deliveryMode,
                          orderNumber: orderNumber,
                          paymentLabel: paymentLabel,
                        );
                      }),
                      const StoreCheckoutDivider(),
                      StoreCheckoutSectionTitle(title: 'Entrega'),
                      const SizedBox(height: 10),
                      StoreCheckoutSimpleLine(
                        label: 'Opção selecionada',
                        value: deliveryLabel,
                      ),
                      if (isLokallyShipping) ...[
                        const SizedBox(height: 6),
                        StoreCheckoutSimpleLine(
                          label: 'Endereço de entrega',
                          value: widget.deliveryAddress?.address ?? '-',
                        ),
                        const SizedBox(height: 6),
                        StoreCheckoutSimpleLine(
                          label: 'Frete',
                          value: widget.shippingTotal <= 0
                              ? 'Grátis'
                              : StoreCartCurrency.format(widget.shippingTotal),
                        ),
                      ],
                      const StoreCheckoutDivider(),
                      StoreCheckoutSectionTitle(title: 'Pagamento'),
                      const SizedBox(height: 10),
                      StoreCheckoutSimpleLine(
                        label: 'Forma de pagamento',
                        value: paymentLabel,
                      ),
                      const SizedBox(height: 6),
                      StoreCheckoutSimpleLine(
                        label: 'Total',
                        value: StoreCartCurrency.format(widget.orderTotal),
                        highlight: true,
                        primaryColor: primaryColor,
                      ),
                      if (paymentApproved) ...[
                        const SizedBox(height: 14),
                        StoreCheckoutApprovedMessage(
                          primaryColor: primaryColor,
                          deliveryMode: widget.deliveryMode,
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
              'Checkout',
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
      title,
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

class StoreCheckoutStoreSummary extends StatelessWidget {
  final StoreCartStoreGroup group;
  final Color primaryColor;
  final bool paymentApproved;
  final StoreCartDeliveryMode deliveryMode;
  final String orderNumber;
  final String paymentLabel;

  const StoreCheckoutStoreSummary({
    super.key,
    required this.group,
    required this.primaryColor,
    required this.paymentApproved,
    required this.deliveryMode,
    required this.orderNumber,
    required this.paymentLabel,
  });

  bool get isLokallyShipping {
    return deliveryMode == StoreCartDeliveryMode.lokallyShipping;
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
          if (paymentApproved) ...[
            const SizedBox(height: 10),
            if (isLokallyShipping)
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
          '\nValor unitário: ${StoreCartCurrency.format(item.product.finalPrice)}'
          '\nTotal do item: ${StoreCartCurrency.format(item.total)}';
    }).join('\n\n');

    return 'Olá, ${group.storeName}, eu fiz um pedido no Marketplace da Lokally, '
        'pedido $orderNumber, e escolhi retirar o pedido. '
        'Gostaria de saber o horário que poderei retirar?'
        '\n\nPedido: $orderNumber'
        '\nStatus atual: Retirar Produto'
        '\nForma de pagamento: $paymentLabel'
        '\nTotal do pedido: ${StoreCartCurrency.format(group.subtotal)}'
        '\n\nProdutos:\n$productsText';
  }

  Future<void> openWhatsApp(BuildContext context) async {
    if (whatsappPhone.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'WhatsApp da loja não disponível.',
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
            'Não foi possível abrir o WhatsApp da loja.',
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
          'Retirada liberada',
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Apresente o pedido $orderNumber ao vendedor no momento da retirada.',
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 12.5,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Horários disponíveis: horário comercial do vendedor.',
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
              : 'Endereço de retirada será enviado pela loja.',
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
                'Contatar loja pelo WhatsApp',
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
      'Pedido aprovado. O vendedor tem até 24h para solicitar um parceiro Lokally para enviar o seu pedido.',
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

  const StoreCheckoutApprovedMessage({
    super.key,
    required this.primaryColor,
    required this.deliveryMode,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      deliveryMode == StoreCartDeliveryMode.pickup
          ? 'Pagamento aprovado. As informações de retirada foram liberadas.'
          : 'Pagamento aprovado. O vendedor tem até 24h para solicitar o Lokally Envios.',
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
  final StoreCartPaymentMode paymentMode;
  final VoidCallback onPayTap;

  const StoreCheckoutBottomBar({
    super.key,
    required this.primaryColor,
    required this.paymentApproved,
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
            'Pedido aprovado',
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
            onPressed: onPayTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
            child: Text(
              paymentMode == StoreCartPaymentMode.appBalance
                  ? 'Pagar com saldo'
                  : 'Pagar com cartão',
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
  });

  factory StoreCartProductData.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> store = map['store'] is Map
        ? Map<String, dynamic>.from(map['store'])
        : <String, dynamic>{};

    final String sellerId = '${map['seller_id'] ?? ''}';
    final String storeId = '${store['id'] ?? sellerId}';

    return StoreCartProductData(
      id: '${map['id'] ?? ''}',
      sellerId: sellerId,
      title: '${map['name'] ?? ''}',
      finalPrice: StoreCartCurrency.parseDouble(
        map['final_price'] ?? map['price'],
      ),
      mainImageUrl: '${map['main_image_url'] ?? ''}',
      storeId: storeId,
      storeName: '${store['name'] ?? 'Loja'}',
      storeLogoUrl: '${store['logo_url'] ?? ''}',
      storeAddress:
          '${store['address'] ?? store['store_address'] ?? store['full_address'] ?? ''}',
      storePhone:
          '${store['phone'] ?? store['contact_phone'] ?? store['business_phone'] ?? store['mobile'] ?? ''}',
      storeEmail: '${store['email'] ?? store['business_email'] ?? ''}',
    );
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
