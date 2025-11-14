import 'dart:async';
import 'dart:io' show Directory, File, Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../models/media_models.dart';
import '../services/media_submission_store.dart';

String _describePayoutMethod(String method) {
  switch (method) {
    case 'wallet':
      return 'Wallet address';
    case 'cash_app':
    default:
      return 'Cash App tag';
  }
}

class AdminMediaMarketplaceScreen extends StatefulWidget {
  const AdminMediaMarketplaceScreen({super.key});

  @override
  State<AdminMediaMarketplaceScreen> createState() =>
      _AdminMediaMarketplaceScreenState();
}

class _AdminMediaMarketplaceScreenState
    extends State<AdminMediaMarketplaceScreen> {
  final MediaSubmissionStore _store = MediaSubmissionStore.instance;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _store.addListener(_handleStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _store.load();
      if (!mounted) return;
      setState(() {
        _initializing = false;
      });
    });
  }

  @override
  void dispose() {
    _store.removeListener(_handleStoreChanged);
    super.dispose();
  }

  void _handleStoreChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Marketplace Desk'),
        centerTitle: false,
      ),
      body: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          if (_initializing) {
            return const Center(child: CircularProgressIndicator());
          }

          final pending = _store.pendingSubmissions;
          final approved = _store.approvedSubmissions;
          final rejected = _store.rejectedSubmissions;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_hasPendingPayouts(approved)) ...[
                  _buildPayoutBanner(approved),
                  const SizedBox(height: 20),
                ],
                _buildSection(
                  title: 'Waiting for review',
                  entries: pending,
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: 'Approved and published',
                  entries: approved,
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: 'Rejected or archived',
                  entries: rejected,
                  showActions: false,
                  allowDeletion: true,
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _hasPendingPayouts(List<MediaSubmission> approved) {
    return approved.any(
      (submission) =>
          submission.status == MediaSubmissionStatus.approved &&
          !submission.isPaid,
    );
  }

  Widget _buildPayoutBanner(List<MediaSubmission> approved) {
    final pending = _pendingPayoutSubmissions(approved);
    final total = pending.fold<double>(
      0,
      (sum, submission) =>
          sum + (submission.approvedPayout ?? submission.askingPrice),
    );
    final method = _store.payoutMethod ?? 'cash_app';
    final methodLabel = _describePayoutMethod(method);
    final handle = _store.payoutHandle ?? '';
    final hasDetails = _store.hasPayoutDetails;
    final summary =
        hasDetails ? '$methodLabel • $handle' : 'No payout details saved yet';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F3C5B), Color(0xFF25405F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.tealAccent.withAlpha((0.25 * 255).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pending.length == 1
                ? '1 creator is ready for a payout'
                : '${pending.length} creators are ready for payout',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total outstanding ${_formatCurrency(total)}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            style: TextStyle(
              color: hasDetails
                  ? Colors.white.withAlpha((0.75 * 255).round())
                  : Colors.orangeAccent.withAlpha((0.85 * 255).round()),
              fontWeight: hasDetails ? FontWeight.w500 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: pending
                .take(3)
                .map((submission) =>
                    _buildTagChip(submission.title, inactive: true))
                .toList(),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openWithdrawalSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.payments),
            label: const Text('Record payout'),
          ),
        ],
      ),
    );
  }

  List<MediaSubmission> _pendingPayoutSubmissions(
      List<MediaSubmission> approved) {
    return approved
        .where((submission) =>
            submission.status == MediaSubmissionStatus.approved &&
            !submission.isPaid)
        .toList(growable: false);
  }

  Widget _buildSection({
    required String title,
    required List<MediaSubmission> entries,
    bool showActions = true,
    bool allowDeletion = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.04 * 255).round()),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withAlpha((0.08 * 255).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withAlpha((0.18 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${entries.length}',
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const Text(
              'Nothing here for now.',
              style: TextStyle(color: Colors.white54),
            )
          else
            Column(
              children: entries
                  .map(
                    (submission) => _buildAdminCard(
                      submission,
                      showActions: showActions,
                      onDelete: allowDeletion
                          ? () => _confirmDelete(submission)
                          : null,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(
    MediaSubmission submission, {
    required bool showActions,
    VoidCallback? onDelete,
  }) {
    final wordCount = submission.captionScript
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    final payoutValue = submission.approvedPayout ?? submission.askingPrice;

    final actionButtons = <Widget>[
      OutlinedButton.icon(
        onPressed: () => _openSubmissionDetail(submission),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.tealAccent,
          side: BorderSide(
            color: Colors.tealAccent.withAlpha((0.35 * 255).round()),
          ),
        ),
        icon: const Icon(Icons.play_circle_outline),
        label: const Text('Review details'),
      ),
    ];

    if (showActions && submission.status == MediaSubmissionStatus.pending) {
      actionButtons.addAll([
        ElevatedButton.icon(
          onPressed: () => _openReviewDialog(
            submission,
            targetStatus: MediaSubmissionStatus.approved,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.tealAccent,
            foregroundColor: Colors.black,
          ),
          icon: const Icon(Icons.verified),
          label: const Text('Approve and publish'),
        ),
        OutlinedButton.icon(
          onPressed: () => _openReviewDialog(
            submission,
            targetStatus: MediaSubmissionStatus.rejected,
          ),
          icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
          label: const Text(
            'Reject',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ]);
    }

    if (showActions &&
        submission.status == MediaSubmissionStatus.approved &&
        !submission.isPaid) {
      actionButtons.add(
        ElevatedButton.icon(
          onPressed: () => _openWithdrawalSheet(focusSubmission: submission),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.tealAccent,
            foregroundColor: Colors.black,
          ),
          icon: const Icon(Icons.payments),
          label: const Text('Record payout'),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.06 * 255).round()),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submission.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${submission.creatorName} • ${submission.contactHandle}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusChip(submission.status),
                  if (onDelete != null) ...[
                    const SizedBox(height: 6),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      tooltip: 'Delete this receipt',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildInfoBadge(
                Icons.timer_outlined,
                _formatDurationLabel(submission.videoDuration),
              ),
              _buildInfoBadge(
                Icons.auto_stories,
                'Script $wordCount words',
              ),
              _buildInfoBadge(
                Icons.closed_caption,
                'Transcript ${submission.transcriptSegments.length}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Ask ${_formatCurrency(submission.askingPrice)}',
            style: const TextStyle(
              color: Colors.tealAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Creator payout ${_formatCurrency(payoutValue)}',
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            submission.captionScript,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 10),
          _buildVideoSourceRow(submission),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: submission.autoTags.isEmpty
                ? [
                    _buildTagChip('No auto-tags yet', inactive: true),
                  ]
                : submission.autoTags
                    .take(12)
                    .map((tag) => _buildTagChip(tag))
                    .toList(),
          ),
          const SizedBox(height: 10),
          Text(
            'Submitted ${_formatDateTime(submission.submittedAt)}',
            style: const TextStyle(color: Colors.white54),
          ),
          if (submission.reviewedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Reviewed ${_formatDateTime(submission.reviewedAt!)}',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          if (submission.isPaid)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Paid ${_formatDateTime(submission.paidAt!)}',
                style: const TextStyle(color: Colors.tealAccent),
              ),
            ),
          if (submission.adminNotes != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                submission.adminNotes!,
                style: const TextStyle(color: Colors.white54, height: 1.4),
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: actionButtons,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String tag, {bool inactive = false}) {
    final background = inactive
        ? Colors.white.withAlpha((0.08 * 255).round())
        : Colors.tealAccent.withAlpha((0.2 * 255).round());
    final foreground = inactive ? Colors.white54 : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: foreground,
          fontWeight: inactive ? FontWeight.w500 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVideoSourceRow(MediaSubmission submission) {
    final hasLocal = submission.localVideoPath != null &&
        submission.localVideoPath!.trim().isNotEmpty;
    final hasUrl = submission.videoUrl.isNotEmpty;
    IconData icon;
    String message;

    if (hasLocal) {
      icon = Icons.upload_file;
      message = 'Local upload available';
    } else if (hasUrl) {
      icon = Icons.link;
      message = submission.videoUrl;
    } else {
      icon = Icons.help_outline;
      message = 'Waiting for media upload';
    }

    return Row(
      children: [
        Icon(icon, color: Colors.tealAccent, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _openSubmissionDetail(MediaSubmission submission) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SubmissionDetailSheet(
          submission: submission,
          onRequestPayout:
              submission.status == MediaSubmissionStatus.approved &&
                      !submission.isPaid
                  ? () {
                      Navigator.of(context).pop();
                      _openWithdrawalSheet(focusSubmission: submission);
                    }
                  : null,
        );
      },
    );
  }

  Future<void> _openWithdrawalSheet({MediaSubmission? focusSubmission}) async {
    final pending = _pendingPayoutSubmissions(_store.approvedSubmissions);
    if (pending.isEmpty) {
      _showSnack('No creators waiting on a payout.', Colors.orange);
      return;
    }

    if (!_store.hasPayoutDetails) {
      _showSnack(
        'No payout details on file. Ask the creator to save their Cash App tag or wallet.',
        Colors.orange,
      );
      return;
    }

    final processed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CashAppPayoutSheet(
          pending: pending,
          focus: focusSubmission,
          payoutHandle: _store.payoutHandle ?? '',
          payoutMethod: _store.payoutMethod ?? 'cash_app',
          onConfirm: (selected, payoutHandle, memo) async {
            await _processPayoutTransfers(
              selected: selected,
              payoutHandle: payoutHandle,
              memo: memo,
            );
          },
        );
      },
    );

    if (processed == true) {
      _showSnack('Payout logged.', Colors.tealAccent);
    }
  }

  Future<void> _processPayoutTransfers({
    required List<MediaSubmission> selected,
    required String payoutHandle,
    required String memo,
  }) async {
    final trimmedHandle = payoutHandle.trim();
    final trimmedMemo = memo.trim();
    final stamp = _formatDateTimeShort(DateTime.now());
    final methodLabel =
        _describePayoutMethod(_store.payoutMethod ?? 'cash_app');

    for (final submission in selected) {
      if (trimmedHandle.isNotEmpty || trimmedMemo.isNotEmpty) {
        final existing = submission.adminNotes?.trim();
        final destination =
            trimmedHandle.isEmpty ? '' : '$methodLabel $trimmedHandle';
        final noteLine = [
          if (destination.isNotEmpty) destination,
          'logged $stamp',
        ].join(' ');
        final withMemo =
            trimmedMemo.isEmpty ? noteLine : '$noteLine • $trimmedMemo';
        final merged = <String>[
          if (existing != null && existing.isNotEmpty) existing,
          withMemo,
        ].join('\n');
        await _store.reviewSubmission(
          submissionId: submission.id,
          status: submission.status,
          approvedPayout: submission.approvedPayout,
          adminNotes: merged.isEmpty ? null : merged,
        );
      }
      await _store.markPaid(submission.id);
    }
  }

  Future<void> _openReviewDialog(
    MediaSubmission submission, {
    required String targetStatus,
  }) async {
    final approving = targetStatus == MediaSubmissionStatus.approved;
    final payoutController = TextEditingController(
      text: (submission.approvedPayout ?? submission.askingPrice)
          .toStringAsFixed(2),
    );
    final notesController =
        TextEditingController(text: submission.adminNotes ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101A2D),
          title: Text(
            approving ? 'Approve submission' : 'Reject submission',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                submission.title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (approving) ...[
                const Text(
                  'Creator payout',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: payoutController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '95.00',
                    hintStyle: TextStyle(
                      color: Colors.white.withAlpha((0.4 * 255).round()),
                    ),
                    filled: true,
                    fillColor: Colors.white.withAlpha((0.08 * 255).round()),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withAlpha((0.2 * 255).round()),
                      ),
                    ),
                    prefixText: 'NG\$ ',
                    prefixStyle: const TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Admin notes',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Why are we approving or rejecting this clip?',
                  hintStyle: TextStyle(
                    color: Colors.white.withAlpha((0.4 * 255).round()),
                  ),
                  filled: true,
                  fillColor: Colors.white.withAlpha((0.08 * 255).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withAlpha((0.2 * 255).round()),
                    ),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    approving ? Colors.tealAccent : Colors.redAccent,
                foregroundColor: Colors.black,
              ),
              child: Text(approving ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      payoutController.dispose();
      notesController.dispose();
      return;
    }

    double? payout;
    if (approving) {
      payout = double.tryParse(payoutController.text.trim());
      if (payout == null || payout <= 0) {
        _showSnack(
          'Enter a valid payout to approve this submission.',
          Colors.orange,
        );
        payoutController.dispose();
        notesController.dispose();
        return;
      }
    }

    await _store.reviewSubmission(
      submissionId: submission.id,
      status: targetStatus,
      approvedPayout: payout,
      adminNotes: notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
    );

    payoutController.dispose();
    notesController.dispose();

    _showSnack(
      approving ? 'Approved and ready to publish.' : 'Submission rejected.',
      Colors.tealAccent,
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case MediaSubmissionStatus.approved:
        color = Colors.tealAccent;
        label = 'Approved';
        break;
      case MediaSubmissionStatus.rejected:
        color = Colors.redAccent;
        label = 'Rejected';
        break;
      default:
        color = Colors.amberAccent;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((0.2 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _confirmDelete(MediaSubmission submission) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111B2E),
          title: const Text(
            'Delete receipt?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This permanently removes the submission and any cached copy of the clip.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteSubmission(submission);
    }
  }

  Future<void> _deleteSubmission(MediaSubmission submission) async {
    final localPath = submission.localVideoPath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      final file = _fileForPath(localPath);
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (error, stackTrace) {
        debugPrint('Failed to delete cached video (${submission.id}): $error');
        debugPrint('$stackTrace');
      }
    }

    final voicePath = submission.voiceNotePath?.trim();
    if (voicePath != null && voicePath.isNotEmpty) {
      final audioFile = _fileForPath(voicePath);
      try {
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      } catch (error, stackTrace) {
        debugPrint('Failed to delete voice note (${submission.id}): $error');
        debugPrint('$stackTrace');
      }
    }

    await _store.deleteSubmission(submission.id);
    if (!mounted) return;
    _showSnack('Submission removed.', Colors.redAccent);
  }

  File _fileForPath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.startsWith('file://')) {
      return File.fromUri(Uri.parse(trimmed));
    }
    return File(trimmed);
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  String _formatCurrency(double value) => 'NG\$${value.toStringAsFixed(2)}';

  String _formatDurationLabel(Duration duration) {
    if (duration.inSeconds <= 0) {
      return 'Length pending';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_monthLabels[dateTime.month - 1]} '
        '${dateTime.day.toString().padLeft(2, '0')}, '
        '${dateTime.year} • ${_formatTime(dateTime)}';
  }

  String _formatDateTimeShort(DateTime dateTime) {
    return '${_monthLabels[dateTime.month - 1]} '
        '${dateTime.day.toString().padLeft(2, '0')} • ${_formatTime(dateTime)}';
  }

  String _formatTime(DateTime dateTime) {
    final hour12 = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  static const List<String> _monthLabels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

class _SubmissionDetailSheet extends StatefulWidget {
  const _SubmissionDetailSheet({
    required this.submission,
    this.onRequestPayout,
  });

  final MediaSubmission submission;
  final VoidCallback? onRequestPayout;

  @override
  State<_SubmissionDetailSheet> createState() => _SubmissionDetailSheetState();
}

enum _VideoSource {
  none,
  local,
  remote,
}

class _SubmissionDetailSheetState extends State<_SubmissionDetailSheet> {
  final MediaSubmissionStore _store = MediaSubmissionStore.instance;
  VideoPlayerController? _controller;
  bool _loadingVideo = false;
  String? _loadError;
  bool _downloading = false;
  _VideoSource _activeSource = _VideoSource.none;
  AudioPlayer? _audioPlayer;
  StreamSubscription<PlayerState>? _audioPlayerStateSub;
  StreamSubscription<Duration>? _audioDurationSub;
  StreamSubscription<Duration>? _audioPositionSub;
  StreamSubscription<void>? _audioCompleteSub;
  bool _audioLoading = false;
  String? _audioLoadError;
  Duration? _audioDuration;
  Duration _audioPosition = Duration.zero;
  PlayerState _audioPlayerState = PlayerState.stopped;
  bool _audioHasStarted = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _initializeAudio();
  }

  @override
  void didUpdateWidget(covariant _SubmissionDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.submission.id != widget.submission.id) {
      _initializeVideo();
      _initializeAudio();
      return;
    }
    if (oldWidget.submission.voiceNotePath != widget.submission.voiceNotePath) {
      _initializeAudio();
    }
  }

  Future<void> _initializeVideo() async {
    final existingController = _controller;
    _controller = null;
    if (existingController != null) {
      await existingController.pause();
      await existingController.dispose();
    }

    final submission = widget.submission;
    setState(() {
      _loadingVideo = true;
      _loadError = null;
      _activeSource = _VideoSource.none;
    });

    final localPath = submission.localVideoPath?.trim();
    final remoteUrl = submission.videoUrl.trim();
    final hasLocalCandidate =
        !kIsWeb && localPath != null && localPath.isNotEmpty;
    final hasRemoteCandidate = remoteUrl.isNotEmpty;

    VideoPlayerController? controller;
    String? localError;
    String? remoteError;

    if (hasLocalCandidate) {
      try {
        final file = _resolveLocalFile(localPath);
        final exists = await file.exists();
        if (exists) {
          final localController = VideoPlayerController.file(file);
          try {
            await localController.initialize();
            controller = localController;
            _activeSource = _VideoSource.local;
          } catch (error, stackTrace) {
            debugPrint('Local video init failed (${submission.id}): $error');
            debugPrint('$stackTrace');
            await localController.dispose();
            localError =
                'Video failed to load. Confirm the file still exists on this device.';
          }
        } else {
          localError = 'Local video file is missing on this device.';
        }
      } catch (error, stackTrace) {
        debugPrint('Local video lookup failed (${submission.id}): $error');
        debugPrint('$stackTrace');
        localError =
            'Video failed to load. Confirm the file still exists on this device.';
      }
    }

    if (controller == null && hasRemoteCandidate) {
      final uri = Uri.tryParse(remoteUrl);
      if (uri == null || uri.scheme.isEmpty) {
        remoteError = 'Invalid video URL';
      } else {
        final shouldCacheFirst =
            !kIsWeb && (!hasLocalCandidate || localError != null);
        if (shouldCacheFirst) {
          final cachedFile = await _cacheRemoteVideo(uri, submission);
          if (cachedFile != null) {
            final cachedController = VideoPlayerController.file(cachedFile);
            try {
              await cachedController.initialize();
              controller = cachedController;
              _activeSource = _VideoSource.local;
              remoteError = null;
            } catch (error, stackTrace) {
              debugPrint('Cached video init failed (${submission.id}): $error');
              debugPrint('$stackTrace');
              await cachedController.dispose();
            }
          }
        }

        if (controller == null) {
          final remoteController = VideoPlayerController.networkUrl(uri);
          try {
            await remoteController.initialize();
            controller = remoteController;
            _activeSource = _VideoSource.remote;
            remoteError = null;
          } catch (error, stackTrace) {
            debugPrint('Network video init failed (${submission.id}): $error');
            debugPrint('$stackTrace');
            await remoteController.dispose();

            if (!kIsWeb && !shouldCacheFirst) {
              final cachedFile = await _cacheRemoteVideo(uri, submission);
              if (cachedFile != null) {
                final cachedController = VideoPlayerController.file(cachedFile);
                try {
                  await cachedController.initialize();
                  controller = cachedController;
                  _activeSource = _VideoSource.local;
                  remoteError = null;
                } catch (cacheError, cacheStack) {
                  debugPrint(
                      'Cached retry init failed (${submission.id}): $cacheError');
                  debugPrint('$cacheStack');
                  await cachedController.dispose();
                }
              }
            }

            if (controller == null) {
              remoteError =
                  'Video failed to load. Confirm the link is reachable on this network.';
            }
          }
        }
      }
    }

    if (!mounted) {
      await controller?.dispose();
      return;
    }

    if (controller == null) {
      setState(() {
        _loadingVideo = false;
        _loadError = remoteError ??
            localError ??
            'No video attached for this submission.';
      });
      return;
    }

    controller
      ..setLooping(true)
      ..setVolume(1);

    setState(() {
      _controller = controller;
      _loadingVideo = false;
      _loadError = null;
    });

    unawaited(controller.play().catchError((error, stackTrace) {
      debugPrint('Video autoplay failed (${submission.id}): $error');
      debugPrint('$stackTrace');
    }));
  }

  Future<void> _initializeAudio() async {
    _disposeAudioPlayer();

    final submission = widget.submission;
    final rawPath = submission.voiceNotePath?.trim();
    final seededDuration = submission.voiceNoteDuration;

    if (rawPath == null || rawPath.isEmpty) {
      if (!mounted) {
        _audioLoading = false;
        _audioLoadError = null;
        _audioDuration = seededDuration;
        _audioPosition = Duration.zero;
        return;
      }
      setState(() {
        _audioLoading = false;
        _audioLoadError = null;
        _audioDuration = seededDuration;
        _audioPosition = Duration.zero;
      });
      return;
    }

    if (!mounted) {
      _audioLoading = true;
      _audioLoadError = null;
      _audioDuration = seededDuration;
      _audioPosition = Duration.zero;
    } else {
      setState(() {
        _audioLoading = true;
        _audioLoadError = null;
        _audioDuration = seededDuration;
        _audioPosition = Duration.zero;
      });
    }

    try {
      final file = _resolveLocalFile(rawPath);
      final exists = await file.exists();
      if (!exists) {
        if (mounted) {
          setState(() {
            _audioLoading = false;
            _audioLoadError = 'Voice note file is missing on this device.';
          });
        } else {
          _audioLoading = false;
          _audioLoadError = 'Voice note file is missing on this device.';
        }
        return;
      }

      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(1);

      _audioPlayerStateSub = player.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        setState(() {
          _audioPlayerState = state;
        });
      });
      _audioDurationSub = player.onDurationChanged.listen((duration) {
        if (!mounted) return;
        setState(() {
          _audioDuration = duration;
        });
      });
      _audioPositionSub = player.onPositionChanged.listen((position) {
        if (!mounted) return;
        setState(() {
          _audioPosition = position;
        });
      });
      _audioCompleteSub = player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _audioPlayerState = PlayerState.completed;
          _audioPosition = _audioDuration ?? Duration.zero;
        });
        _audioHasStarted = false;
      });

      await player.setSourceDeviceFile(file.path);

      if (!mounted) {
        await player.dispose();
        return;
      }

      setState(() {
        _audioPlayer = player;
        _audioLoading = false;
        _audioLoadError = null;
        _audioHasStarted = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Voice note init failed (${submission.id}): $error');
      debugPrint('$stackTrace');
      final message =
          'Voice note failed to load. Confirm the file is accessible.';
      if (mounted) {
        setState(() {
          _audioLoading = false;
          _audioLoadError = message;
        });
      } else {
        _audioLoading = false;
        _audioLoadError = message;
      }
    }
  }

  void _disposeAudioPlayer() {
    _audioPlayerStateSub?.cancel();
    _audioDurationSub?.cancel();
    _audioPositionSub?.cancel();
    _audioCompleteSub?.cancel();
    _audioPlayerStateSub = null;
    _audioDurationSub = null;
    _audioPositionSub = null;
    _audioCompleteSub = null;
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _audioPlayerState = PlayerState.stopped;
    _audioPosition = Duration.zero;
    _audioHasStarted = false;
  }

  Future<void> _toggleAudioPlayback() async {
    final player = _audioPlayer;
    if (player == null) {
      return;
    }

    try {
      if (_audioPlayerState == PlayerState.playing) {
        await player.pause();
        return;
      }

      final rawPath = widget.submission.voiceNotePath?.trim();
      if (rawPath == null || rawPath.isEmpty) {
        return;
      }

      final file = _resolveLocalFile(rawPath);

      if (!_audioHasStarted) {
        await player.play(DeviceFileSource(file.path));
        _audioHasStarted = true;
        return;
      }

      final shouldRestart = _audioPlayerState == PlayerState.completed ||
          (_audioDuration != null &&
              _audioDuration != Duration.zero &&
              _audioPosition >=
                  _audioDuration! - const Duration(milliseconds: 250));

      if (shouldRestart) {
        await player.seek(Duration.zero);
      }

      await player.resume();
      _audioHasStarted = true;
    } catch (error, stackTrace) {
      debugPrint(
          'Voice note playback failed (${widget.submission.id}): $error');
      debugPrint('$stackTrace');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice note playback failed.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _formatAudioTimestamp(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controller?.dispose();
    _disposeAudioPlayer();
    super.dispose();
  }

  File _resolveLocalFile(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.startsWith('file://')) {
      return File.fromUri(Uri.parse(trimmed));
    }
    return File(trimmed);
  }

  Future<File?> _cacheRemoteVideo(
    Uri uri,
    MediaSubmission submission,
  ) async {
    if (kIsWeb) {
      return null;
    }

    try {
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Cache download failed (${submission.id}): status ${response.statusCode}',
        );
        return null;
      }

      final supportDir = await getApplicationSupportDirectory();
      final cacheDir = Directory(
        '${supportDir.path}${Platform.pathSeparator}media_cache',
      );
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final extension = _inferExtension(submission) ?? 'mp4';
      final filePath =
          '${cacheDir.path}${Platform.pathSeparator}${submission.id}.$extension';
      final file = File(filePath);

      final previousPath = submission.localVideoPath?.trim();
      if (previousPath != null &&
          previousPath.isNotEmpty &&
          previousPath != filePath) {
        try {
          final previousFile = _resolveLocalFile(previousPath);
          if (await previousFile.exists()) {
            await previousFile.delete();
          }
        } catch (error, stackTrace) {
          debugPrint(
              'Failed to clear old cached video (${submission.id}): $error');
          debugPrint('$stackTrace');
        }
      }

      await file.writeAsBytes(response.bodyBytes);
      submission.localVideoPath = file.path;
      await _store.updateLocalVideoPath(submission.id, file.path);
      return file;
    } catch (error, stackTrace) {
      debugPrint('Remote cache error (${submission.id}): $error');
      debugPrint('$stackTrace');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final submission = widget.submission;
    final mediaQuery = MediaQuery.of(context);
    final segments = submission.transcriptSegments.take(20).toList();
    final hasVoiceNote = submission.voiceNotePath?.trim().isNotEmpty ?? false;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: EdgeInsets.only(top: mediaQuery.size.height * 0.1),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Colors.white.withAlpha((0.06 * 255).round()),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                mediaQuery.viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.25 * 255).round()),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    submission.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${submission.creatorName} • ${submission.contactHandle}',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 16),
                  _buildVideoPlayer(),
                  const SizedBox(height: 12),
                  _buildVideoActions(submission),
                  if (hasVoiceNote) ...[
                    const SizedBox(height: 12),
                    _buildVoiceNoteSection(),
                  ],
                  const SizedBox(height: 20),
                  _buildInfoRow(submission),
                  const SizedBox(height: 16),
                  const Text(
                    'Script / captions',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.05 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      submission.captionScript,
                      style:
                          const TextStyle(color: Colors.white70, height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Auto-tags',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: submission.autoTags.isEmpty
                        ? [
                            _buildTagChip('Tags pending', inactive: true),
                          ]
                        : submission.autoTags
                            .take(16)
                            .map((tag) => _buildTagChip(tag))
                            .toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Transcript moments',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (segments.isEmpty)
                    Text(
                      'No transcript attached yet.',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.6 * 255).round()),
                      ),
                    )
                  else
                    Column(
                      children: segments
                          .map((segment) => _buildTranscriptTile(segment))
                          .toList(),
                    ),
                  const SizedBox(height: 20),
                  if (widget.onRequestPayout != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: widget.onRequestPayout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.payments),
                        label: const Text('Record payout'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_loadingVideo) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.05 * 255).round()),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_loadError != null) {
      return _buildVideoPlaceholder(
        icon: Icons.warning_amber_rounded,
        title: 'Video failed to load',
        message: _loadError!,
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _buildVideoPlaceholder(
        icon: Icons.videocam_off_outlined,
        title: 'Video not available',
        message: 'No video attached for this submission.',
      );
    }

    final aspectRatio = controller.value.aspectRatio == 0
        ? 16 / 9
        : controller.value.aspectRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
            });
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: VideoPlayer(controller),
                ),
              ),
              AnimatedOpacity(
                opacity: controller.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.45 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        VideoProgressIndicator(
          controller,
          allowScrubbing: true,
          colors: VideoProgressColors(
            playedColor: Colors.tealAccent,
            bufferedColor: Colors.white30,
            backgroundColor: Colors.white10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          controller.value.isPlaying
              ? 'Tap to pause playback.'
              : 'Tap to play loop.',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildVideoActions(MediaSubmission submission) {
    final hasLocal = submission.localVideoPath?.trim().isNotEmpty ?? false;
    final hasRemote = submission.videoUrl.trim().isNotEmpty;
    final canDownload = hasLocal || hasRemote;

    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: canDownload && !_downloading ? _downloadVideo : null,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: Colors.tealAccent.withAlpha((0.3 * 255).round()),
            ),
            foregroundColor: Colors.tealAccent,
          ),
          icon: _downloading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: Text(_downloading ? 'Preparing…' : 'Download clip'),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildSourceDescription()),
      ],
    );
  }

  Widget _buildSourceDescription() {
    late final String message;
    switch (_activeSource) {
      case _VideoSource.local:
        message = 'Stored locally for instant playback and export.';
        break;
      case _VideoSource.remote:
        message = 'Streaming from a linked URL. Download fetches a new copy.';
        break;
      case _VideoSource.none:
        message = widget.submission.videoUrl.trim().isEmpty &&
                (widget.submission.localVideoPath?.trim().isEmpty ?? true)
            ? 'No video attachment on this submission yet.'
            : 'Attempting to load the attached video…';
        break;
    }

    return Text(
      message,
      style: TextStyle(
        color: Colors.white.withAlpha((0.65 * 255).round()),
        fontSize: 13,
      ),
    );
  }

  Widget _buildVoiceNoteSection() {
    final submission = widget.submission;
    final hasVoiceNote = submission.voiceNotePath?.trim().isNotEmpty ?? false;
    if (!hasVoiceNote) {
      return const SizedBox.shrink();
    }

    BoxDecoration containerDecoration(Color borderColor) {
      return BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withAlpha((0.3 * 255).round())),
      );
    }

    if (_audioLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: containerDecoration(Colors.amberAccent),
        child: Row(
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Preparing voice note…',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_audioLoadError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: containerDecoration(Colors.redAccent),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _audioLoadError!,
                style: const TextStyle(color: Colors.redAccent, height: 1.3),
              ),
            ),
            IconButton(
              onPressed: () => _initializeAudio(),
              tooltip: 'Retry loading',
              icon: const Icon(Icons.refresh, color: Colors.redAccent),
            ),
          ],
        ),
      );
    }

    final duration = _audioDuration ?? submission.voiceNoteDuration;
    final effectivePosition = duration != null && _audioPosition > duration
        ? duration
        : _audioPosition;
    final durationLabel =
        duration != null ? _formatAudioTimestamp(duration) : 'Length pending';
    final positionLabel = _formatAudioTimestamp(effectivePosition);
    final progress = duration != null && duration.inMilliseconds > 0
        ? effectivePosition.inMilliseconds / duration.inMilliseconds
        : null;
    final isPlaying = _audioPlayerState == PlayerState.playing;
    final canControl = _audioPlayer != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: containerDecoration(Colors.amberAccent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withAlpha((0.2 * 255).round()),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: Colors.amberAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Creator voice note',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      duration != null
                          ? 'Length $durationLabel'
                          : 'Length pending',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: canControl ? () => _toggleAudioPlayback() : null,
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  color: Colors.amberAccent,
                  size: 30,
                ),
                tooltip: isPlaying ? 'Pause voice note' : 'Play voice note',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (progress != null) ...[
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
            ),
            const SizedBox(height: 6),
            Text(
              '$positionLabel • $durationLabel total',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ] else
            Text(
              positionLabel,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          const SizedBox(height: 8),
          Text(
            'Use this quick memo for approval context or licensing notes.',
            style: TextStyle(
              color: Colors.white.withAlpha((0.65 * 255).round()),
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlaceholder({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.06 * 255).round()),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.amberAccent, size: 36),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.3),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadVideo() async {
    final submission = widget.submission;
    if (_downloading) {
      return;
    }

    final localPath = submission.localVideoPath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      final file = _resolveLocalFile(localPath);
      if (await file.exists()) {
        try {
          await _shareFile(file, name: _suggestedFileName(submission));
        } catch (error, stackTrace) {
          debugPrint('Share failed (${submission.id}): $error');
          debugPrint('$stackTrace');
          _showSnack('Could not share the local video.',
              color: Colors.redAccent);
        }
        return;
      }
    }

    final remoteUrl = submission.videoUrl.trim();
    if (remoteUrl.isEmpty) {
      _showSnack('No downloadable video found for this submission.',
          color: Colors.orange);
      return;
    }

    final uri = Uri.tryParse(remoteUrl);
    if (uri == null || uri.scheme.isEmpty) {
      _showSnack('Video link is invalid.', color: Colors.orange);
      return;
    }

    setState(() {
      _downloading = true;
    });

    try {
      final file = await _downloadRemoteVideo(uri, submission);
      if (file == null) {
        _showSnack('Could not download this clip.', color: Colors.redAccent);
        return;
      }
      await _shareFile(file, name: _suggestedFileName(submission));
    } catch (error, stackTrace) {
      debugPrint('Download/share failed (${submission.id}): $error');
      debugPrint('$stackTrace');
      _showSnack('Could not download this clip.', color: Colors.redAccent);
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  Future<File?> _downloadRemoteVideo(
    Uri uri,
    MediaSubmission submission,
  ) async {
    try {
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Download failed (${submission.id}): status ${response.statusCode}',
        );
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = _suggestedFileName(submission);
      final tempPath =
          '${tempDir.path}${Platform.pathSeparator}download-$fileName';
      final file = File(tempPath);
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } catch (error, stackTrace) {
      debugPrint('Remote download error (${submission.id}): $error');
      debugPrint('$stackTrace');
      return null;
    }
  }

  Future<void> _shareFile(File file, {required String name}) async {
    await Share.shareXFiles(
      [XFile(file.path, name: name)],
      text: 'Media marketplace clip: ${widget.submission.title}',
    );
  }

  String _suggestedFileName(MediaSubmission submission) {
    final extension = _inferExtension(submission) ?? 'mp4';
    final base = submission.title.trim().toLowerCase();
    final sanitized = base
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .trim();
    final safeBase = sanitized.isEmpty ? 'clip' : sanitized;
    final idSuffix = submission.id.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$safeBase-$idSuffix.$extension';
  }

  String? _inferExtension(MediaSubmission submission) {
    return _extensionFromPath(submission.localVideoPath) ??
        _extensionFromPath(submission.videoUrl);
  }

  String? _extensionFromPath(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    final sanitized = path.split('?').first.split('#').first;
    final dotIndex = sanitized.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == sanitized.length - 1) {
      return null;
    }
    final ext = sanitized.substring(dotIndex + 1).toLowerCase();
    if (ext.length > 5) {
      return null;
    }
    return ext;
  }

  void _showSnack(String message, {Color color = Colors.white70}) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color.withAlpha((0.9 * 255).round()),
      ),
    );
  }

  Widget _buildInfoRow(MediaSubmission submission) {
    final wordCount = submission.captionScript
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildInfoBadge(
          Icons.timer_outlined,
          _formatDurationLabel(submission.videoDuration),
        ),
        _buildInfoBadge(Icons.auto_stories, 'Script $wordCount words'),
        _buildInfoBadge(
          Icons.closed_caption,
          '${submission.transcriptSegments.length} transcript clips',
        ),
        _buildInfoBadge(
          Icons.attach_money,
          'Ask ${_formatCurrency(submission.askingPrice)}',
        ),
      ],
    );
  }

  Widget _buildInfoBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String tag, {bool inactive = false}) {
    final background = inactive
        ? Colors.white.withAlpha((0.08 * 255).round())
        : Colors.tealAccent.withAlpha((0.2 * 255).round());
    final foreground = inactive ? Colors.white54 : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: foreground,
          fontWeight: inactive ? FontWeight.w500 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTranscriptTile(VideoTranscriptSegment segment) {
    final duration = segment.position;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.04 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withAlpha((0.18 * 255).round()),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _formatTimestamp(duration),
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              segment.text,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDurationLabel(Duration duration) {
    if (duration.inSeconds <= 0) {
      return 'Length pending';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _formatCurrency(double value) => 'NG\$${value.toStringAsFixed(2)}';
}

typedef _PayoutConfirmCallback = Future<void> Function(
  List<MediaSubmission> selected,
  String payoutHandle,
  String memo,
);

class _CashAppPayoutSheet extends StatefulWidget {
  const _CashAppPayoutSheet({
    required this.pending,
    required this.onConfirm,
    required this.payoutHandle,
    required this.payoutMethod,
    this.focus,
  });

  final List<MediaSubmission> pending;
  final MediaSubmission? focus;
  final _PayoutConfirmCallback onConfirm;
  final String payoutHandle;
  final String payoutMethod;

  @override
  State<_CashAppPayoutSheet> createState() => _CashAppPayoutSheetState();
}

class _CashAppPayoutSheetState extends State<_CashAppPayoutSheet> {
  late final TextEditingController _memoController;
  late Set<String> _selectedIds;
  late final String _payoutHandle;
  bool _processing = false;
  String? _errorMessage;

  String get _methodLabel => _describePayoutMethod(widget.payoutMethod);

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.focus != null
        ? {widget.focus!.id}
        : widget.pending.map((submission) => submission.id).toSet();
    _payoutHandle = widget.payoutHandle.trim();
    _memoController = TextEditingController();
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  double get _selectionTotal => widget.pending
      .where((submission) => _selectedIds.contains(submission.id))
      .fold<double>(
        0,
        (sum, submission) =>
            sum + (submission.approvedPayout ?? submission.askingPrice),
      );

  Future<void> _handleConfirm() async {
    final selected = widget.pending
        .where((submission) => _selectedIds.contains(submission.id))
        .toList(growable: false);
    if (selected.isEmpty) {
      setState(() {
        _errorMessage = 'Select at least one submission.';
      });
      return;
    }

    if (_payoutHandle.isEmpty) {
      setState(() {
        _errorMessage =
            'No payout destination saved. Ask the creator to update their payout details.';
      });
      return;
    }

    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm(
        selected,
        _payoutHandle,
        _memoController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _errorMessage = 'Failed to record payout: $error';
      });
    }
  }

  void _toggleSelection(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: EdgeInsets.only(top: mediaQuery.size.height * 0.2),
          decoration: BoxDecoration(
            color: const Color(0xFF101A2D),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Colors.white.withAlpha((0.08 * 255).round()),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                mediaQuery.viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.25 * 255).round()),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Log creator payout',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select creators, review the saved payout destination, and add an optional memo.',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.65 * 255).round()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.pending.length,
                      itemBuilder: (context, index) {
                        final submission = widget.pending[index];
                        final value =
                            submission.approvedPayout ?? submission.askingPrice;
                        final checked = _selectedIds.contains(submission.id);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (newValue) => _toggleSelection(
                            submission.id,
                            newValue ?? false,
                          ),
                          activeColor: Colors.tealAccent,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            submission.title,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            '${submission.contactHandle} • ${submission.creatorName}\n${_formatCurrency(value)}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.06 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withAlpha((0.15 * 255).round()),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payout destination',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.75 * 255).round()),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _payoutHandle.isEmpty
                              ? 'No payout details saved'
                              : '$_methodLabel: $_payoutHandle',
                          style: const TextStyle(color: Colors.white),
                        ),
                        if (_payoutHandle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Update or replace this in the Media Testing Lab payout settings.',
                            style: TextStyle(
                              color:
                                  Colors.white.withAlpha((0.55 * 255).round()),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _memoController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Reference code or reminder',
                      hintStyle: TextStyle(
                        color: Colors.white.withAlpha((0.45 * 255).round()),
                      ),
                      filled: true,
                      fillColor: Colors.white.withAlpha((0.08 * 255).round()),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withAlpha((0.2 * 255).round()),
                        ),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total selected',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        _formatCurrency(_selectionTotal),
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _processing
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _processing ? null : _handleConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.tealAccent,
                            foregroundColor: Colors.black,
                          ),
                          icon: _processing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check),
                          label: Text(
                            _processing ? 'Logging...' : 'Confirm payout',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double value) => 'NG\$${value.toStringAsFixed(2)}';
}
