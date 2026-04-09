import 'package:flutter/material.dart';
import 'package:otraku/extension/filter_chip_extension.dart';
import 'package:otraku/feature/discover/discover_filter_model.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/shadowed_overflow_list.dart';
import 'package:otraku/widget/sheets.dart';

Future<void> showUsersFilterSheet({
  required BuildContext context,
  required DiscoverUsersFilter filter,
  required bool highContrast,
  required void Function(DiscoverUsersFilter) onDone,
}) {
  return showSheet(
    context,
    SimpleSheet(
      initialHeight: Theming.normalTapTarget * 3 + MediaQuery.paddingOf(context).bottom + 40,
      builder: (context, scrollCtrl) => _UsersFilterSheetContent(
        filter: filter,
        highContrast: highContrast,
        scrollCtrl: scrollCtrl,
        onChanged: (f) => filter = f,
      ),
    ),
  ).then((_) => onDone(filter));
}

class _UsersFilterSheetContent extends StatefulWidget {
  const _UsersFilterSheetContent({
    required this.filter,
    required this.highContrast,
    required this.scrollCtrl,
    required this.onChanged,
  });

  final DiscoverUsersFilter filter;
  final bool highContrast;
  final ScrollController scrollCtrl;
  final void Function(DiscoverUsersFilter) onChanged;

  @override
  State<_UsersFilterSheetContent> createState() => _UsersFilterSheetContentState();
}

class _UsersFilterSheetContentState extends State<_UsersFilterSheetContent> {
  late var _filter = widget.filter;

  static const _pairedLabels = ['ID', 'USERNAME', 'WATCH TIME', 'CHAPTERS READ'];

  static const _pairs = [
    (UsersSort.id, UsersSort.idDesc),
    (UsersSort.username, UsersSort.usernameDesc),
    (UsersSort.watchedTime, UsersSort.watchedTimeDesc),
    (UsersSort.chaptersRead, UsersSort.chaptersReadDesc),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final chipBuilder = FilterChipExtension.highContrast(widget.highContrast);

    final currentSort = _filter.sort;
    final pairedGroupIndex = _pairs.indexWhere((p) => p.$1 == currentSort || p.$2 == currentSort);
    final isDesc = pairedGroupIndex != -1 && _pairs[pairedGroupIndex].$2 == currentSort;

    return ListView(
      controller: widget.scrollCtrl,
      physics: Theming.bouncyPhysics,
      padding: const .symmetric(horizontal: Theming.offset, vertical: Theming.offset * 2),
      children: [
        //Sort
        _selectionTile(context, 'Sort'),
        SizedBox(
          height: 40,
          child: ShadowedOverflowList(
            itemCount: _pairedLabels.length + 1,
            itemBuilder: (context, index) {
              // first chip
              if (index == 0) {
                final selected = currentSort == UsersSort.searchMatch;
                return chipBuilder(
                  label: const Text('Relevance'),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() => _filter = _filter.copyWith(sort: UsersSort.searchMatch));
                    widget.onChanged(_filter);
                  },
                );
              }
              //paired chips
              final pairIndex = index - 1;
              final selected = pairedGroupIndex == pairIndex;
              return chipBuilder(
                label: Text(_pairedLabels[pairIndex]),
                selected: selected,
                showCheckmark: false,
                avatar: selected
                    ? Icon(
                        isDesc ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: colorScheme.onPrimaryContainer,
                      )
                    : null,
                onSelected: (_) {
                  final (asc, desc) = _pairs[pairIndex];
                  final newSort = selected ? (isDesc ? asc : desc) : (isDesc ? desc : asc);
                  setState(() => _filter = _filter.copyWith(sort: newSort));
                  widget.onChanged(_filter);
                },
              );
            },
          ),
        ),
        const SizedBox(height: Theming.offset),

        //mod
        _selectionTile(context, 'Moderator'),
        SizedBox(
          height: 40,
          child: _TriStateChip(
            label: 'Moderator',
            value: _filter.isModerator,
            highContrast: widget.highContrast,
            onChanged: (v) {
              setState(() => _filter = _filter.copyWith(isModerator: (v,)));
              widget.onChanged(_filter);
            },
          ),
        ),
      ],
    );
  }

  Widget _selectionTile(BuildContext context, String title) => Padding(
    padding: const .only(
      top: Theming.offset / 2,
      bottom: Theming.offset / 2,
      right: Theming.offset,
    ),
    child: Text(title),
  );
}

class _TriStateChip extends StatelessWidget {
  const _TriStateChip({
    required this.label,
    required this.value,
    required this.highContrast,
    required this.onChanged,
  });

  final String label;
  final bool? value;
  final bool highContrast;
  final void Function(bool?) onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final chipBuilder = FilterChipExtension.highContrast(highContrast);

    Color? selectedColor;
    if (value == true) selectedColor = Colors.green.withAlpha(102);
    if (value == false) selectedColor = colorScheme.errorContainer;

    return ShadowedOverflowList(
      itemCount: 1,
      itemBuilder: (context, _) => chipBuilder(
        label: Text(label),
        selected: value != null,
        showCheckmark: false,
        selectedColor: selectedColor,
        onSelected: (_) {
          final next = switch (value) {
            null => true,
            true => false,
            false => null,
          };
          onChanged(next);
        },
      ),
    );
  }
}
