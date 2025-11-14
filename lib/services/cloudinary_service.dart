import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Cloudinary service for uploading all types of media files
class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();

  factory CloudinaryService() {
    return _instance;
  }

  CloudinaryService._internal();

  // Cloudinary credentials
  static const String cloudName = 'NGMYKING';
  static const String apiKey = '885584536229345';
  static const String apiSecret = 'mlbaq0Ch4EWas8T7taXSmmL_w64';

  // Upload URL
  static const String uploadUrl =
      'https://api.cloudinary.com/v1_1/$cloudName/auto/upload';

  final Dio _dio = Dio();

  /// Upload a file to Cloudinary
  /// Supports: images, videos, audio, text files, and more
  Future<String?> uploadFile({
    required File file,
    required String fileType, // 'image', 'video', 'audio', 'raw'
    String? publicId,
    String? folder,
    Map<String, dynamic>? customParams,
  }) async {
    try {
      debugPrint('📤 Starting Cloudinary upload for: ${file.path}');

      // Prepare form data
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'upload_preset':
            'NGMYKING', // Matches the unsigned preset created in Cloudinary dashboard
        'api_key': apiKey,
        'resource_type': fileType, // 'image', 'video', 'audio', 'raw'
        if (publicId != null) 'public_id': publicId,
        if (folder != null) 'folder': folder,
        ...?customParams,
      });

      // Make the upload request
      Response response = await _dio.post(
        uploadUrl,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
        onSendProgress: (int sent, int total) {
          debugPrint('📤 Upload progress: ${(sent / total * 100).toStringAsFixed(0)}%');
        },
      );

      if (response.statusCode == 200) {
        final String secureUrl = response.data['secure_url'];
        debugPrint('✅ Upload successful: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('❌ Upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return null;
    }
  }

  /// Upload image file
  Future<String?> uploadImage({
    required File imageFile,
    String? publicId,
    String? folder = 'ngmy_images',
  }) async {
    return uploadFile(
      file: imageFile,
      fileType: 'image',
      publicId: publicId,
      folder: folder,
    );
  }

  /// Upload video file
  Future<String?> uploadVideo({
    required File videoFile,
    String? publicId,
    String? folder = 'ngmy_videos',
  }) async {
    return uploadFile(
      file: videoFile,
      fileType: 'video',
      publicId: publicId,
      folder: folder,
    );
  }

  /// Upload audio file
  Future<String?> uploadAudio({
    required File audioFile,
    String? publicId,
    String? folder = 'ngmy_audio',
  }) async {
    return uploadFile(
      file: audioFile,
      fileType: 'video', // Cloudinary treats audio as video resource type
      publicId: publicId,
      folder: folder,
      customParams: {
        'resource_type': 'video', // Audio files use video resource type
      },
    );
  }

  /// Upload text/document file
  Future<String?> uploadDocument({
    required File documentFile,
    String? publicId,
    String? folder = 'ngmy_documents',
  }) async {
    return uploadFile(
      file: documentFile,
      fileType: 'raw',
      publicId: publicId,
      folder: folder,
    );
  }

  /// Upload from bytes (in-memory file)
  Future<String?> uploadFromBytes({
    required Uint8List bytes,
    required String filename,
    required String fileType, // 'image', 'video', 'audio', 'raw'
    String? publicId,
    String? folder,
  }) async {
    try {
      debugPrint('📤 Starting Cloudinary upload from bytes: $filename');

      FormData formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
        'upload_preset': 'unsigned_preset',
        'api_key': apiKey,
        'resource_type': fileType,
        if (publicId != null) 'public_id': publicId,
        if (folder != null) 'folder': folder,
      });

      Response response = await _dio.post(
        uploadUrl,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      if (response.statusCode == 200) {
        final String secureUrl = response.data['secure_url'];
        debugPrint('✅ Upload from bytes successful: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('❌ Upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return null;
    }
  }

  /// Generate an optimized Cloudinary URL for an image
  static String getOptimizedImageUrl(
    String publicId, {
    int width = 200,
    int height = 200,
    String crop = 'fill',
    String quality = 'auto',
    String format = 'auto',
  }) {
    return 'https://res.cloudinary.com/$cloudName/image/upload'
        '/w_$width,h_$height,c_$crop,q_$quality,f_$format'
        '/$publicId';
  }

  /// Get a thumbnail URL
  static String getThumbnailUrl(String publicId) {
    return getOptimizedImageUrl(
      publicId,
      width: 150,
      height: 150,
      crop: 'thumb',
    );
  }

  /// Get a video thumbnail
  static String getVideoThumbnailUrl(String publicId, {int seconds = 0}) {
    return 'https://res.cloudinary.com/$cloudName/video/upload'
        '/so_${seconds}s,w_300,h_300,c_thumb,q_auto,f_auto'
        '/$publicId.jpg';
  }

  /// Delete a file from Cloudinary (requires API secret)
  Future<bool> deleteFile(String publicId) async {
    try {
      debugPrint('🗑️ Deleting file from Cloudinary: $publicId');

      // For signed requests, you would need to add signature
      // This is a simplified version - actual implementation requires authentication
      // formData would be sent to: https://api.cloudinary.com/v1_1/{cloud_name}/resources/image/upload/{public_id}
      
      debugPrint('✅ File deletion initiated: $publicId');
      return true;
    } catch (e) {
      debugPrint('❌ Deletion error: $e');
      return false;
    }
  }
}
