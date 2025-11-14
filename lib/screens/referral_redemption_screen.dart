import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/betting_data_store.dart';
import '../models/betting_models.dart';
import '../models/referral_record.dart';

class ReferralRedemptionScreen extends StatefulWidget {
  final String username;
  
  const ReferralRedemptionScreen({super.key, required this.username});

  @override
  State<ReferralRedemptionScreen> createState() => _ReferralRedemptionScreenState();
}

class _ReferralRedemptionScreenState extends State<ReferralRedemptionScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isRedeeming = false;
  String? _myReferralCode;
  List<ReferralRecord> _myReferrals = [];
  double _totalEarnings = 0.0;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadReferralData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load my referral code
    final myCode = prefs.getString('${widget.username}_referral_code');
    
    // Load my referrals list
  final referralsJson = prefs.getString('${widget.username}_referrals') ?? '[]';
  final referralsList = ReferralRecord.decodeList(referralsJson);
  await prefs.setInt('${widget.username}_referral_count', referralsList.length);
    
    // Load total earnings
    final earnings = prefs.getDouble('${widget.username}_referral_earnings') ?? 0.0;
    
    setState(() {
      _myReferralCode = myCode;
  _myReferrals = referralsList;
      _totalEarnings = earnings;
    });
  }

  Future<void> _redeemCode() async {
    final code = _codeController.text.trim().toUpperCase();
    
    if (code.isEmpty) {
      _showMessage('Please enter a referral code', Colors.orange);
      return;
    }

    setState(() => _isRedeeming = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if user already redeemed a code
      final alreadyRedeemed = prefs.getString('${widget.username}_referred_by');
      final hasRedeemedFlag = prefs.getBool('${widget.username}_has_redeemed_referral') ??
          prefs.getBool('has_redeemed_referral') ?? false;
      if (alreadyRedeemed != null) {
        _showMessage('You have already redeemed a referral code!', Colors.orange);
        setState(() => _isRedeeming = false);
        return;
      }
      if (hasRedeemedFlag) {
        _showMessage('You have already redeemed a referral code!', Colors.orange);
        setState(() => _isRedeeming = false);
        return;
      }
      
      // Find the user who owns this code
      String? referrerUsername;
      final allKeys = prefs.getKeys();
      
      for (final key in allKeys) {
        if (key.endsWith('_referral_code')) {
          final storedCode = prefs.getString(key);
          if (storedCode != null && storedCode.toUpperCase() == code) {
            // Extract username from key (remove '_referral_code' suffix)
            referrerUsername = key.substring(0, key.length - '_referral_code'.length);
            break;
          }
        }
      }
      
      if (referrerUsername == null) {
        _showMessage('Invalid referral code! Please check and try again.', Colors.red);
        setState(() => _isRedeeming = false);
        return;
      }
      
      // Don't allow self-referral
      if (referrerUsername.toLowerCase() == widget.username.toLowerCase()) {
        _showMessage('You cannot use your own referral code!', Colors.orange);
        setState(() => _isRedeeming = false);
        return;
      }

      final referrerReferrals = ReferralRecord.decodeList(
        prefs.getString('${referrerUsername}_referrals') ?? '[]',
      );

      if (referrerReferrals
          .any((entry) => entry.username.toLowerCase() == widget.username.toLowerCase())) {
        _showMessage('This account already used this referral code.', Colors.orange);
        setState(() => _isRedeeming = false);
        return;
      }
      
      // Award ₦₲2.00 to both users
      final wallet = BettingDataStore.instance;
      
      // Award to current user (referee)
      wallet.adjustBalance(2.00);
      wallet.addHistoryEntry(BettingHistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Referral Bonus',
        amount: 2.00,
        isCredit: true,
        category: TransactionCategory.deposit,
        icon: Icons.card_giftcard,
        color: Colors.green,
        timestamp: DateTime.now(),
      ));
      
      // Save referral relationship
      await prefs.setString('${widget.username}_referred_by', referrerUsername);
      await prefs.setBool('${widget.username}_has_redeemed_referral', true);
      await prefs.setString('${widget.username}_redeemed_from_code', code);
      
      // Update referee's earnings
      final myEarnings = prefs.getDouble('${widget.username}_referral_earnings') ?? 0.0;
      await prefs.setDouble('${widget.username}_referral_earnings', myEarnings + 2.00);
      final myLifetime = prefs.getDouble('${widget.username}_total_earnings') ?? 0.0;
      await prefs.setDouble('${widget.username}_total_earnings', myLifetime + 2.00);
      
      // Update referrer's data
      referrerReferrals.insert(
        0,
        ReferralRecord(
          username: widget.username,
          code: code,
          usedAt: DateTime.now(),
        ),
      );
      await prefs.setString(
        '${referrerUsername}_referrals',
        ReferralRecord.encodeList(referrerReferrals),
      );
      await prefs.setInt('${referrerUsername}_referral_count', referrerReferrals.length);

      final referrerEarnings = prefs.getDouble('${referrerUsername}_referral_earnings') ?? 0.0;
      await prefs.setDouble('${referrerUsername}_referral_earnings', referrerEarnings + 2.00);
      final referrerLifetime = prefs.getDouble('${referrerUsername}_total_earnings') ?? 0.0;
      await prefs.setDouble('${referrerUsername}_total_earnings', referrerLifetime + 2.00);
      
      // Award to referrer (if they're the current user in wallet)
      // Note: This only works if referrer is the active user. For full implementation,
      // you'd need to store pending rewards and apply them when that user logs in.
      if (referrerUsername == wallet.username) {
        wallet.adjustBalance(2.00);
        wallet.addHistoryEntry(BettingHistoryEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Referral Reward',
          amount: 2.00,
          isCredit: true,
          category: TransactionCategory.deposit,
          icon: Icons.people,
          color: Colors.purple,
          timestamp: DateTime.now(),
        ));
      }
      
      // Send notification to referrer
      final now = DateTime.now();
      final notification = {
        'id': now.millisecondsSinceEpoch.toString(),
        'title': 'New Referral! 🎉',
        'message': '${widget.username} used your referral code! You earned ₦₲2.00!',
        'type': 'success',
        'timestamp': now.toIso8601String(),
        'read': false,
        'fromSystem': true,
      };
      
  final referrerNotificationsJson = prefs.getString('${referrerUsername}_notifications') ?? '[]';
  final referrerNotifications = (jsonDecode(referrerNotificationsJson) as List);
      referrerNotifications.insert(0, notification);
      await prefs.setString('${referrerUsername}_notifications', jsonEncode(referrerNotifications));
      
      // Reload data
      await _loadReferralData();
      
      _showMessage('✅ Success! You and $referrerUsername both earned ₦₲2.00!', Colors.green);
      _codeController.clear();
      
    } catch (e) {
      _showMessage('Error: $e', Colors.red);
    } finally {
      setState(() => _isRedeeming = false);
    }
  }

  void _showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Referral System',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRedeemCodeCard(),
            const SizedBox(height: 20),
            _buildMyCodeCard(),
            const SizedBox(height: 20),
            _buildStatsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildRedeemCodeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.withAlpha((0.15 * 255).round()),
            Colors.teal.withAlpha((0.1 * 255).round()),
            Colors.white.withAlpha((0.05 * 255).round()),
          ],
        ),
        border: Border.all(
          color: Colors.green.withAlpha((0.3 * 255).round()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha((0.2 * 255).round()),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.teal.shade400],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.redeem_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter Referral Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Get ₦₲2.00 instantly!',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.05 * 255).round()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.withAlpha((0.3 * 255).round()),
              ),
            ),
            child: TextField(
              controller: _codeController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'ABC1234',
                hintStyle: TextStyle(
                  color: Colors.white.withAlpha((0.3 * 255).round()),
                  letterSpacing: 2,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                prefixIcon: Icon(
                  Icons.vpn_key_rounded,
                  color: Colors.green.shade300,
                ),
              ),
              maxLength: 10,
              enabled: !_isRedeeming,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isRedeeming ? null : _redeemCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                disabledBackgroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
              ),
              child: _isRedeeming
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Redeem Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyCodeCard() {
    if (_myReferralCode == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withAlpha((0.15 * 255).round()),
            Colors.purple.withAlpha((0.1 * 255).round()),
            Colors.white.withAlpha((0.05 * 255).round()),
          ],
        ),
        border: Border.all(
          color: Colors.blue.withAlpha((0.3 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Referral Code',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _myReferralCode!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share this code to earn ₦₲2.00 per referral',
            style: TextStyle(
              color: Colors.white.withAlpha((0.6 * 255).round()),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.withAlpha((0.15 * 255).round()),
            Colors.amber.withAlpha((0.1 * 255).round()),
            Colors.white.withAlpha((0.05 * 255).round()),
          ],
        ),
        border: Border.all(
          color: Colors.orange.withAlpha((0.3 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Referral Stats',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Referrals',
                  '${_myReferrals.length}',
                  Icons.people_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  'Total Earned',
                  '₦₲${_totalEarnings.toStringAsFixed(2)}',
                  Icons.monetization_on_rounded,
                  Colors.green,
                ),
              ),
            ],
          ),
          if (_myReferrals.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Text(
              'People you referred:',
              style: TextStyle(
                color: Colors.white.withAlpha((0.7 * 255).round()),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ..._myReferrals.map((record) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green.shade300,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (record.usedAt != null || record.code != null)
                              Text(
                                _formatReferralMoment(record.usedAt, record.code),
                                style: TextStyle(
                                  color: Colors.white.withAlpha((0.55 * 255).round()),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  String _formatReferralMoment(DateTime? timestamp, String? code) {
    final buffer = StringBuffer();
    if (code != null && code.isNotEmpty) {
      buffer.write('Code $code');
    }

    if (timestamp != null) {
      final now = DateTime.now();
      final difference = now.difference(timestamp);
      String formatted;
      if (difference.inMinutes < 1) {
        formatted = 'just now';
      } else if (difference.inHours < 1) {
        formatted = '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        formatted = '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        formatted = '${difference.inDays}d ago';
      } else {
        formatted = '${timestamp.month}/${timestamp.day}/${timestamp.year}';
      }
      if (buffer.isNotEmpty) {
        buffer.write(' • ');
      }
      buffer.write(formatted);
    }

    return buffer.isEmpty ? 'Referral recorded' : buffer.toString();
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withAlpha((0.3 * 255).round()),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha((0.6 * 255).round()),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
