import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/cards_client.dart';
import '../../celaut/cards_effects.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/chat/gen/cards.pb.dart' as cpb;
import '../../celaut/chat_client.dart' show ChatSlotLink;
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart' show rustFor;
import '../../theme/argus_tones.dart' show mossFor;
import 'cards_look.dart';
import 'open_web.dart';

/// What a `slot_link` of the chat opens (`docs/celaut/chat.md`, section 5.8).
enum SlotKind { cards, web, chat }

/// The kind of the slot [port] of [instance], or null if the app does not support it or
/// the instance does not have it. The slots of the instance are the ones that count
/// (`Instance.uri_slot`), as Rust found them at the start.
SlotKind? slotKindOf(InstanceListView instance, int port) {
  if (instance.cardsSlots.contains(port)) return SlotKind.cards;
  if (instance.chatSlots.contains(port)) return SlotKind.chat;
  if (instance.webSlots.contains(port)) return SlotKind.web;
  return null;
}

/// The link of a chat message as a button: null if the app shows no button for it (the
/// slot is not one of [instance], is not supported, or is the slot of this conversation).
SlotKind? slotLinkButtonKind(InstanceListView instance, ChatSlotLink link) {
  final kind = slotKindOf(instance, link.port);
  // The conversation of the instance is the screen that shows the link.
  if (kind == SlotKind.chat) return null;
  return kind;
}

/// Open the slot of [link] after the user tapped its button: the deck of a cards slot,
/// or the browser for a web slot. It returns the text to send to the chat, or null (see
/// [openCards]).
Future<String?> openSlotLink(
  BuildContext context,
  InstanceListView instance,
  ChatSlotLink link, {
  required String title,
  Future<int> Function(String instanceId, int slot)? openTunnel,
}) async {
  switch (slotLinkButtonKind(instance, link)) {
    case SlotKind.cards:
      return openCards(context, instance, link.port, title: title, openTunnel: openTunnel);
    case SlotKind.web:
      await openWebInBrowser(context, instance, slot: link.port, openTunnel: openTunnel);
    case SlotKind.chat || null:
      break;
  }
  return null;
}

/// Open the deck of the cards slot [slot] of [instance] on the full screen. The page shows
/// at once; the tunnel opens under it. It returns the `done_text` of the deck if the user
/// went back to the chat with the button of the end of the deck, or null: then the caller
/// sends that text to the chat.
Future<String?> openCards(
  BuildContext context,
  InstanceListView instance,
  int slot, {
  required String title,
  Future<int> Function(String instanceId, int slot)? openTunnel,
}) async {
  final tunnel = (openTunnel ?? (id, s) => celautOpenTunnel(instanceId: id, slot: s))(instance.instanceId, slot);
  final result = await Navigator.of(context).push<Object>(
    MaterialPageRoute(builder: (_) => CardsScreen(title: title, tunnel: tunnel)),
  );
  if (result is CelautError && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CelautStrings.errorText(result.kind))));
  }
  return result is String && result.isNotEmpty ? result : null;
}

/// The color of a [cpb.Tone] in the theme (`docs/celaut/cards.md`, section 5.4).
Color toneColor(BuildContext context, cpb.Tone tone) {
  final scheme = Theme.of(context).colorScheme;
  return switch (tone) {
    cpb.Tone.TONE_POSITIVE => mossFor(context),
    cpb.Tone.TONE_NEGATIVE => rustFor(context),
    cpb.Tone.TONE_WARNING => Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFCC80)
        : const Color(0xFF8A5A00),
    cpb.Tone.TONE_ACCENT => scheme.primary,
    _ => scheme.onSurfaceVariant,
  };
}

/// The icon of a [cpb.Icon], or null for none (the fixed list of section 5.4).
IconData? iconOf(cpb.Icon icon) => switch (icon) {
      cpb.Icon.ICON_CHECK => Icons.check,
      cpb.Icon.ICON_CLOSE => Icons.close,
      cpb.Icon.ICON_LATER => Icons.schedule,
      cpb.Icon.ICON_STAR => Icons.star_outline,
      cpb.Icon.ICON_CART => Icons.shopping_cart_outlined,
      cpb.Icon.ICON_ARCHIVE => Icons.archive_outlined,
      cpb.Icon.ICON_DELETE => Icons.delete_outline,
      cpb.Icon.ICON_FLAG => Icons.flag_outlined,
      cpb.Icon.ICON_INFO => Icons.info_outline,
      _ => null,
    };

/// The full-screen deck of a cards slot (`docs/celaut/cards.md`, section 7), with the
/// effects of section 13 (reflections, vibration, transitions, frames, motion gestures).
///
/// Give it the [tunnel] to the slot (a page that opens a [CardsClient] on the local port),
/// or a [client] (tests). On a pop, the page closes the client after the queue of
/// decisions is sent, and pops a [CelautError] if the tunnel failed. [settings], [sensors]
/// and [haptics] default to the ones of the app; tests give their own.
class CardsScreen extends StatefulWidget {
  const CardsScreen({
    super.key,
    required this.title,
    this.tunnel,
    this.client,
    this.settings,
    this.sensors,
    this.haptics,
    this.armTimeout = const Duration(seconds: 30),
  }) : assert(tunnel != null || client != null);

  final String title;
  final Future<int>? tunnel;
  final CardsClient? client;
  final CardsSettings? settings;
  final CardsSensors? sensors;
  final CardsHapticPlayer? haptics;

  /// The motion gestures end by themselves after this time with no gesture.
  final Duration armTimeout;

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

/// The card that leaves after a decision, drawn over the deck while its transition runs.
class _Leaving {
  const _Leaving(this.card, this.from, this.direction, this.hint);

  final DeckCard card;
  final Offset from;
  final cpb.Direction direction;
  final CardsAction? hint;
}

class _CardsScreenState extends State<CardsScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  CardsClient? _client;
  Offset _drag = Offset.zero;

  /// The card whose texts show in full on the card (a press toggles it).
  String? _expanded;
  final _focus = FocusNode();

  CardsSettings get _settings => widget.settings ?? cardsSettings;
  CardsEffects _fx = CardsEffects.none;

  late final AnimationController _leave;
  late final AnimationController _appear;
  _Leaving? _leaving;

  /// The deck id and its items: a change that the user did not make is a refresh.
  String _signature = '';

  bool _pastThreshold = false;

  final _tilt = ValueNotifier<Offset>(Offset.zero);
  Offset _gyroTilt = Offset.zero;
  Offset _pointerTilt = Offset.zero;
  final _filter = TiltFilter();
  StreamSubscription<GyroSample>? _gyro;
  bool _resumed = true;

  bool _armed = false;
  Timer? _armTimer;
  WristGestureDetector? _wrist;

  final _guard = FrameRateGuard();
  int _stepDown = 0;

  @override
  void initState() {
    super.initState();
    _leave = AnimationController(vsync: this)..addStatusListener(_leaveStatus);
    _appear = AnimationController(vsync: this, value: 1);
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_timings);
    _settings.addListener(_settingsChanged);
    final given = widget.client;
    if (given != null) {
      _use(given);
    } else {
      widget.tunnel!.then((port) {
        if (mounted) setState(() => _use(CardsClient(port: port)));
      }, onError: (Object e) {
        if (!mounted) return;
        Navigator.of(context).pop(
          e is CelautError ? e : CelautError(kind: CelautErrorKind.protocol, message: '$e'),
        );
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  void _use(CardsClient client) {
    _client = client;
    client.addListener(_changed);
    client.start();
    client.prefetch();
  }

  void _changed() {
    if (!mounted) return;
    _client?.prefetch();
    final deck = _client?.deck;
    if (deck != null) {
      final sig = '${deck.id}|${deck.cards.map((c) => c.itemId).join(',')}';
      if (_signature.isNotEmpty && sig != _signature) _play(_appear);
      _signature = sig;
    }
    setState(() {});
    _syncSensors();
  }

  void _settingsChanged() {
    if (!mounted) return;
    setState(_resolve);
  }

  /// The effects now: the settings, "reduce motion" of the system and the steps down.
  void _resolve() {
    _fx = _settings.resolve(reduceMotion: MediaQuery.disableAnimationsOf(context), stepDown: _stepDown);
    if (!_fx.gestures && _armed) _disarm();
    _syncSensors();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    // The screen goes off or the app goes away: the gestures end and the sensor stops.
    if (!_resumed && _armed) _disarm();
    _syncSensors();
  }

  void _timings(List<FrameTiming> timings) {
    var changed = false;
    for (final t in timings) {
      changed = _guard.add(t.totalSpan) || changed;
    }
    if (changed && mounted) {
      setState(() {
        _stepDown = _guard.stepDown;
        _resolve();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    _settings.removeListener(_settingsChanged);
    _armTimer?.cancel();
    unawaited(_gyro?.cancel());
    _gyro = null;
    _leave.dispose();
    _appear.dispose();
    _tilt.dispose();
    _focus.dispose();
    final client = _client;
    if (client != null) {
      client.removeListener(_changed);
      // A screen of a test owns nothing: its client is closed by the test.
      if (widget.client == null) unawaited(client.closeWhenSent());
    }
    super.dispose();
  }

  // --- Sensors -----------------------------------------------------------------------

  /// The gyroscope runs only while the deck shows a card, the app is in front, and an
  /// effect needs it (section 13, U6).
  void _syncSensors() {
    final client = _client;
    final want = mounted &&
        _resumed &&
        client != null &&
        client.current != null &&
        (_fx.gyroReflections || (_armed && _fx.gestures));
    if (want && _gyro == null) {
      _filter.reset();
      _gyro = (widget.sensors ?? const PlatformCardsSensors()).gyro().listen(_sample, onError: (Object _) {
        // No sensor after all: the reflection follows the finger, the gestures end.
        _gyro = null;
        if (_armed) _disarm();
      });
    } else if (!want && _gyro != null) {
      unawaited(_gyro!.cancel());
      _gyro = null;
      _gyroTilt = Offset.zero;
      _updateTilt();
    }
  }

  void _sample(GyroSample s) {
    if (!mounted) return;
    if (_fx.gyroReflections) {
      _gyroTilt = _filter.add(s);
      _updateTilt();
    }
    final wrist = _wrist;
    final client = _client;
    if (!_armed || wrist == null || client == null) return;
    final turn = wrist.add(s);
    if (turn == WristTurn.none) return;
    // The swap is for left and right; up and down stay where the screen turns.
    final side = switch (turn) {
      WristTurn.left => _fx.swapSides ? cpb.Direction.DIRECTION_RIGHT : cpb.Direction.DIRECTION_LEFT,
      WristTurn.right => _fx.swapSides ? cpb.Direction.DIRECTION_LEFT : cpb.Direction.DIRECTION_RIGHT,
      WristTurn.up => cpb.Direction.DIRECTION_UP,
      WristTurn.down => cpb.Direction.DIRECTION_DOWN,
      WristTurn.none => cpb.Direction.DIRECTION_NONE,
    };
    final action = client.actionFor(side);
    if (action == null || client.current == null) return;
    _restartArmTimer();
    _decide(action, side: side);
  }

  void _updateTilt() {
    final x = (_gyroTilt.dx + _pointerTilt.dx).clamp(-1.0, 1.0);
    final y = (_gyroTilt.dy + _pointerTilt.dy).clamp(-1.0, 1.0);
    _tilt.value = Offset(x, y);
  }

  // --- Motion gestures ---------------------------------------------------------------

  void _toggleArm() => _armed ? _disarm() : _arm();

  void _arm() {
    setState(() {
      _armed = true;
      _wrist = WristGestureDetector(threshold: WristGestureDetector.thresholdOf(_fx.sensitivity));
    });
    _restartArmTimer();
    _syncSensors();
  }

  void _disarm() {
    _armTimer?.cancel();
    _armTimer = null;
    _wrist = null;
    if (mounted) setState(() => _armed = false);
    _syncSensors();
  }

  void _restartArmTimer() {
    _armTimer?.cancel();
    _armTimer = Timer(widget.armTimeout, _disarm);
  }

  // --- Vibration and transitions -----------------------------------------------------

  void _buzz(CardsHapticEvent event) {
    if (!_fx.haptics) return;
    (widget.haptics ?? playSystemHaptic)(hapticLevelOf(event, _fx.hapticStrength));
  }

  Duration get _leaveTime => switch (_fx.transitions) {
        CardsTransitions.full => const Duration(milliseconds: 260),
        CardsTransitions.simple => const Duration(milliseconds: 150),
        CardsTransitions.off => Duration.zero,
      };

  void _play(AnimationController c) {
    final time = _leaveTime;
    if (time == Duration.zero) {
      c.value = 1;
      return;
    }
    c.duration = time;
    c.forward(from: 0);
  }

  void _leaveStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && _leaving != null && mounted) setState(() => _leaving = null);
  }

  /// A decision by a swipe, a button, a key or a motion gesture: it vibrates, the card
  /// leaves with the transition, and the action goes to the client at once (the effects
  /// never wait for anything).
  void _decide(CardsAction action, {cpb.Direction? side}) {
    final client = _client;
    final card = client?.current;
    if (client == null || card == null) return;
    _buzz(CardsHapticEvent.release);
    if (_fx.transitions != CardsTransitions.off) {
      final dir = side ?? action.direction;
      _leaving = _Leaving(card, _drag, dir, dir == cpb.Direction.DIRECTION_NONE ? null : action);
      _play(_leave);
      if (_fx.transitions == CardsTransitions.full) _play(_appear);
    }
    _act(action);
  }

  void _act(CardsAction action, [DeckCard? card]) {
    final client = _client;
    if (client == null) return;
    client.act(action.id, card: card);
    setState(() {
      _drag = Offset.zero;
      _expanded = null;
      _pastThreshold = false;
    });
    _pointerTilt = Offset.zero;
    _updateTilt();
  }

  void _undo() {
    if (_client?.canUndo != true) return;
    _buzz(CardsHapticEvent.undo);
    _client?.undo();
    setState(() {
      _leaving = null;
      _drag = Offset.zero;
      _expanded = null;
    });
    _play(_appear);
  }

  cpb.Direction _sideOf(Offset o, Size size, Velocity v) {
    final dx = o.dx, dy = o.dy;
    final fast = v.pixelsPerSecond.distance > 900;
    final horizontal = dx.abs() >= dy.abs();
    final far = horizontal ? dx.abs() > size.width * 0.28 : dy.abs() > size.height * 0.2;
    if (!far && !fast) return cpb.Direction.DIRECTION_NONE;
    if (horizontal) return dx < 0 ? cpb.Direction.DIRECTION_LEFT : cpb.Direction.DIRECTION_RIGHT;
    return dy < 0 ? cpb.Direction.DIRECTION_UP : cpb.Direction.DIRECTION_DOWN;
  }

  void _dragBy(Offset delta, Size size, CardsClient client) {
    _drag += delta;
    final past = client.actionFor(_sideOf(_drag, size, Velocity.zero)) != null;
    // One vibration when the card passes the decision point, none for each frame.
    if (past && !_pastThreshold) _buzz(CardsHapticEvent.threshold);
    _pastThreshold = past;
    _pointerTilt = Offset((_drag.dx / size.width).clamp(-1.0, 1.0), (_drag.dy / size.height).clamp(-1.0, 1.0));
    _updateTilt();
    setState(() {});
  }

  void _dragEnd(Velocity v, Size size, CardsClient client) {
    final action = client.actionFor(_sideOf(_drag, size, v));
    if (action != null) {
      _decide(action);
      return;
    }
    // The card comes back: a cancel, when the drag went somewhere.
    if (_pastThreshold || _drag.distance > 24) _buzz(CardsHapticEvent.cancel);
    _pointerTilt = Offset.zero;
    _updateTilt();
    setState(() {
      _drag = Offset.zero;
      _pastThreshold = false;
    });
  }

  void _hover(Offset local, Size size) {
    if (_fx.gyroReflections || !_fx.reflections) return;
    _pointerTilt = Offset(
      ((local.dx / size.width) * 2 - 1).clamp(-1.0, 1.0),
      ((local.dy / size.height) * 2 - 1).clamp(-1.0, 1.0),
    );
    _updateTilt();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    final client = _client;
    if (client == null || event is! KeyDownEvent) return KeyEventResult.ignored;
    final side = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => cpb.Direction.DIRECTION_LEFT,
      LogicalKeyboardKey.arrowRight => cpb.Direction.DIRECTION_RIGHT,
      LogicalKeyboardKey.arrowUp => cpb.Direction.DIRECTION_UP,
      LogicalKeyboardKey.arrowDown => cpb.Direction.DIRECTION_DOWN,
      _ => cpb.Direction.DIRECTION_NONE,
    };
    final action = client.actionFor(side);
    if (action == null || client.current == null) return KeyEventResult.ignored;
    _decide(action, side: side);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final client = _client;
    final deck = client?.deck;
    final canArm = _fx.gestures && client != null && client.current != null;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _key,
      child: Scaffold(
        key: const Key('cards-screen'),
        appBar: AppBar(
          titleSpacing: 0,
          title: Text(
            deck != null && deck.title.isNotEmpty ? deck.title : widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (canArm)
              IconButton(
                key: const Key('cards-arm'),
                isSelected: _armed,
                tooltip: _armed ? l.cardsGesturesDisarm : l.cardsGesturesArm,
                icon: const Icon(Icons.screen_rotation_alt_outlined),
                selectedIcon: const Icon(Icons.screen_rotation_alt),
                onPressed: _toggleArm,
              ),
            // With the gestures armed, undo is always on screen (section 13).
            if (client != null && (client.canUndo || _armed))
              IconButton(
                key: const Key('cards-undo'),
                tooltip: l.cardsUndo,
                icon: const Icon(Icons.undo),
                onPressed: client.canUndo ? _undo : null,
              ),
          ],
        ),
        body: SafeArea(child: client == null ? const Center(child: CircularProgressIndicator()) : _body(context, client)),
      ),
    );
  }

  Widget _body(BuildContext context, CardsClient client) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    if (!client.loaded) {
      return Center(
        key: const Key('cards-loading'),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(l.cardsLoading),
        ]),
      );
    }
    final deck = client.deck;
    final status = _status(context, client);
    if (deck.id.isEmpty) {
      return _message(context, const Key('cards-none'), Icons.style_outlined, l.cardsNoDeck, status);
    }
    final current = client.current;
    if (current == null) {
      final end = _message(
        context,
        const Key('cards-end'),
        Icons.check_circle_outline,
        deck.endText.isNotEmpty ? deck.endText : l.cardsEnd,
        status,
        extra: [
          if (client.canUndo)
            OutlinedButton.icon(
              key: const Key('cards-end-undo'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(88, 48)),
              onPressed: _undo,
              icon: const Icon(Icons.undo),
              label: Text(l.cardsUndo),
            ),
          FilledButton(
            key: const Key('cards-back'),
            style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
            onPressed: () {
              // The text of the deck for the end goes to the chat (cards.md, section 7).
              final text = deck.doneText;
              Navigator.of(context).pop(text.isEmpty ? null : text);
            },
            child: Text(l.cardsBackToChat),
          ),
        ],
      );
      // The end comes with its own short effect, under the last card that leaves.
      return Stack(children: [
        Positioned.fill(child: _appearing(end)),
        if (_leaving != null)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: LayoutBuilder(builder: (context, box) => _ghost(context, client, box.biggest)),
            ),
          ),
      ]);
    }
    final ahead = client.ahead;
    final next = ahead.length > 1 ? ahead[1] : null;
    final third = _fx.transitions == CardsTransitions.full && ahead.length > 2 ? ahead[2] : null;
    return Column(
      children: [
        if (deck.showProgress || status != null || _armed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              if (deck.showProgress)
                Text(
                  l.cardsProgress(client.doneCount + 1, deck.cards.length),
                  key: const Key('cards-progress'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              const Spacer(),
              ?status,
            ]),
          ),
        if (_armed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(children: [
              Icon(Icons.screen_rotation_alt, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.cardsGesturesArmed,
                  key: const Key('cards-armed'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.primary),
                ),
              ),
            ]),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LayoutBuilder(builder: (context, box) {
              final size = box.biggest;
              final side = _sideOf(_drag, size, Velocity.zero);
              final hint = client.actionFor(side);
              return _appearing(Stack(
                children: [
                  if (third != null)
                    Positioned.fill(
                      child: Transform.translate(
                        offset: const Offset(0, 14),
                        child: Transform.scale(
                          scale: 0.90,
                          child: _CardFace(
                            key: ValueKey('cards-under2-${third.itemId}'),
                            card: third,
                            client: client,
                            frames: _fx.frames,
                          ),
                        ),
                      ),
                    ),
                  if (next != null)
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(0, third != null ? 7 : 0),
                        child: Transform.scale(
                          scale: 0.95,
                          child: _CardFace(
                            key: ValueKey('cards-under-${next.itemId}'),
                            card: next,
                            client: client,
                            frames: _fx.frames,
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: MouseRegion(
                      onHover: (e) => _hover(e.localPosition, size),
                      onExit: (_) {
                        _pointerTilt = Offset.zero;
                        _updateTilt();
                      },
                      child: GestureDetector(
                        key: Key('cards-card-${current.itemId}'),
                        onTap: () => _toggle(current),
                        onLongPress: () => _toggle(current),
                        onPanUpdate: (d) => _dragBy(d.delta, size, client),
                        onPanEnd: (d) => _dragEnd(d.velocity, size, client),
                        onPanCancel: () => _dragEnd(Velocity.zero, size, client),
                        child: _rising(Transform.translate(
                          offset: _drag,
                          child: Transform.rotate(
                            angle: _drag.dx / size.width * 0.25,
                            child: _CardFace(
                              key: ValueKey('cards-face-${current.itemId}'),
                              card: current,
                              client: client,
                              hint: hint,
                              expanded: _expanded == current.itemId,
                              frames: _fx.frames,
                              reflection: _fx.reflections
                                  ? CardReflection(tilt: _tilt, opacity: reflectionOpacity(_fx.reflectionStrength))
                                  : null,
                            ),
                          ),
                        )),
                      ),
                    ),
                  ),
                  if (_leaving != null) Positioned.fill(child: _ghost(context, client, size)),
                ],
              ));
            }),
          ),
        ),
        _ActionBar(
          actions: [...deck.actions, ...current.buttons],
          onAction: (a) => _decide(a),
        ),
        const SizedBox(height: 8),
        Text(
          l.cardsTapForDetail,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// The new top card grows from its place under the one that leaves (full transitions).
  Widget _rising(Widget child) {
    if (_leaving == null || _fx.transitions != CardsTransitions.full) return child;
    return AnimatedBuilder(
      animation: _leave,
      builder: (context, child) =>
          Transform.scale(scale: 0.95 + 0.05 * Curves.easeOut.transform(_leave.value), child: child),
      child: child,
    );
  }

  /// The short effect of the end of the deck, a refresh and an undo: a fade (simple), with
  /// a small scale (full). Nothing with the transitions off.
  Widget _appearing(Widget child) {
    if (_fx.transitions == CardsTransitions.off) return child;
    final full = _fx.transitions == CardsTransitions.full;
    return AnimatedBuilder(
      animation: _appear,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_appear.value);
        final faded = Opacity(opacity: 0.4 + 0.6 * t, child: child);
        return full ? Transform.scale(scale: 0.96 + 0.04 * t, child: faded) : faded;
      },
      child: child,
    );
  }

  /// The card that leaves, with the style of the transition. It takes no input and is not
  /// read by a screen reader: the deck under it is already the new state.
  Widget _ghost(BuildContext context, CardsClient client, Size size) {
    final leaving = _leaving!;
    final face = _CardFace(
      key: ValueKey('cards-leaving-${leaving.card.itemId}'),
      card: leaving.card,
      client: client,
      hint: leaving.hint,
      frames: _fx.frames,
    );
    final dir = switch (leaving.direction) {
      cpb.Direction.DIRECTION_LEFT => const Offset(-1, 0),
      cpb.Direction.DIRECTION_RIGHT => const Offset(1, 0),
      cpb.Direction.DIRECTION_UP => const Offset(0, -1),
      cpb.Direction.DIRECTION_DOWN => const Offset(0, 1),
      _ => Offset.zero,
    };
    final simple = _fx.transitions == CardsTransitions.simple;
    final style = dir == Offset.zero && !simple ? CardsTransitionStyle.fade : _fx.style;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _leave,
          builder: (context, child) {
            final t = Curves.easeIn.transform(_leave.value);
            final baseAngle = leaving.from.dx / size.width * 0.25;
            if (simple) {
              // Reduced motion: no movement, only a fade.
              return Opacity(
                opacity: 1 - t,
                child: Transform.translate(offset: leaving.from, child: Transform.rotate(angle: baseAngle, child: child)),
              );
            }
            final far = Offset(dir.dx * size.width * 1.3, dir.dy * size.height * 1.2);
            return switch (style) {
              CardsTransitionStyle.toss => Opacity(
                  opacity: 1 - 0.3 * t,
                  child: Transform.translate(
                    offset: leaving.from + far * t,
                    child: Transform.rotate(angle: baseAngle + dir.dx * 0.35 * t, child: child),
                  ),
                ),
              CardsTransitionStyle.slide => Transform.translate(
                  offset: leaving.from + far * t,
                  child: Transform.rotate(angle: baseAngle * (1 - t), child: child),
                ),
              CardsTransitionStyle.fade => Opacity(
                  opacity: 1 - t,
                  child: Transform.translate(
                    offset: leaving.from * (1 - t),
                    child: Transform.scale(scale: 1 - 0.12 * t, child: child),
                  ),
                ),
            };
          },
          child: face,
        ),
      ),
    );
  }

  /// "Connecting" or the moves that wait, or null when all is sent and `Watch` is open.
  Widget? _status(BuildContext context, CardsClient client) {
    final l = context.l10n;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(color: rustFor(context));
    if (client.pending > 0 && !client.watching) {
      return Text(l.cardsWaiting(client.pending), key: const Key('cards-waiting'), style: style);
    }
    if (!client.watching) return Text(l.cardsConnecting, key: const Key('cards-connecting'), style: style);
    return null;
  }

  Widget _message(BuildContext context, Key key, IconData icon, String text, Widget? status,
      {List<Widget> extra = const []}) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            if (status != null) ...[const SizedBox(height: 8), status],
            const SizedBox(height: 24),
            Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: extra),
          ],
        ),
      ),
    );
  }

  /// A press on the card shows its texts in full, inside the card; another press hides them.
  void _toggle(DeckCard card) => setState(() => _expanded = _expanded == card.itemId ? null : card.itemId);
}

/// The buttons of the actions: one for each action of the deck (also the ones of a swipe,
/// section 5.3) and for each button of the card.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.actions, required this.onAction});

  final List<CardsAction> actions;
  final void Function(CardsAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final sorted = [...actions]..sort((a, b) => _order(a.direction).compareTo(_order(b.direction)));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [for (final a in sorted) actionButton(context, a, () => onAction(a))],
      ),
    );
  }

  static int _order(cpb.Direction d) => switch (d) {
        cpb.Direction.DIRECTION_LEFT => 0,
        cpb.Direction.DIRECTION_DOWN => 1,
        cpb.Direction.DIRECTION_NONE => 2,
        cpb.Direction.DIRECTION_UP => 3,
        _ => 4,
      };
}

/// The button of an action, with an arrow for the side of its swipe.
Widget actionButton(BuildContext context, CardsAction a, VoidCallback onPressed) {
  final color = toneColor(context, a.tone);
  final icon = iconOf(a.icon);
  final arrow = switch (a.direction) {
    cpb.Direction.DIRECTION_LEFT => Icons.arrow_back,
    cpb.Direction.DIRECTION_RIGHT => Icons.arrow_forward,
    cpb.Direction.DIRECTION_UP => Icons.arrow_upward,
    cpb.Direction.DIRECTION_DOWN => Icons.arrow_downward,
    _ => null,
  };
  return OutlinedButton(
    key: Key('cards-action-${a.id}'),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(64, 48),
      foregroundColor: color,
      side: BorderSide(color: color),
    ),
    onPressed: onPressed,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (arrow != null && a.direction == cpb.Direction.DIRECTION_LEFT) ...[Icon(arrow, size: 18), const SizedBox(width: 4)],
      if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
      Text(a.label),
      if (arrow != null && a.direction != cpb.Direction.DIRECTION_LEFT) ...[const SizedBox(width: 4), Icon(arrow, size: 18)],
    ]),
  );
}

/// The image of a card, read on demand from the service.
class _CardImage extends StatelessWidget {
  const _CardImage({required this.card, required this.client});

  final DeckCard card;
  final CardsClient client;

  @override
  Widget build(BuildContext context) {
    final cached = client.cachedImage(card);
    Widget show(Uint8List bytes) => Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          semanticLabel: card.altText.isNotEmpty ? card.altText : null,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
    if (cached != null) return show(cached);
    return FutureBuilder<Uint8List?>(
      future: client.image(card),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes != null) return show(bytes);
        if (snap.connectionState == ConnectionState.done) return const SizedBox.shrink();
        return const Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)));
      },
    );
  }
}

/// One card as it shows in the deck.
class _CardFace extends StatelessWidget {
  const _CardFace({
    super.key,
    required this.card,
    required this.client,
    this.hint,
    this.expanded = false,
    this.frames = CardsFrames.none,
    this.reflection,
  });

  final DeckCard card;
  final CardsClient client;

  /// The action that a release now would make, shown on the card during a drag.
  final CardsAction? hint;

  /// The card shows its texts in full, with the `detail`, in place of its image.
  final bool expanded;

  /// The frame of the card (section 13): from the theme, or none.
  final CardsFrames frames;

  /// The light on the image (section 13), or null. It never covers the texts.
  final Widget? reflection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final frame = cardFrameOf(
      theme,
      card.tone == cpb.Tone.TONE_NEUTRAL ? null : toneColor(context, card.tone),
      frames,
    );
    final hasImage = card.image != null;
    final full = card.layout == cpb.Layout.LAYOUT_IMAGE_FULL && hasImage;
    final texts = <Widget>[
      if (card.group.isNotEmpty)
        Text(card.group.toUpperCase(),
            key: Key('cards-group-${card.itemId}'),
            style: theme.textTheme.labelSmall?.copyWith(color: full ? Colors.white70 : scheme.primary, letterSpacing: 1.2)),
      Text(card.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(color: full ? Colors.white : scheme.onSurface)),
      if (card.text.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(card.text,
            maxLines: full ? 3 : 6,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(color: full ? Colors.white : scheme.onSurfaceVariant)),
      ],
    ];
    return Semantics(
      container: true,
      label: card.title,
      hint: context.l10n.cardsTapForDetail,
      child: DecoratedBox(
        key: Key('cards-frame-${card.itemId}'),
        decoration: frame.decoration(scheme.surfaceContainerHigh),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(frame.radius),
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
          children: [
            if (full) ...[
              Positioned.fill(child: _CardImage(card: card, client: client)),
              if (reflection != null) Positioned.fill(child: reflection!),
            ] else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasImage)
                    Expanded(
                      flex: 5,
                      child: Stack(fit: StackFit.expand, children: [
                        _CardImage(card: card, client: client),
                        ?reflection,
                      ]),
                    ),
                  Expanded(
                    flex: hasImage ? 4 : 1,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: hasImage ? MainAxisAlignment.start : MainAxisAlignment.center,
                        children: texts,
                      ),
                    ),
                  ),
                ],
              ),
            if (full)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: texts),
                  ),
                ),
              ),
            if (expanded)
              Positioned.fill(
                child: ColoredBox(
                  key: Key('cards-expanded-${card.itemId}'),
                  color: scheme.surfaceContainerHigh,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (card.group.isNotEmpty)
                          Text(card.group.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary, letterSpacing: 1.2)),
                        Text(card.title, style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onSurface)),
                        if (card.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(card.text, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                        if (card.detail.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(card.detail, key: const Key('cards-detail-text'), style: theme.textTheme.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (hint != null)
              Positioned(
                top: 16,
                left: hint!.direction == cpb.Direction.DIRECTION_RIGHT ? 16 : null,
                right: hint!.direction == cpb.Direction.DIRECTION_RIGHT ? null : 16,
                child: DecoratedBox(
                  key: const Key('cards-hint'),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border.all(color: toneColor(context, hint!.tone), width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(hint!.label,
                        style: theme.textTheme.titleMedium?.copyWith(color: toneColor(context, hint!.tone))),
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
