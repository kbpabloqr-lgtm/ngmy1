import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'dart:convert';

class AdminPenaltyMonitorScreen extends StatefulWidget {
  const AdminPenaltyMonitorScreen({super.key});

  @override
  State<AdminPenaltyMonitorScreen> createState() => _AdminPenaltyMonitorScreenState();
}

class _AdminPenaltyMonitorScreenState extends State<AdminPenaltyMonitorScreen> {
  Map<String, List<Map<String, dynamic>>> _allUserPenalties = {};
  bool _isLoading = true;
  double _totalPenaltiesCollected = 0.0;
  int _totalPenaltyCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAllUserPenalties();
  }

  Future<void> _loadAllUserPenalties() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    
    final userPenalties = <String, List<Map<String, dynamic>>>{};
    double totalAmount = 0.0;
    int totalCount = 0;
    
    // Find all penalty history keys
    for (final key in allKeys) {
      if (key.endsWith('_penalty_history')) {
        final username = key.replaceAll('_penalty_history', '');
        final penaltyList = prefs.getStringList(key) ?? [];
        
        final penalties = penaltyList
            .map((record) {
              try {
                return jsonDecode(record) as Map<String, dynamic>;
              } catch (e) {
                return <String, dynamic>{};
              }
            })
            .where((record) => record.isNotEmpty)
            .toList();
        
        if (penalties.isNotEmpty) {
          userPenalties[username] = penalties;
          
          // Calculate totals
          for (final penalty in penalties) {
            totalAmount += (penalty['amount'] as num?)?.toDouble() ?? 0.0;
            totalCount++;
          }
        }
      }
    }
    
    setState(() {
      _allUserPenalties = userPenalties;
      _totalPenaltiesCollected = totalAmount;
      _totalPenaltyCount = totalCount;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Admin Penalty Monitor',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadAllUserPenalties();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Column(
              children: [
                _buildStatsHeader(),
                Expanded(
                  child: _allUserPenalties.isEmpty
                      ? _buildEmptyState()
                      : _buildUserPenaltiesList(),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.withAlpha((0.2 * 255).round()),
            Colors.red.withAlpha((0.2 * 255).round()),
          ],
        ),
        border: Border.all(
          color: Colors.orange.withAlpha((0.4 * 255).round()),
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
                    Icons.analytics_outlined,
                    color: Colors.orange.shade300,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Penalty System Statistics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(
                    'Total Users',
                    '${_allUserPenalties.length}',
                    Icons.people,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Total Penalties',
                    '$_totalPenaltyCount',
                    Icons.warning_amber,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Amount Collected',
                    '₦₲${_totalPenaltiesCollected.toStringAsFixed(2)}',
                    Icons.account_balance_wallet,
                    Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color.withAlpha((0.7 * 255).round()), size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color.withAlpha((0.9 * 255).round()),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha((0.6 * 255).round()),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Penalties Applied',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All users are checking in on time!',
            style: TextStyle(
              color: Colors.white.withAlpha((0.7 * 255).round()),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserPenaltiesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _allUserPenalties.length,
      itemBuilder: (context, index) {
        final username = _allUserPenalties.keys.elementAt(index);
        final penalties = _allUserPenalties[username]!;
        return _buildUserPenaltyCard(username, penalties);
      },
    );
  }

  Widget _buildUserPenaltyCard(String username, List<Map<String, dynamic>> penalties) {
    final totalPenaltyAmount = penalties.fold<double>(
      0.0,
      (sum, penalty) => sum + ((penalty['amount'] as num?)?.toDouble() ?? 0.0),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withAlpha((0.1 * 255).round()),
            Colors.white.withAlpha((0.05 * 255).round()),
          ],
        ),
        border: Border.all(
          color: Colors.white.withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            iconColor: Colors.white,
            collapsedIconColor: Colors.white70,
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red.withAlpha((0.3 * 255).round()),
                  child: Text(
                    username.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${penalties.length} penalties • ₦₲${totalPenaltyAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            children: penalties.map((penalty) {
              return _buildPenaltyItem(penalty);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPenaltyItem(Map<String, dynamic> penalty) {
    final date = DateTime.tryParse(penalty['date'] ?? '');
    final reason = penalty['reason'] ?? 'Unknown';
    final percentage = penalty['percentage'] ?? '0%';
    final amount = (penalty['amount'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  reason,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha((0.3 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  percentage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date != null ? _formatDate(date) : 'Unknown date',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.5 * 255).round()),
                  fontSize: 12,
                ),
              ),
              Text(
                '₦₲${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
