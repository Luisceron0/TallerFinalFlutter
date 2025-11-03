import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../models/notification_model.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<NotificationEntity>> getUserNotifications(String userId) async {
    try {
      final response = await _client
          .from('notifications')
          .select('''
            *,
            games!inner(title, image_url)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return response.map<NotificationEntity>((json) {
        final notification = NotificationModel.fromJson(json);
        return NotificationEntity(
          id: notification.id,
          userId: notification.userId,
          gameId: notification.gameId,
          type: notification.type,
          message: notification.message,
          isRead: notification.isRead,
          createdAt: notification.createdAt,
          gameTitle: json['games']['title'] as String?,
          gameImageUrl: json['games']['image_url'] as String?,
        );
      }).toList();
    } catch (e) {
      throw Exception('Error fetching notifications: $e');
    }
  }

  @override
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      throw Exception('Error marking notification as read: $e');
    }
  }

  @override
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      throw Exception('Error marking all notifications as read: $e');
    }
  }

  @override
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final response = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      throw Exception('Error getting unread notification count: $e');
    }
  }
}
