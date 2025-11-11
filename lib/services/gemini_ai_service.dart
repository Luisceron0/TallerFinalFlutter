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
      // If a Gemini API key is configured, prefer calling Gemini directly
      final geminiKey = ScraperConfig.geminiApiKey;
      if (geminiKey.isNotEmpty) {
        try {
          final dio = Dio();
          // Build a Spanish prompt that asks Gemini to return JSON and prefer deterministic
          // heuristics (thresholds). The assistant must reply ONLY with JSON (no extra text).
          final prompt =
              '''
Eres un asistente experto que evalúa si el precio de Steam de un juego de PC es una buena oferta.
RESPONDE ÚNICAMENTE con un objeto JSON (sin texto adicional). El objeto debe tener esta forma:
{
  "analysis": {
    "recommendation": "BUY_NOW" | "WAIT_FOR_SALE" | "AVOID",
    "summary": "resumen corto en español (1-2 frases)",
    "key_factors": ["lista de 2-4 factores cortos considerados"]
  }
}

Título del juego: "${gameTitle}"
Precio en Steam (EUR): ${steamPrice ?? 'null'}

IGNORA Epic y otras tiendas — solo evalúa Steam.
Aplica las siguientes reglas como heurísticas deterministas (útiles como criterio de desempate):
- Si el precio es numérico y <= 10 => RECOMENDACIÓN: BUY_NOW.
- Si el precio es numérico y <= 20 con descuento significativo (o juego claramente indie) => BUY_NOW.
- Si el precio es numérico y está entre 20 y 40 sin descuento => WAIT_FOR_SALE.
- Si el precio es numérico y > 40 sin descuento => AVOID.
- Si el precio es null o no se puede parsear => WAIT_FOR_SALE.

Usa el sentido común y conocimiento de mercado, pero prioriza las reglas anteriores al decidir. Responde los valores del JSON en español dentro de los campos (ej. "summary" en español).
''';

          final resp = await dio.post(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$geminiKey',
            data: {
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              // Lower temperature for more deterministic JSON output
              'temperature': 0.0,
            },
            options: Options(headers: {'Content-Type': 'application/json'}),
          );

          if (resp.statusCode == 200 && resp.data != null) {
            final raw = resp.data;
            final text =
                raw['candidates']?[0]?['content']?['parts']?[0]?['text'];
            if (text != null) {
              try {
                final decoded = json.decode(text) as Map<String, dynamic>;
                return decoded;
              } catch (decErr) {
                print('Gemini returned non-JSON or could not parse: $decErr');
                // fallthrough to other methods
              }
            }
          }
        } catch (gemErr) {
          print('Direct Gemini analyze failed: $gemErr');
          // fallthrough to supabase/scraper fallback
        }
      }

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
