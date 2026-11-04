// This is a generated file - do not edit.
//
// Generated from chat.proto.

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

@$core.Deprecated('Use messageStatusDescriptor instead')
const MessageStatus$json = {
  '1': 'MessageStatus',
  '2': [
    {'1': 'MESSAGE_STATUS_UNSPECIFIED', '2': 0},
    {'1': 'MESSAGE_STATUS_PENDING', '2': 1},
    {'1': 'MESSAGE_STATUS_IN_PROGRESS', '2': 2},
    {'1': 'MESSAGE_STATUS_COMPLETED', '2': 3},
    {'1': 'MESSAGE_STATUS_FAILED', '2': 4},
    {'1': 'MESSAGE_STATUS_CANCELLED', '2': 5},
  ],
};

/// Descriptor for `MessageStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List messageStatusDescriptor = $convert.base64Decode(
    'Cg1NZXNzYWdlU3RhdHVzEh4KGk1FU1NBR0VfU1RBVFVTX1VOU1BFQ0lGSUVEEAASGgoWTUVTU0'
    'FHRV9TVEFUVVNfUEVORElORxABEh4KGk1FU1NBR0VfU1RBVFVTX0lOX1BST0dSRVNTEAISHAoY'
    'TUVTU0FHRV9TVEFUVVNfQ09NUExFVEVEEAMSGQoVTUVTU0FHRV9TVEFUVVNfRkFJTEVEEAQSHA'
    'oYTUVTU0FHRV9TVEFUVVNfQ0FOQ0VMTEVEEAU=');

@$core.Deprecated('Use conversationDescriptor instead')
const Conversation$json = {
  '1': 'Conversation',
  '2': [
    {'1': 'conversation_id', '3': 1, '4': 1, '5': 9, '10': 'conversationId'},
    {
      '1': 'parent_conversation_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'parentConversationId',
      '17': true
    },
    {
      '1': 'forked_from_message_id',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'forkedFromMessageId',
      '17': true
    },
    {'1': 'title', '3': 4, '4': 1, '5': 9, '9': 2, '10': 'title', '17': true},
    {'1': 'created_at', '3': 5, '4': 1, '5': 3, '10': 'createdAt'},
    {'1': 'archived', '3': 6, '4': 1, '5': 8, '10': 'archived'},
  ],
  '8': [
    {'1': '_parent_conversation_id'},
    {'1': '_forked_from_message_id'},
    {'1': '_title'},
  ],
};

/// Descriptor for `Conversation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List conversationDescriptor = $convert.base64Decode(
    'CgxDb252ZXJzYXRpb24SJwoPY29udmVyc2F0aW9uX2lkGAEgASgJUg5jb252ZXJzYXRpb25JZB'
    'I5ChZwYXJlbnRfY29udmVyc2F0aW9uX2lkGAIgASgJSABSFHBhcmVudENvbnZlcnNhdGlvbklk'
    'iAEBEjgKFmZvcmtlZF9mcm9tX21lc3NhZ2VfaWQYAyABKAlIAVITZm9ya2VkRnJvbU1lc3NhZ2'
    'VJZIgBARIZCgV0aXRsZRgEIAEoCUgCUgV0aXRsZYgBARIdCgpjcmVhdGVkX2F0GAUgASgDUglj'
    'cmVhdGVkQXQSGgoIYXJjaGl2ZWQYBiABKAhSCGFyY2hpdmVkQhkKF19wYXJlbnRfY29udmVyc2'
    'F0aW9uX2lkQhkKF19mb3JrZWRfZnJvbV9tZXNzYWdlX2lkQggKBl90aXRsZQ==');

@$core.Deprecated('Use forkConversationRequestDescriptor instead')
const ForkConversationRequest$json = {
  '1': 'ForkConversationRequest',
  '2': [
    {
      '1': 'parent_conversation_id',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'parentConversationId',
      '17': true
    },
    {
      '1': 'forked_from_message_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'forkedFromMessageId'
    },
    {'1': 'title', '3': 3, '4': 1, '5': 9, '9': 1, '10': 'title', '17': true},
  ],
  '8': [
    {'1': '_parent_conversation_id'},
    {'1': '_title'},
  ],
};

/// Descriptor for `ForkConversationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List forkConversationRequestDescriptor = $convert.base64Decode(
    'ChdGb3JrQ29udmVyc2F0aW9uUmVxdWVzdBI5ChZwYXJlbnRfY29udmVyc2F0aW9uX2lkGAEgAS'
    'gJSABSFHBhcmVudENvbnZlcnNhdGlvbklkiAEBEjMKFmZvcmtlZF9mcm9tX21lc3NhZ2VfaWQY'
    'AiABKAlSE2ZvcmtlZEZyb21NZXNzYWdlSWQSGQoFdGl0bGUYAyABKAlIAVIFdGl0bGWIAQFCGQ'
    'oXX3BhcmVudF9jb252ZXJzYXRpb25faWRCCAoGX3RpdGxl');

@$core.Deprecated('Use getConversationRequestDescriptor instead')
const GetConversationRequest$json = {
  '1': 'GetConversationRequest',
  '2': [
    {
      '1': 'conversation_id',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'conversationId',
      '17': true
    },
  ],
  '8': [
    {'1': '_conversation_id'},
  ],
};

/// Descriptor for `GetConversationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getConversationRequestDescriptor =
    $convert.base64Decode(
        'ChZHZXRDb252ZXJzYXRpb25SZXF1ZXN0EiwKD2NvbnZlcnNhdGlvbl9pZBgBIAEoCUgAUg5jb2'
        '52ZXJzYXRpb25JZIgBAUISChBfY29udmVyc2F0aW9uX2lk');

@$core.Deprecated('Use messageDescriptor instead')
const Message$json = {
  '1': 'Message',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'sequence', '3': 2, '4': 1, '5': 4, '10': 'sequence'},
    {
      '1': 'conversation_id',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'conversationId',
      '17': true
    },
    {
      '1': 'content',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.ContentPart',
      '10': 'content'
    },
    {
      '1': 'status',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.MessageStatus',
      '10': 'status'
    },
    {'1': 'created_at', '3': 6, '4': 1, '5': 3, '10': 'createdAt'},
    {'1': 'updated_at', '3': 7, '4': 1, '5': 3, '10': 'updatedAt'},
    {
      '1': 'reply_to_message_id',
      '3': 8,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'replyToMessageId',
      '17': true
    },
    {'1': 'pinned', '3': 9, '4': 1, '5': 8, '10': 'pinned'},
    {
      '1': 'metadata',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.Message.MetadataEntry',
      '10': 'metadata'
    },
    {'1': 'from_service', '3': 11, '4': 1, '5': 8, '10': 'fromService'},
    {'1': 'reasoning', '3': 12, '4': 1, '5': 9, '10': 'reasoning'},
    {
      '1': 'idempotency_key',
      '3': 13,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'idempotencyKey',
      '17': true
    },
    {'1': 'error', '3': 14, '4': 1, '5': 9, '9': 3, '10': 'error', '17': true},
    {'1': 'suggestions', '3': 15, '4': 3, '5': 9, '10': 'suggestions'},
    {
      '1': 'corrector',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.CorrectorState',
      '9': 4,
      '10': 'corrector',
      '17': true
    },
  ],
  '3': [Message_MetadataEntry$json],
  '8': [
    {'1': '_conversation_id'},
    {'1': '_reply_to_message_id'},
    {'1': '_idempotency_key'},
    {'1': '_error'},
    {'1': '_corrector'},
  ],
};

@$core.Deprecated('Use messageDescriptor instead')
const Message_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Message`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageDescriptor = $convert.base64Decode(
    'CgdNZXNzYWdlEh0KCm1lc3NhZ2VfaWQYASABKAlSCW1lc3NhZ2VJZBIaCghzZXF1ZW5jZRgCIA'
    'EoBFIIc2VxdWVuY2USLAoPY29udmVyc2F0aW9uX2lkGAMgASgJSABSDmNvbnZlcnNhdGlvbklk'
    'iAEBEiYKB2NvbnRlbnQYBCADKAsyDC5Db250ZW50UGFydFIHY29udGVudBImCgZzdGF0dXMYBS'
    'ABKA4yDi5NZXNzYWdlU3RhdHVzUgZzdGF0dXMSHQoKY3JlYXRlZF9hdBgGIAEoA1IJY3JlYXRl'
    'ZEF0Eh0KCnVwZGF0ZWRfYXQYByABKANSCXVwZGF0ZWRBdBIyChNyZXBseV90b19tZXNzYWdlX2'
    'lkGAggASgJSAFSEHJlcGx5VG9NZXNzYWdlSWSIAQESFgoGcGlubmVkGAkgASgIUgZwaW5uZWQS'
    'MgoIbWV0YWRhdGEYCiADKAsyFi5NZXNzYWdlLk1ldGFkYXRhRW50cnlSCG1ldGFkYXRhEiEKDG'
    'Zyb21fc2VydmljZRgLIAEoCFILZnJvbVNlcnZpY2USHAoJcmVhc29uaW5nGAwgASgJUglyZWFz'
    'b25pbmcSLAoPaWRlbXBvdGVuY3lfa2V5GA0gASgJSAJSDmlkZW1wb3RlbmN5S2V5iAEBEhkKBW'
    'Vycm9yGA4gASgJSANSBWVycm9yiAEBEiAKC3N1Z2dlc3Rpb25zGA8gAygJUgtzdWdnZXN0aW9u'
    'cxIyCgljb3JyZWN0b3IYECABKAsyDy5Db3JyZWN0b3JTdGF0ZUgEUgljb3JyZWN0b3KIAQEaOw'
    'oNTWV0YWRhdGFFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6'
    'AjgBQhIKEF9jb252ZXJzYXRpb25faWRCFgoUX3JlcGx5X3RvX21lc3NhZ2VfaWRCEgoQX2lkZW'
    '1wb3RlbmN5X2tleUIICgZfZXJyb3JCDAoKX2NvcnJlY3Rvcg==');

@$core.Deprecated('Use sendMessageRequestDescriptor instead')
const SendMessageRequest$json = {
  '1': 'SendMessageRequest',
  '2': [
    {
      '1': 'conversation_id',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'conversationId',
      '17': true
    },
    {
      '1': 'content',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.ContentPart',
      '10': 'content'
    },
    {
      '1': 'reply_to_message_id',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'replyToMessageId',
      '17': true
    },
    {
      '1': 'idempotency_key',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'idempotencyKey',
      '17': true
    },
    {
      '1': 'corrector',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.CorrectorState',
      '9': 3,
      '10': 'corrector',
      '17': true
    },
  ],
  '8': [
    {'1': '_conversation_id'},
    {'1': '_reply_to_message_id'},
    {'1': '_idempotency_key'},
    {'1': '_corrector'},
  ],
};

/// Descriptor for `SendMessageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendMessageRequestDescriptor = $convert.base64Decode(
    'ChJTZW5kTWVzc2FnZVJlcXVlc3QSLAoPY29udmVyc2F0aW9uX2lkGAEgASgJSABSDmNvbnZlcn'
    'NhdGlvbklkiAEBEiYKB2NvbnRlbnQYAiADKAsyDC5Db250ZW50UGFydFIHY29udGVudBIyChNy'
    'ZXBseV90b19tZXNzYWdlX2lkGAMgASgJSAFSEHJlcGx5VG9NZXNzYWdlSWSIAQESLAoPaWRlbX'
    'BvdGVuY3lfa2V5GAQgASgJSAJSDmlkZW1wb3RlbmN5S2V5iAEBEjIKCWNvcnJlY3RvchgFIAEo'
    'CzIPLkNvcnJlY3RvclN0YXRlSANSCWNvcnJlY3RvcogBAUISChBfY29udmVyc2F0aW9uX2lkQh'
    'YKFF9yZXBseV90b19tZXNzYWdlX2lkQhIKEF9pZGVtcG90ZW5jeV9rZXlCDAoKX2NvcnJlY3Rv'
    'cg==');

@$core.Deprecated('Use correctorStateDescriptor instead')
const CorrectorState$json = {
  '1': 'CorrectorState',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {
      '1': 'corrections',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.Correction',
      '10': 'corrections'
    },
  ],
};

/// Descriptor for `CorrectorState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List correctorStateDescriptor = $convert.base64Decode(
    'Cg5Db3JyZWN0b3JTdGF0ZRIYCgdlbmFibGVkGAEgASgIUgdlbmFibGVkEi0KC2NvcnJlY3Rpb2'
    '5zGAIgAygLMgsuQ29ycmVjdGlvblILY29ycmVjdGlvbnM=');

@$core.Deprecated('Use correctionDescriptor instead')
const Correction$json = {
  '1': 'Correction',
  '2': [
    {'1': 'original', '3': 1, '4': 1, '5': 9, '10': 'original'},
    {'1': 'replacement', '3': 2, '4': 1, '5': 9, '10': 'replacement'},
  ],
};

/// Descriptor for `Correction`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List correctionDescriptor = $convert.base64Decode(
    'CgpDb3JyZWN0aW9uEhoKCG9yaWdpbmFsGAEgASgJUghvcmlnaW5hbBIgCgtyZXBsYWNlbWVudB'
    'gCIAEoCVILcmVwbGFjZW1lbnQ=');

@$core.Deprecated('Use getMessagesRequestDescriptor instead')
const GetMessagesRequest$json = {
  '1': 'GetMessagesRequest',
  '2': [
    {
      '1': 'conversation_id',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'conversationId',
      '17': true
    },
    {'1': 'after_sequence', '3': 2, '4': 1, '5': 4, '10': 'afterSequence'},
    {'1': 'limit', '3': 3, '4': 1, '5': 13, '10': 'limit'},
    {'1': 'before_sequence', '3': 4, '4': 1, '5': 4, '10': 'beforeSequence'},
    {'1': 'last', '3': 5, '4': 1, '5': 13, '10': 'last'},
  ],
  '8': [
    {'1': '_conversation_id'},
  ],
};

/// Descriptor for `GetMessagesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMessagesRequestDescriptor = $convert.base64Decode(
    'ChJHZXRNZXNzYWdlc1JlcXVlc3QSLAoPY29udmVyc2F0aW9uX2lkGAEgASgJSABSDmNvbnZlcn'
    'NhdGlvbklkiAEBEiUKDmFmdGVyX3NlcXVlbmNlGAIgASgEUg1hZnRlclNlcXVlbmNlEhQKBWxp'
    'bWl0GAMgASgNUgVsaW1pdBInCg9iZWZvcmVfc2VxdWVuY2UYBCABKARSDmJlZm9yZVNlcXVlbm'
    'NlEhIKBGxhc3QYBSABKA1SBGxhc3RCEgoQX2NvbnZlcnNhdGlvbl9pZA==');

@$core.Deprecated('Use setMessagePinnedRequestDescriptor instead')
const SetMessagePinnedRequest$json = {
  '1': 'SetMessagePinnedRequest',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {
      '1': 'conversation_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'conversationId',
      '17': true
    },
    {'1': 'pinned', '3': 3, '4': 1, '5': 8, '10': 'pinned'},
  ],
  '8': [
    {'1': '_conversation_id'},
  ],
};

/// Descriptor for `SetMessagePinnedRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setMessagePinnedRequestDescriptor = $convert.base64Decode(
    'ChdTZXRNZXNzYWdlUGlubmVkUmVxdWVzdBIdCgptZXNzYWdlX2lkGAEgASgJUgltZXNzYWdlSW'
    'QSLAoPY29udmVyc2F0aW9uX2lkGAIgASgJSABSDmNvbnZlcnNhdGlvbklkiAEBEhYKBnBpbm5l'
    'ZBgDIAEoCFIGcGlubmVkQhIKEF9jb252ZXJzYXRpb25faWQ=');

@$core.Deprecated('Use messageCreatedDescriptor instead')
const MessageCreated$json = {
  '1': 'MessageCreated',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 11, '6': '.Message', '10': 'message'},
  ],
};

/// Descriptor for `MessageCreated`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageCreatedDescriptor = $convert.base64Decode(
    'Cg5NZXNzYWdlQ3JlYXRlZBIiCgdtZXNzYWdlGAEgASgLMgguTWVzc2FnZVIHbWVzc2FnZQ==');

@$core.Deprecated('Use messageDeletedDescriptor instead')
const MessageDeleted$json = {
  '1': 'MessageDeleted',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {
      '1': 'conversation_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'conversationId',
      '17': true
    },
  ],
  '8': [
    {'1': '_conversation_id'},
  ],
};

/// Descriptor for `MessageDeleted`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageDeletedDescriptor = $convert.base64Decode(
    'Cg5NZXNzYWdlRGVsZXRlZBIdCgptZXNzYWdlX2lkGAEgASgJUgltZXNzYWdlSWQSLAoPY29udm'
    'Vyc2F0aW9uX2lkGAIgASgJSABSDmNvbnZlcnNhdGlvbklkiAEBQhIKEF9jb252ZXJzYXRpb25f'
    'aWQ=');

@$core.Deprecated('Use messageStatusChangedDescriptor instead')
const MessageStatusChanged$json = {
  '1': 'MessageStatusChanged',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {
      '1': 'conversation_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'conversationId',
      '17': true
    },
    {
      '1': 'status',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.MessageStatus',
      '10': 'status'
    },
    {'1': 'updated_at', '3': 4, '4': 1, '5': 3, '10': 'updatedAt'},
    {'1': 'error', '3': 5, '4': 1, '5': 9, '9': 1, '10': 'error', '17': true},
    {'1': 'suggestions', '3': 6, '4': 3, '5': 9, '10': 'suggestions'},
  ],
  '8': [
    {'1': '_conversation_id'},
    {'1': '_error'},
  ],
};

/// Descriptor for `MessageStatusChanged`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageStatusChangedDescriptor = $convert.base64Decode(
    'ChRNZXNzYWdlU3RhdHVzQ2hhbmdlZBIdCgptZXNzYWdlX2lkGAEgASgJUgltZXNzYWdlSWQSLA'
    'oPY29udmVyc2F0aW9uX2lkGAIgASgJSABSDmNvbnZlcnNhdGlvbklkiAEBEiYKBnN0YXR1cxgD'
    'IAEoDjIOLk1lc3NhZ2VTdGF0dXNSBnN0YXR1cxIdCgp1cGRhdGVkX2F0GAQgASgDUgl1cGRhdG'
    'VkQXQSGQoFZXJyb3IYBSABKAlIAVIFZXJyb3KIAQESIAoLc3VnZ2VzdGlvbnMYBiADKAlSC3N1'
    'Z2dlc3Rpb25zQhIKEF9jb252ZXJzYXRpb25faWRCCAoGX2Vycm9y');

@$core.Deprecated('Use messageDeltaDescriptor instead')
const MessageDelta$json = {
  '1': 'MessageDelta',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {
      '1': 'conversation_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'conversationId',
      '17': true
    },
    {'1': 'text_append', '3': 3, '4': 1, '5': 9, '10': 'textAppend'},
    {'1': 'reasoning_append', '3': 4, '4': 1, '5': 9, '10': 'reasoningAppend'},
  ],
  '8': [
    {'1': '_conversation_id'},
  ],
};

/// Descriptor for `MessageDelta`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageDeltaDescriptor = $convert.base64Decode(
    'CgxNZXNzYWdlRGVsdGESHQoKbWVzc2FnZV9pZBgBIAEoCVIJbWVzc2FnZUlkEiwKD2NvbnZlcn'
    'NhdGlvbl9pZBgCIAEoCUgAUg5jb252ZXJzYXRpb25JZIgBARIfCgt0ZXh0X2FwcGVuZBgDIAEo'
    'CVIKdGV4dEFwcGVuZBIpChByZWFzb25pbmdfYXBwZW5kGAQgASgJUg9yZWFzb25pbmdBcHBlbm'
    'RCEgoQX2NvbnZlcnNhdGlvbl9pZA==');

@$core.Deprecated('Use messagePinnedChangedDescriptor instead')
const MessagePinnedChanged$json = {
  '1': 'MessagePinnedChanged',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {
      '1': 'conversation_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'conversationId',
      '17': true
    },
    {'1': 'pinned', '3': 3, '4': 1, '5': 8, '10': 'pinned'},
    {'1': 'updated_at', '3': 4, '4': 1, '5': 3, '10': 'updatedAt'},
  ],
  '8': [
    {'1': '_conversation_id'},
  ],
};

/// Descriptor for `MessagePinnedChanged`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messagePinnedChangedDescriptor = $convert.base64Decode(
    'ChRNZXNzYWdlUGlubmVkQ2hhbmdlZBIdCgptZXNzYWdlX2lkGAEgASgJUgltZXNzYWdlSWQSLA'
    'oPY29udmVyc2F0aW9uX2lkGAIgASgJSABSDmNvbnZlcnNhdGlvbklkiAEBEhYKBnBpbm5lZBgD'
    'IAEoCFIGcGlubmVkEh0KCnVwZGF0ZWRfYXQYBCABKANSCXVwZGF0ZWRBdEISChBfY29udmVyc2'
    'F0aW9uX2lk');

@$core.Deprecated('Use messageProgressDescriptor instead')
const MessageProgress$json = {
  '1': 'MessageProgress',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {
      '1': 'progress',
      '3': 2,
      '4': 1,
      '5': 2,
      '9': 0,
      '10': 'progress',
      '17': true
    },
    {
      '1': 'description',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'description',
      '17': true
    },
  ],
  '8': [
    {'1': '_progress'},
    {'1': '_description'},
  ],
};

/// Descriptor for `MessageProgress`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageProgressDescriptor = $convert.base64Decode(
    'Cg9NZXNzYWdlUHJvZ3Jlc3MSHQoKbWVzc2FnZV9pZBgBIAEoCVIJbWVzc2FnZUlkEh8KCHByb2'
    'dyZXNzGAIgASgCSABSCHByb2dyZXNziAEBEiUKC2Rlc2NyaXB0aW9uGAMgASgJSAFSC2Rlc2Ny'
    'aXB0aW9uiAEBQgsKCV9wcm9ncmVzc0IOCgxfZGVzY3JpcHRpb24=');

@$core.Deprecated('Use subscriptionReadyDescriptor instead')
const SubscriptionReady$json = {
  '1': 'SubscriptionReady',
  '2': [
    {'1': 'latest_sequence', '3': 1, '4': 1, '5': 4, '10': 'latestSequence'},
  ],
};

/// Descriptor for `SubscriptionReady`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscriptionReadyDescriptor = $convert.base64Decode(
    'ChFTdWJzY3JpcHRpb25SZWFkeRInCg9sYXRlc3Rfc2VxdWVuY2UYASABKARSDmxhdGVzdFNlcX'
    'VlbmNl');

@$core.Deprecated('Use protocolErrorDescriptor instead')
const ProtocolError$json = {
  '1': 'ProtocolError',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {
      '1': 'event_id',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'eventId',
      '17': true
    },
  ],
  '8': [
    {'1': '_event_id'},
  ],
};

/// Descriptor for `ProtocolError`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List protocolErrorDescriptor = $convert.base64Decode(
    'Cg1Qcm90b2NvbEVycm9yEhIKBGNvZGUYASABKAlSBGNvZGUSGAoHbWVzc2FnZRgCIAEoCVIHbW'
    'Vzc2FnZRIeCghldmVudF9pZBgDIAEoCUgAUgdldmVudElkiAEBQgsKCV9ldmVudF9pZA==');

@$core.Deprecated('Use answerSecretRequestRequestDescriptor instead')
const AnswerSecretRequestRequest$json = {
  '1': 'AnswerSecretRequestRequest',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'request_id', '3': 2, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'value', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'value'},
    {'1': 'skipped', '3': 4, '4': 1, '5': 8, '9': 0, '10': 'skipped'},
  ],
  '8': [
    {'1': 'answer'},
  ],
};

/// Descriptor for `AnswerSecretRequestRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List answerSecretRequestRequestDescriptor =
    $convert.base64Decode(
        'ChpBbnN3ZXJTZWNyZXRSZXF1ZXN0UmVxdWVzdBIdCgptZXNzYWdlX2lkGAEgASgJUgltZXNzYW'
        'dlSWQSHQoKcmVxdWVzdF9pZBgCIAEoCVIJcmVxdWVzdElkEhYKBXZhbHVlGAMgASgJSABSBXZh'
        'bHVlEhoKB3NraXBwZWQYBCABKAhIAFIHc2tpcHBlZEIICgZhbnN3ZXI=');

@$core.Deprecated('Use answerSecretRequestResponseDescriptor instead')
const AnswerSecretRequestResponse$json = {
  '1': 'AnswerSecretRequestResponse',
};

/// Descriptor for `AnswerSecretRequestResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List answerSecretRequestResponseDescriptor =
    $convert.base64Decode('ChtBbnN3ZXJTZWNyZXRSZXF1ZXN0UmVzcG9uc2U=');

@$core.Deprecated('Use contentPartDescriptor instead')
const ContentPart$json = {
  '1': 'ContentPart',
  '2': [
    {
      '1': 'text',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.TextContent',
      '9': 0,
      '10': 'text'
    },
    {
      '1': 'file',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.FileReference',
      '9': 0,
      '10': 'file'
    },
    {
      '1': 'image',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.ImageContent',
      '9': 0,
      '10': 'image'
    },
    {
      '1': 'audio',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.AudioContent',
      '9': 0,
      '10': 'audio'
    },
    {
      '1': 'structured',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.StructuredContent',
      '9': 0,
      '10': 'structured'
    },
    {
      '1': 'secret_request',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.SecretRequest',
      '9': 0,
      '10': 'secretRequest'
    },
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `ContentPart`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List contentPartDescriptor = $convert.base64Decode(
    'CgtDb250ZW50UGFydBIiCgR0ZXh0GAEgASgLMgwuVGV4dENvbnRlbnRIAFIEdGV4dBIkCgRmaW'
    'xlGAIgASgLMg4uRmlsZVJlZmVyZW5jZUgAUgRmaWxlEiUKBWltYWdlGAMgASgLMg0uSW1hZ2VD'
    'b250ZW50SABSBWltYWdlEiUKBWF1ZGlvGAQgASgLMg0uQXVkaW9Db250ZW50SABSBWF1ZGlvEj'
    'QKCnN0cnVjdHVyZWQYBSABKAsyEi5TdHJ1Y3R1cmVkQ29udGVudEgAUgpzdHJ1Y3R1cmVkEjcK'
    'DnNlY3JldF9yZXF1ZXN0GAYgASgLMg4uU2VjcmV0UmVxdWVzdEgAUg1zZWNyZXRSZXF1ZXN0Qg'
    'YKBGtpbmQ=');

@$core.Deprecated('Use secretRequestDescriptor instead')
const SecretRequest$json = {
  '1': 'SecretRequest',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'prose', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'prose', '17': true},
  ],
  '8': [
    {'1': '_prose'},
  ],
};

/// Descriptor for `SecretRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List secretRequestDescriptor = $convert.base64Decode(
    'Cg1TZWNyZXRSZXF1ZXN0Eh0KCnJlcXVlc3RfaWQYASABKAlSCXJlcXVlc3RJZBISCgRuYW1lGA'
    'IgASgJUgRuYW1lEhkKBXByb3NlGAMgASgJSABSBXByb3NliAEBQggKBl9wcm9zZQ==');

@$core.Deprecated('Use textContentDescriptor instead')
const TextContent$json = {
  '1': 'TextContent',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `TextContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textContentDescriptor =
    $convert.base64Decode('CgtUZXh0Q29udGVudBISCgR0ZXh0GAEgASgJUgR0ZXh0');

@$core.Deprecated('Use hashDescriptor instead')
const Hash$json = {
  '1': 'Hash',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 12, '10': 'type'},
    {'1': 'value', '3': 2, '4': 1, '5': 12, '10': 'value'},
  ],
};

/// Descriptor for `Hash`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List hashDescriptor = $convert.base64Decode(
    'CgRIYXNoEhIKBHR5cGUYASABKAxSBHR5cGUSFAoFdmFsdWUYAiABKAxSBXZhbHVl');

@$core.Deprecated('Use fileReferenceDescriptor instead')
const FileReference$json = {
  '1': 'FileReference',
  '2': [
    {'1': 'hashes', '3': 1, '4': 3, '5': 11, '6': '.Hash', '10': 'hashes'},
    {
      '1': 'filename',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'filename',
      '17': true
    },
    {
      '1': 'mime_type',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'mimeType',
      '17': true
    },
    {
      '1': 'size_bytes',
      '3': 4,
      '4': 1,
      '5': 4,
      '9': 2,
      '10': 'sizeBytes',
      '17': true
    },
  ],
  '8': [
    {'1': '_filename'},
    {'1': '_mime_type'},
    {'1': '_size_bytes'},
  ],
};

/// Descriptor for `FileReference`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fileReferenceDescriptor = $convert.base64Decode(
    'Cg1GaWxlUmVmZXJlbmNlEh0KBmhhc2hlcxgBIAMoCzIFLkhhc2hSBmhhc2hlcxIfCghmaWxlbm'
    'FtZRgCIAEoCUgAUghmaWxlbmFtZYgBARIgCgltaW1lX3R5cGUYAyABKAlIAVIIbWltZVR5cGWI'
    'AQESIgoKc2l6ZV9ieXRlcxgEIAEoBEgCUglzaXplQnl0ZXOIAQFCCwoJX2ZpbGVuYW1lQgwKCl'
    '9taW1lX3R5cGVCDQoLX3NpemVfYnl0ZXM=');

@$core.Deprecated('Use imageContentDescriptor instead')
const ImageContent$json = {
  '1': 'ImageContent',
  '2': [
    {'1': 'file', '3': 1, '4': 1, '5': 11, '6': '.FileReference', '10': 'file'},
    {
      '1': 'alt_text',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'altText',
      '17': true
    },
  ],
  '8': [
    {'1': '_alt_text'},
  ],
};

/// Descriptor for `ImageContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageContentDescriptor = $convert.base64Decode(
    'CgxJbWFnZUNvbnRlbnQSIgoEZmlsZRgBIAEoCzIOLkZpbGVSZWZlcmVuY2VSBGZpbGUSHgoIYW'
    'x0X3RleHQYAiABKAlIAFIHYWx0VGV4dIgBAUILCglfYWx0X3RleHQ=');

@$core.Deprecated('Use audioContentDescriptor instead')
const AudioContent$json = {
  '1': 'AudioContent',
  '2': [
    {'1': 'file', '3': 1, '4': 1, '5': 11, '6': '.FileReference', '10': 'file'},
    {
      '1': 'transcript',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'transcript',
      '17': true
    },
    {
      '1': 'duration_ms',
      '3': 3,
      '4': 1,
      '5': 4,
      '9': 1,
      '10': 'durationMs',
      '17': true
    },
  ],
  '8': [
    {'1': '_transcript'},
    {'1': '_duration_ms'},
  ],
};

/// Descriptor for `AudioContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List audioContentDescriptor = $convert.base64Decode(
    'CgxBdWRpb0NvbnRlbnQSIgoEZmlsZRgBIAEoCzIOLkZpbGVSZWZlcmVuY2VSBGZpbGUSIwoKdH'
    'JhbnNjcmlwdBgCIAEoCUgAUgp0cmFuc2NyaXB0iAEBEiQKC2R1cmF0aW9uX21zGAMgASgESAFS'
    'CmR1cmF0aW9uTXOIAQFCDQoLX3RyYW5zY3JpcHRCDgoMX2R1cmF0aW9uX21z');

@$core.Deprecated('Use structuredContentDescriptor instead')
const StructuredContent$json = {
  '1': 'StructuredContent',
  '2': [
    {'1': 'media_type', '3': 1, '4': 1, '5': 9, '10': 'mediaType'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `StructuredContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List structuredContentDescriptor = $convert.base64Decode(
    'ChFTdHJ1Y3R1cmVkQ29udGVudBIdCgptZWRpYV90eXBlGAEgASgJUgltZWRpYVR5cGUSEgoEZG'
    'F0YRgCIAEoDFIEZGF0YQ==');

@$core.Deprecated('Use queryFilesRequestDescriptor instead')
const QueryFilesRequest$json = {
  '1': 'QueryFilesRequest',
  '2': [
    {'1': 'hash', '3': 1, '4': 1, '5': 11, '6': '.Hash', '10': 'hash'},
  ],
};

/// Descriptor for `QueryFilesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List queryFilesRequestDescriptor = $convert.base64Decode(
    'ChFRdWVyeUZpbGVzUmVxdWVzdBIZCgRoYXNoGAEgASgLMgUuSGFzaFIEaGFzaA==');

@$core.Deprecated('Use queryFilesResponseDescriptor instead')
const QueryFilesResponse$json = {
  '1': 'QueryFilesResponse',
  '2': [
    {'1': 'hash', '3': 1, '4': 1, '5': 11, '6': '.Hash', '10': 'hash'},
    {'1': 'available', '3': 2, '4': 1, '5': 8, '10': 'available'},
  ],
};

/// Descriptor for `QueryFilesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List queryFilesResponseDescriptor = $convert.base64Decode(
    'ChJRdWVyeUZpbGVzUmVzcG9uc2USGQoEaGFzaBgBIAEoCzIFLkhhc2hSBGhhc2gSHAoJYXZhaW'
    'xhYmxlGAIgASgIUglhdmFpbGFibGU=');

@$core.Deprecated('Use uploadFileRequestDescriptor instead')
const UploadFileRequest$json = {
  '1': 'UploadFileRequest',
  '2': [
    {
      '1': 'file',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.FileReference',
      '9': 0,
      '10': 'file'
    },
    {'1': 'chunk', '3': 2, '4': 1, '5': 12, '9': 0, '10': 'chunk'},
  ],
  '8': [
    {'1': 'part'},
  ],
};

/// Descriptor for `UploadFileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uploadFileRequestDescriptor = $convert.base64Decode(
    'ChFVcGxvYWRGaWxlUmVxdWVzdBIkCgRmaWxlGAEgASgLMg4uRmlsZVJlZmVyZW5jZUgAUgRmaW'
    'xlEhYKBWNodW5rGAIgASgMSABSBWNodW5rQgYKBHBhcnQ=');

@$core.Deprecated('Use uploadFileResponseDescriptor instead')
const UploadFileResponse$json = {
  '1': 'UploadFileResponse',
  '2': [
    {'1': 'file', '3': 1, '4': 1, '5': 11, '6': '.FileReference', '10': 'file'},
  ],
};

/// Descriptor for `UploadFileResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uploadFileResponseDescriptor = $convert.base64Decode(
    'ChJVcGxvYWRGaWxlUmVzcG9uc2USIgoEZmlsZRgBIAEoCzIOLkZpbGVSZWZlcmVuY2VSBGZpbG'
    'U=');

@$core.Deprecated('Use downloadFileRequestDescriptor instead')
const DownloadFileRequest$json = {
  '1': 'DownloadFileRequest',
  '2': [
    {'1': 'hash', '3': 1, '4': 1, '5': 11, '6': '.Hash', '10': 'hash'},
  ],
};

/// Descriptor for `DownloadFileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List downloadFileRequestDescriptor =
    $convert.base64Decode(
        'ChNEb3dubG9hZEZpbGVSZXF1ZXN0EhkKBGhhc2gYASABKAsyBS5IYXNoUgRoYXNo');

@$core.Deprecated('Use downloadFileResponseDescriptor instead')
const DownloadFileResponse$json = {
  '1': 'DownloadFileResponse',
  '2': [
    {'1': 'chunk', '3': 1, '4': 1, '5': 12, '10': 'chunk'},
  ],
};

/// Descriptor for `DownloadFileResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List downloadFileResponseDescriptor =
    $convert.base64Decode(
        'ChREb3dubG9hZEZpbGVSZXNwb25zZRIUCgVjaHVuaxgBIAEoDFIFY2h1bms=');

@$core.Deprecated('Use getCapabilitiesRequestDescriptor instead')
const GetCapabilitiesRequest$json = {
  '1': 'GetCapabilitiesRequest',
};

/// Descriptor for `GetCapabilitiesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCapabilitiesRequestDescriptor =
    $convert.base64Decode('ChZHZXRDYXBhYmlsaXRpZXNSZXF1ZXN0');

@$core.Deprecated('Use capabilitiesDescriptor instead')
const Capabilities$json = {
  '1': 'Capabilities',
  '2': [
    {
      '1': 'accepted_mime_types',
      '3': 1,
      '4': 3,
      '5': 9,
      '10': 'acceptedMimeTypes'
    },
    {'1': 'max_file_bytes', '3': 2, '4': 1, '5': 4, '10': 'maxFileBytes'},
    {
      '1': 'max_files_per_message',
      '3': 3,
      '4': 1,
      '5': 13,
      '10': 'maxFilesPerMessage'
    },
    {'1': 'max_text_bytes', '3': 4, '4': 1, '5': 13, '10': 'maxTextBytes'},
    {'1': 'supports_fork', '3': 5, '4': 1, '5': 8, '10': 'supportsFork'},
    {'1': 'supports_cancel', '3': 6, '4': 1, '5': 8, '10': 'supportsCancel'},
  ],
};

/// Descriptor for `Capabilities`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List capabilitiesDescriptor = $convert.base64Decode(
    'CgxDYXBhYmlsaXRpZXMSLgoTYWNjZXB0ZWRfbWltZV90eXBlcxgBIAMoCVIRYWNjZXB0ZWRNaW'
    '1lVHlwZXMSJAoObWF4X2ZpbGVfYnl0ZXMYAiABKARSDG1heEZpbGVCeXRlcxIxChVtYXhfZmls'
    'ZXNfcGVyX21lc3NhZ2UYAyABKA1SEm1heEZpbGVzUGVyTWVzc2FnZRIkCg5tYXhfdGV4dF9ieX'
    'RlcxgEIAEoDVIMbWF4VGV4dEJ5dGVzEiMKDXN1cHBvcnRzX2ZvcmsYBSABKAhSDHN1cHBvcnRz'
    'Rm9yaxInCg9zdXBwb3J0c19jYW5jZWwYBiABKAhSDnN1cHBvcnRzQ2FuY2Vs');

@$core.Deprecated('Use clientEventDescriptor instead')
const ClientEvent$json = {
  '1': 'ClientEvent',
  '2': [
    {
      '1': 'send_message',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.SendMessageRequest',
      '9': 0,
      '10': 'sendMessage'
    },
    {
      '1': 'subscribe',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.SubscribeRequest',
      '9': 0,
      '10': 'subscribe'
    },
    {
      '1': 'acknowledge',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.AcknowledgeEvent',
      '9': 0,
      '10': 'acknowledge'
    },
    {
      '1': 'cancel_message',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.CancelMessageRequest',
      '9': 0,
      '10': 'cancelMessage'
    },
    {
      '1': 'event_id',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'eventId',
      '17': true
    },
  ],
  '8': [
    {'1': 'event'},
    {'1': '_event_id'},
  ],
};

/// Descriptor for `ClientEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientEventDescriptor = $convert.base64Decode(
    'CgtDbGllbnRFdmVudBI4CgxzZW5kX21lc3NhZ2UYASABKAsyEy5TZW5kTWVzc2FnZVJlcXVlc3'
    'RIAFILc2VuZE1lc3NhZ2USMQoJc3Vic2NyaWJlGAIgASgLMhEuU3Vic2NyaWJlUmVxdWVzdEgA'
    'UglzdWJzY3JpYmUSNQoLYWNrbm93bGVkZ2UYAyABKAsyES5BY2tub3dsZWRnZUV2ZW50SABSC2'
    'Fja25vd2xlZGdlEj4KDmNhbmNlbF9tZXNzYWdlGAQgASgLMhUuQ2FuY2VsTWVzc2FnZVJlcXVl'
    'c3RIAFINY2FuY2VsTWVzc2FnZRIeCghldmVudF9pZBgFIAEoCUgBUgdldmVudElkiAEBQgcKBW'
    'V2ZW50QgsKCV9ldmVudF9pZA==');

@$core.Deprecated('Use serverEventDescriptor instead')
const ServerEvent$json = {
  '1': 'ServerEvent',
  '2': [
    {
      '1': 'message_created',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.MessageCreated',
      '9': 0,
      '10': 'messageCreated'
    },
    {
      '1': 'message_deleted',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.MessageDeleted',
      '9': 0,
      '10': 'messageDeleted'
    },
    {
      '1': 'message_progress',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.MessageProgress',
      '9': 0,
      '10': 'messageProgress'
    },
    {
      '1': 'subscription_ready',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.SubscriptionReady',
      '9': 0,
      '10': 'subscriptionReady'
    },
    {
      '1': 'error',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.ProtocolError',
      '9': 0,
      '10': 'error'
    },
    {
      '1': 'message_status_changed',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.MessageStatusChanged',
      '9': 0,
      '10': 'messageStatusChanged'
    },
    {
      '1': 'message_delta',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.MessageDelta',
      '9': 0,
      '10': 'messageDelta'
    },
    {
      '1': 'message_pinned_changed',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.MessagePinnedChanged',
      '9': 0,
      '10': 'messagePinnedChanged'
    },
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `ServerEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverEventDescriptor = $convert.base64Decode(
    'CgtTZXJ2ZXJFdmVudBI6Cg9tZXNzYWdlX2NyZWF0ZWQYASABKAsyDy5NZXNzYWdlQ3JlYXRlZE'
    'gAUg5tZXNzYWdlQ3JlYXRlZBI6Cg9tZXNzYWdlX2RlbGV0ZWQYAiABKAsyDy5NZXNzYWdlRGVs'
    'ZXRlZEgAUg5tZXNzYWdlRGVsZXRlZBI9ChBtZXNzYWdlX3Byb2dyZXNzGAMgASgLMhAuTWVzc2'
    'FnZVByb2dyZXNzSABSD21lc3NhZ2VQcm9ncmVzcxJDChJzdWJzY3JpcHRpb25fcmVhZHkYBCAB'
    'KAsyEi5TdWJzY3JpcHRpb25SZWFkeUgAUhFzdWJzY3JpcHRpb25SZWFkeRImCgVlcnJvchgFIA'
    'EoCzIOLlByb3RvY29sRXJyb3JIAFIFZXJyb3ISTQoWbWVzc2FnZV9zdGF0dXNfY2hhbmdlZBgG'
    'IAEoCzIVLk1lc3NhZ2VTdGF0dXNDaGFuZ2VkSABSFG1lc3NhZ2VTdGF0dXNDaGFuZ2VkEjQKDW'
    '1lc3NhZ2VfZGVsdGEYByABKAsyDS5NZXNzYWdlRGVsdGFIAFIMbWVzc2FnZURlbHRhEk0KFm1l'
    'c3NhZ2VfcGlubmVkX2NoYW5nZWQYCCABKAsyFS5NZXNzYWdlUGlubmVkQ2hhbmdlZEgAUhRtZX'
    'NzYWdlUGlubmVkQ2hhbmdlZEIHCgVldmVudA==');

@$core.Deprecated('Use subscribeRequestDescriptor instead')
const SubscribeRequest$json = {
  '1': 'SubscribeRequest',
  '2': [
    {
      '1': 'conversation_id',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'conversationId',
      '17': true
    },
    {'1': 'after_sequence', '3': 2, '4': 1, '5': 4, '10': 'afterSequence'},
  ],
  '8': [
    {'1': '_conversation_id'},
  ],
};

/// Descriptor for `SubscribeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscribeRequestDescriptor = $convert.base64Decode(
    'ChBTdWJzY3JpYmVSZXF1ZXN0EiwKD2NvbnZlcnNhdGlvbl9pZBgBIAEoCUgAUg5jb252ZXJzYX'
    'Rpb25JZIgBARIlCg5hZnRlcl9zZXF1ZW5jZRgCIAEoBFINYWZ0ZXJTZXF1ZW5jZUISChBfY29u'
    'dmVyc2F0aW9uX2lk');

@$core.Deprecated('Use acknowledgeEventDescriptor instead')
const AcknowledgeEvent$json = {
  '1': 'AcknowledgeEvent',
  '2': [
    {'1': 'last_sequence', '3': 1, '4': 1, '5': 4, '10': 'lastSequence'},
  ],
};

/// Descriptor for `AcknowledgeEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List acknowledgeEventDescriptor = $convert.base64Decode(
    'ChBBY2tub3dsZWRnZUV2ZW50EiMKDWxhc3Rfc2VxdWVuY2UYASABKARSDGxhc3RTZXF1ZW5jZQ'
    '==');

@$core.Deprecated('Use cancelMessageRequestDescriptor instead')
const CancelMessageRequest$json = {
  '1': 'CancelMessageRequest',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {
      '1': 'conversation_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'conversationId',
      '17': true
    },
  ],
  '8': [
    {'1': '_conversation_id'},
  ],
};

/// Descriptor for `CancelMessageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cancelMessageRequestDescriptor = $convert.base64Decode(
    'ChRDYW5jZWxNZXNzYWdlUmVxdWVzdBIdCgptZXNzYWdlX2lkGAEgASgJUgltZXNzYWdlSWQSLA'
    'oPY29udmVyc2F0aW9uX2lkGAIgASgJSABSDmNvbnZlcnNhdGlvbklkiAEBQhIKEF9jb252ZXJz'
    'YXRpb25faWQ=');
