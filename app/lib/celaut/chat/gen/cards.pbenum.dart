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

import 'package:protobuf/protobuf.dart' as $pb;

class Direction extends $pb.ProtobufEnum {
  static const Direction DIRECTION_NONE =
      Direction._(0, _omitEnumNames ? '' : 'DIRECTION_NONE');
  static const Direction DIRECTION_LEFT =
      Direction._(1, _omitEnumNames ? '' : 'DIRECTION_LEFT');
  static const Direction DIRECTION_RIGHT =
      Direction._(2, _omitEnumNames ? '' : 'DIRECTION_RIGHT');
  static const Direction DIRECTION_UP =
      Direction._(3, _omitEnumNames ? '' : 'DIRECTION_UP');
  static const Direction DIRECTION_DOWN =
      Direction._(4, _omitEnumNames ? '' : 'DIRECTION_DOWN');

  static const $core.List<Direction> values = <Direction>[
    DIRECTION_NONE,
    DIRECTION_LEFT,
    DIRECTION_RIGHT,
    DIRECTION_UP,
    DIRECTION_DOWN,
  ];

  static final $core.List<Direction?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static Direction? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Direction._(super.value, super.name);
}

/// El conjunto base de colores. Un valor que el cliente no conoce es
/// TONE_NEUTRAL.
class Tone extends $pb.ProtobufEnum {
  static const Tone TONE_NEUTRAL =
      Tone._(0, _omitEnumNames ? '' : 'TONE_NEUTRAL');
  static const Tone TONE_POSITIVE =
      Tone._(1, _omitEnumNames ? '' : 'TONE_POSITIVE');
  static const Tone TONE_NEGATIVE =
      Tone._(2, _omitEnumNames ? '' : 'TONE_NEGATIVE');
  static const Tone TONE_WARNING =
      Tone._(3, _omitEnumNames ? '' : 'TONE_WARNING');
  static const Tone TONE_ACCENT =
      Tone._(4, _omitEnumNames ? '' : 'TONE_ACCENT');

  static const $core.List<Tone> values = <Tone>[
    TONE_NEUTRAL,
    TONE_POSITIVE,
    TONE_NEGATIVE,
    TONE_WARNING,
    TONE_ACCENT,
  ];

  static final $core.List<Tone?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static Tone? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Tone._(super.value, super.name);
}

/// El conjunto base de formas. Un valor que el cliente no conoce es
/// LAYOUT_IMAGE_TOP.
class Layout extends $pb.ProtobufEnum {
  /// Imagen arriba (si hay), y el texto debajo.
  static const Layout LAYOUT_IMAGE_TOP =
      Layout._(0, _omitEnumNames ? '' : 'LAYOUT_IMAGE_TOP');

  /// La imagen ocupa la carta y el texto va encima, abajo.
  static const Layout LAYOUT_IMAGE_FULL =
      Layout._(1, _omitEnumNames ? '' : 'LAYOUT_IMAGE_FULL');

  /// Solo texto: el cliente no muestra la imagen.
  static const Layout LAYOUT_TEXT =
      Layout._(2, _omitEnumNames ? '' : 'LAYOUT_TEXT');

  static const $core.List<Layout> values = <Layout>[
    LAYOUT_IMAGE_TOP,
    LAYOUT_IMAGE_FULL,
    LAYOUT_TEXT,
  ];

  static final $core.List<Layout?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static Layout? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Layout._(super.value, super.name);
}

/// La lista fija de iconos. Un valor que el cliente no conoce es ICON_NONE.
class Icon extends $pb.ProtobufEnum {
  static const Icon ICON_NONE = Icon._(0, _omitEnumNames ? '' : 'ICON_NONE');
  static const Icon ICON_CHECK = Icon._(1, _omitEnumNames ? '' : 'ICON_CHECK');
  static const Icon ICON_CLOSE = Icon._(2, _omitEnumNames ? '' : 'ICON_CLOSE');
  static const Icon ICON_LATER = Icon._(3, _omitEnumNames ? '' : 'ICON_LATER');
  static const Icon ICON_STAR = Icon._(4, _omitEnumNames ? '' : 'ICON_STAR');
  static const Icon ICON_CART = Icon._(5, _omitEnumNames ? '' : 'ICON_CART');
  static const Icon ICON_ARCHIVE =
      Icon._(6, _omitEnumNames ? '' : 'ICON_ARCHIVE');
  static const Icon ICON_DELETE =
      Icon._(7, _omitEnumNames ? '' : 'ICON_DELETE');
  static const Icon ICON_FLAG = Icon._(8, _omitEnumNames ? '' : 'ICON_FLAG');
  static const Icon ICON_INFO = Icon._(9, _omitEnumNames ? '' : 'ICON_INFO');

  static const $core.List<Icon> values = <Icon>[
    ICON_NONE,
    ICON_CHECK,
    ICON_CLOSE,
    ICON_LATER,
    ICON_STAR,
    ICON_CART,
    ICON_ARCHIVE,
    ICON_DELETE,
    ICON_FLAG,
    ICON_INFO,
  ];

  static final $core.List<Icon?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 9);
  static Icon? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Icon._(super.value, super.name);
}

/// El conjunto base de grupos de sonido. Cada valor es un concepto: el cliente
/// elige el sonido concreto, corto (1 s o menos). Un valor que el cliente no
/// conoce es SOUND_DEFAULT.
class Sound extends $pb.ProtobufEnum {
  /// El cliente elige por el tone y por keep de la acción (cards.md, 5.5).
  static const Sound SOUND_DEFAULT =
      Sound._(0, _omitEnumNames ? '' : 'SOUND_DEFAULT');

  /// Se acepta, se hace, se confirma.
  static const Sound SOUND_CONFIRM =
      Sound._(1, _omitEnumNames ? '' : 'SOUND_CONFIRM');

  /// Se rechaza, se quita, se borra.
  static const Sound SOUND_REJECT =
      Sound._(2, _omitEnumNames ? '' : 'SOUND_REJECT');

  /// Se deja para después: la carta vuelve más tarde.
  static const Sound SOUND_LATER =
      Sound._(3, _omitEnumNames ? '' : 'SOUND_LATER');

  /// Una decisión que destaca: favorito, urgente, importante.
  static const Sound SOUND_SPECIAL =
      Sound._(4, _omitEnumNames ? '' : 'SOUND_SPECIAL');

  static const $core.List<Sound> values = <Sound>[
    SOUND_DEFAULT,
    SOUND_CONFIRM,
    SOUND_REJECT,
    SOUND_LATER,
    SOUND_SPECIAL,
  ];

  static final $core.List<Sound?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static Sound? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Sound._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
