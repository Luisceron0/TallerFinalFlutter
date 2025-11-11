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

      // Sort by created_at if available to ensure latest comes last
      priceHistory.sort((a, b) {
        try {
          final aDate = a['created_at'] != null
              ? DateTime.parse(a['created_at'])
              : DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b['created_at'] != null
              ? DateTime.parse(b['created_at'])
              : DateTime.fromMillisecondsSinceEpoch(0);
          return aDate.compareTo(bDate);
        } catch (_) {
          return 0;
        }
      });

      // Group by store and get latest price for each store
      final steamPrices = priceHistory
          .where((p) => (p['store']?.toString() ?? '').toLowerCase() == 'steam')
          .toList();
      final epicPrices = priceHistory
          .where((p) => (p['store']?.toString() ?? '').toLowerCase() == 'epic')
          .toList();

      dynamic _parsePriceEntry(Map<String, dynamic> entry) {
        // Safely parse price to double if possible
        final rawPrice = entry['price'];
        double? priceVal;
        if (rawPrice is num) {
          priceVal = rawPrice.toDouble();
        } else if (rawPrice is String) {
          priceVal = double.tryParse(rawPrice.replaceAll(',', '.'));
        }

        return {
          'price': priceVal,
          'discount_percent': entry['discount_percent'] is int
              ? entry['discount_percent']
              : (int.tryParse('${entry['discount_percent']}') ?? 0),
          'is_free': entry['is_free'] is bool
              ? entry['is_free']
              : (entry['is_free'] == 'true' || entry['is_free'] == 1),
          'url': entry['url']?.toString(),
        };
      }

      if (steamPrices.isNotEmpty) {
        final latestSteam = steamPrices.last as Map<String, dynamic>;
        prices['steam'] = _parsePriceEntry(latestSteam);
      }

      if (epicPrices.isNotEmpty) {
        final latestEpic = epicPrices.last as Map<String, dynamic>;
        prices['epic'] = _parsePriceEntry(latestEpic);
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
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
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
