import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otraku/feature/media/media_models.dart';
import 'package:otraku/feature/viewer/persistence_provider.dart';

final mediaTabOrderProvider = NotifierProvider<MediaTabOrderNotifier, List<MediaTab>>(
  MediaTabOrderNotifier.new,
);

//Order all the tabs except overview
class MediaTabOrderNotifier extends Notifier<List<MediaTab>> {
  @override
  List<MediaTab> build() {
    final saved = ref
        .read(persistenceProvider.notifier)
        .mediaTabOrder
        .map((n) => MediaTab.values.where((t) => t.name == n).firstOrNull)
        .whereType<MediaTab>()
        .where((t) => t != MediaTab.info)
        .toSet()
        .toList();

    for (final t in MediaTab.values) {
      if (t != MediaTab.info && !saved.contains(t)) saved.add(t);
    }
    return saved;
  }

  //puts tab in different position
  void move(MediaTab tab, MediaTab target) {
    final list = [...state]..remove(tab);
    list.insert(state.indexOf(target), tab);
    state = list;
    ref.read(persistenceProvider.notifier).setMediaTabOrder(list.map((t) => t.name).toList());
  }
}
