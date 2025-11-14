import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import '../models/media_models.dart';
import '../widgets/floating_header.dart';
import '../services/broadcast_service.dart';
import 'tickets/admin_ticket_control_screen.dart';

/// Admin Media Control Screen
/// Allows admin to configure Live Zone timer, categories, artists, and voting
class AdminMediaControlScreen extends StatefulWidget {
  const AdminMediaControlScreen({super.key});

  @override
  State<AdminMediaControlScreen> createState() => _AdminMediaControlScreenState();
}

class _AdminMediaControlScreenState extends State<AdminMediaControlScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Live Settings
  late LiveSettings _liveSettings;
  bool _isLoading = true;
  
  // Categories
  List<CategoryModel> _categories = [];
  
  // Timer controllers
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _secondsController = TextEditingController();
  
  // Categories title controller
  final TextEditingController _categoriesTitleController = TextEditingController();
  final TextEditingController _ceremonyHeaderController = TextEditingController();
  final TextEditingController _artist1Controller = TextEditingController();
  final TextEditingController _artist2Controller = TextEditingController();
  final TextEditingController _artist1ImageController = TextEditingController();
  final TextEditingController _artist2ImageController = TextEditingController();
  
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _daysController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _categoriesTitleController.dispose();
    _ceremonyHeaderController.dispose();
    _artist1Controller.dispose();
    _artist2Controller.dispose();
    _artist1ImageController.dispose();
    _artist2ImageController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    
    // Load live settings
    final liveSettingsJson = prefs.getString('live_settings');
    if (liveSettingsJson != null) {
      _liveSettings = LiveSettings.fromJson(jsonDecode(liveSettingsJson));
    } else {
      _liveSettings = LiveSettings();
    }
    
    // Load categories
    final categoriesJson = prefs.getString('media_categories');
    if (categoriesJson != null) {
      final List<dynamic> decoded = jsonDecode(categoriesJson);
      _categories = decoded.map((c) => CategoryModel.fromJson(c)).toList();
    } else {
      _categories = _getDefaultCategories();
    }
    
    // Update controllers
    final days = _liveSettings.countdownDuration.inDays;
    final hours = _liveSettings.countdownDuration.inHours.remainder(24);
    final minutes = _liveSettings.countdownDuration.inMinutes.remainder(60);
    final seconds = _liveSettings.countdownDuration.inSeconds.remainder(60);
    
    _daysController.text = days.toString();
    _hoursController.text = hours.toString();
    _minutesController.text = minutes.toString();
    _secondsController.text = seconds.toString();
    _categoriesTitleController.text = _liveSettings.categoriesTitle;
    _ceremonyHeaderController.text = _liveSettings.ceremonyHeader;
    _artist1Controller.text = _liveSettings.liveVotingArtist1 ?? '';
    _artist2Controller.text = _liveSettings.liveVotingArtist2 ?? '';
    _artist1ImageController.text = _liveSettings.artist1ImageUrl ?? '';
    _artist2ImageController.text = _liveSettings.artist2ImageUrl ?? '';
    
    setState(() => _isLoading = false);
  }

  List<CategoryModel> _getDefaultCategories() {
    return [
      CategoryModel(
        id: '1',
        title: 'Best Music Performance',
        icon: Icons.music_note,
        color: const Color(0xFFFF6B9D),
      ),
      CategoryModel(
        id: '2',
        title: 'Most Viewed Video',
        icon: Icons.play_circle_filled,
        color: const Color(0xFF00D9FF),
      ),
      CategoryModel(
        id: '3',
        title: 'Best Actor',
        icon: Icons.movie,
        color: const Color(0xFFFFB800),
      ),
      CategoryModel(
        id: '4',
        title: 'Rising Star',
        icon: Icons.stars,
        color: const Color(0xFF00FF94),
      ),
      CategoryModel(
        id: '5',
        title: 'Best Collaboration',
        icon: Icons.people,
        color: const Color(0xFFB794F6),
      ),
      CategoryModel(
        id: '6',
        title: 'Fan Favorite',
        icon: Icons.favorite,
        color: const Color(0xFFFF5757),
      ),
    ];
  }
  
  Future<void> _pickImageForArtist(int artistNumber) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          if (artistNumber == 1) {
            _artist1ImageController.text = image.path;
          } else {
            _artist2ImageController.text = image.path;
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Artist $artistNumber profile picture selected!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Update live settings from controllers
    final days = int.tryParse(_daysController.text) ?? 0;
    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    
    _liveSettings.countdownDuration = Duration(
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
    
    // Save the start timestamp and total duration for persistent countdown
    final totalSeconds = (days * 86400) + (hours * 3600) + (minutes * 60) + seconds;
    await prefs.setInt('media_countdown_start', DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt('media_countdown_duration', totalSeconds);
    
    _liveSettings.categoriesTitle = _categoriesTitleController.text;
    _liveSettings.ceremonyHeader = _ceremonyHeaderController.text;
    _liveSettings.liveVotingArtist1 = _artist1Controller.text.isEmpty ? null : _artist1Controller.text;
    _liveSettings.liveVotingArtist2 = _artist2Controller.text.isEmpty ? null : _artist2Controller.text;
    _liveSettings.artist1ImageUrl = _artist1ImageController.text.isEmpty ? null : _artist1ImageController.text;
    _liveSettings.artist2ImageUrl = _artist2ImageController.text.isEmpty ? null : _artist2ImageController.text;
    
    // Save to SharedPreferences
    await prefs.setString('live_settings', jsonEncode(_liveSettings.toJson()));
    await prefs.setString('media_categories', jsonEncode(_categories.map((c) => c.toJson()).toList()));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Media settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E27),
        body: Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: FloatingHeader(
        title: 'Media Controls',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.green),
            onPressed: _saveSettings,
            tooltip: 'Save All Settings',
          ),
        ],
        bottom: FloatingTabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(icon: Icon(Icons.timer), text: 'Live Timer'),
            Tab(icon: Icon(Icons.category), text: 'Categories'),
            Tab(icon: Icon(Icons.live_tv), text: 'Live'),
            Tab(icon: Icon(Icons.confirmation_number), text: 'Tickets'),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, // Account for keyboard
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildLiveTimerTab(),
            _buildCategoriesTab(),
            _buildLiveVotingTab(),
            _buildTicketManagementTab(),
          ],
        ),
      ),
    );
  }

  // ==================== TAB 1: LIVE TIMER ====================
  Widget _buildLiveTimerTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.025, // 2.5% left (more conservative)
        MediaQuery.of(context).size.height * 0.003, // 0.3% top (minimal)
        MediaQuery.of(context).size.width * 0.025, // 2.5% right
        MediaQuery.of(context).size.height * 0.003, // 0.3% bottom (minimal)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03), // 3% of screen width
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.purple.shade400],
                        ),
                        borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03),
                      ),
                      child: Icon(Icons.timer, color: Colors.white, size: MediaQuery.of(context).size.width * 0.07), // 7% of screen width
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width * 0.04), // 4% of screen width
                    Expanded(
                      child: Text(
                        'Countdown Timer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: MediaQuery.of(context).size.width * 0.05, // 5% of screen width
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.03), // 3% of screen height
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeField('Days', _daysController, Icons.calendar_today),
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width * 0.03), // 3% of screen width
                    Expanded(
                      child: _buildTimeField('Hours', _hoursController, Icons.schedule),
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width * 0.03), // 3% of screen width
                    Expanded(
                      child: _buildTimeField('Minutes', _minutesController, Icons.schedule),
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width * 0.03), // 3% of screen width
                    Expanded(
                      child: _buildTimeField('Seconds', _secondsController, Icons.schedule),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.03), // 3% of screen height
                SwitchListTile(
                  value: _liveSettings.isLiveManuallyEnabled,
                  onChanged: (value) {
                    setState(() {
                      _liveSettings.isLiveManuallyEnabled = value;
                    });
                  },
                  title: const Text('Enable Live Immediately', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'Override timer and open Live Zone now',
                    style: TextStyle(color: Colors.white.withAlpha((0.6 * 255).round())),
                  ),
                  activeThumbColor: Colors.green,
                  tileColor: Colors.white.withAlpha((0.05 * 255).round()),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03)),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.015), // 1.5% of screen height
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.title, color: Colors.amber, size: MediaQuery.of(context).size.width * 0.06), // 6% of screen width
                    SizedBox(width: MediaQuery.of(context).size.width * 0.03), // 3% of screen width
                    Text(
                      'Categories Section Title',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: MediaQuery.of(context).size.width * 0.045, // 4.5% of screen width
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02), // 2% of screen height
                TextField(
                  controller: _categoriesTitleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Title (e.g., "TODAY\'S CATEGORIES")',
                    labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
                    prefixIcon: const Icon(Icons.edit, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.015), // 1.5% of screen height
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: MediaQuery.of(context).size.width * 0.06), // 6% of screen width
                    SizedBox(width: MediaQuery.of(context).size.width * 0.03), // 3% of screen width
                    Text(
                      'Ceremony Header Text',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: MediaQuery.of(context).size.width * 0.045, // 4.5% of screen width
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02), // 2% of screen height
                TextField(
                  controller: _ceremonyHeaderController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Ceremony Header (e.g., "ARTIST AWARDS 2025 LIVE CEREMONY")',
                    labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
                    prefixIcon: const Icon(Icons.edit, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Colors.white, fontSize: MediaQuery.of(context).size.width * 0.045), // 4.5% of screen width
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
        prefixIcon: Icon(icon, color: Colors.white70, size: MediaQuery.of(context).size.width * 0.05), // 5% of screen width
        filled: true,
        fillColor: Colors.white.withAlpha((0.1 * 255).round()),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ==================== TAB 2: CATEGORIES ====================
  Widget _buildCategoriesTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.025, // 2.5% left
        MediaQuery.of(context).size.height * 0.003, // 0.3% top
        MediaQuery.of(context).size.width * 0.025, // 2.5% right
        MediaQuery.of(context).size.height * 0.003, // 0.3% bottom
      ),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: _addNewCategory,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.06, // 6% of screen width
                vertical: MediaQuery.of(context).size.height * 0.02, // 2% of screen height
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03)),
            ),
            icon: Icon(Icons.add, size: MediaQuery.of(context).size.width * 0.05), // 5% of screen width
            label: Text('Add New Category', style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.04)), // 4% of screen width
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.015), // 1.5% of screen height
          ..._categories.map((category) => _buildCategoryCard(category)),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(CategoryModel category) {
    return Dismissible(
      key: Key(category.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        setState(() {
          _categories.removeWhere((c) => c.id == category.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${category.title} deleted'),
            backgroundColor: Colors.red,
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: MediaQuery.of(context).size.width * 0.05), // 5% of screen width
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.04), // 4% of screen width
        ),
        child: Icon(Icons.delete, color: Colors.white, size: MediaQuery.of(context).size.width * 0.08), // 8% of screen width
      ),
      child: _buildGlassCard(
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.005), // 0.5% of screen height
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.025), // 2.5% of screen width
                  decoration: BoxDecoration(
                    color: category.color.withAlpha((0.2 * 255).round()),
                    borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03),
                  ),
                  child: Icon(category.icon, color: category.color, size: MediaQuery.of(context).size.width * 0.06), // 6% of screen width
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.04), // 4% of screen width
                Expanded(
                  child: Text(
                    category.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: MediaQuery.of(context).size.width * 0.04, // 4% of screen width
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue, size: MediaQuery.of(context).size.width * 0.05), // 5% of screen width
                  onPressed: () => _editCategory(category),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red, size: MediaQuery.of(context).size.width * 0.05), // 5% of screen width
                  onPressed: () => _deleteCategory(category),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.015), // 1.5% of screen height
            SwitchListTile(
              value: category.votingEnabled,
              onChanged: (value) {
                setState(() {
                  final index = _categories.indexWhere((c) => c.id == category.id);
                  _categories[index] = category.copyWith(votingEnabled: value);
                });
                _saveSettings(); // Save when voting is toggled
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(value ? 'Voting enabled for ${category.title}' : 'Voting disabled for ${category.title}'),
                    backgroundColor: value ? Colors.green : Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              title: Text('Enable Voting', style: TextStyle(color: Colors.white, fontSize: MediaQuery.of(context).size.width * 0.04)), // 4% of screen width
              subtitle: Text('Allow users to vote on content in this category', style: TextStyle(color: Colors.white54, fontSize: MediaQuery.of(context).size.width * 0.03)), // 3% of screen width
              activeThumbColor: Colors.green,
              tileColor: Colors.white.withAlpha((0.05 * 255).round()),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.02)),
            ),
            if (category.nominees.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Nominees:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...category.nominees.map((nominee) => _buildNomineeChip(nominee)),
            ],
            SizedBox(height: MediaQuery.of(context).size.height * 0.015), // 1.5% of screen height
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addNomineeToCategory(category),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.02)),
                    ),
                    icon: Icon(Icons.person_add, size: MediaQuery.of(context).size.width * 0.04), // 4% of screen width
                    label: Text('Add Nominee', style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.035)), // 3.5% of screen width
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.02), // 2% of screen width
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addVideoToCategory(category),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.02)),
                    ),
                    icon: Icon(Icons.video_library, size: MediaQuery.of(context).size.width * 0.04), // 4% of screen width
                    label: Text('Add Video', style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.035)), // 3.5% of screen width
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01), // 1% of screen height
            ElevatedButton.icon(
              onPressed: () => _addImageFromGallery(category),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.02)),
              ),
              icon: Icon(Icons.photo_library, size: MediaQuery.of(context).size.width * 0.04), // 4% of screen width
              label: Text('Add Image from Gallery', style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.035)), // 3.5% of screen width
            ),
            if (category.videos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Videos (${category.videos.length}):',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...category.videos.map((video) => _buildVideoChip(video, category)),
            ],
            if (category.images.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Images (${category.images.length}):',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...category.images.map((image) => _buildImageChip(image, category)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNomineeChip(ArtistNominee nominee) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: Colors.blue,
        child: Text(nominee.artistName[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
      ),
      label: Text(
        '${nominee.artistName}${nominee.workTitle != null ? ' - ${nominee.workTitle}' : ''}',
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.white.withAlpha((0.15 * 255).round()),
      deleteIcon: const Icon(Icons.close, size: 18, color: Colors.red),
      onDeleted: () {
        setState(() {
          for (var category in _categories) {
            category.nominees.removeWhere((n) => n.id == nominee.id);
          }
        });
      },
    );
  }

  void _addNewCategory() {
    showDialog(
      context: context,
      builder: (context) => _CategoryEditorDialog(
        onSave: (title, icon, color) {
          setState(() {
            _categories.add(CategoryModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: title,
              icon: icon,
              color: color,
            ));
          });
        },
      ),
    );
  }

  void _editCategory(CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => _CategoryEditorDialog(
        initialTitle: category.title,
        initialIcon: category.icon,
        initialColor: category.color,
        onSave: (title, icon, color) {
          setState(() {
            final index = _categories.indexWhere((c) => c.id == category.id);
            _categories[index] = category.copyWith(title: title, icon: icon, color: color);
          });
        },
      ),
    );
  }

  void _addNomineeToCategory(CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => _NomineeEditorDialog(
        onSave: (artistName, workTitle, imageUrl, expiresInDays) {
          setState(() {
            final index = _categories.indexWhere((c) => c.id == category.id);
            final updatedNominees = List<ArtistNominee>.from(_categories[index].nominees)
              ..add(ArtistNominee(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                artistName: artistName,
                workTitle: workTitle,
                imageUrl: imageUrl,
                expiresInDays: expiresInDays,
              ));
            _categories[index] = _categories[index].copyWith(nominees: updatedNominees);
          });
          _saveSettings(); // Auto-save to SharedPreferences
        },
      ),
    );
  }

  void _addVideoToCategory(CategoryModel category) async {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => _VideoEditorDialog(
        category: category,
        onSave: (title, url, thumbnailPath, expiresInDays) {
          setState(() {
            final index = _categories.indexWhere((c) => c.id == category.id);
            final updatedVideos = List<CategoryVideo>.from(_categories[index].videos)
              ..add(CategoryVideo(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: title,
                youtubeUrl: url,
                thumbnailUrl: thumbnailPath,
                expiresInDays: expiresInDays,
              ));
            _categories[index] = _categories[index].copyWith(videos: updatedVideos);
          });
          _saveSettings(); // Auto-save to SharedPreferences
        },
      ),
    );
  }

  Future<void> _addImageFromGallery(CategoryModel category) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile == null) return; // User cancelled
      
      final TextEditingController captionController = TextEditingController();
      int? selectedExpiration; // null = never expires
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF1A1E3F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Image', style: TextStyle(color: Colors.white, fontSize: 20)),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(pickedFile.path),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 150,
                            color: Colors.grey.withAlpha((0.3 * 255).round()),
                            child: const Center(
                              child: Icon(Icons.error, color: Colors.red, size: 40),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: captionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Caption',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Describe this image...',
                        hintStyle: TextStyle(color: Colors.white.withAlpha((0.5 * 255).round())),
                        filled: true,
                        fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Post Duration', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildExpirationChip('Never', null, selectedExpiration, setDialogState, (val) => selectedExpiration = val),
                        _buildExpirationChip('1 Day', 1, selectedExpiration, setDialogState, (val) => selectedExpiration = val),
                        _buildExpirationChip('3 Days', 3, selectedExpiration, setDialogState, (val) => selectedExpiration = val),
                        _buildExpirationChip('1 Week', 7, selectedExpiration, setDialogState, (val) => selectedExpiration = val),
                        _buildExpirationChip('2 Weeks', 14, selectedExpiration, setDialogState, (val) => selectedExpiration = val),
                        _buildExpirationChip('1 Month', 30, selectedExpiration, setDialogState, (val) => selectedExpiration = val),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    final index = _categories.indexWhere((c) => c.id == category.id);
                    final updatedImages = List<CategoryImage>.from(_categories[index].images)
                      ..add(CategoryImage(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        imageUrl: pickedFile.path,
                        caption: captionController.text.trim().isEmpty ? null : captionController.text.trim(),
                        expiresInDays: selectedExpiration,
                      ));
                    _categories[index] = _categories[index].copyWith(images: updatedImages);
                  });
                  _saveSettings(); // Auto-save to SharedPreferences
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Image added successfully!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: category.color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildExpirationChip(String label, int? days, int? selected, StateSetter setDialogState, ValueChanged<int?> onChanged) {
    final isSelected = selected == days;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool value) {
        setDialogState(() {
          onChanged(days);
        });
      },
      selectedColor: Colors.blue.withAlpha((0.5 * 255).round()),
      backgroundColor: Colors.white.withAlpha((0.1 * 255).round()),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _deleteCategory(CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E3F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Category', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${category.title}"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _categories.removeWhere((c) => c.id == category.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${category.title} deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoChip(CategoryVideo video, CategoryModel category) {
    return Chip(
      avatar: const CircleAvatar(
        backgroundColor: Colors.purple,
        child: Icon(Icons.play_arrow, color: Colors.white, size: 16),
      ),
      label: Text(
        video.title,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.white.withAlpha((0.15 * 255).round()),
      deleteIcon: const Icon(Icons.close, size: 18, color: Colors.red),
      onDeleted: () {
        setState(() {
          final index = _categories.indexWhere((c) => c.id == category.id);
          final updatedVideos = List<CategoryVideo>.from(_categories[index].videos)
            ..removeWhere((v) => v.id == video.id);
          _categories[index] = _categories[index].copyWith(videos: updatedVideos);
        });
      },
    );
  }

  Widget _buildImageChip(CategoryImage image, CategoryModel category) {
    return Chip(
      avatar: const CircleAvatar(
        backgroundColor: Colors.green,
        child: Icon(Icons.image, color: Colors.white, size: 16),
      ),
      label: Text(
        image.caption ?? 'Image',
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.white.withAlpha((0.15 * 255).round()),
      deleteIcon: const Icon(Icons.close, size: 18, color: Colors.red),
      onDeleted: () {
        setState(() {
          final index = _categories.indexWhere((c) => c.id == category.id);
          final updatedImages = List<CategoryImage>.from(_categories[index].images)
            ..removeWhere((img) => img.id == image.id);
          _categories[index] = _categories[index].copyWith(images: updatedImages);
        });
      },
    );
  }

  // ==================== BROADCAST STUDIO ====================
  Widget _buildBroadcastStudio() {
    final broadcast = BroadcastService.instance;
    
    return AnimatedBuilder(
      animation: broadcast,
      builder: (context, child) {
        return _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03), // 3% of screen width
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.orange.shade400],
                      ),
                      borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03),
                    ),
                    child: Icon(Icons.videocam, color: Colors.white, size: MediaQuery.of(context).size.width * 0.07), // 7% of screen width
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.04), // 4% of screen width
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Live Broadcast Studio',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: MediaQuery.of(context).size.width * 0.05, // 5% of screen width
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.005), // 0.5% of screen height
                        Text(
                          broadcast.isLive 
                              ? '🔴 LIVE - Users are watching!' 
                              : 'Start camera, screen record, or share video',
                          style: TextStyle(
                            color: broadcast.isLive ? Colors.red : Colors.white70,
                            fontSize: 13,
                            fontWeight: broadcast.isLive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Broadcast preview frame (300px height for better studio view)
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withAlpha((0.9 * 255).round()),
                      Colors.grey.shade900.withAlpha((0.8 * 255).round()),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: broadcast.isLive 
                        ? Colors.red.withAlpha((0.8 * 255).round())
                        : Colors.grey.withAlpha((0.3 * 255).round()),
                    width: broadcast.isLive ? 3 : 2,
                  ),
                  boxShadow: broadcast.isLive ? [
                    BoxShadow(
                      color: Colors.red.withAlpha((0.4 * 255).round()),
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  ] : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Main broadcast content
                      _buildBroadcastContent(broadcast),
                      
                      // Live indicator
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width * 0.03, // 3% of screen width
                            vertical: MediaQuery.of(context).size.height * 0.0075, // 0.75% of screen height
                          ),
                          decoration: BoxDecoration(
                            color: broadcast.isLive ? Colors.red : Colors.grey,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: (broadcast.isLive ? Colors.red : Colors.grey)
                                    .withAlpha((0.5 * 255).round()),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Colors.white, size: 8),
                              const SizedBox(width: 6),
                              Text(
                                broadcast.isLive ? 'LIVE' : 'OFFLINE',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Source indicator (top right)
                      if (broadcast.isLive)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: MediaQuery.of(context).size.width * 0.025, // 2.5% of screen width
                              vertical: MediaQuery.of(context).size.height * 0.006, // 0.6% of screen height
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha((0.7 * 255).round()),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getSourceIcon(broadcast.currentSource),
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _getSourceName(broadcast.currentSource),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Source selection buttons
              if (!broadcast.isLive) ...[
                const Text(
                  'Select Broadcast Source:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSourceButton(
                        icon: Icons.videocam,
                        label: 'Camera',
                        color: Colors.blue,
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await broadcast.initializeCameras();
                          final success = await broadcast.startCameraBroadcast();
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(success 
                                    ? '🎥 Camera broadcast started!' 
                                    : '❌ ${broadcast.cameraError ?? "Failed to start camera"}'),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSourceButton(
                        icon: Icons.screen_share,
                        label: 'Screen',
                        color: Colors.purple,
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final success = await broadcast.startScreenRecordingBroadcast();
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(success 
                                    ? '📱 Screen recording started!' 
                                    : '❌ Failed to start screen recording'),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSourceButton(
                        icon: Icons.video_library,
                        label: 'Video',
                        color: Colors.orange,
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final success = await broadcast.selectVideoFromGallery();
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(success 
                                    ? '🎬 Video selected and broadcasting!' 
                                    : '❌ No video selected'),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // User Go Live Access Control - under source buttons
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.05 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withAlpha((0.2 * 255).round()),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_alt,
                        color: _liveSettings.allowUsersToGoLive ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'User Go Live Access',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _liveSettings.allowUsersToGoLive
                                  ? 'Users can access the Go Live button'
                                  : 'Go Live button disabled for users',
                              style: TextStyle(
                                color: Colors.white.withAlpha((0.7 * 255).round()),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _liveSettings.allowUsersToGoLive,
                        activeThumbColor: Colors.green,
                        onChanged: (value) {
                          setState(() {
                            _liveSettings.allowUsersToGoLive = value;
                          });
                          _saveSettings();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(value
                                  ? '✅ Users can now access Go Live button'
                                  : '🔒 Go Live button disabled for users'),
                              backgroundColor: value ? Colors.green : Colors.red,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              
              // Active broadcast controls
              if (broadcast.isLive) ...[
                // Source controls
                Row(
                  children: [
                    if (broadcast.currentSource == BroadcastSource.camera) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await broadcast.flipCamera();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.cameraswitch, size: 20),
                          label: const Text('Flip Camera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (broadcast.currentSource == BroadcastSource.screen) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            broadcast.enableBackgroundRecording(
                                !broadcast.screenRecordingInBackground);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(broadcast.screenRecordingInBackground
                                    ? '✅ Recording will continue in background'
                                    : '⏸️ Background recording disabled'),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: broadcast.screenRecordingInBackground 
                                ? Colors.green 
                                : Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(
                            broadcast.screenRecordingInBackground 
                                ? Icons.play_circle 
                                : Icons.pause_circle,
                            size: 20,
                          ),
                          label: Text(broadcast.screenRecordingInBackground 
                              ? 'Recording in BG' 
                              : 'Enable BG Record'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await broadcast.stopBroadcast();
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('⏹️ Broadcast stopped'),
                                backgroundColor: Colors.grey,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.stop_circle, size: 20),
                        label: const Text('Stop Broadcast'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Effects and overlays
                const Text(
                  'Studio Controls:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildControlChip(
                      icon: Icons.flip_camera_android,
                      label: broadcast.mirrorMode ? 'Mirror: ON' : 'Mirror: OFF',
                      isActive: broadcast.mirrorMode,
                      onTap: broadcast.toggleMirrorMode,
                    ),
                    _buildControlChip(
                      icon: Icons.face_retouching_natural,
                      label: broadcast.beautyFilterEnabled ? 'Beauty: ON' : 'Beauty: OFF',
                      isActive: broadcast.beautyFilterEnabled,
                      onTap: broadcast.toggleBeautyFilter,
                    ),
                    _buildControlChip(
                      icon: Icons.picture_in_picture_alt,
                      label: broadcast.hasOverlay ? 'PIP: ON' : 'Add PIP',
                      isActive: broadcast.hasOverlay,
                      onTap: () {
                        if (broadcast.hasOverlay) {
                          broadcast.removeOverlay();
                        } else {
                          _showAddOverlayDialog(context, broadcast);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBroadcastContent(BroadcastService broadcast) {
    if (!broadcast.isLive) {
      // Offline state
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off,
              size: 64,
              color: Colors.white.withAlpha((0.3 * 255).round()),
            ),
            const SizedBox(height: 12),
            Text(
              'Broadcast Studio Ready',
              style: TextStyle(
                color: Colors.white.withAlpha((0.5 * 255).round()),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a source below to start broadcasting',
              style: TextStyle(
                color: Colors.white.withAlpha((0.3 * 255).round()),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Live broadcast content based on source
    switch (broadcast.currentSource) {
      case BroadcastSource.camera:
        if (broadcast.isLoadingCamera) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Starting camera...',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          );
        }
        if (broadcast.isCameraInitialized && broadcast.cameraController != null) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scaleByVector3(Vector3(broadcast.mirrorMode ? -1.0 : 1.0, 1.0, 1.0)),
            child: CameraPreview(broadcast.cameraController!),
          );
        }
        if (broadcast.cameraError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  broadcast.cameraError!,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        break;

      case BroadcastSource.screen:
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.withAlpha((0.3 * 255).round()),
                        Colors.red.withAlpha((0.3 * 255).round()),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withAlpha((0.5 * 255).round()),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.screen_share,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red, Colors.red.shade900],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withAlpha((0.6 * 255).round()),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 12, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        '� SCREEN SHARING LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  broadcast.screenRecordingInBackground 
                      ? '✅ Recording in background - You can leave this screen'
                      : '⚠️ Stay on this screen to keep recording',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.9 * 255).round()),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'Your screen is being broadcast to users in real-time',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.6 * 255).round()),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );

      case BroadcastSource.video:
        if (broadcast.selectedVideo != null && broadcast.videoController != null) {
          // Show actual video playback
          if (broadcast.videoController!.value.isInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (broadcast.videoController != null) {
                broadcast.videoController!.setVolume(1.0);
              }
            });
            return SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: broadcast.videoController!.value.size.width,
                  height: broadcast.videoController!.value.size.height,
                  child: VideoPlayer(broadcast.videoController!),
                ),
              ),
            );
          } else {
            // Loading video
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 16),
                  Text(
                    'Loading video...',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            );
          }
        } else if (broadcast.selectedVideo != null) {
          // Fallback display when video controller not initialized
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.withAlpha((0.3 * 255).round()),
                          Colors.deepOrange.withAlpha((0.3 * 255).round()),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withAlpha((0.5 * 255).round()),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_circle_filled,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange, Colors.deepOrange.shade900],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withAlpha((0.6 * 255).round()),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 12, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text(
                          '🎬 VIDEO STREAMING LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      broadcast.selectedVideo!.path.split('/').last,
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.9 * 255).round()),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Video is playing for all users watching',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.6 * 255).round()),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        break;

      case BroadcastSource.none:
        break;
    }

    return const SizedBox.shrink();
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withAlpha((0.7 * 255).round())],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha((0.3 * 255).round()),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? Colors.green.withAlpha((0.3 * 255).round())
              : Colors.white.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.green : Colors.white.withAlpha((0.3 * 255).round()),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.green : Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.green : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSourceIcon(BroadcastSource source) {
    switch (source) {
      case BroadcastSource.camera:
        return Icons.videocam;
      case BroadcastSource.screen:
        return Icons.screen_share;
      case BroadcastSource.video:
        return Icons.video_library;
      case BroadcastSource.none:
        return Icons.videocam_off;
    }
  }

  String _getSourceName(BroadcastSource source) {
    switch (source) {
      case BroadcastSource.camera:
        return 'CAMERA';
      case BroadcastSource.screen:
        return 'SCREEN';
      case BroadcastSource.video:
        return 'VIDEO';
      case BroadcastSource.none:
        return 'OFFLINE';
    }
  }

  void _showAddOverlayDialog(BuildContext context, BroadcastService broadcast) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E3F),
        title: const Text(
          'Add Picture-in-Picture',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add a small overlay with:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            if (broadcast.currentSource != BroadcastSource.camera)
              _buildSourceButton(
                icon: Icons.videocam,
                label: 'Camera Overlay',
                color: Colors.blue,
                onTap: () async {
                  Navigator.pop(context);
                  // Initialize camera for overlay if needed
                  if (!broadcast.isCameraInitialized) {
                    await broadcast.initializeCameras();
                    await broadcast.startCameraBroadcast();
                  }
                  broadcast.addOverlay(BroadcastSource.camera);
                },
              ),
            if (broadcast.currentSource != BroadcastSource.screen)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildSourceButton(
                  icon: Icons.screen_share,
                  label: 'Screen Overlay',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    broadcast.addOverlay(BroadcastSource.screen);
                  },
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ==================== TAB 3: LIVE VOTING ====================
  Widget _buildLiveVotingTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.025, // 2.5% left
        MediaQuery.of(context).size.height * 0.003, // 0.3% top
        MediaQuery.of(context).size.width * 0.025, // 2.5% right
        MediaQuery.of(context).size.height * 0.003, // 0.3% bottom
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ADMIN BROADCAST STUDIO
          _buildBroadcastStudio(),
          SizedBox(height: MediaQuery.of(context).size.height * 0.015), // 1.5% of screen height
          // LIVE VOTING ARTISTS
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03), // 3% of screen width
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade400, Colors.pink.shade400],
                        ),
                        borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03),
                      ),
                      child: Icon(Icons.how_to_vote, color: Colors.white, size: MediaQuery.of(context).size.width * 0.07), // 7% of screen width
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width * 0.04), // 4% of screen width
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live Voting Artists',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Set 2 artists for live head-to-head voting',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _artist1Controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Artist 1 Name',
                    labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
                    prefixIcon: const Icon(Icons.person, color: Colors.blue),
                    filled: true,
                    fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Artist 1 Profile Picture Picker (Clickable)
                GestureDetector(
                  onTap: () => _pickImageForArtist(1),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withAlpha((0.3 * 255).round()),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha((0.3 * 255).round()),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue, width: 2),
                          ),
                          child: _artist1ImageController.text.isNotEmpty
                              ? ClipOval(
                                  child: _artist1ImageController.text.startsWith('http')
                                      ? Image.network(
                                          _artist1ImageController.text,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        )
                                      : Image.file(
                                          File(_artist1ImageController.text),
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                )
                              : const Icon(Icons.person, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Artist 1 Profile Picture',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _artist1ImageController.text.isNotEmpty
                                    ? 'Tap to change image'
                                    : 'Tap to select image from gallery',
                                style: TextStyle(
                                  color: Colors.white.withAlpha((0.7 * 255).round()),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.camera_alt, color: Colors.blue, size: 28),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _artist2Controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Artist 2 Name',
                    labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
                    prefixIcon: const Icon(Icons.person, color: Colors.purple),
                    filled: true,
                    fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Artist 2 Profile Picture Picker (Clickable)
                GestureDetector(
                  onTap: () => _pickImageForArtist(2),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.purple.withAlpha((0.3 * 255).round()),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.purple.withAlpha((0.3 * 255).round()),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.purple, width: 2),
                          ),
                          child: _artist2ImageController.text.isNotEmpty
                              ? ClipOval(
                                  child: _artist2ImageController.text.startsWith('http')
                                      ? Image.network(
                                          _artist2ImageController.text,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        )
                                      : Image.file(
                                          File(_artist2ImageController.text),
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                )
                              : const Icon(Icons.person, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Artist 2 Profile Picture',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _artist2ImageController.text.isNotEmpty
                                    ? 'Tap to change image'
                                    : 'Tap to select image from gallery',
                                style: TextStyle(
                                  color: Colors.white.withAlpha((0.7 * 255).round()),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.camera_alt, color: Colors.purple, size: 28),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildVoteCountCard(
                        'Artist 1 Votes',
                        _liveSettings.votesForArtist1,
                        Colors.blue,
                        Icons.person,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildVoteCountCard(
                        'Artist 2 Votes',
                        _liveSettings.votesForArtist2,
                        Colors.purple,
                        Icons.person,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    setState(() {
                      _liveSettings.votesForArtist1 = 0;
                      _liveSettings.votesForArtist2 = 0;
                      _liveSettings.userVotedFor.clear(); // Clear all user votes
                    });
                    await _saveSettings();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All votes and voting history reset!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset All Votes'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Generate new broadcast ID
                    final newBroadcastId = 'broadcast_${DateTime.now().millisecondsSinceEpoch}';
                    
                    setState(() {
                      // Keep current votes, but start a new broadcast session
                      // This allows users to vote again
                      _liveSettings.currentBroadcastId = newBroadcastId;
                      _liveSettings.broadcastVotes[newBroadcastId] = {};
                    });
                    await _saveSettings();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🎬 New broadcast started! Users can vote again.'),
                          backgroundColor: Colors.blue,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.broadcast_on_personal),
                  label: const Text('Start New Broadcast Session'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteCountCard(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withAlpha((0.25 * 255).round()),
            color.withAlpha((0.1 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.4 * 255).round())),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha((0.8 * 255).round()),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets? margin}) {
    return Container(
      margin: margin,
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.025), // 2.5% of screen width (reduced)
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.04), // 4% of screen width
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withAlpha((0.12 * 255).round()),
            Colors.white.withAlpha((0.06 * 255).round()),
          ],
        ),
        border: Border.all(
          color: Colors.white.withAlpha((0.2 * 255).round()),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.3 * 255).round()),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.04), // 4% of screen width
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }

  // ==================== TAB 4: TICKET MANAGEMENT ====================
  
  Widget _buildTicketManagementTab() {
    return const AdminTicketControlScreen();
  }
}

// ==================== DIALOGS ====================

class _CategoryEditorDialog extends StatefulWidget {
  final String? initialTitle;
  final IconData? initialIcon;
  final Color? initialColor;
  final Function(String title, IconData icon, Color color) onSave;

  const _CategoryEditorDialog({
    this.initialTitle,
    this.initialIcon,
    this.initialColor,
    required this.onSave,
  });

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late TextEditingController _titleController;
  late IconData _selectedIcon;
  late Color _selectedColor;

  final List<IconData> _availableIcons = [
    Icons.music_note,
    Icons.play_circle_filled,
    Icons.movie,
    Icons.stars,
    Icons.people,
    Icons.favorite,
    Icons.audiotrack,
    Icons.mic,
    Icons.video_library,
    Icons.album,
  ];

  final List<Color> _availableColors = [
    const Color(0xFFFF6B9D),
    const Color(0xFF00D9FF),
    const Color(0xFFFFB800),
    const Color(0xFF00FF94),
    const Color(0xFFB794F6),
    const Color(0xFFFF5757),
    const Color(0xFF4CAF50),
    const Color(0xFF2196F3),
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _selectedIcon = widget.initialIcon ?? Icons.music_note;
    _selectedColor = widget.initialColor ?? const Color(0xFFFF6B9D);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1E3F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.initialTitle == null ? 'Add Category' : 'Edit Category',
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Category Title',
                labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
                filled: true,
                fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Select Icon:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableIcons.map((icon) {
                final isSelected = icon == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedColor.withAlpha((0.3 * 255).round())
                          : Colors.white.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _selectedColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(icon, color: isSelected ? _selectedColor : Colors.white70, size: 28),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Select Color:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableColors.map((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty) {
              widget.onSave(_titleController.text, _selectedIcon, _selectedColor);
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _NomineeEditorDialog extends StatefulWidget {
  final Function(String artistName, String? workTitle, String? imageUrl, int? expiresInDays) onSave;

  const _NomineeEditorDialog({required this.onSave});

  @override
  State<_NomineeEditorDialog> createState() => _NomineeEditorDialogState();
}

class _NomineeEditorDialogState extends State<_NomineeEditorDialog> {
  final TextEditingController _artistNameController = TextEditingController();
  final TextEditingController _workTitleController = TextEditingController();
  String? _imagePath;
  int? _selectedExpiration; // null = never expires

  @override
  void dispose() {
    _artistNameController.dispose();
    _workTitleController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null && mounted) {
        setState(() {
          _imagePath = pickedFile.path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Image selected!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildExpirationChip(String label, int? days) {
    final isSelected = _selectedExpiration == days;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool value) {
        setState(() {
          _selectedExpiration = days;
        });
      },
      selectedColor: Colors.blue.withAlpha((0.5 * 255).round()),
      backgroundColor: Colors.white.withAlpha((0.1 * 255).round()),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1E3F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Nominee', style: TextStyle(color: Colors.white, fontSize: 20)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _artistNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Artist Name *',
                  labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
                  filled: true,
                  fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _workTitleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Work Title (optional)',
                  labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
                  filled: true,
                  fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                icon: const Icon(Icons.photo_library, size: 20),
                label: Text(_imagePath == null ? 'Add Image (Optional)' : 'Image Selected'),
              ),
              if (_imagePath != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_imagePath!),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha((0.3 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, color: Colors.red, size: 32),
                              SizedBox(height: 8),
                              Text(
                                'Error loading image',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Post Duration', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildExpirationChip('Never', null),
                  _buildExpirationChip('1 Day', 1),
                  _buildExpirationChip('3 Days', 3),
                  _buildExpirationChip('1 Week', 7),
                  _buildExpirationChip('2 Weeks', 14),
                  _buildExpirationChip('1 Month', 30),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_artistNameController.text.trim().isNotEmpty) {
              widget.onSave(
                _artistNameController.text.trim(),
                _workTitleController.text.trim().isEmpty ? null : _workTitleController.text.trim(),
                _imagePath,
                _selectedExpiration,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Nominee added successfully!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter artist name'), backgroundColor: Colors.orange),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// Video Editor Dialog Widget
class _VideoEditorDialog extends StatefulWidget {
  final CategoryModel category;
  final Function(String title, String url, String? thumbnailPath, int? expiresInDays) onSave;

  const _VideoEditorDialog({required this.category, required this.onSave});

  @override
  State<_VideoEditorDialog> createState() => _VideoEditorDialogState();
}

class _VideoEditorDialogState extends State<_VideoEditorDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  String? _thumbnailPath;
  int? _selectedExpiration;

  Future<void> _pickThumbnail() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null && mounted) {
        setState(() {
          _thumbnailPath = pickedFile.path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Thumbnail selected!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildExpirationChip(String label, int? days) {
    final isSelected = _selectedExpiration == days;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool value) {
        setState(() {
          _selectedExpiration = days;
        });
      },
      selectedColor: Colors.blue.withAlpha((0.5 * 255).round()),
      backgroundColor: Colors.white.withAlpha((0.1 * 255).round()),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1E3F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add YouTube Video', style: TextStyle(color: Colors.white, fontSize: 20)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Video Title *',
                  labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
                  filled: true,
                  fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'YouTube URL *',
                  labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
                  prefixIcon: const Icon(Icons.link, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickThumbnail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                icon: const Icon(Icons.photo_library, size: 20),
                label: Text(_thumbnailPath == null ? 'Add Thumbnail (Optional)' : 'Thumbnail Selected'),
              ),
              if (_thumbnailPath != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_thumbnailPath!),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha((0.3 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, color: Colors.red, size: 32),
                              SizedBox(height: 8),
                              Text(
                                'Error loading image',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Post Duration', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildExpirationChip('Never', null),
                  _buildExpirationChip('1 Day', 1),
                  _buildExpirationChip('3 Days', 3),
                  _buildExpirationChip('1 Week', 7),
                  _buildExpirationChip('2 Weeks', 14),
                  _buildExpirationChip('1 Month', 30),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.trim().isNotEmpty && _urlController.text.trim().isNotEmpty) {
              widget.onSave(
                _titleController.text.trim(),
                _urlController.text.trim(),
                _thumbnailPath,
                _selectedExpiration,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Video added successfully!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill in title and URL'), backgroundColor: Colors.orange),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.category.color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

