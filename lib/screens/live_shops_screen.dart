import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;

/// LiveShops - Modern streaming shopping platform
class LiveShopsScreen extends StatefulWidget {
  const LiveShopsScreen({super.key});

  @override
  State<LiveShopsScreen> createState() => _LiveShopsScreenState();
}

class _LiveShopsScreenState extends State<LiveShopsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showOnboarding = true;
  final Set<String> _selectedInterests = {};

  final List<String> _interests = [
    'Beauty & Style',
    'Food',
    'Music',
    'Books',
    'Sport',
    'Electronics',
    'Gaming',
    'Cars',
    'News',
    'Games',
    'Education',
    'Drinks',
    'Movies',
    'Art',
    'Flowers',
    'Gardening',
    'Tourism',
    'Travel',
    'Tech',
    'Seafood',
    'Pets',
  ];

  final List<Map<String, dynamic>> _liveStreams = [
    {
      'seller': 'Sarah M.',
      'title': 'Amazing T-Shirts',
      'rating': 4.5,
      'reviews': 245,
      'viewers': 1234,
      'products': 6,
      'category': 'Fashion',
      'color': Color(0xFFE91E63),
    },
    {
      'seller': 'Mike\'s Tech',
      'title': 'Latest Gadgets',
      'rating': 4.8,
      'reviews': 892,
      'viewers': 3421,
      'products': 12,
      'category': 'Electronics',
      'color': Color(0xFF2196F3),
    },
    {
      'seller': 'Bella Beauty',
      'title': 'Makeup Essentials',
      'rating': 4.7,
      'reviews': 567,
      'viewers': 2156,
      'products': 8,
      'category': 'Beauty',
      'color': Color(0xFFFF6B9D),
    },
  ];

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Fashion', 'icon': Icons.checkroom, 'color': Color(0xFFE91E63), 'live': 234},
    {'name': 'Electronics', 'icon': Icons.devices, 'color': Color(0xFF2196F3), 'live': 156},
    {'name': 'Beauty', 'icon': Icons.face, 'color': Color(0xFFFF6B9D), 'live': 189},
    {'name': 'Sports', 'icon': Icons.sports_basketball, 'color': Color(0xFFFF9800), 'live': 92},
    {'name': 'Cooking', 'icon': Icons.restaurant, 'color': Color(0xFF4CAF50), 'live': 145},
    {'name': 'Music', 'icon': Icons.music_note, 'color': Color(0xFF9C27B0), 'live': 78},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding && _selectedInterests.isEmpty) {
      return _buildOnboardingScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFeedTab(),
                  _buildCategoriesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Choose your\ninterests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tell us what you\'re into, and we\'ll\nsuggest great live recommendations',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.6 * 255).round()),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _interests.map((interest) {
                      final isSelected = _selectedInterests.contains(interest);
                      return _buildInterestChip(interest, isSelected);
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedInterests.isEmpty ? null : () {
                    setState(() => _showOnboarding = false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCDFF00),
                    disabledBackgroundColor: Colors.white.withAlpha((0.1 * 255).round()),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Next',
                    style: TextStyle(
                      color: _selectedInterests.isEmpty ? Colors.white38 : Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterestChip(String label, bool isSelected) {
    IconData icon;
    if (label.contains('Beauty')) {
      icon = Icons.face;
    } else if (label.contains('Food')) {
      icon = Icons.restaurant;
    } else if (label.contains('Music')) {
      icon = Icons.music_note;
    } else if (label.contains('Books')) {
      icon = Icons.book;
    } else if (label.contains('Sport')) {
      icon = Icons.sports_basketball;
    } else if (label.contains('Electronics')) {
      icon = Icons.devices;
    } else if (label.contains('Gaming')) {
      icon = Icons.sports_esports;
    } else if (label.contains('Cars')) {
      icon = Icons.directions_car;
    } else if (label.contains('News')) {
      icon = Icons.article;
    } else if (label.contains('Education')) {
      icon = Icons.school;
    } else if (label.contains('Drinks')) {
      icon = Icons.local_bar;
    } else if (label.contains('Movies')) {
      icon = Icons.movie;
    } else if (label.contains('Art')) {
      icon = Icons.palette;
    } else if (label.contains('Flowers')) {
      icon = Icons.local_florist;
    } else if (label.contains('Gardening')) {
      icon = Icons.yard;
    } else if (label.contains('Tourism')) {
      icon = Icons.tour;
    } else if (label.contains('Travel')) {
      icon = Icons.flight;
    } else if (label.contains('Tech')) {
      icon = Icons.computer;
    } else if (label.contains('Seafood')) {
      icon = Icons.set_meal;
    } else if (label.contains('Pets')) {
      icon = Icons.pets;
    } else {
      icon = Icons.star;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedInterests.remove(label);
          } else {
            _selectedInterests.add(label);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withAlpha((0.2 * 255).round()),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.check,
                  size: 18,
                  color: Colors.black,
                ),
              ),
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.black : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0E27),
            const Color(0xFF0A0E27).withAlpha((0.8 * 255).round()),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 8),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Live',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: 'Shops',
                      style: TextStyle(
                        color: Color(0xFFCDFF00),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withAlpha((0.2 * 255).round()),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, color: Colors.white.withAlpha((0.7 * 255).round()), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.05 * 255).round()),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white.withAlpha((0.15 * 255).round()),
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withAlpha((0.5 * 255).round()),
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Following'),
                Tab(text: 'For you'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedTab() {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemBuilder: (context, index) {
        final stream = _liveStreams[index % _liveStreams.length];
        return _buildLiveStreamCard(stream);
      },
    );
  }

  Widget _buildLiveStreamCard(Map<String, dynamic> stream) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            stream['color'].withAlpha((0.3 * 255).round()),
            const Color(0xFF0A0E27),
            stream['color'].withAlpha((0.2 * 255).round()),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Simulated video background with pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _VideoBackgroundPainter(stream['color']),
            ),
          ),
          
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha((0.7 * 255).round()),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ),

          // Top info bar
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.5 * 255).round()),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${stream['viewers']}',
                        style: const TextStyle(
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
          ),

          // Seller info and products
          Positioned(
            bottom: 100,
            left: 20,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: stream['color'],
                      child: Text(
                        stream['seller'][0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stream['seller'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${stream['rating']} (${stream['reviews']})',
                                style: TextStyle(
                                  color: Colors.white.withAlpha((0.8 * 255).round()),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  stream['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Get amazed retail and consultant about\nyour personal look.',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                // Product thumbnails
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      stream['products'],
                      (index) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.2 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withAlpha((0.3 * 255).round()),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.checkroom,
                            color: Colors.white.withAlpha((0.5 * 255).round()),
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right side actions
          Positioned(
            right: 12,
            bottom: 100,
            child: Column(
              children: [
                _buildActionButton(Icons.favorite_border, '234', Colors.red),
                const SizedBox(height: 24),
                _buildActionButton(Icons.comment, '45', Colors.blue),
                const SizedBox(height: 24),
                _buildActionButton(Icons.share, '12', Colors.green),
                const SizedBox(height: 24),
                _buildActionButton(Icons.shopping_bag, '${stream['products']}', stream['color']),
              ],
            ),
          ),

          // Bottom CTA
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    stream['color'],
                    stream['color'].withAlpha((0.7 * 255).round()),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: stream['color'].withAlpha((0.4 * 255).round()),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'BUY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha((0.5 * 255).round()),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withAlpha((0.3 * 255).round()),
              width: 2,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar with tags
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFCDFF00),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trending Searches',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '#Beauty & Style', '#iPod', '#Music', '#Books',
                    '#Sport', '#Roommate', '#Kitchen', '#Games',
                    '#Laptop', '#Garden', '#Animal', '#Family',
                    '#iPad', '#Education', '#Phone'
                  ].map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Category',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return _buildCategoryCard(category);
            },
          ),
          const SizedBox(height: 32),
          const Text(
            'Live Now',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              return _buildLiveNowCard(_liveStreams[index % _liveStreams.length]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            category['color'].withAlpha((0.3 * 255).round()),
            category['color'].withAlpha((0.1 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: category['color'].withAlpha((0.5 * 255).round()),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.2 * 255).round()),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    category['icon'],
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const Spacer(),
                Text(
                  category['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${category['live']} live',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveNowCard(Map<String, dynamic> stream) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            stream['color'].withAlpha((0.4 * 255).round()),
            const Color(0xFF0A0E27),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: stream['color'].withAlpha((0.5 * 255).round()),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Simulated thumbnail
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                painter: _VideoBackgroundPainter(stream['color']),
              ),
            ),
          ),
          
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha((0.8 * 255).round()),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),

          // Live badge
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.white, size: 8),
                  SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Viewer count
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.6 * 255).round()),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.remove_red_eye, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '${stream['viewers']}',
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

          // Seller info
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stream['seller'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stream['title'],
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.8 * 255).round()),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for video background simulation
class _VideoBackgroundPainter extends CustomPainter {
  final Color color;

  _VideoBackgroundPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Create a pattern with circles
    final random = math.Random(42);
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 40 + 20;
      
      paint.color = color.withAlpha((random.nextDouble() * 0.2 * 255).round());
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Add some diagonal lines
    paint.strokeWidth = 2;
    paint.style = PaintingStyle.stroke;
    for (int i = 0; i < 10; i++) {
      paint.color = color.withAlpha((random.nextDouble() * 0.15 * 255).round());
      canvas.drawLine(
        Offset(random.nextDouble() * size.width, 0),
        Offset(random.nextDouble() * size.width, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
