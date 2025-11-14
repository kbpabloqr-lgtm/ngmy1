import 'package:flutter/material.dart';
import '../../services/ticket_data_store.dart';
import '../../models/ticket_models.dart';
import 'ticket_template_editor_screen.dart';

class TicketCreatorScreen extends StatefulWidget {
  const TicketCreatorScreen({super.key});

  @override
  State<TicketCreatorScreen> createState() => _TicketCreatorScreenState();
}

class _TicketCreatorScreenState extends State<TicketCreatorScreen> {
  final _store = TicketDataStore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Create Tickets',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Choose a template to customize',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.white70),
                    onPressed: () {
                      // Show created tickets history
                    },
                  ),
                ],
              ),
            ),

            // Templates Grid
            Expanded(
              child: AnimatedBuilder(
                animation: _store,
                builder: (context, _) {
                  final templates = _store.templates;
                  
                  return GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      final template = templates[index];
                      return _buildTemplateCard(template);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(TicketTemplate template) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TicketTemplateEditorScreen(template: template),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              template.primaryColor,
              template.accentColor,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: template.primaryColor.withAlpha((0.3 * 255).round()),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Opacity(
                  opacity: 0.1,
                  child: CustomPaint(
                    painter: TicketPatternPainter(),
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getTemplateIcon(template.type),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Template name
                  Text(
                    template.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Template type
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getTemplateTypeName(template.type),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Features
                  Row(
                    children: [
                      if (template.hasQrCode)
                        const Icon(
                          Icons.qr_code,
                          color: Colors.white70,
                          size: 16,
                        ),
                      if (template.hasQrCode) const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${template.customFields.length} custom fields',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // "Create" overlay on hover (visual indicator)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Icon(
                  Icons.arrow_forward,
                  color: template.primaryColor,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTemplateIcon(TicketTemplateType type) {
    switch (type) {
      case TicketTemplateType.concert:
        return Icons.music_note;
      case TicketTemplateType.sports:
        return Icons.sports_soccer;
      case TicketTemplateType.conference:
        return Icons.business;
      case TicketTemplateType.vip:
        return Icons.star;
      case TicketTemplateType.generalAdmission:
        return Icons.confirmation_number;
      case TicketTemplateType.backstage:
        return Icons.verified;
      case TicketTemplateType.festival:
        return Icons.festival;
      case TicketTemplateType.theater:
        return Icons.theater_comedy;
    }
  }

  String _getTemplateTypeName(TicketTemplateType type) {
    switch (type) {
      case TicketTemplateType.concert:
        return 'CONCERT';
      case TicketTemplateType.sports:
        return 'SPORTS';
      case TicketTemplateType.conference:
        return 'CONFERENCE';
      case TicketTemplateType.vip:
        return 'VIP';
      case TicketTemplateType.generalAdmission:
        return 'GENERAL';
      case TicketTemplateType.backstage:
        return 'BACKSTAGE';
      case TicketTemplateType.festival:
        return 'FESTIVAL';
      case TicketTemplateType.theater:
        return 'THEATER';
    }
  }
}

class TicketPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 20.0;
    
    // Draw diagonal lines pattern
    for (var i = 0; i < size.width + size.height; i += spacing.toInt()) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(0, i.toDouble()),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
