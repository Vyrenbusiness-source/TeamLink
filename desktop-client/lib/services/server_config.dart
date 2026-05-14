import 'dart:io';

import 'package:desktop_client/services/api_client.dart';
import 'package:desktop_client/services/ws_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ServerMode { host, joiner }

class ServerConfig {
  const ServerConfig({
    required this.mode,
    required this.baseUrl,
  });

  final ServerMode mode;
  final String baseUrl;

  static const _kModeKey = 'server_mode';
  static const _kUrlKey = 'server_base_url';
  static const _localHost = 'http://localhost:3000';

  static const ServerConfig defaultHost = ServerConfig(
    mode: ServerMode.host,
    baseUrl: _localHost,
  );

  Uri get httpUri => Uri.parse(baseUrl);

  Uri get wsUri {
    final u = httpUri;
    return u.replace(
      scheme: u.scheme == 'https' ? 'wss' : 'ws',
    );
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModeKey, mode.name);
    await prefs.setString(_kUrlKey, baseUrl);
    await _writeLauncherMarker(mode);
  }

  static Future<void> _writeLauncherMarker(ServerMode mode) async {
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) return;
    try {
      final dir = Directory('$appData\\TeamLink');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}\\mode.txt');
      await file.writeAsString(mode.name);
    } catch (_) {
      // Best-effort: launcher falls back to host mode if file missing.
    }
  }

  static Future<ServerConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_kModeKey);
    final url = prefs.getString(_kUrlKey);
    final mode = ServerMode.values
        .firstWhere((m) => m.name == modeStr, orElse: () => ServerMode.host);
    return ServerConfig(
      mode: mode,
      baseUrl: url ?? _localHost,
    );
  }
}

class ServerConfigNotifier extends StateNotifier<ServerConfig> {
  ServerConfigNotifier(super.initial);

  void _applyToClients(ServerConfig cfg) {
    ApiClient.instance.setBaseUrl(cfg.baseUrl);
    ApiClient.instance.clearSession();
    WsClient.instance.setUrl(cfg.wsUri.toString());
  }

  Future<void> setHost() async {
    state = ServerConfig.defaultHost;
    _applyToClients(state);
    await state.persist();
  }

  Future<void> setJoiner(String baseUrl) async {
    final cleaned = baseUrl.trim();
    state = ServerConfig(mode: ServerMode.joiner, baseUrl: cleaned);
    _applyToClients(state);
    await state.persist();
  }
}

final serverConfigProvider =
    StateNotifierProvider<ServerConfigNotifier, ServerConfig>(
  (_) => ServerConfigNotifier(ServerConfig.defaultHost),
);
