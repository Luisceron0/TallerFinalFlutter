import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/game_controller.dart';
import '../controllers/auth_controller.dart';
import 'game_detail_page.dart';


class GameSearchPage extends StatefulWidget {
  const GameSearchPage({super.key});

  @override
  State<GameSearchPage> createState() => _GameSearchPageState();
}

class _GameSearchPageState extends State<GameSearchPage> {
  final GameController _gameController = Get.put(GameController());
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _searchController = TextEditingController();
  final SupabaseClient _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _gameController.loadPopularGames();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.trim().isNotEmpty) {
      final user = _client.auth.currentUser;
      _gameController.searchGames(
        query,
        userId: user?.id,
      );
    } else {
      _gameController.clearSearchResults();
    }
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
                            'Buscar Juegos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48), // Balance back button
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar juegos...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.primaryPurple,
                          ),
                          suffixIcon: Obx(() => _gameController.isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(14),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primaryPurple,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: AppColors.primaryPurple,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _gameController.clearSearchResults();
                                  },
                                )),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        onSubmitted: _performSearch,
                        onChanged: (value) {
                          if (value.isEmpty) {
                            _gameController.clearSearchResults();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: Container(
                color: Colors.white,
                child: Obx(() {
                  if (_gameController.isLoading && _gameController.popularGames.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryNeon,
                      ),
                    );
                  }

                  final games = _gameController.searchResults.isNotEmpty
                      ? _gameController.searchResults
                      : _gameController.popularGames;

                  if (games.isEmpty && !_gameController.isSearching) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _gameController.searchResults.isEmpty && _searchController.text.isNotEmpty
                                ? Icons.search_off
                                : Icons.games,
                            size: 64,
                            color: AppColors.secondaryText,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _gameController.searchResults.isEmpty && _searchController.text.isNotEmpty
                                ? 'No se encontraron juegos'
                                : 'Juegos populares',
                            style: const TextStyle(
                              fontSize: 18,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: games.length,
                    itemBuilder: (context, index) {
                      final game = games[index];
                      return _GameCard(
                        game: game,
                        onTap: () => Get.to(() => GameDetailPage(game: game)),
                      );
                    },
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final dynamic game;
  final VoidCallback onTap;

  const _GameCard({
    required this.game,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryNeon.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Game image placeholder
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                image: game.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(game.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: game.imageUrl == null
                  ? const Icon(
                      Icons.gamepad,
                      color: AppColors.primaryNeon,
                      size: 30,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Game info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (game.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      game.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.primaryNeon,
            ),
          ],
        ),
      ),
    );
  }
}
