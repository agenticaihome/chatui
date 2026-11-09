/// Every text of the Celaut service screen (milestone M2), in one place.
class ServiceStrings {
  const ServiceStrings._();

  // Settings
  static const rowTitle = 'Celaut service';
  static const rowSubtitle = 'Quote, start, call and stop a service on free credit';

  // Screen
  static const screenTitle = 'Celaut service';
  static const intro =
      'Launch a service on the best node: the balancer asks the nodes for a quote and the '
      'app starts it on the best one that works. You can also ask for the quotes and choose '
      'a node yourself. Then call the service through a port on this device. The app uses '
      'its own client on each '
      'node: a new client gets free credit from the node, and a deposit adds to it. '
      'Starting and stopping need a full wallet. The node must already have the service.';
  static const nodesLabel = 'Node addresses';
  static const nodesHint = 'One host:port on each line. Empty: the nodes of the Nodes list';
  static const serviceLabel = 'Service id';
  static const serviceHint = '64 hexadecimal characters';
  static const initialLabel = 'Start balance in MU (optional)';
  static const initialHint = 'Empty: the default of the node, one hour of resources';
  static const initialDefault = '1000000';
  static const quote = 'Get quotes';
  static const launch = 'Launch on the best node';
  static const launching = 'Launching…';
  static const quoting = 'Asking the nodes…';

  // Input errors
  static const nodesEmpty =
      'Enter at least one node address as host:port, or add a node in the Nodes list.';
  static String nodeInvalid(String line) => 'This address is not valid: $line';
  static const serviceInvalid = 'The service id must be 64 hexadecimal characters.';
  static const initialInvalid = 'The start balance must be a whole number, more than 0.';

  // Quotes
  static const quotesTitle = 'Quotes, best first';
  static const noQuotes = 'No node gave a quote.';
  static const failuresTitle = 'Nodes without a quote';
  static String cost(String mu) => 'Start: $mu';
  static String maintenance(String mu, int seconds) => 'Then $mu every $seconds s';
  static String compared(String? nanoErg) => nanoErg == null
      ? 'No ERG rate: the price cannot be compared with other nodes.'
      : 'For the comparison: $nanoErg nanoERG';
  static const start = 'Start here';
  static const starting = 'Starting…';

  // Pick a skill (the catalog)
  static const pickSkill = 'Pick a skill';
  static const skillsTitle = 'Skills';
  static const skillsIntro =
      'The skills that publishers put on Ergo. Pick one: the app ranks the services that '
      'cover it by what they measured and by the reputation of who published them.';
  static const skillsLoading = 'Reading the catalog…';
  static const skillsEmpty = 'The catalog has no skills.';
  static const servicesLoading = 'Reading the services of this skill…';
  static const servicesEmpty = 'No service covers this skill yet.';
  static const servicesTitle = 'Services, best first';
  static const bestService = 'Best';
  static String serviceScore(String score) => 'Score $score';
  static const serviceDeclared = 'A publisher declared that it covers the skill';
  static const serviceFromResults = 'Only in the results of a benchmark of the skill';
  static const useService = 'Use this service';
  static const otherSkill = 'Other skills';
  static const retry = 'Try again';
  static const testDataNote =
      'Most results on Ergo today are tests. A high score is not a proof that the service works.';

  // Launch (the balancer picks the node)
  static String launched(String address, String cost) =>
      'Started on $address. The balancer chose this node. Start: $cost';
  static const skippedTitle = 'Better nodes that did not start it';
  static String skippedLine(String address, String reason) => '$address: $reason';
  static const launchNoQuotes = 'No node gave a quote, so nothing started.';
  static const launchAllFailed = 'Nodes gave quotes, but none of them started the service.';

  // Instance
  static const instanceTitle = 'Running instance';
  static String slot(int slot) => 'Port $slot of the service';
  static String localPort(int port) => 'Local port 127.0.0.1:$port';
  static const openPort = 'Open a local port';
  static const pathLabel = 'Path';
  static const call = 'Call GET';
  static const openChat = 'Open as a chat';
  static String answer(int status) => 'HTTP $status';
  static const refresh = 'Refresh the balance';
  static String clientBalance(String mu) => 'Balance of the client: $mu';
  static String instanceBalance(String mu) => 'Balance of the instance: $mu';
  static String costSoFar(String mu) => 'Cost so far: $mu';
  static String streams(BigInt n) => 'Tunnel streams opened: $n (one per TCP connection)';
  static const keepAliveNote =
      'The node charges each new TCP connection to the local port. '
      'This screen keeps one connection alive for all its calls.';
  static String tunnelError(String e) => 'Last tunnel error: $e';
  static const stop = 'Stop';
  static const stopping = 'Stopping…';
  static String stopped(String refund, String balance) =>
      'Stopped. Refund: $refund. Balance of the client: $balance.';

  // The instances of the app, also from an earlier run
  static const appInstancesTitle = 'Instances of the app';
  static String appInstance(String service, String node) => 'Service $service on $node';
  static String callFailed(String e) => 'The call failed: $e';
}
