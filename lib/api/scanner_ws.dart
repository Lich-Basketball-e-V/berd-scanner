import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'scanner_api.dart';

String scannerWsUrlFromBookingBase(String bookingBase) {
  var base = bookingBase.replaceAll(RegExp(r'/+$'), '');
  if (base.startsWith('https://')) {
    base = 'wss://${base.substring(8)}';
  } else if (base.startsWith('http://')) {
    base = 'ws://${base.substring(7)}';
  }
  return '$base/ws/scanner';
}

class ScannerWsClient {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  Timer? _pingTimer;
  void Function()? onRevoked;

  bool get isConnected => _channel != null;

  Future<void> connect(String wsUrl, String deviceToken) async {
    await disconnect();
    final uri = Uri.parse(wsUrl).replace(
      queryParameters: {'token': deviceToken},
    );
    _channel = WebSocketChannel.connect(uri);
    _sub = _channel!.stream.listen(
      _onMessage,
      onError: (_) {},
      onDone: () {},
    );
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 40), (_) {
      unawaited(request('scanner.ping', const {}));
    });
    await request('scanner.hello', const {
      'label': 'BERD Empfang',
      'platform': 'android',
      'app_version': '1.2.0',
    });
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(ScannerApiException('Verbindung beendet'));
      }
    }
    _pending.clear();
  }

  void _onMessage(dynamic event) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(event as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final action = json['action']?.toString();
    if (action == 'device.revoked') {
      onRevoked?.call();
      unawaited(disconnect());
      return;
    }
    final id = json['id']?.toString();
    if (id != null && _pending.containsKey(id)) {
      _pending.remove(id)!.complete(json);
    }
  }

  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final ch = _channel;
    if (ch == null) {
      throw ScannerApiException('Keine WebSocket-Verbindung');
    }
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    ch.sink.add(
      jsonEncode({'id': id, 'action': action, 'payload': payload}),
    );
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _pending.remove(id);
        throw ScannerApiException('Zeitüberschreitung');
      },
    );
  }

  Future<VerifyResult> verify(String rawCode) async {
    final json = await request('scanner.verify', {
      'token': rawCode,
      'scan': rawCode,
    });
    if (json['success'] != true) {
      throw ScannerApiException(
        json['message']?.toString() ?? 'Prüfung fehlgeschlagen',
      );
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return VerifyResult.fromJson(data);
    }
    return VerifyResult.fromJson(json);
  }
}