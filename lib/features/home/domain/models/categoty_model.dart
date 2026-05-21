class CategoryModel {
  String? responseCode;
  String? message;
  int? totalSize;
  String? limit;
  String? offset;
  List<Category>? data;

  CategoryModel({
    this.responseCode,
    this.message,
    this.totalSize,
    this.limit,
    this.offset,
    this.data,
  });

  CategoryModel.fromJson(Map<String, dynamic> json) {
    responseCode = json['response_code']?.toString();
    message = json['message']?.toString();
    totalSize = _parseInt(json['total_size']);
    limit = json['limit']?.toString();
    offset = json['offset']?.toString();

    data = <Category>[];

    final dynamic dataValue = json['data'];
    if (dataValue is List) {
      for (final dynamic item in dataValue) {
        final Map<String, dynamic>? itemMap = _asMap(item);
        if (itemMap == null) {
          continue;
        }

        final Category category = Category.fromJson(itemMap);
        if ((category.id ?? '').isNotEmpty &&
            (category.name ?? '').isNotEmpty) {
          data!.add(category);
        }
      }
    }
  }

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['response_code'] = responseCode;
    data['message'] = message;
    data['total_size'] = totalSize;
    data['limit'] = limit;
    data['offset'] = offset;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }

    return data;
  }
}

class Category {
  String? id;
  String? name;
  String? image;
  List<Fare>? fare;

  Category({this.id, this.name, this.image, this.fare});

  Category.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    name = json['name']?.toString();
    image = json['image']?.toString();

    fare = <Fare>[];

    final dynamic fareValue = json['fare'];
    if (fareValue is List) {
      for (final dynamic item in fareValue) {
        final Map<String, dynamic>? itemMap = _asMap(item);
        if (itemMap != null) {
          fare!.add(Fare.fromJson(itemMap));
        }
      }
    }
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['image'] = image;
    if (fare != null) {
      data['fare'] = fare!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Fare {
  String? id;
  double? baseFare;
  double? baseFarePerKm;
  double? waitingFeePerMin;
  double? minCancellationFee;
  double? idleFeePerMin;
  double? tripDelayFeePerMin;
  double? penaltyFeeForCancel;
  double? feeAddToNext;
  String? createdAt;

  Fare({
    this.id,
    this.baseFare,
    this.baseFarePerKm,
    this.waitingFeePerMin,
    this.minCancellationFee,
    this.idleFeePerMin,
    this.tripDelayFeePerMin,
    this.penaltyFeeForCancel,
    this.feeAddToNext,
    this.createdAt,
  });

  Fare.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    baseFare = _parseDouble(json['base_fare']);
    baseFarePerKm = _parseDouble(json['base_fare_per_km']);
    waitingFeePerMin = _parseDouble(json['waiting_fee_per_min']);
    minCancellationFee = _parseDouble(json['min_cancellation_fee']);
    idleFeePerMin = _parseDouble(json['idle_fee_per_min']);
    tripDelayFeePerMin = _parseDouble(json['trip_delay_fee_per_min']);
    penaltyFeeForCancel = _parseDouble(json['penalty_fee_for_cancel']);
    feeAddToNext = _parseDouble(json['fee_add_to_next']);
    createdAt = json['created_at']?.toString();
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['base_fare'] = baseFare;
    data['base_fare_per_km'] = baseFarePerKm;
    data['waiting_fee_per_min'] = waitingFeePerMin;
    data['min_cancellation_fee'] = minCancellationFee;
    data['idle_fee_per_min'] = idleFeePerMin;
    data['trip_delay_fee_per_min'] = tripDelayFeePerMin;
    data['penalty_fee_for_cancel'] = penaltyFeeForCancel;
    data['fee_add_to_next'] = feeAddToNext;
    data['created_at'] = createdAt;
    return data;
  }
}
