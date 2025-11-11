import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/scraper_config.dart';

import '../../domain/entities/game_entity.dart';
import '../models/game_model.dart';

class ScraperApiService {
  late final Dio _dio;

  ScraperApiService() {
    _initializeDio();
  }

  void _initializeDio() {
    try {
      _dio = Dio(
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
      _setupInterceptors();
    } catch (e) {
      // If SCRAPER_API_URL is not configured, create Dio without baseUrl
      // This will cause requests to fail gracefully
      _dio = Dio(
        BaseOptions(
          connectTimeout: Duration(seconds: ScraperConfig.searchTimeout),
          receiveTimeout: Duration(seconds: ScraperConfig.searchTimeout),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      _setupInterceptors();
    }
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
        data: {'query': query, if (userId != null) 'user_id': userId},
      );

      // Debug: print full payload when in debug mode to diagnose missing Epic data
      try {
        if (ScraperConfig.isDebugMode) {
          print('Scraper API raw response: ${response.data}');
        }
      } catch (_) {}

      // Support multiple response shapes: { results: [...] } or direct list
      List resultsList = [];
      if (response.data is Map && response.data['results'] is List) {
        resultsList = response.data['results'] as List;
      } else if (response.data is List) {
        resultsList = response.data as List;
      } else if (response.data is Map && response.data['data'] is List) {
        // some APIs wrap under 'data'
        resultsList = response.data['data'] as List;
      } else {
        // unknown shape - try to coerce
        try {
          resultsList = List.from(response.data as Iterable);
        } catch (_) {
          resultsList = [];
        }
      }

      return resultsList
          .map(
            (json) =>
                GameModel.fromJson(json as Map<String, dynamic>).toEntity(),
          )
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
        data: {'user_id': userId, 'game_ids': gameIds},
        options: Options(
          receiveTimeout: Duration(seconds: ScraperConfig.refreshTimeout),
        ),
      );

      return response.data;
    } catch (e) {
      throw Exception('Error refreshing wishlist: $e');
    }
  }

  /// Agregar juego a wishlist
  Future<Map<String, dynamic>> addToWishlist({
    required String userId,
    required String gameId,
    double? targetPrice,
  }) async {
    try {
      final response = await _dio.post(
        '/api/wishlist/add',
        data: {
          'user_id': userId,
          'game_id': gameId,
          if (targetPrice != null) 'target_price': targetPrice,
        },
      );

      return response.data;
    } catch (e) {
      throw Exception('Error adding to wishlist: $e');
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
