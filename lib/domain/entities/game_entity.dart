class GameEntity {
  final String id;
  final String title;
  final String normalizedTitle;
  final String? steamAppId;
  final String? epicSlug;
  final String? description;
  final String? imageUrl;
  final Map<String, dynamic>? prices;
  final String? aiInsight;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GameEntity({
    required this.id,
    required this.title,
    required this.normalizedTitle,
    this.steamAppId,
    this.epicSlug,
    this.description,
    this.imageUrl,
    this.prices,
    this.aiInsight,
    required this.createdAt,
    required this.updatedAt,
  });

  GameEntity copyWith({
    String? id,
    String? title,
    String? normalizedTitle,
    String? steamAppId,
    String? epicSlug,
    String? description,
    String? imageUrl,
    Map<String, dynamic>? prices,
    String? aiInsight,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GameEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      normalizedTitle: normalizedTitle ?? this.normalizedTitle,
      steamAppId: steamAppId ?? this.steamAppId,
      epicSlug: epicSlug ?? this.epicSlug,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      prices: prices ?? this.prices,
      aiInsight: aiInsight ?? this.aiInsight,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameEntity &&
        other.id == id &&
        other.title == title &&
        other.normalizedTitle == normalizedTitle &&
        other.steamAppId == steamAppId &&
        other.epicSlug == epicSlug &&
        other.description == description &&
        other.imageUrl == imageUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        normalizedTitle.hashCode ^
        steamAppId.hashCode ^
        epicSlug.hashCode ^
        description.hashCode ^
        imageUrl.hashCode;
  }
}
