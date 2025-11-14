import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloudinary_service.dart';

/// Manages media uploads and storage of Cloudinary URLs
class MediaUploadManager {
  static final MediaUploadManager _instance = MediaUploadManager._internal();

  factory MediaUploadManager() {
    return _instance;
  }

  MediaUploadManager._internal();

  final CloudinaryService _cloudinary = CloudinaryService();

  /// Upload and store image with URL caching
  Future<String?> uploadAndStoreImage({
    required File imageFile,
    required String username,
    String? mediaId,
    String? folder = 'ngmy_user_images',
  }) async {
    try {
      debugPrint('📸 Uploading image for user: $username');

      // Upload to Cloudinary
      final String? cloudinaryUrl = await _cloudinary.uploadImage(
        imageFile: imageFile,
        publicId: mediaId,
        folder: folder,
      );

      if (cloudinaryUrl == null) {
        debugPrint('❌ Cloudinary upload failed');
        return null;
      }

      // Store URL in SharedPreferences
      await _storeMediaUrl(
        username: username,
        mediaId: mediaId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        url: cloudinaryUrl,
        type: 'image',
      );

      debugPrint('✅ Image uploaded and stored: $cloudinaryUrl');
      return cloudinaryUrl;
    } catch (e) {
      debugPrint('❌ Error uploading image: $e');
      return null;
    }
  }

  /// Upload and store video with URL caching
  Future<String?> uploadAndStoreVideo({
    required File videoFile,
    required String username,
    String? mediaId,
    String? folder = 'ngmy_user_videos',
  }) async {
    try {
      debugPrint('🎥 Uploading video for user: $username');

      final String? cloudinaryUrl = await _cloudinary.uploadVideo(
        videoFile: videoFile,
        publicId: mediaId,
        folder: folder,
      );

      if (cloudinaryUrl == null) {
        debugPrint('❌ Cloudinary upload failed');
        return null;
      }

      await _storeMediaUrl(
        username: username,
        mediaId: mediaId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        url: cloudinaryUrl,
        type: 'video',
      );

      debugPrint('✅ Video uploaded and stored: $cloudinaryUrl');
      return cloudinaryUrl;
    } catch (e) {
      debugPrint('❌ Error uploading video: $e');
      return null;
    }
  }

  /// Upload and store audio with URL caching
  Future<String?> uploadAndStoreAudio({
    required File audioFile,
    required String username,
    String? mediaId,
    String? folder = 'ngmy_user_audio',
  }) async {
    try {
      debugPrint('🎵 Uploading audio for user: $username');

      final String? cloudinaryUrl = await _cloudinary.uploadAudio(
        audioFile: audioFile,
        publicId: mediaId,
        folder: folder,
      );

      if (cloudinaryUrl == null) {
        debugPrint('❌ Cloudinary upload failed');
        return null;
      }

      await _storeMediaUrl(
        username: username,
        mediaId: mediaId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        url: cloudinaryUrl,
        type: 'audio',
      );

      debugPrint('✅ Audio uploaded and stored: $cloudinaryUrl');
      return cloudinaryUrl;
    } catch (e) {
      debugPrint('❌ Error uploading audio: $e');
      return null;
    }
  }

  /// Upload and store document with URL caching
  Future<String?> uploadAndStoreDocument({
    required File documentFile,
    required String username,
    String? mediaId,
    String? folder = 'ngmy_user_documents',
  }) async {
    try {
      debugPrint('📄 Uploading document for user: $username');

      final String? cloudinaryUrl = await _cloudinary.uploadDocument(
        documentFile: documentFile,
        publicId: mediaId,
        folder: folder,
      );

      if (cloudinaryUrl == null) {
        debugPrint('❌ Cloudinary upload failed');
        return null;
      }

      await _storeMediaUrl(
        username: username,
        mediaId: mediaId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        url: cloudinaryUrl,
        type: 'document',
      );

      debugPrint('✅ Document uploaded and stored: $cloudinaryUrl');
      return cloudinaryUrl;
    } catch (e) {
      debugPrint('❌ Error uploading document: $e');
      return null;
    }
  }

  /// Store media URL in SharedPreferences
  Future<void> _storeMediaUrl({
    required String username,
    required String mediaId,
    required String url,
    required String type,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${username}_media_library';

      // Get existing media library
      final rawLibrary = prefs.getString(key);
      final Map<String, dynamic> library = rawLibrary != null
          ? jsonDecode(rawLibrary) as Map<String, dynamic>
          : <String, dynamic>{};

      // Add new media entry
      library[mediaId] = {
        'url': url,
        'type': type,
        'uploadedAt': DateTime.now().toIso8601String(),
      };

      // Save back to SharedPreferences
      await prefs.setString(key, jsonEncode(library));

      debugPrint('💾 Media URL stored: $mediaId');
    } catch (e) {
      debugPrint('❌ Error storing media URL: $e');
    }
  }

  /// Get all media for a user
  Future<Map<String, dynamic>> getUserMedia(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${username}_media_library';

      final rawLibrary = prefs.getString(key);
      if (rawLibrary == null) {
        return <String, dynamic>{};
      }

      return jsonDecode(rawLibrary) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Error retrieving media: $e');
      return <String, dynamic>{};
    }
  }

  /// Get specific media by type
  Future<List<Map<String, dynamic>>> getMediaByType(
    String username,
    String type,
  ) async {
    try {
      final allMedia = await getUserMedia(username);
      final List<Map<String, dynamic>> filtered = [];

      allMedia.forEach((id, data) {
        if (data['type'] == type) {
          filtered.add({
            'id': id,
            ...data as Map<String, dynamic>,
          });
        }
      });

      return filtered;
    } catch (e) {
      debugPrint('❌ Error filtering media: $e');
      return [];
    }
  }

  /// Delete media from library
  Future<bool> deleteMedia(String username, String mediaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${username}_media_library';

      final rawLibrary = prefs.getString(key);
      if (rawLibrary == null) {
        return false;
      }

      final Map<String, dynamic> library =
          jsonDecode(rawLibrary) as Map<String, dynamic>;

      if (library.containsKey(mediaId)) {
        library.remove(mediaId);
        await prefs.setString(key, jsonEncode(library));
        debugPrint('🗑️ Media deleted: $mediaId');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error deleting media: $e');
      return false;
    }
  }

  /// Get thumbnail URL for image
  String getImageThumbnail(String publicId) {
    return CloudinaryService.getThumbnailUrl(publicId);
  }

  /// Get optimized image URL
  String getOptimizedImageUrl(
    String publicId, {
    int width = 300,
    int height = 300,
  }) {
    return CloudinaryService.getOptimizedImageUrl(
      publicId,
      width: width,
      height: height,
    );
  }

  /// Get video thumbnail
  String getVideoThumbnail(String publicId, {int seconds = 0}) {
    return CloudinaryService.getVideoThumbnailUrl(publicId, seconds: seconds);
  }
}
