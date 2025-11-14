import 'package:flutter/material.dart';

/// Fast loading widget that shows while app initializes
class FastStartupWidget extends StatelessWidget {
  const FastStartupWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0047FF), // Electric blue
            Color(0xFF0066FF),
            Color(0xFF3385FF),
            Color(0xFF66A3FF),
            Color(0xFF1A5CFF)
          ],
          stops: [0.0, 0.2, 0.5, 0.8, 1.0],
        ),
      ),
      child: const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo or icon
              Icon(
                Icons.storefront,
                size: 64,
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                'NGMY Store',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}