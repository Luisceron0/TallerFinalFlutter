import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/game_controller.dart';
import '../controllers/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _checkWishlistStatus();
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
    final prices = widget.game.prices ?? {};

    if (prices.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.lightPurple,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryPurple.withOpacity(0.3),
          ),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.store,
              color: AppColors.primaryPurple,
              size: 32,
            ),
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

    if (steamPrice != null && steamPrice['price'] != null && !steamPrice['is_free']) {
      availablePrices.add({
        'store': 'Steam',
        'price': steamPrice['price'],
        'url': steamPrice['url'],
        'discount_percent': steamPrice['discount_percent'] ?? 0,
      });
    }

    if (epicPrice != null && epicPrice['price'] != null && !epicPrice['is_free']) {
      availablePrices.add({
        'store': 'Epic',
        'price': epicPrice['price'],
        'url': epicPrice['url'],
        'discount_percent': epicPrice['discount_percent'] ?? 0,
      });
    }

    return Column(
      children: [
        // Price cards
        ...availablePrices.map((priceData) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          child: _buildPriceCard(priceData),
        )),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      child: Row(
        children: [
          // Store icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: store == 'Steam' ? Colors.blue.withOpacity(0.1) : Colors.purple.withOpacity(0.1),
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
                  '\$${price.toStringAsFixed(0)} COP',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryPurple,
                  ),
                ),
                if (discountPercent > 0) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        // Remove from wishlist
        await _client
            .from('wishlist')
            .delete()
            .eq('user_id', user.id)
            .eq('game_id', widget.game.id);

        setState(() => _isInWishlist = false);
        Get.snackbar('Removido', 'Juego removido de tu wishlist');
      } else {
        // Add to wishlist
        await _client.from('wishlist').insert({
          'user_id': user.id,
          'game_id': widget.game.id,
          'target_price': null,
          'priority': 3,
        });

        setState(() => _isInWishlist = true);
        Get.snackbar('Agregado', 'Juego agregado a tu wishlist');
      }
    } catch (e) {
      Get.snackbar('Error', 'No se pudo actualizar la wishlist: $e');
    } finally {
      setState(() => _isLoadingWishlist = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        widget.game.title,
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
                child: SingleChildScrollView(
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
                            image: widget.game.imageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(widget.game.imageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: widget.game.imageUrl == null
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
                        widget.game.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Description
                      if (widget.game.description != null) ...[
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
                          widget.game.description!,
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
                      if (widget.game.aiInsight != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryNeon.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryNeon.withOpacity(0.3),
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
                                widget.game.aiInsight!,
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

                      // Action buttons
                      Row(
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // TODO: Implement sharing
                                Get.snackbar('Próximamente', 'Compartir próximamente');
                              },
                              icon: const Icon(Icons.share),
                              label: const Text('Compartir'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryPurple,
                                side: const BorderSide(color: AppColors.primaryPurple),
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
