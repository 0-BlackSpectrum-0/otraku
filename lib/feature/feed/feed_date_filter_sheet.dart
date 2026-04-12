import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otraku/extension/date_time_extension.dart';
import 'package:otraku/feature/activity/activities_filter_model.dart';
import 'package:otraku/feature/activity/activities_filter_provider.dart';
import 'package:otraku/feature/activity/activities_model.dart';
import 'package:otraku/feature/activity/activity_date_filter.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/sheets.dart';

enum _DateMode { single, range, before, after }

void showFeedDateFilterSheet(BuildContext context, WidgetRef ref, ActivitiesTag tag) {
  final current = ref.read(activitiesFilterProvider(tag));

  ActivityDateFilter result = switch (current) {
    HomeActivitiesFilter f => f.dateFilter,
    UserActivitiesFilter f => f.dateFilter,
    _ => ActivityDateNone(),
  };

  showSheet(
    context,
    SimpleSheet(
      initialHeight: Theming.normalTapTarget * 5 + Theming.offset * 4,
      builder: (context, scrollCtrl) => _DateFilterSheetContent(
        initial: result,
        scrollCtrl: scrollCtrl,
        onChanged: (v) => result = v,
      ),
    ),
  ).then((_) {
    final notifier = ref.read(activitiesFilterProvider(tag).notifier);
    final filter = ref.read(activitiesFilterProvider(tag));
    switch (filter) {
      case HomeActivitiesFilter f:
        notifier.state = f.copyWith(dateFilter: result);
      case UserActivitiesFilter f:
        notifier.state = f.copyWithTypeIn(dateFilter: result);
      default:
        break;
    }
  });
}

class _DateFilterSheetContent extends StatefulWidget {
  const _DateFilterSheetContent({
    required this.initial,
    required this.scrollCtrl,
    required this.onChanged,
  });

  final ActivityDateFilter initial;
  final ScrollController scrollCtrl;
  final void Function(ActivityDateFilter) onChanged;

  @override
  State<_DateFilterSheetContent> createState() => _DateFilterSheetContentState();
}

class _DateFilterSheetContentState extends State<_DateFilterSheetContent> {
  late _DateMode _mode;
  DateTime? _date;
  DateTime? _rangeTo;

  @override
  void initState() {
    super.initState();
    switch (widget.initial) {
      case ActivityDateNone():
        _mode = _DateMode.single;
        _date = null;
        _rangeTo = null;
      case ActivityDateSingle(:final date):
        _mode = _DateMode.single;
        _date = date;
      case ActivityDateRange(:final from, :final to):
        _mode = _DateMode.range;
        _date = from;
        _rangeTo = to;
      case ActivityDateBefore(:final date):
        _mode = _DateMode.before;
        _date = date;
      case ActivityDateAfter(:final date):
        _mode = _DateMode.after;
        _date = date;
    }
  }

  void _notify() {
    final filter = _buildFilter();
    widget.onChanged(filter);
  }

  ActivityDateFilter _buildFilter() {
    return switch (_mode) {
      _DateMode.single when _date != null => ActivityDateSingle(_date!),
      _DateMode.range when _date != null && _rangeTo != null => ActivityDateRange(
        _date!,
        _rangeTo!,
      ),
      _DateMode.before when _date != null => ActivityDateBefore(_date!),
      _DateMode.after when _date != null => ActivityDateAfter(_date!),
      _ => const ActivityDateNone(),
    };
  }

  String _fmt(DateTime d) => '${d.day} ${DateTimeExtension.monthName(d.month)} ${d.year}';

  Future<void> _pickSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    _notify();
  }

  String get _selectionLabel {
    return switch (_mode) {
      _DateMode.single => _date != null ? _fmt(_date!) : 'No date selected',
      _DateMode.range =>
        (_date != null && _rangeTo != null)
            ? '${_fmt(_date!)} → ${_fmt(_rangeTo!)}'
            : 'No range selected',
      _DateMode.before => _date != null ? 'Before ${_fmt(_date!)}' : 'No date selected',
      _DateMode.after => _date != null ? 'After ${_fmt(_date!)}' : 'No date selected',
    };
  }

  bool get _hasSelection => switch (_mode) {
    _DateMode.range => _date != null && _rangeTo != null,
    _ => _date != null,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);

    return ListView(
      controller: widget.scrollCtrl,
      physics: Theming.bouncyPhysics,
      padding: const .symmetric(horizontal: Theming.offset, vertical: Theming.offset),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Date'),
              icon: Icon(Icons.calendar_today_outlined),
            ),
            ButtonSegment(value: true, label: Text('Range'), icon: Icon(Icons.date_range_outlined)),
          ],
          selected: {_mode != _DateMode.single},
          onSelectionChanged: (v) {
            setState(() {
              _mode = v.first ? _DateMode.range : _DateMode.single;
              _date = null;
              _rangeTo = null;
            });
            _notify();
          },
        ),
        if (_mode != _DateMode.single) ...[
          const SizedBox(height: Theming.offset),
          Wrap(
            spacing: Theming.offset / 2,
            children: [
              ChoiceChip(
                label: const Text('From ~ To'),
                selected: _mode == _DateMode.range,
                onSelected: (_) {
                  setState(() {
                    _mode = _DateMode.range;
                    _date = null;
                    _rangeTo = null;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('Before'),
                selected: _mode == _DateMode.before,
                onSelected: (_) {
                  setState(() {
                    _mode = _DateMode.before;
                    _date = null;
                    _rangeTo = null;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('After'),
                selected: _mode == _DateMode.after,
                onSelected: (_) {
                  setState(() {
                    _mode = _DateMode.after;
                    _date = null;
                    _rangeTo = null;
                  });
                },
              ),
            ],
          ),
        ],

        const SizedBox(height: Theming.offset),

        Container(
          padding: const .symmetric(horizontal: Theming.offset, vertical: Theming.offset),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: Theming.borderRadiusSmall,
          ),
          child: Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: Theming.iconSmall,
                color: _hasSelection ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Theming.offset),
              Expanded(
                child: Text(
                  _selectionLabel,
                  style: _hasSelection
                      ? textTheme.bodyMedium?.copyWith(color: colorScheme.primary)
                      : textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),

              if (_hasSelection)
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded),
                  iconSize: Theming.iconSmall,
                  onPressed: () {
                    setState(() {
                      _date = null;
                      _rangeTo = null;
                    });
                    _notify();
                  },
                ),
            ],
          ),
        ),

        const SizedBox(height: Theming.offset),

        if (_mode == _DateMode.range) ...[
          FilledButton.icon(
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(_date != null ? 'From: ${_fmt(_date!)}' : 'Pick From Date'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked == null) return;
              setState(() => _date = picked);
              _notify();
            },
          ),
          const SizedBox(height: Theming.offset / 2),
          FilledButton.icon(
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(_rangeTo != null ? 'To: ${_fmt(_rangeTo!)}' : 'Pick To Date'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _rangeTo ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked == null) return;
              setState(() => _rangeTo = picked);
              _notify();
            },
          ),
        ] else
          FilledButton.icon(
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('Pick Date'),
            onPressed: _pickSingleDate,
          ),
      ],
    );
  }
}
