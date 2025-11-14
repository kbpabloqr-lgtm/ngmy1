import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../services/betting_data_store.dart';
import '../screens/admin_notification_composer_screen.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    this.iconColor = Colors.white70,
    this.badgeColor = Colors.red,
    this.tooltip,
    this.allowCompose = false,
    this.allowBroadcast = false,
    this.titleOverride,
    this.scopes = const ['global'],
  });

  final Color iconColor;
  final Color badgeColor;
  final String? tooltip;
  final bool allowCompose;
  final bool allowBroadcast;
  final String? titleOverride;
  final List<String> scopes;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  static const Duration _retention = Duration(days: 5);
  static const String _userComposePrefKey = 'notifications_user_compose_enabled';

  final BettingDataStore _store = BettingDataStore.instance;
  late final VoidCallback _storeListener;

  int _unreadCount = 0;
  bool _loading = false;
  bool _userComposeEnabled = false;

  @override
  void initState() {
    super.initState();
    _storeListener = () {
      if (!mounted) {
        return;
      }
      _refreshUnread();
    };
    _store.addListener(_storeListener);
    _refreshUnread();
    _loadComposePermission();
  }

  @override
  void dispose() {
    _store.removeListener(_storeListener);
    super.dispose();
  }

  Future<void> _refreshUnread() async {
    if (_loading) {
      return;
    }
    _loading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      var username = _store.username.trim();
      final bool hasExplicitUsername = username.isNotEmpty;
      if (!hasExplicitUsername) {
        username = 'guest';
      }

      final normalized = username.toLowerCase();
      final primaryKey = '${normalized}_notifications';
      final String? existingPrimaryRaw = prefs.getString(primaryKey);

      final Set<String> legacyKeys = <String>{};
      if (hasExplicitUsername) {
        for (final key in prefs.getKeys()) {
          if (key == primaryKey) continue;
          if (!key.endsWith('_notifications')) continue;
          if (key.toLowerCase() == primaryKey) {
            legacyKeys.add(key);
          }
        }
      } else {
        const legacyCandidates = ['NGMY User_notifications', 'ngmy user_notifications'];
        for (final key in legacyCandidates) {
          if (prefs.containsKey(key)) {
            legacyKeys.add(key);
          }
        }
      }

      final now = DateTime.now();
      bool primaryChanged = false;

      Future<List<Map<String, dynamic>>> loadKey(
        String key, {
        bool markPrimaryChange = false,
      }) async {
        final raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) {
          return <Map<String, dynamic>>[];
        }
        List<dynamic> decoded;
        try {
          decoded = jsonDecode(raw) as List<dynamic>;
        } catch (_) {
          if (markPrimaryChange) {
            primaryChanged = true;
          }
          await prefs.setString(key, '[]');
          return <Map<String, dynamic>>[];
        }
        final List<Map<String, dynamic>> kept = <Map<String, dynamic>>[];
        bool changed = false;
        for (final entry in decoded) {
          if (entry is! Map) {
            changed = true;
            continue;
          }
          final map = Map<String, dynamic>.from(entry);
          final timestampRaw = map['timestamp']?.toString();
          final timestamp = timestampRaw != null ? DateTime.tryParse(timestampRaw) : null;
          if (timestamp == null || now.difference(timestamp) > _retention) {
            changed = true;
            continue;
          }
          kept.add(map);
        }
        if (changed) {
          await prefs.setString(key, jsonEncode(kept));
          if (markPrimaryChange) {
            primaryChanged = true;
          }
        }
        return kept;
      }

      final Map<String, Map<String, dynamic>> primaryEntries = <String, Map<String, dynamic>>{};

      List<Map<String, dynamic>> primaryList = await loadKey(primaryKey, markPrimaryChange: true);
      if (primaryList.isEmpty && existingPrimaryRaw == null) {
        // Ensure we can backfill from global if nothing exists yet.
        primaryChanged = true;
      }
      for (final map in primaryList) {
        final id = _deriveNotificationId(map, primaryKey);
        primaryEntries[id] = map;
      }

      for (final legacyKey in legacyKeys) {
        final legacyList = await loadKey(legacyKey);
        for (final map in legacyList) {
          final id = _deriveNotificationId(map, primaryKey);
          primaryEntries.putIfAbsent(id, () {
            primaryChanged = true;
            return map;
          });
        }
      }

      Future<void> mergeFrom(String key) async {
        final list = await loadKey(key);
        for (final map in list) {
          final id = _deriveNotificationId(map, primaryKey);
          if (!primaryEntries.containsKey(id)) {
            primaryEntries[id] = map;
            primaryChanged = true;
          }
        }
      }

      await mergeFrom('user_notifications');
      if (widget.allowCompose || widget.allowBroadcast) {
        await mergeFrom('admin_notifications');
      }

      var ordered = primaryEntries.values
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
      ordered.sort((a, b) {
        final aTime = DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      if (ordered.length > 60) {
        ordered = ordered.sublist(0, 60);
        primaryChanged = true;
      }

      if (primaryChanged) {
        await prefs.setString(primaryKey, jsonEncode(ordered));
      }

      final Set<String> allowedScopes = widget.scopes.map((scope) => scope.toLowerCase()).toSet();
      final int unread = ordered.where((entry) {
        if (entry['read'] == true) {
          return false;
        }
        final scopesRaw = entry['scopes'];
        if (scopesRaw is! List || scopesRaw.isEmpty) {
          return true;
        }
        final scopes = scopesRaw.whereType<String>().map((scope) => scope.toLowerCase()).toSet();
        if (scopes.contains('global')) {
          return true;
        }
        return scopes.any(allowedScopes.contains);
      }).length;

      if (mounted) {
        setState(() {
          _unreadCount = unread;
        });
      }
    } finally {
      _loading = false;
    }
  }

  String _deriveNotificationId(Map<String, dynamic> map, String fallbackKey) {
    final id = map['id']?.toString();
    if (id != null && id.isNotEmpty) {
      return id;
    }
    final timestampRaw = map['timestamp']?.toString();
    final timestamp = timestampRaw != null ? DateTime.tryParse(timestampRaw) : null;
    if (timestamp != null) {
      return '${timestamp.microsecondsSinceEpoch}_$fallbackKey';
    }
    final title = map['title']?.toString() ?? '';
    final message = map['message']?.toString() ?? '';
    return '${title.hashCode}_${message.hashCode}_$fallbackKey';
  }

  Future<void> _loadComposePermission() async {
    if (widget.allowCompose) {
      if (_userComposeEnabled) {
        setState(() => _userComposeEnabled = false);
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_userComposePrefKey) ?? false;
    if (!mounted || _userComposeEnabled == enabled) {
      return;
    }
    setState(() => _userComposeEnabled = enabled);
  }

  Future<void> _openNotifications() async {
    final allowMemberCompose = !widget.allowCompose && _userComposeEnabled;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminNotificationComposerScreen(
          allowCompose: widget.allowCompose,
          allowBroadcast: widget.allowBroadcast,
          allowMemberCompose: allowMemberCompose,
          titleOverride: widget.titleOverride,
          scopes: widget.scopes.toSet(),
        ),
      ),
    );
    if (mounted) {
      await _refreshUnread();
      await _loadComposePermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tooltip = widget.tooltip ?? 'Notifications';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          color: widget.iconColor,
          tooltip: tooltip,
          onPressed: _openNotifications,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: widget.badgeColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.badgeColor.withAlpha((0.5 * 255).round()),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
