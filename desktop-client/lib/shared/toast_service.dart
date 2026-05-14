// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ToastType { info, warning }

class ToastMessage {
  ToastMessage({
    required this.title,
    required this.body,
    this.type = ToastType.info,
  }) : id = DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  final String title;
  final String body;
  final ToastType type;
}

class ToastNotifier extends Notifier<List<ToastMessage>> {
  @override
  List<ToastMessage> build() => [];

  void show(ToastMessage msg) {
    state = [...state, msg];
    Future.delayed(const Duration(seconds: 4), () => dismiss(msg.id));
  }

  void dismiss(String id) {
    state = state.where((m) => m.id != id).toList();
  }
}

final toastProvider =
    NotifierProvider<ToastNotifier, List<ToastMessage>>(ToastNotifier.new);

class ToastOverlay extends ConsumerWidget {
  const ToastOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(toastProvider);
    if (toasts.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: toasts.map((t) => _ToastCard(toast: t)).toList(),
    );
  }
}

class _ToastCard extends ConsumerWidget {
  const _ToastCard({required this.toast});

  final ToastMessage toast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isWarning = toast.type == ToastType.warning;
    final bg = isWarning ? cs.errorContainer : cs.primaryContainer;
    final fg = isWarning ? cs.onErrorContainer : cs.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: bg,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                isWarning
                    ? Icons.warning_amber_rounded
                    : Icons.assignment_ind_outlined,
                color: isWarning ? cs.error : cs.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      toast.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: fg,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      toast.body,
                      style: TextStyle(color: fg, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => ref.read(toastProvider.notifier).dismiss(toast.id),
                child: Icon(Icons.close, size: 16, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
