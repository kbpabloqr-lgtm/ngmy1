import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import '../terms_of_service_screen.dart';
import '../privacy_policy_screen.dart';
import '../penalty_history_screen.dart';
import 'global_notifications_screen.dart';
import '../../services/global_account_guard.dart';
import '../../models/referral_record.dart';
import '../../services/country_location_service.dart';

class GlobalProfileScreen extends StatefulWidget {
  const GlobalProfileScreen({super.key});

  @override
  State<GlobalProfileScreen> createState() => _GlobalProfileScreenState();

}

class _GlobalProfileScreenState extends State<GlobalProfileScreen> {
  static const Color _deepPurple = Color(0xFF140C2F);
  static const Color _midPurple = Color(0xFF1F1147);
  static const Color _accentPurple = Color(0xFF6C3FDB);
  static const Color _softPurple = Color(0xFFA379FF);
  static const Color _lavender = Color(0xFF8C7CFF);
  static const Color _magentaGlow = Color(0xFFD29BFF);
  static const double _statCardHeight = 152;
  static const double _liveUpdateTolerance = 0.01;

  double _totalBalance = 0.0;
  double _totalEarnings = 0.0;
  int _activeDays = 0;

  String _userName = 'NGMY User';
  String _userID = '';
  String _phoneNumber = '';
  String _referralCode = '';
  int _referralCount = 0;
  List<ReferralRecord> _referralHistory = const <ReferralRecord>[];
  ReferralRecord? _latestReferral;

  bool _isVerified = false;
  Uint8List? _profilePicture;
  final ImagePicker _picker = ImagePicker();
  GlobalAccountStatus _accountStatus = const GlobalAccountStatus(
    username: 'NGMY User',
    isDisabled: false,
    isSuspended: false,
  );
  Timer? _liveMetricsTimer;
  bool _isPollingLiveMetrics = false;
  bool _isDetectingLocation = false;
  double? _locationLatitude;
  double? _locationLongitude;
  double? _locationAccuracy;
  DateTime? _locationTimestamp;
  bool _locationConfidenceHigh = false;
  String? _locationError;
  bool _countryLocked = false;
  CountryOption _countryOption = CountryLocationService.defaultCountry;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startLiveMetricsRefresh();
  }

  String _readUsername(SharedPreferences prefs) {
    return prefs.getString('global_user_name') ??
        prefs.getString('Global_user_name') ??
        'NGMY User';
  }

  String _uKey(String username, String suffix) => '${username}_global_$suffix';
  String _gKey(String suffix) => 'global_$suffix';
  String _legacyKey(String username, String suffix) => '${username}_$suffix';
  String _namespacedUserIdKey(String username) => '${username}_global_user_id';
  bool _isGlobalUserId(String value) => value.toUpperCase().startsWith('GI-');

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
      final savedName = _readUsername(prefs);

      final latestBalance =
          prefs.getDouble(_uKey(savedName, 'balance')) ?? 0.0;
      final lifetimeEarnings =
          prefs.getDouble(_uKey(savedName, 'total_earnings')) ?? 0.0;
      final todayEarnings =
          prefs.getDouble(_uKey(savedName, 'today_earnings')) ?? 0.0;
      final lastClaimed =
          prefs.getDouble(_uKey(savedName, 'last_claimed_amount')) ?? 0.0;
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

  @override
  void dispose() {
    _liveMetricsTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
  final prefs = await SharedPreferences.getInstance();

  // Get current username
  final savedName = _readUsername(prefs);

  // Load from user-specific keys first, fallback to legacy keys
  final approvedInvestment =
    prefs.getDouble(_uKey(savedName, 'approved_investment')) ??
    prefs.getDouble(_gKey('approved_investment')) ??
    0.0;
  final hasInvestment = approvedInvestment > 0;

  double savedBalance =
    prefs.getDouble(_uKey(savedName, 'balance')) ??
    0.0;
  int savedActiveDays =
    prefs.getInt(_uKey(savedName, 'active_days')) ??
    prefs.getInt(_gKey('active_days')) ??
    0;
  final savedPhone =
    prefs.getString(_uKey(savedName, 'phone')) ??
    prefs.getString(_gKey('user_phone')) ??
    '';
  final referralRecords = ReferralRecord.decodeList(
    prefs.getString(_uKey(savedName, 'referrals')) ?? '[]',
  );
  final referralCount = referralRecords.length;
  await prefs.setInt(_uKey(savedName, 'referral_count'), referralCount);
  final latestReferral =
      referralRecords.isNotEmpty ? referralRecords.first : null;

  // Load TOTAL LIFETIME EARNINGS plus any unclaimed daily income
  final lifetimeEarnings =
      prefs.getDouble(_uKey(savedName, 'total_earnings')) ?? 0.0;
  final todayEarnings =
      prefs.getDouble(_uKey(savedName, 'today_earnings')) ?? 0.0;
  final lastClaimed =
      prefs.getDouble(_uKey(savedName, 'last_claimed_amount')) ?? 0.0;
  final pendingEarnings = todayEarnings - lastClaimed;
  double totalEarnings =
      lifetimeEarnings + (pendingEarnings > 0 ? pendingEarnings : 0.0);

  // Load verification status from user-specific key
  final isVerified =
      prefs.getBool(_uKey(savedName, 'verified')) ??
          prefs.getBool('${savedName}_verified') ??
          prefs.getBool('user_verified') ??
          false;

  // Load profile picture
  final profileBase64 =
      prefs.getString(_uKey(savedName, 'profile_picture')) ??
      prefs.getString('${savedName}_profile_picture');
  Uint8List? profilePicture;
  if (profileBase64 != null && profileBase64.isNotEmpty) {
    try {
      profilePicture = base64Decode(profileBase64);
    } catch (_) {
      // Ignore decode failures for legacy data
    }
  }

  if (!hasInvestment) {
    savedBalance = 0.0;
    savedActiveDays = 0;
    totalEarnings = 0.0;
  }

  // Generate or load user ID
  final legacyUserKey = _legacyKey(savedName, 'user_id');
  String userID =
      prefs.getString(_uKey(savedName, 'user_id')) ??
      prefs.getString(_namespacedUserIdKey(savedName)) ??
      prefs.getString(_gKey('user_id')) ??
      prefs.getString('Global_user_id') ??
      prefs.getString('global_user_id') ??
      prefs.getString(legacyUserKey) ??
      '';
  if (userID.isEmpty || !_isGlobalUserId(userID)) {
    userID = _generateUserID();
  }
  await prefs.setString(_gKey('user_id'), userID);
  await prefs.setString(_uKey(savedName, 'user_id'), userID);
  await prefs.setString(_namespacedUserIdKey(savedName), userID);
  await prefs.setString('Global_user_id', userID);
  await prefs.setString('global_user_id', userID);
  if (prefs.containsKey(legacyUserKey)) {
    await prefs.remove(legacyUserKey);
  }

  // Generate or load referral code
  String refCode = prefs.getString('${savedName}_referral_code') ??
      prefs.getString('Global_referral_code') ??
      '';
  if (refCode.isEmpty) {
    refCode = _generateReferralCode();
    await prefs.setString('Global_referral_code', refCode);
    await prefs.setString('${savedName}_referral_code', refCode);
  }

  final status =
      await GlobalAccountGuard.load(prefs: prefs, username: savedName);

  final storedCountryCode =
      prefs.getString(_uKey(savedName, 'country_code')) ??
      prefs.getString('global_country_code');
  final detectedCountry =
      CountryLocationService.optionForCode(storedCountryCode) ??
      CountryLocationService.defaultCountry;
  final storedLocked =
      prefs.getBool(_uKey(savedName, 'country_locked')) ??
      prefs.getBool('global_country_locked') ??
      false;
  final storedLatitude =
      prefs.getDouble(_uKey(savedName, 'location_lat')) ??
      prefs.getDouble('global_location_lat');
  final storedLongitude =
      prefs.getDouble(_uKey(savedName, 'location_lon')) ??
      prefs.getDouble('global_location_lon');
  final storedAccuracy =
      prefs.getDouble(_uKey(savedName, 'location_accuracy')) ??
      prefs.getDouble('global_location_accuracy');
  final storedTimestampMs =
      prefs.getInt(_uKey(savedName, 'location_timestamp')) ??
      prefs.getInt('global_location_timestamp');
  DateTime? storedTimestamp;
  if (storedTimestampMs != null) {
    storedTimestamp = DateTime.fromMillisecondsSinceEpoch(storedTimestampMs);
  }
  final storedConfidence =
      prefs.getBool(_uKey(savedName, 'location_confidence_high')) ??
      prefs.getBool('global_location_confidence_high') ??
      false;

  final shouldUpdateStatus =
      status.isDisabled != _accountStatus.isDisabled ||
      status.isSuspended != _accountStatus.isSuspended;

  final shouldUpdate =
      savedBalance != _totalBalance ||
      savedActiveDays != _activeDays ||
      totalEarnings != _totalEarnings ||
      referralCount != _referralCount ||
      !_sameLatestReferral(latestReferral, _latestReferral) ||
      shouldUpdateStatus ||
      _userName != savedName ||
      _userID != userID ||
      _phoneNumber != savedPhone ||
      _referralCode != refCode ||
      _isVerified != isVerified ||
      _profilePicture != profilePicture ||
      _countryOption.code != detectedCountry.code ||
      _countryLocked != storedLocked ||
      _locationLatitude != storedLatitude ||
      _locationLongitude != storedLongitude ||
      _locationAccuracy != storedAccuracy ||
      (_locationTimestamp?.millisecondsSinceEpoch ?? -1) !=
          (storedTimestamp?.millisecondsSinceEpoch ?? -1) ||
      _locationConfidenceHigh != storedConfidence ||
      _locationError != null;

  if (mounted && shouldUpdate) {
    setState(() {
      _totalBalance = savedBalance;
      _activeDays = savedActiveDays;
      _userName = savedName;
      _userID = userID;
      _phoneNumber = savedPhone;
      _referralCode = refCode;
      _referralCount = referralCount;
      _referralHistory = referralRecords;
      _latestReferral = latestReferral;
      _totalEarnings = totalEarnings;
      _isVerified = isVerified;
      _profilePicture = profilePicture;
      _accountStatus = status;
      _countryOption = detectedCountry;
      _countryLocked = storedLocked;
      _locationLatitude = storedLatitude;
      _locationLongitude = storedLongitude;
      _locationAccuracy = storedAccuracy;
      _locationTimestamp = storedTimestamp;
      _locationConfidenceHigh = storedConfidence;
      _locationError = null;
    });
  }

  if (!_countryLocked ||
      _locationLatitude == null ||
      _locationLongitude == null) {
    await _maybeDetectLocation();
  }
  }

  String _generateUserID() {
    // Generate Global-specific ID with GI- prefix
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final suffix = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
    return 'GI-$suffix';
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
  await prefs.setString(_uKey(_userName, 'profile_picture'), profileBase64);
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
            SnackBar(
              content: const Text('Profile picture updated successfully!'),
              backgroundColor: _accentPurple,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gKey('user_name'), name);
    await prefs.setString('Global_user_name', name);
    if (name.trim().isNotEmpty) {
      await prefs.setString(_uKey(name, 'user_name'), name);
      await prefs.setString(_uKey(name, 'display_name'), name);
    }
  }

  Future<void> _savePhoneNumber(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gKey('user_phone'), phone);
    await prefs.setString('Global_user_phone', phone);
    if (_userName.trim().isNotEmpty) {
      await prefs.setString(_uKey(_userName, 'phone'), phone);
    }
  }

  CountryOption get _effectiveCountry => _countryOption;
  bool get _isUnitedStates =>
      _countryOption.code == CountryLocationService.defaultCountry.code;

  String _currencyPrefix(String symbol) {
    if (symbol.trim().isEmpty) {
      return '';
    }
    final startsWithLetter = RegExp(r'^[A-Za-z]').hasMatch(symbol);
    return startsWithLetter ? '${symbol.trim()} ' : symbol.trim();
  }

  String _formatLocalCurrency(double usdAmount, {int decimals = 2}) {
    final option = _effectiveCountry;
    final isParityCountry =
        option.code == CountryLocationService.defaultCountry.code;
    final formatted = isParityCountry
        ? option.formatUsd(usdAmount, decimals: decimals)
        : option.formatLocalAmount(usdAmount, decimals: decimals);
    return '${_currencyPrefix(option.currencySymbol)}$formatted';
  }

  String _formatUsdAmount(double usdAmount, {int decimals = 2}) {
    final formatted = CountryLocationService.defaultCountry
        .formatUsd(usdAmount, decimals: decimals);
    return '${r'$'}$formatted';
  }

  String _formatLocalWithUsd(double usdAmount, {int decimals = 2}) {
    final local = _formatLocalCurrency(usdAmount, decimals: decimals);
    final usd = _formatUsdAmount(usdAmount, decimals: decimals);
    return '$local ($usd)';
  }

  String? _formatCoordinatePair() {
    if (_locationLatitude == null || _locationLongitude == null) {
      return null;
    }
    final lat = _locationLatitude!.toStringAsFixed(4);
    final lon = _locationLongitude!.toStringAsFixed(4);
    return '$lat, $lon';
  }

  Future<void> _persistCountrySelection({
    required CountryOption option,
    required bool lock,
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? timestamp,
    bool confidenceHigh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final username = _userName.trim().isNotEmpty ? _userName : _readUsername(prefs);

    await prefs.setString(_uKey(username, 'country_code'), option.code);
    await prefs.setString(_uKey(username, 'country_name'), option.name);
    await prefs.setString(_uKey(username, 'currency_code'), option.currencyCode);
    await prefs.setString(_uKey(username, 'currency_symbol'), option.currencySymbol);
    await prefs.setDouble(_uKey(username, 'usd_rate'), option.usdToLocalRate);
    await prefs.setString(_uKey(username, 'country_region'), option.region);
    await prefs.setBool(_uKey(username, 'country_locked'), lock);
    await prefs.setBool(
      _uKey(username, 'location_confidence_high'),
      confidenceHigh,
    );

    if (latitude != null) {
      await prefs.setDouble(_uKey(username, 'location_lat'), latitude);
    }
    if (longitude != null) {
      await prefs.setDouble(_uKey(username, 'location_lon'), longitude);
    }
    if (accuracy != null) {
      await prefs.setDouble(_uKey(username, 'location_accuracy'), accuracy);
    }
    if (timestamp != null) {
      await prefs.setInt(
        _uKey(username, 'location_timestamp'),
        timestamp.millisecondsSinceEpoch,
      );
    }

    await prefs.setString('global_country_code', option.code);
    await prefs.setString('global_country_name', option.name);
    await prefs.setString('global_currency_code', option.currencyCode);
    await prefs.setString('global_currency_symbol', option.currencySymbol);
    await prefs.setDouble('global_usd_rate', option.usdToLocalRate);
    await prefs.setString('global_country_region', option.region);
    await prefs.setBool('global_country_locked', lock);
    await prefs.setBool('global_location_confidence_high', confidenceHigh);

    if (latitude != null) {
      await prefs.setDouble('global_location_lat', latitude);
    }
    if (longitude != null) {
      await prefs.setDouble('global_location_lon', longitude);
    }
    if (accuracy != null) {
      await prefs.setDouble('global_location_accuracy', accuracy);
    }
    if (timestamp != null) {
      await prefs.setInt(
        'global_location_timestamp',
        timestamp.millisecondsSinceEpoch,
      );
    }
  }

  Future<void> _maybeDetectLocation({bool force = false}) async {
    if (!mounted) {
      return;
    }

    if (_isDetectingLocation) {
      return;
    }

    final hasExistingCoords =
        _locationLatitude != null && _locationLongitude != null;
    if (!force && _countryLocked && hasExistingCoords) {
      return;
    }

    setState(() {
      _isDetectingLocation = true;
      _locationError = null;
    });

    final result = await CountryLocationService.detectCountry();

    if (!mounted) {
      return;
    }

    if (result.country != null) {
      final option = result.country!;
      final timestamp = DateTime.now();
      await _persistCountrySelection(
        option: option,
        lock: result.confidenceHigh,
        latitude: result.latitude,
        longitude: result.longitude,
        accuracy: result.accuracyMeters,
        timestamp: timestamp,
        confidenceHigh: result.confidenceHigh,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _countryOption = option;
        _countryLocked = result.confidenceHigh;
        _locationLatitude = result.latitude;
        _locationLongitude = result.longitude;
        _locationAccuracy = result.accuracyMeters;
        _locationTimestamp = timestamp;
        _locationConfidenceHigh = result.confidenceHigh;
        _locationError = null;
      });
    } else if (force) {
      setState(() {
        _locationError = result.error ?? 'Unable to determine location';
        _locationConfidenceHigh = false;
      });
    }

    if (mounted) {
      setState(() {
        _isDetectingLocation = false;
      });
    }
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
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 24),
                      _buildStatsCards(),
                      const SizedBox(height: 24),
                      _buildReferralCard(),
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
                      _softPurple,
                      _accentPurple,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accentPurple.withAlpha((0.5 * 255).round()),
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
                decoration: BoxDecoration(
                  color: _midPurple,
                  shape: BoxShape.circle,
                ),
                child: GestureDetector(
                  onTap: _pickProfilePicture,
                  child: Icon(
                    Icons.camera_alt,
                    color: _softPurple,
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
                      SnackBar(
                        content: const Text('User ID copied to clipboard'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: _accentPurple,
                      ),
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
          if (_countryOption.name.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.public,
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                    size: 14),
                const SizedBox(width: 6),
                Text(
                  '${_countryOption.name} · ${_currencyPrefix(_effectiveCountry.currencySymbol)}',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (_formatCoordinatePair() != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on,
                        color: Colors.white.withAlpha((0.6 * 255).round()),
                        size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _formatCoordinatePair()!,
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.6 * 255).round()),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _countryLocked ? Icons.lock : Icons.edit_location_alt,
                    color: _countryLocked
                        ? Colors.orangeAccent
                        : Colors.white.withAlpha((0.6 * 255).round()),
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _countryLocked
                        ? (_locationConfidenceHigh
                            ? 'Locked by live location'
                            : 'Country locked')
                        : 'Editable location',
                    style: TextStyle(
                      color: _countryLocked
                          ? Colors.orangeAccent
                          : Colors.white.withAlpha((0.6 * 255).round()),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (_locationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _locationError!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
          const SizedBox(height: 12),
          if (_isVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _softPurple.withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _softPurple),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Verified Member',
                    style: TextStyle(
                      color: Colors.white,
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
  final balanceLocal = _formatLocalCurrency(_totalBalance, decimals: 2);
  final balanceUsd = _formatUsdAmount(_totalBalance, decimals: 2);
  final earningsLocal = _formatLocalCurrency(_totalEarnings, decimals: 2);
  final earningsUsd = _formatUsdAmount(_totalEarnings, decimals: 2);
  final showUsdCompanion = !_isUnitedStates;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Available Balance',
                balanceLocal,
                Icons.account_balance_wallet,
                _softPurple,
                detail: showUsdCompanion ? balanceUsd : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Active Days',
                '$_activeDays',
                Icons.calendar_today,
                _lavender,
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
                _accentPurple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Earnings',
                earningsLocal,
                Icons.trending_up,
                _magentaGlow,
                detail: showUsdCompanion ? earningsUsd : null,
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
    final detailStyle = TextStyle(
      color: Colors.white.withAlpha((0.7 * 255).round()),
      fontSize: 11,
    );
    final helperStyle = TextStyle(
      color: Colors.white.withAlpha((0.5 * 255).round()),
      fontSize: 11,
    );
    final labelStyle = TextStyle(
      color: Colors.white.withAlpha((0.6 * 255).round()),
      fontSize: 12,
    );

    return SizedBox(
      height: _statCardHeight,
      child: Container(
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
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildScaledStatLine(
                    value,
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 4),
                    _buildScaledStatLine(detail, detailStyle),
                  ],
                  if (helper != null) ...[
                    const SizedBox(height: 3),
                    _buildScaledStatLine(helper, helperStyle),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            _buildScaledStatLine(label, labelStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildScaledStatLine(String text, TextStyle style) {
    return SizedBox(
      width: double.infinity,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildReferralCard() {
    const double referralBonusUsd = 5.0;
    final referralBonusLocal = _formatLocalCurrency(referralBonusUsd, decimals: 2);
    final referralBonusWithUsd =
        _formatLocalWithUsd(referralBonusUsd, decimals: 2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentPurple,
            _softPurple,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _accentPurple.withAlpha((0.4 * 255).round()),
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
                child: Text(
                  '$referralBonusLocal/friend',
                  style: const TextStyle(
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
            'Invite friends and earn $referralBonusWithUsd for each friend who joins!',
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
                      SnackBar(
                        content: Text('Referral code copied!'),
                        backgroundColor: _accentPurple,
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
                      child: Icon(Icons.copy, color: _accentPurple, size: 20),
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
                    foregroundColor: _accentPurple,
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
            MaterialPageRoute(builder: (context) => const GlobalNotificationsScreen()),
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
                scope: PenaltyHistoryScope.global,
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
    final countries = CountryLocationService.supportedCountries;

    CountryOption tempSelection = _countryOption;
    CountryOption lockedAnchor = _countryOption;
    bool tempLocked = _countryLocked;
    bool manualOverride = !_countryLocked;
    bool detectionInProgress = false;
    bool detectionConfidence = _locationConfidenceHigh;
    String? detectionMessage = _locationError;
    bool detectionMessageIsError = _locationError != null;
    double? detectedLatitude = _locationLatitude;
    double? detectedLongitude = _locationLongitude;
    double? detectedAccuracy = _locationAccuracy;
    DateTime? detectedTimestamp = _locationTimestamp;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> detectLocation() async {
              setDialogState(() {
                detectionInProgress = true;
                detectionMessage = null;
                detectionMessageIsError = false;
              });

              final result = await CountryLocationService.detectCountry();

              if (!mounted) {
                return;
              }

              if (result.country != null) {
                final detectedCountry = result.country!;
                setDialogState(() {
                  tempSelection = detectedCountry;
                  tempLocked = result.confidenceHigh;
                  manualOverride = !result.confidenceHigh;
                  detectionConfidence = result.confidenceHigh;
                  detectionMessageIsError = false;
                  lockedAnchor = detectedCountry;
                  detectedLatitude = result.latitude;
                  detectedLongitude = result.longitude;
                  detectedAccuracy = result.accuracyMeters;
                  detectedTimestamp = DateTime.now();
                  detectionMessage = result.confidenceHigh
                      ? 'Live location locked to ${detectedCountry.name}.'
                      : 'Location detected with low confidence. Adjust manually if needed.';
                });
              } else {
                setDialogState(() {
                  detectionConfidence = false;
                  detectionMessageIsError = true;
                  detectionMessage = result.error ?? 'Unable to determine location.';
                });
              }

              setDialogState(() {
                detectionInProgress = false;
              });
            }

            bool isOptionEnabled(CountryOption option) {
              if (manualOverride) {
                return true;
              }
              if (!tempLocked) {
                return true;
              }
              return CountryLocationService.shareRegion(lockedAnchor, option);
            }

            Color messageColor() {
              if (detectionMessageIsError) {
                return Colors.redAccent;
              }
              if (detectionConfidence && !manualOverride) {
                return Colors.tealAccent;
              }
              return Colors.orangeAccent;
            }

            final dropdownItems = countries
                .map(
                  (option) => DropdownMenuItem<CountryOption>(
                    value: option,
                    enabled: isOptionEnabled(option),
                    child: Text(
                      '${option.name} (${option.currencySymbol})',
                      style: TextStyle(
                        color: isOptionEnabled(option)
                            ? Colors.white
                            : Colors.white.withAlpha((0.4 * 255).round()),
                      ),
                    ),
                  ),
                )
                .toList();

            return AlertDialog(
              backgroundColor: _midPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Text(
                    'Edit Profile',
                    style: TextStyle(color: Colors.white),
                  ),
                  if (tempLocked)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha((0.2 * 255).round()),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Location Locked',
                        style: TextStyle(color: Colors.orange, fontSize: 11),
                      ),
                    ),
                ],
              ),
              content: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
                  ),
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
                            borderSide: BorderSide(color: _softPurple),
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
                          hintStyle:
                              TextStyle(color: Colors.white.withAlpha((0.3 * 255).round())),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white38),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _softPurple),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<CountryOption>(
                        initialValue: tempSelection,
                        items: dropdownItems,
                        dropdownColor: _midPurple,
                        iconEnabledColor: Colors.white70,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Country / Location',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.flag, color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white38),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _softPurple),
                          ),
                        ),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          if (!manualOverride && tempLocked && !CountryLocationService.shareRegion(lockedAnchor, value)) {
                            setDialogState(() {
                              detectionMessage =
                                  'Manual override required to switch outside ${lockedAnchor.name}\'s region.';
                              detectionMessageIsError = false;
                            });
                            return;
                          }
                          setDialogState(() {
                            tempSelection = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: detectionInProgress ? null : detectLocation,
                          icon: detectionInProgress
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.tealAccent,
                                  ),
                                )
                              : const Icon(Icons.my_location_outlined,
                                  color: Colors.tealAccent),
                          label: Text(
                            detectionInProgress ? 'Detecting...' : 'Use Live Location',
                            style: const TextStyle(color: Colors.tealAccent),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.tealAccent,
                          ),
                        ),
                      ),
                      if (tempLocked || _countryLocked)
                        SwitchListTile.adaptive(
                          value: manualOverride,
                          onChanged: (value) {
                            setDialogState(() {
                              manualOverride = value;
                              if (value) {
                                tempLocked = false;
                                detectionConfidence = false;
                              } else {
                                tempLocked = true;
                                tempSelection = lockedAnchor;
                                detectionMessageIsError = false;
                                detectionMessage = 'Location locked to ${lockedAnchor.name}.';
                              }
                            });
                          },
                          activeThumbColor: Colors.tealAccent,
              activeTrackColor: Colors.tealAccent
                .withAlpha((0.35 * 255).round()),
                          title: const Text(
                            'Manual override',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            manualOverride
                                ? 'Override enabled — choose any country.'
                                : 'Locked to the detected region. Enable override to change.',
                            style: TextStyle(
                              color: Colors.white.withAlpha((0.7 * 255).round()),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (detectionMessage != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            detectionMessage!,
                            style: TextStyle(
                              color: messageColor(),
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: detectionInProgress
                      ? null
                      : () async {
                          final trimmedName = nameController.text.trim();
                          final trimmedPhone = phoneController.text.trim();

                          if (trimmedName.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('Name is required'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          final shouldLock = tempLocked && !manualOverride;
                          final latitudeToSave = detectedLatitude ?? _locationLatitude;
                          final longitudeToSave = detectedLongitude ?? _locationLongitude;
                          final accuracyToSave = detectedAccuracy ?? _locationAccuracy;
                          final timestampToSave = detectedTimestamp ?? _locationTimestamp ?? DateTime.now();

                          setState(() {
                            _userName = trimmedName;
                            _phoneNumber = trimmedPhone;
                            _countryOption = tempSelection;
                            _countryLocked = shouldLock;
                            _locationLatitude = latitudeToSave;
                            _locationLongitude = longitudeToSave;
                            _locationAccuracy = accuracyToSave;
                            _locationTimestamp = timestampToSave;
                            _locationConfidenceHigh = shouldLock ? detectionConfidence : false;
                            _locationError = shouldLock ? null : detectionMessage;
                          });

                          await _saveUserName(trimmedName);
                          await _savePhoneNumber(trimmedPhone);
                          await _persistCountrySelection(
                            option: tempSelection,
                            lock: shouldLock,
                            latitude: latitudeToSave,
                            longitude: longitudeToSave,
                            accuracy: accuracyToSave,
                            timestamp: timestampToSave,
                            confidenceHigh: shouldLock ? detectionConfidence : false,
                          );

                          if (!mounted) {
                            return;
                          }

                          if (!dialogContext.mounted) {
                            return;
                          }

                          Navigator.pop(dialogContext);

                          if (!mounted) {
                            return;
                          }

                          final messenger = ScaffoldMessenger.maybeOf(context);
                          messenger?.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Profile updated. Using ${tempSelection.name} (${tempSelection.currencyCode}).',
                              ),
                              backgroundColor: _accentPurple,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: _accentPurple),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _shareReferralCode() {
    // Create share text
    final shareText = '''
Join NGMY Global Income and start earning!

Use my referral code: $_referralCode

Download the app and start earning passive income today!
''';
    
    // Copy to clipboard (simple share implementation)
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Share message copied! Paste it to share with friends.'),
        backgroundColor: _accentPurple,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showRedeemCodeDialog() {
    final codeController = TextEditingController();
    final referralBonusDisplay = _formatLocalWithUsd(5.0, decimals: 2);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _midPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enter Referral Code', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter the referral code from your friend to earn $referralBonusDisplay bonus!',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
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
            style: FilledButton.styleFrom(backgroundColor: _accentPurple),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
  }

  Future<void> _redeemReferralCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = _userName;

  final alreadyRedeemed = prefs.getString(_uKey(savedName, 'referred_by'));
  final hasRedeemed = prefs.getBool(_uKey(savedName, 'has_redeemed_referral')) ?? false;

    if (alreadyRedeemed != null || hasRedeemed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You have already redeemed a referral code'),
          backgroundColor: _accentPurple,
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
      prefs.getString(_uKey(referrer, 'referrals')) ?? '[]',
    );
    if (referrerReferrals
        .any((entry) => entry.username.toLowerCase() == savedName.toLowerCase())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('This referral code was already used for this account'),
          backgroundColor: _accentPurple,
        ),
      );
      return;
    }

  const bonusAmount = 5.0;
  final bonusDisplay = _formatLocalWithUsd(bonusAmount, decimals: 2);

  final currentBalance = prefs.getDouble(_uKey(savedName, 'balance')) ??
    0.0;
    final newBalance = currentBalance + bonusAmount;
  await prefs.setDouble(_uKey(savedName, 'balance'), newBalance);
    await prefs.setBool(_uKey(savedName, 'has_redeemed_referral'), true);
    await prefs.setString(_uKey(savedName, 'redeemed_from_code'), code);
    await prefs.setString(_uKey(savedName, 'referred_by'), referrer);

    final userReferralEarnings =
        prefs.getDouble(_uKey(savedName, 'referral_earnings')) ?? 0.0;
    await prefs.setDouble(_uKey(savedName, 'referral_earnings'), userReferralEarnings + bonusAmount);
    final userLifetime = prefs.getDouble(_uKey(savedName, 'total_earnings')) ?? 0.0;
    await prefs.setDouble(_uKey(savedName, 'total_earnings'), userLifetime + bonusAmount);

    final referrerBalance =
        prefs.getDouble(_uKey(referrer, 'balance')) ?? 0.0;
    await prefs.setDouble(_uKey(referrer, 'balance'), referrerBalance + bonusAmount);

    referrerReferrals.insert(
      0,
      ReferralRecord(
        username: savedName,
        code: code,
        usedAt: DateTime.now(),
      ),
    );
    await prefs.setString(
      _uKey(referrer, 'referrals'),
      ReferralRecord.encodeList(referrerReferrals),
    );
    await prefs.setInt(_uKey(referrer, 'referral_count'), referrerReferrals.length);

    final referrerEarnings =
        prefs.getDouble(_uKey(referrer, 'referral_earnings')) ?? 0.0;
    await prefs.setDouble(_uKey(referrer, 'referral_earnings'), referrerEarnings + bonusAmount);
    final referrerLifetime =
        prefs.getDouble(_uKey(referrer, 'total_earnings')) ?? 0.0;
    await prefs.setDouble(_uKey(referrer, 'total_earnings'), referrerLifetime + bonusAmount);

  final now = DateTime.now();
  final notification = {
    'id': now.millisecondsSinceEpoch.toString(),
    'title': 'New Referral! 🎉',
    'message': '$savedName used your referral code! You earned $bonusDisplay!',
    'type': 'success',
    'timestamp': now.toIso8601String(),
    'read': false,
    'fromSystem': true,
  };

  final referrerNotificationsJson =
    prefs.getString(_uKey(referrer, 'notifications')) ?? '[]';
  final referrerNotifications = (jsonDecode(referrerNotificationsJson) as List);
  referrerNotifications.insert(0, notification);
  await prefs.setString(_uKey(referrer, 'notifications'), jsonEncode(referrerNotifications));

    await _loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 Referral code redeemed! $bonusDisplay added to your balance'),
        backgroundColor: _accentPurple,
        duration: const Duration(seconds: 4),
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
        backgroundColor: _midPurple,
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
        backgroundColor: _midPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('About', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet, size: 64, color: _accentPurple),
            const SizedBox(height: 16),
            const Text(
              'Global Income',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
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
        backgroundColor: _midPurple,
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
                SnackBar(
                  content: const Text('Logged out successfully'),
                  backgroundColor: _accentPurple,
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

