import '../../domain/entities/map_point_entity.dart';

class MapPointModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final String userId;

  MapPointModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.userId,
  });

  factory MapPointModel.fromJson(Map<String, dynamic> json) {
    return MapPointModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Location',
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : 0.0,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : 0.0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      userId: json['user_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
    };
  }

  MapPointEntity toEntity() {
    return MapPointEntity(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      createdAt: createdAt,
      userId: userId,
    );
  }
}