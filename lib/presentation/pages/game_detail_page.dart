import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/game_controller.dart';
// auth_controller import not required in this page
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/gemini_ai_service.dart';
import '../../data/services/scraper_api_service.dart';
import '../../core/config/scraper_config.dart';
import 'dart:convert';

class GameDetailPage extends StatefulWidget {
  final dynamic game;

  const GameDetailPage({super.key, required this.game});

  @override
  State<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends State<GameDetailPage> {
  final GameController _gameController = Get.find<GameController>();
  // AuthController removed (not used here) to avoid unused-field warnings
  final SupabaseClient _client = Supabase.instance.client;

  bool _isInWishlist = false;
  bool _isLoadingWishlist = false;
  bool _isAnalyzingPurchase = false;
  bool _isLoadingGame = true;
  Map<String, dynamic>? _purchaseAnalysis;
  dynamic _gameData;

  @override
  void initState() {
    super.initState();
    _loadGameData();
    _checkWishlistStatus();
  }

  Future<void> _loadGameData() async {
    setState(() => _isLoadingGame = true);
    try {
      // Always fetch fresh game data with prices from repository
      final gameData = await _gameController.getGameDetails(widget.game.id);
      if (gameData != null && mounted) {
        // If repository returned a game but it has no prices, try scraper as fallback
        final hasPrices =
            (gameData.prices != null && (gameData.prices as Map).isNotEmpty);
        if (!hasPrices) {
          print(
            'GameDetailPage: repository returned game without prices, trying scraper fallback for ${widget.game.title}',
          );
          await _fetchPricesFromScraper();

          // If scraper found a richer result it sets _gameData; otherwise keep repository result
          if (_gameData == null) {
            if (mounted) {
              setState(() {
                _gameData = gameData;
              });
            }
            // If widget got removed while awaiting scraper, avoid further work
            if (!mounted) return;
            // Try to fetch Steam price as last resort
            await _fetchSteamPriceAndUpdate();
          }
        } else {
          if (mounted) {
            setState(() {
              _gameData = gameData;
            });
          }
          if (!mounted) return;
          // Enrich with Steam API if needed
          await _fetchSteamPriceAndUpdate();
        }
      } else {
        // If no data from repository, try to fetch from scraper API directly
        await _fetchPricesFromScraper();
      }
    } catch (e) {
      print('Error loading game data: $e');
      // Try to fetch prices from scraper API as fallback
      await _fetchPricesFromScraper();
    } finally {
      if (mounted) setState(() => _isLoadingGame = false);
    }
  }

  Future<void> _fetchPricesFromScraper() async {
    try {
      // Try to get prices directly from scraper API
      ScraperApiService scraperService;
      try {
        scraperService = Get.find<ScraperApiService>();
      } catch (_) {
        // If not registered in GetX, create and register a local instance
        scraperService = ScraperApiService();
        try {
          Get.put<ScraperApiService>(scraperService);
        } catch (_) {}
      }

      final searchResults = await scraperService.searchGames(widget.game.title);

      if (searchResults.isNotEmpty) {
        final matchingGame = searchResults.firstWhere(
          (game) =>
              game.title.toLowerCase().contains(
                widget.game.title.toLowerCase(),
              ) ||
              widget.game.title.toLowerCase().contains(
                game.title.toLowerCase(),
              ),
          orElse: () => searchResults.first,
        );

        // Always set matching game, we'll try to enrich if prices are missing
        if (mounted) {
          setState(() {
            _gameData = matchingGame;
          });
        }
        // If widget disposed while awaiting, stop
        if (!mounted) return;
        // Try to enrich with Steam API price if available
        await _fetchSteamPriceAndUpdate();
      }
    } catch (e) {
      print('Error fetching prices from scraper: $e');
    }
  }

  /// Try to fetch Steam price using Steam store API if we have steamAppId
  Future<void> _fetchSteamPriceAndUpdate() async {
    try {
      final steamId = (_gameData?.steamAppId ?? widget.game.steamAppId)
          ?.toString();
      if (steamId == null || steamId.isEmpty) return;

      if (kIsWeb) {
        // Direct Steam API calls are blocked by CORS on web. Use scraper backend instead.
        try {
          ScraperApiService scraperService;
          try {
            scraperService = Get.find<ScraperApiService>();
          } catch (_) {
            scraperService = ScraperApiService();
            try {
              Get.put<ScraperApiService>(scraperService);
            } catch (_) {}
          }

          final results = await scraperService.searchGames(widget.game.title);
          if (results.isNotEmpty) {
            final match = results.first;
            if (match.prices != null && match.prices!.isNotEmpty) {
              final src = match.prices as Map<String, dynamic>;
              if (mounted) {
                setState(() {
                  // merge into _gameData
                  try {
                    final base = (_gameData ?? widget.game) as dynamic;
                    final updated = base.copyWith(prices: src);
                    _gameData = updated;
                  } catch (_) {
                    _gameData =
                        {...(_gameData ?? widget.game), 'prices': src}
                            as dynamic;
                  }
                });
              }
            }
          }
        } catch (e) {
          print('Error fetching Steam price via scraper backend: $e');
        }
        return;
      }

      // Not web: call Steam API directly
      final dio = Dio();
      final resp = await dio.get(
        'https://store.steampowered.com/api/appdetails',
        queryParameters: {'appids': steamId, 'cc': 'es', 'l': 'es'},
      );

      if (resp.statusCode == 200 && resp.data != null) {
        final map = resp.data as Map<String, dynamic>;
        final appData = map[steamId];
        if (appData != null && appData['success'] == true) {
          final details = appData['data'] as Map<String, dynamic>?;
          if (details != null) {
            // price_overview may be null for free games
            final priceOverview =
                details['price_overview'] as Map<String, dynamic>?;
            double? price;
            int discount = 0;
            bool isFree = false;

            if (priceOverview != null) {
              final finalPrice = priceOverview['final'];
              if (finalPrice is num) {
                price = finalPrice.toDouble() / 100.0;
              } else if (finalPrice is String) {
                price = double.tryParse(finalPrice) ?? null;
              }
              discount = priceOverview['discount_percent'] is int
                  ? priceOverview['discount_percent'] as int
                  : (int.tryParse('${priceOverview['discount_percent']}') ?? 0);
            } else {
              // check if game is free
              final is_free = details['is_free'] as bool? ?? false;
              isFree = is_free;
            }

            // Merge into existing prices map
            Map<String, dynamic> existingPrices = {};
            try {
              final src =
                  (_gameData?.prices ?? widget.game.prices)
                      as Map<String, dynamic>?;
              if (src != null) existingPrices.addAll(src);
            } catch (_) {}

            existingPrices['steam'] = {
              'price': price,
              'discount_percent': discount,
              'is_free': isFree,
              'url': 'https://store.steampowered.com/app/$steamId',
            };

            // Update _gameData using copyWith if available
            try {
              final base = (_gameData ?? widget.game) as dynamic;
              final updated = base.copyWith(prices: existingPrices);
              if (mounted) {
                setState(() {
                  _gameData = updated;
                });
              }
            } catch (e) {
              // Fallback: if copyWith not available, try wrapping minimal data
              if (mounted) {
                setState(() {
                  _gameData =
                      {...(_gameData ?? widget.game), 'prices': existingPrices}
                          as dynamic;
                });
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching Steam price: $e');
    }
  }

  Future<void> _checkWishlistStatus() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        await _client
            .from('wishlist')
            .select()
            .eq('user_id', user.id)
            .eq('game_id', widget.game.id)
            .single();

  if (mounted) setState(() => _isInWishlist = true);
      }
    } catch (e) {
  // Game not in wishlist
  if (mounted) setState(() => _isInWishlist = false);
    }
  }

  Widget _buildPriceComparison() {
    // Use fresh game data if available, otherwise fallback to widget.game
    final game = _gameData ?? widget.game;
    // Normalize incoming prices structure: accept Map, List, nested lists, and different casing
    dynamic rawPrices = game.prices;

    Map<String, dynamic> prices = {};

    try {
      if (rawPrices == null) {
        prices = {};
      } else if (rawPrices is Map<String, dynamic>) {
        // Normalize keys to lowercase for matching
        rawPrices.forEach((k, v) {
          final key = k.toString().toLowerCase();
          if (v is List && v.isNotEmpty) {
            // take last entry
            prices[key] = v.last is Map ? v.last : {'price': v.last};
          } else if (v is Map) {
            prices[key] = v;
          } else {
            // primitive value (e.g., price directly)
            prices[key] = {'price': v};
          }
        });
      } else if (rawPrices is List) {
        for (final entry in rawPrices) {
          if (entry is Map && entry['store'] != null) {
            final key = entry['store'].toString().toLowerCase();
            prices[key] = entry;
          }
        }
      } else {
        // Unknown format
        prices = {};
      }
    } catch (e) {
      print('Error normalizing prices for ${game.id ?? game.title}: $e');
      prices = {};
    }

    if (prices.isEmpty) {
      print(
        'GameDetailPage: precios no disponibles para juego="${game.title}" id=${game.id} rawPrices=${game.prices}',
      );

      final encodedTitle = Uri.encodeComponent(game.title ?? '');
      final steamSearch =
          'https://store.steampowered.com/search/?term=$encodedTitle';
      final epicSearch =
          'https://www.epicgames.com/store/en-US/search?q=$encodedTitle';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.lightPurple,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.store, color: AppColors.primaryPurple, size: 32),
            const SizedBox(height: 8),
            const Text(
              'Precios no disponibles',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(steamSearch);
                    if (await canLaunchUrl(uri))
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                  },
                  icon: const Icon(Icons.store, size: 18),
                  label: const Text('Buscar en Steam'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(epicSearch);
                    if (await canLaunchUrl(uri))
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                  },
                  icon: const Icon(Icons.shopping_cart, size: 18),
                  label: const Text('Buscar en Epic'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Extract prices (accept keys like 'steam', 'steam_store', 'epic')
    dynamic steamPrice;
    dynamic epicPrice;
    // find best matching keys
    for (final k in prices.keys) {
      if (k.contains('steam')) steamPrice = prices[k];
      if (k.contains('epic')) epicPrice = prices[k];
    }

    // Collect all available prices
    List<Map<String, dynamic>> availablePrices = [];

    if (steamPrice != null &&
        steamPrice is Map &&
        (steamPrice['price'] != null || steamPrice['price'] != null) &&
        !(steamPrice['is_free'] == true)) {
      availablePrices.add({
        'store': 'Steam',
        'price': steamPrice['price'],
        'url':
            steamPrice['url'] ?? steamPrice['link'] ?? steamPrice['url_link'],
        'discount_percent': steamPrice['discount_percent'] ?? 0,
      });
    }

    if (epicPrice != null &&
        epicPrice is Map &&
        (epicPrice['price'] != null || epicPrice['price'] != null) &&
        !(epicPrice['is_free'] == true)) {
      availablePrices.add({
        'store': 'Epic',
        'price': epicPrice['price'],
        'url': epicPrice['url'] ?? epicPrice['link'] ?? epicPrice['url_link'],
        'discount_percent': epicPrice['discount_percent'] ?? 0,
      });
    }

    // If no paid prices, show free message
    if (availablePrices.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: const Column(
          children: [
            Icon(Icons.card_giftcard, color: Colors.green, size: 32),
            SizedBox(height: 8),
            Text(
              'Juego gratuito',
              style: TextStyle(
                fontSize: 16,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Price cards
        ...availablePrices.map(
          (priceData) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            child: _buildPriceCard(priceData),
          ),
        ),

        // Show availability message if only one store
        if (availablePrices.length == 1) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondaryText.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.secondaryText,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Disponible solo en ${availablePrices[0]['store']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPriceCard(Map<String, dynamic> priceData) {
    final store = priceData['store'];
    final price = priceData['price'];
    final url = priceData['url'];
    final discountPercent = priceData['discount_percent'] ?? 0;

    return ElevatedButton(
      onPressed: () async {
        if (url != null && url.isNotEmpty) {
          final Uri uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            Get.snackbar('Error', 'No se pudo abrir la URL');
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surfaceColor,
        foregroundColor: AppColors.primaryText,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: Row(
        children: [
          // Store icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: store == 'Steam'
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              store == 'Steam' ? Icons.sports_esports : Icons.store,
              color: store == 'Steam' ? Colors.blue : Colors.purple,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Price info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    // Safely format price if numeric, otherwise show 'N/D'
                    String priceText;
                    if (price is num) {
                      priceText = '\$${price.toDouble().toStringAsFixed(2)}';
                    } else if (price is String) {
                      final parsed = double.tryParse(
                        price.replaceAll(',', '.'),
                      );
                      priceText = parsed != null
                          ? '\$${parsed.toStringAsFixed(2)}'
                          : 'N/D';
                    } else {
                      priceText = 'N/D';
                    }

                    return Text(
                      priceText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryPurple,
                      ),
                    );
                  },
                ),
                if (discountPercent > 0) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '-${discountPercent}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Arrow icon
          const Icon(
            Icons.arrow_forward_ios,
            color: AppColors.primaryPurple,
            size: 16,
          ),
        ],
      ),
    );
  }

  Future<void> _toggleWishlist() async {
    if (_isLoadingWishlist) return;

  setState(() => _isLoadingWishlist = true);

    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        Get.snackbar('Error', 'Debes iniciar sesión para usar la wishlist');
        return;
      }

      if (_isInWishlist) {
        // Remove from wishlist using controller
        await _gameController.removeFromWishlist(
          userId: user.id,
          gameId: widget.game.id,
        );

  if (mounted) setState(() => _isInWishlist = false);
      } else {
        // Add to wishlist using controller
        await _gameController.addToWishlist(
          userId: user.id,
          gameId: widget.game.id,
          targetPrice: null,
        );

  if (mounted) setState(() => _isInWishlist = true);
      }
    } catch (e) {
      Get.snackbar('Error', 'No se pudo actualizar la wishlist: $e');
    } finally {
      if (mounted) setState(() => _isLoadingWishlist = false);
    }
  }

  Future<void> _analyzePurchaseDecision() async {
    if (_isAnalyzingPurchase) return;

    setState(() => _isAnalyzingPurchase = true);

    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        Get.snackbar('Error', 'Debes iniciar sesión para analizar compras');
        return;
      }

      final analysis = await Get.find<GeminiAIService>()
          .analyzePurchaseDecision(
            gameTitle: widget.game.title,
            steamPrice: widget.game.prices?['steam']?['price'],
            epicPrice: widget.game.prices?['epic']?['price'],
            userId: user.id,
          );

      if (mounted) setState(() => _purchaseAnalysis = analysis);
      Get.snackbar('Éxito', 'Análisis de compra completado');
    } catch (e) {
      Get.snackbar('Error', 'No se pudo analizar la compra: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzingPurchase = false);
    }
  }

  Color _getRecommendationColor(String recommendation) {
    switch (recommendation.toUpperCase()) {
      case 'BUY_NOW':
        return Colors.green;
      case 'WAIT_FOR_SALE':
        return Colors.orange;
      case 'AVOID':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getRecommendationText(String recommendation) {
    switch (recommendation.toUpperCase()) {
      case 'BUY_NOW':
        return 'Comprar Ahora';
      case 'WAIT_FOR_SALE':
        return 'Esperar Oferta';
      case 'AVOID':
        return 'Evitar';
      default:
        return 'Sin Recomendación';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use fresh game data if available, otherwise fallback to widget.game
    final game = _gameData ?? widget.game;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and wishlist toggle
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
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () => Get.back(),
                    ),
                    Expanded(
                      child: Text(
                        game.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isInWishlist ? Icons.favorite : Icons.favorite_border,
                        color: _isInWishlist ? Colors.red : Colors.white,
                        size: 28,
                      ),
                      onPressed: _isLoadingWishlist ? null : _toggleWishlist,
                    ),
                  ],
                ),
              ),
            ),

            // Game details content
            Expanded(
              child: Container(
                color: Colors.white,
                child: _isLoadingGame
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryPurple,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Game image
                            Center(
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceColor,
                                  borderRadius: BorderRadius.circular(16),
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
                                        size: 80,
                                      )
                                    : null,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Game title
                            Text(
                              game.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Description
                            if (game.description != null) ...[
                              const Text(
                                'Descripción',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                game.description!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.secondaryText,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Price comparison section
                            const Text(
                              'Precios',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Enhanced price comparison
                            _buildPriceComparison(),

                            // Debug: show raw prices when in debug mode to help diagnose missing prices
                            if (ScraperConfig.isDebugMode) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    'RAW prices: ' +
                                        (game.prices != null
                                            ? const JsonEncoder.withIndent(
                                                '  ',
                                              ).convert(game.prices)
                                            : 'null'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (ScraperConfig.isDebugMode) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    'steamAppId: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                  Text(
                                    game.steamAppId?.toString() ?? 'null',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'epicSlug: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                  Text(
                                    game.epicSlug?.toString() ?? 'null',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 16),

                            // AI Insight section
                            if (game.aiInsight != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryNeon.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primaryNeon.withOpacity(
                                      0.3,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.lightbulb,
                                          color: AppColors.primaryNeon,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Insight IA',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      game.aiInsight!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.secondaryText,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            const SizedBox(height: 24),

                            // AI Purchase Analysis section
                            if (_purchaseAnalysis != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primaryPurple.withOpacity(
                                      0.3,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.analytics,
                                          color: AppColors.primaryPurple,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Análisis de Compra IA',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Recommendation
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getRecommendationColor(
                                          _purchaseAnalysis!['analysis']['recommendation'],
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _getRecommendationText(
                                          _purchaseAnalysis!['analysis']['recommendation'],
                                        ),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _getRecommendationColor(
                                            _purchaseAnalysis!['analysis']['recommendation'],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Summary
                                    Text(
                                      _purchaseAnalysis!['analysis']['summary'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.secondaryText,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Key factors
                                    if (_purchaseAnalysis!['analysis']['key_factors'] !=
                                        null) ...[
                                      const Text(
                                        'Factores clave:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ...(_purchaseAnalysis!['analysis']['key_factors']
                                              as List<dynamic>)
                                          .map(
                                            (factor) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    '• ',
                                                    style: TextStyle(
                                                      color: AppColors
                                                          .secondaryText,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      factor.toString(),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .secondaryText,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isAnalyzingPurchase
                                        ? null
                                        : _analyzePurchaseDecision,
                                    icon: _isAnalyzingPurchase
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.analytics),
                                    label: Text(
                                      _isAnalyzingPurchase
                                          ? 'Analizando...'
                                          : 'Analizar Compra',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      // TODO: Implement sharing
                                      Get.snackbar(
                                        'Próximamente',
                                        'Compartir próximamente',
                                      );
                                    },
                                    icon: const Icon(Icons.share),
                                    label: const Text('Compartir'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryPurple,
                                      side: const BorderSide(
                                        color: AppColors.primaryPurple,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
