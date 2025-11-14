import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

/// Service for syncing user profiles and data to Firebase Realtime Database
class RealtimeDatabaseService {
  static final RealtimeDatabaseService _instance =
      RealtimeDatabaseService._internal();

  factory RealtimeDatabaseService() {
    return _instance;
  }

  RealtimeDatabaseService._internal();

  late FirebaseDatabase _database;
  bool _initialized = false;

  FirebaseDatabase get database => _database;
  bool get initialized => _initialized;

  /// Initialize Realtime Database
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('💾 Realtime Database already initialized');
      return;
    }

    try {
      debugPrint('💾 Initializing Firebase Realtime Database...');
      _database = FirebaseDatabase.instance;
      
      // Enable offline persistence
      await _database.ref().keepSynced(true);
      
      _initialized = true;
      debugPrint('✅ Firebase Realtime Database initialized');
    } catch (e) {
      debugPrint('❌ Realtime Database initialization error: $e');
    }
  }

  /// Save user profile to Realtime Database
  Future<bool> saveUserProfile({
    required String userId,
    required String username,
    required String email,
    String? profileImageUrl,
    String? bio,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      debugPrint('💾 Saving user profile: $userId');

      final userRef = _database.ref('users/$userId');
      final profileData = {
        'userId': userId,
        'username': username,
        'email': email,
        'profileImageUrl': profileImageUrl,
        'bio': bio,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        ...?additionalData,
      };

      await userRef.set(profileData);
      debugPrint('✅ User profile saved: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving user profile: $e');
      return false;
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      debugPrint('📝 Updating user profile: $userId');

      final userRef = _database.ref('users/$userId');
      data['updatedAt'] = DateTime.now().toIso8601String();

      await userRef.update(data);
      debugPrint('✅ User profile updated');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating user profile: $e');
      return false;
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final snapshot = await _database.ref('users/$userId').get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user profile: $e');
      return null;
    }
  }

  /// Stream user profile in real-time
  Stream<Map<String, dynamic>?> streamUserProfile(String userId) {
    return _database.ref('users/$userId').onValue.map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }

  /// Save media URL to user's media collection
  Future<bool> saveMediaUrl({
    required String userId,
    required String mediaId,
    required String mediaUrl,
    required String mediaType, // 'image', 'video', 'document', 'audio'
    String? caption,
  }) async {
    try {
      debugPrint('📸 Saving media URL for user: $userId');

      final mediaRef = _database.ref('users/$userId/media/$mediaId');
      final mediaData = {
        'mediaId': mediaId,
        'url': mediaUrl,
        'type': mediaType,
        'caption': caption,
        'uploadedAt': DateTime.now().toIso8601String(),
      };

      await mediaRef.set(mediaData);
      debugPrint('✅ Media saved: $mediaId');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving media: $e');
      return false;
    }
  }

  /// Get all media for user
  Future<List<Map<String, dynamic>>> getUserMedia(String userId) async {
    try {
      final snapshot = await _database.ref('users/$userId/media').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        return data.entries.map((e) {
          return Map<String, dynamic>.from(e.value as Map)
            ..['id'] = e.key;
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error getting user media: $e');
      return [];
    }
  }

  /// Stream user media in real-time
  Stream<List<Map<String, dynamic>>> streamUserMedia(String userId) {
    return _database.ref('users/$userId/media').onValue.map((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map;
        return data.entries.map((e) {
          return Map<String, dynamic>.from(e.value as Map)
            ..['id'] = e.key;
        }).toList();
      }
      return [];
    });
  }

  /// Delete media
  Future<bool> deleteMedia({
    required String userId,
    required String mediaId,
  }) async {
    try {
      await _database.ref('users/$userId/media/$mediaId').remove();
      debugPrint('✅ Media deleted: $mediaId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting media: $e');
      return false;
    }
  }

  /// Save user statistics (earnings, sessions, etc.)
  Future<bool> saveUserStats({
    required String userId,
    required Map<String, dynamic> stats,
  }) async {
    try {
      debugPrint('📊 Saving user statistics: $userId');

      final statsRef = _database.ref('users/$userId/stats');
      stats['updatedAt'] = DateTime.now().toIso8601String();

      await statsRef.set(stats);
      debugPrint('✅ User statistics saved');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving statistics: $e');
      return false;
    }
  }

  /// Stream user statistics in real-time
  Stream<Map<String, dynamic>?> streamUserStats(String userId) {
    return _database.ref('users/$userId/stats').onValue.map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }

  /// Save notification data
  Future<bool> saveNotification({
    required String userId,
    required String title,
    required String message,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notificationRef =
          _database.ref('users/$userId/notifications').push();
      
      await notificationRef.set({
        'title': title,
        'message': message,
        'type': type ?? 'info',
        'read': false,
        'timestamp': DateTime.now().toIso8601String(),
        ...?data,
      });

      debugPrint('✅ Notification saved');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving notification: $e');
      return false;
    }
  }

  /// Stream user notifications in real-time
  Stream<List<Map<String, dynamic>>> streamUserNotifications(String userId) {
    return _database
        .ref('users/$userId/notifications')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map;
        return data.entries.map((e) {
          return Map<String, dynamic>.from(e.value as Map)
            ..['id'] = e.key;
        }).toList().reversed.toList(); // Most recent first
      }
      return [];
    });
  }

  /// Bulk sync data to Realtime Database
  /// This is useful for syncing from local storage to Firebase
  Future<bool> bulkSyncData({
    required String userId,
    required String path,
    required Map<String, dynamic> data,
  }) async {
    try {
      debugPrint('🔄 Bulk syncing data to $path');

      final ref = _database.ref('users/$userId/$path');
      await ref.set(data);

      debugPrint('✅ Bulk sync completed');
      return true;
    } catch (e) {
      debugPrint('❌ Error during bulk sync: $e');
      return false;
    }
  }

  /// Get all user data
  Future<Map<String, dynamic>?> getAllUserData(String userId) async {
    try {
      final snapshot = await _database.ref('users/$userId').get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting all user data: $e');
      return null;
    }
  }

  /// Stream all user data in real-time
  Stream<Map<String, dynamic>?> streamAllUserData(String userId) {
    return _database.ref('users/$userId').onValue.map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }
}
