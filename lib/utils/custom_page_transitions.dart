import 'package:flutter/material.dart';

class CustomPageTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Zoom in animation for entering page
    const curve = Curves.easeOutCubic;
    
    // Scale from 0.85 to 1.0 (zoom in effect)
    final scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).chain(CurveTween(curve: curve)).animate(animation);
    
    // Fade in from 0 to 1
    final fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: curve,
    );
    
    // Secondary animation for the page being covered (zoom out slightly)
    final secondaryScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).chain(CurveTween(curve: curve)).animate(secondaryAnimation);
    
    final secondaryFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).chain(CurveTween(curve: curve)).animate(secondaryAnimation);

    return FadeTransition(
      opacity: secondaryFadeAnimation,
      child: ScaleTransition(
        scale: secondaryScaleAnimation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        ),
      ),
    );
  }
}

// Custom route for article detail page with shared element transition
class HeroDialogRoute<T> extends PageRoute<T> {
  HeroDialogRoute({
    required this.builder,
    this.barrierLabel,
    this.barrierColor = Colors.black54,
    this.maintainState = true,
  }) : super();

  final WidgetBuilder builder;
  final Color barrierColor;
  final String? barrierLabel;
  final bool maintainState;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      ),
      child: child,
    );
  }
}