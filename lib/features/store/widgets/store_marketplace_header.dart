import 'package:flutter/material.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_cart_screen.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

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
          hintText: 'Buscar produtos',
          hintStyle: textRegular.copyWith(
            color: Colors.grey.shade500,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}
