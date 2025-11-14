import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/media_models.dart';
import '../services/media_submission_store.dart';

class _WithdrawalRequest {
  const _WithdrawalRequest({
    required this.amount,
    required this.method,
    required this.handle,
  });

  final double amount;
  final String method;
  final String handle;
}

class MediaTestingLabScreen extends StatefulWidget {
  const MediaTestingLabScreen({super.key});

  @override
  State<MediaTestingLabScreen> createState() => _MediaTestingLabScreenState();
}

class _MediaTestingLabScreenState extends State<MediaTestingLabScreen> {
  final MediaSubmissionStore _store = MediaSubmissionStore.instance;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _creatorController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _askingPriceController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _initializing = true;
  bool _isSubmitting = false;
  bool _isPickingVideo = false;
  bool _isWithdrawing = false;
  bool _isRecordingVoice = false;
  bool _isProcessingVoice = false;

  String? _pickedVideoPath;
  String? _voiceNotePath;
  String? _pendingVoiceNotePath;
  String? _voiceNoteCleanupCandidate;
  Duration? _voiceNoteDuration;
  DateTime? _voiceRecordingStartedAt;
  String? _voiceNoteError;

  @override
  void initState() {
    super.initState();
    _store.addListener(_handleStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _store.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
      });
    });
  }

  @override
  void dispose() {
    _store.removeListener(_handleStoreChanged);
    _titleController.dispose();
    _creatorController.dispose();
    _contactController.dispose();
    _askingPriceController.dispose();
    _captionController.dispose();
    if (_isRecordingVoice) {
      unawaited(_audioRecorder.stop());
    }
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }

  void _handleStoreChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Media Marketplace'),
        centerTitle: false,
      ),
      body: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          if (_initializing) {
            return const Center(child: CircularProgressIndicator());
          }

          final approved = _store.approvedSubmissions;
          return _buildMarketplaceContent(approved);
        },
      ),
    );
  }

  Widget _buildMarketplaceContent(List<MediaSubmission> approved) {
    final availableBalance = _store.pendingCreatorPayoutTotal;
    final lifetimeEarnings = _store.lifetimeCreatorEarningsTotal;
    final lifetimePaidOut = _store.lifetimeCreatorPayoutTotal;
    final pendingDeals = _store.pendingCreatorPayoutCount;
    final pendingReviewCount = _store.pendingSubmissions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroHeader(
            availableBalance: availableBalance,
            lifetimeEarnings: lifetimeEarnings,
            lifetimePaidOut: lifetimePaidOut,
            pendingDeals: pendingDeals,
            pendingReviewCount: pendingReviewCount,
          ),
          const SizedBox(height: 20),
          _buildSubmissionForm(),
          const SizedBox(height: 24),
          _buildMarketplaceList(approved),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeroHeader({
    required double availableBalance,
    required double lifetimeEarnings,
    required double lifetimePaidOut,
    required int pendingDeals,
    required int pendingReviewCount,
  }) {
    final canWithdraw = availableBalance > 0 && !_isWithdrawing;
    final payoutLabel =
        '$pendingDeals ${pendingDeals == 1 ? 'clip' : 'clips'} ready to withdraw';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF23355A), Color(0xFF3F2F63)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sell vetted clips',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload polished videos, attach scripts, and cash out once a license clears.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.12 * 255).round()),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Available balance',
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.75 * 255).round()),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatCurrency(availableBalance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        payoutLabel,
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.72 * 255).round()),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: canWithdraw ? _withdrawEarnings : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    minimumSize: const Size(0, 44),
                  ),
                  icon: _isWithdrawing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.account_balance_wallet_outlined),
                  label: Text(_isWithdrawing ? 'Processing...' : 'Withdraw'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Withdrawals land in your Money wallet instantly once your payout details are on file.',
            style: TextStyle(
              color: Colors.white.withAlpha((0.72 * 255).round()),
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildHeroMetric(
                  icon: Icons.local_play_outlined,
                  label: 'Lifetime approvals',
                  value: _formatCurrency(lifetimeEarnings),
                  accent: Colors.amberAccent,
                ),
                const SizedBox(width: 12),
                _buildHeroMetric(
                  icon: Icons.payments_outlined,
                  label: 'Withdrawn so far',
                  value: _formatCurrency(lifetimePaidOut),
                  accent: Colors.tealAccent,
                ),
                const SizedBox(width: 12),
                _buildHeroMetric(
                  icon: Icons.pending_actions_outlined,
                  label: 'In review',
                  value:
                      '$pendingReviewCount ${pendingReviewCount == 1 ? 'clip' : 'clips'}',
                  accent: Colors.purpleAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return SizedBox(
      width: 210,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((0.18 * 255).round()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withAlpha((0.1 * 255).round()),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.75 * 255).round()),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _withdrawEarnings() async {
    if (_isWithdrawing) {
      return;
    }

    final available = _store.pendingCreatorPayoutTotal;
    if (available <= 0) {
      _showSnack('No approved payouts are ready yet.', Colors.orange);
      return;
    }

    final request = await _promptForWithdrawalDetails(available);
    if (request == null) {
      return;
    }

    if ((request.amount - available).abs() > 0.01) {
      _showSnack(
        'Withdraw the full available balance (${_formatCurrency(available)}) to clear payouts.',
        Colors.orange,
      );
      return;
    }

    setState(() {
      _isWithdrawing = true;
    });

    try {
      await _store.updatePayoutDetails(
        method: request.method,
        handle: request.handle,
      );
      final withdrawn = await _store.withdrawAllApprovedPayouts();
      if (!mounted) {
        return;
      }

      if (withdrawn <= 0) {
        _showSnack('No approved payouts are ready yet.', Colors.orange);
        return;
      }

      final methodLabel = _describePayoutMethod(request.method);
      final handle = request.handle;
      _showSnack(
        'Logged ${_formatCurrency(withdrawn)} for $methodLabel ($handle). Money wallet was credited.',
        Colors.tealAccent,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('Could not withdraw funds: $error', Colors.redAccent);
    } finally {
      if (mounted) {
        setState(() {
          _isWithdrawing = false;
        });
      }
    }
  }

  Future<_WithdrawalRequest?> _promptForWithdrawalDetails(
      double available) async {
    final amountController = TextEditingController(
      text: available.toStringAsFixed(2),
    );
    final handleController =
        TextEditingController(text: _store.payoutHandle ?? '');
    String selectedMethod = _store.payoutMethod ?? 'cash_app';
    String? errorText;
    String? handleErrorText;

    String handleLabelFor(String method) {
      return method == 'wallet' ? 'Wallet address' : 'Cash App tag';
    }

    final result = await showModalBottomSheet<_WithdrawalRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 12,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1627),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withAlpha((0.08 * 255).round()),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Finalize withdrawal',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Available: ${_formatCurrency(available)}',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Withdrawal amount',
                        labelStyle: const TextStyle(color: Colors.white70),
                        errorText: errorText,
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
                      onChanged: (_) {
                        if (errorText != null) {
                          setSheetState(() {
                            errorText = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: selectedMethod,
                      items: const [
                        DropdownMenuItem(
                          value: 'cash_app',
                          child: Text('Cash App tag'),
                        ),
                        DropdownMenuItem(
                          value: 'wallet',
                          child: Text('Wallet address'),
                        ),
                      ],
                      dropdownColor: const Color(0xFF0F1627),
                      onChanged: (value) {
                        setSheetState(() {
                          selectedMethod = value ?? 'cash_app';
                          handleErrorText = null;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Payout method',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withAlpha((0.08 * 255).round()),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withAlpha((0.2 * 255).round()),
                          ),
                        ),
                      ),
                      iconEnabledColor: Colors.white,
                      iconDisabledColor: Colors.white54,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: handleController,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: handleLabelFor(selectedMethod),
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: selectedMethod == 'wallet'
                            ? '0xABC123...'
                            : r'Example: $CreatorTag',
                        errorText: handleErrorText,
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
                      onChanged: (_) {
                        if (handleErrorText != null) {
                          setSheetState(() {
                            handleErrorText = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We save these payout details for your next withdrawal.',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.6 * 255).round()),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color:
                                    Colors.white.withAlpha((0.4 * 255).round()),
                              ),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final sanitized =
                                  amountController.text.replaceAll(
                                RegExp(r'[^0-9\.]'),
                                '',
                              );
                              final parsed = double.tryParse(sanitized);
                              if (parsed == null || parsed <= 0) {
                                setSheetState(() {
                                  errorText = 'Enter a valid amount.';
                                });
                                return;
                              }
                              if (parsed - available > 0.01) {
                                setSheetState(() {
                                  errorText =
                                      'You only have ${_formatCurrency(available)} available.';
                                });
                                return;
                              }
                              final handle = handleController.text.trim();
                              if (handle.isEmpty) {
                                setSheetState(() {
                                  handleErrorText =
                                      'Enter where we should send the funds.';
                                });
                                return;
                              }
                              Navigator.of(context).pop(
                                _WithdrawalRequest(
                                  amount: parsed,
                                  method: selectedMethod,
                                  handle: handle,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Confirm'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    amountController.dispose();
    handleController.dispose();
    return result;
  }

  String _describePayoutMethod(String method) {
    switch (method) {
      case 'wallet':
        return 'Wallet address';
      case 'cash_app':
      default:
        return 'Cash App tag';
    }
  }

  Widget _buildSubmissionForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha((0.08 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Submit a video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _titleController,
            label: 'Video Title',
            icon: Icons.title,
            hintText: 'Give your clip a standout name',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _creatorController,
            label: 'Creator or Studio',
            icon: Icons.person_outline,
            hintText: 'How should we credit you?',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _contactController,
            label: 'Contact Handle or Email',
            icon: Icons.alternate_email,
            hintText: '@handle or you@example.com',
          ),
          const SizedBox(height: 12),
          _buildVideoPicker(),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _askingPriceController,
            label: 'Asking Price',
            icon: Icons.attach_money,
            hintText: 'NG\$ 120.00',
            prefixText: 'NG\$ ',
            inputType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          _buildMultilineField(
            controller: _captionController,
            label: 'Paste the script or captions',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitMedia,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_isSubmitting ? 'Submitting...' : 'Send to review'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPicker() {
    final hasSelection =
        _pickedVideoPath != null && _pickedVideoPath!.trim().isNotEmpty;
    final fileName = hasSelection ? _resolveFileName(_pickedVideoPath!) : null;
    final cameraSupported = !kIsWeb;
    final voiceSupported = !kIsWeb;
    final hasVoiceNote =
        _voiceNotePath != null && _voiceNotePath!.trim().isNotEmpty;
    final voiceFileName =
        hasVoiceNote ? _resolveFileName(_voiceNotePath!) : null;
    final voiceDurationLabel = _voiceNoteDuration != null
        ? _formatVoiceNoteDurationLabel(_voiceNoteDuration!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attach a video',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: _isPickingVideo
                  ? null
                  : () => _selectVideo(ImageSource.gallery),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withAlpha((0.12 * 255).round()),
                foregroundColor: Colors.tealAccent,
              ),
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('From gallery'),
            ),
            OutlinedButton.icon(
              onPressed: _isPickingVideo || !cameraSupported
                  ? null
                  : () => _selectVideo(ImageSource.camera),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: Colors.white.withAlpha((0.18 * 255).round()),
                ),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Record now'),
            ),
            OutlinedButton.icon(
              onPressed: !voiceSupported || _isProcessingVoice
                  ? null
                  : () => _handleVoiceNoteAction(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: Colors.amberAccent.withAlpha((0.3 * 255).round()),
                ),
                foregroundColor: Colors.amberAccent,
              ),
              icon: Icon(
                _isRecordingVoice
                    ? Icons.stop_circle_outlined
                    : Icons.mic_outlined,
              ),
              label: Text(
                _isRecordingVoice
                    ? 'Stop voice note'
                    : hasVoiceNote
                        ? 'Re-record voice note'
                        : 'Voice note',
              ),
            ),
          ],
        ),
        if (_isPickingVideo) ...[
          const SizedBox(height: 12),
          Row(
            children: const [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text(
                'Preparing video...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ] else if (hasSelection) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.06 * 255).round()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.tealAccent.withAlpha((0.2 * 255).round()),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.tealAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fileName ?? 'Video attached',
                    style: const TextStyle(color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: _isPickingVideo ? null : _clearPickedVideo,
                  icon: const Icon(Icons.close, color: Colors.white54),
                  tooltip: 'Remove video',
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'Upload directly and include your transcript so editors can search instantly.',
            style:
                TextStyle(color: Colors.white.withAlpha((0.6 * 255).round())),
          ),
        ],
        if (!cameraSupported)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Recording is disabled on this platform. Use the gallery upload option instead.',
              style:
                  TextStyle(color: Colors.white.withAlpha((0.5 * 255).round())),
            ),
          ),
        const SizedBox(height: 16),
        if (_isRecordingVoice) ...[
          Row(
            children: const [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text(
                'Recording voice note... tap stop when finished.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ] else if (_isProcessingVoice) ...[
          Row(
            children: const [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text(
                'Saving voice note...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ] else if (hasVoiceNote) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.05 * 255).round()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amberAccent.withAlpha((0.25 * 255).round()),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.mic, color: Colors.amberAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voiceFileName ?? 'Voice note attached',
                        style: const TextStyle(color: Colors.white70),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (voiceDurationLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Length $voiceDurationLabel',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _removeVoiceNote(),
                  icon: const Icon(Icons.close, color: Colors.white54),
                  tooltip: 'Remove voice note',
                ),
              ],
            ),
          ),
        ] else if (_voiceNoteError != null) ...[
          Text(
            _voiceNoteError!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ] else ...[
          Text(
            'Optional: record a quick voice note to describe the story or licensing terms.',
            style: TextStyle(
              color: Colors.white.withAlpha((0.6 * 255).round()),
            ),
          ),
        ],
        if (!voiceSupported)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Voice notes are unavailable on this platform. Use another device to attach audio guidance.',
              style: TextStyle(
                color: Colors.white.withAlpha((0.5 * 255).round()),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _selectVideo(ImageSource source) async {
    setState(() {
      _isPickingVideo = true;
    });

    try {
      final XFile? file = await _picker.pickVideo(source: source);
      if (!mounted) {
        return;
      }
      if (file == null) {
        setState(() {
          _isPickingVideo = false;
        });
        return;
      }

      final cachedPath = await _cachePickedVideo(file);
      setState(() {
        _pickedVideoPath = cachedPath ?? file.path;
        _isPickingVideo = false;
      });

      _showSnack(
        'Video attached. Add the script and submit when ready.',
        Colors.tealAccent,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPickingVideo = false;
      });
      _showSnack(
        'Could not access the camera or gallery: $error',
        Colors.redAccent,
      );
    }
  }

  void _clearPickedVideo() {
    setState(() {
      _pickedVideoPath = null;
    });
  }

  Future<String?> _cachePickedVideo(XFile file) async {
    if (kIsWeb) {
      return null;
    }
    try {
      final existingPath = file.path;
      if (existingPath.isNotEmpty && await _isWithinAppStorage(existingPath)) {
        return existingPath;
      }

      final supportDir = await getApplicationSupportDirectory();
      final uploadsDir = Directory(
        '${supportDir.path}${Platform.pathSeparator}media_uploads',
      );
      if (!await uploadsDir.exists()) {
        await uploadsDir.create(recursive: true);
      }

      final originalName =
          file.name.isNotEmpty ? file.name : _resolveFileName(file.path);
      final sanitizedName = _sanitizeFileName(originalName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destinationPath =
          '${uploadsDir.path}${Platform.pathSeparator}$timestamp-$sanitizedName';

      await file.saveTo(destinationPath);
      return destinationPath;
    } catch (error, stackTrace) {
      debugPrint('Failed to cache picked video: $error');
      debugPrint('$stackTrace');
      return null;
    }
  }

  Future<void> _handleVoiceNoteAction() async {
    if (_isProcessingVoice) {
      return;
    }

    if (_isRecordingVoice) {
      await _stopVoiceRecording();
      return;
    }

    final hasExisting =
        _voiceNotePath != null && _voiceNotePath!.trim().isNotEmpty;
    if (hasExisting) {
      final confirmed = await _confirmVoiceReplacement();
      if (!confirmed) {
        return;
      }
      await _removeVoiceNote();
    }

    await _startVoiceRecording();
  }

  Future<void> _startVoiceRecording() async {
    if (_isRecordingVoice || _isProcessingVoice) {
      return;
    }

    if (kIsWeb) {
      _showSnack(
          'Voice notes are not supported on this device.', Colors.orange);
      return;
    }

    try {
      if (!await _audioRecorder.hasPermission()) {
        _showSnack('Microphone permission denied.', Colors.redAccent);
        return;
      }

      if (await _audioRecorder.isRecording()) {
        return;
      }

      final supportDir = await getApplicationSupportDirectory();
      final voiceDir = Directory(
        '${supportDir.path}${Platform.pathSeparator}media_voice_notes',
      );
      if (!await voiceDir.exists()) {
        await voiceDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destinationPath =
          '${voiceDir.path}${Platform.pathSeparator}voice_note_$timestamp.m4a';

      _voiceNoteCleanupCandidate = _voiceNotePath;

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: destinationPath,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isRecordingVoice = true;
        _voiceRecordingStartedAt = DateTime.now();
        _pendingVoiceNotePath = destinationPath;
        _voiceNoteError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to start voice recording: $error');
      debugPrint('$stackTrace');
      if (mounted) {
        _showSnack('Could not start recording: $error', Colors.redAccent);
      }
      _voiceNoteCleanupCandidate = null;
    }
  }

  Future<bool> _confirmVoiceReplacement() async {
    if (!mounted) {
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1627),
          title: const Text(
            'Re-record voice note?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Recording again will replace your existing voice note.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
              ),
              child: const Text('Keep current'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
              ),
              child: const Text('Replace'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _stopVoiceRecording({bool cancel = false}) async {
    if (!_isRecordingVoice && _pendingVoiceNotePath == null) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isProcessingVoice = true;
    });

    try {
      final recordedPath = await _audioRecorder.stop();
      final path = recordedPath ?? _pendingVoiceNotePath;
      _pendingVoiceNotePath = null;

      if (cancel || path == null) {
        if (path != null) {
          await _deleteVoiceFile(path);
        }
        if (!mounted) {
          return;
        }
        setState(() {
          if (!cancel) {
            _voiceNoteError = 'Voice note was not saved. Please retry.';
          }
          _voiceNoteDuration = null;
        });
        return;
      }

      final duration = _voiceRecordingStartedAt == null
          ? null
          : DateTime.now().difference(_voiceRecordingStartedAt!);
      final normalizedDuration =
          duration == null || duration.inMilliseconds <= 500
              ? const Duration(seconds: 1)
              : duration;

      if (_voiceNoteCleanupCandidate != null &&
          _voiceNoteCleanupCandidate != path) {
        await _deleteVoiceFile(_voiceNoteCleanupCandidate!);
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _voiceNotePath = path;
        _voiceNoteDuration = normalizedDuration;
        _voiceNoteError = null;
      });
      _showSnack('Voice note attached.', Colors.tealAccent);
    } catch (error, stackTrace) {
      debugPrint('Failed to stop voice recording: $error');
      debugPrint('$stackTrace');
      if (mounted) {
        _showSnack('Could not save voice note: $error', Colors.redAccent);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecordingVoice = false;
          _isProcessingVoice = false;
          _voiceRecordingStartedAt = null;
        });
      } else {
        _isRecordingVoice = false;
        _isProcessingVoice = false;
        _voiceRecordingStartedAt = null;
      }
      _voiceNoteCleanupCandidate = null;
    }
  }

  Future<void> _removeVoiceNote() async {
    if (_isRecordingVoice || _isProcessingVoice) {
      return;
    }
    final path = _voiceNotePath;
    if (mounted) {
      setState(() {
        _voiceNotePath = null;
        _voiceNoteDuration = null;
        _voiceNoteError = null;
      });
    } else {
      _voiceNotePath = null;
      _voiceNoteDuration = null;
      _voiceNoteError = null;
    }
    _voiceNoteCleanupCandidate = null;
    _pendingVoiceNotePath = null;
    if (path == null) {
      return;
    }
    await _deleteVoiceFile(path);
    if (mounted) {
      _showSnack('Voice note removed.', Colors.white70);
    }
  }

  Future<void> _deleteVoiceFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to delete voice note: $error');
      debugPrint('$stackTrace');
    }
  }

  String _formatVoiceNoteDurationLabel(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<bool> _isWithinAppStorage(String path) async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      return path.startsWith(supportDir.path);
    } catch (_) {
      return false;
    }
  }

  String _sanitizeFileName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'upload.mp4';
    }
    final sanitized = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return sanitized.isEmpty ? 'upload.mp4' : sanitized;
  }

  String _resolveFileName(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isNotEmpty ? segments.last : path;
  }

  Widget _buildMarketplaceList(List<MediaSubmission> approved) {
    if (approved.isEmpty) {
      return _buildEmptyState(
        icon: Icons.hourglass_empty,
        title: 'No clips published',
        message:
            'Approved submissions will appear here with pricing and auto-tags.',
      );
    }

    return Column(
      children: approved.map(_buildMarketplaceCard).toList(),
    );
  }

  Widget _buildMarketplaceCard(MediaSubmission submission) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha((0.08 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  submission.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildStatusChip(submission.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${submission.creatorName} - ${_formatDuration(submission.videoDuration)}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildTagChips(submission.autoTags),
          ),
          const SizedBox(height: 12),
          Text(
            'Asking Price ${_formatCurrency(submission.askingPrice)}',
            style: const TextStyle(
              color: Colors.tealAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (submission.approvedPayout != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Creator payout ${_formatCurrency(submission.approvedPayout!)}',
                style: const TextStyle(color: Colors.white60),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                submission.localVideoPath != null &&
                        submission.localVideoPath!.trim().isNotEmpty
                    ? Icons.upload_file
                    : Icons.link,
                color: Colors.tealAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  submission.localVideoPath != null &&
                          submission.localVideoPath!.trim().isNotEmpty
                      ? 'Local upload available'
                      : submission.videoUrl.isNotEmpty
                          ? submission.videoUrl
                          : 'Asset attached',
                  style: const TextStyle(color: Colors.white54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            submission.contactHandle,
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTagChips(List<String> tags) {
    if (tags.isEmpty) {
      return <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.08 * 255).round()),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'No tags yet',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ];
    }

    return tags
        .map(
          (tag) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withAlpha((0.18 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        )
        .toList();
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.04 * 255).round()),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha((0.08 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white38, size: 48),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    String? hintText,
    String? prefixText,
    String? suffixText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.tealAccent),
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.white.withAlpha((0.4 * 255).round()),
        ),
        prefixText: prefixText,
        prefixStyle: const TextStyle(color: Colors.white70),
        suffixText: suffixText,
        suffixStyle: const TextStyle(color: Colors.white70),
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
    );
  }

  Widget _buildMultilineField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      maxLines: 6,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        labelStyle: const TextStyle(color: Colors.white70),
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
    );
  }

  Future<void> _submitMedia() async {
    FocusScope.of(context).unfocus();

    final title = _titleController.text.trim();
    final creator = _creatorController.text.trim();
    final contact = _contactController.text.trim();
    final priceRaw = _askingPriceController.text.trim();
    final caption = _captionController.text.trim();
    final hasLocalVideo =
        _pickedVideoPath != null && _pickedVideoPath!.trim().isNotEmpty;

    if ([title, creator, contact, priceRaw, caption]
        .any((value) => value.isEmpty)) {
      _showSnack('Please fill in every submission field.', Colors.orange);
      return;
    }

    if (!hasLocalVideo) {
      _showSnack('Attach a video so we can review it.', Colors.orange);
      return;
    }

    final askingPrice = double.tryParse(priceRaw);
    if (askingPrice == null || askingPrice <= 0) {
      _showSnack('Enter a positive asking price.', Colors.orange);
      return;
    }

    if (_voiceNotePath != null) {
      final voiceFile = File(_voiceNotePath!);
      if (!await voiceFile.exists()) {
        _showSnack(
            'Voice note file is missing. Record it again before submitting.',
            Colors.orange);
        return;
      }
    }

    final duration = _estimateDurationFromScript(caption);

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _store.submitMedia(
        title: title,
        creatorName: creator,
        contactHandle: contact,
        localVideoPath: hasLocalVideo ? _pickedVideoPath : null,
        voiceNotePath: _voiceNotePath,
        voiceNoteDuration: _voiceNoteDuration,
        videoLength: duration,
        askingPrice: askingPrice,
        captionScript: caption,
      );
      _clearSubmissionForm();
      _showSnack(
        'Submission received. We will review it shortly.',
        Colors.tealAccent,
      );
    } catch (error) {
      _showSnack('Could not save submission: $error', Colors.redAccent);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _clearSubmissionForm() {
    _titleController.clear();
    _creatorController.clear();
    _contactController.clear();
    _askingPriceController.clear();
    _captionController.clear();
    setState(() {
      _pickedVideoPath = null;
      _voiceNotePath = null;
      _voiceNoteDuration = null;
      _voiceNoteError = null;
      _voiceNoteCleanupCandidate = null;
      _pendingVoiceNotePath = null;
    });
  }

  void _showSnack(String message, Color color) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Duration _estimateDurationFromScript(String script) {
    final words =
        script.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
    if (words == 0) {
      return const Duration(minutes: 2);
    }
    var seconds = (words * 0.5).round();
    if (seconds < 30) {
      seconds = 30;
    } else if (seconds > 900) {
      seconds = 900;
    }
    return Duration(seconds: seconds);
  }

  String _formatCurrency(double value) => 'NG\$${value.toStringAsFixed(2)}';

  String _formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) {
      return 'Length review pending';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
}
