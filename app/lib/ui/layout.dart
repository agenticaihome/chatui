import 'package:flutter/material.dart';

/// The layout of the app for the size of its window, after the window size classes of
/// Material 3: a phone held upright is compact, a phone on its side or a small tablet is
/// medium, a tablet on its side or a desktop window is expanded.
///
/// - From [medium] width the tabs of the home screen are a rail on the side, not a bar at
///   the bottom: a phone on its side has little height, and a bar would take a part of it.
/// - From [expanded] width, with at least [twoPaneMinHeight] of height, the chats show the
///   list and the open conversation side by side, as a messenger on a tablet or a desktop.
///   A phone on its side is wide enough but too short: its conversation keeps the whole
///   window.
/// - Text and forms never grow wider than [readable] ([ReadableWidth]): a line that spans a
///   whole tablet is hard to read.
abstract final class AppLayout {
  static const medium = 600.0;
  static const expanded = 840.0;
  static const twoPaneMinHeight = 480.0;
  static const readable = 760.0;

  /// The width of the list of chats next to an open conversation.
  static const listPaneWidth = 360.0;

  /// Under this height the window is short (a phone on its side): what the app draws at
  /// the bottom, as its own keyboard, takes less room.
  static const shortHeight = 500.0;

  /// The tabs of the home screen are a rail on the side.
  static bool rail(BuildContext context) => MediaQuery.sizeOf(context).width >= medium;

  /// The list of chats and the open conversation show side by side.
  static bool twoPane(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= expanded && size.height >= twoPaneMinHeight;
  }

  /// The window is short: a phone on its side.
  static bool short(BuildContext context) => MediaQuery.sizeOf(context).height < shortHeight;

  /// The room on each side of a [ReadableWidth] of [maxWidth] in [width].
  static double readableSide(double width, [double maxWidth = readable]) =>
      width.isFinite && width > maxWidth ? (width - maxWidth) / 2 : 0;
}

/// [child] at most [maxWidth] wide, in the middle of the space it has. The space on its
/// sides stays the ground of the page, so a page on a wide window reads as a column.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child, this.maxWidth = AppLayout.readable});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Padding keeps the height that the page gives, tight or loose; and the same tree
        // at any width keeps the state of the page when the window changes.
        final side = AppLayout.readableSide(box.maxWidth, maxWidth);
        return Padding(padding: EdgeInsets.symmetric(horizontal: side), child: child);
      },
    );
  }
}
