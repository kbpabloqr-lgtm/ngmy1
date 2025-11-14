import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/payment_proof.dart';
import '../../services/global_account_guard.dart';
import '../../services/country_location_service.dart';

class GlobalInvestmentJoinScreen extends StatefulWidget {
  const GlobalInvestmentJoinScreen({super.key});

  @override
  State<GlobalInvestmentJoinScreen> createState() =>
      _GlobalInvestmentJoinScreenState();
}

class _GlobalInvestmentJoinScreenState
    extends State<GlobalInvestmentJoinScreen> {
  double _currentInvestment = 0.0;
  double _dailyEarnings = 0.0;
  double? _pendingProofAmount;

  static const double _dailyReturnRate = 0.0286; // 2.86% per day
  static const int _workingDaysPerMonth = 20; // Weekdays in a four-week cycle

  GlobalAccountStatus _accountStatus = const GlobalAccountStatus(
    username: 'NGMY User',
    isDisabled: false,
    isSuspended: false,
  );

  bool get _isInvestmentLocked =>
      _accountStatus.blocksAllActions || _accountStatus.withdrawOnly;

  static const Color _deepPurple = Color(0xFF140C2F);
  static const Color _midPurple = Color(0xFF1C1045);
  static const Color _panelTint = Color(0xFF231A4B);
  static const Color _accentPurple = Color(0xFF6C3FDB);
  static const Color _lavenderGlow = Color(0xFFA379FF);
  static const Color _magentaPulse = Color(0xFFD36BFF);

  String _paymentMethod = 'cashapp';
  String _cashAppTag = r'$NGMYPay';
  String _cashAppLink = '';
  String _cryptoAddress = '';
  String _cryptoWalletLabel = '';
  String _cryptoWalletNote = '';
  CountryOption _countryOption = CountryLocationService.defaultCountry;

  bool get _isUnitedStates =>
      _countryOption.code == CountryLocationService.defaultCountry.code;

  final List<Map<String, dynamic>> _investmentTiers = [
    {'amount': 1.0, 'color': const Color(0xFF1DE9B6)},
    {'amount': 3.0, 'color': const Color(0xFF26A69A)},
    {'amount': 5.0, 'color': const Color(0xFF7E57C2)},
    {'amount': 8.0, 'color': const Color(0xFFFFB74D)},
    {'amount': 10.0, 'color': const Color(0xFF42A5F5)},
    {'amount': 15.0, 'color': const Color(0xFFE53935)},
    {'amount': 20.0, 'color': const Color(0xFF00BFA5)},
    {'amount': 25.0, 'color': const Color(0xFFFFD54F)},
    {'amount': 30.0, 'color': const Color(0xFF9575CD)},
    {'amount': 40.0, 'color': const Color(0xFF4DB6AC)},
    {'amount': 55.0, 'color': const Color(0xFF64B5F6)},
    {'amount': 80.0, 'color': const Color(0xFFBA68C8)},
    {'amount': 100.0, 'color': const Color(0xFFFF7043)},
    {'amount': 200.0, 'color': const Color(0xFFFF8A65)},
    {'amount': 300.0, 'color': const Color(0xFF26C6DA)},
    {'amount': 400.0, 'color': const Color(0xFF7CB342)},
    {'amount': 500.0, 'color': const Color(0xFF8E24AA)},
  ];

  @override
  void initState() {
    super.initState();
    _loadInvestment();
  }

  Future<void> _loadInvestment() async {
    final prefs = await SharedPreferences.getInstance();
    final status = await GlobalAccountGuard.load(prefs: prefs);
    final username = status.username;

    final approvedInvestment =
        prefs.getDouble('${username}_global_approved_investment') ??
            prefs.getDouble('global_approved_investment') ??
            0.0;
    final pendingProof =
        prefs.getDouble('${username}_global_pending_investment_amount') ??
            prefs.getDouble('global_pending_investment_amount');

    final paymentMethod = prefs.getString('global_payment_method') ?? 'cashapp';
    final paymentCashAppTag =
        prefs.getString('global_payment_cashapp_tag') ?? r'$NGMYPay';
    final paymentCashAppLink =
        prefs.getString('global_payment_cashapp_link') ?? '';
    final paymentCryptoAddress =
        prefs.getString('global_payment_crypto_address') ?? '';
    final paymentCryptoLabel =
        prefs.getString('global_payment_crypto_label') ?? '';
    final paymentCryptoNote =
        prefs.getString('global_payment_crypto_note') ?? '';

    final storedCountryCode =
        prefs.getString('${username}_global_country_code') ??
        prefs.getString('global_country_code');
    final countryOption =
        CountryLocationService.optionForCode(storedCountryCode) ??
        CountryLocationService.defaultCountry;

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
      _countryOption = countryOption;
    });
  }

  Future<bool> _ensureInvestmentActionAllowed() async {
    final decision = await GlobalAccountGuard.evaluateAction(
      actionLabel: 'Join an investment plan',
    );

    if (!mounted) {
      return decision.allowed;
    }

    setState(() {
      _accountStatus = decision.status;
    });

    if (!decision.allowed) {
      GlobalAccountGuard.showBlockedMessage(context, decision);
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
            'A payment for ${_formatLocalWithUsd(_pendingProofAmount!, decimals: 2)} is awaiting review. Please wait until it is processed.',
          ),
          backgroundColor: _magentaPulse,
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
            'You currently have a ${_formatLocalWithUsd(_currentInvestment, decimals: 2)} plan. Downgrades are not available.',
          ),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final pendingAmount = prefs.getDouble('global_pending_upload_amount');
    final pendingTimestamp = prefs.getInt('global_pending_upload_timestamp');

    if (pendingAmount == amount && pendingTimestamp != null) {
      final sessionStart =
          DateTime.fromMillisecondsSinceEpoch(pendingTimestamp);
      if (DateTime.now().difference(sessionStart).inHours < 1) {
        if (!mounted) return;
        await _showPaymentProofDialog(amount);
        return;
      } else {
        await prefs.remove('global_pending_upload_amount');
        await prefs.remove('global_pending_upload_timestamp');
      }
    }

    if (!mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panelTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Global Investment',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Investment Amount: ${_formatLocalWithUsd(amount, decimals: 2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Daily Return: ${_formatLocalWithUsd(amount * _dailyReturnRate, decimals: 2)}',
              style: TextStyle(color: _lavenderGlow, fontSize: 14),
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
            style: FilledButton.styleFrom(backgroundColor: _accentPurple),
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
              backgroundColor: _panelTint,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              scrollable: true,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accentPurple.withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.payment, color: _lavenderGlow, size: 24),
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
                          color: _accentPurple.withAlpha((0.12 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _accentPurple.withAlpha((0.3 * 255).round()),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: _lavenderGlow, size: 20),
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
                              'global_pending_upload_amount', amount);
                          await prefs.setInt(
                            'global_pending_upload_timestamp',
                            DateTime.now().millisecondsSinceEpoch,
                          );
                          if (!dialogContext.mounted) {
                            return;
                          }
                          Navigator.pop(dialogContext, 'upload');
                        }
                      : null,
                  style: FilledButton.styleFrom(backgroundColor: _accentPurple),
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
                              FittedBox(
                                alignment: Alignment.centerRight,
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _formatLocalCurrency(amount, decimals: 2),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!_isUnitedStates) ...[
                                const SizedBox(height: 2),
                                FittedBox(
                                  alignment: Alignment.centerRight,
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _formatUsdAmount(amount, decimals: 2),
                                    style: TextStyle(
                                      color: Colors.white
                                          .withAlpha((0.7 * 255).round()),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
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
              backgroundColor: _panelTint,
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
                        prefixText: _currencyPrefix(_countryOption.currencySymbol),
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
                          borderSide: const BorderSide(color: _accentPurple),
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
                                ? _accentPurple
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
                                  ? _lavenderGlow
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
                                    ? _lavenderGlow
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
                  style: FilledButton.styleFrom(backgroundColor: _accentPurple),
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
      folder: 'global',
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

    final username = prefs.getString('global_user_name') ?? 'NGMY User';
    final proof = PaymentProof(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: username,
      investmentAmount: investmentAmount,
      paidAmount: paidAmount,
      screenshotPath: storedScreenshotPath,
      submittedAt: DateTime.now(),
      status: 'pending',
      scope: 'global',
    );

    final proofsList = prefs.getStringList('global_payment_proofs') ?? [];
    proofsList.add(json.encode(proof.toJson()));
    await prefs.setStringList('global_payment_proofs', proofsList);

    await prefs.setDouble('global_pending_investment_amount', investmentAmount);
    await prefs.setDouble(
      '${username}_global_pending_investment_amount',
      investmentAmount,
    );

    await prefs.remove('global_pending_upload_amount');
    await prefs.remove('global_pending_upload_timestamp');

    await _loadInvestment();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Payment proof submitted! Waiting for approval.'),
        backgroundColor: _magentaPulse,
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
              _deepPurple,
              _midPurple,
              _deepPurple,
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
              color: _accentPurple.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _accentPurple.withAlpha((0.35 * 255).round()),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: _lavenderGlow, size: 16),
                const SizedBox(width: 4),
                Text(
                  '2.86%',
                  style: TextStyle(
                    color: _lavenderGlow,
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
        color: _magentaPulse.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _magentaPulse.withAlpha((0.3 * 255).round()),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _magentaPulse.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.pending_actions,
              color: _lavenderGlow,
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
                  '${_formatLocalWithUsd(_pendingProofAmount!, decimals: 2)} investment awaiting review',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.hourglass_empty,
            color: _lavenderGlow,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentInvestment() {
    final showUsdLine = !_isUnitedStates;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _currentInvestment > 0
              ? [_accentPurple, _lavenderGlow]
              : [_panelTint, _deepPurple],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_currentInvestment > 0 ? _accentPurple : Colors.black)
                .withAlpha((0.3 * 255).round()),
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
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                _formatLocalCurrency(_currentInvestment, decimals: 2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (showUsdLine) ...[
              const SizedBox(height: 6),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatUsdAmount(_currentInvestment, decimals: 2),
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
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
                      FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatLocalCurrency(_dailyEarnings, decimals: 2),
                          style: TextStyle(
                            color: _lavenderGlow,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (showUsdLine) ...[
                        const SizedBox(height: 2),
                        FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatUsdAmount(_dailyEarnings, decimals: 2),
                            style: TextStyle(
                              color: Colors.white
                                  .withAlpha((0.6 * 255).round()),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
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
                      FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatLocalCurrency(
                            _dailyEarnings * _workingDaysPerMonth,
                            decimals: 2,
                          ),
                          style: TextStyle(
                            color: _lavenderGlow,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (showUsdLine) ...[
                        const SizedBox(height: 2),
                        FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatUsdAmount(
                              _dailyEarnings * _workingDaysPerMonth,
                              decimals: 2,
                            ),
                            style: TextStyle(
                              color: Colors.white
                                  .withAlpha((0.6 * 255).round()),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
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

  final showUsdLine = !_isUnitedStates;
  final planLocal = _formatLocalCurrency(amount, decimals: 2);
  final planUsd = showUsdLine
    ? _formatUsdAmount(amount, decimals: 2)
    : null;
  final dailyLocal = _formatLocalCurrency(dailyReturn, decimals: 2);
  final dailyUsd = showUsdLine
    ? _formatUsdAmount(dailyReturn, decimals: 2)
    : null;
  final monthlyLocal = _formatLocalCurrency(monthlyReturn, decimals: 2);
  final monthlyUsd = showUsdLine
    ? _formatUsdAmount(monthlyReturn, decimals: 2)
    : null;

    final statusLabel = isLocked
        ? 'Not Available'
        : isStatusLocked
            ? _accountStatus.blocksAllActions
                ? 'Suspended'
                : 'Disabled'
            : isPending
                ? 'Pending Approval'
                : 'Investment Plan';

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
                      FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          planLocal,
                          style: TextStyle(
                            color: isLocked || isPending || isStatusLocked
                                ? Colors.grey
                                : Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (planUsd != null) ...[
                        const SizedBox(height: 2),
                        FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            planUsd,
                            style: TextStyle(
                              color: Colors.white
                                  .withAlpha((0.6 * 255).round()),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: isPending
                              ? Colors.orange
                              : isLocked || isStatusLocked
                                  ? Colors.grey
                                      .withAlpha((0.8 * 255).round())
                                  : Colors.white
                                      .withAlpha((0.6 * 255).round()),
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
                      'Cannot downgrade from ${_formatLocalWithUsd(_currentInvestment, decimals: 2)}',
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
                  dailyLocal,
                  Icons.today,
                  isLocked || isStatusLocked ? Colors.grey : color,
                  usdValue: dailyUsd,
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
                  monthlyLocal,
                  Icons.calendar_month,
                  isLocked || isStatusLocked ? Colors.grey : color,
                  usdValue: monthlyUsd,
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
    Color color, {
    String? usdValue,
  }) {
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
        FittedBox(
          alignment: Alignment.center,
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (usdValue != null) ...[
          const SizedBox(height: 2),
          FittedBox(
            alignment: Alignment.center,
            fit: BoxFit.scaleDown,
            child: Text(
              usdValue,
              style: TextStyle(
                color: Colors.white.withAlpha((0.6 * 255).round()),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _currencyPrefix(String symbol) {
    if (symbol.trim().isEmpty) {
      return '';
    }
    final startsWithLetter = RegExp(r'^[A-Za-z]').hasMatch(symbol);
    return startsWithLetter ? '${symbol.trim()} ' : symbol.trim();
  }

  String _formatLocalCurrency(double usdAmount, {int decimals = 2}) {
    final option = _countryOption;
    final isParityCountry =
        option.code == CountryLocationService.defaultCountry.code;
    final formatted = isParityCountry
        ? option.formatUsd(usdAmount, decimals: decimals)
        : option.formatLocalAmount(usdAmount, decimals: decimals);
    return '${_currencyPrefix(option.currencySymbol)}$formatted';
  }

  String _formatUsdAmount(double usdAmount, {int decimals = 2}) {
    final defaultCountry = CountryLocationService.defaultCountry;
    final formatted =
        defaultCountry.formatUsd(usdAmount, decimals: decimals);
    return '${_currencyPrefix(defaultCountry.currencySymbol)}$formatted';
  }

  String _formatLocalWithUsd(double usdAmount, {int decimals = 2}) {
    final local = _formatLocalCurrency(usdAmount, decimals: decimals);
    if (_isUnitedStates) {
      return local;
    }
    final usd = _formatUsdAmount(usdAmount, decimals: decimals);
    return '$local ($usd)';
  }

}
