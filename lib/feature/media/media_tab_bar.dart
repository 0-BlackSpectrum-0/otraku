import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:otraku/feature/media/media_models.dart';
import 'package:otraku/feature/media/media_tab_order_provider.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/util/theming.dart';

class MediaTabBar extends ConsumerStatefulWidget {
  const MediaTabBar({required this.tabCtrl, required this.withOverview, required this.scrollToTop});

  final TabController tabCtrl;
  final bool withOverview;
  final void Function() scrollToTop;

  @override
  ConsumerState<MediaTabBar> createState() => _MediaTabBarState();
}

class _MediaTabBarState extends ConsumerState<MediaTabBar> {
  static const _edgeSize = 24.0;
  static const _scrollSpeed = 5.0;

  final _barKey = GlobalKey();
  Timer? _scrollTimer;
  ScrollPosition? _position;
  double _direction = 0;

  @override
  void dispose() {
    _stopScrolling();
    super.dispose();
  }

  void _onDragUpdate(ScrollPosition? position, Offset pointer) {
    final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || position == null) return;

    final bar = box.localToGlobal(Offset.zero) & box.size;
    _position = position;

    if (pointer.dx < bar.left + _edgeSize) {
      _direction = -1;
    } else if (pointer.dx > bar.right - _edgeSize) {
      _direction = 1;
    } else {
      _stopScrolling();
      return;
    }

    _scrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final p = _position!;
      p.jumpTo(
        (p.pixels + _direction * _scrollSpeed)
            .clamp(p.minScrollExtent, p.maxScrollExtent)
            .toDouble(),
      );
    });
  }

  void _stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _direction = 0;
  }

  void _move(MediaTab dragged, MediaTab target) {
    final offset = widget.withOverview ? 1 : 0;
    final tabCtrl = widget.tabCtrl;
    final selected = widget.tabCtrl.index < offset
        ? null
        : ref.read(mediaTabOrderProvider)[tabCtrl.index - offset];

    ref.read(mediaTabOrderProvider.notifier).move(dragged, target);
    if (selected != null) {
      tabCtrl.index = ref.read(mediaTabOrderProvider).indexOf(selected) + offset;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final order = ref.watch(mediaTabOrderProvider);

    return TabBar(
      key: _barKey,
      controller: widget.tabCtrl,
      isScrollable: true,
      tabAlignment: .center,
      splashBorderRadius: Theming.borderRadiusSmall,
      onTap: (index) {
        if (index == widget.tabCtrl.index) widget.scrollToTop;
      },
      tabs: [
        if (widget.withOverview) Tab(text: l10n.overview),
        for (final tab in order)
          _DraggableTab(
            tab: tab,
            label: _label(tab, l10n),
            onDrop: (dragged) => _move(dragged, tab),
            onDragUpdate: _onDragUpdate,
            onDragEnd: _stopScrolling,
          ),
      ],
    );
  }

  static String _label(MediaTab tab, AppLocalizations l10n) => switch (tab) {
    MediaTab.info => l10n.overview,
    MediaTab.relations => l10n.related,
    MediaTab.characters => l10n.characters,
    MediaTab.staff => l10n.staff,
    MediaTab.reviews => l10n.reviews,
    MediaTab.threads => l10n.threads,
    MediaTab.following => l10n.followed,
    MediaTab.activities => l10n.activities,
    MediaTab.recommendations => l10n.recommendations,
    MediaTab.statistics => l10n.statistics,
  };
}

class _DraggableTab extends StatelessWidget {
  const _DraggableTab({
    required this.tab,
    required this.label,
    required this.onDrop,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final MediaTab tab;
  final String label;
  final void Function(MediaTab dragged) onDrop;
  final void Function(ScrollPosition? position, Offset pointer) onDragUpdate;
  final void Function() onDragEnd;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    final tabWidget = Tab(text: label);

    return DragTarget<MediaTab>(
      onWillAcceptWithDetails: (details) => details.data != tab,
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) => LongPressDraggable<MediaTab>(
        data: tab,
        hapticFeedbackOnStart: true,
        onDragUpdate: (details) => onDragUpdate(
          Scrollable.maybeOf(context, axis: .horizontal)?.position,
          details.globalPosition,
        ),
        onDragEnd: (_) => onDragEnd(),
        feedback: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const .all(16),
            child: Text(
              label,
              style: TextTheme.of(context).titleSmall?.copyWith(color: colors.primary),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: tabWidget),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: candidates.isEmpty ? null : colors.primary.withValues(alpha: 0.12),
            borderRadius: Theming.borderRadiusSmall,
          ),
          child: tabWidget,
        ),
      ),
    );
  }
}
