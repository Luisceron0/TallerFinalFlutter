import 'package:equatable/equatable.dart';

class NotificationEntity extends Equatable {
  final String id;
  final String userId;
  final String gameId;
  final String type; // 'price_drop', 'target_reached', 'ai_tip'
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? gameTitle;
  final String? gameImageUrl;

  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.gameId,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.gameTitle,
    this.gameImageUrl,
  });

  NotificationEntity copyWith({
    String? id,
    String? userId,
    String? gameId,
    String? type,
    String? message,
    bool? isRead,
    DateTime? createdAt,
    String? gameTitle,
    String? gameImageUrl,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      gameId: gameId ?? this.gameId,
      type: type ?? this.type,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      gameTitle: gameTitle ?? this.gameTitle,
      gameImageUrl: gameImageUrl ?? this.gameImageUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        gameId,
        type,
        message,
        isRead,
        createdAt,
        gameTitle,
        gameImageUrl,
      ];
}
