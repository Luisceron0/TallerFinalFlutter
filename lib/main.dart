import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'presentation/pages/auth_gate.dart';
import 'core/constants/app_colors.dart';
import 'core/config/supabase_config.dart';
import 'presentation/controllers/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Supabase
    await SupabaseConfig.initialize();
    // Register global AuthController
    Get.put(AuthController(), permanent: true);
    runApp(const MyApp());
  } catch (e) {
    // If Supabase initialization fails, show error and run app anyway
    print('Error initializing Supabase: $e');
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'GamePrice Comparator',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundColor,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryNeon,
          secondary: AppColors.secondaryNeon,
          surface: AppColors.surfaceColor,
          background: AppColors.backgroundColor,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        cardTheme: CardTheme(
          color: AppColors.cardBackground,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryNeon,
            foregroundColor: AppColors.backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.secondaryNeon),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryNeon, width: 2),
          ),
          labelStyle: TextStyle(color: AppColors.secondaryText),
        ),
      ),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}
