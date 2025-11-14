import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service that syncs all local data (messages, notifications, money, media) to Firebase
/// This ensures data is never lost and can be accessed from any device
class DataSyncService {
  static final DataSyncService _instance = DataSyncService._internal();

  factory DataSyncService() {
    return _instance;
  }

  DataSyncService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _syncEnabled = true;

  /// Sync notifications to Firebase
  /// Call this whenever a notification is sent
  Future<void> syncNotificationToFirebase({
    required String notificationId,
    required String title,
    required String message,
    required String timestamp,
    String? targetUserId,
    Map<String, dynamic>? extraData,
  }) async {
    if (!_syncEnabled || _auth.currentUser == null) {
      debugPrint('⚠️ Sync disabled or not authenticated');
      return;
    }

    try {
      final userId = _auth.currentUser!.uid;
      debugPrint('📤 Syncing notification to Firebase: $notificationId');

      // Save to admin notifications
      await _db.ref('users/$userId/notifications/$notificationId').set({
        'id': notificationId,
        'title': title,
        'message': message,
        'timestamp': timestamp,
        'read': false,
        'targetUserId': targetUserId,
        ...?extraData,
      });

      // If this is a targeted notification, also save to target user's inbox
      if (targetUserId != null && targetUserId.isNotEmpty) {
        await _db
            .ref('users/$targetUserId/notifications/$notificationId')
            .set({
          'id': notificationId,
          'title': title,
          'message': message,
          'timestamp': timestamp,
          'read': false,
          'fromAdmin': true,
          ...?extraData,
        });
      }

      debugPrint('✅ Notification synced to Firebase');
    } catch (e) {
      debugPrint('❌ Error syncing notification: $e');
    }
  }

  /// Sync wallet/money transaction to Firebase
  /// Call this whenever money is added/removed or a transaction occurs
  Future<void> syncMoneyTransaction({
    required String transactionId,
    required String type, // 'credit', 'debit', 'bet', 'win'
    required double amount,
    required String description,
    required String timestamp,
    Map<String, dynamic>? extraData,
  }) async {
    if (!_syncEnabled || _auth.currentUser == null) {
      debugPrint('⚠️ Sync disabled or not authenticated');
      return;
    }

    try {
      final userId = _auth.currentUser!.uid;
      debugPrint('💰 Syncing money transaction to Firebase: $transactionId');

      await _db.ref('users/$userId/money/transactions/$transactionId').set({
        'transactionId': transactionId,
        'type': type,
        'amount': amount,
        'description': description,
        'timestamp': timestamp,
        ...?extraData,
      });

      debugPrint('✅ Money transaction synced to Firebase');
    } catch (e) {
      debugPrint('❌ Error syncing money transaction: $e');
    }
  }

  /// Sync current wallet balance to Firebase
  Future<void> syncWalletBalance(double balance, {String? currency}) async {
    if (!_syncEnabled || _auth.currentUser == null) {
      debugPrint('⚠️ Sync disabled or not authenticated');
      return;
    }

    try {
      final userId = _auth.currentUser!.uid;
      debugPrint('💰 Syncing wallet balance to Firebase: $balance');

      await _db.ref('users/$userId/money/balance').set({
        'amount': balance,
        'currency': currency ?? 'USD',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Wallet balance synced to Firebase');
    } catch (e) {
      debugPrint('❌ Error syncing wallet balance: $e');
    }
  }

  /// Sync media URL to Firebase (after Cloudinary upload)
  Future<void> syncMediaToFirebase({
    required String mediaId,
    required String mediaUrl,
    required String mediaType, // 'image', 'video', 'audio', 'document'
    String? caption,
    String? fileName,
  }) async {
    if (!_syncEnabled || _auth.currentUser == null) {
      debugPrint('⚠️ Sync disabled or not authenticated');
      return;
    }

    try {
      final userId = _auth.currentUser!.uid;
      debugPrint('🖼️ Syncing media to Firebase: $mediaId');

      await _db.ref('users/$userId/media/$mediaId').set({
        'mediaId': mediaId,
        'url': mediaUrl,
        'type': mediaType,
        'caption': caption,
        'fileName': fileName,
        'uploadedAt': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Media synced to Firebase');
    } catch (e) {
      debugPrint('❌ Error syncing media: $e');
    }
  }

  /// Sync profile update to Firebase
  Future<void> syncProfileToFirebase({
    required String name,
    String? bio,
    String? profileImageUrl,
    Map<String, dynamic>? additionalFields,
  }) async {
    if (!_syncEnabled || _auth.currentUser == null) {
      debugPrint('⚠️ Sync disabled or not authenticated');
      return;
    }

    try {
      final userId = _auth.currentUser!.uid;
      debugPrint('👤 Syncing profile to Firebase');

      await _db.ref('users/$userId/profile').update({
        'name': name,
        'bio': bio,
        'profileImageUrl': profileImageUrl,
        'updatedAt': DateTime.now().toIso8601String(),
        ...?additionalFields,
      });

      debugPrint('✅ Profile synced to Firebase');
    } catch (e) {
      debugPrint('❌ Error syncing profile: $e');
    }
  }

  /// Sync family tree check-in/earnings to Firebase
  Future<void> syncFamilyTreeData({
    required String type, // 'checkin', 'earning', 'penalty'
    required Map<String, dynamic> data,
  }) async {
    if (!_syncEnabled || _auth.currentUser == null) {
      debugPrint('⚠️ Sync disabled or not authenticated');
      return;
    }

    try {
      final userId = _auth.currentUser!.uid;
      final entryId = DateTime.now().millisecondsSinceEpoch.toString();
      debugPrint('🌳 Syncing family tree data to Firebase: $type');

      await _db
          .ref('users/$userId/familyTree/$type/$entryId')
          .set({...data, 'timestamp': DateTime.now().toIso8601String()});

      debugPrint('✅ Family tree data synced to Firebase');
    } catch (e) {
      debugPrint('❌ Error syncing family tree data: $e');
    }
  }

  /// Sync store/wheel spin results to Firebase
  Future<void> syncStoreWinToFirebase({
    required String winId,
    required String itemWon, // or money amount
    required String segmentLabel,
    required String timestamp,
    Map<String, dynamic>? extraData,
  }) async {
    if (!_syncEnabled || _auth.currentUser == null) {
      debugPrint('⚠️ Sync disabled or not authenticated');
      return;
    }

    try {
      final userId = _auth.currentUser!.uid;
      debugPrint('🎡 Syncing store win to Firebase: $winId');

      await _db.ref('users/$userId/store/wins/$winId').set({
        'winId': winId,
        'itemWon': itemWon,
        'segmentLabel': segmentLabel,
        'timestamp': timestamp,
        ...?extraData,
      });

      debugPrint('✅ Store win synced to Firebase');
    } catch (e) {
      debugPrint('❌ Error syncing store win: $e');
    }
  }

  /// Sync betting/gaming transaction to Firebase
  Future<void> syncBettingTransactionToFirebase({
    required String transactionId,
    required String gameType,
    required double betAmount,
    required double? winAmount,
    required String result, // 'win', 'loss', 'pending'
    required String timestamp,
    Map<String, dynamic>? extraData,
  }) async {
    if (!_syncEnabled || _auth.currentUser == null) {
      debugPrint('⚠️ Sync disabled or not authenticated');
      return;
    }

    try {
      final userId = _auth.currentUser!.uid;
      debugPrint('🎲 Syncing betting transaction to Firebase: $transactionId');

      await _db.ref('users/$userId/betting/transactions/$transactionId').set({
        'transactionId': transactionId,
        'gameType': gameType,
        'betAmount': betAmount,
        'winAmount': winAmount,
        'result': result,
        'timestamp': timestamp,
        ...?extraData,
      });

      debugPrint('✅ Betting transaction synced to Firebase');
    } catch (e) {
      debugPrint('❌ Error syncing betting transaction: $e');
    }
  }

  /// Batch sync everything for offline recovery
  /// Use this when app reconnects to sync all pending local changes
  Future<void> batchSyncLocalDataToFirebase({
    required Map<String, dynamic> localData,
  }) async {
    if (!_syncEnabled || _auth.currentUser == null) {
      debugPrint('⚠️ Sync disabled or not authenticated');
      return;
    }

    try {
      final userId = _auth.currentUser!.uid;
      debugPrint('📦 Batch syncing all local data to Firebase...');

      // Sync each section
      if (localData.containsKey('profile')) {
        await _db
            .ref('users/$userId/profile')
            .set(localData['profile']);
      }

      if (localData.containsKey('media')) {
        await _db.ref('users/$userId/media').set(localData['media']);
      }

      if (localData.containsKey('notifications')) {
        await _db
            .ref('users/$userId/notifications')
            .set(localData['notifications']);
      }

      if (localData.containsKey('money')) {
        await _db.ref('users/$userId/money').set(localData['money']);
      }

      if (localData.containsKey('familyTree')) {
        await _db
            .ref('users/$userId/familyTree')
            .set(localData['familyTree']);
      }

      if (localData.containsKey('store')) {
        await _db.ref('users/$userId/store').set(localData['store']);
      }

      if (localData.containsKey('betting')) {
        await _db.ref('users/$userId/betting').set(localData['betting']);
      }

      debugPrint('✅ Batch sync completed - all data synced to Firebase');
    } catch (e) {
      debugPrint('❌ Error during batch sync: $e');
    }
  }

  /// Enable/disable syncing (useful for testing or offline mode)
  void setSyncEnabled(bool enabled) {
    _syncEnabled = enabled;
    debugPrint(_syncEnabled ? '✅ Sync enabled' : '⛔ Sync disabled');
  }

  bool get isSyncEnabled => _syncEnabled;
}
