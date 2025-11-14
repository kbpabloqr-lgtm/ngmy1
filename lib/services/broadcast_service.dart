import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// Broadcast source types
enum BroadcastSource {
  none,      // No broadcast
  camera,    // Live camera feed
  screen,    // Screen recording
  video,     // Video file from gallery
}

/// Singleton service to manage admin live broadcast state
class BroadcastService extends ChangeNotifier {
  static final BroadcastService _instance = BroadcastService._internal();
  factory BroadcastService() => _instance;
  static BroadcastService get instance => _instance;
  
  BroadcastService._internal();

  // Broadcast state
  bool _isLive = false;
  BroadcastSource _currentSource = BroadcastSource.none;
  String? _broadcastId;
  DateTime? _broadcastStartTime;
  
  // Camera
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isLoadingCamera = false;
  String? _cameraError;
  
  // Screen recording
  bool _isScreenRecording = false;
  bool _screenRecordingInBackground = false;
  
  // Video from gallery
  File? _selectedVideo;
  VideoPlayerController? _videoController;
  bool _isVideoPlaying = false;
  Duration? _videoDuration;
  Duration? _videoPosition;
  
  // Picture-in-picture overlay
  bool _hasOverlay = false;
  BroadcastSource _overlaySource = BroadcastSource.none;
  Offset _overlayPosition = const Offset(0.7, 0.1); // Normalized (0-1)
  Size _overlaySize = const Size(0.25, 0.25); // Normalized (0-1)
  
  // Filters and effects
  bool _beautyFilterEnabled = false;
  bool _mirrorMode = false;
  
  final ImagePicker _imagePicker = ImagePicker();

  // Getters
  bool get isLive => _isLive;
  BroadcastSource get currentSource => _currentSource;
  String? get broadcastId => _broadcastId;
  DateTime? get broadcastStartTime => _broadcastStartTime;
  CameraController? get cameraController => _cameraController;
  bool get isCameraInitialized => _isCameraInitialized;
  bool get isLoadingCamera => _isLoadingCamera;
  String? get cameraError => _cameraError;
  bool get isScreenRecording => _isScreenRecording;
  bool get screenRecordingInBackground => _screenRecordingInBackground;
  File? get selectedVideo => _selectedVideo;
  VideoPlayerController? get videoController => _videoController;
  bool get isVideoPlaying => _isVideoPlaying;
  Duration? get videoDuration => _videoDuration;
  Duration? get videoPosition => _videoPosition;
  bool get hasOverlay => _hasOverlay;
  BroadcastSource get overlaySource => _overlaySource;
  Offset get overlayPosition => _overlayPosition;
  Size get overlaySize => _overlaySize;
  bool get beautyFilterEnabled => _beautyFilterEnabled;
  bool get mirrorMode => _mirrorMode;

  /// Initialize available cameras
  Future<void> initializeCameras() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      debugPrint('Failed to get cameras: $e');
    }
  }

  /// Start broadcasting with camera
  Future<bool> startCameraBroadcast() async {
    try {
      _isLoadingCamera = true;
      _cameraError = null;
      notifyListeners();

      // Request permission
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _cameraError = 'Camera permission denied';
        _isLoadingCamera = false;
        notifyListeners();
        return false;
      }

      if (_cameras.isEmpty) {
        await initializeCameras();
        if (_cameras.isEmpty) {
          _cameraError = 'No cameras available';
          _isLoadingCamera = false;
          notifyListeners();
          return false;
        }
      }

      // Initialize camera controller with maximum quality
      final camera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.max, // Changed from high to max for best quality
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      // Ensure built-in audio capture is active for downstream previews
      try {
        await _cameraController!.setFlashMode(FlashMode.off);
      } catch (_) {
        // Ignore devices without flash or flash permissions
      }

      _isCameraInitialized = true;
      _isLoadingCamera = false;
      _currentSource = BroadcastSource.camera;
      _isLive = true;
      _broadcastId = DateTime.now().millisecondsSinceEpoch.toString();
      _broadcastStartTime = DateTime.now();
      
      await _saveBroadcastState();
      notifyListeners();
      return true;
    } catch (e) {
      _cameraError = 'Camera error: $e';
      _isLoadingCamera = false;
      _isCameraInitialized = false;
      notifyListeners();
      return false;
    }
  }

  /// Flip camera (front/back)
  Future<void> flipCamera() async {
    if (!_isCameraInitialized || _cameras.length < 2) return;

    try {
      final currentLensDirection = _cameraController!.description.lensDirection;
      final newCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection != currentLensDirection,
        orElse: () => _cameras.first,
      );

      await _cameraController?.dispose();
      
      _cameraController = CameraController(
        newCamera,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      notifyListeners();
    } catch (e) {
      debugPrint('Error flipping camera: $e');
    }
  }

  /// Start screen recording broadcast
  Future<bool> startScreenRecordingBroadcast() async {
    try {
      // Note: Actual screen recording requires platform-specific implementation
      // This is a placeholder for the UI flow
      _isScreenRecording = true;
      _currentSource = BroadcastSource.screen;
      _isLive = true;
      _broadcastId = DateTime.now().millisecondsSinceEpoch.toString();
      _broadcastStartTime = DateTime.now();
      
      await _saveBroadcastState();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error starting screen recording: $e');
      return false;
    }
  }

  /// Enable background screen recording
  void enableBackgroundRecording(bool enable) {
    _screenRecordingInBackground = enable;
    notifyListeners();
  }

  /// Select and broadcast video from gallery
  Future<bool> selectVideoFromGallery() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video != null) {
        _selectedVideo = File(video.path);
        
        // Initialize video player controller
        _videoController = VideoPlayerController.file(_selectedVideo!);
        await _videoController!.initialize();
  await _videoController!.setVolume(1.0);
        await _videoController!.setLooping(true); // Loop video continuously
        await _videoController!.play(); // Auto-play when selected
        
        _isVideoPlaying = true;
        _videoDuration = _videoController!.value.duration;
        _currentSource = BroadcastSource.video;
        _isLive = true;
        _broadcastId = DateTime.now().millisecondsSinceEpoch.toString();
        _broadcastStartTime = DateTime.now();
        
        await _saveBroadcastState();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error selecting video: $e');
      return false;
    }
  }

  /// Control video playback
  void playVideo() {
    _videoController?.play();
    _isVideoPlaying = true;
    _videoController?.setVolume(1.0);
    notifyListeners();
  }

  void pauseVideo() {
    _videoController?.pause();
    _isVideoPlaying = false;
    notifyListeners();
  }

  void stopVideo() {
    _isVideoPlaying = false;
    _videoPosition = Duration.zero;
    _videoController?.setVolume(0.0);
    notifyListeners();
  }

  void seekVideo(Duration position) {
    _videoPosition = position;
    notifyListeners();
  }

  /// Add picture-in-picture overlay
  void addOverlay(BroadcastSource source) {
    if (source == _currentSource || source == BroadcastSource.none) return;
    
    _hasOverlay = true;
    _overlaySource = source;
    notifyListeners();
  }

  void removeOverlay() {
    _hasOverlay = false;
    _overlaySource = BroadcastSource.none;
    notifyListeners();
  }

  void updateOverlayPosition(Offset position) {
    _overlayPosition = position;
    notifyListeners();
  }

  void updateOverlaySize(Size size) {
    _overlaySize = size;
    notifyListeners();
  }

  /// Toggle filters and effects
  void toggleBeautyFilter() {
    _beautyFilterEnabled = !_beautyFilterEnabled;
    notifyListeners();
  }

  void toggleMirrorMode() {
    _mirrorMode = !_mirrorMode;
    notifyListeners();
  }

  /// Stop broadcasting
  Future<void> stopBroadcast() async {
    try {
      // Dispose camera
      if (_cameraController != null) {
        await _cameraController?.dispose();
        _cameraController = null;
      }
      
      // Dispose video controller
      if (_videoController != null) {
        await _videoController?.dispose();
        _videoController = null;
      }

      // Reset state
      _isLive = false;
      _currentSource = BroadcastSource.none;
      _isCameraInitialized = false;
      _isScreenRecording = false;
      _screenRecordingInBackground = false;
      _selectedVideo = null;
      _isVideoPlaying = false;
      _hasOverlay = false;
      _overlaySource = BroadcastSource.none;
      _cameraError = null;
      
      await _saveBroadcastState();
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping broadcast: $e');
    }
  }

  /// Save broadcast state to SharedPreferences
  Future<void> _saveBroadcastState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final state = {
        'isLive': _isLive,
        'currentSource': _currentSource.name,
        'broadcastId': _broadcastId,
        'broadcastStartTime': _broadcastStartTime?.toIso8601String(),
        'videoPath': _selectedVideo?.path,
      };
      await prefs.setString('broadcast_state', jsonEncode(state));
    } catch (e) {
      debugPrint('Error saving broadcast state: $e');
    }
  }

  /// Load broadcast state from SharedPreferences
  Future<void> loadBroadcastState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = prefs.getString('broadcast_state');
      
      if (stateJson != null) {
        final state = jsonDecode(stateJson);
        _isLive = state['isLive'] ?? false;
        _broadcastId = state['broadcastId'];
        
        final startTimeStr = state['broadcastStartTime'];
        if (startTimeStr != null) {
          _broadcastStartTime = DateTime.parse(startTimeStr);
        }
        
        final sourceName = state['currentSource'];
        if (sourceName != null) {
          _currentSource = BroadcastSource.values.firstWhere(
            (s) => s.name == sourceName,
            orElse: () => BroadcastSource.none,
          );
        }
        
        final videoPath = state['videoPath'];
        if (videoPath != null) {
          _selectedVideo = File(videoPath);
        }
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading broadcast state: $e');
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}
