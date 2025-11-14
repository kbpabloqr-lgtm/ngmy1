import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage persistent storage of default event details
/// so users don't have to re-enter event name, venue, and artist/performer
class EventDefaultsService {
  static const String _eventNameKey = 'default_event_name';
  static const String _venueKey = 'default_venue';
  static const String _artistKey = 'default_artist';
  static const String _priceKey = 'default_price';
  static const String _ticketTypeKey = 'default_ticket_type';

  /// Save default event name
  static Future<void> saveEventName(String eventName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eventNameKey, eventName);
  }

  /// Get saved event name
  static Future<String?> getEventName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_eventNameKey);
  }

  /// Save default venue/address
  static Future<void> saveVenue(String venue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_venueKey, venue);
  }

  /// Get saved venue/address
  static Future<String?> getVenue() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_venueKey);
  }

  /// Save default artist/performer name
  static Future<void> saveArtist(String artist) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_artistKey, artist);
  }

  /// Get saved artist/performer name
  static Future<String?> getArtist() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_artistKey);
  }

  /// Save default price
  static Future<void> savePrice(double price) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_priceKey, price);
  }

  /// Get saved price
  static Future<double?> getPrice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_priceKey);
  }

  /// Save default ticket type
  static Future<void> saveTicketType(String ticketType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ticketTypeKey, ticketType);
  }

  /// Get saved ticket type
  static Future<String?> getTicketType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ticketTypeKey);
  }

  /// Save all defaults at once
  static Future<void> saveAllDefaults({
    String? eventName,
    String? venue,
    String? artist,
    double? price,
    String? ticketType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (eventName != null && eventName.isNotEmpty) {
      await prefs.setString(_eventNameKey, eventName);
    }
    if (venue != null && venue.isNotEmpty) {
      await prefs.setString(_venueKey, venue);
    }
    if (artist != null && artist.isNotEmpty) {
      await prefs.setString(_artistKey, artist);
    }
    if (price != null && price > 0) {
      await prefs.setDouble(_priceKey, price);
    }
    if (ticketType != null && ticketType.isNotEmpty) {
      await prefs.setString(_ticketTypeKey, ticketType);
    }
  }

  /// Load all defaults
  static Future<Map<String, dynamic>> getAllDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'eventName': prefs.getString(_eventNameKey),
      'venue': prefs.getString(_venueKey),
      'artist': prefs.getString(_artistKey),
      'price': prefs.getDouble(_priceKey),
      'ticketType': prefs.getString(_ticketTypeKey),
    };
  }

  /// Clear all defaults
  static Future<void> clearAllDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eventNameKey);
    await prefs.remove(_venueKey);
    await prefs.remove(_artistKey);
    await prefs.remove(_priceKey);
    await prefs.remove(_ticketTypeKey);
  }
}