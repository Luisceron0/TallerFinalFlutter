import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  final String id;
  final String userId;
  final String gameId;
  final String type; // 'price_drop', 'target_reached', 'ai_tip'
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? gameTitle; // Optional for display
  final String? gameImageUrl; // Optional for display

  const NotificationModel({
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

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      gameId: json['game_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'unknown',
      message: json['message']?.toString() ?? 'No message',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      gameTitle: json['game_title']?.toString(),
      gameImageUrl: json['game_image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'game_id': gameId,
      'type': type,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'game_title': gameTitle,
      'game_image_url': gameImageUrl,
    };
  }

  NotificationModel copyWith({
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
    return NotificationModel(
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
