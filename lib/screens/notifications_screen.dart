import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getString('user_notifications');
    
    if (notificationsJson != null) {
      final List<dynamic> decoded = jsonDecode(notificationsJson);
      setState(() {
        _notifications = decoded.cast<Map<String, dynamic>>();
      });
    }
  }

  Future<void> _markAsRead(int index) async {
    setState(() {
      _notifications[index]['read'] = true;
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_notifications', jsonEncode(_notifications));
  }

  Future<void> _deleteNotification(int index) async {
    setState(() {
      _notifications.removeAt(index);
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_notifications', jsonEncode(_notifications));
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
      ),
      body: _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
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
                
                return Dismissible(
                  key: Key('notification_$index'),
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha((0.3 * 255).round()),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.red),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    _deleteNotification(index);
                  },
                  child: GestureDetector(
                    onTap: () => _markAsRead(index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isRead
                            ? Colors.white.withAlpha((0.05 * 255).round())
                            : Colors.blue.withAlpha((0.15 * 255).round()),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isRead
                              ? Colors.white.withAlpha((0.1 * 255).round())
                              : Colors.blue.withAlpha((0.3 * 255).round()),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  notification['title'] ?? 'Notification',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            notification['message'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withAlpha((0.7 * 255).round()),
                              fontSize: 14,
                            ),
                          ),
                          if (notification['timestamp'] != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              notification['timestamp'],
                              style: TextStyle(
                                color: Colors.white.withAlpha((0.5 * 255).round()),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
