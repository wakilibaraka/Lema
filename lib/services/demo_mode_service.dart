import 'package:shared_preferences/shared_preferences.dart';

class DemoModeService {
  static const String _keyEnabled = 'lema_demo_mode';
  static const String _keyMockToken = 'lema_mock_token';

  static bool _enabled = false;
  static bool get isEnabled => _enabled;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keyEnabled) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
  }

  static Future<void> saveMockToken(String platform, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_keyMockToken}_$platform', token);
  }

  static Future<String?> getMockToken(String platform) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_keyMockToken}_$platform');
  }

  static Map<String, dynamic> getMockAnalytics() => {
        'likes': 1247,
        'views': 15230,
        'comments': 89,
        'shares': 34,
        'engagementRate': 8.9,
      };

  static List<Map<String, dynamic>> getMockQueue() => [
        {
          'id': 'demo-1',
          'platform': 'instagram',
          'status': 'scheduled',
          'scheduledTime': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
          'caption': 'Demo scheduled post for app review walkthrough.',
        },
        {
          'id': 'demo-2',
          'platform': 'tiktok',
          'status': 'published',
          'scheduledTime': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'caption': 'Demo published post showing analytics.',
        },
      ];
}
