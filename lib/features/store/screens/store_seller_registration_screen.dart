import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/custom_text_field.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/location/view/pick_map_screen.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreSellerRegistrationScreen extends StatefulWidget {
  const StoreSellerRegistrationScreen({super.key});

  @override
  State<StoreSellerRegistrationScreen> createState() =>
      _StoreSellerRegistrationScreenState();
}

class _StoreSellerRegistrationScreenState
    extends State<StoreSellerRegistrationScreen> {
  final TextEditingController storeNameController = TextEditingController();
  final TextEditingController ownerNameController = TextEditingController();
  final TextEditingController documentController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final FocusNode storeNameFocus = FocusNode();
  final FocusNode ownerNameFocus = FocusNode();
  final FocusNode documentFocus = FocusNode();
  final FocusNode phoneFocus = FocusNode();
  final FocusNode addressFocus = FocusNode();
  final FocusNode descriptionFocus = FocusNode();

  bool pickupEnabled = true;
  bool ownDeliveryEnabled = false;
  bool lokallyDeliveryEnabled = true;
  bool isSubmitting = false;

  Address? selectedStoreAddress;
  double? storeLatitude;
  double? storeLongitude;

  @override
  void dispose() {
    storeNameController.dispose();
    ownerNameController.dispose();
    documentController.dispose();
    phoneController.dispose();
    addressController.dispose();
    descriptionController.dispose();

    storeNameFocus.dispose();
    ownerNameFocus.dispose();
    documentFocus.dispose();
    phoneFocus.dispose();
    addressFocus.dispose();
    descriptionFocus.dispose();

    super.dispose();
  }

  String? resolveCurrentZoneId() {
    final ApiClient apiClient = Get.find<ApiClient>();

    final String? savedZoneId =
        apiClient.sharedPreferences.getString(AppConstants.zoneId);

    if (savedZoneId != null && savedZoneId.trim().isNotEmpty) {
      return savedZoneId.trim();
    }

    final String? savedAddress =
        apiClient.sharedPreferences.getString(AppConstants.userAddress);

    if (savedAddress == null || savedAddress.trim().isEmpty) {
      return null;
    }

    try {
      final dynamic decoded = jsonDecode(savedAddress);

      if (decoded is Map) {
        final dynamic zoneId =
            decoded['zone_id'] ?? decoded['zoneId'] ?? decoded['zone'];

        if (zoneId != null && zoneId.toString().trim().isNotEmpty) {
          return zoneId.toString().trim();
        }
      }
    } catch (_) {}

    return null;
  }

  String onlyNumbers(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String getDocumentType() {
    final String document = onlyNumbers(documentController.text);

    if (document.length > 11) {
      return 'cnpj';
    }

    return 'cpf';
  }

  void clearSelectedStoreCoordinatesIfNeeded(String value) {
    final String typedAddress = value.trim();
    final String selectedAddress = selectedStoreAddress?.address?.trim() ?? '';

    if (selectedAddress.isNotEmpty && typedAddress == selectedAddress) {
      return;
    }

    if (selectedStoreAddress == null &&
        storeLatitude == null &&
        storeLongitude == null) {
      return;
    }

    setState(() {
      selectedStoreAddress = null;
      storeLatitude = null;
      storeLongitude = null;
    });
  }

  Future<void> pickStoreAddressFromMap() async {
    FocusScope.of(context).unfocus();

    final LocationController locationController =
        Get.find<LocationController>();

    locationController.clearAddAddress();

    await Get.to(
      () => PickMapScreen(
        type: LocationType.location,
        address: selectedStoreAddress,
      ),
    );

    if (!mounted) {
      return;
    }

    final Address? pickedAddress = locationController.addAddress;

    if (pickedAddress == null ||
        pickedAddress.latitude == null ||
        pickedAddress.longitude == null ||
        pickedAddress.latitude == 0 ||
        pickedAddress.longitude == 0) {
      return;
    }

    setState(() {
      selectedStoreAddress = pickedAddress;
      storeLatitude = pickedAddress.latitude;
      storeLongitude = pickedAddress.longitude;

      if ((pickedAddress.address ?? '').trim().isNotEmpty) {
        addressController.text = pickedAddress.address!.trim();
      }
    });
  }

  bool validateForm() {
    if (storeNameController.text.trim().isEmpty) {
      showStoreMessage('Informe o nome da loja.');
      storeNameFocus.requestFocus();
      return false;
    }

    if (ownerNameController.text.trim().isEmpty) {
      showStoreMessage('Informe o nome do responsável.');
      ownerNameFocus.requestFocus();
      return false;
    }

    if (documentController.text.trim().isEmpty) {
      showStoreMessage('Informe o CPF ou CNPJ.');
      documentFocus.requestFocus();
      return false;
    }

    if (phoneController.text.trim().isEmpty) {
      showStoreMessage('Informe o telefone comercial.');
      phoneFocus.requestFocus();
      return false;
    }

    if (addressController.text.trim().isEmpty) {
      showStoreMessage('Informe o endereço da loja.');
      addressFocus.requestFocus();
      return false;
    }

    if (storeLatitude == null || storeLongitude == null) {
      showStoreMessage('Selecione a localização da loja no mapa.');
      return false;
    }

    return true;
  }

  Future<void> submitSellerRequest() async {
    if (isSubmitting || !validateForm()) {
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    final String? zoneId = resolveCurrentZoneId();

    final Map<String, dynamic> body = {
      'store_name': storeNameController.text.trim(),
      'owner_name': ownerNameController.text.trim(),
      'phone': phoneController.text.trim(),
      'document_type': getDocumentType(),
      'document_number': documentController.text.trim(),
      'description': descriptionController.text.trim(),
      'address': addressController.text.trim(),
      'latitude': storeLatitude,
      'longitude': storeLongitude,
      'pickup_enabled': pickupEnabled,
      'own_delivery_enabled': ownDeliveryEnabled,
      'lokally_delivery_enabled': lokallyDeliveryEnabled,
      'own_delivery_base_fee': 0,
      'lokally_delivery_base_fee': 8,
    };

    if (zoneId != null && zoneId.isNotEmpty) {
      body['zone_id'] = zoneId;
    }

    final Response response = await Get.find<ApiClient>().postData(
      AppConstants.storeSellerRequest,
      body,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      isSubmitting = false;
    });

    final dynamic responseBody = response.body;

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        responseBody is Map &&
        responseBody['status'] == true) {
      Get.back(result: true);
      return;
    }

    String message = 'Não foi possível enviar o cadastro agora.';

    if (responseBody is Map) {
      if (responseBody['message'] != null) {
        message = responseBody['message'].toString();
      } else if (responseBody['errors'] != null) {
        message = responseBody['errors'].toString();
      }
    }

    showStoreMessage(message);
  }

  void showStoreMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            StoreSellerRegistrationHeader(
              primaryColor: primaryColor,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Dimensions.paddingSizeDefault,
                  18,
                  Dimensions.paddingSizeDefault,
                  28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StoreSellerIntroCard(primaryColor: primaryColor),
                    const SizedBox(height: 18),
                    StoreFormLabel(label: 'Nome da loja'),
                    CustomTextField(
                      controller: storeNameController,
                      focusNode: storeNameFocus,
                      nextFocus: ownerNameFocus,
                      hintText: 'Ex: Loja Teste Lokally',
                      capitalization: TextCapitalization.words,
                      borderRadius: 16,
                      fillColor: Colors.grey.shade50,
                      prefix: false,
                      inputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    StoreFormLabel(label: 'Nome do responsável'),
                    CustomTextField(
                      controller: ownerNameController,
                      focusNode: ownerNameFocus,
                      nextFocus: documentFocus,
                      hintText: 'Nome completo',
                      capitalization: TextCapitalization.words,
                      borderRadius: 16,
                      fillColor: Colors.grey.shade50,
                      prefix: false,
                      inputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    StoreFormLabel(label: 'CPF ou CNPJ'),
                    CustomTextField(
                      controller: documentController,
                      focusNode: documentFocus,
                      nextFocus: phoneFocus,
                      hintText: 'Digite o documento da loja ou responsável',
                      borderRadius: 16,
                      fillColor: Colors.grey.shade50,
                      prefix: false,
                      inputAction: TextInputAction.next,
                      inputType: TextInputType.text,
                    ),
                    const SizedBox(height: 14),
                    StoreFormLabel(label: 'Telefone comercial'),
                    CustomTextField(
                      controller: phoneController,
                      focusNode: phoneFocus,
                      nextFocus: addressFocus,
                      hintText: 'Ex: +5535991284648',
                      borderRadius: 16,
                      fillColor: Colors.grey.shade50,
                      prefix: false,
                      inputAction: TextInputAction.next,
                      inputType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    StoreFormLabel(label: 'Endereço da loja'),
                    CustomTextField(
                      controller: addressController,
                      focusNode: addressFocus,
                      nextFocus: descriptionFocus,
                      hintText: 'Rua, número, bairro e cidade',
                      capitalization: TextCapitalization.sentences,
                      borderRadius: 16,
                      fillColor: Colors.grey.shade50,
                      prefix: false,
                      inputAction: TextInputAction.next,
                      inputType: TextInputType.streetAddress,
                      maxLines: 2,
                      onChanged: clearSelectedStoreCoordinatesIfNeeded,
                    ),
                    const SizedBox(height: 9),
                    StoreMapLocationPickerCard(
                      primaryColor: primaryColor,
                      hasLocation:
                          storeLatitude != null && storeLongitude != null,
                      latitude: storeLatitude,
                      longitude: storeLongitude,
                      onTap: pickStoreAddressFromMap,
                    ),
                    const SizedBox(height: 14),
                    StoreFormLabel(label: 'Descrição da loja'),
                    CustomTextField(
                      controller: descriptionController,
                      focusNode: descriptionFocus,
                      hintText: 'Conte brevemente o que sua loja vende',
                      capitalization: TextCapitalization.sentences,
                      borderRadius: 16,
                      fillColor: Colors.grey.shade50,
                      prefix: false,
                      inputAction: TextInputAction.done,
                      inputType: TextInputType.multiline,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 18),
                    StoreDeliveryOptionsCard(
                      primaryColor: primaryColor,
                      pickupEnabled: pickupEnabled,
                      ownDeliveryEnabled: ownDeliveryEnabled,
                      lokallyDeliveryEnabled: lokallyDeliveryEnabled,
                      onPickupChanged: (value) {
                        setState(() {
                          pickupEnabled = value;
                        });
                      },
                      onOwnDeliveryChanged: (value) {
                        setState(() {
                          ownDeliveryEnabled = value;
                        });
                      },
                      onLokallyDeliveryChanged: (value) {
                        setState(() {
                          lokallyDeliveryEnabled = value;
                        });
                      },
                    ),
                    const SizedBox(height: 22),
                    if (isSubmitting)
                      Center(
                        child: CircularProgressIndicator(
                          color: primaryColor,
                        ),
                      )
                    else
                      ButtonWidget(
                        buttonText: 'Enviar cadastro',
                        radius: 16,
                        height: 50,
                        backgroundColor: primaryColor,
                        onPressed: submitSellerRequest,
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Após o envio, o ADM da Lokally poderá aprovar, reprovar ou bloquear temporariamente o cadastro conforme as regras do marketplace.',
                      textAlign: TextAlign.center,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        height: 1.35,
                      ),
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

class StoreSellerRegistrationHeader extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerRegistrationHeader({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 14),
      decoration: BoxDecoration(
        color: primaryColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 6),
            blurRadius: 18,
            color: Colors.black.withValues(alpha: 0.10),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cadastrar loja',
              style: textBold.copyWith(
                color: Colors.white,
                fontSize: 19,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSellerIntroCard extends StatelessWidget {
  final Color primaryColor;

  const StoreSellerIntroCard({
    super.key,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: primaryColor,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Preencha os dados comerciais da sua loja. Seu login, senha e acesso ao app continuam os mesmos; o cadastro abaixo cria apenas o perfil de vendedor no marketplace.',
              style: textMedium.copyWith(
                color: Colors.black87,
                fontSize: 13.2,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreMapLocationPickerCard extends StatelessWidget {
  final Color primaryColor;
  final bool hasLocation;
  final double? latitude;
  final double? longitude;
  final VoidCallback onTap;

  const StoreMapLocationPickerCard({
    super.key,
    required this.primaryColor,
    required this.hasLocation,
    required this.latitude,
    required this.longitude,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String title = hasLocation
        ? 'Localização da loja definida'
        : 'Selecionar localização da loja no mapa';

    final String description = hasLocation
        ? 'Coordenadas salvas para Retire Grátis e Lokally Envios.'
        : 'Obrigatório para calcular rota, retirada e entregas com parceiro Lokally.';

    final String? coordinates = hasLocation
        ? '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'
        : null;

    return Material(
      color: primaryColor.withValues(alpha: hasLocation ? 0.08 : 0.05),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: primaryColor.withValues(alpha: hasLocation ? 0.30 : 0.18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  hasLocation
                      ? Icons.check_circle_outline_rounded
                      : Icons.location_on_outlined,
                  color: primaryColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textBold.copyWith(
                        color: Colors.black87,
                        fontSize: 12.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: textRegular.copyWith(
                        color: Colors.grey.shade700,
                        fontSize: 11.8,
                        height: 1.28,
                      ),
                    ),
                    if (coordinates != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        coordinates,
                        style: textMedium.copyWith(
                          color: primaryColor,
                          fontSize: 11.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: primaryColor,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreFormLabel extends StatelessWidget {
  final String label;

  const StoreFormLabel({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 3, bottom: 7),
      child: Text(
        label,
        style: textBold.copyWith(
          color: Colors.black87,
          fontSize: 13.5,
        ),
      ),
    );
  }
}

class StoreDeliveryOptionsCard extends StatelessWidget {
  final Color primaryColor;
  final bool pickupEnabled;
  final bool ownDeliveryEnabled;
  final bool lokallyDeliveryEnabled;
  final ValueChanged<bool> onPickupChanged;
  final ValueChanged<bool> onOwnDeliveryChanged;
  final ValueChanged<bool> onLokallyDeliveryChanged;

  const StoreDeliveryOptionsCard({
    super.key,
    required this.primaryColor,
    required this.pickupEnabled,
    required this.ownDeliveryEnabled,
    required this.lokallyDeliveryEnabled,
    required this.onPickupChanged,
    required this.onOwnDeliveryChanged,
    required this.onLokallyDeliveryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 8),
            blurRadius: 22,
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Retirada e entrega',
            style: textBold.copyWith(
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure como o cliente poderá receber os produtos da sua loja.',
            style: textRegular.copyWith(
              color: Colors.grey.shade600,
              fontSize: 12.5,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          StoreSwitchRow(
            title: 'Retirada grátis',
            description: 'Cliente retira o pedido na loja.',
            value: pickupEnabled,
            primaryColor: primaryColor,
            onChanged: onPickupChanged,
          ),
          StoreSwitchRow(
            title: 'Entrega própria',
            description: 'A loja entrega com equipe própria.',
            value: ownDeliveryEnabled,
            primaryColor: primaryColor,
            onChanged: onOwnDeliveryChanged,
          ),
          StoreSwitchRow(
            title: 'Frete Lokally',
            description: 'Permitir entrega usando a rede Lokally.',
            value: lokallyDeliveryEnabled,
            primaryColor: primaryColor,
            onChanged: onLokallyDeliveryChanged,
          ),
        ],
      ),
    );
  }
}

class StoreSwitchRow extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final Color primaryColor;
  final ValueChanged<bool> onChanged;

  const StoreSwitchRow({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textBold.copyWith(
                      color: Colors.black87,
                      fontSize: 13.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: textRegular.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 11.8,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
