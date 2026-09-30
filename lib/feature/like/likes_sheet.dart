import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:otraku/feature/like/likes_provider.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/cached_image.dart';
import 'package:otraku/widget/loaders.dart';
import 'package:otraku/widget/sheets.dart';

export 'package:otraku/feature/like/likes_provider.dart' show LikeableType;

void showLikesSheet(BuildContext context, int id, LikeableType type, {int? rootId}) =>
    showSheet(context, _LikesSheet((id: id, type: type, rootId: rootId)));

class _LikesSheet extends StatelessWidget {
  const _LikesSheet(this.tag);

  final LikesTag tag;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SimpleSheet(
      builder: (context, scrollCtrl) => Consumer(
        builder: (context, ref, _) => ref
            .watch(likesProvider(tag))
            .when(
              loading: () => const Center(child: Loader()),
              error: (_, _) => const Center(child: Text('Failed to load likes')),
              data: (users) => users.isEmpty
                  ? Center(child: Text(l10n.noResults))
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const .only(top: Theming.offset),
                      itemCount: users.length,
                      itemBuilder: (context, i) => ListTile(
                        leading: ClipRRect(
                          borderRadius: Theming.borderRadiusSmall,
                          child: CachedImage(users[i].avatarUrl, width: 40, height: 40),
                        ),
                        title: Text(users[i].name),
                        onTap: () {
                          final router = GoRouter.of(context);
                          Navigator.pop(context);
                          router.push(Routes.user(users[i].id, users[i].avatarUrl));
                        },
                      ),
                    ),
            ),
      ),
    );
  }
}
