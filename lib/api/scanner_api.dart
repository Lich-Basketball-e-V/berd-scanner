import 'dart:convert';

import 'package:http/http.dart' as http;

class ScannerApiException implements Exception {
  ScannerApiException(this.message, {this.status = 0});
  final String message;
  final int status;
  @override
  String toString() => message;
}

class ScannerApi {
  ScannerApi(this.baseUrl);

  final String baseUrl;

  Uri _uri(String path) {
    final root = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$root$path');
  }

  Future<String> pair(String rawCode) async {
    final res = await http.post(
      _uri('/api/booking-scanner/pair'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'code': rawCode}),
    );
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } on FormatException {
      throw ScannerApiException('Ungültige Server-Antwort', status: res.statusCode);
    }
    if (res.statusCode < 200 || res.statusCode >= 300 || json['ok'] != true) {
      throw ScannerApiException(
        (json['error'] ?? json['message'] ?? 'Koppeln fehlgeschlagen').toString(),
        status: res.statusCode,
      );
    }
    final token = json['device_token']?.toString() ?? '';
    if (token.isEmpty) {
      throw ScannerApiException('Kein Geräte-Token erhalten');
    }
    return token;
  }

  Future<VerifyResult> verify(String deviceToken, String rawCode) async {
    final res = await http.post(
      _uri('/api/booking-scanner/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $deviceToken',
      },
      body: jsonEncode({
        'token': rawCode,
        'payload': rawCode,
        'scan': rawCode,
        'redeem': true,
      }),
    );
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } on FormatException {
      throw ScannerApiException('Ungültige Server-Antwort', status: res.statusCode);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ScannerApiException(
        (json['error'] ?? json['message'] ?? 'Prüfung fehlgeschlagen').toString(),
        status: res.statusCode,
      );
    }
    return VerifyResult.fromJson(json);
  }
}

class VerifyResult {
  VerifyResult({
    required this.valid,
    required this.ok,
    required this.message,
    this.booking,
    this.redeemed = false,
    this.alreadyRedeemed = false,
    this.checkedInAt,
  });

  final bool valid;
  final bool ok;
  final String message;
  final Map<String, dynamic>? booking;
  final bool redeemed;
  final bool alreadyRedeemed;
  final String? checkedInAt;

  factory VerifyResult.fromJson(Map<String, dynamic> json) {
    return VerifyResult(
      valid: json['valid'] == true,
      ok: json['ok'] == true,
      message: json['message']?.toString() ?? '',
      booking: json['booking'] is Map<String, dynamic>
          ? json['booking'] as Map<String, dynamic>
          : null,
      redeemed: json['redeemed'] == true,
      alreadyRedeemed: json['already_redeemed'] == true,
      checkedInAt: json['checked_in_at']?.toString(),
    );
  }

  bool get admissionGranted => valid && ok;
}