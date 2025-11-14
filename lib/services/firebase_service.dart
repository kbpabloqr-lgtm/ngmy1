import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

/// Central Firebase service for all Firebase operations
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  late FirebaseAuth _auth;
  late FirebaseFirestore _firestore;
  late FirebaseStorage _storage;
  late FirebaseMessaging _messaging;

  bool _initialized = false;

  // Getters for Firebase instances
  FirebaseAuth get auth => _auth;
  FirebaseFirestore get firestore => _firestore;
  FirebaseStorage get storage => _storage;
  FirebaseMessaging get messaging => _messaging;
  bool get initialized => _initialized;

  /// Initialize Firebase with platform-specific configuration
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('🔥 Firebase already initialized');
      return;
    }

    try {
      debugPrint('🔥 Initializing Firebase...');

      // For Android, google-services.json handles the configuration
      // For other platforms, use DefaultFirebaseOptions
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android uses google-services.json - no need to pass options
        await Firebase.initializeApp();
        debugPrint('✅ Firebase initialized from google-services.json (Android)');
      } else {
        // iOS, macOS, Windows, Web use DefaultFirebaseOptions
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('✅ Firebase initialized from DefaultFirebaseOptions');
      }

      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _storage = FirebaseStorage.instance;
      _messaging = FirebaseMessaging.instance;

      debugPrint('✅ Firebase services initialized');

      // Request notification permission
      await _requestNotificationPermission();

      _initialized = true;
      debugPrint('✅ Firebase fully initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Firebase initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      _initialized = false;
      // Don't rethrow - let app continue even if Firebase fails
    }
  }

  /// Request user notification permission
  Future<void> _requestNotificationPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        provisional: false,
        sound: true,
      );

      debugPrint('🔔 Notification permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('⚠️ Error requesting notification permission: $e');
    }
  }

  /// Get Firebase Authentication token
  Future<String?> getAuthToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      return await user.getIdToken(true);
    } catch (e) {
      debugPrint('❌ Error getting auth token: $e');
      return null;
    }
  }

  /// Sign out from Firebase
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('✅ Signed out from Firebase');
    } catch (e) {
      debugPrint('❌ Error signing out: $e');
    }
  }

  /// Upload file to Firebase Storage
  Future<String?> uploadFile({
    required String filePath,
    required String storagePath,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ File not found: $filePath');
        return null;
      }

      debugPrint('📤 Uploading to Firebase Storage: $storagePath');

      final task = _storage.ref(storagePath).putFile(file);
      final snapshot = await task;
      final url = await snapshot.ref.getDownloadURL();

      debugPrint('✅ File uploaded: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return null;
    }
  }

  /// Save user data to Firestore
  Future<bool> saveUserData({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      debugPrint('💾 Saving user data to Firestore: $userId');

      await _firestore.collection('users').doc(userId).set(
        data,
        SetOptions(merge: true),
      );

      debugPrint('✅ User data saved');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving user data: $e');
      return false;
    }
  }

  /// Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      debugPrint('❌ Error getting user data: $e');
      return null;
    }
  }

  /// Create a new document in a collection
  Future<String?> createDocument({
    required String collection,
    required Map<String, dynamic> data,
    String? documentId,
  }) async {
    try {
      late DocumentReference<Map<String, dynamic>> ref;

      if (documentId != null) {
        ref = _firestore.collection(collection).doc(documentId);
        await ref.set(data);
      } else {
        ref = await _firestore.collection(collection).add(data);
      }

      debugPrint('✅ Document created: ${ref.id}');
      return ref.id;
    } catch (e) {
      debugPrint('❌ Error creating document: $e');
      return null;
    }
  }

  /// Get a document from Firestore
  Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      final doc = await _firestore.collection(collection).doc(documentId).get();
      return doc.data();
    } catch (e) {
      debugPrint('❌ Error getting document: $e');
      return null;
    }
  }

  /// Query documents from Firestore
  Future<List<Map<String, dynamic>>> queryDocuments({
    required String collection,
    String? whereField,
    dynamic whereValue,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _firestore.collection(collection);

      if (whereField != null && whereValue != null) {
        query = query.where(whereField, isEqualTo: whereValue);
      }

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Error querying documents: $e');
      return [];
    }
  }

  /// Delete a document from Firestore
  Future<bool> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).delete();
      debugPrint('✅ Document deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting document: $e');
      return false;
    }
  }

  /// Update a document in Firestore
  Future<bool> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).update(data);
      debugPrint('✅ Document updated');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating document: $e');
      return false;
    }
  }

  /// Get FCM token for push notifications
  Future<String?> getFCMToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('🔔 FCM Token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Listen to Firebase Authentication state changes
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Listen to user data changes in real-time
  Stream<DocumentSnapshot<Map<String, dynamic>>> userDataStream(
      String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }
}
