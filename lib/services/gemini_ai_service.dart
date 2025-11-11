import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import '../core/config/scraper_config.dart';

class GeminiAIService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> generateQuickTip({
    required String gameTitle,
    double? steamPrice,
    double? epicPrice,
    required String userId,
  }) async {
    try {
      // Usar Supabase Edge Function para generar tip
      final supabase = Supabase.instance.client;

      final response = await supabase.functions.invoke(
        'generate-tip',
        body: {
          'game_title': gameTitle,
          'steam_price': steamPrice,
          'epic_price': epicPrice,
          'user_id': userId,
        },
      );

      if (response.status == 200) {
        return response.data['tip'] as String?;
      }

      return null;
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
      // Usar Supabase Edge Function para análisis
      final supabase = Supabase.instance.client;

      final response = await supabase.functions.invoke(
        'analyze-purchase',
        body: {
          'game_title': gameTitle,
          'steam_price': steamPrice,
          'epic_price': epicPrice,
          'user_id': userId,
        },
      );

      if (response.status == 200) {
        return response.data as Map<String, dynamic>;
      }

      print('Supabase analyze-purchase returned status: ${response.status}');

      // Fallback: try the scraper API analyze endpoint
      try {
        final dio = Dio();
        final resp = await dio.post(
          ScraperConfig.analyzePurchaseEndpoint,
          data: {
            'game_title': gameTitle,
            'steam_price': steamPrice,
            'epic_price': epicPrice,
            'user_id': userId,
          },
          options: Options(headers: {'Content-Type': 'application/json'}),
        );

        if (resp.statusCode == 200 && resp.data != null) {
          return Map<String, dynamic>.from(resp.data as Map);
        }
      } catch (fallbackErr) {
        print('Fallback analyze endpoint failed: $fallbackErr');
      }

      return null;
    } catch (e) {
      print('Error analizando decisión: $e');
      return null;
    }
  }

  Future<String?> generateChatResponse(String userMessage) async {
    try {
      final prompt =
          """
      Eres un asistente especializado en juegos de PC. Responde de manera útil y concisa a: "$userMessage"

      Mantén un tono amigable y experto en gaming. Si mencionan precios, enfócate en rangos realistas (€10-60 para juegos AAA, €5-30 para indie).
      Si preguntan por recomendaciones, sugiere juegos específicos con precios aproximados.
      Responde en español.
      """;

      // Try Supabase Edge Function first
      try {
        final supabase = Supabase.instance.client;
        final response = await supabase.functions.invoke(
          'chat-response',
          body: {'message': userMessage, 'prompt': prompt},
        );

        if (response.status == 200) {
          return response.data['response'] as String?;
        }
      } catch (supabaseError) {
        print(
          'Supabase function failed, trying direct API call: $supabaseError',
        );
      }

      // Fallback to direct Gemini API call
      final geminiApiKey = ScraperConfig.geminiApiKey;
      if (geminiApiKey.isEmpty) {
        return 'Lo siento, el servicio de IA no está disponible en este momento.';
      }

      final dio = Dio();
      final response = await dio.post(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$geminiApiKey',
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final responseText =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return responseText ??
            'Lo siento, tuve un problema procesando tu mensaje. ¿Puedes intentarlo de nuevo?';
      }

      return 'Lo siento, tuve un problema procesando tu mensaje. ¿Puedes intentarlo de nuevo?';
    } catch (e) {
      print('Error generando respuesta de chat: $e');
      return 'Lo siento, tuve un problema procesando tu mensaje. ¿Puedes intentarlo de nuevo?';
    }
  }
}
