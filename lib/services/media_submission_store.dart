import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/betting_models.dart';
import '../models/media_models.dart';
import 'betting_data_store.dart';

class MediaSubmissionStore extends ChangeNotifier {
  MediaSubmissionStore._internal();

  static final MediaSubmissionStore _instance = MediaSubmissionStore._internal();

  static MediaSubmissionStore get instance => _instance;

  final List<MediaSubmission> _submissions = <MediaSubmission>[];
  bool _loaded = false;
  Timer? _expirationSweepTimer;
  String? _payoutMethod;
  String? _payoutHandle;

  List<MediaSubmission> get submissions => List.unmodifiable(_submissions);

  List<MediaSubmission> get approvedSubmissions => _submissions
      .where(
          (submission) => submission.status == MediaSubmissionStatus.approved)
      .toList(growable: false);

  List<MediaSubmission> get pendingSubmissions => _submissions
      .where((submission) => submission.status == MediaSubmissionStatus.pending)
      .toList(growable: false);

  List<MediaSubmission> get rejectedSubmissions => _submissions
      .where(
          (submission) => submission.status == MediaSubmissionStatus.rejected)
      .toList(growable: false);

  String? get payoutMethod => _payoutMethod;

  String? get payoutHandle => _payoutHandle;

  bool get hasPayoutDetails =>
      (_payoutMethod?.isNotEmpty ?? false) &&
      (_payoutHandle?.isNotEmpty ?? false);

  double get pendingCreatorPayoutTotal => _submissions
      .where((submission) =>
          submission.status == MediaSubmissionStatus.approved &&
          !submission.isPaid)
      .fold<double>(
        0,
        (sum, submission) =>
            sum + (submission.approvedPayout ?? submission.askingPrice),
      );

  double get lifetimeCreatorPayoutTotal =>
      _submissions.where((submission) => submission.isPaid).fold<double>(
            0,
            (sum, submission) =>
                sum + (submission.approvedPayout ?? submission.askingPrice),
          );

  double get lifetimeCreatorEarningsTotal => _submissions
      .where(
          (submission) => submission.status == MediaSubmissionStatus.approved)
      .fold<double>(
        0,
        (sum, submission) =>
            sum + (submission.approvedPayout ?? submission.askingPrice),
      );

  int get pendingCreatorPayoutCount => _submissions
      .where((submission) =>
          submission.status == MediaSubmissionStatus.approved &&
          !submission.isPaid)
      .length;

  double? get smallestPendingCreatorPayout {
    double? min;
    for (final submission in _submissions) {
      if (submission.status == MediaSubmissionStatus.approved &&
          !submission.isPaid) {
        final payout = submission.approvedPayout ?? submission.askingPrice;
        if (payout > 0 && (min == null || payout < min)) {
          min = payout;
        }
      }
    }
    return min;
  }

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('media_submission_entries');
    _payoutMethod = prefs.getString('media_submission_payout_method');
    _payoutHandle = prefs.getString('media_submission_payout_handle');
    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      _submissions
        ..clear()
        ..addAll(decoded.map((entry) =>
            MediaSubmission.fromJson(entry as Map<String, dynamic>)));
    } else {
      _seedDefaults();
      await _save();
    }
    final pruned = await _pruneExpiredEntries();
    if (pruned) {
      await _save();
    }
    _scheduleExpirationSweep();
    _loaded = true;
    notifyListeners();
  }

  Future<MediaSubmission> submitMedia({
    required String title,
    required String creatorName,
    required String contactHandle,
    String? videoUrl,
    String? localVideoPath,
    String? voiceNotePath,
    Duration? voiceNoteDuration,
    required Duration videoLength,
    required double askingPrice,
    required String captionScript,
  }) async {
    await load();
    final id = 'media-${DateTime.now().millisecondsSinceEpoch}';
    final segments = _buildSegments(
      script: captionScript,
      length: videoLength,
    );
    final submission = MediaSubmission(
      id: id,
      title: title,
      creatorName: creatorName,
      contactHandle: contactHandle,
      videoUrl: videoUrl ?? '',
      localVideoPath: localVideoPath,
      voiceNotePath: voiceNotePath,
      voiceNoteDurationSeconds: voiceNoteDuration?.inSeconds,
      videoDurationSeconds: videoLength.inSeconds,
      askingPrice: askingPrice,
      captionScript: captionScript,
      transcriptSegments: segments,
      autoTags: _extractTags(captionScript),
    );
    _submissions.insert(0, submission);
    await _save();
    notifyListeners();
    return submission;
  }

  Future<void> reviewSubmission({
    required String submissionId,
    required String status,
    double? approvedPayout,
    String? adminNotes,
  }) async {
    await load();
    final index =
        _submissions.indexWhere((submission) => submission.id == submissionId);
    if (index == -1) {
      return;
    }
    final submission = _submissions[index].copyWith(
      status: status,
      approvedPayout: approvedPayout ?? _submissions[index].approvedPayout,
      adminNotes: adminNotes ?? _submissions[index].adminNotes,
      reviewedAt: DateTime.now(),
    );
    _submissions[index] = submission;
    final pruned = await _pruneExpiredEntries();
    await _save();
    if (pruned) {
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  Future<void> markPaid(String submissionId) async {
    await load();
    final index =
        _submissions.indexWhere((submission) => submission.id == submissionId);
    if (index == -1) {
      return;
    }
    final submission = _submissions[index].copyWith(paidAt: DateTime.now());
    _submissions[index] = submission;
    await _save();
    notifyListeners();
  }

  Future<void> updateLocalVideoPath(
    String submissionId,
    String? localPath,
  ) async {
    await load();
    final index =
        _submissions.indexWhere((submission) => submission.id == submissionId);
    if (index == -1) {
      return;
    }

    final submission =
        _submissions[index].copyWith(localVideoPath: localPath?.trim());
    _submissions[index] = submission;
    await _save();
    notifyListeners();
  }

  Future<void> deleteSubmission(String submissionId) async {
    await load();
    final initialLength = _submissions.length;
    _submissions.removeWhere((submission) => submission.id == submissionId);
    if (_submissions.length == initialLength) {
      return;
    }
    await _save();
    notifyListeners();
  }

  MediaSubmission? findById(String submissionId) {
    try {
      return _submissions.firstWhere(
        (submission) => submission.id == submissionId,
      );
    } catch (_) {
      return null;
    }
  }

  List<MediaTranscriptMatch> searchTranscript({
    required String submissionId,
    required String query,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return <MediaTranscriptMatch>[];
    }
    final submission = findById(submissionId);
    if (submission == null) {
      return <MediaTranscriptMatch>[];
    }
    final matches = <MediaTranscriptMatch>[];
    for (final segment in submission.transcriptSegments) {
      if (segment.text.toLowerCase().contains(normalized)) {
        matches.add(MediaTranscriptMatch(
          submissionId: submission.id,
          segment: segment,
          query: normalized,
        ));
      }
    }
    return matches;
  }

  Future<double> withdrawAllApprovedPayouts() async {
    await load();
    double total = 0;
    var updated = false;
    final now = DateTime.now();

    for (var i = 0; i < _submissions.length; i++) {
      final submission = _submissions[i];
      final isReady = submission.status == MediaSubmissionStatus.approved &&
          !submission.isPaid;
      if (!isReady) {
        continue;
      }

      final payout = submission.approvedPayout ?? submission.askingPrice;
      if (payout <= 0) {
        continue;
      }

      total += payout;
      _submissions[i] = submission.copyWith(paidAt: now);
      updated = true;
    }

    if (!updated) {
      return 0;
    }

    await _save();
    notifyListeners();

    if (total <= 0) {
      return 0;
    }

    final wallet = BettingDataStore.instance;
    final timestamp = DateTime.now();
    await wallet.loadFromStorage();
    wallet.adjustBalance(total);
    wallet.addHistoryEntry(
      BettingHistoryEntry(
        id: 'media-withdraw-${timestamp.millisecondsSinceEpoch}',
        title: 'Media marketplace earnings',
        amount: total,
        isCredit: true,
        category: TransactionCategory.deposit,
        icon: Icons.movie_creation_outlined,
        color: Colors.tealAccent,
        timestamp: timestamp,
      ),
    );

    return total;
  }

  Future<void> attachTranscript({
    required String submissionId,
    required List<VideoTranscriptSegment> segments,
  }) async {
    await load();
    final index =
        _submissions.indexWhere((submission) => submission.id == submissionId);
    if (index == -1) {
      return;
    }
    final submission = _submissions[index].copyWith(
      transcriptSegments: segments,
      autoTags: _extractTags(segments.map((segment) => segment.text).join(' ')),
    );
    _submissions[index] = submission;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
        _submissions.map((submission) => submission.toJson()).toList());
    await prefs.setString('media_submission_entries', encoded);
    if (_payoutMethod != null && _payoutMethod!.isNotEmpty) {
      await prefs.setString(
        'media_submission_payout_method',
        _payoutMethod!,
      );
    } else {
      await prefs.remove('media_submission_payout_method');
    }
    if (_payoutHandle != null && _payoutHandle!.isNotEmpty) {
      await prefs.setString(
        'media_submission_payout_handle',
        _payoutHandle!,
      );
    } else {
      await prefs.remove('media_submission_payout_handle');
    }
  }

  Future<void> updatePayoutDetails({
    required String method,
    required String handle,
  }) async {
    await load();
    final normalizedMethod = method.trim().toLowerCase();
    final normalizedHandle = handle.trim();
    _payoutMethod = normalizedMethod.isEmpty ? null : normalizedMethod;
    _payoutHandle = normalizedHandle.isEmpty ? null : normalizedHandle;
    await _save();
    notifyListeners();
  }

  void _scheduleExpirationSweep() {
    _expirationSweepTimer ??= Timer.periodic(
      const Duration(hours: 1),
      (_) => unawaited(_runExpirationSweep()),
    );
  }

  Future<void> _runExpirationSweep() async {
    final removed = await _pruneExpiredEntries();
    if (removed) {
      await _save();
      notifyListeners();
    }
  }

  Future<bool> _pruneExpiredEntries() async {
    if (_submissions.isEmpty) {
      return false;
    }

    final cutoff = DateTime.now().subtract(const Duration(days: 2));
    final initialLength = _submissions.length;

    _submissions.removeWhere((submission) {
      final status = submission.status;
      if (status != MediaSubmissionStatus.approved &&
          status != MediaSubmissionStatus.rejected) {
        return false;
      }

      final reference = submission.reviewedAt ?? submission.submittedAt;
      return reference.isBefore(cutoff);
    });

    return _submissions.length != initialLength;
  }

  void _seedDefaults() {
    _submissions.clear();
    _payoutMethod = null;
    _payoutHandle = null;
  }

  List<VideoTranscriptSegment> _buildSegments({
    required String script,
    required Duration length,
  }) {
    final sanitized = script.replaceAll('\r', '\n');
    final snippets = sanitized
        .split(RegExp(r'[\n\.\?!]'))
        .map((snippet) => snippet.trim())
        .where((snippet) => snippet.isNotEmpty)
        .toList();
    if (snippets.isEmpty) {
      return <VideoTranscriptSegment>[];
    }
    final totalSeconds =
        length.inSeconds > 0 ? length.inSeconds : snippets.length * 12;
    final step = totalSeconds / snippets.length;
    final segments = <VideoTranscriptSegment>[];
    for (var i = 0; i < snippets.length; i++) {
      final offset = step * i;
      segments.add(VideoTranscriptSegment(
        offsetSeconds: offset,
        text: snippets[i],
      ));
    }
    return segments;
  }

  List<String> _extractTags(String script) {
    final words = script
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 3)
        .toSet()
        .toList();
    words.sort();
    return words.take(12).toList();
  }
}
