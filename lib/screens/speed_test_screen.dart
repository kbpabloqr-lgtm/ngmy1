import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> 
    with TickerProviderStateMixin {
  
  bool _isTestRunning = false;
  double _currentSpeed = 0.0;
  double _downloadSpeed = 12.7;
  double _uploadSpeed = 17.7;
  int _ping = 10;
  String _testPhase = 'Uploading';
  
  late AnimationController _speedometerController;
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    _speedometerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _speedometerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runSpeedTest() async {
    setState(() {
      _isTestRunning = true;
      _currentSpeed = 0.0;
      _testPhase = 'Starting...';
    });

    // Download test
    setState(() => _testPhase = 'Downloading');
    await _animateSpeed(120.5, 'Download');
    
    // Upload test
    setState(() => _testPhase = 'Uploading');
    await _animateSpeed(85.2, 'Upload');
    
    // Ping test
    setState(() => _testPhase = 'Testing Ping');
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _isTestRunning = false;
      _testPhase = 'Complete';
      _downloadSpeed = 120.5;
      _uploadSpeed = 85.2;
      _ping = 8;
    });
  }

  Future<void> _animateSpeed(double targetSpeed, String phase) async {
    final random = Random();
    for (int i = 0; i <= 100; i += 2) {
      await Future.delayed(const Duration(milliseconds: 80));
      setState(() {
        _currentSpeed = (targetSpeed * i / 100) + random.nextDouble() * 10;
        _testPhase = '$phase: ${_currentSpeed.toStringAsFixed(1)} Mbps';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1B5E20),
              Color(0xFF2E7D32),
              Color(0xFF4CAF50),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Main speedometer area
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      
                      // Speedometer
                      _buildSpeedometer(),
                      
                      const SizedBox(height: 40),
                      
                      // Stats row
                      _buildStatsRow(),
                      
                      const SizedBox(height: 40),
                      
                      // Start/Stop button
                      _buildTestButton(),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              
              // Bottom navigation
              _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Spacer(),
          const Text(
            'Speed Test',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  'Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedometer() {
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Speedometer background
          CustomPaint(
            size: const Size(300, 300),
            painter: SpeedometerPainter(
              progress: _currentSpeed / 200,
              isActive: _isTestRunning,
            ),
          ),
          
          // Center content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _testPhase,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _currentSpeed.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Mbps',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          
          // Pulse animation when testing
          if (_isTestRunning)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 280 + (_pulseController.value * 40),
                  height: 280 + (_pulseController.value * 40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withValues(
                        alpha: 0.3 - (_pulseController.value * 0.3),
                      ),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard(
            icon: Icons.download,
            value: '${_downloadSpeed.toStringAsFixed(1)} Mb/s',
            label: 'Download',
          ),
          _buildStatCard(
            icon: Icons.upload,
            value: '${_uploadSpeed.toStringAsFixed(1)} Mb/s',
            label: 'Upload',
          ),
          _buildStatCard(
            icon: Icons.speed,
            value: '${_ping.toStringAsFixed(0)} Ms',
            label: 'Ping',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: _isTestRunning ? null : _runSpeedTest,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isTestRunning ? Colors.red : const Color(0xFF4CAF50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Text(
            _isTestRunning ? 'Stop' : 'Start Test',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.language, 'Global', false),
          _buildNavItem(Icons.home, 'Home', false),
          _buildNavItem(Icons.speed, 'Speed', true),
          _buildNavItem(Icons.settings, 'Settings', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF4CAF50) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF4CAF50) : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class SpeedometerPainter extends CustomPainter {
  final double progress;
  final bool isActive;

  SpeedometerPainter({required this.progress, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Background arc
    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi * 0.75,
      pi * 1.5,
      false,
      backgroundPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF4CAF50),
          const Color(0xFF8BC34A),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi * 0.75,
      pi * 1.5 * progress,
      false,
      progressPaint,
    );

    // Speed marks
    final markPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2;

    for (int i = 0; i <= 10; i++) {
      final angle = -pi * 0.75 + (pi * 1.5 * i / 10);
      final startRadius = radius - 15;
      final endRadius = radius - 5;
      
      final start = Offset(
        center.dx + cos(angle) * startRadius,
        center.dy + sin(angle) * startRadius,
      );
      final end = Offset(
        center.dx + cos(angle) * endRadius,
        center.dy + sin(angle) * endRadius,
      );
      
      canvas.drawLine(start, end, markPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}