import 'dart:async';

import 'package:flutter/material.dart';

class AppMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 360);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubic;

  static final PageTransitionsTheme pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      for (final platform in TargetPlatform.values)
        platform: const _FadeSlidePageTransitionsBuilder(),
    },
  );
}

class AppEntrance extends StatefulWidget {
  const AppEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.medium,
    this.beginOffset = const Offset(0, 0.035),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;

  @override
  State<AppEntrance> createState() => _AppEntranceState();
}

class _AppEntranceState extends State<AppEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.enterCurve,
    );
    _offset = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.enterCurve),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, _controller.forward);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

class AppPulsePlaceholder extends StatefulWidget {
  const AppPulsePlaceholder({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AppPulsePlaceholder> createState() => _AppPulsePlaceholderState();
}

class _AppPulsePlaceholderState extends State<AppPulsePlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.55,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: widget.child);
  }
}

class _FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: AppMotion.enterCurve);
    final offset = Tween<Offset>(
      begin: const Offset(0.03, 0),
      end: Offset.zero,
    ).animate(curved);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(position: offset, child: child),
    );
  }
}