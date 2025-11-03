import 'package:get/get.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../data/repositories/notification_repository_impl.dart';

class NotificationController extends GetxController {
  final NotificationRepository _notificationRepository = NotificationRepositoryImpl();

  // Observable variables
  final RxList<NotificationEntity> _notifications = <NotificationEntity>[].obs;
  final RxBool _isLoading = false.obs;
  final RxInt _unreadCount = 0.obs;
  final RxString _errorMessage = ''.obs;

  // Getters
  List<NotificationEntity> get notifications => _notifications;
  bool get isLoading => _isLoading.value;
  int get unreadCount => _unreadCount.value;
  String get errorMessage => _errorMessage.value;

  @override
  void onInit() {
    super.onInit();
    loadUnreadCount();
  }

  /// Cargar notificaciones del usuario
  Future<void> loadNotifications({String? userId}) async {
    if (userId == null) return;

    try {
      _isLoading.value = true;
      _errorMessage.value = '';

      final notifications = await _notificationRepository.getUserNotifications(userId);
      _notifications.assignAll(notifications);
    } catch (e) {
      _errorMessage.value = 'Error loading notifications: $e';
      Get.snackbar('Error', _errorMessage.value);
    } finally {
      _isLoading.value = false;
    }
  }

  /// Cargar conteo de notificaciones no leídas
  Future<void> loadUnreadCount({String? userId}) async {
    if (userId == null) return;

    try {
      final count = await _notificationRepository.getUnreadNotificationCount(userId);
      _unreadCount.value = count;
    } catch (e) {
      // Silently handle error for unread count
      _unreadCount.value = 0;
    }
  }

  /// Marcar notificación como leída
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationRepository.markNotificationAsRead(notificationId);

      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final updatedNotification = _notifications[index].copyWith(isRead: true);
        _notifications[index] = updatedNotification;
        _unreadCount.value = (_unreadCount.value - 1).clamp(0, double.infinity).toInt();
      }
    } catch (e) {
      _errorMessage.value = 'Error marking notification as read: $e';
      Get.snackbar('Error', _errorMessage.value);
    }
  }

  /// Marcar todas las notificaciones como leídas
  Future<void> markAllAsRead(String userId) async {
    try {
      await _notificationRepository.markAllNotificationsAsRead(userId);

      // Update local state
      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
        }
      }
      _unreadCount.value = 0;
    } catch (e) {
      _errorMessage.value = 'Error marking all notifications as read: $e';
      Get.snackbar('Error', _errorMessage.value);
    }
  }

  /// Limpiar notificaciones
  void clearNotifications() {
    _notifications.clear();
    _errorMessage.value = '';
  }

  /// Refresh notificaciones y conteo
  Future<void> refreshNotifications(String userId) async {
    await Future.wait([
      loadNotifications(userId: userId),
      loadUnreadCount(userId: userId),
    ]);
  }
}
