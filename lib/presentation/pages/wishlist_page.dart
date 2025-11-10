import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/game_controller.dart';

import '../../data/models/game_model.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final AuthController _authController = Get.find<AuthController>();
  final GameController _gameController = Get.find<GameController>();
  final SupabaseClient _client = Supabase.instance.client;

  List<Map<String, dynamic>> _wishlistItems = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    try {
      setState(() => _isLoading = true);

      final user = _client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get wishlist items with game details and latest prices
      final response = await _client
          .from('wishlist')
          .select('''
            *,
            games (
              id,
              title,
              image_url,
              description,
              steam_app_id,
              epic_slug,
              price_history (
                price,
                store,
                discount_percent,
                is_free,
                scraped_at
              )
            )
          ''')
          .eq('user_id', user.id)
          .order('added_at', ascending: false);

      setState(() {
        _wishlistItems = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading wishlist: $e');
      setState(() => _isLoading = false);
      Get.snackbar('Error', 'No se pudo cargar la wishlist');
    }
  }

  Future<void> _refreshPrices() async {
    if (_isRefreshing) return;

    try {
      setState(() => _isRefreshing = true);

      final user = _client.auth.currentUser;
      if (user == null) return;

      final gameIds = _wishlistItems
          .map((item) => item['game_id'] as String)
          .toList();

      if (gameIds.isEmpty) {
        setState(() => _isRefreshing = false);
        return;
      }

      // Refresh prices via API
      await _gameController.refreshWishlistPrices(
        userId: user.id,
        gameIds: gameIds,
      );

      // Reload wishlist to get updated prices
      await _loadWishlist();

      Get.snackbar('Éxito', 'Precios actualizados');
    } catch (e) {
      Get.snackbar('Error', 'No se pudieron actualizar los precios');
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _removeFromWishlist(String gameId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _gameController.removeFromWishlist(userId: user.id, gameId: gameId);

      // Remove from local list
      setState(() {
        _wishlistItems.removeWhere((item) => item['game_id'] == gameId);
      });

      Get.snackbar('Éxito', 'Juego removido de la wishlist');
    } catch (e) {
      Get.snackbar('Error', 'No se pudo remover el juego');
    }
  }

  Widget _buildPriceInfo(Map<String, dynamic> gameData) {
    final priceHistory = gameData['price_history'] as List<dynamic>? ?? [];

    if (priceHistory.isEmpty) {
      return const Text(
        'Precio no disponible',
        style: TextStyle(fontSize: 14, color: AppColors.secondaryText),
      );
    }

    // Get latest prices for each store
    final steamPrice = priceHistory
        .where((p) => p['store'] == 'steam')
        .toList()
        .lastOrNull;

    final epicPrice = priceHistory
        .where((p) => p['store'] == 'epic')
        .toList()
        .lastOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (steamPrice != null && !steamPrice['is_free']) ...[
          Row(
            children: [
              Icon(Icons.sports_esports, size: 16, color: Colors.blue),
              const SizedBox(width: 4),
              Text(
                'Steam: €${steamPrice['price'].toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryText,
                ),
              ),
              if (steamPrice['discount_percent'] > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-${steamPrice['discount_percent']}%',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (epicPrice != null && !epicPrice['is_free']) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.store, size: 16, color: Colors.purple),
              const SizedBox(width: 4),
              Text(
                'Epic: €${epicPrice['price'].toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryText,
                ),
              ),
              if (epicPrice['discount_percent'] > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-${epicPrice['discount_percent']}%',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
        if ((steamPrice == null || steamPrice['is_free']) &&
            (epicPrice == null || epicPrice['is_free'])) ...[
          const Text(
            'Gratis',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.green,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Back button and title
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 22,
                          ),
                          onPressed: () => Get.back(),
                        ),
                        const Expanded(
                          child: Text(
                            'Mi Wishlist',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // Refresh button
                        IconButton(
                          icon: Icon(
                            _isRefreshing
                                ? Icons.refresh
                                : Icons.refresh_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: _isRefreshing ? null : _refreshPrices,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: Container(
                color: Colors.white,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryPurple,
                          ),
                        ),
                      )
                    : _wishlistItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.favorite_border,
                              size: 64,
                              color: AppColors.secondaryText,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tu wishlist está vacía',
                              style: const TextStyle(
                                fontSize: 18,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Agrega juegos desde la búsqueda',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.tertiaryText,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadWishlist,
                        color: AppColors.primaryPurple,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _wishlistItems.length,
                          itemBuilder: (context, index) {
                            final item = _wishlistItems[index];
                            final game = item['games'] as Map<String, dynamic>?;

                            if (game == null) return const SizedBox.shrink();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () {
                                  // Navigate to game detail page
                                  final gameEntity = GameModel.fromJson(
                                    game,
                                  ).toEntity();
                                  Get.toNamed(
                                    '/game-detail',
                                    arguments: gameEntity,
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Game image
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          image: game['image_url'] != null
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                    game['image_url'],
                                                  ),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                          color: AppColors.surfaceColor,
                                        ),
                                        child: game['image_url'] == null
                                            ? const Icon(
                                                Icons.gamepad,
                                                color: AppColors.primaryNeon,
                                                size: 30,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),

                                      // Game info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              game['title'] ?? 'Sin título',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryText,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            _buildPriceInfo(game),
                                            if (item['target_price'] !=
                                                null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Precio objetivo: €${item['target_price'].toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.secondaryText,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Remove button
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _removeFromWishlist(
                                          item['game_id'],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
