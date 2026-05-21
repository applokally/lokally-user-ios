import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/custom_pop_scope_widget.dart';
import 'package:ride_sharing_user_app/features/message/widget/message_bubble.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/localization/localization_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/message/controllers/message_controller.dart';
import 'package:ride_sharing_user_app/features/notification/widgets/notification_shimmer.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/no_data_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/paginated_list_widget.dart';
import 'dart:math' as math;

class MessageScreen extends StatefulWidget {
  final String channelId;
  final String tripId;
  final String userName;
  final bool isSupportChat;
  final bool supportCanReply;
  final String supportContext;

  const MessageScreen({
    super.key,
    required this.channelId,
    required this.tripId,
    required this.userName,
    this.isSupportChat = false,
    this.supportCanReply = true,
    this.supportContext = 'customer',
  });

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen>
    with WidgetsBindingObserver {
  final ScrollController scrollController = ScrollController();
  bool _supportInitialLoadStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.isSupportChat && state == AppLifecycleState.resumed) {
      Get.find<MessageController>().getSupportConversation(
        widget.channelId,
        silent: true,
      );
    }
  }

  Future<void> _loadData() async {
    final MessageController messageController = Get.find<MessageController>();

    if (widget.isSupportChat) {
      _loadSupportConversation(messageController);
      return;
    }

    if (Get.find<ProfileController>().profileModel?.data?.id == null) {
      await Get.find<ProfileController>().getProfileInfo();
    }

    messageController.findChannelRideStatus(widget.channelId);
    messageController.getConversation(widget.channelId, 1);
    messageController.subscribeMessageChannel(widget.tripId);
  }

  void _loadSupportConversation(MessageController messageController) {
    if (_supportInitialLoadStarted) {
      return;
    }

    _supportInitialLoadStarted = true;

    messageController.prepareSupportConversation(
      canReply: widget.supportCanReply,
    );

    messageController.messageModel = null;
    messageController.update();

    messageController.getSupportConversation(
      widget.channelId,
      showLoader: true,
    );

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }

      messageController.getSupportConversation(
        widget.channelId,
        silent: true,
      );
    });

    if (widget.supportCanReply) {
      messageController.startSupportConversationAutoRefresh(widget.channelId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    if (widget.isSupportChat) {
      final MessageController messageController = Get.find<MessageController>();
      messageController.stopSupportConversationAutoRefresh();
      messageController.getSupportChannelList(
        1,
        silent: true,
        supportContext: widget.supportContext,
      );
    }

    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: CustomPopScopeWidget(
        child: Scaffold(
          body: BodyWidget(
            appBar: AppBarWidget(
              title: widget.isSupportChat
                  ? (widget.supportCanReply
                      ? 'Atendimento Lokally'
                      : 'Atendimento encerrado')
                  : "${'chat_with'.tr} ${widget.userName}",
              showBackButton: true,
              centerTitle: true,
            ),
            body: GetBuilder<MessageController>(builder: (messageController) {
              final bool canWrite = widget.isSupportChat
                  ? !messageController.isSupportConversationClosed
                  : messageController.channelRideStatus;

              return Column(
                children: [
                  _buildConversationArea(
                    context,
                    messageController,
                  ),
                  if (messageController.pickedImageFile != null &&
                      messageController.pickedImageFile!.isNotEmpty)
                    _buildPickedImages(messageController),
                  if (messageController.otherFile != null)
                    _buildPickedFile(messageController),
                  const SizedBox(height: 20),
                  canWrite
                      ? _buildInputArea(context, messageController)
                      : _buildClosedConversationFooter(context),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationArea(
    BuildContext context,
    MessageController messageController,
  ) {
    if (messageController.messageModel?.data == null) {
      if (widget.isSupportChat) {
        return Expanded(
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        );
      }

      return const Expanded(child: NotificationShimmer());
    }

    if (messageController.messageModel!.data!.isEmpty) {
      if (widget.isSupportChat) {
        return Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeLarge,
              ),
              child: Text(
                widget.supportCanReply
                    ? 'Envie uma mensagem para iniciar o atendimento com a Lokally.'
                    : 'Nenhuma mensagem encontrada neste atendimento encerrado.',
                textAlign: TextAlign.center,
                style: textRegular.copyWith(
                  color: Theme.of(context).hintColor,
                  fontSize: Dimensions.fontSizeDefault,
                ),
              ),
            ),
          ),
        );
      }

      return const Expanded(
        child: NoDataWidget(title: 'no_message_found'),
      );
    }

    return Expanded(
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: scrollController,
            reverse: true,
            child: PaginatedListWidget(
              reverse: true,
              scrollController: scrollController,
              totalSize: messageController.messageModel?.totalSize,
              offset: (messageController.messageModel != null &&
                      messageController.messageModel?.offset != null)
                  ? int.parse(messageController.messageModel!.offset.toString())
                  : null,
              onPaginate: (int? offset) async {
                if (widget.isSupportChat) {
                  await messageController.getSupportConversation(
                    widget.channelId,
                    silent: true,
                  );
                } else {
                  await messageController.getConversation(
                    widget.channelId,
                    offset!,
                  );
                }
              },
              itemView: ListView.builder(
                reverse: true,
                itemCount: messageController.messageModel?.data?.length,
                padding: const EdgeInsets.all(0),
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemBuilder: (BuildContext context, int index) {
                  if (index != 0) {
                    return ConversationBubble(
                      message: messageController.messageModel!.data![index],
                      previousMessage:
                          messageController.messageModel!.data![index - 1],
                      index: index,
                      length: messageController.messageModel!.data!.length,
                      showTripInfo: !widget.isSupportChat,
                    );
                  }

                  return ConversationBubble(
                    message: messageController.messageModel!.data![index],
                    index: index,
                    length: messageController.messageModel!.data!.length,
                    showTripInfo: !widget.isSupportChat,
                  );
                },
              ),
            ),
          ),
          if (widget.isSupportChat &&
              messageController.isSupportConversationRefreshing)
            Positioned(
              top: 8,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPickedImages(MessageController messageController) {
    return Container(
      height: 90,
      width: Get.width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: messageController.pickedImageFile!.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 80,
                    width: 80,
                    child: Image.file(
                      File(messageController.pickedImageFile![index].path),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 5,
                child: InkWell(
                  onTap: () => messageController.pickMultipleImage(
                    true,
                    index: index,
                  ),
                  child: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPickedFile(MessageController messageController) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          height: 25,
          child: Text(messageController.otherFile!.names.toString()),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: InkWell(
            onTap: () => messageController.pickOtherFile(true),
            child: const Icon(
              Icons.cancel_outlined,
              color: Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea(
    BuildContext context,
    MessageController messageController,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(
              left: Dimensions.paddingSizeSmall,
              right: Dimensions.paddingSizeSmall,
              bottom: Dimensions.paddingSizeSmall,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).primaryColor),
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.all(Radius.circular(100)),
            ),
            child: Form(
              key: messageController.conversationKey,
              child: Row(
                children: [
                  const SizedBox(width: Dimensions.paddingSizeDefault),
                  Expanded(
                    child: TextField(
                      minLines: 1,
                      controller: messageController.conversationController,
                      textCapitalization: TextCapitalization.sentences,
                      style: textMedium.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .color!
                            .withValues(alpha: 0.8),
                      ),
                      keyboardType: TextInputType.multiline,
                      maxLines: 2,
                      cursorColor: Theme.of(context).primaryColor,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "type_here".tr,
                        hintStyle: textRegular.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium!
                              .color!
                              .withValues(alpha: 0.8),
                          fontSize: 16,
                        ),
                      ),
                      onChanged: (String newText) {},
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeSmall,
                    ),
                    child: InkWell(
                      onTap: () => messageController.pickMultipleImage(false),
                      child: Image.asset(
                        Images.pickImage,
                        color: Get.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).primaryColor),
            color: Theme.of(context).primaryColor,
            borderRadius: const BorderRadius.all(Radius.circular(50)),
          ),
          margin: EdgeInsets.only(
            bottom: Dimensions.paddingSizeDefault,
            right: Get.find<LocalizationController>().isLtr
                ? Dimensions.paddingSizeDefault
                : 0,
            left: Get.find<LocalizationController>().isLtr
                ? 0
                : Dimensions.paddingSizeDefault,
          ),
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          child: messageController.isSending
              ? SpinKitCircle(color: Theme.of(context).cardColor, size: 20)
              : messageController.isImagePicked
                  ? SpinKitCircle(
                      color: Theme.of(context).cardColor,
                      size: 20,
                    )
                  : InkWell(
                      onTap: () {
                        if (messageController.conversationController.text
                                .trim()
                                .isEmpty &&
                            messageController.pickedImageFile!.isEmpty &&
                            messageController.otherFile == null) {
                          showCustomSnackBar(
                            'write_something'.tr,
                            isError: true,
                          );
                        } else if (messageController
                            .conversationKey.currentState!
                            .validate()) {
                          if (widget.isSupportChat) {
                            messageController
                                .sendSupportMessage(
                                  widget.channelId,
                                  supportContext: widget.supportContext,
                                )
                                .then((value) {});
                          } else {
                            messageController
                                .sendMessage(widget.channelId, widget.tripId)
                                .then((value) {});
                          }
                        }
                      },
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Get.find<LocalizationController>().isLtr
                            ? Matrix4.rotationY(0)
                            : Matrix4.rotationY(math.pi),
                        child: Image.asset(
                          Images.sendMessage,
                          width: Dimensions.iconSizeMedium,
                          height: Dimensions.iconSizeMedium,
                          color: Theme.of(context).cardColor,
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildClosedConversationFooter(BuildContext context) {
    final String text = widget.isSupportChat
        ? 'Este chat foi encerrado. Você não pode enviar mensagens, apenas visualizar o histórico.'
        : "you_could't_replay_you_have_no_trip".tr;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeSmall,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeDefault,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.block),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: textRegular.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: Dimensions.fontSizeSmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
