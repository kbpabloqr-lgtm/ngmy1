import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;

class GlobalStatsScreen extends StatefulWidget {
  const GlobalStatsScreen({super.key});

  @override
  State<GlobalStatsScreen> createState() => _GlobalStatsScreenState();
}

class _GlobalStatsScreenState extends State<GlobalStatsScreen> {
  static const double _dailyReturnRate =
      0.0286; // 2.86% per day - same as investment screen
  static const int _workingDaysPerMonth = 20; // Monday-Friday over four weeks
  static const double _liveUpdateTolerance = 0.01;
  static const Color _deepPurple = Color(0xFF140C2F);
  static const Color _midPurple = Color(0xFF1C1045);
  static const Color _accentPurple = Color(0xFF6C3FDB);
  static const Color _lavenderGlow = Color(0xFFA379FF);
  static const Color _magentaPulse = Color(0xFFD36BFF);

  double _totalBalance = 0.0;
  int _activeDays = 0;
  double _approvedInvestment = 0.0;
  Duration _totalWorkTime = Duration.zero;
  Timer? _liveMetricsTimer;
  bool _isPollingLiveMetrics = false;

  String _uKey(String username, String suffix) => '${username}_global_$suffix';
  String _gKey(String suffix) => 'global_$suffix';

  @override
  void initState() {
    super.initState();
    _loadData();
    _startLiveMetricsRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload balance whenever screen is shown
    _refreshBalance();
  }

  Future<void> _refreshBalance() async {
  final prefs = await SharedPreferences.getInstance();
  final username =
    prefs.getString(_gKey('user_name')) ??
    prefs.getString('Global_user_name') ??
    'NGMY User';
  final savedBalance = prefs.getDouble(_uKey(username, 'balance')) ??
        0.0;
  final savedActiveDays = prefs.getInt(_uKey(username, 'active_days')) ??
    prefs.getInt(_gKey('active_days')) ??
        0;
  final approvedInvestment =
    prefs.getDouble(_uKey(username, 'approved_investment')) ??
      prefs.getDouble(_gKey('approved_investment')) ??
            0.0;

    if (mounted &&
        (savedBalance != _totalBalance ||
            savedActiveDays != _activeDays ||
            approvedInvestment != _approvedInvestment)) {
      setState(() {
        _totalBalance = savedBalance;
        _activeDays = savedActiveDays;
        _approvedInvestment = approvedInvestment;
        _totalWorkTime = Duration(hours: _activeDays * 8);
      });
    }
  }

  Future<void> _loadData() async {
  final prefs = await SharedPreferences.getInstance();
  final username =
    prefs.getString(_gKey('user_name')) ??
    prefs.getString('Global_user_name') ??
    'NGMY User';
  final savedBalance = prefs.getDouble(_uKey(username, 'balance')) ??
        0.0;
  final savedActiveDays = prefs.getInt(_uKey(username, 'active_days')) ??
    prefs.getInt(_gKey('active_days')) ??
        0;
  final approvedInvestment =
    prefs.getDouble(_uKey(username, 'approved_investment')) ??
      prefs.getDouble(_gKey('approved_investment')) ??
            0.0;

    if (mounted) {
      setState(() {
        _totalBalance = savedBalance;
        _activeDays = savedActiveDays;
        _approvedInvestment = approvedInvestment;
        // Estimate total work time (assume 8 hours per day on average)
        _totalWorkTime = Duration(hours: _activeDays * 8);
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
      final username = prefs.getString('Global_user_name') ?? 'NGMY User';
      final latestBalance =
          prefs.getDouble(_uKey(username, 'balance')) ?? 0.0;
      final latestActiveDays =
          prefs.getInt(_uKey(username, 'active_days')) ??
              prefs.getInt(_gKey('active_days')) ??
              0;
      final latestApprovedInvestment =
          prefs.getDouble(_uKey(username, 'approved_investment')) ??
              prefs.getDouble(_gKey('approved_investment')) ??
              0.0;

      if (!mounted) {
        return;
      }

      final shouldUpdateBalance =
          (latestBalance - _totalBalance).abs() > _liveUpdateTolerance;
      final shouldUpdateActiveDays = latestActiveDays != _activeDays;
      final shouldUpdateInvestment =
          (latestApprovedInvestment - _approvedInvestment).abs() >
              _liveUpdateTolerance;

      if (shouldUpdateBalance ||
          shouldUpdateActiveDays ||
          shouldUpdateInvestment) {
        setState(() {
          if (shouldUpdateBalance) {
            _totalBalance = latestBalance;
          }
          if (shouldUpdateActiveDays) {
            _activeDays = latestActiveDays;
            _totalWorkTime = Duration(hours: _activeDays * 8);
          }
          if (shouldUpdateInvestment) {
            _approvedInvestment = latestApprovedInvestment;
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
                      _buildOverviewCards(),
                      const SizedBox(height: 24),
                      _buildEarningsChart(),
                      const SizedBox(height: 24),
                      _buildStatsGrid(),
                      const SizedBox(height: 24),
                      _buildMilestones(),
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
            'Statistics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    final hasInvestment = _approvedInvestment > 0;
    final totalEarnedDisplay = hasInvestment ? _totalBalance : 0.0;
    final projectedMonthly = hasInvestment
        ? _approvedInvestment * _dailyReturnRate * _workingDaysPerMonth
        : 0.0;

    return Row(
      children: [
        Expanded(
          child: _buildOverviewCard(
            'Total Earned',
            _formatCurrency(totalEarnedDisplay),
            Icons.account_balance_wallet,
            _accentPurple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOverviewCard(
            'Projected Monthly',
            _formatCurrency(projectedMonthly),
            Icons.trending_up,
            _lavenderGlow,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(
      String label, String value, IconData icon, Color color) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha((0.7 * 255).round()),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsChart() {
    final hasInvestment = _approvedInvestment > 0;
    final activeDaysDisplay = hasInvestment ? _activeDays : 0;
    final totalBalanceDisplay = hasInvestment ? _totalBalance : 0.0;
    final averagePerDay = activeDaysDisplay > 0
        ? totalBalanceDisplay / activeDaysDisplay
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: _accentPurple, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Earnings Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Simple bar chart visualization
          SizedBox(
            height: 150,
            child: hasInvestment && activeDaysDisplay > 0
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(math.min(7, activeDaysDisplay), (index) {
                      final dayEarnings =
                          5.0 + (math.Random(index).nextDouble() * 3);
                      const maxBarHeight = 120.0;
                      final barHeight =
                          (dayEarnings / 8) * maxBarHeight;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 30,
                          height: barHeight.clamp(0.0, maxBarHeight).toDouble(),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  _accentPurple,
                                  _lavenderGlow,
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'D${index + 1}',
                            style: TextStyle(
                              color:
                                  Colors.white.withAlpha((0.6 * 255).round()),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    }),
                  )
                : Center(
                    child: Text(
                      'No data yet',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.5 * 255).round()),
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.white.withAlpha((0.1 * 255).round())),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildChartLegend(
                  'Avg/Day',
                  _formatCurrency(averagePerDay),
                  _accentPurple),
              _buildChartLegend(
                  'Peak',
                  hasInvestment ? '₦₲8.00' : '₦₲0.00',
                  _lavenderGlow),
              _buildChartLegend(
                  'Low',
                  hasInvestment ? '₦₲3.50' : '₦₲0.00',
                  _magentaPulse),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha((0.6 * 255).round()),
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final hasInvestment = _approvedInvestment > 0;
    final activeDaysDisplay = hasInvestment ? _activeDays : 0;
    final totalBalanceDisplay = hasInvestment ? _totalBalance : 0.0;
    final totalHours = hasInvestment ? _totalWorkTime.inHours : 0;
    final avgPerDay = activeDaysDisplay > 0
        ? totalBalanceDisplay / activeDaysDisplay
        : 0.0;
    final avgHoursPerDay = activeDaysDisplay > 0
        ? totalHours / activeDaysDisplay
        : 0.0;
    final totalBandwidth = hasInvestment ? activeDaysDisplay * 2.5 : 0.0; // Estimate

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detailed Statistics',
          style: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.of(context).size.width *
                0.045, // 4.5% of screen width
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(
            height: MediaQuery.of(context).size.height *
                0.02), // 2% of screen height
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: MediaQuery.of(context).size.height *
              0.015, // 1.5% of screen height
          crossAxisSpacing:
              MediaQuery.of(context).size.width * 0.03, // 3% of screen width
          childAspectRatio: MediaQuery.of(context).size.width > 600
              ? 1.3
              : 1.1, // Responsive aspect ratio
          children: [
      _buildStatCard('Active Days', '$activeDaysDisplay', Icons.calendar_today,
        _accentPurple),
      _buildStatCard('Avg/Day', _formatCurrency(avgPerDay),
        Icons.attach_money, _lavenderGlow),
      _buildStatCard('Total Hours', '${totalHours}h', Icons.access_time,
        _magentaPulse),
      _buildStatCard(
        'Bandwidth',
        '${totalBandwidth.toStringAsFixed(1)} GB',
        Icons.wifi,
        _accentPurple),
      _buildStatCard(
        'Avg Hours/Day',
        '${avgHoursPerDay.toStringAsFixed(1)}h',
        Icons.timelapse,
        _lavenderGlow),
      _buildStatCard(
        'Efficiency',
        hasInvestment ? '98%' : '0%',
        Icons.speed,
        _magentaPulse),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04), // 4% of screen width
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.08 * 255).round()),
        borderRadius:
            BorderRadius.circular(screenWidth * 0.04), // 4% of screen width
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: screenWidth * 0.08, // 8% of screen width
          ),
          SizedBox(height: screenHeight * 0.008), // 0.8% of screen height
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: screenWidth * 0.045, // 4.5% of screen width
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: screenHeight * 0.005), // 0.5% of screen height
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withAlpha((0.6 * 255).round()),
                fontSize: screenWidth * 0.03, // 3% of screen width
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestones() {
    final hasInvestment = _approvedInvestment > 0;
    final activeDaysDisplay = hasInvestment ? _activeDays : 0;
    final totalBalanceDisplay = hasInvestment ? _totalBalance : 0.0;

    final milestones = [
      {
        'title': 'First Earnings',
        'description': 'Earned your first ₦₲',
        'icon': Icons.star,
        'achieved': activeDaysDisplay > 0
      },
      {
        'title': '7 Day Streak',
        'description': 'Active for 7 consecutive days',
        'icon': Icons.local_fire_department,
        'achieved': activeDaysDisplay >= 7
      },
      {
        'title': '₦₲100 Milestone',
        'description': 'Earned ₦₲100 total',
        'icon': Icons.emoji_events,
        'achieved': totalBalanceDisplay >= 100
      },
      {
        'title': '30 Day Champion',
        'description': 'Active for 30 days',
        'icon': Icons.workspace_premium,
        'achieved': activeDaysDisplay >= 30
      },
      {
        'title': '₦₲500 Master',
        'description': 'Earned ₦₲500 total',
        'icon': Icons.military_tech,
        'achieved': totalBalanceDisplay >= 500
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Achievements',
          style: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.of(context).size.width *
                0.045, // 4.5% of screen width
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(
            height: MediaQuery.of(context).size.height *
                0.02), // 2% of screen height
        ...milestones.map((milestone) => _buildMilestoneCard(
              milestone['title'] as String,
              milestone['description'] as String,
              milestone['icon'] as IconData,
              milestone['achieved'] as bool,
            )),
      ],
    );
  }

  Widget _buildMilestoneCard(
      String title, String description, IconData icon, bool achieved) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      margin: EdgeInsets.only(
          bottom: screenHeight * 0.015), // 1.5% of screen height
      padding: EdgeInsets.all(screenWidth * 0.04), // 4% of screen width
      decoration: BoxDecoration(
        color: achieved
            ? _accentPurple.withAlpha((0.15 * 255).round())
            : Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius:
            BorderRadius.circular(screenWidth * 0.04), // 4% of screen width
        border: Border.all(
          color: achieved
              ? _accentPurple.withAlpha((0.3 * 255).round())
              : Colors.white.withAlpha((0.1 * 255).round()),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.03), // 3% of screen width
            decoration: BoxDecoration(
              color: achieved
                  ? _accentPurple.withAlpha((0.3 * 255).round())
                  : Colors.white.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(
                  screenWidth * 0.03), // 3% of screen width
            ),
            child: Icon(
              icon,
              color: achieved
                  ? _lavenderGlow
                  : Colors.white.withAlpha((0.3 * 255).round()),
              size: screenWidth * 0.07, // 7% of screen width
            ),
          ),
          SizedBox(width: screenWidth * 0.04), // 4% of screen width
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: achieved
                        ? Colors.white
                        : Colors.white.withAlpha((0.5 * 255).round()),
                    fontSize: screenWidth * 0.035, // 3.5% of screen width
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: screenHeight * 0.005), // 0.5% of screen height
                Text(
                  description,
                  style: TextStyle(
                    color: achieved
                        ? Colors.white70
                        : Colors.white.withAlpha((0.3 * 255).round()),
                    fontSize: screenWidth * 0.03, // 3% of screen width
                  ),
                ),
              ],
            ),
          ),
          if (achieved)
            Icon(
              Icons.check_circle,
              color: _lavenderGlow,
              size: screenWidth * 0.06, // 6% of screen width
            )
          else
            Icon(
              Icons.lock_outline,
              color: Colors.white.withAlpha((0.3 * 255).round()),
              size: screenWidth * 0.06, // 6% of screen width
            ),
        ],
      ),
    );
  }

  String _formatCurrency(num amount, {int decimals = 2}) {
    final isNegative = amount.isNegative;
    final absolute = amount.abs();
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

    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';
    final sign = isNegative ? '-' : '';
    return '₦₲$sign${buffer.toString()}$decimalPart';
  }
}

