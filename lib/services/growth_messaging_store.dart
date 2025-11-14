import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/growth_chat_models.dart';

class GrowthMessagingStore extends ChangeNotifier {
  GrowthMessagingStore._();

  static final GrowthMessagingStore instance = GrowthMessagingStore._();

  static const String _threadsKey = 'growth_chat_threads_v1';
  static const String _groupCreatorsKey = 'growth_chat_group_creators_v1';
  static const String _threadReadsKey = 'growth_chat_reads_v1';
  static const Duration _deletedRetention = Duration(days: 2);

  final List<GrowthChatThread> _threads = <GrowthChatThread>[];
  final Set<String> _groupCreators = <String>{};
  final Map<String, Map<String, DateTime>> _readMarks =
      <String, Map<String, DateTime>>{};
  bool _loaded = false;
  final Random _random = Random();

  List<GrowthChatThread> get threads =>
      List<GrowthChatThread>.unmodifiable(_threads);

  bool canUserCreateGroup(String userId) {
    if (userId.isEmpty) {
      return false;
    }
    return _groupCreators.contains(userId);
  }

  Map<String, bool> get groupCreatorMap {
    return Map<String, bool>.fromEntries(
      _groupCreators.map((id) => MapEntry<String, bool>(id, true)),
    );
  }

  Future<void> load() async {
    if (_loaded) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    final rawThreads = prefs.getString(_threadsKey);
    if (rawThreads != null && rawThreads.isNotEmpty) {
      _threads
        ..clear()
        ..addAll(decodeGrowthThreads(rawThreads));
    }

    final rawCreators = prefs.getStringList(_groupCreatorsKey) ?? <String>[];
    _groupCreators
      ..clear()
      ..addAll(rawCreators.where((id) => id.isNotEmpty));

    final rawReads = prefs.getString(_threadReadsKey);
    if (rawReads != null && rawReads.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawReads) as Map<String, dynamic>;
        _readMarks
          ..clear()
          ..addAll(decoded.map((userId, value) {
            final threads = <String, DateTime>{};
            if (value is Map<String, dynamic>) {
              value.forEach((threadId, timestamp) {
                if (timestamp is String) {
                  final parsed = DateTime.tryParse(timestamp);
                  if (parsed != null) {
                    threads[threadId] = parsed;
                  }
                }
              });
            }
            return MapEntry(userId, threads);
          }));
      } catch (_) {
        _readMarks.clear();
      }
    }

    final cleaned = _runMaintenanceSweep();
    if (cleaned) {
      await _persist();
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_threadsKey, encodeGrowthThreads(_threads));
    await prefs.setStringList(_groupCreatorsKey, _groupCreators.toList());
    await _persistReads(prefs);
  }

  Future<void> _persistReads([SharedPreferences? prefs]) async {
    final destination = prefs ?? await SharedPreferences.getInstance();
    final serializable = _readMarks.map((userId, threads) {
      final mapped = threads.map(
        (threadId, timestamp) => MapEntry(
          threadId,
          timestamp.toIso8601String(),
        ),
      );
      return MapEntry(userId, mapped);
    });
    await destination.setString(_threadReadsKey, jsonEncode(serializable));
  }

  List<GrowthChatThread> threadsForScope(GrowthChatScope scope) {
    final scoped = _threads
        .where((thread) => thread.scope == scope)
        .map(_visibleThreadSnapshot)
        .toList(growable: false);
    scoped.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return scoped;
  }

  List<GrowthChatThread> threadsForUser(
    String userId,
    GrowthChatScope scope,
  ) {
    if (userId.isEmpty) {
      return <GrowthChatThread>[];
    }
    final scoped = threadsForScope(scope)
        .where(
          (thread) =>
              thread.isBroadcast ||
              thread.participants.any((member) => member.userId == userId),
        )
        .toList(growable: false);
    scoped.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return scoped;
  }

  GrowthChatThread? findThread(String threadId) {
    try {
      return _threads.firstWhere((thread) => thread.id == threadId);
    } catch (_) {
      return null;
    }
  }

  Future<GrowthChatThread> ensureDirectThread({
    required GrowthChatScope scope,
    required GrowthChatParticipant requester,
    required GrowthChatParticipant other,
  }) async {
    await load();
    final existing = _threads.where((thread) {
      if (!thread.isGroup && thread.scope == scope) {
        final hasRequester =
            thread.participants.any((p) => p.userId == requester.userId);
        final hasOther =
            thread.participants.any((p) => p.userId == other.userId);
        return hasRequester && hasOther;
      }
      return false;
    }).toList();

    if (existing.isNotEmpty) {
      return existing.first;
    }

    final now = DateTime.now();
    final newThread = GrowthChatThread(
      id: _generateId('thread'),
      scope: scope,
      isGroup: false,
      isBroadcast: false,
      title: other.displayName,
      createdBy: requester.userId,
      createdAt: now,
      updatedAt: now,
      participants: <GrowthChatParticipant>[requester, other],
      messages: <GrowthChatMessage>[],
      callHistory: <GrowthChatCallRecord>[],
      lockedUntil: null,
    );

    _threads.add(newThread);
    await _persist();
    notifyListeners();
    return newThread;
  }

  Future<GrowthChatThread> createGroupThread({
    required GrowthChatScope scope,
    required String title,
    required String createdBy,
    required List<GrowthChatParticipant> participants,
  }) async {
    await load();
    final now = DateTime.now();
    final newThread = GrowthChatThread(
      id: _generateId('thread'),
      scope: scope,
      isGroup: true,
      isBroadcast: false,
      title: title.trim().isEmpty ? 'New Group' : title.trim(),
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
      participants: participants,
      messages: <GrowthChatMessage>[],
      callHistory: <GrowthChatCallRecord>[],
      lockedUntil: null,
    );

    _threads.add(newThread);
    await _persist();
    notifyListeners();
    return newThread;
  }

  Future<void> renameThread(String threadId, String newTitle) async {
    final thread = findThread(threadId);
    if (thread == null) {
      return;
    }
    final updated = thread.copyWith(
      title: newTitle.trim().isEmpty ? thread.title : newTitle.trim(),
      updatedAt: DateTime.now(),
    );
    final idx = _threads.indexOf(thread);
    _threads[idx] = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> setThreadLockState(
    String threadId,
    bool locked, {
    DateTime? lockedUntil,
  }) async {
    var thread = _ensureThreadCurrent(threadId);
    if (thread == null) {
      return;
    }

    final now = DateTime.now();
    DateTime? resolvedUntil;
    if (locked) {
      if (lockedUntil != null && lockedUntil.isAfter(now)) {
        resolvedUntil = lockedUntil;
      } else if (lockedUntil != null && !lockedUntil.isAfter(now)) {
        resolvedUntil = null;
      } else {
        resolvedUntil = thread.lockedUntil;
      }
    } else {
      resolvedUntil = null;
    }

    if (thread.isLocked == locked && thread.lockedUntil == resolvedUntil) {
      return;
    }

    final updated = thread.copyWith(
      isLocked: locked,
      lockedUntil: resolvedUntil,
      updatedAt: now,
    );

    final idx = _threads.indexOf(thread);
    _threads[idx] = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> addParticipant(
    String threadId,
    GrowthChatParticipant participant,
  ) async {
    var thread = _ensureThreadCurrent(threadId);
    if (thread == null) {
      return;
    }
    final exists =
        thread.participants.any((p) => p.userId == participant.userId);
    if (exists) {
      return;
    }
    final updatedParticipants =
        List<GrowthChatParticipant>.from(thread.participants)..add(participant);
    final updated = thread.copyWith(
      participants: updatedParticipants,
      updatedAt: DateTime.now(),
    );
    final idx = _threads.indexOf(thread);
    _threads[idx] = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> updateParticipantPermissions(
    String threadId,
    String userId,
    bool canCreateGroup,
  ) async {
    var thread = _ensureThreadCurrent(threadId);
    if (thread == null) {
      return;
    }
    final participants = thread.participants.map((participant) {
      if (participant.userId == userId) {
        return participant.copyWith(canCreateGroups: canCreateGroup);
      }
      return participant;
    }).toList();
    final updated = thread.copyWith(
      participants: participants,
      updatedAt: DateTime.now(),
    );
    final idx = _threads.indexOf(thread);
    _threads[idx] = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> sendTextMessage({
    required String threadId,
    required String senderId,
    required String senderName,
    required String content,
  }) async {
    var thread = _ensureThreadCurrent(threadId);
    if (thread == null) {
      return;
    }
    if (_threadIsLocked(thread)) {
      return;
    }
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final updatedParticipants = _participantsWithSender(
      thread.participants,
      senderId,
      senderName,
    );

    final message = GrowthChatMessage(
      id: _generateId('msg'),
      threadId: threadId,
      senderId: senderId,
      senderName: senderName,
      type: GrowthChatMessageType.text,
      content: trimmed,
      imagePath: null,
      timestamp: DateTime.now(),
    );

    final updatedMessages = List<GrowthChatMessage>.from(thread.messages)
      ..add(message);

    final updated = thread.copyWith(
      messages: updatedMessages,
      participants: updatedParticipants,
      updatedAt: message.timestamp,
    );

    final idx = _threads.indexOf(thread);
    _threads[idx] = updated;
    await _persist();
    await _updateReadMark(senderId, threadId, message.timestamp);
    notifyListeners();
  }

  Future<void> sendImageMessage({
    required String threadId,
    required String senderId,
    required String senderName,
    required String content,
    required File source,
  }) async {
    var thread = _ensureThreadCurrent(threadId);
    if (thread == null) {
      return;
    }
    if (_threadIsLocked(thread)) {
      return;
    }
    if (!await source.exists()) {
      return;
    }

    final updatedParticipants = _participantsWithSender(
      thread.participants,
      senderId,
      senderName,
    );

    final stored = await _storeImage(source);
    final message = GrowthChatMessage(
      id: _generateId('msg'),
      threadId: thread.id,
      senderId: senderId,
      senderName: senderName,
      type: GrowthChatMessageType.image,
      content: content.trim(),
      imagePath: stored?.path,
      timestamp: DateTime.now(),
    );

    final updatedMessages = List<GrowthChatMessage>.from(thread.messages)
      ..add(message);

    final updated = thread.copyWith(
      messages: updatedMessages,
      participants: updatedParticipants,
      updatedAt: message.timestamp,
    );

    final idx = _threads.indexOf(thread);
    _threads[idx] = updated;
    await _persist();
    await _updateReadMark(senderId, thread.id, message.timestamp);
    notifyListeners();
  }

  Future<void> sendVoiceMessage({
    required String threadId,
    required String senderId,
    required String senderName,
    required File source,
    required Duration duration,
    String? caption,
  }) async {
    var thread = _ensureThreadCurrent(threadId);
    if (thread == null) {
      return;
    }
    if (_threadIsLocked(thread)) {
      return;
    }
    if (!await source.exists()) {
      return;
    }

    final stored = await _storeVoice(source);
    if (stored == null) {
      return;
    }

    final updatedParticipants = _participantsWithSender(
      thread.participants,
      senderId,
      senderName,
    );

    final message = GrowthChatMessage(
      id: _generateId('msg'),
      threadId: thread.id,
      senderId: senderId,
      senderName: senderName,
      type: GrowthChatMessageType.voice,
      content: (caption ?? '').trim(),
      imagePath: null,
      voicePath: stored.path,
      voiceDurationMillis: duration.inMilliseconds,
      timestamp: DateTime.now(),
    );

    final updatedMessages = List<GrowthChatMessage>.from(thread.messages)
      ..add(message);

    final updated = thread.copyWith(
      messages: updatedMessages,
      participants: updatedParticipants,
      updatedAt: message.timestamp,
    );

    final idx = _threads.indexOf(thread);
    _threads[idx] = updated;
    await _persist();
    await _updateReadMark(senderId, thread.id, message.timestamp);
    notifyListeners();
  }

  Future<File?> _storeImage(File source) async {
    try {
      if (kIsWeb) {
        return source;
      }
      final supportDir = await getApplicationSupportDirectory();
      final chatDir = Directory(
        '${supportDir.path}${Platform.pathSeparator}growth_chat_media',
      );
      if (!await chatDir.exists()) {
        await chatDir.create(recursive: true);
      }
      final name = source.path.split(Platform.pathSeparator).last;
      final storedPath =
          '${chatDir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_$name';
      final storedFile = File(storedPath);
      await storedFile.writeAsBytes(await source.readAsBytes());
      return storedFile;
    } catch (_) {
      return null;
    }
  }

  Future<File?> _storeVoice(File source) async {
    try {
      if (kIsWeb) {
        return source;
      }
      final supportDir = await getApplicationSupportDirectory();
      final voiceDir = Directory(
        '${supportDir.path}${Platform.pathSeparator}growth_chat_voice',
      );
      if (!await voiceDir.exists()) {
        await voiceDir.create(recursive: true);
      }
      final name = source.path.split(Platform.pathSeparator).last;
      final storedPath =
          '${voiceDir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_$name';
      final storedFile = File(storedPath);
      await storedFile.writeAsBytes(await source.readAsBytes());
      return storedFile;
    } catch (_) {
      return null;
    }
  }

  Future<void> logCall({
    required String threadId,
    required String initiatorId,
    required String initiatorName,
    required GrowthChatCallType type,
    String? notes,
  }) async {
    var thread = _ensureThreadCurrent(threadId);
    if (thread == null) {
      return;
    }

    final record = GrowthChatCallRecord(
      id: _generateId('call'),
      threadId: threadId,
      initiatorId: initiatorId,
      initiatorName: initiatorName,
      type: type,
      timestamp: DateTime.now(),
      notes: notes,
    );

    final updatedCalls = List<GrowthChatCallRecord>.from(thread.callHistory)
      ..add(record);

    final updated = thread.copyWith(
      callHistory: updatedCalls,
      updatedAt: record.timestamp,
    );

    final idx = _threads.indexOf(thread);
    _threads[idx] = updated;
    await _persist();
    notifyListeners();
  }

  Future<bool> deleteMessage({
    required String threadId,
    required String messageId,
    required String requestorId,
  }) async {
    if (threadId.isEmpty || messageId.isEmpty || requestorId.isEmpty) {
      return false;
    }

    var thread = _ensureThreadCurrent(threadId);
    if (thread == null) {
      return false;
    }

    final messageIndex =
        thread.messages.indexWhere((message) => message.id == messageId);
    if (messageIndex == -1) {
      return false;
    }

    GrowthChatParticipant? requestor;
    for (final participant in thread.participants) {
      if (participant.userId == requestorId) {
        requestor = participant;
        break;
      }
    }

    final message = thread.messages[messageIndex];
    final isAdmin = requestor?.isAdmin ?? false;
    final isSender = message.senderId == requestorId;
    if (!isAdmin && !isSender) {
      return false;
    }

    if (message.deletedAt != null) {
      return true;
    }

    final deletionTime = DateTime.now();
    final updatedMessages = List<GrowthChatMessage>.from(thread.messages)
      ..[messageIndex] = message.copyWith(deletedAt: deletionTime);

    final idx = _threads.indexOf(thread);
    _threads[idx] = thread.copyWith(
      messages: updatedMessages,
      updatedAt: deletionTime,
    );

    _runMaintenanceSweep();
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> setUserGroupPermission(String userId, bool allowed) async {
    if (userId.isEmpty) {
      return;
    }
    await load();
    if (allowed) {
      _groupCreators.add(userId);
    } else {
      _groupCreators.remove(userId);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> markThreadRead({
    required String userId,
    required String threadId,
  }) async {
    if (userId.isEmpty || threadId.isEmpty) {
      return;
    }
    await load();
    final userReads =
        _readMarks.putIfAbsent(userId, () => <String, DateTime>{});
    userReads[threadId] = DateTime.now();
    await _persistReads();
    notifyListeners();
  }

  int unreadCountForThread(String userId, String threadId) {
    if (userId.isEmpty || threadId.isEmpty) {
      return 0;
    }
    final thread = findThread(threadId);
    if (thread is GrowthChatThread) {
      return _unreadCountForThread(thread, userId);
    }
    return 0;
  }

  int totalUnreadForScope(String userId, GrowthChatScope scope) {
    if (userId.isEmpty) {
      return 0;
    }
    final relevant = threadsForUser(userId, scope);
    var total = 0;
    for (final thread in relevant) {
      total += _unreadCountForThread(thread, userId);
    }
    return total;
  }

  Future<GrowthChatThread> ensureBroadcastThread({
    required GrowthChatScope scope,
    required String adminId,
    required String adminName,
  }) async {
    await load();
    final existing = _threads.where(
      (thread) => thread.scope == scope && thread.isBroadcast,
    );
    if (existing.isNotEmpty) {
      final thread = existing.first;
      final participants = _participantsWithSender(
        thread.participants,
        adminId,
        adminName,
        isAdmin: true,
      );
      final idx = _threads.indexOf(thread);
      _threads[idx] = thread.copyWith(
        participants: participants,
        updatedAt: DateTime.now(),
      );
      await _persist();
      notifyListeners();
      return _threads[idx];
    }

    final now = DateTime.now();
  final title = scope.broadcastTitle;
    final adminParticipant = GrowthChatParticipant(
      userId: adminId,
      displayName: adminName,
      isAdmin: true,
      canCreateGroups: true,
    );

    final broadcast = GrowthChatThread(
      id: _generateId('thread'),
      scope: scope,
      isGroup: true,
      isBroadcast: true,
      title: title,
      createdBy: adminId,
      createdAt: now,
      updatedAt: now,
      participants: <GrowthChatParticipant>[adminParticipant],
      messages: <GrowthChatMessage>[],
      callHistory: <GrowthChatCallRecord>[],
      lockedUntil: null,
    );

    _threads.add(broadcast);
    await _persist();
    notifyListeners();
    return broadcast;
  }

  String _generateId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(0xFFFFFF);
    return '$prefix-$timestamp-$rand';
  }

  List<GrowthChatParticipant> _participantsWithSender(
    List<GrowthChatParticipant> current,
    String senderId,
    String senderName, {
    bool isAdmin = false,
  }) {
    if (senderId.isEmpty) {
      return current;
    }
    final exists = current.any((p) => p.userId == senderId);
    if (exists) {
      return current;
    }
    final updated = List<GrowthChatParticipant>.from(current)
      ..add(
        GrowthChatParticipant(
          userId: senderId,
          displayName: senderName,
          isAdmin: isAdmin,
          canCreateGroups: canUserCreateGroup(senderId),
        ),
      );
    return updated;
  }

  Future<void> _updateReadMark(
    String userId,
    String threadId,
    DateTime timestamp,
  ) async {
    if (userId.isEmpty || threadId.isEmpty) {
      return;
    }
    final userReads =
        _readMarks.putIfAbsent(userId, () => <String, DateTime>{});
    final existing = userReads[threadId];
    if (existing != null && !timestamp.isAfter(existing)) {
      return;
    }
    userReads[threadId] = timestamp;
    await _persistReads();
  }

  int _unreadCountForThread(GrowthChatThread thread, String userId) {
    final readAt = _readMarks[userId]?[thread.id];
    final messages = thread.messages
        .where((message) => message.deletedAt == null)
        .toList(growable: false);
    if (messages.isEmpty) {
      return 0;
    }
    if (readAt == null) {
      return messages.where((msg) => msg.senderId != userId).length;
    }
    return messages
        .where(
          (msg) => msg.senderId != userId && msg.timestamp.isAfter(readAt),
        )
        .length;
  }

  GrowthChatThread _visibleThreadSnapshot(GrowthChatThread thread) {
    final now = DateTime.now();
    final normalized = _normalizeLockState(thread, now) ?? thread;
    final filtered = _visibleMessages(normalized.messages);
    if (filtered.length == normalized.messages.length) {
      return normalized;
    }
    return normalized.copyWith(messages: filtered);
  }

  List<GrowthChatMessage> _visibleMessages(
    List<GrowthChatMessage> messages,
  ) {
    if (messages.isEmpty) {
      return const <GrowthChatMessage>[];
    }
    return messages
        .where((message) => message.deletedAt == null)
        .toList(growable: false);
  }

  GrowthChatThread? _ensureThreadCurrent(String threadId) {
    final thread = findThread(threadId);
    if (thread == null) {
      return null;
    }
    var updated = thread;
    var mutated = false;
    final now = DateTime.now();

    final normalized = _normalizeLockState(updated, now);
    if (normalized != null) {
      updated = normalized;
      mutated = true;
    }

    if (updated.messages.isNotEmpty) {
      final cutoff = now.subtract(_deletedRetention);
      final filtered = updated.messages.where((message) {
        final deletedAt = message.deletedAt;
        if (deletedAt == null) {
          return true;
        }
        return deletedAt.isAfter(cutoff);
      }).toList(growable: false);
      if (filtered.length != updated.messages.length) {
        updated = updated.copyWith(messages: filtered);
        mutated = true;
      }
    }

    if (mutated) {
      final idx = _threads.indexOf(thread);
      _threads[idx] = updated;
    }

    return updated;
  }

  bool _threadIsLocked(GrowthChatThread thread) {
    final until = thread.lockedUntil;
    if (until != null) {
      return until.isAfter(DateTime.now());
    }
    return thread.isLocked;
  }

  GrowthChatThread? _normalizeLockState(
    GrowthChatThread thread,
    DateTime now,
  ) {
    final until = thread.lockedUntil;
    if (until == null) {
      return null;
    }
    if (until.isAfter(now)) {
      if (thread.isLocked) {
        return null;
      }
      return thread.copyWith(isLocked: true);
    }
    if (!thread.isLocked && thread.lockedUntil == null) {
      return null;
    }
    return thread.copyWith(isLocked: false, lockedUntil: null);
  }

  bool _runMaintenanceSweep() {
    final now = DateTime.now();
    final cutoff = now.subtract(_deletedRetention);
    var changed = false;
    for (var i = 0; i < _threads.length; i++) {
      final thread = _threads[i];
      var updated = thread;
      var mutated = false;

      final normalized = _normalizeLockState(updated, now);
      if (normalized != null) {
        updated = normalized;
        mutated = true;
      }

      if (updated.messages.isNotEmpty) {
        final filtered = updated.messages.where((message) {
          final deletedAt = message.deletedAt;
          if (deletedAt == null) {
            return true;
          }
          return deletedAt.isAfter(cutoff);
        }).toList(growable: false);
        if (filtered.length != updated.messages.length) {
          updated = updated.copyWith(messages: filtered);
          mutated = true;
        }
      }

      if (mutated) {
        _threads[i] = updated;
        changed = true;
      }
    }
    return changed;
  }
}
