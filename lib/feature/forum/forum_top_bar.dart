import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:otraku/feature/forum/forum_filter_provider.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/util/debounce.dart';
import 'package:otraku/widget/input/search_field.dart';

class ForumTopBarTrailingContent extends StatelessWidget {
  const ForumTopBarTrailingContent();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer(
      builder: (context, ref, _) => Expanded(
        child: Row(
          children: [
            Expanded(
              child: SearchField(
                debounce: Debounce(),
                hint: l10n.forum,
                value: ref.watch(forumFilterProvider.select((s) => s.search)),
                onChanged: (search) => ref
                    .read(forumFilterProvider.notifier)
                    .update((s) => s.copyWith(search: search.trim())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
