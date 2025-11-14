import 'package:flutter/material.dart';

/// Core colors for the liquid glass theme. These are dynamic and adapt to
/// both light and dark mode contexts automatically.
class LiquidColors {
  static const primary = Color(0xFF2196F3);
  static const accent = Color(0xFF64B5F6);
  
  // Glass surface opacities carefully tuned for both modes
  static const lightGlassOpacity = 0.65;
  static const darkGlassOpacity = 0.45;
  
  // Blur effects (in logical pixels)
  static const surfaceBlur = 10.0;
  static const modalBlur = 20.0;
  
  // Gradients for glass effects
  static LinearGradient glassGradient(BuildContext context, {double opacity = 1.0}) {
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        (isLight ? Colors.white : Colors.white12).withAlpha(((opacity * (isLight ? 0.92 : 0.12)) * 255).round()),
        (isLight ? Colors.white70 : Colors.white10).withAlpha(((opacity * (isLight ? 0.75 : 0.08)) * 255).round()),
      ],
      stops: const [0.0, 1.0],
    );
  }
}

/// The main theme data configuration that sets up the liquid glass visual style
ThemeData liquidThemeData(BuildContext context, {bool isDark = false}) {
  final baseTheme = ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorSchemeSeed: LiquidColors.primary,
  );

  return baseTheme.copyWith(
    scaffoldBackgroundColor: const Color(0xFF0A0E27),
    primaryColor: const Color(0xFF1E88E5),
    
    // Card theme with glass effect
    cardTheme: baseTheme.cardTheme.copyWith(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    
    // Fully rounded buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
      ),
    ),
    
    // Rounded text fields with glass effect
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: isDark 
          ? Colors.white.withAlpha((0.08 * 255).round())
          : Colors.black.withAlpha((0.04 * 255).round()),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
    ),
    
    // Dialog theme with strong blur and rounded corners
    dialogTheme: baseTheme.dialogTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      elevation: 0,
    ),
    
    // Bottom sheet theme with extra large radius
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(32),
        ),
      ),
    ),
    
    // Smooth animations for all transitions
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// Provides easy access to the current theme's glass surface configuration
extension LiquidThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get glassColor => isDark 
      ? Colors.white.withAlpha((LiquidColors.darkGlassOpacity * 255).round())
      : Colors.white.withAlpha((LiquidColors.lightGlassOpacity * 255).round());
  Color get glassHighlight => isDark
      ? Colors.white.withAlpha((0.1 * 255).round())
      : Colors.white.withAlpha((0.6 * 255).round());
}