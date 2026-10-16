import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:otraku/localizations/gen.dart';

const _userAgent =
    'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36';

const imageHeaders = {
  'User-Agent': _userAgent,
  'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=1.0',
  'Referer': 'https://anilist.co/',
};

const videoHeaders = {'User-Agent': _userAgent, 'Referer': 'https://anilist.co/'};

/// A custom cache manager is needed to define exact image cap and stale period.
final _cacheManager = CacheManager(
  Config('imageCache', maxNrOfCacheObjects: 1000, stalePeriod: const Duration(days: 10)),
);

/// Erases image cache.
void clearImageCache() => _cacheManager.emptyCache();

CacheManager get imageCacheManager => _cacheManager;

Future<File> getFileFromCacheOrDownload(String url) =>
    _cacheManager.getSingleFile(url, headers: imageHeaders);

/// A [CachedNetworkImage] wrapper that simplifies the interface
/// and uses the custom cache manager, without exposing it.
class CachedImage extends StatelessWidget {
  const CachedImage(
    this.imageUrl, {
    this.fit = .cover,
    this.width = .infinity,
    this.height = .infinity,
    this.fullResolution = false,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final bool fullResolution;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final w = (width != null && width!.isFinite) ? width! : MediaQuery.sizeOf(context).width;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      httpHeaders: imageHeaders,
      memCacheWidth: fullResolution ? null : math.min((w * dpr).round(), 720),
      fit: fit,
      width: width,
      height: height,
      cacheManager: _cacheManager,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 100),
      errorWidget: (context, _, _) => Tooltip(
        preferBelow: false,
        triggerMode: .tap,
        message: AppLocalizations.of(context)!.errorFailedGettingFile,
        child: const Icon(Icons.error_outline_rounded),
      ),
    );
  }
}
