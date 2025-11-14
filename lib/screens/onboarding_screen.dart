import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Default onboarding data - can be customized by admin
  List<OnboardingPage> _onboardingPages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOnboardingData();
  }

  Future<void> _loadOnboardingData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load admin-configured onboarding or use defaults
    final customPages = prefs.getStringList('admin_onboarding_pages');
    
    if (customPages != null && customPages.isNotEmpty) {
      // Load custom admin pages
      _onboardingPages = await _loadCustomPages(customPages);
    } else {
      // Use default beautiful pages
      _onboardingPages = _getDefaultPages();
    }
    
    setState(() => _isLoading = false);
  }

  List<OnboardingPage> _getDefaultPages() {
    return [
      OnboardingPage(
        title: "Create images",
        subtitle: "Create stunning images with\ngenerative prompts",
        imagePath: null, // Will use default gradient
        gradientColors: [
          const Color(0xFF1A1A2E),
          const Color(0xFF16213E),
          const Color(0xFF0F3460),
        ],
        buttonText: "Next",
      ),
      OnboardingPage(
        title: "Generate videos",
        subtitle: "Generate captivating videos using\nour AI models",
        imagePath: null,
        gradientColors: [
          const Color(0xFF0F3460),
          const Color(0xFF16213E),
          const Color(0xFF1A1A2E),
        ],
        buttonText: "Next",
      ),
      OnboardingPage(
        title: "Break the limit",
        subtitle: "The only limit is your imagination",
        imagePath: null,
        gradientColors: [
          const Color(0xFF1A1A2E),
          const Color(0xFF16213E),
          const Color(0xFF0F3460),
        ],
        buttonText: "Let's Go",
        isLastPage: true,
      ),
    ];
  }

  Future<List<OnboardingPage>> _loadCustomPages(List<String> customPages) async {
    // Load custom pages from admin configuration
    // For now, fall back to default pages if no custom configuration is available
    // In the future, this could load from SharedPreferences or a config file
    return _getDefaultPages();
  }

  void _nextPage() {
    if (_currentPage < _onboardingPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F3460),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _onboardingPages[_currentPage].gradientColors,
              ),
            ),
          ),
          
          // Page view
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: _onboardingPages.length,
            itemBuilder: (context, index) {
              return _buildOnboardingPage(_onboardingPages[index], index);
            },
          ),
          
          // Page indicators
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.18, // 18% from bottom
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _onboardingPages.length,
                (index) => Container(
                  margin: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.01), // 1% margin
                  width: _currentPage == index ? MediaQuery.of(context).size.width * 0.06 : MediaQuery.of(context).size.width * 0.02, // 6% or 2% of screen width
                  height: MediaQuery.of(context).size.height * 0.01, // 1% of screen height
                  decoration: BoxDecoration(
                    color: _currentPage == index 
                        ? Colors.white 
                        : Colors.white.withAlpha(77),
                    borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.01),
                  ),
                ),
              ),
            ),
          ),
          
          // Next button
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.06, // 6% from bottom
            left: MediaQuery.of(context).size.width * 0.06, // 6% from left
            right: MediaQuery.of(context).size.width * 0.06, // 6% from right
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.02), // 2% of screen height
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.06), // 6% of screen width
                ),
                elevation: 0,
              ),
              child: Text(
                _onboardingPages[_currentPage].buttonText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingPage page, int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            constraints.maxWidth * 0.06, // 6% left
            constraints.maxHeight * 0.05, // 5% top (reduced from fixed 80)
            constraints.maxWidth * 0.06, // 6% right
            constraints.maxHeight * 0.02, // 2% bottom
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight * 0.8, // Ensure minimum height
            ),
            child: Column(
              children: [
                // Image container
                Container(
                  width: double.infinity,
                  height: constraints.maxHeight * 0.45, // 45% of available height
                  margin: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.05), // 5% margin
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(constraints.maxWidth * 0.06), // Responsive border radius
                    color: Colors.white.withAlpha(25),
                    border: Border.all(
                      color: Colors.white.withAlpha(51),
                      width: 1,
                    ),
                  ),
                  child: page.imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(constraints.maxWidth * 0.055), // Responsive border radius
                          child: Image.file(
                            File(page.imagePath!),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(constraints.maxWidth * 0.055),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withAlpha(51),
                                Colors.white.withAlpha(13),
                              ],
                            ),
                          ),
                          child: Center(
                            child: _buildDefaultThumbnail(constraints),
                          ),
                        ),
                ),
                
                SizedBox(height: constraints.maxHeight * 0.06), // 6% of screen height
                
                // Title and subtitle
                Column(
                  children: [
                    Text(
                      page.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: constraints.maxWidth * 0.08, // 8% of screen width
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Helvetica',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: constraints.maxHeight * 0.02), // 2% of screen height
                    Text(
                      page.subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha(204),
                        fontSize: constraints.maxWidth * 0.04, // 4% of screen width
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                
                SizedBox(height: constraints.maxHeight * 0.15), // 15% space for button area
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultThumbnail(BoxConstraints constraints) {
    return Stack(
      children: [
        // Background with subtle pattern
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(constraints.maxWidth * 0.055),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A1A2E).withAlpha(200),
                const Color(0xFF16213E).withAlpha(180),
                const Color(0xFF0F3460).withAlpha(160),
              ],
            ),
          ),
        ),
        
        // Main content
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                  // NGMY Text
                  Text(
                    'NGMY',
                    style: TextStyle(
                      fontSize: constraints.maxWidth * 0.1, // Reduced from 0.12 to 0.1
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: constraints.maxWidth * 0.006, // Reduced spacing
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(100),
                          blurRadius: constraints.maxWidth * 0.01,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: constraints.maxHeight * 0.015), // Reduced from 0.02
                  
                  // Rocket Icon
                  Container(
                    padding: EdgeInsets.all(constraints.maxWidth * 0.015), // Reduced padding
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(102),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.rocket_launch,
                      size: constraints.maxWidth * 0.06, // Reduced from 0.08 to 0.06
                      color: Colors.white,
                    ),
                  ),
                  
                  SizedBox(height: constraints.maxHeight * 0.015), // Reduced from 0.02
                  
                  // Subtitle
                  Text(
                    'AI Powered Platform',
                    style: TextStyle(
                      fontSize: constraints.maxWidth * 0.022, // Reduced from 0.025
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(180),
                      letterSpacing: 1,
                    ),
                  ),
            ],
          ),
        ),
        
        // Decorative elements
        Positioned(
          top: constraints.maxHeight * 0.05,
          right: constraints.maxWidth * 0.05,
          child: Icon(
            Icons.auto_awesome,
            size: constraints.maxWidth * 0.03,
            color: Colors.white.withAlpha(102),
          ),
        ),
        Positioned(
          bottom: constraints.maxHeight * 0.05,
          left: constraints.maxWidth * 0.05,
          child: Icon(
            Icons.stars,
            size: constraints.maxWidth * 0.025,
            color: Colors.white.withAlpha(77),
          ),
        ),
      ],
    );
  }


}

class OnboardingPage {
  final String title;
  final String subtitle;
  final String? imagePath;
  final List<Color> gradientColors;
  final String buttonText;
  final bool isLastPage;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    this.imagePath,
    required this.gradientColors,
    required this.buttonText,
    this.isLastPage = false,
  });
}
