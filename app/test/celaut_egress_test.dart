import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/bridge/api/celaut_service_info.dart';
import 'package:argus_wallet/celaut/egress.dart';
import 'package:flutter_test/flutter_test.dart';

NetworkView _net(List<String> tags, [String formal = '']) =>
    NetworkView(tags: tags, prose: '', formal: formal, protocolStack: const []);

QuoteView _quote(String peer, {String credit = '', String cost = '10'}) => QuoteView(
  address: NodeAddress(host: '$peer.example', port: 1),
  peerId: peer,
  costMu: cost,
  initMaintenanceMu: '1',
  maxMaintenanceMu: '1',
  maintenanceSecondsLoop: 10,
  variance: 0,
  comparedNanoErg: '1',
  clientBalanceMu: credit,
);

void main() {
  group('a tag that leaves the node, as nodo decides', () {
    test('every address, a chain and a host name leave the node', () {
      expect(tagLeavesNode('*'), isTrue);
      expect(tagLeavesNode('pow:ergo'), isTrue);
      expect(tagLeavesNode('api.example.com'), isTrue);
    });

    test('a group of the instances of the node stays on it', () {
      expect(tagLeavesNode('postgres'), isFalse);
      expect(tagLeavesNode('ipv4'), isFalse);
      // nodo needs a lower-case letter: an upper-case name or an address literal is a group.
      expect(tagLeavesNode('API.Example.com'), isFalse);
      expect(tagLeavesNode('10.0.0.1'), isFalse);
    });
  });

  group('egressOf', () {
    test('no network: nothing leaves and nothing is shared', () {
      final r = egressOf(const []);
      expect(r.egress, isFalse);
      expect(r.exposed, isFalse);
    });

    test('the exits and the groups, each once, in order', () {
      final r = egressOf([
        _net(['*']),
        _net(['api.example.com', 'api']),
        _net(['pow:ergo']),
        _net(['api.example.com']),
        _net(['postgres', 'db']),
        _net(['postgres']),
      ]);
      expect(r.anyAddress, isTrue);
      expect(r.hosts, ['api.example.com', 'pow:ergo']);
      expect(r.local, ['postgres']);
      expect(r.egress, isTrue);
    });

    test('a network with a host name among its tags counts as an exit, not as a group', () {
      final r = egressOf([_net(['db', 'db.example.org'])]);
      expect(r.hosts, ['db.example.org']);
      expect(r.local, isEmpty);
    });

    test('a variable that a network takes by name steers that network', () {
      final r = egressOf([_net(['api.example.com'], 'host=\${API_HOST}\nport=443')]);
      expect(r.steered, {
        'API_HOST': ['api.example.com'],
      });
    });
  });

  group('the nodes that can read the values', () {
    test('a node where the credit is less than the price is never asked', () {
      final nodes = envTargetNodes([
        _quote('aa', credit: '5', cost: '10'),
        _quote('bb', credit: '10', cost: '10'),
        _quote('cc'),
      ], {'cc'});
      expect(nodes.map((n) => (n.address, n.trusted)), [('bb.example:1', false), ('cc.example:1', true)]);
    });
  });

  group('EnvWarnings', () {
    final report = egressOf([_net(['*']), _net(['postgres'])]);
    const untrusted = EnvTargetNode(peerId: 'aa', address: 'a:1', trusted: false);
    const trusted = EnvTargetNode(peerId: 'bb', address: 'b:1', trusted: true);

    test('with no sensitive value there is no warning at all', () {
      final w = EnvWarnings.of(sensitive: false, report: report, nodes: [untrusted]);
      expect(w.any, isFalse);
      expect(w.egress, isFalse);
      expect(w.untrusted, isEmpty);
    });

    test('a sensitive value: the exits, the groups and the untrusted nodes', () {
      final w = EnvWarnings.of(sensitive: true, report: report, nodes: [trusted, untrusted]);
      expect(w.egress, isTrue);
      expect(w.anyAddress, isTrue);
      expect(w.local, ['postgres']);
      expect(w.untrusted.map((n) => n.address), ['a:1']);
    });

    test('a trusted node and no network: nothing to warn of', () {
      final w = EnvWarnings.of(sensitive: true, report: egressOf(const []), nodes: [trusted]);
      expect(w.any, isFalse);
    });
  });
}
