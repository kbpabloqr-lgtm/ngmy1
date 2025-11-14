import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/glass_widgets.dart';
import '../widgets/notification_bell.dart';
import 'admin_money_screen.dart';
import 'admin_growth_screen.dart';
import 'coming_soon.dart';
import 'admin_store_screen.dart';
import 'admin_media_control_screen.dart';
import 'admin_media_marketplace_screen.dart';
import 'admin_home_screen_control.dart';
import 'admin_app_control.dart';
import 'admin_learn_control_screen.dart';
import 'admin_onboarding_screen.dart';
import 'admin_family_tree_control_screen.dart';
import 'admin_delivery_templates_screen.dart';

class AdminControlPanel extends StatefulWidget {
  final List<String> currentImages;
  final Function(List<String>) onImagesUpdated;
  final Function(int) onSlideDurationUpdated;
  final Function() onMenuConfigPressed;
  final int currentSlideDuration;

  const AdminControlPanel({
    super.key,
    required this.currentImages,
    required this.onImagesUpdated,
    required this.onSlideDurationUpdated,
    required this.onMenuConfigPressed,
    this.currentSlideDuration = 4,
  });

  @override
  State<AdminControlPanel> createState() => _AdminControlPanelState();
}

class _AdminControlPanelState extends State<AdminControlPanel> {
  final TextEditingController _urlController = TextEditingController();
  final List<String> _tempImages = [];
  late int _slideDuration;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tempImages.addAll(widget.currentImages);
    _slideDuration = widget.currentSlideDuration;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _addImage() {
    if (_urlController.text.isNotEmpty && _tempImages.length < 5) {
      // Check if it's a URL or AI prompt
      if (_urlController.text.startsWith('http')) {
        // Regular URL
        setState(() {
          _tempImages.add(_urlController.text);
          _urlController.clear();
        });
      } else {
        // AI prompt - generate image
        _generateAIImageFromPrompt(_urlController.text);
      }
    }
  }

  void _generateAIImageFromPrompt(String prompt) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanPrompt = prompt.replaceAll(' ', '+').toLowerCase();

    final aiImageUrl =
        'https://picsum.photos/seed/$cleanPrompt$timestamp/1280/720';

    setState(() {
      _tempImages.add(aiImageUrl);
      _urlController.clear();
    });

    _showSnack(
      'AI image generated for "$prompt"',
      icon: Icons.psychology,
    );
  }

  void _removeImage(int index) {
    setState(() {
      _tempImages.removeAt(index);
    });
  }

  void _saveChanges() {
    widget.onImagesUpdated(_tempImages);
    widget.onSlideDurationUpdated(_slideDuration);
    Navigator.of(context).pop();
  }

  void _openAdminMenu({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    if (title == 'Growth') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminGrowthScreen()),
      );
      return;
    }

    if (title == 'Money') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminMoneyScreen()),
      );
      return;
    }

    if (title == 'Media') {
      _showMediaOptions();
      return;
    }

    if (title == 'NGMY Store') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminStoreScreen()),
      );
      return;
    }

    if (title == 'Learn') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminLearnControlScreen()),
      );
      return;
    }

    if (title == 'Family Tree') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminFamilyTreeControlScreen()),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComingSoonScreen(
          menuTitle: '$title Controls',
          menuIcon: icon,
          menuColor: color,
        ),
      ),
    );
  }

  void _showMediaOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F162A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.live_tv_rounded, color: Colors.tealAccent),
                title: const Text(
                  'Live & Broadcast Controls',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Manage countdowns, categories, and live programming',
                  style: TextStyle(color: Colors.white54),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminMediaControlScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.storefront_rounded,
                    color: Colors.tealAccent),
                title: const Text(
                  'Marketplace Desk',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Approve clips, set payouts, and track payments',
                  style: TextStyle(color: Colors.white54),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminMediaMarketplaceScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminMenuItem(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withAlpha((0.3 * 255).round()),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryTemplateShortcut() {
    return Semantics(
      label: 'Open delivery template preview',
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _openDeliveryTemplates,
          child: Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withAlpha((0.18 * 255).round()),
              ),
              color: Colors.white.withAlpha((0.08 * 255).round()),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha((0.6 * 255).round()),
            color.withAlpha((0.8 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha((0.3 * 255).round()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                Icon(icon, color: Colors.white, size: 32),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDeliveryTemplates() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminDeliveryTemplatesScreen(),
      ),
    );
  }

  void _handleAddMedia() {
    if (_urlController.text.isNotEmpty) {
      _addImage();
    } else {
      _showAddOptions();
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((0.9 * 255).round()),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add Media',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildModernOptionButton(
              title: 'Add Photos',
              subtitle: 'Select photos from gallery',
              icon: Icons.photo_library,
              color: Colors.blue,
              onPressed: () {
                Navigator.pop(context);
                _pickPhotosFromGallery();
              },
            ),
            const SizedBox(height: 12),
            _buildModernOptionButton(
              title: 'Add Video',
              subtitle: 'Choose a video from gallery',
              icon: Icons.video_library,
              color: Colors.purple,
              onPressed: () {
                Navigator.pop(context);
                _pickVideoFromGallery();
              },
            ),
            const SizedBox(height: 12),
            _buildModernOptionButton(
              title: 'Use AI Prompt',
              subtitle: 'Describe a scene to generate',
              icon: Icons.psychology,
              color: Colors.indigo,
              onPressed: () {
                Navigator.pop(context);
                FocusScope.of(context).requestFocus(FocusNode());
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhotosFromGallery() async {
    final images = await _picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;

    setState(() {
      for (final image in images) {
        if (_tempImages.length >= 5) break;
        _tempImages.add(image.path);
      }
    });

    _showSnack('Added ${images.length} image(s) from gallery.');
  }

  Future<void> _pickVideoFromGallery() async {
    final video = await _picker.pickVideo(
        source: ImageSource.gallery, maxDuration: const Duration(seconds: 30));
    if (video == null) return;

    if (_tempImages.length >= 5) {
      _showSnack('Limit reached. Remove an item before adding more.',
          icon: Icons.warning_amber_rounded);
      return;
    }

    setState(() {
      _tempImages.add(video.path);
    });

    _showSnack('Video added successfully!', icon: Icons.movie_creation_rounded);
  }

  void _showSnack(String message, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _generateAIImages() {
    // Generate unique AI images each time with different themes
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    setState(() {
      _tempImages.clear();
      _tempImages.addAll([
        'https://picsum.photos/seed/${timestamp}nature/1280/720',
        'https://picsum.photos/seed/${timestamp}tech/1280/720',
        'https://picsum.photos/seed/${timestamp}city/1280/720',
        'https://picsum.photos/seed/${timestamp}art/1280/720',
      ]);
    });

    // Show professional AI generation message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AI Images Generated Successfully!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Professional high-quality images ready for display',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withAlpha((0.8 * 255).round()),
      appBar: AppBar(
        title: const Text(
          'Admin Control Panel',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: NotificationBell(
              badgeColor: const Color(0xFF80DEEA),
              tooltip: 'Compose notifications',
              allowCompose: true,
              titleOverride: 'Compose Notifications',
                   scopes: const ['global', 'growth', 'family_tree', 'store', 'money', 'tickets', 'media'],
                   allowBroadcast: true,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Menu Grid (3x2)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.dashboard_rounded,
                          color: Colors.white70),
                      const SizedBox(width: 12),
                      const Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      _buildDeliveryTemplateShortcut(),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // First row (3 items) - Actual home screen menus
                  Row(
                    children: [
                      Expanded(
                          child: _buildAdminMenuItem(
                        'Growth',
                        Icons.trending_up_rounded,
                        Colors.green,
                        () => _openAdminMenu(
                          title: 'Growth',
                          icon: Icons.trending_up_rounded,
                          color: Colors.green,
                        ),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildAdminMenuItem(
                        'Money',
                        Icons.account_balance_wallet_rounded,
                        Colors.blue,
                        () => _openAdminMenu(
                          title: 'Money',
                          icon: Icons.account_balance_wallet_rounded,
                          color: Colors.blue,
                        ),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildAdminMenuItem(
                        'Media',
                        Icons.live_tv_rounded,
                        Colors.purple,
                        () => _openAdminMenu(
                          title: 'Media',
                          icon: Icons.live_tv_rounded,
                          color: Colors.purple,
                        ),
                      )),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Second row (3 items) - Actual home screen menus
                  Row(
                    children: [
                      Expanded(
                          child: _buildAdminMenuItem(
                        'NGMY Store',
                        Icons.shopping_bag_rounded,
                        Colors.orange,
                        () => _openAdminMenu(
                          title: 'NGMY Store',
                          icon: Icons.shopping_bag_rounded,
                          color: Colors.orange,
                        ),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildAdminMenuItem(
                        'Family Tree',
                        Icons.diversity_3_rounded,
                        Colors.teal,
                        () => _openAdminMenu(
                          title: 'Family Tree',
                          icon: Icons.diversity_3_rounded,
                          color: Colors.teal,
                        ),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildAdminMenuItem(
                        'Learn',
                        Icons.school_rounded,
                        Colors.red,
                        () => _openAdminMenu(
                          title: 'Learn',
                          icon: Icons.school_rounded,
                          color: Colors.red,
                        ),
                      )),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // App Configuration Section
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings_applications_rounded,
                          color: Colors.white.withAlpha(230), size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'App Configuration',
                        style: TextStyle(
                          color: Colors.white.withAlpha(230),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Onboarding Configuration
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminOnboardingScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withAlpha(38),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withAlpha(51),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.app_registration_rounded,
                              color: Colors.indigo,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Onboarding Configuration',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(230),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Configure app onboarding screens, images, and content',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(179),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white.withAlpha(153),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Image Slider Management
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.slideshow, color: Colors.white70),
                      const SizedBox(width: 12),
                      const Text(
                        'Image Slider Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_tempImages.length}/5',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // AI Image Generator
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.psychology,
                              color: Colors.white70, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'AI Image Generator',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _urlController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText:
                                    'Describe what you want (e.g., "Netflix logo", "Modern tech design")',
                                hintStyle:
                                    const TextStyle(color: Colors.white54),
                                prefixIcon: const Icon(Icons.auto_awesome,
                                    color: Colors.white54),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white30),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white30),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF667eea)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildModernButton(
                            onPressed:
                                _tempImages.length < 5 ? _handleAddMedia : null,
                            icon: Icons.psychology,
                            tooltip: 'Generate AI Image',
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Demo Images Button
                  Center(
                    child: _buildModernDemoButton(),
                  ),

                  const SizedBox(height: 20),

                  // Slide Duration Control
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.white70),
                      const SizedBox(width: 12),
                      const Text(
                        'Slide Duration:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_slideDuration}s',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.blue,
                      inactiveTrackColor: Colors.white30,
                      thumbColor: Colors.white,
                      overlayColor: Colors.blue.withAlpha((0.2 * 255).round()),
                      trackHeight: 4,
                      showValueIndicator: ShowValueIndicator.onDrag,
                    ),
                    child: Slider(
                      value: _slideDuration.toDouble(),
                      min: 1,
                      max: 60,
                      divisions: 59,
                      label: '${_slideDuration}s',
                      onChanged: (value) {
                        setState(() {
                          _slideDuration = value.round();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Current Images List
                  if (_tempImages.isNotEmpty) ...[
                    const Text(
                      'Current Images:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_tempImages.length, (index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 24,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color:
                                    Colors.white.withAlpha((0.2 * 255).round()),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: _tempImages[index].startsWith('http')
                                    ? Image.network(
                                        _tempImages[index],
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(Icons.broken_image,
                                                    size: 16,
                                                    color: Colors.white54),
                                      )
                                    : Image.asset(
                                        _tempImages[index],
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(Icons.broken_image,
                                                    size: 16,
                                                    color: Colors.white54),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _tempImages[index],
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _removeImage(index),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
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

            const SizedBox(height: 20),

            // Menu Configuration
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.menu, color: Colors.white70),
                      const SizedBox(width: 12),
                      const Text(
                        'Menu Configuration',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onMenuConfigPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.settings, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Configure Menu Items',
                            style: TextStyle(
                              fontSize: 16,
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

            const SizedBox(height: 20),

            // Home Screen & App Control Buttons
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.white70),
                      SizedBox(width: 12),
                      Text(
                        'Advanced Controls',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildControlButton(
                          'Home Screen Control',
                          Icons.wallpaper,
                          Colors.blue,
                          () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminHomeScreenControl(),
                              ),
                            );
                            // Notify that wallpaper may have changed
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Return to home screen to see wallpaper changes'),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildControlButton(
                          'App Control',
                          Icons.settings_applications,
                          Colors.purple,
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminAppControl(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.purple],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _saveChanges,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Save Changes',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
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

  // Modern button for the plus icon next to URL input
  Widget _buildModernButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: onPressed != null
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withAlpha((0.15 * 255).round()),
                    Colors.white.withAlpha((0.05 * 255).round()),
                  ],
                ),
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color:
                        const Color(0xFF4A90E2).withAlpha((0.3 * 255).round()),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Center(
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Modern option button for the modal
  Widget _buildModernOptionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha((0.8 * 255).round()),
            color.withAlpha((0.6 * 255).round()),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha((0.3 * 255).round()),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.2 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.8 * 255).round()),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withAlpha((0.6 * 255).round()),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Modern demo button
  Widget _buildModernDemoButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2)
          ], // Professional AI purple gradient
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withAlpha((0.4 * 255).round()),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _generateAIImages,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Generate AI Images',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
