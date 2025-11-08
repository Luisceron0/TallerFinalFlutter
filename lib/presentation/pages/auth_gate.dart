import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import 'auth_page.dart';
import 'home_menu_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      final client = SupabaseConfig.client;
      return StreamBuilder<AuthState>(
        stream: client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = client.auth.currentSession;
          if (session != null) {
            return const HomeMenuPage();
          }
          return const AuthPage();
        },
      );
    } catch (e) {
      // If Supabase is not initialized, show loading or error
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
  }
}
