import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static SupabaseClient? _client;

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase not initialized. Call initialize() first.');
    }
    return _client!;
  }

  static Future<void> initialize() async {
    try {
      // Load environment variables
      await dotenv.load(fileName: ".env");

      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl == null || supabaseAnonKey == null) {
        throw Exception(
          'Supabase URL and Anon Key must be provided in .env file'
        );
      }

      // Initialize Supabase
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: false, // Set to true for development
      );

      _client = Supabase.instance.client;
    } catch (e) {
      print('Error initializing Supabase: $e');
      rethrow;
    }
  }

  // Helper method to check if user is authenticated
  static bool get isAuthenticated => _client?.auth.currentUser != null;

  // Helper method to get current user
  static User? get currentUser => _client?.auth.currentUser;
}
