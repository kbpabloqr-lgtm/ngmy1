import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Enhanced authentication service that uses Firebase Auth instead of local storage
/// This ensures data persists across devices when users login with the same email
class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();

  factory FirebaseAuthService() {
    return _instance;
  }

  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;
  String? get currentUserId => _auth.currentUser?.uid;
  String? get currentEmail => _auth.currentUser?.email;

  /// Register a new user with email and password
  /// Also saves user profile to Firestore and Realtime Database
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Registering user: $email');

      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Save user profile to Firestore (primary database)
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Also save to Realtime Database for real-time sync
      await _realtimeDb.ref('users/$uid/profile').set({
        'uid': uid,
        'email': email,
        'name': name,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'isActive': true,
      });

      // Save to local storage for offline access
      await _saveLocalUser(uid, email, name);

      debugPrint('✅ User registered successfully: $uid');
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Registration error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected registration error: $e');
      return false;
    }
  }

  /// Login user with email and password
  /// Pulls all user data from Firebase to local storage
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Logging in user: $email');

      // Authenticate with Firebase
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Pull user profile from Firestore
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        debugPrint('⚠️ User profile not found in Firestore');
        return false;
      }

      final userData = userDoc.data()!;
      final name = userData['name'] as String? ?? email.split('@')[0];

      // Save to local storage for offline access
      await _saveLocalUser(uid, email, name);

      debugPrint('✅ User logged in successfully: $uid');
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Login error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected login error: $e');
      return false;
    }
  }

  /// Logout current user
  Future<void> logout() async {
    try {
      await _auth.signOut();
      await _clearLocalUser();
      debugPrint('✅ User logged out');
    } catch (e) {
      debugPrint('❌ Logout error: $e');
    }
  }

  /// Save user data locally for offline access and quick retrieval
  Future<void> _saveLocalUser(String uid, String email, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = {
        'uid': uid,
        'email': email,
        'name': name,
        'loginTime': DateTime.now().toIso8601String(),
      };
      await prefs.setString('_firebase_user', jsonEncode(userData));
      debugPrint('💾 Local user saved: $uid');
    } catch (e) {
      debugPrint('⚠️ Failed to save local user: $e');
    }
  }

  /// Clear local user data on logout
  Future<void> _clearLocalUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('_firebase_user');
      debugPrint('🗑️ Local user cleared');
    } catch (e) {
      debugPrint('⚠️ Failed to clear local user: $e');
    }
  }

  /// Get locally cached user data (for offline mode)
  Future<Map<String, dynamic>?> getLocalUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('_firebase_user');
      if (userJson != null) {
        return jsonDecode(userJson) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load local user: $e');
    }
    return null;
  }

  /// Save user profile data to both Firestore and Realtime Database
  Future<bool> updateUserProfile({
    required String userId,
    required String name,
    String? bio,
    String? profileImageUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      debugPrint('📝 Updating user profile: $userId');

      final timestamp = FieldValue.serverTimestamp();
      final updateData = {
        'name': name,
        'bio': bio,
        'profileImageUrl': profileImageUrl,
        'updatedAt': timestamp,
        ...?additionalData,
      };

      // Update in Firestore (primary)
      await _firestore.collection('users').doc(userId).update(updateData);

      // Update in Realtime Database (sync)
      await _realtimeDb.ref('users/$userId/profile').update({
        'name': name,
        'bio': bio,
        'profileImageUrl': profileImageUrl,
        'updatedAt': DateTime.now().toIso8601String(),
        ...?additionalData,
      });

      debugPrint('✅ User profile updated: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Profile update error: $e');
      return false;
    }
  }

  /// Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      debugPrint('❌ Failed to get user profile: $e');
      return null;
    }
  }

  /// Stream user profile changes in real-time
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserProfile(
      String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  /// Get all user data (profile, media, stats, notifications, money)
  Future<Map<String, dynamic>?> getAllUserData(String userId) async {
    try {
      debugPrint('📥 Pulling all user data: $userId');

      final profile = await getUserProfile(userId);

      // Get media from Realtime Database
      final mediaSnapshot = await _realtimeDb.ref('users/$userId/media').get();
      final media = mediaSnapshot.value as Map<dynamic, dynamic>? ?? {};

      // Get stats from Realtime Database
      final statsSnapshot = await _realtimeDb.ref('users/$userId/stats').get();
      final stats = statsSnapshot.value as Map<dynamic, dynamic>? ?? {};

      // Get notifications from Realtime Database
      final notificationsSnapshot =
          await _realtimeDb.ref('users/$userId/notifications').get();
      final notifications =
          notificationsSnapshot.value as Map<dynamic, dynamic>? ?? {};

      // Get money/betting data from Realtime Database
      final moneySnapshot = await _realtimeDb.ref('users/$userId/money').get();
      final money = moneySnapshot.value as Map<dynamic, dynamic>? ?? {};

      // Get family tree data from Realtime Database
      final familyTreeSnapshot =
          await _realtimeDb.ref('users/$userId/familyTree').get();
      final familyTree =
          familyTreeSnapshot.value as Map<dynamic, dynamic>? ?? {};

      final allData = {
        'uid': userId,
        'profile': profile,
        'media': media,
        'stats': stats,
        'notifications': notifications,
        'money': money,
        'familyTree': familyTree,
        'pulledAt': DateTime.now().toIso8601String(),
      };

      debugPrint('✅ All user data pulled: ${allData.length} sections');
      return allData;
    } catch (e) {
      debugPrint('❌ Failed to get all user data: $e');
      return null;
    }
  }

  /// Stream all user data in real-time
  Stream<Map<String, dynamic>> streamAllUserData(String userId) {
    return _realtimeDb.ref('users/$userId').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is Map<dynamic, dynamic>) {
        return Map<String, dynamic>.from(value);
      }
      return {};
    });
  }

  /// Initialize auth state listener
  /// This runs when app starts to check if user is already logged in
  Future<void> initializeAuthState() async {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        debugPrint('🔐 User is authenticated: ${user.email} (${user.uid})');
      } else {
        debugPrint('🔐 User is not authenticated');
      }
    });
  }
}
