import '../../domain/entities/game_entity.dart';

abstract class GameRepository {
  /// Buscar juegos por query usando la API del scraper
  Future<List<GameEntity>> searchGames(String query, {String? userId});

  /// Obtener juegos populares (últimos buscados)
  Future<List<GameEntity>> getPopularGames();

  /// Obtener detalles completos de un juego
  Future<GameEntity> getGameDetails(String gameId);

  /// Actualizar precios de juegos en wishlist
  Future<void> refreshWishlistPrices({
    required String userId,
    required List<String> gameIds,
  });

  /// Agregar juego a wishlist
  Future<void> addToWishlist({
    required String userId,
    required String gameId,
    double? targetPrice,
  });
}
