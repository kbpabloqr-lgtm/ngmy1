import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// Cash App Style Models
class Contact {
  final String id;
  final String name;
  final String avatar;
  final bool isFavorite;

  Contact({
    required this.id,
    required this.name,
    required this.avatar,
    this.isFavorite = false,
  });
}

class Transaction {
  final String id;
  final String type; // 'send', 'receive', 'payment', 'withdraw'
  final String personName;
  final double amount;
  final DateTime timestamp;
  final String description;
  final IconData icon;

  Transaction({
    required this.id,
    required this.type,
    required this.personName,
    required this.amount,
    required this.timestamp,
    required this.description,
    required this.icon,
  });
}

class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({super.key});

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen> with TickerProviderStateMixin {
  // Cash App Style State Variables
  double _totalBalance = 23590.73;
  double _lastWeekGain = 456.00;
  
  // Sample data matching the screenshots
  final List<Contact> _favoriteContacts = [
    Contact(id: '1', name: 'Alina', avatar: '👩', isFavorite: true),
    Contact(id: '2', name: 'Mark', avatar: '👨', isFavorite: true),
    Contact(id: '3', name: 'Ruby', avatar: '👩‍🦰', isFavorite: true),
  ];
  
  final List<Transaction> _transactions = [
    Transaction(
      id: '1',
      type: 'send',
      personName: 'Kumashi H.',
      amount: -450.00,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      description: 'TRCB CU220301234',
      icon: Icons.arrow_outward,
    ),
    Transaction(
      id: '2',
      type: 'receive',
      personName: 'Alina',
      amount: 1350.00,
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      description: 'TRCB CU220301234',
      icon: Icons.arrow_downward,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalBalance = prefs.getDouble('total_balance') ?? 23590.73;
      _lastWeekGain = prefs.getDouble('last_week_gain') ?? 456.00;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9ACD32), // Bright lime green background like screenshot
      body: SafeArea(
        child: Column(
          children: [
            // Header with profile and settings
            _buildHeader(),
            
            // Main content area
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF9ACD32), // Keep green background
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Balance Card - Main focal point
                      _buildBalanceCard(),
                      
                      const SizedBox(height: 30),
                      
                      // Quick Action Buttons (Send, Request, Payment, Withdraw)
                      _buildQuickActions(),
                      
                      const SizedBox(height: 40),
                      
                      // Favorite Contacts Section
                      _buildFavoriteContacts(),
                      
                      const SizedBox(height: 40),
                      
                      // Transactions Section
                      _buildTransactionsSection(),
                      
                      const SizedBox(height: 100), // Bottom padding
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // Bottom Navigation Bar
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Profile Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Name
          const Expanded(
            child: Text(
              'Janvis David',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Settings and Search Icons
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.black.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.settings,
              color: Colors.white,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 12),
          
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.black.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.qr_code_scanner,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // "Total Balance" label
          const Text(
            'Total Balance',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Main balance amount
          Text(
            '\$${_totalBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: -2,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Last week indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+\$${_lastWeekGain.toStringAsFixed(0)} Last week',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // More options button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.more_horiz, color: Colors.black54, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickActionButton(
            'Send',
            Icons.arrow_outward,
            () {
              // Send money action
            },
          ),
          _buildQuickActionButton(
            'Request',
            Icons.arrow_downward,
            () {
              // Request money action
            },
          ),
          _buildQuickActionButton(
            'Payment',
            Icons.credit_card,
            () {
              // Payment action
            },
          ),
          _buildQuickActionButton(
            'Withdraw',
            Icons.account_balance,
            () {
              // Withdraw action
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteContacts() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Favourite Contacts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'View all',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withValues(alpha: 0.8),
                size: 14,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Contacts Row
          Row(
            children: [
              // Add Contact Button
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Favorite contacts
              ..._favoriteContacts.map((contact) => Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: Text(
                          contact.avatar,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      contact.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Transactions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'View all',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withValues(alpha: 0.8),
                size: 14,
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // "Today" label
          Text(
            'Today',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Transaction Items
          ..._transactions.map((transaction) => _buildTransactionItem(transaction)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final isPositive = transaction.amount > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Transaction Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              transaction.icon,
              color: isPositive ? Colors.green : Colors.red,
              size: 22,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Transaction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isPositive ? 'Receive from' : 'Send Money to'} ${transaction.personName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Amount and Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : ''}\$${transaction.amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  color: isPositive ? Colors.white : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatTime(transaction.timestamp),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.home, 'Home', true),
          _buildNavItem(Icons.credit_card, 'Cards', false),
          _buildNavItem(Icons.history, 'History', false),
          _buildNavItem(Icons.search, 'Search', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF9ACD32) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : Colors.black54,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF9ACD32) : Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} PM';
    }
  }
}
