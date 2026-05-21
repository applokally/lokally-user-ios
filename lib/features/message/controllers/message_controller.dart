import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/message/domain/services/message_service_interface.dart';
import 'package:ride_sharing_user_app/features/message/screens/message_screen.dart';
import 'package:ride_sharing_user_app/features/message/domain/models/channel_model.dart';
import 'package:ride_sharing_user_app/features/message/domain/models/message_model.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/file_validation_helper.dart';
import 'package:ride_sharing_user_app/helper/pusher_helper.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class MessageController extends GetxController implements GetxService {
  final MessageServiceInterface messageServiceInterface;
  MessageController({required this.messageServiceInterface});

  List<XFile>? _pickedImageFiles = [];
  List<XFile>? get pickedImageFile => _pickedImageFiles;

  bool isLoading = false;
  bool isOpeningLokallySupportChat = false;
  bool isSupportConversationRefreshing = false;
  bool isSupportConversationClosed = false;
  bool isSupportChannelListLoading = false;

  Timer? _supportConversationTimer;
  String _activeSupportChannelId = '';
  bool _isSupportConversationRequestRunning = false;

  FilePickerResult? _otherFile;
  FilePickerResult? get otherFile => _otherFile;

  File? _file;
  PlatformFile? objFile;
  File? get file => _file;

  List<MultipartBody> _selectedImageList = [];
  List<MultipartBody> get selectedImageList => _selectedImageList;

  final List<dynamic> _conversationList = [];
  List<dynamic> get conversationList => _conversationList;

  final bool _paginationLoading = true;
  bool get paginationLoading => _paginationLoading;

  final String _name = '';
  String get name => _name;
  final String _image = '';
  String get image => _image;

  var conversationController = TextEditingController();
  final GlobalKey<FormState> conversationKey = GlobalKey<FormState>();

  ChannelModel? channelModel;
  MessageModel? messageModel;

  List<SupportChannelItem> supportChannels = [];

  @override
  void onInit() {
    super.onInit();
    conversationController.text = '';
  }

  bool isImagePicked = false;

  void pickMultipleImage(bool isRemove, {int? index}) async {
    if (isRemove) {
      if (index != null) {
        _pickedImageFiles!.removeAt(index);
        _selectedImageList.removeAt(index);
      }
    } else {
      isImagePicked = true;
      Future.delayed(const Duration(seconds: 1)).then((value) {
        update();
      });
      _pickedImageFiles =
          await FileValidationHelper.validateAndPickMultipleImages();
      if (_pickedImageFiles != null) {
        for (int i = 0; i < _pickedImageFiles!.length; i++) {
          _selectedImageList
              .add(MultipartBody('files[$i]', _pickedImageFiles![i]));
        }
      }
      isImagePicked = false;
    }
    update();
  }

  bool permissionGranted = false;

  Future getStoragePermission() async {
    if (await Permission.storage.request().isGranted) {
      permissionGranted = true;
    } else if (await Permission.storage.request().isPermanentlyDenied) {
      await openAppSettings();
    } else if (await Permission.storage.request().isDenied) {
      await openAppSettings();
      Permission.storage.request();
    }
    update();
  }

  void pickOtherFile(bool isRemove) async {
    if (isRemove) {
      _otherFile = null;
      _file = null;
    } else {
      _otherFile = (await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withReadStream: true,
        allowedExtensions: AppConstants.allowedImageExtensionsForFile,
      ))!;
      if (_otherFile != null) {
        if (await FileValidationHelper.validatePlatformFileSizeAsync(
            file: _otherFile!.files.single)) {
          objFile = _otherFile!.files.single;
        }
      }
    }
    update();
  }

  void removeFile() async {
    _otherFile = null;
    update();
  }

  void cleanOldData() {
    _pickedImageFiles = [];
    _selectedImageList = [];
    _otherFile = null;
    _file = null;
    objFile = null;
    conversationController.clear();
  }

  Future<void> refreshMessageHome({
    String supportContext = 'customer',
    bool includeRideChats = true,
  }) async {
    getSupportChannelList(
      1,
      silent: true,
      supportContext: supportContext,
    );

    if (includeRideChats) {
      getChannelList(1);
    }
  }

  Future<void> getChannelList(int offset) async {
    Response response = await messageServiceInterface.getChannelList(offset);
    if (response.statusCode == 200) {
      if (offset == 1) {
        channelModel = ChannelModel.fromJson(response.body);
      } else {
        channelModel!.totalSize =
            ChannelModel.fromJson(response.body).totalSize;
        channelModel!.offset = ChannelModel.fromJson(response.body).offset;
        channelModel!.data!.addAll(ChannelModel.fromJson(response.body).data!);
      }
      isLoading = false;
    } else {
      ApiChecker.checkApi(response);
    }
    update();
  }

  Future<void> getSupportChannelList(
    int offset, {
    bool silent = false,
    String supportContext = 'customer',
  }) async {
    if (!silent) {
      isSupportChannelListLoading = true;
      update();
    }

    Response response = await messageServiceInterface.getSupportChannelList(
      offset,
      supportContext: supportContext,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data =
          response.body['data'] is List ? response.body['data'] : <dynamic>[];

      final List<SupportChannelItem> parsedList = data
          .map((item) => SupportChannelItem.fromJson(
                item is Map ? Map<String, dynamic>.from(item) : {},
                fallbackSupportContext: supportContext,
              ))
          .where((item) => item.id.isNotEmpty)
          .toList();

      if (offset == 1) {
        supportChannels = parsedList;
      } else {
        supportChannels.addAll(parsedList);
      }
    } else if (!silent) {
      ApiChecker.checkApi(response);
    }

    isSupportChannelListLoading = false;
    update();
  }

  Future<void> createChannel(String userId, String? tripId) async {
    isLoading = true;
    Response response =
        await messageServiceInterface.createChannel(userId, tripId!);
    if (response.statusCode == 200) {
      isLoading = false;
      Map map = response.body;
      String channelId = map['data']['channel']['id'];
      String tripId = map['data']['channel']['trip_id'];
      Get.to(() => MessageScreen(
          channelId: channelId,
          tripId: tripId,
          userName:
              '${map['data']['user']['first_name']} ${map['data']['user']['last_name']}'));
    } else {
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    update();
  }

  Future<void> openLokallySupportChat({
    String supportContext = 'customer',
    String supportTitle = 'Atendimento Lokally',
  }) async {
    if (isOpeningLokallySupportChat) {
      return;
    }

    isOpeningLokallySupportChat = true;
    update();

    Response response = await messageServiceInterface.createChannelWithAdmin(
      supportContext: supportContext,
    );

    if (response.statusCode == 200) {
      Map map = response.body;
      final dynamic dataValue = map['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};
      final dynamic channelValue = data['channel'];
      final Map<String, dynamic> channel = channelValue is Map
          ? Map<String, dynamic>.from(channelValue)
          : <String, dynamic>{};
      String channelId = '${channel['id'] ?? ''}';
      String supportStatus = '${channel['support_status'] ?? 'open'}';

      if (channelId.isNotEmpty) {
        cleanOldData();
        messageModel = MessageModel(
          data: [],
          totalSize: 0,
          limit: '20',
          offset: '1',
        );
        isSupportConversationClosed = supportStatus == 'closed';
        _channelRideStatus = !isSupportConversationClosed;
        isOpeningLokallySupportChat = false;
        update();

        await Get.to(
          () => MessageScreen(
            channelId: channelId,
            tripId: '',
            userName: supportTitle,
            isSupportChat: true,
            supportContext: supportContext,
            supportCanReply: !isSupportConversationClosed,
          ),
        );

        getSupportChannelList(
          1,
          silent: true,
          supportContext: supportContext,
        );
        return;
      }

      showCustomSnackBar('Não foi possível abrir o atendimento agora.',
          isError: true);
    } else {
      ApiChecker.checkApi(response);
    }

    isOpeningLokallySupportChat = false;
    update();
  }

  Future<void> openExistingSupportChat(
    SupportChannelItem supportChannel, {
    String supportContext = 'customer',
  }) async {
    if (supportChannel.id.isEmpty) {
      return;
    }

    cleanOldData();
    messageModel = MessageModel(
      data: [],
      totalSize: 0,
      limit: '30',
      offset: '1',
    );
    isSupportConversationClosed = !supportChannel.canReply;
    _channelRideStatus = supportChannel.canReply;
    update();

    await Get.to(
      () => MessageScreen(
        channelId: supportChannel.id,
        tripId: '',
        userName: supportChannel.canReply
            ? 'Atendimento Lokally'
            : 'Atendimento encerrado',
        isSupportChat: true,
        supportCanReply: supportChannel.canReply,
        supportContext: supportContext,
      ),
    );

    getSupportChannelList(
      1,
      silent: true,
      supportContext: supportContext,
    );
  }

  Future<void> deleteClosedSupportChannel(
    String channelId, {
    String supportContext = 'customer',
  }) async {
    Response response =
        await messageServiceInterface.deleteSupportChannel(channelId);

    if (response.statusCode == 200) {
      supportChannels.removeWhere((channel) => channel.id == channelId);
      showCustomSnackBar('Atendimento removido da sua listagem.',
          isError: false);
    } else {
      ApiChecker.checkApi(response);
    }

    update();
  }

  Future<void> getConversation(String channelId, int offset) async {
    isLoading = true;
    Response response =
        await messageServiceInterface.getConversation(channelId, offset);
    if (response.statusCode == 200) {
      if (offset == 1) {
        messageModel = MessageModel.fromJson(response.body);
      } else {
        messageModel!.totalSize =
            MessageModel.fromJson(response.body).totalSize;
        messageModel!.offset = MessageModel.fromJson(response.body).offset;
        messageModel!.data!.addAll(MessageModel.fromJson(response.body).data!);
      }
      isLoading = false;
    } else {
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    update();
  }

  Future<void> getSupportConversation(
    String channelId, {
    bool showLoader = false,
    bool silent = false,
  }) async {
    if (_isSupportConversationRequestRunning) {
      return;
    }

    _isSupportConversationRequestRunning = true;

    if (showLoader && messageModel == null) {
      messageModel = MessageModel(
        data: [],
        totalSize: 0,
        limit: '20',
        offset: '1',
      );
      update();
    }

    if (!silent) {
      isSupportConversationRefreshing = true;
      update();
    }

    try {
      Response response =
          await messageServiceInterface.getSupportConversation(channelId, 1);

      if (response.statusCode == 200) {
        messageModel = MessageModel.fromJson(response.body);
        final dynamic canReplyValue = response.body['can_reply'];
        final bool canReply = canReplyValue == true || '$canReplyValue' == '1';
        isSupportConversationClosed = !canReply;
        _channelRideStatus = canReply;
      } else if (response.statusCode == 409) {
        isSupportConversationClosed = true;
        _channelRideStatus = false;
      } else if (!silent) {
        ApiChecker.checkApi(response);
      }
    } finally {
      isSupportConversationRefreshing = false;
      _isSupportConversationRequestRunning = false;
      update();
    }
  }

  void startSupportConversationAutoRefresh(String channelId) {
    _activeSupportChannelId = channelId;
    _supportConversationTimer?.cancel();

    _supportConversationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_activeSupportChannelId.isEmpty || isSending) {
        return;
      }

      getSupportConversation(
        _activeSupportChannelId,
        silent: true,
      );
    });
  }

  void stopSupportConversationAutoRefresh() {
    _supportConversationTimer?.cancel();
    _supportConversationTimer = null;
    _activeSupportChannelId = '';
  }

  bool isSending = false;

  Future<void> sendMessage(String channelId, String tripId) async {
    isSending = true;
    update();
    Response response = await messageServiceInterface.sendMessage(
        conversationController.value.text,
        channelId,
        tripId,
        _selectedImageList,
        objFile);
    if (response.statusCode == 200) {
      isSending = false;
      getConversation(channelId, 1);
      conversationController.text = '';
      _pickedImageFiles = [];
      _selectedImageList = [];
      _otherFile = null;
      objFile = null;
      _file = null;
    } else if (response.statusCode == 400) {
      isSending = false;
      String message = response.body['errors'][0]['message'];
      if (message.contains("png  jpg  jpeg  csv  txt  xlx  xls  pdf")) {
        message = "the_files_types_must_be";
      }
      if (message.contains("failed to upload")) {
        message = "failed_to_upload";
      }
      _pickedImageFiles = [];
      _selectedImageList = [];
      _otherFile = null;
      objFile = null;
      _file = null;
      showCustomSnackBar(message.tr);
    } else {
      isSending = false;
      _pickedImageFiles = [];
      _selectedImageList = [];
      _otherFile = null;
      objFile = null;
      _file = null;
      ApiChecker.checkApi(response);
    }
    isLoading = false;
    update();
  }

  Future<void> sendSupportMessage(
    String channelId, {
    String supportContext = 'customer',
  }) async {
    final String textToSend = conversationController.value.text.trim();
    final int? temporaryMessageId =
        textToSend.isNotEmpty ? -DateTime.now().millisecondsSinceEpoch : null;

    if (temporaryMessageId != null) {
      final String? currentUserId =
          Get.find<ProfileController>().profileModel?.data?.id;

      messageModel ??= MessageModel(
        data: [],
        totalSize: 0,
        limit: '30',
        offset: '1',
      );

      messageModel!.data ??= [];

      messageModel!.data!.insert(
        0,
        Message.fromJson({
          'id': temporaryMessageId,
          'user_id': currentUserId,
          'message': textToSend,
          'trip_id': null,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'conversation_files': [],
          'user': {
            'id': currentUserId,
            'user_type': 'customer',
            'profile_image': '',
          },
        }),
      );

      messageModel!.totalSize = (messageModel!.totalSize ?? 0) + 1;
    }

    isSending = true;
    update();

    Response response = await messageServiceInterface.sendMessageToAdmin(
      textToSend,
      channelId,
      _selectedImageList,
      objFile,
    );

    if (response.statusCode == 200) {
      isSending = false;
      conversationController.text = '';
      _pickedImageFiles = [];
      _selectedImageList = [];
      _otherFile = null;
      objFile = null;
      _file = null;
      isLoading = false;
      update();

      getSupportConversation(channelId, silent: true);
      getSupportChannelList(
        1,
        silent: true,
        supportContext: supportContext,
      );
      return;
    }

    if (temporaryMessageId != null && messageModel?.data != null) {
      messageModel!.data!
          .removeWhere((message) => message.id == temporaryMessageId);
      messageModel!.totalSize = (messageModel!.totalSize ?? 1) - 1;
    }

    if (response.statusCode == 409) {
      isSending = false;
      isSupportConversationClosed = true;
      _channelRideStatus = false;
      showCustomSnackBar(
        'Este atendimento foi encerrado. Inicie um novo atendimento para enviar uma nova mensagem.',
        isError: true,
      );
    } else if (response.statusCode == 400 || response.statusCode == 403) {
      isSending = false;
      String message =
          response.body['errors'] != null && response.body['errors'].isNotEmpty
              ? response.body['errors'][0]['message']
              : 'Não foi possível enviar a mensagem.';
      if (message.contains("png  jpg  jpeg  csv  txt  xlx  xls  pdf")) {
        message = "the_files_types_must_be";
      }
      if (message.contains("failed to upload")) {
        message = "failed_to_upload";
      }
      _pickedImageFiles = [];
      _selectedImageList = [];
      _otherFile = null;
      objFile = null;
      _file = null;
      showCustomSnackBar(message.tr);
    } else {
      isSending = false;
      _pickedImageFiles = [];
      _selectedImageList = [];
      _otherFile = null;
      objFile = null;
      _file = null;
      ApiChecker.checkApi(response);
    }

    isLoading = false;
    update();
  }

  void prepareSupportConversation({bool canReply = true}) {
    isSupportConversationClosed = !canReply;
    _channelRideStatus = canReply;
    update();
  }

  late PrivateChannel channel;
  String id = "";
  bool _isRideChatSubscribed = false;
  String _subscribedRideChatId = '';

  void subscribeMessageChannel(String tripId) {
    id = tripId;

    if (_isRideChatSubscribed && _subscribedRideChatId == id) {
      return;
    }

    if (Get.find<ConfigController>().pusherConnectionStatus != null ||
        Get.find<ConfigController>().pusherConnectionStatus == 'Connected') {
      channel = PusherHelper.pusherClient!.privateChannel(
          "private-customer-ride-chat.$id",
          authorizationDelegate:
              EndpointAuthorizableChannelTokenAuthorizationDelegate
                  .forPrivateChannel(
            authorizationEndpoint: Uri.parse(
                'https://${Get.find<ConfigController>().config!.webSocketUrl}/broadcasting/auth'),
            headers: {
              "Accept": "application/json",
              "Authorization":
                  "Bearer ${Get.find<AuthController>().getUserToken()}",
              "Access-Control-Allow-Origin": "*",
              'Access-Control-Allow-Methods': "PUT, GET, POST, DELETE, OPTIONS"
            },
          ));

      channel.subscribe();
      _isRideChatSubscribed = true;
      _subscribedRideChatId = id;

      channel.bind("customer-ride-chat.$id").listen((event) {
        if (id ==
            jsonDecode(event.data!)['channel_conversation']['channel']
                ['trip_id']) {
          messageModel!.data!.insert(
              0,
              Message.fromJson(
                  jsonDecode(event.data!)['channel_conversation']));
          update();
        }
      });
    }
  }

  bool _channelRideStatus = true;
  bool get channelRideStatus => _channelRideStatus;

  void findChannelRideStatus(String channelId) async {
    Response response =
        await messageServiceInterface.findChannelRideStatus(channelId);
    if (response.body['data'] == "cancelled" ||
        response.body['data'] == 'completed') {
      _channelRideStatus = false;
    } else {
      _channelRideStatus = true;
    }
    update();
  }

  @override
  void onClose() {
    stopSupportConversationAutoRefresh();
    conversationController.dispose();
    super.onClose();
  }
}

class SupportChannelItem {
  final String id;
  final String title;
  final String supportStatus;
  final String supportContext;
  final String lastMessage;
  final String lastMessageCreatedAt;
  final String updatedAt;
  final int unreadCount;
  final bool canReply;

  SupportChannelItem({
    required this.id,
    required this.title,
    required this.supportStatus,
    required this.supportContext,
    required this.lastMessage,
    required this.lastMessageCreatedAt,
    required this.updatedAt,
    required this.unreadCount,
    required this.canReply,
  });

  bool get isOpen => supportStatus == 'open';

  factory SupportChannelItem.fromJson(
    Map<String, dynamic> json, {
    String fallbackSupportContext = 'customer',
  }) {
    final String status = '${json['support_status'] ?? 'open'}';

    return SupportChannelItem(
      id: '${json['id'] ?? ''}',
      title:
          '${json['title'] ?? (status == 'open' ? 'Suporte em andamento' : 'Suporte encerrado')}',
      supportStatus: status,
      supportContext: '${json['support_context'] ?? fallbackSupportContext}',
      lastMessage: '${json['last_message'] ?? ''}',
      lastMessageCreatedAt: '${json['last_message_created_at'] ?? ''}',
      updatedAt: '${json['updated_at'] ?? ''}',
      unreadCount: int.tryParse('${json['unread_count'] ?? 0}') ?? 0,
      canReply: json['can_reply'] == true || '${json['can_reply']}' == '1',
    );
  }
}
