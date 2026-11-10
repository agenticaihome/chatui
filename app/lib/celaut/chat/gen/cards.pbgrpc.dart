// This is a generated file - do not edit.
//
// Generated from cards.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'cards.pb.dart' as $0;

export 'cards.pb.dart';

@$pb.GrpcServiceName('CardsService')
class CardsServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  CardsServiceClient(super.channel, {super.options, super.interceptors});

  /// Estado del mazo en tiempo real. El primer evento es siempre una copia
  /// completa (DeckEvent.deck). Después llegan los cambios, en orden.
  $grpc.ResponseStream<$0.DeckEvent> watch(
    $0.WatchRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$watch, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Una decisión del usuario sobre una carta. El servicio la acepta y
  /// contesta sin esperar nada más. Repetir la misma idempotency_key no
  /// cambia nada.
  $grpc.ResponseFuture<$0.SendActionResponse> sendAction(
    $0.SendActionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$sendAction, request, options: options);
  }

  // method descriptors

  static final _$watch = $grpc.ClientMethod<$0.WatchRequest, $0.DeckEvent>(
      '/CardsService/Watch',
      ($0.WatchRequest value) => value.writeToBuffer(),
      $0.DeckEvent.fromBuffer);
  static final _$sendAction =
      $grpc.ClientMethod<$0.SendActionRequest, $0.SendActionResponse>(
          '/CardsService/SendAction',
          ($0.SendActionRequest value) => value.writeToBuffer(),
          $0.SendActionResponse.fromBuffer);
}

@$pb.GrpcServiceName('CardsService')
abstract class CardsServiceBase extends $grpc.Service {
  $core.String get $name => 'CardsService';

  CardsServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.WatchRequest, $0.DeckEvent>(
        'Watch',
        watch_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.WatchRequest.fromBuffer(value),
        ($0.DeckEvent value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SendActionRequest, $0.SendActionResponse>(
        'SendAction',
        sendAction_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SendActionRequest.fromBuffer(value),
        ($0.SendActionResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.DeckEvent> watch_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.WatchRequest> $request) async* {
    yield* watch($call, await $request);
  }

  $async.Stream<$0.DeckEvent> watch(
      $grpc.ServiceCall call, $0.WatchRequest request);

  $async.Future<$0.SendActionResponse> sendAction_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SendActionRequest> $request) async {
    return sendAction($call, await $request);
  }

  $async.Future<$0.SendActionResponse> sendAction(
      $grpc.ServiceCall call, $0.SendActionRequest request);
}
