import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otraku/feature/viewer/repository_provider.dart';
import 'package:otraku/util/graphql.dart';

enum LikeableType { activity, reply, thread, comment }

typedef LikesTag = ({int id, LikeableType type, int? rootId});
typedef LikeUser = ({int id, String name, String avatarUrl});

void _log(String msg) => debugPrint('[likes] $msg');

Map? _findComment(Object? node, int id) {
  if (node is List) {
    for (final c in node) {
      final found = _findComment(c, id);
      if (found != null) return found;
    }
  } else if (node is Map) {
    if (node['id'] == id) return node;
    return _findComment(node['childComments'], id);
  }
  return null;
}

final likesProvider = FutureProvider.autoDispose.family<List<LikeUser>, LikesTag>((ref, tag) async {
  final repo = ref.read(repositoryProvider);

  Future<Map?> fetchComment(int id) async {
    final data = await repo.request(GqlQuery.commentLikes, {'id': id});
    final root = data['ThreadComment'];
    final first = root is List ? root.firstOrNull : root;
    return first is Map ? first : null;
  }

  List? likes;

  if (tag.type == LikeableType.comment) {
    // Asking for a reply's id returns its parent (without replies), and asking
    // for the parent's id returns the parent with its reply tree. So walk up
    // until the tree containing the requested comment is found.
    Map? node;
    var lookupId = tag.rootId ?? tag.id;
    for (var i = 0; i < 8; i++) {
      final root = await fetchComment(lookupId);
      _log(
        'lookup=$lookupId -> id=${root?['id']} '
        'childComments=${root?['childComments'].runtimeType}',
      );
      if (root == null) break;

      node = _findComment(root, tag.id);
      if (node != null) break;

      final next = root['id'];
      if (next is! int || next == lookupId) break;
      lookupId = next;
    }

    _log('found=${node != null} likes=${node?['likes']}');
    likes = node?['likes'];
  } else {
    final data = await repo.request(GqlQuery.likes, {'id': tag.id, tag.type.name: true});
    likes = switch (tag.type) {
      .activity => data['Activity']?['likes'],
      .thread => data['Thread']?['likes'],
      .reply => (data['repliesPage']?['activityReplies'] as List?)?.firstOrNull?['likes'],
      .comment => null,
    };
  }

  if (likes == null || likes.isEmpty) return const [];

  //Fallback for avatars if it returns none
  final avatars = <int, String>{};
  final missing = <int>{
    for (final u in likes)
      if (u['avatar']?['large'] == null) u['id'] as int,
  };
  _log('likes=${likes.length} missingAvatars=${missing.length}');

  if (missing.isNotEmpty) {
    try {
      final query =
          'query {${[for (final id in missing) 'u$id: User(id: $id) {avatar {large}}'].join(' ')}}';
      final res = await repo.request(query, const {});
      for (final id in missing) {
        final url = res['u$id']?['avatar']?['large'];
        if (url is String) avatars[id] = url;
      }
    } catch (e) {
      _log('avatar lookup failed: $e');
    }
  }
  return [
    for (final u in likes)
      (
        id: u['id'] as int,
        name: u['name'] as String,
        avatarUrl: (u['avatar']?['large'] as String?) ?? avatars[u['id'] as int] ?? '',
      ),
  ];
});
