import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controllers/notification_controller.dart';
import '../controllers/auth_controller.dart';
import '../../core/constants/app_colors.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationController _notificationController = Get.put(NotificationController());
  final AuthController _authController = Get.find<AuthController>();
  final SupabaseClient _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    final user = _client.auth.currentUser;
    if (user != null) {
      _notificationController.loadNotifications(userId: user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Back button and title
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 22,
                          ),
                          onPressed: () => Get.back(),
                        ),
                        const Expanded(
                          child: Text(
                            'Notificaciones',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // Mark all as read button
                        Obx(() => _notificationController.unreadCount > 0
                            ? IconButton(
                                icon: const Icon(
                                  Icons.done_all,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  final user = _client.auth.currentUser;
                                  if (user != null) {
                                    _notificationController.markAllAsRead(user.id);
                                  }
                                },
                              )
                            : const SizedBox(width: 48)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Unread count
                    Obx(() => Text(
                          '${_notificationController.unreadCount} sin leer',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        )),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: Container(
                color: Colors.white,
                child: Obx(() {
                  if (_notificationController.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryNeon,
                      ),
                    );
                  }

                  final notifications = _notificationController.notifications;

                  if (notifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: AppColors.secondaryText,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tienes notificaciones',
                            style: const TextStyle(
                              fontSize: 18,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      final user = _client.auth.currentUser;
                      if (user != null) {
                        await _notificationController.refreshNotifications(user.id);
                      }
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return _NotificationCard(
                          notification: notification,
                          onMarkAsRead: () => _notificationController.markAsRead(notification.id),
                        );
                      },
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final dynamic notification;
  final VoidCallback onMarkAsRead;

  const _NotificationCard({
    required this.notification,
    required this.onMarkAsRead,
  });

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'price_drop':
        return Icons.trending_down;
      case 'target_reached':
        return Icons.check_circle;
      case 'ai_tip':
        return Icons.lightbulb;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'price_drop':
        return Colors.green;
      case 'target_reached':
        return Colors.blue;
      case 'ai_tip':
        return AppColors.primaryNeon;
      default:
        return AppColors.primaryPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: notification.isRead ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.check,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) => onMarkAsRead(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead ? AppColors.cardBackground : AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead
                ? AppColors.primaryNeon.withOpacity(0.2)
                : AppColors.primaryNeon.withOpacity(0.5),
            width: notification.isRead ? 1 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notification icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getNotificationColor(notification.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getNotificationIcon(notification.type),
                color: _getNotificationColor(notification.type),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Notification content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Game title if available
                  if (notification.gameTitle != null) ...[
                    Text(
                      notification.gameTitle!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Message
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primaryText,
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Timestamp
                  Text(
                    _formatTimestamp(notification.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            // Unread indicator
            if (!notification.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primaryNeon,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return DateFormat('dd/MM/yyyy').format(timestamp);
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes}m';
    } else {
      return 'Ahora';
    }
  }
}
