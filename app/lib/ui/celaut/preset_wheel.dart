import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../celaut/service_presets.dart';
import '../../l10n/l10n.dart';
import 'robot_avatar.dart';

/// The size of a slot of the wheel.
const presetSlotSize = 56.0;

/// The width of the name under a slot.
const presetLabelWidth = 76.0;

/// The least distance between the centres of two slots of a ring.
const _minSpacing = 66.0;

/// The radius of the first ring, and the step to the next one.
const _firstRadius = 100.0;
const _ringStep = 78.0;

/// The angles of a ring, from the vertical of the button: the slots are not right on the
/// vertical or the horizontal, so that their names do not leave the screen.
const _firstAngle = 0.10;
const _lastAngle = math.pi / 2 - 0.10;

/// Where the [count] slots of the wheel go, from the centre of the pencil button
/// ([center]), on a screen of [screen] with [padding] (the system bars): rings of a quarter
/// of a circle, towards the middle of the screen (up and to the left for the button at the
/// bottom right). The first slot is the nearest to the vertical of the button, on the first
/// ring; each ring holds as many slots as fit with [_minSpacing] between them. If the rings
/// do not fit on the screen (a phone on its side), they come closer.
List<Offset> presetWheelOffsets(
  int count, {
  required Offset center,
  required Size screen,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  if (count <= 0) return const [];
  final sx = center.dx > screen.width / 2 ? -1.0 : 1.0;
  final sy = center.dy > screen.height / 2 ? -1.0 : 1.0;
  const span = _lastAngle - _firstAngle;
  // The rings: (radius, number of slots).
  // The rings: (radius, number of slots, angle between two slots). A full ring spreads its
  // slots over the quarter; one that is not full keeps them a little apart, from the
  // vertical, so that two slots are not one up and one to the side.
  final rings = <(double, int, double)>[];
  var left = count;
  for (var k = 0; left > 0; k++) {
    final r = _firstRadius + _ringStep * k;
    final fits = (r * span / _minSpacing).floor() + 1;
    final n = math.min(fits, left);
    final step = n == 1 ? 0.0 : math.min(span / (n - 1), _minSpacing * 1.15 / r);
    rings.add((r, n, step));
    left -= n;
  }
  // The room on the screen, from the centre of the button to the edges that the wheel
  // goes to, less half a name and a slot.
  final roomX = sx < 0 ? center.dx - padding.left - presetLabelWidth / 2 : screen.width - center.dx - padding.right - presetLabelWidth / 2;
  final roomY = sy < 0
      ? center.dy - padding.top - presetSlotSize / 2
      : screen.height - center.dy - padding.bottom - presetSlotSize / 2 - 24;
  final room = math.min(roomX, roomY);
  final outer = rings.last.$1;
  final scale = outer > room && room > 0 ? math.max(0.55, room / outer) : 1.0;
  return [
    for (final (r, n, step) in rings)
      for (var i = 0; i < n; i++)
        () {
          final a = n == 1 && rings.length == 1 ? (_firstAngle + _lastAngle) / 2 : _firstAngle + step * i;
          final rr = r * scale;
          return Offset(sx * rr * math.sin(a), sy * rr * math.cos(a));
        }(),
  ];
}

/// What the user chose on the wheel: Objectives (no preset), a preset to start, or a preset to
/// rename or remove ([edit]).
@immutable
class PresetWheelPick {
  const PresetWheelPick.objectives()
      : preset = null,
        edit = false;
  const PresetWheelPick.start(ServicePreset this.preset) : edit = false;
  const PresetWheelPick.edit(ServicePreset this.preset) : edit = true;

  final ServicePreset? preset;
  final bool edit;
}

/// The pencil button of Chats with the wheel of presets (`docs/celaut/presets.md`).
///
/// - Without presets it is the pencil of before: a tap opens the objectives ([onObjectives]).
/// - With presets, a tap opens the wheel over the list: "Objectives" and the presets. A tap on
///   a slot chooses it; a long press on a preset renames or removes it; a tap outside, the
///   close button or Back closes the wheel.
/// - Press and slide: a slide from the button (or a long press) opens the wheel at once;
///   the slot under the finger grows, and letting go on it chooses it. Letting go
///   elsewhere after a slide closes the wheel; a long press without a slide leaves it open
///   for taps.
class PresetWheelButton extends StatefulWidget {
  const PresetWheelButton({
    super.key,
    required this.presets,
    required this.tooltip,
    required this.onObjectives,
    required this.onPreset,
    required this.onEdit,
  });

  final ServicePresets presets;

  /// The tooltip of the button: "New conversation".
  final String tooltip;

  final VoidCallback onObjectives;
  final ValueChanged<ServicePreset> onPreset;
  final ValueChanged<ServicePreset> onEdit;

  @override
  State<PresetWheelButton> createState() => PresetWheelButtonState();
}

class PresetWheelButtonState extends State<PresetWheelButton> with SingleTickerProviderStateMixin {
  final _fab = GlobalKey();
  final _highlight = ValueNotifier<int?>(null);
  late final AnimationController _shown;

  /// The wheel for taps: a route ([open]).
  _PresetWheelRoute? _route;

  /// The wheel under a finger that slides from the button: an entry of the overlay, not a
  /// route, because a new route cancels the pointers that are down (the slide would stop).
  OverlayEntry? _entry;

  /// Where the wheel is while it shows.
  _WheelGeometry? _geometry;
  Offset? _dragFrom;
  bool _slid = false;

  /// The wheel shows.
  bool get isOpen => _route != null || _entry != null;

  @override
  void initState() {
    super.initState();
    _shown = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  }

  @override
  void dispose() {
    _removeEntry();
    _shown.dispose();
    _highlight.dispose();
    super.dispose();
  }

  NavigatorState get _navigator => Navigator.of(context);

  RenderBox? get _overlayBox => _navigator.overlay?.context.findRenderObject() as RenderBox?;

  /// Where the slots go now, or null if the button is not laid out or there is no preset.
  _WheelGeometry? _measure() {
    final presets = widget.presets.presets;
    final overlay = _overlayBox;
    final fab = _fab.currentContext?.findRenderObject() as RenderBox?;
    if (presets.isEmpty || overlay == null || fab == null || !fab.hasSize) return null;
    final rect = fab.localToGlobal(Offset.zero, ancestor: overlay) & fab.size;
    final offsets = presetWheelOffsets(
      presets.length + 1,
      center: rect.center,
      screen: overlay.size,
      padding: MediaQuery.paddingOf(context),
    );
    return _WheelGeometry(rect, [for (final o in offsets) rect.center + o], presets);
  }

  Color get _scrim {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Theme.of(context).colorScheme.scrim.withValues(alpha: dark ? 0.6 : 0.36);
  }

  /// Open the wheel for taps. What the user chooses goes to the callbacks of the widget.
  /// [instant]: no entrance (the wheel of a long press is on the screen already).
  Future<void> open({bool instant = false}) async {
    if (_route != null) return;
    final geometry = _geometry ?? _measure();
    if (geometry == null) {
      widget.onObjectives();
      return;
    }
    _geometry = geometry;
    final route = _route = _PresetWheelRoute(
      geometry: geometry,
      highlight: _highlight,
      barrier: _scrim,
      closeLabel: context.l10n.commonClose,
      instant: instant,
    );
    if (!instant) unawaited(HapticFeedback.selectionClick());
    final pick = await _navigator.push(route);
    _route = null;
    _geometry = null;
    _highlight.value = null;
    if (mounted && pick != null) _choose(pick);
  }

  void _choose(PresetWheelPick pick) {
    final preset = pick.preset;
    if (preset == null) {
      widget.onObjectives();
    } else if (pick.edit) {
      widget.onEdit(preset);
    } else {
      widget.onPreset(preset);
    }
  }

  int? _slotAt(Offset global) {
    final overlay = _overlayBox;
    final geometry = _geometry;
    if (overlay == null || geometry == null) return null;
    final p = overlay.globalToLocal(global);
    int? best;
    var bestDistance = presetSlotSize * 0.8;
    for (var i = 0; i < geometry.centers.length; i++) {
      final d = (geometry.centers[i] - p).distance;
      if (d < bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }

  /// A slide or a long press starts on the button: the wheel shows under the finger.
  void _pressStart(Offset global) {
    if (isOpen) return;
    final geometry = _measure();
    if (geometry == null) return;
    _geometry = geometry;
    _dragFrom = global;
    _slid = false;
    final scrim = _scrim;
    final entry = _entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: _PresetWheelLayer(geometry: geometry, highlight: _highlight, animation: _shown, scrim: scrim),
      ),
    );
    _navigator.overlay!.insert(entry);
    _shown.forward(from: 0);
    unawaited(HapticFeedback.selectionClick());
  }

  void _pressMove(Offset global) {
    if (_entry == null) return;
    final from = _dragFrom;
    if (from != null && (global - from).distance > presetSlotSize / 2) _slid = true;
    final at = _slotAt(global);
    if (at != _highlight.value) {
      _highlight.value = at;
      if (at != null) unawaited(HapticFeedback.selectionClick());
    }
  }

  void _pressEnd() {
    if (_entry == null) return;
    final geometry = _geometry!;
    final at = _highlight.value;
    _removeEntry();
    _dragFrom = null;
    if (at != null) {
      _geometry = null;
      _highlight.value = null;
      _choose(geometry.pickAt(at));
    } else if (_slid) {
      // Let go on nothing after a slide: closed.
      _geometry = null;
      _highlight.value = null;
    } else {
      // A long press without a slide: the wheel stays, for taps.
      unawaited(open(instant: true));
    }
  }

  void _pressCancel() {
    _removeEntry();
    _dragFrom = null;
    if (_route == null) _geometry = null;
    _highlight.value = null;
  }

  void _removeEntry() {
    final entry = _entry;
    _entry = null;
    if (entry == null) return;
    entry.remove();
    entry.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: widget.presets,
      builder: (context, _) {
        final has = !widget.presets.isEmpty;
        // The pencil of before: the same look, with or without presets.
        final fab = FloatingActionButton(
          key: const Key('chats-new'),
          // With presets a long press opens the wheel, so the tooltip (which a long press
          // shows) gives its text to the semantics below.
          tooltip: has ? null : widget.tooltip,
          onPressed: has ? open : widget.onObjectives,
          child: const Icon(Icons.edit_outlined),
        );
        return KeyedSubtree(
          key: _fab,
          child: !has
              ? fab
              : MergeSemantics(
                  child: Semantics(
                    label: widget.tooltip,
                    hint: l.presetWheelHint,
                    child: GestureDetector(
                      onLongPressStart: (d) => _pressStart(d.globalPosition),
                      onLongPressMoveUpdate: (d) => _pressMove(d.globalPosition),
                      onLongPressEnd: (_) => _pressEnd(),
                      onLongPressCancel: _pressCancel,
                      onPanStart: (d) => _pressStart(d.globalPosition),
                      onPanUpdate: (d) => _pressMove(d.globalPosition),
                      onPanEnd: (_) => _pressEnd(),
                      onPanCancel: _pressCancel,
                      child: fab,
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// Where the wheel is: the rectangle of the button and the centres of the slots, in the
/// coordinates of the overlay of the navigator, and the presets of the slots after the
/// first (Objectives).
class _WheelGeometry {
  const _WheelGeometry(this.button, this.centers, this.presets);

  final Rect button;
  final List<Offset> centers;
  final List<ServicePreset> presets;

  PresetWheelPick pickAt(int i) => i == 0 ? const PresetWheelPick.objectives() : PresetWheelPick.start(presets[i - 1]);
}

/// The wheel for taps, as a route over the list: Back and a tap outside close it, and the
/// screen reader reads only the wheel.
class _PresetWheelRoute extends PopupRoute<PresetWheelPick> {
  _PresetWheelRoute({
    required this.geometry,
    required this.highlight,
    required this.barrier,
    required this.closeLabel,
    this.instant = false,
  });

  final _WheelGeometry geometry;
  final ValueNotifier<int?> highlight;
  final Color barrier;
  final String closeLabel;
  final bool instant;

  @override
  Color? get barrierColor => barrier;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => closeLabel;

  @override
  Duration get transitionDuration => instant ? Duration.zero : const Duration(milliseconds: 180);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 120);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final navigator = Navigator.of(context);
    return _PresetWheelLayer(
      geometry: geometry,
      highlight: highlight,
      animation: animation,
      onChoose: (pick) => navigator.pop(pick),
      onClose: () => navigator.pop(),
    );
  }
}

/// The slots of the wheel and the Close button where the pencil is. Without [onChoose] it
/// is the wheel under a finger: it draws its own [scrim] and takes no tap.
class _PresetWheelLayer extends StatelessWidget {
  const _PresetWheelLayer({
    required this.geometry,
    required this.highlight,
    required this.animation,
    this.onChoose,
    this.onClose,
    this.scrim,
  });

  final _WheelGeometry geometry;
  final ValueNotifier<int?> highlight;
  final Animation<double> animation;
  final ValueChanged<PresetWheelPick>? onChoose;
  final VoidCallback? onClose;
  final Color? scrim;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final still = MediaQuery.disableAnimationsOf(context);
    final scheme = Theme.of(context).colorScheme;
    final c = geometry.button.center;
    final choose = onChoose ?? (_) {};
    final close = onClose ?? () {};
    final slots = <Widget>[
      for (var i = 0; i < geometry.centers.length; i++)
        Positioned(
          left: geometry.centers[i].dx - presetLabelWidth / 2,
          top: geometry.centers[i].dy - presetSlotSize / 2,
          width: presetLabelWidth,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              // The slots come out of the button.
              final t = still ? 1.0 : Curves.easeOutBack.transform(animation.value.clamp(0.0, 1.0));
              final from = c - geometry.centers[i];
              return Opacity(
                opacity: animation.value.clamp(0.0, 1.0),
                child: Transform.translate(offset: from * (1 - t), child: child),
              );
            },
            child: ValueListenableBuilder<int?>(
              valueListenable: highlight,
              builder: (context, at, _) {
                final preset = i == 0 ? null : geometry.presets[i - 1];
                return _WheelSlot(
                  key: Key(preset == null ? 'preset-slot-objectives' : 'preset-slot-${preset.id}'),
                  preset: preset,
                  highlighted: at == i,
                  onTap: () => choose(geometry.pickAt(i)),
                  onLongPress: preset == null ? null : () => choose(PresetWheelPick.edit(preset)),
                );
              },
            ),
          ),
        ),
    ];
    final scrim = this.scrim;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
      child: FocusScope(
        autofocus: onChoose != null,
        child: Stack(
          key: const Key('preset-wheel'),
          children: [
            if (scrim != null)
              Positioned.fill(
                child: FadeTransition(opacity: animation, child: ColoredBox(color: scrim)),
              ),
            ...slots,
            // The button turns into Close, where it was.
            Positioned.fromRect(
              rect: geometry.button,
              child: Center(
                child: FloatingActionButton(
                  key: const Key('preset-wheel-close'),
                  heroTag: null,
                  tooltip: l.commonClose,
                  backgroundColor: scheme.surfaceContainerHighest,
                  foregroundColor: scheme.onSurface,
                  onPressed: close,
                  child: const Icon(Icons.close),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One slot of the wheel: the robot of the instance of a preset, or the mark of Objectives,
/// with its name under it.
class _WheelSlot extends StatelessWidget {
  const _WheelSlot({
    super.key,
    required this.preset,
    required this.highlighted,
    required this.onTap,
    this.onLongPress,
  });

  final ServicePreset? preset;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = preset;
    final name = p?.name ?? l.presetWheelObjectives;
    final circle = Material(
      color: p == null ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      elevation: highlighted ? 8 : 3,
      shape: CircleBorder(
        side: BorderSide(
          color: highlighted ? scheme.primary : scheme.outlineVariant,
          width: highlighted ? 3 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox.square(
          dimension: presetSlotSize,
          child: Center(
            child: p == null
                ? Icon(Icons.auto_awesome_outlined, color: scheme.onPrimaryContainer)
                : RobotAvatar(seed: p.fromInstance, size: presetSlotSize - 12),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: p == null ? l.presetWheelObjectivesLabel : l.presetWheelStart(name),
      hint: p == null ? null : l.presetWheelEditHint,
      onTap: onTap,
      onLongPress: onLongPress,
      customSemanticsActions: onLongPress == null
          ? null
          : {CustomSemanticsAction(label: l.presetWheelEditHint): onLongPress!},
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: highlighted ? 1.18 : 1,
            duration: const Duration(milliseconds: 120),
            child: circle,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (highlighted ? scheme.primary : scheme.surface).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: highlighted ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
