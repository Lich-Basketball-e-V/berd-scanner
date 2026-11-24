import 'package:shared_preferences/shared_preferences.dart';

const pairPrefix = 'LBB-SCAN-PAIR:';
const checkInPrefix = 'LBB-BERD:';
const deviceTokenKey = 'lbb_berd_scanner_device_token';
const bookingBaseUrlKey = 'lbb_berd_scanner_booking_base_url';

/// Beim Build überschreiben: --dart-define=BOOKING_BASE_URL=https://book.example.de
const defaultBookingBaseUrl = String.fromEnvironment(
  'BOOKING_BASE_URL',
  defaultValue: 'https://book.lbb.cylone.de',
);

Future<String> loadBookingBaseUrl() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(bookingBaseUrlKey)?.trim();
  if (stored != null && stored.isNotEmpty) {
    return stored.replaceAll(RegExp(r'/+$'), '');
  }
  return defaultBookingBaseUrl.replaceAll(RegExp(r'/+$'), '');
}

Future<void> saveBookingBaseUrl(String url) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    bookingBaseUrlKey,
    url.trim().replaceAll(RegExp(r'/+$'), ''),
  );
}

Future<String?> loadDeviceToken() async {
  final prefs = await SharedPreferences.getInstance();
  final t = prefs.getString(deviceTokenKey)?.trim();
  return t != null && t.isNotEmpty ? t : null;
}

Future<void> saveDeviceToken(String? token) async {
  final prefs = await SharedPreferences.getInstance();
  if (token == null || token.isEmpty) {
    await prefs.remove(deviceTokenKey);
  } else {
    await prefs.setString(deviceTokenKey, token);
  }
}

String normalizePairCode(String raw) {
  var s = raw.trim();
  if (s.startsWith(pairPrefix)) {
    s = s.substring(pairPrefix.length).trim();
  }
  return s;
}

String normalizeCheckInCode(String raw) {
  var s = raw.trim();
  if (s.startsWith(checkInPrefix)) {
    s = s.substring(checkInPrefix.length).trim();
  }
  return s;
}