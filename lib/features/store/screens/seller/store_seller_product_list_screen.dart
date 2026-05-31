import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_cart_screen.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

import 'store_seller_products_screen.dart';
import 'store_seller_service_form_screen.dart';
import 'store_seller_real_estate_form_screen.dart';
import 'store_seller_vehicle_form_screen.dart';
import 'store_seller_publish_type_screen.dart';

String _storeSellerText(String value, {Map<String, String>? params}) {
  final String rawValue = value.trim();

  if (rawValue.isEmpty) {
    return rawValue;
  }

  const Map<String, String> labels = <String, String>{
    'store_advertise_again_question': 'Você anunciaria novamente na Lokally?',
    'store_all': 'Todos',
    'store_answer_all_questions_to_finish':
        'Responda todas as perguntas para finalizar.',
    'store_approved': 'Aprovado',
    'store_approved_plural': 'Aprovados',
    'store_bathroom_count': '@count banheiros',
    'store_bathroom_count_one': '@count banheiro',
    'store_bedroom_count': '@count quartos',
    'store_bedroom_count_one': '@count quarto',
    'store_cancel': 'Cancelar',
    'store_close': 'Fechar',
    'store_closed': 'Encerrado',
    'store_complete_sale': 'Concluir',
    'store_create_first_listing_description':
        'Cadastre seu primeiro produto, serviço, veículo ou imóvel para análise da Lokally.',
    'store_customer_location_service': 'Atendimento no local do cliente',
    'store_delivery_by_download': 'Entrega por download',
    'store_digital_service': 'Serviço digital',
    'store_draft': 'Rascunho',
    'store_edit_and_resubmit': 'Editar e reenviar',
    'store_edit_product': 'Editar produto',
    'store_edit_product_and_resubmit': 'Editar produto e reenviar',
    'store_edit_property': 'Editar imóvel',
    'store_edit_service': 'Editar serviço',
    'store_edit_service_and_resubmit': 'Editar serviço e reenviar',
    'store_edit_vehicle': 'Editar veículo',
    'store_filter_with_count': '@label (@count)',
    'store_finish_payment_mercado_pago':
        'Finalize o pagamento no Mercado Pago.',
    'store_immediate': 'Disponível imediato',
    'store_invalid_listing_payment': 'Anúncio inválido para pagamento.',
    'store_license_plate_with_value': 'Placa: @value',
    'store_listing_cannot_be_edited': 'Este anúncio não pode ser editado.',
    'store_listing_cannot_mark_sold_yet':
        'Este anúncio ainda não pode ser marcado como vendido.',
    'store_listing_payment_create_error':
        'Não foi possível gerar o pagamento do anúncio.',
    'store_listing_payment_start_error':
        'Não foi possível iniciar o pagamento do anúncio.',
    'store_listing_rejected': 'Anúncio reprovado',
    'store_listings_load_error': 'Não foi possível carregar seus anúncios.',
    'store_listings_status_empty_description':
        'Nenhum anúncio encontrado neste filtro.',
    'store_mark_as_sold': 'Marcar como vendido',
    'store_mark_listing_sold_error':
        'Não foi possível marcar o anúncio como vendido.',
    'store_my_listings': 'Meus anúncios',
    'store_new': 'Novo',
    'store_no': 'Não',
    'store_no_cart_or_delivery': 'Sem informações adicionais',
    'store_no_listing_registered': 'Nenhum anúncio cadastrado',
    'store_no_listing_with_status': 'Nenhum anúncio neste status',
    'store_online_service': 'Serviço online',
    'store_package_with_value': 'Pacote: @value',
    'store_parking_space_count': '@count vagas',
    'store_parking_space_count_one': '@count vaga',
    'store_pay_listing': 'Pagar anúncio',
    'store_payment_link_created': 'Pagamento criado com sucesso.',
    'store_payment_link_missing': 'Link de pagamento não encontrado.',
    'store_payment_sent_wait_confirmation':
        'Pagamento enviado. Aguarde a confirmação.',
    'store_presential_service': 'Serviço presencial',
    'store_product': 'Produto',
    'store_product_rejected': 'Produto reprovado',
    'store_properties': 'Imóveis',
    'store_property': 'Imóvel',
    'store_property_listing': 'Anúncio de imóvel',
    'store_provider_location_service': 'Atendimento no local do prestador',
    'store_rate_your_experience': 'Avalie sua experiência',
    'store_regional_service': 'Atendimento regional',
    'store_register_new': 'Cadastrar novo',
    'store_registered_listings': 'Anúncios cadastrados',
    'store_registered_listings_description':
        'Acompanhe seus produtos, serviços, veículos e imóveis enviados para análise da Lokally.',
    'store_rejected': 'Reprovado',
    'store_rejected_plural': 'Reprovados',
    'store_rejected_view_reason': 'Ver motivo da reprovação',
    'store_rejection_reason': 'Motivo da reprovação',
    'store_rejection_reason_not_informed': 'Motivo não informado.',
    'store_satisfied_listing_lokally_question':
        'Você ficou satisfeito com a experiência na Lokally?',
    'store_service': 'Serviço',
    'store_service_attendance': 'Atendimento do serviço',
    'store_services': 'Serviços',
    'store_sold': 'Vendido',
    'store_sold_survey_congrats': 'Parabéns pela venda!',
    'store_sold_survey_send_error': 'Não foi possível enviar sua resposta.',
    'store_sold_survey_thanks_description':
        'Obrigado por responder. Suas informações ajudam a melhorar os anúncios da Lokally.',
    'store_sold_through_lokally_question':
        'A venda aconteceu por meio da Lokally?',
    'store_stock_with_value': 'Estoque: @value',
    'store_suspended': 'Suspenso',
    'store_thanks_for_answering': 'Obrigado por responder',
    'store_uncategorized': 'Sem categoria',
    'store_vehicle': 'Veículo',
    'store_vehicle_listing': 'Anúncio de veículo',
    'store_vehicles': 'Veículos',
    'store_view_lokally_rejection_reason':
        'Veja o motivo informado pela Lokally.',
    'store_view_reason_adjust_resubmit':
        'Veja o motivo, ajuste e envie novamente.',
    'store_waiting': 'Aguardando',
    'store_waiting_approval': 'Aguardando aprovação',
    'store_waiting_payment': 'Aguardando pagamento',
    'store_within_24h': 'Em até 24h',
    'store_year_with_value': 'Ano: @value',
    'store_yes': 'Sim',
    'approved': 'Aprovado',
    'pending': 'Aguardando aprovação',
    'payment_pending': 'Aguardando pagamento',
    'rejected': 'Reprovado',
    'suspended': 'Suspenso',
    'sold': 'Vendido',
    'closed': 'Encerrado',
    'expired': 'Expirado',
    'active': 'Em veiculação',
    'paid': 'Pago',
    'failed': 'Falhou',
    'draft': 'Rascunho',
    'vehicle': 'Veículo',
    'vehicle_ad': 'Veículo',
    'real_estate_ad': 'Imóvel',
    'service': 'Serviço',
    'physical': 'Produto físico',
    'product': 'Produto',
    'digital': 'Serviço digital',
    'presential': 'Serviço presencial',
    'download': 'Entrega por download',
    'online': 'Serviço online',
    'client_location': 'Atendimento no local do cliente',
    'provider_location': 'Atendimento no local do prestador',
    'region': 'Atendimento regional',
    'sale': 'Venda',
    'rent': 'Aluguel',
    'seasonal': 'Temporada',
    'sell': 'Venda',
    'apartment': 'Apartamento',
    'house': 'Casa',
    'commercial': 'Comercial',
    'land': 'Terreno',
    'new': 'Novo',
    'used': 'Usado',
  };

  String result = labels[rawValue] ?? rawValue.tr;

  if (result == rawValue && rawValue.startsWith('store_')) {
    result = rawValue.replaceFirst('store_', '').replaceAll('_', ' ').trim();

    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1);
    }
  }

  if (params != null && params.isNotEmpty) {
    params.forEach((String key, String paramValue) {
      result = result
          .replaceAll('@$key', paramValue)
          .replaceAll('{$key}', paramValue)
          .replaceAll(':$key', paramValue);
    });
  }

  return result;
}

extension _StoreSellerTextExtension on String {
  String get sellerText => _storeSellerText(this);

  String sellerTextParams(Map<String, String> params) {
    return _storeSellerText(this, params: params);
  }
}

class StoreSellerProductListScreen extends StatefulWidget {
  const StoreSellerProductListScreen({super.key});

  @override
  State<StoreSellerProductListScreen> createState() =>
      _StoreSellerProductListScreenState();
}

class _StoreSellerProductListScreenState
    extends State<StoreSellerProductListScreen> {
  static const String storeProductsUri = '/api/customer/store/products';

  static String vehicleAdPaymentUri(String vehicleAdId) {
    return '/api/customer/store/vehicle-ad/$vehicleAdId/payment';
  }

  static String realEstateAdPaymentUri(String realEstateAdId) {
    return '/api/customer/store/real-estate-ad/$realEstateAdId/payment';
  }

  static String serviceAdPaymentUri(String serviceAdId) {
    return '/api/customer/store/service/$serviceAdId/payment';
  }

  static String vehicleAdSoldUri(String vehicleAdId) {
    return '/api/customer/store/vehicle-ad/$vehicleAdId/sold';
  }

  bool isLoading = false;
  String selectedStatus = 'all';

  List<StoreSellerProductItem> products = [];
  StoreSellerProductCounts counts = StoreSellerProductCounts.empty();

  final List<StoreSellerProductStatusFilter> filters = [
    StoreSellerProductStatusFilter(
      keyName: 'all',
      label: 'store_all',
      apiStatus: null,
    ),
    StoreSellerProductStatusFilter(
      keyName: 'pending',
      label: 'store_waiting',
      apiStatus: 'pending',
    ),
    StoreSellerProductStatusFilter(
      keyName: 'approved',
      label: 'store_approved_plural',
      apiStatus: 'approved',
    ),
    StoreSellerProductStatusFilter(
      keyName: 'rejected',
      label: 'store_rejected_plural',
      apiStatus: 'rejected',
    ),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadProducts();
    });
  }

  Future<void> loadProducts({String? statusKey}) async {
    if (isLoading) {
      return;
    }

    final String nextStatus = statusKey ?? selectedStatus;
    final StoreSellerProductStatusFilter filter = filters.firstWhere(
      (item) => item.keyName == nextStatus,
      orElse: () => filters.first,
    );

    setState(() {
      isLoading = true;
      selectedStatus = nextStatus;
    });

    final String uri = filter.apiStatus == null
        ? storeProductsUri
        : '$storeProductsUri?status=${filter.apiStatus}';

    final Response response = await Get.find<ApiClient>().getData(uri);

    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = false;
    });

    final dynamic body = response.body;

    if (response.statusCode != 200 || body is! Map || body['status'] != true) {
      showStoreMessage('store_listings_load_error');
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

    final dynamic productsValue = data['products'];
    final List<dynamic> productList =
        productsValue is List ? productsValue : <dynamic>[];

    setState(() {
      counts = StoreSellerProductCounts.fromMap(countsMap);
      products = productList
          .whereType<Map>()
          .map((item) => StoreSellerProductItem.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    });
  }

  void openCreateProduct() {
    Get.to(() => const StoreSellerPublishTypeScreen())?.then((_) {
      loadProducts();
    });
  }

  void openEditProduct(StoreSellerProductItem product) {
    if (product.isSold) {
      showStoreMessage('store_listing_cannot_be_edited');
      return;
    }

    if (product.isService) {
      Get.to(
        () => StoreSellerServiceFormScreen(
          initialService: product.toInitialServiceMap(),
        ),
      )?.then((_) {
        loadProducts();
      });
      return;
    }

    if (product.isVehicle) {
      Get.to(
        () => StoreSellerVehicleFormScreen(
          initialVehicle: product.toInitialVehicleMap(),
        ),
      )?.then((_) {
        loadProducts();
      });
      return;
    }

    if (product.isRealEstate) {
      Get.to(
        () => StoreSellerRealEstateFormScreen(
          initialRealEstate: product.toInitialRealEstateMap(),
        ),
      )?.then((_) {
        loadProducts();
      });
      return;
    }

    Get.to(
      () => StoreSellerProductsScreen(
        initialProduct: product.toInitialProductMap(),
      ),
    )?.then((_) {
      loadProducts();
    });
  }

  Future<void> openMarketplaceAdPayment(StoreSellerProductItem product) async {
    if (!product.isMarketplaceAd || product.id.trim().isEmpty) {
      showStoreMessage('store_invalid_listing_payment');
      return;
    }

    final String uri = product.isService
        ? serviceAdPaymentUri(product.id)
        : product.isRealEstate
            ? realEstateAdPaymentUri(product.id)
            : vehicleAdPaymentUri(product.id);

    try {
      final Response response = await Get.find<ApiClient>().postData(
        uri,
        <String, String>{},
      );

      if (!mounted) {
        return;
      }

      final dynamic responseBody = response.body;
      String message = response.statusCode == 200 || response.statusCode == 201
          ? 'store_payment_link_created'
          : 'store_listing_payment_create_error';

      if (responseBody is Map && responseBody['message'] != null) {
        message = responseBody['message'].toString();
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        showStoreMessage(message);
        return;
      }

      final dynamic dataValue =
          responseBody is Map ? responseBody['data'] : null;
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};
      final String paymentUrl = '${data['payment_url'] ?? ''}'.trim();

      if (paymentUrl.isEmpty) {
        showStoreMessage(
          'store_payment_link_missing',
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
        showStoreMessage(
          'store_payment_sent_wait_confirmation',
        );
      } else {
        showStoreMessage(
          'store_finish_payment_mercado_pago',
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 650));
      loadProducts();
    } catch (_) {
      if (mounted) {
        showStoreMessage('store_listing_payment_start_error');
      }
    }
  }

  Future<void> openVehicleSoldSurvey(StoreSellerProductItem product) async {
    if (!product.canMarkAsSold || product.id.trim().isEmpty) {
      showStoreMessage('store_listing_cannot_mark_sold_yet');
      return;
    }

    bool? soldThroughLokally;
    bool? satisfiedWithLokally;
    bool? wouldAdvertiseAgain;
    int rating = 0;
    bool isSubmitting = false;

    final Color primaryColor = Theme.of(context).primaryColor;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submitSurvey() async {
              if (soldThroughLokally == null ||
                  satisfiedWithLokally == null ||
                  wouldAdvertiseAgain == null ||
                  rating <= 0) {
                showStoreMessage('store_answer_all_questions_to_finish');
                return;
              }

              setModalState(() {
                isSubmitting = true;
              });

              try {
                final Response response = await Get.find<ApiClient>().postData(
                  vehicleAdSoldUri(product.id),
                  <String, dynamic>{
                    'sold_through_lokally': soldThroughLokally == true,
                    'satisfied_with_lokally': satisfiedWithLokally == true,
                    'would_advertise_again': wouldAdvertiseAgain == true,
                    'rating': rating,
                  },
                );

                if (!mounted) {
                  return;
                }

                if (response.statusCode != 200 && response.statusCode != 201) {
                  String message = 'store_mark_listing_sold_error';

                  final dynamic body = response.body;

                  if (body is Map && body['message'] != null) {
                    message = body['message'].toString();
                  }

                  setModalState(() {
                    isSubmitting = false;
                  });

                  showStoreMessage(message);
                  return;
                }

                Get.back();

                await showVehicleSoldThanksDialog();
                loadProducts();
              } catch (_) {
                if (mounted) {
                  setModalState(() {
                    isSubmitting = false;
                  });

                  showStoreMessage(
                    'store_sold_survey_send_error',
                  );
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 18),
                        blurRadius: 36,
                        color: Colors.black.withValues(alpha: 0.18),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(17),
                              ),
                              child: Icon(
                                Icons.verified_rounded,
                                color: primaryColor,
                                size: 25,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'store_sold_survey_congrats'.sellerText,
                                style: textBold.copyWith(
                                  color: Colors.black87,
                                  fontSize: 16.2,
                                  height: 1.18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        VehicleSoldSurveyOption(
                          title: 'store_sold_through_lokally_question',
                          value: soldThroughLokally,
                          primaryColor: primaryColor,
                          onChanged: (value) {
                            setModalState(() {
                              soldThroughLokally = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        VehicleSoldSurveyOption(
                          title: 'store_satisfied_listing_lokally_question',
                          value: satisfiedWithLokally,
                          primaryColor: primaryColor,
                          onChanged: (value) {
                            setModalState(() {
                              satisfiedWithLokally = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        VehicleSoldSurveyOption(
                          title: 'store_advertise_again_question',
                          value: wouldAdvertiseAgain,
                          primaryColor: primaryColor,
                          onChanged: (value) {
                            setModalState(() {
                              wouldAdvertiseAgain = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'store_rate_your_experience'.sellerText,
                          style: textBold.copyWith(
                            color: Colors.black87,
                            fontSize: 13.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(5, (index) {
                            final int starValue = index + 1;
                            final bool selected = rating >= starValue;

                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  rating = starValue;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: Icon(
                                  selected
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: selected
                                      ? const Color(0xFFFFB300)
                                      : Colors.grey.shade400,
                                  size: 34,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 18),
                        Material(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            onTap: isSubmitting ? null : submitSurvey,
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              height: 48,
                              width: double.infinity,
                              alignment: Alignment.center,
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'store_complete_sale'.sellerText,
                                      style: textBold.copyWith(
                                        color: Colors.white,
                                        fontSize: 13.6,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(modalContext).pop(),
                            child: Text(
                              'store_cancel'.sellerText,
                              style: textBold.copyWith(
                                color: Colors.grey.shade600,
                                fontSize: 12.6,
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
  }

  Future<void> showVehicleSoldThanksDialog() async {
    final Color primaryColor = Theme.of(context).primaryColor;

    await showDialog<void>(
      context: context,
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
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: primaryColor,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'store_thanks_for_answering'.sellerText,
                  textAlign: TextAlign.center,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'store_sold_survey_thanks_description'.sellerText,
                  textAlign: TextAlign.center,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 13.2,
                    height: 1.34,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 46,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'store_close'.sellerText,
                      style: textBold.copyWith(
                        color: Colors.white,
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

  void showStoreMessage(String message) {
    final Color primaryColor = Theme.of(context).primaryColor;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.sellerText,
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
      case 'pending':
        return counts.pending;
      case 'approved':
        return counts.approved;
      case 'rejected':
        return counts.rejected;
      default:
        return counts.all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F6),
      body: Column(
        children: [
          StoreSellerProductListTopBar(
            primaryColor: primaryColor,
            onBackTap: () => Get.back(),
            onAddTap: openCreateProduct,
          ),
          Expanded(
            child: RefreshIndicator(
              color: primaryColor,
              onRefresh: () => loadProducts(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Dimensions.paddingSizeDefault,
                  16,
                  Dimensions.paddingSizeDefault,
                  28,
                ),
                children: [
                  StoreSellerProductListIntro(
                    primaryColor: primaryColor,
                    counts: counts,
                    onCreateTap: openCreateProduct,
                  ),
                  const SizedBox(height: 14),
                  StoreSellerProductStatusFilters(
                    primaryColor: primaryColor,
                    filters: filters,
                    selectedStatus: selectedStatus,
                    countForFilter: countForFilter,
                    onChanged: (status) => loadProducts(statusKey: status),
                  ),
                  const SizedBox(height: 14),
                  if (isLoading)
                    StoreSellerProductsLoading(primaryColor: primaryColor)
                  else if (products.isEmpty)
                    StoreSellerProductsEmpty(
                      primaryColor: primaryColor,
                      selectedStatus: selectedStatus,
                      onCreateTap: openCreateProduct,
                    )
                  else
                    ...products.map(
                      (product) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StoreSellerProductCard(
                          product: product,
                          primaryColor: primaryColor,
                          onEditTap: () => openEditProduct(product),
                          onPaymentTap: () => openMarketplaceAdPayment(product),
                          onSoldTap: () => openVehicleSoldSurvey(product),
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

class StoreSellerProductListTopBar extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onBackTap;
  final VoidCallback onAddTap;

  const StoreSellerProductListTopBar({
    super.key,
    required this.primaryColor,
    required this.onBackTap,
    required this.onAddTap,
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
              'store_my_listings'.sellerText,
              style: textBold.copyWith(
                color: Colors.white,
                fontSize: 19,
              ),
            ),
          ),
          GestureDetector(
            onTap: onAddTap,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'store_new'.sellerText,
                    style: textBold.copyWith(
                      color: Colors.white,
                      fontSize: 12.5,
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

class StoreSellerProductListIntro extends StatelessWidget {
  final Color primaryColor;
  final StoreSellerProductCounts counts;
  final VoidCallback onCreateTap;

  const StoreSellerProductListIntro({
    super.key,
    required this.primaryColor,
    required this.counts,
    required this.onCreateTap,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'store_registered_listings'.sellerText,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'store_registered_listings_description'.sellerText,
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
                child: StoreSellerProductMiniCount(
                  primaryColor: primaryColor,
                  value: counts.pending.toString(),
                  label: 'store_waiting',
                  icon: Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StoreSellerProductMiniCount(
                  primaryColor: primaryColor,
                  value: counts.approved.toString(),
                  label: 'store_approved_plural',
                  icon: Icons.verified_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StoreSellerProductMiniCount(
                  primaryColor: Colors.redAccent,
                  value: counts.rejected.toString(),
                  label: 'store_rejected_plural',
                  icon: Icons.error_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: primaryColor,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onCreateTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 48,
                width: double.infinity,
                alignment: Alignment.center,
                child: Text(
                  'store_register_new'.sellerText,
                  style: textBold.copyWith(
                    color: Colors.white,
                    fontSize: 13.5,
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

class StoreSellerProductMiniCount extends StatelessWidget {
  final Color primaryColor;
  final String value;
  final String label;
  final IconData icon;

  const StoreSellerProductMiniCount({
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
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
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
            label.sellerText,
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

class StoreSellerProductStatusFilters extends StatelessWidget {
  final Color primaryColor;
  final List<StoreSellerProductStatusFilter> filters;
  final String selectedStatus;
  final int Function(String keyName) countForFilter;
  final ValueChanged<String> onChanged;

  const StoreSellerProductStatusFilters({
    super.key,
    required this.primaryColor,
    required this.filters,
    required this.selectedStatus,
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
          final StoreSellerProductStatusFilter filter = filters[index];
          final bool isSelected = filter.keyName == selectedStatus;

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
                    'store_filter_with_count'.sellerTextParams({
                      'label': filter.label.sellerText,
                      'count': '${countForFilter(filter.keyName)}',
                    }),
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

class StoreSellerProductCard extends StatelessWidget {
  final StoreSellerProductItem product;
  final Color primaryColor;
  final VoidCallback onEditTap;
  final VoidCallback onPaymentTap;
  final VoidCallback onSoldTap;

  const StoreSellerProductCard({
    super.key,
    required this.product,
    required this.primaryColor,
    required this.onEditTap,
    required this.onPaymentTap,
    required this.onSoldTap,
  });

  void openRejectedReasonModal(BuildContext context) {
    final String reason = product.rejectionNote.trim().isEmpty
        ? 'store_rejection_reason_not_informed'.sellerText
        : product.rejectionNote.trim();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
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
                        color: Colors.redAccent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.redAccent,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.isMarketplaceAd
                                ? 'store_listing_rejected'.sellerText
                                : 'store_product_rejected'.sellerText,
                            style: textBold.copyWith(
                              color: Colors.black87,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            product.isMarketplaceAd
                                ? 'store_view_lokally_rejection_reason'
                                    .sellerText
                                : 'store_view_reason_adjust_resubmit'
                                    .sellerText,
                            style: textRegular.copyWith(
                              color: Colors.grey.shade600,
                              fontSize: 12.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
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
                const SizedBox(height: 15),
                Container(
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
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textBold.copyWith(
                          color: Colors.black87,
                          fontSize: 13.8,
                          height: 1.22,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        product.displayCategoryName.sellerText,
                        style: textRegular.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  'store_rejection_reason'.sellerText,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 13.4,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.32,
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        reason,
                        style: textRegular.copyWith(
                          color: Colors.redAccent,
                          fontSize: 12.4,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!product.isMarketplaceAd) ...[
                  const SizedBox(height: 15),
                  Material(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        onEditTap();
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        height: 48,
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Text(
                          'store_edit_and_resubmit'.sellerText,
                          style: textBold.copyWith(
                            color: Colors.white,
                            fontSize: 13.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Material(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 46,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'store_close'.sellerText,
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
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = product.statusColor(primaryColor);
    final bool isSold = product.isSold;
    final bool canPayMarketplaceAd =
        product.isMarketplaceAd && product.isPaymentPending && !isSold;
    final bool canEdit = product.canEdit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StoreSellerProductImage(
            imageUrl: product.mainImageUrl,
            primaryColor: primaryColor,
            isVehicle: product.isVehicle,
            isRealEstate: product.isRealEstate,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    StoreSellerProductStatusBadge(
                      label: product.approvalStatusLabel,
                      color: statusColor,
                    ),
                    StoreSellerProductStatusBadge(
                      label: product.typeBadgeLabel,
                      color: product.typeBadgeColor(primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(
                    color: Colors.black87,
                    fontSize: 14.2,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  product.displayCategoryName.sellerText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 11.8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: product.hasPromotionalPrice
                      ? [
                          Text(
                            product.formattedPrice,
                            style: textRegular.copyWith(
                              color: Colors.redAccent,
                              fontSize: 11.8,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Colors.redAccent,
                              decorationThickness: 1.4,
                            ),
                          ),
                          Text(
                            product.formattedPromotionalPrice,
                            style: textBold.copyWith(
                              color: primaryColor,
                              fontSize: 14.2,
                            ),
                          ),
                        ]
                      : [
                          Text(
                            product.formattedPrice,
                            style: textBold.copyWith(
                              color: primaryColor,
                              fontSize: 14.2,
                            ),
                          ),
                        ],
                ),
                const SizedBox(height: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StoreSellerProductInlineInfo(
                      icon: product.primaryInfoIcon,
                      text: product.primaryInfoLine,
                    ),
                    const SizedBox(height: 5),
                    StoreSellerProductInlineInfo(
                      icon: product.secondaryInfoIcon,
                      text: product.secondaryInfoLine,
                    ),
                  ],
                ),
                if (product.isMarketplaceAd && product.planName.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        Icons.workspace_premium_outlined,
                        color: Colors.grey.shade600,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          product.planPriceLabel.isEmpty
                              ? product.planName
                              : '${product.planName} • ${product.planPriceLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textRegular.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 11.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (product.approvalStatus == 'rejected') ...[
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.redAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => openRejectedReasonModal(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'store_rejected_view_reason'.sellerText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textBold.copyWith(
                                  color: Colors.redAccent,
                                  fontSize: 11.8,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_right_rounded,
                              color: Colors.redAccent,
                              size: 19,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (canPayMarketplaceAd) ...[
                  const SizedBox(height: 10),
                  Material(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      onTap: onPaymentTap,
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        child: Text(
                          'store_pay_listing'.sellerText,
                          style: textBold.copyWith(
                            color: Colors.white,
                            fontSize: 12.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (product.canMarkAsSold) ...[
                  const SizedBox(height: 10),
                  Material(
                    color: const Color(0xFF0B8F72).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      onTap: onSoldTap,
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        child: Text(
                          'store_mark_as_sold'.sellerText,
                          style: textBold.copyWith(
                            color: const Color(0xFF0B8F72),
                            fontSize: 12.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (canEdit) ...[
                  const SizedBox(height: 10),
                  Material(
                    color: product.approvalStatus == 'rejected'
                        ? Colors.redAccent.withValues(alpha: 0.10)
                        : primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      onTap: onEditTap,
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        child: Text(
                          product.editButtonLabel.sellerText,
                          style: textBold.copyWith(
                            color: product.approvalStatus == 'rejected'
                                ? Colors.redAccent
                                : primaryColor,
                            fontSize: 12.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VehicleSoldSurveyOption extends StatelessWidget {
  final String title;
  final bool? value;
  final Color primaryColor;
  final ValueChanged<bool> onChanged;

  const VehicleSoldSurveyOption({
    super.key,
    required this.title,
    required this.value,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
            title.sellerText,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 12.8,
              height: 1.22,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: VehicleSoldSurveyChoice(
                  label: 'store_yes',
                  selected: value == true,
                  primaryColor: primaryColor,
                  onTap: () => onChanged(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: VehicleSoldSurveyChoice(
                  label: 'store_no',
                  selected: value == false,
                  primaryColor: primaryColor,
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VehicleSoldSurveyChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;

  const VehicleSoldSurveyChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? primaryColor : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? primaryColor : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label.sellerText,
            style: textBold.copyWith(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}

class StoreSellerProductInlineInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const StoreSellerProductInlineInfo({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.grey.shade600,
          size: 15,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text.sellerText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 11.4,
              height: 1.16,
            ),
          ),
        ),
      ],
    );
  }
}

class StoreSellerProductImage extends StatelessWidget {
  final String imageUrl;
  final Color primaryColor;
  final bool isVehicle;
  final bool isRealEstate;

  const StoreSellerProductImage({
    super.key,
    required this.imageUrl,
    required this.primaryColor,
    this.isVehicle = false,
    this.isRealEstate = false,
  });

  Color get placeholderColor {
    if (isVehicle) {
      return Colors.blueGrey;
    }

    if (isRealEstate) {
      return const Color(0xFF0B8F72);
    }

    return primaryColor;
  }

  IconData get placeholderIcon {
    if (isVehicle) {
      return Icons.directions_car_filled_rounded;
    }

    if (isRealEstate) {
      return Icons.apartment_rounded;
    }

    return Icons.image_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 102,
      decoration: BoxDecoration(
        color: placeholderColor.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
      ),
      child: imageUrl.isEmpty
          ? Icon(
              placeholderIcon,
              color: placeholderColor,
              size: 30,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Icon(
                    placeholderIcon,
                    color: placeholderColor,
                    size: 30,
                  );
                },
              ),
            ),
    );
  }
}

class StoreSellerProductStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StoreSellerProductStatusBadge({
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
        color: color.withValues(alpha: 0.10),
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
            label.sellerText,
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

class StoreSellerProductsLoading extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerProductsLoading({
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

class StoreSellerProductsEmpty extends StatelessWidget {
  final Color primaryColor;
  final String selectedStatus;
  final VoidCallback onCreateTap;

  const StoreSellerProductsEmpty({
    super.key,
    required this.primaryColor,
    required this.selectedStatus,
    required this.onCreateTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAll = selectedStatus == 'all';

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
            Icons.inventory_2_outlined,
            color: primaryColor,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            (isAll
                    ? 'store_no_listing_registered'
                    : 'store_no_listing_with_status')
                .sellerText,
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 15.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isAll
                ? 'store_create_first_listing_description'.sellerText
                : 'store_listings_status_empty_description'.sellerText,
            textAlign: TextAlign.center,
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 12.3,
              height: 1.35,
            ),
          ),
          if (isAll) ...[
            const SizedBox(height: 14),
            Material(
              color: primaryColor,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: onCreateTap,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 46,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Text(
                    'store_register_new'.sellerText,
                    style: textBold.copyWith(
                      color: Colors.white,
                      fontSize: 13.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StoreSellerProductItem {
  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final String mainImageUrl;
  final String shortDescription;
  final String description;
  final String approvalStatus;
  final String approvalStatusLabel;
  final String rejectionNote;
  final String availabilityType;
  final String availabilityLabel;
  final String conditionType;
  final String serviceDeliveryType;
  final String sku;
  final String barcode;
  final int stock;
  final int minStock;
  final String unit;
  final bool manageStock;
  final double price;
  final double promotionalPrice;
  final double costPrice;
  final bool allowPickup;
  final bool allowLokallyShipping;
  final bool allowNationalShipping;
  final String packageHeightCm;
  final String packageWidthCm;
  final String packageLengthCm;
  final String packageWeightKg;
  final double totalMonthlyCost;
  final String itemType;
  final String productType;
  final String planName;
  final double planMonthlyPrice;
  final String plate;
  final String brandName;
  final String modelName;
  final String year;
  final String mileage;
  final String vehicleStatus;
  final String billingStatus;
  final String paymentStatus;
  final String realEstateStatus;
  final String listingType;
  final String listingTypeLabel;
  final String propertyType;
  final String areaM2;
  final String bedrooms;
  final String bathrooms;
  final String parkingSpaces;
  final String address;
  final String city;
  final String state;
  final String closedType;
  final Map<String, dynamic> rawData;

  StoreSellerProductItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.mainImageUrl,
    required this.shortDescription,
    required this.description,
    required this.approvalStatus,
    required this.approvalStatusLabel,
    required this.rejectionNote,
    required this.availabilityType,
    required this.availabilityLabel,
    required this.conditionType,
    required this.serviceDeliveryType,
    required this.sku,
    required this.barcode,
    required this.stock,
    required this.minStock,
    required this.unit,
    required this.manageStock,
    required this.price,
    required this.promotionalPrice,
    required this.costPrice,
    required this.allowPickup,
    required this.allowLokallyShipping,
    required this.allowNationalShipping,
    required this.packageHeightCm,
    required this.packageWidthCm,
    required this.packageLengthCm,
    required this.packageWeightKg,
    required this.totalMonthlyCost,
    required this.itemType,
    required this.productType,
    required this.planName,
    required this.planMonthlyPrice,
    required this.plate,
    required this.brandName,
    required this.modelName,
    required this.year,
    required this.mileage,
    required this.vehicleStatus,
    required this.billingStatus,
    required this.paymentStatus,
    required this.realEstateStatus,
    required this.listingType,
    required this.listingTypeLabel,
    required this.propertyType,
    required this.areaM2,
    required this.bedrooms,
    required this.bathrooms,
    required this.parkingSpaces,
    required this.address,
    required this.city,
    required this.state,
    required this.closedType,
    required this.rawData,
  });

  factory StoreSellerProductItem.fromMap(Map<String, dynamic> map) {
    return StoreSellerProductItem(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      categoryId: '${map['category_id'] ?? ''}',
      categoryName: '${map['category_name'] ?? ''}',
      mainImageUrl:
          '${map['main_image_url'] ?? map['image_url'] ?? map['image'] ?? map['thumbnail'] ?? ''}',
      shortDescription: '${map['short_description'] ?? ''}',
      description: '${map['description'] ?? ''}',
      approvalStatus:
          '${map['approval_status'] ?? map['vehicle_status'] ?? map['real_estate_status'] ?? 'pending'}',
      approvalStatusLabel: '${map['approval_status_label'] ?? ''}'.isEmpty
          ? statusLabelFromValue(
              '${map['approval_status'] ?? map['vehicle_status'] ?? map['real_estate_status'] ?? 'pending'}',
            )
          : '${map['approval_status_label']}',
      rejectionNote: '${map['rejection_note'] ?? ''}',
      availabilityType: '${map['availability_type'] ?? 'immediate'}',
      availabilityLabel: '${map['availability_label'] ?? ''}'.isEmpty
          ? availabilityLabelFromValue(
              '${map['availability_type'] ?? 'immediate'}',
            )
          : '${map['availability_label']}',
      conditionType: '${map['condition_type'] ?? 'new'}'.trim().toLowerCase(),
      serviceDeliveryType:
          '${map['service_delivery_type'] ?? ''}'.trim().toLowerCase(),
      sku: '${map['sku'] ?? ''}',
      barcode: '${map['barcode'] ?? ''}',
      stock: int.tryParse('${map['stock'] ?? 0}') ?? 0,
      minStock: int.tryParse('${map['min_stock'] ?? 0}') ?? 0,
      unit: '${map['unit'] ?? 'unidade'}',
      manageStock: parseBool(map['manage_stock'], fallback: true),
      price: parseDouble(map['price']),
      promotionalPrice: parseDouble(map['old_price']),
      costPrice: parseDouble(map['cost_price']),
      allowPickup: parseBool(map['allow_pickup'] ?? map['delivery_immediate']),
      allowLokallyShipping: parseBool(
        map['allow_lokally_shipping'] ?? map['delivery_full_24h'],
      ),
      allowNationalShipping: parseBool(
        map['allow_national_shipping'] ?? map['delivery_lokally_br'],
      ),
      packageHeightCm:
          '${map['package_height_cm'] ?? map['shipping_height_cm'] ?? map['shipping_depth_cm'] ?? ''}',
      packageWidthCm:
          '${map['package_width_cm'] ?? map['shipping_width_cm'] ?? ''}',
      packageLengthCm:
          '${map['package_length_cm'] ?? map['shipping_length_cm'] ?? ''}',
      packageWeightKg:
          '${map['package_weight_kg'] ?? map['shipping_weight'] ?? ''}',
      totalMonthlyCost: parseDouble(map['total_monthly_cost']),
      itemType: '${map['item_type'] ?? map['product_type'] ?? 'product'}',
      productType: '${map['product_type'] ?? map['item_type'] ?? 'product'}',
      planName: '${map['plan_name'] ?? ''}',
      planMonthlyPrice: double.tryParse(
              '${map['plan_monthly_price'] ?? map['plan_price'] ?? 0}') ??
          0,
      plate: '${map['plate'] ?? ''}',
      brandName: '${map['brand_name'] ?? ''}',
      modelName: '${map['model_name'] ?? ''}',
      year: '${map['year'] ?? ''}',
      mileage: '${map['mileage'] ?? ''}',
      vehicleStatus: '${map['vehicle_status'] ?? ''}',
      billingStatus: '${map['billing_status'] ?? ''}',
      paymentStatus: '${map['payment_status'] ?? ''}',
      realEstateStatus: '${map['real_estate_status'] ?? ''}',
      listingType: '${map['listing_type'] ?? ''}',
      listingTypeLabel: '${map['listing_type_label'] ?? ''}',
      propertyType: '${map['property_type'] ?? ''}',
      areaM2: '${map['area_m2'] ?? ''}',
      bedrooms: '${map['bedrooms'] ?? ''}',
      bathrooms: '${map['bathrooms'] ?? ''}',
      parkingSpaces: '${map['parking_spaces'] ?? ''}',
      address: '${map['address'] ?? ''}',
      city: '${map['city'] ?? ''}',
      state: '${map['state'] ?? ''}',
      closedType: '${map['closed_type'] ?? ''}',
      rawData: Map<String, dynamic>.from(map),
    );
  }

  bool get isVehicle {
    return itemType == 'vehicle' ||
        productType == 'vehicle' ||
        availabilityType == 'vehicle_ad';
  }

  bool get isRealEstate {
    return itemType == 'real_estate_ad' ||
        productType == 'real_estate_ad' ||
        availabilityType == 'real_estate_ad';
  }

  bool get isService {
    final Set<String> serviceTypeValues = <String>{
      itemType.trim().toLowerCase(),
      productType.trim().toLowerCase(),
      '${rawData['type'] ?? ''}'.trim().toLowerCase(),
      '${rawData['ad_type'] ?? ''}'.trim().toLowerCase(),
      '${rawData['listing_type_key'] ?? ''}'.trim().toLowerCase(),
    };

    if (serviceTypeValues.any((value) =>
        value == 'service' ||
        value == 'servico' ||
        value == 'serviço' ||
        value == 'store_service' ||
        value == 'service_ad')) {
      return true;
    }

    if (rawData['service'] is Map || rawData['service_details'] is Map) {
      return true;
    }

    final List<String> serviceOnlyKeys = <String>[
      'service_format',
      'service_delivery_type',
      'included_items',
      'excluded_items',
      'customer_requirements',
      'estimated_deadline',
      'execution_time',
      'needs_scheduling',
      'attendance_location',
      'service_area',
      'instructions_after_payment',
      'deliverable_description',
      'category_request_name',
    ];

    return serviceOnlyKeys.any((key) {
      final dynamic value = rawData[key];
      return value != null && value.toString().trim().isNotEmpty;
    });
  }

  bool get isMarketplaceAd => isVehicle || isRealEstate || isService;

  String get displayCategoryName {
    if (isVehicle) {
      return 'store_vehicles';
    }

    if (isRealEstate) {
      return 'store_properties';
    }

    if (isService) {
      return 'store_services';
    }

    return categoryName.isEmpty ? 'store_uncategorized' : categoryName;
  }

  String get typeBadgeLabel {
    if (isVehicle) {
      return 'store_vehicle';
    }

    if (isRealEstate) {
      return 'store_property';
    }

    if (isService) {
      return 'store_service';
    }

    return 'store_product';
  }

  Color typeBadgeColor(Color primaryColor) {
    if (isVehicle) {
      return Colors.blueGrey;
    }

    if (isRealEstate) {
      return const Color(0xFF0B8F72);
    }

    return primaryColor;
  }

  bool get isPaymentPending {
    final String label = approvalStatusLabel.toLowerCase();
    final String serviceBillingStatus =
        '${rawData['service_billing_status'] ?? ''}'.trim().toLowerCase();
    final String servicePaymentStatus =
        '${rawData['service_payment_status'] ?? ''}'.trim().toLowerCase();
    final String marketplaceAdBillingStatus =
        '${rawData['marketplace_ad_billing_status'] ?? ''}'
            .trim()
            .toLowerCase();

    return isMarketplaceAd &&
        (vehicleStatus == 'payment_pending' ||
            realEstateStatus == 'payment_pending' ||
            billingStatus == 'payment_pending' ||
            paymentStatus == 'pending' ||
            serviceBillingStatus == 'payment_pending' ||
            marketplaceAdBillingStatus == 'payment_pending' ||
            servicePaymentStatus == 'pending' ||
            label.contains('pagamento'));
  }

  bool get isSold {
    final String normalizedLabel = approvalStatusLabel.toLowerCase();

    return vehicleStatus == 'sold' ||
        realEstateStatus == 'closed' ||
        closedType == 'sold' ||
        closedType == 'rented' ||
        closedType == 'unavailable' ||
        billingStatus == 'sold' ||
        approvalStatus == 'sold' ||
        approvalStatus == 'closed' ||
        normalizedLabel.contains('vendido') ||
        normalizedLabel.contains('alugado') ||
        normalizedLabel.contains('encerrado');
  }

  bool get canMarkAsSold {
    return isVehicle &&
        approvalStatus == 'approved' &&
        paymentStatus == 'paid' &&
        billingStatus == 'active' &&
        !isSold;
  }

  bool get isClosedOrExpired {
    final String normalizedLabel = approvalStatusLabel.toLowerCase();

    return vehicleStatus == 'expired' ||
        vehicleStatus == 'closed' ||
        realEstateStatus == 'expired' ||
        realEstateStatus == 'closed' ||
        approvalStatus == 'expired' ||
        approvalStatus == 'closed' ||
        closedType == 'unavailable' ||
        normalizedLabel.contains('expirado') ||
        normalizedLabel.contains('encerrado');
  }

  bool get canEdit {
    if (isSold || isClosedOrExpired || isPaymentPending) {
      return false;
    }

    return approvalStatus != 'suspended';
  }

  String get vehicleInfoLine {
    final List<String> parts = <String>[];

    if (plate.trim().isNotEmpty && plate != 'null') {
      parts.add(
          'store_license_plate_with_value'.sellerTextParams({'value': plate}));
    }

    if (year.trim().isNotEmpty && year != 'null') {
      parts.add('store_year_with_value'.sellerTextParams({'value': year}));
    }

    if (mileage.trim().isNotEmpty && mileage != 'null') {
      final int? km = int.tryParse(mileage);
      parts.add(km == null ? '$mileage km' : '${formatInteger(km)} km');
    }

    return parts.isEmpty
        ? 'store_vehicle_listing'.sellerText
        : parts.join(' • ');
  }

  String get realEstateInfoLine {
    final List<String> parts = <String>[];

    if (listingTypeLabel.trim().isNotEmpty && listingTypeLabel != 'null') {
      parts.add(listingTypeLabel);
    }

    if (propertyType.trim().isNotEmpty && propertyType != 'null') {
      parts.add(propertyType);
    }

    final int? area = int.tryParse(areaM2.split('.').first);
    if (area != null && area > 0) {
      parts.add('${formatInteger(area)} m²');
    }

    return parts.isEmpty
        ? 'store_property_listing'.sellerText
        : parts.join(' • ');
  }

  String get realEstateDetailsLine {
    final List<String> parts = <String>[];

    final int? rooms = int.tryParse(bedrooms);
    final int? baths = int.tryParse(bathrooms);
    final int? spots = int.tryParse(parkingSpaces);

    if (rooms != null && rooms > 0) {
      parts.add((rooms == 1 ? 'store_bedroom_count_one' : 'store_bedroom_count')
          .sellerTextParams({'count': '$rooms'}));
    }

    if (baths != null && baths > 0) {
      parts.add(
          (baths == 1 ? 'store_bathroom_count_one' : 'store_bathroom_count')
              .sellerTextParams({'count': '$baths'}));
    }

    if (spots != null && spots > 0) {
      parts.add((spots == 1
              ? 'store_parking_space_count_one'
              : 'store_parking_space_count')
          .sellerTextParams({'count': '$spots'}));
    }

    if (parts.isEmpty) {
      final String location = [city, state]
          .where((item) => item.trim().isNotEmpty && item != 'null')
          .join(' / ');

      return location.isEmpty
          ? 'store_no_cart_or_delivery'.sellerText
          : location;
    }

    return parts.join(' • ');
  }

  IconData get primaryInfoIcon {
    if (isVehicle) {
      return Icons.local_offer_outlined;
    }

    if (isRealEstate) {
      return Icons.home_work_outlined;
    }

    if (isService) {
      return Icons.handyman_outlined;
    }

    return Icons.inventory_2_outlined;
  }

  IconData get secondaryInfoIcon {
    if (isVehicle) {
      return Icons.event_available_outlined;
    }

    if (isRealEstate) {
      return Icons.bed_outlined;
    }

    if (isService) {
      return Icons.design_services_outlined;
    }

    return availabilityType == 'within_24h'
        ? Icons.schedule_rounded
        : Icons.flash_on_rounded;
  }

  String get primaryInfoLine {
    if (isVehicle) {
      return vehicleInfoLine;
    }

    if (isRealEstate) {
      return realEstateInfoLine;
    }

    if (isService) {
      return serviceFormatLabel;
    }

    return 'store_stock_with_value'.sellerTextParams({'value': '$stock'});
  }

  String get secondaryInfoLine {
    if (isVehicle) {
      return availabilityLabel;
    }

    if (isRealEstate) {
      return realEstateDetailsLine;
    }

    if (isService) {
      return serviceDeliveryLabel;
    }

    return availabilityLabel;
  }

  String get editButtonLabel {
    if (isVehicle) {
      return 'store_edit_vehicle';
    }

    if (isRealEstate) {
      return 'store_edit_property';
    }

    if (isService) {
      return approvalStatus == 'rejected'
          ? 'store_edit_service_and_resubmit'
          : 'store_edit_service';
    }

    return approvalStatus == 'rejected'
        ? 'store_edit_product_and_resubmit'
        : 'store_edit_product';
  }

  String get serviceFormatLabel {
    final String format =
        '${rawData['service_format'] ?? ''}'.trim().toLowerCase();

    if (format == 'presential') {
      return 'store_presential_service';
    }

    if (format == 'digital') {
      return 'store_digital_service';
    }

    return 'store_service';
  }

  String get serviceDeliveryLabel {
    final String delivery = serviceDeliveryType.trim().toLowerCase();

    switch (delivery) {
      case 'download':
        return 'store_delivery_by_download';
      case 'client_location':
        return 'store_customer_location_service';
      case 'provider_location':
        return 'store_provider_location_service';
      case 'region':
        return 'store_regional_service';
      case 'online':
        return 'store_online_service';
      default:
        return availabilityLabel.isEmpty
            ? 'store_service_attendance'
            : availabilityLabel;
    }
  }

  String get planPriceLabel {
    if (planMonthlyPrice <= 0) {
      return '';
    }

    if (isMarketplaceAd) {
      return 'store_package_with_value'
          .sellerTextParams({'value': formatCurrency(planMonthlyPrice)});
    }

    return formatCurrency(planMonthlyPrice);
  }

  Map<String, dynamic> toInitialServiceMap() {
    final Map<String, dynamic> service = Map<String, dynamic>.from(rawData);
    final Map<String, dynamic> nestedService = rawData['service'] is Map
        ? Map<String, dynamic>.from(rawData['service'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> nestedDetails = rawData['service_details'] is Map
        ? Map<String, dynamic>.from(rawData['service_details'] as Map)
        : <String, dynamic>{};

    service.addAll(nestedService);
    service.addAll(nestedDetails);

    service['id'] = id;
    service['name'] = name;
    service['category_id'] = categoryId;
    service['category_name'] = categoryName;
    service['item_type'] = 'service';
    service['product_type'] = 'service';
    service['main_image_url'] = mainImageUrl;
    service['image_url'] = mainImageUrl;
    service['main_image'] = service['main_image'] ?? rawData['main_image'];
    service['short_description'] = shortDescription;
    service['description'] = description;
    service['approval_status'] = approvalStatus;
    service['approval_status_label'] = approvalStatusLabel;
    service['rejection_note'] = rejectionNote;
    service['service_delivery_type'] = serviceDeliveryType.isEmpty
        ? '${service['service_delivery_type'] ?? 'online'}'
        : serviceDeliveryType;
    service['sku'] = sku;
    service['barcode'] = barcode;
    service['price'] = price;
    service['old_price'] = promotionalPrice;
    service['cost_price'] = costPrice;

    final String serviceFormat = '${service['service_format'] ?? ''}'.trim();
    if (serviceFormat.isEmpty) {
      service['service_format'] = 'digital';
    }

    return service;
  }

  Map<String, dynamic> toInitialVehicleMap() {
    final Map<String, dynamic> vehicle = Map<String, dynamic>.from(rawData);

    vehicle['id'] = id;
    vehicle['item_type'] = 'vehicle';
    vehicle['product_type'] = 'vehicle';
    vehicle['name'] = name;
    vehicle['title'] = '${vehicle['title'] ?? name}'.trim();
    vehicle['main_image_url'] = mainImageUrl;
    vehicle['image_url'] = mainImageUrl;
    vehicle['cover_image_url'] = vehicle['cover_image_url'] ?? mainImageUrl;
    vehicle['approval_status'] = approvalStatus;
    vehicle['approval_status_label'] = approvalStatusLabel;
    vehicle['status'] = vehicleStatus.isEmpty ? approvalStatus : vehicleStatus;
    vehicle['billing_status'] = billingStatus;
    vehicle['payment_status'] = paymentStatus;
    vehicle['plan_name'] = planName;
    vehicle['plan_price'] = planMonthlyPrice;
    vehicle['plan_monthly_price'] = planMonthlyPrice;
    vehicle['plate'] = plate;
    vehicle['brand_name'] = brandName;
    vehicle['model_name'] = modelName;
    vehicle['year'] = year;
    vehicle['mileage'] = mileage;
    vehicle['condition_type'] = conditionType;
    vehicle['description'] = description;
    vehicle['price'] = price;
    vehicle['state'] = state;
    vehicle['city'] = city;

    return vehicle;
  }

  Map<String, dynamic> toInitialRealEstateMap() {
    final Map<String, dynamic> realEstate = Map<String, dynamic>.from(rawData);

    realEstate['id'] = id;
    realEstate['item_type'] = 'real_estate_ad';
    realEstate['product_type'] = 'real_estate_ad';
    realEstate['name'] = name;
    realEstate['title'] = '${realEstate['title'] ?? name}'.trim();
    realEstate['main_image_url'] = mainImageUrl;
    realEstate['image_url'] = mainImageUrl;
    realEstate['cover_media_url'] =
        realEstate['cover_media_url'] ?? mainImageUrl;
    realEstate['approval_status'] = approvalStatus;
    realEstate['approval_status_label'] = approvalStatusLabel;
    realEstate['status'] =
        realEstateStatus.isEmpty ? approvalStatus : realEstateStatus;
    realEstate['billing_status'] = billingStatus;
    realEstate['payment_status'] = paymentStatus;
    realEstate['closed_type'] = closedType;
    realEstate['listing_type'] = listingType;
    realEstate['listing_type_label'] = listingTypeLabel;
    realEstate['property_type'] = propertyType;
    realEstate['area_m2'] = areaM2;
    realEstate['bedrooms'] = bedrooms;
    realEstate['bathrooms'] = bathrooms;
    realEstate['parking_spaces'] = parkingSpaces;
    realEstate['address'] = address;
    realEstate['city'] = city;
    realEstate['state'] = state;
    realEstate['price'] = price;
    realEstate['total_monthly_cost'] = totalMonthlyCost;
    realEstate['description'] = description;
    realEstate['category_id'] = categoryId;
    realEstate['category_name'] = categoryName;
    realEstate['plan_name'] = planName;
    realEstate['plan_price'] = planMonthlyPrice;

    return realEstate;
  }

  Map<String, dynamic> toInitialProductMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'category_id': categoryId,
      'category_name': categoryName,
      'item_type': itemType,
      'product_type': productType,
      'main_image_url': mainImageUrl,
      'short_description': shortDescription,
      'description': description,
      'approval_status': approvalStatus,
      'approval_status_label': approvalStatusLabel,
      'rejection_note': rejectionNote,
      'availability_type': availabilityType,
      'availability_label': availabilityLabel,
      'condition_type': conditionType,
      'service_delivery_type': serviceDeliveryType,
      'sku': sku,
      'barcode': barcode,
      'delivery_immediate': allowPickup || availabilityType == 'immediate',
      'delivery_full_24h':
          allowLokallyShipping || availabilityType == 'within_24h',
      'delivery_lokally_br':
          allowNationalShipping || availabilityType == 'lokally_br',
      'allow_pickup': allowPickup,
      'allow_lokally_shipping': allowLokallyShipping,
      'allow_national_shipping': allowNationalShipping,
      'stock': stock,
      'min_stock': minStock,
      'unit': unit,
      'manage_stock': manageStock,
      'price': price,
      'old_price': promotionalPrice,
      'cost_price': costPrice,
      'package_height_cm': packageHeightCm,
      'package_width_cm': packageWidthCm,
      'package_length_cm': packageLengthCm,
      'package_weight_kg': packageWeightKg,
      'shipping_height_cm': packageHeightCm,
      'shipping_depth_cm': packageHeightCm,
      'shipping_width_cm': packageWidthCm,
      'shipping_length_cm': packageLengthCm,
      'shipping_weight': packageWeightKg,
      'total_monthly_cost': totalMonthlyCost,
    };
  }

  Color statusColor(Color primaryColor) {
    if (isPaymentPending) {
      return const Color(0xFF1769C2);
    }

    switch (approvalStatus) {
      case 'approved':
        return primaryColor;
      case 'sold':
        return const Color(0xFF284FA3);
      case 'rejected':
        return Colors.redAccent;
      case 'suspended':
        return Colors.deepOrange;
      default:
        return const Color(0xFFB7791F);
    }
  }

  bool get hasPromotionalPrice {
    return !isMarketplaceAd && promotionalPrice > 0;
  }

  double get displayPrice {
    if (isRealEstate && totalMonthlyCost > 0) {
      final String label = listingTypeLabel.toLowerCase();
      final String type = listingType.toLowerCase();

      if (label.contains('aluguel') ||
          label.contains('temporada') ||
          type == 'rent' ||
          type == 'seasonal') {
        return totalMonthlyCost;
      }
    }

    return price;
  }

  String get formattedPrice {
    return formatCurrency(displayPrice);
  }

  String get formattedPromotionalPrice {
    if (promotionalPrice <= 0) {
      return '';
    }

    return formatCurrency(promotionalPrice);
  }

  static double parseDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    String cleanValue = '$value'.trim();

    if (cleanValue.isEmpty || cleanValue == 'null') {
      return 0;
    }

    cleanValue = cleanValue.replaceAll('R\$', '').replaceAll(' ', '');
    cleanValue = cleanValue.replaceAll(RegExp(r'[^0-9,.-]'), '');

    if (cleanValue.contains(',') && cleanValue.contains('.')) {
      cleanValue = cleanValue.replaceAll('.', '').replaceAll(',', '.');
    } else if (cleanValue.contains(',')) {
      cleanValue = cleanValue.replaceAll('.', '').replaceAll(',', '.');
    }

    return double.tryParse(cleanValue) ?? 0;
  }

  static bool parseBool(dynamic value, {bool fallback = false}) {
    if (value == null) {
      return fallback;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final String normalized = '$value'.trim().toLowerCase();

    if (normalized.isEmpty || normalized == 'null') {
      return fallback;
    }

    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'sim' ||
        normalized == 'yes' ||
        normalized == 'on';
  }

  static String statusLabelFromValue(String value) {
    switch (value) {
      case 'approved':
        return 'store_approved';
      case 'sold':
        return 'store_sold';
      case 'closed':
        return 'store_closed';
      case 'payment_pending':
        return 'store_waiting_payment';
      case 'rejected':
        return 'store_rejected';
      case 'suspended':
        return 'store_suspended';
      case 'draft':
        return 'store_draft';
      default:
        return 'store_waiting_approval';
    }
  }

  static String availabilityLabelFromValue(String value) {
    if (value == 'vehicle_ad') {
      return 'store_vehicle_listing';
    }

    if (value == 'real_estate_ad') {
      return 'store_property_listing';
    }

    if (value == 'within_24h') {
      return 'store_within_24h';
    }

    return 'store_immediate';
  }

  static String formatInteger(int value) {
    String integer = value.toString();
    final RegExp regex = RegExp(r'(\d+)(\d{3})');

    while (regex.hasMatch(integer)) {
      integer = integer.replaceAllMapped(
        regex,
        (match) => '${match.group(1)}.${match.group(2)}',
      );
    }

    return integer;
  }

  static String formatCurrency(double value) {
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

    return 'R\$ $integer,$decimal';
  }
}

class StoreSellerProductCounts {
  final int all;
  final int pending;
  final int approved;
  final int rejected;
  final int suspended;

  StoreSellerProductCounts({
    required this.all,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.suspended,
  });

  factory StoreSellerProductCounts.empty() {
    return StoreSellerProductCounts(
      all: 0,
      pending: 0,
      approved: 0,
      rejected: 0,
      suspended: 0,
    );
  }

  factory StoreSellerProductCounts.fromMap(Map<String, dynamic> map) {
    return StoreSellerProductCounts(
      all: int.tryParse('${map['all'] ?? 0}') ?? 0,
      pending: int.tryParse('${map['pending'] ?? 0}') ?? 0,
      approved: int.tryParse('${map['approved'] ?? 0}') ?? 0,
      rejected: int.tryParse('${map['rejected'] ?? 0}') ?? 0,
      suspended: int.tryParse('${map['suspended'] ?? 0}') ?? 0,
    );
  }
}

class StoreSellerProductStatusFilter {
  final String keyName;
  final String label;
  final String? apiStatus;

  StoreSellerProductStatusFilter({
    required this.keyName,
    required this.label,
    required this.apiStatus,
  });
}
