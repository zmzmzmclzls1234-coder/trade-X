import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _prefCustomBackendKey = 'tradex_custom_backend_url';
  static const String _prefYoutubeApiKey = 'tradex_youtube_api_key';

  // Primary Gemini API Key for direct mobile REST connectivity on Wi-Fi and mobile networks
  static const String geminiApiKey = '';

  // Optional official YouTube Data API v3 key
  static String? _inMemoryYoutubeApiKey;

  static Future<String?> getYoutubeApiKey() async {
    if (_inMemoryYoutubeApiKey != null && _inMemoryYoutubeApiKey!.isNotEmpty) {
      return _inMemoryYoutubeApiKey;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefYoutubeApiKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setYoutubeApiKey(String key) async {
    _inMemoryYoutubeApiKey = key.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (key.trim().isEmpty) {
        await prefs.remove(_prefYoutubeApiKey);
      } else {
        await prefs.setString(_prefYoutubeApiKey, key.trim());
      }
    } catch (_) {}
  }

  // Cloud backend production endpoints
  static const String defaultCloudRunUrl = 'https://ais-dev-sbksx6am6quh4t34yawg5m-624856084147.europe-west1.run.app';
  static const String defaultSharedUrl = 'https://ais-pre-sbksx6am6quh4t34yawg5m-624856084147.europe-west1.run.app';

  static Future<String?> getCustomBackendUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefCustomBackendKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setCustomBackendUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url.trim().isEmpty) {
        await prefs.remove(_prefCustomBackendKey);
      } else {
        await prefs.setString(_prefCustomBackendKey, url.trim());
      }
    } catch (_) {}
  }
}
