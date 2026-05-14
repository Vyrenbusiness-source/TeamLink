// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:convert';

import 'package:desktop_client/services/api_client.dart';
import 'package:desktop_client/services/ws_events.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsClient {
  WsClient._();

  static final WsClient instance = WsClient._();

  String _wsBaseUrl = 'ws://localhost:3000';

  /// Update the WebSocket base URL and force-reconnect if connected.
  void setUrl(String url) {
    if (url == _wsBaseUrl) return;
    _wsBaseUrl = url;
    if (_userId != null || _projectId != null) {
      _subscription?.cancel();
      _subscription = null;
      _channel?.sink.close();
      _channel = null;
      _backoff = _initialBackoff;
      _connect();
    }
  }

  static const Duration _initialBackoff = Duration(milliseconds: 500);
  static const Duration _maxBackoff = Duration(seconds: 30);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Duration _backoff = _initialBackoff;
  bool _disposed = false;
  bool _connecting = false;

  String? _userId;
  String? _projectId;
  final _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _controller.stream;

  void joinUser(String userId) {
    _userId = userId;
    _disposed = false;
    _connect();
  }

  void joinProject(String projectId) {
    _projectId = projectId;
    _disposed = false;
    _connect();
  }

  Uri _buildUri() {
    final token = ApiClient.instance.accessToken;
    final base = _wsBaseUrl;
    if (token != null) {
      return Uri.parse('$base?token=${Uri.encodeComponent(token)}');
    }
    return Uri.parse(base);
  }

  void _connect() {
    if (_disposed) return;
    if (_userId == null && _projectId == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_connecting) return;
    _connecting = true;

    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();

    try {
      _channel = WebSocketChannel.connect(_buildUri());
    } catch (_) {
      _connecting = false;
      _scheduleReconnect();
      return;
    }

    _subscription = _channel!.stream.listen(
      (data) {
        _backoff = _initialBackoff;
        try {
          final msg =
              jsonDecode(data as String) as Map<String, dynamic>;
          // welcome confirms auth — send project join if needed
          if (msg['type'] == WsEvent.welcome) {
            if (_projectId != null) {
              _channel!.sink.add(
                jsonEncode({
                  'type': WsEvent.join,
                  'projectId': _projectId,
                }),
              );
            }
            return;
          }
          _controller.add(msg);
        } catch (_) {}
      },
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
      cancelOnError: true,
    );

    _connecting = false;
  }

  void _scheduleReconnect() {
    _connecting = false;
    if (_disposed) return;
    if (_userId == null && _projectId == null) return;
    if (_reconnectTimer != null) return;

    final delay = _backoff;
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      _connect();
    });

    final nextMs = (_backoff.inMilliseconds * 2)
        .clamp(0, _maxBackoff.inMilliseconds);
    _backoff = Duration(milliseconds: nextMs);
  }

  void leave() {
    _disposed = true;
    _userId = null;
    _projectId = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _backoff = _initialBackoff;
  }
}

final wsClientProvider = Provider<WsClient>((_) => WsClient.instance);
