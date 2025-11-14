import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/payment_proof.dart';

class FamilyTreeInvestmentScreen extends StatefulWidget {
  const FamilyTreeInvestmentScreen({super.key});

  @override
  State<FamilyTreeInvestmentScreen> createState() =>
      _FamilyTreeInvestmentScreenState();
}

class _FamilyTreeInvestmentScreenState
    extends State<FamilyTreeInvestmentScreen> {
  double _currentInvestment = 0.0;
  double _dailyEarnings = 0.0;
  double? _pendingProofAmount;
  static const double _dailyReturnRate =
      0.0333; // 3.33% per day for Family Tree
  static const int _workingDaysPerMonth = 20; // Monday-Friday over four weeks
  bool _isAccountDisabled = false;
  bool _isAccountBanned = false;
  DateTime? _accountSuspendedUntil;
  bool get _isAccountSuspended =>
      _accountSuspendedUntil != null &&
      DateTime.now().isBefore(_accountSuspendedUntil!);
  bool get _isAccountLocked =>
      _isAccountBanned || _isAccountDisabled || _isAccountSuspended;

  String _paymentMethod = 'cashapp';
  String _cashAppTag = r'$NGMYPay';
  String _cashAppLink = '';
  String _cryptoAddress = '';
  String _cryptoWalletLabel = '';
  String _cryptoWalletNote = '';

  // Family Tree specific investment tiers with attractive green-based colors
  final List<Map<String, dynamic>> _investmentTiers = [
    // Green Tier (₦₲10-50)
    {
      'amount': 10.0,
      'color': const Color(0xFF4CAF50),
      'tier': 'Green',
      'icon': Icons.attach_money
    },
    {
      'amount': 20.0,
      'color': const Color(0xFF66BB6A),
      'tier': 'Green',
      'icon': Icons.attach_money
    },
    {
      'amount': 50.0,
      'color': const Color(0xFF81C784),
      'tier': 'Green',
      'icon': Icons.attach_money
    },
    // Silver Tier (₦₲100-2000)
    {
      'amount': 100.0,
      'color': const Color(0xFF9E9E9E),
      'tier': 'Silver',
      'icon': Icons.star
    },
    {
      'amount': 300.0,
      'color': const Color(0xFFBDBDBD),
      'tier': 'Silver',
      'icon': Icons.star
    },
    {
      'amount': 500.0,
      'color': const Color(0xFFE0E0E0),
      'tier': 'Silver',
      'icon': Icons.stars
    },
    {
      'amount': 1000.0,
      'color': const Color(0xFFE8E8E8),
      'tier': 'Silver',
      'icon': Icons.diamond_outlined
    },
    {
      'amount': 2000.0,
      'color': const Color(0xFFF5F5F5),
      'tier': 'Silver',
      'icon': Icons.diamond
    },
    // Gold Tier (₦₲2500-4500)
    {
      'amount': 2500.0,
      'color': const Color(0xFFFFD700),
      'tier': 'Gold',
      'icon': Icons.workspace_premium
    },
    {
      'amount': 3000.0,
      'color': const Color(0xFFFFE135),
      'tier': 'Gold',
      'icon': Icons.military_tech
    },
    {
      'amount': 3500.0,
      'color': const Color(0xFFFFE66D),
      'tier': 'Gold',
      'icon': Icons.emoji_events
    },
    {
      'amount': 4000.0,
      'color': const Color(0xFFFFEB8C),
      'tier': 'Gold',
      'icon': Icons.shield
    },
    {
      'amount': 4500.0,
      'color': const Color(0xFFFFF2A8),
      'tier': 'Gold',
      'icon': Icons.auto_awesome
    },
    // Platinum Tier (₦₲5000-25000)
    {
      'amount': 5000.0,
      'color': const Color(0xFFB39DDB),
      'tier': 'Platinum',
      'icon': Icons.grade
    },
    {
      'amount': 7500.0,
      'color': const Color(0xFF9C27B0),
      'tier': 'Platinum',
      'icon': Icons.local_fire_department
    },
    {
      'amount': 8000.0,
      'color': const Color(0xFFAB47BC),
      'tier': 'Platinum',
      'icon': Icons.flash_on
    },
    {
      'amount': 10000.0,
      'color': const Color(0xFFBA68C8),
      'tier': 'Platinum',
      'icon': Icons.bolt
    },
    {
      'amount': 15000.0,
      'color': const Color(0xFFCE93D8),
      'tier': 'Platinum',
      'icon': Icons.electric_bolt
    },
    {
      'amount': 20000.0,
      'color': const Color(0xFFE1BEE7),
      'tier': 'Platinum',
      'icon': Icons.castle
    },
    {
      'amount': 25000.0,
      'color': const Color(0xFFF3E5F5),
      'tier': 'Platinum',
      'icon': Icons.account_balance
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadInvestment();
  }

  Future<void> _loadInvestment() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';

    // Load from Family Tree specific keys
    final approvedInvestment =
        prefs.getDouble('${username}_family_tree_approved_investment') ??
            prefs.getDouble('family_tree_approved_investment') ??
            0.0;
    final pendingProof =
        prefs.getDouble('${username}_family_tree_pending_proof_amount') ??
            prefs.getDouble('family_tree_pending_proof_amount');
    final disabled = prefs.getBool('${username}_family_tree_disabled') ?? false;
    final banned = prefs.getBool('${username}_family_tree_banned') ?? false;
    DateTime? suspendedUntil;
    final suspensionString =
        prefs.getString('${username}_family_tree_suspension_until');
    if (suspensionString != null && suspensionString.isNotEmpty) {
      final parsed = DateTime.tryParse(suspensionString);
      if (parsed != null) {
        if (DateTime.now().isAfter(parsed)) {
          await prefs.remove('${username}_family_tree_suspension_until');
        } else {
          suspendedUntil = parsed.toLocal();
        }
      }
    }

    final paymentMethod =
        prefs.getString('family_tree_payment_method') ?? 'cashapp';
    final paymentCashAppTag =
        prefs.getString('family_tree_payment_cashapp_tag') ?? r'$NGMYPay';
    final paymentCashAppLink =
        prefs.getString('family_tree_payment_cashapp_link') ?? '';
  final paymentCryptoAddress =
    prefs.getString('family_tree_payment_crypto_address') ?? '';
  final paymentCryptoLabel =
    prefs.getString('family_tree_payment_crypto_label') ?? '';
  final paymentCryptoNote =
    prefs.getString('family_tree_payment_crypto_note') ?? '';

    setState(() {
      _currentInvestment = approvedInvestment;
      _dailyEarnings = _currentInvestment * _dailyReturnRate;
      _pendingProofAmount = pendingProof;
      _isAccountDisabled = disabled;
      _isAccountBanned = banned;
      _accountSuspendedUntil = suspendedUntil;
      _paymentMethod = paymentMethod;
      _cashAppTag = paymentCashAppTag.trim().isNotEmpty
          ? paymentCashAppTag.trim()
          : r'$NGMYPay';
      _cashAppLink = paymentCashAppLink.trim();
      _cryptoAddress = paymentCryptoAddress.trim();
      _cryptoWalletLabel = paymentCryptoLabel.trim();
      _cryptoWalletNote = paymentCryptoNote.trim();
    });
  }

  String _accountLockReason() {
    if (_isAccountBanned) {
      return 'This account is banned by an administrator.';
    }
    if (_isAccountDisabled) {
      return 'This account is disabled by an administrator. Withdrawals remain available from the dashboard.';
    }
    if (_isAccountSuspended && _accountSuspendedUntil != null) {
      return 'Suspended until ${_formatSuspensionDate(_accountSuspendedUntil!)}.';
    }
    if (_isAccountSuspended) {
      return 'This account is suspended by an administrator.';
    }
    return 'This account is currently locked by an administrator.';
  }

  Future<void> _selectInvestment(double amount) async {
    if (_isAccountLocked) {
      if (!mounted) {
        return;
      }
      final message = _accountLockReason();
      final snackColor = _isAccountBanned ? Colors.redAccent : Colors.orange;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Investment unavailable. $message'),
          backgroundColor: snackColor,
        ),
      );
      return;
    }
    // Prevent downgrade - user can only join equal or higher investment
    if (_currentInvestment > 0 && amount < _currentInvestment) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Cannot downgrade! You already have a ₦₲${_formatAmount(_currentInvestment)} investment. You can only upgrade to higher plans.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Check if there's a pending upload session for this amount
    final prefs = await SharedPreferences.getInstance();
    final pendingAmount = prefs.getDouble('family_tree_pending_upload_amount');
    final pendingTimestamp =
        prefs.getInt('family_tree_pending_upload_timestamp');

    if (pendingAmount == amount && pendingTimestamp != null) {
      final sessionStart =
          DateTime.fromMillisecondsSinceEpoch(pendingTimestamp);
      final now = DateTime.now();
      final hoursPassed = now.difference(sessionStart).inHours;

      // If less than 1 hour passed, go directly to upload dialog
      if (hoursPassed < 1) {
        if (!mounted) return;
        await _showPaymentProofDialog(amount);
        return;
      } else {
        // Clear expired session
        await prefs.remove('family_tree_pending_upload_amount');
        await prefs.remove('family_tree_pending_upload_timestamp');
      }
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Family Tree Investment',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Investment Amount: ₦₲${_formatAmount(amount)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Daily Return: ₦₲${_formatAmount(amount * 0.0333, decimals: 2)}',
              style: const TextStyle(color: Colors.green, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Family Tree investment requires 5 sessions before withdrawal.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Proceed to Payment'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;

      // Show deposit dialog with CashApp payment
      await _showDepositDialog(amount);
    }
  }

  Future<void> _showDepositDialog(double amount) async {
    final parentContext = context;
    final isCashApp = _paymentMethod == 'cashapp';
    final displayValue = isCashApp
        ? (_cashAppTag.isNotEmpty ? _cashAppTag : r'$NGMYPay')
        : _cryptoAddress;
    final hasPaymentValue = displayValue.trim().isNotEmpty;
    final rawCashAppLink = _cashAppLink.trim();
    Uri? preparedCashAppUri;
    if (isCashApp && rawCashAppLink.isNotEmpty) {
      preparedCashAppUri = Uri.tryParse(rawCashAppLink);
      if (preparedCashAppUri != null && !preparedCashAppUri.hasScheme) {
        preparedCashAppUri = Uri.tryParse('https://$rawCashAppLink');
      }
    }
    final hasLaunchLink = isCashApp && preparedCashAppUri != null;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool acknowledged = false;

        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> showSnack(String message) async {
              if (!mounted) return;
              ScaffoldMessenger.of(parentContext).showSnackBar(
                SnackBar(content: Text(message)),
              );
            }

            Future<void> handleCopy() async {
              if (!hasPaymentValue) {
                await showSnack('No payment details configured yet.');
                return;
              }
              await Clipboard.setData(ClipboardData(text: displayValue.trim()));
              await showSnack(isCashApp
                  ? 'CashApp handle copied to clipboard.'
                  : 'Crypto address copied to clipboard.');
              setState(() => acknowledged = true);
            }

            Future<void> handleLaunch() async {
              final uri = preparedCashAppUri;
              if (!hasLaunchLink || uri == null) {
                await showSnack('Payment link is not configured.');
                return;
              }
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
                setState(() => acknowledged = true);
              } else {
                await showSnack('Unable to launch the CashApp link.');
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF0D4D3D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.payment,
                        color: Colors.green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Send Payment',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: hasPaymentValue
                        ? () async {
                            if (isCashApp) {
                              if (hasLaunchLink) {
                                await handleLaunch();
                              } else {
                                await showSnack(
                                    'CashApp link is not configured yet.');
                              }
                            } else {
                              setState(() => acknowledged = true);
                            }
                          }
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: isCashApp
                            ? const LinearGradient(
                                colors: [Color(0xFF00D09E), Color(0xFF00A878)],
                              )
                            : const LinearGradient(
                                colors: [Color(0xFF4B6CB7), Color(0xFF182848)],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        border: acknowledged
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCashApp
                                ? 'CLICK HERE TO MAKE THE PAYMENT'
                                : 'Tap after copying the crypto details:',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!isCashApp &&
                              _cryptoWalletLabel.trim().isNotEmpty) ...[
                            Text(
                              _cryptoWalletLabel.trim(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha((0.2 * 255).round()),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              hasPaymentValue
                                  ? displayValue
                                  : 'No details configured',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.05,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Amount: ₦₲${_formatAmount(amount)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: hasPaymentValue ? handleCopy : null,
                                icon: const Icon(Icons.copy, size: 18),
                                label: Text(isCashApp
                                    ? 'Copy Tag'
                                    : 'Copy Address'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              if (isCashApp)
                                TextButton.icon(
                                  onPressed: hasLaunchLink ? handleLaunch : null,
                                  icon: const Icon(Icons.payment, size: 18),
                                  label: const Text('Pay Now'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                          if (!isCashApp &&
                              _cryptoWalletNote.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _cryptoWalletNote.trim(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha((0.15 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withAlpha((0.3 * 255).round()),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
              !hasPaymentValue
                ? 'An administrator has not configured payment details yet. Please try again later.'
                : isCashApp
                  ? 'Tap anywhere on the payment card to launch the CashApp link, complete your payment, then return to upload the screenshot.'
                  : 'Copy the crypto wallet details above, send the exact amount, then upload your proof on the next step.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                FilledButton(
                  onPressed: hasPaymentValue && acknowledged
                      ? () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setDouble(
                              'family_tree_pending_upload_amount', amount);
                          await prefs.setInt(
                            'family_tree_pending_upload_timestamp',
                            DateTime.now().millisecondsSinceEpoch,
                          );
                          if (!parentContext.mounted) return;
                          Navigator.pop(dialogContext, 'upload');
                        }
                      : null,
                  style:
                      FilledButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('I Sent Payment'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == 'upload') {
      if (!mounted) return;
      await _showPaymentProofDialog(amount);
    }
  }

  Future<void> _showPaymentProofDialog(double investmentAmount) async {
    String? screenshotPath;
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF0D4D3D),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.upload_file, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Upload Payment Proof',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha((0.15 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.blue.withAlpha((0.3 * 255).round())),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.blue, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Upload screenshot of your payment and enter the amount sent.',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.9 * 255).round()),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Investment Amount',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '₦₲${_formatAmount(investmentAmount)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Amount Sent (₦₲)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'Enter amount you sent',
                    hintStyle: TextStyle(
                        color: Colors.white.withAlpha((0.3 * 255).round())),
                    filled: true,
                    fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon:
                        const Icon(Icons.attach_money, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Payment Screenshot',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picker = ImagePicker();
                    final image =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setState(() {
                        screenshotPath = image.path;
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: screenshotPath != null
                          ? Colors.green.withAlpha((0.15 * 255).round())
                          : Colors.white.withAlpha((0.08 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: screenshotPath != null
                            ? Colors.green.withAlpha((0.3 * 255).round())
                            : Colors.white.withAlpha((0.2 * 255).round()),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          screenshotPath != null
                              ? Icons.check_circle
                              : Icons.cloud_upload,
                          color: screenshotPath != null
                              ? Colors.green
                              : Colors.white70,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          screenshotPath != null
                              ? 'Screenshot Selected ✓'
                              : 'Tap to Upload Screenshot',
                          style: TextStyle(
                            color: screenshotPath != null
                                ? Colors.green
                                : Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (screenshotPath != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _extractFileName(screenshotPath!),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            FilledButton(
              onPressed: () async {
                if (screenshotPath == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please upload payment screenshot')),
                  );
                  return;
                }

                final paidAmount = double.tryParse(amountController.text);
                if (paidAmount == null || paidAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid amount')),
                  );
                  return;
                }

                await _submitPaymentProof(
                    investmentAmount, paidAmount, screenshotPath!);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Submit for Approval'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPaymentProof(
      double investmentAmount, double paidAmount, String screenshotPath) async {
    final prefs = await SharedPreferences.getInstance();

    final storedScreenshotPath =
        await _persistPaymentProofImage(screenshotPath, folder: 'family_tree');
    if (storedScreenshotPath == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Unable to read the screenshot file. Please try again.'),
        ),
      );
      return;
    }

    // Get current username
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';

    // Create payment proof with username and Family Tree prefix
    final proof = PaymentProof(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: username,
      investmentAmount: investmentAmount,
      paidAmount: paidAmount,
      screenshotPath: storedScreenshotPath,
      submittedAt: DateTime.now(),
      status: 'pending',
    );

    // Save to SharedPreferences with Family Tree prefix
    final proofsList = prefs.getStringList('family_tree_payment_proofs') ?? [];
    proofsList.add(json.encode(proof.toJson()));
    await prefs.setStringList('family_tree_payment_proofs', proofsList);

    // Save pending investment to BOTH global and user-specific keys with Family Tree prefix
    await prefs.setDouble(
        'family_tree_pending_investment_amount', investmentAmount);
    await prefs.setDouble(
        '${username}_family_tree_pending_investment_amount', investmentAmount);

    // Clear the upload session since proof is submitted
    await prefs.remove('family_tree_pending_upload_amount');
    await prefs.remove('family_tree_pending_upload_timestamp');

    setState(() {
      _pendingProofAmount = investmentAmount;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Family Tree payment proof submitted! Waiting for admin approval.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<String?> _persistPaymentProofImage(String originalPath,
      {required String folder}) async {
    try {
      final sourceFile = File(originalPath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final baseDir = await getApplicationDocumentsDirectory();
      final proofsRoot =
          Directory('${baseDir.path}${Platform.pathSeparator}ngmy_proofs');
      if (!await proofsRoot.exists()) {
        await proofsRoot.create(recursive: true);
      }

      final targetDir = Directory(
        '${proofsRoot.path}${Platform.pathSeparator}$folder',
      );
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final sanitizedName =
          _sanitizeFileName(_extractFileName(originalPath));
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destinationPath =
          '${targetDir.path}${Platform.pathSeparator}${timestamp}_$sanitizedName';

      final savedFile = await sourceFile.copy(destinationPath);
      return savedFile.path;
    } catch (error) {
      debugPrint('Failed to persist payment proof image: $error');
      return null;
    }
  }

  String _extractFileName(String path) {
    if (path.isEmpty) {
      return 'proof.png';
    }
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isNotEmpty ? segments.last : path;
  }

  String _sanitizeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return sanitized.isEmpty ? 'proof.png' : sanitized;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0D1B2A), // Dark blue-black at top
              const Color(0xFF1B263B), // Deeper blue-gray middle
              const Color(0xFF0D1B2A), // Back to dark blue-black
              const Color(0xFF415A77)
                  .withAlpha((0.6 * 255).round()), // Lighter blue-gray bottom
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCurrentInvestment(),
                      if (_isAccountLocked) ...[
                        const SizedBox(height: 16),
                        _buildAccountLockBanner(),
                      ],
                      if (_pendingProofAmount != null) ...[
                        const SizedBox(height: 16),
                        _buildPendingProofBanner(),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        'Family Tree Investment Plans',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Earn 3.33% daily returns • 5 sessions per day • 5 minutes each',
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.7 * 255).round()),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ..._investmentTiers.map((tier) => _buildInvestmentCard(
                            tier['amount'] as double,
                            tier['color'] as Color,
                            tier['tier'] as String,
                            tier['icon'] as IconData,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Family Tree Investment',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.green.withAlpha((0.3 * 255).round())),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                const Text(
                  '3.33%',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatSuspensionDate(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Widget _buildAccountLockBanner() {
    Color accent;
    String title;
    String message;

    if (_isAccountBanned) {
      accent = Colors.redAccent;
      title = 'Account Banned';
      message =
          'This account cannot invest or withdraw until the ban is lifted by an administrator.';
    } else if (_isAccountSuspended) {
      accent = Colors.orangeAccent;
      final untilLabel = _accountSuspendedUntil != null
          ? _formatSuspensionDate(_accountSuspendedUntil!)
          : 'the suspension is lifted';
      title = 'Account Suspended';
      message = 'Family Tree activity is paused until $untilLabel.';
    } else {
      accent = Colors.orangeAccent;
      title = 'Account Disabled';
      message =
          'Family Tree activity is paused. Withdrawals remain available from the main dashboard.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withAlpha((0.18 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withAlpha((0.45 * 255).round())),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.lock_outline, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.75 * 255).round()),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingProofBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.orange.withAlpha((0.3 * 255).round()), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.hourglass_empty,
                color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Pending Approval',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₦₲${_formatAmount(_pendingProofAmount!)} investment awaiting admin approval',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.8 * 255).round()),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentInvestment() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _currentInvestment > 0
              ? [const Color(0xFF0F5F47), const Color(0xFF1A8567)]
              : [Colors.grey.shade800, Colors.grey.shade900],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.3 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _currentInvestment > 0
                    ? Icons.account_balance
                    : Icons.info_outline,
                color: Colors.white.withAlpha((0.8 * 255).round()),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _currentInvestment > 0
                    ? 'Active Family Tree Investment'
                    : 'No Active Investment',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.8 * 255).round()),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_currentInvestment > 0) ...[
            const Text(
              'Investment Amount',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '₦₲${_formatAmount(_currentInvestment)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Earnings',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₦₲${_formatAmount(_dailyEarnings, decimals: 2)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monthly Projection',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₦₲${_formatAmount(_dailyEarnings * _workingDaysPerMonth, decimals: 2)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'Start earning with 5 daily sessions!',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose an investment plan below to get started.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvestmentCard(
      double amount, Color color, String tierName, IconData tierIcon) {
    final dailyReturn = amount * _dailyReturnRate;
    final monthlyReturn = dailyReturn * _workingDaysPerMonth;
    final accountLocked = _isAccountLocked;
    final isActive = _currentInvestment == amount;
    final isLocked = _currentInvestment > 0 &&
        amount < _currentInvestment; // Lock lower tiers
    final isPending = _pendingProofAmount ==
        amount; // Check if this tier has pending approval
    final canJoin = !isActive && !isLocked && !isPending && !accountLocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isLocked || isPending
            ? Colors.grey.withAlpha((0.05 * 255).round())
            : Colors.white.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? color
              : isPending
                  ? Colors.orange.withAlpha((0.5 * 255).round())
                  : isLocked
                      ? Colors.grey.withAlpha((0.2 * 255).round())
                      : Colors.white.withAlpha((0.1 * 255).round()),
          width: isActive || isPending ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withAlpha((0.3 * 255).round()),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : isPending
                ? [
                    BoxShadow(
                      color: Colors.orange.withAlpha((0.3 * 255).round()),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isLocked || isPending ? Colors.grey : color)
                          .withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isLocked
                          ? Icons.lock
                          : isPending
                              ? Icons.hourglass_empty
                              : tierIcon,
                      color: isLocked
                          ? Colors.grey
                          : isPending
                              ? Colors.orange
                              : color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '₦₲${_formatAmount(amount)}',
                            style: TextStyle(
                              color: isLocked || isPending
                                  ? Colors.grey
                                  : Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withAlpha((0.2 * 255).round()),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tierName,
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLocked
                            ? 'Not Available'
                            : isPending
                                ? 'Pending Approval'
                                : 'Investment Plan',
                        style: TextStyle(
                          color: isPending
                              ? Colors.orange
                              : isLocked
                                  ? Colors.grey.withAlpha((0.8 * 255).round())
                                  : Colors.white.withAlpha((0.6 * 255).round()),
                          fontSize: 12,
                          fontWeight:
                              isPending ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (isLocked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha((0.3 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'LOCKED',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (isLocked) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha((0.15 * 255).round()),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.orange.withAlpha((0.3 * 255).round())),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cannot downgrade from ₦₲${_formatAmount(_currentInvestment)}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Divider(color: Colors.white.withAlpha((0.1 * 255).round())),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildReturnInfo(
                  'Daily Return',
                  '₦₲${_formatAmount(dailyReturn, decimals: 2)}',
                  Icons.today,
                  isLocked ? Colors.grey : color,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withAlpha((0.1 * 255).round()),
              ),
              Expanded(
                child: _buildReturnInfo(
                  'Monthly Est.',
                  '₦₲${_formatAmount(monthlyReturn, decimals: 2)}',
                  Icons.calendar_month,
                  isLocked ? Colors.grey : color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canJoin ? () => _selectInvestment(amount) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canJoin
                    ? const Color(0xFF4CAF50)
                    : Colors.grey.shade700, // Always green for join buttons
                disabledBackgroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: canJoin ? 4 : 0,
                shadowColor: canJoin
                    ? const Color(0xFF4CAF50).withAlpha((0.3 * 255).round())
                    : null,
              ),
              child: Text(
                isActive
                    ? 'Current Plan'
                    : isPending
                        ? 'Pending Approval'
                        : accountLocked
                            ? 'Account Locked'
                            : isLocked
                                ? 'Locked'
                                : 'Join Now',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnInfo(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha((0.6 * 255).round()),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatAmount(num value, {int decimals = 0}) {
    final isNegative = value.isNegative;
    final absolute = value.abs();
    final fixed = absolute.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final integerPart = parts[0];
    final buffer = StringBuffer();

    for (int i = 0; i < integerPart.length; i++) {
      buffer.write(integerPart[i]);
      final digitsLeft = integerPart.length - i - 1;
      if (digitsLeft > 0 && digitsLeft % 3 == 0) {
        buffer.write(',');
      }
    }

    final decimalsPart = (decimals > 0 && parts.length > 1) ? '.${parts[1]}' : '';
    final sign = isNegative ? '-' : '';
    return '$sign${buffer.toString()}$decimalsPart';
  }
}
