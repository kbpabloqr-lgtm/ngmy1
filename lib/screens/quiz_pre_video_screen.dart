import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/learn_models.dart';

class QuizPreVideoScreen extends StatefulWidget {
  const QuizPreVideoScreen({super.key, required this.event});

  final QuizEvent event;

  @override
  State<QuizPreVideoScreen> createState() => _QuizPreVideoScreenState();
}

class _QuizPreVideoScreenState extends State<QuizPreVideoScreen> {
  VideoPlayerController? _controller;
  YoutubePlayerController? _youtubeController;
  StreamSubscription<YoutubePlayerValue>? _youtubeSubscription;
  VoidCallback? _videoListener;
  bool _initializing = true;
  bool _hasError = false;
  bool _missingClip = false;
  bool _canContinue = false;
  bool _isYouTube = false;
  String? _externalUrl;
  bool _externalOpened = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _disposeYoutubeController();
    _disposeLocalController();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _initializing = true;
      _hasError = false;
      _missingClip = false;
      _canContinue = false;
      _externalUrl = null;
    });

    final source = widget.event.preQuizVideoUrl?.trim();
    if (source == null || source.isEmpty) {
      setState(() {
        _initializing = false;
        _missingClip = true;
        _canContinue = true;
      });
      return;
    }

    _disposeLocalController();
    _disposeYoutubeController();
    _externalOpened = false;
    _isYouTube = false;

    if (_isYouTubeUrl(source)) {
      _isYouTube = true;
      if (_supportsInlineYoutube()) {
        final videoId = YoutubePlayerController.convertUrlToId(source);
        if (videoId == null) {
          setState(() {
            _hasError = true;
            _initializing = false;
            _canContinue = true;
          });
          return;
        }

        final controller = YoutubePlayerController.fromVideoId(
          videoId: videoId,
          autoPlay: true,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
          ),
        );

        _youtubeSubscription = controller.listen((value) {
          if (!mounted) {
            return;
          }
          if (value.hasError) {
            if (!_hasError) {
              setState(() {
                _hasError = true;
                _canContinue = false;
              });
            }
            return;
          }
          if (value.playerState == PlayerState.ended && !_canContinue) {
            setState(() => _canContinue = true);
          }
        });

        if (!mounted) {
          controller.close();
          _youtubeSubscription?.cancel();
          _youtubeSubscription = null;
          return;
        }

        setState(() {
          _youtubeController = controller;
          _initializing = false;
          _hasError = false;
          _canContinue = false;
          _externalUrl = null;
          _isYouTube = true;
        });
        controller.playVideo();
        return;
      }

      setState(() {
        _externalUrl = source;
        _initializing = false;
        _hasError = false;
        _canContinue = false;
        _isYouTube = false;
      });
      return;
    }

    try {
      final controller = await _createController(source);
      await controller.initialize();
      await controller.seekTo(Duration.zero);
      controller.setLooping(false);
      await controller.play();

      _videoListener = () {
        if (!mounted) {
          return;
        }
        final value = controller.value;
        if (value.hasError && !_hasError) {
          setState(() {
            _hasError = true;
            _canContinue = true;
          });
        } else if (!_canContinue &&
            value.isInitialized &&
            value.duration > Duration.zero &&
            value.position >=
                value.duration - const Duration(milliseconds: 150)) {
          setState(() => _canContinue = true);
        }
      };
      controller.addListener(_videoListener!);

      if (!mounted) {
        controller.removeListener(_videoListener!);
        await controller.dispose();
        _videoListener = null;
        return;
      }

      setState(() {
        _controller = controller;
        _initializing = false;
        _hasError = false;
        _canContinue = false;
        _externalUrl = null;
        _isYouTube = false;
      });
    } catch (_) {
      setState(() {
        _controller = null;
        _hasError = true;
        _initializing = false;
        _canContinue = false;
      });
    }
  }

  void _disposeLocalController() {
    final controller = _controller;
    if (controller != null) {
      controller.pause();
      if (_videoListener != null) {
        controller.removeListener(_videoListener!);
      }
      controller.dispose();
    }
    _controller = null;
    _videoListener = null;
  }

  void _disposeYoutubeController() {
    _youtubeSubscription?.cancel();
    _youtubeSubscription = null;
    _youtubeController?.close();
    _youtubeController = null;
  }

  Future<VideoPlayerController> _createController(String source) async {
    if (_looksLikeNetwork(source)) {
      return VideoPlayerController.networkUrl(Uri.parse(source));
    }
    if (_looksLikeContentUri(source)) {
      return VideoPlayerController.contentUri(Uri.parse(source));
    }
    if (_looksLikeFileUri(source)) {
      return VideoPlayerController.file(io.File.fromUri(Uri.parse(source)));
    }
    if (_looksLikeAsset(source)) {
      return VideoPlayerController.asset(source);
    }
    if (_looksLikeFile(source)) {
      final file = io.File(source);
      if (!await file.exists()) {
        throw ArgumentError('Video file does not exist at $source');
      }
      return VideoPlayerController.file(file);
    }
    final uri = Uri.tryParse(source);
    if (uri != null && uri.hasScheme) {
      return VideoPlayerController.networkUrl(uri);
    }
    throw ArgumentError('Unsupported video source: $source');
  }

  bool _looksLikeNetwork(String source) {
    final lower = source.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  bool _looksLikeAsset(String source) {
    return source.startsWith('assets/');
  }

  bool _looksLikeFileUri(String source) {
    final lower = source.toLowerCase();
    return lower.startsWith('file://');
  }

  bool _looksLikeContentUri(String source) {
    return source.toLowerCase().startsWith('content://');
  }

  bool _looksLikeFile(String source) {
    if (kIsWeb) {
      return false;
    }
    return io.File(source).isAbsolute;
  }

  bool _supportsInlineYoutube() {
    if (kIsWeb) {
      return true;
    }
    try {
      return io.Platform.isAndroid ||
          io.Platform.isIOS ||
          io.Platform.isMacOS ||
          io.Platform.isWindows ||
          io.Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  bool _isYouTubeUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') || lower.contains('youtu.be');
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _openExternalVideo() async {
    final url = _externalUrl;
    if (url == null) {
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnack('Invalid video link.');
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) {
        return;
      }
      if (launched) {
        setState(() {
          _externalOpened = true;
          _canContinue = true;
        });
      } else {
        _showSnack('Unable to open the video link.');
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Unable to open the video link.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF5350),
      ),
    );
  }

  Future<void> _openFullscreen(VideoPlayerController controller) async {
    final navigator = Navigator.of(context);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    await navigator.push(MaterialPageRoute<void>(
      builder: (_) => _FullscreenVideoPage(controller: controller),
    ));

    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.event.color;
    final clipTitleRaw = (widget.event.preQuizVideoTitle ?? '').trim();
    final clipTitle = clipTitleRaw.isEmpty ? 'Warm-up clip' : clipTitleRaw;

    final controller = _controller;
    final youtubeController = _youtubeController;
    final externalUrl = _externalUrl;

    Widget playerWidget;
    double aspectRatio = 16 / 9;
    VideoPlayerController? initializedController;

    if (externalUrl != null) {
      playerWidget = Container(
        color: Colors.black26,
        child: const Center(
          child: Icon(Icons.open_in_new, color: Colors.white54, size: 44),
        ),
      );
    } else if (_isYouTube && youtubeController != null) {
      playerWidget = YoutubePlayer(
        controller: youtubeController,
        aspectRatio: 16 / 9,
      );
    } else if (controller != null && controller.value.isInitialized) {
      initializedController = controller;
      final controllerAspect = controller.value.aspectRatio;
      if (controllerAspect > 0) {
        aspectRatio = controllerAspect;
      }
      playerWidget = VideoPlayer(controller);
    } else if (_hasError) {
      playerWidget = Container(
        color: Colors.black26,
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.white54, size: 48),
        ),
      );
    } else {
      playerWidget = Container(
        color: Colors.black26,
        child: const Center(
          child: Icon(Icons.slow_motion_video,
              color: Colors.white38, size: 44),
        ),
      );
    }

  final showProgressIndicator = initializedController != null &&
        externalUrl == null &&
        !_isYouTube &&
        !_hasError;

  final progressController = showProgressIndicator ? initializedController : null;

    // Reflect the admin-configured title throughout the warm-up experience.
    final String instructions = () {
      if (_hasError) {
        return 'We couldn\'t load "$clipTitle". Please retry so you can start the quiz.';
      }
      if (_missingClip) {
        return 'No warm-up clip was provided for "${widget.event.title}".';
      }
      if (externalUrl != null) {
        return _externalOpened
            ? 'You can reopen "$clipTitle" if you want to rewatch it.'
            : 'Open "$clipTitle" before starting "${widget.event.title}".';
      }
      return 'Watch "$clipTitle" before starting "${widget.event.title}".';
    }();

    final String footerMessage = () {
      if (_hasError) {
        return 'Retry the clip to unlock the quiz.';
      }
      if (_missingClip) {
        return 'You can start the quiz whenever you\'re ready.';
      }
      if (externalUrl != null) {
        return _canContinue
            ? 'Great! Start the quiz when you\'re ready.'
            : 'Tap the button above to open "$clipTitle" before starting.';
      }
      if (_isYouTube) {
        return _canContinue
            ? 'You\'re good to go!'
            : 'The quiz unlocks after "$clipTitle" finishes.';
      }
      return _canContinue
          ? 'You\'re good to go!'
          : 'The quiz unlocks after "$clipTitle" finishes.';
    }();

    final Widget? externalButton = externalUrl != null
        ? OutlinedButton.icon(
            onPressed: _openExternalVideo,
            icon: Icon(
              _externalOpened ? Icons.refresh : Icons.open_in_new,
              color: Colors.white70,
            ),
            label: Text(
              _externalOpened ? 'Reopen "$clipTitle"' : 'Open "$clipTitle"',
              style: const TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withAlpha(120)),
            ),
          )
        : null;

  final bool canLeave = _missingClip || _canContinue;
  final String continueLabel = _hasError
    ? 'Retry clip'
    : canLeave
      ? 'Start quiz'
      : externalUrl != null
        ? 'Open clip to continue'
        : 'Watch to continue';

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(clipTitle, style: const TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _initializing
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF00BFA5)),
                      )
                    : Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: AspectRatio(
                                    aspectRatio: aspectRatio,
                                    child: playerWidget,
                                  ),
                                ),
                                if (progressController != null)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 16, right: 4),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () =>
                                            _openFullscreen(progressController),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(Icons.fullscreen),
                                        label: const Text('Fullscreen'),
                                      ),
                                    ),
                                  ),
                                if (progressController != null) ...[
                                  const SizedBox(height: 16),
                                  VideoProgressIndicator(
                                    progressController,
                                    allowScrubbing: false,
                                    colors: VideoProgressColors(
                                      playedColor: accent,
                                      bufferedColor: Colors.white30,
                                      backgroundColor: Colors.white12,
                                    ),
                                  ),
                                ],
                                if (externalButton != null) ...[
                                  const SizedBox(height: 16),
                                  externalButton,
                                ],
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    instructions,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _hasError
                    ? (_initializing ? null : () => _initialize())
                    : canLeave
                        ? () => Navigator.of(context).pop(true)
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(continueLabel),
              ),
              const SizedBox(height: 8),
              Text(
                footerMessage,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: !_initializing &&
              progressController != null &&
              !_hasError
          ? FloatingActionButton(
              backgroundColor: accent,
              foregroundColor: Colors.black,
              onPressed: _togglePlayback,
              child: Icon(progressController.value.isPlaying
                  ? Icons.pause
                  : Icons.play_arrow),
            )
          : null,
    );
  }
}

class _FullscreenVideoPage extends StatelessWidget {
  const _FullscreenVideoPage({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final aspect = value.isInitialized && value.aspectRatio > 0
                ? value.aspectRatio
                : 16 / 9;
            return Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: AspectRatio(
                      aspectRatio: aspect,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) => FloatingActionButton(
          backgroundColor: const Color(0xFF00BFA5),
          foregroundColor: Colors.black,
          onPressed: () async {
            if (value.isPlaying) {
              await controller.pause();
            } else {
              await controller.play();
            }
          },
          child: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
        ),
      ),
    );
  }
}
