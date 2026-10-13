import 'package:flutter/material.dart';
import 'package:otraku/extension/scroll_controller_extension.dart';

/// Hides/Shows [child] on scroll.
class HidingFloatingActionButton extends StatefulWidget {
  const HidingFloatingActionButton({
    required super.key,
    required this.child,
    required this.scrollCtrl,
  });

  final Widget child;
  final ScrollController scrollCtrl;

  @override
  State<HidingFloatingActionButton> createState() => _HidingFloatingActionButtonState();
}

class _HidingFloatingActionButtonState extends State<HidingFloatingActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationCtrl;
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
    _fadeAnimation = curved;
  }

  @override
  void dispose() {
    widget.scrollCtrl.removeListener(_visibility);
    _animationCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HidingFloatingActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.scrollCtrl != oldWidget.scrollCtrl) {
      oldWidget.scrollCtrl.removeListener(_visibility);
      widget.scrollCtrl.addListener(_visibility);
      _animationCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _fadeAnimation,
      child: FadeTransition(opacity: _fadeAnimation, child: widget.child),
    );
  }
}
