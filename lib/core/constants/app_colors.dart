import 'package:flutter/material.dart';

class AppColors {
  // Gaming theme - Dark backgrounds with neon accents
  static const Color primaryNeon = Color(0xFF00FF88); // Bright green neon
  static const Color secondaryNeon = Color(0xFF00D4FF); // Cyan neon
  static const Color accentNeon = Color(0xFFFF0080); // Magenta neon

  // Dark theme backgrounds
  static const Color backgroundColor = Color(0xFF0A0A0A); // Very dark
  static const Color surfaceColor = Color(0xFF1A1A1A); // Dark surface
  static const Color cardBackground = Color(0xFF2A2A2A); // Card background

  // Text colors for dark theme
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB3B3B3);
  static const Color tertiaryText = Color(0xFF808080);

  // Status colors
  static const Color successColor = Color(0xFF00FF88); // Green for deals
  static const Color warningColor = Color(0xFFFFA500); // Orange for warnings
  static const Color errorColor = Color(0xFFFF4444); // Red for errors

  // Store specific colors
  static const Color steamColor = Color(0xFF1B2838); // Steam blue-grey
  static const Color epicColor = Color(0xFF313131); // Epic dark grey

  // Price colors
  static const Color discountColor = Color(0xFFFF6B35); // Orange-red for discounts
  static const Color bestPriceColor = Color(0xFF00FF88); // Green for best price

  // Legacy colors for compatibility
  static const Color primaryPurple = Color(0xFF6366F1); // Indigo
  static const Color lightPurple = Color(0xFFA5B4FC); // Light indigo
  static const Color pendingTask = Color(0xFFFFA500); // Orange

  // Gradient colors - Gaming style
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00FF88), // Neon green
      Color(0xFF00D4FF), // Cyan
      Color(0xFFFF0080), // Magenta
    ],
  );

  // Card gradients
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A2A2A),
      Color(0xFF1A1A1A),
    ],
  );

  // Button gradients
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00FF88),
      Color(0xFF00D4FF),
    ],
  );
}
