import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/profile/screens/profile_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_cart_screen.dart';
import 'package:ride_sharing_user_app/helper/login_helper.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreMarketplaceBottomSearchCartBar extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onSearchTap;
  final VoidCallback onCartTap;

  const StoreMarketplaceBottomSearchCartBar({
    super.key,
    required this.primaryColor,
    required this.onSearchTap,
    required this.onCartTap,
  });

  bool get isCustomerLoggedIn {
    return Get.isRegistered<AuthController>() &&
        Get.find<AuthController>().isLoggedIn();
  }

  void openProfileOrLoginDialog() {
    if (isCustomerLoggedIn) {
      Get.to(() => const ProfileScreen());
      return;
    }

    if (Get.isDialogOpen ?? false) {
      return;
    }

    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
        contentPadding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: primaryColor,
              size: 25,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Área exclusiva',
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Esta área exige cadastro. Entre ou crie sua conta para acessar seu perfil, pedidos, carteira e dados da Lokally.',
          style: textRegular.copyWith(
            color: Colors.grey.shade700,
            fontSize: 13,
            height: 1.34,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Agora não',
              style: textBold.copyWith(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            ),
            onPressed: () {
              Get.back();
              LoginHelper.checkLoginMedium();
            },
            child: Text(
              'Cadastrar ou entrar',
              style: textBold.copyWith(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.26),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 7),
              blurRadius: 18,
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _StoreMarketplaceFooterAssetButton(
                primaryColor: primaryColor,
                assetPath: 'assets/image/search_footer.png',
                fallbackIcon: Icons.search_rounded,
                label: 'Buscar',
                semanticLabel: 'Buscar produtos',
                onTap: onSearchTap,
              ),
            ),
            Expanded(
              child: _StoreMarketplaceFooterAssetButton(
                primaryColor: primaryColor,
                assetPath: 'assets/image/profile_footer.png',
                fallbackIcon: Icons.person_outline_rounded,
                label: 'Perfil',
                semanticLabel: 'Perfil',
                onTap: openProfileOrLoginDialog,
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: StoreCartSession.cartRevision,
                builder: (context, revision, _) {
                  final int cartQuantity = StoreCartSession.totalQuantity;

                  return _StoreMarketplaceFooterAssetButton(
                    primaryColor: primaryColor,
                    assetPath: 'assets/image/shopping_footer.webp.png',
                    fallbackIcon: Icons.shopping_cart_outlined,
                    label: 'Carrinho',
                    semanticLabel: 'Carrinho',
                    onTap: onCartTap,
                    isHighlighted: true,
                    badgeValue: cartQuantity,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreMarketplaceFooterAssetButton extends StatelessWidget {
  final Color primaryColor;
  final String assetPath;
  final IconData fallbackIcon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool isHighlighted;
  final int badgeValue;

  const _StoreMarketplaceFooterAssetButton({
    required this.primaryColor,
    required this.assetPath,
    required this.fallbackIcon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.isHighlighted = false,
    this.badgeValue = 0,
  });

  @override
  Widget build(BuildContext context) {
    final Color labelColor =
        isHighlighted ? primaryColor : Colors.grey.shade700;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: Center(
                      child: Image.asset(
                        assetPath,
                        width: isHighlighted ? 31 : 29,
                        height: isHighlighted ? 31 : 29,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          fallbackIcon,
                          color: primaryColor,
                          size: isHighlighted ? 29 : 27,
                        ),
                      ),
                    ),
                  ),
                  if (badgeValue > 0)
                    Positioned(
                      top: -7,
                      right: -9,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              offset: const Offset(0, 4),
                              blurRadius: 10,
                              color: Colors.black.withValues(alpha: 0.16),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            badgeValue > 99 ? '99+' : '$badgeValue',
                            style: textBold.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textBold.copyWith(
                  color: labelColor,
                  fontSize: 11.4,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreMarketplaceBackToTopButton extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onTap;

  const StoreMarketplaceBackToTopButton({
    super.key,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 7,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.20),
            ),
          ),
          child: Icon(
            Icons.keyboard_arrow_up_rounded,
            color: primaryColor,
            size: 28,
          ),
        ),
      ),
    );
  }
}
