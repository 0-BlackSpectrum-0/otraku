import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:otraku/extension/snack_bar_extension.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/anilist_link_handler.dart';
import 'package:otraku/widget/cached_image.dart';
import 'package:otraku/widget/loaders.dart';
import 'package:otraku/widget/dialogs.dart';
import 'package:otraku/widget/media_loader.dart';

import 'package:video_player/video_player.dart';
import 'package:otraku/widget/shimmer.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HtmlContent extends StatefulWidget {
  const HtmlContent(this.text, {this.renderMode = .column});

  final String text;
  final RenderMode renderMode;

  @override
  State<HtmlContent> createState() => _HtmlContentState();
}

class _HtmlContentState extends State<HtmlContent> {
  static final _prepared = <String, String>{};

  static String _prepare(String text) {
    final cached = _prepared[text];
    if (cached != null) return cached;

    final result = fixMalformedImageUrls(_replaceAniListLinks(repairBrokenHtml(text)));
    if (_prepared.length > 64) _prepared.remove(_prepared.keys.first);
    return _prepared[text] = result;
  }

  late String _html = _prepare(widget.text);

  @override
  void didUpdateWidget(HtmlContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _html = _prepare(widget.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return HtmlWidget(
      _html,
      factoryBuilder: _HtmlFactory.new,
      renderMode: widget.renderMode,
      textStyle: TextTheme.of(context).bodyMedium,
      onTapUrl: (url) => _openLink(context, url),
      onLoadingBuilder: (_, _, _) => const Center(child: Loader()),
      onErrorBuilder: (_, element, err) => Center(
        child: Tooltip(
          preferBelow: false,
          triggerMode: .tap,
          message: l10n.errorFailedLoading(element.localName ?? '?'),
          child: const Icon(Icons.error_outline_rounded),
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
            (element.attributes['width'] ?? '').isNotEmpty
                ? {'width': element.attributes['width']!}
                : null,
          _ => const {},
        };
      },
      customWidgetBuilder: (element) {
        if (element.localName == 'hr') {
          return Container(
            height: 5,
            width: .infinity,
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
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: .expand,
                children: [
                  CachedImage('https://img.youtube.com/vi/${element.text}/0.jpg'),

                  const Center(
                    child: Icon(Ionicons.logo_youtube, color: Color(0xFFFF0000), size: 56),
                  ),
                ],
              ),
            ),
          );
        }

        if (element.localName == 'video') {
          final src = element.querySelector('source')?.attributes['src'];
          if (src != null && src.startsWith('http')) {
            return _InlineVideoPlayer(src);
          }
        }
        if (element.localName == 'anilistcard') {
          final category = element.attributes['category'] ?? '';
          final idOrName = element.attributes['id'] ?? '';

          if (category.isNotEmpty && idOrName.isNotEmpty) {
            return AnilistLinkHandler(category: category, idOrName: idOrName);
          }
        }
        if (element.localName == 'details') {
          final inner = element.innerHtml.replaceFirst(
            RegExp(r'^\s*<summary[^>]*>.*?</summary>', caseSensitive: false, dotAll: true),
            '',
          );
          return _Spoiler(inner);
        }
        return null;
      },
    );
  }
}

String repairBrokenHtml(String html) {
  final mention = RegExp(
    r'(src="[^"<]*)<a href="https?://anilist\.co/user/[^"]*">(@[^<]*)</a>',
    caseSensitive: false,
  );
  String prev;
  do {
    prev = html;
    html = html.replaceAllMapped(mention, (m) => '${m[1]}${m[2]}');
  } while (html != prev);

  return html.replaceAll(RegExp(r'<a\s*<br\s*/?>\s*', caseSensitive: false), '<a ');
}

String _replaceAniListLinks(String html) {
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
  return result;
}

final _routeMatchers = {
  RegExp(r'^https?://(?:www\.)?anilist\.co/(?:anime|manga)/(\d+)'): (String id) =>
      Routes.media(int.parse(id)),
  RegExp(r'^https?://(?:www\.)?anilist\.co/user/([A-Za-z0-9_]+)'): (String name) =>
      Routes.userByName(name),
  RegExp(r'^https?://(?:www\.)?anilist\.co/character/(\d+)'): (String id) =>
      Routes.character(int.parse(id)),
  RegExp(r'^https?://(?:www\.)?anilist\.co/staff/(\d+)'): (String id) =>
      Routes.staff(int.parse(id)),
  RegExp(r'^https?://(?:www\.)?anilist\.co/studio/(\d+)'): (String id) =>
      Routes.studio(int.parse(id)),
  RegExp(r'^https?://(?:www\.)?anilist\.co/review/(\d+)'): (String id) =>
      Routes.review(int.parse(id)),
  RegExp(r'^https?://(?:www\.)?anilist\.co/activity/(\d+)'): (String id) =>
      Routes.activity(int.parse(id)),
  RegExp(r'^https?://(?:www\.)?anilist\.co/forum/thread/(\d+)'): (String id) =>
      Routes.thread(int.parse(id)),
};

Future<bool> _openLink(BuildContext context, String url) {
  for (final matcher in _routeMatchers.entries) {
    final match = matcher.key.firstMatch(url)?.group(1);
    if (match != null) {
      context.push(matcher.value(match));
      return Future.value(true);
    }
  }
  return SnackBarExtension.launch(context, url);
}

class _VideoSlots {
  static const keepLoaded = 3;
  static final _items = <_InlineVideoPlayerState>{};
  static Timer? _timer;

  static void add(_InlineVideoPlayerState s) {
    _items.add(s);
    _timer ??= Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    trim();
  }

  static void trim() {
    if (_items.length <= keepLoaded) return;
    final offscreen = _items.where((s) => !s.isVisible).toList()
      ..sort((a, b) => a.lastSeen.compareTo(b.lastSeen));
    var excess = _items.length - keepLoaded;
    for (final s in offscreen) {
      if (excess-- <= 0) break;
      s.unload();
    }
  }

  static void remove(_InlineVideoPlayerState s) {
    _items.remove(s);
    if (_items.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// The loaded video closest to the screen's vertical center plays, the rest pause.
  static void _tick() {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return;
    final centerY = view.physicalSize.height / view.devicePixelRatio / 2;

    _InlineVideoPlayerState? best;
    var bestDistance = double.infinity;
    for (final s in _items) {
      final d = s.distanceTo(centerY);
      if (d != null && d < bestDistance) {
        best = s;
        bestDistance = d;
      }
    }
    for (final s in _items) {
      s.setPlaying(s == best);
    }
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  const _InlineVideoPlayer(this.url);

  final String url;

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  static final _aspects = <String, double>{}; // remembered so the box never resizes
  static final _posters = <String, Uint8List>{}; // first frame per video
  final _boundaryKey = GlobalKey();
  bool _visible = false;
  DateTime _lastSeen = DateTime.now();

  bool get isVisible => _visible;
  DateTime get lastSeen => _lastSeen;

  final _visKey = UniqueKey();
  VideoPlayerController? _controller;
  bool _muted = true;
  bool _failed = false;
  bool _wantPlay = false;
  bool _dialog = false;

  void _onVisibility(VisibilityInfo info) {
    if (!mounted) return;
    _visible = info.visibleFraction > 0;
    _lastSeen = DateTime.now();

    if (_visible) {
      _load(); // no-op if its controller is still alive
    } else {
      setPlaying(false);
      _VideoSlots.trim();
    }
  }

  Future<void> _load() async {
    if (_controller != null || _failed) return;
    _VideoSlots.add(this);

    final c = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: videoHeaders,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = c;
    try {
      await c.initialize();
      if (!mounted || _controller != c) return; // already disposed by _unload
      _aspects[widget.url] = c.value.aspectRatio;
      await c.setVolume(_muted ? 0 : 1);
      await c.setLooping(true);
      if (_wantPlay) await c.play();
      if (mounted) setState(() {});
      _capturePoster();
    } catch (e) {
      debugPrint('video_player failed for ${widget.url}: $e');
      if (!mounted || _controller != c) return;
      _controller = null;
      _VideoSlots.remove(this);
      c.dispose();
      setState(() => _failed = true);
    }
  }

  void unload() {
    _VideoSlots.remove(this);
    final c = _controller;
    _controller = null;
    _wantPlay = false;
    c?.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _capturePoster() async {
    if (_posters.containsKey(widget.url)) return;
    await Future.delayed(const Duration(milliseconds: 400)); // let the first frame render
    final boundary = _boundaryKey.currentContext?.findRenderObject();
    if (!mounted || boundary is! RenderRepaintBoundary) return;
    try {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return;
      if (_posters.length > 30) _posters.remove(_posters.keys.first);
      _posters[widget.url] = data.buffer.asUint8List();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void setPlaying(bool play) {
    play = play && !_dialog;
    _wantPlay = play;
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isPlaying == play) return;
    play ? c.play() : c.pause();
  }

  /// Distance of this video's center to [centerY], or null if under half visible.
  double? distanceTo(double centerY) {
    final box = context.findRenderObject();
    if (!mounted || box is! RenderBox || !box.attached || !box.hasSize) return null;
    final top = box.localToGlobal(Offset.zero).dy;
    final h = box.size.height;
    final visible = math.min(top + h, centerY * 2) - math.max(top, 0);
    if (visible < h * 0.5) return null;
    return (top + h / 2 - centerY).abs();
  }

  Future<void> _openDialog() async {
    _dialog = true;
    setPlaying(false);
    await showDialog(context: context, builder: (context) => VideoDialog(widget.url));
    _dialog = false; // the next tick resumes it if it's still centered
  }

  @override
  void dispose() {
    _VideoSlots.remove(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return MediaKitFallbackPlayer(widget.url);

    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    final aspect = ready ? c.value.aspectRatio : (_aspects[widget.url] ?? 16 / 9);
    final poster = _posters[widget.url];

    return VisibilityDetector(
      key: _visKey,
      onVisibilityChanged: _onVisibility,
      child: GestureDetector(
        onTap: ready ? _openDialog : null,
        child: AspectRatio(
          aspectRatio: aspect,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: ColorScheme.of(context).surfaceContainerHighest),
              if (poster != null) Image.memory(poster, fit: BoxFit.cover, gaplessPlayback: true),
              if (ready)
                RepaintBoundary(key: _boundaryKey, child: VideoPlayer(c))
              else
                const Center(child: CircularProgressIndicator()),
              if (ready)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: InkResponse(
                    onTap: () => setState(() {
                      _muted = !_muted;
                      c.setVolume(_muted ? 0 : 1);
                    }),
                    child: Container(
                      padding: const .all(4),
                      decoration: BoxDecoration(
                        color: ColorScheme.of(context).surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: ColorScheme.of(context).primary,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MediaKitFallbackPlayer extends StatefulWidget {
  const MediaKitFallbackPlayer(this.url, {this.inDialog = false});

  final String url;
  final bool inDialog;

  @override
  State<MediaKitFallbackPlayer> createState() => _MediaKitFallbackPlayerState();
}

class _MediaKitFallbackPlayerState extends State<MediaKitFallbackPlayer> {
  late final player = Player(configuration: const PlayerConfiguration(bufferSize: 8 * 1024 * 1024));
  late final controller = VideoController(player);
  StreamSubscription<String>? _errorSub;
  bool _muted = true;
  String? _mediaKitError;

  @override
  void initState() {
    super.initState();
    _errorSub = player.stream.error.listen((error) {
      if (mounted) setState(() => _mediaKitError = error);
    });
    player.setPlaylistMode(PlaylistMode.single);
    player.setVolume(widget.inDialog ? 100 : 0);
    player.open(Media(widget.url, httpHeaders: videoHeaders), play: true);
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mediaKitError != null) {
      return GestureDetector(
        onTap: () => SnackBarExtension.launch(context, widget.url),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: ColorScheme.of(context).surfaceContainerHighest,
              borderRadius: Theming.borderRadiusSmall,
            ),
            padding: const .all(Theming.offset),
            child: Center(child: Text(_mediaKitError!)),
          ),
        ),
      );
    }

    final video = AspectRatio(
      aspectRatio: 16 / 9,
      child: Video(
        controller: controller,
        controls: widget.inDialog ? MaterialVideoControls : NoVideoControls,
      ),
    );

    // Inside the dialog there is nothing to open, so just show the player.
    if (widget.inDialog) return video;

    return GestureDetector(
      onTap: () => showDialog(context: context, builder: (context) => VideoDialog(widget.url)),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          video,
          Positioned(
            bottom: 4,
            right: 4,
            child: Tooltip(
              preferBelow: false,
              message: _muted ? 'Unmute' : 'Mute',
              child: InkResponse(
                onTap: () => setState(() {
                  _muted = !_muted;
                  player.setVolume(_muted ? 0 : 100);
                }),
                child: Container(
                  padding: const .all(4),
                  decoration: BoxDecoration(
                    color: ColorScheme.of(context).surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: ColorScheme.of(context).primary,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String fixMalformedImageUrls(String html) {
  var result = html.replaceAllMapped(
    RegExp(r'<img([^>]*?)src=(?:<br\s*/?>\s*)*\s*\n\s*"([^"]+)"([^>]*?)>', caseSensitive: false),
    (m) {
      final before = m.group(1)!;
      final url = m.group(2)!;
      final after = m.group(3)!;
      return '<img${before}src="$url"${after}/>';
    },
  );

  result = result.replaceAllMapped(
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
  return result;
}

class _HtmlFactory extends WidgetFactory {
  @override
  Widget? buildImageWidget(BuildTree tree, ImageSource src) {
    if (!src.url.startsWith('http')) return super.buildImageWidget(tree, src);

    // This was 'herf' before, so linked images never found their link.
    String? href;
    for (var e = tree.element.parent; e != null; e = e.parent) {
      if (e.localName == 'a') {
        href = e.attributes['href'];
        break;
      }
    }

    return _HtmlImage(url: MediaLoader.normalize(src.url), href: href);
  }
}

class _HtmlImage extends StatefulWidget {
  const _HtmlImage({required this.url, required this.href});

  final String url;
  final String? href;

  @override
  State<_HtmlImage> createState() => _HtmlImageState();
}

class _HtmlImageState extends State<_HtmlImage> {
  ResolvedImage? _image;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _image = MediaLoader.instance.peek(widget.url); // instant if prefetched (spoilers)
    if (_image == null) _fetch();
  }

  @override
  void didUpdateWidget(_HtmlImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _error = null;
      _image = MediaLoader.instance.peek(widget.url);
      if (_image == null) _fetch();
    }
  }

  void _fetch() {
    final url = widget.url;
    MediaLoader.instance
        .load(url, MediaRequest(isAlive: () => mounted, bounds: _bounds))
        .then(
          (image) {
            if (mounted && widget.url == url) setState(() => _image = image);
          },
          onError: (Object e) {
            if (mounted && widget.url == url) setState(() => _error = e);
          },
        );
  }

  ({double top, double bottom})? _bounds() {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final top = box.localToGlobal(Offset.zero).dy;
    return (top: top, bottom: top + box.size.height);
  }

  void _onTap() {
    final href = widget.href?.trim();
    if (href != null && href.isNotEmpty) {
      _openLink(context, href);
    } else if (_error != null) {
      setState(() => _error = null); // tap a failed image to retry
      _fetch();
    } else {
      SnackBarExtension.show(
        context,
        'No link attached to this image, long press to view the image',
      );
    }
  }

  void _onLongPress() {
    final image = _image;
    if (image == null) return;
    if (image.isSvg) {
      SnackBarExtension.launch(context, widget.url);
    } else {
      showDialog(context: context, builder: (context) => ImageDialog(image.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final Widget child;

    if (image == null) {
      child = _error == null ? const _ImagePlaceholder() : _failedImage(context, widget.url);
    } else if (image.isSvg) {
      child = _SvgImage(image.svg!, image.url);
    } else {
      final px = MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context);
      child = Image.file(
        image.file!,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        cacheWidth: math.min(px.round(), 1440),
        errorBuilder: (context, _, _) => _failedImage(context, widget.url),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      onLongPress: _onLongPress,
      child: child,
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Shimmer(
          ShimmerItem(
            Container(
              width: 60,
              height: 15,
              decoration: BoxDecoration(
                borderRadius: Theming.borderRadiusSmall,
                color: scheme.surfaceContainerHighest,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- SVG (this is what makes the Spotify card work) ----------

Size? _svgSize(String svg) {
  final tag = RegExp(r'<svg\b[^>]*>', caseSensitive: false, dotAll: true).firstMatch(svg)?.group(0);
  if (tag == null) return null;

  final vb = RegExp(
    r'''viewBox\s*=\s*["']\s*[-\d.]+[\s,]+[-\d.]+[\s,]+([\d.]+)[\s,]+([\d.]+)''',
    caseSensitive: false,
  ).firstMatch(tag);
  if (vb != null) {
    final w = double.tryParse(vb.group(1)!);
    final h = double.tryParse(vb.group(2)!);
    if (w != null && h != null && w > 0 && h > 0) return Size(w, h);
  }

  double? attr(String name) {
    final m = RegExp(
      '(?<![-\\w])$name\\s*=\\s*["\']\\s*([\\d.]+)(?:px)?\\s*["\']',
      caseSensitive: false,
    ).firstMatch(tag);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  final w = attr('width');
  final h = attr('height');
  return (w != null && h != null && w > 0 && h > 0) ? Size(w, h) : null;
}

/// flutter_svg ignores these, so they need a real browser engine.
bool _needsBrowser(String svg) => RegExp(
  r'''<foreignObject|<script|@import|url\(\s*["']?https?:|<image[^>]+href\s*=\s*["']https?:''',
  caseSensitive: false,
).hasMatch(svg);

class _SvgImage extends StatelessWidget {
  const _SvgImage(this.svg, this.url);

  final String svg;
  final String url;

  @override
  Widget build(BuildContext context) {
    final size = _svgSize(svg);
    final aspect = size == null ? 16 / 9 : size.width / size.height;

    if (_needsBrowser(svg)) {
      return _SvgWebView(svg: svg, baseUrl: url, aspectRatio: aspect);
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: size?.width ?? 300,
        height: size?.height ?? 150,
        child: SvgPicture.string(
          svg,
          fit: BoxFit.contain,
          errorBuilder: (context, _, _) => _SvgWebView(svg: svg, baseUrl: url, aspectRatio: aspect),
        ),
      ),
    );
  }
}

class _SvgWebView extends StatefulWidget {
  const _SvgWebView({required this.svg, required this.baseUrl, required this.aspectRatio});

  final String svg;
  final String baseUrl;
  final double aspectRatio;

  @override
  State<_SvgWebView> createState() => _SvgWebViewState();
}

class _SvgWebViewState extends State<_SvgWebView> {
  // The SVG is inlined into an HTML page. Inline SVG can load external images
  // and render <foreignObject>, unlike an SVG loaded through <img>.
  late final _ctrl = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.disabled)
    ..setBackgroundColor(Colors.transparent)
    ..loadHtmlString(_page(widget.svg), baseUrl: widget.baseUrl);

  static String _page(String svg) {
    var s = svg
        .replaceAll(RegExp(r'<\?xml[^>]*\?>'), '')
        .replaceAll(RegExp(r'<!doctype[^>]*>', caseSensitive: false), '');

    final size = _svgSize(s);
    if (size != null && !RegExp(r'<svg\b[^>]*viewBox', caseSensitive: false).hasMatch(s)) {
      s = s.replaceFirst(
        RegExp(r'<svg\b', caseSensitive: false),
        '<svg viewBox="0 0 ${size.width} ${size.height}"',
      );
    }

    return '<!doctype html><html><head>'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<style>html,body{margin:0;padding:0;background:transparent;overflow:hidden}'
        'svg{display:block;width:100%;height:auto}</style></head><body>$s</body></html>';
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: widget.aspectRatio,
    child: IgnorePointer(child: WebViewWidget(controller: _ctrl)),
  );
}

Widget _failedImage(BuildContext context, String url) {
  final hasExt = RegExp(
    r'\.(png|jpe?g|gif|webp|bmp|avif|svg)(\?|$)',
    caseSensitive: false,
  ).hasMatch(url);

  if (!hasExt) return _WebImage(url);

  return Tooltip(
    preferBelow: false,
    message: 'Can\'t load image',
    child: Icon(Icons.broken_image_outlined, size: 40, color: ColorScheme.of(context).onError),
  );
}

class _WebImage extends StatefulWidget {
  const _WebImage(this.url);

  final String url;

  @override
  State<_WebImage> createState() => _WebImageState();
}

class _WebImageState extends State<_WebImage> {
  late final _ctrl = WebViewController()
    ..setJavaScriptMode(.disabled)
    ..setBackgroundColor(Colors.transparent)
    ..loadHtmlString(
      '<body style="margin:0"><img style ="width:100%" '
      'src="${const HtmlEscape(HtmlEscapeMode.attribute).convert(widget.url)}"></body>',
      baseUrl: 'https://anilist.co/',
    );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 200,
    child: IgnorePointer(child: WebViewWidget(controller: _ctrl)),
  );
}

class _Spoiler extends StatefulWidget {
  const _Spoiler(this.html);

  final String html;

  @override
  State<_Spoiler> createState() => _SpoilerState();
}

class _SpoilerState extends State<_Spoiler> {
  static final _imgSrc = RegExp(r'''<img[^>]+src\s*=\s*["']([^"']+)["']''', caseSensitive: false);

  bool _open = false;
  bool _loading = false;

  Future<void> _toggle() async {
    if (_loading) return;
    if (_open) {
      setState(() => _open = false);
      return;
    }

    final urls = {
      for (final m in _imgSrc.allMatches(widget.html))
        if (m[1]!.startsWith('http')) MediaLoader.normalize(m[1]!.replaceAll('&amp;', '&')),
    };
    final missing = urls.where((u) => MediaLoader.instance.peek(u) == null).toList();

    if (missing.isNotEmpty) {
      setState(() => _loading = true);
      await MediaLoader.instance.prefetch(missing);
      if (!mounted) return;
    }

    setState(() {
      _loading = false;
      _open = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Align(
          alignment: .centerLeft,
          child: TextButton.icon(
            onPressed: _toggle,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Icon(_open ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
            label: Text(_open ? l10n.actionSpoilersHide : l10n.actionSpoilersShow),
          ),
        ),
        if (_open)
          Container(
            padding: const .only(left: Theming.offset),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: ColorScheme.of(context).outlineVariant, width: 3),
              ),
            ),
            child: HtmlContent(widget.html),
          ),
      ],
    );
  }
}
