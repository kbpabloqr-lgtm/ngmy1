import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/ticket_data_store.dart';
import '../../models/ticket_models.dart';
import 'face_scan_screen.dart';

class CodeApplicationScreen extends StatefulWidget {
  const CodeApplicationScreen({super.key});

  @override
  State<CodeApplicationScreen> createState() => _CodeApplicationScreenState();
}

class _CodeApplicationScreenState extends State<CodeApplicationScreen> {
  final _store = TicketDataStore.instance;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _reasonController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  bool _hasApplied = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _reasonController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Use consistent user ID
    final userId = 'user_${DateTime.now().day}'; // Temporary - replace with real auth

    await _store.submitCodeApplication(
      userId: userId,
      userName: _nameController.text,
      userEmail: _emailController.text,
      reason: _reasonController.text,
    );

    setState(() {
      _isSubmitting = false;
      _hasApplied = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application submitted! Check notifications once approved.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _verifyCode() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your access code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Find the code in access codes
    final accessCode = _store.accessCodes.firstWhere(
      (ac) => ac.code == code,
      orElse: () => AccessCode(
        code: '',
        userId: '',
        issuedAt: DateTime.now(),
        expiryDate: DateTime.now(),
        isRevoked: true,
      ),
    );

    if (accessCode.code.isEmpty || !accessCode.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid or expired code. Check notifications for your approved code.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Code is valid - proceed to face scan
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceScanScreen(accessCode: code, userId: accessCode.userId),
      ),
    );
  }

  void _showNotifications(BuildContext context, List<CodeApplication> approvedApps) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.green),
                  const SizedBox(width: 12),
                  const Text(
                    'Approved Access Codes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (approvedApps.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No approved codes yet',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                )
              else
                ...approvedApps.map((app) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withAlpha((0.3 * 255).round())),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Access Code:',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                app.approvedCode ?? 'N/A',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, color: Colors.green),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: app.approvedCode ?? ''),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Code copied!'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Expires: ${_formatDate(app.codeExpiryDate!)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Get current user ID (replace with actual user auth)
    final currentUserId = 'user_${DateTime.now().day}'; // Temporary - replace with real auth
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ticket Creator Access',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          // Notification Bell
          AnimatedBuilder(
            animation: _store,
            builder: (context, _) {
              final myApprovedCodes = _store.codeApplications
                  .where((app) =>
                      app.userId == currentUserId &&
                      app.status == CodeApplicationStatus.approved)
                  .toList();
              
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.black87),
                    onPressed: () => _showNotifications(context, myApprovedCodes),
                  ),
                  if (myApprovedCodes.isNotEmpty)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${myApprovedCodes.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          // Check if user already has an active code (recalculated on every store change)
          final hasActiveCode = _store.hasActiveCode(currentUserId);
          final userActiveCodes = _store.getUserActiveCodes(currentUserId);
          
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 20),
                // Title
                const Text(
                  'Ticket Creator Access',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter your access code or apply for one',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black.withAlpha((0.6 * 255).round()),
                  ),
                ),
                const SizedBox(height: 40),

                // Code Entry Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.05 * 255).round()),
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
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A90E2).withAlpha((0.1 * 255).round()),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.vpn_key_rounded,
                              color: Color(0xFF4A90E2),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Enter Access Code',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'XXXX-XXXX-XXXX',
                          filled: true,
                          fillColor: const Color(0xFFF5F7FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _verifyCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Verify Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Show active code info or application form
                if (hasActiveCode) ...[
                  // User has active code - show info
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withAlpha((0.1 * 255).round()),
                          Colors.teal.withAlpha((0.05 * 255).round()),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.withAlpha((0.3 * 255).round()),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha((0.2 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'You Have Active Access',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'You currently have ${userActiveCodes.length} active access code(s). Use the code entry above to access the ticket creator.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black.withAlpha((0.7 * 255).round()),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...userActiveCodes.map((code) {
                          final daysLeft = code.expiryDate.difference(DateTime.now()).inDays;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withAlpha((0.2 * 255).round()),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.vpn_key, color: Colors.green, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        code.code,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Expires in $daysLeft days (${_formatDate(code.expiryDate)})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black.withAlpha((0.5 * 255).round()),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: Colors.green),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: code.code));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Code copied!'),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ] else ...[
                  // User doesn't have active code - show divider and application form
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.black.withAlpha((0.1 * 255).round()))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.black.withAlpha((0.4 * 255).round()),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.black.withAlpha((0.1 * 255).round()))),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // Application Form Section
                  Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.05 * 255).round()),
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
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B9D).withAlpha((0.1 * 255).round()),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.assignment_outlined,
                              color: Color(0xFFFF6B9D),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Apply for Access Code',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _reasonController,
                        label: 'Reason for Application',
                        icon: Icons.edit_outlined,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _hasApplied ? null : _submitApplication,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B9D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _hasApplied ? 'Application Submitted' : 'Submit Application',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      if (_hasApplied) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha((0.1 * 255).round()),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withAlpha((0.3 * 255).round()),
                            ),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your application has been sent to admin. You\'ll receive your code via email once approved.',
                                  style: TextStyle(
                                    color: Colors.green,
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
                ], // End of else block for application form
                const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(icon),
      ),
    );
  }
}
