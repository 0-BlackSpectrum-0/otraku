import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:otraku/extension/snack_bar_extension.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/anilist_link_handler.dart';
import 'package:otraku/widget/cached_image.dart';
import 'package:otraku/widget/loaders.dart';
import 'package:otraku/widget/dialogs.dart';
import 'package:otraku/widget/sheets.dart';
import 'package:url_launcher/url_launcher.dart';

class HtmlContent extends StatelessWidget {
  const HtmlContent(this.text, {this.renderMode = RenderMode.column});

  final String text;
  final RenderMode renderMode;

  @override
  Widget build(BuildContext context) {
    final processedText = _replaceAniListLinks(text);

    return HtmlWidget(
      fixMalformedImageUrls(processedText),
      factoryBuilder: () => _HtmlFactory(),
      renderMode: renderMode,
      textStyle: TextTheme.of(context).bodyMedium,
      onTapUrl: (url) {
        for (final matcher in _routeMatchers.entries) {
          final match = matcher.key.firstMatch(url)?.group(1);
          if (match != null) {
            context.push(matcher.value(match));
            return true;
          }
        }

        return SnackBarExtension.launch(context, url);
      },
      onTapImage: (metadata) {
        final source = metadata.sources.firstOrNull?.url;
        if (source != null) {
          showDialog(context: context, builder: (context) => ImageDialog(source));
        }
      },
      onLoadingBuilder: (_, _, _) => const Center(child: Loader()),
      onErrorBuilder: (_, element, err) => Center(
        child: IconButton(
          tooltip: 'Error',
          icon: const Icon(Icons.close_outlined),
          onPressed: () =>
              SnackBarExtension.show(context, 'Failed to load element ${element.localName}'),
        ),
      ),
      customStylesBuilder: (element) {
        return switch (element.localName) {
          'br' => const {'line-height': '15px'},
          'i' || 'em' => const {'font-style': 'italic'},
          'b' || 'strong' => const {'font-weight': '500'},
          'h1' => const {'font-size': '20px', 'font-weight': '400'},
          'h2' => const {'font-size': '18px', 'font-weight': '400'},
          'h3' => const {'font-size': '17px', 'font-weight': '400'},
          'h5' => const {'font-size': '13px', 'font-weight': '400'},
          'h4' || 'h6' => const {'font-weight': '400'},
          'a' => const {'text-decoration': 'none'},
          'img' =>
            element.attributes['width'] != null ? {'width': element.attributes['width']!} : null,
          _ => const {},
        };
      },
      customWidgetBuilder: (element) {
        if (element.localName == 'hr') {
          return Container(
            height: 5,
            width: double.infinity,
            margin: const .symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: ColorScheme.of(context).surfaceContainerHighest,
              borderRadius: Theming.borderRadiusSmall,
            ),
          );
        }

        if (element.localName == 'youtube') {
          return GestureDetector(
            onTap: () =>
                SnackBarExtension.launch(context, 'https://youtube.com/watch?v=${element.text}'),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240, maxHeight: 135),
                  child: CachedImage('https://img.youtube.com/vi/${element.text}/0.jpg'),
                ),
                const Icon(Ionicons.logo_youtube, color: Color(0xFFFF0000), size: 40),
              ],
            ),
          );
        }

        if (element.localName == 'video') {
          final source = element.children.firstWhere((e) => e.localName == 'source');
          final url = source.attributes['src'] ?? '';
          return SizedBox(
            width: double.infinity,
            child: Center(
              child: IconButton(
                tooltip: 'WebM Video',
                icon: const Icon(Ionicons.videocam, size: 50),
                onPressed: () => showSheet(context, SimpleSheet.link(context, url)),
              ),
            ),
          );
        }

        if (element.localName == 'anilistcard') {
          final category = element.attributes['category'] ?? '';
          final idOrName = element.attributes['id'] ?? '';

          if (category.isNotEmpty && idOrName.isNotEmpty) {
            return AnilistLinkHandler(category: category, idOrName: idOrName);
          }
        }

        return null;
      },
    );
  }
}

String _replaceAniListLinks(String html) {
  debugPrint('=== HTML BEFORE REPLACE ===\n$html');

  final result = html.replaceAllMapped(
    RegExp(
      '<a[^>]*href=["\']https?://anilist\\.co/(anime|manga|character|staff|user)/(\\d+|[A-Za-z0-9_-]+)[^"\']*["\'][^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    ),
    (m) {
      final category = m.group(1)!;
      final idOrName = m.group(2)!;
      final linkText = m.group(3)!.trim();

      if (!linkText.startsWith('http')) return m.group(0)!;

      return '<anilistcard category="$category" id="$idOrName"></anilistcard>';
    },
  );
  debugPrint('=== PROCESSED ===\n$result');
  return result;
}

final _routeMatchers = {
  RegExp(r'anilist.co\/(?:anime|manga)\/(\d+)'): (String id) => Routes.media(int.parse(id)),
  RegExp(r'anilist.co\/user\/([A-Za-z0-9]+)'): (String name) => Routes.userByName(name),
  RegExp(r'anilist.co\/character\/(\d+)'): (String id) => Routes.character(int.parse(id)),
  RegExp(r'anilist.co\/staff\/(\d+)'): (String id) => Routes.staff(int.parse(id)),
  RegExp(r'anilist.co\/studio\/(\d+)'): (String id) => Routes.studio(int.parse(id)),
  RegExp(r'anilist.co\/review\/(\d+)'): (String id) => Routes.review(int.parse(id)),
  RegExp(r'anilist.co\/activity\/(\d+)'): (String id) => Routes.activity(int.parse(id)),
};

String fixMalformedImageUrls(String html) {
  return html.replaceAllMapped(
    RegExp(
      r'<img([^>]*?)src="([^"]*?)"([^>]*?)/>([^<]*?)(\.(?:png|jpg|jpeg|gif|webp))\)?',
      caseSensitive: false,
    ),
    (m) {
      final before = m.group(1)!;
      final url = m.group(2)!;
      final after = m.group(3)!;
      final ext = m.group(5)!;
      return '<img${before}src="${url}${ext}"${after}/>';
    },
  );
}

class _HtmlFactory extends WidgetFactory {
  @override
  Widget? buildImageWidget(BuildTree tree, ImageSource src) {
    final url = src.url;
    if (!url.startsWith('http')) {
      return super.buildImageWidget(tree, src);
    }

    final isGif = url.toLowerCase().endsWith('.gif');
    final proxiedUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(url)}';

    final imageWidget = CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      errorWidget: (context, error, _) {
        if (isGif) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Image.network(proxiedUrl, fit: BoxFit.contain),
              Tooltip(
                message: 'Can\'t load the GIF',
                preferBelow: false,
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 40,
                  color: ColorScheme.of(context).onError,
                ),
              ),
            ],
          );
        } else {
          return CachedNetworkImage(
            imageUrl: proxiedUrl,
            fit: BoxFit.contain,
            errorWidget: (context, error, _) => Tooltip(
              message: 'Can\'t load the image',
              preferBelow: false,
              child: Icon(
                Icons.broken_image_outlined,
                size: 40,
                color: ColorScheme.of(context).onError,
              ),
            ),
          );
        }
      },
    );

    final anchor = tree.element.parent;
    final href = anchor?.localName == 'a' ? anchor?.attributes['href'] : null;

    if (href != null) {
      return Stack(
        alignment: Alignment.bottomRight,
        children: [
          imageWidget,
          Positioned(
            bottom: 4,
            right: 4,
            child: Builder(
              builder: (context) => Tooltip(
                message: href,
                preferBelow: false,
                child: InkResponse(
                  onTap: () => launchUrl(Uri.parse(href)),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: ColorScheme.of(context).surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.link, color: ColorScheme.of(context).onSurface, size: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return imageWidget;
  }
}
