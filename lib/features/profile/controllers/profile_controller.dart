import 'dart:async';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/profile/domain/models/profile_model.dart';
import 'package:ride_sharing_user_app/features/profile/domain/services/profile_service_interface.dart';
import 'package:ride_sharing_user_app/helper/file_validation_helper.dart';

class ProfileController extends GetxController implements GetxService {
  final ProfileServiceInterface profileServiceInterface;

  ProfileController({required this.profileServiceInterface});

  final List<String> _identityTypeList = ['rg', 'cnh'];

  XFile? _pickedProfileFile;
  List<MultipartBody> multipartList = [];
  XFile? _pickedIdentityImageFront;
  XFile identityImage = XFile('');
  XFile? _pickedIdentityImageBack;
  bool isLoading = false;
  String _identityType = 'rg';
  ProfileModel? profileModel;
  bool isUpdating = false;

  XFile? get pickedProfileFile => _pickedProfileFile;
  XFile? get pickedIdentityImageFront => _pickedIdentityImageFront;
  XFile? get pickedIdentityImageBack => _pickedIdentityImageBack;
  List<XFile> identityImages = [];
  List<String> get identityTypeList => _identityTypeList;
  String get identityType => _identityType;

  String _normalizeIdentityType(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();

    if (normalized == 'cnh' || normalized == 'driving_license') {
      return 'cnh';
    }

    if (normalized == 'rg' ||
        normalized == 'passport' ||
        normalized == 'nid' ||
        normalized.isEmpty) {
      return 'rg';
    }

    if (_identityTypeList.contains(normalized)) {
      return normalized;
    }

    return 'rg';
  }

  void setIdentityType(String setValue, {bool notify = true}) {
    _identityType = _normalizeIdentityType(setValue);

    if (notify) {
      update();
    }
  }

  Future<bool> pickImage(bool isBack, bool isProfile) async {
    if (isProfile) {
      _pickedProfileFile = (await FileValidationHelper.validateAndPickImage(
        source: ImageSource.gallery,
      ))!;
    } else {
      identityImage = (await FileValidationHelper.validateAndPickImage(
        source: ImageSource.gallery,
      ))!;
      identityImages.add(identityImage);
    }

    update();
    return true;
  }

  void removeImage(int index) {
    identityImages.removeAt(index);
    update();
  }

  void clearSelectedImage() {
    _pickedProfileFile = null;
  }

  String customerName() {
    if (profileModel != null) {
      return '${profileModel!.data!.firstName ?? ''} ${profileModel!.data!.lastName ?? ''}';
    } else {
      return 'Guest';
    }
  }

  String customerFirstName() {
    if (profileModel != null) {
      return profileModel!.data!.firstName ?? '';
    } else {
      return 'Guest';
    }
  }

  Future<Response> getProfileInfo() async {
    Response? response = await profileServiceInterface.getProfileInfo();

    if (response!.statusCode == 200) {
      profileModel = ProfileModel.fromJson(response.body);
      _identityType = _normalizeIdentityType(
        profileModel?.data?.identificationType,
      );
    } else {
      ApiChecker.checkApi(response);
    }

    isLoading = false;
    update();
    return response;
  }

  Future<Response> updateProfile(
    String firstName,
    String lastName,
    String identityType,
    String idNumber,
  ) async {
    isUpdating = true;
    update();

    final String normalizedIdentityType = _normalizeIdentityType(identityType);

    Response? response = await profileServiceInterface.updateProfileInfo(
      firstName,
      lastName,
      idNumber,
      normalizedIdentityType,
      _pickedProfileFile,
      multipartList,
    );

    if (response!.statusCode == 200) {
      _identityType = normalizedIdentityType;
      Get.back();
      getProfileInfo();
    } else {
      ApiChecker.checkApi(response);
    }

    isUpdating = false;
    update();
    return response;
  }
}
