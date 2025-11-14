import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/floating_header.dart';
import 'package:ngmy1/services/betting_data_store.dart';

enum NotificationAttachmentType { image, audio }

class NotificationAttachment {
	NotificationAttachment({
		required this.id,
		required this.type,
		required this.bytes,
		required this.name,
		required this.mimeType,
	});

	final String id;
	final NotificationAttachmentType type;
	final Uint8List bytes;
	final String name;
	final String mimeType;

	bool get isImage => type == NotificationAttachmentType.image;
	bool get isAudio => type == NotificationAttachmentType.audio;

	Map<String, dynamic> toJson() => {
				'id': id,
				'type': type.name,
				'bytes': base64Encode(bytes),
				'name': name,
				'mimeType': mimeType,
			};

	factory NotificationAttachment.fromJson(Map<String, dynamic> json) {
		final encoded = json['bytes'] as String?;
		return NotificationAttachment(
			id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
			type: ((json['type'] as String?) ?? 'image') == 'audio'
					? NotificationAttachmentType.audio
					: NotificationAttachmentType.image,
			bytes: encoded != null && encoded.isNotEmpty
					? Uint8List.fromList(base64Decode(encoded))
					: Uint8List(0),
			name: json['name'] as String? ?? 'attachment',
			mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
		);
	}
}

class AdminNotificationComposerScreen extends StatefulWidget {
	const AdminNotificationComposerScreen({
		super.key,
		this.allowCompose = false,
		this.allowBroadcast = false,
		this.allowMemberCompose = false,
		this.titleOverride,
		Set<String>? scopes,
	}) : scopes = scopes ?? const {'global'};

	final bool allowCompose;
	final bool allowBroadcast;
	final bool allowMemberCompose;
	final String? titleOverride;
	final Set<String> scopes;

	@override
	State<AdminNotificationComposerScreen> createState() => _AdminNotificationComposerScreenState();
}

class _AdminNotificationComposerScreenState extends State<AdminNotificationComposerScreen>
		with SingleTickerProviderStateMixin {
	static const Duration _retentionWindow = Duration(days: 5);
	final TextEditingController _titleController = TextEditingController();
	final TextEditingController _messageController = TextEditingController();
	final TextEditingController _targetUserController = TextEditingController();
	final TextEditingController _memberMessageController = TextEditingController();

	late TabController _tabController;

	final List<Map<String, dynamic>> _sentHistory = <Map<String, dynamic>>[];
	final List<Map<String, dynamic>> _receivedNotifications = <Map<String, dynamic>>[];
	final List<NotificationAttachment> _attachments = <NotificationAttachment>[];

	static const Set<String> _allScopes = {
		'global',
		'growth',
		'family_tree',
		'store',
		'money',
		'tickets',
		'media',
	};
	static const String _userComposePrefKey = 'notifications_user_compose_enabled';

	final Set<String> _selectedScopes = {..._allScopes};
	final Set<String> _replyAllowedUsers = <String>{};

	final AudioPlayer _audioPlayer = AudioPlayer();
	final AudioRecorder _recorder = AudioRecorder();
	StreamSubscription<void>? _playerCompleteSub;

	String? _playingAttachmentId;
	bool _isRecording = false;
	bool _isSending = false;
	bool _sendToAll = true;
	bool _isReplyAllowedForTargetUser = true;
	bool _currentUserRepliesAllowed = false;
	bool _userComposeEnabled = false;

	int _unreadCount = 0;
	String _notificationType = 'info';
	String? _scopeError;
	String _currentUsername = '';

	final Map<String, String> _scopeLabels = <String, String>{
		'global': 'All Menus',
		'growth': 'Growth',
		'family_tree': 'Family Tree',
		'store': 'Store',
		'money': 'Money',
		'tickets': 'Tickets',
		'media': 'Media Lab',
	};

	String _computeNotificationSignature(Map<String, dynamic> notification) {
		try {
			final id = notification['id'];
			if (id != null) {
				final idStr = id is String ? id : id.toString();
				if (idStr.isNotEmpty) {
					return 'id:$idStr';
				}
			}
			
			final originalId = notification['originalId'];
			final originalIdStr = originalId != null 
				? (originalId is String ? originalId : originalId.toString())
				: '';
			
			final timestamp = notification['timestamp'];
			final timestampStr = timestamp != null
				? (timestamp is String ? timestamp : timestamp.toString())
				: '';
			
			final title = notification['title'];
			final titleStr = title != null
				? (title is String ? title : title.toString())
				: '';
			
			final message = notification['message'];
			final messageStr = message != null
				? (message is String ? message : message.toString())
				: '';
			
			final fromAdmin = notification['fromAdmin'];
			final fromAdminStr = fromAdmin != null
				? (fromAdmin is String ? fromAdmin : fromAdmin.toString())
				: '';
			
			final fromUser = notification['fromUser'];
			final fromUserStr = fromUser != null
				? (fromUser is String ? fromUser : fromUser.toString())
				: '';
			
			final scopesRaw = notification['scopes'];
			final List<String> scopes = scopesRaw is List
				? scopesRaw.map((scope) => scope?.toString() ?? '').toList()
				: <String>[];
			scopes.sort();
			
			final attachments = notification['attachments'];
			final attachmentCount = attachments is List ? attachments.length : 0;
			
			return [
				'orig:$originalIdStr',
				'ts:$timestampStr',
				'title:$titleStr',
				'msg:$messageStr',
				'admin:$fromAdminStr',
				'user:$fromUserStr',
				'scopes:${scopes.join(',')}',
				'att:$attachmentCount',
			].join('|');
		} catch (e) {
			debugPrint('⚠️ Error computing signature: $e');
			return 'error:${DateTime.now().millisecondsSinceEpoch}';
		}
	}

	bool get _canAddMoreAttachments => !_isRecording && _attachments.length < 5;
	bool get _memberComposerActive => !widget.allowBroadcast && widget.allowMemberCompose && _userComposeEnabled;
	bool get _canSendMemberMessage => !_isRecording &&
				(_memberMessageController.text.trim().isNotEmpty || _attachments.isNotEmpty);

	@override
	void initState() {
		super.initState();
		final tabCount = widget.allowCompose ? 2 : 1;
		_tabController = TabController(length: tabCount, vsync: this);
		final initialScopes = widget.allowBroadcast
			? _allScopes
			: (widget.scopes.isEmpty ? const {'global'} : widget.scopes.toSet());
		_selectedScopes
			..clear()
			..addAll(initialScopes);
		_memberMessageController.addListener(() {
			if (!mounted || widget.allowBroadcast) return;
			setState(() {});
		});
		_sendToAll = widget.allowBroadcast;
		if (!widget.allowBroadcast) {
			_sendToAll = false;
			_targetUserController.text = 'admin';
		}
		_initialize();
	}

	@override
	void dispose() {
		_playerCompleteSub?.cancel();
		_audioPlayer.dispose();
		_recorder.dispose();
		_tabController.dispose();
		_titleController.dispose();
		_messageController.dispose();
		_targetUserController.dispose();
		_memberMessageController.dispose();
		super.dispose();
	}

	Future<void> _initialize() async {
		await _loadCurrentUser();
		await Future.wait([
			_loadReplyPermissions(),
			_loadUserComposeSetting(),
			if (widget.allowBroadcast && widget.allowCompose) _loadSentHistory(),
		]);
		await _loadReceivedNotifications();
	}

	Future<void> _loadCurrentUser() async {
		final store = BettingDataStore.instance;
		final username = store.username.trim();
		if (!mounted) return;
		setState(() {
			_currentUsername = username.isEmpty ? 'guest' : username;
		});
	}

	Future<void> _loadReplyPermissions() async {
		final prefs = await SharedPreferences.getInstance();
		final stored = prefs.getStringList('notification_reply_allowlist') ?? const <String>[];
		final lower = stored.map((e) => e.toLowerCase()).toSet();
		if (!mounted) return;
		setState(() {
			_replyAllowedUsers
				..clear()
				..addAll(lower);
			_currentUserRepliesAllowed = _replyAllowedUsers.contains(_currentUsername.toLowerCase());
		});
	}

	Future<void> _loadUserComposeSetting() async {
		final prefs = await SharedPreferences.getInstance();
		final enabled = prefs.getBool(_userComposePrefKey) ?? false;
		if (!mounted) return;
		setState(() {
			_userComposeEnabled = enabled;
			if (!widget.allowBroadcast) {
				_currentUserRepliesAllowed = enabled;
			}
		});
	}

	Future<void> _setUserComposeEnabled(bool value) async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setBool(_userComposePrefKey, value);
		if (!mounted) return;
		setState(() {
			_userComposeEnabled = value;
			if (!widget.allowBroadcast) {
				_currentUserRepliesAllowed = value;
			}
		});
	}

	Future<void> _loadSentHistory() async {
		final prefs = await SharedPreferences.getInstance();
		final raw = prefs.getString('admin_sent_notifications');
		if (raw == null || raw.isEmpty) {
			if (!mounted) return;
			setState(() => _sentHistory.clear());
			return;
		}

		final decoded = jsonDecode(raw);
		if (decoded is! List) {
			if (!mounted) return;
			setState(() => _sentHistory.clear());
			return;
		}

		final now = DateTime.now();
		final filtered = decoded.whereType<Map>().where((entry) {
			final timestampRaw = entry['timestamp']?.toString();
			final timestamp = timestampRaw != null ? DateTime.tryParse(timestampRaw) : null;
			if (timestamp == null) {
				return false;
			}
			return now.difference(timestamp) < _retentionWindow;
		}).map((entry) {
			final Map<String, dynamic> converted = {};
			for (final key in entry.keys) {
				converted[key.toString()] = entry[key];
			}
			return converted;
		}).toList();
		if (filtered.length != decoded.length) {
			await prefs.setString('admin_sent_notifications', jsonEncode(filtered));
		}

		if (!mounted) return;
		setState(() {
			_sentHistory
				..clear()
				..addAll(filtered);
		});
	}

	Future<void> _loadReceivedNotifications() async {
		final prefs = await SharedPreferences.getInstance();
		final username = _currentUsername.toLowerCase();
		final keys = <String>{'${username}_notifications'};
		keys.add('user_notifications');
		if (widget.allowCompose) {
			keys.add('admin_notifications');
		}

		final List<Map<String, dynamic>> aggregated = [];
		final Set<String> seenSignatures = <String>{};
		final now = DateTime.now();

		for (final key in keys) {
			final raw = prefs.getString(key);
			if (raw == null || raw.isEmpty) {
				continue;
			}
			final decoded = jsonDecode(raw);
			if (decoded is! List) {
				continue;
			}
			final kept = <Map<String, dynamic>>[];

			for (final entry in decoded) {
				if (entry is! Map) continue;
				final map = <String, dynamic>{};
				for (final k in entry.keys) {
					map[k.toString()] = entry[k];
				}
				final timestampRaw = map['timestamp']?.toString();
				final timestamp = timestampRaw != null ? DateTime.tryParse(timestampRaw) : null;
				if (timestamp == null) continue;
				if (now.difference(timestamp) > _retentionWindow) {
					continue;
				}
				kept.add(map);

				final signature = _computeNotificationSignature(map);
				if (!seenSignatures.add(signature)) {
					continue;
				}
				aggregated.add(map);
			}

			if (kept.length != decoded.length) {
				await prefs.setString(key, jsonEncode(kept));
			}
		}

		aggregated.sort((a, b) {
			final aTime = DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
			final bTime = DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
			return bTime.compareTo(aTime);
		});

		if (!mounted) return;
		setState(() {
			_receivedNotifications
				..clear()
				..addAll(aggregated);
			_unreadCount = aggregated.where((n) => n['read'] != true).length;
		});
	}

	Future<void> _persistReceived() async {
		final prefs = await SharedPreferences.getInstance();
		final key = '${_currentUsername.toLowerCase()}_notifications';
		await prefs.setString(key, jsonEncode(_receivedNotifications));
	}

	Future<void> _markAsRead(int index) async {
		if (index < 0 || index >= _receivedNotifications.length) return;
		setState(() {
			_receivedNotifications[index]['read'] = true;
			_unreadCount = _receivedNotifications.where((n) => n['read'] != true).length;
		});
		await _persistReceived();
	}

	Future<void> _markAsUnread(int index) async {
		if (index < 0 || index >= _receivedNotifications.length) return;
		setState(() {
			_receivedNotifications[index]['read'] = false;
			_unreadCount = _receivedNotifications.where((n) => n['read'] != true).length;
		});
		await _persistReceived();
	}

	Future<void> _deleteReceivedNotification(int index) async {
		try {
			debugPrint('🔴 DELETE BUTTON CLICKED! Index: $index, Total notifications: ${_receivedNotifications.length}');
			
			if (index < 0 || index >= _receivedNotifications.length) {
				debugPrint('❌ Invalid index: $index');
				return;
			}
			
			final notificationRaw = _receivedNotifications[index];
			final notification = <String, dynamic>{};
			for (final key in notificationRaw.keys) {
				notification[key.toString()] = notificationRaw[key];
			}
			debugPrint('📧 Deleting notification: ${notification['title']} (ID: ${notification['id']})');
			
			// FIRST: Remove from ALL storage locations
			await _removeNotificationEverywhere(notification);
			
			// THEN: Update local state
			debugPrint('📝 Updating UI state - current list size: ${_receivedNotifications.length}');
			if (mounted) {
				setState(() {
					_receivedNotifications.removeAt(index);
					_unreadCount = _receivedNotifications.where((n) => n['read'] != true).length;
				});
				debugPrint('✅ UI updated - new list size: ${_receivedNotifications.length}');
			} else {
				debugPrint('❌ Widget not mounted, cannot update UI');
				return;
			}
			
			// FINALLY: Save the updated list
			debugPrint('💾 Saving updated list to storage...');
			await _persistReceived();
			debugPrint('✅ List saved to storage');
			await _pruneInboxForNotification(notification);
			if (widget.allowBroadcast) {
				await _loadSentHistory();
			}
			
			if (mounted) {
				_showSnack('Notification permanently deleted', color: Colors.redAccent);
			}
		} catch (e, stackTrace) {
			debugPrint('❌ ERROR deleting notification: $e');
			debugPrint('Stack trace: $stackTrace');
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text('Error deleting notification: $e'),
						backgroundColor: Colors.red,
						duration: const Duration(seconds: 3),
					),
				);
			}
		}
	}

	Future<void> _deleteSentMessage(int index) async {
		try {
			if (index < 0 || index >= _sentHistory.length) return;
			final notificationRaw = _sentHistory[index];
			final notification = <String, dynamic>{};
			for (final key in notificationRaw.keys) {
				notification[key.toString()] = notificationRaw[key];
			}
			
			// FIRST: Remove from ALL storage locations
			await _removeNotificationEverywhere(notification);
			
			// THEN: Update local state
			setState(() => _sentHistory.removeAt(index));
			
			// FINALLY: Save the updated sent history
			final prefs = await SharedPreferences.getInstance();
			await prefs.setString('admin_sent_notifications', jsonEncode(_sentHistory));
			await _pruneInboxForNotification(notification);
			
			_showSnack('Sent message permanently deleted', color: Colors.redAccent);
		} catch (e, stackTrace) {
			debugPrint('❌ ERROR deleting sent message: $e');
			debugPrint('Stack trace: $stackTrace');
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text('Error deleting message: $e'),
						backgroundColor: Colors.red,
						duration: const Duration(seconds: 3),
					),
				);
			}
		}
	}

	void _showSnack(String message, {Color color = Colors.teal}) {
		if (!mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(message),
				backgroundColor: color,
				duration: const Duration(seconds: 2),
			),
		);
	}

	Future<void> _appendNotification(
		SharedPreferences prefs,
		String key,
		Map<String, dynamic> notification,
	) async {
		final raw = prefs.getString(key);
		final List<Map<String, dynamic>> entries;
		if (raw != null && raw.isNotEmpty) {
			final decoded = jsonDecode(raw);
			if (decoded is List) {
				entries = decoded.whereType<Map>().map((e) {
					final Map<String, dynamic> converted = {};
					for (final k in e.keys) {
						converted[k.toString()] = e[k];
					}
					return converted;
				}).toList();
			} else {
				entries = <Map<String, dynamic>>[];
			}
		} else {
			entries = <Map<String, dynamic>>[];
		}
		entries.insert(0, notification);
		if (entries.length > 60) {
			entries.removeRange(60, entries.length);
		}
		await prefs.setString(key, jsonEncode(entries));
	}

	Future<void> _removeNotificationEverywhere(Map<String, dynamic> notification) async {
		final id = notification['id']?.toString();
		final timestamp = notification['timestamp']?.toString();
		final originalId = notification['originalId']?.toString();
		final signature = _computeNotificationSignature(notification);
	
		debugPrint('🗑️ Starting global removal - signature: $signature');
		
		final prefs = await SharedPreferences.getInstance();
		
		// Get ALL notification-related keys from SharedPreferences
		final allKeys = prefs.getKeys().where((key) =>
			key == 'user_notifications' ||
			key == 'admin_notifications' ||
			key == 'admin_sent_notifications' ||
			key.endsWith('_notifications')).toSet();
		
		int totalDeleted = 0;
		
		for (final key in allKeys) {
			final raw = prefs.getString(key);
			if (raw == null || raw.isEmpty) {
				debugPrint('ℹ️ [$key] empty, skipping');
				continue;
			}
			
			List<dynamic> decoded;
			try {
				decoded = jsonDecode(raw) as List<dynamic>;
			} catch (_) {
				debugPrint('⚠️ [$key] decode error, skipping');
				continue;
			}
			
		final entries = decoded
			.whereType<Map>()
			.map((entry) {
				final Map<String, dynamic> converted = {};
				for (final key in entry.keys) {
					converted[key.toString()] = entry[key];
				}
				return converted;
			})
			.toList();			final originalLength = entries.length;
			debugPrint('📦 [$key] before delete: $originalLength entries');
			
			// Remove matching notifications
			entries.removeWhere((entry) {
				final entryMap = <String, dynamic>{};
				for (final k in entry.keys) {
					entryMap[k.toString()] = entry[k];
				}
				final entrySignature = _computeNotificationSignature(entryMap);
				if (entrySignature == signature) {
					return true;
				}
				final entryId = entryMap['id']?.toString();
				if (id != null && id.isNotEmpty && entryId == id) {
					return true;
				}
				final entryOriginalId = entryMap['originalId']?.toString();
				if (originalId != null && originalId.isNotEmpty && entryOriginalId == originalId) {
					return true;
				}
				if (timestamp != null && timestamp.isNotEmpty) {
					final entryTimestamp = entryMap['timestamp']?.toString();
					if (entryTimestamp == timestamp) {
						return true;
					}
				}
				return false;
			});
			
			// Save if anything was removed
			if (entries.length != originalLength) {
				final removedCount = originalLength - entries.length;
				totalDeleted += removedCount;
				await prefs.setString(key, jsonEncode(entries));
				debugPrint('✅ [$key] removed $removedCount item(s)');
			} else {
				debugPrint('ℹ️ [$key] no matching entries removed');
			}
		}

		// Debug: Log how many were deleted
		debugPrint('🗑️ Deleted notification from $totalDeleted location(s). ID: $id');
	}

	bool _matchesNotification(
		Map<String, dynamic> candidate, {
		required String signature,
		String? id,
		String? originalId,
		String? timestamp,
	}) {
		try {
			final entrySignature = _computeNotificationSignature(candidate);
			if (entrySignature == signature) {
				return true;
			}
		} catch (e) {
			debugPrint('⚠️ Error computing signature for candidate: $e');
		}
		
		final entryId = candidate['id']?.toString();
		if (id != null && id.isNotEmpty && entryId == id) {
			return true;
		}
		final entryOriginalId = candidate['originalId']?.toString();
		if (originalId != null && originalId.isNotEmpty && entryOriginalId == originalId) {
			return true;
		}
		if (timestamp != null && timestamp.isNotEmpty) {
			final entryTimestamp = candidate['timestamp']?.toString();
			if (entryTimestamp == timestamp) {
				return true;
			}
		}
		return false;
	}

	Future<void> _pruneInboxForNotification(Map<String, dynamic> notification) async {
		if (_receivedNotifications.isEmpty) {
			return;
		}

		final signature = _computeNotificationSignature(notification);
		final id = notification['id']?.toString();
		final originalId = notification['originalId']?.toString();
		final timestamp = notification['timestamp']?.toString();

		final before = _receivedNotifications.length;
		final filtered = _receivedNotifications
			.where((entry) => !_matchesNotification(
				entry,
				signature: signature,
				id: id,
				originalId: originalId,
				timestamp: timestamp,
			))
			.toList(growable: true);

		if (filtered.length == before) {
			return;
		}

		if (mounted) {
			setState(() {
				_receivedNotifications
					..clear()
					..addAll(filtered);
				_unreadCount = _receivedNotifications.where((n) => n['read'] != true).length;
			});
		} else {
			_receivedNotifications
				..clear()
				..addAll(filtered);
			_unreadCount = _receivedNotifications.where((n) => n['read'] != true).length;
		}

		await _persistReceived();
	}

	Future<void> _updateReplyPermission(String username, bool allow) async {
		final prefs = await SharedPreferences.getInstance();
		final list = prefs.getStringList('notification_reply_allowlist') ?? <String>[];
		final lower = username.toLowerCase();
		if (allow) {
			if (!list.contains(lower)) {
				list.add(lower);
			}
		} else {
			list.remove(lower);
		}
		await prefs.setStringList('notification_reply_allowlist', list);
		if (!mounted) return;
		setState(() {
			_replyAllowedUsers
				..clear()
				..addAll(list.map((e) => e.toLowerCase()));
		});
	}

	Future<void> _sendNotification() async {
		if (_isSending) return;

		final title = _titleController.text.trim();
		final body = _messageController.text.trim();

		if (title.isEmpty || body.isEmpty) {
			_showSnack('Please add both a title and a message', color: Colors.orangeAccent);
			return;
		}

		if (_selectedScopes.isEmpty) {
			setState(() => _scopeError = 'Choose at least one menu');
			_showSnack('Select at least one menu', color: Colors.orangeAccent);
			return;
		}

		if (!_sendToAll && _targetUserController.text.trim().isEmpty) {
			_showSnack('Enter a username for targeted sends', color: Colors.orangeAccent);
			return;
		}

		setState(() {
			_isSending = true;
			_scopeError = null;
		});

		try {
			final prefs = await SharedPreferences.getInstance();
			final now = DateTime.now();
			final scopesSource = _sendToAll ? _allScopes : _selectedScopes;
			final scopes = scopesSource.map((e) => e.toLowerCase()).toList();
			final allowReplies = !_sendToAll && _isReplyAllowedForTargetUser;

			final payload = <String, dynamic>{
				'id': now.microsecondsSinceEpoch.toString(),
				'title': title,
				'message': body,
				'type': _notificationType,
				'timestamp': now.toIso8601String(),
				'read': false,
				'fromAdmin': widget.allowBroadcast,
				'scopes': scopes,
				'allowReplies': allowReplies,
				'attachments': _attachments.map((a) => a.toJson()).toList(),
			};
			if (!widget.allowBroadcast) {
				payload['fromUser'] = _currentUsername;
			}

			if (_sendToAll) {
				await _appendNotification(prefs, 'admin_notifications', payload);
				await _appendNotification(prefs, 'user_notifications', payload);
			} else {
				final target = _targetUserController.text.trim().toLowerCase();
				await _appendNotification(prefs, '${target}_notifications', payload);
				if (widget.allowBroadcast) {
					await _updateReplyPermission(target, allowReplies);
				}
			}

			if (widget.allowBroadcast) {
				final historyEntry = {
					...payload,
					'target': _sendToAll ? 'everyone' : _targetUserController.text.trim(),
				};
				await _appendNotification(prefs, 'admin_sent_notifications', historyEntry);
			}

			if (!mounted) return;
			setState(() {
				_attachments.clear();
				_titleController.clear();
				_messageController.clear();
				if (!_sendToAll) {
					if (widget.allowBroadcast) {
						_targetUserController.clear();
					} else {
						_targetUserController.text = 'admin';
					}
				}
			});

			if (widget.allowBroadcast) {
				await _loadSentHistory();
			}
			await _loadReceivedNotifications();

			_showSnack('Notification sent');
		} catch (err) {
			_showSnack('Failed to send notification: $err', color: Colors.redAccent);
		} finally {
			if (mounted) {
				setState(() => _isSending = false);
			}
		}
	}

	Future<void> _sendMemberMessage() async {
		if (_isSending || !_memberComposerActive || !_canSendMemberMessage) {
			return;
		}

		final body = _memberMessageController.text.trim();
		final message = body.isEmpty && _attachments.isNotEmpty ? '(attachment)' : body;
		if (message.isEmpty && _attachments.isEmpty) {
			_showSnack('Add a message or attachment before sending', color: Colors.orangeAccent);
			return;
		}

		setState(() => _isSending = true);

		try {
			final prefs = await SharedPreferences.getInstance();
			final now = DateTime.now();
			final scopes = widget.scopes.isEmpty
					? <String>['global']
					: widget.scopes.map((e) => e.toLowerCase()).toList();
			final attachments = _attachments.map((a) => a.toJson()).toList();
			final payload = <String, dynamic>{
				'id': 'member_${now.microsecondsSinceEpoch}',
				'title': 'Message from $_currentUsername',
				'message': message,
				'type': 'member',
				'timestamp': now.toIso8601String(),
				'read': false,
				'fromUser': _currentUsername,
				'fromAdmin': false,
				'allowReplies': false,
				'scopes': scopes,
				'attachments': attachments,
			};

			await _appendNotification(prefs, 'admin_notifications', payload);
			final selfKey = '${_currentUsername.toLowerCase()}_notifications';
			final userCopy = Map<String, dynamic>.from(payload)..['read'] = true;
			await _appendNotification(prefs, selfKey, userCopy);

			if (!mounted) return;
			FocusScope.of(context).unfocus();
			setState(() {
				_memberMessageController.clear();
				_attachments.clear();
			});

			await _loadReceivedNotifications();
			_showSnack('Message sent to admin');
		} catch (err) {
			_showSnack('Failed to send message: $err', color: Colors.redAccent);
		} finally {
			if (mounted) {
				setState(() => _isSending = false);
			}
		}
	}

	List<NotificationAttachment> _parseAttachments(Map<String, dynamic> notification) {
		final raw = notification['attachments'];
		if (raw is! List) return const [];
		return raw
				.whereType<Map>()
				.map((e) => NotificationAttachment.fromJson(e.cast<String, dynamic>()))
				.toList();
	}

	Future<void> _togglePlayback(NotificationAttachment attachment) async {
		if (attachment.type != NotificationAttachmentType.audio) return;

		if (_playingAttachmentId == attachment.id) {
			await _audioPlayer.stop();
			if (mounted) {
				setState(() => _playingAttachmentId = null);
			}
			return;
		}

		final tempDir = await getTemporaryDirectory();
		final file = File('${tempDir.path}/${attachment.id}.m4a');
		await file.writeAsBytes(attachment.bytes, flush: true);

		await _audioPlayer.stop();
		_playerCompleteSub?.cancel();
		_playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
			if (mounted) {
				setState(() => _playingAttachmentId = null);
			}
		});

		await _audioPlayer.play(DeviceFileSource(file.path));
		if (mounted) {
			setState(() => _playingAttachmentId = attachment.id);
		}
	}

	Future<void> _pickImageAttachment() async {
		if (!_canAddMoreAttachments) return;

		final result = await FilePicker.platform.pickFiles(type: FileType.image);
		if (result == null || result.files.isEmpty) return;

		final file = result.files.first;
		final bytes = file.bytes ?? await File(file.path!).readAsBytes();
		if (!mounted) return;
		setState(() {
					_attachments.add(
						NotificationAttachment(
							id: DateTime.now().microsecondsSinceEpoch.toString(),
							type: NotificationAttachmentType.image,
							bytes: bytes,
							name: file.name,
							mimeType: 'image/${file.extension ?? 'jpeg'}',
						),
					);
		});
	}

	Future<void> _toggleRecording() async {
		if (_isRecording) {
			await _stopRecording(save: true);
		} else {
			await _startRecording();
		}
	}

	Future<void> _startRecording() async {
		if (!_canAddMoreAttachments) return;

		final status = await Permission.microphone.request();
		if (!status.isGranted) {
			_showSnack('Microphone permission needed', color: Colors.orangeAccent);
			return;
		}

		final hasPermission = await _recorder.hasPermission();
		if (!hasPermission) {
			_showSnack('Microphone access denied', color: Colors.orangeAccent);
			return;
		}

		final tempDir = await getTemporaryDirectory();
		final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

		await _recorder.start(
			const RecordConfig(
				encoder: AudioEncoder.aacLc,
				bitRate: 128000,
				sampleRate: 44100,
			),
			path: path,
		);

		if (mounted) {
			setState(() => _isRecording = true);
		}
	}

		Future<void> _stopRecording({bool save = false}) async {
			final path = await _recorder.stop();
		if (mounted) {
			setState(() => _isRecording = false);
		}
		if (!save || path == null) return;
		final file = File(path);
		if (!await file.exists()) return;
		final bytes = await file.readAsBytes();
		if (!mounted) return;
		setState(() {
			_attachments.add(
				NotificationAttachment(
					id: DateTime.now().microsecondsSinceEpoch.toString(),
					type: NotificationAttachmentType.audio,
					bytes: bytes,
					name: 'Voice note ${_attachments.length + 1}',
					mimeType: 'audio/m4a',
				),
			);
		});
	}

	Widget _buildAttachmentChips() {
		if (_attachments.isEmpty && !_isRecording) {
			return const SizedBox.shrink();
		}

		return Wrap(
			spacing: 8,
			runSpacing: 8,
			children: [
				if (_isRecording)
					Chip(
						avatar: const Icon(Icons.mic, color: Colors.redAccent, size: 18),
						label: const Text('Recording…', style: TextStyle(color: Colors.white)),
						backgroundColor: Colors.red.withValues(alpha: 0.2),
						deleteIcon: const Icon(Icons.stop, color: Colors.white70, size: 18),
						onDeleted: () => _stopRecording(save: true),
					),
				..._attachments.map(
					(attachment) => Chip(
						avatar: Icon(
							attachment.isAudio ? Icons.graphic_eq_rounded : Icons.image_rounded,
							color: Colors.white,
							size: 18,
						),
						label: Text(attachment.name, style: const TextStyle(color: Colors.white)),
						backgroundColor: Colors.white.withValues(alpha: 0.1),
						deleteIcon: const Icon(Icons.close, color: Colors.white70, size: 18),
						onDeleted: () => setState(() => _attachments.remove(attachment)),
					),
				),
			],
		);
	}

	Widget _buildAttachmentViewer(List<NotificationAttachment> attachments) {
		if (attachments.isEmpty) return const SizedBox.shrink();
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: attachments.map((attachment) {
				if (attachment.isImage) {
					return Container(
						margin: const EdgeInsets.only(top: 12),
						decoration: BoxDecoration(
							borderRadius: BorderRadius.circular(16),
							border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
						),
						clipBehavior: Clip.antiAlias,
						child: Image.memory(
							attachment.bytes,
							height: 160,
							width: double.infinity,
							fit: BoxFit.cover,
						),
					);
				}
				final isPlaying = _playingAttachmentId == attachment.id;
				return Container(
					margin: const EdgeInsets.only(top: 12),
					padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
					decoration: BoxDecoration(
						color: Colors.white.withValues(alpha: 0.06),
						borderRadius: BorderRadius.circular(16),
						border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
					),
					child: Row(
						children: [
							IconButton(
								icon: Icon(isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_fill_rounded),
								color: Colors.white,
								onPressed: () => _togglePlayback(attachment),
							),
							const SizedBox(width: 12),
							Expanded(
								child: Text(
									attachment.name,
									style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
									overflow: TextOverflow.ellipsis,
								),
							),
						],
					),
				);
			}).toList(),
		);
	}

	Widget _buildUserComposeToggle() {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
			decoration: BoxDecoration(
				color: Colors.white.withValues(alpha: 0.06),
				borderRadius: BorderRadius.circular(18),
				border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
			),
			child: Row(
				children: [
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								const Text(
									'Member compose permission',
									style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
								),
								const SizedBox(height: 4),
								Text(
									'Let users send messages with images and voice notes when enabled.',
									style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
								),
							],
						),
					),
					Switch(
						value: _userComposeEnabled,
						onChanged: (value) async {
							await _setUserComposeEnabled(value);
							if (mounted) {
								_showSnack(
									value ? 'Members can now compose notifications' : 'Member compose access disabled',
									color: value ? Colors.tealAccent : Colors.orangeAccent,
								);
							}
						},
						thumbColor: const WidgetStatePropertyAll<Color>(Colors.tealAccent),
					),
				],
			),
		);
	}

		Widget _buildNotificationTypeSelector() {
			final options = <Map<String, dynamic>>[
				{'id': 'info', 'label': 'Info', 'icon': Icons.info_rounded, 'color': Colors.blue},
				{'id': 'success', 'label': 'Success', 'icon': Icons.check_circle_rounded, 'color': Colors.green},
				{'id': 'warning', 'label': 'Warning', 'icon': Icons.warning_amber_rounded, 'color': Colors.orange},
				{'id': 'urgent', 'label': 'Urgent', 'icon': Icons.priority_high_rounded, 'color': Colors.red},
			];

			return Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					const Text(
						'Alert Style',
						style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
					),
					const SizedBox(height: 12),
					Wrap(
						spacing: 12,
						runSpacing: 12,
						children: options.map((option) {
							final selected = _notificationType == option['id'];
							final Color color = option['color'] as Color;
							return ChoiceChip(
								selected: selected,
								onSelected: (_) => setState(() => _notificationType = option['id'] as String),
								label: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										Icon(option['icon'] as IconData, size: 18, color: Colors.white),
										const SizedBox(width: 6),
										Text(option['label'] as String, style: const TextStyle(color: Colors.white)),
									],
								),
								selectedColor: color.withValues(alpha: 0.6),
								backgroundColor: Colors.white.withValues(alpha: 0.08),
								shape: StadiumBorder(side: BorderSide(color: color.withValues(alpha: 0.5))),
							);
						}).toList(),
					),
				],
			);
		}

		Widget _buildScopeSelector() {
			return Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					const Text(
						'Target Menus',
						style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
					),
					const SizedBox(height: 12),
					Wrap(
						spacing: 8,
						runSpacing: 8,
						children: _scopeLabels.entries.map((entry) {
							final scope = entry.key;
							final label = entry.value;
							final selected = _selectedScopes.contains(scope);
							return FilterChip(
								label: Text(label, style: const TextStyle(color: Colors.white)),
								selected: selected,
								onSelected: (value) {
									setState(() {
										if (value) {
											_selectedScopes.add(scope);
										} else {
											_selectedScopes.remove(scope);
										}
										if (_selectedScopes.isEmpty) {
											_selectedScopes.add('global');
										}
									});
								},
								backgroundColor: Colors.white.withValues(alpha: 0.08),
								selectedColor: Colors.teal.withValues(alpha: 0.6),
							);
						}).toList(),
					),
					if (_scopeError != null) ...[
						const SizedBox(height: 8),
						Text(_scopeError!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 13)),
					],
				],
			);
		}

		Widget _buildTargetingControls() {
			if (!widget.allowBroadcast) {
				return Container(
					padding: const EdgeInsets.all(16),
					decoration: BoxDecoration(
						color: Colors.white.withValues(alpha: 0.06),
						borderRadius: BorderRadius.circular(18),
						border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
					),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Row(
								children: [
									Container(
										width: 36,
										height: 36,
										decoration: BoxDecoration(
											color: Colors.tealAccent.withValues(alpha: 0.2),
											shape: BoxShape.circle,
										),
										child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 18),
									),
									const SizedBox(width: 12),
									Expanded(
										child: Text(
											'Sending directly to the admin team',
											style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
										),
									),
								],
							),
							const SizedBox(height: 10),
							Text(
								'Attachments and voice notes are private between you and the admins.',
								style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
							),
							const SizedBox(height: 6),
							Text(
								'Admins can reply back when this setting is enabled.',
								style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
							),
						],
					),
				);
			}

			return Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Row(
						children: [
							Switch(
								value: !_sendToAll,
								onChanged: (value) {
									setState(() {
										_sendToAll = !value;
										if (_sendToAll) {
											_selectedScopes
												..clear()
												..addAll(_allScopes);
										}
									});
								},
								thumbColor: const WidgetStatePropertyAll<Color>(Colors.tealAccent),
							),
							const SizedBox(width: 8),
							Text(
								_sendToAll ? 'Send to everyone' : 'Send to specific user',
								style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
							),
						],
					),
					if (!_sendToAll) ...[
						const SizedBox(height: 12),
						TextField(
							controller: _targetUserController,
							style: const TextStyle(color: Colors.white),
							decoration: InputDecoration(
								labelText: 'Username',
								labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
								filled: true,
								fillColor: Colors.white.withValues(alpha: 0.08),
								border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
							),
						),
						const SizedBox(height: 12),
						Row(
							children: [
								const Icon(Icons.reply_rounded, color: Colors.white70),
								const SizedBox(width: 8),
								Expanded(
									child: Text(
										'Allow replies from this user',
										style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
									),
								),
								Switch(
									value: _isReplyAllowedForTargetUser,
									onChanged: (value) => setState(() => _isReplyAllowedForTargetUser = value),
									thumbColor: const WidgetStatePropertyAll<Color>(Colors.tealAccent),
								),
							],
						),
					],
				],
			);
		}

		Widget _buildComposeFields() {
			return Column(
				children: [
					TextField(
						controller: _titleController,
						style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
						decoration: InputDecoration(
							labelText: 'Title',
							labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
							filled: true,
							fillColor: Colors.white.withValues(alpha: 0.08),
							border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
						),
					),
					const SizedBox(height: 12),
					TextField(
						controller: _messageController,
						style: const TextStyle(color: Colors.white),
						maxLines: 6,
						decoration: InputDecoration(
							labelText: 'Message',
							labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
							filled: true,
							fillColor: Colors.white.withValues(alpha: 0.08),
							border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
						),
					),
				],
			);
		}

		Widget _buildAttachmentButtons() {
			return Wrap(
				spacing: 12,
				runSpacing: 12,
				children: [
					ElevatedButton.icon(
						onPressed: _canAddMoreAttachments ? _pickImageAttachment : null,
						icon: const Icon(Icons.image_rounded),
						label: const Text('Add Image'),
						style: ElevatedButton.styleFrom(
							backgroundColor: Colors.white.withValues(alpha: 0.08),
							foregroundColor: Colors.white,
							shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
						),
					),
					ElevatedButton.icon(
						onPressed: _toggleRecording,
						icon: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded),
						label: Text(_isRecording ? 'Stop Recording' : 'Record Voice'),
						style: ElevatedButton.styleFrom(
							backgroundColor: _isRecording ? Colors.redAccent : Colors.white.withValues(alpha: 0.08),
							foregroundColor: Colors.white,
							shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
						),
					),
				],
			);
		}

		Widget _buildSentHistoryTile(Map<String, dynamic> notification) {
			final date = DateTime.tryParse(notification['timestamp']?.toString() ?? '');
			final scopes = (notification['scopes'] as List?)?.cast<String>() ?? const <String>[];
			final target = notification['target']?.toString() ?? 'everyone';
			return Container(
				margin: const EdgeInsets.only(bottom: 12),
				padding: const EdgeInsets.all(16),
				decoration: BoxDecoration(
					color: Colors.white.withValues(alpha: 0.05),
					borderRadius: BorderRadius.circular(18),
					border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
				),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							children: [
								Expanded(
									child: Text(
										notification['title']?.toString() ?? 'Notification',
										style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
									),
								),
								IconButton(
									icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
									onPressed: () {
										final index = _sentHistory.indexOf(notification);
										if (index != -1) {
											_deleteSentMessage(index);
										}
									},
								),
							],
						),
						const SizedBox(height: 8),
						Text(
							notification['message']?.toString() ?? '',
							style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
						),
						const SizedBox(height: 12),
						Wrap(
							spacing: 8,
							runSpacing: 8,
							children: [
								Chip(
									label: Text('Target: $target'),
									backgroundColor: Colors.white.withValues(alpha: 0.08),
									labelStyle: const TextStyle(color: Colors.white),
								),
								Chip(
									label: Text('Scopes: ${scopes.isEmpty ? 'global' : scopes.join(', ')}'),
									backgroundColor: Colors.white.withValues(alpha: 0.08),
									labelStyle: const TextStyle(color: Colors.white),
								),
								if (date != null)
									Chip(
										label: Text(_formatDate(date)),
										backgroundColor: Colors.white.withValues(alpha: 0.08),
										labelStyle: const TextStyle(color: Colors.white),
									),
							],
						),
					],
				),
			);
		}

		Widget _buildNotificationCard(Map<String, dynamic> notification, int index) {
			final bool isRead = notification['read'] == true;
			final bool fromUser = notification['fromUser'] != null;
			final bool allowReplies = notification['allowReplies'] == true;
			final DateTime? timestamp = DateTime.tryParse(notification['timestamp']?.toString() ?? '');
			final attachments = _parseAttachments(notification);

			final type = (notification['type'] as String?) ?? 'info';
			Color accent;
			IconData icon;
			switch (type) {
				case 'success':
					accent = Colors.green;
					icon = Icons.check_circle_rounded;
					break;
				case 'warning':
					accent = Colors.orange;
					icon = Icons.warning_amber_rounded;
					break;
				case 'urgent':
					accent = Colors.red;
					icon = Icons.priority_high_rounded;
					break;
				case 'reply':
					accent = Colors.purple;
					icon = Icons.reply_rounded;
					break;
				default:
					accent = Colors.blue;
					icon = Icons.info_rounded;
			}
			if (fromUser) {
				accent = Colors.purple;
				icon = Icons.reply_rounded;
			}

			return Container(
				margin: const EdgeInsets.only(bottom: 18),
				padding: const EdgeInsets.all(18),
				decoration: BoxDecoration(
					borderRadius: BorderRadius.circular(22),
					border: Border.all(color: accent.withValues(alpha: isRead ? 0.25 : 0.6), width: 1.5),
					gradient: LinearGradient(
						begin: Alignment.topLeft,
						end: Alignment.bottomRight,
						colors: [
							accent.withValues(alpha: isRead ? 0.18 : 0.28),
							Colors.black.withValues(alpha: 0.4),
						],
					),
				),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Container(
									padding: const EdgeInsets.all(10),
									decoration: BoxDecoration(
										color: accent.withValues(alpha: 0.8),
										borderRadius: BorderRadius.circular(16),
									),
									child: Icon(icon, color: Colors.white, size: 22),
								),
								const SizedBox(width: 12),
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												notification['title']?.toString() ?? 'Notification',
												style: TextStyle(
													color: Colors.white,
													fontSize: 16,
													fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
												),
											),
											const SizedBox(height: 4),
											if (timestamp != null)
												Text(
													_formatDate(timestamp),
													style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
												),
										],
									),
								),
								if (!isRead)
									Container(
										padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
										decoration: BoxDecoration(
											color: Colors.green.shade700,
											borderRadius: BorderRadius.circular(16),
										),
										child: const Text(
											'NEW',
											style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
										),
									),
							],
						),
						if (notification['originalMessage'] != null) ...[
							const SizedBox(height: 12),
							Container(
								padding: const EdgeInsets.all(12),
								decoration: BoxDecoration(
									color: Colors.purple.withValues(alpha: 0.15),
									borderRadius: BorderRadius.circular(16),
									border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
								),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											'Reply to: ${notification['originalTitle'] ?? ''}',
											style: TextStyle(color: Colors.purple.shade100, fontWeight: FontWeight.bold),
										),
										const SizedBox(height: 4),
										Text(
											notification['originalMessage']?.toString() ?? '',
											style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontStyle: FontStyle.italic),
										),
									],
								),
							),
						],
						const SizedBox(height: 12),
						Text(
							notification['message']?.toString() ?? '',
							style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.4),
						),
						_buildAttachmentViewer(attachments),
						const SizedBox(height: 16),
						Wrap(
							spacing: 12,
							runSpacing: 8,
							children: [
								TextButton.icon(
									onPressed: () => isRead ? _markAsUnread(index) : _markAsRead(index),
									icon: Icon(isRead ? Icons.mark_email_unread_rounded : Icons.mark_email_read_rounded),
									label: Text(isRead ? 'Mark unread' : 'Mark read'),
									style: TextButton.styleFrom(foregroundColor: Colors.white),
								),
								  if (!widget.allowCompose && allowReplies && !fromUser && _currentUserRepliesAllowed)
									TextButton.icon(
										onPressed: () => _promptReply(notification),
										icon: const Icon(Icons.reply_rounded),
										label: const Text('Reply'),
										style: TextButton.styleFrom(foregroundColor: Colors.white),
									),
								if (widget.allowBroadcast)
									TextButton.icon(
										onPressed: () async {
											debugPrint('🔴 Remove button tapped for index: $index');
											try {
												await _deleteReceivedNotification(index);
												debugPrint('✅ Delete completed successfully');
											} catch (e) {
												debugPrint('❌ Delete failed: $e');
												if (mounted) {
													ScaffoldMessenger.of(context).showSnackBar(
														SnackBar(
															content: Text('Error deleting notification: $e'),
															backgroundColor: Colors.red,
														),
													);
												}
											}
										},
										icon: const Icon(Icons.delete_rounded),
										label: const Text('Remove'),
										style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
									),
							],
						),
					],
				),
			);
		}

		Widget _buildEmptyInboxState() {
			return Container(
				margin: const EdgeInsets.only(top: 40),
				padding: const EdgeInsets.all(32),
				decoration: BoxDecoration(
					borderRadius: BorderRadius.circular(24),
					gradient: LinearGradient(
						colors: [
							Colors.white.withValues(alpha: 0.05),
							Colors.white.withValues(alpha: 0.02),
						],
					),
					border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
				),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Icon(Icons.notifications_none_rounded, size: 56, color: Colors.white.withValues(alpha: 0.35)),
						const SizedBox(height: 16),
						Text(
							'No notifications yet',
							style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
						),
					],
				),
			);
		}

		Widget _buildComposeTab() {
			return SingleChildScrollView(
				padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						if (widget.allowBroadcast) ...[
							_buildUserComposeToggle(),
							const SizedBox(height: 24),
						],
						_buildNotificationTypeSelector(),
						const SizedBox(height: 24),
						_buildScopeSelector(),
						const SizedBox(height: 24),
						_buildTargetingControls(),
						const SizedBox(height: 24),
						_buildComposeFields(),
						const SizedBox(height: 20),
						_buildAttachmentButtons(),
						const SizedBox(height: 12),
						_buildAttachmentChips(),
						const SizedBox(height: 24),
						SizedBox(
							width: double.infinity,
							child: ElevatedButton.icon(
								onPressed: _isSending ? null : _sendNotification,
								icon: _isSending
										? const SizedBox(
												width: 16,
												height: 16,
												child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
											)
										: const Icon(Icons.send_rounded),
								label: Text(_isSending ? 'Sending…' : 'Send notification'),
								style: ElevatedButton.styleFrom(
									backgroundColor: Colors.tealAccent.withValues(alpha: 0.3),
									foregroundColor: Colors.white,
									padding: const EdgeInsets.symmetric(vertical: 16),
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
								),
							),
						),
						if (widget.allowBroadcast) ...[
							const SizedBox(height: 32),
							const Divider(color: Colors.white12),
							const SizedBox(height: 24),
							const Text(
								'Recently sent',
								style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
							),
							const SizedBox(height: 16),
							if (_sentHistory.isEmpty)
								Text(
									'Sent messages from the last 48 hours will appear here.',
									style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
								)
							else
								..._sentHistory.map(_buildSentHistoryTile),
						],
					],
				),
			);
		}

		Widget _buildInboxTab() {
			final showComposer = _memberComposerActive;
			final bottomPadding = showComposer ? 220.0 : 120.0;
			final listView = ListView.builder(
				padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
				physics: const AlwaysScrollableScrollPhysics(),
				itemCount: _receivedNotifications.isEmpty ? 1 : _receivedNotifications.length,
				itemBuilder: (context, index) {
					if (_receivedNotifications.isEmpty) {
						return _buildEmptyInboxState();
					}
					final notification = _receivedNotifications[index];
					return _buildNotificationCard(notification, index);
				},
			);

			return Column(
				children: [
					Expanded(
						child: RefreshIndicator(
							onRefresh: _loadReceivedNotifications,
							backgroundColor: Colors.black87,
							color: Colors.tealAccent,
							child: listView,
						),
					),
					if (showComposer) _buildMemberComposerBar(),
				],
			);
		}

		Widget _buildMemberComposerBar() {
			final bottomInset = MediaQuery.of(context).viewInsets.bottom;
			final inset = bottomInset > 12 ? bottomInset - 12 : 0.0;
			return AnimatedPadding(
				duration: const Duration(milliseconds: 200),
				padding: EdgeInsets.only(bottom: inset),
				child: SafeArea(
					top: false,
					child: Container(
						padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
						decoration: BoxDecoration(
							color: const Color(0xFF161622).withValues(alpha: 0.95),
							borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
							border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
							boxShadow: const [
								BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, -4)),
							],
						),
						child: Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								if (_attachments.isNotEmpty || _isRecording) ...[
									_buildAttachmentChips(),
									const SizedBox(height: 12),
								],
								Row(
									crossAxisAlignment: CrossAxisAlignment.end,
									children: [
										Expanded(
											child: TextField(
												controller: _memberMessageController,
												style: const TextStyle(color: Colors.white),
												minLines: 1,
												maxLines: 4,
												textInputAction: TextInputAction.newline,
												decoration: InputDecoration(
													hintText: 'Message admin…',
													hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
													filled: true,
													fillColor: Colors.white.withValues(alpha: 0.08),
													border: OutlineInputBorder(
														borderSide: BorderSide.none,
														borderRadius: BorderRadius.circular(18),
													),
													contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
												),
											),
										),
										const SizedBox(width: 12),
										Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												IconButton(
													icon: const Icon(Icons.image_rounded),
													color: Colors.white,
													onPressed: _canAddMoreAttachments ? _pickImageAttachment : null,
													tooltip: 'Add photo',
												),
												IconButton(
													icon: Icon(_isRecording ? Icons.stop_circle_outlined : Icons.mic_rounded),
													color: _isRecording ? Colors.redAccent : Colors.white,
													onPressed: !_isRecording && !_canAddMoreAttachments ? null : _toggleRecording,
													tooltip: _isRecording ? 'Stop recording' : 'Record voice note',
												),
											],
										),
										const SizedBox(width: 12),
										ElevatedButton(
											onPressed: _canSendMemberMessage && !_isSending ? _sendMemberMessage : null,
											style: ElevatedButton.styleFrom(
												backgroundColor: Colors.tealAccent.withValues(alpha: 0.35),
												foregroundColor: Colors.white,
												padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
												shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
											),
											child: _isSending
												? const SizedBox(
													width: 18,
													height: 18,
													child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
												)
												: const Icon(Icons.send_rounded),
										),
									],
								),
							],
						),
					),
				),
			);
		}

		void _promptReply(Map<String, dynamic> notification) {
			final controller = TextEditingController();
			showModalBottomSheet<void>(
				context: context,
				isScrollControlled: true,
				backgroundColor: const Color(0xFF181824),
				shape: const RoundedRectangleBorder(
					borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
				),
				builder: (context) {
					return Padding(
						padding: EdgeInsets.only(
							left: 24,
							right: 24,
							bottom: MediaQuery.of(context).viewInsets.bottom + 24,
							top: 24,
						),
						child: Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(
									'Reply to ${notification['title'] ?? 'message'}',
									style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
								),
								const SizedBox(height: 16),
								TextField(
									controller: controller,
									style: const TextStyle(color: Colors.white),
									maxLines: 5,
									decoration: InputDecoration(
										hintText: 'Type your reply…',
										hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
										filled: true,
										fillColor: Colors.white.withValues(alpha: 0.08),
										border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
									),
								),
								const SizedBox(height: 20),
								SizedBox(
									width: double.infinity,
									child: ElevatedButton.icon(
										onPressed: () async {
											final text = controller.text.trim();
											if (text.isEmpty) {
												_showSnack('Reply cannot be empty', color: Colors.orangeAccent);
												return;
											}
											Navigator.of(context).pop();
											await _submitUserReply(notification, text);
										},
										icon: const Icon(Icons.send_rounded),
										label: const Text('Send reply'),
										style: ElevatedButton.styleFrom(
											backgroundColor: Colors.tealAccent.withValues(alpha: 0.35),
											foregroundColor: Colors.white,
											padding: const EdgeInsets.symmetric(vertical: 14),
											shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
										),
									),
								),
							],
						),
					);
				},
			);
		}

		Future<void> _submitUserReply(Map<String, dynamic> notification, String reply) async {
			final prefs = await SharedPreferences.getInstance();
			final now = DateTime.now();
			final payload = <String, dynamic>{
				'id': 'reply_${now.microsecondsSinceEpoch}',
				'title': '$_currentUsername replied',
				'message': reply,
				'type': 'reply',
				'timestamp': now.toIso8601String(),
				'read': false,
				'fromUser': _currentUsername,
				'allowReplies': false,
				'originalId': notification['id'],
				'originalTitle': notification['title'],
				'originalMessage': notification['message'],
				'scopes': notification['scopes'] ?? const ['global'],
				'attachments': const [],
			};

			await _appendNotification(prefs, 'admin_notifications', payload);

			final userCopy = Map<String, dynamic>.from(payload)..['read'] = true;
			await _appendNotification(prefs, '${_currentUsername.toLowerCase()}_notifications', userCopy);

			await _loadReceivedNotifications();
			_showSnack('Reply sent');
		}

		String _formatDate(DateTime timestamp) {
			final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
			final minute = timestamp.minute.toString().padLeft(2, '0');
			final ampm = timestamp.hour >= 12 ? 'PM' : 'AM';
			return '${timestamp.month}/${timestamp.day}/${timestamp.year} $hour:$minute $ampm';
		}

		@override
		Widget build(BuildContext context) {
			final tabs = <Tab>[
				if (widget.allowCompose) const Tab(text: 'Compose'),
				Tab(text: _unreadCount > 0 ? 'Inbox (${_unreadCount.toString()})' : 'Inbox'),
			];

			final views = <Widget>[
				if (widget.allowCompose) _buildComposeTab(),
				_buildInboxTab(),
			];

			final headerTitle = widget.titleOverride ?? (widget.allowCompose ? 'Admin Notifications' : 'Notifications');
			final canPop = Navigator.of(context).canPop();
			final leading = canPop
					? IconButton(
						icon: const Icon(Icons.arrow_back, color: Colors.white70),
						onPressed: () => Navigator.of(context).pop(),
					)
					: null;

			if (tabs.length == 1) {
				return Scaffold(
					backgroundColor: const Color(0xFF101018),
					appBar: FloatingHeader(
						title: headerTitle,
						leading: leading,
					),
					body: views.first,
				);
			}

			return Scaffold(
				backgroundColor: const Color(0xFF101018),
				appBar: FloatingHeader(
					title: headerTitle,
					leading: leading,
					bottom: PreferredSize(
						preferredSize: const Size.fromHeight(56),
						child: Padding(
							padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
							child: Container(
								height: 44,
								decoration: BoxDecoration(
									color: Colors.white.withValues(alpha: 0.08),
									borderRadius: BorderRadius.circular(22),
								),
								child: TabBar(
									controller: _tabController,
									tabs: tabs,
									indicator: BoxDecoration(
										color: Colors.tealAccent.withValues(alpha: 0.35),
										borderRadius: BorderRadius.circular(20),
									),
									labelColor: Colors.white,
									unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
									dividerColor: Colors.transparent,
									indicatorSize: TabBarIndicatorSize.tab,
									labelStyle: const TextStyle(fontWeight: FontWeight.w600),
								),
							),
						),
					),
				),
				body: TabBarView(
					controller: _tabController,
					children: views,
				),
			);
		}
		}

