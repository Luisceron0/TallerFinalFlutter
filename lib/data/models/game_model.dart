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
    super.prices,
    super.aiInsight,
    required super.createdAt,
    required super.updatedAt,
  });

  factory GameModel.fromJson(Map<String, dynamic> json) {
    // Extract prices from price_history if available
    Map<String, dynamic>? prices;
    if (json['price_history'] != null && json['price_history'] is List) {
      prices = {};
      final priceHistory = json['price_history'] as List;

      // Group by store and get latest price for each store
      final steamPrices = priceHistory.where((p) => p['store'] == 'steam').toList();
      final epicPrices = priceHistory.where((p) => p['store'] == 'epic').toList();

      if (steamPrices.isNotEmpty) {
        final latestSteam = steamPrices.last;
        prices['steam'] = {
          'price': latestSteam['price'] != null ? (latestSteam['price'] as num).toDouble() : null,
          'discount_percent': latestSteam['discount_percent'] as int? ?? 0,
          'is_free': latestSteam['is_free'] as bool? ?? false,
        };
      }

      if (epicPrices.isNotEmpty) {
        final latestEpic = epicPrices.last;
        prices['epic'] = {
          'price': latestEpic['price'] != null ? (latestEpic['price'] as num).toDouble() : null,
          'discount_percent': latestEpic['discount_percent'] as int? ?? 0,
          'is_free': latestEpic['is_free'] as bool? ?? false,
        };
      }
    } else {
      prices = json['prices'] as Map<String, dynamic>?;
    }

    return GameModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Game',
      normalizedTitle: json['normalized_title']?.toString() ?? '',
      steamAppId: json['steam_app_id']?.toString(),
      epicSlug: json['epic_slug']?.toString(),
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString(),
      prices: prices,
      aiInsight: json['ai_insight']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
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
      prices: prices,
      aiInsight: aiInsight,
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
      prices: entity.prices,
      aiInsight: entity.aiInsight,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
