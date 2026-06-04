import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/notification/controllers/notification_controller.dart';
import 'package:ride_sharing_user_app/features/notification/widgets/notification_card.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/features/notification/widgets/notification_shimmer.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/no_data_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/paginated_list_widget.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    Get.find<NotificationController>().getNotificationList(1);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BodyWidget(
      appBar: AppBarWidget(title: 'Notificações', showBackButton: true),
      body: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GetBuilder<NotificationController>(
            builder: (notificationController) {
              return Row(children: [
                _NotificationFilterButton(
                  title: 'Todas',
                  value: 'all',
                  selectedValue: notificationController.selectedReadStatus,
                  onTap: () =>
                      notificationController.changeReadStatusFilter('all'),
                ),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                _NotificationFilterButton(
                  title: 'Não lidas',
                  value: 'unread',
                  selectedValue: notificationController.selectedReadStatus,
                  onTap: () =>
                      notificationController.changeReadStatusFilter('unread'),
                ),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                _NotificationFilterButton(
                  title: 'Lidas',
                  value: 'read',
                  selectedValue: notificationController.selectedReadStatus,
                  onTap: () =>
                      notificationController.changeReadStatusFilter('read'),
                ),
              ]);
            },
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Expanded(child: GetBuilder<NotificationController>(
              builder: (notificationController) {
            return notificationController.notificationModel != null
                ? (notificationController.notificationModel!.data != null &&
                        notificationController
                            .notificationModel!.data!.isNotEmpty)
                    ? SingleChildScrollView(
                        controller: scrollController,
                        child: PaginatedListWidget(
                          scrollController: scrollController,
                          totalSize: notificationController
                              .notificationModel!.totalSize,
                          offset: (notificationController.notificationModel !=
                                      null &&
                                  notificationController
                                          .notificationModel!.offset !=
                                      null)
                              ? int.parse(notificationController
                                  .notificationModel!.offset
                                  .toString())
                              : null,
                          onPaginate: (int? offset) async {
                            await notificationController
                                .getNotificationList(offset!);
                          },
                          itemView: ListView.builder(
                            itemCount: notificationController
                                .notificationModel!.data!.length,
                            padding: const EdgeInsets.all(0),
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemBuilder: (BuildContext context, int index) {
                              return NotificationCard(
                                previousNotification: index == 0
                                    ? null
                                    : notificationController
                                        .notificationModel!.data![index - 1],
                                notification: notificationController
                                    .notificationModel!.data![index],
                                nextNotification: (index ==
                                        notificationController
                                                .notificationModel!
                                                .data!
                                                .length -
                                            1)
                                    ? null
                                    : notificationController
                                        .notificationModel!.data![index + 1],
                                index: index,
                              );
                            },
                          ),
                        ),
                      )
                    : const NoDataWidget(title: 'no_notification_found')
                : const NotificationShimmer();
          })),
          Container(height: 70),
        ]),
      ),
    );
  }
}

class _NotificationFilterButton extends StatelessWidget {
  final String title;
  final String value;
  final String selectedValue;
  final VoidCallback onTap;

  const _NotificationFilterButton({
    required this.title,
    required this.value,
    required this.selectedValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = value == selectedValue;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).primaryColor
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: selected
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).hintColor.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: Dimensions.fontSizeSmall,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyMedium?.color,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
