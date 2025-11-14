import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/ticket_models.dart';
import '../../services/ticket_data_store.dart';
import '../../services/event_defaults_service.dart';
import '../../widgets/modern_ticket_widget.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:nfc_manager/nfc_manager.dart';
// ignore: implementation_imports
import 'package:nfc_manager/src/nfc_manager_android/tags/ndef.dart' as android_ndef;
// ignore: implementation_imports
import 'package:nfc_manager/src/nfc_manager_ios/tags/ndef.dart' as ios_ndef;
import 'package:ndef_record/ndef_record.dart';

class TicketTemplateEditorScreen extends StatefulWidget {
  final TicketTemplate template;

  const TicketTemplateEditorScreen({super.key, required this.template});

  @override
  State<TicketTemplateEditorScreen> createState() => _TicketTemplateEditorScreenState();
}

class _TicketTemplateEditorScreenState extends State<TicketTemplateEditorScreen> {
  final _store = TicketDataStore.instance;
  final _formKey = GlobalKey<FormState>();
  final _ticketKey = GlobalKey(); // Key for capturing ticket as image
  late final SignatureController _signatureController;
  
  late TextEditingController _eventNameController;
  late TextEditingController _artistNameController;
  late TextEditingController _venueController;
  late TextEditingController _ticketTypeController;
  late TextEditingController _priceController;
  late TextEditingController _buyerNameController;
  final Map<String, TextEditingController> _customFieldControllers = {};
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  bool _isGenerating = false;
  Uint8List? _signatureBytes;
  String? _selectedImagePath;
  
  // Image position and size controls
  String _imagePosition = 'top-right'; // top-right, top-left, bottom-right, bottom-left, center
  double _imageSize = 200; // Width in pixels
  
  // Color scheme selection
  String _selectedColorScheme = 'classic';
  
  // Template style selection
  String _selectedTemplateStyle = 'classic';

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.transparent,
    );
    _eventNameController = TextEditingController();
    _artistNameController = TextEditingController();
    _venueController = TextEditingController();
    _ticketTypeController = TextEditingController(text: widget.template.name);
    _priceController = TextEditingController(text: '50.00');
    _buyerNameController = TextEditingController();
    
    // Load saved defaults
    _loadEventDefaults();
    
    for (final field in widget.template.customFields) {
      _customFieldControllers[field] = TextEditingController();
    }
    
    // Load saved signature
    _loadSavedSignature();
  }
  
  Future<void> _loadSavedSignature() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSig = prefs.getString('saved_signature');
    if (savedSig != null) {
      try {
  // Decode the saved signature into bytes for preview reuse
  final bytes = base64Decode(savedSig);
  setState(() => _signatureBytes = bytes);
        
        // Note: We keep the signature pad empty but show indicator that signature is saved
        // Signature loaded successfully
      } catch (e) {
        // Error loading signature
      }
    }
  }
  
  Future<void> _saveSignature() async {
    if (_signatureBytes != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        // Encode to base64 for storage
        final base64Str = base64Encode(_signatureBytes!);
        await prefs.setString('saved_signature', base64Str);
        // Signature saved successfully
      } catch (e) {
        // Error saving signature
      }
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _eventNameController.dispose();
    _artistNameController.dispose();
    _venueController.dispose();
    _ticketTypeController.dispose();
    _priceController.dispose();
    _buyerNameController.dispose();
    for (var c in _customFieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Load saved event defaults from persistent storage
  Future<void> _loadEventDefaults() async {
    try {
      final defaults = await EventDefaultsService.getAllDefaults();
      
      if (defaults['eventName'] != null) {
        _eventNameController.text = defaults['eventName'];
      }
      if (defaults['venue'] != null) {
        _venueController.text = defaults['venue'];
      }
      if (defaults['artist'] != null) {
        _artistNameController.text = defaults['artist'];
      }
      if (defaults['price'] != null) {
        _priceController.text = defaults['price'].toString();
      }
      if (defaults['ticketType'] != null) {
        _ticketTypeController.text = defaults['ticketType'];
      }
      
      // Update UI if mounted
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Handle error silently - don't break the app if defaults can't be loaded
    }
  }

  /// Save current event details as defaults
  Future<void> _saveEventDefaults() async {
    try {
      await EventDefaultsService.saveAllDefaults(
        eventName: _eventNameController.text.trim(),
        venue: _venueController.text.trim(),
        artist: _artistNameController.text.trim(),
        price: double.tryParse(_priceController.text),
        ticketType: _ticketTypeController.text.trim(),
      );
    } catch (e) {
      // Error saving event defaults - fail silently
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    
    if (pickedFile != null) {
      setState(() {
        _selectedImagePath = pickedFile.path;
      });
    }
  }

  Future<void> _generateTicket() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Capture signature
    if (_signatureController.isNotEmpty) {
      final signatureImage = await _signatureController.toPngBytes();
      setState(() => _signatureBytes = signatureImage);
      // Save signature for future use
      await _saveSignature();
    }

    setState(() => _isGenerating = true);

    try {
      final customData = <String, String>{};
      _customFieldControllers.forEach((key, controller) {
        customData[key] = controller.text;
      });
      
      // Add signature data if available
      if (_signatureBytes != null) {
        customData['has_signature'] = 'true';
      }
      
      // Add buyer name
      if (_buyerNameController.text.isNotEmpty) {
        customData['buyer_name'] = _buyerNameController.text;
      }
      
      // Add image path if selected
      if (_selectedImagePath != null) {
        customData['ticket_image'] = _selectedImagePath!;
        customData['image_position'] = _imagePosition;
        customData['image_size'] = _imageSize.toString();
      }
      
      // Add color scheme selection
      customData['color_scheme'] = _selectedColorScheme;
      
      // Add template style selection
      customData['template_style'] = _selectedTemplateStyle;

      final ticket = await _store.generateTicket(
        templateId: widget.template.id,
        eventName: _eventNameController.text,
        artistName: _artistNameController.text,
        eventDate: _selectedDate,
        venue: _venueController.text,
        ticketType: _ticketTypeController.text,
        price: double.tryParse(_priceController.text) ?? 0,
        createdBy: 'user123', // Replace with actual user ID
        customData: customData,
      );

      // Save current values as defaults for future use
      await _saveEventDefaults();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => _buildSuccessDialog(ticket),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Widget _buildSuccessDialog(GeneratedTicket ticket) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1628),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.green, width: 2),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Ticket Generated Successfully!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Serial: ${ticket.serialNumber}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 24),
              
              // Modern Ticket Preview - Properly Scaled and Capturable
              RepaintBoundary(
                key: _ticketKey,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.85,
                  ),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ModernTicketWidget(
                        ticket: ticket,
                        showStub: false,
                        width: 600,
                        signatureBytes: _signatureBytes,
                        imagePath: _selectedImagePath,
                        imagePosition: _imagePosition,
                        imageSize: _imageSize,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openNfcShareSheet(ticket),
                    icon: const Icon(Icons.nfc),
                    label: const Text('NFT Tag Transfer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _downloadTicket(ticket),
                    icon: const Icon(Icons.download),
                    label: const Text('Download Ticket'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Reset form for next ticket
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Another'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.template.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNfcShareSheet(GeneratedTicket ticket) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'NFT Tag Transfer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.qr_code_2, color: Colors.white70),
                  title: const Text(
                    'Share Ticket Metadata',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Writes secure ticket details for instant scan on other devices.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _shareTicketMetadataNfc(ticket);
                  },
                ),
                const Divider(color: Colors.white12, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.image, color: Colors.white70),
                  title: const Text(
                    'Share Ticket Snapshot',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Transfers a PNG preview that nearby phones can save.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _shareTicketImageNfc();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareTicketMetadataNfc(GeneratedTicket ticket) async {
    final payload = <String, dynamic>{
      'type': 'ngmy_ticket',
      'serialNumber': ticket.serialNumber,
      'eventName': ticket.eventName,
      'artistName': ticket.artistName,
      'eventDate': ticket.eventDate.toIso8601String(),
      'venue': ticket.venue,
      'ticketType': ticket.ticketType,
      'price': ticket.price,
      'createdAt': ticket.createdAt.toIso8601String(),
      'qrCodeData': ticket.qrCodeData,
      'customData': ticket.customData,
    };

    final encoded = utf8.encode(jsonEncode(payload));
    await _startNfcWrite(
      Uint8List.fromList(encoded),
      mimeType: 'application/json',
      successMessage: 'Ticket metadata transferred. Ask the recipient to scan now.',
    );
  }

  Future<void> _shareTicketImageNfc() async {
    final bytes = await _captureTicketPreviewBytes();
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket preview not ready. Try again after it finishes rendering.'),
          ),
        );
      }
      return;
    }

    await _startNfcWrite(
      bytes,
      mimeType: 'image/png',
      successMessage: 'Ticket image handed off. The recipient can save it instantly.',
    );
  }

  Future<void> _startNfcWrite(
    Uint8List payload, {
    required String mimeType,
    required String successMessage,
  }) async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      if (availability != NfcAvailability.enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('NFC is not available on this device.'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hold your phone near the recipient to transfer via NFT tag...'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      await NfcManager.instance.startSession(
        pollingOptions: const {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (tag) async {
        try {
          final record = NdefRecord(
            typeNameFormat: TypeNameFormat.media,
            type: Uint8List.fromList(utf8.encode(mimeType)),
            identifier: Uint8List(0),
            payload: payload,
          );
          final message = NdefMessage(records: [record]);

          switch (defaultTargetPlatform) {
            case TargetPlatform.android:
              final ndef = android_ndef.NdefAndroid.from(tag);
              if (ndef == null) {
                await NfcManager.instance
                    .stopSession(errorMessageIos: 'Incompatible NFC tag');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tag is not NDEF compatible.')),
                  );
                }
                return;
              }

              if (!ndef.isWritable) {
                await NfcManager.instance
                    .stopSession(errorMessageIos: 'Tag is read-only');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('This tag cannot be written to.')),
                  );
                }
                return;
              }

              final estimatedSize = payload.length + 10;
              if (ndef.maxSize > 0 && estimatedSize > ndef.maxSize) {
                await NfcManager.instance
                    .stopSession(errorMessageIos: 'Tag capacity too small');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tag capacity too small (needs ~$estimatedSize bytes).'),
                    ),
                  );
                }
                return;
              }

              await ndef.writeNdefMessage(message);
              break;

            case TargetPlatform.iOS:
              final ndef = ios_ndef.NdefIos.from(tag);
              if (ndef == null) {
                await NfcManager.instance
                    .stopSession(errorMessageIos: 'Incompatible NFC tag');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tag is not NDEF compatible.')),
                  );
                }
                return;
              }

              final status = await ndef.queryNdefStatus();
              if (status.status == ios_ndef.NdefStatusIos.notSupported) {
                await NfcManager.instance
                    .stopSession(errorMessageIos: 'Tag not supported');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('This tag cannot store tickets.')),
                  );
                }
                return;
              }

              if (status.status == ios_ndef.NdefStatusIos.readOnly) {
                await NfcManager.instance
                    .stopSession(errorMessageIos: 'Tag is read-only');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('This tag is locked and cannot be written.')),
                  );
                }
                return;
              }

              if (status.capacity > 0 && payload.length > status.capacity) {
                await NfcManager.instance
                    .stopSession(errorMessageIos: 'Tag capacity too small');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tag capacity too small (needs ~${payload.length} bytes).'),
                    ),
                  );
                }
                return;
              }

              await ndef.writeNdef(message);
              break;

            default:
              await NfcManager.instance
                  .stopSession(errorMessageIos: 'Platform not supported');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('NFC writing is not supported on this platform.')),
                );
              }
              return;
          }

          await NfcManager.instance.stopSession(alertMessageIos: 'Ticket shared');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(successMessage)),
            );
          }
        } catch (e) {
          await NfcManager.instance.stopSession(errorMessageIos: 'Transfer failed');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Transfer failed: $e')),
            );
          }
        }
        },
      );
    } catch (e) {
      await NfcManager.instance.stopSession().catchError((_) {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('NFC session error: $e')),
        );
      }
    }
  }

  Future<Uint8List?> _captureTicketPreviewBytes() async {
    final boundary = _ticketKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      return null;
    }

    final image = await boundary.toImage(pixelRatio: 4.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _downloadTicket(GeneratedTicket ticket) async {
    try {
      // Find the RepaintBoundary
      final boundary = _ticketKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not find ticket widget');
      }

      // Capture the widget as a high-resolution image (8.0 pixel ratio for ultra-clear quality)
      final image = await boundary.toImage(pixelRatio: 8.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Failed to convert ticket to image');
      }

      final pngBytes = byteData.buffer.asUint8List();

      // Get temporary directory to save the file
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'ticket_${ticket.serialNumber}_$timestamp.png';
      final file = File('${directory.path}/$fileName');
      
      // Write the file
      await file.writeAsBytes(pngBytes);

      // Share the file (this allows user to save to gallery or share)
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My Ticket - ${ticket.eventName}',
        subject: ticket.serialNumber,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎫 Ticket ready to save or share!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Edit ${widget.template.name}',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05), // 5% of screen width
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview Card
              _buildTicketPreview(),
              
              SizedBox(height: MediaQuery.of(context).size.height * 0.04),
              
              // Form Fields
              _buildTextField(
                controller: _eventNameController,
                label: 'Event Name',
                icon: Icons.event,
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.02),
              
              _buildTextField(
                controller: _artistNameController,
                label: 'Artist/Performer Name',
                icon: Icons.person,
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.02),
              
              _buildTextField(
                controller: _venueController,
                label: 'Venue',
                icon: Icons.location_on,
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.02),
              
              _buildDatePicker(),
              SizedBox(height: MediaQuery.of(context).size.height * 0.02),
              
              _buildTextField(
                controller: _ticketTypeController,
                label: 'Ticket Type',
                icon: Icons.confirmation_number,
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.02),
              
              _buildTextField(
                controller: _priceController,
                label: 'Price',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
              ),
              
              SizedBox(height: MediaQuery.of(context).size.height * 0.02),
              
              _buildTextField(
                controller: _buyerNameController,
                label: 'Buyer Name',
                icon: Icons.person_outline,
              ),
              
              SizedBox(height: MediaQuery.of(context).size.height * 0.04),
              
              // Optional Image Upload Section
              Text(
                'Ticket Photo (Optional)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: MediaQuery.of(context).size.width * 0.045, // 4.5% of screen width
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
              Text(
                'Add a photo that will blend with the ticket background',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.6 * 255).round()),
                  fontSize: MediaQuery.of(context).size.width * 0.032, // 3.2% of screen width
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.015),
              
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.22, // 22% of screen height
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.05 * 255).round()),
                    borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.04),
                    border: Border.all(
                      color: widget.template.primaryColor.withAlpha((0.5 * 255).round()),
                      width: MediaQuery.of(context).size.width * 0.005, // 0.5% of screen width
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _selectedImagePath != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                File(_selectedImagePath!),
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                                ),
                                onPressed: () {
                                  setState(() => _selectedImagePath = null);
                                },
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: MediaQuery.of(context).size.width * 0.12, // 12% of screen width
                              color: widget.template.primaryColor.withAlpha((0.7 * 255).round()),
                            ),
                            SizedBox(height: MediaQuery.of(context).size.height * 0.015), // 1.5% of screen height
                            Text(
                              'Tap to add photo',
                              style: TextStyle(
                                color: Colors.white.withAlpha((0.7 * 255).round()),
                                fontSize: MediaQuery.of(context).size.width * 0.035, // 3.5% of screen width
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: MediaQuery.of(context).size.height * 0.005), // 0.5% of screen height
                            Text(
                              'Background will be removed automatically',
                              style: TextStyle(
                                color: Colors.white.withAlpha((0.5 * 255).round()),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              // Image Position & Size Controls (only show when image selected)
              if (_selectedImagePath != null) ...[
                const SizedBox(height: 16),
                
                // Position Selector
                const Text(
                  'Photo Position',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPositionChip('Top Left', 'top-left'),
                    _buildPositionChip('Top Right', 'top-right'),
                    _buildPositionChip('Center', 'center'),
                    _buildPositionChip('Bottom Left', 'bottom-left'),
                    _buildPositionChip('Bottom Right', 'bottom-right'),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Size Slider
                const Text(
                  'Photo Size',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Small', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _imageSize,
                        min: 120,
                        max: 300,
                        divisions: 18,
                        activeColor: widget.template.primaryColor,
                        label: '${_imageSize.round()}px',
                        onChanged: (value) {
                          setState(() => _imageSize = value);
                        },
                      ),
                    ),
                    const Text('Large', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
              
              // Color Scheme Selector (always visible)
              SizedBox(height: MediaQuery.of(context).size.height * 0.025), // 2.5% of screen height
              Text(
                'Ticket Color Theme',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: MediaQuery.of(context).size.width * 0.04, // 4% of screen width
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // First row - 5 colors
              Row(
                children: [
                  Expanded(child: _buildColorChip('Classic', 'classic', const Color(0xFFFDA08E), const Color(0xFFBB9FD6))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildColorChip('Golden', 'golden', const Color(0xFFFFD700), const Color(0xFFFFA500))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildColorChip('Purple', 'purple', const Color(0xFF8B5CF6), const Color(0xFFEC4899))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildColorChip('Blue', 'blue', const Color(0xFF3B82F6), const Color(0xFF1E40AF))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildColorChip('Ocean', 'ocean', const Color(0xFF0EA5E9), const Color(0xFF0284C7))),
                ],
              ),
              const SizedBox(height: 10),
              // Second row - 5 colors
              Row(
                children: [
                  Expanded(child: _buildColorChip('Forest', 'forest', const Color(0xFF059669), const Color(0xFF047857))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildColorChip('Sunset', 'sunset', const Color(0xFFFF7849), const Color(0xFFEF4444))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildColorChip('Midnight', 'midnight', const Color(0xFF1E1B4B), const Color(0xFF312E81))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildColorChip('Rose', 'rose', const Color(0xFFE11D48), const Color(0xFFBE185D))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildColorChip('Silver', 'silver', const Color(0xFF6B7280), const Color(0xFF374151))),
                ],
              ),
              
              // Template Style Selector
              const SizedBox(height: 20),
              Text(
                'Ticket Template Style',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: MediaQuery.of(context).size.width * 0.04, // 4% of screen width
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // First row - 3 templates
              Row(
                children: [
                  Expanded(child: _buildTemplateChip('Classic', 'classic', Icons.receipt_long, 'Traditional gradient layout')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTemplateChip('Modern', 'modern', Icons.view_sidebar, 'Side-by-side content')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTemplateChip('Vintage', 'vintage', Icons.auto_awesome, 'Decorative borders')),
                ],
              ),
              const SizedBox(height: 10),
              // Second row - 3 templates  
              Row(
                children: [
                  Expanded(child: _buildTemplateChip('Minimal', 'minimal', Icons.minimize, 'Clean and simple')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTemplateChip('Concert', 'concert', Icons.music_note, 'Poster-style layout')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTemplateChip('Premium', 'premium', Icons.star, 'Luxury VIP design')),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Custom Fields
              if (widget.template.customFields.isNotEmpty) ...[
                Text(
                  'Additional Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: MediaQuery.of(context).size.width * 0.045, // 4.5% of screen width
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...widget.template.customFields.map((field) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildTextField(
                      controller: _customFieldControllers[field]!,
                      label: field,
                      icon: Icons.info_outline,
                    ),
                  );
                }),
              ],
              
              const SizedBox(height: 32),
              
              // Signature Section
              Row(
                children: [
                  Text(
                    'Your Signature',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: MediaQuery.of(context).size.width * 0.045, // 4.5% of screen width
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_signatureBytes != null) ...[
                    SizedBox(width: MediaQuery.of(context).size.width * 0.03), // 3% of screen width
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha((0.2 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 14),
                          const SizedBox(width: 4),
                          const Text(
                            'Saved',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: MediaQuery.of(context).size.height * 0.25, // 25% of screen height
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.04),
                  border: Border.all(
                    color: widget.template.primaryColor,
                    width: MediaQuery.of(context).size.width * 0.005, // 0.5% of screen width
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_signatureBytes != null)
                            TextButton.icon(
                              onPressed: () async {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.remove('saved_signature');
                                _signatureController.clear();
                                setState(() => _signatureBytes = null);
                              },
                              icon: const Icon(Icons.delete_forever, size: 18),
                              label: const Text('Delete Saved'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.orange,
                              ),
                            ),
                          if (_signatureBytes != null)
                            const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () {
                              _signatureController.clear();
                              setState(() => _signatureBytes = null);
                            },
                            icon: const Icon(Icons.clear, size: 18),
                            label: const Text('Clear Canvas'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Generate Button
              SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.07, // 7% of screen height
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _generateTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.template.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.04),
                    ),
                    elevation: 0,
                  ),
                  child: _isGenerating
                      ? SizedBox(
                          height: MediaQuery.of(context).size.width * 0.06, // 6% of screen width
                          width: MediaQuery.of(context).size.width * 0.06, // 6% of screen width
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Generate Ticket',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width * 0.04, // 4% of screen width
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketPreview() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      height: screenHeight * 0.25, // 25% of screen height
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(screenWidth * 0.05), // 5% of screen width
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.template.primaryColor,
            widget.template.accentColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: widget.template.primaryColor.withAlpha((0.3 * 255).round()),
            blurRadius: screenWidth * 0.05,
            offset: Offset(0, screenHeight * 0.01),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: screenWidth * 0.12, // 12% of screen width
              color: Colors.white.withAlpha((0.9 * 255).round()),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              'Ticket Preview',
              style: TextStyle(
                color: Colors.white,
                fontSize: screenWidth * 0.04, // 4% of screen width
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
  fillColor: Colors.white.withAlpha((0.05 * 255).round()),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withAlpha((0.1 * 255).round())),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withAlpha((0.1 * 255).round())),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.template.primaryColor, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field is required';
        }
        return null;
      },
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
        );
        if (date != null) {
          setState(() => _selectedDate = date);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.05 * 255).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha((0.1 * 255).round())),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Event Date',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: MediaQuery.of(context).size.width * 0.04, // 4% of screen width
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPositionChip(String label, String position) {
    final isSelected = _imagePosition == position;
    return GestureDetector(
      onTap: () {
        setState(() => _imagePosition = position);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? widget.template.primaryColor 
              : Colors.white.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? widget.template.primaryColor 
                : Colors.white.withAlpha((0.3 * 255).round()),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  Widget _buildColorChip(String label, String scheme, Color primary, Color secondary) {
    final isSelected = _selectedColorScheme == scheme;
    
    // Adjust font size based on label length and screen size
    double fontSize = MediaQuery.of(context).size.width * 0.03; // 3% of screen width
    if (label.length > 7) {
      fontSize = MediaQuery.of(context).size.width * 0.025; // 2.5% of screen width
    } else if (label.length > 5) {
      fontSize = MediaQuery.of(context).size.width * 0.028; // 2.8% of screen width
    }
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedColorScheme = scheme);
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.18, // 18% of screen width
        height: MediaQuery.of(context).size.height * 0.045, // 4.5% of screen height
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.02, // 2% of screen width
          vertical: MediaQuery.of(context).size.height * 0.008, // 0.8% of screen height
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.04),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withAlpha((0.3 * 255).round()),
            width: isSelected ? MediaQuery.of(context).size.width * 0.008 : MediaQuery.of(context).size.width * 0.003, // 0.8% or 0.3% of screen width
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: primary.withAlpha((0.4 * 255).round()),
              blurRadius: MediaQuery.of(context).size.width * 0.02, // 2% of screen width
              spreadRadius: MediaQuery.of(context).size.width * 0.0025, // 0.25% of screen width
            ),
          ] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              shadows: [
                Shadow(
                  color: Colors.black.withAlpha((0.7 * 255).round()),
                  blurRadius: MediaQuery.of(context).size.width * 0.005, // 0.5% of screen width
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
  
  Widget _buildTemplateChip(String label, String style, IconData icon, String description) {
    final isSelected = _selectedTemplateStyle == style;
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTemplateStyle = style);
      },
      child: Container(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03), // 3% of screen width
        decoration: BoxDecoration(
          color: isSelected 
              ? widget.template.primaryColor.withAlpha((0.2 * 255).round()) 
              : Colors.white.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03),
          border: Border.all(
            color: isSelected 
                ? widget.template.primaryColor 
                : Colors.white.withAlpha((0.3 * 255).round()),
            width: isSelected ? MediaQuery.of(context).size.width * 0.005 : MediaQuery.of(context).size.width * 0.0025, // 0.5% or 0.25% of screen width
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? widget.template.primaryColor : Colors.white70,
              size: MediaQuery.of(context).size.width * 0.06, // 6% of screen width
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01), // 1% of screen height
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: MediaQuery.of(context).size.width * 0.032, // 3.2% of screen width
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withAlpha((0.5 * 255).round()),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
