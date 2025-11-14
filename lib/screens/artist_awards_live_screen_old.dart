import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_models.dart';

/// Artist Awards Live Streaming Platform
/// Promoting community artists with live awards ceremonies
class ArtistAwardsLiveScreen extends StatefulWidget {
  const ArtistAwardsLiveScreen({super.key});

  @override
  State<ArtistAwardsLiveScreen> createState() => _ArtistAwardsLiveScreenState();
}

class _ArtistAwardsLiveScreenState extends State<ArtistAwardsLiveScreen> with TickerProviderStateMixin {
  bool _isLive = false;
  bool _isBroadcasting = false;
  Duration _countdownDuration = const Duration(hours: 2, minutes: 30, seconds: 45);
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  
  // Camera variables
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isLoadingCamera = false;
  String? _cameraError;
  
  // Dynamic settings from admin
  LiveSettings? _liveSettings;
  List<CategoryModel> _categories = [];
  String _categoriesTitle = "TODAY'S CATEGORIES";
  
  final List<Map<String, dynamic>> _awardCategories = [
    {
      'title': 'Best Music Performance',
      'icon': Icons.music_note,
      'color': Color(0xFFFF6B9D),
      'nominees': 5,
    },
    {
      'title': 'Most Viewed Video',
      'icon': Icons.play_circle_filled,
      'color': Color(0xFF00D9FF),
      'nominees': 8,
    },
    {
      'title': 'Best Actor',
      'icon': Icons.movie,
      'color': Color(0xFFFFB800),
      'nominees': 6,
    },
    {
      'title': 'Rising Star',
      'icon': Icons.stars,
      'color': Color(0xFF00FF94),
      'nominees': 10,
    },
    {
      'title': 'Best Collaboration',
      'icon': Icons.people,
      'color': Color(0xFFB794F6),
      'nominees': 4,
    },
    {
      'title': 'Fan Favorite',
      'icon': Icons.favorite,
      'color': Color(0xFFFF5757),
      'nominees': 12,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    
    _initializeCameras();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load live settings
    final liveSettingsJson = prefs.getString('live_settings');
    if (liveSettingsJson != null) {
      _liveSettings = LiveSettings.fromJson(jsonDecode(liveSettingsJson));
      _countdownDuration = _liveSettings!.countdownDuration;
      _categoriesTitle = _liveSettings!.categoriesTitle;
      // Check if admin manually enabled live
      if (_liveSettings!.isLiveManuallyEnabled) {
        _isLive = true;
      }
    } else {
      _liveSettings = LiveSettings();
    }
    
    // Load categories
    final categoriesJson = prefs.getString('media_categories');
    if (categoriesJson != null) {
      final List<dynamic> decoded = jsonDecode(categoriesJson);
      _categories = decoded.map((c) => CategoryModel.fromJson(c)).toList();
    }
    
    setState(() {});
    
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _shimmerController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      setState(() {
        _cameraError = 'Failed to get cameras: $e';
      });
    }
  }

  Future<void> _startBroadcasting() async {
    if (_isBroadcasting) {
      // Stop broadcasting
      await _cameraController?.dispose();
      setState(() {
        _isBroadcasting = false;
        _isCameraInitialized = false;
        _cameraController = null;
      });
      return;
    }

    setState(() {
      _isLoadingCamera = true;
      _cameraError = null;
    });

    try {
      // Request camera permission
      final status = await Permission.camera.request();
      
      if (!status.isGranted) {
        throw Exception('Camera permission denied');
      }

      if (_cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      // Initialize camera controller with front camera (or back camera if front not available)
      final camera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isBroadcasting = true;
          _isLoadingCamera = false;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.videocam, color: Colors.white),
                  SizedBox(width: 12),
                  Text('🎥 Broadcasting started! You are now LIVE!'),
                ],
              ),
              backgroundColor: const Color(0xFF00FF94),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _cameraError = 'Camera error: $e';
        _isLoadingCamera = false;
        _isBroadcasting = false;
      });

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Camera error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdownDuration.inSeconds > 0) {
          _countdownDuration -= const Duration(seconds: 1);
        } else {
          _isLive = true;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: _isLive ? _buildLiveScreen() : _buildCountdownScreen(),
    );
  }

  Widget _buildCountdownScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A0E27),
            const Color(0xFF1A1E3F),
            const Color(0xFF0A0E27),
          ],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // Background animated circles
            ...List.generate(5, (index) {
              return AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, child) {
                  return Positioned(
                    left: (index * 100.0) + (_shimmerController.value * 50),
                    top: 100 + (index * 80.0),
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _awardCategories[index]['color'].withAlpha((0.2 * 255).round()),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
            
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.notifications_active, color: Colors.white),
                                  const SizedBox(width: 12),
                                  const Text('🔔 You\'ll be notified when the live stream starts!'),
                                ],
                              ),
                              backgroundColor: const Color(0xFF00FF94),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.1 * 255).round()),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withAlpha((0.2 * 255).round()),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_active,
                                color: Colors.white.withAlpha((0.7 * 255).round()),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Notify Me',
                                style: TextStyle(
                                  color: Colors.white.withAlpha((0.9 * 255).round()),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        
                        // Main title
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              const Color(0xFFFFD700),
                              const Color(0xFFFFB800),
                              const Color(0xFFFF6B9D),
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'ARTIST AWARDS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          '2025 LIVE CEREMONY',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.7 * 255).round()),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 60),
                        
                        // Live preview card (small embedded stream preview)
                        Container(
                          height: 200,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFFFD700).withAlpha((0.5 * 255).round()),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withAlpha((0.3 * 255).round()),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                // Simulated stream preview
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFF1A1E3F),
                                        const Color(0xFF2A2E4F),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                // Animated stage lights effect
                                AnimatedBuilder(
                                  animation: _shimmerController,
                                  builder: (context, child) {
                                    return CustomPaint(
                                      painter: _StageLightsPainter(_shimmerController.value),
                                      size: const Size(double.infinity, 200),
                                    );
                                  },
                                ),
                                
                                // Center stage icon
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha((0.3 * 255).round()),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.mic,
                                      color: Color(0xFFFFD700),
                                      size: 60,
                                    ),
                                  ),
                                ),
                                
                                // "COMING SOON" label
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6B9D),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'LIVE SOON',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 60),
                        
                        // Countdown timer
                        Text(
                          'GOING LIVE IN',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.6 * 255).round()),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Animated countdown display - ALL NUMBERS IN ONE LINE (Fixed overflow)
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final duration = _countdownDuration;
                            final hours = duration.inHours;
                            final minutes = duration.inMinutes.remainder(60);
                            final seconds = duration.inSeconds.remainder(60);
                            
                            return Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.05),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFFFFD700).withAlpha((0.2 * 255).round()),
                                          const Color(0xFFFF6B9D).withAlpha((0.2 * 255).round()),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFFFD700).withAlpha((0.5 * 255).round()),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFFD700).withAlpha((0.3 * 255).round()),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Hours
                                        _buildTimeUnit(hours.toString().padLeft(2, '0'), 'HOURS'),
                                        const SizedBox(width: 10),
                                        const Text(
                                          ':',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 48,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // Minutes
                                        _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'MINUTES'),
                                        const SizedBox(width: 10),
                                        const Text(
                                          ':',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 48,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // Seconds
                                        _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'SECONDS'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Quick action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildQuickActionButton(
                              'Skip to Live',
                              Icons.fast_forward,
                              const Color(0xFF00FF94),
                              () {
                                setState(() {
                                  _isLive = true;
                                  _countdownTimer?.cancel();
                                });
                              },
                            ),
                            const SizedBox(width: 16),
                            _buildQuickActionButton(
                              'Share Event',
                              Icons.share,
                              const Color(0xFF00D9FF),
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(Icons.share, color: Colors.white),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text('🔗 Event link copied! Share with your friends.'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF00D9FF),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    duration: const Duration(seconds: 3),
                                    action: SnackBarAction(
                                      label: 'OK',
                                      textColor: Colors.white,
                                      onPressed: () {},
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 60),
                        
                        // Award categories preview
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.05 * 255).round()),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withAlpha((0.1 * 255).round()),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _categoriesTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ...List.generate(_categories.isNotEmpty ? _categories.length : _awardCategories.length, (index) {
                                // Use dynamic categories if available, otherwise fall back to default
                                if (_categories.isNotEmpty) {
                                  final category = _categories[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          category.color.withAlpha((0.15 * 255).round()),
                                          category.color.withAlpha((0.05 * 255).round()),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: category.color.withAlpha((0.3 * 255).round()),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: category.color.withAlpha((0.2 * 255).round()),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            category.icon,
                                            color: category.color,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                category.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${category.nominees.length} Nominees',
                                                style: TextStyle(
                                                  color: Colors.white.withAlpha((0.6 * 255).round()),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          color: category.color,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  // Fallback to default categories
                                  final category = _awardCategories[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          category['color'].withAlpha((0.15 * 255).round()),
                                          category['color'].withAlpha((0.05 * 255).round()),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: category['color'].withAlpha((0.3 * 255).round()),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: category['color'].withAlpha((0.2 * 255).round()),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            category['icon'],
                                            color: category['color'],
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                category['title'],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${category['nominees']} Nominees',
                                                style: TextStyle(
                                                  color: Colors.white.withAlpha((0.6 * 255).round()),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          color: category['color'],
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha((0.6 * 255).round()),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withAlpha((0.3 * 255).round()),
              color.withAlpha((0.15 * 255).round()),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: color.withAlpha((0.5 * 255).round()),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveScreen() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Top bar - StreamTV style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF6B7FD7),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.1 * 255).round()),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() => _isLive = false);
                      _startCountdown();
                    },
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Artist TV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _startBroadcasting,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isBroadcasting ? Colors.red : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isLoadingCamera)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B7FD7)),
                              ),
                            )
                          else
                            Icon(
                              _isBroadcasting ? Icons.stop_circle : Icons.videocam,
                              color: _isBroadcasting ? Colors.white : const Color(0xFF6B7FD7),
                              size: 18,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _isBroadcasting ? 'Stop Broadcasting' : 'Start Broadcasting',
                            style: TextStyle(
                              color: _isBroadcasting ? Colors.white : const Color(0xFF6B7FD7),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Hero banner
                    Container(
                      width: double.infinity,
                      height: 250,
                      color: const Color(0xFF6B7FD7),
                      child: Stack(
                        children: [
                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF6B7FD7),
                                  const Color(0xFF8B9FE7),
                                ],
                              ),
                            ),
                          ),
                          
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Go live in one click.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'No signup, no login, no setup',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                GestureDetector(
                                  onTap: _startBroadcasting,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _isBroadcasting ? Colors.red : Colors.white,
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha((0.2 * 255).round()),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_isLoadingCamera)
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B7FD7)),
                                            ),
                                          )
                                        else ...[
                                          Text(
                                            _isBroadcasting ? 'Stop Broadcasting' : 'Start Broadcasting',
                                            style: TextStyle(
                                              color: _isBroadcasting ? Colors.white : const Color(0xFF6B7FD7),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: _isBroadcasting ? Colors.white : const Color(0xFFFF6B9D),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              _isBroadcasting ? Icons.stop : Icons.play_arrow,
                                              color: _isBroadcasting ? Colors.red : Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Main streaming area
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Live stream preview
                          Container(
                            width: double.infinity,
                            height: 400,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                                width: 2,
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Real camera preview or placeholder
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: _isBroadcasting && _isCameraInitialized && _cameraController != null
                                      ? SizedBox.expand(
                                          child: FittedBox(
                                            fit: BoxFit.cover,
                                            child: SizedBox(
                                              width: _cameraController!.value.previewSize!.height,
                                              height: _cameraController!.value.previewSize!.width,
                                              child: CameraPreview(_cameraController!),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFF6B7FD7),
                                                Color(0xFF8B9FE7),
                                                Color(0xFFABBFF7),
                                              ],
                                            ),
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                if (_isLoadingCamera)
                                                  const Column(
                                                    children: [
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 4,
                                                      ),
                                                      SizedBox(height: 20),
                                                      Text(
                                                        'Starting camera...',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                else if (_cameraError != null)
                                                  Column(
                                                    children: [
                                                      const Icon(
                                                        Icons.error_outline,
                                                        color: Colors.white,
                                                        size: 80,
                                                      ),
                                                      const SizedBox(height: 20),
                                                      Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 40),
                                                        child: Text(
                                                          _cameraError!,
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 20),
                                                      ElevatedButton.icon(
                                                        onPressed: _startBroadcasting,
                                                        icon: const Icon(Icons.refresh),
                                                        label: const Text('Try Again'),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.white,
                                                          foregroundColor: const Color(0xFF6B7FD7),
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 24,
                                                            vertical: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                else
                                                  Column(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.all(30),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white.withAlpha((0.2 * 255).round()),
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: const Icon(
                                                          Icons.videocam,
                                                          color: Colors.white,
                                                          size: 80,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 20),
                                                      const Text(
                                                        'ARTIST AWARDS 2025',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 28,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.all(6),
                                                            decoration: const BoxDecoration(
                                                              color: Colors.orange,
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: const Icon(
                                                              Icons.videocam_off,
                                                              color: Colors.white,
                                                              size: 16,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          const Text(
                                                            'NOT BROADCASTING',
                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.w600,
                                                              letterSpacing: 2,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 20),
                                                      const Text(
                                                        'Click "Start Broadcasting" to go live',
                                                        style: TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                                
                                // LIVE badge - only show when actually broadcasting
                                if (_isBroadcasting && _isCameraInitialized)
                                  Positioned(
                                    top: 16,
                                    left: 16,
                                    child: AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, child) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.red.withAlpha(((0.5 + _pulseController.value * 0.5) * 255).round()),
                                                blurRadius: 15,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 10,
                                                height: 10,
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'LIVE',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                
                                // Viewer count - only show when broadcasting
                                if (_isBroadcasting && _isCameraInitialized)
                                  Positioned(
                                    top: 16,
                                    right: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withAlpha((0.5 * 255).round()),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.visibility,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            '12,458',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                
                                // Start Broadcasting button overlay when not broadcasting
                                if (!_isBroadcasting && !_isLoadingCamera)
                                  Center(
                                    child: GestureDetector(
                                      onTap: _startBroadcasting,
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withAlpha((0.2 * 255).round()),
                                              blurRadius: 20,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Color(0xFF6B7FD7),
                                          size: 50,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // LIVE VOTING SECTION - Admin configured artists
                          if (_liveSettings?.liveVotingArtist1 != null && _liveSettings?.liveVotingArtist2 != null)
                            _buildLiveVotingSection(),
                          
                          if (_liveSettings?.liveVotingArtist1 != null && _liveSettings?.liveVotingArtist2 != null)
                            const SizedBox(height: 32),
                          
                          // How it works
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'How it works',
                                  style: TextStyle(
                                    color: Color(0xFF1A1E3F),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildHowItWorksCard(
                                        '1',
                                        'Start a stream',
                                        'Live in seconds.\nNo app download or\naccount setup required.',
                                        const Color(0xFF6B7FD7),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildHowItWorksCard(
                                        '2',
                                        'Share the link',
                                        'Send the private stream link to guests.\nView or screen record the stream from any device.',
                                        const Color(0xFF8B9FE7),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildHowItWorksCard(
                                        '3',
                                        'Let them watch live',
                                        'Up to 2,000 guests can watch simultaneously.\nNo download, login or signup required.',
                                        const Color(0xFFABBFF7),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Broadcast your world section
                          const Text(
                            'Broadcast Your World',
                            style: TextStyle(
                              color: Color(0xFF1A1E3F),
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Category cards
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.3,
                            children: [
                              _buildBroadcastCard(
                                'Music Performance',
                                Icons.music_note,
                                const Color(0xFFFF6B9D),
                              ),
                              _buildBroadcastCard(
                                'Acting Showcase',
                                Icons.movie,
                                const Color(0xFFFFB800),
                              ),
                              _buildBroadcastCard(
                                'Award Ceremony',
                                Icons.emoji_events,
                                const Color(0xFF00FF94),
                              ),
                              _buildBroadcastCard(
                                'Live Interview',
                                Icons.mic,
                                const Color(0xFF00D9FF),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksCard(String number, String title, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withAlpha((0.3 * 255).round()),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1A1E3F),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: const Color(0xFF1A1E3F).withAlpha((0.7 * 255).round()),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastCard(String title, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha((0.15 * 255).round()),
            color.withAlpha((0.05 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withAlpha((0.3 * 255).round()),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 40,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildLiveVotingSection() {
    if (_liveSettings == null) return const SizedBox.shrink();
    
    final artist1 = _liveSettings!.liveVotingArtist1 ?? 'Artist 1';
    final artist2 = _liveSettings!.liveVotingArtist2 ?? 'Artist 2';
    final votes1 = _liveSettings!.votesForArtist1;
    final votes2 = _liveSettings!.votesForArtist2;
    final totalVotes = votes1 + votes2;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF6B9D).withAlpha((0.15 * 255).round()),
            const Color(0xFF00D9FF).withAlpha((0.15 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD700).withAlpha((0.5 * 255).round()),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withAlpha((0.2 * 255).round()),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.pink.shade400],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withAlpha((0.3 * 255).round()),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(Icons.how_to_vote, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE VOTING',
                      style: TextStyle(
                        color: Color(0xFF1A1E3F),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Vote for your favorite artist!',
                      style: TextStyle(
                        color: Color(0xFF6B7FD7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _voteForArtist(1),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade800, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withAlpha((0.4 * 255).round()),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.person, color: Colors.white, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          artist1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.3 * 255).round()),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$votes1 votes',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (totalVotes > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${(votes1 / totalVotes * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1E3F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => _voteForArtist(2),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade400, Colors.purple.shade600],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.purple.shade800, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withAlpha((0.4 * 255).round()),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.person, color: Colors.white, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          artist2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.3 * 255).round()),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$votes2 votes',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (totalVotes > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${(votes2 / totalVotes * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Future<void> _voteForArtist(int artistNumber) async {
    if (_liveSettings == null) return;
    
    setState(() {
      if (artistNumber == 1) {
        _liveSettings!.votesForArtist1++;
      } else {
        _liveSettings!.votesForArtist2++;
      }
    });
    
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('live_settings', jsonEncode(_liveSettings!.toJson()));
    
    // Show confirmation
    if (mounted) {
      final artistName = artistNumber == 1 
          ? _liveSettings!.liveVotingArtist1 
          : _liveSettings!.liveVotingArtist2;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Voted for $artistName!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Custom painter for stage lights effect
class _StageLightsPainter extends CustomPainter {
  final double progress;

  _StageLightsPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw moving spotlights
    for (int i = 0; i < 3; i++) {
      final x = (size.width / 3) * i + (progress * size.width / 3);
      final gradient = RadialGradient(
        colors: [
          const Color(0xFFFFD700).withAlpha((0.3 * 255).round()),
          Colors.transparent,
        ],
      );
      
      paint.shader = gradient.createShader(
        Rect.fromCircle(
          center: Offset(x % size.width, size.height * 0.5),
          radius: 100,
        ),
      );
      
      canvas.drawCircle(
        Offset(x % size.width, size.height * 0.5),
        100,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
