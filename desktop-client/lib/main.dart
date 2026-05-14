import 'package:desktop_client/features/onboarding/onboarding_provider.dart';
import 'package:desktop_client/services/api_client.dart';
import 'package:desktop_client/services/server_config.dart';
import 'package:desktop_client/services/ws_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;
  final serverConfig = await ServerConfig.load();
  ApiClient.instance.setBaseUrl(serverConfig.baseUrl);
  WsClient.instance.setUrl(serverConfig.wsUri.toString());
  runApp(
    ProviderScope(
      overrides: [
        onboardingDoneProvider.overrideWith((ref) => onboardingDone),
        serverConfigProvider.overrideWith(
          (_) => ServerConfigNotifier(serverConfig),
        ),
      ],
      child: const TeamLinkApp(),
    ),
  );
}
