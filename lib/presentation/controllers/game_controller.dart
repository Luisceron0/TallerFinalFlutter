import 'package:get/get.dart';
import '../../domain/entities/game_entity.dart';
import '../../domain/repositories/game_repository.dart';
import '../../data/repositories/game_repository_impl.dart';

class GameController extends GetxController {
  final GameRepository _gameRepository = GameRepositoryImpl();

  // Observable variables
  final RxList<GameEntity> _searchResults = <GameEntity>[].obs;
  final RxList<GameEntity> _popularGames = <GameEntity>[].obs;
  final RxBool _isLoading = false.obs;
  final RxBool _isSearching = false.obs;
  final RxString _errorMessage = ''.obs;

  // Getters
  List<GameEntity> get searchResults => _searchResults;
  List<GameEntity> get popularGames => _popularGames;
  bool get isLoading => _isLoading.value;
  bool get isSearching => _isSearching.value;
  String get errorMessage => _errorMessage.value;

  @override
  void onInit() {
    super.onInit();
    loadPopularGames();
  }

  /// Cargar juegos populares
  Future<void> loadPopularGames() async {
    try {
      _isLoading.value = true;
      _errorMessage.value = '';

      final games = await _gameRepository.getPopularGames();
      _popularGames.assignAll(games);
    } catch (e) {
      _errorMessage.value = 'Error loading popular games: $e';
      Get.snackbar('Error', _errorMessage.value);
    } finally {
      _isLoading.value = false;
    }
  }

  /// Buscar juegos
  Future<void> searchGames(String query, {String? userId}) async {
    if (query.trim().isEmpty) {
      _searchResults.clear();
      return;
    }

    try {
      _isSearching.value = true;
      _errorMessage.value = '';

      final results = await _gameRepository.searchGames(query, userId: userId);
      _searchResults.assignAll(results);
    } catch (e) {
      _errorMessage.value = 'Error searching games: $e';
      Get.snackbar('Error', _errorMessage.value);
    } finally {
      _isSearching.value = false;
    }
  }

  /// Limpiar resultados de búsqueda
  void clearSearchResults() {
    _searchResults.clear();
    _errorMessage.value = '';
  }

  /// Actualizar precios de wishlist
  Future<void> refreshWishlistPrices({
    required String userId,
    required List<String> gameIds,
  }) async {
    try {
      _isLoading.value = true;
      _errorMessage.value = '';

      await _gameRepository.refreshWishlistPrices(
        userId: userId,
        gameIds: gameIds,
      );

      Get.snackbar('Success', 'Wishlist prices updated successfully');
    } catch (e) {
      _errorMessage.value = 'Error refreshing prices: $e';
      Get.snackbar('Error', _errorMessage.value);
    } finally {
      _isLoading.value = false;
    }
  }

  /// Obtener detalles de un juego específico
  Future<GameEntity?> getGameDetails(String gameId) async {
    try {
      return await _gameRepository.getGameDetails(gameId);
    } catch (e) {
      _errorMessage.value = 'Error getting game details: $e';
      Get.snackbar('Error', _errorMessage.value);
      return null;
    }
  }
}
