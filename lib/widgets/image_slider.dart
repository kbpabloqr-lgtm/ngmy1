import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:io';

class ImageSlider extends StatefulWidget {
  final List<String> imageUrls;
  final double aspectRatio; // 1280/720 = 16:9 ratio
  final int slideDurationSeconds;
  final String? defaultAssetImage;
  
  const ImageSlider({
    super.key,
    required this.imageUrls,
    this.aspectRatio = 16 / 9, // YouTube thumbnail aspect ratio
    this.slideDurationSeconds = 4, // Default 4 seconds
    this.defaultAssetImage,
  });

  @override
  State<ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<ImageSlider> {
  late PageController _pageController;
  int _currentIndex = 0;
  Timer? _autoSlideTimer;
  final Map<int, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Delay initialization to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.imageUrls.isNotEmpty) {
        _startAutoSlide();
        // Only preload first slide after UI is ready
        _initializeVideoIfNeeded(0);
      }
    });
  }

  void _initializeVideoIfNeeded(int index) {
    final mediaPath = widget.imageUrls[index];
    
    if (_isVideoFile(mediaPath) && !_videoControllers.containsKey(index)) {
      VideoPlayerController controller;
      try {
        if (mediaPath.startsWith('http')) {
          controller = VideoPlayerController.networkUrl(Uri.parse(mediaPath));
        } else {
          controller = VideoPlayerController.file(File(mediaPath));
        }
        
        _videoControllers[index] = controller;
        
        controller.initialize().then((_) {
          if (mounted) {
            setState(() {});
            controller.setLooping(true);
            controller.setVolume(1.0);
            // Auto-play if this is the current slide
            if (index == _currentIndex) {
              controller.play();
            }
          }
        }).catchError((error) {
          // print removed to avoid production logging
        });
      } catch (e) {
  // print removed to avoid production logging
      }
    }
  }

  @override
  void didUpdateWidget(covariant ImageSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls != widget.imageUrls || 
        oldWidget.slideDurationSeconds != widget.slideDurationSeconds) {
      _autoSlideTimer?.cancel();
      // Dispose old video controllers
      for (var controller in _videoControllers.values) {
        controller.dispose();
      }
      _videoControllers.clear();
      _currentIndex = 0;
      if (widget.imageUrls.isNotEmpty) {
        _startAutoSlide();
        _initializeVideoIfNeeded(0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoSlideTimer?.cancel();
    // Dispose all video controllers
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    super.dispose();
  }

  void _startAutoSlide() {
    _autoSlideTimer = Timer.periodic(Duration(seconds: widget.slideDurationSeconds), (timer) {
      if (widget.imageUrls.isNotEmpty) {
        final nextIndex = (_currentIndex + 1) % widget.imageUrls.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
        // Prefetch next image to avoid jank when sliding
        if (mounted && widget.imageUrls[nextIndex].startsWith('http')) {
          precacheImage(NetworkImage(widget.imageUrls[nextIndex]), context);
        }
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    // Initialize video for current slide if needed
    _initializeVideoIfNeeded(index);
    
    // Preload next video
    final nextIndex = (index + 1) % widget.imageUrls.length;
    _initializeVideoIfNeeded(nextIndex);
    
    // Pause all videos except the current one and auto-play current
    _videoControllers.forEach((key, controller) {
      if (key == index) {
        // Current video - ensure it's playing
        if (controller.value.isInitialized && !controller.value.isPlaying) {
          controller.play();
        }
      } else {
        // Other videos - pause them
        if (controller.value.isPlaying) {
          controller.pause();
        }
      }
    });
  }

  bool _isVideoFile(String filePath) {
    final videoExtensions = ['.mp4', '.avi', '.mov', '.mkv', '.wmv', '.flv', '.webm'];
    return videoExtensions.any((ext) => filePath.toLowerCase().endsWith(ext));
  }

  Widget _buildMediaWidget(int index) {
    final mediaPath = widget.imageUrls[index];
    
    // Check if it's a video file
    if (_isVideoFile(mediaPath)) {
      return _buildVideoWidget(index);
    }
    
    // Handle images (network or local) - NO loading indicators
    if (mediaPath.startsWith('http')) {
      return Image.network(
        mediaPath,
        fit: BoxFit.cover,
        cacheWidth: 1920,
        cacheHeight: 1080,
        errorBuilder: (context, error, stackTrace) =>
            _buildPlaceholderImage(index),
      );
    } else {
      return Image.file(
        File(mediaPath),
        fit: BoxFit.cover,
        cacheWidth: 1920,
        cacheHeight: 1080,
        errorBuilder: (context, error, stackTrace) =>
            _buildPlaceholderImage(index),
      );
    }
  }

  Widget _buildVideoWidget(int index) {
    final controller = _videoControllers[index];
    
    // Controller should already be initialized from preload
    if (controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, color: Colors.white54, size: 48),
              SizedBox(height: 8),
              Text(
                'Video not available',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }
    
    if (!controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Loading video...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }
    
    // Make sure video is playing
    if (!controller.value.isPlaying && controller.value.isInitialized) {
      controller.play();
    }
    
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        // Custom video controls (seek only, no pause)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withAlpha((0.7 * 255).round()),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                // Current time
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    return Text(
                      _formatDuration(value.position),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                // Seek bar
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      final position = value.position.inMilliseconds.toDouble();
                      final duration = value.duration.inMilliseconds.toDouble();
                      return SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        ),
                        child: Slider(
                          value: duration > 0 ? position.clamp(0, duration) : 0,
                          min: 0,
                          max: duration > 0 ? duration : 1,
                          activeColor: Colors.white,
                          inactiveColor: Colors.white.withAlpha((0.3 * 255).round()),
                          onChanged: (newValue) {
                            controller.seekTo(Duration(milliseconds: newValue.toInt()));
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Duration
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    return Text(
                      _formatDuration(value.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _resolveWidth(constraints, context);
        final height = width / widget.aspectRatio;

        if (widget.imageUrls.isEmpty) {
          return _buildEmptySlider(width, height);
        }

        return SizedBox(
          width: width,
          height: height,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              return RepaintBoundary(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.25 * 255).round()),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _buildMediaWidget(index),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  double _resolveWidth(BoxConstraints constraints, BuildContext context) {
    if (constraints.maxWidth.isFinite && constraints.maxWidth > 0) {
      return constraints.maxWidth;
    }
    return MediaQuery.of(context).size.width;
  }

  Widget _buildEmptySlider(double width, double height) {
    final fallbackAsset = widget.defaultAssetImage;
    if (fallbackAsset != null) {
      return SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                fallbackAsset,
                fit: BoxFit.cover,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha((0.2 * 255).round()),
                      Colors.black.withAlpha((0.05 * 255).round()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.withAlpha((0.3 * 255).round()),
            Colors.grey.withAlpha((0.1 * 255).round()),
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 48,
              color: Colors.white54,
            ),
            SizedBox(height: 12),
            Text(
              'No images added yet',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Admin can add up to 5 images',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(int index) {
    return Container(
      color: Colors.grey.withAlpha((0.3 * 255).round()),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: Colors.white54,
            ),
            const SizedBox(height: 8),
            Text(
              'Image ${index + 1}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}