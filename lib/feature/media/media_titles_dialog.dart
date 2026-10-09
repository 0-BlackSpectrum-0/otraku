import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:otraku/extension/card_extension.dart';
import 'package:otraku/extension/snack_bar_extension.dart';
import 'package:otraku/feature/media/media_models.dart';
import 'package:otraku/feature/viewer/persistence_provider.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/util/theming.dart';

class MediaTitlesDialog extends ConsumerWidget {
  const MediaTitlesDialog(this.info);

  final MediaInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final highContrast = ref.watch(persistenceProvider.select((s) => s.options.highContrast));

    final titles = [
      if (info.hashtag != null) (l10n.mediaHashtag, info.hashtag!),
      if (info.romajiTitle != null) (l10n.mediaTitleRomaji, info.romajiTitle!),
      if (info.englishTitle != null) (l10n.mediaTitleEnglish, info.englishTitle!),
      if (info.nativeTitle != null) (l10n.mediaTitleNative, info.nativeTitle!),
      ...info.synonyms.map((s) => (l10n.mediaTitleSynonym, s)),
    ];

    return Dialog(
      insetPadding: const .all(Theming.offset),
      shape: RoundedRectangleBorder(borderRadius: Theming.borderRadiusSmall),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: Padding(
          padding: const .symmetric(horizontal: Theming.offset),
          child: Flexible(
            fit: FlexFit.tight,
            child: SingleChildScrollView(
              padding: const .symmetric(vertical: Theming.offset),
              child: CardExtension.highContrast(highContrast)(
                child: Padding(
                  padding: const .symmetric(vertical: Theming.offset),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: titles.length,
                    padding: .zero,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder: (context, _) => const Divider(),
                    itemBuilder: (context, i) => Row(
                      children: [
                        const SizedBox(width: Theming.offset),
                        Center(child: Text(titles[i].$1, textAlign: .start)),
                        const SizedBox(width: Theming.offset * 2),
                        Expanded(
                          child: GestureDetector(
                            behavior: .opaque,
                            onTap: () => SnackBarExtension.copy(context, titles[i].$2),
                            child: Text(titles[i].$2, textAlign: .end),
                          ),
                        ),
                        const SizedBox(width: Theming.offset),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
