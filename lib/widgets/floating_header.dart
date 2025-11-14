import 'package:flutter/material.dart';

class FloatingHeader extends StatelessWidget implements PreferredSizeWidget {
  const FloatingHeader({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.backgroundColor = Colors.transparent,
  });

  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((0.8 * 255).round()),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.3 * 255).round()),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.white.withAlpha((0.1 * 255).round()),
            blurRadius: 0,
            spreadRadius: 1,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main header content
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Leading widget (back button, etc.)
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 8),
                ],
                // Title
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Action widgets
                if (actions != null) ...actions!,
              ],
            ),
          ),
          // Bottom widget (tabs, etc.)
          if (bottom != null) bottom!,
        ],
      ),
    );
  }

  @override
  Size get preferredSize {
    double height = 56; // Base header height
    if (bottom != null) {
      height += bottom!.preferredSize.height;
    }
    height += 48; // Add margin space (top: 40 + bottom: 8)
    return Size.fromHeight(height);
  }
}

// Wrapper for TabBar to work with FloatingHeader
class FloatingTabBar extends StatelessWidget implements PreferredSizeWidget {
  const FloatingTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.indicatorColor,
    this.labelColor,
    this.unselectedLabelColor,
    this.isScrollable = false,
    this.tabAlignment,
  });

  final List<Widget> tabs;
  final TabController? controller;
  final Color? indicatorColor;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final bool isScrollable;
  final TabAlignment? tabAlignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
        border: Border(
          top: BorderSide(
            color: Colors.white.withAlpha((0.1 * 255).round()),
            width: 0.5,
          ),
        ),
      ),
      child: TabBar(
        controller: controller,
        tabs: tabs,
        indicatorColor: indicatorColor ?? const Color(0xFF00E5A8),
        labelColor: labelColor ?? Colors.white,
        unselectedLabelColor: unselectedLabelColor ?? Colors.white54,
        isScrollable: isScrollable,
        tabAlignment: tabAlignment,
        dividerColor: Colors.transparent,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}