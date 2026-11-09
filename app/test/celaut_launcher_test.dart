import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_env.dart';
import 'package:argus_wallet/bridge/api/celaut_health.dart';
import 'package:argus_wallet/bridge/api/celaut_home.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/launch_problems.dart';
import 'package:argus_wallet/celaut/launcher.dart';
import 'package:argus_wallet/celaut/maintenance_price.dart';
import 'package:flutter_test/flutter_test.dart';

QuoteView _quote(String peer, int port, {String credit = '', String cost = '1000'}) => QuoteView(
  address: NodeAddress(host: 'node$port.example', port: port),
  peerId: peer,
  costMu: cost,
  initMaintenanceMu: '1',
  maxMaintenanceMu: '1',
  maintenanceSecondsLoop: 10,
  variance: 0,
  comparedNanoErg: '1',
  clientBalanceMu: credit,
);

NodeHealthView _health(
  int port, {
  NodeAvailability availability = NodeAvailability.unreachable,
  int failures = 2,
  CelautErrorKind? kind = CelautErrorKind.timeout,
  String? text = 'the node did not answer in time',
}) => NodeHealthView(
  peerId: 'peer$port',
  address: 'node$port.example:$port',
  availability: availability,
  failures: failures,
  errorKind: kind,
  error: text,
  checkedAt: 100,
  lastOkAt: 0,
  nextCheckAt: 200,
);

InstanceView _instance(String id) => InstanceView(
  instanceId: id,
  peerId: 'p',
  slots: Uint16List.fromList([8080]),
  chatSlots: Uint16List.fromList([8080]),
  webSlots: Uint16List(0),
  clientBalanceMu: '5',
);

const _service = 'ab';
const _error = CelautError(kind: CelautErrorKind.unreachable, message: 'down');
const _forgot = CelautError(kind: CelautErrorKind.clientUnknown, message: 'forgot');

void main() {
  late List<List<NodeAddress>> asked;
  late List<int> started;
  late QuotesView answer;
  late Map<int, CelautError> failures;
  late List<NodeHealthView> healthRecords;

  setUp(() {
    asked = [];
    started = [];
    failures = {};
    healthRecords = [];
    answer = QuotesView(quotes: [_quote('a', 1), _quote('b', 2), _quote('c', 3)], failures: const []);
  });

  Future<LaunchOutcome> launch({List<NodeAddress>? nodes, List<KnownNodeView> known = const []}) =>
      launchService(
        serviceIdHex: _service,
        initialMu: '7',
        nodes: nodes,
        knownNodes: () => known,
        health: () => healthRecords,
        quote: ({required nodes, required serviceIdHex, initialMu}) async {
          asked.add(nodes);
          expect(initialMu, '7');
          return answer;
        },
        start: ({required node, required serviceIdHex, initialMu, required environment}) async {
          started.add(node.port);
          // The quote of the node, which has the build in it, is the start balance.
          expect(initialMu, answer.quotes.firstWhere((q) => q.address.port == node.port).costMu);
          final failure = failures[node.port];
          if (failure != null) throw failure;
          return _instance('i${node.port}');
        },
      );

  test('the first quote starts, and the others are not tried', () async {
    final outcome = await launch(nodes: [const NodeAddress(host: 'x', port: 1)]);
    expect(started, [1]);
    expect(outcome.quote.peerId, 'a');
    expect(outcome.instance.instanceId, 'i1');
    expect(outcome.skipped, isEmpty);
  });

  test('a node that fails is skipped, in the order of the quotes', () async {
    failures = {1: _error, 2: _error};
    final outcome = await launch(nodes: [const NodeAddress(host: 'x', port: 1)]);
    expect(started, [1, 2, 3]);
    expect(outcome.quote.peerId, 'c');
    expect(outcome.skipped.map((s) => s.quote.peerId), ['a', 'b']);
    expect(outcome.skipped.first.error, _error);
  });

  test('when every node fails, the failure has each reason', () async {
    failures = {1: _error, 2: _forgot, 3: _error};
    await expectLater(
      launch(nodes: [const NodeAddress(host: 'x', port: 1)]),
      throwsA(
        isA<LaunchFailure>()
            .having((f) => f.kind, 'kind', LaunchFailureKind.allFailed)
            .having((f) => f.skipped, 'skipped', hasLength(3))
            .having((f) => f.clientUnknown.single.quote.peerId, 'forgot', 'b'),
      ),
    );
    expect(started, [1, 2, 3]);
  });

  test('no quote is no start', () async {
    answer = QuotesView(
      quotes: const [],
      failures: [
        QuoteFailureView(
          address: const NodeAddress(host: 'x', port: 1),
          kind: CelautErrorKind.timeout,
          message: 't',
        ),
      ],
    );
    await expectLater(
      launch(nodes: [const NodeAddress(host: 'x', port: 1)]),
      throwsA(
        isA<LaunchFailure>()
            .having((f) => f.kind, 'kind', LaunchFailureKind.noQuotes)
            .having((f) => f.quoteFailures, 'quoteFailures', hasLength(1)),
      ),
    );
    expect(started, isEmpty);
  });

  test('with no nodes, the known nodes are asked with their latest address', () async {
    await launch(
      known: [
        KnownNodeView(
          peerId: 'a',
          addresses: ['one.example:10', 'old.example:11'],
          depositedNanoErg: BigInt.zero,
        trusted: false, priority: 50, setPriority: 50,
        ),
        KnownNodeView(peerId: 'b', addresses: const [], depositedNanoErg: BigInt.zero, trusted: false, priority: 50, setPriority: 50),
        KnownNodeView(peerId: 'c', addresses: ['not an address'], depositedNanoErg: BigInt.zero, trusted: false, priority: 50, setPriority: 50),
        KnownNodeView(peerId: 'd', addresses: ['[::1]:12'], depositedNanoErg: BigInt.zero, trusted: false, priority: 50, setPriority: 50),
      ],
    );
    expect(asked.single.map((n) => '${n.host}:${n.port}'), ['one.example:10', '::1:12']);
  });

  test('typed nodes are used and the known nodes are not read', () async {
    final typed = [const NodeAddress(host: 'typed.example', port: 5)];
    await launch(nodes: typed);
    expect(asked.single, typed);
  });

  test('no typed and no known node is a failure, and nobody is asked', () async {
    await expectLater(
      launch(),
      throwsA(isA<LaunchFailure>().having((f) => f.kind, 'kind', LaunchFailureKind.noNodes)),
    );
    expect(asked, isEmpty);
  });

  group('credit pre-check', () {
    test('a node where the credit is less than the price is not asked to start', () async {
      answer = QuotesView(
        quotes: [_quote('a', 1, credit: '500', cost: '1000'), _quote('b', 2, credit: '5000', cost: '1000')],
        failures: const [],
      );
      final outcome = await launch(nodes: [const NodeAddress(host: 'x', port: 1)]);
      expect(started, [2], reason: 'the node with too little credit gets no call');
      expect(outcome.skipped.single.isCreditProblem, isTrue);
      expect(outcome.skipped.single.error.kind, CelautErrorKind.insufficientCredit);
      expect(outcome.skipped.single.quote.clientBalanceMu, '500');
    });

    test('an unknown balance, or one equal to the price, does not stop the start', () async {
      answer = QuotesView(
        quotes: [_quote('a', 1, credit: '', cost: '1000'), _quote('b', 2, credit: '1000', cost: '1000')],
        failures: const [],
      );
      final outcome = await launch(nodes: [const NodeAddress(host: 'x', port: 1)]);
      expect(started, [1]);
      expect(outcome.skipped, isEmpty);
    });

    test('when every node has too little credit the failure says it for each node', () async {
      answer = QuotesView(
        quotes: [_quote('a', 1, credit: '1', cost: '1000'), _quote('b', 2, credit: '2', cost: '900')],
        failures: const [],
      );
      await expectLater(
        launch(nodes: [const NodeAddress(host: 'x', port: 1)]),
        throwsA(
          isA<LaunchFailure>()
              .having((f) => f.kind, 'kind', LaunchFailureKind.allFailed)
              .having((f) => f.skipped.every((s) => s.isCreditProblem), 'credit', isTrue),
        ),
      );
      expect(started, isEmpty);
    });
  });

  group('node health', () {
    final nodes = [
      const NodeAddress(host: 'node1.example', port: 1),
      const NodeAddress(host: 'node2.example', port: 2),
    ];

    test('a node that failed two checks in a row is left out of the quotes', () async {
      healthRecords = [_health(1)];
      final outcome = await launch(nodes: nodes);
      expect(asked.single.map((n) => n.port), [2]);
      expect(outcome.leftOut.single.address, 'node1.example:1');
      expect(outcome.leftOut.single.kind, CelautErrorKind.timeout);
      expect(outcome.leftOut.single.message, 'the node did not answer in time');
    });

    test('one failed check, a slow node, or an available node is asked', () async {
      healthRecords = [
        _health(1, failures: 1),
        _health(2, availability: NodeAvailability.slow, failures: 0),
      ];
      final outcome = await launch(nodes: nodes);
      expect(asked.single.map((n) => n.port), [1, 2]);
      expect(outcome.leftOut, isEmpty);
    });

    test('if every node would be left out, all of them are asked', () async {
      healthRecords = [_health(1), _health(2)];
      final outcome = await launch(nodes: nodes);
      expect(asked.single.map((n) => n.port), [1, 2]);
      expect(outcome.leftOut, isEmpty);
    });

    test('the nodes that were left out are in the failure', () async {
      healthRecords = [_health(1)];
      answer = const QuotesView(quotes: [], failures: []);
      await expectLater(
        launch(nodes: nodes),
        throwsA(
          isA<LaunchFailure>()
              .having((f) => f.kind, 'kind', LaunchFailureKind.noQuotes)
              .having((f) => f.leftOut.single.address, 'left out', 'node1.example:1'),
        ),
      );
    });

    test('a node with no health record is asked', () async {
      healthRecords = [_health(9)];
      await launch(nodes: nodes);
      expect(asked.single, hasLength(2));
    });
  });

  group('problems of a failure', () {
    test('the action of each reason', () {
      const retry = [
        CelautErrorKind.nodeClosed,
        CelautErrorKind.noRoom,
        CelautErrorKind.rateLimited,
        CelautErrorKind.recursionLimit,
        CelautErrorKind.launchFailed,
        CelautErrorKind.unreachable,
        CelautErrorKind.timeout,
      ];
      const other = [
        CelautErrorKind.serviceMissing,
        CelautErrorKind.policyRefused,
        CelautErrorKind.unsupportedArchitecture,
        CelautErrorKind.identityMismatch,
      ];
      for (final k in retry) {
        expect(actionFor(k), ProblemAction.retryLater, reason: '$k');
      }
      for (final k in other) {
        expect(actionFor(k), ProblemAction.chooseOtherNode, reason: '$k');
      }
      expect(actionFor(CelautErrorKind.insufficientCredit), ProblemAction.addDeposit);
      expect(actionFor(CelautErrorKind.clientUnknown), ProblemAction.askClientChoice);
      expect(actionFor(CelautErrorKind.storage), ProblemAction.none);
    });

    test('a failure gives one problem for each node, with the numbers and the texts', () {
      final failure = LaunchFailure(
        LaunchFailureKind.allFailed,
        quoteFailures: [
          QuoteFailureView(
            address: const NodeAddress(host: 'q.example', port: 9),
            kind: CelautErrorKind.serviceMissing,
            message: 'This node does not have the service ab',
          ),
        ],
        skipped: [
          LaunchSkip(
            _quote('a', 1, credit: '10', cost: '1000'),
            const CelautError(kind: CelautErrorKind.insufficientCredit, message: 'credit 10 MU, price 1000 MU'),
          ),
          LaunchSkip(
            _quote('b', 2),
            const CelautError(kind: CelautErrorKind.nodeClosed, message: 'closed until 09:00'),
          ),
        ],
        leftOut: const [
          LeftOutNode(address: 'd.example:4', peerId: 'd', kind: CelautErrorKind.timeout, message: 'slow'),
          LeftOutNode(address: 'e.example:5', peerId: 'e'),
        ],
      );
      final problems = problemsOf(failure);
      expect(problems.map((p) => p.address), [
        'q.example:9',
        'node1.example:1',
        'node2.example:2',
        'd.example:4',
        'e.example:5',
      ]);
      expect(problems[0].action, ProblemAction.chooseOtherNode);
      expect(problems[0].message, 'This node does not have the service ab');
      expect(problems[1].action, ProblemAction.addDeposit);
      expect((problems[1].creditMu, problems[1].costMu), ('10', '1000'));
      expect(problems[1].message, isEmpty);
      expect(problems[2].action, ProblemAction.retryLater);
      expect(problems[2].message, 'closed until 09:00');
      expect(problems[3].leftOut, isTrue);
      expect(problems[4].kind, CelautErrorKind.unreachable, reason: 'no reason in the record');
    });
  });

  group('environment variables', () {
    final nodes = [const NodeAddress(host: 'x', port: 1)];

    Future<LaunchOutcome> withEnvironment(
      EnvironmentStep? environment,
      List<String> log, {
      List<List<EnvChoice>>? starts,
    }) => launchService(
      serviceIdHex: _service,
      nodes: nodes,
      environment: environment,
      knownNodes: () => const [],
      health: () => const [],
      quote: ({required nodes, required serviceIdHex, initialMu}) async {
        log.add('quote');
        return answer;
      },
      start: ({required node, required serviceIdHex, initialMu, required environment}) async {
        log.add('start ${node.port}');
        starts?.add(environment);
        if (node.port == 1) throw _error;
        return _instance('i${node.port}');
      },
    );

    test('the question comes after the quotes and before the first start', () async {
      final log = <String>[];
      final starts = <List<EnvChoice>>[];
      final outcome = await withEnvironment(
        (quotes) async {
          log.add('ask ${quotes.quotes.length}');
          return [const EnvChoice(name: 'API_KEY', container: 'MY_KEY')];
        },
        log,
        starts: starts,
      );
      expect(log, ['quote', 'ask 3', 'start 1', 'start 2']);
      expect(outcome.quote.peerId, 'b');
      // The same values go to each node that is asked to start; no quote has them.
      expect(starts.length, 2);
      for (final s in starts) {
        expect(s.single.name, 'API_KEY');
        expect(s.single.container, 'MY_KEY');
        expect(s.single.text, isNull);
      }
    });

    test('with no question a start gets no variable', () async {
      final log = <String>[];
      final starts = <List<EnvChoice>>[];
      await withEnvironment(null, log, starts: starts);
      expect(starts, everyElement(isEmpty));
    });

    test('an empty answer is a start with no variable', () async {
      final starts = <List<EnvChoice>>[];
      await withEnvironment((q) async => const [], [], starts: starts);
      expect(starts, everyElement(isEmpty));
    });

    test('a cancelled question starts nothing', () async {
      final log = <String>[];
      await expectLater(withEnvironment((q) async => null, log), throwsA(isA<LaunchCancelled>()));
      expect(log, ['quote']);
    });

    test('with no quote there is no question', () async {
      answer = const QuotesView(quotes: [], failures: []);
      var asked = false;
      await expectLater(
        withEnvironment((q) async {
          asked = true;
          return const [];
        }, []),
        throwsA(isA<LaunchFailure>()),
      );
      expect(asked, isFalse);
    });
  });

  group('the least time of a launch', () {
    QuoteView priced(int port, {required String init, required int loop, double variance = 0, String cost = '1000'}) =>
        QuoteView(
          address: NodeAddress(host: 'node$port.example', port: port),
          peerId: 'p$port',
          costMu: cost,
          initMaintenanceMu: init,
          maxMaintenanceMu: init,
          maintenanceSecondsLoop: loop,
          variance: variance,
          comparedNanoErg: '1',
          clientBalanceMu: '',
        );

    test('the balance is the periods of the time, plus one, with the margin of the node', () {
      // 10 minutes of 60-second periods at 1000 MU: 10 periods and the one at the end.
      expect(survivalBalanceMu(priced(1, init: '1000', loop: 60), const Duration(minutes: 10)), BigInt.from(11000));
      // A part of a period counts as a whole one.
      expect(survivalBalanceMu(priced(1, init: '1000', loop: 60), const Duration(seconds: 61)), BigInt.from(3000));
      // A variance of 0.5: 1500 MU a period.
      expect(
        survivalBalanceMu(priced(1, init: '1000', loop: 60, variance: 0.5), const Duration(minutes: 2)),
        BigInt.from(4500),
      );
      // No price per period: no balance.
      expect(survivalBalanceMu(priced(1, init: '', loop: 60), const Duration(minutes: 1)), isNull);
      expect(survivalBalanceMu(priced(1, init: '5', loop: 0), const Duration(minutes: 1)), isNull);
    });

    test('the time of a balance is the inverse', () {
      final q = priced(1, init: '1000', loop: 60);
      expect(survivalOf(q, BigInt.from(11000)), const Duration(minutes: 10));
      expect(survivalOf(q, BigInt.from(500)), Duration.zero);
      expect(startCostWith(priced(1, init: '1', loop: 1, cost: '1000300'), BigInt.from(1000000), BigInt.from(5000)),
          BigInt.from(5300));
    });

    test('the nodes are asked again with the balance for the most expensive one', () async {
      final initials = <String?>[];
      final outcome = await launchService(
        serviceIdHex: _service,
        initialMu: '1000000',
        minSurvival: const Duration(minutes: 10),
        nodes: const [NodeAddress(host: 'node1.example', port: 1), NodeAddress(host: 'node2.example', port: 2)],
        health: () => const [],
        quote: ({required nodes, required serviceIdHex, initialMu}) async {
          initials.add(initialMu);
          return QuotesView(
            quotes: [
              priced(1, init: '1000', loop: 60, cost: '${300 + int.parse(initialMu!)}'),
              priced(2, init: '2000', loop: 60, cost: '${400 + int.parse(initialMu)}'),
            ],
            failures: const [],
          );
        },
        start: ({required node, required serviceIdHex, initialMu, required environment}) async {
          started.add(node.port);
          // The start pays the quote of the second round: build plus the balance.
          expect(initialMu, '22300');
          return _instance('i');
        },
      );
      // The first round prices the time; the second asks with 11 periods of 2000 MU.
      expect(initials, ['1000000', '22000']);
      expect(outcome.quote.address.port, 1);
      expect(started, [1]);
    });

    test('without a time, the nodes are asked once, as before', () async {
      final initials = <String?>[];
      await launchService(
        serviceIdHex: _service,
        initialMu: '1000000',
        nodes: const [NodeAddress(host: 'node1.example', port: 1)],
        health: () => const [],
        quote: ({required nodes, required serviceIdHex, initialMu}) async {
          initials.add(initialMu);
          return QuotesView(quotes: [priced(1, init: '1000', loop: 60)], failures: const []);
        },
        start: ({required node, required serviceIdHex, initialMu, required environment}) async => _instance('i'),
      );
      expect(initials, ['1000000']);
    });
  });
  group('keep running', () {
    QuoteView priced({String init = '1000', int loop = 60, double variance = 0.25}) => QuoteView(
          address: const NodeAddress(host: 'node1.example', port: 1),
          peerId: 'p1',
          costMu: '5000',
          initMaintenanceMu: init,
          maxMaintenanceMu: init,
          maintenanceSecondsLoop: loop,
          variance: variance,
          comparedNanoErg: '1',
          clientBalanceMu: '',
        );

    Future<LaunchOutcome> launch({
      required QuoteView quote,
      required List<String> calls,
      bool keepAlive = false,
      String? budgetMu,
      bool failing = false,
    }) =>
        launchService(
          serviceIdHex: _service,
          keepAlive: keepAlive,
          budgetMu: budgetMu,
          nodes: const [NodeAddress(host: 'node1.example', port: 1)],
          health: () => const [],
          quote: ({required nodes, required serviceIdHex, initialMu}) async =>
              QuotesView(quotes: [quote], failures: const []),
          start: ({required node, required serviceIdHex, initialMu, required environment}) async => _instance('i'),
          setPricing: ({required instanceId, required maintenanceMu, required maintenanceSeconds, required variance}) {
            calls.add('price $instanceId $maintenanceMu $maintenanceSeconds $variance');
            if (failing) throw StateError('no core');
          },
          setKeepAlive: ({required instanceId, required enabled, budgetMu}) {
            calls.add('keep $instanceId $enabled $budgetMu');
          },
        );

    test('the price of the node is kept with the instance, and keep-alive stays off', () async {
      final calls = <String>[];
      await launch(quote: priced(), calls: calls);
      expect(calls, ['price i 1000 60 0.25']);
    });

    test('keep-alive turns on after the start, with its limit', () async {
      final calls = <String>[];
      await launch(quote: priced(), calls: calls, keepAlive: true, budgetMu: '90000');
      expect(calls, ['price i 1000 60 0.25', 'keep i true 90000']);
      calls.clear();
      await launch(quote: priced(), calls: calls, keepAlive: true);
      expect(calls.last, 'keep i true null');
    });

    test('a failure to keep the plan does not fail a launch that worked', () async {
      final calls = <String>[];
      final outcome = await launch(quote: priced(), calls: calls, failing: true, keepAlive: true);
      expect(outcome.instance.instanceId, 'i');
    });

    test('a quote with no price keeps no price, but still turns keep-alive on', () async {
      final calls = <String>[];
      await launch(quote: priced(init: '0'), calls: calls, keepAlive: true);
      expect(calls, ['keep i true null']);
    });
  });

  group('the price of keeping an instance', () {
    test('turns time into MU and back', () {
      final p = MaintenancePrice.of(perPeriodMu: '1000', periodSeconds: 60, variance: 0.5)!;
      // 1500 MU with the margin each minute.
      expect(p.addFor(const Duration(minutes: 10)), BigInt.from(15000));
      // A start balance has one more period, for the one that runs at the end.
      expect(p.balanceFor(const Duration(minutes: 10)), BigInt.from(16500));
      // A part of a period is a whole one.
      expect(p.addFor(const Duration(seconds: 61)), BigInt.from(3000));
      expect(p.lasts(BigInt.from(16500)), const Duration(minutes: 10));
      expect(p.lasts(BigInt.from(1500)), Duration.zero);
      expect(p.lasts(BigInt.zero), Duration.zero);
    });

    test('gives nothing for a missing or wrong price', () {
      expect(MaintenancePrice.of(perPeriodMu: '', periodSeconds: 60, variance: 0), isNull);
      expect(MaintenancePrice.of(perPeriodMu: '0', periodSeconds: 60, variance: 0), isNull);
      expect(MaintenancePrice.of(perPeriodMu: '5', periodSeconds: 0, variance: 0), isNull);
    });
  });
}
