class PriceHistoryEntity {
  final String id;
  final String gameId;
  final String store; // 'steam' or 'epic'
  final double? price;
  final int discountPercent;
  final bool isFree;
  final DateTime scrapedAt;

  const PriceHistoryEntity({
    required this.id,
    required this.gameId,
    required this.store,
    this.price,
    this.discountPercent = 0,
    required this.isFree,
    required this.scrapedAt,
  });

  PriceHistoryEntity copyWith({
    String? id,
    String? gameId,
    String? store,
    double? price,
    int? discountPercent,
    bool? isFree,
    DateTime? scrapedAt,
  }) {
    return PriceHistoryEntity(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      store: store ?? this.store,
      price: price ?? this.price,
      discountPercent: discountPercent ?? this.discountPercent,
      isFree: isFree ?? this.isFree,
      scrapedAt: scrapedAt ?? this.scrapedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PriceHistoryEntity &&
        other.id == id &&
        other.gameId == gameId &&
        other.store == store &&
        other.price == price &&
        other.discountPercent == discountPercent &&
        other.isFree == isFree;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        gameId.hashCode ^
        store.hashCode ^
        price.hashCode ^
        discountPercent.hashCode ^
        isFree.hashCode;
  }
}
