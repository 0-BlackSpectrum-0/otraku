import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:otraku/widget/cached_image.dart';

class ResolvedImage {
  ResolvedImage({required this.url, this.file, this.svg}) : at = DateTime.now();

  final String url;
  final File? file;
  final String? svg;
  final DateTime at;

  bool get isSvg => svg != null;
}

class MediaRequest {
  const MediaRequest({required this.isAlive, required this.bounds});

  final bool Function() isAlive;
  final ({double top, double bottom})? Function() bounds;
}

bool _always() => true;
({double top, double bottom})? _onScreen() => (top: 0, bottom: 1);

class _Job {
  _Job(this.url);

  final String url;
  final completer = Completer<ResolvedImage>();
  final requests = <MediaRequest>[];
}

class MediaLoader {
  MediaLoader._();
  static final instance = MediaLoader._();

  static const _maxParallel = 4;
  static const _svgTtl = Duration(minutes: 1);

  final _memory = <String, ResolvedImage>{};
  final _jobs = <String, _Job>{};
  final _queue = <_Job>[];
  var _running = 0;
  var _pumpScheduled = false;

  static String normalize(String url) {
    final u = url.trim();
    return u.startsWith('http://') ? 'https://${u.substring(7)}' : u;
  }

  ResolvedImage? peek(String url) {
    final r = _memory[url];
    if (r == null) return null;

    if (r.isSvg && DateTime.now().difference(r.at) > _svgTtl) {
      _memory.remove(url);
      return null;
    }
    return r;
  }

  void clearMemory() => _memory.clear();

  Future<ResolvedImage> load(String url, MediaRequest request) {
    final hit = peek(url);
    if (hit != null) return Future.value(hit);

    var job = _jobs[url];
    if (job == null) {
      job = _Job(url);
      job.completer.future.ignore();
      _jobs[url] = job;
      _queue.add(job);
    }
    job.requests.add(request);
    _schedulePump();
    return job.completer.future;
  }

  Future<void> prefetch(Iterable<String> urls) async {
    const request = MediaRequest(isAlive: _always, bounds: _onScreen);
    await Future.wait<void>(
      urls.map((u) => load(u, request).then((_) {}, onError: (_) {})),
    ).timeout(const Duration(seconds: 25), onTimeout: () => const <void>[]);
  }

  void _schedulePump() {
    if (_pumpScheduled) return;
    _pumpScheduled = true;
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      _pumpScheduled = false;
      _pump();
    });
    binding.ensureVisualUpdate();
  }

  void _pump() {
    _queue.removeWhere((job) {
      final dead = !job.requests.any((r) => r.isAlive());
      if (dead) _jobs.remove(job.url);
      return dead;
    });
    while (_running < _maxParallel && _queue.isNotEmpty) {
      final height = _viewportHeight();
      var best = _queue.first;
      var bestScore = _score(best, height);
      for (final job in _queue.skip(1)) {
        final s = _score(job, height);
        if (s < bestScore) {
          best = job;
          bestScore = s;
        }
      }
      _queue.remove(best);
      _running++;
      _run(best).whenComplete(() {
        _running--;
        _schedulePump();
      });
    }
  }

  double _viewportHeight() {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    return view == null ? 800 : view.physicalSize.height / view.devicePixelRatio;
  }

  double _score(_Job job, double height) {
    var best = double.infinity;
    for (final r in job.requests) {
      if (!r.isAlive()) continue;
      final b = r.bounds();
      final double s;
      if (b == null) {
        s = 3e6;
      } else if (b.bottom > 0 && b.top < height) {
        s = math.max(b.top, 0);
      } else if (b.top >= height) {
        s = 1e6 + b.top;
      } else {
        s = 2e6 - b.bottom;
      }
      best = math.min(best, s);
    }
    return best;
  }

  Future<void> _run(_Job job) async {
    try {
      final result = await _resolve(job.url);
      _memory[job.url] = result;
      if (_memory.length > 300) _memory.remove(_memory.keys.first);
      job.completer.complete(result);
    } catch (e, s) {
      job.completer.completeError(e, s);
    } finally {
      _jobs.remove(job.url);
    }
  }

  Future<ResolvedImage> _resolve(String url) async {
    final isGif = Uri.tryParse(url)?.path.toLowerCase().endsWith('.gif') ?? false;
    final proxy =
        'https://wsrv.nl/?url=${Uri.encodeComponent(url)}${isGif ? '' : '&w=1080&we&output=webp&q=80'}';

    Object error = 'Could not load $url';

    for (final candidate in [url, proxy]) {
      try {
        final file = await imageCacheManager
            .getSingleFile(candidate, headers: imageHeaders)
            .timeout(const Duration(seconds: 30));
        final head = await _readHead(file);
        if (_looksLikeSvg(head)) {
          if (await file.length() > 1024 * 1024) throw 'Svg too large';
          final svg = await file.readAsString();

          unawaited(imageCacheManager.removeFile(candidate));
          return ResolvedImage(url: candidate, svg: svg);
        }

        if (await _decodable(file)) return ResolvedImage(url: candidate, file: file);

        await imageCacheManager.removeFile(candidate);
        error = 'Unsupported image data';
      } catch (e) {
        error = e;
      }
    }
    throw error;
  }

  Future<Uint8List> _readHead(File file) async {
    final raf = await file.open();
    try {
      return await raf.read(1024);
    } finally {
      await raf.close();
    }
  }

  bool _looksLikeSvg(Uint8List head) {
    final t = latin1.decode(head).trimLeft().toLowerCase();
    return t.startsWith('<svg') ||
        ((t.startsWith('<?xml') || t.startsWith('<!doctype svg') || t.startsWith('<!--')) &&
            t.contains('<svg'));
  }

  Future<bool> _decodable(File file) async {
    try {
      final codec = await ui.instantiateImageCodec(await file.readAsBytes(), targetWidth: 16);
      codec.dispose();
      return true;
    } catch (_) {
      return false;
    }
  }
}
