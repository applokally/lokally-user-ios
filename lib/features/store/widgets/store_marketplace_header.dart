import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_cart_screen.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreMarketplaceCategoryViewData {
  final String id;
  final String name;
  final String primaryIconUrl;
  final String? localIconAsset;
  final bool isAll;
  final String normalizedIdentifier;

  const StoreMarketplaceCategoryViewData({
    required this.id,
    required this.name,
    required this.primaryIconUrl,
    required this.localIconAsset,
    required this.isAll,
    required this.normalizedIdentifier,
  });
}

/// Header superior padrão do Marketplace.
/// Deve ser usado pela Home e pelas páginas de categorias para manter o mesmo visual.
class StoreMarketplaceModeSelectorHeader extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onShoppingTap;
  final VoidCallback onTravelTap;
  final VoidCallback onDeliveryTap;

  const StoreMarketplaceModeSelectorHeader({
    super.key,
    required this.primaryColor,
    required this.onShoppingTap,
    required this.onTravelTap,
    required this.onDeliveryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: primaryColor,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 10,
        16,
        12,
      ),
      child: StoreMarketplaceModeSelectorPill(
        primaryColor: primaryColor,
        onShoppingTap: onShoppingTap,
        onTravelTap: onTravelTap,
        onDeliveryTap: onDeliveryTap,
      ),
    );
  }
}

class StoreMarketplaceModeSelectorPill extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onShoppingTap;
  final VoidCallback onTravelTap;
  final VoidCallback onDeliveryTap;

  const StoreMarketplaceModeSelectorPill({
    super.key,
    required this.primaryColor,
    required this.onShoppingTap,
    required this.onTravelTap,
    required this.onDeliveryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 8),
            blurRadius: 18,
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: StoreMarketplaceModeSelectorItem(
              label: 'Lokally Shop',
              asset: 'assets/image/shopping.png',
              selected: true,
              primaryColor: primaryColor,
              onTap: onShoppingTap,
            ),
          ),
          Expanded(
            flex: 4,
            child: StoreMarketplaceModeSelectorItem(
              label: 'Viagens',
              asset: 'assets/image/viagens.png',
              selected: false,
              primaryColor: primaryColor,
              onTap: onTravelTap,
            ),
          ),
          Expanded(
            flex: 4,
            child: StoreMarketplaceModeSelectorItem(
              label: 'Entregas',
              asset: 'assets/image/entregas.png',
              selected: false,
              primaryColor: primaryColor,
              onTap: onDeliveryTap,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreMarketplaceModeSelectorItem extends StatelessWidget {
  final String label;
  final String asset;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreMarketplaceModeSelectorItem({
    super.key,
    required this.label,
    required this.asset,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor =
        selected ? primaryColor.withValues(alpha: 0.12) : Colors.transparent;
    final Color textColor = Colors.black87;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(26),
          border: selected
              ? Border.all(color: primaryColor.withValues(alpha: 0.18))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              asset,
              width: 30,
              height: 30,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: textBold.copyWith(
                  color: textColor,
                  fontSize: 13.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fundo degradê padrão que fica atrás das categorias e banners.
class StoreMarketplaceHeaderGradient extends StatelessWidget {
  final Color primaryColor;
  final double height;

  const StoreMarketplaceHeaderGradient({
    super.key,
    required this.primaryColor,
    this.height = 315,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor,
              primaryColor.withValues(alpha: 0.90),
              primaryColor.withValues(alpha: 0.30),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.42, 0.75, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Menu de categorias principais padrão.
/// A categoria selecionada fica em destaque e as demais continuam visíveis.
class StoreMarketplaceMainCategoryMenu extends StatelessWidget {
  final List<StoreMarketplaceCategoryViewData> categories;
  final int selectedIndex;
  final Color primaryColor;
  final ValueChanged<int> onSelected;

  const StoreMarketplaceMainCategoryMenu({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.primaryColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return StoreMarketplaceCategoryMenuItem(
            category: categories[index],
            isSelected: index == selectedIndex,
            primaryColor: primaryColor,
            onTap: () => onSelected(index),
          );
        },
      ),
    );
  }
}

class StoreMarketplaceCategoryMenuItem extends StatelessWidget {
  final StoreMarketplaceCategoryViewData category;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreMarketplaceCategoryMenuItem({
    super.key,
    required this.category,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String networkIconUrl = category.primaryIconUrl;
    final bool hasNetworkIcon = networkIconUrl.isNotEmpty;
    final String? localIconAsset = category.localIconAsset;
    final bool hasIcon = hasNetworkIcon || localIconAsset != null;
    final Color labelColor =
        Colors.white.withValues(alpha: isSelected ? 1 : 0.94);

    Widget iconWidget() {
      if (!hasIcon) {
        return SizedBox(
          width: 58,
          height: 58,
          child: Icon(
            category.isAll ? Icons.apps_rounded : Icons.storefront_rounded,
            color: Colors.white.withValues(alpha: 0.92),
            size: 36,
          ),
        );
      }

      final Widget image = hasNetworkIcon
          ? Image.network(
              networkIconUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                if (localIconAsset != null) {
                  return Image.asset(
                    localIconAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return Icon(
                        category.isAll
                            ? Icons.apps_rounded
                            : Icons.storefront_rounded,
                        color: Colors.white.withValues(alpha: 0.92),
                        size: 36,
                      );
                    },
                  );
                }

                return Icon(
                  category.isAll
                      ? Icons.apps_rounded
                      : Icons.storefront_rounded,
                  color: Colors.white.withValues(alpha: 0.92),
                  size: 36,
                );
              },
            )
          : Image.asset(
              localIconAsset!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return Icon(
                  category.isAll
                      ? Icons.apps_rounded
                      : Icons.storefront_rounded,
                  color: Colors.white.withValues(alpha: 0.92),
                  size: 36,
                );
              },
            );

      return SizedBox(
        width: 50,
        height: 50,
        child: image,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 3),
        padding: const EdgeInsets.only(top: 1, bottom: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget(),
            const SizedBox(height: 2),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: (isSelected ? textBold : textMedium).copyWith(
                color: labelColor,
                fontSize: category.isAll ? 12.1 : 11.4,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isSelected ? 30 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header antigo preservado para não quebrar telas que ainda usam busca no topo.
/// A Home nova e as páginas de categoria devem usar StoreMarketplaceModeSelectorHeader
/// + StoreMarketplaceHeaderGradient + StoreMarketplaceMainCategoryMenu.
class StoreMarketplaceHeader extends StatelessWidget {
  final Color primaryColor;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCartTap;
  final bool showSellButton;
  final bool isSellButtonLoading;
  final String sellButtonLabel;
  final VoidCallback? onSellTap;

  const StoreMarketplaceHeader({
    super.key,
    required this.primaryColor,
    required this.onSearchChanged,
    required this.onCartTap,
    this.showSellButton = false,
    this.isSellButtonLoading = false,
    this.sellButtonLabel = 'Vender',
    this.onSellTap,
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
          if (showSellButton) ...[
            StoreMarketplaceHeaderSellButton(
              primaryColor: primaryColor,
              label: sellButtonLabel,
              isLoading: isSellButtonLoading,
              onTap: onSellTap,
            ),
            const SizedBox(width: 8),
          ] else ...[
            Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Image.asset(
                'assets/image/loja.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: StoreMarketplaceHeaderSearchField(
              onChanged: onSearchChanged,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCartTap,
            child: ValueListenableBuilder<int>(
              valueListenable: StoreCartSession.cartRevision,
              builder: (context, _, __) {
                final int cartQuantity = StoreCartSession.totalQuantity;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    if (cartQuantity > 0)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          height: 19,
                          constraints: const BoxConstraints(
                            minWidth: 19,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              cartQuantity > 99
                                  ? '99+'
                                  : cartQuantity.toString(),
                              style: textBold.copyWith(
                                color: Colors.white,
                                fontSize: 9.5,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class StoreMarketplaceHeaderSellButton extends StatelessWidget {
  final Color primaryColor;
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  const StoreMarketplaceHeaderSellButton({
    super.key,
    required this.primaryColor,
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 42,
          constraints: const BoxConstraints(minWidth: 74),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 4),
                blurRadius: 12,
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  )
                : Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(
                      color: primaryColor,
                      fontSize: 13.2,
                      height: 1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class StoreMarketplaceHeaderSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const StoreMarketplaceHeaderSearchField({
    super.key,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: textRegular.copyWith(
          color: Colors.black87,
          fontSize: 13.5,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: const EdgeInsets.only(top: 10),
          icon: Icon(
            Icons.search_rounded,
            color: Colors.grey.shade600,
            size: 20,
          ),
          hintText: 'store_search_products'.tr,
          hintStyle: textRegular.copyWith(
            color: Colors.grey.shade500,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}
