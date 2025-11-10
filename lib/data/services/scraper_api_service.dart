import 'package:dio/dio.dart';
import '../../core/config/scraper_config.dart';
import '../../core/config/app_config.dart';

import '../../domain/entities/game_entity.dart';
import '../models/game_model.dart';
import '../../services/gemini_ai_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScraperApiService {
  late final Dio _dio;
  GeminiAIService? _aiService;

  ScraperApiService({GeminiAIService? aiService}) {
    // Initialize AI service if API key is available
    if (AppConfig.geminiApiKey != null) {
      _aiService = aiService ?? GeminiAIService(AppConfig.geminiApiKey!);
    }
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

  /// Analizar decisión de compra con IA
  Future<Map<String, dynamic>> analyzePurchaseDecision({
    required String gameId,
    required String userId,
  }) async {
    // Si tenemos IA local, usarla directamente
    if (_aiService != null) {
      try {
        // Obtener datos del juego desde Supabase
        final gameData = await _getGameData(gameId);

        return await _aiService!.analyzePurchaseDecision(
              gameTitle: gameData['title'],
              steamPrice: gameData['steam_price'],
              epicPrice: gameData['epic_price'],
              userId: userId,
            ) ??
            _getFallbackAnalysis();
      } catch (e) {
        print('Error usando IA local, intentando API externa: $e');
        // Fallback: llamar a API externa si es necesario
        return await _callExternalApi(gameId, userId);
      }
    }

    // Fallback: llamar a API externa si no hay IA local
    return await _callExternalApi(gameId, userId);
  }

  Future<Map<String, dynamic>> _getGameData(String gameId) async {
    try {
      // Consultar directamente desde Supabase en lugar del endpoint inexistente
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('games')
          .select(
            'title, price_history(price, store, discount_percent, is_free)',
          )
          .eq('id', gameId)
          .single();

      final priceHistory = response['price_history'] as List<dynamic>? ?? [];
      double? steamPrice;
      double? epicPrice;

      for (var price in priceHistory) {
        if (price['store'] == 'steam' && !price['is_free']) {
          steamPrice = (price['price'] as num).toDouble();
        } else if (price['store'] == 'epic' && !price['is_free']) {
          epicPrice = (price['price'] as num).toDouble();
        }
      }

      return {
        'title': response['title'] ?? 'Unknown Game',
        'steam_price': steamPrice,
        'epic_price': epicPrice,
      };
    } catch (e) {
      // Si falla la consulta, devolver datos básicos
      return {'title': 'Unknown Game', 'steam_price': null, 'epic_price': null};
    }
  }

  Future<Map<String, dynamic>> _callExternalApi(
    String gameId,
    String userId,
  ) async {
    try {
      final response = await _dio.post(
        '/api/analyze-purchase',
        data: {'game_id': gameId, 'user_id': userId},
      );

      return response.data;
    } catch (e) {
      throw Exception('Error analyzing purchase decision: $e');
    }
  }

  Map<String, dynamic> _getFallbackAnalysis() {
    return {
      'analysis': {
        'recommendation': 'CONSIDER',
        'confidence': 50,
        'summary': 'Análisis no disponible. Verifica precios manualmente.',
        'key_factors': [
          'Precio no determinado',
          'Compara con ofertas similares',
        ],
      },
    };
  }
}
