import 'package:flutter/material.dart';
import 'dart:ui';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Privacy Policy',
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
                    'NGMY Investments – Privacy Policy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your privacy is important to us. This Privacy Policy explains how NGMY Investments collects, uses, and protects your personal information.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildTermsSection(
                    '1. Information We Collect',
                    'We collect the following information to manage your account and provide our services:\n\n'
                    '• Personal Information: Name, email address, phone number, and Cash App ID.\n'
                    '• Account Data: Investment amounts, balance, check-in history, referrals, and transaction records.\n'
                    '• Usage Data: Platform activity, login times, check-in times, and session durations.\n'
                    '• Penalty Records: Automated penalty applications and their timestamps.',
                  ),
                  
                  _buildTermsSection(
                    '2. How We Use Your Information',
                    'Your information is used to:\n\n'
                    '• Manage your account and process transactions.\n'
                    '• Calculate and distribute daily returns based on your investment.\n'
                    '• Enforce check-in policies and apply penalties automatically.\n'
                    '• Process withdrawals and payments via Cash App.\n'
                    '• Track referrals and account activity.\n'
                    '• Communicate important updates, policy changes, or account issues.\n'
                    '• Improve platform performance and user experience.',
                  ),
                  
                  _buildTermsSection(
                    '3. Automated Data Processing',
                    'NGMY Investments uses automated systems to:\n\n'
                    '• Monitor daily check-in times.\n'
                    '• Calculate late check-in penalties (25% or 35% of daily income, based on delay).\n'
                    '• Apply daily income deductions automatically.\n'
                    '• Track earning sessions and calculate returns.\n'
                    '• Log all account activity for security and compliance.',
                  ),
                  
                  _buildTermsSection(
                    '4. Data Storage and Security',
                    'Your data is stored securely on your device and our servers:\n\n'
                    '• Local Storage: Account data is cached locally on your device for offline access.\n'
                    '• Cloud Storage: Primary data is stored on secure cloud servers with encryption.\n'
                    '• Access Control: Only authorized personnel can access sensitive user data.\n'
                    '• Backups: Regular backups ensure data recovery in case of system failures.',
                  ),
                  
                  _buildTermsSection(
                    '5. Data Sharing',
                    'We DO NOT sell or share your personal information with third parties, except:\n\n'
                    '• Payment Processing: Cash App ID is used exclusively for withdrawal processing.\n'
                    '• Legal Requirements: We may disclose information if required by law or to protect our rights.\n'
                    '• Service Providers: Trusted third-party services that help operate the platform (subject to strict confidentiality agreements).',
                  ),
                  
                  _buildTermsSection(
                    '6. Check-In and Penalty Tracking',
                    'We automatically track:\n\n'
                    '• Exact check-in timestamps for all users.\n'
                    '• Minutes of delay past midnight (12:00 AM).\n'
                    '• Penalty amounts (25% or 35% of daily income) and reasons.\n'
                    '• Historical penalty records.\n\n'
                    'This data is used to enforce our Terms of Service fairly and transparently. Users can view their penalty history in their profile.',
                  ),
                  
                  _buildTermsSection(
                    '7. Your Rights',
                    'You have the right to:\n\n'
                    '• Access: View your account data, balance, and transaction history at any time.\n'
                    '• Correction: Update your profile information (name, email, Cash App ID).\n'
                    '• Deletion: Request account deletion (subject to pending transactions being settled).\n'
                    '• Export: Request a copy of your data in a readable format.',
                  ),
                  
                  _buildTermsSection(
                    '8. Cookies and Tracking',
                    'NGMY Investments does not use browser cookies or third-party tracking.\n\n'
                    'All tracking is limited to app functionality: login sessions, check-in times, and account activity for platform operation.',
                  ),
                  
                  _buildTermsSection(
                    '9. Changes to Privacy Policy',
                    'We may update this Privacy Policy from time to time.\n\n'
                    'Users will be notified of significant changes via in-app notifications or email. Continued use of the platform after changes indicates acceptance of the updated policy.',
                  ),
                  
                  _buildTermsSection(
                    '10. Contact Us',
                    'If you have questions about this Privacy Policy or how your data is used, please contact us at:\n\n'
                    'Email: support@ngmyinvestments.com\n'
                    'Response Time: Within 48 hours',
                  ),
                  
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withAlpha((0.5 * 255).round()),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.privacy_tip_rounded,
                          color: Colors.blue.shade300,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Your privacy is protected. We only use your data to provide and improve our services.',
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
