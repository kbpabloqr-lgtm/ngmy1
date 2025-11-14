import 'package:flutter/material.dart';
import 'dart:ui';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Terms of Service',
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NGMY Investments – Terms & Conditions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome to NGMY Investments. By creating an account and using our platform, you agree to comply with the following Terms and Conditions. Please read them carefully before participating.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildTermsSection(
                    '1. Account Responsibility',
                    'Users are required to log in and check in daily before 12:00 AM (midnight). Failure to do so may result in a balance penalty as outlined below.\n\n'
                    'Users who have purchased an investment plan are subject to all check-in requirements and penalties.',
                  ),
                  
                  _buildTermsSection(
                    '2. Daily Check-In Policy',
                    'On-Time Check-In: Users must check in daily by 12:00 AM (midnight).\n\n'
                    'Late Check-In Penalties (Automatic Enforcement):\n\n'
                    '• If you check in 15-29 minutes late (between 12:15 AM and 12:29 AM):\n'
                    '  → 25% deduction applied to your daily income.\n\n'
                    '• If you check in 30 minutes late or more (12:30 AM or later):\n'
                    '  → 35% deduction applied to your daily income.\n\n'
                    'Grace Period:\n'
                    '• Check-ins completed before 12:15 AM have NO penalties.\n\n'
                    'Penalty Calculation Example:\n'
                    '• If your investment amount is \$300, your daily income is 2.86% of \$300 = \$8.58.\n'
                    '• If you clock in 15 minutes late, 25% of \$8.58 (\$2.15) will be deducted, so you earn \$6.43 for that day.\n'
                    '• If you clock in 35 minutes late, 35% of \$8.58 (\$3.00) will be deducted, so you earn \$5.58 for that day.\n\n'
                    'Important Notes:\n'
                    '• Penalties are calculated based on your daily income at check-in time.\n'
                    '• Penalties are applied immediately and automatically.\n'
                    '• All penalties are non-refundable and final.\n'
                    '• Penalty history is tracked and can be viewed in your profile.\n'
                    '• Only users with active investment plans are subject to penalties.',
                  ),
                  
                  _buildTermsSection(
                    '3. Investment Requirements',
                    'To earn daily returns, users must:\n\n'
                    '• Purchase an approved investment plan.\n'
                    '• Check in daily during the allowed time window.\n'
                    '• Complete the required 2-hour earning session.\n\n'
                    'Daily returns are calculated at 2.86% of your investment amount. Returns are earned progressively during your 2-hour session.',
                  ),
                  
                  _buildTermsSection(
                    '4. Referral Requirement',
                    'Each user is required to invite three (3) new members to the platform within 30 days of registration.\n\n'
                    'If you fail to invite 3 users within the 30-day period:\n'
                    '• Your account will be deactivated and removed from the platform.\n'
                    '• The remaining balance in your account will be sent to you through Cash App.\n'
                    '• After payment is sent, no further compensation or payments will be issued by NGMY Investments.',
                  ),
                  
                  _buildTermsSection(
                    '5. Account Termination',
                    'NGMY Investments reserves the right to terminate or suspend any account that:\n\n'
                    '• Violates these Terms.\n'
                    '• Engages in fraudulent activity.\n'
                    '• Fails to meet participation requirements.\n'
                    '• Repeatedly violates check-in policies.',
                  ),
                  
                  _buildTermsSection(
                    '6. Payment Policy',
                    'All withdrawals and refunds will be processed exclusively via Cash App.\n\n'
                    'NGMY Investments is not responsible for delays or errors resulting from incorrect Cash App details provided by the user.',
                  ),
                  
                  _buildTermsSection(
                    '7. Penalty Appeals',
                    'Penalties are automatically applied by the system based on check-in times.\n\n'
                    'If you believe a penalty was applied in error due to a technical issue, you may contact support within 24 hours of the incident with evidence.\n\n'
                    'Valid technical errors may result in penalty reversal. User error or forgetfulness is not grounds for appeal.',
                  ),
                  
                  _buildTermsSection(
                    '8. Updates to Terms',
                    'NGMY Investments reserves the right to amend these Terms at any time.\n\n'
                    'Users will be notified of updates, and continued use of the platform constitutes acceptance of the revised Terms.',
                  ),
                  
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withAlpha((0.5 * 255).round()),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade300,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'By using NGMY Investments, you acknowledge that you have read, understood, and agree to these Terms of Service.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
