import 'package:shared_preferences/shared_preferences.dart';

/// Service to preload critical app data for faster startup
class AppPreloadService {
  static SharedPreferences? _cachedPrefs;
  
  /// Initialize shared preferences early to avoid delays
  static Future<void> initialize() async {
    try {
      _cachedPrefs = await SharedPreferences.getInstance();
    } catch (e) {
      // Handle error silently - app will still work
    }
  }
  
  /// Get cached SharedPreferences instance or create new one
  static Future<SharedPreferences> getPrefs() async {
    return _cachedPrefs ?? await SharedPreferences.getInstance();
  }
  
  /// Preload essential app settings
  static Future<Map<String, dynamic>> preloadEssentialData() async {
    try {
      final prefs = await getPrefs();
      
      return {
        'sliderImages': prefs.getStringList('home_slider_images') ?? <String>[],
        'slideDuration': prefs.getInt('home_slider_duration') ?? 4,
        'wallpaper': prefs.getString('home_wallpaper') ?? 'electric_blue_curves',
        'userName': prefs.getString('growth_user_name') ?? 'NGMY User',
      };
    } catch (e) {
      // Return defaults if loading fails
      return {
        'sliderImages': <String>[],
        'slideDuration': 4,
        'wallpaper': 'electric_blue_curves',
        'userName': 'NGMY User',
      };
    }
  }
}