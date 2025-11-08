import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/entities/game_entity.dart';
import '../../domain/repositories/game_repository.dart';
import '../models/game_model.dart';
import '../services/scraper_api_service.dart';

class GameRepositoryImpl implements GameRepository {
  final ScraperApiService _scraperApiService = ScraperApiService();
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<GameEntity>> searchGames(String query, {String? userId}) async {
    try {
      // Buscar en la API del scraper
      final games = await _scraperApiService.searchGames(query, userId: userId);

      // Guardar la búsqueda del usuario en Supabase (si hay userId)
      if (userId != null) {
        await _saveUserSearch(userId, query);
      }

      return games;
    } catch (e) {
      throw Exception('Error searching games: $e');
    }
  }

  @override
  Future<List<GameEntity>> getPopularGames() async {
    try {
      // Obtener juegos populares de las últimas búsquedas con precios
      final response = await _client
          .from('games')
          .select('*, price_history(*)')
          .order('created_at', ascending: false)
          .limit(20);

      return response
          .map<GameEntity>((json) => GameModel.fromJson(json).toEntity())
          .toList();
    } catch (e) {
      throw Exception('Error getting popular games: $e');
    }
  }

  @override
  Future<GameEntity> getGameDetails(String gameId) async {
    try {
      final response = await _client
          .from('games')
          .select('*, price_history(*)')
          .eq('id', gameId)
          .single();

      return GameModel.fromJson(response).toEntity();
    } catch (e) {
      throw Exception('Error getting game details: $e');
    }
  }

  @override
  Future<void> refreshWishlistPrices({
    required String userId,
    required List<String> gameIds,
  }) async {
    try {
      await _scraperApiService.refreshWishlistPrices(
        userId: userId,
        gameIds: gameIds,
      );
    } catch (e) {
      throw Exception('Error refreshing wishlist prices: $e');
    }
  }

  /// Guardar búsqueda del usuario para análisis de IA
  Future<void> _saveUserSearch(String userId, String query) async {
    try {
      await _client.from('user_searches').insert({
        'user_id': userId,
        'query': query,
        'searched_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // No fallar la búsqueda si no se puede guardar el log
      print('Warning: Could not save user search: $e');
    }
  }
}
