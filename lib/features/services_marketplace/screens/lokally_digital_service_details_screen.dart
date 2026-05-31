import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_customer_order_list_screen.dart';
import 'package:ride_sharing_user_app/helper/login_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class LokallyDigitalServiceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> service;

  const LokallyDigitalServiceDetailsScreen({
    super.key,
    required this.service,
  });

  @override
  State<LokallyDigitalServiceDetailsScreen> createState() =>
      _LokallyDigitalServiceDetailsScreenState();
}

class _LokallyDigitalServiceDetailsScreenState
    extends State<LokallyDigitalServiceDetailsScreen> {
  final PageController imagePageController = PageController();
  Timer? imageCarouselTimer;
  int selectedImageIndex = 0;
  Map<String, dynamic> detailedService = <String, dynamic>{};
  bool isLoadingDetails = false;
  bool hasLoadedDetails = false;
  bool isRequestingServiceChat = false;

  Map<String, dynamic> get currentService {
    return detailedService.isNotEmpty ? detailedService : widget.service;
  }

  String normalizeComparableText(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[\u00A0]'), ' ');
  }

  bool isSameText(String first, String second) {
    final String normalizedFirst = normalizeComparableText(first);
    final String normalizedSecond = normalizeComparableText(second);

    return normalizedFirst.isNotEmpty && normalizedFirst == normalizedSecond;
  }

  Map<String, dynamic> sanitizePublicServiceMap(Map<String, dynamic> source) {
    const Set<String> forbiddenKeys = <String>{
      'seller_id',
      'phone',
      'whatsapp',
      'whatsapp_number',
      'contact_phone',
      'email',
      'address',
      'store_address',
      'full_address',
      'seller_phone',
      'seller_contact_phone',
      'seller_email',
      'seller_address',
      'shipping_origin_postal_code',
      'shipping_origin_city',
      'shipping_origin_state',
      'seller_shipping_origin_postal_code',
      'seller_shipping_origin_city',
      'seller_shipping_origin_state',
      'store_shipping_origin_postal_code',
      'store_shipping_origin_city',
      'store_shipping_origin_state',
      'store_city',
      'store_state',
    };

    dynamic sanitizeValue(dynamic value) {
      if (value is Map) {
        final Map<String, dynamic> cleaned = <String, dynamic>{};

        value.forEach((dynamic key, dynamic child) {
          final String stringKey = '$key';

          if (forbiddenKeys.contains(stringKey)) {
            return;
          }

          cleaned[stringKey] = sanitizeValue(child);
        });

        return cleaned;
      }

      if (value is List) {
        return value.map(sanitizeValue).toList();
      }

      return value;
    }

    return Map<String, dynamic>.from(sanitizeValue(source) as Map);
  }

  String nestedValue(
    String parentKey,
    List<String> keys, {
    String fallback = '',
  }) {
    final dynamic parent = currentService[parentKey];

    if (parent is! Map) {
      return fallback;
    }

    final Map<String, dynamic> source = Map<String, dynamic>.from(parent);

    for (final String key in keys) {
      if (!source.containsKey(key)) {
        continue;
      }

      final String text = cleanText(source[key]);

      if (text.isNotEmpty) {
        return text;
      }
    }

    return fallback;
  }

  String formatCurrencyFromValue(dynamic rawValue) {
    if (rawValue == null) {
      return '';
    }

    final String text = '$rawValue'.trim();

    if (text.isEmpty || text == 'null') {
      return '';
    }

    final double? value = double.tryParse(text.replaceAll(',', '.'));

    if (value == null || value <= 0) {
      return '';
    }

    final String fixed = value.toStringAsFixed(2);
    final List<String> parts = fixed.split('.');
    final String integer = parts.first;
    final String decimals = parts.length > 1 ? parts[1] : '00';
    final StringBuffer formattedInteger = StringBuffer();

    for (int index = 0; index < integer.length; index++) {
      final int reverseIndex = integer.length - index;
      formattedInteger.write(integer[index]);

      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        formattedInteger.write('.');
      }
    }

    return 'R\$ ${formattedInteger.toString()},$decimals';
  }

  String humanizeServiceDeliveryType(String rawValue) {
    final String value = rawValue.trim().toLowerCase();

    switch (value) {
      case 'download':
        return 'Entrega digital';
      case 'online':
        return 'Atendimento online';
      case 'client_location':
        return 'No endereço do cliente';
      case 'provider_location':
        return 'No endereço do prestador';
      case 'region':
        return 'Atendimento regional';
      default:
        return rawValue.trim();
    }
  }

  String humanizeServiceFormat(String rawValue) {
    final String value = rawValue.trim().toLowerCase();

    switch (value) {
      case 'digital':
        return 'Serviço digital';
      case 'presential':
      case 'presencial':
        return 'Serviço presencial';
      default:
        return rawValue.trim();
    }
  }

  String cleanText(dynamic rawValue) {
    if (rawValue == null) {
      return '';
    }

    if (rawValue is List) {
      return rawValue
          .map(cleanText)
          .where((item) => item.trim().isNotEmpty)
          .join('\n');
    }

    if (rawValue is Map) {
      for (final String preferredKey in <String>[
        'value',
        'text',
        'label',
        'description',
        'title',
        'name',
        'content',
      ]) {
        if (rawValue.containsKey(preferredKey)) {
          final String preferredText = cleanText(rawValue[preferredKey]);

          if (preferredText.isNotEmpty) {
            return preferredText;
          }
        }
      }

      return rawValue.values
          .map(cleanText)
          .where((item) => item.trim().isNotEmpty)
          .join('\n');
    }

    final String text = '$rawValue'.trim();

    if (text.isEmpty || text == 'null' || text == '[]' || text == '{}') {
      return '';
    }

    return text;
  }

  dynamic rawValueForKey(String key) {
    final List<Map<String, dynamic>> sources = <Map<String, dynamic>>[
      currentService,
    ];

    for (final String nestedKey in <String>[
      'service',
      'service_details',
      'details',
      'metadata',
    ]) {
      final dynamic nestedValue = currentService[nestedKey];

      if (nestedValue is Map) {
        sources.add(Map<String, dynamic>.from(nestedValue));
      }
    }

    for (final Map<String, dynamic> source in sources) {
      if (source.containsKey(key)) {
        return source[key];
      }
    }

    return null;
  }

  String value(String key, {String fallback = ''}) {
    final String text = cleanText(rawValueForKey(key));

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  String firstValue(List<String> keys, {String fallback = ''}) {
    for (final String key in keys) {
      final String text = value(key);

      if (text.isNotEmpty) {
        return text;
      }
    }

    return fallback;
  }

  List<String> get imageUrls {
    final List<String> images = <String>[];

    void addImage(dynamic rawValue) {
      final String image = '${rawValue ?? ''}'.trim();

      if (image.isEmpty || image == 'null' || images.contains(image)) {
        return;
      }

      images.add(image);
    }

    void addImagesFromList(dynamic rawValue) {
      if (rawValue is! List) {
        return;
      }

      for (final dynamic item in rawValue) {
        if (item is Map) {
          addImage(
            item['full_url'] ??
                item['image_url'] ??
                item['url'] ??
                item['image'] ??
                item['path'] ??
                item['file'] ??
                item['thumbnail'],
          );
        } else {
          addImage(item);
        }
      }
    }

    addImagesFromList(currentService['gallery_image_urls']);
    addImagesFromList(currentService['images']);
    addImagesFromList(currentService['gallery']);
    addImagesFromList(currentService['product_images']);
    addImagesFromList(currentService['media']);

    addImage(currentService['image_url']);
    addImage(currentService['main_image_url']);
    addImage(currentService['main_image']);
    addImage(currentService['thumbnail']);

    return images;
  }

  String get title => firstValue(
        <String>['title', 'name', 'service_title', 'product_name'],
        fallback: 'Serviço digital',
      );
  String get providerName {
    final String storeName = nestedValue(
      'store',
      <String>['name', 'store_name', 'business_name'],
    );

    if (storeName.isNotEmpty) {
      return storeName;
    }

    return firstValue(
      <String>[
        'provider_name',
        'store_name',
        'seller_name',
        'seller_full_name',
        'provider',
      ],
      fallback: 'Prestador',
    );
  }

  String get description => firstValue(
        <String>[
          'description',
          'full_description',
          'long_description',
          'service_description',
          'details',
        ],
      );
  String get categoryName => firstValue(
        <String>['category_name', 'category', 'service_category_name'],
        fallback: 'Serviço digital',
      );
  String get priceValueLabel {
    final String label = value('price_value_label');

    if (label.isNotEmpty) {
      return label;
    }

    return formatCurrencyFromValue(
      rawValueForKey('final_price') ??
          rawValueForKey('price') ??
          rawValueForKey('regular_price'),
    ).isNotEmpty
        ? formatCurrencyFromValue(
            rawValueForKey('final_price') ??
                rawValueForKey('price') ??
                rawValueForKey('regular_price'),
          )
        : 'Sob consulta';
  }

  String get priceUnitLabel => value('price_unit_label');
  String get ratingLabel => value('rating_label', fallback: 'Novo');
  String get reviewCountLabel =>
      value('review_count_label', fallback: '(sem avaliações)');
  String get deliveryTypeLabel {
    final String label = firstValue(
      <String>['delivery_type_label', 'service_delivery_label'],
    );

    if (label.isNotEmpty) {
      return label;
    }

    final String rawType = firstValue(
      <String>['service_delivery_type', 'delivery_type'],
    );

    final String humanized = humanizeServiceDeliveryType(rawType);

    return humanized.isEmpty ? 'Entrega digital' : humanized;
  }

  String get shortDescription => firstValue(
        <String>['short_description', 'summary', 'resume'],
      );
  String get deliverableDescription => firstValue(
        <String>[
          'deliverable_description',
          'delivery_description',
          'deliverables',
          'what_will_be_delivered',
          'what_will_deliver',
          'delivery_details',
        ],
      );
  String get includedItems => firstValue(
        <String>[
          'included_items',
          'included',
          'includes',
          'what_is_included',
          'service_includes',
        ],
      );
  String get excludedItems => firstValue(
        <String>[
          'excluded_items',
          'excluded',
          'not_included',
          'what_is_not_included',
          'service_excludes',
        ],
      );
  String get customerRequirements => firstValue(
        <String>[
          'customer_requirements',
          'client_requirements',
          'buyer_requirements',
          'requirements',
          'required_from_customer',
        ],
      );
  String get estimatedDeadline => firstValue(
        <String>[
          'estimated_deadline',
          'delivery_deadline',
          'deadline',
          'estimated_delivery_time',
          'delivery_time',
        ],
      );
  String get executionTime => firstValue(
        <String>['execution_time', 'estimated_execution_time', 'service_time'],
      );
  String get instructionsAfterPayment => firstValue(
        <String>[
          'instructions_after_payment',
          'post_payment_instructions',
          'after_payment_instructions',
          'instructions',
          'service_instructions',
        ],
      );
  String get serviceFormatLabel {
    final String label = firstValue(
      <String>['service_format_label', 'format_label'],
    );

    if (label.isNotEmpty) {
      return label;
    }

    final String rawFormat = firstValue(<String>['service_format', 'format']);
    final String humanized = humanizeServiceFormat(rawFormat);

    return humanized.isEmpty ? 'Serviço digital' : humanized;
  }

  String get serviceId => firstValue(<String>['id', 'product_id']);

  Future<void> loadPublicServiceDetails() async {
    final String id = serviceId.trim();

    if (id.isEmpty || isLoadingDetails) {
      return;
    }

    setState(() {
      isLoadingDetails = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().getData(
        '/api/store/services/$id',
      );

      if (!mounted) {
        return;
      }

      final dynamic responseBody = response.body;

      if (response.statusCode == 200 &&
          responseBody is Map &&
          responseBody['status'] == true) {
        final dynamic dataValue = responseBody['data'];
        final Map<String, dynamic> data = dataValue is Map
            ? Map<String, dynamic>.from(dataValue)
            : <String, dynamic>{};
        final dynamic serviceValue = data['service'] ?? data['product'];

        if (serviceValue is Map) {
          setState(() {
            detailedService = sanitizePublicServiceMap(
              Map<String, dynamic>.from(serviceValue),
            );
            isLoadingDetails = false;
            hasLoadedDetails = true;
            selectedImageIndex = 0;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }

            if (imagePageController.hasClients) {
              imagePageController.jumpToPage(0);
            }

            restartImageCarousel();
          });
          return;
        }
      }

      setState(() {
        isLoadingDetails = false;
        hasLoadedDetails = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingDetails = false;
        hasLoadedDetails = true;
      });
    }
  }

  bool get isCustomerLoggedIn {
    return Get.isRegistered<AuthController>() &&
        Get.find<AuthController>().isLoggedIn();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadPublicServiceDetails();
      restartImageCarousel();
    });
  }

  @override
  void dispose() {
    imageCarouselTimer?.cancel();
    imagePageController.dispose();
    super.dispose();
  }

  void restartImageCarousel() {
    imageCarouselTimer?.cancel();

    if (imageUrls.length <= 1) {
      return;
    }

    imageCarouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted ||
          !imagePageController.hasClients ||
          imageUrls.length <= 1) {
        return;
      }

      final int nextIndex = selectedImageIndex + 1 >= imageUrls.length
          ? 0
          : selectedImageIndex + 1;

      imagePageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOut,
      );
    });
  }

  void showServiceMessage(String message) {
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
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 86),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> handleContractTap() async {
    if (!isCustomerLoggedIn) {
      LoginHelper.checkLoginMedium();
      return;
    }

    final String id = serviceId.trim();

    if (id.isEmpty) {
      showServiceMessage('Não foi possível identificar este serviço.');
      return;
    }

    if (isRequestingServiceChat) {
      return;
    }

    setState(() {
      isRequestingServiceChat = true;
    });

    try {
      final Response response = await Get.find<ApiClient>().postData(
        '/api/customer/store/service/$id/request-chat',
        <String, dynamic>{},
      );

      if (!mounted) {
        return;
      }

      final dynamic body = response.body;
      final Map<String, dynamic> responseMap =
          body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
      final bool success =
          (response.statusCode == 200 || response.statusCode == 201) &&
              responseMap['status'] == true;

      if (!success) {
        final String message = cleanText(responseMap['message']).isNotEmpty
            ? cleanText(responseMap['message'])
            : 'Não foi possível enviar sua solicitação agora. Tente novamente.';

        showServiceMessage(message);
        return;
      }

      final dynamic dataValue = responseMap['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};
      final String popupMessage = cleanText(data['popup_message']).isNotEmpty
          ? cleanText(data['popup_message'])
          : 'Sua solicitação foi enviada com sucesso, em breve você receberá uma notificação do prestador para iniciar as tratativas pelo chat.';

      await showServiceRequestSuccessDialog(popupMessage);

      if (!mounted) {
        return;
      }

      Get.off(() => const StoreCustomerOrderListScreen());
    } catch (_) {
      if (mounted) {
        showServiceMessage(
          'Não foi possível enviar sua solicitação agora. Tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isRequestingServiceChat = false;
        });
      }
    }
  }

  Future<void> showServiceRequestSuccessDialog(String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
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
                    color: const Color(0xFFFFEE75).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.mark_chat_read_rounded,
                    color: Colors.black87,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Solicitação enviada',
                  textAlign: TextAlign.center,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 13.2,
                    height: 1.36,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 46,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFEE75),
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Entendi',
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 13.4,
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

  Widget buildHeroImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        color: const Color(0xFFFFEE75).withValues(alpha: 0.34),
        child: const Center(
          child: Icon(
            Icons.design_services_rounded,
            color: Colors.black87,
            size: 58,
          ),
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          color: const Color(0xFFFFEE75).withValues(alpha: 0.34),
          child: const Center(
            child: Icon(
              Icons.design_services_rounded,
              color: Colors.black87,
              size: 58,
            ),
          ),
        );
      },
    );
  }

  Widget buildProviderAvatar() {
    final String image = firstValue(<String>[
      'provider_image_url',
      'store_logo_url',
      'logo_url',
    ]).isNotEmpty
        ? firstValue(<String>[
            'provider_image_url',
            'store_logo_url',
            'logo_url',
          ])
        : nestedValue('store', <String>['logo_url', 'logo']);

    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 8),
            blurRadius: 18,
            color: Colors.black.withValues(alpha: 0.12),
          ),
        ],
      ),
      child: ClipOval(
        child: image.isEmpty
            ? Container(
                color: const Color(0xFFFFEE75).withValues(alpha: 0.24),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.black87,
                  size: 30,
                ),
              )
            : Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: const Color(0xFFFFEE75).withValues(alpha: 0.24),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.black87,
                      size: 30,
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget buildSoftChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.black87,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 11.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textBold.copyWith(
            color: Colors.black87,
            fontSize: 19,
            height: 1.12,
          ),
        ),
        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 13,
              height: 1.28,
            ),
          ),
        ],
      ],
    );
  }

  Widget buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    if (value.trim().isEmpty || value.trim() == 'null') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.black87,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 13.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 13.1,
                    height: 1.34,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDescriptionBlock({
    required String title,
    required String text,
  }) {
    if (text.trim().isEmpty || text.trim() == 'null') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 15.6,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            text,
            style: textRegular.copyWith(
              color: Colors.grey.shade800,
              fontSize: 14.0,
              height: 1.44,
            ),
          ),
        ],
      ),
    );
  }

  bool hasText(String text) {
    final String clean = text.trim();
    return clean.isNotEmpty && clean != 'null';
  }

  Widget buildAdvertiserField({
    required String label,
    required String text,
  }) {
    if (!hasText(text)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 13.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: textRegular.copyWith(
              color: Colors.grey.shade800,
              fontSize: 14.0,
              height: 1.46,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAdvertiserSection({
    required String title,
    required List<Widget> children,
  }) {
    final List<Widget> visibleChildren = children
        .where((child) => child is! SizedBox || child.width != 0)
        .toList();

    if (visibleChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 18.2,
                  ),
                ),
              ),
            ],
          ),
          ...visibleChildren,
        ],
      ),
    );
  }

  Widget buildAdvertiserInformation() {
    final String visibleShortDescription =
        hasText(shortDescription) && !isSameText(shortDescription, description)
            ? shortDescription
            : '';
    final String visibleDeadline =
        hasText(estimatedDeadline) ? estimatedDeadline : executionTime;
    final bool hasDescriptionInfo =
        hasText(visibleShortDescription) || hasText(description);
    final bool hasDeliveryInfo = hasText(deliverableDescription) ||
        hasText(visibleDeadline) ||
        hasText(instructionsAfterPayment);
    final bool hasScopeInfo = hasText(includedItems) ||
        hasText(excludedItems) ||
        hasText(customerRequirements);

    if (!hasDescriptionInfo && !hasDeliveryInfo && !hasScopeInfo) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDescriptionInfo)
          buildAdvertiserSection(
            title: 'Sobre este serviço',
            children: [
              buildAdvertiserField(
                label: 'Resumo do anúncio',
                text: visibleShortDescription,
              ),
              buildAdvertiserField(
                label: 'Descrição completa',
                text: description,
              ),
            ],
          ),
        if (hasDeliveryInfo)
          buildAdvertiserSection(
            title: 'Entrega digital',
            children: [
              buildAdvertiserField(
                label: 'O que será entregue ao cliente',
                text: deliverableDescription,
              ),
              buildAdvertiserField(
                label: 'Prazo de entrega ou atendimento',
                text: visibleDeadline,
              ),
              buildAdvertiserField(
                label: 'Instruções após pagamento',
                text: instructionsAfterPayment,
              ),
            ],
          ),
        if (hasScopeInfo)
          buildAdvertiserSection(
            title: 'Escopo do serviço',
            children: [
              buildAdvertiserField(
                label: 'O que está incluso',
                text: includedItems,
              ),
              buildAdvertiserField(
                label: 'O que não está incluso',
                text: excludedItems,
              ),
              buildAdvertiserField(
                label: 'Requisitos para o cliente',
                text: customerRequirements,
              ),
            ],
          ),
      ],
    );
  }

  Widget buildTimelineStep({
    required int number,
    required String title,
    required String description,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 31,
              height: 31,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEE75),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: textBold.copyWith(
                  color: Colors.black87,
                  fontSize: 13,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 1.4,
                height: 42,
                color: Colors.black.withValues(alpha: 0.08),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 14.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 12.8,
                    height: 1.32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildHero() {
    final List<String> images = imageUrls;

    return SizedBox(
      height: 310,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          images.isEmpty
              ? buildHeroImage('')
              : PageView.builder(
                  controller: imagePageController,
                  itemCount: images.length,
                  onPageChanged: (index) {
                    setState(() {
                      selectedImageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return buildHeroImage(images[index]);
                  },
                ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.34),
                    Colors.black.withValues(alpha: 0.02),
                    Colors.black.withValues(alpha: 0.48),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            child: GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.black87,
                  size: 24,
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildSoftChip(
                        icon: Icons.language_rounded,
                        label: serviceFormatLabel,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 26,
                          height: 1.04,
                        ),
                      ),
                    ],
                  ),
                ),
                if (images.length > 1) ...[
                  const SizedBox(width: 14),
                  Row(
                    children: List.generate(images.length, (index) {
                      final bool active = selectedImageIndex == index;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: active ? 17 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: active ? 0.98 : 0.58,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 118),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildHero(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Dimensions.paddingSizeDefault,
                    18,
                    Dimensions.paddingSizeDefault,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          buildProviderAvatar(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Anúncio de',
                                  style: textMedium.copyWith(
                                    color: Colors.grey.shade600,
                                    fontSize: 12.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  providerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textBold.copyWith(
                                    color: Colors.black87,
                                    fontSize: 16.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildSoftChip(
                            icon: Icons.category_rounded,
                            label: categoryName,
                          ),
                          buildSoftChip(
                            icon: Icons.delivery_dining_rounded,
                            label: deliveryTypeLabel,
                          ),
                          buildSoftChip(
                            icon: Icons.chat_rounded,
                            label: 'Chat seguro',
                          ),
                        ],
                      ),
                      if (isLoadingDetails) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          minHeight: 3,
                          color: const Color(0xFFFFEE75),
                          backgroundColor: Colors.grey.shade100,
                        ),
                      ],
                      const SizedBox(height: 22),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: priceValueLabel,
                                    style: textBold.copyWith(
                                      color: Colors.black87,
                                      fontSize: 25,
                                    ),
                                  ),
                                  TextSpan(
                                    text: priceUnitLabel,
                                    style: textMedium.copyWith(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFD84D),
                            size: 22,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$ratingLabel $reviewCountLabel',
                            style: textMedium.copyWith(
                              color: Colors.grey.shade800,
                              fontSize: 12.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      buildAdvertiserInformation(),
                      const SizedBox(height: 26),
                      buildSectionTitle(
                        'Como funciona',
                        subtitle:
                            'Ao clicar em Contratar agora você terá acesso ao anunciante.',
                      ),
                      const SizedBox(height: 16),
                      buildTimelineStep(
                        number: 1,
                        title: 'Segurança',
                        description:
                            'Evite contatos por telefone, WhatsApp ou e-mail. Trate todo o assunto dentro do chat seguro da Lokally.',
                      ),
                      buildTimelineStep(
                        number: 2,
                        title: 'Revise o anúncio',
                        description:
                            'Antes de emitir pagamento, tenha certeza do que está contratando.',
                      ),
                      buildTimelineStep(
                        number: 3,
                        title: 'Suporte Lokally',
                        description:
                            'Conte com o suporte via chat no app com a Lokally.',
                      ),
                      buildTimelineStep(
                        number: 4,
                        title: 'Receba a entrega digital',
                        description:
                            'O prestador vai enviar seus arquivos, links, materiais ou orientações conforme anunciado ou combinado via chat.',
                        isLast: true,
                      ),
                      const SizedBox(height: 28),
                      buildSectionTitle(
                        'Segurança Lokally',
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildSoftChip(
                            icon: Icons.verified_user_rounded,
                            label: 'Prestador avaliado',
                          ),
                          buildSoftChip(
                            icon: Icons.lock_rounded,
                            label: 'Chat seguro',
                          ),
                          buildSoftChip(
                            icon: Icons.support_agent_rounded,
                            label: 'Suporte Lokally',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                Dimensions.paddingSizeDefault,
                12,
                Dimensions.paddingSizeDefault,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, -8),
                    blurRadius: 28,
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total do serviço',
                          style: textRegular.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 11.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          priceValueLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textBold.copyWith(
                            color: Colors.black87,
                            fontSize: 17.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            isRequestingServiceChat ? null : handleContractTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEE75),
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          disabledBackgroundColor:
                              const Color(0xFFFFEE75).withValues(alpha: 0.64),
                          disabledForegroundColor:
                              Colors.black87.withValues(alpha: 0.72),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: isRequestingServiceChat
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.black87,
                                ),
                              )
                            : Text(
                                'Contratar agora',
                                style: textBold.copyWith(
                                  color: Colors.black87,
                                  fontSize: 14.2,
                                ),
                              ),
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
