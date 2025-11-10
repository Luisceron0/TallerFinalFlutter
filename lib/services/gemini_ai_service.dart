import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

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

      // Usar Supabase Edge Function para chat
      final supabase = Supabase.instance.client;

      final response = await supabase.functions.invoke(
        'chat-response',
        body: {'message': userMessage, 'prompt': prompt},
      );

      if (response.status == 200) {
        return response.data['response'] as String?;
      }

      return 'Lo siento, tuve un problema procesando tu mensaje. ¿Puedes intentarlo de nuevo?';
    } catch (e) {
      print('Error generando respuesta de chat: $e');
      return 'Lo siento, tuve un problema procesando tu mensaje. ¿Puedes intentarlo de nuevo?';
    }
  }
}
