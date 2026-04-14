import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:ionicons/ionicons.dart';
import 'package:otraku/extension/snack_bar_extension.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/cached_image.dart';
import 'package:otraku/widget/html_content.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:video_player/video_player.dart';

class TextInputDialog extends StatefulWidget {
  const TextInputDialog({required this.title, required this.initialValue, this.validator});

  final String title;
  final String initialValue;
  final String? Function(String)? validator;

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  late final _textCtrl = TextEditingController(text: widget.initialValue);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          autofocus: true,
          controller: _textCtrl,
          decoration: InputDecoration(
            isDense: true,
            hint: const Text('Enter'),
            hintStyle: TextStyle(color: ColorScheme.of(context).onSurfaceVariant),
            border: const OutlineInputBorder(borderRadius: Theming.borderRadiusSmall),
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) {
              return 'The field cannot be empty.';
            }

            if (widget.validator != null) {
              return widget.validator!(text);
            }

            return null;
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _textCtrl.text.trim());
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

// A basic container for a dialog.
class DialogBox extends StatelessWidget {
  const DialogBox(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const .symmetric(horizontal: 30, vertical: 50),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: child,
      ),
    );
  }
}

class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog._({
    required this.title,
    required this.content,
    required this.primaryAction,
    required this.secondaryAction,
  });

  final String title;
  final String? content;
  final String primaryAction;
  final String? secondaryAction;

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? content,
    String primaryAction = 'Ok',
    String? secondaryAction,
    void Function()? onConfirm,
  }) => showDialog(
    context: context,
    builder: (context) => ConfirmationDialog._(
      title: title,
      content: content,
      primaryAction: primaryAction,
      secondaryAction: secondaryAction,
    ),
  ).then((ok) => ok == true ? onConfirm?.call() : null);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: content != null ? Text(content!) : null,
      actions: [
        if (secondaryAction != null)
          TextButton(child: Text(secondaryAction!), onPressed: () => Navigator.pop(context, false)),
        TextButton(child: Text(primaryAction), onPressed: () => Navigator.pop(context, true)),
      ],
    );
  }
}

class ImageDialog extends StatefulWidget {
  const ImageDialog(this.url);

  final String url;

  @override
  State<ImageDialog> createState() => _ImageDialogState();
}

class _ImageDialogState extends State<ImageDialog> with SingleTickerProviderStateMixin {
  final _transformCtrl = TransformationController();
  late final AnimationController _animationCtrl;
  late final CurvedAnimation _curveWrapper;
  Animation<Matrix4>? _animation;

  /// Last place the user double-tapped on.
  Offset? _lastOffset;

  @override
  void initState() {
    super.initState();
    _animationCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _curveWrapper = CurvedAnimation(parent: _animationCtrl, curve: Curves.easeOutExpo);
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    _animationCtrl.dispose();
    super.dispose();
  }

  void _updateState() => _transformCtrl.value = _animation!.value;

  void _endAnimation() {
    _animation?.removeListener(_updateState);
    _animation = null;
    _animationCtrl.reset();
  }

  void _animateMatrixTo(Matrix4 goal) {
    _endAnimation();
    _animation = Matrix4Tween(begin: _transformCtrl.value, end: goal).animate(_curveWrapper);
    _animation!.addListener(_updateState);
    _animationCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: .zero,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: GestureDetector(
        onDoubleTapDown: (details) => _lastOffset = details.localPosition,
        onDoubleTap: () {
          // If zoomed in, zoom out.
          if (_transformCtrl.value.getMaxScaleOnAxis() > 1) {
            _animateMatrixTo(Matrix4.identity());
            return;
          }

          // Can't be null, but checking just in case.
          if (_lastOffset == null) return;

          // If zoomed out, zoom in towards the tapped spot.
          final zoomed = _transformCtrl.value.clone();
          zoomed.translateByVector3(Vector3(-_lastOffset!.dx, -_lastOffset!.dy, 0));
          zoomed.scaleByVector3(Vector3(2.0, 2.0, 1.0));
          _animateMatrixTo(zoomed);
        },
        child: InteractiveViewer(
          clipBehavior: Clip.none,
          transformationController: _transformCtrl,
          child: CachedImage(widget.url, fit: BoxFit.contain, width: null, height: null),
        ),
      ),
    );
  }
}

class TextDialog extends StatelessWidget {
  const TextDialog({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => _DialogColumn(title: title, child: SelectableText(text));
}

class HtmlDialog extends StatelessWidget {
  const HtmlDialog({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => _DialogColumn(title: title, child: HtmlContent(text));
}

class _DialogColumn extends StatelessWidget {
  const _DialogColumn({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DialogBox(
      Padding(
        padding: const .symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            Padding(
              padding: const .symmetric(vertical: Theming.offset),
              child: Text(title, style: TextTheme.of(context).bodyMedium),
            ),
            const Divider(height: 2, thickness: 2),
            Flexible(
              fit: FlexFit.loose,
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const .symmetric(vertical: Theming.offset),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoDialog extends StatefulWidget {
  const VideoDialog(this.url);

  final String url;

  @override
  State<VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<VideoDialog> {
  late final VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller.play();
        _controller.setVolume(1);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: .zero,
      backgroundColor: ColorScheme.of(context).surface.withAlpha(125),
      surfaceTintColor: Colors.transparent,
      child: GestureDetector(
        behavior: .opaque,
        onTap: () => Navigator.pop(context),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            children: [
              Center(
                child: GestureDetector(
                  onTap: () {
                    _controller.value.isPlaying ? _controller.pause() : _controller.play();
                    setState(() {});
                  },
                  child: !_initialized
                      ? const CircularProgressIndicator()
                      : AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                ),
              ),
              //play pause
              if (_initialized)
                Center(
                  child: IgnorePointer(
                    child: ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (context, value, _) => AnimatedOpacity(
                        opacity: value.isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 64,
                          color: ColorScheme.of(context).onSurface.withAlpha(200),
                        ),
                      ),
                    ),
                  ),
                ),
              // Slider
              Align(
                alignment: .bottomCenter,
                child: Padding(
                  padding: .all(Theming.offset * 2),
                  child: Column(
                    mainAxisSize: .min,
                    children: [
                      if (_initialized)
                        ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, value, _) {
                            final pos = value.position.inMilliseconds.toDouble();
                            final dur = value.duration.inMilliseconds.toDouble();
                            return Slider(
                              value: pos.clamp(0, dur > 0 ? dur : 1),
                              min: 0,
                              max: dur > 0 ? dur : 1,
                              onChanged: (v) =>
                                  _controller.seekTo(Duration(milliseconds: v.round())),
                            );
                          },
                        ),
                      const SizedBox(height: 8),
                      Row(
                        spacing: Theming.offset,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: ColorScheme.of(context).onSurface.withAlpha(125),
                              borderRadius: Theming.borderRadiusSmall,
                            ),
                            child: IconButton(
                              color: ColorScheme.of(context).onPrimary,
                              tooltip: 'Close',
                              icon: const Icon(Ionicons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const Spacer(),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: ColorScheme.of(context).onSurface.withAlpha(125),
                              borderRadius: Theming.borderRadiusSmall,
                            ),
                            child: IconButton(
                              color: ColorScheme.of(context).onPrimary,
                              tooltip: 'Download',
                              icon: const Icon(Icons.download_outlined),
                              onPressed: () => _saveVideo(context),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: ColorScheme.of(context).onSurface.withAlpha(125),
                              borderRadius: Theming.borderRadiusSmall,
                            ),
                            child: PopupMenuButton<String>(
                              shape: RoundedRectangleBorder(
                                borderRadius: Theming.borderRadiusSmall,
                              ),
                              tooltip: 'More',
                              iconColor: ColorScheme.of(context).onPrimary,
                              color: ColorScheme.of(context).surface,
                              elevation: 3,
                              icon: const Icon(Ionicons.ellipsis_vertical),
                              offset: const Offset(0, -200),
                              onSelected: (result) async {
                                switch (result) {
                                  case 'copy':
                                    SnackBarExtension.copy(context, widget.url);
                                    Navigator.pop(context);
                                  case 'browser':
                                    launchUrl(
                                      Uri.parse(widget.url),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  case 'share':
                                    final file = await DefaultCacheManager().getSingleFile(
                                      widget.url,
                                    );
                                    final fileName = _getVideoFileName(widget.url);
                                    final temp = File(
                                      '${(await getTemporaryDirectory()).path}/$fileName',
                                    );
                                    await file.copy(temp.path);
                                    await SharePlus.instance.share(
                                      ShareParams(files: [XFile(temp.path)]),
                                    );
                                    await temp.delete();
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'copy',
                                  child: ListTile(
                                    leading: Icon(Ionicons.clipboard_outline),
                                    title: Text('Copy URL'),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'browser',
                                  child: ListTile(
                                    leading: Icon(Ionicons.link_outline),
                                    title: Text('Open in Browser'),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'share',
                                  child: ListTile(
                                    leading: Icon(Ionicons.share_outline),
                                    title: Text('Share Video'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveVideo(BuildContext context) async {
    try {
      final file = await DefaultCacheManager().getSingleFile(widget.url);
      final fileName = _getVideoFileName(widget.url);
      final Directory dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) await dir.create(recursive: true);
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final dotIndex = fileName.lastIndexOf('.');
      final name = dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;
      final ext = dotIndex != -1 ? fileName.substring(dotIndex) : '';

      int i = 0;
      while (true) {
        final destPath = i == 0 ? '${dir.path}/$fileName' : '${dir.path}/$name($i)$ext';
        try {
          await file.copy(destPath);
          break;
        } on FileSystemException catch (e) {
          if (e.osError?.errorCode == 17) {
            i++;
          } else {
            rethrow;
          }
        }
      }

      if (context.mounted) {
        Navigator.pop(context);
        SnackBarExtension.show(
          context,
          Platform.isAndroid ? 'Saved to Downloads' : 'Saved to Documents',
        );
      }
    } catch (e) {
      final osError = e is FileSystemException ? e.osError : null;
      final message = osError != null
          ? '${osError.message}, errno = ${osError.errorCode}'
          : e.toString();
      if (context.mounted) {
        Navigator.pop(context);
        SnackBarExtension.show(context, 'Failed to save : $message');
      }
    }
  }

  String _getVideoFileName(String url) {
    final name = Uri.parse(url).pathSegments.last;
    if (name.endsWith('gifv')) return name.replaceAll('.gifv', '.mp4');
    if (name.contains('.')) return name;
    return '$name.mp4';
  }
}
