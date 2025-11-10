import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String? geminiApiKey;

  static void initialize() {
    // Cargar desde .env o Supabase secrets
    geminiApiKey = dotenv.env['GEMINI_API_KEY'];
  }
}
