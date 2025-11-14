import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';
import 'penalty_history_screen.dart';
import 'growth_notifications_screen.dart';
import 'global/global_premium.dart';
import '../services/growth_account_guard.dart';
import '../models/referral_record.dart';

class GrowthProfileScreen extends StatefulWidget {
  const GrowthProfileScreen({super.key});

  @override
  State<GrowthProfileScreen> createState() => _GrowthProfileScreenState();
}

class _GrowthProfileScreenState extends State<GrowthProfileScreen>
    with TickerProviderStateMixin {
  double _totalBalance = 0.0;
  int _activeDays = 0;
  String _userName = 'NGMY User';
  String _userID = '';
  String _phoneNumber = '';
  String _referralCode = '';
  int _referralCount = 0;
  double _totalEarnings = 0.0;
  List<ReferralRecord> _referralHistory = const [];
  ReferralRecord? _latestReferral;
  bool _isVerified = false;
  Uint8List? _profilePicture;
  final ImagePicker _picker = ImagePicker();
  GrowthAccountStatus _accountStatus = const GrowthAccountStatus(
    username: 'NGMY User',
    isDisabled: false,
    isSuspended: false,
  );
  late AnimationController _globeRotationController;
  Timer? _liveMetricsTimer;
  bool _isPollingLiveMetrics = false;
  static const double _liveUpdateTolerance = 0.01;

  String _growthIdKey(String username) => '${username}_growth_user_id';
  String _legacyIdKey(String username) => '${username}_user_id';

  bool _looksGlobalId(String value) => value.toUpperCase().startsWith('GI-');
  bool _looksGrowthId(String value) => value.toUpperCase().startsWith('GR-');

  @override
  void initState() {
    super.initState();
    _globeRotationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat();
    _loadData();
    _startLiveMetricsRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload balance whenever screen is shown
    _refreshBalance();
  }

  @override
  void dispose() {
    _globeRotationController.dispose();
    _liveMetricsTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('growth_user_name') ?? 'NGMY User';
  final savedBalance = prefs.getDouble('${savedName}_balance') ?? prefs.getDouble('total_balance') ?? 0.0;
  final savedActiveDays = prefs.getInt('${savedName}_active_days') ?? prefs.getInt('active_days') ?? 0;
  final lifetimeEarnings = prefs.getDouble('${savedName}_total_earnings') ?? 0.0;
  final todayEarnings = prefs.getDouble('${savedName}_today_earnings') ?? 0.0;
  final lastClaimed = prefs.getDouble('${savedName}_last_claimed_amount') ?? 0.0;
  final pendingEarnings = todayEarnings - lastClaimed;
  final totalEarnings = lifetimeEarnings + (pendingEarnings > 0 ? pendingEarnings : 0.0);
    final referralRecords = ReferralRecord.decodeList(
      prefs.getString('${savedName}_referrals') ?? '[]',
    );
    await prefs.setInt('${savedName}_referral_count', referralRecords.length);
    final latestReferral = referralRecords.isNotEmpty ? referralRecords.first : null;
    final status = await GrowthAccountGuard.load(prefs: prefs, username: savedName);
    
    final shouldUpdateStatus =
        status.isDisabled != _accountStatus.isDisabled ||
        status.isSuspended != _accountStatus.isSuspended;

    if (mounted &&
        (savedBalance != _totalBalance ||
            savedActiveDays != _activeDays ||
            totalEarnings != _totalEarnings ||
            referralRecords.length != _referralCount ||
            !_sameLatestReferral(latestReferral, _latestReferral) ||
            shouldUpdateStatus)) {
      setState(() {
        _totalBalance = savedBalance;
        _activeDays = savedActiveDays;
        _totalEarnings = totalEarnings;
        _referralHistory = referralRecords;
        _latestReferral = latestReferral;
        _referralCount = referralRecords.length;
        _accountStatus = status;
      });
    }
  }

  void _startLiveMetricsRefresh() {
    _liveMetricsTimer?.cancel();
    _liveMetricsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollLiveMetrics(),
    );
  }

  Future<void> _pollLiveMetrics() async {
    if (!mounted || _isPollingLiveMetrics) {
      return;
    }

    _isPollingLiveMetrics = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = _userName != 'NGMY User'
          ? _userName
          : (prefs.getString('growth_user_name') ?? 'NGMY User');

      final latestBalance =
          prefs.getDouble('${savedName}_balance') ??
              prefs.getDouble('total_balance') ??
              0.0;
      final lifetimeEarnings =
          prefs.getDouble('${savedName}_total_earnings') ?? 0.0;
      final todayEarnings =
          prefs.getDouble('${savedName}_today_earnings') ?? 0.0;
      final lastClaimed =
          prefs.getDouble('${savedName}_last_claimed_amount') ?? 0.0;
      final pending = todayEarnings - lastClaimed;
      final latestTotalEarnings =
          lifetimeEarnings + (pending > 0 ? pending : 0.0);

      if (!mounted) {
        return;
      }

      final shouldUpdateBalance =
          (latestBalance - _totalBalance).abs() > _liveUpdateTolerance;
      final shouldUpdateEarnings =
          (latestTotalEarnings - _totalEarnings).abs() > _liveUpdateTolerance;

      if (shouldUpdateBalance || shouldUpdateEarnings) {
        setState(() {
          if (shouldUpdateBalance) {
            _totalBalance = latestBalance;
          }
          if (shouldUpdateEarnings) {
            _totalEarnings = latestTotalEarnings;
          }
        });
      }
    } finally {
      _isPollingLiveMetrics = false;
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get current username
    final savedName = prefs.getString('growth_user_name') ?? 'NGMY User';
    
    // Load from user-specific keys first, fallback to global
    final savedBalance = prefs.getDouble('${savedName}_balance') ?? prefs.getDouble('total_balance') ?? 0.0;
    final savedActiveDays = prefs.getInt('${savedName}_active_days') ?? prefs.getInt('active_days') ?? 0;
    final savedPhone = prefs.getString('${savedName}_phone') ?? prefs.getString('growth_user_phone') ?? '';
    final referralRecords = ReferralRecord.decodeList(
      prefs.getString('${savedName}_referrals') ?? '[]',
    );
    final referralCount = referralRecords.length;
    await prefs.setInt('${savedName}_referral_count', referralCount);
    
    // Load TOTAL LIFETIME EARNINGS plus any unclaimed daily income
    final lifetimeEarnings = prefs.getDouble('${savedName}_total_earnings') ?? 0.0;
    final todayEarnings = prefs.getDouble('${savedName}_today_earnings') ?? 0.0;
    final lastClaimed = prefs.getDouble('${savedName}_last_claimed_amount') ?? 0.0;
    final pendingEarnings = todayEarnings - lastClaimed;
    final totalEarnings = lifetimeEarnings + (pendingEarnings > 0 ? pendingEarnings : 0.0);
    
    // Load verification status from user-specific key
    final isVerified = prefs.getBool('${savedName}_verified') ?? prefs.getBool('user_verified') ?? false;
    
    // Load profile picture
    final profileBase64 = prefs.getString('${savedName}_profile_picture');
    Uint8List? profilePicture;
    if (profileBase64 != null && profileBase64.isNotEmpty) {
      try {
        profilePicture = base64Decode(profileBase64);
      } catch (e) {
        // If decoding fails, ignore
      }
    }
    
    // Generate or load user ID
    String userID =
        prefs.getString(_growthIdKey(savedName)) ??
        prefs.getString('growth_user_id') ??
        '';

    if (userID.isEmpty) {
      final legacyId = prefs.getString(_legacyIdKey(savedName)) ?? '';
      if (legacyId.isNotEmpty && !_looksGlobalId(legacyId)) {
        userID = legacyId;
      }
    }

    if (userID.isEmpty || _looksGlobalId(userID) || !_looksGrowthId(userID)) {
      userID = _generateUserID();
    }

    await prefs.setString('growth_user_id', userID);
    await prefs.setString(_growthIdKey(savedName), userID);
    final legacyKey = _legacyIdKey(savedName);
    if (prefs.containsKey(legacyKey)) {
      await prefs.remove(legacyKey);
    }
    
  // Generate or load referral code
    String refCode = prefs.getString('${savedName}_referral_code') ?? prefs.getString('growth_referral_code') ?? '';
    if (refCode.isEmpty) {
      refCode = _generateReferralCode();
      await prefs.setString('growth_referral_code', refCode);
      await prefs.setString('${savedName}_referral_code', refCode);
    }
    
    final status = await GrowthAccountGuard.load(prefs: prefs, username: savedName);

    if (mounted) {
      setState(() {
        _totalBalance = savedBalance;
        _activeDays = savedActiveDays;
        _userName = savedName;
        _userID = userID;
        _phoneNumber = savedPhone;
        _referralCode = refCode;
  _referralCount = referralCount;
  _referralHistory = referralRecords;
  _latestReferral = referralRecords.isNotEmpty ? referralRecords.first : null;
  _totalEarnings = totalEarnings; // Lifetime total earnings across the account
        _isVerified = isVerified; // Load verification status from admin settings
        _profilePicture = profilePicture;
        _accountStatus = status;
      });
    }
  }

  String _generateUserID() {
    // Generate Growth-specific ID with GR- prefix
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final suffix = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
    return 'GR-$suffix';
  }

  String _generateReferralCode() {
    // Generate referral code like NGMY-XXXX
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final suffix = List.generate(4, (index) => chars[random.nextInt(chars.length)]).join();
    return 'NGMY-$suffix';
  }

  Future<void> _saveProfilePicture() async {
    if (_profilePicture == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final profileBase64 = base64Encode(_profilePicture!);
    await prefs.setString('${_userName}_profile_picture', profileBase64);
  }

  Future<void> _pickProfilePicture() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _profilePicture = bytes;
        });
        await _saveProfilePicture();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('growth_user_name', name);
  }

  Future<void> _savePhoneNumber(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('growth_user_phone', phone);
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
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 24),
                      _buildStatsCards(),
                      const SizedBox(height: 24),
                      _buildReferralCard(),
                      const SizedBox(height: 24),
                      _buildGlobalProgramCard(),
                      const SizedBox(height: 24),
                      _buildSettingsSection(),
                      const SizedBox(height: 24),
                      _buildAccountSection(),
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
          const Spacer(),
          const Text(
            'Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showEditProfileDialog,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.shade400,
                      Colors.green.shade700,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withAlpha((0.5 * 255).round()),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _profilePicture != null
                    ? ClipOval(
                        child: Image.memory(
                          _profilePicture!,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                        ),
                      )
                    : const Icon(Icons.person, size: 48, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D4D3D),
                  shape: BoxShape.circle,
                ),
                child: GestureDetector(
                  onTap: _pickProfilePicture,
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.green.shade400,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          // User ID
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.badge, color: Colors.white.withAlpha((0.7 * 255).round()), size: 14),
              const SizedBox(width: 6),
              Text(
                'ID: $_userID',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _userID));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User ID copied to clipboard'), duration: Duration(seconds: 2)),
                  );
                },
                child: Icon(Icons.copy, color: Colors.white.withAlpha((0.5 * 255).round()), size: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Phone Number
          if (_phoneNumber.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone, color: Colors.white.withAlpha((0.7 * 255).round()), size: 14),
                const SizedBox(width: 6),
                Text(
                  _phoneNumber,
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          if (_isVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade400),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Colors.green, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Verified Member',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (_accountStatus.blocksAllActions || _accountStatus.withdrawOnly)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildAccountStatusNotice(),
            ),
        ],
      ),
    );
  }

  Widget _buildAccountStatusNotice() {
    final suspended = _accountStatus.blocksAllActions;
    final accent = suspended ? Colors.redAccent : Colors.orangeAccent;
    final icon = suspended ? Icons.block : Icons.pause_circle_filled;
    final title = suspended ? 'Account Suspended' : 'Account Disabled';
    final subtitle = suspended
        ? 'Investments and transfers are paused while this suspension is active.'
        : 'Investments are paused while the account is disabled. Withdrawals remain available.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withAlpha((0.4 * 255).round())),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: accent.withAlpha((0.85 * 255).round()),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Available Balance',
                '₦₲${_formatCurrency(_totalBalance)}',
                Icons.account_balance_wallet,
                Colors.green.shade400,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Active Days',
                '$_activeDays',
                Icons.calendar_today,
                Colors.blue.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Referrals',
                '$_referralCount',
                Icons.people,
                Colors.purple.shade400,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Earnings',
                '₦₲${_formatCurrency(_totalEarnings)}',
                Icons.trending_up,
                Colors.orange.shade400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? detail,
    String? helper,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail,
              style: TextStyle(
                color: Colors.white.withAlpha((0.7 * 255).round()),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (helper != null) ...[
            const SizedBox(height: 2),
            Text(
              helper,
              style: TextStyle(
                color: Colors.white.withAlpha((0.5 * 255).round()),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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

  String _formatCurrency(double amount) {
    final isNegative = amount.isNegative;
    final absolute = amount.abs();
    final fixed = absolute.toStringAsFixed(2);
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

    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';
    final prefix = isNegative ? '-' : '';
    return '$prefix${buffer.toString()}$decimalPart';
  }

  Widget _buildReferralCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade700,
            Colors.orange.shade500,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withAlpha((0.5 * 255).round()),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Referral Program',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.3 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '₦₲5/friend',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Invite friends and earn ₦₲5 for each friend who joins!',
            style: TextStyle(
              color: Colors.white.withAlpha((0.9 * 255).round()),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          // Your Referral Code
          const Text(
            'Your Referral Code',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withAlpha((0.3 * 255).round()),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _referralCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _referralCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Referral code copied!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.copy, color: Colors.orange, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareReferralCode,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showRedeemCodeDialog,
                  icon: const Icon(Icons.redeem, size: 18),
                  label: const Text('Enter Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha((0.3 * 255).round()),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white, width: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_referralHistory.isNotEmpty) ...[
            Text(
              'Recent referral activity',
              style: TextStyle(
                color: Colors.white.withAlpha((0.85 * 255).round()),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
      ..._referralHistory
        .take(4)
        .map((record) => _buildReferralHistoryTile(record)),
          ] else
            Text(
              'No referrals yet. Share your code to start earning.',
              style: TextStyle(
                color: Colors.white.withAlpha((0.7 * 255).round()),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlobalProgramCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const GlobalScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B2B65),
              Color(0xFF0F986A),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withAlpha((0.35 * 255).round()),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _globeRotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _globeRotationController.value * 2 * pi,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          Color(0xFF00A8E8),
                          Color(0xFF5CE0D8),
                          Color(0xFFF9C74F),
                          Color(0xFF00A8E8),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withAlpha((0.25 * 255).round()),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.public,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Global Income Program',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap to open worldwide earnings, separate wallet, and international opportunities.',
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.75 * 255).round()),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.18 * 255).round()),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.25 * 255).round()),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withAlpha((0.15 * 255).round()),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.flag_circle,
                    color: Colors.white.withAlpha((0.85 * 255).round()),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Built for members across Africa, the Americas, Europe, and beyond — one tap takes you to the full Global experience.',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _buildSettingItem(Icons.notifications, 'Notifications', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GrowthNotificationsScreen()),
          );
        }),
        _buildSettingItem(Icons.security, 'Security', () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Security settings coming soon')),
          );
        }),
        _buildSettingItem(Icons.language, 'Language', () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Language selection coming soon')),
          );
        }),
        _buildSettingItem(Icons.help_outline, 'Help & Support', () {
          _showSupportDialog();
        }),
      ],
    );
  }

  Widget _buildSettingItem(IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.08 * 255).round()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withAlpha((0.1 * 255).round()),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withAlpha((0.5 * 255).round()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _buildAccountItem(Icons.history, 'Penalty History', () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PenaltyHistoryScreen(
                scope: PenaltyHistoryScope.growth,
              ),
            ),
          );
        }),
        _buildAccountItem(Icons.privacy_tip, 'Privacy Policy', () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
          );
        }),
        _buildAccountItem(Icons.description, 'Terms of Service', () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const TermsOfServiceScreen()),
          );
        }),
        _buildAccountItem(Icons.info_outline, 'About', () {
          _showAboutDialog();
        }),
        _buildAccountItem(Icons.logout, 'Logout', () {
          _showLogoutDialog();
        }, isDestructive: true),
      ],
    );
  }

  Widget _buildAccountItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withAlpha((0.1 * 255).round())
              : Colors.white.withAlpha((0.08 * 255).round()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive
                ? Colors.red.withAlpha((0.3 * 255).round())
                : Colors.white.withAlpha((0.1 * 255).round()),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withAlpha((0.2 * 255).round())
                    : Colors.white.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isDestructive ? Colors.red : Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDestructive ? Colors.red : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDestructive ? Colors.red.withAlpha((0.5 * 255).round()) : Colors.white.withAlpha((0.5 * 255).round()),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userName);
    final phoneController = TextEditingController(text: _phoneNumber);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.person, color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white38),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.phone, color: Colors.white70),
                hintText: '+1234567890',
                hintStyle: TextStyle(color: Colors.white.withAlpha((0.3 * 255).round())),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white38),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green),
                ),
              ),
            ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _userName = nameController.text;
                _phoneNumber = phoneController.text;
              });
              await _saveUserName(nameController.text);
              await _savePhoneNumber(phoneController.text);
              
              if (!context.mounted) return;
              Navigator.pop(context);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _shareReferralCode() {
    // Create share text
    final shareText = '''
Join NGMY Growth Income and start earning!

Use my referral code: $_referralCode

Download the app and start earning passive income today!
''';
    
    // Copy to clipboard (simple share implementation)
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share message copied! Paste it to share with friends.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showRedeemCodeDialog() {
    final codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enter Referral Code', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the referral code from your friend to earn ₦₲5 bonus!',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'NGMY-XXXX',
                    hintStyle: TextStyle(color: Colors.white.withAlpha((0.3 * 255).round())),
                    filled: true,
                    fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () async {
              final code = codeController.text.trim().toUpperCase();
              if (code.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a code')),
                );
                return;
              }
              
              Navigator.pop(context);
              await _redeemReferralCode(code);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
  }

  Future<void> _redeemReferralCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = _userName;

    final alreadyRedeemed = prefs.getString('${savedName}_referred_by');
    final hasRedeemed = prefs.getBool('${savedName}_has_redeemed_referral') ??
        prefs.getBool('has_redeemed_referral') ?? false;

    if (alreadyRedeemed != null || hasRedeemed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already redeemed a referral code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (code == _referralCode) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot use your own referral code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!code.startsWith('NGMY-') || code.length != 9) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid referral code format'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final allUsers = prefs.getStringList('all_users') ?? [];
    String? referrer;
    for (final user in allUsers) {
      final userCode = prefs.getString('${user}_referral_code');
      if (userCode != null && userCode.toUpperCase() == code) {
        referrer = user;
        break;
      }
    }

    if (referrer == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid or inactive referral code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (referrer.toLowerCase() == savedName.toLowerCase()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot use your own referral code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final referrerReferrals = ReferralRecord.decodeList(
      prefs.getString('${referrer}_referrals') ?? '[]',
    );
    if (referrerReferrals
        .any((entry) => entry.username.toLowerCase() == savedName.toLowerCase())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This referral code was already used for this account'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    const bonusAmount = 5.0;

    final currentBalance =
        prefs.getDouble('${savedName}_balance') ?? prefs.getDouble('total_balance') ?? 0.0;
    final newBalance = currentBalance + bonusAmount;
    await prefs.setDouble('${savedName}_balance', newBalance);
    await prefs.setDouble('total_balance', newBalance);
    await prefs.setBool('${savedName}_has_redeemed_referral', true);
    await prefs.setString('${savedName}_redeemed_from_code', code);
    await prefs.setString('${savedName}_referred_by', referrer);

    final userReferralEarnings =
        prefs.getDouble('${savedName}_referral_earnings') ?? 0.0;
    await prefs.setDouble('${savedName}_referral_earnings', userReferralEarnings + bonusAmount);
    final userLifetime = prefs.getDouble('${savedName}_total_earnings') ?? 0.0;
    await prefs.setDouble('${savedName}_total_earnings', userLifetime + bonusAmount);

    final referrerBalance = prefs.getDouble('${referrer}_balance') ?? 0.0;
    await prefs.setDouble('${referrer}_balance', referrerBalance + bonusAmount);

    referrerReferrals.insert(
      0,
      ReferralRecord(
        username: savedName,
        code: code,
        usedAt: DateTime.now(),
      ),
    );
    await prefs.setString(
      '${referrer}_referrals',
      ReferralRecord.encodeList(referrerReferrals),
    );
    await prefs.setInt('${referrer}_referral_count', referrerReferrals.length);

    final referrerEarnings =
        prefs.getDouble('${referrer}_referral_earnings') ?? 0.0;
    await prefs.setDouble('${referrer}_referral_earnings', referrerEarnings + bonusAmount);
    final referrerLifetime = prefs.getDouble('${referrer}_total_earnings') ?? 0.0;
    await prefs.setDouble('${referrer}_total_earnings', referrerLifetime + bonusAmount);

  final now = DateTime.now();
  final notification = {
    'id': now.millisecondsSinceEpoch.toString(),
    'title': 'New Referral! 🎉',
    'message': '$savedName used your referral code! You earned ₦₲${bonusAmount.toStringAsFixed(2)}!',
    'type': 'success',
    'timestamp': now.toIso8601String(),
    'read': false,
    'fromSystem': true,
  };

  final referrerNotificationsJson =
    prefs.getString('${referrer}_notifications') ?? '[]';
  final referrerNotifications = (jsonDecode(referrerNotificationsJson) as List);
  referrerNotifications.insert(0, notification);
  await prefs.setString('${referrer}_notifications', jsonEncode(referrerNotifications));

    await _loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Referral code redeemed! ₦₲5 added to your balance'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Widget _buildReferralHistoryTile(ReferralRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha((0.18 * 255).round())),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.15 * 255).round()),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _formatHistorySubtitle(record),
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.6 * 255).round()),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatHistorySubtitle(ReferralRecord record) {
    final parts = <String>[];
    if (record.code != null && record.code!.isNotEmpty) {
      parts.add('Code ${record.code}');
    }
    if (record.usedAt != null) {
      parts.add(_formatRelativeTime(record.usedAt!));
    }
    return parts.isEmpty ? 'Referral recorded' : parts.join(' • ');
  }

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
    return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
  }

  bool _sameLatestReferral(ReferralRecord? a, ReferralRecord? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a == null || b == null) {
      return a == b;
    }
    final aUsed = a.usedAt?.toIso8601String();
    final bUsed = b.usedAt?.toIso8601String();
    return a.username == b.username && a.code == b.code && aUsed == bUsed;
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Help & Support', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Need help?', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.white),
              title: const Text('Email Support', style: TextStyle(color: Colors.white)),
              subtitle: const Text('support@ngmy.com', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.white),
              title: const Text('Live Chat', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Available 24/7', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('About', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Growth Income',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Text(
              'Earn passive income by sharing your bandwidth.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out successfully'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
