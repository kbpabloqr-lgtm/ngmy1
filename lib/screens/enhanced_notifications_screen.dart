import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'referral_redemption_screen.dart';

class EnhancedNotificationsScreen extends StatefulWidget {
  final String username;
  
  const EnhancedNotificationsScreen({super.key, required this.username});

  @override
  State<EnhancedNotificationsScreen> createState() => _EnhancedNotificationsScreenState();
}

class _EnhancedNotificationsScreenState extends State<EnhancedNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Try user-specific notifications first
    String? notificationsJson = prefs.getString('${widget.username}_notifications');
    
    // If no user-specific notifications, try global as fallback
    if (notificationsJson == null || notificationsJson == '[]') {
      notificationsJson = prefs.getString('user_notifications');
    }
    
    if (notificationsJson != null) {
      final List<dynamic> decoded = jsonDecode(notificationsJson);
      final now = DateTime.now();
      
      // Filter out notifications older than 2 days
      final filteredNotifications = decoded.where((item) {
        final timestamp = DateTime.tryParse(item['timestamp'] ?? '');
        if (timestamp == null) return false;
        final age = now.difference(timestamp);
        return age.inDays < 2; // Keep only last 2 days
      }).toList();
      
      // Save filtered notifications back to user-specific key
      if (filteredNotifications.length != decoded.length) {
        await prefs.setString('${widget.username}_notifications', jsonEncode(filteredNotifications));
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
    await prefs.setString('${widget.username}_notifications', jsonEncode(_notifications));
  }

  Future<void> _markAsUnread(int index) async {
    setState(() {
      _notifications[index]['read'] = false;
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${widget.username}_notifications', jsonEncode(_notifications));
  }

  Future<void> _deleteNotification(int index) async {
    setState(() {
      _notifications.removeAt(index);
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${widget.username}_notifications', jsonEncode(_notifications));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade400, Colors.blue.shade400],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.card_giftcard, color: Colors.white, size: 20),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ReferralRedemptionScreen(username: widget.username),
                ),
              );
            },
            tooltip: 'Refer & Earn',
          ),
          const SizedBox(width: 8),
        ],
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
                
                return Dismissible(
                  key: Key('notification_${notification['id'] ?? index}'),
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.withAlpha((0.9 * 255).round()),
                          Colors.red.shade900,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withAlpha((0.4 * 255).round()),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_rounded, color: Colors.white, size: 28),
                        const SizedBox(height: 4),
                        const Text(
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
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    _deleteNotification(index);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.white),
                            const SizedBox(width: 12),
                            const Text('Notification deleted'),
                          ],
                        ),
                        backgroundColor: Colors.red.shade700,
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    );
                  },
                  child: _buildNotificationCard(notification, index, isRead, type),
                );
              },
            ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, int index, bool isRead, String type) {
    final timestamp = DateTime.tryParse(notification['timestamp'] ?? '');
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    
    Color typeColor = Colors.blue;
    IconData typeIcon = Icons.info;
    
    switch (type) {
      case 'success':
        typeColor = Colors.green;
        typeIcon = Icons.check_circle_rounded;
        break;
      case 'warning':
        typeColor = Colors.orange;
        typeIcon = Icons.warning_rounded;
        break;
      case 'urgent':
        typeColor = Colors.red;
        typeIcon = Icons.priority_high_rounded;
        break;
      default:
        typeColor = Colors.blue;
        typeIcon = Icons.info_rounded;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isRead
                ? Colors.white.withAlpha((0.08 * 255).round())
                : typeColor.withAlpha((0.22 * 255).round()),
            isRead
                ? Colors.white.withAlpha((0.04 * 255).round())
                : typeColor.withAlpha((0.12 * 255).round()),
          ],
        ),
        border: Border.all(
          color: isRead
              ? Colors.white.withAlpha((0.15 * 255).round())
              : typeColor.withAlpha((0.45 * 255).round()),
          width: isRead ? 1.5 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isRead
                ? Colors.black.withAlpha((0.1 * 255).round())
                : typeColor.withAlpha((0.25 * 255).round()),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            if (!isRead) {
              _markAsRead(index);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            typeColor,
                            typeColor.withAlpha((0.7 * 255).round()),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: typeColor.withAlpha((0.4 * 255).round()),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(typeIcon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [typeColor, typeColor.withAlpha((0.8 * 255).round())],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: typeColor.withAlpha((0.4 * 255).round()),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.circle, color: Colors.white, size: 8),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'NEW',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          if (timestamp != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha((0.1 * 255).round()),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 13,
                                    color: Colors.white.withAlpha((0.6 * 255).round()),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTimestamp(timestamp),
                                    style: TextStyle(
                                      color: Colors.white.withAlpha((0.6 * 255).round()),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.05 * 255).round()),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.9 * 255).round()),
                        fontSize: 15,
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Mark as read/unread button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isRead
                              ? [
                                  Colors.orange.withAlpha((0.8 * 255).round()),
                                  Colors.orange.shade900,
                                ]
                              : [
                                  Colors.green.withAlpha((0.8 * 255).round()),
                                  Colors.green.shade900,
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (isRead ? Colors.orange : Colors.green).withAlpha((0.3 * 255).round()),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => isRead ? _markAsUnread(index) : _markAsRead(index),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isRead ? Icons.mark_email_unread_rounded : Icons.mark_email_read_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isRead ? 'Unread' : 'Read',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
