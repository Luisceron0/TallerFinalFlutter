import '../../domain/entities/price_history_entity.dart';

class PriceHistoryModel extends PriceHistoryEntity {
  const PriceHistoryModel({
    required super.id,
    required super.gameId,
    required super.store,
    super.price,
    super.discountPercent,
    required super.isFree,
    required super.scrapedAt,
  });

  factory PriceHistoryModel.fromJson(Map<String, dynamic> json) {
    return PriceHistoryModel(
      id: json['id'] as String,
      gameId: json['game_id'] as String,
      store: json['store'] as String,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      discountPercent: json['discount_percent'] as int? ?? 0,
      isFree: json['is_free'] as bool? ?? false,
      scrapedAt: DateTime.parse(json['scraped_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'game_id': gameId,
      'store': store,
      'price': price,
      'discount_percent': discountPercent,
      'is_free': isFree,
      'scraped_at': scrapedAt.toIso8601String(),
    };
  }

  PriceHistoryEntity toEntity() {
    return PriceHistoryEntity(
      id: id,
      gameId: gameId,
      store: store,
      price: price,
      discountPercent: discountPercent,
      isFree: isFree,
      scrapedAt: scrapedAt,
    );
  }

  factory PriceHistoryModel.fromEntity(PriceHistoryEntity entity) {
    return PriceHistoryModel(
      id: entity.id,
      gameId: entity.gameId,
      store: entity.store,
      price: entity.price,
      discountPercent: entity.discountPercent,
      isFree: entity.isFree,
      scrapedAt: entity.scrapedAt,
    );
  }
}
