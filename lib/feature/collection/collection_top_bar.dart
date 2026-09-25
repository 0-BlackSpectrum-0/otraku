import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:otraku/feature/collection/collection_entries_provider.dart';
import 'package:otraku/feature/collection/collection_filter_provider.dart';
import 'package:otraku/feature/collection/collection_models.dart';
import 'package:otraku/feature/collection/collection_provider.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/util/debounce.dart';
import 'package:otraku/widget/input/search_field.dart';
import 'package:otraku/widget/dialogs.dart';

class CollectionTopBarTrailingContent extends StatelessWidget {
  const CollectionTopBarTrailingContent(this.tag, this.focusNode);

  final CollectionTag tag;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer(
      builder: (context, ref, _) {
        final filter = ref.watch(collectionFilterProvider(tag));

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: SearchField(
                  debounce: Debounce(),
                  focusNode: focusNode,
                  hint: ref.watch(collectionProvider(tag).select((s) => s.value?.listName ?? '')),
                  value: filter.search,
                  onChanged: (search) => ref
                      .read(collectionFilterProvider(tag).notifier)
                      .update((s) => s.copyWith(search: search)),
                ),
              ),
              IconButton(
                tooltip: l10n.random,
                icon: const Icon(Ionicons.shuffle_outline),
                onPressed: () {
                  final lists = ref.read(collectionEntriesProvider(tag));
                  if (lists.isEmpty) {
                    ConfirmationDialog.show(context, title: l10n.noEntries);
                    return;
                  }

                  final list = lists[Random().nextInt(lists.length)];
                  if (list.entries.isEmpty) {
                    ConfirmationDialog.show(context, title: l10n.noEntries);
                    return;
                  }

                  final entry = list.entries[Random().nextInt(list.entries.length)];
                  context.push(Routes.media(entry.mediaId, entry.imageUrl));
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
