import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/betting_data_store.dart';
import '../models/betting_models.dart';

class AdminMoneyTransactionsScreen extends StatefulWidget {
  const AdminMoneyTransactionsScreen({super.key});

  @override
  State<AdminMoneyTransactionsScreen> createState() => _AdminMoneyTransactionsScreenState();
}

class _AdminMoneyTransactionsScreenState extends State<AdminMoneyTransactionsScreen> with SingleTickerProviderStateMixin {
  final _store = BettingDataStore.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Ensure store data is loaded from storage for admin access
    _initializeAdminTransactionStore();
  }

  Future<void> _initializeAdminTransactionStore() async {
    // Load saved transactions from storage to show pending deposits/withdrawals
    await _store.loadFromStorage();
    if (mounted) {
      setState(() {}); // Refresh UI with loaded data
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Transaction Management',
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF9800),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(
              icon: Icon(Icons.pending_actions),
              text: 'Pending',
            ),
            Tab(
              icon: Icon(Icons.check_circle),
              text: 'Completed',
            ),
            Tab(
              icon: Icon(Icons.cancel),
              text: 'Rejected',
            ),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildPendingTab(),
              _buildCompletedTab(),
              _buildRejectedTab(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingTab() {
    final pendingTransactions = _store.pendingTransactions;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCard(pendingTransactions, 'Pending Approvals', const Color(0xFFFF9800)),
          const SizedBox(height: 24),
          _buildTransactionsList(pendingTransactions, showActions: true),
        ],
      ),
    );
  }

  Widget _buildCompletedTab() {
    final completedTransactions = _store.completedTransactions;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCard(completedTransactions, 'Completed Transactions', const Color(0xFF4CAF50)),
          const SizedBox(height: 24),
          _buildTransactionsList(completedTransactions, showActions: false),
        ],
      ),
    );
  }

  Widget _buildRejectedTab() {
    final rejectedTransactions = _store.rejectedTransactions;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCard(rejectedTransactions, 'Rejected Transactions', const Color(0xFFF44336)),
          const SizedBox(height: 24),
          _buildTransactionsList(rejectedTransactions, showActions: false),
        ],
      ),
    );
  }

  Widget _buildStatsCard(List<BettingHistoryEntry> transactions, String title, Color accentColor) {
    final deposits = transactions.where((e) => e.category == TransactionCategory.deposit).length;
    final withdrawals = transactions.where((e) => e.category == TransactionCategory.withdraw).length;
    final totalAmount = transactions.fold<double>(0, (sum, e) => sum + e.amount);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withAlpha((0.2 * 255).round()),
            accentColor.withAlpha((0.1 * 255).round()),
          ],
        ),
        border: Border.all(
          color: accentColor.withAlpha((0.3 * 255).round()),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    title.contains('Pending') 
                      ? Icons.pending_actions 
                      : title.contains('Completed')
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: accentColor,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Deposits', '$deposits', Icons.download_rounded, const Color(0xFF26A69A)),
                  _buildStatItem('Withdrawals', '$withdrawals', Icons.upload_rounded, const Color(0xFFFF7043)),
                  _buildStatItem('Total', '₦₲${totalAmount.toStringAsFixed(0)}', Icons.attach_money, const Color(0xFFFFD54F)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha((0.2 * 255).round()),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList(List<BettingHistoryEntry> transactions, {required bool showActions}) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.white.withAlpha((0.3 * 255).round()),
            ),
            const SizedBox(height: 16),
            Text(
              showActions ? 'No pending transactions' : 'No transactions',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              showActions 
                ? 'All deposits and withdrawals are processed!' 
                : 'No transactions found in this category',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          showActions ? 'Pending Transactions' : 'Transaction History',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...transactions.map((transaction) => _buildTransactionCard(transaction, showActions: showActions)),
      ],
    );
  }

  Widget _buildTransactionCard(BettingHistoryEntry transaction, {required bool showActions}) {
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withAlpha((0.3 * 255).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: transaction.color.withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(transaction.icon, color: transaction.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(transaction.timestamp),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₦₲${transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: transaction.color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (transaction.receiptBytes != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withAlpha((0.3 * 255).round())),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt, color: Colors.blue, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    transaction.receiptName ?? 'Receipt attached',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveTransaction(transaction),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _rejectTransaction(transaction),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.cancel, size: 20),
                    label: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  void _approveTransaction(BettingHistoryEntry transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve Transaction?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Approve ${transaction.title} for ₦₲${transaction.amount.toStringAsFixed(2)}?\n\n'
          'The user\'s balance will be ${transaction.isCredit ? "increased" : "decreased"}.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              _store.approveTransaction(transaction.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaction approved!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _rejectTransaction(BettingHistoryEntry transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Transaction?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Reject ${transaction.title} for ₦₲${transaction.amount.toStringAsFixed(2)}?\n\n'
          'The transaction will be marked as rejected and no balance changes will occur.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              _store.rejectTransaction(transaction.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaction rejected.'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
