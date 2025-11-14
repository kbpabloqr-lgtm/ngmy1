import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';

class AdminOnboardingScreen extends StatefulWidget {
  const AdminOnboardingScreen({super.key});

  @override
  State<AdminOnboardingScreen> createState() => _AdminOnboardingScreenState();
}

class _AdminOnboardingScreenState extends State<AdminOnboardingScreen> {
  final List<OnboardingPageConfig> _pages = [];
  bool _isLoading = true;
  String? _appLogoPath;

  @override
  void initState() {
    super.initState();
    _loadOnboardingConfig();
  }

  Future<void> _loadOnboardingConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final pagesJson = prefs.getStringList('admin_onboarding_config') ?? [];
    
    if (pagesJson.isEmpty) {
      // Create default pages
      _pages.addAll([
        OnboardingPageConfig(
          title: 'Create images',
          subtitle: 'Create stunning images with\ngenerative prompts',
          buttonText: 'Next',
        ),
        OnboardingPageConfig(
          title: 'Generate videos',
          subtitle: 'Generate captivating videos using\nour AI models',
          buttonText: 'Next',
        ),
        OnboardingPageConfig(
          title: 'Break the limit',
          subtitle: 'The only limit is your imagination',
          buttonText: "Let's Go",
          isLastPage: true,
        ),
      ]);
    } else {
      _pages.addAll(pagesJson.map((json) {
        final data = jsonDecode(json);
        return OnboardingPageConfig.fromJson(data);
      }));
    }
    
    // Load app logo
    _appLogoPath = prefs.getString('app_logo_path');
    
    setState(() => _isLoading = false);
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final pagesJson = _pages.map((page) => jsonEncode(page.toJson())).toList();
    await prefs.setStringList('admin_onboarding_config', pagesJson);
    
    // Save app logo
    if (_appLogoPath != null) {
      await prefs.setString('app_logo_path', _appLogoPath!);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Onboarding configuration saved!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _pickImageForPage(int index) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    
    if (pickedFile != null) {
      setState(() {
        _pages[index].imagePath = pickedFile.path;
      });
    }
  }

  Future<void> _pickAppLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    
    if (pickedFile != null) {
      setState(() {
        _appLogoPath = pickedFile.path;
      });
      _saveConfig(); // Auto-save when logo is changed
    }
  }

  void _addPage() {
    setState(() {
      _pages.add(OnboardingPageConfig(
        title: 'New Page',
        subtitle: 'Enter description here',
        buttonText: 'Next',
      ));
    });
  }

  void _removePage(int index) {
    if (_pages.length > 1) {
      setState(() {
        _pages.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E27),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Onboarding Configuration',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _addPage,
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _saveConfig,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Logo Configuration
            _buildAppLogoSection(),
            
            const SizedBox(height: 24),
            
            // Onboarding Pages
            const Text(
              'Onboarding Pages',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            ...List.generate(_pages.length, (index) => _buildPageEditor(index)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppLogoSection() {
    return Card(
      color: Colors.white.withAlpha(25),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App Logo Configuration',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Login Screen Logo',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 12),
            
            GestureDetector(
              onTap: _pickAppLogo,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(13),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withAlpha(51),
                    width: 1,
                  ),
                ),
                child: _appLogoPath != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_appLogoPath!),
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                              onPressed: () {
                                setState(() => _appLogoPath = null);
                                _saveConfig();
                              },
                            ),
                          ),
                        ],
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 40,
                            color: Colors.white70,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap to add app logo',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Replaces default store icon on login screen',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
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

  Widget _buildPageEditor(int index) {
    final page = _pages[index];
    
    return Card(
      color: Colors.white.withAlpha(25),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Page ${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_pages.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removePage(index),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Image section
            GestureDetector(
              onTap: () => _pickImageForPage(index),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(13),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withAlpha(51),
                    width: 1,
                  ),
                ),
                child: page.imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(
                          File(page.imagePath!),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 48,
                            color: Colors.white.withAlpha(128),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to add image',
                            style: TextStyle(
                              color: Colors.white.withAlpha(179),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Title field
            TextFormField(
              initialValue: page.title,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: Colors.white.withAlpha(179)),
                filled: true,
                fillColor: Colors.white.withAlpha(25),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withAlpha(51)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withAlpha(51)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
              onChanged: (value) {
                page.title = value;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Subtitle field
            TextFormField(
              initialValue: page.subtitle,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Subtitle',
                labelStyle: TextStyle(color: Colors.white.withAlpha(179)),
                filled: true,
                fillColor: Colors.white.withAlpha(25),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withAlpha(51)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withAlpha(51)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
              onChanged: (value) {
                page.subtitle = value;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Button text field
            TextFormField(
              initialValue: page.buttonText,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Button Text',
                labelStyle: TextStyle(color: Colors.white.withAlpha(179)),
                filled: true,
                fillColor: Colors.white.withAlpha(25),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withAlpha(51)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withAlpha(51)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
              onChanged: (value) {
                page.buttonText = value;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Is last page checkbox
            Row(
              children: [
                Checkbox(
                  value: page.isLastPage,
                  onChanged: (value) {
                    setState(() {
                      page.isLastPage = value ?? false;
                    });
                  },
                  activeColor: Colors.white,
                  checkColor: const Color(0xFF0A0E27),
                ),
                const Text(
                  'This is the last page',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPageConfig {
  String title;
  String subtitle;
  String? imagePath;
  String buttonText;
  bool isLastPage;

  OnboardingPageConfig({
    required this.title,
    required this.subtitle,
    this.imagePath,
    required this.buttonText,
    this.isLastPage = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'imagePath': imagePath,
      'buttonText': buttonText,
      'isLastPage': isLastPage,
    };
  }

  factory OnboardingPageConfig.fromJson(Map<String, dynamic> json) {
    return OnboardingPageConfig(
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      imagePath: json['imagePath'],
      buttonText: json['buttonText'] ?? 'Next',
      isLastPage: json['isLastPage'] ?? false,
    );
  }
}
