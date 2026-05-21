import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/message/controllers/message_controller.dart';
import 'package:ride_sharing_user_app/features/message/domain/models/channel_model.dart';
import 'package:ride_sharing_user_app/features/message/widget/message_item.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/notification/widgets/notification_shimmer.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';

class MessageListScreen extends StatefulWidget {
  final String supportContext;
  final String title;
  final bool showRideChats;

  const MessageListScreen({
    super.key,
    this.supportContext = 'customer',
    this.title = 'message',
    this.showRideChats = true,
  });

  @override
  State<MessageListScreen> createState() => _MessageListScreenState();
}

class _MessageListScreenState extends State<MessageListScreen> {
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    Get.find<MessageController>().refreshMessageHome(
      supportContext: widget.supportContext,
      includeRideChats: widget.showRideChats,
    );
    super.initState();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  List<SupportChannelItem> _openSupportChannels(MessageController controller) {
    return controller.supportChannels
        .where((supportChannel) =>
            supportChannel.canReply &&
            supportChannel.supportContext == widget.supportContext)
        .toList();
  }

  List<SupportChannelItem> _closedSupportChannels(
      MessageController controller) {
    return controller.supportChannels
        .where((supportChannel) =>
            !supportChannel.canReply &&
            supportChannel.supportContext == widget.supportContext)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        body: BodyWidget(
          appBar: AppBarWidget(title: widget.title.tr, showBackButton: true),
          body: GetBuilder<MessageController>(builder: (messageController) {
            final List<SupportChannelItem> openSupport =
                _openSupportChannels(messageController);
            final List<SupportChannelItem> closedSupport =
                _closedSupportChannels(messageController);

            return Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: RefreshIndicator(
                onRefresh: () => messageController.refreshMessageHome(
                  supportContext: widget.supportContext,
                  includeRideChats: widget.showRideChats,
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LokallySupportChatCard(
                        isLoading:
                            messageController.isOpeningLokallySupportChat,
                        onTap: () => messageController.openLokallySupportChat(
                          supportContext: widget.supportContext,
                          supportTitle: widget.title.tr,
                        ),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),
                      if (openSupport.isNotEmpty) ...[
                        _SectionTitle(title: 'Atendimento aberto'),
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                        ...openSupport.map(
                          (supportChannel) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: Dimensions.paddingSizeSmall,
                            ),
                            child: SupportChannelListItem(
                              supportChannel: supportChannel,
                              onTap: () =>
                                  messageController.openExistingSupportChat(
                                supportChannel,
                                supportContext: widget.supportContext,
                              ),
                              onDelete: null,
                            ),
                          ),
                        ),
                        const SizedBox(height: Dimensions.paddingSizeDefault),
                      ],
                      if (closedSupport.isNotEmpty) ...[
                        _SectionTitle(title: 'Histórico de atendimentos'),
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                        ...closedSupport.map(
                          (supportChannel) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: Dimensions.paddingSizeSmall,
                            ),
                            child: SupportChannelListItem(
                              supportChannel: supportChannel,
                              onTap: () =>
                                  messageController.openExistingSupportChat(
                                supportChannel,
                                supportContext: widget.supportContext,
                              ),
                              onDelete: () =>
                                  messageController.deleteClosedSupportChannel(
                                supportChannel.id,
                                supportContext: widget.supportContext,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: Dimensions.paddingSizeDefault),
                      ],
                      if (widget.showRideChats &&
                          messageController.channelModel?.data == null)
                        const SizedBox(
                          height: 260,
                          child: NotificationShimmer(),
                        )
                      else if (widget.showRideChats &&
                          messageController.channelModel!.data!.isNotEmpty) ...[
                        _SectionTitle(title: 'Conversas de viagens'),
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                        ListView.builder(
                          itemCount:
                              messageController.channelModel!.data!.length,
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (BuildContext context, int index) {
                            ChannelUsers? channelUser;

                            for (var element in messageController
                                .channelModel!.data![index].channelUsers!) {
                              if (element.user?.userType == 'driver') {
                                channelUser = element;
                              }
                            }

                            return messageController.channelModel!.data![index]
                                        .lastChannelConversations !=
                                    null
                                ? MessageItem(
                                    isRead: false,
                                    channelUsers: channelUser,
                                    unReadCount: messageController.channelModel!
                                        .data![index].unReadCount!,
                                    lastMessage: messageController
                                            .channelModel!
                                            .data![index]
                                            .lastChannelConversations
                                            ?.message ??
                                        '',
                                    tripId: messageController
                                        .channelModel!.data![index].tripId!,
                                  )
                                : const SizedBox();
                          },
                        ),
                      ] else if (openSupport.isEmpty &&
                          closedSupport.isEmpty) ...[
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            'Nenhuma conversa encontrada.',
                            style: textRegular.copyWith(
                              color: Theme.of(context).hintColor,
                              fontSize: Dimensions.fontSizeDefault,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: textBold.copyWith(
        color: Theme.of(context).textTheme.bodyMedium?.color,
        fontSize: Dimensions.fontSizeDefault,
      ),
    );
  }
}

class LokallySupportChatCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const LokallySupportChatCard({
    super.key,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.support_agent_rounded,
                color: primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Falar com a Lokally',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(
                      color: Colors.black87,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Abra um atendimento direto com o suporte oficial.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 12.2,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: primaryColor,
                    ),
                  )
                : Icon(
                    Icons.add_comment_rounded,
                    color: primaryColor,
                    size: 22,
                  ),
          ],
        ),
      ),
    );
  }
}

class SupportChannelListItem extends StatelessWidget {
  final SupportChannelItem supportChannel;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const SupportChannelListItem({
    super.key,
    required this.supportChannel,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final bool isOpen = supportChannel.canReply;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isOpen
              ? primaryColor.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOpen
                ? primaryColor.withValues(alpha: 0.18)
                : Colors.grey.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isOpen
                    ? primaryColor.withValues(alpha: 0.14)
                    : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isOpen
                    ? Icons.mark_chat_unread_rounded
                    : Icons.mark_chat_read_rounded,
                color: isOpen ? primaryColor : Colors.grey.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supportChannel.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(
                      color: Colors.black87,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    supportChannel.lastMessage.isNotEmpty
                        ? supportChannel.lastMessage
                        : isOpen
                            ? 'Continue seu atendimento com a Lokally.'
                            : 'Toque para visualizar o histórico.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(
                      color: Colors.grey.shade700,
                      fontSize: 12.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (supportChannel.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${supportChannel.unreadCount}',
                  style: textBold.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            if (onDelete != null)
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent.shade200,
                    size: 21,
                  ),
                ),
              )
            else
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.grey.shade500,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
