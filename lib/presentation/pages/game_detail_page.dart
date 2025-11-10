import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/game_controller.dart';
import '../controllers/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/gemini_ai_service.dart';

class GameDetailPage extends StatefulWidget {
  final dynamic game;

  const GameDetailPage({super.key, required this.game});

  @override
  State<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends State<GameDetailPage> {
  final GameController _gameController = Get.find<GameController>();
  final AuthController _authController = Get.find<AuthController>();
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
        setState(() {
          _gameData = gameData;
        });
      }
    } catch (e) {
      print('Error loading game data: $e');
    } finally {
      setState(() => _isLoadingGame = false);
    }
  }

  Future<void> _checkWishlistStatus() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        final response = await _client
            .from('wishlist')
            .select()
            .eq('user_id', user.id)
            .eq('game_id', widget.game.id)
            .single();

        setState(() => _isInWishlist = true);
      }
    } catch (e) {
      // Game not in wishlist
      setState(() => _isInWishlist = false);
    }
  }

  Widget _buildPriceComparison() {
    // Use fresh game data if available, otherwise fallback to widget.game
    final game = _gameData ?? widget.game;
    final prices = game.prices ?? {};

    if (prices.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.lightPurple,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
        ),
        child: const Column(
          children: [
            Icon(Icons.store, color: AppColors.primaryPurple, size: 32),
            SizedBox(height: 8),
            Text(
              'Precios no disponibles',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Extract prices
    final steamPrice = prices['steam'];
    final epicPrice = prices['epic'];

    // Collect all available prices
    List<Map<String, dynamic>> availablePrices = [];

    if (steamPrice != null &&
        steamPrice['price'] != null &&
        !steamPrice['is_free']) {
      availablePrices.add({
        'store': 'Steam',
        'price': steamPrice['price'],
        'url': steamPrice['url'],
        'discount_percent': steamPrice['discount_percent'] ?? 0,
      });
    }

    if (epicPrice != null &&
        epicPrice['price'] != null &&
        !epicPrice['is_free']) {
      availablePrices.add({
        'store': 'Epic',
        'price': epicPrice['price'],
        'url': epicPrice['url'],
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
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryPurple,
                  ),
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

        setState(() => _isInWishlist = false);
      } else {
        // Add to wishlist using controller
        await _gameController.addToWishlist(
          userId: user.id,
          gameId: widget.game.id,
          targetPrice: null,
        );

        setState(() => _isInWishlist = true);
      }
    } catch (e) {
      Get.snackbar('Error', 'No se pudo actualizar la wishlist: $e');
    } finally {
      setState(() => _isLoadingWishlist = false);
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

      setState(() => _purchaseAnalysis = analysis);
      Get.snackbar('Éxito', 'Análisis de compra completado');
    } catch (e) {
      Get.snackbar('Error', 'No se pudo analizar la compra: $e');
    } finally {
      setState(() => _isAnalyzingPurchase = false);
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
