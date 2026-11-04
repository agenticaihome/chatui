// Secret requests of a service in the chat (`docs/celaut/chat.md`, sections 5.6 and 6.9).
import 'dart:async';
import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut_env.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/bridge/api/celaut_service_info.dart';
import 'package:argus_wallet/celaut/chat/gen/chat.pbgrpc.dart' as pb;
import 'package:argus_wallet/celaut/chat_client.dart';
import 'package:argus_wallet/celaut/chat_done_watcher.dart';
import 'package:argus_wallet/celaut/conversation_keep_alive.dart';
import 'package:argus_wallet/celaut/conversations.dart';
import 'package:argus_wallet/celaut/egress.dart';
import 'package:argus_wallet/celaut/env_store.dart';
import 'package:argus_wallet/celaut/payers.dart';
import 'package:argus_wallet/celaut/secret_answers.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/celaut/chat_screen.dart';
import 'package:argus_wallet/ui/celaut/env_questions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_chat_service.dart';

pb.ContentPart secretPart(String id, String name, {String prose = ''}) =>
    pb.ContentPart(secretRequest: pb.SecretRequest(requestId: id, name: name, prose: prose));

/// A container in memory.
class _Store {
  final values = <String, String>{};
  final notSensitive = <String>{};
  final saved = <String>[];

  EnvStore get store => EnvStore(
        names: () => [
          for (final n in values.keys.toList()..sort())
            EnvNameView(name: n, changedAt: 1, sensitive: !notSensitive.contains(n)),
        ],
        get: (n) => values[n],
        set: (n, v, sensitive) {
          saved.add('$n ${sensitive ? 'sensitive' : 'plain'}');
          values[n] = v;
          sensitive ? notSensitive.remove(n) : notSensitive.add(n);
        },
        setSensitive: (n, s) {},
        delete: values.remove,
      );
}

ServiceInfoView _info({List<NetworkView> networks = const []}) => ServiceInfoView(
      prose: '',
      architecture: const [],
      filesystemBytes: BigInt.zero,
      entryPath: const [],
      configPath: const [],
      nodeProtocols: const [],
      environment: const [],
      slots: const [],
      networks: networks,
      workloads: const [],
      workloadsSkipped: 0,
      partsSkipped: 0,
      apiSkipped: false,
      chat: ChatSupportView.supported,
      truncated: false,
    );

NetworkView _net(String tag) => NetworkView(tags: [tag], prose: '', formal: '', protocolStack: const []);

final _instance = InstanceListView(
  instanceId: 'i1',
  peerId: 'aa' * 32,
  address: 'node.example:53460',
  serviceId: '65' * 32,
  slots: Uint16List.fromList([8080]),
  chatSlots: Uint16List.fromList([8080]),
  webSlots: Uint16List(0),
  startedAt: 1760000000,
  startChargeMu: '1000',
  refundMu: '',
  name: 'Agent',
  alias: '',
  title: '',
);

const _request = ChatSecretRequest(requestId: 'r1', name: 'API_KEY', prose: 'To call the model.');

/// A chat client with no network: one answer that asks for [_request].
class _SecretChat extends ChatClient {
  _SecretChat() : super(port: 0);

  final _messages = [
    const ChatMessage(seq: 1, role: 'user', text: 'start', id: 'm1'),
    const ChatMessage(seq: 2, role: 'assistant', text: 'I need a key.', id: 'm2', secretRequests: [_request]),
  ];

  /// What went to the service: the value, or `skip`.
  final answers = <String>[];
  ChatException? failWith;

  @override
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  @override
  int get count => _messages.length;
  @override
  bool get streaming => true;
  @override
  bool get awaitingAnswer => false;
  @override
  Future<void> sync() async {}
  @override
  Future<void> syncWhenStarted({Duration limit = const Duration(minutes: 2), Future<void> Function(Duration)? wait}) async {}

  @override
  Future<void> answerSecretRequest(ChatMessage message, ChatSecretRequest request, {String? value}) async {
    final failure = failWith;
    if (failure != null) throw failure;
    answers.add(value ?? 'skip');
  }
}

class _KeepAlive implements ConversationKeepAlive {
  @override
  Future<void> start() async {}
  @override
  Future<void> waiting(bool on) async {}
  @override
  Future<void> stop() async {}
}

class _Wallets implements FullWallets {
  @override
  Future<List<PayerWallet>> payers() async => const [];
  @override
  Future<bool> unlock(BuildContext context, PayerWallet wallet) async => true;
}

class _NoTimer implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
}

ChatDoneWatcher _idleWatcher() => ChatDoneWatcher(
      holds: ForegroundHolds(isAndroid: false),
      isMuted: (_) => false,
      timer: (d, f) => _NoTimer(),
      connect: (_) async => throw Exception('no tunnel in this test'),
    );

void main() {
  group('client', () {
    late FakeChatService svc;
    late TcpProxy proxy;
    late ChatClient chat;

    setUp(() async {
      svc = FakeChatService();
      proxy = TcpProxy(await svc.start());
      await proxy.start();
      chat = ChatClient(port: proxy.port, callTimeout: const Duration(seconds: 5));
    });

    tearDown(() async {
      await chat.close();
      await proxy.stop();
      await svc.stop();
    });

    test('a done answer of the service has its secret requests; other messages do not', () async {
      svc.user('go');
      svc.assistant('need it', extra: [secretPart('r1', 'API_KEY', prose: 'why')]);
      svc.assistant('open', status: pb.MessageStatus.MESSAGE_STATUS_IN_PROGRESS, extra: [secretPart('r2', 'B')]);
      svc.user('', extra: [secretPart('r3', 'C')]);
      svc.assistant('bad', extra: [secretPart('bad id!', 'D'), secretPart('r5', '1BAD')]);
      await chat.sync();
      final m = chat.messages;
      expect(m[1].secretRequests.single.requestId, 'r1');
      expect(m[1].secretRequests.single.name, 'API_KEY');
      expect(m[1].secretRequests.single.prose, 'why');
      expect(m[2].secretRequests, isEmpty);
      expect(m[3].secretRequests, isEmpty);
      expect(m[4].secretRequests, isEmpty);
    });

    test('a value and a skip go in AnswerSecretRequest, and not in a message', () async {
      svc.assistant('need it', extra: [secretPart('r1', 'A'), secretPart('r2', 'B')]);
      await chat.sync();
      final m = chat.messages.single;
      await chat.answerSecretRequest(m, m.secretRequests[0], value: 'sk-123');
      await chat.answerSecretRequest(m, m.secretRequests[1]);
      expect(svc.secretAnswers[0].messageId, m.id);
      expect(svc.secretAnswers[0].requestId, 'r1');
      expect(svc.secretAnswers[0].value, 'sk-123');
      expect(svc.secretAnswers[1].whichAnswer(), pb.AnswerSecretRequestRequest_Answer.skipped);
      expect(svc.secretAnswers[1].skipped, isTrue);
      await chat.sync();
      expect(chat.messages, hasLength(1));
      expect(svc.unarySends, isEmpty);
    });

    test('a value that the service cannot take is refused before the call', () async {
      svc.assistant('need it', extra: [secretPart('r1', 'A')]);
      await chat.sync();
      final m = chat.messages.single;
      for (final bad in ['', 'a\u0000b', 'x' * (ChatClient.maxSecretBytes + 1)]) {
        await expectLater(
          chat.answerSecretRequest(m, m.secretRequests.single, value: bad),
          throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.badRequest)),
        );
      }
      expect(svc.secretAnswers, isEmpty);
      await chat.answerSecretRequest(m, m.secretRequests.single, value: 'x' * ChatClient.maxSecretBytes);
      expect(svc.secretAnswers, hasLength(1));
    });

    test('an error of the service is a ChatException, with no value in it', () async {
      svc.assistant('need it', extra: [secretPart('r1', 'A')]);
      await chat.sync();
      final m = chat.messages.single;
      svc.secretErrors.add(chatError(StatusCode.notFound, 'not_found'));
      final error = await chat
          .answerSecretRequest(m, m.secretRequests.single, value: 'sk-secret')
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(error, isA<ChatException>());
      expect(error.toString(), isNot(contains('sk-secret')));
    });
  });

  group('questions', () {
    Future<List<EnvChoice>?> ask(
      WidgetTester tester,
      _Store store, {
      EnvQuestionsPurpose purpose = EnvQuestionsPurpose.launch,
      List<NetworkView> networks = const [],
      bool trusted = true,
    }) async {
      List<EnvChoice>? result;
      var done = false;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('go'),
            onPressed: () async {
              result = await Navigator.of(context).push<List<EnvChoice>>(MaterialPageRoute(
                builder: (_) => EnvQuestionsScreen(
                  declared: const [DeclaredVariableView(name: 'API_KEY', tags: [], prose: 'why')],
                  networks: networks,
                  nodes: [EnvTargetNode(peerId: 'p', address: 'n:1', trusted: trusted)],
                  purpose: purpose,
                  store: store.store,
                ),
              ));
              done = true;
            },
            child: const Text('go'),
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('go')));
      await tester.pumpAndSettle();
      expect(done, isFalse);
      return result;
    }

    testWidgets('a typed value with "Save" goes in the container, with its mark, on Run', (tester) async {
      final store = _Store();
      await ask(tester, store);
      await tester.tap(find.byKey(const Key('env-ask-type')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('env-typed')), 'sk-1');
      expect(find.text(appL10n.celautEnvAskSaveHint('API_KEY')), findsOneWidget);
      await tester.tap(find.byKey(const Key('env-typed-save')));
      await tester.tap(find.byKey(const Key('env-typed-sensitive')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-typed-use')));
      await tester.pumpAndSettle();
      // Not saved before the user confirms.
      expect(store.saved, isEmpty);
      await tester.tap(find.byKey(const Key('env-run')));
      await tester.pumpAndSettle();
      expect(store.saved, ['API_KEY sensitive']);
      expect(store.values['API_KEY'], 'sk-1');
    });

    testWidgets('without "Save" a typed value is not kept', (tester) async {
      final store = _Store()..values['API_KEY'] = 'old';
      await ask(tester, store);
      await tester.tap(find.byKey(const Key('env-ask-type')));
      await tester.pumpAndSettle();
      // A variable with the same name exists: the switch says that it replaces it.
      expect(find.text(appL10n.celautEnvAskSaveReplaces('API_KEY')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('env-typed')), 'new');
      await tester.tap(find.byKey(const Key('env-typed-use')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-run')));
      await tester.pumpAndSettle();
      expect(store.saved, isEmpty);
      expect(store.values['API_KEY'], 'old');
    });

    testWidgets('for the chat, the title and the buttons are about one secret', (tester) async {
      final store = _Store();
      await ask(tester, store, purpose: EnvQuestionsPurpose.chat);
      expect(find.text(appL10n.celautSecretAskTitle), findsOneWidget);
      await tester.tap(find.byKey(const Key('env-ask-skip')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.celautSecretSend), findsOneWidget);
      expect(find.text(appL10n.celautSecretReviewNote), findsOneWidget);
    });
  });

  group('chat screen', () {
    late _SecretChat chat;
    late _Store store;
    late SecretAnswers answers;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      chat = _SecretChat();
      store = _Store();
      answers = SecretAnswers('i1');
    });

    Future<void> open(
      WidgetTester tester, {
      List<NetworkView> networks = const [],
      bool trusted = true,
      bool unreadable = false,
    }) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(
          instance: _instance,
          port: 1,
          chat: chat,
          wallets: _Wallets(),
          keepAlive: _KeepAlive(),
          typewriter: false,
          watcher: _idleWatcher(),
          notes: ConversationNotes(),
          loadStatus: (_) async =>
              InstanceStatusView(instanceBalanceMu: '900', costSoFarMu: '100', streamsOpened: BigInt.one),
          inspect: (_, _) async => unreadable ? throw Exception('no node') : _info(networks: networks),
          trustedNodes: () => trusted ? {'aa' * 32} : const {},
          envStore: store.store,
          secretAnswers: answers,
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> pickApiKey(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('chat-secret-answer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-ask-pick')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-pick-API_KEY')));
      await tester.pumpAndSettle();
    }

    testWidgets('the card shows the name and the reason; a variable of the container is sent', (tester) async {
      store.values['API_KEY'] = 'sk-live';
      await open(tester);
      expect(find.text(appL10n.chatSecretCardTitle('API_KEY')), findsOneWidget);
      expect(find.text('To call the model.'), findsOneWidget);
      await pickApiKey(tester);
      // A trusted node and no networks: no warning, even for a sensitive value.
      expect(find.byKey(const Key('env-warning')), findsNothing);
      expect(find.byKey(const Key('env-warning-egress')), findsNothing);
      await tester.tap(find.byKey(const Key('env-run')));
      await tester.pumpAndSettle();
      expect(chat.answers, ['sk-live']);
      expect(find.byKey(const Key('chat-secret-sent')), findsOneWidget);
      expect(find.byKey(const Key('chat-secret-answer')), findsNothing);
      expect(find.textContaining('sk-live'), findsNothing);
      expect(answers.of('r1'), SecretAnswer.sent);
    });

    testWidgets('a skip is sent as a skip', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('chat-secret-answer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-ask-skip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-run')));
      await tester.pumpAndSettle();
      expect(chat.answers, ['skip']);
      expect(find.byKey(const Key('chat-secret-skipped')), findsOneWidget);
    });

    testWidgets('a node that is not fully trusted warns for a sensitive value', (tester) async {
      store.values['API_KEY'] = 'sk-live';
      await open(tester, trusted: false);
      await pickApiKey(tester);
      expect(find.byKey(const Key('env-warn-nodes')), findsOneWidget);
      expect(find.byKey(const Key('env-warn-egress')), findsNothing);
    });

    testWidgets('a service with a network on the node warns for a sensitive value', (tester) async {
      store.values['API_KEY'] = 'sk-live';
      await open(tester, networks: [_net('postgres')]);
      await pickApiKey(tester);
      expect(find.byKey(const Key('env-warn-networks')), findsOneWidget);
    });

    testWidgets('a value that is not sensitive gets no warning', (tester) async {
      store.values['API_KEY'] = 'plain';
      store.notSensitive.add('API_KEY');
      await open(tester, networks: [_net('*')], trusted: false);
      await pickApiKey(tester);
      expect(find.byKey(const Key('env-warning')), findsNothing);
      expect(find.byKey(const Key('env-warning-egress')), findsNothing);
    });

    testWidgets('egress is red and Deny sends nothing; an unreadable service counts as egress', (tester) async {
      store.values['API_KEY'] = 'sk-live';
      await open(tester, unreadable: true);
      await pickApiKey(tester);
      expect(find.byKey(const Key('env-warning-egress')), findsOneWidget);
      await tester.tap(find.byKey(const Key('env-deny')));
      await tester.pumpAndSettle();
      expect(chat.answers, isEmpty);
      expect(find.byKey(const Key('chat-secret-answer')), findsOneWidget);
      expect(answers.of('r1'), isNull);
    });

    testWidgets('a failed answer tells the user and the card stays open', (tester) async {
      store.values['API_KEY'] = 'sk-live';
      chat.failWith = const ChatException(ChatErrorKind.unreachable);
      await open(tester);
      await pickApiKey(tester);
      await tester.tap(find.byKey(const Key('env-run')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.chatSecretFailed), findsOneWidget);
      expect(find.byKey(const Key('chat-secret-answer')), findsOneWidget);
      expect(answers.of('r1'), isNull);
    });

    testWidgets('the answer is remembered when the conversation opens again', (tester) async {
      await answers.set('r1', SecretAnswer.skipped);
      final again = SecretAnswers('i1');
      await again.load();
      expect(again.of('r1'), SecretAnswer.skipped);
      expect(SecretAnswers('other').of('r1'), isNull);
    });
  });
}
