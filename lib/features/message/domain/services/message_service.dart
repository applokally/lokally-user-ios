import 'package:file_picker/file_picker.dart';
import 'package:get/get_connect/http/src/response/response.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/message/domain/repositories/message_repository_interface.dart';
import 'package:ride_sharing_user_app/features/message/domain/services/message_service_interface.dart';

class MessageService implements MessageServiceInterface {
  MessageRepositoryInterface messageRepositoryInterface;

  MessageService({required this.messageRepositoryInterface});

  @override
  Future createChannel(String userId, String tripId) async {
    return await messageRepositoryInterface.createChannel(userId, tripId);
  }

  @override
  Future createChannelWithAdmin({String supportContext = 'customer'}) async {
    return await messageRepositoryInterface.createChannelWithAdmin(
      supportContext: supportContext,
    );
  }

  @override
  Future getChannelList(int offset) async {
    return await messageRepositoryInterface.getChannelList(offset);
  }

  @override
  Future getSupportChannelList(
    int offset, {
    String supportContext = 'customer',
  }) async {
    return await messageRepositoryInterface.getSupportChannelList(
      offset,
      supportContext: supportContext,
    );
  }

  @override
  Future getConversation(String channelId, int offset) async {
    return await messageRepositoryInterface.getConversation(channelId, offset);
  }

  @override
  Future getSupportConversation(String channelId, int offset) async {
    return await messageRepositoryInterface.getSupportConversation(
      channelId,
      offset,
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
    return await messageRepositoryInterface.sendMessage(
      message,
      channelID,
      tripId,
      file,
      platformFile,
    );
  }

  @override
  Future<Response> sendMessageToAdmin(
    String message,
    String channelID,
    List<MultipartBody> file,
    PlatformFile? platformFile,
  ) async {
    return await messageRepositoryInterface.sendMessageToAdmin(
      message,
      channelID,
      file,
      platformFile,
    );
  }

  @override
  Future<Response> deleteSupportChannel(String channelId) async {
    return await messageRepositoryInterface.deleteSupportChannel(channelId);
  }

  @override
  Future findChannelRideStatus(String channelId) {
    return messageRepositoryInterface.findChannelRideStatus(channelId);
  }
}
