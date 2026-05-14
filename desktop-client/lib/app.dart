import 'package:desktop_client/features/dm/dm_screen.dart';
import 'package:desktop_client/features/onboarding/onboarding_provider.dart';
import 'package:desktop_client/features/onboarding/onboarding_screen.dart';
import 'package:desktop_client/features/projects/project_detail_screen.dart';
import 'package:desktop_client/l10n/app_locale.dart';
import 'package:desktop_client/shared/app_shell.dart';
import 'package:desktop_client/shared/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/task_overview_screen.dart';

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<bool>(onboardingDoneProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final done = _ref.read(onboardingDoneProvider);
    if (!done && state.matchedLocation != '/onboarding') return '/onboarding';
    if (done && state.matchedLocation == '/onboarding') return '/';
    return null;
  }
}

final _routerNotifierProvider = Provider<_RouterNotifier>(
  (ref) => _RouterNotifier(ref),
);

final _routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);
  return GoRouter(
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/projects/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final name = state.extra as String? ?? 'Projekt';
              return ProjectDetailScreen(projectId: id, projectName: name);
            },
          ),
          GoRoute(
            path: '/overview',
            builder: (context, state) => const TaskOverviewScreen(),
          ),
          GoRoute(
            path: '/dm',
            builder: (context, state) => const DmListScreen(),
          ),
          GoRoute(
            path: '/dm/:partnerId',
            builder: (context, state) {
              final partnerId = state.pathParameters['partnerId']!;
              final partnerName = state.extra as String? ?? partnerId;
              return DmChatScreen(
                partnerId: partnerId,
                partnerName: partnerName,
              );
            },
          ),
        ],
      ),
    ],
  );
});

class TeamLinkApp extends ConsumerWidget {
  const TeamLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(_routerProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'TeamLink',
      routerConfig: router,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
