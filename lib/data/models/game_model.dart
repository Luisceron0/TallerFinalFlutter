import '../../domain/entities/game_entity.dart';

class GameModel extends GameEntity {
  const GameModel({
    required super.id,
    required super.title,
    required super.normalizedTitle,
    super.steamAppId,
    super.epicSlug,
    super.description,
    super.imageUrl,
    super.createdAt,
    super.updatedAt,
  });

  factory GameModel.fromJson(Map<String, dynamic> json) {
    return GameModel(
      id: json['id'] as String,
      title: json['title'] as String,
      normalizedTitle: json['normalized_title'] as String,
      steamAppId: json['steam_app_id'] as String?,
      epicSlug: json['epic_slug'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'normalized_title': normalizedTitle,
      'steam_app_id': steamAppId,
      'epic_slug': epicSlug,
      'description': description,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  GameEntity toEntity() {
    return GameEntity(
      id: id,
      title: title,
      normalizedTitle: normalizedTitle,
      steamAppId: steamAppId,
      epicSlug: epicSlug,
      description: description,
      imageUrl: imageUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory GameModel.fromEntity(GameEntity entity) {
    return GameModel(
      id: entity.id,
      title: entity.title,
      normalizedTitle: entity.normalizedTitle,
      steamAppId: entity.steamAppId,
      epicSlug: entity.epicSlug,
      description: entity.description,
      imageUrl: entity.imageUrl,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
