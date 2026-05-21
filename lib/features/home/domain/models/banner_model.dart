class BannerModel {
  int? totalSize;
  String? limit;
  String? offset;
  List<Banner>? data;

  BannerModel({
    this.totalSize,
    this.limit,
    this.offset,
    this.data,
  });

  BannerModel.fromJson(Map<String, dynamic> json) {
    totalSize = _parseInt(json['total_size']);
    limit = json['limit']?.toString();
    offset = json['offset']?.toString();

    data = <Banner>[];

    final dynamic dataValue = json['data'];
    if (dataValue is List) {
      for (final dynamic item in dataValue) {
        final Map<String, dynamic>? itemMap = _asMap(item);
        if (itemMap == null) {
          continue;
        }

        final Banner banner = Banner.fromJson(itemMap);
        if ((banner.id ?? '').isNotEmpty || (banner.image ?? '').isNotEmpty) {
          data!.add(banner);
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
    data['total_size'] = totalSize;
    data['limit'] = limit;
    data['offset'] = offset;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }

    return data;
  }
}

class Banner {
  String? id;
  String? name;
  String? image;
  String? redirectLink;
  int? totalRedirection;
  String? createdAt;

  Banner({
    this.id,
    this.name,
    this.image,
    this.redirectLink,
    this.totalRedirection,
    this.createdAt,
  });

  Banner.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    name = json['name']?.toString();
    image = json['image']?.toString();
    redirectLink = json['redirect_link']?.toString();
    totalRedirection = _parseInt(json['total_redirection']);
    createdAt = json['created_at']?.toString();
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

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['image'] = image;
    data['redirect_link'] = redirectLink;
    data['total_redirection'] = totalRedirection;
    data['created_at'] = createdAt;
    return data;
  }
}
