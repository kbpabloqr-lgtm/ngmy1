import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_menu.dart';
import '../widgets/image_slider.dart';
import 'admin_control_panel.dart';
import 'menu_configuration_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _WallpaperEffectType { glow, rain, snow, sparkles }

class _WallpaperEffectConfig {
  final _WallpaperEffectType type;
  final List<Color> colors;
  final int elements;
  final double speed;
  final double sizeMultiplier;

  const _WallpaperEffectConfig({
    required this.type,
    required this.colors,
    this.elements = 16,
    this.speed = 1.0,
    this.sizeMultiplier = 1.0,
  });
}

const Map<String, _WallpaperEffectConfig> _wallpaperEffects = {
  'soft_pink_waves': _WallpaperEffectConfig(
    type: _WallpaperEffectType.glow,
    colors: [
      Color(0x33FFFFFF),
      Color(0x33FF85A1),
      Color(0x26FF6F91),
    ],
    elements: 14,
    speed: 0.7,
    sizeMultiplier: 1.15,
  ),
  'vibrant_orange_flow': _WallpaperEffectConfig(
    type: _WallpaperEffectType.sparkles,
    colors: [
      Color(0x44FFFFFF),
      Color(0x33FFC56B),
      Color(0x33FF8C32),
    ],
    elements: 18,
    speed: 1.2,
    sizeMultiplier: 1.0,
  ),
  'golden_amber_swirl': _WallpaperEffectConfig(
    type: _WallpaperEffectType.sparkles,
    colors: [
      Color(0x44FFEFD3),
      Color(0x33FFD369),
      Color(0x33B38600),
    ],
    elements: 16,
    speed: 1.0,
    sizeMultiplier: 1.05,
  ),
  'ocean_depth_layers': _WallpaperEffectConfig(
    type: _WallpaperEffectType.rain,
    colors: [
      Color(0x44FFFFFF),
      Color(0x3388E5FF),
    ],
    elements: 22,
    speed: 1.3,
    sizeMultiplier: 1.0,
  ),
  'lavender_dream_folds': _WallpaperEffectConfig(
    type: _WallpaperEffectType.snow,
    colors: [
      Color(0x66FFFFFF),
      Color(0x44EFD6FF),
    ],
    elements: 18,
    speed: 0.55,
    sizeMultiplier: 1.0,
  ),
  'sunset_peach_ribbon': _WallpaperEffectConfig(
    type: _WallpaperEffectType.glow,
    colors: [
      Color(0x33FFFFFF),
      Color(0x33FFB07B),
      Color(0x26FF8F6D),
    ],
    elements: 15,
    speed: 0.75,
    sizeMultiplier: 1.05,
  ),
  'rose_pink_soft': _WallpaperEffectConfig(
    type: _WallpaperEffectType.glow,
    colors: [
      Color(0x33FFFFFF),
      Color(0x33FF87C0),
      Color(0x26FF5EAB),
    ],
    elements: 16,
    speed: 0.8,
    sizeMultiplier: 1.1,
  ),
  'violet_fold_waves': _WallpaperEffectConfig(
    type: _WallpaperEffectType.sparkles,
    colors: [
      Color(0x44FFFFFF),
      Color(0x338C80FF),
      Color(0x33C0B6FF),
    ],
    elements: 20,
    speed: 1.1,
    sizeMultiplier: 0.95,
  ),
  'deep_purple_spiral': _WallpaperEffectConfig(
    type: _WallpaperEffectType.sparkles,
    colors: [
      Color(0x44FFFFFF),
      Color(0x336C32EC),
      Color(0x338B5CFF),
    ],
    elements: 20,
    speed: 1.05,
    sizeMultiplier: 1.05,
  ),
  'sky_blue_ripple': _WallpaperEffectConfig(
    type: _WallpaperEffectType.rain,
    colors: [
      Color(0x44FFFFFF),
      Color(0x332DD4BF),
    ],
    elements: 24,
    speed: 1.4,
    sizeMultiplier: 1.0,
  ),
  'tangerine_bright': _WallpaperEffectConfig(
    type: _WallpaperEffectType.glow,
    colors: [
      Color(0x33FFFFFF),
      Color(0x33FF9436),
      Color(0x26FF7A18),
    ],
    elements: 15,
    speed: 0.85,
    sizeMultiplier: 1.05,
  ),
  'twilight_purple_layer': _WallpaperEffectConfig(
    type: _WallpaperEffectType.sparkles,
    colors: [
      Color(0x44FFFFFF),
      Color(0x338E6CDF),
      Color(0x33C59AEE),
    ],
    elements: 20,
    speed: 1.0,
    sizeMultiplier: 1.0,
  ),
  'royal_violet_swirl': _WallpaperEffectConfig(
    type: _WallpaperEffectType.sparkles,
    colors: [
      Color(0x44FFFFFF),
      Color(0x338D51D7),
      Color(0x33B582F2),
    ],
    elements: 20,
    speed: 1.1,
    sizeMultiplier: 1.05,
  ),
  'burgundy_wine_fold': _WallpaperEffectConfig(
    type: _WallpaperEffectType.glow,
    colors: [
      Color(0x33FFFFFF),
      Color(0x33A22152),
      Color(0x26D94D71),
    ],
    elements: 16,
    speed: 0.75,
    sizeMultiplier: 1.0,
  ),
};

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<String> _sliderImages = [];
  int _slideDuration = 4;
  String _selectedWallpaper = 'electric_blue_curves';
  late final AnimationController _wallpaperController;

  @override
  void initState() {
    super.initState();
    _wallpaperController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    // Load data after UI is built (fast startup)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataAsync();
    });
  }

  @override
  void dispose() {
    _wallpaperController.dispose();
    super.dispose();
  }

  Future<void> _loadDataAsync() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (mounted) {
      setState(() {
        _sliderImages = prefs.getStringList('home_slider_images') ?? [];
        _slideDuration = prefs.getInt('home_slider_duration') ?? 4;
        _selectedWallpaper = prefs.getString('home_wallpaper') ?? 'electric_blue_curves';
      });
    }
  }

  LinearGradient _getWallpaperGradient(String wallpaperId) {
    final Map<String, LinearGradient> wallpapers = {
      // Row 1 - Pink, Blue, Orange, Golden variations
      'soft_pink_waves': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFF8FB1),
          Color(0xFFFF6F91),
          Color(0xFFFF5D8F),
          Color(0xFFFF85A1),
          Color(0xFFFFC2D1),
        ],
        stops: [0.0, 0.18, 0.45, 0.72, 1.0],
        transform: GradientRotation(0.6),
      ),
      'electric_blue_curves': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0047FF), Color(0xFF0066FF), Color(0xFF3385FF), Color(0xFF66A3FF), Color(0xFF1A5CFF)],
        stops: [0.0, 0.2, 0.5, 0.8, 1.0],
      ),
      'vibrant_orange_flow': const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFF4600),
          Color(0xFFFF6D00),
          Color(0xFFFF8C32),
          Color(0xFFFFB347),
          Color(0xFFFFC56B),
        ],
        stops: [0.0, 0.2, 0.48, 0.76, 1.0],
        transform: GradientRotation(1.1),
      ),
      'golden_amber_swirl': const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFF8F6B00),
          Color(0xFFB38600),
          Color(0xFFD9A441),
          Color(0xFFFFD369),
          Color(0xFFFFE598),
        ],
        stops: [0.0, 0.22, 0.52, 0.78, 1.0],
        transform: GradientRotation(0.9),
      ),
      
      // Row 2 - Blue, Lavender, Peach, Rose variations
      'ocean_depth_layers': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF001B2E),
          Color(0xFF003459),
          Color(0xFF005384),
          Color(0xFF0070A2),
          Color(0xFF00A6C0),
        ],
        stops: [0.0, 0.14, 0.45, 0.72, 1.0],
        transform: GradientRotation(1.2),
      ),
      'lavender_dream_folds': const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFBFA8F6),
          Color(0xFFCB9DFF),
          Color(0xFFD8A7FF),
          Color(0xFFEDC2FF),
          Color(0xFFF7D6FF),
        ],
        stops: [0.0, 0.23, 0.5, 0.74, 1.0],
        transform: GradientRotation(0.8),
      ),
      'sunset_peach_ribbon': const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFFFF715B),
          Color(0xFFFF8F6D),
          Color(0xFFFFB07B),
          Color(0xFFFFC38D),
          Color(0xFFFFE0B2),
        ],
        stops: [0.0, 0.21, 0.46, 0.73, 1.0],
        transform: GradientRotation(1.05),
      ),
      'rose_pink_soft': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFF9BBF),
          Color(0xFFFF7BAA),
          Color(0xFFFF5EAB),
          Color(0xFFFF87C0),
          Color(0xFFFFD0E5),
        ],
        stops: [0.0, 0.2, 0.48, 0.78, 1.0],
        transform: GradientRotation(0.7),
      ),
      
      // Row 3 - Violet, Purple, Sky, Tangerine variations
      'violet_fold_waves': const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF6C63FF),
          Color(0xFF7F6BFF),
          Color(0xFF9D8CFF),
          Color(0xFFC0B6FF),
          Color(0xFFE1DDFF),
        ],
        stops: [0.0, 0.19, 0.47, 0.74, 1.0],
        transform: GradientRotation(1.0),
      ),
      'deep_purple_spiral': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF3E1C96),
          Color(0xFF5422C1),
          Color(0xFF6C32EC),
          Color(0xFF8B5CFF),
          Color(0xFFB292FF),
        ],
        stops: [0.0, 0.22, 0.5, 0.78, 1.0],
        transform: GradientRotation(0.75),
      ),
      'sky_blue_ripple': const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFF00B4DB),
          Color(0xFF0083B0),
          Color(0xFF2DD4BF),
          Color(0xFF7EE8FA),
          Color(0xFFACE0FF),
        ],
        stops: [0.0, 0.18, 0.46, 0.74, 1.0],
        transform: GradientRotation(1.15),
      ),
      'tangerine_bright': const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFF5F00),
          Color(0xFFFF7A18),
          Color(0xFFFF9436),
          Color(0xFFFFB25C),
          Color(0xFFFFD089),
        ],
        stops: [0.0, 0.24, 0.5, 0.76, 1.0],
        transform: GradientRotation(0.95),
      ),
      
      // Row 4 - Midnight, Twilight, Royal, Burgundy variations
      'midnight_purple_depth': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0B0131),
          Color(0xFF1B0063),
          Color(0xFF310092),
          Color(0xFF4500BF),
          Color(0xFF2A0580),
        ],
        stops: [0.0, 0.21, 0.47, 0.74, 1.0],
        transform: GradientRotation(1.05),
      ),
      'twilight_purple_layer': const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF3D1E6D),
          Color(0xFF53298E),
          Color(0xFF7242B3),
          Color(0xFF9960D9),
          Color(0xFFC59AEE),
        ],
        stops: [0.0, 0.22, 0.5, 0.76, 1.0],
        transform: GradientRotation(0.85),
      ),
      'royal_violet_swirl': const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFF4E148C),
          Color(0xFF6F30B5),
          Color(0xFF8D51D7),
          Color(0xFFB582F2),
          Color(0xFFDAB6FF),
        ],
        stops: [0.0, 0.24, 0.51, 0.77, 1.0],
        transform: GradientRotation(1.1),
      ),
      'burgundy_wine_fold': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF3D001B),
          Color(0xFF5C002C),
          Color(0xFF7A103D),
          Color(0xFFA22152),
          Color(0xFFD94D71),
        ],
        stops: [0.0, 0.21, 0.49, 0.76, 1.0],
        transform: GradientRotation(0.9),
      ),
    };

    return wallpapers[wallpaperId] ?? wallpapers['electric_blue_curves']!;
  }

  Future<void> _saveSliderData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('home_slider_images', _sliderImages);
    await prefs.setInt('home_slider_duration', _slideDuration);
  }

  void _openAdminPanel() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdminControlPanel(
          currentImages: _sliderImages,
          currentSlideDuration: _slideDuration,
          onImagesUpdated: (newImages) {
            setState(() {
              _sliderImages = newImages;
            });
            _saveSliderData();
          },
          onSlideDurationUpdated: (newDuration) {
            setState(() {
              _slideDuration = newDuration;
            });
            _saveSliderData();
          },
          onMenuConfigPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const MenuConfigurationScreen(),
              ),
            );
          },
        ),
      ),
    ).then((_) async {
      // Reload wallpaper when returning from admin panel
      final prefs = await SharedPreferences.getInstance();
      final newWallpaper = prefs.getString('home_wallpaper') ?? 'electric_blue_curves';
      if (mounted && newWallpaper != _selectedWallpaper) {
        setState(() {
          _selectedWallpaper = newWallpaper;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildWallpaperBackground()),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  // Image Slider at the top
                  const SizedBox(height: 12),
                  _buildFramedSlider(),

                  const SizedBox(height: 20),
                  
                  // Circular Menu with Admin Home Button
                  Expanded(
                    child: Align(
                      alignment: const Alignment(0.0, 0.8), // Bring it up once from the bottom
                      child: CircularMenu(
                        size: MediaQuery.of(context).size.shortestSide * 0.92,
                        onAdminPressed: _openAdminPanel, // Pass admin callback
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaperBackground() {
    final gradient = _getWallpaperGradient(_selectedWallpaper);
    final effectConfig = _wallpaperEffects[_selectedWallpaper];

    if (effectConfig == null) {
      return DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: const SizedBox.expand(),
      );
    }

    return AnimatedBuilder(
      animation: _wallpaperController,
      builder: (_, __) {
        return DecoratedBox(
          decoration: BoxDecoration(gradient: gradient),
          child: CustomPaint(
            painter: _WallpaperEffectPainter(
              progress: _wallpaperController.value,
              config: effectConfig,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

    Widget _buildFramedSlider() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF8E2DE2),
                      Color(0xFF4A00E0),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.28 * 255).round()),
                      offset: const Offset(0, 14),
                      blurRadius: 22,
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withAlpha((0.18 * 255).round()),
                        width: 1.5,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withAlpha((0.08 * 255).round()),
                          Colors.white.withAlpha((0.02 * 255).round()),
                        ],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ImageSlider(
                        key: ValueKey(_sliderImages.length),
                        imageUrls: _sliderImages,
                        slideDurationSeconds: _slideDuration,
                        defaultAssetImage: 'assets/images/default_promo.png',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
}

class _WallpaperEffectPainter extends CustomPainter {
  final double progress;
  final _WallpaperEffectConfig config;

  const _WallpaperEffectPainter({
    required this.progress,
    required this.config,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (config.type) {
      case _WallpaperEffectType.glow:
        _paintGlow(canvas, size);
        break;
      case _WallpaperEffectType.rain:
        _paintRain(canvas, size);
        break;
      case _WallpaperEffectType.snow:
        _paintSnow(canvas, size);
        break;
      case _WallpaperEffectType.sparkles:
        _paintSparkles(canvas, size);
        break;
    }
  }

  void _paintGlow(Canvas canvas, Size size) {
    final int count = config.elements;
    final double baseSize = size.shortestSide;

    for (int i = 0; i < count; i++) {
      final double phase = (progress * config.speed + i / count) % 1.0;
      final double xSeed = (i * 0.21 + progress * config.speed) % 1.0;
      final double x = size.width * ((xSeed + 0.15 * math.sin((progress + i) * math.pi * 2) + 1) % 1.0);
      final double y = size.height * phase;
      final double radius = baseSize * (0.08 + 0.04 * math.cos((progress + i * 0.3) * math.pi * 2)) * config.sizeMultiplier;

      double opacity = 0.2 + 0.3 * math.sin((progress + i * 0.37) * math.pi * 2);
      opacity = math.max(0.08, math.min(0.55, opacity));
      final Color baseColor = config.colors[i % config.colors.length];
      final paint = Paint()
        ..color = baseColor.withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);

      canvas.drawCircle(Offset(x, y), radius.abs(), paint);
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    final int count = config.elements;
    final double strokeWidth = size.shortestSide * 0.006;

    for (int i = 0; i < count; i++) {
      final double phase = (progress * config.speed + i / count) % 1.0;
      final double xSeed = (i * 0.17 + progress * 0.4) % 1.0;
      final double startX = size.width * xSeed;
      final double startY = size.height * (phase - 0.2);
      final double endX = startX + size.width * 0.05;
      final double endY = startY + size.height * 0.28;

      double opacity = 0.25 + 0.35 * math.sin((progress + i * 0.5) * math.pi * 2);
      opacity = math.max(0.12, math.min(0.6, opacity));
      final Color baseColor = config.colors[i % config.colors.length].withValues(alpha: opacity);

      final paint = Paint()
        ..color = baseColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    final int count = config.elements;
    final double baseSize = size.shortestSide * 0.018 * config.sizeMultiplier;

    for (int i = 0; i < count; i++) {
      final double phase = (progress * config.speed + i / count) % 1.0;
      final double drift = 0.18 * math.sin((progress + i * 0.42) * math.pi * 2);
      final double xSeed = ((i * 0.19) + drift + 1.0) % 1.0;
      final double x = size.width * xSeed;
      final double y = size.height * phase;
      final double radius = baseSize * (0.6 + 0.4 * math.cos((progress + i) * math.pi * 2));

      double opacity = 0.28 + 0.35 * math.cos((progress + i * 0.3) * math.pi * 2);
      opacity = math.max(0.15, math.min(0.6, opacity));
      final Color baseColor = config.colors[i % config.colors.length].withValues(alpha: opacity);

      final paint = Paint()
        ..color = baseColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

      canvas.drawCircle(Offset(x, y), radius.abs(), paint);
    }
  }

  void _paintSparkles(Canvas canvas, Size size) {
    final int count = config.elements;
    final double maxSize = size.shortestSide * 0.03 * config.sizeMultiplier;

    for (int i = 0; i < count; i++) {
      final double phase = (progress * config.speed + i / count) % 1.0;
      final double oscillation = math.sin((progress + i * 0.6) * math.pi * 2);
      final double x = size.width * ((math.sin((i * 11.3) + progress * math.pi * 2) * 0.45) + 0.5);
      final double y = size.height * phase;
      final double sparkleSize = maxSize * (0.6 + 0.4 * math.cos((progress + i * 0.4) * math.pi * 2));

      double opacity = 0.22 + 0.5 * (0.5 + oscillation * 0.5);
      opacity = math.max(0.18, math.min(0.75, opacity));
      final Color baseColor = config.colors[i % config.colors.length];

      final Paint glowPaint = Paint()
        ..color = baseColor.withValues(alpha: opacity * 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

      canvas.drawCircle(Offset(x, y), sparkleSize * 0.6, glowPaint);

      final Paint strokePaint = Paint()
        ..color = baseColor.withValues(alpha: opacity)
        ..strokeWidth = sparkleSize * 0.12
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x - sparkleSize, y),
        Offset(x + sparkleSize, y),
        strokePaint,
      );
      canvas.drawLine(
        Offset(x, y - sparkleSize),
        Offset(x, y + sparkleSize),
        strokePaint,
      );
      canvas.drawLine(
        Offset(x - sparkleSize * 0.7, y - sparkleSize * 0.7),
        Offset(x + sparkleSize * 0.7, y + sparkleSize * 0.7),
        strokePaint,
      );
      canvas.drawLine(
        Offset(x - sparkleSize * 0.7, y + sparkleSize * 0.7),
        Offset(x + sparkleSize * 0.7, y - sparkleSize * 0.7),
        strokePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WallpaperEffectPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.config != config;
  }
}
