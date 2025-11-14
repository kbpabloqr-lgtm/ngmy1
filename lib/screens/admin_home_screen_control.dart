import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminHomeScreenControl extends StatefulWidget {
  const AdminHomeScreenControl({super.key});

  @override
  State<AdminHomeScreenControl> createState() => _AdminHomeScreenControlState();
}

class _AdminHomeScreenControlState extends State<AdminHomeScreenControl> {
  String _selectedWallpaper = 'electric_blue_curves';
  bool _isSaving = false;

  // Collection of wallpaper options - Inspired by modern 3D curved designs
  final List<Map<String, dynamic>> _wallpapers = [
    // Row 1 - Pink, Blue, Orange, Golden variations
    {
      'id': 'soft_pink_waves',
      'name': 'Soft Pink',
      'gradient': const LinearGradient(
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
    },
    {
      'id': 'electric_blue_curves',
      'name': 'Electric Blue',
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0047FF),
          Color(0xFF0066FF),
          Color(0xFF3385FF),
          Color(0xFF66A3FF),
          Color(0xFF1A5CFF),
        ],
        stops: [0.0, 0.2, 0.5, 0.8, 1.0],
      ),
    },
    {
      'id': 'vibrant_orange_flow',
      'name': 'Vibrant Orange',
      'gradient': const LinearGradient(
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
    },
    {
      'id': 'golden_amber_swirl',
      'name': 'Golden Amber',
      'gradient': const LinearGradient(
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
    },
    
    // Row 2 - Blue, Lavender, Peach, Rose variations
    {
      'id': 'ocean_depth_layers',
      'name': 'Ocean Depth',
      'gradient': const LinearGradient(
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
    },
    {
      'id': 'lavender_dream_folds',
      'name': 'Lavender Dream',
      'gradient': const LinearGradient(
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
    },
    {
      'id': 'sunset_peach_ribbon',
      'name': 'Sunset Peach',
      'gradient': const LinearGradient(
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
    },
    {
      'id': 'rose_pink_soft',
      'name': 'Rose Pink',
      'gradient': const LinearGradient(
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
    },
    
    // Row 3 - Violet, Purple, Sky, Tangerine variations
    {
      'id': 'violet_fold_waves',
      'name': 'Violet Waves',
      'gradient': const LinearGradient(
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
    },
    {
      'id': 'deep_purple_spiral',
      'name': 'Deep Purple',
      'gradient': const LinearGradient(
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
    },
    {
      'id': 'sky_blue_ripple',
      'name': 'Sky Blue',
      'gradient': const LinearGradient(
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
    },
    {
      'id': 'tangerine_bright',
      'name': 'Tangerine',
      'gradient': const LinearGradient(
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
    },
    
    // Row 4 - Midnight, Twilight, Royal, Burgundy variations
    {
      'id': 'midnight_purple_depth',
      'name': 'Midnight Purple',
      'gradient': const LinearGradient(
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
    },
    {
      'id': 'twilight_purple_layer',
      'name': 'Twilight Purple',
      'gradient': const LinearGradient(
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
    },
    {
      'id': 'royal_violet_swirl',
      'name': 'Royal Violet',
      'gradient': const LinearGradient(
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
    },
    {
      'id': 'burgundy_wine_fold',
      'name': 'Burgundy Wine',
      'gradient': const LinearGradient(
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
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSelectedWallpaper();
  }

  Future<void> _loadSelectedWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedWallpaper = prefs.getString('home_wallpaper') ?? 'electric_blue_curves';
    });
  }

  Future<void> _saveWallpaper() async {
    setState(() => _isSaving = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('home_wallpaper', _selectedWallpaper);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Wallpaper Saved!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Home screen background updated successfully',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving wallpaper: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Home Screen Control',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.withAlpha((0.3 * 255).round()),
                          Colors.purple.withAlpha((0.2 * 255).round()),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.withAlpha((0.3 * 255).round()),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade400, Colors.purple.shade400],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.wallpaper, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Wallpaper Selection',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Choose a background for your home screen',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Wallpaper Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _wallpapers.length,
                    itemBuilder: (context, index) {
                      final wallpaper = _wallpapers[index];
                      final isSelected = _selectedWallpaper == wallpaper['id'];
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedWallpaper = wallpaper['id'];
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: wallpaper['gradient'],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? Colors.green : Colors.white.withAlpha((0.3 * 255).round()),
                              width: isSelected ? 4 : 2,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: Colors.green.withAlpha((0.5 * 255).round()),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Name at the bottom
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha((0.6 * 255).round()),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(14),
                                      bottomRight: Radius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    wallpaper['name'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              
                              // Selected checkmark
                              if (isSelected)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withAlpha((0.5 * 255).round()),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          
          // Save Button at the bottom
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0A0E27).withAlpha((0 * 255).round()),
                  const Color(0xFF0A0E27),
                ],
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveWallpaper,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Save Wallpaper',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
