import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../models/media_models.dart';
import '../services/betting_data_store.dart';
import '../services/broadcast_service.dart';
import 'category_detail_screen.dart';
import 'tickets/face_recognition_login_screen.dart';
import 'media_testing_lab_screen.dart';

/// Artist Awards Live Streaming Platform
/// Promoting community artists with live awards ceremonies
class ArtistAwardsLiveScreen extends StatefulWidget {
  const ArtistAwardsLiveScreen({super.key});

  @override
  State<ArtistAwardsLiveScreen> createState() => _ArtistAwardsLiveScreenState();
}

class _ArtistAwardsLiveScreenState extends State<ArtistAwardsLiveScreen> with TickerProviderStateMixin {
  bool _isBroadcasting = false;
  Duration _countdownDuration = const Duration(hours: 2, minutes: 30, seconds: 45);
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  
  // Camera variables
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  
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
      _categoriesTitle = _liveSettings!.categoriesTitle;
      // Admin manually enabled live is checked via _liveSettings!.isLiveManuallyEnabled
    } else {
      _liveSettings = LiveSettings();
    }
    
    // Calculate remaining time from saved timestamp
    final startTime = prefs.getInt('media_countdown_start');
    final durationSeconds = prefs.getInt('media_countdown_duration');
    
    if (startTime != null && durationSeconds != null) {
      final elapsed = (DateTime.now().millisecondsSinceEpoch - startTime) ~/ 1000;
      final remaining = durationSeconds - elapsed;
      _countdownDuration = Duration(seconds: remaining > 0 ? remaining : 0);
    } else {
      // Fallback to old method if no persistent timer is set
      _countdownDuration = _liveSettings!.countdownDuration;
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
      // Silently handle camera initialization errors
      debugPrint('Failed to get cameras: $e');
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

    // Start broadcasting
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
          // Countdown finished - UI will react to _countdownDuration.inSeconds <= 0
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: Stack(
        children: [
          _buildUnifiedScreen(), // Single unified screen with all content
          // Floating header - positioned over content  
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              child: _buildCompactHeader(),
            ),
          ),
        ],
      ),
    );
  }

  // Unified screen with all content on one scrollable page
  Widget _buildUnifiedScreen() {
    final isCountdownFinished = _countdownDuration.inSeconds <= 0;
    final shouldShowBroadcast = _isBroadcasting || (_liveSettings?.isLiveManuallyEnabled ?? false);
    
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
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 0), // Extra top padding for floating header
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Large broadcast frame (350px) - shows mic until countdown ends, then shows broadcast
                    _buildLargeBroadcastFrame(isCountdownFinished, shouldShowBroadcast),
                    
                    const SizedBox(height: 16),
                    
                    // Countdown timer BELOW broadcast frame with ID button (between broadcast and voting)
                    if (!isCountdownFinished && !_isBroadcasting)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            // ID Button (Left)
                            _buildSideButton(
                              icon: Icons.badge,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const FaceRecognitionLoginScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            // Countdown (Center - wider)
                            Expanded(
                              flex: 3,
                              child: _buildCompactCountdownDisplay(),
                            ),
                            const SizedBox(width: 12),
                            // Media Testing Lab Button (Right)
                            _buildSideButton(
                              icon: Icons.video_settings,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const MediaTestingLabScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                    
                    // Live voting section (only show after countdown or when admin enables)
                    if (isCountdownFinished || shouldShowBroadcast)
                      _buildLiveVotingSection(),
                    
                    const SizedBox(height: 30),
                    
                    // Categories section
                    _buildCategoriesSection(),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Compact one-line header bar
  Widget _buildCompactHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A1A3F).withAlpha((0.95 * 255).round()),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.4 * 255).round()),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFFFFD700).withAlpha((0.15 * 255).round()),
              blurRadius: 30,
              spreadRadius: -5,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: Colors.white.withAlpha((0.15 * 255).round()),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4), // Reduced padding for more space
                      child: FittedBox(
                        fit: BoxFit.fitWidth, // Fill the entire width available
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFFFD700),
                              Color(0xFFFF6B35),
                              Color(0xFFE11584),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            _liveSettings?.ceremonyHeader ?? 'ARTIST AWARDS 2025 LIVE CEREMONY',
                            style: const TextStyle(
                              fontSize: 32, // Much larger base font size to fill the bar better
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.8, // Increased letter spacing for better distribution
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Balance for back button
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Large broadcast frame (350px) - YouTube-style frame
  Widget _buildLargeBroadcastFrame(bool isCountdownFinished, bool shouldShowBroadcast) {
    final broadcast = BroadcastService.instance;
    
    return Container(
      height: 350, // Large frame as requested
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD700).withAlpha((0.5 * 255).round()),
          width: 3,
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
        child: AnimatedBuilder(
          animation: broadcast,
          builder: (context, child) {
            return Stack(
              children: [
                // Show admin broadcast if live, otherwise show local camera or background
                if (broadcast.isLive)
                  _buildAdminBroadcastView(broadcast)
                else if (_isBroadcasting && _isCameraInitialized && _cameraController != null)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraController!.value.previewSize!.height,
                        height: _cameraController!.value.previewSize!.width,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  )
                else
                  // Background when NOT broadcasting
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
            
                // Animated stage lights effect (only when NOT broadcasting and admin NOT live)
                if (!_isBroadcasting && !broadcast.isLive)
                  AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _StageLightsPainter(_shimmerController.value),
                        size: const Size(double.infinity, 350),
                      );
                    },
                  ),
            
                // Center mic icon (only when NOT broadcasting and admin NOT live)
                if (!_isBroadcasting && !broadcast.isLive)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.3 * 255).round()),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic,
                        color: Color(0xFFFFD700),
                        size: 80,
                      ),
                    ),
                  ),
            
                // Status badge - changes based on admin broadcast, countdown and broadcasting state
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (broadcast.isLive || _isBroadcasting)
                          ? Colors.red 
                          : (isCountdownFinished ? const Color(0xFF00FF94) : const Color(0xFFFF6B9D)),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: (broadcast.isLive || _isBroadcasting)
                          ? [
                              BoxShadow(
                                color: Colors.red.withAlpha((0.6 * 255).round()),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (broadcast.isLive || _isBroadcasting)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withAlpha(
                                    ((0.5 + (0.5 * _pulseController.value)) * 255).round(),
                                  ),
                                ),
                              );
                            },
                          ),
                        Text(
                          (broadcast.isLive || _isBroadcasting)
                              ? 'LIVE NOW' 
                              : (isCountdownFinished ? 'READY TO GO LIVE' : 'LIVE SOON'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            
                // No countdown overlay inside frame anymore - it's now below the frame
            
                // Admin controls overlay (only show when admin is NOT broadcasting)
                // Hide completely when admin broadcast is active to avoid distractions
                if ((isCountdownFinished || shouldShowBroadcast) && 
                    _isAdminUser() && 
                    !broadcast.isLive)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.7 * 255).round()),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withAlpha((0.3 * 255).round()),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildControlButton(
                            icon: _isBroadcasting ? Icons.stop_circle : Icons.videocam,
                            label: _isBroadcasting ? 'Stop' : 'Go Live',
                            color: _isBroadcasting ? Colors.red : const Color(0xFF00FF94),
                            onTap: _startBroadcasting,
                            enabled: _isBroadcasting || (_liveSettings?.allowUsersToGoLive ?? true),
                          ),
                          if (_isBroadcasting) ...[
                            _buildControlButton(
                              icon: Icons.cameraswitch,
                              label: 'Flip',
                              color: Colors.blue,
                              onTap: _flipCamera,
                            ),
                            _buildControlButton(
                              icon: Icons.fullscreen,
                              label: 'Fullscreen',
                              color: Colors.purple,
                              onTap: _toggleFullscreen,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Build admin broadcast view for users to watch
  Widget _buildAdminBroadcastView(BroadcastService broadcast) {
    switch (broadcast.currentSource) {
      case BroadcastSource.camera:
        if (broadcast.isCameraInitialized && broadcast.cameraController != null) {
          return SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: broadcast.cameraController!.value.previewSize!.height,
                height: broadcast.cameraController!.value.previewSize!.width,
                child: CameraPreview(broadcast.cameraController!),
              ),
            ),
          );
        }
        break;

      case BroadcastSource.screen:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withAlpha((0.9 * 255).round()),
                Colors.grey.shade900,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha((0.2 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.screen_share,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '📱 ADMIN IS BROADCASTING',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Screen sharing active',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );

      case BroadcastSource.video:
        if (broadcast.selectedVideo != null && broadcast.videoController != null) {
          // Show actual video playback for users
          if (broadcast.videoController!.value.isInitialized) {
            return SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: broadcast.videoController!.value.size.width,
                  height: broadcast.videoController!.value.size.height,
                  child: VideoPlayer(broadcast.videoController!),
                ),
              ),
            );
          } else {
            // Loading video
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withAlpha((0.9 * 255).round()),
                    Colors.grey.shade900,
                  ],
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 16),
                    Text(
                      'Loading video...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }
        } else if (broadcast.selectedVideo != null) {
          // Fallback when video controller not available
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withAlpha((0.9 * 255).round()),
                  Colors.grey.shade900,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha((0.2 * 255).round()),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_circle_filled,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '🎬 ADMIN IS BROADCASTING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Video streaming active',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.7 * 255).round()),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        break;

      case BroadcastSource.none:
        break;
    }

    return Container(
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
    );
  }

  // Helper to check if current user is admin
  bool _isAdminUser() {
    // For now, return true for testing purposes
    // In production, this should check actual admin credentials
    return true;
  }

  // Control button for broadcast controls
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔒 Go Live access has been disabled by admin'),
            backgroundColor: Colors.red,
          ),
        );
      },
      child: Opacity(
        opacity: enabled ? 1.0 : 0.6, // Slightly fade when disabled
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha((0.2 * 255).round()),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Compact countdown display - NOW 3X SMALLER and shown BELOW broadcast frame
  Widget _buildCompactCountdownDisplay() {
    final days = _countdownDuration.inDays;
    final hours = _countdownDuration.inHours.remainder(24);
    final minutes = _countdownDuration.inMinutes.remainder(60);
    final seconds = _countdownDuration.inSeconds.remainder(60);
    
    return Container(
      height: 60, // Fixed height to match buttons
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withAlpha((0.3 * 255).round()),
            const Color(0xFFFF6B9D).withAlpha((0.3 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFFFD700).withAlpha((0.5 * 255).round()),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTimeUnit(days.toString().padLeft(2, '0'), 'DD'),
          const Text(' : ', style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold)),
          _buildTimeUnit(hours.toString().padLeft(2, '0'), 'HH'),
          const Text(' : ', style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold)),
          _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'MM'),
          const Text(' : ', style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold)),
          _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'SS'),
        ],
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
            color: Color(0xFFFFD700),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha((0.5 * 255).round()),
            fontSize: 6,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ID / Ticket Creation Button
  Widget _buildSideButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60, // Match countdown height
        width: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF4A90E2).withAlpha((0.3 * 255).round()),
              const Color(0xFF6B4AE2).withAlpha((0.3 * 255).round()),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF4A90E2).withAlpha((0.6 * 255).round()),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF4A90E2),
          size: 28,
        ),
      ),
    );
  }

  /* REMOVED: Old unused countdown screen method
  Widget _buildOldCountdownScreen() {
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
                                // Show camera preview if broadcasting, otherwise show stage background
                                if (_isBroadcasting && _isCameraInitialized && _cameraController != null)
                                  SizedBox.expand(
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: _cameraController!.value.previewSize!.height,
                                        height: _cameraController!.value.previewSize!.width,
                                        child: CameraPreview(_cameraController!),
                                      ),
                                    ),
                                  )
                                else
                                  // Simulated stream preview (background when NOT broadcasting)
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
                                
                                // Animated stage lights effect (only when NOT broadcasting)
                                if (!_isBroadcasting)
                                  AnimatedBuilder(
                                    animation: _shimmerController,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        painter: _StageLightsPainter(_shimmerController.value),
                                        size: const Size(double.infinity, 200),
                                      );
                                    },
                                  ),
                                
                                // Center stage icon (only when NOT broadcasting)
                                if (!_isBroadcasting)
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
                                
                                // Status label - changes based on broadcasting state
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _isBroadcasting ? Colors.red : const Color(0xFFFF6B9D),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: _isBroadcasting
                                          ? [
                                              BoxShadow(
                                                color: Colors.red.withAlpha((0.6 * 255).round()),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_isBroadcasting)
                                          AnimatedBuilder(
                                            animation: _pulseController,
                                            builder: (context, child) {
                                              return Container(
                                                width: 8,
                                                height: 8,
                                                margin: const EdgeInsets.only(right: 6),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white.withAlpha(
                                                    ((0.5 + (0.5 * _pulseController.value)) * 255).round(),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        Text(
                                          _isBroadcasting ? 'LIVE NOW' : 'LIVE SOON',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
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
  */ // END OF REMOVED _buildOldCountdownScreen

  /* REMOVED: Old unused live screen method  
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
  */ // END OF REMOVED _buildLiveScreen
  
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(16),
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Profile picture or icon and vote count side-by-side at top (Artist 1)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Artist 1 Profile Picture
                            _liveSettings?.artist1ImageUrl != null && _liveSettings!.artist1ImageUrl!.isNotEmpty
                                ? Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha((0.3 * 255).round()),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: _liveSettings!.artist1ImageUrl!.startsWith('http')
                                          ? Image.network(
                                              _liveSettings!.artist1ImageUrl!,
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => 
                                                  const Icon(Icons.person, color: Colors.white, size: 24),
                                            )
                                          : Image.file(
                                              File(_liveSettings!.artist1ImageUrl!),
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => 
                                                  const Icon(Icons.person, color: Colors.white, size: 24),
                                            ),
                                    ),
                                  )
                                : const Icon(Icons.person, color: Colors.white, size: 36),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha((0.3 * 255).round()),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '$votes1',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (totalVotes > 0) ...[
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '(${(votes1 / totalVotes * 100).toStringAsFixed(0)}%)',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Artist name at bottom - FILLS THE WIDTH
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              artist1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1E3F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _voteForArtist(2),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade400, Colors.purple.shade600],
                      ),
                      borderRadius: BorderRadius.circular(16),
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Profile picture or icon and vote count side-by-side at top (Artist 2)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Artist 2 Profile Picture
                            _liveSettings?.artist2ImageUrl != null && _liveSettings!.artist2ImageUrl!.isNotEmpty
                                ? Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha((0.3 * 255).round()),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: _liveSettings!.artist2ImageUrl!.startsWith('http')
                                          ? Image.network(
                                              _liveSettings!.artist2ImageUrl!,
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => 
                                                  const Icon(Icons.person, color: Colors.white, size: 24),
                                            )
                                          : Image.file(
                                              File(_liveSettings!.artist2ImageUrl!),
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => 
                                                  const Icon(Icons.person, color: Colors.white, size: 24),
                                            ),
                                    ),
                                  )
                                : const Icon(Icons.person, color: Colors.white, size: 36),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha((0.3 * 255).round()),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '$votes2',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (totalVotes > 0) ...[
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '(${(votes2 / totalVotes * 100).toStringAsFixed(0)}%)',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Artist name at bottom - FILLS THE WIDTH
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              artist2,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
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
  
  // Categories section
  Widget _buildCategoriesSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withAlpha((0.1 * 255).round()),
            Colors.white.withAlpha((0.05 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha((0.2 * 255).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events,
                color: Color(0xFFFFD700),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                _categoriesTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // If we have categories from settings, show them
          if (_categories.isNotEmpty)
            ..._categories.map((category) {
              final categoryIndex = _categories.indexOf(category);
              return GestureDetector(
                onTap: () => _onCategoryTap(category, categoryIndex),
                // NO long press - users cannot edit/delete
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.08 * 255).round()),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: category.color.withAlpha((0.4 * 255).round()),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: category.color.withAlpha((0.2 * 255).round()),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [category.color, category.color.withAlpha((0.7 * 255).round())],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: category.color.withAlpha((0.3 * 255).round()),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(category.icon, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              category.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // NO edit/delete buttons for users - managed in admin panel only
                        ],
                      ),
                      if (category.nominees.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...category.nominees.map((nominee) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 16,
                                  color: category.color.withAlpha((0.7 * 255).round()),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  nominee.artistName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withAlpha((0.8 * 255).round()),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              );
            })
          else
            // Default categories if none configured
            ..._awardCategories.map((category) {
              return GestureDetector(
                onTap: () => _onDefaultCategoryTap(category),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.05 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (category['color'] as Color).withAlpha((0.3 * 255).round()),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        category['icon'] as IconData,
                        color: category['color'] as Color,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          category['title'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (category['color'] as Color).withAlpha((0.2 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${category['nominees']} nominees',
                          style: TextStyle(
                            color: category['color'] as Color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
  
  Future<void> _voteForArtist(int artistNumber) async {
    if (_liveSettings == null) return;
    
    // Get current username
    final prefs = await SharedPreferences.getInstance();
    final store = BettingDataStore.instance;
    final username = store.username;
    
    // Check if user has already voted in this broadcast session
    final currentBroadcast = _liveSettings!.currentBroadcastId ?? 'default';
    final votersInThisBroadcast = _liveSettings!.broadcastVotes[currentBroadcast] ?? {};
    
    if (votersInThisBroadcast.contains(username)) {
      // User already voted in this session
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ You have already voted in this broadcast session!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    setState(() {
      if (artistNumber == 1) {
        _liveSettings!.votesForArtist1++;
      } else {
        _liveSettings!.votesForArtist2++;
      }
      
      // Record that this user has voted in this broadcast
      if (_liveSettings!.broadcastVotes[currentBroadcast] == null) {
        _liveSettings!.broadcastVotes[currentBroadcast] = {};
      }
      _liveSettings!.broadcastVotes[currentBroadcast]!.add(username);
    });
    
    // Save to SharedPreferences
    await prefs.setString('live_settings', jsonEncode(_liveSettings!.toJson()));
    
    // Show confirmation
    if (mounted) {
      final artistName = artistNumber == 1 
          ? _liveSettings!.liveVotingArtist1 
          : _liveSettings!.liveVotingArtist2;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Vote locked for $artistName! Cannot change vote.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  // Category tap handler - Now opens category detail page
  void _onCategoryTap(CategoryModel category, int index) {
    // Navigate to category detail page where users can see content
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return CategoryDetailScreen(
            category: category,
            isAdmin: _isAdminUser(),
            onUpdate: (updatedCategory) {
              setState(() {
                _categories[index] = updatedCategory;
              });
              _saveCategories();
            },
          );
        },
      ),
    );
  }
  
  // Default category tap handler
  void _onDefaultCategoryTap(Map<String, dynamic> category) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${category['title']} - ${category['nominees']} nominees'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  // Flip camera between front and back
  Future<void> _flipCamera() async {
    if (!_isCameraInitialized || _cameras.isEmpty) return;
    
    try {
      // Get current camera direction
      final currentCamera = _cameraController!.description;
      final isCurrentlyFront = currentCamera.lensDirection == CameraLensDirection.front;
      
      // Find the opposite camera
      final newCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == (isCurrentlyFront ? CameraLensDirection.back : CameraLensDirection.front),
        orElse: () => _cameras.first,
      );
      
      // Dispose current controller
      await _cameraController?.dispose();
      
      // Initialize new camera
      _cameraController = CameraController(
        newCamera,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error flipping camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to flip camera')),
        );
      }
    }
  }
  
  // Toggle fullscreen broadcast
  void _toggleFullscreen() {
    if (!_isBroadcasting) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              if (_isCameraInitialized && _cameraController != null)
                Center(
                  child: AspectRatio(
                    aspectRatio: _cameraController!.value.aspectRatio,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                top: 40,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.white, size: 8),
                      SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
      ),
    );
  }
  
  // Save categories to SharedPreferences
  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('media_categories', jsonEncode(_categories.map((c) => c.toJson()).toList()));
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
