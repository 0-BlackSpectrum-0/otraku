import 'package:material_ui/material_ui.dart';
import 'package:otraku/extension/scroll_controller_extension.dart';

class HidingBar extends StatefulWidget implements PreferredSizeWidget {
  const HidingBar({required this.child, required this.scrollCtrl});

  final PreferredSizeWidget child;
  final ScrollController scrollCtrl;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  State<HidingBar> createState() => _HidingBarState();
}

class _HidingBarState extends State<HidingBar> with SingleTickerProviderStateMixin {
  late final AnimationController _animationCtrl;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  void _visibility() {
    switch (widget.scrollCtrl.barsVisibility) {
      case null:
        break;
      case true:
        _animationCtrl.forward();
      case false:
        _animationCtrl.reverse();
    }
  }

  @override
  void initState() {
    super.initState();
    widget.scrollCtrl.addListener(_visibility);

    _animationCtrl = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
      value: 1,
    );
    final curved = CurvedAnimation(
      parent: _animationCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _slideAnimation = Tween(begin: const Offset(0, -1), end: Offset.zero).animate(curved);
    _fadeAnimation = curved;
  }

  @override
  void dispose() {
    widget.scrollCtrl.removeListener(_visibility);
    _animationCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HidingBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.scrollCtrl != oldWidget.scrollCtrl) {
      oldWidget.scrollCtrl.removeListener(_visibility);
      widget.scrollCtrl.addListener(_visibility);
      _animationCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationCtrl,
      builder: (context, child) =>
          IgnorePointer(ignoring: _animationCtrl.value < 0.5, child: child),
      child: RepaintBoundary(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(opacity: _fadeAnimation, child: widget.child),
        ),
      ),
    );
  }
}
