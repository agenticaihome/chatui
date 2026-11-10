// This is a generated file - do not edit.
//
// Generated from chat.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'chat.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'chat.pbenum.dart';

class Conversation extends $pb.GeneratedMessage {
  factory Conversation({
    $core.String? conversationId,
    $core.String? parentConversationId,
    $core.String? forkedFromMessageId,
    $core.String? title,
    $fixnum.Int64? createdAt,
    $core.bool? archived,
  }) {
    final result = Conversation._();
    if (conversationId != null) result.conversationId = conversationId;
    if (parentConversationId != null)
      result.parentConversationId = parentConversationId;
    if (forkedFromMessageId != null)
      result.forkedFromMessageId = forkedFromMessageId;
    if (title != null) result.title = title;
    if (createdAt != null) result.createdAt = createdAt;
    if (archived != null) result.archived = archived;
    return result;
  }

  Conversation._();

  factory Conversation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Conversation()..mergeFromBuffer(data, registry);
  factory Conversation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Conversation()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Conversation',
      createEmptyInstance: Conversation.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'conversationId')
    ..aOS(2, _omitFieldNames ? '' : 'parentConversationId')
    ..aOS(3, _omitFieldNames ? '' : 'forkedFromMessageId')
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aInt64(5, _omitFieldNames ? '' : 'createdAt')
    ..aOB(6, _omitFieldNames ? '' : 'archived')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Conversation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Conversation copyWith(void Function(Conversation) updates) =>
      super.copyWith((message) => updates(message as Conversation))
          as Conversation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Conversation() / Conversation.new instead')
  static Conversation create() => Conversation._();
  static $pb.GeneratedMessage $_createMessage() => Conversation._();
  @$core.override
  Conversation createEmptyInstance() => Conversation._();
  @$core.pragma('dart2js:noInline')
  static Conversation getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Conversation>(
          Conversation.$_createMessage);
  static Conversation? _defaultInstance;

  /// Identificador de la conversación.
  /// La conversación principal no necesita identificador explícito.
  @$pb.TagNumber(1)
  $core.String get conversationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set conversationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConversationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearConversationId() => $_clearField(1);

  /// Conversación de origen. Ausente para la conversación principal.
  @$pb.TagNumber(2)
  $core.String get parentConversationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set parentConversationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasParentConversationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearParentConversationId() => $_clearField(2);

  /// Mensaje desde el que se creó esta rama.
  @$pb.TagNumber(3)
  $core.String get forkedFromMessageId => $_getSZ(2);
  @$pb.TagNumber(3)
  set forkedFromMessageId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasForkedFromMessageId() => $_has(2);
  @$pb.TagNumber(3)
  void clearForkedFromMessageId() => $_clearField(3);

  /// Nombre opcional para identificar el hilo.
  ///
  /// Revisión 6 (ronda 9, propuesta #89): en la conversación principal es
  /// el título que el servicio le da (chat.md, 6.10). UTF-8, de 1 a 256
  /// bytes, en una línea. Ausente: no tiene título.
  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);

  /// Fecha de creación, en milisegundos Unix.
  @$pb.TagNumber(5)
  $fixnum.Int64 get createdAt => $_getI64(4);
  @$pb.TagNumber(5)
  set createdAt($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCreatedAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearCreatedAt() => $_clearField(5);

  /// Indica si la conversación está archivada.
  @$pb.TagNumber(6)
  $core.bool get archived => $_getBF(5);
  @$pb.TagNumber(6)
  set archived($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasArchived() => $_has(5);
  @$pb.TagNumber(6)
  void clearArchived() => $_clearField(6);
}

class ForkConversationRequest extends $pb.GeneratedMessage {
  factory ForkConversationRequest({
    $core.String? parentConversationId,
    $core.String? forkedFromMessageId,
    $core.String? title,
  }) {
    final result = ForkConversationRequest._();
    if (parentConversationId != null)
      result.parentConversationId = parentConversationId;
    if (forkedFromMessageId != null)
      result.forkedFromMessageId = forkedFromMessageId;
    if (title != null) result.title = title;
    return result;
  }

  ForkConversationRequest._();

  factory ForkConversationRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ForkConversationRequest()..mergeFromBuffer(data, registry);
  factory ForkConversationRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ForkConversationRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ForkConversationRequest',
      createEmptyInstance: ForkConversationRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'parentConversationId')
    ..aOS(2, _omitFieldNames ? '' : 'forkedFromMessageId')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForkConversationRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForkConversationRequest copyWith(
          void Function(ForkConversationRequest) updates) =>
      super.copyWith((message) => updates(message as ForkConversationRequest))
          as ForkConversationRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ForkConversationRequest() / ForkConversationRequest.new instead')
  static ForkConversationRequest create() => ForkConversationRequest._();
  static $pb.GeneratedMessage $_createMessage() => ForkConversationRequest._();
  @$core.override
  ForkConversationRequest createEmptyInstance() => ForkConversationRequest._();
  @$core.pragma('dart2js:noInline')
  static ForkConversationRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ForkConversationRequest>(
          ForkConversationRequest.$_createMessage);
  static ForkConversationRequest? _defaultInstance;

  /// Conversación de origen.
  /// Ausente para la conversación principal.
  @$pb.TagNumber(1)
  $core.String get parentConversationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set parentConversationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasParentConversationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearParentConversationId() => $_clearField(1);

  /// Mensaje de origen de la bifurcación.
  @$pb.TagNumber(2)
  $core.String get forkedFromMessageId => $_getSZ(1);
  @$pb.TagNumber(2)
  set forkedFromMessageId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasForkedFromMessageId() => $_has(1);
  @$pb.TagNumber(2)
  void clearForkedFromMessageId() => $_clearField(2);

  /// Título opcional de la nueva rama.
  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);
}

class GetConversationRequest extends $pb.GeneratedMessage {
  factory GetConversationRequest({
    $core.String? conversationId,
  }) {
    final result = GetConversationRequest._();
    if (conversationId != null) result.conversationId = conversationId;
    return result;
  }

  GetConversationRequest._();

  factory GetConversationRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetConversationRequest()..mergeFromBuffer(data, registry);
  factory GetConversationRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetConversationRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetConversationRequest',
      createEmptyInstance: GetConversationRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'conversationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetConversationRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetConversationRequest copyWith(
          void Function(GetConversationRequest) updates) =>
      super.copyWith((message) => updates(message as GetConversationRequest))
          as GetConversationRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetConversationRequest() / GetConversationRequest.new instead')
  static GetConversationRequest create() => GetConversationRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetConversationRequest._();
  @$core.override
  GetConversationRequest createEmptyInstance() => GetConversationRequest._();
  @$core.pragma('dart2js:noInline')
  static GetConversationRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetConversationRequest>(
          GetConversationRequest.$_createMessage);
  static GetConversationRequest? _defaultInstance;

  /// Ausente para la conversación principal.
  @$pb.TagNumber(1)
  $core.String get conversationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set conversationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConversationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearConversationId() => $_clearField(1);
}

class Message extends $pb.GeneratedMessage {
  factory Message({
    $core.String? messageId,
    $fixnum.Int64? sequence,
    $core.String? conversationId,
    $core.Iterable<ContentPart>? content,
    MessageStatus? status,
    $fixnum.Int64? createdAt,
    $fixnum.Int64? updatedAt,
    $core.String? replyToMessageId,
    $core.bool? pinned,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? metadata,
    $core.bool? fromService,
    $core.String? reasoning,
    $core.String? idempotencyKey,
    $core.String? error,
    $core.Iterable<$core.String>? suggestions,
    CorrectorState? corrector,
  }) {
    final result = Message._();
    if (messageId != null) result.messageId = messageId;
    if (sequence != null) result.sequence = sequence;
    if (conversationId != null) result.conversationId = conversationId;
    if (content != null) result.content.addAll(content);
    if (status != null) result.status = status;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    if (replyToMessageId != null) result.replyToMessageId = replyToMessageId;
    if (pinned != null) result.pinned = pinned;
    if (metadata != null) result.metadata.addEntries(metadata);
    if (fromService != null) result.fromService = fromService;
    if (reasoning != null) result.reasoning = reasoning;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    if (error != null) result.error = error;
    if (suggestions != null) result.suggestions.addAll(suggestions);
    if (corrector != null) result.corrector = corrector;
    return result;
  }

  Message._();

  factory Message.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Message()..mergeFromBuffer(data, registry);
  factory Message.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Message()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Message',
      createEmptyInstance: Message.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'sequence', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(3, _omitFieldNames ? '' : 'conversationId')
    ..pPM<ContentPart>(4, _omitFieldNames ? '' : 'content',
        subBuilder: ContentPart.$_createMessage)
    ..aE<MessageStatus>(5, _omitFieldNames ? '' : 'status',
        enumValues: MessageStatus.values)
    ..aInt64(6, _omitFieldNames ? '' : 'createdAt')
    ..aInt64(7, _omitFieldNames ? '' : 'updatedAt')
    ..aOS(8, _omitFieldNames ? '' : 'replyToMessageId')
    ..aOB(9, _omitFieldNames ? '' : 'pinned')
    ..m<$core.String, $core.String>(10, _omitFieldNames ? '' : 'metadata',
        entryClassName: 'Message.MetadataEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS)
    ..aOB(11, _omitFieldNames ? '' : 'fromService')
    ..aOS(12, _omitFieldNames ? '' : 'reasoning')
    ..aOS(13, _omitFieldNames ? '' : 'idempotencyKey')
    ..aOS(14, _omitFieldNames ? '' : 'error')
    ..pPS(15, _omitFieldNames ? '' : 'suggestions')
    ..aOM<CorrectorState>(16, _omitFieldNames ? '' : 'corrector',
        subBuilder: CorrectorState.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Message clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Message copyWith(void Function(Message) updates) =>
      super.copyWith((message) => updates(message as Message)) as Message;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Message() / Message.new instead')
  static Message create() => Message._();
  static $pb.GeneratedMessage $_createMessage() => Message._();
  @$core.override
  Message createEmptyInstance() => Message._();
  @$core.pragma('dart2js:noInline')
  static Message getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Message>(Message.$_createMessage);
  static Message? _defaultInstance;

  /// Identificador estable del mensaje.
  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  /// Secuencia incremental dentro de su conversación.
  @$pb.TagNumber(2)
  $fixnum.Int64 get sequence => $_getI64(1);
  @$pb.TagNumber(2)
  set sequence($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSequence() => $_has(1);
  @$pb.TagNumber(2)
  void clearSequence() => $_clearField(2);

  /// Ausente para la conversación principal.
  @$pb.TagNumber(3)
  $core.String get conversationId => $_getSZ(2);
  @$pb.TagNumber(3)
  set conversationId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasConversationId() => $_has(2);
  @$pb.TagNumber(3)
  void clearConversationId() => $_clearField(3);

  /// Contenido del mensaje.
  ///
  /// Revisión 6: el contenido es el que el mensaje tiene cuando su
  /// estado es COMPLETED, FAILED o CANCELLED (estado final). Entonces
  /// no cambia nunca. Mientras el estado es PENDING o IN_PROGRESS,
  /// contiene lo producido hasta ese momento y solo puede crecer al
  /// final con MessageDelta (ver MessageDelta).
  @$pb.TagNumber(4)
  $pb.PbList<ContentPart> get content => $_getList(3);

  /// Estado de procesamiento.
  @$pb.TagNumber(5)
  MessageStatus get status => $_getN(4);
  @$pb.TagNumber(5)
  set status(MessageStatus value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearStatus() => $_clearField(5);

  /// Fecha de creación, en milisegundos Unix.
  @$pb.TagNumber(6)
  $fixnum.Int64 get createdAt => $_getI64(5);
  @$pb.TagNumber(6)
  set createdAt($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedAt() => $_clearField(6);

  /// Fecha de la última modificación del estado o de la fijación.
  @$pb.TagNumber(7)
  $fixnum.Int64 get updatedAt => $_getI64(6);
  @$pb.TagNumber(7)
  set updatedAt($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUpdatedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearUpdatedAt() => $_clearField(7);

  /// Mensaje al que responde, si corresponde.
  @$pb.TagNumber(8)
  $core.String get replyToMessageId => $_getSZ(7);
  @$pb.TagNumber(8)
  set replyToMessageId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasReplyToMessageId() => $_has(7);
  @$pb.TagNumber(8)
  void clearReplyToMessageId() => $_clearField(8);

  /// Indica si está fijado.
  @$pb.TagNumber(9)
  $core.bool get pinned => $_getBF(8);
  @$pb.TagNumber(9)
  set pinned($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPinned() => $_has(8);
  @$pb.TagNumber(9)
  void clearPinned() => $_clearField(9);

  /// Metadatos extensibles en formato clave-valor.
  @$pb.TagNumber(10)
  $pb.PbMap<$core.String, $core.String> get metadata => $_getMap(9);

  /// false = usuario; true = servicio.
  @$pb.TagNumber(11)
  $core.bool get fromService => $_getBF(10);
  @$pb.TagNumber(11)
  set fromService($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasFromService() => $_has(10);
  @$pb.TagNumber(11)
  void clearFromService() => $_clearField(11);

  /// Revisión 6.
  /// Razonamiento del modelo, aparte del contenido. Solo lo tiene un
  /// mensaje del servicio. Sigue la misma regla que content: solo
  /// crece al final con MessageDelta mientras el estado no es final.
  /// Vacío si el servicio no da razonamiento.
  @$pb.TagNumber(12)
  $core.String get reasoning => $_getSZ(11);
  @$pb.TagNumber(12)
  set reasoning($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasReasoning() => $_has(11);
  @$pb.TagNumber(12)
  void clearReasoning() => $_clearField(12);

  /// Revisión 6.
  /// idempotency_key de SendMessageRequest que creó este mensaje.
  /// Solo lo tiene un mensaje del usuario, y solo si el envío lo tenía.
  @$pb.TagNumber(13)
  $core.String get idempotencyKey => $_getSZ(12);
  @$pb.TagNumber(13)
  set idempotencyKey($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasIdempotencyKey() => $_has(12);
  @$pb.TagNumber(13)
  void clearIdempotencyKey() => $_clearField(13);

  /// Revisión 6.
  /// Texto corto y legible del motivo de un fallo, en UTF-8, de 1 KiB
  /// como máximo. El servicio lo fija junto con el estado FAILED y no
  /// lo cambia después. Solo un mensaje del servicio con estado FAILED
  /// lo tiene.
  @$pb.TagNumber(14)
  $core.String get error => $_getSZ(13);
  @$pb.TagNumber(14)
  set error($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasError() => $_has(13);
  @$pb.TagNumber(14)
  void clearError() => $_clearField(14);

  /// Revisión 6 (ronda 10, propuesta #88).
  /// De 0 a 3 respuestas cortas que el servicio propone al usuario después
  /// de este mensaje (chat.md, 5.7). Cada una: UTF-8, de 1 a 64 caracteres,
  /// en una línea. Solo un mensaje del servicio con estado COMPLETED las
  /// tiene. Se fijan una vez, con ese estado, y no cambian después.
  @$pb.TagNumber(15)
  $pb.PbList<$core.String> get suggestions => $_getList(14);

  /// Revisión 6 (ronda 10, propuesta #88).
  /// Estado del corrector del cliente para este mensaje del usuario, como
  /// lo dio el envío (SendMessageRequest.corrector). Solo un mensaje del
  /// usuario lo tiene, y solo si el servicio lo guarda.
  @$pb.TagNumber(16)
  CorrectorState get corrector => $_getN(15);
  @$pb.TagNumber(16)
  set corrector(CorrectorState value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasCorrector() => $_has(15);
  @$pb.TagNumber(16)
  void clearCorrector() => $_clearField(16);
  @$pb.TagNumber(16)
  CorrectorState ensureCorrector() => $_ensure(15);
}

class SendMessageRequest extends $pb.GeneratedMessage {
  factory SendMessageRequest({
    $core.String? conversationId,
    $core.Iterable<ContentPart>? content,
    $core.String? replyToMessageId,
    $core.String? idempotencyKey,
    CorrectorState? corrector,
  }) {
    final result = SendMessageRequest._();
    if (conversationId != null) result.conversationId = conversationId;
    if (content != null) result.content.addAll(content);
    if (replyToMessageId != null) result.replyToMessageId = replyToMessageId;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    if (corrector != null) result.corrector = corrector;
    return result;
  }

  SendMessageRequest._();

  factory SendMessageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendMessageRequest()..mergeFromBuffer(data, registry);
  factory SendMessageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendMessageRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendMessageRequest',
      createEmptyInstance: SendMessageRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'conversationId')
    ..pPM<ContentPart>(2, _omitFieldNames ? '' : 'content',
        subBuilder: ContentPart.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'replyToMessageId')
    ..aOS(4, _omitFieldNames ? '' : 'idempotencyKey')
    ..aOM<CorrectorState>(5, _omitFieldNames ? '' : 'corrector',
        subBuilder: CorrectorState.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMessageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMessageRequest copyWith(void Function(SendMessageRequest) updates) =>
      super.copyWith((message) => updates(message as SendMessageRequest))
          as SendMessageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SendMessageRequest() / SendMessageRequest.new instead')
  static SendMessageRequest create() => SendMessageRequest._();
  static $pb.GeneratedMessage $_createMessage() => SendMessageRequest._();
  @$core.override
  SendMessageRequest createEmptyInstance() => SendMessageRequest._();
  @$core.pragma('dart2js:noInline')
  static SendMessageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendMessageRequest>(
          SendMessageRequest.$_createMessage);
  static SendMessageRequest? _defaultInstance;

  /// Ausente para enviar a la conversación principal.
  @$pb.TagNumber(1)
  $core.String get conversationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set conversationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConversationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearConversationId() => $_clearField(1);

  /// Contenido del mensaje.
  @$pb.TagNumber(2)
  $pb.PbList<ContentPart> get content => $_getList(1);

  /// Referencia opcional al mensaje al que se responde.
  @$pb.TagNumber(3)
  $core.String get replyToMessageId => $_getSZ(2);
  @$pb.TagNumber(3)
  set replyToMessageId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReplyToMessageId() => $_has(2);
  @$pb.TagNumber(3)
  void clearReplyToMessageId() => $_clearField(3);

  /// Evita duplicados cuando se reintenta una operación.
  ///
  /// Revisión 6: de 1 a 64 caracteres de A-Z, a-z, 0-9, "-" y "_".
  /// Es único dentro de una conversación. Si ya existe un mensaje del
  /// usuario con la misma clave, el servicio devuelve ese mensaje y no
  /// crea otro.
  @$pb.TagNumber(4)
  $core.String get idempotencyKey => $_getSZ(3);
  @$pb.TagNumber(4)
  set idempotencyKey($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIdempotencyKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearIdempotencyKey() => $_clearField(4);

  /// Revisión 6 (ronda 10, propuesta #88).
  /// Estado del corrector del cliente mientras el usuario escribió este
  /// mensaje (chat.md, 5.7). No cambia el texto. El servicio puede usarlo o
  /// ignorarlo; un envío nunca falla por él.
  @$pb.TagNumber(5)
  CorrectorState get corrector => $_getN(4);
  @$pb.TagNumber(5)
  set corrector(CorrectorState value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCorrector() => $_has(4);
  @$pb.TagNumber(5)
  void clearCorrector() => $_clearField(5);
  @$pb.TagNumber(5)
  CorrectorState ensureCorrector() => $_ensure(4);
}

/// Revisión 6 (ronda 10, propuesta #88).
/// Estado del corrector del cliente para un mensaje del usuario (chat.md, 5.7).
class CorrectorState extends $pb.GeneratedMessage {
  factory CorrectorState({
    $core.bool? enabled,
    $core.Iterable<Correction>? corrections,
  }) {
    final result = CorrectorState._();
    if (enabled != null) result.enabled = enabled;
    if (corrections != null) result.corrections.addAll(corrections);
    return result;
  }

  CorrectorState._();

  factory CorrectorState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CorrectorState()..mergeFromBuffer(data, registry);
  factory CorrectorState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CorrectorState()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CorrectorState',
      createEmptyInstance: CorrectorState.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..pPM<Correction>(2, _omitFieldNames ? '' : 'corrections',
        subBuilder: Correction.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CorrectorState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CorrectorState copyWith(void Function(CorrectorState) updates) =>
      super.copyWith((message) => updates(message as CorrectorState))
          as CorrectorState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CorrectorState() / CorrectorState.new instead')
  static CorrectorState create() => CorrectorState._();
  static $pb.GeneratedMessage $_createMessage() => CorrectorState._();
  @$core.override
  CorrectorState createEmptyInstance() => CorrectorState._();
  @$core.pragma('dart2js:noInline')
  static CorrectorState getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CorrectorState>(
          CorrectorState.$_createMessage);
  static CorrectorState? _defaultInstance;

  /// true si el corrector estaba activo mientras el usuario escribió.
  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);

  /// Palabras que el corrector cambió en el texto, en el orden de los cambios.
  /// De 0 a 32.
  @$pb.TagNumber(2)
  $pb.PbList<Correction> get corrections => $_getList(1);
}

/// Revisión 6 (ronda 10, propuesta #88).
/// Una palabra que el corrector cambió.
class Correction extends $pb.GeneratedMessage {
  factory Correction({
    $core.String? original,
    $core.String? replacement,
  }) {
    final result = Correction._();
    if (original != null) result.original = original;
    if (replacement != null) result.replacement = replacement;
    return result;
  }

  Correction._();

  factory Correction.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Correction()..mergeFromBuffer(data, registry);
  factory Correction.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Correction()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Correction',
      createEmptyInstance: Correction.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'original')
    ..aOS(2, _omitFieldNames ? '' : 'replacement')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Correction clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Correction copyWith(void Function(Correction) updates) =>
      super.copyWith((message) => updates(message as Correction)) as Correction;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Correction() / Correction.new instead')
  static Correction create() => Correction._();
  static $pb.GeneratedMessage $_createMessage() => Correction._();
  @$core.override
  Correction createEmptyInstance() => Correction._();
  @$core.pragma('dart2js:noInline')
  static Correction getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Correction>(Correction.$_createMessage);
  static Correction? _defaultInstance;

  /// Palabra que escribió el usuario. De 1 a 64 caracteres.
  @$pb.TagNumber(1)
  $core.String get original => $_getSZ(0);
  @$pb.TagNumber(1)
  set original($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOriginal() => $_has(0);
  @$pb.TagNumber(1)
  void clearOriginal() => $_clearField(1);

  /// Palabra que el corrector puso en su lugar, y que está en el texto.
  /// De 1 a 64 caracteres.
  @$pb.TagNumber(2)
  $core.String get replacement => $_getSZ(1);
  @$pb.TagNumber(2)
  set replacement($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReplacement() => $_has(1);
  @$pb.TagNumber(2)
  void clearReplacement() => $_clearField(2);
}

class GetMessagesRequest extends $pb.GeneratedMessage {
  factory GetMessagesRequest({
    $core.String? conversationId,
    $fixnum.Int64? afterSequence,
    $core.int? limit,
    $fixnum.Int64? beforeSequence,
    $core.int? last,
  }) {
    final result = GetMessagesRequest._();
    if (conversationId != null) result.conversationId = conversationId;
    if (afterSequence != null) result.afterSequence = afterSequence;
    if (limit != null) result.limit = limit;
    if (beforeSequence != null) result.beforeSequence = beforeSequence;
    if (last != null) result.last = last;
    return result;
  }

  GetMessagesRequest._();

  factory GetMessagesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetMessagesRequest()..mergeFromBuffer(data, registry);
  factory GetMessagesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetMessagesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetMessagesRequest',
      createEmptyInstance: GetMessagesRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'conversationId')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'afterSequence', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(3, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'beforeSequence', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(5, _omitFieldNames ? '' : 'last', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMessagesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMessagesRequest copyWith(void Function(GetMessagesRequest) updates) =>
      super.copyWith((message) => updates(message as GetMessagesRequest))
          as GetMessagesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetMessagesRequest() / GetMessagesRequest.new instead')
  static GetMessagesRequest create() => GetMessagesRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetMessagesRequest._();
  @$core.override
  GetMessagesRequest createEmptyInstance() => GetMessagesRequest._();
  @$core.pragma('dart2js:noInline')
  static GetMessagesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetMessagesRequest>(
          GetMessagesRequest.$_createMessage);
  static GetMessagesRequest? _defaultInstance;

  /// Ausente para consultar la conversación principal.
  @$pb.TagNumber(1)
  $core.String get conversationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set conversationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConversationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearConversationId() => $_clearField(1);

  /// Recupera mensajes cuya secuencia sea mayor que este valor.
  @$pb.TagNumber(2)
  $fixnum.Int64 get afterSequence => $_getI64(1);
  @$pb.TagNumber(2)
  set afterSequence($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAfterSequence() => $_has(1);
  @$pb.TagNumber(2)
  void clearAfterSequence() => $_clearField(2);

  /// Número máximo de mensajes que se deben devolver.
  /// 0 significa que se aplica el límite predeterminado del servidor.
  /// Devuelve los primeros mensajes del rango.
  @$pb.TagNumber(3)
  $core.int get limit => $_getIZ(2);
  @$pb.TagNumber(3)
  set limit($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimit() => $_clearField(3);

  /// Recupera mensajes cuya secuencia sea menor que este valor.
  /// 0 significa que no hay cota superior.
  @$pb.TagNumber(4)
  $fixnum.Int64 get beforeSequence => $_getI64(3);
  @$pb.TagNumber(4)
  set beforeSequence($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBeforeSequence() => $_has(3);
  @$pb.TagNumber(4)
  void clearBeforeSequence() => $_clearField(4);

  /// Devuelve solo los últimos N mensajes del rango, en orden de secuencia.
  /// 0 significa que no se aplica. No se puede combinar con limit.
  @$pb.TagNumber(5)
  $core.int get last => $_getIZ(4);
  @$pb.TagNumber(5)
  set last($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLast() => $_has(4);
  @$pb.TagNumber(5)
  void clearLast() => $_clearField(5);
}

class SetMessagePinnedRequest extends $pb.GeneratedMessage {
  factory SetMessagePinnedRequest({
    $core.String? messageId,
    $core.String? conversationId,
    $core.bool? pinned,
  }) {
    final result = SetMessagePinnedRequest._();
    if (messageId != null) result.messageId = messageId;
    if (conversationId != null) result.conversationId = conversationId;
    if (pinned != null) result.pinned = pinned;
    return result;
  }

  SetMessagePinnedRequest._();

  factory SetMessagePinnedRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetMessagePinnedRequest()..mergeFromBuffer(data, registry);
  factory SetMessagePinnedRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetMessagePinnedRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetMessagePinnedRequest',
      createEmptyInstance: SetMessagePinnedRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOS(2, _omitFieldNames ? '' : 'conversationId')
    ..aOB(3, _omitFieldNames ? '' : 'pinned')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMessagePinnedRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMessagePinnedRequest copyWith(
          void Function(SetMessagePinnedRequest) updates) =>
      super.copyWith((message) => updates(message as SetMessagePinnedRequest))
          as SetMessagePinnedRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetMessagePinnedRequest() / SetMessagePinnedRequest.new instead')
  static SetMessagePinnedRequest create() => SetMessagePinnedRequest._();
  static $pb.GeneratedMessage $_createMessage() => SetMessagePinnedRequest._();
  @$core.override
  SetMessagePinnedRequest createEmptyInstance() => SetMessagePinnedRequest._();
  @$core.pragma('dart2js:noInline')
  static SetMessagePinnedRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetMessagePinnedRequest>(
          SetMessagePinnedRequest.$_createMessage);
  static SetMessagePinnedRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  /// Ausente para la conversación principal.
  @$pb.TagNumber(2)
  $core.String get conversationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set conversationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConversationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConversationId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get pinned => $_getBF(2);
  @$pb.TagNumber(3)
  set pinned($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPinned() => $_has(2);
  @$pb.TagNumber(3)
  void clearPinned() => $_clearField(3);
}

class MessageCreated extends $pb.GeneratedMessage {
  factory MessageCreated({
    Message? message,
  }) {
    final result = MessageCreated._();
    if (message != null) result.message = message;
    return result;
  }

  MessageCreated._();

  factory MessageCreated.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MessageCreated()..mergeFromBuffer(data, registry);
  factory MessageCreated.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MessageCreated()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageCreated',
      createEmptyInstance: MessageCreated.$_createMessage)
    ..aOM<Message>(1, _omitFieldNames ? '' : 'message',
        subBuilder: Message.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageCreated clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageCreated copyWith(void Function(MessageCreated) updates) =>
      super.copyWith((message) => updates(message as MessageCreated))
          as MessageCreated;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MessageCreated() / MessageCreated.new instead')
  static MessageCreated create() => MessageCreated._();
  static $pb.GeneratedMessage $_createMessage() => MessageCreated._();
  @$core.override
  MessageCreated createEmptyInstance() => MessageCreated._();
  @$core.pragma('dart2js:noInline')
  static MessageCreated getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MessageCreated>(
          MessageCreated.$_createMessage);
  static MessageCreated? _defaultInstance;

  @$pb.TagNumber(1)
  Message get message => $_getN(0);
  @$pb.TagNumber(1)
  set message(Message value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);
  @$pb.TagNumber(1)
  Message ensureMessage() => $_ensure(0);
}

class MessageDeleted extends $pb.GeneratedMessage {
  factory MessageDeleted({
    $core.String? messageId,
    $core.String? conversationId,
  }) {
    final result = MessageDeleted._();
    if (messageId != null) result.messageId = messageId;
    if (conversationId != null) result.conversationId = conversationId;
    return result;
  }

  MessageDeleted._();

  factory MessageDeleted.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MessageDeleted()..mergeFromBuffer(data, registry);
  factory MessageDeleted.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MessageDeleted()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageDeleted',
      createEmptyInstance: MessageDeleted.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOS(2, _omitFieldNames ? '' : 'conversationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageDeleted clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageDeleted copyWith(void Function(MessageDeleted) updates) =>
      super.copyWith((message) => updates(message as MessageDeleted))
          as MessageDeleted;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MessageDeleted() / MessageDeleted.new instead')
  static MessageDeleted create() => MessageDeleted._();
  static $pb.GeneratedMessage $_createMessage() => MessageDeleted._();
  @$core.override
  MessageDeleted createEmptyInstance() => MessageDeleted._();
  @$core.pragma('dart2js:noInline')
  static MessageDeleted getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MessageDeleted>(
          MessageDeleted.$_createMessage);
  static MessageDeleted? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  /// Ausente para la conversación principal.
  @$pb.TagNumber(2)
  $core.String get conversationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set conversationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConversationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConversationId() => $_clearField(2);
}

class MessageStatusChanged extends $pb.GeneratedMessage {
  factory MessageStatusChanged({
    $core.String? messageId,
    $core.String? conversationId,
    MessageStatus? status,
    $fixnum.Int64? updatedAt,
    $core.String? error,
    $core.Iterable<$core.String>? suggestions,
  }) {
    final result = MessageStatusChanged._();
    if (messageId != null) result.messageId = messageId;
    if (conversationId != null) result.conversationId = conversationId;
    if (status != null) result.status = status;
    if (updatedAt != null) result.updatedAt = updatedAt;
    if (error != null) result.error = error;
    if (suggestions != null) result.suggestions.addAll(suggestions);
    return result;
  }

  MessageStatusChanged._();

  factory MessageStatusChanged.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MessageStatusChanged()..mergeFromBuffer(data, registry);
  factory MessageStatusChanged.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MessageStatusChanged()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageStatusChanged',
      createEmptyInstance: MessageStatusChanged.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOS(2, _omitFieldNames ? '' : 'conversationId')
    ..aE<MessageStatus>(3, _omitFieldNames ? '' : 'status',
        enumValues: MessageStatus.values)
    ..aInt64(4, _omitFieldNames ? '' : 'updatedAt')
    ..aOS(5, _omitFieldNames ? '' : 'error')
    ..pPS(6, _omitFieldNames ? '' : 'suggestions')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageStatusChanged clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageStatusChanged copyWith(void Function(MessageStatusChanged) updates) =>
      super.copyWith((message) => updates(message as MessageStatusChanged))
          as MessageStatusChanged;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MessageStatusChanged() / MessageStatusChanged.new instead')
  static MessageStatusChanged create() => MessageStatusChanged._();
  static $pb.GeneratedMessage $_createMessage() => MessageStatusChanged._();
  @$core.override
  MessageStatusChanged createEmptyInstance() => MessageStatusChanged._();
  @$core.pragma('dart2js:noInline')
  static MessageStatusChanged getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MessageStatusChanged>(
          MessageStatusChanged.$_createMessage);
  static MessageStatusChanged? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  /// Ausente para la conversación principal.
  @$pb.TagNumber(2)
  $core.String get conversationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set conversationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConversationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConversationId() => $_clearField(2);

  @$pb.TagNumber(3)
  MessageStatus get status => $_getN(2);
  @$pb.TagNumber(3)
  set status(MessageStatus value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearStatus() => $_clearField(3);

  /// Fecha del cambio de estado, en milisegundos Unix.
  @$pb.TagNumber(4)
  $fixnum.Int64 get updatedAt => $_getI64(3);
  @$pb.TagNumber(4)
  set updatedAt($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUpdatedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearUpdatedAt() => $_clearField(4);

  /// Revisión 6.
  /// Igual que Message.error. Solo se envía si status es FAILED, y
  /// tiene el mismo valor que Message.error.
  @$pb.TagNumber(5)
  $core.String get error => $_getSZ(4);
  @$pb.TagNumber(5)
  set error($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasError() => $_has(4);
  @$pb.TagNumber(5)
  void clearError() => $_clearField(5);

  /// Revisión 6 (ronda 10, propuesta #88).
  /// Igual que Message.suggestions. Solo se envía si status es COMPLETED,
  /// y tiene el mismo valor que Message.suggestions.
  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get suggestions => $_getList(5);
}

/// Revisión 6.
/// Añade texto al final de un mensaje que no está en estado final.
/// El texto se añade a la última parte TextContent de content. Si
/// content no tiene partes, o su última parte no es TextContent, el
/// receptor añade una parte TextContent nueva al final.
/// Solo se puede enviar para un mensaje en estado IN_PROGRESS, después
/// de su MessageCreated. No cambia updated_at.
class MessageDelta extends $pb.GeneratedMessage {
  factory MessageDelta({
    $core.String? messageId,
    $core.String? conversationId,
    $core.String? textAppend,
    $core.String? reasoningAppend,
  }) {
    final result = MessageDelta._();
    if (messageId != null) result.messageId = messageId;
    if (conversationId != null) result.conversationId = conversationId;
    if (textAppend != null) result.textAppend = textAppend;
    if (reasoningAppend != null) result.reasoningAppend = reasoningAppend;
    return result;
  }

  MessageDelta._();

  factory MessageDelta.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MessageDelta()..mergeFromBuffer(data, registry);
  factory MessageDelta.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MessageDelta()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageDelta',
      createEmptyInstance: MessageDelta.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOS(2, _omitFieldNames ? '' : 'conversationId')
    ..aOS(3, _omitFieldNames ? '' : 'textAppend')
    ..aOS(4, _omitFieldNames ? '' : 'reasoningAppend')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageDelta clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageDelta copyWith(void Function(MessageDelta) updates) =>
      super.copyWith((message) => updates(message as MessageDelta))
          as MessageDelta;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MessageDelta() / MessageDelta.new instead')
  static MessageDelta create() => MessageDelta._();
  static $pb.GeneratedMessage $_createMessage() => MessageDelta._();
  @$core.override
  MessageDelta createEmptyInstance() => MessageDelta._();
  @$core.pragma('dart2js:noInline')
  static MessageDelta getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MessageDelta>(
          MessageDelta.$_createMessage);
  static MessageDelta? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  /// Ausente para la conversación principal.
  @$pb.TagNumber(2)
  $core.String get conversationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set conversationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConversationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConversationId() => $_clearField(2);

  /// Texto que se añade al final del contenido. Puede estar vacío.
  @$pb.TagNumber(3)
  $core.String get textAppend => $_getSZ(2);
  @$pb.TagNumber(3)
  set textAppend($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTextAppend() => $_has(2);
  @$pb.TagNumber(3)
  void clearTextAppend() => $_clearField(3);

  /// Texto que se añade al final de Message.reasoning. Puede estar vacío.
  @$pb.TagNumber(4)
  $core.String get reasoningAppend => $_getSZ(3);
  @$pb.TagNumber(4)
  set reasoningAppend($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReasoningAppend() => $_has(3);
  @$pb.TagNumber(4)
  void clearReasoningAppend() => $_clearField(4);
}

/// Revisión 6.
/// Cambio del campo pinned de un mensaje, hecho por el servicio o por
/// SetMessagePinned de otro cliente.
class MessagePinnedChanged extends $pb.GeneratedMessage {
  factory MessagePinnedChanged({
    $core.String? messageId,
    $core.String? conversationId,
    $core.bool? pinned,
    $fixnum.Int64? updatedAt,
  }) {
    final result = MessagePinnedChanged._();
    if (messageId != null) result.messageId = messageId;
    if (conversationId != null) result.conversationId = conversationId;
    if (pinned != null) result.pinned = pinned;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  MessagePinnedChanged._();

  factory MessagePinnedChanged.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MessagePinnedChanged()..mergeFromBuffer(data, registry);
  factory MessagePinnedChanged.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MessagePinnedChanged()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessagePinnedChanged',
      createEmptyInstance: MessagePinnedChanged.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOS(2, _omitFieldNames ? '' : 'conversationId')
    ..aOB(3, _omitFieldNames ? '' : 'pinned')
    ..aInt64(4, _omitFieldNames ? '' : 'updatedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessagePinnedChanged clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessagePinnedChanged copyWith(void Function(MessagePinnedChanged) updates) =>
      super.copyWith((message) => updates(message as MessagePinnedChanged))
          as MessagePinnedChanged;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MessagePinnedChanged() / MessagePinnedChanged.new instead')
  static MessagePinnedChanged create() => MessagePinnedChanged._();
  static $pb.GeneratedMessage $_createMessage() => MessagePinnedChanged._();
  @$core.override
  MessagePinnedChanged createEmptyInstance() => MessagePinnedChanged._();
  @$core.pragma('dart2js:noInline')
  static MessagePinnedChanged getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MessagePinnedChanged>(
          MessagePinnedChanged.$_createMessage);
  static MessagePinnedChanged? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  /// Ausente para la conversación principal.
  @$pb.TagNumber(2)
  $core.String get conversationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set conversationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConversationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConversationId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get pinned => $_getBF(2);
  @$pb.TagNumber(3)
  set pinned($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPinned() => $_has(2);
  @$pb.TagNumber(3)
  void clearPinned() => $_clearField(3);

  /// Fecha del cambio, en milisegundos Unix.
  @$pb.TagNumber(4)
  $fixnum.Int64 get updatedAt => $_getI64(3);
  @$pb.TagNumber(4)
  set updatedAt($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUpdatedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearUpdatedAt() => $_clearField(4);
}

class MessageProgress extends $pb.GeneratedMessage {
  factory MessageProgress({
    $core.String? messageId,
    $core.double? progress,
    $core.String? description,
  }) {
    final result = MessageProgress._();
    if (messageId != null) result.messageId = messageId;
    if (progress != null) result.progress = progress;
    if (description != null) result.description = description;
    return result;
  }

  MessageProgress._();

  factory MessageProgress.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MessageProgress()..mergeFromBuffer(data, registry);
  factory MessageProgress.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MessageProgress()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageProgress',
      createEmptyInstance: MessageProgress.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aD(2, _omitFieldNames ? '' : 'progress', fieldType: $pb.PbFieldType.OF)
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageProgress clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageProgress copyWith(void Function(MessageProgress) updates) =>
      super.copyWith((message) => updates(message as MessageProgress))
          as MessageProgress;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MessageProgress() / MessageProgress.new instead')
  static MessageProgress create() => MessageProgress._();
  static $pb.GeneratedMessage $_createMessage() => MessageProgress._();
  @$core.override
  MessageProgress createEmptyInstance() => MessageProgress._();
  @$core.pragma('dart2js:noInline')
  static MessageProgress getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MessageProgress>(
          MessageProgress.$_createMessage);
  static MessageProgress? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  /// Progreso entre 0 y 1, si se conoce.
  @$pb.TagNumber(2)
  $core.double get progress => $_getN(1);
  @$pb.TagNumber(2)
  set progress($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProgress() => $_has(1);
  @$pb.TagNumber(2)
  void clearProgress() => $_clearField(2);

  /// Descripción del estado actual.
  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);
}

class SubscriptionReady extends $pb.GeneratedMessage {
  factory SubscriptionReady({
    $fixnum.Int64? latestSequence,
    $core.String? title,
  }) {
    final result = SubscriptionReady._();
    if (latestSequence != null) result.latestSequence = latestSequence;
    if (title != null) result.title = title;
    return result;
  }

  SubscriptionReady._();

  factory SubscriptionReady.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SubscriptionReady()..mergeFromBuffer(data, registry);
  factory SubscriptionReady.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SubscriptionReady()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubscriptionReady',
      createEmptyInstance: SubscriptionReady.$_createMessage)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'latestSequence', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscriptionReady clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscriptionReady copyWith(void Function(SubscriptionReady) updates) =>
      super.copyWith((message) => updates(message as SubscriptionReady))
          as SubscriptionReady;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SubscriptionReady() / SubscriptionReady.new instead')
  static SubscriptionReady create() => SubscriptionReady._();
  static $pb.GeneratedMessage $_createMessage() => SubscriptionReady._();
  @$core.override
  SubscriptionReady createEmptyInstance() => SubscriptionReady._();
  @$core.pragma('dart2js:noInline')
  static SubscriptionReady getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SubscriptionReady>(
          SubscriptionReady.$_createMessage);
  static SubscriptionReady? _defaultInstance;

  /// Última secuencia disponible al confirmar la suscripción.
  @$pb.TagNumber(1)
  $fixnum.Int64 get latestSequence => $_getI64(0);
  @$pb.TagNumber(1)
  set latestSequence($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLatestSequence() => $_has(0);
  @$pb.TagNumber(1)
  void clearLatestSequence() => $_clearField(1);

  /// Revisión 6 (ronda 9, propuesta #89).
  /// Título de la conversación al final de la reproducción (chat.md, 6.10).
  /// Ausente: la conversación no tiene título.
  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);
}

/// Revisión 6 (ronda 9, propuesta #89).
/// El servicio cambia el título de la conversación (chat.md, 6.10). Solo
/// se envía después de SubscriptionReady. No cambia latest.
class ConversationTitleChanged extends $pb.GeneratedMessage {
  factory ConversationTitleChanged({
    $core.String? conversationId,
    $core.String? title,
    $fixnum.Int64? updatedAt,
  }) {
    final result = ConversationTitleChanged._();
    if (conversationId != null) result.conversationId = conversationId;
    if (title != null) result.title = title;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  ConversationTitleChanged._();

  factory ConversationTitleChanged.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConversationTitleChanged()..mergeFromBuffer(data, registry);
  factory ConversationTitleChanged.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConversationTitleChanged()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConversationTitleChanged',
      createEmptyInstance: ConversationTitleChanged.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'conversationId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aInt64(3, _omitFieldNames ? '' : 'updatedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConversationTitleChanged clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConversationTitleChanged copyWith(
          void Function(ConversationTitleChanged) updates) =>
      super.copyWith((message) => updates(message as ConversationTitleChanged))
          as ConversationTitleChanged;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ConversationTitleChanged() / ConversationTitleChanged.new instead')
  static ConversationTitleChanged create() => ConversationTitleChanged._();
  static $pb.GeneratedMessage $_createMessage() => ConversationTitleChanged._();
  @$core.override
  ConversationTitleChanged createEmptyInstance() =>
      ConversationTitleChanged._();
  @$core.pragma('dart2js:noInline')
  static ConversationTitleChanged getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConversationTitleChanged>(
          ConversationTitleChanged.$_createMessage);
  static ConversationTitleChanged? _defaultInstance;

  /// Ausente para la conversación principal.
  @$pb.TagNumber(1)
  $core.String get conversationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set conversationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConversationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearConversationId() => $_clearField(1);

  /// Título nuevo: UTF-8, de 1 a 256 bytes, en una línea. Ausente: el
  /// servicio quita su título.
  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// Fecha del cambio, en milisegundos Unix.
  @$pb.TagNumber(3)
  $fixnum.Int64 get updatedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set updatedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUpdatedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearUpdatedAt() => $_clearField(3);
}

class ProtocolError extends $pb.GeneratedMessage {
  factory ProtocolError({
    $core.String? code,
    $core.String? message,
    $core.String? eventId,
  }) {
    final result = ProtocolError._();
    if (code != null) result.code = code;
    if (message != null) result.message = message;
    if (eventId != null) result.eventId = eventId;
    return result;
  }

  ProtocolError._();

  factory ProtocolError.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProtocolError()..mergeFromBuffer(data, registry);
  factory ProtocolError.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProtocolError()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProtocolError',
      createEmptyInstance: ProtocolError.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..aOS(3, _omitFieldNames ? '' : 'eventId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolError clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolError copyWith(void Function(ProtocolError) updates) =>
      super.copyWith((message) => updates(message as ProtocolError))
          as ProtocolError;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ProtocolError() / ProtocolError.new instead')
  static ProtocolError create() => ProtocolError._();
  static $pb.GeneratedMessage $_createMessage() => ProtocolError._();
  @$core.override
  ProtocolError createEmptyInstance() => ProtocolError._();
  @$core.pragma('dart2js:noInline')
  static ProtocolError getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProtocolError>(
          ProtocolError.$_createMessage);
  static ProtocolError? _defaultInstance;

  /// Motivo del error. Es uno de los nombres de chat.md, sección 9:
  /// bad_request, unsupported_media, too_large, hash_mismatch,
  /// not_found, file_missing, bad_state, history_full, storage_full,
  /// busy, service_error, unimplemented.
  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);

  /// Revisión 6.
  /// event_id del ClientEvent que falló. Ausente si el error no
  /// corresponde a un evento del cliente, o si el evento no tenía
  /// event_id.
  @$pb.TagNumber(3)
  $core.String get eventId => $_getSZ(2);
  @$pb.TagNumber(3)
  set eventId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEventId() => $_has(2);
  @$pb.TagNumber(3)
  void clearEventId() => $_clearField(3);
}

enum AnswerSecretRequestRequest_Answer { value, skipped, notSet }

class AnswerSecretRequestRequest extends $pb.GeneratedMessage {
  factory AnswerSecretRequestRequest({
    $core.String? messageId,
    $core.String? requestId,
    $core.String? value,
    $core.bool? skipped,
  }) {
    final result = AnswerSecretRequestRequest._();
    if (messageId != null) result.messageId = messageId;
    if (requestId != null) result.requestId = requestId;
    if (value != null) result.value = value;
    if (skipped != null) result.skipped = skipped;
    return result;
  }

  AnswerSecretRequestRequest._();

  factory AnswerSecretRequestRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AnswerSecretRequestRequest()..mergeFromBuffer(data, registry);
  factory AnswerSecretRequestRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AnswerSecretRequestRequest()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, AnswerSecretRequestRequest_Answer>
      _AnswerSecretRequestRequest_AnswerByTag = {
    3: AnswerSecretRequestRequest_Answer.value,
    4: AnswerSecretRequestRequest_Answer.skipped,
    0: AnswerSecretRequestRequest_Answer.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnswerSecretRequestRequest',
      createEmptyInstance: AnswerSecretRequestRequest.$_createMessage)
    ..oo(0, [3, 4])
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOS(2, _omitFieldNames ? '' : 'requestId')
    ..aOS(3, _omitFieldNames ? '' : 'value')
    ..aOB(4, _omitFieldNames ? '' : 'skipped')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerSecretRequestRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerSecretRequestRequest copyWith(
          void Function(AnswerSecretRequestRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AnswerSecretRequestRequest))
          as AnswerSecretRequestRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AnswerSecretRequestRequest() / AnswerSecretRequestRequest.new instead')
  static AnswerSecretRequestRequest create() => AnswerSecretRequestRequest._();
  static $pb.GeneratedMessage $_createMessage() =>
      AnswerSecretRequestRequest._();
  @$core.override
  AnswerSecretRequestRequest createEmptyInstance() =>
      AnswerSecretRequestRequest._();
  @$core.pragma('dart2js:noInline')
  static AnswerSecretRequestRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnswerSecretRequestRequest>(
          AnswerSecretRequestRequest.$_createMessage);
  static AnswerSecretRequestRequest? _defaultInstance;

  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  AnswerSecretRequestRequest_Answer whichAnswer() =>
      _AnswerSecretRequestRequest_AnswerByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  void clearAnswer() => $_clearField($_whichOneof(0));

  /// message_id del mensaje que contiene el SecretRequest.
  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  /// request_id del SecretRequest.
  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => $_clearField(2);

  /// Texto de la variable: UTF-8, de 1 a 8 192 bytes, sin byte NUL.
  @$pb.TagNumber(3)
  $core.String get value => $_getSZ(2);
  @$pb.TagNumber(3)
  set value($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearValue() => $_clearField(3);

  /// true para omitir la petición.
  @$pb.TagNumber(4)
  $core.bool get skipped => $_getBF(3);
  @$pb.TagNumber(4)
  set skipped($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSkipped() => $_has(3);
  @$pb.TagNumber(4)
  void clearSkipped() => $_clearField(4);
}

/// Sin campos: la respuesta solo confirma que el servicio tiene el valor
/// o la omisión. Nunca devuelve el valor.
class AnswerSecretRequestResponse extends $pb.GeneratedMessage {
  factory AnswerSecretRequestResponse() => AnswerSecretRequestResponse._();

  AnswerSecretRequestResponse._();

  factory AnswerSecretRequestResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AnswerSecretRequestResponse()..mergeFromBuffer(data, registry);
  factory AnswerSecretRequestResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AnswerSecretRequestResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnswerSecretRequestResponse',
      createEmptyInstance: AnswerSecretRequestResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerSecretRequestResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerSecretRequestResponse copyWith(
          void Function(AnswerSecretRequestResponse) updates) =>
      super.copyWith(
              (message) => updates(message as AnswerSecretRequestResponse))
          as AnswerSecretRequestResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AnswerSecretRequestResponse() / AnswerSecretRequestResponse.new instead')
  static AnswerSecretRequestResponse create() =>
      AnswerSecretRequestResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      AnswerSecretRequestResponse._();
  @$core.override
  AnswerSecretRequestResponse createEmptyInstance() =>
      AnswerSecretRequestResponse._();
  @$core.pragma('dart2js:noInline')
  static AnswerSecretRequestResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnswerSecretRequestResponse>(
          AnswerSecretRequestResponse.$_createMessage);
  static AnswerSecretRequestResponse? _defaultInstance;
}

enum ContentPart_Kind {
  text,
  file,
  image,
  audio,
  structured,
  secretRequest,
  slotLink,
  notSet
}

class ContentPart extends $pb.GeneratedMessage {
  factory ContentPart({
    TextContent? text,
    FileReference? file,
    ImageContent? image,
    AudioContent? audio,
    StructuredContent? structured,
    SecretRequest? secretRequest,
    SlotLink? slotLink,
  }) {
    final result = ContentPart._();
    if (text != null) result.text = text;
    if (file != null) result.file = file;
    if (image != null) result.image = image;
    if (audio != null) result.audio = audio;
    if (structured != null) result.structured = structured;
    if (secretRequest != null) result.secretRequest = secretRequest;
    if (slotLink != null) result.slotLink = slotLink;
    return result;
  }

  ContentPart._();

  factory ContentPart.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContentPart()..mergeFromBuffer(data, registry);
  factory ContentPart.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContentPart()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ContentPart_Kind> _ContentPart_KindByTag = {
    1: ContentPart_Kind.text,
    2: ContentPart_Kind.file,
    3: ContentPart_Kind.image,
    4: ContentPart_Kind.audio,
    5: ContentPart_Kind.structured,
    6: ContentPart_Kind.secretRequest,
    7: ContentPart_Kind.slotLink,
    0: ContentPart_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContentPart',
      createEmptyInstance: ContentPart.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7])
    ..aOM<TextContent>(1, _omitFieldNames ? '' : 'text',
        subBuilder: TextContent.$_createMessage)
    ..aOM<FileReference>(2, _omitFieldNames ? '' : 'file',
        subBuilder: FileReference.$_createMessage)
    ..aOM<ImageContent>(3, _omitFieldNames ? '' : 'image',
        subBuilder: ImageContent.$_createMessage)
    ..aOM<AudioContent>(4, _omitFieldNames ? '' : 'audio',
        subBuilder: AudioContent.$_createMessage)
    ..aOM<StructuredContent>(5, _omitFieldNames ? '' : 'structured',
        subBuilder: StructuredContent.$_createMessage)
    ..aOM<SecretRequest>(6, _omitFieldNames ? '' : 'secretRequest',
        subBuilder: SecretRequest.$_createMessage)
    ..aOM<SlotLink>(7, _omitFieldNames ? '' : 'slotLink',
        subBuilder: SlotLink.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContentPart clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContentPart copyWith(void Function(ContentPart) updates) =>
      super.copyWith((message) => updates(message as ContentPart))
          as ContentPart;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ContentPart() / ContentPart.new instead')
  static ContentPart create() => ContentPart._();
  static $pb.GeneratedMessage $_createMessage() => ContentPart._();
  @$core.override
  ContentPart createEmptyInstance() => ContentPart._();
  @$core.pragma('dart2js:noInline')
  static ContentPart getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContentPart>(
          ContentPart.$_createMessage);
  static ContentPart? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  ContentPart_Kind whichKind() => _ContentPart_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  void clearKind() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  TextContent get text => $_getN(0);
  @$pb.TagNumber(1)
  set text(TextContent value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);
  @$pb.TagNumber(1)
  TextContent ensureText() => $_ensure(0);

  @$pb.TagNumber(2)
  FileReference get file => $_getN(1);
  @$pb.TagNumber(2)
  set file(FileReference value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasFile() => $_has(1);
  @$pb.TagNumber(2)
  void clearFile() => $_clearField(2);
  @$pb.TagNumber(2)
  FileReference ensureFile() => $_ensure(1);

  @$pb.TagNumber(3)
  ImageContent get image => $_getN(2);
  @$pb.TagNumber(3)
  set image(ImageContent value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasImage() => $_has(2);
  @$pb.TagNumber(3)
  void clearImage() => $_clearField(3);
  @$pb.TagNumber(3)
  ImageContent ensureImage() => $_ensure(2);

  @$pb.TagNumber(4)
  AudioContent get audio => $_getN(3);
  @$pb.TagNumber(4)
  set audio(AudioContent value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasAudio() => $_has(3);
  @$pb.TagNumber(4)
  void clearAudio() => $_clearField(4);
  @$pb.TagNumber(4)
  AudioContent ensureAudio() => $_ensure(3);

  @$pb.TagNumber(5)
  StructuredContent get structured => $_getN(4);
  @$pb.TagNumber(5)
  set structured(StructuredContent value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasStructured() => $_has(4);
  @$pb.TagNumber(5)
  void clearStructured() => $_clearField(5);
  @$pb.TagNumber(5)
  StructuredContent ensureStructured() => $_ensure(4);

  /// Revisión 6 (ronda 8, borrador). Solo en un mensaje del asistente COMPLETED.
  @$pb.TagNumber(6)
  SecretRequest get secretRequest => $_getN(5);
  @$pb.TagNumber(6)
  set secretRequest(SecretRequest value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasSecretRequest() => $_has(5);
  @$pb.TagNumber(6)
  void clearSecretRequest() => $_clearField(6);
  @$pb.TagNumber(6)
  SecretRequest ensureSecretRequest() => $_ensure(5);

  /// Revisión 6 (ronda 11, propuesta #120). Solo en un mensaje del asistente
  /// COMPLETED. Apunta a otro slot de la misma instancia (chat.md, 5.8).
  @$pb.TagNumber(7)
  SlotLink get slotLink => $_getN(6);
  @$pb.TagNumber(7)
  set slotLink(SlotLink value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSlotLink() => $_has(6);
  @$pb.TagNumber(7)
  void clearSlotLink() => $_clearField(7);
  @$pb.TagNumber(7)
  SlotLink ensureSlotLink() => $_ensure(6);
}

/// Revisión 6 (ronda 11, propuesta #120). Un puntero a otro slot de la misma
/// instancia, por ejemplo un mazo de cards.md. El cliente muestra un botón y
/// abre el slot solo cuando el usuario lo toca (chat.md, 5.8).
class SlotLink extends $pb.GeneratedMessage {
  factory SlotLink({
    $core.int? port,
    $core.String? label,
  }) {
    final result = SlotLink._();
    if (port != null) result.port = port;
    if (label != null) result.label = label;
    return result;
  }

  SlotLink._();

  factory SlotLink.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SlotLink()..mergeFromBuffer(data, registry);
  factory SlotLink.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SlotLink()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SlotLink',
      createEmptyInstance: SlotLink.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'port', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SlotLink clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SlotLink copyWith(void Function(SlotLink) updates) =>
      super.copyWith((message) => updates(message as SlotLink)) as SlotLink;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SlotLink() / SlotLink.new instead')
  static SlotLink create() => SlotLink._();
  static $pb.GeneratedMessage $_createMessage() => SlotLink._();
  @$core.override
  SlotLink createEmptyInstance() => SlotLink._();
  @$core.pragma('dart2js:noInline')
  static SlotLink getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SlotLink>(SlotLink.$_createMessage);
  static SlotLink? _defaultInstance;

  /// El port de un Slot del Service.Api de la instancia. Nombra el slot, como
  /// en ServiceTunnel. No es una dirección.
  @$pb.TagNumber(1)
  $core.int get port => $_getIZ(0);
  @$pb.TagNumber(1)
  set port($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPort() => $_has(0);
  @$pb.TagNumber(1)
  void clearPort() => $_clearField(1);

  /// Texto del botón: 1 a 32 caracteres, una línea. Ausente: el cliente usa
  /// su propio texto.
  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);
}

/// Revisión 6 (ronda 8, borrador). Petición de un secreto por nombre (chat.md, 5.6).
class SecretRequest extends $pb.GeneratedMessage {
  factory SecretRequest({
    $core.String? requestId,
    $core.String? name,
    $core.String? prose,
  }) {
    final result = SecretRequest._();
    if (requestId != null) result.requestId = requestId;
    if (name != null) result.name = name;
    if (prose != null) result.prose = prose;
    return result;
  }

  SecretRequest._();

  factory SecretRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SecretRequest()..mergeFromBuffer(data, registry);
  factory SecretRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SecretRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SecretRequest',
      createEmptyInstance: SecretRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'prose')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SecretRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SecretRequest copyWith(void Function(SecretRequest) updates) =>
      super.copyWith((message) => updates(message as SecretRequest))
          as SecretRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SecretRequest() / SecretRequest.new instead')
  static SecretRequest create() => SecretRequest._();
  static $pb.GeneratedMessage $_createMessage() => SecretRequest._();
  @$core.override
  SecretRequest createEmptyInstance() => SecretRequest._();
  @$core.pragma('dart2js:noInline')
  static SecretRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SecretRequest>(
          SecretRequest.$_createMessage);
  static SecretRequest? _defaultInstance;

  /// Identifica la petición en la instancia. 1 a 64 caracteres: A-Z, a-z, 0-9, - y _.
  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  /// Nombre de la variable que el servicio pide. 1 a 128 caracteres: A-Z, a-z, 0-9 y _.
  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  /// Texto para el usuario que explica por qué hace falta. Vacío equivale a ausente.
  @$pb.TagNumber(3)
  $core.String get prose => $_getSZ(2);
  @$pb.TagNumber(3)
  set prose($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProse() => $_has(2);
  @$pb.TagNumber(3)
  void clearProse() => $_clearField(3);
}

class TextContent extends $pb.GeneratedMessage {
  factory TextContent({
    $core.String? text,
  }) {
    final result = TextContent._();
    if (text != null) result.text = text;
    return result;
  }

  TextContent._();

  factory TextContent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TextContent()..mergeFromBuffer(data, registry);
  factory TextContent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TextContent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TextContent',
      createEmptyInstance: TextContent.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextContent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextContent copyWith(void Function(TextContent) updates) =>
      super.copyWith((message) => updates(message as TextContent))
          as TextContent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TextContent() / TextContent.new instead')
  static TextContent create() => TextContent._();
  static $pb.GeneratedMessage $_createMessage() => TextContent._();
  @$core.override
  TextContent createEmptyInstance() => TextContent._();
  @$core.pragma('dart2js:noInline')
  static TextContent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TextContent>(
          TextContent.$_createMessage);
  static TextContent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);
}

class Hash extends $pb.GeneratedMessage {
  factory Hash({
    $core.List<$core.int>? type,
    $core.List<$core.int>? value,
  }) {
    final result = Hash._();
    if (type != null) result.type = type;
    if (value != null) result.value = value;
    return result;
  }

  Hash._();

  factory Hash.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Hash()..mergeFromBuffer(data, registry);
  factory Hash.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Hash()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Hash',
      createEmptyInstance: Hash.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Hash clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Hash copyWith(void Function(Hash) updates) =>
      super.copyWith((message) => updates(message as Hash)) as Hash;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Hash() / Hash.new instead')
  static Hash create() => Hash._();
  static $pb.GeneratedMessage $_createMessage() => Hash._();
  @$core.override
  Hash createEmptyInstance() => Hash._();
  @$core.pragma('dart2js:noInline')
  static Hash getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Hash>(Hash.$_createMessage);
  static Hash? _defaultInstance;

  /// Identifica el algoritmo de hash y su longitud de salida.
  ///
  /// Se define como el digest de una entrada vacía calculado
  /// con ese algoritmo y esa longitud.
  ///
  /// Revisión 6: en el cable son los bytes crudos del digest (por
  /// ejemplo, 32 bytes para SHA3-256), no su texto hexadecimal. El
  /// hexadecimal solo es la forma en que chat.md escribe esos bytes.
  ///
  /// Revisión 6: type es obligatorio. Se envía siempre de forma
  /// explícita en cada Hash (QueryFilesRequest, QueryFilesResponse,
  /// FileReference, DownloadFileRequest y UploadFile). En proto3 un
  /// campo bytes no tiene presencia: un type vacío equivale a un type
  /// ausente y es un error (bad_request). Un type que no está vacío y
  /// que el servicio no conoce es un algoritmo desconocido, no un error.
  /// El número del campo no cambia: el cable es el mismo que con optional.
  @$pb.TagNumber(1)
  $core.List<$core.int> get type => $_getN(0);
  @$pb.TagNumber(1)
  set type($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  /// Digest del contenido.
  @$pb.TagNumber(2)
  $core.List<$core.int> get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);
}

class FileReference extends $pb.GeneratedMessage {
  factory FileReference({
    $core.Iterable<Hash>? hashes,
    $core.String? filename,
    $core.String? mimeType,
    $fixnum.Int64? sizeBytes,
  }) {
    final result = FileReference._();
    if (hashes != null) result.hashes.addAll(hashes);
    if (filename != null) result.filename = filename;
    if (mimeType != null) result.mimeType = mimeType;
    if (sizeBytes != null) result.sizeBytes = sizeBytes;
    return result;
  }

  FileReference._();

  factory FileReference.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FileReference()..mergeFromBuffer(data, registry);
  factory FileReference.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FileReference()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FileReference',
      createEmptyInstance: FileReference.$_createMessage)
    ..pPM<Hash>(1, _omitFieldNames ? '' : 'hashes',
        subBuilder: Hash.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'filename')
    ..aOS(3, _omitFieldNames ? '' : 'mimeType')
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'sizeBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileReference clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileReference copyWith(void Function(FileReference) updates) =>
      super.copyWith((message) => updates(message as FileReference))
          as FileReference;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FileReference() / FileReference.new instead')
  static FileReference create() => FileReference._();
  static $pb.GeneratedMessage $_createMessage() => FileReference._();
  @$core.override
  FileReference createEmptyInstance() => FileReference._();
  @$core.pragma('dart2js:noInline')
  static FileReference getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FileReference>(
          FileReference.$_createMessage);
  static FileReference? _defaultInstance;

  /// Hashes que identifican el mismo contenido.
  /// Cada hash debe incluir type explícitamente.
  @$pb.TagNumber(1)
  $pb.PbList<Hash> get hashes => $_getList(0);

  /// Nombre del archivo, si se conoce.
  @$pb.TagNumber(2)
  $core.String get filename => $_getSZ(1);
  @$pb.TagNumber(2)
  set filename($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFilename() => $_has(1);
  @$pb.TagNumber(2)
  void clearFilename() => $_clearField(2);

  /// Tipo MIME, si se conoce.
  @$pb.TagNumber(3)
  $core.String get mimeType => $_getSZ(2);
  @$pb.TagNumber(3)
  set mimeType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMimeType() => $_has(2);
  @$pb.TagNumber(3)
  void clearMimeType() => $_clearField(3);

  /// Tamaño del archivo en bytes, si se conoce.
  @$pb.TagNumber(4)
  $fixnum.Int64 get sizeBytes => $_getI64(3);
  @$pb.TagNumber(4)
  set sizeBytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSizeBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearSizeBytes() => $_clearField(4);
}

class ImageContent extends $pb.GeneratedMessage {
  factory ImageContent({
    FileReference? file,
    $core.String? altText,
  }) {
    final result = ImageContent._();
    if (file != null) result.file = file;
    if (altText != null) result.altText = altText;
    return result;
  }

  ImageContent._();

  factory ImageContent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImageContent()..mergeFromBuffer(data, registry);
  factory ImageContent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImageContent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImageContent',
      createEmptyInstance: ImageContent.$_createMessage)
    ..aOM<FileReference>(1, _omitFieldNames ? '' : 'file',
        subBuilder: FileReference.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'altText')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageContent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageContent copyWith(void Function(ImageContent) updates) =>
      super.copyWith((message) => updates(message as ImageContent))
          as ImageContent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ImageContent() / ImageContent.new instead')
  static ImageContent create() => ImageContent._();
  static $pb.GeneratedMessage $_createMessage() => ImageContent._();
  @$core.override
  ImageContent createEmptyInstance() => ImageContent._();
  @$core.pragma('dart2js:noInline')
  static ImageContent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ImageContent>(
          ImageContent.$_createMessage);
  static ImageContent? _defaultInstance;

  /// Referencia al contenido de imagen almacenado.
  @$pb.TagNumber(1)
  FileReference get file => $_getN(0);
  @$pb.TagNumber(1)
  set file(FileReference value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasFile() => $_has(0);
  @$pb.TagNumber(1)
  void clearFile() => $_clearField(1);
  @$pb.TagNumber(1)
  FileReference ensureFile() => $_ensure(0);

  /// Descripción alternativa de la imagen.
  @$pb.TagNumber(2)
  $core.String get altText => $_getSZ(1);
  @$pb.TagNumber(2)
  set altText($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAltText() => $_has(1);
  @$pb.TagNumber(2)
  void clearAltText() => $_clearField(2);
}

class AudioContent extends $pb.GeneratedMessage {
  factory AudioContent({
    FileReference? file,
    $core.String? transcript,
    $fixnum.Int64? durationMs,
  }) {
    final result = AudioContent._();
    if (file != null) result.file = file;
    if (transcript != null) result.transcript = transcript;
    if (durationMs != null) result.durationMs = durationMs;
    return result;
  }

  AudioContent._();

  factory AudioContent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AudioContent()..mergeFromBuffer(data, registry);
  factory AudioContent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AudioContent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AudioContent',
      createEmptyInstance: AudioContent.$_createMessage)
    ..aOM<FileReference>(1, _omitFieldNames ? '' : 'file',
        subBuilder: FileReference.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'transcript')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'durationMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AudioContent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AudioContent copyWith(void Function(AudioContent) updates) =>
      super.copyWith((message) => updates(message as AudioContent))
          as AudioContent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AudioContent() / AudioContent.new instead')
  static AudioContent create() => AudioContent._();
  static $pb.GeneratedMessage $_createMessage() => AudioContent._();
  @$core.override
  AudioContent createEmptyInstance() => AudioContent._();
  @$core.pragma('dart2js:noInline')
  static AudioContent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AudioContent>(
          AudioContent.$_createMessage);
  static AudioContent? _defaultInstance;

  /// Referencia al contenido de audio almacenado.
  @$pb.TagNumber(1)
  FileReference get file => $_getN(0);
  @$pb.TagNumber(1)
  set file(FileReference value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasFile() => $_has(0);
  @$pb.TagNumber(1)
  void clearFile() => $_clearField(1);
  @$pb.TagNumber(1)
  FileReference ensureFile() => $_ensure(0);

  /// Transcripción del audio, si existe.
  @$pb.TagNumber(2)
  $core.String get transcript => $_getSZ(1);
  @$pb.TagNumber(2)
  set transcript($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTranscript() => $_has(1);
  @$pb.TagNumber(2)
  void clearTranscript() => $_clearField(2);

  /// Duración del audio en milisegundos.
  @$pb.TagNumber(3)
  $fixnum.Int64 get durationMs => $_getI64(2);
  @$pb.TagNumber(3)
  set durationMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDurationMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearDurationMs() => $_clearField(3);
}

class StructuredContent extends $pb.GeneratedMessage {
  factory StructuredContent({
    $core.String? mediaType,
    $core.List<$core.int>? data,
  }) {
    final result = StructuredContent._();
    if (mediaType != null) result.mediaType = mediaType;
    if (data != null) result.data = data;
    return result;
  }

  StructuredContent._();

  factory StructuredContent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredContent()..mergeFromBuffer(data, registry);
  factory StructuredContent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredContent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredContent',
      createEmptyInstance: StructuredContent.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'mediaType')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredContent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredContent copyWith(void Function(StructuredContent) updates) =>
      super.copyWith((message) => updates(message as StructuredContent))
          as StructuredContent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StructuredContent() / StructuredContent.new instead')
  static StructuredContent create() => StructuredContent._();
  static $pb.GeneratedMessage $_createMessage() => StructuredContent._();
  @$core.override
  StructuredContent createEmptyInstance() => StructuredContent._();
  @$core.pragma('dart2js:noInline')
  static StructuredContent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StructuredContent>(
          StructuredContent.$_createMessage);
  static StructuredContent? _defaultInstance;

  /// Tipo MIME del contenido.
  /// Por ejemplo: application/json.
  @$pb.TagNumber(1)
  $core.String get mediaType => $_getSZ(0);
  @$pb.TagNumber(1)
  set mediaType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMediaType() => $_has(0);
  @$pb.TagNumber(1)
  void clearMediaType() => $_clearField(1);

  /// Datos serializados.
  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);
}

class QueryFilesRequest extends $pb.GeneratedMessage {
  factory QueryFilesRequest({
    Hash? hash,
  }) {
    final result = QueryFilesRequest._();
    if (hash != null) result.hash = hash;
    return result;
  }

  QueryFilesRequest._();

  factory QueryFilesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      QueryFilesRequest()..mergeFromBuffer(data, registry);
  factory QueryFilesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      QueryFilesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QueryFilesRequest',
      createEmptyInstance: QueryFilesRequest.$_createMessage)
    ..aOM<Hash>(1, _omitFieldNames ? '' : 'hash',
        subBuilder: Hash.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QueryFilesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QueryFilesRequest copyWith(void Function(QueryFilesRequest) updates) =>
      super.copyWith((message) => updates(message as QueryFilesRequest))
          as QueryFilesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use QueryFilesRequest() / QueryFilesRequest.new instead')
  static QueryFilesRequest create() => QueryFilesRequest._();
  static $pb.GeneratedMessage $_createMessage() => QueryFilesRequest._();
  @$core.override
  QueryFilesRequest createEmptyInstance() => QueryFilesRequest._();
  @$core.pragma('dart2js:noInline')
  static QueryFilesRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<QueryFilesRequest>(
          QueryFilesRequest.$_createMessage);
  static QueryFilesRequest? _defaultInstance;

  /// Hash del archivo que se desea consultar.
  /// type debe estar presente explícitamente (ver Hash).
  @$pb.TagNumber(1)
  Hash get hash => $_getN(0);
  @$pb.TagNumber(1)
  set hash(Hash value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHash() => $_has(0);
  @$pb.TagNumber(1)
  void clearHash() => $_clearField(1);
  @$pb.TagNumber(1)
  Hash ensureHash() => $_ensure(0);
}

class QueryFilesResponse extends $pb.GeneratedMessage {
  factory QueryFilesResponse({
    Hash? hash,
    $core.bool? available,
  }) {
    final result = QueryFilesResponse._();
    if (hash != null) result.hash = hash;
    if (available != null) result.available = available;
    return result;
  }

  QueryFilesResponse._();

  factory QueryFilesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      QueryFilesResponse()..mergeFromBuffer(data, registry);
  factory QueryFilesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      QueryFilesResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QueryFilesResponse',
      createEmptyInstance: QueryFilesResponse.$_createMessage)
    ..aOM<Hash>(1, _omitFieldNames ? '' : 'hash',
        subBuilder: Hash.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'available')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QueryFilesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QueryFilesResponse copyWith(void Function(QueryFilesResponse) updates) =>
      super.copyWith((message) => updates(message as QueryFilesResponse))
          as QueryFilesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use QueryFilesResponse() / QueryFilesResponse.new instead')
  static QueryFilesResponse create() => QueryFilesResponse._();
  static $pb.GeneratedMessage $_createMessage() => QueryFilesResponse._();
  @$core.override
  QueryFilesResponse createEmptyInstance() => QueryFilesResponse._();
  @$core.pragma('dart2js:noInline')
  static QueryFilesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QueryFilesResponse>(
          QueryFilesResponse.$_createMessage);
  static QueryFilesResponse? _defaultInstance;

  /// Hash consultado, con type explícito.
  @$pb.TagNumber(1)
  Hash get hash => $_getN(0);
  @$pb.TagNumber(1)
  set hash(Hash value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHash() => $_has(0);
  @$pb.TagNumber(1)
  void clearHash() => $_clearField(1);
  @$pb.TagNumber(1)
  Hash ensureHash() => $_ensure(0);

  /// Indica si el contenido está disponible para el solicitante.
  @$pb.TagNumber(2)
  $core.bool get available => $_getBF(1);
  @$pb.TagNumber(2)
  set available($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAvailable() => $_has(1);
  @$pb.TagNumber(2)
  void clearAvailable() => $_clearField(2);
}

enum UploadFileRequest_Part { file, chunk, notSet }

class UploadFileRequest extends $pb.GeneratedMessage {
  factory UploadFileRequest({
    FileReference? file,
    $core.List<$core.int>? chunk,
  }) {
    final result = UploadFileRequest._();
    if (file != null) result.file = file;
    if (chunk != null) result.chunk = chunk;
    return result;
  }

  UploadFileRequest._();

  factory UploadFileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UploadFileRequest()..mergeFromBuffer(data, registry);
  factory UploadFileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UploadFileRequest()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, UploadFileRequest_Part>
      _UploadFileRequest_PartByTag = {
    1: UploadFileRequest_Part.file,
    2: UploadFileRequest_Part.chunk,
    0: UploadFileRequest_Part.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UploadFileRequest',
      createEmptyInstance: UploadFileRequest.$_createMessage)
    ..oo(0, [1, 2])
    ..aOM<FileReference>(1, _omitFieldNames ? '' : 'file',
        subBuilder: FileReference.$_createMessage)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'chunk', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadFileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadFileRequest copyWith(void Function(UploadFileRequest) updates) =>
      super.copyWith((message) => updates(message as UploadFileRequest))
          as UploadFileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UploadFileRequest() / UploadFileRequest.new instead')
  static UploadFileRequest create() => UploadFileRequest._();
  static $pb.GeneratedMessage $_createMessage() => UploadFileRequest._();
  @$core.override
  UploadFileRequest createEmptyInstance() => UploadFileRequest._();
  @$core.pragma('dart2js:noInline')
  static UploadFileRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UploadFileRequest>(
          UploadFileRequest.$_createMessage);
  static UploadFileRequest? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  UploadFileRequest_Part whichPart() =>
      _UploadFileRequest_PartByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearPart() => $_clearField($_whichOneof(0));

  /// Debe aparecer una vez, al principio del stream.
  @$pb.TagNumber(1)
  FileReference get file => $_getN(0);
  @$pb.TagNumber(1)
  set file(FileReference value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasFile() => $_has(0);
  @$pb.TagNumber(1)
  void clearFile() => $_clearField(1);
  @$pb.TagNumber(1)
  FileReference ensureFile() => $_ensure(0);

  /// Bloque de datos del archivo.
  /// Solo puede aparecer después de FileReference.
  @$pb.TagNumber(2)
  $core.List<$core.int> get chunk => $_getN(1);
  @$pb.TagNumber(2)
  set chunk($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChunk() => $_has(1);
  @$pb.TagNumber(2)
  void clearChunk() => $_clearField(2);
}

class UploadFileResponse extends $pb.GeneratedMessage {
  factory UploadFileResponse({
    FileReference? file,
  }) {
    final result = UploadFileResponse._();
    if (file != null) result.file = file;
    return result;
  }

  UploadFileResponse._();

  factory UploadFileResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UploadFileResponse()..mergeFromBuffer(data, registry);
  factory UploadFileResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UploadFileResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UploadFileResponse',
      createEmptyInstance: UploadFileResponse.$_createMessage)
    ..aOM<FileReference>(1, _omitFieldNames ? '' : 'file',
        subBuilder: FileReference.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadFileResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadFileResponse copyWith(void Function(UploadFileResponse) updates) =>
      super.copyWith((message) => updates(message as UploadFileResponse))
          as UploadFileResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UploadFileResponse() / UploadFileResponse.new instead')
  static UploadFileResponse create() => UploadFileResponse._();
  static $pb.GeneratedMessage $_createMessage() => UploadFileResponse._();
  @$core.override
  UploadFileResponse createEmptyInstance() => UploadFileResponse._();
  @$core.pragma('dart2js:noInline')
  static UploadFileResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UploadFileResponse>(
          UploadFileResponse.$_createMessage);
  static UploadFileResponse? _defaultInstance;

  /// Referencia confirmada por el servidor, con los hashes
  /// validados y el tamaño real del archivo.
  @$pb.TagNumber(1)
  FileReference get file => $_getN(0);
  @$pb.TagNumber(1)
  set file(FileReference value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasFile() => $_has(0);
  @$pb.TagNumber(1)
  void clearFile() => $_clearField(1);
  @$pb.TagNumber(1)
  FileReference ensureFile() => $_ensure(0);
}

class DownloadFileRequest extends $pb.GeneratedMessage {
  factory DownloadFileRequest({
    Hash? hash,
  }) {
    final result = DownloadFileRequest._();
    if (hash != null) result.hash = hash;
    return result;
  }

  DownloadFileRequest._();

  factory DownloadFileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadFileRequest()..mergeFromBuffer(data, registry);
  factory DownloadFileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadFileRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DownloadFileRequest',
      createEmptyInstance: DownloadFileRequest.$_createMessage)
    ..aOM<Hash>(1, _omitFieldNames ? '' : 'hash',
        subBuilder: Hash.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadFileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadFileRequest copyWith(void Function(DownloadFileRequest) updates) =>
      super.copyWith((message) => updates(message as DownloadFileRequest))
          as DownloadFileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use DownloadFileRequest() / DownloadFileRequest.new instead')
  static DownloadFileRequest create() => DownloadFileRequest._();
  static $pb.GeneratedMessage $_createMessage() => DownloadFileRequest._();
  @$core.override
  DownloadFileRequest createEmptyInstance() => DownloadFileRequest._();
  @$core.pragma('dart2js:noInline')
  static DownloadFileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DownloadFileRequest>(
          DownloadFileRequest.$_createMessage);
  static DownloadFileRequest? _defaultInstance;

  /// Hash que identifica el archivo.
  /// type debe estar presente explícitamente.
  @$pb.TagNumber(1)
  Hash get hash => $_getN(0);
  @$pb.TagNumber(1)
  set hash(Hash value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHash() => $_has(0);
  @$pb.TagNumber(1)
  void clearHash() => $_clearField(1);
  @$pb.TagNumber(1)
  Hash ensureHash() => $_ensure(0);
}

class DownloadFileResponse extends $pb.GeneratedMessage {
  factory DownloadFileResponse({
    $core.List<$core.int>? chunk,
  }) {
    final result = DownloadFileResponse._();
    if (chunk != null) result.chunk = chunk;
    return result;
  }

  DownloadFileResponse._();

  factory DownloadFileResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadFileResponse()..mergeFromBuffer(data, registry);
  factory DownloadFileResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadFileResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DownloadFileResponse',
      createEmptyInstance: DownloadFileResponse.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'chunk', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadFileResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadFileResponse copyWith(void Function(DownloadFileResponse) updates) =>
      super.copyWith((message) => updates(message as DownloadFileResponse))
          as DownloadFileResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DownloadFileResponse() / DownloadFileResponse.new instead')
  static DownloadFileResponse create() => DownloadFileResponse._();
  static $pb.GeneratedMessage $_createMessage() => DownloadFileResponse._();
  @$core.override
  DownloadFileResponse createEmptyInstance() => DownloadFileResponse._();
  @$core.pragma('dart2js:noInline')
  static DownloadFileResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DownloadFileResponse>(
          DownloadFileResponse.$_createMessage);
  static DownloadFileResponse? _defaultInstance;

  /// Bloque consecutivo del archivo.
  /// El final del stream indica el final de la transferencia.
  @$pb.TagNumber(1)
  $core.List<$core.int> get chunk => $_getN(0);
  @$pb.TagNumber(1)
  set chunk($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChunk() => $_has(0);
  @$pb.TagNumber(1)
  void clearChunk() => $_clearField(1);
}

class GetCapabilitiesRequest extends $pb.GeneratedMessage {
  factory GetCapabilitiesRequest() => GetCapabilitiesRequest._();

  GetCapabilitiesRequest._();

  factory GetCapabilitiesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetCapabilitiesRequest()..mergeFromBuffer(data, registry);
  factory GetCapabilitiesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetCapabilitiesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetCapabilitiesRequest',
      createEmptyInstance: GetCapabilitiesRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCapabilitiesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCapabilitiesRequest copyWith(
          void Function(GetCapabilitiesRequest) updates) =>
      super.copyWith((message) => updates(message as GetCapabilitiesRequest))
          as GetCapabilitiesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetCapabilitiesRequest() / GetCapabilitiesRequest.new instead')
  static GetCapabilitiesRequest create() => GetCapabilitiesRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetCapabilitiesRequest._();
  @$core.override
  GetCapabilitiesRequest createEmptyInstance() => GetCapabilitiesRequest._();
  @$core.pragma('dart2js:noInline')
  static GetCapabilitiesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetCapabilitiesRequest>(
          GetCapabilitiesRequest.$_createMessage);
  static GetCapabilitiesRequest? _defaultInstance;
}

class Capabilities extends $pb.GeneratedMessage {
  factory Capabilities({
    $core.Iterable<$core.String>? acceptedMimeTypes,
    $fixnum.Int64? maxFileBytes,
    $core.int? maxFilesPerMessage,
    $core.int? maxTextBytes,
    $core.bool? supportsFork,
    $core.bool? supportsCancel,
  }) {
    final result = Capabilities._();
    if (acceptedMimeTypes != null)
      result.acceptedMimeTypes.addAll(acceptedMimeTypes);
    if (maxFileBytes != null) result.maxFileBytes = maxFileBytes;
    if (maxFilesPerMessage != null)
      result.maxFilesPerMessage = maxFilesPerMessage;
    if (maxTextBytes != null) result.maxTextBytes = maxTextBytes;
    if (supportsFork != null) result.supportsFork = supportsFork;
    if (supportsCancel != null) result.supportsCancel = supportsCancel;
    return result;
  }

  Capabilities._();

  factory Capabilities.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Capabilities()..mergeFromBuffer(data, registry);
  factory Capabilities.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Capabilities()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Capabilities',
      createEmptyInstance: Capabilities.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'acceptedMimeTypes')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'maxFileBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(3, _omitFieldNames ? '' : 'maxFilesPerMessage',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'maxTextBytes',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(5, _omitFieldNames ? '' : 'supportsFork')
    ..aOB(6, _omitFieldNames ? '' : 'supportsCancel')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Capabilities clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Capabilities copyWith(void Function(Capabilities) updates) =>
      super.copyWith((message) => updates(message as Capabilities))
          as Capabilities;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Capabilities() / Capabilities.new instead')
  static Capabilities create() => Capabilities._();
  static $pb.GeneratedMessage $_createMessage() => Capabilities._();
  @$core.override
  Capabilities createEmptyInstance() => Capabilities._();
  @$core.pragma('dart2js:noInline')
  static Capabilities getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Capabilities>(
          Capabilities.$_createMessage);
  static Capabilities? _defaultInstance;

  /// Tipos MIME que el servicio acepta en SendMessage, en minúsculas y
  /// sin parámetros. Vacío: el servicio acepta solo texto.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get acceptedMimeTypes => $_getList(0);

  /// Tamaño máximo de un archivo, en bytes. 0: el valor de chat.md.
  @$pb.TagNumber(2)
  $fixnum.Int64 get maxFileBytes => $_getI64(1);
  @$pb.TagNumber(2)
  set maxFileBytes($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMaxFileBytes() => $_has(1);
  @$pb.TagNumber(2)
  void clearMaxFileBytes() => $_clearField(2);

  /// Número máximo de archivos en un mensaje. 0: el valor de chat.md.
  @$pb.TagNumber(3)
  $core.int get maxFilesPerMessage => $_getIZ(2);
  @$pb.TagNumber(3)
  set maxFilesPerMessage($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMaxFilesPerMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearMaxFilesPerMessage() => $_clearField(3);

  /// Tamaño máximo del texto de un mensaje, en bytes UTF-8.
  /// 0: el valor de chat.md.
  @$pb.TagNumber(4)
  $core.int get maxTextBytes => $_getIZ(3);
  @$pb.TagNumber(4)
  set maxTextBytes($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMaxTextBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearMaxTextBytes() => $_clearField(4);

  /// El servicio implementa ForkConversation y las conversaciones
  /// distintas de la principal.
  @$pb.TagNumber(5)
  $core.bool get supportsFork => $_getBF(4);
  @$pb.TagNumber(5)
  set supportsFork($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSupportsFork() => $_has(4);
  @$pb.TagNumber(5)
  void clearSupportsFork() => $_clearField(5);

  /// El servicio implementa el evento cancel_message de ClientEvent
  /// (CancelMessageRequest).
  @$pb.TagNumber(6)
  $core.bool get supportsCancel => $_getBF(5);
  @$pb.TagNumber(6)
  set supportsCancel($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSupportsCancel() => $_has(5);
  @$pb.TagNumber(6)
  void clearSupportsCancel() => $_clearField(6);
}

enum ClientEvent_Event {
  sendMessage,
  subscribe,
  acknowledge,
  cancelMessage,
  notSet
}

class ClientEvent extends $pb.GeneratedMessage {
  factory ClientEvent({
    SendMessageRequest? sendMessage,
    SubscribeRequest? subscribe,
    AcknowledgeEvent? acknowledge,
    CancelMessageRequest? cancelMessage,
    $core.String? eventId,
  }) {
    final result = ClientEvent._();
    if (sendMessage != null) result.sendMessage = sendMessage;
    if (subscribe != null) result.subscribe = subscribe;
    if (acknowledge != null) result.acknowledge = acknowledge;
    if (cancelMessage != null) result.cancelMessage = cancelMessage;
    if (eventId != null) result.eventId = eventId;
    return result;
  }

  ClientEvent._();

  factory ClientEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClientEvent()..mergeFromBuffer(data, registry);
  factory ClientEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClientEvent()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ClientEvent_Event> _ClientEvent_EventByTag =
      {
    1: ClientEvent_Event.sendMessage,
    2: ClientEvent_Event.subscribe,
    3: ClientEvent_Event.acknowledge,
    4: ClientEvent_Event.cancelMessage,
    0: ClientEvent_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientEvent',
      createEmptyInstance: ClientEvent.$_createMessage)
    ..oo(0, [1, 2, 3, 4])
    ..aOM<SendMessageRequest>(1, _omitFieldNames ? '' : 'sendMessage',
        subBuilder: SendMessageRequest.$_createMessage)
    ..aOM<SubscribeRequest>(2, _omitFieldNames ? '' : 'subscribe',
        subBuilder: SubscribeRequest.$_createMessage)
    ..aOM<AcknowledgeEvent>(3, _omitFieldNames ? '' : 'acknowledge',
        subBuilder: AcknowledgeEvent.$_createMessage)
    ..aOM<CancelMessageRequest>(4, _omitFieldNames ? '' : 'cancelMessage',
        subBuilder: CancelMessageRequest.$_createMessage)
    ..aOS(5, _omitFieldNames ? '' : 'eventId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientEvent copyWith(void Function(ClientEvent) updates) =>
      super.copyWith((message) => updates(message as ClientEvent))
          as ClientEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ClientEvent() / ClientEvent.new instead')
  static ClientEvent create() => ClientEvent._();
  static $pb.GeneratedMessage $_createMessage() => ClientEvent._();
  @$core.override
  ClientEvent createEmptyInstance() => ClientEvent._();
  @$core.pragma('dart2js:noInline')
  static ClientEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ClientEvent>(
          ClientEvent.$_createMessage);
  static ClientEvent? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  ClientEvent_Event whichEvent() => _ClientEvent_EventByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  void clearEvent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  SendMessageRequest get sendMessage => $_getN(0);
  @$pb.TagNumber(1)
  set sendMessage(SendMessageRequest value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSendMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearSendMessage() => $_clearField(1);
  @$pb.TagNumber(1)
  SendMessageRequest ensureSendMessage() => $_ensure(0);

  @$pb.TagNumber(2)
  SubscribeRequest get subscribe => $_getN(1);
  @$pb.TagNumber(2)
  set subscribe(SubscribeRequest value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSubscribe() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubscribe() => $_clearField(2);
  @$pb.TagNumber(2)
  SubscribeRequest ensureSubscribe() => $_ensure(1);

  @$pb.TagNumber(3)
  AcknowledgeEvent get acknowledge => $_getN(2);
  @$pb.TagNumber(3)
  set acknowledge(AcknowledgeEvent value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAcknowledge() => $_has(2);
  @$pb.TagNumber(3)
  void clearAcknowledge() => $_clearField(3);
  @$pb.TagNumber(3)
  AcknowledgeEvent ensureAcknowledge() => $_ensure(2);

  @$pb.TagNumber(4)
  CancelMessageRequest get cancelMessage => $_getN(3);
  @$pb.TagNumber(4)
  set cancelMessage(CancelMessageRequest value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCancelMessage() => $_has(3);
  @$pb.TagNumber(4)
  void clearCancelMessage() => $_clearField(4);
  @$pb.TagNumber(4)
  CancelMessageRequest ensureCancelMessage() => $_ensure(3);

  /// Revisión 6.
  /// Identificador del evento, de 1 a 64 caracteres de A-Z, a-z, 0-9,
  /// "-" y "_". Es único dentro del stream. Es opcional, pero un
  /// cliente que envía eventos por Connect debe ponerlo. Si el evento
  /// falla, el servicio lo copia en ProtocolError.event_id.
  @$pb.TagNumber(5)
  $core.String get eventId => $_getSZ(4);
  @$pb.TagNumber(5)
  set eventId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEventId() => $_has(4);
  @$pb.TagNumber(5)
  void clearEventId() => $_clearField(5);
}

enum ServerEvent_Event {
  messageCreated,
  messageDeleted,
  messageProgress,
  subscriptionReady,
  error,
  messageStatusChanged,
  messageDelta,
  messagePinnedChanged,
  conversationTitleChanged,
  notSet
}

class ServerEvent extends $pb.GeneratedMessage {
  factory ServerEvent({
    MessageCreated? messageCreated,
    MessageDeleted? messageDeleted,
    MessageProgress? messageProgress,
    SubscriptionReady? subscriptionReady,
    ProtocolError? error,
    MessageStatusChanged? messageStatusChanged,
    MessageDelta? messageDelta,
    MessagePinnedChanged? messagePinnedChanged,
    ConversationTitleChanged? conversationTitleChanged,
  }) {
    final result = ServerEvent._();
    if (messageCreated != null) result.messageCreated = messageCreated;
    if (messageDeleted != null) result.messageDeleted = messageDeleted;
    if (messageProgress != null) result.messageProgress = messageProgress;
    if (subscriptionReady != null) result.subscriptionReady = subscriptionReady;
    if (error != null) result.error = error;
    if (messageStatusChanged != null)
      result.messageStatusChanged = messageStatusChanged;
    if (messageDelta != null) result.messageDelta = messageDelta;
    if (messagePinnedChanged != null)
      result.messagePinnedChanged = messagePinnedChanged;
    if (conversationTitleChanged != null)
      result.conversationTitleChanged = conversationTitleChanged;
    return result;
  }

  ServerEvent._();

  factory ServerEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ServerEvent()..mergeFromBuffer(data, registry);
  factory ServerEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ServerEvent()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ServerEvent_Event> _ServerEvent_EventByTag =
      {
    1: ServerEvent_Event.messageCreated,
    2: ServerEvent_Event.messageDeleted,
    3: ServerEvent_Event.messageProgress,
    4: ServerEvent_Event.subscriptionReady,
    5: ServerEvent_Event.error,
    6: ServerEvent_Event.messageStatusChanged,
    7: ServerEvent_Event.messageDelta,
    8: ServerEvent_Event.messagePinnedChanged,
    9: ServerEvent_Event.conversationTitleChanged,
    0: ServerEvent_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerEvent',
      createEmptyInstance: ServerEvent.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9])
    ..aOM<MessageCreated>(1, _omitFieldNames ? '' : 'messageCreated',
        subBuilder: MessageCreated.$_createMessage)
    ..aOM<MessageDeleted>(2, _omitFieldNames ? '' : 'messageDeleted',
        subBuilder: MessageDeleted.$_createMessage)
    ..aOM<MessageProgress>(3, _omitFieldNames ? '' : 'messageProgress',
        subBuilder: MessageProgress.$_createMessage)
    ..aOM<SubscriptionReady>(4, _omitFieldNames ? '' : 'subscriptionReady',
        subBuilder: SubscriptionReady.$_createMessage)
    ..aOM<ProtocolError>(5, _omitFieldNames ? '' : 'error',
        subBuilder: ProtocolError.$_createMessage)
    ..aOM<MessageStatusChanged>(
        6, _omitFieldNames ? '' : 'messageStatusChanged',
        subBuilder: MessageStatusChanged.$_createMessage)
    ..aOM<MessageDelta>(7, _omitFieldNames ? '' : 'messageDelta',
        subBuilder: MessageDelta.$_createMessage)
    ..aOM<MessagePinnedChanged>(
        8, _omitFieldNames ? '' : 'messagePinnedChanged',
        subBuilder: MessagePinnedChanged.$_createMessage)
    ..aOM<ConversationTitleChanged>(
        9, _omitFieldNames ? '' : 'conversationTitleChanged',
        subBuilder: ConversationTitleChanged.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerEvent copyWith(void Function(ServerEvent) updates) =>
      super.copyWith((message) => updates(message as ServerEvent))
          as ServerEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ServerEvent() / ServerEvent.new instead')
  static ServerEvent create() => ServerEvent._();
  static $pb.GeneratedMessage $_createMessage() => ServerEvent._();
  @$core.override
  ServerEvent createEmptyInstance() => ServerEvent._();
  @$core.pragma('dart2js:noInline')
  static ServerEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ServerEvent>(
          ServerEvent.$_createMessage);
  static ServerEvent? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  ServerEvent_Event whichEvent() => _ServerEvent_EventByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  void clearEvent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  MessageCreated get messageCreated => $_getN(0);
  @$pb.TagNumber(1)
  set messageCreated(MessageCreated value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageCreated() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageCreated() => $_clearField(1);
  @$pb.TagNumber(1)
  MessageCreated ensureMessageCreated() => $_ensure(0);

  @$pb.TagNumber(2)
  MessageDeleted get messageDeleted => $_getN(1);
  @$pb.TagNumber(2)
  set messageDeleted(MessageDeleted value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageDeleted() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageDeleted() => $_clearField(2);
  @$pb.TagNumber(2)
  MessageDeleted ensureMessageDeleted() => $_ensure(1);

  @$pb.TagNumber(3)
  MessageProgress get messageProgress => $_getN(2);
  @$pb.TagNumber(3)
  set messageProgress(MessageProgress value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasMessageProgress() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessageProgress() => $_clearField(3);
  @$pb.TagNumber(3)
  MessageProgress ensureMessageProgress() => $_ensure(2);

  @$pb.TagNumber(4)
  SubscriptionReady get subscriptionReady => $_getN(3);
  @$pb.TagNumber(4)
  set subscriptionReady(SubscriptionReady value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasSubscriptionReady() => $_has(3);
  @$pb.TagNumber(4)
  void clearSubscriptionReady() => $_clearField(4);
  @$pb.TagNumber(4)
  SubscriptionReady ensureSubscriptionReady() => $_ensure(3);

  @$pb.TagNumber(5)
  ProtocolError get error => $_getN(4);
  @$pb.TagNumber(5)
  set error(ProtocolError value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasError() => $_has(4);
  @$pb.TagNumber(5)
  void clearError() => $_clearField(5);
  @$pb.TagNumber(5)
  ProtocolError ensureError() => $_ensure(4);

  @$pb.TagNumber(6)
  MessageStatusChanged get messageStatusChanged => $_getN(5);
  @$pb.TagNumber(6)
  set messageStatusChanged(MessageStatusChanged value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasMessageStatusChanged() => $_has(5);
  @$pb.TagNumber(6)
  void clearMessageStatusChanged() => $_clearField(6);
  @$pb.TagNumber(6)
  MessageStatusChanged ensureMessageStatusChanged() => $_ensure(5);

  /// Revisión 6.
  @$pb.TagNumber(7)
  MessageDelta get messageDelta => $_getN(6);
  @$pb.TagNumber(7)
  set messageDelta(MessageDelta value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasMessageDelta() => $_has(6);
  @$pb.TagNumber(7)
  void clearMessageDelta() => $_clearField(7);
  @$pb.TagNumber(7)
  MessageDelta ensureMessageDelta() => $_ensure(6);

  /// Revisión 6.
  @$pb.TagNumber(8)
  MessagePinnedChanged get messagePinnedChanged => $_getN(7);
  @$pb.TagNumber(8)
  set messagePinnedChanged(MessagePinnedChanged value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasMessagePinnedChanged() => $_has(7);
  @$pb.TagNumber(8)
  void clearMessagePinnedChanged() => $_clearField(8);
  @$pb.TagNumber(8)
  MessagePinnedChanged ensureMessagePinnedChanged() => $_ensure(7);

  /// Revisión 6 (ronda 9, propuesta #89).
  @$pb.TagNumber(9)
  ConversationTitleChanged get conversationTitleChanged => $_getN(8);
  @$pb.TagNumber(9)
  set conversationTitleChanged(ConversationTitleChanged value) =>
      $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasConversationTitleChanged() => $_has(8);
  @$pb.TagNumber(9)
  void clearConversationTitleChanged() => $_clearField(9);
  @$pb.TagNumber(9)
  ConversationTitleChanged ensureConversationTitleChanged() => $_ensure(8);
}

class SubscribeRequest extends $pb.GeneratedMessage {
  factory SubscribeRequest({
    $core.String? conversationId,
    $fixnum.Int64? afterSequence,
  }) {
    final result = SubscribeRequest._();
    if (conversationId != null) result.conversationId = conversationId;
    if (afterSequence != null) result.afterSequence = afterSequence;
    return result;
  }

  SubscribeRequest._();

  factory SubscribeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SubscribeRequest()..mergeFromBuffer(data, registry);
  factory SubscribeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SubscribeRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubscribeRequest',
      createEmptyInstance: SubscribeRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'conversationId')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'afterSequence', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeRequest copyWith(void Function(SubscribeRequest) updates) =>
      super.copyWith((message) => updates(message as SubscribeRequest))
          as SubscribeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SubscribeRequest() / SubscribeRequest.new instead')
  static SubscribeRequest create() => SubscribeRequest._();
  static $pb.GeneratedMessage $_createMessage() => SubscribeRequest._();
  @$core.override
  SubscribeRequest createEmptyInstance() => SubscribeRequest._();
  @$core.pragma('dart2js:noInline')
  static SubscribeRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SubscribeRequest>(
          SubscribeRequest.$_createMessage);
  static SubscribeRequest? _defaultInstance;

  /// Ausente para la conversación principal.
  @$pb.TagNumber(1)
  $core.String get conversationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set conversationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConversationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearConversationId() => $_clearField(1);

  /// Última secuencia procesada por el cliente.
  @$pb.TagNumber(2)
  $fixnum.Int64 get afterSequence => $_getI64(1);
  @$pb.TagNumber(2)
  set afterSequence($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAfterSequence() => $_has(1);
  @$pb.TagNumber(2)
  void clearAfterSequence() => $_clearField(2);
}

class AcknowledgeEvent extends $pb.GeneratedMessage {
  factory AcknowledgeEvent({
    $fixnum.Int64? lastSequence,
  }) {
    final result = AcknowledgeEvent._();
    if (lastSequence != null) result.lastSequence = lastSequence;
    return result;
  }

  AcknowledgeEvent._();

  factory AcknowledgeEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AcknowledgeEvent()..mergeFromBuffer(data, registry);
  factory AcknowledgeEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AcknowledgeEvent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AcknowledgeEvent',
      createEmptyInstance: AcknowledgeEvent.$_createMessage)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'lastSequence', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcknowledgeEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcknowledgeEvent copyWith(void Function(AcknowledgeEvent) updates) =>
      super.copyWith((message) => updates(message as AcknowledgeEvent))
          as AcknowledgeEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AcknowledgeEvent() / AcknowledgeEvent.new instead')
  static AcknowledgeEvent create() => AcknowledgeEvent._();
  static $pb.GeneratedMessage $_createMessage() => AcknowledgeEvent._();
  @$core.override
  AcknowledgeEvent createEmptyInstance() => AcknowledgeEvent._();
  @$core.pragma('dart2js:noInline')
  static AcknowledgeEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AcknowledgeEvent>(
          AcknowledgeEvent.$_createMessage);
  static AcknowledgeEvent? _defaultInstance;

  /// Última secuencia procesada por el cliente.
  ///
  /// Revisión 6: es una indicación de que el cliente tiene todos los
  /// mensajes hasta esa secuencia en estado final. El servicio puede
  /// descartar los eventos pendientes de esos mensajes. Nunca borra el
  /// historial. Una secuencia mayor que la última del servicio produce
  /// ProtocolError bad_request. Una secuencia menor que una anterior
  /// se ignora. No tiene respuesta positiva.
  @$pb.TagNumber(1)
  $fixnum.Int64 get lastSequence => $_getI64(0);
  @$pb.TagNumber(1)
  set lastSequence($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLastSequence() => $_has(0);
  @$pb.TagNumber(1)
  void clearLastSequence() => $_clearField(1);
}

class CancelMessageRequest extends $pb.GeneratedMessage {
  factory CancelMessageRequest({
    $core.String? messageId,
    $core.String? conversationId,
  }) {
    final result = CancelMessageRequest._();
    if (messageId != null) result.messageId = messageId;
    if (conversationId != null) result.conversationId = conversationId;
    return result;
  }

  CancelMessageRequest._();

  factory CancelMessageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CancelMessageRequest()..mergeFromBuffer(data, registry);
  factory CancelMessageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CancelMessageRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CancelMessageRequest',
      createEmptyInstance: CancelMessageRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOS(2, _omitFieldNames ? '' : 'conversationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelMessageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelMessageRequest copyWith(void Function(CancelMessageRequest) updates) =>
      super.copyWith((message) => updates(message as CancelMessageRequest))
          as CancelMessageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CancelMessageRequest() / CancelMessageRequest.new instead')
  static CancelMessageRequest create() => CancelMessageRequest._();
  static $pb.GeneratedMessage $_createMessage() => CancelMessageRequest._();
  @$core.override
  CancelMessageRequest createEmptyInstance() => CancelMessageRequest._();
  @$core.pragma('dart2js:noInline')
  static CancelMessageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CancelMessageRequest>(
          CancelMessageRequest.$_createMessage);
  static CancelMessageRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  /// Ausente para la conversación principal.
  @$pb.TagNumber(2)
  $core.String get conversationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set conversationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConversationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConversationId() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
