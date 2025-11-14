import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'dart:convert';

enum PenaltyHistoryScope { growth, global }

class PenaltyHistoryScreen extends StatefulWidget {
  const PenaltyHistoryScreen({
    super.key,
    this.scope = PenaltyHistoryScope.growth,
  });

  final PenaltyHistoryScope scope;

  @override
  State<PenaltyHistoryScreen> createState() => _PenaltyHistoryScreenState();
}

class _PenaltyHistoryScreenState extends State<PenaltyHistoryScreen> {
  static const int _retentionDays = 2;
  List<Map<String, dynamic>> _penaltyHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPenaltyHistory();
  }

  Future<void> _loadPenaltyHistory() async {
    final prefs = await SharedPreferences.getInstance();

    final isGlobal = widget.scope == PenaltyHistoryScope.global;
    final username = isGlobal
        ? (prefs.getString('global_user_name') ??
            prefs.getString('Global_user_name') ??
            'NGMY User')
        : (prefs.getString('growth_user_name') ?? 'NGMY User');

    final penaltyKey = isGlobal
        ? '${username}_global_penalty_history'
        : '${username}_penalty_history';

    if (isGlobal) {
      final legacyKey = '${username}_penalty_history';
      if (prefs.containsKey(legacyKey)) {
        await prefs.remove(legacyKey);
      }
    }
    final penaltyList = prefs.getStringList(penaltyKey) ?? [];
    final cutoff = DateTime.now().subtract(const Duration(days: _retentionDays));
    final retainedStrings = <String>[];
    final retainedHistory = <Map<String, dynamic>>[];

    for (final record in penaltyList) {
      try {
        final decoded = jsonDecode(record) as Map<String, dynamic>;
        final date = DateTime.tryParse(decoded['date'] as String? ?? '');
        if (date != null && !date.isBefore(cutoff)) {
          retainedStrings.add(record);
          retainedHistory.add(decoded);
        }
      } catch (_) {
        // Skip malformed entries silently
      }
    }

    if (retainedStrings.length != penaltyList.length) {
      await prefs.setStringList(penaltyKey, retainedStrings);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _penaltyHistory = retainedHistory;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Penalty History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _penaltyHistory.isEmpty
              ? _buildEmptyState()
              : _buildPenaltyList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Penalties Applied',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re doing great! Keep checking in on time.',
            style: TextStyle(
              color: Colors.white.withAlpha((0.7 * 255).round()),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltyList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _penaltyHistory.length,
      itemBuilder: (context, index) {
        final penalty = _penaltyHistory[index];
        return _buildPenaltyCard(penalty);
      },
    );
  }

  Widget _buildPenaltyCard(Map<String, dynamic> penalty) {
    final date = DateTime.tryParse(penalty['date'] ?? '');
    final reason = penalty['reason'] ?? 'Unknown';
    final percentage = penalty['percentage'] ?? '0%';
    final amount = (penalty['amount'] as num?)?.toDouble() ?? 0.0;
    final balanceBefore = (penalty['balanceBefore'] as num?)?.toDouble() ?? 0.0;
    final balanceAfter = (penalty['balanceAfter'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.withAlpha((0.15 * 255).round()),
            Colors.red.withAlpha((0.05 * 255).round()),
          ],
        ),
        border: Border.all(
          color: Colors.red.withAlpha((0.3 * 255).round()),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade300,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha((0.3 * 255).round()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      percentage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow('Penalty Amount', '₦₲${amount.toStringAsFixed(2)}', Colors.red.shade300),
              const SizedBox(height: 6),
              _buildInfoRow('Balance Before', '₦₲${balanceBefore.toStringAsFixed(2)}', Colors.white70),
              const SizedBox(height: 6),
              _buildInfoRow('Balance After', '₦₲${balanceAfter.toStringAsFixed(2)}', Colors.white70),
              if (date != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.white.withAlpha((0.5 * 255).round()),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.5 * 255).round()),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha((0.7 * 255).round()),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
