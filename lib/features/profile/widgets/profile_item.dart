import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class ProfileMenuItem extends StatelessWidget {
  final String title;
  final String icon;
  final Function()? onTap;
  final bool divider;
  final bool highlighted;
  final IconData? highlightIcon;
  final String? subtitle;

  const ProfileMenuItem({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
    this.divider = true,
    this.highlighted = false,
    this.highlightIcon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color textColor =
        Theme.of(context).textTheme.bodyLarge!.color!.withValues(alpha: 0.9);

    final Widget leading = highlighted
        ? Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 6),
                  blurRadius: 16,
                  color: primaryColor.withValues(alpha: 0.24),
                ),
              ],
            ),
            child: Center(
              child: highlightIcon != null
                  ? Icon(
                      highlightIcon,
                      color: Colors.white,
                      size: 21,
                    )
                  : Image.asset(
                      icon,
                      width: 20,
                      height: 20,
                      fit: BoxFit.cover,
                      color: Colors.white,
                    ),
            ),
          )
        : Image.asset(
            icon,
            width: 20,
            height: 20,
            fit: BoxFit.cover,
            color: primaryColor,
          );

    final Widget item = ListTile(
      contentPadding: highlighted
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 4)
          : null,
      leading: leading,
      title: Text(
        title.tr,
        style: textMedium.copyWith(
          color: highlighted ? primaryColor : textColor,
          fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                subtitle!,
                style: textRegular.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .color!
                      .withValues(alpha: 0.58),
                  fontSize: 11.5,
                ),
              ),
            ),
      trailing: highlighted
          ? Icon(
              Icons.arrow_forward_ios_rounded,
              color: primaryColor,
              size: 15,
            )
          : null,
      onTap: onTap,
    );

    return Column(children: [
      highlighted
          ? Container(
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.18),
                ),
              ),
              child: item,
            )
          : SizedBox(child: item),
      divider
          ? Divider(
              color: primaryColor.withValues(alpha: highlighted ? 0.10 : 0.2),
              thickness: 0.8,
            )
          : const SizedBox(),
    ]);
  }
}
