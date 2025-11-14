import 'package:flutter/material.dart';
import '../widgets/glass_widgets.dart';

class ComingSoonScreen extends StatelessWidget {
  final String menuTitle;
  final IconData menuIcon;
  final Color menuColor;

  const ComingSoonScreen({
    super.key,
    required this.menuTitle,
    required this.menuIcon,
    required this.menuColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0A2472),  // Deep blue
              const Color(0xFF0E6BA8),  // Medium blue
              const Color(0xFF0BA2C0),  // Light blue-green
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: GlassButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Back'),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Main content
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Large icon with glow effect
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              menuColor.withAlpha((0.3 * 255).round()),
                              menuColor.withAlpha((0.1 * 255).round()),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: menuColor.withAlpha((0.4 * 255).round()),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          menuIcon,
                          size: 60,
                          color: menuColor,
                          shadows: [
                            Shadow(
                              color: menuColor.withAlpha((0.6 * 255).round()),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Title
                      Text(
                        menuTitle,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: menuColor.withAlpha((0.5 * 255).round()),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Coming soon message
                      GlassSurface(
                        blur: 15,
                        borderRadius: BorderRadius.circular(20),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.construction_rounded,
                              size: 48,
                              color: Colors.orange.withAlpha((0.8 * 255).round()),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Coming Soon!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'We are working hard to bring you this amazing feature. Stay tuned for updates!',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 20,
                                  color: Colors.white60,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Expected: Soon',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white60,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GlassButton(
                            onPressed: () => Navigator.of(context).pop(),
                            isPrimary: true,
                            child: const Text('Go Back'),
                          ),
                          const SizedBox(width: 16),
                          GlassButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('We\'ll notify you when it\'s ready!'),
                                  backgroundColor: menuColor,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                            child: const Text('Notify Me'),
                          ),
                        ],
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
}