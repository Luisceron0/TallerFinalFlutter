import 'package:dio/dio.dart';
import '../../core/config/scraper_config.dart';
import '../../domain/entities/game_entity.dart';
import '../models/game_model.dart';

class ScraperApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ScraperConfig.scraperApiUrl,
      connectTimeout: Duration(seconds: ScraperConfig.searchTimeout),
      receiveTimeout: Duration(seconds: ScraperConfig.searchTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  ScraperApiService() {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('🌐 API Request: ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('✅ API Response: ${response.statusCode}');
          return handler.next(response);
        },
        onError: (error, handler) {
          print('❌ API Error: ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  /// Buscar juegos por query
  Future<List<GameEntity>> searchGames(String query, {String? userId}) async {
    try {
      final response = await _dio.post(
        '/api/search',
        data: {
          'query': query,
          if (userId != null) 'user_id': userId,
        },
      );

      final results = response.data['results'] as List;
      return results
          .map((json) => GameModel.fromJson(json).toEntity())
          .toList();
    } catch (e) {
      throw Exception('Error searching games: $e');
    }
  }

  /// Actualizar precios de wishlist
  Future<Map<String, dynamic>> refreshWishlistPrices({
    required String userId,
    required List<String> gameIds,
  }) async {
    try {
      final response = await _dio.post(
        '/api/refresh-wishlist',
        data: {
          'user_id': userId,
          'game_ids': gameIds,
        },
        options: Options(
          receiveTimeout: Duration(seconds: ScraperConfig.refreshTimeout),
        ),
      );

      return response.data;
    } catch (e) {
      throw Exception('Error refreshing wishlist: $e');
    }
  }

  /// Health check del scraper
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
