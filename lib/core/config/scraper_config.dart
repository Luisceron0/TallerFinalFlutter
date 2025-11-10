import 'package:flutter_dotenv/flutter_dotenv.dart';

class ScraperConfig {
  static String get scraperApiUrl {
    // Use Render production URL
    return 'https://gameprice-scraper.onrender.com';
  }

  static String get geminiApiKey {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      // Return empty string in production if not configured
      // AI features will be disabled gracefully
      return '';
    }
    return key;
  }

  static bool get isDebugMode {
    return dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';
  }

  // API Endpoints
  static String get searchEndpoint => '$scraperApiUrl/api/search';
  static String get refreshWishlistEndpoint => '$scraperApiUrl/api/refresh-wishlist';
  static String get analyzePurchaseEndpoint => '$scraperApiUrl/api/analyze-purchase';

  // Request timeouts (in seconds)
  static const int searchTimeout = 30; // Steam/Epic scraping can be slow
  static const int refreshTimeout = 60; // Multiple games refresh

  // Rate limiting
  static const int maxRequestsPerMinute = 10;
}
