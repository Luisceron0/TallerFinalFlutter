import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GeminiAIService {
  late final GenerativeModel _model;
  final SupabaseClient _supabase = Supabase.instance.client;

  GeminiAIService(String apiKey) {
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
  }

  Future<String?> generateQuickTip({
    required String gameTitle,
    double? steamPrice,
    double? epicPrice,
    required String userId,
  }) async {
    try {
      // Obtener historial del usuario desde Supabase
      final history = await _getUserSearchHistory(userId);

      final prompt =
          """
      Analiza estos precios de juegos y da un tip breve (máx 50 palabras):

      Juego: $gameTitle
      Precio Steam: ${steamPrice ?? 'No disponible'}€
      Precio Epic: ${epicPrice ?? 'No disponible'}€

      Búsquedas recientes del usuario: ${history.join(', ')}

      Enfócate en:
      - Mejor oferta entre tiendas
      - Valor por dinero
      - Momento ideal para comprar

      Mantén conciso y práctico.
      """;

      final response = await _model.generateContent([Content.text(prompt)]);
      final tip = response.text;

      // Guardar el insight en Supabase para sincronización
      if (tip != null) {
        await _saveAIInsight(userId, 'quick_tip', {
          'game_title': gameTitle,
          'steam_price': steamPrice,
          'epic_price': epicPrice,
          'tip': tip,
        });
      }

      return tip;
    } catch (e) {
      print('Error generando tip IA: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> analyzePurchaseDecision({
    required String gameTitle,
    double? steamPrice,
    double? epicPrice,
    required String userId,
  }) async {
    try {
      // Obtener historial de precios desde Supabase
      final priceHistory = await _getPriceHistory(gameTitle);
      final userProfile = await _analyzeUserProfile(userId);

      final prompt =
          """
      Análisis completo de decisión de compra. Responde en JSON:

      {
        "recomendacion": "COMPRAR_AHORA" | "ESPERAR" | "EVITAR",
        "confianza": 0-100,
        "resumen": "Resumen de 2-3 frases",
        "factores_clave": ["factor 1", "factor 2", "factor 3"]
      }

      Juego: $gameTitle
      Steam: ${steamPrice ?? 'N/A'}€
      Epic: ${epicPrice ?? 'N/A'}€

      Historial precios: ${priceHistory.toString()}
      Perfil usuario: ${userProfile.toString()}
      """;

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text != null) {
        final jsonResponse = json.decode(text);
        return jsonResponse;
      }
      return null;
    } catch (e) {
      print('Error analizando decisión: $e');
      return null;
    }
  }

  Future<List<String>> _getUserSearchHistory(String userId) async {
    try {
      final response = await _supabase
          .from('user_searches')
          .select('query')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10);

      return response.map((r) => r['query'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<double>> _getPriceHistory(String gameTitle) async {
    try {
      final response = await _supabase
          .from('price_history')
          .select('price')
          .eq('game_title', gameTitle)
          .order('created_at', ascending: false)
          .limit(10);

      return response.map((r) => (r['price'] as num).toDouble()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _analyzeUserProfile(String userId) async {
    try {
      // Obtener estadísticas del usuario
      final searches = await _supabase
          .from('user_searches')
          .select('query')
          .eq('user_id', userId)
          .order('searched_at', ascending: false)
          .limit(20);

      final wishlist = await _supabase
          .from('wishlist')
          .select('games(title)')
          .eq('user_id', userId);

      return {
        'total_searches': searches.length,
        'favorite_genres': _extractGenres(searches),
        'wishlist_count': wishlist.length,
        'search_patterns': searches.map((s) => s['query']).toList(),
      };
    } catch (e) {
      return {};
    }
  }

  List<String> _extractGenres(List<dynamic> searches) {
    // Simple genre extraction based on keywords
    final genres = <String>[];
    final genreKeywords = {
      'action': ['action', 'fps', 'shooter', 'battle'],
      'rpg': ['rpg', 'role', 'fantasy', 'adventure'],
      'strategy': ['strategy', 'rts', 'simulation', 'management'],
      'sports': ['sports', 'football', 'soccer', 'racing'],
      'indie': ['indie', 'pixel', 'retro'],
    };

    for (var search in searches) {
      final query = search['query'].toString().toLowerCase();
      for (var genre in genreKeywords.keys) {
        if (genreKeywords[genre]!.any((keyword) => query.contains(keyword))) {
          if (!genres.contains(genre)) genres.add(genre);
        }
      }
    }

    return genres;
  }

  Future<void> _saveAIInsight(
    String userId,
    String insightType,
    Map<String, dynamic> content,
  ) async {
    try {
      await _supabase.from('ai_insights').insert({
        'user_id': userId,
        'insight_type': insightType,
        'content': content,
        'expires_at': DateTime.now().add(Duration(days: 7)).toIso8601String(),
      });
    } catch (e) {
      print('Error saving AI insight: $e');
    }
  }
}
