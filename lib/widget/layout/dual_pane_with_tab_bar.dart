import 'package:material_ui/material_ui.dart';
import 'package:otraku/util/theming.dart';

/// Two panes side by side, the left with capped width.
/// There's a tab bar over the right one.
class DualPaneWithTabBar extends StatelessWidget {
  const DualPaneWithTabBar({
    this.tabs,
    this.tabCtrl,
    this.scrollToTop,
    this.tabBar,
    required this.leftPane,
    required this.rightPane,
  }) : assert(tabBar != null || (tabs != null && tabCtrl != null && scrollToTop != null));

  final List<Tab>? tabs;
  final TabController? tabCtrl;
  final void Function()? scrollToTop;
  final Widget? tabBar;
  final Widget leftPane;
  final Widget rightPane;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top + Theming.normalTapTarget;

    return Row(
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Theming.windowWidthMedium),
            child: leftPane,
          ),
        ),
        Flexible(
          child: Stack(
            children: [
              MediaQuery(
                data: mediaQuery.copyWith(padding: mediaQuery.padding.copyWith(top: topPadding)),
                child: rightPane,
              ),
              Align(
                alignment: .topCenter,
                child: ClipRect(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).navigationBarTheme.backgroundColor,
                    ),
                    child: SizedBox(
                      height: topPadding,
                      child: Align(
                        alignment: .bottomCenter,
                        child: Material(
                          color: Colors.transparent,
                          child:
                              tabBar ??
                              TabBar(
                                isScrollable: true,
                                tabAlignment: .center,
                                splashBorderRadius: Theming.borderRadiusSmall,
                                tabs: tabs!,
                                controller: tabCtrl,
                                onTap: (index) {
                                  if (index == tabCtrl!.index) {
                                    scrollToTop!();
                                  }
                                },
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
