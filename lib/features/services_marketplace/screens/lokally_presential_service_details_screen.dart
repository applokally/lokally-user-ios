import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_customer_order_list_screen.dart';
import 'package:ride_sharing_user_app/helper/login_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class _LokallyPublicDetailField {
  final String label;
  final String text;

  const _LokallyPublicDetailField({
    required this.label,
    required this.text,
  });
}

class LokallyPresentialServiceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> service;

  const LokallyPresentialServiceDetailsScreen({
    super.key,
    required this.service,
  });

  @override
  State<LokallyPresentialServiceDetailsScreen> createState() =>
      _LokallyPresentialServiceDetailsScreenState();
}

class _LokallyPresentialServiceDetailsScreenState
    extends State<LokallyPresentialServiceDetailsScreen> {
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

  Map<String, dynamic> mapFromDynamic(dynamic rawValue) {
    if (rawValue is Map) {
      return Map<String, dynamic>.from(rawValue);
    }

    if (rawValue is String) {
      final String text = rawValue.trim();

      if (text.isEmpty || text == 'null' || text == '{}' || text == '[]') {
        return <String, dynamic>{};
      }

      try {
        final dynamic decoded = jsonDecode(text);

        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return <String, dynamic>{};
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
      final Map<String, dynamic> nestedMap = mapFromDynamic(
        currentService[nestedKey],
      );

      if (nestedMap.isNotEmpty) {
        sources.add(nestedMap);
      }
    }

    final List<Map<String, dynamic>> expandableSources =
        List<Map<String, dynamic>>.from(sources);

    for (final Map<String, dynamic> source in expandableSources) {
      for (final String nestedKey in <String>[
        'extra_data',
        'presential_extra_data',
        'service_extra_data',
        'attendance_extra_data',
      ]) {
        final Map<String, dynamic> nestedMap = mapFromDynamic(
          source[nestedKey],
        );

        if (nestedMap.isNotEmpty) {
          sources.add(nestedMap);
        }
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
        fallback: 'Serviço presencial',
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
  String get categoryName {
    final String rawCategory = firstValue(
      <String>['category_name', 'category', 'service_category_name'],
      fallback: 'Serviço presencial',
    );

    final String publicCategory = sanitizeCommercialPublicText(rawCategory);

    return publicCategory.isEmpty ? 'Serviço presencial' : publicCategory;
  }

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

    return humanized.isEmpty ? 'Atendimento presencial' : humanized;
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

  String get attendanceLocationLabel {
    final String explicitLabel = firstValue(
      <String>[
        'attendance_location_label',
        'service_location_label',
        'location_label',
      ],
    );

    if (explicitLabel.isNotEmpty) {
      return explicitLabel;
    }

    final String attendanceLocation = firstValue(
      <String>[
        'attendance_location',
        'service_location',
        'service_delivery_type',
        'delivery_type',
      ],
    );

    return humanizeServiceDeliveryType(attendanceLocation);
  }

  String get serviceArea => firstValue(
        <String>[
          'service_area',
          'attendance_area',
          'coverage_area',
          'service_region',
          'region_description',
        ],
      );

  String get scheduleDays => firstValue(
        <String>[
          'schedule_days',
          'available_days',
          'attendance_days',
          'service_days',
        ],
      );

  String get scheduleHours => firstValue(
        <String>[
          'schedule_hours',
          'available_hours',
          'attendance_hours',
          'service_hours',
        ],
      );

  String get minimumNoticeHoursLabel {
    final String text = firstValue(
      <String>[
        'minimum_notice_hours',
        'notice_hours',
        'minimum_advance_hours',
      ],
    );

    if (!hasText(text)) {
      return '';
    }

    final int? hours = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));

    if (hours == null || hours <= 0) {
      return text;
    }

    if (hours == 1) {
      return '1 hora de antecedência';
    }

    return '$hours horas de antecedência';
  }

  String get estimatedDuration => firstValue(
        <String>[
          'estimated_duration',
          'duration',
          'service_duration',
          'execution_time',
          'estimated_execution_time',
        ],
      );

  String get serviceRadiusLabel {
    final String text = firstValue(
      <String>[
        'service_radius_km',
        'radius_km',
        'attendance_radius_km',
      ],
    );

    if (!hasText(text)) {
      return '';
    }

    final String normalized = text.replaceAll(',', '.').trim();
    final double? radius = double.tryParse(normalized);

    if (radius == null) {
      return text;
    }

    if (radius <= 0) {
      return 'Sem limite informado pelo prestador';
    }

    final bool isInteger = radius == radius.roundToDouble();
    final String radiusText = isInteger
        ? radius.toInt().toString()
        : radius.toStringAsFixed(1).replaceAll('.', ',');

    return 'Até $radiusText km';
  }

  String get presentialExtraDetails => firstValue(
        <String>[
          'presential_details',
          'attendance_details',
          'onsite_details',
          'in_person_details',
        ],
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

    return humanized.isEmpty ? 'Serviço presencial' : humanized;
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
            Icons.home_repair_service_rounded,
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
              Icons.home_repair_service_rounded,
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
    final String publicLabel = sanitizeCommercialPublicText(label);
    final String publicText = sanitizeCommercialPublicText(text);

    if (!hasText(publicLabel) || !hasText(publicText)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            publicLabel,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 13.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            publicText,
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

  String normalizeOptionText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String normalizeCommercialPublicPhrase(String value) {
    return normalizeOptionText(value)
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool isWarrantyRiskPublicText(String value) {
    final String normalized = normalizeCommercialPublicPhrase(value);

    return normalized == 'fora da garantia' ||
        normalized == 'fora de garantia' ||
        normalized == 'out of warranty';
  }

  String sanitizeCommercialPublicText(String value) {
    if (!hasText(value)) {
      return '';
    }

    final List<String> sanitizedLines = <String>[];

    for (final String line in value.split('\n')) {
      final String trimmedLine = line.trim();

      if (trimmedLine.isEmpty) {
        continue;
      }

      if (isWarrantyRiskPublicText(trimmedLine)) {
        sanitizedLines.add('Serviço especializado');
        continue;
      }

      final String normalizedLine =
          normalizeCommercialPublicPhrase(trimmedLine);

      if (normalizedLine.endsWith(' fora da garantia') ||
          normalizedLine.endsWith(' fora de garantia')) {
        sanitizedLines.add(
          trimmedLine.replaceAll(
            RegExp(r'fora\s+d[ae]\s+garantia', caseSensitive: false),
            'Serviço especializado',
          ),
        );
        continue;
      }

      sanitizedLines.add(trimmedLine);
    }

    return sanitizedLines.join('\n').trim();
  }

  List<dynamic> listFromDynamic(dynamic rawValue) {
    if (rawValue is List) {
      return rawValue;
    }

    if (rawValue is String) {
      final String text = rawValue.trim();

      if (text.isEmpty || text == 'null' || text == '[]' || text == '{}') {
        return <dynamic>[];
      }

      try {
        final dynamic decoded = jsonDecode(text);

        if (decoded is List) {
          return decoded;
        }
      } catch (_) {}
    }

    return <dynamic>[];
  }

  bool isTruthyConfiguredValue(dynamic rawValue) {
    if (rawValue is bool) {
      return rawValue;
    }

    final String text = normalizeOptionText('$rawValue');

    return text == '1' ||
        text == 'true' ||
        text == 'sim' ||
        text == 'yes' ||
        text == 'on' ||
        text == 'ativo' ||
        text == 'enabled' ||
        text == 'habilitado';
  }

  bool isFalsyConfiguredValue(dynamic rawValue) {
    if (rawValue is bool) {
      return !rawValue;
    }

    final String text = normalizeOptionText('$rawValue');

    return text.isEmpty ||
        text == 'null' ||
        text == '0' ||
        text == 'false' ||
        text == 'nao' ||
        text == 'não' ||
        text == 'no' ||
        text == 'off' ||
        text == 'inativo' ||
        text == 'disabled' ||
        text == 'desabilitado';
  }

  bool shouldHideConfiguredKey(String key) {
    final String normalized = key.trim().toLowerCase();

    if (isWarrantyRiskPublicText(normalized)) {
      return true;
    }

    const Set<String> hiddenKeys = <String>{
      'id',
      'uuid',
      'product_id',
      'service_id',
      'seller_id',
      'store_id',
      'category_id',
      'user_id',
      'admin_id',
      'created_at',
      'updated_at',
      'deleted_at',
      'created_by',
      'updated_by',
      'deleted_by',
      'status',
      'approval_status',
      'is_active',
      'is_approved',
      'approved_at',
      'approved_by',
      'rejection_note',
      'image',
      'images',
      'gallery',
      'media',
      'main_image',
      'main_image_url',
      'image_url',
      'thumbnail',
      'gallery_image_urls',
      'product_images',
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
      'name',
      'title',
      'service_title',
      'product_name',
      'description',
      'full_description',
      'long_description',
      'service_description',
      'details',
      'short_description',
      'summary',
      'resume',
      'category_name',
      'category',
      'service_category_name',
      'price',
      'final_price',
      'regular_price',
      'old_price',
      'cost_price',
      'price_value_label',
      'price_unit_label',
      'rating_label',
      'review_count_label',
      'service_format',
      'format',
      'service_format_label',
      'format_label',
      'service_delivery_type',
      'delivery_type',
      'delivery_type_label',
      'service_delivery_label',
      'attendance_location',
      'service_location',
      'attendance_location_label',
      'service_location_label',
      'location_label',
      'service_area',
      'attendance_area',
      'coverage_area',
      'service_region',
      'region_description',
      'service_radius_km',
      'radius_km',
      'attendance_radius_km',
      'schedule_days',
      'available_days',
      'attendance_days',
      'service_days',
      'schedule_hours',
      'available_hours',
      'attendance_hours',
      'service_hours',
      'minimum_notice_hours',
      'notice_hours',
      'minimum_advance_hours',
      'estimated_duration',
      'duration',
      'service_duration',
      'estimated_deadline',
      'delivery_deadline',
      'deadline',
      'estimated_delivery_time',
      'delivery_time',
      'execution_time',
      'estimated_execution_time',
      'service_time',
      'deliverable_description',
      'delivery_description',
      'deliverables',
      'what_will_be_delivered',
      'what_will_deliver',
      'delivery_details',
      'included_items',
      'included',
      'includes',
      'what_is_included',
      'service_includes',
      'excluded_items',
      'excluded',
      'not_included',
      'what_is_not_included',
      'service_excludes',
      'customer_requirements',
      'client_requirements',
      'buyer_requirements',
      'requirements',
      'required_from_customer',
      'instructions_after_payment',
      'post_payment_instructions',
      'after_payment_instructions',
      'instructions',
      'service_instructions',
      'extra_data',
      'presential_extra_data',
      'service_extra_data',
      'attendance_extra_data',
    };

    if (hiddenKeys.contains(normalized)) {
      return true;
    }

    return normalized.contains('token') ||
        normalized.contains('password') ||
        normalized.contains('secret') ||
        normalized.contains('document') ||
        normalized.contains('cpf') ||
        normalized.contains('cnpj') ||
        normalized.contains('rg') ||
        normalized.contains('phone') ||
        normalized.contains('whatsapp') ||
        normalized.contains('email') ||
        normalized.contains('address') ||
        normalized.contains('postal_code') ||
        normalized.contains('zip') ||
        normalized.contains('latitude') ||
        normalized.contains('longitude') ||
        normalized.contains('lat') ||
        normalized.contains('lng');
  }

  bool mapLooksLikeSingleValue(Map<String, dynamic> map) {
    for (final String preferredKey in <String>[
      'value',
      'text',
      'label',
      'description',
      'title',
      'name',
      'content',
    ]) {
      if (map.containsKey(preferredKey) &&
          hasText(cleanText(map[preferredKey]))) {
        return true;
      }
    }

    return false;
  }

  String humanizePublicFieldLabel(String key) {
    final String normalized = key.trim().toLowerCase();

    const Map<String, String> labels = <String, String>{
      'price_display_type': 'Exibição do preço',
      'price_label': 'Informação do preço',
      'request_button_type': 'Tipo de solicitação',
      'accepts_quote': 'Aceita orçamento',
      'accepts_schedule': 'Aceita agendamento',
      'accepts_immediate_request': 'Aceita solicitação imediata',
      'accepts_lokally_meeting': 'Lokally Meeting disponível',
      'allows_tracking': 'Permite acompanhamento',
      'allows_recurring': 'Permite atendimento recorrente',
      'customer_address_required': 'Endereço do cliente necessário',
      'provider_address_enabled': 'Atendimento no endereço do prestador',
      'needs_scheduling': 'Precisa de agendamento',
      'home_service': 'Atende em domicílio',
      'client_location': 'Atende no endereço do cliente',
      'provider_location': 'Atende no endereço do prestador',
      'region': 'Atendimento regional',
      'online_payment': 'Pagamento pelo app',
      'chat_required': 'Chat obrigatório',
      'meeting_required': 'Reunião necessária',
      'emergency_service': 'Atendimento emergencial',
      'same_day_service': 'Atendimento no mesmo dia',
      'weekend_service': 'Atendimento aos fins de semana',
      'holiday_service': 'Atendimento em feriados',
      'materials_included': 'Materiais inclusos',
      'equipment_included': 'Equipamentos inclusos',
      'warranty': 'Garantia',
      'warranty_days': 'Garantia em dias',
      'service_guarantee': 'Garantia do serviço',
    };

    if (labels.containsKey(normalized)) {
      return labels[normalized]!;
    }

    final String readable = normalized
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (readable.isEmpty) {
      return 'Informação do serviço';
    }

    final List<String> words = readable.split(' ');

    return words
        .map((word) =>
            word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String firstValueFromMap(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final String key in keys) {
      if (!map.containsKey(key)) {
        continue;
      }

      final String text = cleanText(map[key]);

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  String humanizeConfiguredTextValue(String key, String rawText) {
    final String normalizedKey = key.trim().toLowerCase();
    final String normalizedValue = normalizeOptionText(rawText);

    if (normalizedKey == 'price_display_type') {
      switch (normalizedValue) {
        case 'fixed':
        case 'fixo':
          return 'Preço fixo';
        case 'from':
        case 'starting_from':
        case 'a partir de':
          return 'A partir de';
        case 'quote':
        case 'orcamento':
        case 'sob consulta':
          return 'Sob consulta';
      }
    }

    if (normalizedKey == 'request_button_type') {
      switch (normalizedValue) {
        case 'quote':
        case 'orcamento':
          return 'Solicitar orçamento';
        case 'schedule':
        case 'agendamento':
          return 'Agendar atendimento';
        case 'immediate':
        case 'request':
        case 'solicitar':
          return 'Solicitar atendimento';
        case 'chat':
          return 'Conversar pelo chat';
      }
    }

    if (normalizedKey.contains('delivery_type') ||
        normalizedKey.contains('attendance_location')) {
      final String humanized = humanizeServiceDeliveryType(rawText);

      return humanized.isEmpty ? rawText.trim() : humanized;
    }

    return sanitizeCommercialPublicText(rawText.trim());
  }

  String formatConfiguredFieldValue(String key, dynamic rawValue) {
    if (rawValue == null || isFalsyConfiguredValue(rawValue)) {
      return '';
    }

    if (rawValue is bool) {
      return rawValue ? 'Sim' : '';
    }

    final Map<String, dynamic> decodedMap = mapFromDynamic(rawValue);

    if (decodedMap.isNotEmpty) {
      final String optionLabel = firstValueFromMap(
        decodedMap,
        <String>['public_label', 'label', 'title', 'name', 'text'],
      );
      final dynamic selectedValue = decodedMap['value'] ??
          decodedMap['selected'] ??
          decodedMap['checked'] ??
          decodedMap['enabled'] ??
          decodedMap['is_selected'] ??
          decodedMap['active'];

      if (optionLabel.isNotEmpty && selectedValue != null) {
        if (isFalsyConfiguredValue(selectedValue)) {
          return '';
        }

        return isTruthyConfiguredValue(selectedValue)
            ? optionLabel
            : '$optionLabel: ${humanizeConfiguredTextValue(key, cleanText(selectedValue))}';
      }

      if (mapLooksLikeSingleValue(decodedMap)) {
        return humanizeConfiguredTextValue(key, cleanText(decodedMap));
      }

      final List<String> parts = <String>[];

      decodedMap.forEach((dynamic childKey, dynamic childValue) {
        final String stringKey = '$childKey';

        if (shouldHideConfiguredKey(stringKey) ||
            isFalsyConfiguredValue(childValue)) {
          return;
        }

        final String childText =
            formatConfiguredFieldValue(stringKey, childValue);

        if (!hasText(childText)) {
          return;
        }

        if (childText == 'Sim') {
          parts.add(humanizePublicFieldLabel(stringKey));
        } else {
          parts.add('${humanizePublicFieldLabel(stringKey)}: $childText');
        }
      });

      return parts.join('\n');
    }

    final List<dynamic> decodedList = listFromDynamic(rawValue);

    if (decodedList.isNotEmpty) {
      final List<String> parts = <String>[];

      for (final dynamic item in decodedList) {
        if (item is Map) {
          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          final String itemText = mapLooksLikeSingleValue(itemMap)
              ? cleanText(itemMap)
              : formatConfiguredFieldValue(key, itemMap);

          if (hasText(itemText)) {
            parts.add(itemText);
          }
        } else {
          final String itemText = formatConfiguredFieldValue(key, item);

          if (hasText(itemText) && itemText != 'Sim') {
            parts.add(itemText);
          }
        }
      }

      return parts.join('\n');
    }

    if (isTruthyConfiguredValue(rawValue)) {
      return 'Sim';
    }

    final String text = cleanText(rawValue);

    if (!hasText(text)) {
      return '';
    }

    return humanizeConfiguredTextValue(key, text);
  }

  List<Map<String, dynamic>> serviceDataSources() {
    final List<Map<String, dynamic>> sources = <Map<String, dynamic>>[
      currentService,
    ];

    for (final String nestedKey in <String>[
      'service',
      'service_details',
      'details',
      'metadata',
    ]) {
      final Map<String, dynamic> nestedMap = mapFromDynamic(
        currentService[nestedKey],
      );

      if (nestedMap.isNotEmpty) {
        sources.add(nestedMap);
      }
    }

    return sources;
  }

  List<_LokallyPublicDetailField> configuredExtraFields() {
    final List<_LokallyPublicDetailField> fields =
        <_LokallyPublicDetailField>[];
    final Set<String> seen = <String>{};

    void addField(
      String key,
      dynamic rawValue, {
      String prefix = '',
    }) {
      if (shouldHideConfiguredKey(key)) {
        return;
      }

      final String text = sanitizeCommercialPublicText(
        formatConfiguredFieldValue(key, rawValue),
      );

      if (!hasText(text)) {
        return;
      }

      final String baseLabel = sanitizeCommercialPublicText(
        humanizePublicFieldLabel(key),
      );

      if (!hasText(baseLabel)) {
        return;
      }

      if (isWarrantyRiskPublicText(baseLabel) ||
          isWarrantyRiskPublicText(text)) {
        return;
      }

      final String label =
          prefix.trim().isEmpty ? baseLabel : '$prefix - $baseLabel';
      final String uniqueKey = normalizeComparableText('$label|$text');

      if (seen.contains(uniqueKey)) {
        return;
      }

      seen.add(uniqueKey);
      fields.add(_LokallyPublicDetailField(label: label, text: text));
    }

    void collectFromMap(
      Map<String, dynamic> map, {
      String prefix = '',
    }) {
      map.forEach((dynamic rawKey, dynamic rawValue) {
        final String key = '$rawKey';

        if (shouldHideConfiguredKey(key)) {
          return;
        }

        final Map<String, dynamic> decodedMap = mapFromDynamic(rawValue);

        if (decodedMap.isNotEmpty && !mapLooksLikeSingleValue(decodedMap)) {
          final String nextPrefix = prefix.trim().isEmpty
              ? humanizePublicFieldLabel(key)
              : '$prefix - ${humanizePublicFieldLabel(key)}';
          collectFromMap(decodedMap, prefix: nextPrefix);
          return;
        }

        addField(key, rawValue, prefix: prefix);
      });
    }

    for (final String key in <String>[
      'price_display_type',
      'price_label',
      'request_button_type',
      'needs_scheduling',
      'accepts_quote',
      'accepts_schedule',
      'accepts_immediate_request',
      'accepts_lokally_meeting',
      'allows_tracking',
      'allows_recurring',
      'customer_address_required',
      'provider_address_enabled',
    ]) {
      addField(key, rawValueForKey(key));
    }

    for (final Map<String, dynamic> source in serviceDataSources()) {
      for (final String nestedKey in <String>[
        'presential_extra_data',
        'extra_data',
        'service_extra_data',
        'attendance_extra_data',
        'public_options',
        'service_options',
        'selected_options',
        'configured_options',
      ]) {
        final Map<String, dynamic> nestedMap =
            mapFromDynamic(source[nestedKey]);

        if (nestedMap.isNotEmpty) {
          collectFromMap(nestedMap);
        }
      }
    }

    return fields;
  }

  Widget buildConfiguredField(_LokallyPublicDetailField field) {
    return buildAdvertiserField(
      label: field.label,
      text: field.text,
    );
  }

  Widget buildAdvertiserInformation() {
    final String visibleShortDescription =
        hasText(shortDescription) && !isSameText(shortDescription, description)
            ? shortDescription
            : '';
    final String visibleDeadline =
        hasText(estimatedDeadline) ? estimatedDeadline : executionTime;
    final String visibleDuration =
        hasText(estimatedDuration) ? estimatedDuration : visibleDeadline;
    final List<_LokallyPublicDetailField> extraFields = configuredExtraFields();
    final bool hasDescriptionInfo =
        hasText(visibleShortDescription) || hasText(description);
    final bool hasAttendanceInfo = hasText(attendanceLocationLabel) ||
        hasText(serviceArea) ||
        hasText(serviceRadiusLabel) ||
        hasText(scheduleDays) ||
        hasText(scheduleHours) ||
        hasText(minimumNoticeHoursLabel) ||
        hasText(visibleDuration) ||
        hasText(deliverableDescription) ||
        hasText(presentialExtraDetails) ||
        hasText(instructionsAfterPayment);
    final bool hasScopeInfo = hasText(includedItems) ||
        hasText(excludedItems) ||
        hasText(customerRequirements);
    final bool hasExtraInfo = extraFields.isNotEmpty;

    if (!hasDescriptionInfo &&
        !hasAttendanceInfo &&
        !hasScopeInfo &&
        !hasExtraInfo) {
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
        if (hasAttendanceInfo)
          buildAdvertiserSection(
            title: 'Atendimento presencial',
            children: [
              buildAdvertiserField(
                label: 'Tipo de atendimento',
                text: attendanceLocationLabel,
              ),
              buildAdvertiserField(
                label: 'Área de atendimento',
                text: serviceArea,
              ),
              buildAdvertiserField(
                label: 'Raio de atendimento',
                text: serviceRadiusLabel,
              ),
              buildAdvertiserField(
                label: 'Dias de atendimento',
                text: scheduleDays,
              ),
              buildAdvertiserField(
                label: 'Horários de atendimento',
                text: scheduleHours,
              ),
              buildAdvertiserField(
                label: 'Antecedência mínima',
                text: minimumNoticeHoursLabel,
              ),
              buildAdvertiserField(
                label: 'Duração estimada',
                text: visibleDuration,
              ),
              buildAdvertiserField(
                label: 'Como o atendimento será realizado',
                text: deliverableDescription,
              ),
              buildAdvertiserField(
                label: 'Detalhes do atendimento presencial',
                text: presentialExtraDetails,
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
        if (hasExtraInfo)
          buildAdvertiserSection(
            title: 'Opções configuradas pelo prestador',
            children: extraFields.map(buildConfiguredField).toList(),
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
                        icon: Icons.location_on_rounded,
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
                            icon: Icons.place_rounded,
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
                            'Ao solicitar o atendimento você inicia a conversa com o prestador pelo chat seguro da Lokally.',
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
                        title: 'Receba o atendimento presencial',
                        description:
                            'O prestador realizará o atendimento presencial conforme anunciado ou combinado pelo chat seguro.',
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
                          'Valor do serviço',
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
                                'Solicitar atendimento',
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
