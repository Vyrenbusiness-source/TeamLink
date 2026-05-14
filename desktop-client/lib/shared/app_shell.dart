// ignore_for_file: public_member_api_docs

import 'package:desktop_client/features/projects/project_providers.dart';
import 'package:desktop_client/l10n/app_locale.dart';
import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/shared/notification_watcher.dart';
import 'package:desktop_client/shared/theme_provider.dart';
import 'package:desktop_client/shared/toast_service.dart';
import 'package:desktop_client/shared/widgets/global_new_task_dialog.dart';
import 'package:desktop_client/shared/widgets/quick_search_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final modifier = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!modifier) return false;

    if (event.logicalKey == LogicalKeyboardKey.keyN) {
      _showNewTask();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyK) {
      _showQuickSearch();
      return true;
    }
    return false;
  }

  void _showNewTask() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) => GlobalNewTaskDialog(
          onCreate: ({required projectId, required title, deadline, assigneeId}) =>
              ref.read(tasksProvider(projectId).notifier).create(
                    title: title,
                    deadline: deadline,
                    assigneeId: assigneeId,
                  ),
        ),
      ),
    );
  }

  void _showQuickSearch() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => const QuickSearchOverlay(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return NotificationWatcher(
      child: Stack(
        children: [
          widget.child,
          const Positioned(
            bottom: 16,
            right: 16,
            width: 320,
            child: ToastOverlay(),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GlobalActionButton(
                  icon: Icons.add_task,
                  tooltip: s.tooltipNewTask,
                  onPressed: _showNewTask,
                ),
                const SizedBox(height: 8),
                _GlobalActionButton(
                  icon: Icons.search,
                  tooltip: s.tooltipQuickSearch,
                  onPressed: _showQuickSearch,
                ),
                const SizedBox(height: 8),
                const _ThemeToggleButton(),
                const SizedBox(height: 8),
                const _LocaleToggleButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalActionButton extends StatelessWidget {
  const _GlobalActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.circle,
        elevation: 2,
        color: Theme.of(context).colorScheme.surface,
        child: IconButton(
          icon: Icon(icon),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _ThemeToggleButton extends ConsumerWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider);
    final s = ref.watch(appStringsProvider);
    final (icon, tooltip) = switch (mode) {
      ThemeMode.system => (Icons.brightness_auto, s.tooltipThemeSystem),
      ThemeMode.light => (Icons.light_mode, s.tooltipThemeLight),
      ThemeMode.dark => (Icons.dark_mode, s.tooltipThemeDark),
    };
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.circle,
        elevation: 2,
        color: Theme.of(context).colorScheme.surface,
        child: IconButton(
          icon: Icon(icon),
          onPressed: () => ref.read(themeProvider.notifier).cycle(),
        ),
      ),
    );
  }
}

class _LocaleToggleButton extends ConsumerWidget {
  const _LocaleToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final s = ref.watch(appStringsProvider);
    return Tooltip(
      message: s.tooltipLanguage,
      child: Material(
        type: MaterialType.circle,
        elevation: 2,
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => ref.read(localeProvider.notifier).toggle(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Text(
                locale.languageCode.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
