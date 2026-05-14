// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:desktop_client/services/api_client.dart';
import 'package:desktop_client/services/ws_events.dart';
import 'package:desktop_client/shared/models/sync_state.dart';
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

  /// Heartbeat interval — server drops connections silent for >30 s.
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  /// Maximum offline-queue depth (oldest messages are dropped first).
  static const int _maxQueueDepth = 200;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Duration _backoff = _initialBackoff;
  bool _disposed = false;
  bool _connecting = false;

  String? _userId;
  String? _projectId;

  final _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<SyncState>.broadcast();

  /// Pending payloads (JSON strings) buffered while offline.
  final Queue<String> _offlineQueue = Queue<String>();

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  /// Emits [SyncState] transitions: syncing → online → offline (→ syncing…).
  Stream<SyncState> get connectionState => _stateController.stream;

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

  /// Send [payload] immediately when connected; queue it otherwise.
  void send(Map<String, dynamic> payload) {
    final encoded = jsonEncode(payload);
    if (_channel != null && !_disposed) {
      try {
        _channel!.sink.add(encoded);
        return;
      } catch (_) {}
    }
    _enqueue(encoded);
  }

  void _enqueue(String encoded) {
    if (_offlineQueue.length >= _maxQueueDepth) _offlineQueue.removeFirst();
    _offlineQueue.addLast(encoded);
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

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;

    _stateController.add(const SyncState.syncing());

    try {
      _channel = WebSocketChannel.connect(_buildUri());
    } catch (_) {
      _connecting = false;
      _stateController.add(const SyncState.offline());
      _scheduleReconnect();
      return;
    }

    _subscription = _channel!.stream.listen(
      (data) {
        _backoff = _initialBackoff;
        try {
          final msg =
              jsonDecode(data as String) as Map<String, dynamic>;
          if (msg['type'] == WsEvent.welcome) {
            _stateController.add(const SyncState.online());
            _startHeartbeat();
            if (_projectId != null) {
              _channel!.sink.add(jsonEncode({
                'type': WsEvent.join,
                'projectId': _projectId,
              },),);
            }
            _flushQueue();
            return;
          }
          // Silently discard server pongs — they only reset the backoff above.
          if (msg['type'] == WsEvent.pong) return;
          _eventController.add(msg);
        } catch (_) {}
      },
      onError: (_) {
        _stateController.add(const SyncState.offline());
        _scheduleReconnect();
      },
      onDone: () {
        _stateController.add(const SyncState.offline());
        _scheduleReconnect();
      },
      cancelOnError: true,
    );

    _connecting = false;
  }

  void _flushQueue() {
    while (_offlineQueue.isNotEmpty) {
      final encoded = _offlineQueue.first;
      if (_channel == null || _disposed) break;
      try {
        _channel!.sink.add(encoded);
        _offlineQueue.removeFirst();
      } catch (_) {
        break;
      }
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_channel != null && !_disposed) {
        try {
          _channel!.sink.add(jsonEncode({'type': WsEvent.ping}));
        } catch (_) {}
      }
    });
  }

  void _scheduleReconnect() {
    _connecting = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
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
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _backoff = _initialBackoff;
    _offlineQueue.clear();
    _stateController.add(const SyncState.offline());
  }
}

final wsClientProvider = Provider<WsClient>((_) => WsClient.instance);
