import 'package:flutter/material.dart';
import 'package:otraku/util/theming.dart';

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({
    required this.selected,
    required this.items,
    required this.selectedItems,
    required this.onChanged,
    required this.onSame,
    this.scrollCtrl,
  });

  final int selected;
  final Map<String, IconData> items;
  final Map<String, IconData>? selectedItems;
  final void Function(int) onChanged;
  final void Function(int) onSame;
  final ScrollController? scrollCtrl;

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> with SingleTickerProviderStateMixin {
  late int _selected = widget.selected;
  late final AnimationController _animationCtrl;
  late final Animation<Offset> _slideAnimation;
  var _lastOffset = 0.0;

  void _onScroll() {
    final ctrl = widget.scrollCtrl;
    if (ctrl == null || ctrl.positions.isEmpty) return;
    final pos = ctrl.positions.last;
    final dif = pos.pixels - _lastOffset;

    if (dif > 15 || pos.pixels > pos.maxScrollExtent) {
      _lastOffset = pos.pixels;
      _animationCtrl.reverse();
    } else if (dif < -15 || pos.pixels < pos.minScrollExtent) {
      _lastOffset = pos.pixels;
      _animationCtrl.forward();
    }
  }

  @override
  void initState() {
    super.initState();
    _animationCtrl = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnimation = Tween(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationCtrl, curve: Curves.easeOut));

    widget.scrollCtrl?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant BottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selected = widget.selected;
    if (widget.scrollCtrl != oldWidget.scrollCtrl) {
      oldWidget.scrollCtrl?.removeListener(_onScroll);
      widget.scrollCtrl?.addListener(_onScroll);
      _animationCtrl.forward(); // show when switching tabs
    }
  }

  @override
  void dispose() {
    widget.scrollCtrl?.removeListener(_onScroll);
    _animationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 12, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
        child: NavigationBar(
          backgroundColor: ColorScheme.of(context).surface,
          height: BottomBar.height + Theming.offset,
          selectedIndex: _selected,
          indicatorColor: Colors.transparent,
          indicatorShape: const CircleBorder(),
          labelBehavior: .onlyShowSelected,
          onDestinationSelected: (i) {
            if (_selected == i) {
              widget.onSame(i);
            } else {
              setState(() => _selected = i);
              widget.onChanged(_selected);
            }
          },
          destinations: [
            for (final e in widget.items.entries)
              NavigationDestination(
                label: e.key,
                icon: Icon(e.value, color: ColorScheme.of(context).onSurfaceVariant),
                selectedIcon: Icon(
                  widget.selectedItems?[e.key] ?? e.value,
                  color: ColorScheme.of(context).primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SideNavigation extends StatefulWidget {
  const SideNavigation({
    required this.selected,
    required this.items,
    this.selectedItems,
    required this.onChanged,
    required this.onSame,
  });

  final int selected;
  final Map<String, IconData> items;
  final Map<String, IconData>? selectedItems;
  final void Function(int) onChanged;
  final void Function(int) onSame;

  @override
  State<SideNavigation> createState() => _SideNavigationState();
}

class _SideNavigationState extends State<SideNavigation> {
  late int _selected = widget.selected;

  @override
  void didUpdateWidget(covariant SideNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    final rail = NavigationRail(
      elevation: 3.0,
      groupAlignment: -1,
      useIndicator: false,
      labelType: .selected,
      scrollable: true,
      selectedIndex: _selected,
      onDestinationSelected: (i) {
        if (_selected == i) {
          widget.onSame(i);
        } else {
          _selected = i;
          widget.onChanged(_selected);
        }
      },
      destinations: [
        for (final e in widget.items.entries)
          NavigationRailDestination(
            padding: const EdgeInsets.symmetric(vertical: 8),
            label: Text(e.key),
            icon: Icon(e.value, color: ColorScheme.of(context).onSurfaceVariant),
            selectedIcon: Icon(
              widget.selectedItems?[e.key] ?? e.value,
              color: ColorScheme.of(context).primary,
            ),
          ),
      ],
    );

    return ClipRect(child: rail);
  }
}

class BottomBar extends StatelessWidget {
  const BottomBar(this.items);

  final List<Widget> items;

  static const height = 60.0;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: Theming.blurFilter,
        child: SizedBox(
          height: height + bottomPadding,
          child: Material(
            elevation: 3,
            color: Theme.of(context).navigationBarTheme.backgroundColor,
            surfaceTintColor: ColorScheme.of(context).surfaceTint,
            shadowColor: Colors.transparent,
            child: Padding(
              padding: .only(bottom: bottomPadding),
              child: Row(mainAxisAlignment: .spaceEvenly, children: items),
            ),
          ),
        ),
      ),
    );
  }
}

class BottomBarButton extends StatelessWidget {
  const BottomBarButton({
    required this.text,
    required this.icon,
    required this.onTap,
    this.foregroundColor,
  });

  final String text;
  final IconData icon;
  final void Function() onTap;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: Theming.offset),
      child: TextButton.icon(
        label: Text(text),
        icon: Icon(icon),
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
          iconColor: foregroundColor,
          iconSize: Theming.iconBig,
        ),
      ),
    );
  }
}
