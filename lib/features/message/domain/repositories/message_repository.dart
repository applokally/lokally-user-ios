import 'package:file_picker/file_picker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/message/domain/repositories/message_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:get/get_connect/http/src/response/response.dart';

class MessageRepository implements MessageRepositoryInterface {
  final ApiClient apiClient;
  MessageRepository({required this.apiClient});

  @override
  Future<Response> createChannel(String userId, String tripId) async {
    return await apiClient.postData(AppConstants.createChannel, {
      "to": userId,
      "trip_id": tripId,
      "_method": "put",
    });
  }

  @override
  Future<Response> createChannelWithAdmin(
      {String supportContext = 'customer'}) async {
    return await apiClient.postData(AppConstants.createChannelWithAdmin, {
      "_method": "put",
      "support_context": supportContext,
    });
  }

  @override
  Future<Response> getChannelList(int offset) async {
    return await apiClient.getData(
      '${AppConstants.channelList}?limit=10&offset=$offset',
    );
  }

  @override
  Future<Response> getSupportChannelList(
    int offset, {
    String supportContext = 'customer',
  }) async {
    return await apiClient.getData(
      '${AppConstants.supportChannelList}?limit=12&offset=$offset&support_context=$supportContext',
    );
  }

  @override
  Future<Response> getConversation(String channelId, int offset) async {
    return await apiClient.getData(
      '${AppConstants.conversationList}?channel_id=$channelId&limit=20&offset=$offset',
    );
  }

  @override
  Future<Response> getSupportConversation(String channelId, int offset) async {
    return await apiClient.getData(
      '${AppConstants.supportConversation}?channel_id=$channelId&limit=30&offset=$offset',
    );
  }

  @override
  Future<Response> sendMessage(
    String message,
    String channelID,
    String tripId,
    List<MultipartBody> file,
    PlatformFile? platformFile,
  ) async {
    return await apiClient.postMultipartDataConversation(
      AppConstants.sendMessage,
      {
        "message": message,
        "channel_id": channelID,
        "trip_id": tripId,
        "_method": "put",
      },
      file,
      otherFile: platformFile,
    );
  }

  @override
  Future<Response> sendMessageToAdmin(
    String message,
    String channelID,
    List<MultipartBody> file,
    PlatformFile? platformFile,
  ) async {
    return await apiClient.postMultipartDataConversation(
      AppConstants.sendMessageToAdmin,
      {
        "message": message,
        "channel_id": channelID,
        "_method": "put",
      },
      file,
      otherFile: platformFile,
    );
  }

  @override
  Future<Response> deleteSupportChannel(String channelId) async {
    return await apiClient.postData(AppConstants.deleteSupportChannel, {
      "channel_id": channelId,
      "_method": "put",
    });
  }

  @override
  Future<Response> findChannelRideStatus(String channelId) async {
    return await apiClient.getData(
      '${AppConstants.findChannelRideStatus}?channel_id=$channelId',
    );
  }

  @override
  Future add(value) {
    throw UnimplementedError();
  }

  @override
  Future delete(String id) {
    throw UnimplementedError();
  }

  @override
  Future get(String id) {
    throw UnimplementedError();
  }

  @override
  Future getList({int? offset = 1}) {
    throw UnimplementedError();
  }

  @override
  Future update(value, {int? id}) {
    throw UnimplementedError();
  }
}
