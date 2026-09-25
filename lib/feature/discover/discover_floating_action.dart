import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:otraku/feature/discover/discover_filter_provider.dart';
import 'package:otraku/feature/discover/discover_media_filter_view.dart';
import 'package:otraku/feature/discover/discover_model.dart';
import 'package:otraku/feature/discover/discover_recommendations_filter_sheet.dart';
import 'package:otraku/feature/discover/discover_users_filter_sheet.dart';
import 'package:otraku/feature/review/reviews_filter_sheet.dart';
import 'package:otraku/feature/viewer/persistence_provider.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/widget/input/pill_selector.dart';
import 'package:otraku/widget/sheets.dart';

class DiscoverFloatingAction extends StatelessWidget {
  const DiscoverFloatingAction() : super(key: const Key('switchDiscover'));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer(
      builder: (context, ref, child) {
        final type = ref.watch(discoverFilterProvider.select((s) => s.type));

        return FloatingActionButton(
          tooltip: l10n.filter,
          onPressed: () => showDiscoverFilterSheet(context, ref),
          child: Icon(
            type == .character || type == .staff ? Icons.cake_outlined : Ionicons.funnel_outline,
          ),
        );
      },
    );
  }

  // static IconData _typeIcon(DiscoverType type) => switch (type) {
  //   .anime => Ionicons.film_outline,
  //   .manga => Ionicons.book_outline,
  //   .character => Ionicons.man_outline,
  //   .staff => Ionicons.mic_outline,
  //   .studio => Ionicons.business_outline,
  //   .user => Ionicons.person_outline,
  //   .review => Icons.rate_review_outlined,
  //   .recommendation => Icons.thumb_up_outlined,
  // };
}

void showDiscoverTypeSheet(BuildContext context, WidgetRef ref, DiscoverType current) {
  final l10n = AppLocalizations.of(context)!;
  showSheet(
    context,
    SimpleSheet(
      initialHeight: PillSelector.expectedMinHeight(DiscoverType.values.length),
      builder: (context, scrollCtrl) => PillSelector(
        scrollCtrl: scrollCtrl,
        selected: current.index,
        items: DiscoverType.values.map((v) => Text(v.localize(l10n))).toList(),
        onTap: (i) {
          ref
              .read(discoverFilterProvider.notifier)
              .update((s) => s.copyWith(type: DiscoverType.values[i]));
          Navigator.pop(context);
        },
      ),
    ),
  );
}

void showDiscoverFilterSheet(BuildContext context, WidgetRef ref) {
  final filter = ref.read(discoverFilterProvider);
  final highContrast = ref.read(persistenceProvider.select((s) => s.options.highContrast));

  switch (filter.type) {
    case .anime || .manga:
      showSheet(
        context,
        DiscoverMediaFilterView(
          ofAnime: filter.type == .anime,
          filter: filter.mediaFilter,
          onChanged: (mediaFilter) => ref
              .read(discoverFilterProvider.notifier)
              .update((s) => s.copyWith(mediaFilter: mediaFilter)),
        ),
      );
    case .character || .staff:
      ref
          .read(discoverFilterProvider.notifier)
          .update((s) => s.copyWith(hasBirthday: !filter.hasBirthday));
    case .user:
      showUsersFilterSheet(
        context: context,
        filter: filter.usersFilter,
        highContrast: highContrast,
        onDone: (usersFilter) => ref
            .read(discoverFilterProvider.notifier)
            .update((s) => s.copyWith(usersFilter: usersFilter)),
      );
    case .review:
      showReviewsFilterSheet(
        context: context,
        filter: filter.reviewsFilter,
        highContrast: highContrast,
        onDone: (reviewsFilter) => ref
            .read(discoverFilterProvider.notifier)
            .update((s) => s.copyWith(reviewsFilter: reviewsFilter)),
      );
    case .recommendation:
      showRecommendationsFilterSheet(
        context: context,
        filter: filter.recommendationsFilter,
        highContrast: highContrast,
        onDone: (recommendationsFilter) => ref
            .read(discoverFilterProvider.notifier)
            .update((s) => s.copyWith(recommendationsFilter: recommendationsFilter)),
      );
    case .studio:
      break; // no filter for studios
  }
}
