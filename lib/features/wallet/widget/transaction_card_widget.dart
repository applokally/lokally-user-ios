import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/wallet/domain/models/transaction_model.dart';
import 'package:ride_sharing_user_app/common_widgets/divider_widget.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  const TransactionCard({super.key, required this.transaction});

  bool get _isOldReferralCashTransaction {
    final String attribute = '${transaction.attribute ?? ''}'.toLowerCase();

    return attribute.contains('referral') ||
        attribute.contains('indicação') ||
        attribute.contains('indicacao') ||
        attribute.contains('ganho_por_indicacao') ||
        attribute.contains('ganho por indicação') ||
        attribute.contains('referral_earning') ||
        attribute.contains('referral earning');
  }

  String get _transactionTitle {
    final String attribute = '${transaction.attribute ?? ''}'.trim();

    if (attribute.isEmpty) {
      return 'Movimentação da carteira';
    }

    final String translated = attribute.tr.trim();

    if (translated.isEmpty || translated == attribute) {
      return _humanizeAttribute(attribute);
    }

    return translated;
  }

  String _humanizeAttribute(String value) {
    final String normalized = value
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.isEmpty) {
      return 'Movimentação da carteira';
    }

    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  String get _formattedCreatedAt {
    final String rawDate = '${transaction.createdAt ?? ''}'.trim();

    if (rawDate.isEmpty) {
      return '';
    }

    DateTime? parsedDate = DateTime.tryParse(rawDate);
    parsedDate ??= DateTime.tryParse(rawDate.replaceFirst(' ', 'T'));

    if (parsedDate == null) {
      return _formatFallbackDate(rawDate);
    }

    return _formatBrazilianDateTime(parsedDate);
  }

  String _formatBrazilianDateTime(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String year = date.year.toString();
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  String _formatFallbackDate(String value) {
    return value
        .replaceAll(' AM', '')
        .replaceAll(' PM', '')
        .replaceAll('January', 'Janeiro')
        .replaceAll('February', 'Fevereiro')
        .replaceAll('March', 'Março')
        .replaceAll('April', 'Abril')
        .replaceAll('May', 'Maio')
        .replaceAll('June', 'Junho')
        .replaceAll('July', 'Julho')
        .replaceAll('August', 'Agosto')
        .replaceAll('September', 'Setembro')
        .replaceAll('October', 'Outubro')
        .replaceAll('November', 'Novembro')
        .replaceAll('December', 'Dezembro')
        .replaceAll('Jan', 'Jan')
        .replaceAll('Feb', 'Fev')
        .replaceAll('Mar', 'Mar')
        .replaceAll('Apr', 'Abr')
        .replaceAll('May', 'Mai')
        .replaceAll('Jun', 'Jun')
        .replaceAll('Jul', 'Jul')
        .replaceAll('Aug', 'Ago')
        .replaceAll('Sep', 'Set')
        .replaceAll('Oct', 'Out')
        .replaceAll('Nov', 'Nov')
        .replaceAll('Dec', 'Dez');
  }

  @override
  Widget build(BuildContext context) {
    if (_isOldReferralCashTransaction) {
      return const SizedBox.shrink();
    }

    final double debit = transaction.debit ?? 0;
    final double credit = transaction.credit ?? 0;
    final bool isDebit = debit > 0;
    final double amount = isDebit ? debit : credit;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        0,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeDefault,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
            child: Row(
              children: [
                Image.asset(
                  Images.myEarnIcon,
                  height: Dimensions.paddingSizeExtraLarge,
                  width: Dimensions.paddingSizeExtraLarge,
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _transactionTitle,
                              style: textBold.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                              ),
                            ),
                            if (_formattedCreatedAt.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: Dimensions.paddingSizeExtraSmall,
                                ),
                                child: Text(
                                  _formattedCreatedAt,
                                  style: textRegular.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .color!
                                        .withValues(alpha: 0.8),
                                    fontSize: Dimensions.fontSizeExtraSmall,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeDefault,
                    vertical: Dimensions.paddingSizeSeven,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: Theme.of(context).hintColor.withValues(alpha: 0.15),
                  ),
                  child: Text(
                    '${isDebit ? '-' : '+'} ${PriceConverter.convertPrice(amount)}',
                    style: textRobotoBold,
                  ),
                ),
              ],
            ),
          ),
          CustomDivider(
            height: .5,
            color: Theme.of(context).hintColor.withValues(alpha: 0.75),
          ),
        ],
      ),
    );
  }
}
