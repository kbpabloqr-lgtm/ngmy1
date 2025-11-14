import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../screens/coming_soon.dart';
import '../screens/betting_screen.dart';
import '../screens/store/ngmy_store_screen.dart';
import '../screens/growth_premium.dart';
import '../screens/family_tree_screen.dart';
import '../screens/learn_screen.dart';
import '../screens/artist_awards_live_screen.dart';

/// A glass-effect menu with iOS 26-inspired design
class CircularMenu extends StatefulWidget {
  final double size;
  final VoidCallback? onAdminPressed;
  const CircularMenu({
    super.key, 
    required this.size,
    this.onAdminPressed,
  });

  @override
  State<CircularMenu> createState() => _CircularMenuState();
}

class _CircularMenuState extends State<CircularMenu> {
  List<_MenuItem> _menuItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  Future<void> _loadMenuItems() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if Family Tree menu should be visible
    final familyTreeVisible = prefs.getBool('family_tree_menu_visible') ?? true;
    final customTitle = prefs.getString('family_tree_custom_title') ?? 'Family Tree';
    
    // Base menu items
    final baseItems = [
      _MenuItem('Growth', Icons.trending_up_rounded, _MenuColors.growth),
      _MenuItem('Money', Icons.account_balance_wallet_rounded, _MenuColors.money),
      _MenuItem('Media', Icons.live_tv_rounded, _MenuColors.media),
      _MenuItem('NGMY Store', Icons.shopping_bag_rounded, _MenuColors.store),
      _MenuItem('Learn', Icons.school_rounded, _MenuColors.learn),
    ];
    
    // Add Family Tree only if admin allows it
    final menuItems = <_MenuItem>[...baseItems];
    if (familyTreeVisible) {
      menuItems.insert(4, _MenuItem(customTitle, Icons.diversity_3_rounded, _MenuColors.family));
    }
    
    setState(() {
      _menuItems = menuItems;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
      );
    }

    final ringRadius = widget.size * 0.33; // Perfect radius for circular alignment
    final itemSize = widget.size * 0.18;   // Bigger menu items
    final centralSize = widget.size * 0.13; // Proportional center button

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background glass disc
          _buildGlassyBackground(widget.size),
          
          // Center button (placed before menu items to avoid interference)
          _buildCenterButton(context, centralSize),
          
          // Menu items in a perfect circle (placed last to be on top)
          ...List.generate(_menuItems.length, (i) {
            // Perfect circular distribution: start at top (-π/2) and distribute evenly
            final angle = -math.pi / 2 + i * (2 * math.pi / _menuItems.length);
            return _buildMenuItem(
              context,
              _menuItems[i],
              ringRadius,
              itemSize,
              angle,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGlassyBackground(double size) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withAlpha((0.15 * 255).round()),
              Colors.white.withAlpha((0.05 * 255).round()),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: ClipOval(
          child: BackdropFilter(
            // Lower blur to reduce GPU cost while preserving glass look
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withAlpha((0.2 * 255).round()),
                    Colors.white.withAlpha((0.05 * 255).round()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, _MenuItem item, double radius, double itemSize, double angle) {
    // Offset to adjust the circle center so menu items are equidistant from home button
    // One more step to the left: slight negative x offset
    final circleOffset = Offset(-widget.size * 0.06, -widget.size * 0.12);
    
    // Calculate position with perfect circular alignment
    final position = Offset(
      radius * math.cos(angle),
      radius * math.sin(angle),
    );

    return Positioned(
      left: (widget.size / 2) + position.dx - (itemSize / 2) + circleOffset.dx,
      top: (widget.size / 2) + position.dy - (itemSize / 2) + circleOffset.dy,
      child: RepaintBoundary(
        child: _GlassMenuItem(
          item: item,
          size: itemSize, 
        ),
      ),
    );
  }

  Widget _buildCenterButton(BuildContext context, double size) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // Only respond to direct hits on the home button
      onTap: () {
        if (widget.onAdminPressed != null) {
          widget.onAdminPressed!();
        } else {
          // Default home button functionality  
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome Home! 🏠'),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: SizedBox(
        width: size,
        height: size,
        child: _GlassSurface(
          borderRadius: BorderRadius.circular(size),
          blur: 15,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withAlpha((0.3 * 255).round()),
                  Colors.white.withAlpha((0.1 * 255).round()),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.home_rounded,
                size: size * 0.5,
                color: Colors.white.withAlpha((0.9 * 255).round()),
                shadows: [
                  Shadow(
                    color: Colors.white.withAlpha((0.3 * 255).round()),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String label;
  final IconData icon;
  final Color color;
  
  const _MenuItem(this.label, this.icon, this.color);
}

class _MenuColors {
  static const growth = Color(0xFF00C853);   // Vibrant green
  static const money = Color(0xFFFFD700);    // Gold
  static const media = Color(0xFF2962FF);    // Bright blue
  static const store = Color(0xFF00BFA5);    // Teal
  static const family = Color(0xFF8E24AA);   // Royal purple
  static const learn = Color(0xFFFF6D00);    // Bright orange
}

class _GlassMenuItem extends StatefulWidget {
  final _MenuItem item;
  final double size;

  const _GlassMenuItem({
    required this.item,
    required this.size,
  });

  @override
  State<_GlassMenuItem> createState() => _GlassMenuItemState();
}

class _GlassMenuItemState extends State<_GlassMenuItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
    // Add haptic feedback for better user experience
    // HapticFeedback.lightImpact(); // Uncomment if you want haptic feedback
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.8, // Extra space for text positioning
      height: widget.size * 1.8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular menu button at center
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) => Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent, // More sensitive - responds to entire touch area
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onTapCancel: _onTapCancel,
              onTap: () async {
                if (widget.item.label == 'Growth') {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (context) => const GrowthScreen(),
                    ),
                  );
                } else if (widget.item.label == 'Money') {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (context) => const BettingScreen(),
                    ),
                  );
                } else if (widget.item.label == 'NGMY Store') {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (context) => const NgmyStoreScreen(),
                    ),
                  );
                } else if (widget.item.label == 'Family Tree') {
                  // Check admin settings before allowing access
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context, rootNavigator: true);
                  
                  final prefs = await SharedPreferences.getInstance();
                  final familyTreeSystemEnabled = prefs.getBool('family_tree_system_enabled') ?? true;
                  final requireLogin = prefs.getBool('family_tree_require_login') ?? false;
                  
                  if (!mounted) return;
                  
                  if (!familyTreeSystemEnabled) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Family Tree system is currently disabled by admin'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  
                  if (requireLogin) {
                    // Check if user is logged in
                    final username = prefs.getString('family_tree_user_name');
                    if (username == null || username.isEmpty) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Please login to access Family Tree'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                  }
                  
                  navigator.push(
                    MaterialPageRoute(
                      builder: (context) => const FamilyTreeScreen(),
                    ),
                  );
                } else if (widget.item.label == 'Learn') {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (context) => const LearnScreen(),
                    ),
                  );
                } else if (widget.item.label == 'Media') {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (context) => const ArtistAwardsLiveScreen(),
                    ),
                  );
                } else {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (context) => ComingSoonScreen(
                        menuTitle: widget.item.label,
                        menuIcon: widget.item.icon,
                        menuColor: widget.item.color,
                      ),
                    ),
                  );
                }
              },
              child: _GlassSurface(
                borderRadius: BorderRadius.circular(widget.size),
                // Reduce blur to make content crisper while keeping the glass effect
                blur: _isPressed ? 12 : 8,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        // Slightly more vivid background glow
                        widget.item.color.withAlpha((0.45 * 255).round()),
                        widget.item.color.withAlpha((0.15 * 255).round()),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Glowing background
                      if (_isPressed) ...[
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  widget.item.color.withAlpha((0.3 * 255).round()),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      // Icon with stronger color, outline, and glow for readability
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Soft outline (slightly larger icon behind)
                            Icon(
                              widget.item.icon,
                              size: widget.size * 0.48,
                              color: Colors.black.withAlpha((0.45 * 255).round()),
                              shadows: const [
                                Shadow(color: Colors.black54, blurRadius: 2),
                              ],
                            ),
                            // Main icon with full opacity and stronger glow
                            Icon(
                              widget.item.icon,
                              size: widget.size * 0.45,
                              color: widget.item.color, // fully opaque
                              shadows: [
                                Shadow(
                                  color: widget.item.color.withAlpha((0.9 * 255).round()),
                                  blurRadius: _isPressed ? 16 : 8,
                                ),
                                const Shadow(
                                  color: Colors.white24,
                                  blurRadius: 3,
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
            ),
          ),
          // Text label positioned below the circular button
          Positioned(
            bottom: 0,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: widget.size * 1.4,  // Smaller text container
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                // More contrast behind the label for readability
                color: Colors.black.withAlpha((0.65 * 255).round()),
                border: Border.all(
                  color: widget.item.color.withAlpha((0.55 * 255).round()),
                  width: 1,
                ),
              ),
              child: Text(
                widget.item.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,  // Slightly larger
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(color: Colors.black.withAlpha((0.6 * 255).round()), blurRadius: 2),
                    Shadow(color: widget.item.color.withAlpha((0.8 * 255).round()), blurRadius: 4),
                  ],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blur;

  const _GlassSurface({
    required this.child,
    required this.borderRadius,
    this.blur = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: Colors.white.withAlpha((0.1 * 255).round()),
            border: Border.all(
              color: Colors.white.withAlpha((0.2 * 255).round()),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}