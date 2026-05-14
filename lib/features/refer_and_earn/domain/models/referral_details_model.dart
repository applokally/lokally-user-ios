class ReferralDetailsModel {
  String? responseCode;
  String? message;
  int? totalSize;
  int? limit;
  int? offset;
  Data? data;
  List<String>? errors;

  ReferralDetailsModel({
    this.responseCode,
    this.message,
    this.totalSize,
    this.limit,
    this.offset,
    this.data,
    this.errors,
  });

  ReferralDetailsModel.fromJson(Map<String, dynamic> json) {
    responseCode = json['response_code'];
    message = json['message'];
    totalSize = json['total_size'];
    limit = json['limit'];
    offset = json['offset'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
    errors = json['errors'] != null
        ? List<String>.from(json['errors'].map((error) => error.toString()))
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['response_code'] = responseCode;
    result['message'] = message;
    result['total_size'] = totalSize;
    result['limit'] = limit;
    result['offset'] = offset;

    if (data != null) {
      result['data'] = data!.toJson();
    }

    result['errors'] = errors;
    return result;
  }
}

class Data {
  String? referralCode;
  double? shareCodeEarning;
  bool? firstRideDiscountStatus;
  double? discountAmount;
  String? discountAmountType;
  int? discountValidity;
  String? discountValidityType;

  Data({
    this.referralCode,
    this.shareCodeEarning,
    this.firstRideDiscountStatus,
    this.discountAmount,
    this.discountAmountType,
    this.discountValidity,
    this.discountValidityType,
  });

  Data.fromJson(Map<String, dynamic> json) {
    referralCode = json['referral_code'];
    shareCodeEarning =
        double.tryParse((json['share_code_earning'] ?? 0).toString()) ?? 0;
    firstRideDiscountStatus = json['first_ride_discount_status'];
    discountAmount =
        double.tryParse((json['discount_amount'] ?? 0).toString()) ?? 0;
    discountAmountType = json['discount_amount_type'];
    discountValidity =
        int.tryParse((json['discount_validity'] ?? 0).toString()) ?? 0;
    discountValidityType = json['discount_validity_type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['referral_code'] = referralCode;
    result['share_code_earning'] = shareCodeEarning;
    result['first_ride_discount_status'] = firstRideDiscountStatus;
    result['discount_amount'] = discountAmount;
    result['discount_amount_type'] = discountAmountType;
    result['discount_validity'] = discountValidity;
    result['discount_validity_type'] = discountValidityType;
    return result;
  }
}
