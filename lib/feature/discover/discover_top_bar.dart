import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:otraku/feature/discover/discover_filter_provider.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/util/debounce.dart';
import 'package:otraku/widget/input/search_field.dart';

class DiscoverTopBarTrailingContent extends StatelessWidget {
  const DiscoverTopBarTrailingContent(this.focusNode);

  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer(
      builder: (context, ref, _) {
        final filter = ref.watch(discoverFilterProvider);

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: switch (filter.type) {
                  .review => Text(
                    l10n.reviews,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: TextTheme.of(context).bodyMedium,
                  ),
                  .recommendation => Text(
                    l10n.recommendations,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: TextTheme.of(context).bodyMedium,
                  ),
                  _ => SearchField(
                    debounce: Debounce(),
                    focusNode: focusNode,
                    hint: filter.type.localize(l10n),
                    value: filter.search,
                    onChanged: (search) => ref
                        .read(discoverFilterProvider.notifier)
                        .update((s) => s.copyWith(search: search)),
                  ),
                },
              ),
              if (filter.type == .anime)
                IconButton(
                  tooltip: l10n.calendar,
                  icon: const Icon(Ionicons.calendar_outline),
                  onPressed: () => context.push(Routes.calendar),
                ),
            ],
          ),
        );
      },
    );
  }

  //   Widget _usersFilterIcon(
  //     BuildContext context,
  //     WidgetRef ref,
  //     DiscoverFilter filter,
  //     bool highContrast,
  //   ) {
  //     return IconButton(
  //       tooltip: 'Filter',
  //       icon: const Icon(Ionicons.funnel_outline),
  //       onPressed: () => showUsersFilterSheet(
  //         context: context,
  //         filter: filter.usersFilter,
  //         highContrast: highContrast,
  //         onDone: (usersFilter) {
  //           final discoverFilter = ref.read(discoverFilterProvider);
  //           if (usersFilter != discoverFilter.usersFilter) {
  //             ref
  //                 .read(discoverFilterProvider.notifier)
  //                 .update((s) => s.copyWith(usersFilter: usersFilter));
  //           }
  //         },
  //       ),
  //     );
  //   }
  // }

  // class _BirthdayFilter extends StatelessWidget {
  //   const _BirthdayFilter(this.ref);

  //   final WidgetRef ref;

  //   @override
  //   Widget build(BuildContext context) {
  //     final l10n = AppLocalizations.of(context)!;
  //     final hasBirthday = ref.watch(discoverFilterProvider.select((s) => s.hasBirthday));

  //     final icon = IconButton(
  //       tooltip: hasBirthday ? l10n.filterShowAll : l10n.filterShowBirthdayPeople,
  //       icon: const Icon(Icons.cake_outlined),
  //       onPressed: () => ref
  //           .read(discoverFilterProvider.notifier)
  //           .update((s) => s.copyWith(hasBirthday: !hasBirthday)),
  //     );

  //     return hasBirthday
  //         ? Badge(
  //             smallSize: 10,
  //             alignment: .topLeft,
  //             backgroundColor: ColorScheme.of(context).primary,
  //             child: icon,
  //           )
  //         : icon;
  //   }
}
