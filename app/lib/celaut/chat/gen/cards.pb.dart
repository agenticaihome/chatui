// This is a generated file - do not edit.
//
// Generated from cards.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'cards.pbenum.dart';
import 'chat.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'cards.pbenum.dart';

class WatchRequest extends $pb.GeneratedMessage {
  factory WatchRequest() => WatchRequest._();

  WatchRequest._();

  factory WatchRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchRequest()..mergeFromBuffer(data, registry);
  factory WatchRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WatchRequest',
      createEmptyInstance: WatchRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchRequest copyWith(void Function(WatchRequest) updates) =>
      super.copyWith((message) => updates(message as WatchRequest))
          as WatchRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WatchRequest() / WatchRequest.new instead')
  static WatchRequest create() => WatchRequest._();
  static $pb.GeneratedMessage $_createMessage() => WatchRequest._();
  @$core.override
  WatchRequest createEmptyInstance() => WatchRequest._();
  @$core.pragma('dart2js:noInline')
  static WatchRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WatchRequest>(
          WatchRequest.$_createMessage);
  static WatchRequest? _defaultInstance;
}

enum DeckEvent_Event {
  deck,
  cardsAdded,
  cardsRemoved,
  cardMoved,
  cardChanged,
  notSet
}

class DeckEvent extends $pb.GeneratedMessage {
  factory DeckEvent({
    $fixnum.Int64? version,
    $core.String? deckId,
    Deck? deck,
    CardsAdded? cardsAdded,
    CardsRemoved? cardsRemoved,
    CardMoved? cardMoved,
    CardChanged? cardChanged,
  }) {
    final result = DeckEvent._();
    if (version != null) result.version = version;
    if (deckId != null) result.deckId = deckId;
    if (deck != null) result.deck = deck;
    if (cardsAdded != null) result.cardsAdded = cardsAdded;
    if (cardsRemoved != null) result.cardsRemoved = cardsRemoved;
    if (cardMoved != null) result.cardMoved = cardMoved;
    if (cardChanged != null) result.cardChanged = cardChanged;
    return result;
  }

  DeckEvent._();

  factory DeckEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeckEvent()..mergeFromBuffer(data, registry);
  factory DeckEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeckEvent()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, DeckEvent_Event> _DeckEvent_EventByTag = {
    3: DeckEvent_Event.deck,
    4: DeckEvent_Event.cardsAdded,
    5: DeckEvent_Event.cardsRemoved,
    6: DeckEvent_Event.cardMoved,
    7: DeckEvent_Event.cardChanged,
    0: DeckEvent_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeckEvent',
      createEmptyInstance: DeckEvent.$_createMessage)
    ..oo(0, [3, 4, 5, 6, 7])
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'version', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'deckId')
    ..aOM<Deck>(3, _omitFieldNames ? '' : 'deck',
        subBuilder: Deck.$_createMessage)
    ..aOM<CardsAdded>(4, _omitFieldNames ? '' : 'cardsAdded',
        subBuilder: CardsAdded.$_createMessage)
    ..aOM<CardsRemoved>(5, _omitFieldNames ? '' : 'cardsRemoved',
        subBuilder: CardsRemoved.$_createMessage)
    ..aOM<CardMoved>(6, _omitFieldNames ? '' : 'cardMoved',
        subBuilder: CardMoved.$_createMessage)
    ..aOM<CardChanged>(7, _omitFieldNames ? '' : 'cardChanged',
        subBuilder: CardChanged.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeckEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeckEvent copyWith(void Function(DeckEvent) updates) =>
      super.copyWith((message) => updates(message as DeckEvent)) as DeckEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DeckEvent() / DeckEvent.new instead')
  static DeckEvent create() => DeckEvent._();
  static $pb.GeneratedMessage $_createMessage() => DeckEvent._();
  @$core.override
  DeckEvent createEmptyInstance() => DeckEvent._();
  @$core.pragma('dart2js:noInline')
  static DeckEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeckEvent>(DeckEvent.$_createMessage);
  static DeckEvent? _defaultInstance;

  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  DeckEvent_Event whichEvent() => _DeckEvent_EventByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  void clearEvent() => $_clearField($_whichOneof(0));

  /// Versión del estado después de este evento. Crece con cada cambio y nunca
  /// baja durante la vida de la instancia. El cliente ignora un evento cuya
  /// versión no es mayor que la suya.
  @$pb.TagNumber(1)
  $fixnum.Int64 get version => $_getI64(0);
  @$pb.TagNumber(1)
  set version($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);

  /// El mazo al que se aplica el evento. En `deck`, es Deck.deck_id.
  @$pb.TagNumber(2)
  $core.String get deckId => $_getSZ(1);
  @$pb.TagNumber(2)
  set deckId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeckId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeckId() => $_clearField(2);

  /// Reemplaza todo el estado: el primer evento de Watch, un mazo nuevo,
  /// o una recarga del mismo mazo.
  @$pb.TagNumber(3)
  Deck get deck => $_getN(2);
  @$pb.TagNumber(3)
  set deck(Deck value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDeck() => $_has(2);
  @$pb.TagNumber(3)
  void clearDeck() => $_clearField(3);
  @$pb.TagNumber(3)
  Deck ensureDeck() => $_ensure(2);

  /// Añade cartas.
  @$pb.TagNumber(4)
  CardsAdded get cardsAdded => $_getN(3);
  @$pb.TagNumber(4)
  set cardsAdded(CardsAdded value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCardsAdded() => $_has(3);
  @$pb.TagNumber(4)
  void clearCardsAdded() => $_clearField(4);
  @$pb.TagNumber(4)
  CardsAdded ensureCardsAdded() => $_ensure(3);

  /// Quita cartas.
  @$pb.TagNumber(5)
  CardsRemoved get cardsRemoved => $_getN(4);
  @$pb.TagNumber(5)
  set cardsRemoved(CardsRemoved value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCardsRemoved() => $_has(4);
  @$pb.TagNumber(5)
  void clearCardsRemoved() => $_clearField(5);
  @$pb.TagNumber(5)
  CardsRemoved ensureCardsRemoved() => $_ensure(4);

  /// Mueve una carta.
  @$pb.TagNumber(6)
  CardMoved get cardMoved => $_getN(5);
  @$pb.TagNumber(6)
  set cardMoved(CardMoved value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCardMoved() => $_has(5);
  @$pb.TagNumber(6)
  void clearCardMoved() => $_clearField(6);
  @$pb.TagNumber(6)
  CardMoved ensureCardMoved() => $_ensure(5);

  /// Reemplaza una carta que ya está en el mazo (mismo item_id).
  @$pb.TagNumber(7)
  CardChanged get cardChanged => $_getN(6);
  @$pb.TagNumber(7)
  set cardChanged(CardChanged value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCardChanged() => $_has(6);
  @$pb.TagNumber(7)
  void clearCardChanged() => $_clearField(7);
  @$pb.TagNumber(7)
  CardChanged ensureCardChanged() => $_ensure(6);
}

class CardsAdded extends $pb.GeneratedMessage {
  factory CardsAdded({
    $core.Iterable<Card>? cards,
    $core.String? beforeItemId,
  }) {
    final result = CardsAdded._();
    if (cards != null) result.cards.addAll(cards);
    if (beforeItemId != null) result.beforeItemId = beforeItemId;
    return result;
  }

  CardsAdded._();

  factory CardsAdded.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardsAdded()..mergeFromBuffer(data, registry);
  factory CardsAdded.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardsAdded()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CardsAdded',
      createEmptyInstance: CardsAdded.$_createMessage)
    ..pPM<Card>(1, _omitFieldNames ? '' : 'cards',
        subBuilder: Card.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'beforeItemId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardsAdded clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardsAdded copyWith(void Function(CardsAdded) updates) =>
      super.copyWith((message) => updates(message as CardsAdded)) as CardsAdded;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CardsAdded() / CardsAdded.new instead')
  static CardsAdded create() => CardsAdded._();
  static $pb.GeneratedMessage $_createMessage() => CardsAdded._();
  @$core.override
  CardsAdded createEmptyInstance() => CardsAdded._();
  @$core.pragma('dart2js:noInline')
  static CardsAdded getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CardsAdded>(CardsAdded.$_createMessage);
  static CardsAdded? _defaultInstance;

  /// Las cartas nuevas, en orden. Un item_id que ya está en el mazo se ignora.
  @$pb.TagNumber(1)
  $pb.PbList<Card> get cards => $_getList(0);

  /// Las cartas van antes de esta carta. Ausente, o un item_id que no está:
  /// al final del mazo.
  @$pb.TagNumber(2)
  $core.String get beforeItemId => $_getSZ(1);
  @$pb.TagNumber(2)
  set beforeItemId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBeforeItemId() => $_has(1);
  @$pb.TagNumber(2)
  void clearBeforeItemId() => $_clearField(2);
}

class CardsRemoved extends $pb.GeneratedMessage {
  factory CardsRemoved({
    $core.Iterable<$core.String>? itemIds,
  }) {
    final result = CardsRemoved._();
    if (itemIds != null) result.itemIds.addAll(itemIds);
    return result;
  }

  CardsRemoved._();

  factory CardsRemoved.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardsRemoved()..mergeFromBuffer(data, registry);
  factory CardsRemoved.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardsRemoved()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CardsRemoved',
      createEmptyInstance: CardsRemoved.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'itemIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardsRemoved clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardsRemoved copyWith(void Function(CardsRemoved) updates) =>
      super.copyWith((message) => updates(message as CardsRemoved))
          as CardsRemoved;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CardsRemoved() / CardsRemoved.new instead')
  static CardsRemoved create() => CardsRemoved._();
  static $pb.GeneratedMessage $_createMessage() => CardsRemoved._();
  @$core.override
  CardsRemoved createEmptyInstance() => CardsRemoved._();
  @$core.pragma('dart2js:noInline')
  static CardsRemoved getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CardsRemoved>(
          CardsRemoved.$_createMessage);
  static CardsRemoved? _defaultInstance;

  /// Las cartas que salen. Un item_id que no está se ignora.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get itemIds => $_getList(0);
}

class CardMoved extends $pb.GeneratedMessage {
  factory CardMoved({
    $core.String? itemId,
    $core.String? beforeItemId,
  }) {
    final result = CardMoved._();
    if (itemId != null) result.itemId = itemId;
    if (beforeItemId != null) result.beforeItemId = beforeItemId;
    return result;
  }

  CardMoved._();

  factory CardMoved.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardMoved()..mergeFromBuffer(data, registry);
  factory CardMoved.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardMoved()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CardMoved',
      createEmptyInstance: CardMoved.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'itemId')
    ..aOS(2, _omitFieldNames ? '' : 'beforeItemId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardMoved clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardMoved copyWith(void Function(CardMoved) updates) =>
      super.copyWith((message) => updates(message as CardMoved)) as CardMoved;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CardMoved() / CardMoved.new instead')
  static CardMoved create() => CardMoved._();
  static $pb.GeneratedMessage $_createMessage() => CardMoved._();
  @$core.override
  CardMoved createEmptyInstance() => CardMoved._();
  @$core.pragma('dart2js:noInline')
  static CardMoved getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CardMoved>(CardMoved.$_createMessage);
  static CardMoved? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get itemId => $_getSZ(0);
  @$pb.TagNumber(1)
  set itemId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasItemId() => $_has(0);
  @$pb.TagNumber(1)
  void clearItemId() => $_clearField(1);

  /// La carta va antes de esta carta. Ausente, o un item_id que no está: al
  /// final del mazo.
  @$pb.TagNumber(2)
  $core.String get beforeItemId => $_getSZ(1);
  @$pb.TagNumber(2)
  set beforeItemId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBeforeItemId() => $_has(1);
  @$pb.TagNumber(2)
  void clearBeforeItemId() => $_clearField(2);
}

class CardChanged extends $pb.GeneratedMessage {
  factory CardChanged({
    Card? card,
  }) {
    final result = CardChanged._();
    if (card != null) result.card = card;
    return result;
  }

  CardChanged._();

  factory CardChanged.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardChanged()..mergeFromBuffer(data, registry);
  factory CardChanged.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardChanged()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CardChanged',
      createEmptyInstance: CardChanged.$_createMessage)
    ..aOM<Card>(1, _omitFieldNames ? '' : 'card',
        subBuilder: Card.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardChanged clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardChanged copyWith(void Function(CardChanged) updates) =>
      super.copyWith((message) => updates(message as CardChanged))
          as CardChanged;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CardChanged() / CardChanged.new instead')
  static CardChanged create() => CardChanged._();
  static $pb.GeneratedMessage $_createMessage() => CardChanged._();
  @$core.override
  CardChanged createEmptyInstance() => CardChanged._();
  @$core.pragma('dart2js:noInline')
  static CardChanged getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CardChanged>(
          CardChanged.$_createMessage);
  static CardChanged? _defaultInstance;

  @$pb.TagNumber(1)
  Card get card => $_getN(0);
  @$pb.TagNumber(1)
  set card(Card value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCard() => $_has(0);
  @$pb.TagNumber(1)
  void clearCard() => $_clearField(1);
  @$pb.TagNumber(1)
  Card ensureCard() => $_ensure(0);
}

class Deck extends $pb.GeneratedMessage {
  factory Deck({
    $core.String? deckId,
    $core.String? title,
    $core.Iterable<DeckAction>? actions,
    $core.Iterable<Card>? cards,
    $core.bool? showProgress,
    $core.String? endText,
    $core.String? doneText,
  }) {
    final result = Deck._();
    if (deckId != null) result.deckId = deckId;
    if (title != null) result.title = title;
    if (actions != null) result.actions.addAll(actions);
    if (cards != null) result.cards.addAll(cards);
    if (showProgress != null) result.showProgress = showProgress;
    if (endText != null) result.endText = endText;
    if (doneText != null) result.doneText = doneText;
    return result;
  }

  Deck._();

  factory Deck.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Deck()..mergeFromBuffer(data, registry);
  factory Deck.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Deck()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Deck',
      createEmptyInstance: Deck.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'deckId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..pPM<DeckAction>(3, _omitFieldNames ? '' : 'actions',
        subBuilder: DeckAction.$_createMessage)
    ..pPM<Card>(4, _omitFieldNames ? '' : 'cards',
        subBuilder: Card.$_createMessage)
    ..aOB(5, _omitFieldNames ? '' : 'showProgress')
    ..aOS(6, _omitFieldNames ? '' : 'endText')
    ..aOS(7, _omitFieldNames ? '' : 'doneText')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Deck clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Deck copyWith(void Function(Deck) updates) =>
      super.copyWith((message) => updates(message as Deck)) as Deck;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Deck() / Deck.new instead')
  static Deck create() => Deck._();
  static $pb.GeneratedMessage $_createMessage() => Deck._();
  @$core.override
  Deck createEmptyInstance() => Deck._();
  @$core.pragma('dart2js:noInline')
  static Deck getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Deck>(Deck.$_createMessage);
  static Deck? _defaultInstance;

  /// Nombre del mazo. 1 a 64 caracteres: A-Z, a-z, 0-9, - y _. Vacío: no hay
  /// mazo (el servicio no tiene nada que mostrar todavía).
  @$pb.TagNumber(1)
  $core.String get deckId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deckId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeckId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeckId() => $_clearField(1);

  /// Título del mazo para el usuario. Una línea.
  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// Las acciones del mazo: una para cada dirección de deslizar, y botones.
  @$pb.TagNumber(3)
  $pb.PbList<DeckAction> get actions => $_getList(2);

  /// Las cartas, en el orden en que el usuario las ve.
  @$pb.TagNumber(4)
  $pb.PbList<Card> get cards => $_getList(3);

  /// El cliente muestra la cuenta ("12 de 30").
  @$pb.TagNumber(5)
  $core.bool get showProgress => $_getBF(4);
  @$pb.TagNumber(5)
  set showProgress($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasShowProgress() => $_has(4);
  @$pb.TagNumber(5)
  void clearShowProgress() => $_clearField(5);

  /// Texto para el final del mazo, cuando no quedan cartas sin decisión.
  @$pb.TagNumber(6)
  $core.String get endText => $_getSZ(5);
  @$pb.TagNumber(6)
  set endText($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEndText() => $_has(5);
  @$pb.TagNumber(6)
  void clearEndText() => $_clearField(6);

  /// Texto que el cliente envía al chat, como mensaje del usuario, cuando el usuario
  /// toca el botón de volver al chat al final del mazo. Una línea, 256 bytes o menos.
  /// Sin texto, el cliente no envía nada.
  @$pb.TagNumber(7)
  $core.String get doneText => $_getSZ(6);
  @$pb.TagNumber(7)
  set doneText($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDoneText() => $_has(6);
  @$pb.TagNumber(7)
  void clearDoneText() => $_clearField(7);
}

class DeckAction extends $pb.GeneratedMessage {
  factory DeckAction({
    $core.String? actionId,
    $core.String? label,
    Icon? icon,
    Tone? tone,
    Direction? direction,
    $core.bool? keep,
  }) {
    final result = DeckAction._();
    if (actionId != null) result.actionId = actionId;
    if (label != null) result.label = label;
    if (icon != null) result.icon = icon;
    if (tone != null) result.tone = tone;
    if (direction != null) result.direction = direction;
    if (keep != null) result.keep = keep;
    return result;
  }

  DeckAction._();

  factory DeckAction.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeckAction()..mergeFromBuffer(data, registry);
  factory DeckAction.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeckAction()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeckAction',
      createEmptyInstance: DeckAction.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'actionId')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aE<Icon>(3, _omitFieldNames ? '' : 'icon', enumValues: Icon.values)
    ..aE<Tone>(4, _omitFieldNames ? '' : 'tone', enumValues: Tone.values)
    ..aE<Direction>(5, _omitFieldNames ? '' : 'direction',
        enumValues: Direction.values)
    ..aOB(6, _omitFieldNames ? '' : 'keep')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeckAction clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeckAction copyWith(void Function(DeckAction) updates) =>
      super.copyWith((message) => updates(message as DeckAction)) as DeckAction;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DeckAction() / DeckAction.new instead')
  static DeckAction create() => DeckAction._();
  static $pb.GeneratedMessage $_createMessage() => DeckAction._();
  @$core.override
  DeckAction createEmptyInstance() => DeckAction._();
  @$core.pragma('dart2js:noInline')
  static DeckAction getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeckAction>(DeckAction.$_createMessage);
  static DeckAction? _defaultInstance;

  /// Nombre de la acción. 1 a 64 caracteres: A-Z, a-z, 0-9, - y _. Único en el
  /// mazo.
  @$pb.TagNumber(1)
  $core.String get actionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set actionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasActionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearActionId() => $_clearField(1);

  /// Texto del botón. 1 a 32 caracteres, una línea.
  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  /// Icono de la lista fija de cards.md.
  @$pb.TagNumber(3)
  Icon get icon => $_getN(2);
  @$pb.TagNumber(3)
  set icon(Icon value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearIcon() => $_clearField(3);

  /// Color, por su papel; el cliente toma el color del tema.
  @$pb.TagNumber(4)
  Tone get tone => $_getN(3);
  @$pb.TagNumber(4)
  set tone(Tone value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasTone() => $_has(3);
  @$pb.TagNumber(4)
  void clearTone() => $_clearField(4);

  /// Dirección de deslizar que hace esta acción. DIRECTION_NONE: solo botón.
  /// Dos acciones no tienen la misma dirección.
  @$pb.TagNumber(5)
  Direction get direction => $_getN(4);
  @$pb.TagNumber(5)
  set direction(Direction value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasDirection() => $_has(4);
  @$pb.TagNumber(5)
  void clearDirection() => $_clearField(5);

  /// true: la carta no queda hecha con esta acción. Pasa al final del mazo y
  /// vuelve a salir cuando se han recorrido las demás, hasta que el usuario
  /// haga otra acción (por ejemplo "Quizá"). El cliente envía la decisión igual.
  @$pb.TagNumber(6)
  $core.bool get keep => $_getBF(5);
  @$pb.TagNumber(6)
  set keep($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasKeep() => $_has(5);
  @$pb.TagNumber(6)
  void clearKeep() => $_clearField(6);
}

class Card extends $pb.GeneratedMessage {
  factory Card({
    $core.String? itemId,
    $core.String? title,
    $core.String? text,
    $1.ImageContent? image,
    $core.String? detail,
    $core.Iterable<CardButton>? buttons,
    Tone? tone,
    Layout? layout,
    $core.String? group,
    $core.String? decision,
  }) {
    final result = Card._();
    if (itemId != null) result.itemId = itemId;
    if (title != null) result.title = title;
    if (text != null) result.text = text;
    if (image != null) result.image = image;
    if (detail != null) result.detail = detail;
    if (buttons != null) result.buttons.addAll(buttons);
    if (tone != null) result.tone = tone;
    if (layout != null) result.layout = layout;
    if (group != null) result.group = group;
    if (decision != null) result.decision = decision;
    return result;
  }

  Card._();

  factory Card.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Card()..mergeFromBuffer(data, registry);
  factory Card.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Card()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Card',
      createEmptyInstance: Card.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'itemId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..aOM<$1.ImageContent>(4, _omitFieldNames ? '' : 'image',
        subBuilder: $1.ImageContent.$_createMessage)
    ..aOS(5, _omitFieldNames ? '' : 'detail')
    ..pPM<CardButton>(6, _omitFieldNames ? '' : 'buttons',
        subBuilder: CardButton.$_createMessage)
    ..aE<Tone>(7, _omitFieldNames ? '' : 'tone', enumValues: Tone.values)
    ..aE<Layout>(8, _omitFieldNames ? '' : 'layout', enumValues: Layout.values)
    ..aOS(9, _omitFieldNames ? '' : 'group')
    ..aOS(10, _omitFieldNames ? '' : 'decision')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Card clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Card copyWith(void Function(Card) updates) =>
      super.copyWith((message) => updates(message as Card)) as Card;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Card() / Card.new instead')
  static Card create() => Card._();
  static $pb.GeneratedMessage $_createMessage() => Card._();
  @$core.override
  Card createEmptyInstance() => Card._();
  @$core.pragma('dart2js:noInline')
  static Card getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Card>(Card.$_createMessage);
  static Card? _defaultInstance;

  /// Nombre de la carta. 1 a 64 caracteres: A-Z, a-z, 0-9, - y _. Único en el
  /// mazo y estable: no cambia cuando el servicio recarga el mazo.
  @$pb.TagNumber(1)
  $core.String get itemId => $_getSZ(0);
  @$pb.TagNumber(1)
  set itemId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasItemId() => $_has(0);
  @$pb.TagNumber(1)
  void clearItemId() => $_clearField(1);

  /// Título. 1 a 256 bytes de UTF-8, una línea.
  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// Texto corto bajo el título. Texto plano, 1 024 bytes o menos.
  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);

  /// Imagen. Se lee con FileService cuando hace falta (chat.md, 6.4).
  @$pb.TagNumber(4)
  $1.ImageContent get image => $_getN(3);
  @$pb.TagNumber(4)
  set image($1.ImageContent value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasImage() => $_has(3);
  @$pb.TagNumber(4)
  void clearImage() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.ImageContent ensureImage() => $_ensure(3);

  /// Texto de la vista de detalle, que abre un toque. Texto plano, 16 384
  /// bytes o menos.
  @$pb.TagNumber(5)
  $core.String get detail => $_getSZ(4);
  @$pb.TagNumber(5)
  set detail($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDetail() => $_has(4);
  @$pb.TagNumber(5)
  void clearDetail() => $_clearField(5);

  /// Botones propios de la carta (además de las acciones del mazo).
  @$pb.TagNumber(6)
  $pb.PbList<CardButton> get buttons => $_getList(5);

  /// Color de la carta, por su papel.
  @$pb.TagNumber(7)
  Tone get tone => $_getN(6);
  @$pb.TagNumber(7)
  set tone(Tone value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasTone() => $_has(6);
  @$pb.TagNumber(7)
  void clearTone() => $_clearField(7);

  /// Forma de la carta.
  @$pb.TagNumber(8)
  Layout get layout => $_getN(7);
  @$pb.TagNumber(8)
  set layout(Layout value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasLayout() => $_has(7);
  @$pb.TagNumber(8)
  void clearLayout() => $_clearField(8);

  /// Grupo de la carta, por ejemplo el pasillo de la tienda. Una línea.
  @$pb.TagNumber(9)
  $core.String get group => $_getSZ(8);
  @$pb.TagNumber(9)
  set group($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasGroup() => $_has(8);
  @$pb.TagNumber(9)
  void clearGroup() => $_clearField(9);

  /// La decisión que el servicio ya tiene para esta carta (un action_id).
  /// Una carta con decisión está hecha: el cliente no la muestra como la
  /// siguiente.
  @$pb.TagNumber(10)
  $core.String get decision => $_getSZ(9);
  @$pb.TagNumber(10)
  set decision($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDecision() => $_has(9);
  @$pb.TagNumber(10)
  void clearDecision() => $_clearField(10);
}

class CardButton extends $pb.GeneratedMessage {
  factory CardButton({
    $core.String? actionId,
    $core.String? label,
    Icon? icon,
    Tone? tone,
  }) {
    final result = CardButton._();
    if (actionId != null) result.actionId = actionId;
    if (label != null) result.label = label;
    if (icon != null) result.icon = icon;
    if (tone != null) result.tone = tone;
    return result;
  }

  CardButton._();

  factory CardButton.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardButton()..mergeFromBuffer(data, registry);
  factory CardButton.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardButton()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CardButton',
      createEmptyInstance: CardButton.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'actionId')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aE<Icon>(3, _omitFieldNames ? '' : 'icon', enumValues: Icon.values)
    ..aE<Tone>(4, _omitFieldNames ? '' : 'tone', enumValues: Tone.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardButton clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardButton copyWith(void Function(CardButton) updates) =>
      super.copyWith((message) => updates(message as CardButton)) as CardButton;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CardButton() / CardButton.new instead')
  static CardButton create() => CardButton._();
  static $pb.GeneratedMessage $_createMessage() => CardButton._();
  @$core.override
  CardButton createEmptyInstance() => CardButton._();
  @$core.pragma('dart2js:noInline')
  static CardButton getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CardButton>(CardButton.$_createMessage);
  static CardButton? _defaultInstance;

  /// La acción que envía el botón. 1 a 64 caracteres: A-Z, a-z, 0-9, - y _.
  @$pb.TagNumber(1)
  $core.String get actionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set actionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasActionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearActionId() => $_clearField(1);

  /// Texto del botón. 1 a 32 caracteres, una línea.
  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  Icon get icon => $_getN(2);
  @$pb.TagNumber(3)
  set icon(Icon value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearIcon() => $_clearField(3);

  @$pb.TagNumber(4)
  Tone get tone => $_getN(3);
  @$pb.TagNumber(4)
  set tone(Tone value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasTone() => $_has(3);
  @$pb.TagNumber(4)
  void clearTone() => $_clearField(4);
}

class SendActionRequest extends $pb.GeneratedMessage {
  factory SendActionRequest({
    $core.String? deckId,
    $core.String? itemId,
    $core.String? actionId,
    $core.String? idempotencyKey,
    $core.bool? undo,
    $fixnum.Int64? actedAt,
  }) {
    final result = SendActionRequest._();
    if (deckId != null) result.deckId = deckId;
    if (itemId != null) result.itemId = itemId;
    if (actionId != null) result.actionId = actionId;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    if (undo != null) result.undo = undo;
    if (actedAt != null) result.actedAt = actedAt;
    return result;
  }

  SendActionRequest._();

  factory SendActionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendActionRequest()..mergeFromBuffer(data, registry);
  factory SendActionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendActionRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendActionRequest',
      createEmptyInstance: SendActionRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'deckId')
    ..aOS(2, _omitFieldNames ? '' : 'itemId')
    ..aOS(3, _omitFieldNames ? '' : 'actionId')
    ..aOS(4, _omitFieldNames ? '' : 'idempotencyKey')
    ..aOB(5, _omitFieldNames ? '' : 'undo')
    ..aInt64(6, _omitFieldNames ? '' : 'actedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendActionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendActionRequest copyWith(void Function(SendActionRequest) updates) =>
      super.copyWith((message) => updates(message as SendActionRequest))
          as SendActionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SendActionRequest() / SendActionRequest.new instead')
  static SendActionRequest create() => SendActionRequest._();
  static $pb.GeneratedMessage $_createMessage() => SendActionRequest._();
  @$core.override
  SendActionRequest createEmptyInstance() => SendActionRequest._();
  @$core.pragma('dart2js:noInline')
  static SendActionRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SendActionRequest>(
          SendActionRequest.$_createMessage);
  static SendActionRequest? _defaultInstance;

  /// El mazo y la carta. Una carta o un mazo que el servicio ya no tiene no es
  /// un error: el servicio contesta OK y no hace nada (un deslizar tardío).
  @$pb.TagNumber(1)
  $core.String get deckId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deckId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeckId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeckId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get itemId => $_getSZ(1);
  @$pb.TagNumber(2)
  set itemId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasItemId() => $_has(1);
  @$pb.TagNumber(2)
  void clearItemId() => $_clearField(2);

  /// La acción (DeckAction.action_id o CardButton.action_id). Con undo, la
  /// acción que se deshace.
  @$pb.TagNumber(3)
  $core.String get actionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set actionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearActionId() => $_clearField(3);

  /// Nombre de esta decisión. 1 a 64 caracteres: A-Z, a-z, 0-9, - y _. Único
  /// para cada decisión del cliente. La misma clave otra vez: OK, sin cambio.
  @$pb.TagNumber(4)
  $core.String get idempotencyKey => $_getSZ(3);
  @$pb.TagNumber(4)
  set idempotencyKey($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIdempotencyKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearIdempotencyKey() => $_clearField(4);

  /// true: deshace la última decisión de la carta. Es una decisión nueva
  /// sobre la misma carta: la historia solo crece.
  @$pb.TagNumber(5)
  $core.bool get undo => $_getBF(4);
  @$pb.TagNumber(5)
  set undo($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUndo() => $_has(4);
  @$pb.TagNumber(5)
  void clearUndo() => $_clearField(5);

  /// Momento en que el usuario hizo el movimiento, en milisegundos desde
  /// 1970-01-01 UTC. La cola del cliente puede enviarla más tarde.
  @$pb.TagNumber(6)
  $fixnum.Int64 get actedAt => $_getI64(5);
  @$pb.TagNumber(6)
  set actedAt($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasActedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearActedAt() => $_clearField(6);
}

class SendActionResponse extends $pb.GeneratedMessage {
  factory SendActionResponse() => SendActionResponse._();

  SendActionResponse._();

  factory SendActionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendActionResponse()..mergeFromBuffer(data, registry);
  factory SendActionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendActionResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendActionResponse',
      createEmptyInstance: SendActionResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendActionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendActionResponse copyWith(void Function(SendActionResponse) updates) =>
      super.copyWith((message) => updates(message as SendActionResponse))
          as SendActionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SendActionResponse() / SendActionResponse.new instead')
  static SendActionResponse create() => SendActionResponse._();
  static $pb.GeneratedMessage $_createMessage() => SendActionResponse._();
  @$core.override
  SendActionResponse createEmptyInstance() => SendActionResponse._();
  @$core.pragma('dart2js:noInline')
  static SendActionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendActionResponse>(
          SendActionResponse.$_createMessage);
  static SendActionResponse? _defaultInstance;
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
