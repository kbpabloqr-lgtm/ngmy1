import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../models/ticket_models.dart';

class TicketDataStore extends ChangeNotifier {
  static final TicketDataStore _instance = TicketDataStore._internal();
  static TicketDataStore get instance => _instance;

  TicketDataStore._internal() {
    _loadFromStorage();
  }

  List<CodeApplication> _codeApplications = [];
  List<AccessCode> _accessCodes = [];
  List<GeneratedTicket> _tickets = [];
  List<TicketTemplate> _templates = [];

  List<CodeApplication> get codeApplications => List.unmodifiable(_codeApplications);
  List<AccessCode> get accessCodes => List.unmodifiable(_accessCodes);
  List<GeneratedTicket> get tickets => List.unmodifiable(_tickets);
  List<TicketTemplate> get templates => List.unmodifiable(_templates);

  int get pendingApplicationsCount =>
      _codeApplications.where((app) => app.status == CodeApplicationStatus.pending).length;

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();

    // Load applications
    final appsJson = prefs.getString('ticket_applications');
    if (appsJson != null) {
      final List<dynamic> appsList = jsonDecode(appsJson);
      _codeApplications = appsList.map((json) => CodeApplication.fromJson(json)).toList();
    }

    // Load access codes
    final codesJson = prefs.getString('ticket_access_codes');
    if (codesJson != null) {
      final List<dynamic> codesList = jsonDecode(codesJson);
      _accessCodes = codesList.map((json) => AccessCode.fromJson(json)).toList();
    }

    // Load tickets
    final ticketsJson = prefs.getString('ticket_generated');
    if (ticketsJson != null) {
      final List<dynamic> ticketsList = jsonDecode(ticketsJson);
      _tickets = ticketsList.map((json) => GeneratedTicket.fromJson(json)).toList();
    }

    _initializeTemplates();
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ticket_applications', jsonEncode(_codeApplications.map((e) => e.toJson()).toList()));
    await prefs.setString('ticket_access_codes', jsonEncode(_accessCodes.map((e) => e.toJson()).toList()));
    await prefs.setString('ticket_generated', jsonEncode(_tickets.map((e) => e.toJson()).toList()));
  }

  void _initializeTemplates() {
    if (_templates.isNotEmpty) return;

    _templates = [
      TicketTemplate(
        id: 'tpl_concert_1',
        name: 'Concert VIP',
        type: TicketTemplateType.concert,
        primaryColor: const Color(0xFFFF6B9D),
        accentColor: const Color(0xFFFFC371),
        backgroundImage: 'concert_bg',
        customFields: ['Seat Number', 'Gate'],
      ),
      TicketTemplate(
        id: 'tpl_concert_2',
        name: 'Concert General',
        type: TicketTemplateType.concert,
        primaryColor: const Color(0xFF667EEA),
        accentColor: const Color(0xFF764BA2),
        backgroundImage: 'concert_general',
        customFields: ['Section'],
      ),
      TicketTemplate(
        id: 'tpl_festival_1',
        name: 'Festival Pass',
        type: TicketTemplateType.festival,
        primaryColor: const Color(0xFFF093FB),
        accentColor: const Color(0xFFF5576C),
        backgroundImage: 'festival_bg',
        customFields: ['Day Pass', 'Camping'],
      ),
      TicketTemplate(
        id: 'tpl_sports_1',
        name: 'Sports Event',
        type: TicketTemplateType.sports,
        primaryColor: const Color(0xFF4FACFE),
        accentColor: const Color(0xFF00F2FE),
        backgroundImage: 'sports_bg',
        customFields: ['Section', 'Row', 'Seat'],
      ),
      TicketTemplate(
        id: 'tpl_vip_1',
        name: 'VIP Backstage',
        type: TicketTemplateType.backstage,
        primaryColor: const Color(0xFFFFD700),
        accentColor: const Color(0xFFFFA500),
        backgroundImage: 'vip_backstage',
        customFields: ['Access Level', 'Time Slot'],
      ),
      TicketTemplate(
        id: 'tpl_theater_1',
        name: 'Theater Show',
        type: TicketTemplateType.theater,
        primaryColor: const Color(0xFFB06AB3),
        accentColor: const Color(0xFF4568DC),
        backgroundImage: 'theater_bg',
        customFields: ['Balcony', 'Seat Number'],
      ),
      TicketTemplate(
        id: 'tpl_conference_1',
        name: 'Conference Pass',
        type: TicketTemplateType.conference,
        primaryColor: const Color(0xFF38EF7D),
        accentColor: const Color(0xFF11998E),
        backgroundImage: 'conference_bg',
        customFields: ['Badge Type', 'Workshop Access'],
      ),
    ];
  }

  // Generate cryptographically secure serial number
  String _generateSerialNumber() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = List.generate(8, (_) => random.nextInt(256));
    final combined = '$timestamp-${randomBytes.join()}';
    final hash = sha256.convert(utf8.encode(combined)).toString();
    return 'TKT-${hash.substring(0, 8).toUpperCase()}-${hash.substring(8, 16).toUpperCase()}';
  }

  // Generate secure access code
  String _generateAccessCode() {
    final random = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Removed ambiguous chars
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // Submit code application
  Future<void> submitCodeApplication({
    required String userId,
    required String userName,
    required String userEmail,
    required String reason,
  }) async {
    final application = CodeApplication(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      reason: reason,
      appliedAt: DateTime.now(),
    );

    _codeApplications.add(application);
    await _saveToStorage();
    notifyListeners();
  }

  // Approve application and issue code
  Future<void> approveApplication(String applicationId, int expiryDays) async {
    final app = _codeApplications.firstWhere((a) => a.id == applicationId);
    final code = _generateAccessCode();
    final expiryDate = DateTime.now().add(Duration(days: expiryDays));

    app.status = CodeApplicationStatus.approved;
    app.approvedCode = code;
    app.codeExpiryDate = expiryDate;

    final accessCode = AccessCode(
      code: code,
      userId: app.userId,
      issuedAt: DateTime.now(),
      expiryDate: expiryDate,
    );

    _accessCodes.add(accessCode);
    await _saveToStorage();
    notifyListeners();
  }

  // Reject application (removes it completely)
  Future<void> rejectApplication(String applicationId, String reason) async {
    // Remove the application completely instead of just marking as rejected
    _codeApplications.removeWhere((a) => a.id == applicationId);
    await _saveToStorage();
    notifyListeners();
  }

  // Verify access code (reusable until expiry)
  bool verifyAccessCode(String code, String userId) {
    try {
      final accessCode = _accessCodes.firstWhere(
        (ac) => ac.code == code && ac.userId == userId,
      );
      return accessCode.isValid;
    } catch (e) {
      return false;
    }
  }

  // Check if user has active code
  bool hasActiveCode(String userId) {
    return _accessCodes.any(
      (ac) => ac.userId == userId && ac.isValid,
    );
  }

  // Get user's active codes
  List<AccessCode> getUserActiveCodes(String userId) {
    return _accessCodes.where((ac) => ac.userId == userId && ac.isValid).toList();
  }
  
  // Edit code expiry (admin function)
  Future<void> editCodeExpiry(String code, int additionalDays) async {
    final index = _accessCodes.indexWhere((ac) => ac.code == code);
    if (index == -1) throw Exception('Code not found');
    
    final oldCode = _accessCodes[index];
    final newExpiryDate = oldCode.expiryDate.add(Duration(days: additionalDays));
    
    // Create new AccessCode with updated expiry
    _accessCodes[index] = AccessCode(
      code: oldCode.code,
      userId: oldCode.userId,
      issuedAt: oldCode.issuedAt,
      expiryDate: newExpiryDate,
      isUsed: oldCode.isUsed,
      isRevoked: oldCode.isRevoked,
    );
    
    // Also update in applications if it exists
    final appIndex = _codeApplications.indexWhere((a) => a.approvedCode == code);
    if (appIndex != -1) {
      _codeApplications[appIndex].codeExpiryDate = newExpiryDate;
    }
    
    await _saveToStorage();
    notifyListeners();
  }
  
  // Delete access code (admin function)
  Future<void> deleteAccessCode(String code) async {
    // Remove from access codes list
    _accessCodes.removeWhere((ac) => ac.code == code);
    
    // Also completely remove the application that had this code
    _codeApplications.removeWhere((a) => a.approvedCode == code);
    
    await _saveToStorage();
    notifyListeners();
  }

  // Generate ticket
  Future<GeneratedTicket> generateTicket({
    required String templateId,
    required String eventName,
    required String artistName,
    required DateTime eventDate,
    required String venue,
    required String ticketType,
    required double price,
    required String createdBy,
    Map<String, String>? customData,
  }) async {
    final serialNumber = _generateSerialNumber();
    final qrData = jsonEncode({
      'serial': serialNumber,
      'event': eventName,
      'date': eventDate.toIso8601String(),
      'type': ticketType,
    });

    final ticket = GeneratedTicket(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      serialNumber: serialNumber,
      eventName: eventName,
      artistName: artistName,
      eventDate: eventDate,
      venue: venue,
      ticketType: ticketType,
      price: price,
      templateId: templateId,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      qrCodeData: qrData,
      customData: customData ?? {},
    );

    _tickets.add(ticket);
    await _saveToStorage();
    notifyListeners();
    return ticket;
  }

  // Get tickets by creator
  List<GeneratedTicket> getTicketsByCreator(String userId) {
    return _tickets.where((t) => t.createdBy == userId).toList();
  }

  // Validate ticket by serial number
  bool validateTicket(String serialNumber) {
    try {
      final ticket = _tickets.firstWhere((t) => t.serialNumber == serialNumber);
      return ticket.isValid && ticket.eventDate.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  // Revoke access code
  Future<void> revokeAccessCode(String code) async {
    final accessCode = _accessCodes.firstWhere((ac) => ac.code == code);
    accessCode.isRevoked = true;
    await _saveToStorage();
    notifyListeners();
  }
}
