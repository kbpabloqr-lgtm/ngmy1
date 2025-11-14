import 'package:flutter/material.dart';
import '../widgets/glass_widgets.dart';

class MenuConfigurationScreen extends StatefulWidget {
  const MenuConfigurationScreen({super.key});

  @override
  State<MenuConfigurationScreen> createState() => _MenuConfigurationScreenState();
}

class _MenuConfigurationScreenState extends State<MenuConfigurationScreen> {
  // Default menu items that match the ones in glass_menu.dart
  final List<Map<String, dynamic>> _menuItems = [
    {
      'name': 'Growth',
      'icon': Icons.trending_up_rounded,
      'color': Colors.green,
      'enabled': true,
    },
    {
      'name': 'Money',
      'icon': Icons.account_balance_wallet_rounded,
      'color': Colors.blue,
      'enabled': true,
    },
    {
      'name': 'Media',
      'icon': Icons.live_tv_rounded,
      'color': Colors.purple,
      'enabled': true,
    },
    {
      'name': 'NGMY Store',
      'icon': Icons.shopping_bag_rounded,
      'color': Colors.orange,
      'enabled': true,
    },
    {
      'name': 'Family Tree',
      'icon': Icons.diversity_3_rounded,
      'color': Colors.teal,
      'enabled': true,
    },
    {
      'name': 'Learn',
      'icon': Icons.school_rounded,
      'color': Colors.red,
      'enabled': true,
    },
  ];

  void _toggleMenuItem(int index) {
    setState(() {
      _menuItems[index]['enabled'] = !_menuItems[index]['enabled'];
    });
  }

  void _saveConfiguration() {
    // For now, just show a success message
    // In a real app, you would save this configuration to persistent storage
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Menu configuration saved successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withAlpha((0.8 * 255).round()),
      appBar: AppBar(
        title: const Text(
          'Menu Configuration',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Configuration Info
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.settings, color: Colors.white70),
                      SizedBox(width: 12),
                      Text(
                        'Menu Items Configuration',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enable or disable menu items that appear on the home screen. Disabled items will be hidden from users.',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.8 * 255).round()),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Menu Items List
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Menu Items',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  ...List.generate(_menuItems.length, (index) {
                    final item = _menuItems[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: item['enabled'] 
                            ? Colors.white.withAlpha((0.1 * 255).round())
                            : Colors.grey.withAlpha((0.1 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: item['enabled']
                              ? item['color'].withAlpha((0.5 * 255).round())
                              : Colors.grey.withAlpha((0.3 * 255).round()),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: item['color'].withAlpha((0.2 * 255).round()),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              item['icon'],
                              color: item['enabled'] ? item['color'] : Colors.grey,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: TextStyle(
                                    color: item['enabled'] ? Colors.white : Colors.grey,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['enabled'] ? 'Visible to users' : 'Hidden from users',
                                  style: TextStyle(
                                    color: item['enabled'] 
                                        ? Colors.white.withAlpha((0.7 * 255).round())
                                        : Colors.grey.withAlpha((0.7 * 255).round()),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: item['enabled'],
                            onChanged: (value) => _toggleMenuItem(index),
                            activeThumbColor: item['color'],
                            inactiveThumbColor: Colors.grey,
                            inactiveTrackColor: Colors.grey.withAlpha((0.3 * 255).round()),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.green, Colors.teal],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _saveConfiguration,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Save Configuration',
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
}