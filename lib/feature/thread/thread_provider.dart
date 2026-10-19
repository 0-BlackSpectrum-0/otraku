import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otraku/extension/future_extension.dart';
import 'package:otraku/feature/thread/thread_model.dart';
import 'package:otraku/feature/viewer/persistence_provider.dart';
import 'package:otraku/feature/viewer/repository_provider.dart';
import 'package:otraku/util/graphql.dart';

final threadProvider = AsyncNotifierProvider.autoDispose.family<ThreadNotifier, Thread, int>(
  ThreadNotifier.new,
);

final _restoredPages = <int, int>{};

void restoredThreadPage(int threadId, int page) => _restoredPages[threadId] = page;

class ThreadNotifier extends AsyncNotifier<Thread> {
  ThreadNotifier(this.arg);

  final int arg;

  @override
  FutureOr<Thread> build() async {
    final page = state.value?.commentPage ?? _restoredPages.remove(arg) ?? 1;

    final data = await ref.read(repositoryProvider).request(GqlQuery.thread, {
      'id': arg,
      'withInfo': true,
      'page': page,
    });

    final options = ref.watch(persistenceProvider.select((s) => s.options));

    return compute(parseThread, (data: data, quality: options.imageQuality));
  }

  var _pageRequest = 0;

  Future<Object?> changePage(int page) async {
    final value = state.value;
    if (value == null) return null;

    final request = ++_pageRequest;
    state = const AsyncValue.loading();

    try {
      final data = await ref.read(repositoryProvider).request(GqlQuery.thread, {
        'id': arg,
        'page': page,
      });
      final next = await compute(parseThreadPage, (info: value.info, data: data));

      if (ref.mounted && request == _pageRequest) state = AsyncValue.data(next);
      return null;
    } catch (e) {
      // Keep showing the old page instead of spinning forever.
      if (ref.mounted && request == _pageRequest) state = AsyncValue.data(value);
      return e;
    }
  }

  void appendComment(Map<String, dynamic> map, int? parentCommentId) {
    final value = state.value;
    if (value == null) return;

    // If there's a new thread comment, it can only appear on the last page.
    if (parentCommentId == null && value.commentPage != value.totalCommentPages) {
      return;
    }

    state = AsyncValue.data(value.withAppendedComment(map, parentCommentId));
  }

  Future<Object?> toggleThreadLike() {
    final value = state.value;
    if (value == null) return Future.value(null);

    return ref.read(repositoryProvider).request(GqlMutation.toggleLike, {
      'id': value.info.id,
      'type': 'THREAD',
    }).getErrorOrNull();
  }

  Future<Object?> toggleCommentLike(int commentId) {
    return ref.read(repositoryProvider).request(GqlMutation.toggleLike, {
      'id': commentId,
      'type': 'THREAD_COMMENT',
    }).getErrorOrNull();
  }

  Future<Object?> toggleThreadSubscription() async {
    final value = state.value;
    if (value == null) return null;

    final info = value.info;
    final prevIsSubscribed = info.isSubscribed;
    info.isSubscribed = !prevIsSubscribed;

    final err = await ref.read(repositoryProvider).request(GqlMutation.toggleThreadSubscription, {
      'id': info.id,
      'subscribe': info.isSubscribed,
    }).getErrorOrNull();

    if (err != null) {
      info.isSubscribed = prevIsSubscribed;
      return err;
    }

    return null;
  }

  Future<Object?> delete() =>
      ref.read(repositoryProvider).request(GqlMutation.deleteThread, {'id': arg}).getErrorOrNull();
}
