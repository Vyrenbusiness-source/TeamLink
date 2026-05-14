// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

class _SkeletonPulse extends StatefulWidget {
  const _SkeletonPulse({required this.child});

  final Widget child;

  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _anim, child: widget.child);
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 6,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);
    return _SkeletonPulse(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({this.hasLeading = false, super.key});

  final bool hasLeading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (hasLeading) ...[
            SkeletonBox(width: 40, height: 40, borderRadius: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: double.infinity, height: 14),
                const SizedBox(height: 6),
                SkeletonBox(width: 140, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonListView extends StatelessWidget {
  const SkeletonListView({this.count = 4, this.hasLeading = false, super.key});

  final int count;
  final bool hasLeading;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, __) => SkeletonListTile(hasLeading: hasLeading),
    );
  }
}

class SkeletonChatBubbles extends StatelessWidget {
  const SkeletonChatBubbles({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        _BubbleSkeleton(isMe: false, width: 200),
        _BubbleSkeleton(isMe: true, width: 160),
        _BubbleSkeleton(isMe: false, width: 240),
        _BubbleSkeleton(isMe: true, width: 120),
        _BubbleSkeleton(isMe: false, width: 180),
      ],
    );
  }
}

class _BubbleSkeleton extends StatelessWidget {
  const _BubbleSkeleton({required this.isMe, required this.width});

  final bool isMe;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SkeletonBox(width: width, height: 36, borderRadius: 16),
      ),
    );
  }
}

class SkeletonKanbanColumns extends StatelessWidget {
  const SkeletonKanbanColumns({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          3,
          (i) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
              child: _ColumnSkeleton(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColumnSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
            ),
          ),
          ...List.generate(
            3,
            (_) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: double.infinity, height: 12),
                  SizedBox(height: 4),
                  SkeletonBox(width: 80, height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
