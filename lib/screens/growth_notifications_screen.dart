import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class GrowthNotificationsScreen extends StatefulWidget {
  const GrowthNotificationsScreen({super.key});

  @override
  State<GrowthNotificationsScreen> createState() => _GrowthNotificationsScreenState();
}

class _GrowthNotificationsScreenState extends State<GrowthNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('growth_user_name') ?? 'NGMY User';
    
    // Load user-specific notifications
    final notificationsJson = prefs.getString('${username}_growth_notifications');
    
    if (notificationsJson != null) {
      final List<dynamic> decoded = jsonDecode(notificationsJson);
      final now = DateTime.now();
      
      // Filter out notifications older than 2 days
      final filteredNotifications = decoded.where((item) {
        final timestamp = DateTime.tryParse(item['timestamp'] ?? '');
        if (timestamp == null) return false;
        final age = now.difference(timestamp);
        return age.inDays < 2; // Keep only notifications from last 2 days
      }).toList();
      
      // Save filtered notifications back
      if (filteredNotifications.length != decoded.length) {
        await prefs.setString('${username}_growth_notifications', jsonEncode(filteredNotifications));
      }
      
      setState(() {
        _notifications = filteredNotifications.cast<Map<String, dynamic>>();
      });
    }
  }

  Future<void> _markAsRead(int index) async {
    setState(() {
      _notifications[index]['read'] = true;
    });
    
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('growth_user_name') ?? 'NGMY User';
    await prefs.setString('${username}_growth_notifications', jsonEncode(_notifications));
  }

  Future<void> _deleteNotification(int index) async {
    setState(() {
      _notifications.removeAt(index);
    });
    
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('growth_user_name') ?? 'NGMY User';
    await prefs.setString('${username}_growth_notifications', jsonEncode(_notifications));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification deleted'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'penalty':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'success':
        return Colors.green;
      case 'info':
      default:
        return Colors.blue;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'penalty':
        return Icons.warning_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'success':
        return Icons.check_circle_rounded;
      case 'info':
      default:
        return Icons.info_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else {
      return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.withAlpha((0.2 * 255).round()),
                          Colors.purple.withAlpha((0.2 * 255).round()),
                        ],
                      ),
                    ),
                    child: const Icon(Icons.notifications_none, size: 64, color: Colors.white54),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check back later for updates',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                final isRead = notification['read'] ?? false;
                final type = notification['type'] ?? 'info';
                final date = DateTime.tryParse(notification['timestamp'] ?? '');
                final typeColor = _getTypeColor(type);
                
                return Dismissible(
                  key: Key('notification_${notification['id'] ?? index}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _deleteNotification(index),
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.withAlpha((0.9 * 255).round()),
                          Colors.red.shade900,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_rounded, color: Colors.white, size: 28),
                        SizedBox(height: 4),
                        Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  child: GestureDetector(
                    onTap: () => _markAsRead(index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isRead
                              ? [
                                  Colors.white.withAlpha((0.08 * 255).round()),
                                  Colors.white.withAlpha((0.04 * 255).round()),
                                ]
                              : [
                                  typeColor.withAlpha((0.25 * 255).round()),
                                  typeColor.withAlpha((0.12 * 255).round()),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isRead
                              ? Colors.white.withAlpha((0.15 * 255).round())
                              : typeColor.withAlpha((0.4 * 255).round()),
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        typeColor,
                                        typeColor.withAlpha((0.7 * 255).round()),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(_getTypeIcon(type), color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    notification['title'] ?? 'Notification',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.red.shade600, Colors.red.shade800],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.circle, color: Colors.white, size: 8),
                                        SizedBox(width: 4),
                                        Text(
                                          'NEW',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha((0.05 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                notification['message'] ?? '',
                                style: TextStyle(
                                  color: Colors.white.withAlpha((0.9 * 255).round()),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            if (date != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: Colors.white.withAlpha((0.6 * 255).round()),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(date),
                                    style: TextStyle(
                                      color: Colors.white.withAlpha((0.6 * 255).round()),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.red.withAlpha((0.8 * 255).round()),
                                          Colors.red.shade900,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _deleteNotification(index),
                                        borderRadius: BorderRadius.circular(12),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.delete_rounded,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
