import 'package:flutter/material.dart';

/// Model for Live Zone settings controlled by admin
class LiveSettings {
  Duration countdownDuration;
  bool isLiveManuallyEnabled;
  bool allowUsersToGoLive; // Admin control for user Go Live button access
  String categoriesTitle; // e.g., "TODAY'S CATEGORIES"
  String ceremonyHeader; // e.g., "ARTIST AWARDS 2025 LIVE CEREMONY"
  String? liveVotingArtist1; // Artist name for voting button 1
  String? liveVotingArtist2; // Artist name for voting button 2
  String? artist1ImageUrl; // Profile picture URL for artist 1
  String? artist2ImageUrl; // Profile picture URL for artist 2
  int votesForArtist1;
  int votesForArtist2;
  Map<String, int> userVotedFor; // username -> artistNumber (1 or 2)
  String? currentBroadcastId; // Current broadcast session ID
  Map<String, Set<String>> broadcastVotes; // broadcastId -> Set of usernames who voted

  LiveSettings({
    this.countdownDuration = const Duration(hours: 2),
    this.isLiveManuallyEnabled = false,
    this.allowUsersToGoLive = true, // Default: users can go live
    this.categoriesTitle = "TODAY'S CATEGORIES",
    this.ceremonyHeader = "ARTIST AWARDS 2025 LIVE CEREMONY",
    this.liveVotingArtist1,
    this.liveVotingArtist2,
    this.artist1ImageUrl,
    this.artist2ImageUrl,
    this.votesForArtist1 = 0,
    this.votesForArtist2 = 0,
    Map<String, int>? userVotedFor,
    this.currentBroadcastId,
    Map<String, Set<String>>? broadcastVotes,
  }) : userVotedFor = userVotedFor ?? {},
       broadcastVotes = broadcastVotes ?? {};

  Map<String, dynamic> toJson() {
    return {
      'countdownSeconds': countdownDuration.inSeconds,
      'isLiveManuallyEnabled': isLiveManuallyEnabled,
      'allowUsersToGoLive': allowUsersToGoLive,
      'categoriesTitle': categoriesTitle,
      'ceremonyHeader': ceremonyHeader,
      'liveVotingArtist1': liveVotingArtist1,
      'liveVotingArtist2': liveVotingArtist2,
      'artist1ImageUrl': artist1ImageUrl,
      'artist2ImageUrl': artist2ImageUrl,
      'votesForArtist1': votesForArtist1,
      'votesForArtist2': votesForArtist2,
      'userVotedFor': userVotedFor,
      'currentBroadcastId': currentBroadcastId,
      'broadcastVotes': broadcastVotes.map((key, value) => MapEntry(key, value.toList())),
    };
  }

  factory LiveSettings.fromJson(Map<String, dynamic> json) {
    Map<String, Set<String>> parsedBroadcastVotes = {};
    if (json['broadcastVotes'] != null) {
      final broadcastVotesMap = json['broadcastVotes'] as Map<String, dynamic>;
      broadcastVotesMap.forEach((key, value) {
        parsedBroadcastVotes[key] = Set<String>.from(value as List);
      });
    }
    
    return LiveSettings(
      countdownDuration: Duration(seconds: json['countdownSeconds'] ?? 7200),
      isLiveManuallyEnabled: json['isLiveManuallyEnabled'] ?? false,
      allowUsersToGoLive: json['allowUsersToGoLive'] ?? true,
      categoriesTitle: json['categoriesTitle'] ?? "TODAY'S CATEGORIES",
      ceremonyHeader: json['ceremonyHeader'] ?? "ARTIST AWARDS 2025 LIVE CEREMONY",
      liveVotingArtist1: json['liveVotingArtist1'],
      liveVotingArtist2: json['liveVotingArtist2'],
      artist1ImageUrl: json['artist1ImageUrl'],
      artist2ImageUrl: json['artist2ImageUrl'],
      votesForArtist1: json['votesForArtist1'] ?? 0,
      votesForArtist2: json['votesForArtist2'] ?? 0,
      userVotedFor: Map<String, int>.from(json['userVotedFor'] ?? {}),
      currentBroadcastId: json['currentBroadcastId'],
      broadcastVotes: parsedBroadcastVotes,
    );
  }
}

/// Model for category video content
class CategoryVideo {
  String id;
  String title;
  String youtubeUrl;
  String? thumbnailUrl; // Optional thumbnail from gallery
  List<String> likes;
  List<ImageComment> comments; // Reuse ImageComment for videos too
  int votes; // Vote count for this video
  DateTime createdAt; // When the video was added
  int? expiresInDays; // How many days until auto-deletion (null = never expires)

  CategoryVideo({
    required this.id,
    required this.title,
    required this.youtubeUrl,
    this.thumbnailUrl,
    List<String>? likes,
    List<ImageComment>? comments,
    this.votes = 0,
    DateTime? createdAt,
    this.expiresInDays,
  })  : likes = likes ?? [],
        comments = comments ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get isExpired {
    if (expiresInDays == null) return false;
    final expirationDate = createdAt.add(Duration(days: expiresInDays!));
    return DateTime.now().isAfter(expirationDate);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'youtubeUrl': youtubeUrl,
      'thumbnailUrl': thumbnailUrl,
      'likes': likes,
      'comments': comments.map((c) => c.toJson()).toList(),
      'votes': votes,
      'createdAt': createdAt.toIso8601String(),
      'expiresInDays': expiresInDays,
    };
  }

  factory CategoryVideo.fromJson(Map<String, dynamic> json) {
    return CategoryVideo(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      youtubeUrl: json['youtubeUrl'] ?? '',
      thumbnailUrl: json['thumbnailUrl'],
      likes: List<String>.from(json['likes'] ?? []),
      comments: (json['comments'] as List<dynamic>?)
              ?.map((c) => ImageComment.fromJson(c))
              .toList() ??
          [],
      votes: json['votes'] ?? 0,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      expiresInDays: json['expiresInDays'],
    );
  }

  CategoryVideo copyWith({
    String? id,
    String? title,
    String? youtubeUrl,
    String? thumbnailUrl,
    List<String>? likes,
    List<ImageComment>? comments,
    int? votes,
    DateTime? createdAt,
    int? expiresInDays,
  }) {
    return CategoryVideo(
      id: id ?? this.id,
      title: title ?? this.title,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      votes: votes ?? this.votes,
      createdAt: createdAt ?? this.createdAt,
      expiresInDays: expiresInDays ?? this.expiresInDays,
    );
  }
}

/// Model for category image content
class CategoryImage {
  String id;
  String imageUrl; // File path or URL
  String? caption;
  List<String> likes; // List of usernames who liked
  List<ImageComment> comments;
  int votes; // Vote count for this image
  DateTime createdAt; // When the image was added
  int? expiresInDays; // How many days until auto-deletion (null = never expires)

  CategoryImage({
    required this.id,
    required this.imageUrl,
    this.caption,
    List<String>? likes,
    List<ImageComment>? comments,
    this.votes = 0,
    DateTime? createdAt,
    this.expiresInDays,
  })  : likes = likes ?? [],
        comments = comments ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get isExpired {
    if (expiresInDays == null) return false;
    final expirationDate = createdAt.add(Duration(days: expiresInDays!));
    return DateTime.now().isAfter(expirationDate);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'caption': caption,
      'likes': likes,
      'comments': comments.map((c) => c.toJson()).toList(),
      'votes': votes,
      'createdAt': createdAt.toIso8601String(),
      'expiresInDays': expiresInDays,
    };
  }

  factory CategoryImage.fromJson(Map<String, dynamic> json) {
    return CategoryImage(
      id: json['id'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      caption: json['caption'],
      likes: List<String>.from(json['likes'] ?? []),
      comments: (json['comments'] as List<dynamic>?)
              ?.map((c) => ImageComment.fromJson(c))
              .toList() ??
          [],
      votes: json['votes'] ?? 0,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      expiresInDays: json['expiresInDays'],
    );
  }

  CategoryImage copyWith({
    String? id,
    String? imageUrl,
    String? caption,
    List<String>? likes,
    List<ImageComment>? comments,
    int? votes,
    DateTime? createdAt,
    int? expiresInDays,
  }) {
    return CategoryImage(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      caption: caption ?? this.caption,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      votes: votes ?? this.votes,
      createdAt: createdAt ?? this.createdAt,
      expiresInDays: expiresInDays ?? this.expiresInDays,
    );
  }
}

/// Model for comments on images
class ImageComment {
  String id;
  String userId;
  String username;
  String text;
  DateTime timestamp;

  ImageComment({
    required this.id,
    required this.userId,
    required this.username,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ImageComment.fromJson(Map<String, dynamic> json) {
    return ImageComment(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      text: json['text'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Model for Award Category with nominees and artists
class CategoryModel {
  String id;
  String title;
  IconData icon;
  Color color;
  List<ArtistNominee> nominees;
  bool votingEnabled;
  List<CategoryVideo> videos;
  List<CategoryImage> images;

  CategoryModel({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    this.nominees = const [],
    this.votingEnabled = false,
    this.videos = const [],
    this.images = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'iconCodePoint': icon.codePoint,
      'colorValue': color.toARGB32(),
      'nominees': nominees.map((n) => n.toJson()).toList(),
      'votingEnabled': votingEnabled,
      'videos': videos.map((v) => v.toJson()).toList(),
      'images': images.map((img) => img.toJson()).toList(),
    };
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      icon: IconData(json['iconCodePoint'] ?? 0xe5df, fontFamily: 'MaterialIcons'),
      color: Color(json['colorValue'] ?? 0xFFFF6B9D),
      nominees: (json['nominees'] as List<dynamic>?)
              ?.map((n) => ArtistNominee.fromJson(n))
              .toList() ??
          [],
      votingEnabled: json['votingEnabled'] ?? false,
      videos: (json['videos'] as List<dynamic>?)
              ?.map((v) => CategoryVideo.fromJson(v))
              .toList() ??
          [],
      images: (json['images'] as List<dynamic>?)
              ?.map((img) => CategoryImage.fromJson(img))
              .toList() ??
          [],
    );
  }

  CategoryModel copyWith({
    String? id,
    String? title,
    IconData? icon,
    Color? color,
    List<ArtistNominee>? nominees,
    bool? votingEnabled,
    List<CategoryVideo>? videos,
    List<CategoryImage>? images,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      nominees: nominees ?? this.nominees,
      votingEnabled: votingEnabled ?? this.votingEnabled,
      videos: videos ?? this.videos,
      images: images ?? this.images,
    );
  }
}

/// Model for individual artist nominee in a category
class ArtistNominee {
  String id;
  String artistName;
  String? workTitle; // Song title, video title, etc.
  String? imageUrl; // File path or URL
  int votes;
  List<String> likes;
  List<ImageComment> comments;
  DateTime createdAt; // When the nominee was added
  int? expiresInDays; // How many days until auto-deletion (null = never expires)

  ArtistNominee({
    required this.id,
    required this.artistName,
    this.workTitle,
    this.imageUrl,
    this.votes = 0,
    List<String>? likes,
    List<ImageComment>? comments,
    DateTime? createdAt,
    this.expiresInDays,
  })  : likes = likes ?? [],
        comments = comments ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get isExpired {
    if (expiresInDays == null) return false;
    final expirationDate = createdAt.add(Duration(days: expiresInDays!));
    return DateTime.now().isAfter(expirationDate);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'artistName': artistName,
      'workTitle': workTitle,
      'imageUrl': imageUrl,
      'votes': votes,
      'likes': likes,
      'comments': comments.map((c) => c.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'expiresInDays': expiresInDays,
    };
  }

  factory ArtistNominee.fromJson(Map<String, dynamic> json) {
    return ArtistNominee(
      id: json['id'] ?? '',
      artistName: json['artistName'] ?? '',
      workTitle: json['workTitle'],
      imageUrl: json['imageUrl'],
      votes: json['votes'] ?? 0,
      likes: List<String>.from(json['likes'] ?? []),
      comments: (json['comments'] as List<dynamic>?)
              ?.map((c) => ImageComment.fromJson(c))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      expiresInDays: json['expiresInDays'],
    );
  }

  ArtistNominee copyWith({
    String? id,
    String? artistName,
    String? workTitle,
    String? imageUrl,
    int? votes,
    List<String>? likes,
    List<ImageComment>? comments,
    DateTime? createdAt,
    int? expiresInDays,
  }) {
    return ArtistNominee(
      id: id ?? this.id,
      artistName: artistName ?? this.artistName,
      workTitle: workTitle ?? this.workTitle,
      imageUrl: imageUrl ?? this.imageUrl,
      votes: votes ?? this.votes,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      expiresInDays: expiresInDays ?? this.expiresInDays,
    );
  }
}

/// Video marketplace submission stored for the Media Testing Lab overhaul.
class MediaSubmission {
  MediaSubmission({
    required this.id,
    required this.title,
    required this.creatorName,
    required this.contactHandle,
    required this.videoUrl,
    this.localVideoPath,
    this.voiceNotePath,
    this.voiceNoteDurationSeconds,
    required this.videoDurationSeconds,
    required this.askingPrice,
    required this.captionScript,
    List<VideoTranscriptSegment>? transcriptSegments,
    List<String>? autoTags,
    this.status = MediaSubmissionStatus.pending,
    DateTime? submittedAt,
    this.reviewedAt,
    this.adminNotes,
    this.approvedPayout,
    this.paidAt,
  })  : transcriptSegments = transcriptSegments ?? <VideoTranscriptSegment>[],
        autoTags = autoTags ?? <String>[],
        submittedAt = submittedAt ?? DateTime.now();

  final String id;
  String title;
  String creatorName;
  String contactHandle;
  String videoUrl;
  String? localVideoPath;
  String? voiceNotePath;
  int? voiceNoteDurationSeconds;
  int videoDurationSeconds;
  double askingPrice;
  double? approvedPayout;
  String captionScript;
  List<VideoTranscriptSegment> transcriptSegments;
  List<String> autoTags;
  String status;
  DateTime submittedAt;
  DateTime? reviewedAt;
  String? adminNotes;
  DateTime? paidAt;

  Duration get videoDuration => Duration(seconds: videoDurationSeconds);
  bool get isPaid => paidAt != null;
  bool get isApproved => status == MediaSubmissionStatus.approved;
  bool get isPending => status == MediaSubmissionStatus.pending;
  Duration? get voiceNoteDuration => voiceNoteDurationSeconds == null
      ? null
      : Duration(seconds: voiceNoteDurationSeconds!);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'creatorName': creatorName,
      'contactHandle': contactHandle,
      'videoUrl': videoUrl,
      'localVideoPath': localVideoPath,
      'voiceNotePath': voiceNotePath,
      'voiceNoteDurationSeconds': voiceNoteDurationSeconds,
      'videoDurationSeconds': videoDurationSeconds,
      'askingPrice': askingPrice,
      'approvedPayout': approvedPayout,
      'captionScript': captionScript,
      'transcriptSegments':
          transcriptSegments.map((segment) => segment.toJson()).toList(),
      'autoTags': autoTags,
      'status': status,
      'submittedAt': submittedAt.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'adminNotes': adminNotes,
      'paidAt': paidAt?.toIso8601String(),
    };
  }

  factory MediaSubmission.fromJson(Map<String, dynamic> json) {
    return MediaSubmission(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      creatorName: json['creatorName'] ?? '',
      contactHandle: json['contactHandle'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      localVideoPath: json['localVideoPath'] as String?,
      voiceNotePath: json['voiceNotePath'] as String?,
      voiceNoteDurationSeconds:
          (json['voiceNoteDurationSeconds'] as num?)?.toInt(),
      videoDurationSeconds: json['videoDurationSeconds'] ?? 0,
      askingPrice: (json['askingPrice'] as num?)?.toDouble() ?? 0,
      approvedPayout: (json['approvedPayout'] as num?)?.toDouble(),
      captionScript: json['captionScript'] ?? '',
      transcriptSegments: (json['transcriptSegments'] as List<dynamic>? ?? [])
          .map((segment) =>
              VideoTranscriptSegment.fromJson(segment as Map<String, dynamic>))
          .toList(),
      autoTags: List<String>.from(json['autoTags'] ?? const <String>[]),
      status: json['status'] ?? MediaSubmissionStatus.pending,
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt']) ?? DateTime.now()
          : DateTime.now(),
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.tryParse(json['reviewedAt'])
          : null,
      adminNotes: json['adminNotes'],
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'])
          : null,
    );
  }

  MediaSubmission copyWith({
    String? title,
    String? creatorName,
    String? contactHandle,
    String? videoUrl,
    String? localVideoPath,
    String? voiceNotePath,
    int? voiceNoteDurationSeconds,
    int? videoDurationSeconds,
    double? askingPrice,
    double? approvedPayout,
    String? captionScript,
    List<VideoTranscriptSegment>? transcriptSegments,
    List<String>? autoTags,
    String? status,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? adminNotes,
    DateTime? paidAt,
  }) {
    return MediaSubmission(
      id: id,
      title: title ?? this.title,
      creatorName: creatorName ?? this.creatorName,
      contactHandle: contactHandle ?? this.contactHandle,
      videoUrl: videoUrl ?? this.videoUrl,
      localVideoPath: localVideoPath ?? this.localVideoPath,
      voiceNotePath: voiceNotePath ?? this.voiceNotePath,
      voiceNoteDurationSeconds:
          voiceNoteDurationSeconds ?? this.voiceNoteDurationSeconds,
      videoDurationSeconds:
          videoDurationSeconds ?? this.videoDurationSeconds,
      askingPrice: askingPrice ?? this.askingPrice,
      approvedPayout: approvedPayout ?? this.approvedPayout,
      captionScript: captionScript ?? this.captionScript,
      transcriptSegments: transcriptSegments ?? this.transcriptSegments,
      autoTags: autoTags ?? this.autoTags,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      adminNotes: adminNotes ?? this.adminNotes,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}

class VideoTranscriptSegment {
  VideoTranscriptSegment({
    required this.offsetSeconds,
    required this.text,
  });

  double offsetSeconds;
  String text;

  Duration get position => Duration(seconds: offsetSeconds.floor());

  Map<String, dynamic> toJson() => {
        'offsetSeconds': offsetSeconds,
        'text': text,
      };

  factory VideoTranscriptSegment.fromJson(Map<String, dynamic> json) {
    return VideoTranscriptSegment(
      offsetSeconds: (json['offsetSeconds'] as num?)?.toDouble() ?? 0,
      text: json['text'] ?? '',
    );
  }
}

class MediaTranscriptMatch {
  MediaTranscriptMatch({
    required this.submissionId,
    required this.segment,
    required this.query,
  });

  final String submissionId;
  final VideoTranscriptSegment segment;
  final String query;

  Duration get position => segment.position;
}

class MediaSubmissionStatus {
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}
