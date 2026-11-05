import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../celaut/chat_backgrounds.dart';

/// A rounded, translucent and blurred surface that floats over the chat: the header and
/// the input bar. The messages scroll behind it.
class FloatingSurface extends StatelessWidget {
  const FloatingSurface({super.key, required this.child, this.radius = 28});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(color: scheme.shadow.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: scheme.surface.withValues(alpha: 0.72),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The background of a chat, from the choice of the user for the instance.
class ChatBackdrop extends StatelessWidget {
  const ChatBackdrop({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: RepaintBoundary(
        child: CustomPaint(
          key: const Key('chat-background'),
          painter: ChatBackgroundPainter(id, dark),
        ),
      ),
    );
  }
}

/// Reports the height of its child after each layout, so the list can leave room for a
/// bar that floats over it and changes its height (a longer text, a file, an error).
class MeasureHeight extends StatefulWidget {
  const MeasureHeight({super.key, required this.onHeight, required this.child});

  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  State<MeasureHeight> createState() => _MeasureHeightState();
}

class _MeasureHeightState extends State<MeasureHeight> {
  double? _last;

  void _measure() {
    if (!mounted) return;
    final h = context.size?.height;
    if (h != null && h != _last) {
      _last = h;
      widget.onHeight(h);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    // The child can change its height without this widget building again (an
    // [AnimatedSize] that closes the keyboard of the app does it on each frame of its
    // animation): the notifier tells of every change of the size, so the list below
    // always has the real height and does not leave a blank where the keyboard was.
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
        return false;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}
