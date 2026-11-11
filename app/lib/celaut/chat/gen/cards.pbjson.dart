// This is a generated file - do not edit.
//
// Generated from cards.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use directionDescriptor instead')
const Direction$json = {
  '1': 'Direction',
  '2': [
    {'1': 'DIRECTION_NONE', '2': 0},
    {'1': 'DIRECTION_LEFT', '2': 1},
    {'1': 'DIRECTION_RIGHT', '2': 2},
    {'1': 'DIRECTION_UP', '2': 3},
    {'1': 'DIRECTION_DOWN', '2': 4},
  ],
};

/// Descriptor for `Direction`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List directionDescriptor = $convert.base64Decode(
    'CglEaXJlY3Rpb24SEgoORElSRUNUSU9OX05PTkUQABISCg5ESVJFQ1RJT05fTEVGVBABEhMKD0'
    'RJUkVDVElPTl9SSUdIVBACEhAKDERJUkVDVElPTl9VUBADEhIKDkRJUkVDVElPTl9ET1dOEAQ=');

@$core.Deprecated('Use toneDescriptor instead')
const Tone$json = {
  '1': 'Tone',
  '2': [
    {'1': 'TONE_NEUTRAL', '2': 0},
    {'1': 'TONE_POSITIVE', '2': 1},
    {'1': 'TONE_NEGATIVE', '2': 2},
    {'1': 'TONE_WARNING', '2': 3},
    {'1': 'TONE_ACCENT', '2': 4},
  ],
};

/// Descriptor for `Tone`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List toneDescriptor = $convert.base64Decode(
    'CgRUb25lEhAKDFRPTkVfTkVVVFJBTBAAEhEKDVRPTkVfUE9TSVRJVkUQARIRCg1UT05FX05FR0'
    'FUSVZFEAISEAoMVE9ORV9XQVJOSU5HEAMSDwoLVE9ORV9BQ0NFTlQQBA==');

@$core.Deprecated('Use layoutDescriptor instead')
const Layout$json = {
  '1': 'Layout',
  '2': [
    {'1': 'LAYOUT_IMAGE_TOP', '2': 0},
    {'1': 'LAYOUT_IMAGE_FULL', '2': 1},
    {'1': 'LAYOUT_TEXT', '2': 2},
  ],
};

/// Descriptor for `Layout`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List layoutDescriptor = $convert.base64Decode(
    'CgZMYXlvdXQSFAoQTEFZT1VUX0lNQUdFX1RPUBAAEhUKEUxBWU9VVF9JTUFHRV9GVUxMEAESDw'
    'oLTEFZT1VUX1RFWFQQAg==');

@$core.Deprecated('Use iconDescriptor instead')
const Icon$json = {
  '1': 'Icon',
  '2': [
    {'1': 'ICON_NONE', '2': 0},
    {'1': 'ICON_CHECK', '2': 1},
    {'1': 'ICON_CLOSE', '2': 2},
    {'1': 'ICON_LATER', '2': 3},
    {'1': 'ICON_STAR', '2': 4},
    {'1': 'ICON_CART', '2': 5},
    {'1': 'ICON_ARCHIVE', '2': 6},
    {'1': 'ICON_DELETE', '2': 7},
    {'1': 'ICON_FLAG', '2': 8},
    {'1': 'ICON_INFO', '2': 9},
  ],
};

/// Descriptor for `Icon`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List iconDescriptor = $convert.base64Decode(
    'CgRJY29uEg0KCUlDT05fTk9ORRAAEg4KCklDT05fQ0hFQ0sQARIOCgpJQ09OX0NMT1NFEAISDg'
    'oKSUNPTl9MQVRFUhADEg0KCUlDT05fU1RBUhAEEg0KCUlDT05fQ0FSVBAFEhAKDElDT05fQVJD'
    'SElWRRAGEg8KC0lDT05fREVMRVRFEAcSDQoJSUNPTl9GTEFHEAgSDQoJSUNPTl9JTkZPEAk=');

@$core.Deprecated('Use watchRequestDescriptor instead')
const WatchRequest$json = {
  '1': 'WatchRequest',
};

/// Descriptor for `WatchRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchRequestDescriptor =
    $convert.base64Decode('CgxXYXRjaFJlcXVlc3Q=');

@$core.Deprecated('Use deckEventDescriptor instead')
const DeckEvent$json = {
  '1': 'DeckEvent',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 4, '10': 'version'},
    {'1': 'deck_id', '3': 2, '4': 1, '5': 9, '10': 'deckId'},
    {'1': 'deck', '3': 3, '4': 1, '5': 11, '6': '.Deck', '9': 0, '10': 'deck'},
    {
      '1': 'cards_added',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.CardsAdded',
      '9': 0,
      '10': 'cardsAdded'
    },
    {
      '1': 'cards_removed',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.CardsRemoved',
      '9': 0,
      '10': 'cardsRemoved'
    },
    {
      '1': 'card_moved',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.CardMoved',
      '9': 0,
      '10': 'cardMoved'
    },
    {
      '1': 'card_changed',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.CardChanged',
      '9': 0,
      '10': 'cardChanged'
    },
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `DeckEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deckEventDescriptor = $convert.base64Decode(
    'CglEZWNrRXZlbnQSGAoHdmVyc2lvbhgBIAEoBFIHdmVyc2lvbhIXCgdkZWNrX2lkGAIgASgJUg'
    'ZkZWNrSWQSGwoEZGVjaxgDIAEoCzIFLkRlY2tIAFIEZGVjaxIuCgtjYXJkc19hZGRlZBgEIAEo'
    'CzILLkNhcmRzQWRkZWRIAFIKY2FyZHNBZGRlZBI0Cg1jYXJkc19yZW1vdmVkGAUgASgLMg0uQ2'
    'FyZHNSZW1vdmVkSABSDGNhcmRzUmVtb3ZlZBIrCgpjYXJkX21vdmVkGAYgASgLMgouQ2FyZE1v'
    'dmVkSABSCWNhcmRNb3ZlZBIxCgxjYXJkX2NoYW5nZWQYByABKAsyDC5DYXJkQ2hhbmdlZEgAUg'
    'tjYXJkQ2hhbmdlZEIHCgVldmVudA==');

@$core.Deprecated('Use cardsAddedDescriptor instead')
const CardsAdded$json = {
  '1': 'CardsAdded',
  '2': [
    {'1': 'cards', '3': 1, '4': 3, '5': 11, '6': '.Card', '10': 'cards'},
    {
      '1': 'before_item_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'beforeItemId',
      '17': true
    },
  ],
  '8': [
    {'1': '_before_item_id'},
  ],
};

/// Descriptor for `CardsAdded`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cardsAddedDescriptor = $convert.base64Decode(
    'CgpDYXJkc0FkZGVkEhsKBWNhcmRzGAEgAygLMgUuQ2FyZFIFY2FyZHMSKQoOYmVmb3JlX2l0ZW'
    '1faWQYAiABKAlIAFIMYmVmb3JlSXRlbUlkiAEBQhEKD19iZWZvcmVfaXRlbV9pZA==');

@$core.Deprecated('Use cardsRemovedDescriptor instead')
const CardsRemoved$json = {
  '1': 'CardsRemoved',
  '2': [
    {'1': 'item_ids', '3': 1, '4': 3, '5': 9, '10': 'itemIds'},
  ],
};

/// Descriptor for `CardsRemoved`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cardsRemovedDescriptor = $convert
    .base64Decode('CgxDYXJkc1JlbW92ZWQSGQoIaXRlbV9pZHMYASADKAlSB2l0ZW1JZHM=');

@$core.Deprecated('Use cardMovedDescriptor instead')
const CardMoved$json = {
  '1': 'CardMoved',
  '2': [
    {'1': 'item_id', '3': 1, '4': 1, '5': 9, '10': 'itemId'},
    {
      '1': 'before_item_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'beforeItemId',
      '17': true
    },
  ],
  '8': [
    {'1': '_before_item_id'},
  ],
};

/// Descriptor for `CardMoved`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cardMovedDescriptor = $convert.base64Decode(
    'CglDYXJkTW92ZWQSFwoHaXRlbV9pZBgBIAEoCVIGaXRlbUlkEikKDmJlZm9yZV9pdGVtX2lkGA'
    'IgASgJSABSDGJlZm9yZUl0ZW1JZIgBAUIRCg9fYmVmb3JlX2l0ZW1faWQ=');

@$core.Deprecated('Use cardChangedDescriptor instead')
const CardChanged$json = {
  '1': 'CardChanged',
  '2': [
    {'1': 'card', '3': 1, '4': 1, '5': 11, '6': '.Card', '10': 'card'},
  ],
};

/// Descriptor for `CardChanged`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cardChangedDescriptor = $convert
    .base64Decode('CgtDYXJkQ2hhbmdlZBIZCgRjYXJkGAEgASgLMgUuQ2FyZFIEY2FyZA==');

@$core.Deprecated('Use deckDescriptor instead')
const Deck$json = {
  '1': 'Deck',
  '2': [
    {'1': 'deck_id', '3': 1, '4': 1, '5': 9, '10': 'deckId'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'title', '17': true},
    {
      '1': 'actions',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.DeckAction',
      '10': 'actions'
    },
    {'1': 'cards', '3': 4, '4': 3, '5': 11, '6': '.Card', '10': 'cards'},
    {'1': 'show_progress', '3': 5, '4': 1, '5': 8, '10': 'showProgress'},
    {
      '1': 'end_text',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'endText',
      '17': true
    },
  ],
  '8': [
    {'1': '_title'},
    {'1': '_end_text'},
  ],
};

/// Descriptor for `Deck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deckDescriptor = $convert.base64Decode(
    'CgREZWNrEhcKB2RlY2tfaWQYASABKAlSBmRlY2tJZBIZCgV0aXRsZRgCIAEoCUgAUgV0aXRsZY'
    'gBARIlCgdhY3Rpb25zGAMgAygLMgsuRGVja0FjdGlvblIHYWN0aW9ucxIbCgVjYXJkcxgEIAMo'
    'CzIFLkNhcmRSBWNhcmRzEiMKDXNob3dfcHJvZ3Jlc3MYBSABKAhSDHNob3dQcm9ncmVzcxIeCg'
    'hlbmRfdGV4dBgGIAEoCUgBUgdlbmRUZXh0iAEBQggKBl90aXRsZUILCglfZW5kX3RleHQ=');

@$core.Deprecated('Use deckActionDescriptor instead')
const DeckAction$json = {
  '1': 'DeckAction',
  '2': [
    {'1': 'action_id', '3': 1, '4': 1, '5': 9, '10': 'actionId'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
    {'1': 'icon', '3': 3, '4': 1, '5': 14, '6': '.Icon', '10': 'icon'},
    {'1': 'tone', '3': 4, '4': 1, '5': 14, '6': '.Tone', '10': 'tone'},
    {
      '1': 'direction',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.Direction',
      '10': 'direction'
    },
    {'1': 'keep', '3': 6, '4': 1, '5': 8, '10': 'keep'},
  ],
};

/// Descriptor for `DeckAction`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deckActionDescriptor = $convert.base64Decode(
    'CgpEZWNrQWN0aW9uEhsKCWFjdGlvbl9pZBgBIAEoCVIIYWN0aW9uSWQSFAoFbGFiZWwYAiABKA'
    'lSBWxhYmVsEhkKBGljb24YAyABKA4yBS5JY29uUgRpY29uEhkKBHRvbmUYBCABKA4yBS5Ub25l'
    'UgR0b25lEigKCWRpcmVjdGlvbhgFIAEoDjIKLkRpcmVjdGlvblIJZGlyZWN0aW9uEhIKBGtlZX'
    'AYBiABKAhSBGtlZXA=');

@$core.Deprecated('Use cardDescriptor instead')
const Card$json = {
  '1': 'Card',
  '2': [
    {'1': 'item_id', '3': 1, '4': 1, '5': 9, '10': 'itemId'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'text', '17': true},
    {
      '1': 'image',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.ImageContent',
      '9': 1,
      '10': 'image',
      '17': true
    },
    {'1': 'detail', '3': 5, '4': 1, '5': 9, '9': 2, '10': 'detail', '17': true},
    {
      '1': 'buttons',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.CardButton',
      '10': 'buttons'
    },
    {'1': 'tone', '3': 7, '4': 1, '5': 14, '6': '.Tone', '10': 'tone'},
    {'1': 'layout', '3': 8, '4': 1, '5': 14, '6': '.Layout', '10': 'layout'},
    {'1': 'group', '3': 9, '4': 1, '5': 9, '9': 3, '10': 'group', '17': true},
    {
      '1': 'decision',
      '3': 10,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'decision',
      '17': true
    },
  ],
  '8': [
    {'1': '_text'},
    {'1': '_image'},
    {'1': '_detail'},
    {'1': '_group'},
    {'1': '_decision'},
  ],
};

/// Descriptor for `Card`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cardDescriptor = $convert.base64Decode(
    'CgRDYXJkEhcKB2l0ZW1faWQYASABKAlSBml0ZW1JZBIUCgV0aXRsZRgCIAEoCVIFdGl0bGUSFw'
    'oEdGV4dBgDIAEoCUgAUgR0ZXh0iAEBEigKBWltYWdlGAQgASgLMg0uSW1hZ2VDb250ZW50SAFS'
    'BWltYWdliAEBEhsKBmRldGFpbBgFIAEoCUgCUgZkZXRhaWyIAQESJQoHYnV0dG9ucxgGIAMoCz'
    'ILLkNhcmRCdXR0b25SB2J1dHRvbnMSGQoEdG9uZRgHIAEoDjIFLlRvbmVSBHRvbmUSHwoGbGF5'
    'b3V0GAggASgOMgcuTGF5b3V0UgZsYXlvdXQSGQoFZ3JvdXAYCSABKAlIA1IFZ3JvdXCIAQESHw'
    'oIZGVjaXNpb24YCiABKAlIBFIIZGVjaXNpb26IAQFCBwoFX3RleHRCCAoGX2ltYWdlQgkKB19k'
    'ZXRhaWxCCAoGX2dyb3VwQgsKCV9kZWNpc2lvbg==');

@$core.Deprecated('Use cardButtonDescriptor instead')
const CardButton$json = {
  '1': 'CardButton',
  '2': [
    {'1': 'action_id', '3': 1, '4': 1, '5': 9, '10': 'actionId'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
    {'1': 'icon', '3': 3, '4': 1, '5': 14, '6': '.Icon', '10': 'icon'},
    {'1': 'tone', '3': 4, '4': 1, '5': 14, '6': '.Tone', '10': 'tone'},
  ],
};

/// Descriptor for `CardButton`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cardButtonDescriptor = $convert.base64Decode(
    'CgpDYXJkQnV0dG9uEhsKCWFjdGlvbl9pZBgBIAEoCVIIYWN0aW9uSWQSFAoFbGFiZWwYAiABKA'
    'lSBWxhYmVsEhkKBGljb24YAyABKA4yBS5JY29uUgRpY29uEhkKBHRvbmUYBCABKA4yBS5Ub25l'
    'UgR0b25l');

@$core.Deprecated('Use sendActionRequestDescriptor instead')
const SendActionRequest$json = {
  '1': 'SendActionRequest',
  '2': [
    {'1': 'deck_id', '3': 1, '4': 1, '5': 9, '10': 'deckId'},
    {'1': 'item_id', '3': 2, '4': 1, '5': 9, '10': 'itemId'},
    {'1': 'action_id', '3': 3, '4': 1, '5': 9, '10': 'actionId'},
    {'1': 'idempotency_key', '3': 4, '4': 1, '5': 9, '10': 'idempotencyKey'},
    {'1': 'undo', '3': 5, '4': 1, '5': 8, '10': 'undo'},
    {'1': 'acted_at', '3': 6, '4': 1, '5': 3, '10': 'actedAt'},
  ],
};

/// Descriptor for `SendActionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendActionRequestDescriptor = $convert.base64Decode(
    'ChFTZW5kQWN0aW9uUmVxdWVzdBIXCgdkZWNrX2lkGAEgASgJUgZkZWNrSWQSFwoHaXRlbV9pZB'
    'gCIAEoCVIGaXRlbUlkEhsKCWFjdGlvbl9pZBgDIAEoCVIIYWN0aW9uSWQSJwoPaWRlbXBvdGVu'
    'Y3lfa2V5GAQgASgJUg5pZGVtcG90ZW5jeUtleRISCgR1bmRvGAUgASgIUgR1bmRvEhkKCGFjdG'
    'VkX2F0GAYgASgDUgdhY3RlZEF0');

@$core.Deprecated('Use sendActionResponseDescriptor instead')
const SendActionResponse$json = {
  '1': 'SendActionResponse',
};

/// Descriptor for `SendActionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendActionResponseDescriptor =
    $convert.base64Decode('ChJTZW5kQWN0aW9uUmVzcG9uc2U=');
