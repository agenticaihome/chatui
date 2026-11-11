import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/cards_client.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/chat/gen/cards.pb.dart' as cpb;
import '../../celaut/chat_client.dart' show ChatSlotLink;
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart' show cardRadius, rustFor;
import '../../theme/argus_tones.dart' show mossFor;
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
/// or the browser for a web slot.
Future<void> openSlotLink(
  BuildContext context,
  InstanceListView instance,
  ChatSlotLink link, {
  required String title,
  Future<int> Function(String instanceId, int slot)? openTunnel,
}) async {
  switch (slotLinkButtonKind(instance, link)) {
    case SlotKind.cards:
      await openCards(context, instance, link.port, title: title, openTunnel: openTunnel);
    case SlotKind.web:
      await openWebInBrowser(context, instance, slot: link.port, openTunnel: openTunnel);
    case SlotKind.chat || null:
      break;
  }
}

/// Open the deck of the cards slot [slot] of [instance] on the full screen. The page shows
/// at once; the tunnel opens under it.
Future<void> openCards(
  BuildContext context,
  InstanceListView instance,
  int slot, {
  required String title,
  Future<int> Function(String instanceId, int slot)? openTunnel,
}) async {
  final tunnel = (openTunnel ?? (id, s) => celautOpenTunnel(instanceId: id, slot: s))(instance.instanceId, slot);
  final failed = await Navigator.of(context).push<CelautError>(
    MaterialPageRoute(builder: (_) => CardsScreen(title: title, tunnel: tunnel)),
  );
  if (failed != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CelautStrings.errorText(failed.kind))));
  }
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

/// The full-screen deck of a cards slot (`docs/celaut/cards.md`, section 7).
///
/// Give it the [tunnel] to the slot (a page that opens a [CardsClient] on the local port),
/// or a [client] (tests). On a pop, the page closes the client after the queue of
/// decisions is sent, and pops a [CelautError] if the tunnel failed.
class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key, required this.title, this.tunnel, this.client})
      : assert(tunnel != null || client != null);

  final String title;
  final Future<int>? tunnel;
  final CardsClient? client;

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  CardsClient? _client;
  Offset _drag = Offset.zero;

  /// The card whose texts show in full on the card (a press toggles it).
  String? _expanded;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
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

  void _use(CardsClient client) {
    _client = client;
    client.addListener(_changed);
    client.start();
    client.prefetch();
  }

  void _changed() {
    if (!mounted) return;
    _client?.prefetch();
    setState(() {});
  }

  @override
  void dispose() {
    _focus.dispose();
    final client = _client;
    if (client != null) {
      client.removeListener(_changed);
      // A screen of a test owns nothing: its client is closed by the test.
      if (widget.client == null) unawaited(client.closeWhenSent());
    }
    super.dispose();
  }

  void _act(CardsAction action, [DeckCard? card]) {
    final client = _client;
    if (client == null) return;
    client.act(action.id, card: card);
    setState(() {
      _drag = Offset.zero;
      _expanded = null;
    });
  }

  void _undo() {
    _client?.undo();
    setState(() {
      _drag = Offset.zero;
      _expanded = null;
    });
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
    _act(action);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final client = _client;
    final deck = client?.deck;
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
            if (client != null && client.canUndo)
              IconButton(
                key: const Key('cards-undo'),
                tooltip: l.cardsUndo,
                icon: const Icon(Icons.undo),
                onPressed: _undo,
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
      return _message(
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
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l.cardsBackToChat),
          ),
        ],
      );
    }
    final ahead = client.ahead;
    final next = ahead.length > 1 ? ahead[1] : null;
    return Column(
      children: [
        if (deck.showProgress || status != null)
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
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LayoutBuilder(builder: (context, box) {
              final size = box.biggest;
              final side = _sideOf(_drag, size, Velocity.zero);
              final hint = client.actionFor(side);
              return Stack(
                children: [
                  if (next != null)
                    Positioned.fill(
                      child: Transform.scale(
                        scale: 0.95,
                        child: _CardFace(key: ValueKey('cards-under-${next.itemId}'), card: next, client: client),
                      ),
                    ),
                  Positioned.fill(
                    child: GestureDetector(
                      key: Key('cards-card-${current.itemId}'),
                      onTap: () => _toggle(current),
                      onLongPress: () => _toggle(current),
                      onPanUpdate: (d) => setState(() => _drag += d.delta),
                      onPanEnd: (d) {
                        final action = client.actionFor(_sideOf(_drag, size, d.velocity));
                        if (action != null) {
                          _act(action);
                        } else {
                          setState(() => _drag = Offset.zero);
                        }
                      },
                      onPanCancel: () => setState(() => _drag = Offset.zero),
                      child: Transform.translate(
                        offset: _drag,
                        child: Transform.rotate(
                          angle: _drag.dx / size.width * 0.25,
                          child: _CardFace(
                            key: ValueKey('cards-face-${current.itemId}'),
                            card: current,
                            client: client,
                            hint: hint,
                            expanded: _expanded == current.itemId,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
        _ActionBar(
          actions: [...deck.actions, ...current.buttons],
          onAction: (a) => _act(a),
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
  const _CardFace({super.key, required this.card, required this.client, this.hint, this.expanded = false});

  final DeckCard card;
  final CardsClient client;

  /// The action that a release now would make, shown on the card during a drag.
  final CardsAction? hint;

  /// The card shows its texts in full, with the `detail`, in place of its image.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final border = card.tone == cpb.Tone.TONE_NEUTRAL ? scheme.outlineVariant : toneColor(context, card.tone);
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
      child: Material(
        color: scheme.surfaceContainerHigh,
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: border, width: card.tone == cpb.Tone.TONE_NEUTRAL ? 1 : 2),
        ),
        child: Stack(
          children: [
            if (full)
              Positioned.fill(child: _CardImage(card: card, client: client))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasImage) Expanded(flex: 5, child: _CardImage(card: card, client: client)),
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
    );
  }
}
