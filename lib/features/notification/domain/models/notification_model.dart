class NotificationsModel {
  String? responseCode;
  String? message;
  int? totalSize;
  String? limit;
  String? offset;
  List<Notifications>? data;

  NotificationsModel({
    this.responseCode,
    this.message,
    this.totalSize,
    this.limit,
    this.offset,
    this.data,
  });

  NotificationsModel.fromJson(Map<String, dynamic> json) {
    responseCode = json['response_code'];
    message = json['message'];
    totalSize = json['total_size'];
    limit = json['limit'];
    offset = json['offset'];
    if (json['data'] != null) {
      data = <Notifications>[];
      json['data'].forEach((v) {
        data!.add(Notifications.fromJson(v));
      });
    }
  }
}

class Notifications {
  int? id;
  String? userId;
  String? rideRequestId;
  String? title;
  String? description;
  String? image;
  String? type;
  String? action;
  String? createdAt;
  String? notificationType;
  String? relatedType;
  String? relatedId;
  String? targetRoute;
  Map<String, dynamic>? targetParams;
  Map<String, dynamic>? payload;
  bool? isRead;
  String? readAt;

  Notifications({
    this.id,
    this.userId,
    this.rideRequestId,
    this.title,
    this.description,
    this.image,
    this.type,
    this.action,
    this.createdAt,
    this.notificationType,
    this.relatedType,
    this.relatedId,
    this.targetRoute,
    this.targetParams,
    this.payload,
    this.isRead,
    this.readAt,
  });

  Notifications.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    userId = json['user_id'];
    rideRequestId = json['ride_request_id'];
    title = json['title'];
    description = json['description'];
    image = json['image'];
    type = json['type'];
    action = json['action'];
    createdAt = json['created_at'];
    isRead = json['is_read'];
    notificationType = json['notification_type'];
    relatedType = json['related_type'];
    relatedId = json['related_id'];
    targetRoute = json['target_route'];
    targetParams = _mapFromJsonValue(json['target_params']);
    payload = _mapFromJsonValue(json['payload']);
    readAt = json['read_at'];
  }

  static Map<String, dynamic>? _mapFromJsonValue(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  String firstValue(List<String> keys) {
    for (final String key in keys) {
      final dynamic directValue = _directValue(key);
      final String directText = _cleanText(directValue);
      if (directText.isNotEmpty) {
        return directText;
      }

      final String targetParamText = _cleanText(targetParams?[key]);
      if (targetParamText.isNotEmpty) {
        return targetParamText;
      }

      final String payloadText = _cleanText(payload?[key]);
      if (payloadText.isNotEmpty) {
        return payloadText;
      }
    }

    return '';
  }

  dynamic _directValue(String key) {
    switch (key) {
      case 'id':
        return id;
      case 'user_id':
        return userId;
      case 'ride_request_id':
        return rideRequestId;
      case 'title':
        return title;
      case 'description':
        return description;
      case 'image':
        return image;
      case 'type':
        return type;
      case 'action':
        return action;
      case 'created_at':
        return createdAt;
      case 'notification_type':
        return notificationType;
      case 'related_type':
        return relatedType;
      case 'related_id':
        return relatedId;
      case 'target_route':
        return targetRoute;
      case 'read_at':
        return readAt;
    }

    return null;
  }

  static String _cleanText(dynamic value) {
    if (value == null) {
      return '';
    }

    final String text = value.toString().trim();
    if (text == 'null') {
      return '';
    }

    return text;
  }
}
