import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../widgets/glass_widgets.dart';
import '../widgets/floating_header.dart';
import '../models/payment_proof.dart';
import 'admin_requests_screen.dart';
import 'admin_user_management_screen.dart';
import '../models/growth_chat_models.dart';
import '../services/growth_messaging_store.dart';
import 'growth/growth_message_center.dart';
import '../services/user_account_service.dart';

class AdminGrowthScreen extends StatefulWidget {
  const AdminGrowthScreen({super.key});

  @override
  State<AdminGrowthScreen> createState() => _AdminGrowthScreenState();
}

class _AdminGrowthScreenState extends State<AdminGrowthScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedWorkingDays = {};
  String _paymentMethod = 'cashapp';
  final TextEditingController _cashAppTagController =
      TextEditingController(text: r'$NGMYPay');
  final TextEditingController _cashAppLinkController = TextEditingController();
  final TextEditingController _cryptoAddressController =
      TextEditingController();
  final GrowthMessagingStore _messagingStore = GrowthMessagingStore.instance;

  String _growthIdKey(String username) => '${username}_growth_user_id';
  String _globalIdKey(String username) => '${username}_global_user_id';

  bool _looksGlobalId(String value) => value.toUpperCase().startsWith('GI-');
  bool _looksGrowthId(String value) => value.toUpperCase().startsWith('GR-');

  String? _readGrowthUserId(String username, SharedPreferences prefs) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final lower = trimmed.toLowerCase();
    final keys = <String>{
      _growthIdKey(trimmed),
      _growthIdKey(lower),
      '${trimmed}_user_id',
      '${lower}_user_id',
    };

    for (final key in keys) {
      final value = prefs.getString(key);
      if (value == null) {
        continue;
      }
      final normalized = value.trim();
      if (normalized.isEmpty || _looksGlobalId(normalized)) {
        continue;
      }
      return normalized;
    }

    return null;
  }

  String? _readGlobalUserId(String username, SharedPreferences prefs) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final lower = trimmed.toLowerCase();
    final candidates = <String?>[
      prefs.getString(_globalIdKey(trimmed)),
      prefs.getString(_globalIdKey(lower)),
      prefs.getString('${trimmed}_global_userId'),
      prefs.getString('${lower}_global_userId'),
      prefs.getString('Global_user_id'),
      prefs.getString('global_user_id'),
      prefs.getString('${trimmed}_user_id'),
      prefs.getString('${lower}_user_id'),
    ];

    String? fallback;
    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      final normalized = candidate.trim();
      if (normalized.isEmpty) {
        continue;
      }
      if (_looksGlobalId(normalized)) {
        return normalized;
      }
      fallback ??= normalized;
    }

    if (fallback != null && !_looksGrowthId(fallback)) {
      return fallback;
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadSelectedWorkingDays();
    _loadPaymentSettings();
  }

  Future<void> _loadSelectedWorkingDays() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDays = prefs.getStringList('admin_working_days') ?? [];
    setState(() {
      _selectedWorkingDays = savedDays.toSet();
    });
  }

  Future<void> _loadPaymentSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final method = prefs.getString('growth_payment_method') ?? 'cashapp';
    final cashAppTag = prefs.getString('growth_payment_cashapp_tag');
    final cashAppLink = prefs.getString('growth_payment_cashapp_link');
    final cryptoAddress = prefs.getString('growth_payment_crypto_address');

    setState(() {
      _paymentMethod = method;
      if (cashAppTag != null) {
        _cashAppTagController.text = cashAppTag;
      }
      if (cashAppLink != null) {
        _cashAppLinkController.text = cashAppLink;
      }
      if (cryptoAddress != null) {
        _cryptoAddressController.text = cryptoAddress;
      }
    });
  }

  Future<void> _savePaymentSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('growth_payment_method', _paymentMethod);
    await prefs.setString(
        'growth_payment_cashapp_tag', _cashAppTagController.text.trim());
    await prefs.setString(
        'growth_payment_cashapp_link', _cashAppLinkController.text.trim());
    await prefs.setString(
        'growth_payment_crypto_address', _cryptoAddressController.text.trim());

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Growth payment instructions saved.'),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cashAppTagController.dispose();
    _cashAppLinkController.dispose();
    _cryptoAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2472),
      appBar: FloatingHeader(
        title: 'Growth Controls',
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
            // User Search Section
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.search, color: Colors.blue),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'User Account Management',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by username, ID, or phone number...',
                      hintStyle: TextStyle(
                          color: Colors.white.withAlpha((0.5 * 255).round())),
                      prefixIcon:
                          const Icon(Icons.person_search, color: Colors.blue),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon:
                                  const Icon(Icons.clear, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.blue.withAlpha((0.5 * 255).round())),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.blue.withAlpha((0.3 * 255).round())),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.blue, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildUserSearchResults(),
                  ] else ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha((0.1 * 255).round()),
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
                              'Search for a user to manage their account',
                              style: TextStyle(
                                color:
                                    Colors.white.withAlpha((0.9 * 255).round()),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildPaymentSettingsSection(),
            const SizedBox(height: 24),
            // Global System Controls
            _buildGlobalControlsSection(),
            const SizedBox(height: 24),
            _buildMessagingStudioCard(),
            const SizedBox(height: 24),
            // Payment Proofs Section
            _buildPaymentProofsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSettingsSection() {
    final isCashApp = _paymentMethod == 'cashapp';

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments, color: Colors.tealAccent),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Payment Instructions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildPaymentMethodChip(
                value: 'cashapp',
                label: 'CashApp Link',
                icon: Icons.account_balance_wallet,
              ),
              _buildPaymentMethodChip(
                value: 'crypto',
                label: 'Crypto Wallet',
                icon: Icons.currency_bitcoin,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (isCashApp) ...[
            _buildPaymentTextField(
              label: 'CashApp Tag',
              controller: _cashAppTagController,
              hint: r'Enter handle like $NGMYPay',
            ),
            const SizedBox(height: 12),
            _buildPaymentTextField(
              label: 'CashApp Link (optional)',
              controller: _cashAppLinkController,
              hint: r'e.g. https://cash.app/$NGMYPay',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withAlpha(70)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Users must tap the payment frame before "I Sent Payment" unlocks. Include a deep link so their tap can open CashApp instantly.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildPaymentTextField(
              label: 'Crypto Wallet Address',
              controller: _cryptoAddressController,
              hint: 'Paste the full wallet address',
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withAlpha(70)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Users can copy the address from the payment frame. Double-check the network and address before saving.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savePaymentSettings,
              icon: const Icon(Icons.save),
              label: const Text('Save Payment Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagingStudioCard() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.notifications_active_outlined,
                  color: Colors.tealAccent),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Messaging Studio & Notification Bells',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Control the Growth and Global notification bells, manage group access, '
            'and open the studio to chat with investors in real time.',
            style: TextStyle(
              color: Colors.white.withAlpha((0.75 * 255).round()),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openMessagingStudio(GrowthChatScope.growth),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.groups),
                label: const Text('Open Growth Studio'),
              ),
              ElevatedButton.icon(
                onPressed: () => _openMessagingStudio(GrowthChatScope.global),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C3FDB),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.public),
                label: const Text('Open Global Studio'),
              ),
              OutlinedButton.icon(
                onPressed: _showMessagingPermissionManager,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.tealAccent,
                  side: BorderSide(
                    color: Colors.tealAccent.withAlpha((0.4 * 255).round()),
                  ),
                ),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Manage group creators'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openMessagingStudio(GrowthChatScope scope) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GrowthMessagingScreen(
          scope: scope,
          adminMode: true,
        ),
      ),
    );
  }

  Future<void> _showMessagingPermissionManager() async {
    await _messagingStore.load();
    await UserAccountService.instance.initialize();
    final users = await UserAccountService.instance.getAllUsers();
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return GrowthMessagingPermissionSheet(
          store: _messagingStore,
          users: users,
        );
      },
    );
  }

  Widget _buildPaymentMethodChip({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _paymentMethod == value;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() => _paymentMethod = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.teal.withAlpha(80)
              : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.tealAccent : Colors.white.withAlpha(40),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : Colors.white70, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withAlpha((0.3 * 255).round()),
              fontSize: 13,
            ),
            filled: true,
            fillColor: Colors.white.withAlpha(20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withAlpha((0.2 * 255).round()),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Colors.tealAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserSearchResults() {
    return FutureBuilder<List<Map<String, String>>>(
      future: _searchUsers(_searchQuery),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final matchedUsers = snapshot.data!;

        if (matchedUsers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.red.withAlpha((0.3 * 255).round())),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_off, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No users found matching "$_searchQuery"',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.9 * 255).round()),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: matchedUsers.map((userData) {
            final username = (userData['username'] ?? '').trim();
            final userID = (userData['id'] ?? '').trim();
            final phone = (userData['phone'] ?? '').trim();
            final displayNameRaw = (userData['displayName'] ?? '').trim();
            final displayName =
                displayNameRaw.isNotEmpty ? displayNameRaw : username;
            final rawKey = (userData['rawKey'] ?? '').trim();
            final profileBase64 = userData['profile'] ?? '';
            final scopeValue = (userData['scope'] ?? 'growth').toLowerCase();
            final isGlobal = scopeValue == 'global';
            final scopeLabel =
                isGlobal ? 'Global Income Program' : 'Growth Program';
            final Color scopeColor =
                isGlobal ? const Color(0xFF6C3FDB) : Colors.tealAccent.shade400;

            Uint8List? profileBytes;
            if (profileBase64.isNotEmpty) {
              try {
                profileBytes = base64Decode(profileBase64);
              } catch (_) {
                profileBytes = null;
              }
            }

            final profileWidget = CircleAvatar(
              radius: 26,
              backgroundColor: Colors.blue.withAlpha((0.25 * 255).round()),
              backgroundImage:
                  profileBytes != null ? MemoryImage(profileBytes) : null,
              child: profileBytes == null
                  ? Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    )
                  : null,
            );

            return Card(
              color: Colors.white.withAlpha((0.05 * 255).round()),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: Colors.blue.withAlpha((0.3 * 255).round())),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminUserManagementScreen(
                        username: displayName,
                        rawAccountKey: rawKey.isNotEmpty ? rawKey : displayName,
                        displayName: displayName,
                        userId: userID.isNotEmpty ? userID : null,
                        profileBase64:
                            profileBase64.isNotEmpty ? profileBase64 : null,
                        accountScope: isGlobal ? 'global' : 'growth',
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      profileWidget,
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: scopeColor
                                      .withAlpha((0.18 * 255).round()),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  scopeLabel,
                                  style: TextStyle(
                                    color: scopeColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            if (userID.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'ID: $userID',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(
                                      (0.65 * 255).round(),
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (phone.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  phone,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(
                                      (0.5 * 255).round(),
                                    ),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.blue, size: 16),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  bool _isGrowthAccount(String username, SharedPreferences prefs) {
    if (username.isEmpty) {
      return false;
    }

    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final lower = trimmed.toLowerCase();

    // Reject Family Tree or other namespaces to keep systems separated
    if (lower == 'family_tree' ||
        lower.startsWith('family_tree') ||
        lower.contains('familytree') ||
        lower.contains('family tree')) {
      return false;
    }

    // Ignore placeholder/default usernames
    if (lower == 'ngmy user' || lower == 'ngmyuser') {
      return false;
    }

    final growthKeyVariants = <String>{
      '${trimmed}_balance',
      '${lower}_balance',
      '${trimmed}_active_days',
      '${lower}_active_days',
      '${trimmed}_referral_code',
      '${lower}_referral_code',
      '${trimmed}_referral_count',
      '${lower}_referral_count',
      '${trimmed}_total_earnings',
      '${lower}_total_earnings',
      '${trimmed}_growth_notifications',
      '${lower}_growth_notifications',
      '${trimmed}_clock_in_start_time',
      '${lower}_clock_in_start_time',
      '${trimmed}_last_clock_in',
      '${lower}_last_clock_in',
      '${trimmed}_verified',
      '${lower}_verified',
      '${trimmed}_profile_picture',
      '${lower}_profile_picture',
    };

    final hasGrowthMetadata =
        growthKeyVariants.any((key) => prefs.containsKey(key));

    final hasGrowthId = _readGrowthUserId(trimmed, prefs) != null;

    if (!hasGrowthId && !hasGrowthMetadata) {
      return false;
    }

    if (hasGrowthId) {
      return true;
    }

    if (hasGrowthMetadata) {
      final currentGrowthUser =
          prefs.getString('growth_user_name')?.trim().toLowerCase();
      return currentGrowthUser == lower;
    }

    return false;
  }

  bool _recordRepresentsGrowth(
    Map<String, String> user,
    SharedPreferences prefs,
  ) {
    final username = user['username']?.trim();
    final userId = user['id']?.trim();
    if (username == null ||
        username.isEmpty ||
        userId == null ||
        userId.isEmpty) {
      return false;
    }

    if (!_isGrowthAccount(username, prefs)) {
      return false;
    }

    final lower = username.toLowerCase();
    final storedId = _readGrowthUserId(username, prefs);

    if (storedId != null && storedId.isNotEmpty) {
      return storedId.trim().toLowerCase() == userId.toLowerCase();
    }

    final currentGrowthUser =
        prefs.getString('growth_user_name')?.trim().toLowerCase();
    final currentGrowthId = prefs.getString('growth_user_id')?.trim();

    if (currentGrowthUser != null &&
        currentGrowthId != null &&
        currentGrowthUser == lower) {
      return currentGrowthId.toLowerCase() == userId.toLowerCase();
    }

    return false;
  }

  String _deriveDisplayName(String rawUsername, SharedPreferences prefs) {
    final trimmed = rawUsername.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final lower = trimmed.toLowerCase();
    if (lower == 'global') {
      final stored = prefs.getString('global_user_name') ??
          prefs.getString('Global_user_name');
      if (stored != null && stored.trim().isNotEmpty) {
        return stored.trim();
      }
    }

    if (lower.endsWith('_global')) {
      final base =
          trimmed.substring(0, trimmed.length - '_global'.length).trim();
      if (base.isNotEmpty) {
        return base;
      }
    }

    final candidates = <String?>[
      prefs.getString('${trimmed}_global_display_name'),
      prefs.getString('${trimmed}_display_name'),
      prefs.getString('${trimmed}_global_name'),
      prefs.getString('${trimmed}_name'),
      prefs.getString('${trimmed}_profile_name'),
      prefs.getString('${trimmed}_full_name'),
    ];

    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }

    return trimmed;
  }

  String? _resolveProfilePictureBase64(
    String username,
    SharedPreferences prefs,
  ) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final candidates = <String?>[
      prefs.getString('${trimmed}_global_profile_picture'),
      prefs.getString('${trimmed}_profile_picture'),
    ];

    for (final candidate in candidates) {
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }

    return null;
  }

  void _mergeGrowthUser(
    Map<String, Map<String, String>> store,
    String canonicalKey,
    Map<String, String> incoming,
  ) {
    final key = canonicalKey.trim();
    if (key.isEmpty) {
      return;
    }

    final existing = store[key];
    if (existing == null) {
      store[key] = {
        'username': (incoming['username'] ?? '').trim(),
        'rawKey': (incoming['rawKey'] ?? '').trim(),
        'id': (incoming['id'] ?? '').trim(),
        'phone': (incoming['phone'] ?? '').trim(),
        'displayName': (incoming['displayName'] ?? '').trim(),
        'profile': incoming['profile'] ?? '',
        'scope': (incoming['scope'] ?? '').trim(),
      };
      return;
    }

    final merged = Map<String, String>.from(existing);
    merged['username'] = (merged['username'] ?? '').trim();
    merged['rawKey'] = (merged['rawKey'] ?? '').trim();
    merged['id'] = (merged['id'] ?? '').trim();
    merged['phone'] = (merged['phone'] ?? '').trim();
    merged['displayName'] = (merged['displayName'] ?? '').trim();
    merged['profile'] = merged['profile'] ?? '';
    merged['scope'] = (merged['scope'] ?? '').trim();

    String resolveValue(String current, String next) {
      if (current.trim().isEmpty && next.trim().isNotEmpty) {
        return next;
      }
      return current;
    }

    merged['username'] =
        resolveValue(merged['username']!, (incoming['username'] ?? '').trim());
    merged['rawKey'] =
        resolveValue(merged['rawKey']!, (incoming['rawKey'] ?? '').trim());
    merged['id'] = resolveValue(merged['id']!, (incoming['id'] ?? '').trim());
    merged['phone'] =
        resolveValue(merged['phone']!, (incoming['phone'] ?? '').trim());
    merged['displayName'] = resolveValue(
      merged['displayName']!,
      (incoming['displayName'] ?? '').trim(),
    );
    merged['scope'] = resolveValue(
      merged['scope']!,
      (incoming['scope'] ?? '').trim(),
    );

    final incomingProfile = incoming['profile'] ?? '';
    if ((merged['profile'] ?? '').isEmpty && incomingProfile.isNotEmpty) {
      merged['profile'] = incomingProfile;
    }

    store[key] = merged;
  }

  Future<List<Map<String, String>>> _searchUsers(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final growthUsers = <String, Map<String, String>>{};

    // Find all users who have Growth menu IDs (stored as {username}_growth_user_id)
    // This ensures we only get users who joined the Growth menu
    for (final key in allKeys) {
      if (key.endsWith('_growth_user_id')) {
        final rawUsername =
            key.substring(0, key.length - '_growth_user_id'.length);
        final username = rawUsername.trim();
        if (username.isEmpty) {
          continue;
        }
        if (_isGrowthAccount(username, prefs)) {
          final userID = _readGrowthUserId(username, prefs) ?? '';
          if (userID.isEmpty) {
            continue;
          }
          final phone = prefs.getString('${username}_phone') ??
              prefs.getString('${username.toLowerCase()}_phone') ??
              '';
          final displayName = _deriveDisplayName(username, prefs);
          final profile = _resolveProfilePictureBase64(username, prefs) ?? '';

          final canonical = (displayName.isNotEmpty
                  ? displayName.toLowerCase()
                  : username.toLowerCase())
              .trim();
          _mergeGrowthUser(growthUsers, canonical, {
            'username': displayName.isNotEmpty ? displayName : username,
            'rawKey': username,
            'id': userID,
            'phone': phone,
            'displayName': displayName,
            'profile': profile,
            'scope': 'growth',
          });
        }
        continue;
      }

      if (key.endsWith('_user_id') &&
          !key.startsWith('growth_') &&
          key.toLowerCase() != 'global_user_id' &&
          key.toLowerCase() != 'family_tree_user_id' &&
          !key.contains('family_tree')) {
        final rawUsername = key.substring(0, key.length - '_user_id'.length);
        final username = rawUsername.trim();
        if (_isGrowthAccount(username, prefs)) {
          final userID = _readGrowthUserId(username, prefs) ?? '';
          final phone = prefs.getString('${username}_phone') ?? '';
          final displayName = _deriveDisplayName(username, prefs);
          final profile = _resolveProfilePictureBase64(username, prefs) ?? '';

          // Only add if user has a valid ID (meaning they're registered in Growth menu)
          if (userID.isNotEmpty && !_looksGlobalId(userID)) {
            final canonical = (displayName.isNotEmpty
                    ? displayName.toLowerCase()
                    : username.toLowerCase())
                .trim();
            _mergeGrowthUser(growthUsers, canonical, {
              'username': displayName.isNotEmpty ? displayName : username,
              'rawKey': username,
              'id': userID,
              'phone': phone,
              'displayName': displayName,
              'profile': profile,
              'scope': 'growth',
            });
          }
        }
      }
    }

    // Also check for current Growth user (growth_user_name with growth_user_id)
    final currentUserName = prefs.getString('growth_user_name');
    final currentUserID = prefs.getString('growth_user_id');
    if (currentUserName != null &&
        currentUserName != 'NGMY User' &&
        currentUserID != null &&
        currentUserID.isNotEmpty) {
      final trimmedCurrent = currentUserName.trim();
      if (_isGrowthAccount(trimmedCurrent, prefs)) {
        final currentPhone = prefs.getString('growth_user_phone') ?? '';
        final displayName = _deriveDisplayName(trimmedCurrent, prefs);
        final profile =
            _resolveProfilePictureBase64(trimmedCurrent, prefs) ?? '';
        final canonical = (displayName.isNotEmpty
                ? displayName.toLowerCase()
                : trimmedCurrent.toLowerCase())
            .trim();
        _mergeGrowthUser(growthUsers, canonical, {
          'username': displayName.isNotEmpty ? displayName : trimmedCurrent,
          'rawKey': trimmedCurrent,
          'id': currentUserID,
          'phone': currentPhone,
          'displayName': displayName,
          'profile': profile,
          'scope': 'growth',
        });
      }
    }

    final globalUsers = <String, Map<String, String>>{};
    final globalNameCandidates = <String>{};

    for (final key in allKeys) {
      if (key.endsWith('_global_user_id')) {
        final raw = key.substring(0, key.length - '_global_user_id'.length);
        final trimmed = raw.trim();
        if (trimmed.isNotEmpty) {
          globalNameCandidates.add(trimmed);
        }
      }
    }

    final storedGlobalName = prefs.getString('global_user_name') ??
        prefs.getString('Global_user_name');
    if (storedGlobalName != null) {
      final trimmed = storedGlobalName.trim();
      if (trimmed.isNotEmpty) {
        globalNameCandidates.add(trimmed);
      }
    }

    for (final candidate in globalNameCandidates) {
      final displayName = _deriveDisplayName(candidate, prefs);
      final userId = _readGlobalUserId(candidate, prefs) ?? '';
      if (userId.isEmpty) {
        continue;
      }

      final lower = candidate.toLowerCase();
      final phone = prefs.getString('${candidate}_global_phone') ??
          prefs.getString('${candidate}_phone') ??
          prefs.getString('${lower}_global_phone') ??
          prefs.getString('${lower}_phone') ??
          '';
      final profile = _resolveProfilePictureBase64(candidate, prefs) ?? '';

      final canonicalBase = (displayName.isNotEmpty
              ? displayName.toLowerCase()
              : candidate.toLowerCase())
          .trim();
      final canonicalKey = 'global:$canonicalBase';

      _mergeGrowthUser(globalUsers, canonicalKey, {
        'username': displayName.isNotEmpty ? displayName : candidate,
        'rawKey': '${candidate}_global',
        'id': userId,
        'phone': phone,
        'displayName': displayName,
        'profile': profile,
        'scope': 'global',
      });
    }

    // Search by username, ID, or phone
    final matchedUsers = <Map<String, String>>[];
    final lowerQuery = query.toLowerCase();

    Iterable<Map<String, String>> userSources() sync* {
      yield* growthUsers.values;
      yield* globalUsers.values;
    }

    for (final userData in userSources()) {
      final username = (userData['username'] ?? '').trim();
      if (username.isEmpty) {
        continue;
      }

      final userID = (userData['id'] ?? '').trim();
      if (userID.isEmpty) {
        continue;
      }

      final phone = (userData['phone'] ?? '').trim();

      final matchesUsername = username.toLowerCase().contains(lowerQuery);
      final matchesID = userID.toLowerCase().contains(lowerQuery);
      final matchesPhone = phone.toLowerCase().contains(lowerQuery);

      if (matchesUsername || matchesID || matchesPhone) {
        final displayName = (userData['displayName'] ?? username).trim();
        final rawKey = (userData['rawKey'] ?? '').trim();
        final profile = userData['profile'] ?? '';
        final scope = (userData['scope'] ?? '').trim();

        matchedUsers.add({
          'username': username,
          'id': userID,
          'phone': phone,
          'rawKey': rawKey,
          'displayName': displayName,
          'profile': profile,
          'scope': scope.isNotEmpty ? scope : 'growth',
        });
      }
    }

    matchedUsers.sort((a, b) {
      final aName = (a['displayName'] ?? a['username'] ?? '').toLowerCase();
      final bName = (b['displayName'] ?? b['username'] ?? '').toLowerCase();
      return aName.compareTo(bName);
    });

    final uniqueUsers = <Map<String, String>>[];
    final seen = <String>{};
    for (final userData in matchedUsers) {
      final idKey = (userData['id'] ?? '').trim().toLowerCase();
      final nameKey = (userData['username'] ?? '').trim().toLowerCase();
      final scope = (userData['scope'] ?? 'growth').toLowerCase();
      final dedupeKey = '$scope:${idKey.isNotEmpty ? idKey : nameKey}';
      if (!seen.add(dedupeKey)) {
        continue;
      }

      if (scope == 'global') {
        uniqueUsers.add(userData);
        continue;
      }

      if (_recordRepresentsGrowth(userData, prefs)) {
        uniqueUsers.add(userData);
      }
    }

    return uniqueUsers;
  }

  Future<void> _setWorkingDaysLimit() async {
    if (_selectedWorkingDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one working day')),
      );
      return;
    }

    final daysList = _selectedWorkingDays.toList()
      ..sort((a, b) {
        final order = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        return order.indexOf(a).compareTo(order.indexOf(b));
      });

    final daysText = daysList.join(', ');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A2472),
        title: const Text('Set Working Days',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Set working days to:\n\n$daysText\n\nUsers will only be able to clock in on these days.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (!mounted) {
      return;
    }

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('admin_working_days', daysList);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Working days set to: $daysText')),
        );
      }
    }
  }

  Future<void> _restartClockInSystem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A2472),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Restart Clock-In System',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'This will clear all clock-in sessions for ALL users.\n\n'
          'This will NOT affect:\n'
          '• User balances\n'
          '• Active days count\n'
          '• Investment plans\n'
          '• 24-hour cycle settings\n\n'
          'Are you sure you want to restart the clock-in system?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restart System'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      // Clear clock-in related keys for all users
      final keysToRemove = <String>[];
      for (final key in allKeys) {
        if (key.contains('family_tree')) {
          continue;
        }

        if (key.contains('_last_clock_in') ||
            key.contains('_clock_in_start_time') ||
            key == 'last_clock_in_date' ||
            key == 'clock_in_start') {
          keysToRemove.add(key);
        }
      }

      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Clock-in system restarted! Cleared ${keysToRemove.length} sessions.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _resetAllInvestments() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A2472),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('DANGER ZONE', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Text(
          '⚠️ THIS ACTION CANNOT BE UNDONE ⚠️\n\n'
          'This will permanently delete ALL investment plans for ALL users.\n\n'
          'This will clear:\n'
          '• Approved investments\n'
          '• Pending investments\n'
          '• Payment upload data\n'
          '• All payment proofs\n\n'
          'User balances and clock-in data will NOT be affected.\n\n'
          'Are you absolutely sure?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE ALL INVESTMENTS'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;

      // Double confirmation for this dangerous action
      final doubleConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0A2472),
          title: const Text('Final Confirmation',
              style: TextStyle(color: Colors.red)),
          content: const Text(
            'This is your last chance to cancel.\n\n'
            'Type "DELETE" to confirm you want to reset all investments.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Confirm Delete'),
            ),
          ],
        ),
      );

      if (doubleConfirmed == true) {
        final prefs = await SharedPreferences.getInstance();
        final allKeys = prefs.getKeys();

        bool isGrowthInvestmentKey(String key) {
          if (key.contains('family_tree')) {
            return false;
          }

          if (key == 'approved_investment' ||
              key == 'current_investment' ||
              key == 'pending_investment_amount' ||
              key == 'payment_proofs' ||
              key == 'growth_pending_upload_amount' ||
              key == 'growth_pending_upload_timestamp') {
            return true;
          }

          return key.endsWith('_approved_investment') ||
              key.endsWith('_pending_investment') ||
              key.endsWith('_pending_investment_amount') ||
              key.endsWith('_pending_upload') ||
              key.endsWith('_pending_upload_amount') ||
              key.endsWith('_pending_upload_timestamp');
        }

        // Clear growth investment-related keys for all users
        final keysToRemove = <String>[];
        for (final key in allKeys) {
          if (isGrowthInvestmentKey(key)) {
            keysToRemove.add(key);
          }
        }

        for (final key in keysToRemove) {
          await prefs.remove(key);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'All investments reset! Cleared ${keysToRemove.length} records.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          setState(() {}); // Refresh the UI
        }
      }
    }
  }

  Widget _buildGlobalControlsSection() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings, color: Colors.purple),
              const SizedBox(width: 12),
              const Text(
                'Global System Controls',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Working Days Limit Control
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withAlpha(25),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Working Days',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choose which days users can clock in',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                // Day Selection Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDayButton('Monday'),
                    _buildDayButton('Tuesday'),
                    _buildDayButton('Wednesday'),
                    _buildDayButton('Thursday'),
                    _buildDayButton('Friday'),
                    _buildDayButton('Saturday'),
                    _buildDayButton('Sunday'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _setWorkingDaysLimit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    child: Text(
                      _selectedWorkingDays.isEmpty
                          ? 'Select Days to Continue'
                          : 'Save Working Days (${_selectedWorkingDays.length} selected)',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Restart Clock-In System
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withAlpha(25),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restart_alt,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Restart Clock-In System',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Clear all clock-in sessions (keeps 24hr cycle, balances, and days count)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _restartClockInSystem,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Restart Clock-In System'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Reset All Investments
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.redAccent.withAlpha(76),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Reset All Investments',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '⚠️ DANGER: This will clear all investment plans for ALL users',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _resetAllInvestments,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Reset All Investments'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayButton(String day) {
    final isSelected = _selectedWorkingDays.contains(day);
    final dayShort = day.substring(0, 3); // Mon, Tue, Wed, etc.

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedWorkingDays.remove(day);
          } else {
            _selectedWorkingDays.add(day);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withAlpha((0.6 * 255).round())
              : Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.white.withAlpha(51),
            width: 2,
          ),
        ),
        child: Text(
          dayShort,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentProofsSection() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.orange),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Payment Approvals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Pending withdrawals',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<_WithdrawalRequest>>(
            future: _loadWithdrawalRequests(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) {
                return _buildEmptyStateMessage(
                    'Unable to load withdrawal queue');
              }

              final pendingRequests = snapshot.data!
                  .where((request) => request.status == 'pending')
                  .toList()
                ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

              if (pendingRequests.isEmpty) {
                return _buildEmptyStateMessage('No pending withdrawals');
              }

              return Column(
                children: pendingRequests
                    .map((request) => _buildWithdrawalCard(request))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.08 * 255).round()),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Pending payment proofs',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<PaymentProof>>(
            future: _loadPaymentProofs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) {
                return _buildEmptyStateMessage('Unable to load payment proofs');
              }

              final proofs = snapshot.data!;
              final pendingProofs =
                  proofs.where((p) => p.status == 'pending').toList();

              if (pendingProofs.isEmpty) {
                return _buildEmptyStateMessage('No pending payment proofs');
              }

              return Column(
                children: pendingProofs
                    .map((proof) => _buildPaymentProofCard(proof))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminRequestsScreen(
                      system: AdminRequestSystem.growth,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new,
                  color: Colors.orangeAccent, size: 18),
              label: const Text(
                'View full request center',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentProofCard(PaymentProof proof) {
    final programLabel = proof.scope == 'global'
        ? 'Global Income'
        : 'Growth Program';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withAlpha((0.3 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildUserBadge(proof.username),
              const SizedBox(width: 8),
              _buildScopeChip(proof.scope),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            programLabel,
            style: TextStyle(
              color: proof.scope == 'global'
                  ? Colors.purpleAccent
                  : Colors.tealAccent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Investment Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(
                    '\$${proof.investmentAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Paid Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(
                    '\$${proof.paidAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Submitted: ${_formatDate(proof.submittedAt)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _viewPaymentProof(proof),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
              minimumSize: const Size(double.infinity, 40),
            ),
            icon: const Icon(Icons.visibility, size: 18),
            label: const Text('View Details'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showRejectDialog(proof),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approvePayment(proof),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<List<_WithdrawalRequest>> _loadWithdrawalRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final rawRequests = prefs.getStringList('withdrawal_requests') ?? [];
    final requests = <_WithdrawalRequest>[];

    for (var i = 0; i < rawRequests.length; i++) {
      final raw = rawRequests[i];
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final submittedAtString = decoded['submittedAt'] as String?;
        final submittedAt = submittedAtString != null
            ? DateTime.tryParse(submittedAtString) ??
                DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.fromMillisecondsSinceEpoch(0);

        final scopeRaw = (decoded['scope'] as String?)?.toLowerCase();
        final scope = scopeRaw == 'global' ? 'global' : 'growth';

        requests.add(
          _WithdrawalRequest(
            storageIndex: i,
            id: decoded['id'] as String? ?? '${i + 1}',
            username: decoded['username'] as String? ?? 'Unknown user',
            userId: decoded['userID'] as String? ?? '',
            amount: (decoded['amount'] as num?)?.toDouble() ?? 0.0,
            cashTag: decoded['cashTag'] as String? ?? '',
            status: decoded['status'] as String? ?? 'pending',
            submittedAt: submittedAt,
            scope: scope,
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('Failed to parse withdrawal request: $error');
        debugPrint('$stackTrace');
      }
    }

    requests.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return requests;
  }

  Widget _buildUserBadge(String username) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha((0.2 * 255).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person, color: Colors.blue, size: 14),
          const SizedBox(width: 4),
          Text(
            username,
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeChip(String scope) {
    final lowerScope = scope.toLowerCase();
    final isGlobal = lowerScope == 'global';
    final label = isGlobal ? 'Global Income' : 'Growth Program';
    final accent = isGlobal ? Colors.purpleAccent : Colors.tealAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withAlpha((0.18 * 255).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withAlpha((0.5 * 255).round())),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildWithdrawalCard(_WithdrawalRequest request) {
    final isGlobal = request.scope == 'global';
    final programLabel = isGlobal ? 'Global Income' : 'Growth Program';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha((0.35 * 255).round())),
      ),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildUserBadge(request.username),
                        const SizedBox(width: 8),
                        _buildScopeChip(request.scope),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      programLabel,
                      style: TextStyle(
                        color: isGlobal
                            ? Colors.purpleAccent
                            : Colors.tealAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (request.userId.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'ID: ${request.userId}',
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '₦₲${request.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Cash Tag: ${request.cashTag}',
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            'Submitted: ${_formatDate(request.submittedAt)}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmRejectWithdrawal(request),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmApproveWithdrawal(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmApproveWithdrawal(_WithdrawalRequest request) async {
    final programLabel = request.scope == 'global'
        ? 'Global Income Program'
        : 'Growth Program';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Withdrawal'),
        content: Text(
          'Approve ₦₲${request.amount.toStringAsFixed(2)} to ${request.cashTag}?\nProgram: $programLabel\nUser: ${request.username}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _approveWithdrawalRequest(request);
    }
  }

  Future<void> _confirmRejectWithdrawal(_WithdrawalRequest request) async {
    final programLabel = request.scope == 'global'
        ? 'Global Income Program'
        : 'Growth Program';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Withdrawal'),
        content: Text(
          'Reject ₦₲${request.amount.toStringAsFixed(2)} requested by ${request.username}?\nProgram: $programLabel',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _rejectWithdrawalRequest(request);
    }
  }

  Future<void> _approveWithdrawalRequest(_WithdrawalRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    final rawRequests = prefs.getStringList('withdrawal_requests') ?? [];

    if (request.storageIndex < 0 ||
        request.storageIndex >= rawRequests.length) {
      _showSnack('Unable to locate withdrawal request.', color: Colors.red);
      return;
    }

    final decoded =
        jsonDecode(rawRequests[request.storageIndex]) as Map<String, dynamic>;
    if (decoded['status'] == 'approved') {
      _showSnack('Withdrawal already approved.', color: Colors.orange);
      return;
    }

  decoded['status'] = 'approved';
  decoded['reviewedAt'] = DateTime.now().toIso8601String();
  final scopeRaw = (decoded['scope'] as String?)?.toLowerCase();
  final scope = scopeRaw == 'global' ? 'global' : 'growth';
  decoded['scope'] = scope;

    final username = decoded['username'] as String? ?? request.username;
    final amount = (decoded['amount'] as num?)?.toDouble() ?? request.amount;
    final safeAmount = amount.isFinite ? amount : 0.0;

    if (scope == 'global') {
      final primaryKey = '${username}_global_balance';
      final variantKeys = <String>[
        primaryKey,
        '${username}_Global_balance',
        '${username}_GLOBAL_balance',
      ];

      double currentBalance = 0.0;
      bool balanceFound = false;
      for (final key in variantKeys) {
        final stored = prefs.getDouble(key);
        if (stored != null) {
          currentBalance = stored;
          balanceFound = true;
          break;
        }
      }
      if (!balanceFound) {
        currentBalance = prefs.getDouble(primaryKey) ?? 0.0;
      }

      final updatedBalance = currentBalance - safeAmount;
      final safeBalance = updatedBalance < 0 ? 0.0 : updatedBalance;

      await prefs.setDouble(primaryKey, safeBalance);
      for (final key in variantKeys.skip(1)) {
        if (prefs.containsKey(key)) {
          await prefs.setDouble(key, safeBalance);
        }
      }

      final activeGlobalUser = prefs.getString('global_user_name') ??
          prefs.getString('Global_user_name');
      if (activeGlobalUser != null &&
          activeGlobalUser.trim().toLowerCase() ==
              username.trim().toLowerCase()) {
        await prefs.setDouble('global_total_balance', safeBalance);
        for (final variant in ['Global_total_balance', 'GLOBAL_total_balance']) {
          if (prefs.containsKey(variant)) {
            await prefs.setDouble(variant, safeBalance);
          }
        }
      }
    } else {
      final balanceKey = '${username}_balance';
      final currentBalance = prefs.getDouble(balanceKey) ?? 0.0;
      final updatedBalance = currentBalance - safeAmount;
      final safeBalance = updatedBalance < 0 ? 0.0 : updatedBalance;
      await prefs.setDouble(balanceKey, safeBalance);

      final activeUser = prefs.getString('growth_user_name');
      if (activeUser == username) {
        await prefs.setDouble('total_balance', safeBalance);
      }
    }

    decoded['netAmount'] = safeAmount;
    rawRequests[request.storageIndex] = jsonEncode(decoded);
    await prefs.setStringList('withdrawal_requests', rawRequests);

    if (!mounted) {
      return;
    }

    final programLabel = scope == 'global' ? 'Global Income Program' : 'Growth Program';
    _showSnack('Withdrawal approved for $username ($programLabel).',
        color: Colors.green);
    setState(() {});
  }

  Future<void> _rejectWithdrawalRequest(_WithdrawalRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    final rawRequests = prefs.getStringList('withdrawal_requests') ?? [];

    if (request.storageIndex < 0 ||
        request.storageIndex >= rawRequests.length) {
      _showSnack('Unable to locate withdrawal request.', color: Colors.red);
      return;
    }

    final decoded =
        jsonDecode(rawRequests[request.storageIndex]) as Map<String, dynamic>;
    if (decoded['status'] == 'rejected') {
      _showSnack('Withdrawal already rejected.', color: Colors.orange);
      return;
    }

    decoded['status'] = 'rejected';
    decoded['reviewedAt'] = DateTime.now().toIso8601String();
    rawRequests[request.storageIndex] = jsonEncode(decoded);
    await prefs.setStringList('withdrawal_requests', rawRequests);

    if (!mounted) {
      return;
    }

    final username = decoded['username'] as String? ?? request.username;
    final scopeRaw = (decoded['scope'] as String?)?.toLowerCase();
    final scope = scopeRaw == 'global' ? 'global' : 'growth';
    final programLabel = scope == 'global' ? 'Global Income Program' : 'Growth Program';
    _showSnack('Withdrawal rejected for $username ($programLabel).',
        color: Colors.red);
    setState(() {});
  }

  Future<List<PaymentProof>> _loadPaymentProofs() async {
    final prefs = await SharedPreferences.getInstance();
    final proofs = <PaymentProof>[];

  Future<void> ensureScope(
        List<String>? source, String scope, String storageKey) async {
      if (source == null) {
        return;
      }
      final updated = <String>[];
      var mutated = false;
      for (final entry in source) {
        try {
          final data = jsonDecode(entry) as Map<String, dynamic>;
          final existingScope = (data['scope'] as String?)?.toLowerCase();
          if (existingScope != scope) {
            data['scope'] = scope;
            mutated = true;
          }
          proofs.add(PaymentProof.fromJson(data));
          updated.add(jsonEncode(data));
        } catch (error, stackTrace) {
          debugPrint('Failed to parse $scope payment proof: $error');
          debugPrint('$stackTrace');
        }
      }
      if (mutated) {
        await prefs.setStringList(storageKey, updated);
      }
    }

    await ensureScope(
      prefs.getStringList('payment_proofs'),
      'growth',
      'payment_proofs',
    );
    await ensureScope(
      prefs.getStringList('global_payment_proofs'),
      'global',
      'global_payment_proofs',
    );

    proofs.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return proofs;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _viewPaymentProof(PaymentProof proof) async {
    final messageController =
        TextEditingController(text: proof.adminMessage ?? '');
    final File? resolvedScreenshot =
        _resolveScreenshotFile(proof.screenshotPath);

    if (!mounted) {
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Payment Proof Details',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProofDetail('Investment',
                  '\$${proof.investmentAmount.toStringAsFixed(0)}'),
              _buildProofDetail(
                  'Paid', '\$${proof.paidAmount.toStringAsFixed(2)}'),
              _buildProofDetail('Submitted', _formatDate(proof.submittedAt)),
              const SizedBox(height: 16),
              const Text('Screenshot:',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              if (proof.screenshotPath.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.06 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'No screenshot was attached to this proof.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
              ] else if (resolvedScreenshot != null) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showFullScreenImage(resolvedScreenshot.path),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: InteractiveViewer(
                        minScale: 0.9,
                        maxScale: 4.0,
                        child: Image.file(
                          resolvedScreenshot,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.withAlpha((0.2 * 255).round()),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.white54,
                                size: 48,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        _showFullScreenImage(resolvedScreenshot.path),
                    icon: const Icon(Icons.open_in_full, color: Colors.white70),
                    label: const Text(
                      'Open Fullscreen',
                      style: TextStyle(color: Colors.white70),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha((0.12 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withAlpha((0.35 * 255).round()),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Screenshot file is missing or inaccessible.',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        proof.screenshotPath,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ask the user to resubmit their proof if this keeps happening.',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Admin Message (optional)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'Add a message or request changes...',
                  hintStyle: TextStyle(
                      color: Colors.white.withAlpha((0.3 * 255).round())),
                  filled: true,
                  fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (proof.userReply != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha((0.15 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('User Reply:',
                          style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(proof.userReply!,
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
          if (messageController.text.isNotEmpty)
            FilledButton(
              onPressed: () async {
                await _sendMessageToUser(proof, messageController.text);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Send Message'),
            ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _approvePayment(proof);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectPayment(proof, messageController.text);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildProofDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(color: Colors.white70)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _sendMessageToUser(PaymentProof proof, String message) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey =
        proof.scope == 'global' ? 'global_payment_proofs' : 'payment_proofs';
    final proofsJson = prefs.getStringList(storageKey) ?? [];

    // Update proof with admin message
    final updatedProofs = proofsJson.map((json) {
      final proofData = jsonDecode(json) as Map<String, dynamic>;
      if (proofData['id'] == proof.id) {
        proofData['adminMessage'] = message;
        proofData['respondedAt'] = DateTime.now().toIso8601String();
        proofData['scope'] = proof.scope;
      }
      return jsonEncode(proofData);
    }).toList();

    await prefs.setStringList(storageKey, updatedProofs);

    if (!mounted) return;
    _showSnack('Message sent to user', color: Colors.blue);
    setState(() {});
  }

  Future<void> _approvePayment(PaymentProof proof) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Payment?'),
        content: Text(
            'Approve \$${proof.investmentAmount.toStringAsFixed(0)} investment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final isGlobal = proof.scope == 'global';
      final storageKey = isGlobal ? 'global_payment_proofs' : 'payment_proofs';
      final proofsJson = prefs.getStringList(storageKey) ?? [];

      // Update proof status
      final updatedProofs = proofsJson.map((json) {
        final proofData = jsonDecode(json) as Map<String, dynamic>;
        if (proofData['id'] == proof.id) {
          proofData['status'] = 'approved';
          proofData['respondedAt'] = DateTime.now().toIso8601String();
          proofData['scope'] = proof.scope;
        }
        return jsonEncode(proofData);
      }).toList();

      await prefs.setStringList(storageKey, updatedProofs);

      // Activate the investment for THIS SPECIFIC USER
      final username = proof.username;

      if (isGlobal) {
        await prefs.setDouble(
          '${username}_global_approved_investment',
          proof.investmentAmount,
        );
        await prefs.remove('${username}_global_pending_investment_amount');
        await prefs.remove('global_pending_investment_amount');
        await prefs.remove('global_pending_upload_amount');
        await prefs.remove('global_pending_upload_timestamp');

        final activeGlobalUser = prefs.getString('global_user_name') ??
            prefs.getString('Global_user_name');
        if (activeGlobalUser != null &&
            activeGlobalUser.trim().toLowerCase() ==
                username.trim().toLowerCase()) {
          await prefs.setDouble(
              'global_approved_investment', proof.investmentAmount);
        }
      } else {
        // Save to user-specific keys (permanent)
        await prefs.setDouble(
            '${username}_approved_investment', proof.investmentAmount);
        await prefs.remove('${username}_pending_investment_amount');

        // If this is the current logged-in user, also update global keys
        final currentUser = prefs.getString('growth_user_name');
        if (currentUser == username) {
          await prefs.setDouble('approved_investment', proof.investmentAmount);
          await prefs.setDouble('current_investment', proof.investmentAmount);
          await prefs.remove('pending_investment_amount');
        }
      }

      if (!mounted) return;
      _showSnack('✅ Payment approved for $username! Investment activated.',
          color: Colors.green);
      setState(() {});
    }
  }

  File? _resolveScreenshotFile(String rawPath) {
    if (rawPath.isEmpty) {
      return null;
    }
    try {
      String candidate = rawPath;
      if (candidate.startsWith('file://')) {
        candidate = Uri.parse(candidate).toFilePath();
      }

      File file = File(candidate);
      if (file.existsSync()) {
        return file;
      }

      final decoded = Uri.decodeFull(candidate);
      if (decoded != candidate) {
        file = File(decoded);
        if (file.existsSync()) {
          return file;
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to resolve screenshot file: $error');
      debugPrint('$stackTrace');
    }
    return null;
  }

  Future<void> _showFullScreenImage(String imagePath) async {
    final file = _resolveScreenshotFile(imagePath);
    if (file == null || !await file.exists()) {
      if (!mounted) return;
      _showSnack(
        'Screenshot file not found. Ask the user to resubmit their proof.',
        color: Colors.red,
      );
      return;
    }

    if (!mounted) {
      return;
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 300,
                        height: 300,
                        color: Colors.grey.withAlpha((0.2 * 255).round()),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image,
                                color: Colors.white54, size: 64),
                            const SizedBox(height: 16),
                            const Text('Unable to load image',
                                style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(
                              file.path,
                              style: TextStyle(
                                  color: Colors.white
                                      .withAlpha((0.5 * 255).round()),
                                  fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRejectDialog(PaymentProof proof) async {
    final reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            const Text('Reject Payment', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rejecting payment for ${proof.username}',
                style: TextStyle(
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                    fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Amount: \$${proof.investmentAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter rejection reason (optional)',
                  hintStyle: TextStyle(
                      color: Colors.white.withAlpha((0.5 * 255).round())),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _rejectPayment(proof, reasonController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.cancel, size: 18),
            label: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectPayment(PaymentProof proof, String reason) async {
    final prefs = await SharedPreferences.getInstance();
    final isGlobal = proof.scope == 'global';
    final storageKey = isGlobal ? 'global_payment_proofs' : 'payment_proofs';
    final proofsJson = prefs.getStringList(storageKey) ?? [];

    // Update proof status
    final updatedProofs = proofsJson.map((json) {
      final proofData = jsonDecode(json) as Map<String, dynamic>;
      if (proofData['id'] == proof.id) {
        proofData['status'] = 'rejected';
        proofData['adminMessage'] =
            reason.isEmpty ? 'Payment rejected' : reason;
        proofData['respondedAt'] = DateTime.now().toIso8601String();
        proofData['scope'] = proof.scope;
      }
      return jsonEncode(proofData);
    }).toList();

    await prefs.setStringList(storageKey, updatedProofs);

    final username = proof.username;

    if (isGlobal) {
      await prefs.remove('${username}_global_pending_investment_amount');
      await prefs.remove('global_pending_investment_amount');
      await prefs.remove('global_pending_upload_amount');
      await prefs.remove('global_pending_upload_timestamp');

      final activeGlobalUser = prefs.getString('global_user_name') ??
          prefs.getString('Global_user_name');
      if (activeGlobalUser != null &&
          activeGlobalUser.trim().toLowerCase() ==
              username.trim().toLowerCase()) {}
    } else {
      await prefs.remove('${username}_pending_investment_amount');

      final currentUser = prefs.getString('growth_user_name');
      if (currentUser == username) {
        await prefs.remove('pending_investment_amount');
        await prefs.remove('growth_pending_upload_amount');
        await prefs.remove('growth_pending_upload_timestamp');
      }
    }

    if (!mounted) return;
    _showSnack('Payment rejected', color: Colors.red);
    setState(() {});
  }

  void _showSnack(String message, {Color color = const Color(0xFF667eea)}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _WithdrawalRequest {
  const _WithdrawalRequest({
    required this.storageIndex,
    required this.id,
    required this.username,
    required this.userId,
    required this.amount,
    required this.cashTag,
    required this.status,
    required this.submittedAt,
    required this.scope,
  });

  final int storageIndex;
  final String id;
  final String username;
  final String userId;
  final double amount;
  final String cashTag;
  final String status;
  final DateTime submittedAt;
  final String scope;
}
