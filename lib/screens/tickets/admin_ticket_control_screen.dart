import 'package:flutter/material.dart';
import '../../services/ticket_data_store.dart';
import '../../models/ticket_models.dart';

class AdminTicketControlScreen extends StatefulWidget {
  const AdminTicketControlScreen({super.key});

  @override
  State<AdminTicketControlScreen> createState() => _AdminTicketControlScreenState();
}

class _AdminTicketControlScreenState extends State<AdminTicketControlScreen> {
  final _store = TicketDataStore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Ticket System Control',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Notification bell
          AnimatedBuilder(
            animation: _store,
            builder: (context, _) {
              final pendingCount = _store.pendingApplicationsCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    onPressed: () {
                      // Already showing applications, just scroll to top
                    },
                  ),
                  if (pendingCount > 0)
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
                          '$pendingCount',
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
          final applications = _store.codeApplications;
          final pendingApps = applications
              .where((app) => app.status == CodeApplicationStatus.pending)
              .toList();
          final approvedApps = applications
              .where((app) => app.status == CodeApplicationStatus.approved)
              .toList();
          final rejectedApps = applications
              .where((app) => app.status == CodeApplicationStatus.rejected)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Pending',
                        pendingApps.length,
                        Colors.orange,
                        Icons.pending_actions,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Approved',
                        approvedApps.length,
                        Colors.green,
                        Icons.check_circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Rejected',
                        rejectedApps.length,
                        Colors.red,
                        Icons.cancel,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Pending Applications Section
                if (pendingApps.isNotEmpty) ...[
                  const Text(
                    'Pending Applications',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...pendingApps.map((app) => _buildApplicationCard(app)),
                  const SizedBox(height: 24),
                ],
                
                // Approved Applications Section
                if (approvedApps.isNotEmpty) ...[
                  const Text(
                    'Approved Applications',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...approvedApps.map((app) => _buildApplicationCard(app)),
                  const SizedBox(height: 24),
                ],
                
                // Rejected Applications Section
                if (rejectedApps.isNotEmpty) ...[
                  const Text(
                    'Rejected Applications',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...rejectedApps.map((app) => _buildApplicationCard(app)),
                ],
                
                if (applications.isEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: Colors.white.withAlpha((0.3 * 255).round()),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No applications yet',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
  color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withAlpha((0.3 * 255).round()),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(CodeApplication app) {
    final isPending = app.status == CodeApplicationStatus.pending;
    final isApproved = app.status == CodeApplicationStatus.approved;
    
    Color statusColor;
    switch (app.status) {
      case CodeApplicationStatus.pending:
        statusColor = Colors.orange;
        break;
      case CodeApplicationStatus.approved:
        statusColor = Colors.green;
        break;
      case CodeApplicationStatus.rejected:
        statusColor = Colors.red;
        break;
      case CodeApplicationStatus.expired:
        statusColor = Colors.grey;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
  color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withAlpha((0.3 * 255).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      app.userEmail,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  app.status.name.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Reason:',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            app.reason,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Applied: ${_formatDate(app.appliedAt)}',
            style: TextStyle(
              color: Colors.white.withAlpha((0.4 * 255).round()),
              fontSize: 11,
            ),
          ),
          
          if (isApproved && app.approvedCode != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withAlpha((0.3 * 255).round())),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.vpn_key, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Code: ${app.approvedCode}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Expires: ${_formatDate(app.codeExpiryDate!)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showDeleteCodeDialog(app.approvedCode!),
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Delete Code'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showEditExpiryDialog(app.approvedCode!),
                          icon: const Icon(Icons.edit_calendar, size: 16),
                          label: const Text('Edit Expiry'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(app),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showApproveDialog(app),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showApproveDialog(CodeApplication app) {
    int expiryDays = 30;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1628),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Approve Application',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Set code expiration for ${app.userName}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text(
                    'Expiry Days:',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<int>(
                      value: expiryDays,
                      dropdownColor: const Color(0xFF0A1628),
                      style: const TextStyle(color: Colors.white),
                      underline: Container(),
                      items: [7, 14, 30, 60, 90, 365].map((days) {
                        return DropdownMenuItem(
                          value: days,
                          child: Text('$days days'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => expiryDays = value!);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await _store.approveApplication(app.id, expiryDays);
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Approved! Code sent to ${app.userEmail}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Approve'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(CodeApplication app) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reject Application',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Provide a reason for rejecting ${app.userName}\'s application',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Reason for rejection...',
                hintStyle: TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isNotEmpty) {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await _store.rejectApplication(app.id, reasonController.text);
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Application rejected'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showEditExpiryDialog(String code) {
    int daysToAdd = 7; // Default: add 7 days
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1628),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Edit Code Expiry',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Adjust expiration date for code: $code',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      daysToAdd > 0 
                          ? 'Add $daysToAdd day${daysToAdd == 1 ? '' : 's'}'
                          : 'Remove ${-daysToAdd} day${daysToAdd == -1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setDialogState(() {
                        if (daysToAdd > -30) daysToAdd--;
                      });
                    },
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                  ),
                  Expanded(
                    child: Slider(
                      value: daysToAdd.toDouble(),
                      min: -30,
                      max: 90,
                      divisions: 120,
                      activeColor: daysToAdd >= 0 ? Colors.green : Colors.red,
                      label: daysToAdd > 0 
                          ? '+$daysToAdd days'
                          : '$daysToAdd days',
                      onChanged: (value) {
                        setDialogState(() {
                          daysToAdd = value.toInt();
                        });
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setDialogState(() {
                        if (daysToAdd < 90) daysToAdd++;
                      });
                    },
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Range: -30 to +90 days',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.4 * 255).round()),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _store.editCodeExpiry(code, daysToAdd);
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          daysToAdd > 0 
                              ? 'Code expiry extended by $daysToAdd days'
                              : 'Code expiry reduced by ${-daysToAdd} days',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Access Code',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to delete this access code?',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha((0.3 * 255).round())),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This action will:\n• Remove the code permanently\n• Reset the user\'s application to pending\n• Cannot be undone',
              style: TextStyle(
                color: Colors.white.withAlpha((0.6 * 255).round()),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _store.deleteAccessCode(code);
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Access code deleted successfully'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error deleting code: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
