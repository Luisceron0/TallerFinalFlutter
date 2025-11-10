import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'presentation/pages/auth_gate.dart';
import 'presentation/pages/game_search_page.dart';
import 'presentation/pages/game_detail_page.dart';
import 'presentation/pages/notifications_page.dart';
import 'presentation/pages/wishlist_page.dart';
import 'presentation/pages/add_task_page.dart';
import 'presentation/pages/home_page.dart';
import 'core/constants/app_colors.dart';
import 'core/config/supabase_config.dart';
import 'presentation/controllers/auth_controller.dart';
import 'presentation/controllers/game_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Supabase (handles env loading internally)
    await SupabaseConfig.initialize();

    // Initialize other services that might need env vars
    // ScraperApiService will be initialized when needed

    // Register global controllers
    Get.put(AuthController(), permanent: true);
    Get.put(GameController(), permanent: true);
    runApp(const MyApp());
  } catch (e) {
    // If initialization fails, show error and run app anyway
    print('Error initializing app: $e');
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
        cardTheme: const CardThemeData(
          color: AppColors.cardBackground,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
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
      getPages: [
        GetPage(name: '/GameSearchPage', page: () => const GameSearchPage()),
        GetPage(name: '/GameDetailPage', page: () => GameDetailPage(game: Get.arguments as dynamic)),
        GetPage(name: '/NotificationsPage', page: () => const NotificationsPage()),
        GetPage(name: '/WishlistPage', page: () => const WishlistPage()),
        GetPage(name: '/AddTaskPage', page: () => const AddTaskPage()),
        GetPage(name: '/HomePage', page: () => const HomePage()),
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}
