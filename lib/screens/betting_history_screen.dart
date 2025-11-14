import 'package:flutter/material.dart';

import '../models/betting_models.dart';

class BettingHistoryScreen extends StatefulWidget {
  const BettingHistoryScreen({
    super.key,
    required this.entries,
  });

  final List<BettingHistoryEntry> entries;

  @override
  State<BettingHistoryScreen> createState() => _BettingHistoryScreenState();
}

class _BettingHistoryScreenState extends State<BettingHistoryScreen> with SingleTickerProviderStateMixin {
  int _selectedStatusIndex = 0; // 0=Pending, 1=Completed, 2=Rejected

  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    final sortedEntries = List<BettingHistoryEntry>.from(widget.entries)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final pendingEntries = sortedEntries.where((e) => e.status == TransactionStatus.pending).toList();
    final completedEntries = sortedEntries.where((e) => e.status == TransactionStatus.completed).toList();
    final rejectedEntries = sortedEntries.where((e) => e.status == TransactionStatus.rejected).toList();

    // Get filtered entries based on selection
    List<BettingHistoryEntry> filteredEntries;
    switch (_selectedStatusIndex) {
      case 0:
        filteredEntries = pendingEntries;
        break;
      case 1:
        filteredEntries = completedEntries;
        break;
      case 2:
        filteredEntries = rejectedEntries;
        break;
      default:
        filteredEntries = pendingEntries;
    }

    final statusCounts = {
      for (final status in TransactionStatus.values)
        status: sortedEntries.where((entry) => entry.status == status).length,
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _glassIconButton(
                      context: context,
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: const [
                          Text(
                            'History Overview',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Track every deposit and withdrawal',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFAEC0D6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildStatusSummary(context, statusCounts),
                const SizedBox(height: 16),
                Expanded(
                  child: filteredEntries.isEmpty
                      ? _buildEmptyState(context)
                      : _buildHistoryList(filteredEntries),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSummary(
    BuildContext context,
    Map<TransactionStatus, int> counts,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(43, 88, 118, 0.6),
            Color.fromRGBO(78, 67, 118, 0.48),
          ],
        ),
        border: Border.all(
          color: Colors.white.withAlpha((0.12 * 255).round()),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.25 * 255).round()),
            offset: const Offset(0, 18),
            blurRadius: 28,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.stacked_bar_chart_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Status overview',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final statuses = TransactionStatus.values;

              return Row(
                children: [
                  for (var i = 0; i < statuses.length; i++) ...[
                    if (i > 0) const SizedBox(width: spacing),
                    Expanded(
                      child: _buildFilterButton(
                        label: _statusLabel(statuses[i]),
                        count: counts[statuses[i]] ?? 0,
                        icon: _statusIcon(statuses[i]),
                        color: _statusColor(statuses[i]),
                        isSelected: _selectedStatusIndex == i,
                        onTap: () => setState(() => _selectedStatusIndex = i),
                      ),
                    ),
                    if (i < statuses.length - 1) const SizedBox(width: spacing),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<BettingHistoryEntry> entries) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final statusColor = _statusColor(entry.status);
          final amountColor = entry.isCredit
              ? const Color(0xFF81C784)
              : const Color(0xFFFF8A80);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.36),
                        Colors.white.withValues(alpha: 0.12),
                      ],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                  ),
                  child: Icon(entry.icon, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatCurrency(entry.amount, entry.isCredit),
                        style: TextStyle(
                          color: amountColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _statusIcon(entry.status),
                                color: statusColor,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _statusLabel(entry.status),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                color: Color(0xFFAEC0D6),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimestamp(entry.timestamp),
                                style: const TextStyle(
                                  color: Color(0xFFAEC0D6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (entry.receiptBytes != null)
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _showReceiptPreview(context, entry),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: const Color.fromRGBO(66, 165, 245, 0.16),
                                  border: Border.all(
                                    color: const Color.fromRGBO(66, 165, 245, 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.receipt_long_rounded, color: Color(0xFF42A5F5), size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'View receipt',
                                      style: TextStyle(
                                        color: Color(0xFF42A5F5),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withAlpha((0.04 * 255).round()),
        border: Border.all(
          color: Colors.white.withAlpha((0.08 * 255).round()),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.receipt_long_rounded, color: Colors.white38, size: 48),
            SizedBox(height: 12),
            Text(
              'No transactions yet',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Your recent deposits, withdrawals and game outcomes will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassIconButton({
    required BuildContext context,
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withAlpha((0.08 * 255).round()),
          border: Border.all(
            color: Colors.white.withAlpha((0.12 * 255).round()),
          ),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  static String _formatCurrency(double value, bool isCredit) {
    final prefix = isCredit ? '+' : '-';
  return '$prefix₦₲${value.toStringAsFixed(2)}';
  }

  static String _statusLabel(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.rejected:
        return 'Rejected';
    }
  }

  Widget _buildFilterButton({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected 
            ? color.withAlpha((0.25 * 255).round())
            : Colors.white.withAlpha((0.10 * 255).round()),
          border: Border.all(
            color: isSelected 
              ? color
              : color.withAlpha((0.45 * 255).round()),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withAlpha((0.3 * 255).round()),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : [],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.25 * 255).round()),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _statusIcon(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return Icons.timelapse_rounded;
      case TransactionStatus.completed:
        return Icons.check_circle_rounded;
      case TransactionStatus.rejected:
        return Icons.cancel_rounded;
    }
  }

  static Color _statusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return const Color(0xFFFFD54F);
      case TransactionStatus.completed:
        return const Color(0xFF81C784);
      case TransactionStatus.rejected:
        return const Color(0xFFE57373);
    }
  }

  void _showReceiptPreview(BuildContext context, BettingHistoryEntry entry) {
    final receipt = entry.receiptBytes;
    if (receipt == null) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF152238),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.memory(
                  receipt,
                  fit: BoxFit.contain,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: Colors.white70),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.receiptName ?? 'cash-app-receipt',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Submitted ${_formatTimestamp(entry.timestamp)} for ${entry.title}.',
                      style: const TextStyle(
                        color: Color(0xFFAEC0D6),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      final date = timestamp;
      return '${date.day.toString().padLeft(2, '0')} ${_monthLabel(date.month)} ${date.year}';
    }
  }

  static String _monthLabel(int month) {
    const months = [
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
    return months[month - 1];
  }
}
