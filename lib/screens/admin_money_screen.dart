import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/betting_entities.dart';
import '../services/betting_data_store.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/floating_header.dart';
import 'admin_money_transactions_screen.dart';

class AdminMoneyScreen extends StatefulWidget {
  const AdminMoneyScreen({super.key});

  @override
  State<AdminMoneyScreen> createState() => _AdminMoneyScreenState();
}

class _AdminMoneyScreenState extends State<AdminMoneyScreen> {
  final BettingDataStore _store = BettingDataStore.instance;

  late final TextEditingController _usernameController;
  late final TextEditingController _userIdController;
  late final VoidCallback _storeListener;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: _store.username);
    _userIdController = TextEditingController(text: _store.userId);
    _storeListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    _store.addListener(_storeListener);
    
    // Ensure store data is loaded from storage
    _initializeAdminStore();
  }

  Future<void> _initializeAdminStore() async {
    // Load saved transactions and user data from storage
    await _store.loadFromStorage();
    if (mounted) {
      setState(() {
        // Update controllers with loaded data
        _usernameController.text = _store.username;
        _userIdController.text = _store.userId;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _userIdController.dispose();
    _store.removeListener(_storeListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyPreview = _store.history.take(6).toList();
  final gameEntries = kGameCatalogue.entries
    .where((entry) => !entry.value.hidden)
    .toList();

    return Scaffold(
      backgroundColor: Colors.black.withAlpha((0.9 * 255).round()),
      appBar: FloatingHeader(
        title: 'Money & Betting Controls',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Profile identity',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.white70),
                        onPressed: _searchUserByID,
                        tooltip: 'Search User by ID',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _textFieldDecoration(
                      label: 'Display name',
                      icon: Icons.person_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _userIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _textFieldDecoration(
                      label: 'User ID / account number',
                      icon: Icons.badge_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _updateIdentity,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF26C6DA),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save profile'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Transaction Approvals Section
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transaction Management', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _openTransactionApprovals,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.pending_actions),
                        if (_store.pendingTransactions.isNotEmpty)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '${_store.pendingTransactions.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    label: const Text('Approve Deposits & Withdrawals'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Logo Management', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 12),
                  Text(
                    'Upload a payment logo that will appear in all deposit screens across the app',
                    style: TextStyle(color: Colors.white.withAlpha((0.5 * 255).round()), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (_store.paymentLogoBytes != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.05 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withAlpha((0.1 * 255).round())),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _store.paymentLogoBytes!,
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _uploadPaymentLogo,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                  ),
                                  icon: const Icon(Icons.upload_file, size: 18),
                                  label: const Text('Change Logo'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _removePaymentLogo,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  icon: const Icon(Icons.delete, size: 18),
                                  label: const Text('Remove'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: _uploadPaymentLogo,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Payment Logo'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Game availability', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  for (final entry in gameEntries) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.08 * 255).round()),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withAlpha((0.12 * 255).round())),
                      ),
                      child: SwitchListTile(
                        value: _store.isGameEnabled(entry.key),
                        onChanged: (value) => _toggleGame(entry.key, value),
                        activeThumbColor: entry.value.accent,
                        title: Text(
                          entry.value.title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          entry.value.description,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _confirmClearHistory,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE57373),
                            side: const BorderSide(color: Color(0xFFE57373)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.delete_sweep_rounded),
                          label: const Text('Clear history'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _confirmClearResults,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFF06292),
                            side: const BorderSide(color: Color(0xFFF06292)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.auto_delete_rounded),
                          label: const Text('Clear results'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Game Probability Controls',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap a game to expand and configure outcome probabilities',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildWheelOfFortuneExpansion(),
            const SizedBox(height: 12),
            _buildLuckySlotsExpansion(),
            const SizedBox(height: 12),
            _buildPrizeBoxExpansion(),
            const SizedBox(height: 12),
            _buildColorSpinnerExpansion(),
            const SizedBox(height: 24),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent transactions', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (historyPreview.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.05 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withAlpha((0.1 * 255).round())),
                      ),
                      child: const Text('No transactions yet.', style: TextStyle(color: Colors.white54)),
                    )
                  else
                    Column(
                      children: [
                        for (final entry in historyPreview)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha((0.06 * 255).round()),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withAlpha((0.12 * 255).round())),
                            ),
                            child: Row(
                              children: [
                                Icon(entry.icon, color: Colors.white70),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(entry.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text(
                                        entry.timestamp.toLocal().toString().split('.').first,
                                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                      if (entry.receiptName != null && entry.receiptName!.isNotEmpty)
                                        Text(
                                          entry.receiptName!,
                                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  (entry.isCredit ? '+' : '-') + _formatCurrency(entry.amount),
                                  style: TextStyle(
                                    color: entry.isCredit ? const Color(0xFF81C784) : const Color(0xFFFF8A80),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  InputDecoration _textFieldDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white54),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.white30),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF26C6DA)),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final isNegative = amount < 0;
    final absolute = amount.abs();
    final parts = absolute.toStringAsFixed(2).split('.');
    final integer = parts.first;
    final buffer = StringBuffer();

    for (var i = 0; i < integer.length; i++) {
      buffer.write(integer[i]);
      final remaining = integer.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(',');
      }
    }

    final fractional = parts.length > 1 ? parts[1] : '00';
    final formatted = buffer.toString();
    return '${isNegative ? '-' : ''}₦₲$formatted.$fractional';
  }

  Future<double?> _promptDoubleInput({
    required String title,
    required String label,
    required double initialValue,
    double? min,
    double? max,
  }) async {
    final controller = TextEditingController(text: initialValue.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Enter value',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final raw = controller.text.trim().replaceAll(',', '');
              final value = double.tryParse(raw);
              if (value == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid number.')),
                );
                return;
              }
              if (min != null && value < min) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Value must be at least ${min.toStringAsFixed(2)}.')),
                );
                return;
              }
              if (max != null && value > max) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Value must not exceed ${max.toStringAsFixed(2)}.')),
                );
                return;
              }
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _promptEditJackpotAmount() async {
    final result = await _promptDoubleInput(
      title: 'Set progressive jackpot amount',
      label: 'Jackpot pool (₦₲)',
      initialValue: _store.slotJackpot,
      min: 0,
    );
    if (result != null) {
      _store.setSlotJackpot(result);
      _showSnack('Progressive jackpot set to ${_formatCurrency(result)}.', color: const Color(0xFFFFD54F));
    }
  }

  Future<void> _promptEditJackpotSeed() async {
    final result = await _promptDoubleInput(
      title: 'Update jackpot seed',
      label: 'Seed amount (₦₲)',
      initialValue: _store.slotJackpotSeed,
      min: 0,
    );
    if (result != null) {
      _store.setSlotJackpotSeed(result);
      _showSnack('Jackpot seed updated to ${_formatCurrency(result)}.', color: const Color(0xFFFFD54F));
    }
  }

  Future<void> _promptEditJackpotRate() async {
    final result = await _promptDoubleInput(
      title: 'Set contribution rate',
      label: 'Contribution % per spin',
      initialValue: _store.slotJackpotContributionRate * 100,
      min: 0,
      max: 100,
    );
    if (result != null) {
      _store.setSlotJackpotContributionRate(result / 100);
      _showSnack('Contribution rate set to ${result.toStringAsFixed(1)}%.', color: const Color(0xFFFFD54F));
    }
  }

  void _resetProgressiveJackpot() {
    _store.resetSlotJackpot();
    _showSnack('Progressive jackpot reset to seed.', color: const Color(0xFFFFD54F));
  }

  void _injectProgressiveJackpot(double amount) {
    if (amount <= 0) {
      return;
    }
    _store.injectSlotJackpot(amount);
    _showSnack('Added ${_formatCurrency(amount)} to the jackpot.', color: const Color(0xFFFFD54F));
  }

  void _updateIdentity() {
    final name = _usernameController.text.trim();
    final id = _userIdController.text.trim();
    if (name.isNotEmpty) {
      _store.updateUsername(name);
    }
    if (id.isNotEmpty) {
      _store.updateUserId(id);
    }
    _showSnack('Profile details updated.', color: const Color(0xFF26C6DA));
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear transaction history?'),
            content: const Text('This will permanently remove all wallet records for this session.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Clear history')),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      _store.clearHistory();
      _showSnack('History cleared.', color: const Color(0xFFE53935));
    }
  }

  Future<void> _confirmClearResults() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear game results?'),
            content: const Text('All recorded game outcomes will be removed.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Clear results')),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      _store.clearResults();
      _showSnack('Game results cleared.', color: const Color(0xFFE53935));
    }
  }

  void _openTransactionApprovals() {
    // Open admin transaction approvals screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminMoneyTransactionsScreen(),
      ),
    );
  }

  Future<void> _uploadPaymentLogo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        
        _store.setPaymentLogoBytes(bytes);
        _showSnack('Payment logo uploaded successfully!', color: Colors.green);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error uploading logo: $e', color: Colors.red);
    }
  }

  void _removePaymentLogo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Payment Logo?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will remove the payment logo from all deposit screens in the app.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              _store.setPaymentLogoBytes(null);
              Navigator.pop(context);
              _showSnack('Payment logo removed successfully', color: Colors.green);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _searchUserByID() {
    // Open user search dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User search by ID - Coming soon!')),
    );
  }

  void _toggleGame(GameType type, bool enabled) {
    _store.setGameEnabled(type, enabled);
  }

  void _resetWheelProbabilities() {
    _store.resetWheelSegments();
    _showSnack('Wheel probabilities reset to default.', color: const Color(0xFF7C9EFF));
  }

  void _normalizeWheelWeights() {
    _store.normalizeWheelWeights();
    _showSnack('Wheel weights normalized to 100%.', color: const Color(0xFF26C6DA));
  }

  Widget _buildWheelOfFortuneExpansion() {
    return GlassCard(
      padding: const EdgeInsets.all(0),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF7C9EFF).withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.casino_rounded, color: Color(0xFF7C9EFF), size: 24),
          ),
          title: const Text(
            'Wheel of Fortune',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          subtitle: const Text(
            'Configure spin outcome probabilities',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _resetWheelProbabilities,
                icon: const Icon(Icons.refresh, size: 20),
                color: const Color(0xFF7C9EFF),
                tooltip: 'Reset',
              ),
              IconButton(
                onPressed: _normalizeWheelWeights,
                icon: const Icon(Icons.balance, size: 20),
                color: const Color(0xFF26C6DA),
                tooltip: 'Normalize',
              ),
              const Icon(Icons.expand_more, color: Colors.white54),
            ],
          ),
          children: [
            const Text(
              'Control the likelihood of each outcome. Higher weights = more common.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ..._buildWheelSegmentControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildLuckySlotsExpansion() {
    return GlassCard(
      padding: const EdgeInsets.all(0),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD54F).withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.view_column_rounded, color: Color(0xFFFFD54F), size: 24),
          ),
          title: const Text(
            'Lucky Slots',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          subtitle: const Text(
            'Control symbol appearance rates',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  _store.resetSlotSymbols();
                  _showSnack('Lucky Slots reset to default.', color: const Color(0xFFFFD54F));
                },
                icon: const Icon(Icons.refresh, size: 20),
                color: const Color(0xFFFFD54F),
                tooltip: 'Reset',
              ),
              IconButton(
                onPressed: () {
                  _store.normalizeSlotWeights();
                  _showSnack('Slot weights normalized to 100%.', color: const Color(0xFF26C6DA));
                },
                icon: const Icon(Icons.balance, size: 20),
                color: const Color(0xFF26C6DA),
                tooltip: 'Normalize',
              ),
              const Icon(Icons.expand_more, color: Colors.white54),
            ],
          ),
          children: [
            _buildProgressiveJackpotAdminCard(),
            const SizedBox(height: 16),
            const Text(
              'Control which symbols appear on each reel. Higher weights = more frequent.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ..._buildSlotSymbolControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrizeBoxExpansion() {
    return GlassCard(
      padding: const EdgeInsets.all(0),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF26A69A).withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF26A69A), size: 24),
          ),
          title: const Text(
            'Prize Box',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          subtitle: const Text(
            'Configure box prize probabilities',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  _store.resetPrizeBoxes();
                  _showSnack('Prize Box reset to default.', color: const Color(0xFF26A69A));
                },
                icon: const Icon(Icons.refresh, size: 20),
                color: const Color(0xFF26A69A),
                tooltip: 'Reset',
              ),
              IconButton(
                onPressed: () {
                  _store.normalizePrizeBoxWeights();
                  _showSnack('Prize box weights normalized to 100%.', color: const Color(0xFF26C6DA));
                },
                icon: const Icon(Icons.balance, size: 20),
                color: const Color(0xFF26C6DA),
                tooltip: 'Normalize',
              ),
              const Icon(Icons.expand_more, color: Colors.white54),
            ],
          ),
          children: [
            const Text(
              'Control what prizes are hidden in boxes. Higher weights = more likely prizes.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ..._buildPrizeBoxControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSpinnerExpansion() {
    return GlassCard(
      padding: const EdgeInsets.all(0),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350).withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.palette_rounded, color: Color(0xFFEF5350), size: 24),
          ),
          title: const Text(
            'Color Spinner',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          subtitle: const Text(
            'Control color landing probabilities',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  _store.resetColorSegments();
                  _showSnack('Color Spinner reset to default.', color: const Color(0xFFEF5350));
                },
                icon: const Icon(Icons.refresh, size: 20),
                color: const Color(0xFFEF5350),
                tooltip: 'Reset',
              ),
              IconButton(
                onPressed: () {
                  _store.normalizeColorWeights();
                  _showSnack('Color weights normalized to 100%.', color: const Color(0xFF26C6DA));
                },
                icon: const Icon(Icons.balance, size: 20),
                color: const Color(0xFF26C6DA),
                tooltip: 'Normalize',
              ),
              const Icon(Icons.expand_more, color: Colors.white54),
            ],
          ),
          children: [
            const Text(
              'Control which colors the spinner lands on. Higher weights = more frequent.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ..._buildColorSegmentControls(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWheelSegmentControls() {
    final segments = _store.wheelSegments;
    if (segments.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.05 * 255).round()),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha((0.1 * 255).round())),
          ),
          child: const Text(
            'No wheel segments configured.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ];
    }

    return segments.map((segment) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: segment.color.withAlpha((0.15 * 255).round()),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha((0.18 * 255).round())),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: segment.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  segment.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  segment.multiplier == 0
                      ? '(No payout)'
                      : '(${segment.multiplier.toStringAsFixed(1)}x payout)',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  'Weight: ${segment.weight.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: segment.weight,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: segment.color,
                    inactiveColor: segment.color.withAlpha((0.3 * 255).round()),
                    onChanged: (value) {
                      _store.updateWheelSegmentWeight(segment.id, value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${(segment.weight / _store.wheelSegments.fold(0.0, (sum, s) => sum + s.weight) * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildSlotSymbolControls() {
    final symbols = _store.slotSymbols;
    if (symbols.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.05 * 255).round()),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha((0.1 * 255).round())),
          ),
          child: const Text(
            'No slot symbols found.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ];
    }

    return symbols.map((symbol) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: symbol.color.withAlpha((0.15 * 255).round()),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha((0.18 * 255).round())),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  symbol.symbol,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  symbol.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${symbol.multiplier}x)',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (symbol.isProgressive) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F).withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD54F)),
                    ),
                    child: const Text(
                      'Jackpot',
                      style: TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  'Weight: ${symbol.weight.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: symbol.weight,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: symbol.color,
                    inactiveColor: symbol.color.withAlpha((0.3 * 255).round()),
                    onChanged: (value) {
                      _store.updateSlotSymbolWeight(symbol.id, value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${(symbol.weight / _store.slotSymbols.fold(0.0, (sum, s) => sum + s.weight) * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildProgressiveJackpotAdminCard() {
    final jackpot = _store.slotJackpot;
    final seed = _store.slotJackpotSeed;
    final ratePercent = (_store.slotJackpotContributionRate * 100).clamp(0.0, 100.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha((0.12 * 255).round())),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD54F).withAlpha((0.20 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bolt_rounded, color: Color(0xFFFFD54F), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Progressive Jackpot',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              TextButton(
                onPressed: _resetProgressiveJackpot,
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFD54F)),
                child: const Text('Reset to seed'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Current pot: ${_formatCurrency(jackpot)}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Seed amount: ${_formatCurrency(seed)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Contribution rate: ${ratePercent.toStringAsFixed(1)}% per spin',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _promptEditJackpotAmount,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withAlpha((0.35 * 255).round())),
                ),
                icon: const Icon(Icons.savings_outlined, size: 18),
                label: const Text('Set pot'),
              ),
              OutlinedButton.icon(
                onPressed: _promptEditJackpotSeed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withAlpha((0.35 * 255).round())),
                ),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Edit seed'),
              ),
              OutlinedButton.icon(
                onPressed: _promptEditJackpotRate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withAlpha((0.35 * 255).round())),
                ),
                icon: const Icon(Icons.percent, size: 18),
                label: const Text('Edit rate'),
              ),
              OutlinedButton.icon(
                onPressed: () => _injectProgressiveJackpot(5000),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withAlpha((0.35 * 255).round())),
                ),
                icon: const Icon(Icons.add_card, size: 18),
                label: const Text('Inject ₦₲5,000'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPrizeBoxControls() {
    final prizes = _store.prizeBoxes;
    if (prizes.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.05 * 255).round()),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha((0.1 * 255).round())),
          ),
          child: const Text(
            'No prize boxes found.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ];
    }

    return prizes.map((prize) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: prize.color.withAlpha((0.15 * 255).round()),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha((0.18 * 255).round())),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: prize.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  prize.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${prize.multiplier}x)',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  'Weight: ${prize.weight.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: prize.weight,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: prize.color,
                    inactiveColor: prize.color.withAlpha((0.3 * 255).round()),
                    onChanged: (value) {
                      _store.updatePrizeBoxWeight(prize.id, value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${(prize.weight / _store.prizeBoxes.fold(0.0, (sum, p) => sum + p.weight) * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildColorSegmentControls() {
    final segments = _store.colorSegments;
    if (segments.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.05 * 255).round()),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha((0.1 * 255).round())),
          ),
          child: const Text(
            'No color segments found.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ];
    }

    return segments.map((segment) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: segment.color.withAlpha((0.15 * 255).round()),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha((0.18 * 255).round())),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: segment.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  segment.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${segment.multiplier}x)',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  'Weight: ${segment.weight.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: segment.weight,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: segment.color,
                    inactiveColor: segment.color.withAlpha((0.3 * 255).round()),
                    onChanged: (value) {
                      _store.updateColorSegmentWeight(segment.id, value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${(segment.weight / _store.colorSegments.fold(0.0, (sum, s) => sum + s.weight) * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  void _showSnack(String message, {Color color = const Color(0xFF667eea)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
