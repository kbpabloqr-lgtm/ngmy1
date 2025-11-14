import 'package:flutter/material.dart';
import 'dart:async';
import 'ticket_creator_screen.dart';

class FaceScanScreen extends StatefulWidget {
  final String accessCode;
  final String userId;

  const FaceScanScreen({super.key, required this.accessCode, required this.userId});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;
  bool _isScanning = false;
  int _scanProgress = 0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    // Auto-start scanning after a brief delay
    Future.delayed(const Duration(milliseconds: 500), _startScanning);
  }

  @override
  void dispose() {
    _scanController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startScanning() {
    setState(() => _isScanning = true);
    _scanController.repeat();

    // Simulate face scanning progress
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _scanProgress++;
        if (_scanProgress >= 100) {
          timer.cancel();
          _scanController.stop();
          _onScanComplete();
        }
      });
    });
  }

  void _onScanComplete() {
    // Code is reusable until expiry - no need to mark as used

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const TicketCreatorScreen(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1F3A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(
                    _isScanning ? 'Scanning...' : 'Ready to Scan',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const Spacer(),

            // Instruction text
            Padding(
              padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.1), // 10% of screen width
              child: Text(
                'Please look at the camera and hold still',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: MediaQuery.of(context).size.width * 0.04, // 4% of screen width
                ),
              ),
            ),

            SizedBox(height: MediaQuery.of(context).size.height * 0.05), // 5% of screen height

            // Face scan area
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow
                  Container(
                    width: MediaQuery.of(context).size.width * 0.7, // 70% of screen width
                    height: MediaQuery.of(context).size.height * 0.43, // 43% of screen height
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A90E2).withAlpha((0.3 * 255).round()),
                          blurRadius: MediaQuery.of(context).size.width * 0.15, // 15% of screen width
                          spreadRadius: MediaQuery.of(context).size.width * 0.05, // 5% of screen width
                        ),
                      ],
                    ),
                  ),

                  // Face outline with corner brackets
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.7, // 70% of screen width
                    height: MediaQuery.of(context).size.height * 0.43, // 43% of screen height
                    child: CustomPaint(
                      painter: FaceBracketPainter(
                        progress: _scanProgress / 100,
                        isScanning: _isScanning,
                      ),
                    ),
                  ),

                  // Scanning line
                  if (_isScanning)
                    AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        final scanAreaHeight = MediaQuery.of(context).size.height * 0.43;
                        return Positioned(
                          top: scanAreaHeight * 0.06 + (_scanAnimation.value * (scanAreaHeight * 0.88)),
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.625, // 62.5% of screen width
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFF4A90E2),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4A90E2).withAlpha((0.8 * 255).round()),
                                  blurRadius: MediaQuery.of(context).size.width * 0.05, // 5% of screen width
                                  spreadRadius: MediaQuery.of(context).size.width * 0.005, // 0.5% of screen width
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Center face icon placeholder
                  Icon(
                    Icons.face,
                    size: MediaQuery.of(context).size.width * 0.375, // 37.5% of screen width
                    color: Colors.white.withAlpha((0.1 * 255).round()),
                  ),

                  // Detection points (appear during scan)
                  if (_scanProgress > 20)
                    ...List.generate(8, (index) {
                      return _buildDetectionPoint(index);
                    }),
                ],
              ),
            ),

            SizedBox(height: MediaQuery.of(context).size.height * 0.075), // 7.5% of screen height

            // Progress indicator
            Padding(
              padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.15), // 15% of screen width
              child: Column(
                children: [
                  Text(
                    '$_scanProgress% Recognition',
                    style: TextStyle(
                      color: _scanProgress == 100 ? Colors.green : Colors.white,
                      fontSize: MediaQuery.of(context).size.width * 0.045, // 4.5% of screen width
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02), // 2% of screen height
                  ClipRRect(
                    borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.025), // 2.5% of screen width
                    child: LinearProgressIndicator(
                      value: _scanProgress / 100,
                      backgroundColor: Colors.white.withAlpha((0.1 * 255).round()),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _scanProgress == 100
                            ? Colors.green
                            : const Color(0xFF4A90E2),
                      ),
                      minHeight: MediaQuery.of(context).size.height * 0.01, // 1% of screen height
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Status messages
            Padding(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.06), // 6% of screen width
              child: Container(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04), // 4% of screen width
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.05 * 255).round()),
                  borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.04), // 4% of screen width
                  border: Border.all(
                    color: Colors.white.withAlpha((0.1 * 255).round()),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _scanProgress == 100
                          ? Icons.check_circle
                          : Icons.info_outline,
                      color: _scanProgress == 100
                          ? Colors.green
                          : const Color(0xFF4A90E2),
                      size: MediaQuery.of(context).size.width * 0.06, // 6% of screen width
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width * 0.03), // 3% of screen width
                    Expanded(
                      child: Text(
                        _scanProgress == 100
                            ? 'Face verified successfully!'
                            : 'Keep your face within the frame',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: MediaQuery.of(context).size.width * 0.035, // 3.5% of screen width
                        ),
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

  Widget _buildDetectionPoint(int index) {
    // Position points around face area - responsive positioning
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final faceWidth = screenWidth * 0.7;
    final faceHeight = screenHeight * 0.43;
    
    final positions = [
      Offset(faceWidth * 0.29, faceHeight * 0.29), // forehead left
      Offset(faceWidth * 0.71, faceHeight * 0.29), // forehead right
      Offset(faceWidth * 0.21, faceHeight * 0.51), // left eye
      Offset(faceWidth * 0.79, faceHeight * 0.51), // right eye
      Offset(faceWidth * 0.5, faceHeight * 0.57), // nose
      Offset(faceWidth * 0.36, faceHeight * 0.74), // left mouth
      Offset(faceWidth * 0.64, faceHeight * 0.74), // right mouth
      Offset(faceWidth * 0.5, faceHeight * 0.86), // chin
    ];

    final position = positions[index % positions.length];
    final delay = index * 100;
    final shouldShow = _scanProgress > (delay / 10);

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: AnimatedOpacity(
        opacity: shouldShow ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          width: screenWidth * 0.02, // 2% of screen width
          height: screenWidth * 0.02, // 2% of screen width (keeping circular)
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withAlpha((0.6 * 255).round()),
                blurRadius: screenWidth * 0.02, // 2% of screen width
                spreadRadius: screenWidth * 0.005, // 0.5% of screen width
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FaceBracketPainter extends CustomPainter {
  final double progress;
  final bool isScanning;

  FaceBracketPainter({required this.progress, required this.isScanning});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.01 // 1% of face area width
      ..color = isScanning
          ? (progress == 1.0 ? Colors.green : const Color(0xFF4A90E2))
          : Colors.white.withAlpha((0.5 * 255).round());

    final bracketLength = size.width * 0.14; // 14% of face area width
    final radius = size.width * 0.07; // 7% of face area width

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(bracketLength, 0)
        ..lineTo(radius, 0)
        ..arcToPoint(
          const Offset(0, 20),
          radius: Radius.circular(radius),
        )
        ..lineTo(0, bracketLength),
      paint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - bracketLength, 0)
        ..lineTo(size.width - radius, 0)
        ..arcToPoint(
          Offset(size.width, radius),
          radius: Radius.circular(radius),
          clockwise: false,
        )
        ..lineTo(size.width, bracketLength),
      paint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - bracketLength)
        ..lineTo(0, size.height - radius)
        ..arcToPoint(
          Offset(radius, size.height),
          radius: Radius.circular(radius),
          clockwise: false,
        )
        ..lineTo(bracketLength, size.height),
      paint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height - bracketLength)
        ..lineTo(size.width, size.height - radius)
        ..arcToPoint(
          Offset(size.width - radius, size.height),
          radius: Radius.circular(radius),
        )
        ..lineTo(size.width - bracketLength, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant FaceBracketPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isScanning != isScanning;
  }
}
