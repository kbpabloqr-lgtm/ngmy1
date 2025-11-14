import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';
import '../models/ticket_models.dart';

/// Modern ticket widget inspired by concert/festival ticket designs
/// Features: gradient backgrounds, barcode, signature display
class ModernTicketWidget extends StatelessWidget {
  final GeneratedTicket ticket;
  final bool showStub;
  final double width;
  final String? imageUrl;
  final Uint8List? signatureBytes;
  final String? imagePath;
  final String imagePosition;
  final double imageSize;

  const ModernTicketWidget({
    super.key,
    required this.ticket,
    this.showStub = false,
    this.width = 600,
    this.imageUrl,
    this.signatureBytes,
    this.imagePath,
    this.imagePosition = 'top-right',
    this.imageSize = 200,
  });

  @override
  Widget build(BuildContext context) {
    // Color scheme based on ticket type
    final colorScheme = _getColorScheme();
    
    // Template style based on user selection
    final templateStyle = ticket.customData['template_style'] ?? 'classic';
    
    // Optimized ticket size - 600x900 (fits content perfectly without waste)
    return SizedBox(
      width: width,
      height: (width * 1.5), // 2:3 aspect ratio for perfect fit
      child: _buildTicketByStyle(templateStyle, colorScheme),
    );
  }

  Widget _buildTicketByStyle(String style, Map<String, Color> colors) {
    switch (style.toLowerCase()) {
      case 'modern':
        return _buildModernStyle(colors);
      case 'vintage':
        return _buildVintageStyle(colors);
      case 'minimal':
        return _buildMinimalStyle(colors);
      case 'concert':
        return _buildConcertStyle(colors);
      case 'premium':
        return _buildPremiumStyle(colors);
      case 'classic':
        return _buildMainTicketBody(colors);
      default:
        return _buildMainTicketBody(colors);
    }
  }

  Widget _buildMainTicketBody(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors['primary']!, colors['secondary']!],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.3 * 255).round()),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Pattern/Image
          if (imageUrl != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(),
                ),
              ),
            ),
          
          // Decorative shapes
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha((0.1 * 255).round()),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withAlpha((0.08 * 255).round()),
                ),
              ),
            ),
          ),
          
          // Subtle NGMY Watermarks (almost invisible)
          ..._buildWatermarks(),
          
          // Buyer Name Watermarks in opposite corners
          ..._buildBuyerNameWatermarks(),
          
          // User's Photo with Background Blend (if provided) - Dynamic Position
          if (imagePath != null || ticket.customData['ticket_image'] != null)
            _buildDynamicImage(),
          
          // Main Content
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Event Name (Big Bold)
                Text(
                  ticket.eventName.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withAlpha((0.3 * 255).round()),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Tagline/Description
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.2 * 255).round()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '"${ticket.ticketType}"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Venue & Date Info
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoSection(
                        label: 'VENUE',
                        value: ticket.venue,
                        icon: Icons.location_on,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildInfoSection(
                        label: 'DATE',
                        value: _formatDate(ticket.eventDate),
                        icon: Icons.calendar_today,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Artist & Time Info
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoSection(
                        label: 'HEADLINING',
                        value: ticket.artistName,
                        icon: Icons.person,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildInfoSection(
                        label: 'TIME',
                        value: _formatTime(ticket.eventDate),
                        icon: Icons.access_time,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Price & Serial Number
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors['accent']!,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'PRICE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '\$${ticket.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Logo/Brand
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.2 * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.confirmation_number,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'NGMY',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Buyer Name (if available)
                if (ticket.customData['buyer_name'] != null && ticket.customData['buyer_name']!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.15 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withAlpha((0.3 * 255).round()),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TICKET HOLDER',
                              style: TextStyle(
                                color: Colors.white.withAlpha((0.7 * 255).round()),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ticket.customData['buyer_name']!.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Barcode
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomPaint(
                    painter: BarcodePainter(data: ticket.serialNumber),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Signature (if available) - Show actual signature image
                if (signatureBytes != null || ticket.customData['has_signature'] == 'true')
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors['accent']!,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AUTHORIZED SIGNATURE',
                              style: TextStyle(
                                color: colors['primary']!,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (signatureBytes != null)
                              Container(
                                height: 80,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.black.withAlpha((0.3 * 255).round()),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Image.memory(
                                  signatureBytes!,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.centerLeft,
                                ),
                              )
                            else
                              Container(
                                height: 80,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.black.withAlpha((0.3 * 255).round()),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '~signed~',
                                    style: TextStyle(
                                      color: Colors.black.withAlpha((0.6 * 255).round()),
                                      fontSize: 18,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                
                // Ticket Number
                Center(
                  child: Text(
                    'TICKET NO. ${ticket.serialNumber}',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.8 * 255).round()),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((0.2 * 255).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Map<String, Color> _getColorScheme() {
    // Use user-selected color scheme if available, otherwise fall back to ticket type
    final selectedScheme = ticket.customData['color_scheme'] ?? ticket.ticketType.toLowerCase();
    
    switch (selectedScheme.toLowerCase()) {
      case 'golden':
      case 'vip':
      case 'backstage':
        return {
          'primary': const Color(0xFFFFD700),
          'secondary': const Color(0xFFFFA500),
          'accent': const Color(0xFFFF6B6B),
          'stubPrimary': const Color(0xFFFFA500),
          'stubSecondary': const Color(0xFFFF8C00),
          'perforation': const Color(0xFF333333),
        };
      case 'purple':
      case 'festival':
      case 'concert':
        return {
          'primary': const Color(0xFF8B5CF6),
          'secondary': const Color(0xFFEC4899),
          'accent': const Color(0xFFFF1493),
          'stubPrimary': const Color(0xFF9333EA),
          'stubSecondary': const Color(0xFF7C3AED),
          'perforation': const Color(0xFF4B5563),
        };
      case 'blue':
      case 'sports':
        return {
          'primary': const Color(0xFF3B82F6),
          'secondary': const Color(0xFF1E40AF),
          'accent': const Color(0xFF10B981),
          'stubPrimary': const Color(0xFF2563EB),
          'stubSecondary': const Color(0xFF1D4ED8),
          'perforation': const Color(0xFF374151),
        };
      case 'ocean':
        return {
          'primary': const Color(0xFF0EA5E9),
          'secondary': const Color(0xFF0284C7),
          'accent': const Color(0xFF06B6D4),
          'stubPrimary': const Color(0xFF0369A1),
          'stubSecondary': const Color(0xFF0C4A6E),
          'perforation': const Color(0xFF374151),
        };
      case 'forest':
        return {
          'primary': const Color(0xFF059669),
          'secondary': const Color(0xFF047857),
          'accent': const Color(0xFF10B981),
          'stubPrimary': const Color(0xFF065F46),
          'stubSecondary': const Color(0xFF064E3B),
          'perforation': const Color(0xFF374151),
        };
      case 'sunset':
        return {
          'primary': const Color(0xFFFF7849),
          'secondary': const Color(0xFFEF4444),
          'accent': const Color(0xFFF59E0B),
          'stubPrimary': const Color(0xFFDC2626),
          'stubSecondary': const Color(0xFFB91C1C),
          'perforation': const Color(0xFF374151),
        };
      case 'midnight':
        return {
          'primary': const Color(0xFF1E1B4B),
          'secondary': const Color(0xFF312E81),
          'accent': const Color(0xFF6366F1),
          'stubPrimary': const Color(0xFF3730A3),
          'stubSecondary': const Color(0xFF4338CA),
          'perforation': const Color(0xFF6B7280),
        };
      case 'rose':
        return {
          'primary': const Color(0xFFE11D48),
          'secondary': const Color(0xFFBE185D),
          'accent': const Color(0xFFF43F5E),
          'stubPrimary': const Color(0xFF9F1239),
          'stubSecondary': const Color(0xFF881337),
          'perforation': const Color(0xFF374151),
        };
      case 'silver':
        return {
          'primary': const Color(0xFF6B7280),
          'secondary': const Color(0xFF374151),
          'accent': const Color(0xFF9CA3AF),
          'stubPrimary': const Color(0xFF4B5563),
          'stubSecondary': const Color(0xFF1F2937),
          'perforation': const Color(0xFF6B7280),
        };
      case 'classic':
        return {
          'primary': const Color(0xFFFDA08E),
          'secondary': const Color(0xFFBB9FD6),
          'accent': const Color(0xFF6366F1),
          'stubPrimary': const Color(0xFFC4B5E5),
          'stubSecondary': const Color(0xFFA78BDB),
          'perforation': const Color(0xFF6B7280),
        };
      default:
        return {
          'primary': const Color(0xFFFDA08E),
          'secondary': const Color(0xFFBB9FD6),
          'accent': const Color(0xFF6366F1),
          'stubPrimary': const Color(0xFFC4B5E5),
          'stubSecondary': const Color(0xFFA78BDB),
          'perforation': const Color(0xFF6B7280),
        };
    }
  }

  String _formatDate(DateTime date) {
    final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
  
  // Build subtle watermarks throughout the ticket
  List<Widget> _buildWatermarks() {
    return [
      // Top area watermarks
      Positioned(
        top: 50,
        left: 30,
        child: Transform.rotate(
          angle: -0.2,
          child: _buildSingleWatermark(),
        ),
      ),
      Positioned(
        top: 120,
        right: 40,
        child: Transform.rotate(
          angle: 0.15,
          child: _buildSingleWatermark(),
        ),
      ),
      // Middle area watermarks
      Positioned(
        top: 250,
        left: 80,
        child: Transform.rotate(
          angle: -0.1,
          child: _buildSingleWatermark(),
        ),
      ),
      Positioned(
        top: 350,
        right: 60,
        child: Transform.rotate(
          angle: 0.2,
          child: _buildSingleWatermark(),
        ),
      ),
      // Bottom area watermarks
      Positioned(
        bottom: 150,
        left: 50,
        child: Transform.rotate(
          angle: 0.1,
          child: _buildSingleWatermark(),
        ),
      ),
      Positioned(
        bottom: 80,
        right: 70,
        child: Transform.rotate(
          angle: -0.15,
          child: _buildSingleWatermark(),
        ),
      ),
    ];
  }
  
  Widget _buildSingleWatermark() {
    return Opacity(
      opacity: 0.07, // 2x more visible than photo (photo is 0.35, so watermark at 0.07)
      child: Text(
        'NGMY',
        style: TextStyle(
          fontSize: 96, // 3x bigger (was 32)
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 9, // Proportionally increased
        ),
      ),
    );
  }
  
  // Build buyer name watermarks in opposite corners
  List<Widget> _buildBuyerNameWatermarks() {
    final buyerName = ticket.customData['buyer_name'] ?? 'TICKET HOLDER';
    
    return [
      // Top-left corner (opposite of event name which is top-left in content)
      Positioned(
        top: 20,
        right: 20,
        child: Transform.rotate(
          angle: -0.3,
          child: Opacity(
            opacity: 0.07,
            child: Text(
              buyerName.toUpperCase(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
      // Bottom-left corner
      Positioned(
        bottom: 20,
        left: 20,
        child: Transform.rotate(
          angle: 0.3,
          child: Opacity(
            opacity: 0.07,
            child: Text(
              buyerName.toUpperCase(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    ];
  }
  
  // Build dynamically positioned image
  Widget _buildDynamicImage() {
    final position = ticket.customData['image_position'] ?? imagePosition;
    final size = double.tryParse(ticket.customData['image_size'] ?? '') ?? imageSize;
    final imageSrc = imagePath ?? ticket.customData['ticket_image'];
    
    if (imageSrc == null) return const SizedBox.shrink();
    
    double? top, bottom, left, right;
    
    switch (position) {
      case 'top-left':
        top = 0;
        left = 0;
        break;
      case 'top-right':
        top = 0;
        right = 0;
        break;
      case 'center':
        // Will be centered using alignment
        break;
      case 'bottom-left':
        bottom = 0;
        left = 0;
        break;
      case 'bottom-right':
        bottom = 0;
        right = 0;
        break;
    }
    
    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size * 1.3,
        child: Opacity(
          opacity: 0.35,
          child: Image.file(
            File(imageSrc),
            fit: BoxFit.contain, // Show full image without cropping - user controls size
            colorBlendMode: BlendMode.overlay,
          ),
        ),
      ),
    );
    
    if (position == 'center') {
      return Center(child: imageWidget);
    }
    
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: imageWidget,
    );
  }
}

/// Custom painter for barcode effect
class BarcodePainter extends CustomPainter {
  final String data;
  final bool compact;

  BarcodePainter({required this.data, this.compact = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = compact ? 1.5 : 2;

    final random = math.Random(data.hashCode);
    final barCount = compact ? 40 : 80;
    final barWidth = size.width / barCount;

    for (int i = 0; i < barCount; i++) {
      // Create varied bar pattern based on ticket serial
      final shouldDraw = random.nextBool() || (i % 3 == 0);
      if (shouldDraw) {
        final x = i * barWidth;
        final heightFactor = 0.7 + (random.nextDouble() * 0.3);
        final barHeight = size.height * heightFactor;
        final yOffset = (size.height - barHeight) / 2;
        
        canvas.drawLine(
          Offset(x, yOffset),
          Offset(x, yOffset + barHeight),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Additional template style methods
extension TemplateStyles on ModernTicketWidget {
  Widget _buildModernStyle(Map<String, Color> colors) {
    // Modern style: Professional sleek design with tech elements
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors['primary']!,
            colors['secondary']!,
            colors['primary']!.withAlpha((0.8 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha((0.2 * 255).round()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors['primary']!.withAlpha((0.4 * 255).round()),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withAlpha((0.3 * 255).round()),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Tech pattern overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [
                    Colors.white.withAlpha((0.1 * 255).round()),
                    Colors.transparent,
                    Colors.black.withAlpha((0.1 * 255).round()),
                  ],
                ),
              ),
            ),
          ),
          
          // Geometric accents
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withAlpha((0.15 * 255).round()),
                    Colors.white.withAlpha((0.05 * 255).round()),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withAlpha((0.3 * 255).round()),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: Colors.white.withAlpha((0.8 * 255).round()),
                size: 24,
              ),
            ),
          ),
          
          // Watermarks
          ..._buildWatermarks(),
          ..._buildBuyerNameWatermarks(),
          
          // Side-by-side content
          Row(
            children: [
              // Left side - Event info
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Professional event title
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withAlpha((0.15 * 255).round()),
                              Colors.white.withAlpha((0.05 * 255).round()),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withAlpha((0.3 * 255).round()),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          ticket.eventName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Artist with icon
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            color: Colors.white.withAlpha((0.8 * 255).round()),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ticket.artistName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Venue with icon
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white.withAlpha((0.8 * 255).round()),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ticket.venue,
                              style: TextStyle(
                                color: Colors.white.withAlpha((0.9 * 255).round()),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Date with icon
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Colors.white.withAlpha((0.8 * 255).round()),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(ticket.eventDate),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Right side - QR and details
              Expanded(
                flex: 1,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // QR Code placeholder
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CustomPaint(
                          painter: BarcodePainter(data: ticket.serialNumber, compact: true),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        ticket.serialNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '\$${ticket.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Holder Name and Signature Section
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.3 * 255).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Holder Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TICKET HOLDER',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.7 * 255).round()),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ticket.customData['buyer_name']?.isNotEmpty == true 
                              ? ticket.customData['buyer_name']!.toUpperCase()
                              : 'BEARER',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Signature Area
                  Container(
                    width: 120,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withAlpha((0.3 * 255).round()),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (signatureBytes != null)
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                image: DecorationImage(
                                  image: MemoryImage(signatureBytes!),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          )
                        else
                          Column(
                            children: [
                              Icon(
                                Icons.edit,
                                color: Colors.white.withAlpha((0.5 * 255).round()),
                                size: 16,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'SIGNATURE',
                                style: TextStyle(
                                  color: Colors.white.withAlpha((0.5 * 255).round()),
                                  fontSize: 8,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // User's photo if provided
          if (imagePath != null || ticket.customData['ticket_image'] != null)
            _buildDynamicImage(),
        ],
      ),
    );
  }
  
  Widget _buildVintageStyle(Map<String, Color> colors) {
    // Vintage style: Luxurious classic design with rich details
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2D1B69), // Rich royal purple
            colors['primary']!,
            const Color(0xFF1A0E3D), // Deep vintage purple
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4AF37), // Antique gold
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withAlpha((0.3 * 255).round()),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withAlpha((0.5 * 255).round()),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Vintage paper texture overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withAlpha((0.05 * 255).round()),
                    Colors.transparent,
                    Colors.black.withAlpha((0.05 * 255).round()),
                  ],
                ),
              ),
            ),
          ),
          
          // Elegant corner ornaments
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD4AF37), width: 1),
              ),
              child: Icon(Icons.diamond, color: const Color(0xFFD4AF37), size: 20),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD4AF37), width: 1),
              ),
              child: Icon(Icons.diamond, color: const Color(0xFFD4AF37), size: 20),
            ),
          ),
          
          // Vintage filigree pattern
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFFD4AF37),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // Watermarks
          ..._buildWatermarks(),
          ..._buildBuyerNameWatermarks(),
          
          // Main content with vintage styling
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Decorative header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.amber.withAlpha((0.8 * 255).round()), width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ADMIT ONE',
                    style: TextStyle(
                      color: Colors.amber.withAlpha((0.9 * 255).round()),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Event name with vintage typography
                Text(
                  ticket.eventName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                    fontFamily: 'serif',
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Artist with decorative lines
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.amber.withAlpha((0.6 * 255).round()), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        ticket.artistName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.amber.withAlpha((0.6 * 255).round()), thickness: 1)),
                  ],
                ),
                
                const Spacer(),
                
                // Venue and date in vintage style
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withAlpha((0.3 * 255).round())),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        ticket.venue,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDate(ticket.eventDate),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Price and serial
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${ticket.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ticket.serialNumber,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Elegant Holder Name and Signature Section
          Positioned(
            bottom: 25,
            left: 32,
            right: 32,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD4AF37).withAlpha((0.1 * 255).round()),
                    const Color(0xFFD4AF37).withAlpha((0.05 * 255).round()),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withAlpha((0.6 * 255).round()),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Vintage Holder Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.diamond,
                              color: const Color(0xFFD4AF37),
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'TICKET HOLDER',
                              style: TextStyle(
                                color: const Color(0xFFD4AF37).withAlpha((0.9 * 255).round()),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ticket.customData['buyer_name']?.isNotEmpty == true 
                              ? ticket.customData['buyer_name']!.toUpperCase()
                              : 'HONORED GUEST',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            fontFamily: 'serif',
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Vintage Signature Area
                  Container(
                    width: 130,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.08 * 255).round()),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withAlpha((0.4 * 255).round()),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (signatureBytes != null)
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                image: DecorationImage(
                                  image: MemoryImage(signatureBytes!),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          )
                        else
                          Column(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: const Color(0xFFD4AF37).withAlpha((0.7 * 255).round()),
                                size: 18,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'SIGNATURE',
                                style: TextStyle(
                                  color: const Color(0xFFD4AF37).withAlpha((0.7 * 255).round()),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // User's photo if provided
          if (imagePath != null || ticket.customData['ticket_image'] != null)
            _buildDynamicImage(),
        ],
      ),
    );
  }
  
  Widget _buildMinimalStyle(Map<String, Color> colors) {
    // Minimal style: Ultra-modern sophisticated design
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFF8FAFC),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors['primary']!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors['primary']!.withAlpha((0.1 * 255).round()),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Professional accent header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors['primary']!, colors['secondary']!, colors['accent']!],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),
          ),
          
          // Subtle geometric accent
          Positioned(
            top: 20,
            right: 30,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors['primary']!.withAlpha((0.1 * 255).round()),
                    colors['secondary']!.withAlpha((0.05 * 255).round()),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors['primary']!.withAlpha((0.2 * 255).round()),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.verified,
                color: colors['primary']!.withAlpha((0.6 * 255).round()),
                size: 20,
              ),
            ),
          ),
          
          // Watermarks (lighter for minimal style)
          ...(_buildWatermarks().map((w) => Opacity(opacity: 0.02, child: w))),
          ...(_buildBuyerNameWatermarks().map((w) => Opacity(opacity: 0.02, child: w))),
          
          // Clean content layout
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event name - simple and clean
                Text(
                  ticket.eventName,
                  style: TextStyle(
                    color: colors['primary']!,
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.5,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Simple divider
                Container(
                  width: 60,
                  height: 2,
                  color: colors['primary']!,
                ),
                
                const SizedBox(height: 24),
                
                // Event details in clean typography
                _buildMinimalInfoRow('Artist', ticket.artistName, colors),
                const SizedBox(height: 16),
                _buildMinimalInfoRow('Venue', ticket.venue, colors),
                const SizedBox(height: 16),
                _buildMinimalInfoRow('Date', _formatDate(ticket.eventDate), colors),
                const SizedBox(height: 16),
                _buildMinimalInfoRow('Time', _formatTime(ticket.eventDate), colors),
                
                const Spacer(),
                
                // Price and serial at bottom
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRICE',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${ticket.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: colors['primary']!,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    // Simple barcode
                    Container(
                      width: 120,
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: CustomPaint(
                        painter: BarcodePainter(data: ticket.serialNumber, compact: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Clean Minimal Holder Name and Signature
          Positioned(
            bottom: 20,
            left: 40,
            right: 40,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors['primary']!.withAlpha((0.2 * 255).round()),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors['primary']!.withAlpha((0.1 * 255).round()),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Clean Holder Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HOLDER',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ticket.customData['buyer_name']?.isNotEmpty == true 
                              ? ticket.customData['buyer_name']!.toUpperCase()
                              : 'ATTENDEE',
                          style: TextStyle(
                            color: colors['primary']!,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Clean Signature Area
                  Container(
                    width: 100,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (signatureBytes != null)
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                image: DecorationImage(
                                  image: MemoryImage(signatureBytes!),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          )
                        else
                          Column(
                            children: [
                              Icon(
                                Icons.draw,
                                color: Colors.grey.shade400,
                                size: 16,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'SIGNATURE',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 8,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // User's photo if provided (subtle in minimal style)
          if (imagePath != null || ticket.customData['ticket_image'] != null)
            Opacity(opacity: 0.1, child: _buildDynamicImage()),
        ],
      ),
    );
  }
  
  Widget _buildMinimalInfoRow(String label, String value, Map<String, Color> colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: colors['primary']!,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildConcertStyle(Map<String, Color> colors) {
    // Concert style: High-energy professional event design
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A0A0A), // Deep black
            colors['primary']!,
            colors['secondary']!,
            const Color(0xFF1A1A1A), // Rich black
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors['accent']!.withAlpha((0.8 * 255).round()),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors['primary']!.withAlpha((0.4 * 255).round()),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: colors['accent']!.withAlpha((0.2 * 255).round()),
            blurRadius: 50,
            offset: const Offset(0, 25),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Professional stage lighting effects
          Positioned(
            top: -80,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    colors['accent']!.withAlpha((0.15 * 255).round()),
                    colors['primary']!.withAlpha((0.08 * 255).round()),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // Dynamic spotlight beam
          Positioned(
            top: 30,
            right: -20,
            child: Container(
              width: 120,
              height: 250,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    colors['accent']!.withAlpha((0.2 * 255).round()),
                    colors['secondary']!.withAlpha((0.1 * 255).round()),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // Professional concert border accents
          Positioned(
            top: 15,
            left: 15,
            right: 15,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    colors['accent']!,
                    colors['primary']!,
                    colors['accent']!,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // Watermarks
          ..._buildWatermarks(),
          ..._buildBuyerNameWatermarks(),
          
          // Concert poster content
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // "LIVE IN CONCERT" header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.9 * 255).round()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'LIVE IN CONCERT',
                    style: TextStyle(
                      color: colors['primary']!,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Massive event name
                Text(
                  ticket.eventName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    height: 0.9,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 8,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Artist with special styling
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors['accent']!, colors['primary']!],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    'FEATURING ${ticket.artistName.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Venue and date in concert style
                Column(
                  children: [
                    Text(
                      ticket.venue.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(ticket.eventDate).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(ticket.eventDate),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Bottom bar with price and barcode
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.6 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TICKET PRICE',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${ticket.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 100,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: CustomPaint(
                          painter: BarcodePainter(data: ticket.serialNumber, compact: true),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // User's photo if provided
          if (imagePath != null || ticket.customData['ticket_image'] != null)
            _buildDynamicImage(),
        ],
      ),
    );
  }
  
  Widget _buildPremiumStyle(Map<String, Color> colors) {
    // Premium style: Luxury VIP design with gold accents
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E),
            Colors.black,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD700),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withAlpha((0.3 * 255).round()),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Luxury background pattern
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    const Color(0xFFFFD700).withAlpha((0.05 * 255).round()),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // Gold corner ornaments
          Positioned(
            top: 16,
            left: 16,
            child: Icon(Icons.diamond, color: const Color(0xFFFFD700), size: 24),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Icon(Icons.diamond, color: const Color(0xFFFFD700), size: 24),
          ),
          
          // VIP badge
          Positioned(
            top: 20,
            left: 50,
            right: 50,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.3 * 255).round()),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                '★ PREMIUM ACCESS ★',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // Enhanced watermarks
          ..._buildWatermarks(),
          ..._buildBuyerNameWatermarks(),
          
          // Premium content
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 70, 32, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Event name with gold styling
                Text(
                  ticket.eventName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Color(0xFFFFD700),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 20),
                
                // Luxury divider
                Row(
                  children: [
                    Expanded(child: Container(height: 1, color: const Color(0xFFFFD700))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 16),
                    ),
                    Expanded(child: Container(height: 1, color: const Color(0xFFFFD700))),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Artist with premium styling
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFFD700), width: 1),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.black.withAlpha((0.3 * 255).round()),
                  ),
                  child: Text(
                    ticket.artistName,
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Premium event details
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withAlpha((0.6 * 255).round()),
                        Colors.black.withAlpha((0.4 * 255).round()),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD700).withAlpha((0.5 * 255).round())),
                  ),
                  child: Column(
                    children: [
                      _buildPremiumDetailRow('VENUE', ticket.venue),
                      const SizedBox(height: 12),
                      _buildPremiumDetailRow('DATE', _formatDate(ticket.eventDate)),
                      const SizedBox(height: 12),
                      _buildPremiumDetailRow('TIME', _formatTime(ticket.eventDate)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Premium price and serial
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PREMIUM PRICE',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${ticket.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ticket.serialNumber,
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // User's photo if provided
          if (imagePath != null || ticket.customData['ticket_image'] != null)
            _buildDynamicImage(),
        ],
      ),
    );
  }
  
  Widget _buildPremiumDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFFFFD700).withAlpha((0.8 * 255).round()),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
