import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otraku/feature/forum/forum_provider.dart';
import 'package:otraku/feature/forum/forum_top_bar.dart';
import 'package:otraku/feature/forum/thread_item_list.dart';
import 'package:otraku/feature/viewer/persistence_provider.dart';
import 'package:otraku/util/paged_controller.dart';
import 'package:otraku/widget/layout/adaptive_scaffold.dart';
import 'package:otraku/widget/layout/top_bar.dart';
import 'package:otraku/widget/paged_view.dart';

class ForumView extends ConsumerStatefulWidget {
  const ForumView();

  @override
  ConsumerState<ForumView> createState() => _ForumViewState();
}

class _ForumViewState extends ConsumerState<ForumView> {
  late final _scrollCtrl = PagedController(
    loadMore: () => ref.read(forumProvider.notifier).fetch(),
  );

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      topBar: TopBar(trailing: const [ForumTopBarTrailingContent()]),
      child: ForumSubview(_scrollCtrl),
    );
  }
}

class ForumSubview extends StatelessWidget {
  const ForumSubview(this.scrollCtrl);
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final options = ref.watch(persistenceProvider.select((s) => s.options));

        return PagedView(
          provider: forumProvider,
          scrollCtrl: scrollCtrl,
          onRefresh: (invalidate) => invalidate(forumProvider),
          onData: (data) => ThreadItemList(data.items, options.highContrast, options.analogClock),
        );
      },
    );
  }
}
