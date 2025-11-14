import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/payment_proof.dart';
import '../services/growth_account_guard.dart';

class InvestmentJoinScreen extends StatefulWidget {
  const InvestmentJoinScreen({super.key});

  @override
  State<InvestmentJoinScreen> createState() => _InvestmentJoinScreenState();
}

class _InvestmentJoinScreenState extends State<InvestmentJoinScreen> {
  double _currentInvestment = 0.0;
  double _dailyEarnings = 0.0;
  double? _pendingProofAmount;

  static const double _dailyReturnRate = 0.0286; // 2.86% per day
  static const int _workingDaysPerMonth = 20; // Weekdays in a four-week cycle

  GrowthAccountStatus _accountStatus = const GrowthAccountStatus(
    username: 'NGMY User',
    isDisabled: false,
    isSuspended: false,
  );

  bool get _isInvestmentLocked =>
      _accountStatus.blocksAllActions || _accountStatus.withdrawOnly;

  String _paymentMethod = 'cashapp';
  String _cashAppTag = r'$NGMYPay';
  String _cashAppLink = '';
  String _cryptoAddress = '';
  String _cryptoWalletLabel = '';
  String _cryptoWalletNote = '';

  final List<Map<String, dynamic>> _investmentTiers = [
    {'amount': 5.0, 'color': const Color(0xFF1DE9B6)},
    {'amount': 10.0, 'color': const Color(0xFF26A69A)},
    {'amount': 20.0, 'color': const Color(0xFF7E57C2)},
    {'amount': 30.0, 'color': const Color(0xFFFFB74D)},
    {'amount': 40.0, 'color': const Color(0xFF42A5F5)},
    {'amount': 50.0, 'color': const Color(0xFFE53935)},
    {'amount': 100.0, 'color': const Color(0xFF00BFA5)},
    {'amount': 250.0, 'color': const Color(0xFFFFD54F)},
    {'amount': 500.0, 'color': const Color(0xFF9575CD)},
    {'amount': 1000.0, 'color': const Color(0xFF4DB6AC)},
    {'amount': 1500.0, 'color': const Color(0xFF64B5F6)},
    {'amount': 2000.0, 'color': const Color(0xFFBA68C8)},
    {'amount': 4000.0, 'color': const Color(0xFFFF7043)},
    {'amount': 5000.0, 'color': const Color(0xFFFF8A65)},
    {'amount': 6500.0, 'color': const Color(0xFF26C6DA)},
    {'amount': 8000.0, 'color': const Color(0xFF7CB342)},
    {'amount': 9500.0, 'color': const Color(0xFF8E24AA)},
    {'amount': 10000.0, 'color': const Color(0xFF5C6BC0)},
    {'amount': 13000.0, 'color': const Color(0xFF00ACC1)},
    {'amount': 15000.0, 'color': const Color(0xFFFFCA28)},
    {'amount': 18000.0, 'color': const Color(0xFFAB47BC)},
    {'amount': 20000.0, 'color': const Color(0xFF0097A7)},
    {'amount': 23000.0, 'color': const Color(0xFF009688)},
    {'amount': 25000.0, 'color': const Color(0xFFAFB42B)},
    {'amount': 28000.0, 'color': const Color(0xFF42A5F5)},
    {'amount': 30000.0, 'color': const Color(0xFF8D6E63)},
    {'amount': 32000.0, 'color': const Color(0xFFE53935)},
    {'amount': 35000.0, 'color': const Color(0xFFEF5350)},
    {'amount': 38000.0, 'color': const Color(0xFFFFB300)},
    {'amount': 45000.0, 'color': const Color(0xFF3949AB)},
    {'amount': 48000.0, 'color': const Color(0xFF00897B)},
    {'amount': 50000.0, 'color': const Color(0xFFF06292)},
    {'amount': 52000.0, 'color': const Color(0xFF5E35B1)},
    {'amount': 55000.0, 'color': const Color(0xFF1E88E5)},
    {'amount': 60000.0, 'color': const Color(0xFFFF8F00)},
    {'amount': 75000.0, 'color': const Color(0xFFB71C1C)},
    {'amount': 85000.0, 'color': const Color(0xFF00B8D4)},
    {'amount': 90000.0, 'color': const Color(0xFF8E24AA)},
    {'amount': 100000.0, 'color': const Color(0xFF42A5F5)},
    {'amount': 110000.0, 'color': const Color(0xFFFFC107)},
    {'amount': 120000.0, 'color': const Color(0xFFD32F2F)},
  ];

  @override
  void initState() {
    super.initState();
    _loadInvestment();
  }

  Future<void> _loadInvestment() async {
    final prefs = await SharedPreferences.getInstance();
    final status = await GrowthAccountGuard.load(prefs: prefs);
    final username = status.username;

    final approvedInvestment =
        prefs.getDouble('${username}_approved_investment') ??
            prefs.getDouble('approved_investment') ??
            0.0;
    final pendingProof =
        prefs.getDouble('${username}_pending_investment_amount') ??
            prefs.getDouble('pending_investment_amount');

    final paymentMethod = prefs.getString('growth_payment_method') ?? 'cashapp';
    final paymentCashAppTag =
        prefs.getString('growth_payment_cashapp_tag') ?? r'$NGMYPay';
    final paymentCashAppLink =
        prefs.getString('growth_payment_cashapp_link') ?? '';
    final paymentCryptoAddress =
        prefs.getString('growth_payment_crypto_address') ?? '';
    final paymentCryptoLabel =
        prefs.getString('growth_payment_crypto_label') ?? '';
    final paymentCryptoNote =
        prefs.getString('growth_payment_crypto_note') ?? '';

    if (!mounted) {
      return;
    }

    setState(() {
      _accountStatus = status;
      _currentInvestment = approvedInvestment;
      _dailyEarnings = _currentInvestment * _dailyReturnRate;
      _pendingProofAmount = pendingProof;
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

  Future<bool> _ensureInvestmentActionAllowed() async {
    final decision = await GrowthAccountGuard.evaluateAction(
      actionLabel: 'Join an investment plan',
    );

    if (!mounted) {
      return decision.allowed;
    }

    setState(() {
      _accountStatus = decision.status;
    });

    if (!decision.allowed) {
      GrowthAccountGuard.showBlockedMessage(context, decision);
    }

    return decision.allowed;
  }

  Future<void> _joinInvestment(double amount) async {
    if (!await _ensureInvestmentActionAllowed()) {
      return;
    }

    if (_pendingProofAmount != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'A payment for \$${_formatAmount(_pendingProofAmount!)} is awaiting review. Please wait until it is processed.',
          ),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    if (_currentInvestment == amount) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This plan is already active for your account.'),
        ),
      );
      return;
    }

    if (_currentInvestment > 0 && amount < _currentInvestment) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You currently have a \$${_formatAmount(_currentInvestment)} plan. Downgrades are not available.',
          ),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final pendingAmount = prefs.getDouble('growth_pending_upload_amount');
    final pendingTimestamp = prefs.getInt('growth_pending_upload_timestamp');

    if (pendingAmount == amount && pendingTimestamp != null) {
      final sessionStart =
          DateTime.fromMillisecondsSinceEpoch(pendingTimestamp);
      if (DateTime.now().difference(sessionStart).inHours < 1) {
        if (!mounted) return;
        await _showPaymentProofDialog(amount);
        return;
      } else {
        await prefs.remove('growth_pending_upload_amount');
        await prefs.remove('growth_pending_upload_timestamp');
      }
    }

    if (!mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F3A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Growth Investment',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Investment Amount: \$${_formatAmount(amount)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Daily Return: \$${_formatAmount(amount * _dailyReturnRate, decimals: 2)}',
              style: const TextStyle(color: Colors.green, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'You must upload your proof immediately after payment. Pending submissions expire after one hour.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Proceed to Pay'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
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
          builder: (dialogChildContext, setState) {
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
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                setState(() => acknowledged = true);
              } else {
                await showSnack('Unable to launch the CashApp link.');
              }
            }

            Future<void> handleCardTap() async {
              if (!hasPaymentValue) {
                await showSnack('No payment details configured yet.');
                return;
              }
              if (isCashApp) {
                if (hasLaunchLink) {
                  await handleLaunch();
                } else {
                  await showSnack('CashApp link is not configured yet.');
                }
              } else {
                setState(() => acknowledged = true);
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF0F3A2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              scrollable: true,
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
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(parentContext).size.height * 0.7,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPaymentCard(
                        isCashApp: isCashApp,
                        hasPaymentValue: hasPaymentValue,
                        displayValue: displayValue,
                        amount: amount,
                        acknowledged: acknowledged,
                        onTap: hasPaymentValue ? handleCardTap : null,
                        onCopy: hasPaymentValue ? handleCopy : null,
                        onLaunch: hasLaunchLink ? handleLaunch : null,
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
                                        ? 'Tap anywhere on the card or use Pay Now to launch the CashApp link, complete payment, then return to upload your proof.'
                                        : 'Copy the crypto details from the card, send the exact amount, then upload your payment proof in the next step.',
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
                ),
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
                              'growth_pending_upload_amount', amount);
                          await prefs.setInt(
                            'growth_pending_upload_timestamp',
                            DateTime.now().millisecondsSinceEpoch,
                          );
                          if (!dialogContext.mounted) {
                            return;
                          }
                          Navigator.pop(dialogContext, 'upload');
                        }
                      : null,
                  style: FilledButton.styleFrom(backgroundColor: Colors.orange),
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

  Widget _buildPaymentCard({
    required bool isCashApp,
    required bool hasPaymentValue,
    required String displayValue,
    required double amount,
    required bool acknowledged,
    required VoidCallback? onTap,
    required VoidCallback? onCopy,
    required VoidCallback? onLaunch,
  }) {
    final gradient = isCashApp
        ? const LinearGradient(
            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF654EA3), Color(0xFF2C3E50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final cardHolder = _formatCardHolder(isCashApp, displayValue);
    final cardNumber = hasPaymentValue
        ? _formatCardNumber(isCashApp, displayValue)
        : '---- ---- ---- ----';
    final displayCardNumber = isCashApp ? cardNumber : 'NGMY PAY ₦₲';
    final displayCardHolder = isCashApp ? cardHolder : 'NGMY';

    final handlePreview = hasPaymentValue
        ? (isCashApp ? displayValue : _formatCryptoPreview(displayValue))
        : 'No details configured';

    final actionButtons = <Widget>[
      TextButton.icon(
        onPressed: onCopy,
        icon: const Icon(Icons.copy, size: 18),
        label: Text(isCashApp ? 'Copy Tag' : 'Copy Address'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.black87,
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      if (isCashApp)
        TextButton.icon(
          onPressed: onLaunch,
          icon: const Icon(Icons.payment, size: 18),
          label: const Text('Pay Now'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.black.withAlpha((0.35 * 255).round()),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
    ];

    final buttonWidgets = actionButtons
        .map((button) => SizedBox(height: 44, child: button))
        .toList();

    final cardSurface = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.35 * 255).round()),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border:
                acknowledged ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 15 / 10,
              child: Container(
                decoration: BoxDecoration(gradient: gradient),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
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
                                  isCashApp
                                      ? 'CashApp Payment'
                                      : (_cryptoWalletLabel.isNotEmpty
                                          ? _cryptoWalletLabel
                                          : 'Crypto Wallet'),
                                  style: TextStyle(
                                    color: Colors.white
                                        .withAlpha((0.85 * 255).round()),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.45,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  displayCardNumber,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Card Holder',
                                  style: TextStyle(
                                    color: Colors.white
                                        .withAlpha((0.62 * 255).round()),
                                    fontSize: 10.5,
                                    letterSpacing: 0.35,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  displayCardHolder,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isCashApp ? 'Amount Due' : 'Send Amount',
                                style: TextStyle(
                                  color: Colors.white
                                      .withAlpha((0.7 * 255).round()),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '\$${_formatAmount(amount)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Icon(
                                isCashApp
                                    ? Icons.contactless
                                    : Icons.currency_bitcoin,
                                color: Colors.white
                                    .withAlpha((0.82 * 255).round()),
                                size: 24,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black
                                    .withAlpha((0.24 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                handlePreview,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  letterSpacing: 1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isCashApp && _cryptoWalletNote.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  _cryptoWalletNote,
                                  style: TextStyle(
                                    color: Colors.white
                                        .withAlpha((0.75 * 255).round()),
                                    fontSize: 10,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cardSurface,
        if (buttonWidgets.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: buttonWidgets,
          ),
        ],
      ],
    );
  }

  String _formatCardHolder(bool isCashApp, String value) {
    if (isCashApp) {
      final cleaned = value
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(r'$', '')
          .replaceAll('_', ' ')
          .trim();
      if (cleaned.isEmpty) {
        return 'CASHAPP MEMBER';
      }
      return cleaned.toUpperCase();
    }
    if (_cryptoWalletLabel.isNotEmpty) {
      return _cryptoWalletLabel.toUpperCase();
    }
    return 'CRYPTO MEMBER';
  }

  String _formatCardNumber(bool isCashApp, String value) {
    final raw = value.replaceAll(RegExp(r'\s+'), '');
    if (raw.isEmpty) {
      return '---- ---- ---- ----';
    }
    if (isCashApp) {
      final sanitized =
          raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
      if (sanitized.isEmpty) {
        return '---- ---- ---- ----';
      }
      final buffer = StringBuffer();
      for (var i = 0; i < sanitized.length; i++) {
        buffer.write(sanitized[i]);
        if ((i + 1) % 4 == 0 && i != sanitized.length - 1) {
          buffer.write(' ');
        }
      }
      return buffer.toString();
    }

    final sanitized = raw.toUpperCase();
    if (sanitized.length <= 20) {
      return _groupIntoBlocks(sanitized);
    }
    return '${sanitized.substring(0, 8)} •••• ${sanitized.substring(sanitized.length - 6)}';
  }

  String _formatCryptoPreview(String value) {
    if (value.length <= 22) {
      return value;
    }
    return '${value.substring(0, 10)}••••${value.substring(value.length - 8)}';
  }

  String _groupIntoBlocks(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      buffer.write(value[i]);
      if ((i + 1) % 4 == 0 && i != value.length - 1) {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  Future<void> _showPaymentProofDialog(double investmentAmount) async {
    final amountController = TextEditingController(
      text: investmentAmount.toStringAsFixed(0),
    );
    final imagePicker = ImagePicker();
    String? screenshotPath;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogChildContext, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F3A2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Upload Payment Proof',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Enter the amount you paid and upload the payment screenshot for verification.',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Amount Paid',
                        labelStyle: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                        prefixText: '\$',
                        prefixStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withAlpha((0.05 * 255).round()),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withAlpha((0.1 * 255).round()),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final picked = await imagePicker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        if (picked != null) {
                          setState(() => screenshotPath = picked.path);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.05 * 255).round()),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: screenshotPath != null
                                ? Colors.green
                                : Colors.white.withAlpha((0.2 * 255).round()),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
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
                                  ? 'Screenshot Selected'
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
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
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
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white70)),
                ),
                FilledButton(
                  onPressed: () async {
                    final paidAmount = double.tryParse(amountController.text);
                    if (paidAmount == null || paidAmount <= 0) {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      messenger?.showSnackBar(
                        const SnackBar(
                            content: Text('Please enter a valid amount.')),
                      );
                      return;
                    }
                    if (screenshotPath == null) {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      messenger?.showSnackBar(
                        const SnackBar(
                            content:
                                Text('Please upload your payment screenshot.')),
                      );
                      return;
                    }

                    await _submitPaymentProof(
                      investmentAmount,
                      paidAmount,
                      screenshotPath!,
                    );

                    if (!dialogContext.mounted) {
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Submit for Approval'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
  }

  Future<void> _submitPaymentProof(
    double investmentAmount,
    double paidAmount,
    String screenshotPath,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final storedScreenshotPath = await _persistPaymentProofImage(
      screenshotPath,
      folder: 'growth',
    );
    if (storedScreenshotPath == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to read the screenshot file. Please try again.',
          ),
        ),
      );
      return;
    }

    final username = prefs.getString('growth_user_name') ?? 'NGMY User';
    final proof = PaymentProof(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: username,
      investmentAmount: investmentAmount,
      paidAmount: paidAmount,
      screenshotPath: storedScreenshotPath,
      submittedAt: DateTime.now(),
      status: 'pending',
      scope: 'growth',
    );

    final proofsList = prefs.getStringList('payment_proofs') ?? [];
    proofsList.add(json.encode(proof.toJson()));
    await prefs.setStringList('payment_proofs', proofsList);

    await prefs.setDouble('pending_investment_amount', investmentAmount);
    await prefs.setDouble(
      '${username}_pending_investment_amount',
      investmentAmount,
    );

    await prefs.remove('growth_pending_upload_amount');
    await prefs.remove('growth_pending_upload_timestamp');

    await _loadInvestment();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment proof submitted! Waiting for approval.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<String?> _persistPaymentProofImage(
    String originalPath, {
    required String folder,
  }) async {
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

      final sanitizedName = _sanitizeFileName(_extractFileName(originalPath));
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D4D3D),
              Color(0xFF1A6B54),
              Color(0xFF0D4D3D),
            ],
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
                      if (_pendingProofAmount != null) ...[
                        const SizedBox(height: 16),
                        _buildPendingProofBanner(),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        'Investment Plans',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Earn 2.86% daily returns on your investment.',
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.7 * 255).round()),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ..._investmentTiers.map(
                        (tier) => _buildInvestmentCard(
                          tier['amount'] as double,
                          tier['color'] as Color,
                        ),
                      ),
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
              'Join Investment',
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
                color: Colors.green.withAlpha((0.3 * 255).round()),
              ),
            ),
            child: Row(
              children: const [
                Icon(Icons.trending_up, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text(
                  '2.86%',
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

  Widget _buildPendingProofBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withAlpha((0.3 * 255).round()),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.pending_actions,
              color: Colors.orange,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Pending Approval',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${_formatAmount(_pendingProofAmount!)} investment awaiting review',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.hourglass_empty,
            color: Colors.orange,
            size: 24,
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
                    ? 'Active Investment'
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
              '\$${_formatAmount(_currentInvestment)}',
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
                        '\$${_formatAmount(_dailyEarnings, decimals: 2)}',
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
                        '\$${_formatAmount(_dailyEarnings * _workingDaysPerMonth, decimals: 2)}',
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
              'Start earning passive income today!',
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

  Widget _buildInvestmentCard(double amount, Color color) {
    final dailyReturn = amount * _dailyReturnRate;
    final monthlyReturn = dailyReturn * _workingDaysPerMonth;
    final isActive = _currentInvestment == amount;
    final isLocked = _currentInvestment > 0 && amount < _currentInvestment;
    final isPending = _pendingProofAmount == amount;
    final isStatusLocked = _isInvestmentLocked && !isActive;
    final canJoin = !isActive && !isLocked && !isPending && !isStatusLocked;

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
                  : isLocked || isStatusLocked
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
                      color: (isLocked || isPending || isStatusLocked
                              ? Colors.grey
                              : isPending
                                  ? Colors.orange
                                  : color)
                          .withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isLocked || isStatusLocked
                          ? Icons.lock
                          : isPending
                              ? Icons.hourglass_empty
                              : Icons.attach_money,
                      color: isLocked || isStatusLocked
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
                      Text(
                        '\$${_formatAmount(amount)}',
                        style: TextStyle(
                          color: isLocked || isPending || isStatusLocked
                              ? Colors.grey
                              : Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLocked
                            ? 'Not Available'
                            : isStatusLocked
                                ? _accountStatus.blocksAllActions
                                    ? 'Suspended'
                                    : 'Disabled'
                                : isPending
                                    ? 'Pending Approval'
                                    : 'Investment Plan',
                        style: TextStyle(
                          color: isPending
                              ? Colors.orange
                              : isLocked || isStatusLocked
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
                )
              else if (isStatusLocked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha((0.25 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _accountStatus.blocksAllActions ? 'SUSPENDED' : 'DISABLED',
                    style: const TextStyle(
                      color: Colors.white,
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
                  color: Colors.orange.withAlpha((0.3 * 255).round()),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cannot downgrade from \$${_formatAmount(_currentInvestment)}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isStatusLocked) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha((0.15 * 255).round()),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.redAccent.withAlpha((0.35 * 255).round()),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _accountStatus.blocksAllActions
                          ? 'Investments are paused while this account is suspended.'
                          : 'Investments are paused while this account is disabled. Withdrawals remain available.',
                      style: const TextStyle(
                        color: Colors.redAccent,
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
                  '\$${_formatAmount(dailyReturn, decimals: 2)}',
                  Icons.today,
                  isLocked || isStatusLocked ? Colors.grey : color,
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
                  '\$${_formatAmount(monthlyReturn, decimals: 2)}',
                  Icons.calendar_month,
                  isLocked || isStatusLocked ? Colors.grey : color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canJoin ? () => _joinInvestment(amount) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                disabledBackgroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isActive
                    ? 'Current Plan'
                    : isPending
                        ? 'Pending Approval'
                        : isLocked
                            ? 'Locked'
                            : isStatusLocked
                                ? 'Unavailable'
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
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
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

    final decimalsPart =
        (decimals > 0 && parts.length > 1) ? '.${parts[1]}' : '';
    final sign = isNegative ? '-' : '';
    return '$sign${buffer.toString()}$decimalsPart';
  }
}
