import 'package:shared_preferences/shared_preferences.dart';

class CashTagStorage {
  CashTagStorage._();

  static String _buildKey(String scope, String? identifier) {
    final normalizedScope = scope.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final normalizedIdentifier = (identifier ?? 'default')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'cash_tag_${normalizedScope}_$normalizedIdentifier';
  }

  static Future<String?> load({required String scope, String? identifier}) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_buildKey(scope, identifier));
    if (stored == null) {
      return null;
    }
    final trimmed = stored.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Future<void> save(String cashTag, {required String scope, String? identifier}) async {
    final trimmed = cashTag.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_buildKey(scope, identifier), trimmed);
  }

  static Future<void> clear({required String scope, String? identifier}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_buildKey(scope, identifier));
  }
}
