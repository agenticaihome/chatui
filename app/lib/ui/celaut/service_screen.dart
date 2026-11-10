import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_catalog.dart';
import '../../bridge/api/celaut_home.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/host_port.dart';
import '../../celaut/launcher.dart';
import '../../celaut/payers.dart';
import '../../celaut/service_strings.dart';
import '../../celaut/tunnel_http.dart';
import '../../format.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../settings/settings_shared.dart';
import '../widgets/soft_card.dart';
import 'chat_screen.dart';
import 'client_unknown_dialog.dart';
import 'skill_picker.dart';

/// Debug screen of milestone M2: quote a service on several nodes, start it on one,
/// call it through a local port, and stop it, on the balance of the client of the app
/// on that node. Start and stop need a full wallet that is open (`docs/celaut/ui.md`):
/// without a full wallet they are off, with the same message as the deposit screen;
/// with only locked full wallets, they first ask the phone (fingerprint or screen lock) to open one.
class ServiceScreen extends StatefulWidget {
  const ServiceScreen({
    super.key,
    this.http,
    this.wallets = const AppFullWallets(),
    this.newClient,
    this.loadSkills,
    this.loadSkillServices,
  });

  /// The HTTP client of the local ports. Tests give their own.
  final TunnelHttp? http;

  /// The full wallets of the app. Tests give their own.
  final FullWallets wallets;

  /// Make a new client on a node that forgot the client id. Tests give their own.
  final Future<NewClientView> Function(NodeAddress node)? newClient;

  /// Read the skills of the catalog. Tests give their own.
  final Future<List<SkillView>> Function()? loadSkills;

  /// Read the ranked services of a skill. Tests give their own.
  final Future<List<SkillServiceView>> Function(String skillBoxId)? loadSkillServices;

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  final _nodesCtrl = TextEditingController();
  final _serviceCtrl = TextEditingController();
  // Empty: no balance is typed, and the node chooses it (issue #119).
  final _initialCtrl = TextEditingController();
  final _pathCtrl = TextEditingController(text: '/');
  late final TunnelHttp _http = widget.http ?? TunnelHttp();

  String? _nodesError;
  String? _serviceError;
  String? _initialError;
  bool _quoting = false;
  String? _startingPeer;
  bool _stopping = false;
  bool _calling = false;
  bool _launching = false;
  LaunchOutcome? _launched;
  LaunchFailure? _launchFailure;

  QuotesView? _quotes;
  String _serviceId = '';
  InstanceView? _instance;
  final _ports = <int, int>{};
  InstanceStatusView? _status;
  String? _answer;
  StopView? _stopped;
  CelautError? _error;
  FullWalletGate _gate = FullWalletGate.none;
  List<InstanceListView> _appInstances = const [];
  String? _stoppingId;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    final payers = await widget.wallets.payers();
    if (!mounted) return;
    setState(() {
      _gate = fullWalletGate(payers);
      _appInstances = _runningInstances();
    });
  }

  /// Start and stop need an open full wallet: ask to open one if they are all locked.
  Future<bool> _walletOpen() async {
    final open = await ensureOpenFullWallet(context, widget.wallets);
    await _loadWallets();
    return open;
  }

  /// The node forgot the client id: the user chooses a new client or a retry later.
  Future<void> _clientUnknown(NodeAddress node, CelautError e) async {
    await showClientUnknownChoice(
      context,
      node: node,
      error: e.message,
      newClient: widget.newClient,
    );
  }

  /// The instances of the app that this screen does not show above.
  List<InstanceListView> get _otherInstances => [
    for (final i in _appInstances)
      if (i.instanceId != _instance?.instanceId) i,
  ];

  Future<void> _stopOther(InstanceListView instance) async {
    if (!await _walletOpen() || !mounted) return;
    setState(() {
      _stoppingId = instance.instanceId;
      _error = null;
    });
    try {
      final stopped = await celautStopService(instanceId: instance.instanceId);
      if (mounted) setState(() => _stopped = stopped);
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _stoppingId = null;
          _appInstances = _runningInstances();
        });
      }
    }
  }

  @override
  void dispose() {
    _nodesCtrl.dispose();
    _serviceCtrl.dispose();
    _initialCtrl.dispose();
    _pathCtrl.dispose();
    _http.close();
    super.dispose();
  }

  /// Read and check the form. Without typed nodes, the nodes of the Nodes list are
  /// asked. Null if something is wrong: the errors are on the fields.
  ({List<NodeAddress> nodes, String service, String? initial})? _readForm() {
    final nodes = <NodeAddress>[];
    String? nodesError;
    for (final line in _nodesCtrl.text.split('\n')) {
      if (line.trim().isEmpty) continue;
      final parsed = parseHostPort(line);
      if (parsed.value == null) {
        nodesError = ServiceStrings.nodeInvalid(line.trim());
        break;
      }
      nodes.add(NodeAddress(host: parsed.value!.host, port: parsed.value!.port));
    }
    if (nodesError == null && nodes.isEmpty) {
      nodes.addAll(knownNodeAddresses(celautKnownNodes()));
    }
    if (nodesError == null && nodes.isEmpty) nodesError = ServiceStrings.nodesEmpty;
    final service = _serviceCtrl.text.trim().toLowerCase();
    final serviceError = RegExp(r'^[0-9a-f]{64}$').hasMatch(service)
        ? null
        : ServiceStrings.serviceInvalid;
    final initial = _initialCtrl.text.trim();
    final initialError = initial.isEmpty || RegExp(r'^0*[1-9][0-9]*$').hasMatch(initial)
        ? null
        : ServiceStrings.initialInvalid;
    setState(() {
      _nodesError = nodesError;
      _serviceError = serviceError;
      _initialError = initialError;
    });
    if (nodesError != null || serviceError != null || initialError != null) return null;
    return (nodes: nodes, service: service, initial: initial.isEmpty ? null : initial);
  }

  /// Start the service on the node that the balancer chooses, with no choice by the
  /// user (`docs/celaut/balancer.md`). A node that fails is skipped. The user decides
  /// what to do with a node that forgot the client id.
  /// Pick a skill of the catalog and one of its services (the best is chosen at first).
  /// The id of the service goes into the field. Then the user launches it.
  Future<void> _pickSkill() async {
    final serviceId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SkillPickerScreen(
          loadSkills: widget.loadSkills,
          loadServices: widget.loadSkillServices,
        ),
      ),
    );
    if (serviceId == null || !mounted) return;
    setState(() {
      _serviceCtrl.text = serviceId;
      _serviceError = null;
    });
  }

  Future<void> _launch() async {
    final form = _readForm();
    if (form == null) return;
    if (!await _walletOpen() || !mounted) return;
    setState(() {
      _launching = true;
      _error = null;
      _stopped = null;
      _launched = null;
      _launchFailure = null;
      _quotes = null;
    });
    try {
      final outcome = await launchService(
        serviceIdHex: form.service,
        balanceMu: form.initial,
        nodes: form.nodes,
      );
      if (!mounted) return;
      _applyStarted(outcome.instance);
      setState(() => _launched = outcome);
    } on LaunchFailure catch (failure) {
      if (mounted) setState(() => _launchFailure = failure);
      final forgot = failure.clientUnknown;
      if (mounted && forgot.isNotEmpty) {
        await _clientUnknown(forgot.first.quote.address, forgot.first.error);
      }
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  void _applyStarted(InstanceView instance) {
    setState(() {
      _instance = instance;
      _ports.clear();
      _status = null;
      _answer = null;
      _appInstances = _runningInstances();
    });
  }

  Future<void> _quote() async {
    final form = _readForm();
    if (form == null) return;
    final nodes = form.nodes;
    final service = form.service;

    setState(() {
      _quoting = true;
      _quotes = null;
      _error = null;
    });
    try {
      final quotes = await celautQuoteService(
        nodes: nodes,
        serviceIdHex: service,
      );
      if (!mounted) return;
      setState(() {
        _quotes = quotes;
        _serviceId = service;
      });
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  /// The `initial_mu` of a start from [quote] with the balance typed, or null when none
  /// is typed (the node chooses).
  String? _typedStartMu(QuoteView quote) {
    final typed = BigInt.tryParse(_initialCtrl.text.trim());
    return typed == null ? null : startMuFor(quote, null, balanceMu: typed)?.toString();
  }

  Future<void> _start(QuoteView quote) async {
    if (!await _walletOpen() || !mounted) return;
    setState(() {
      _startingPeer = quote.peerId;
      _error = null;
      _stopped = null;
    });
    try {
      final instance = await celautStartService(
        node: quote.address,
        serviceIdHex: _serviceId,
        // The cost of the quote (the builds) plus the balance typed; none typed: no
        // initial_mu, and the node adds its default balance (nodo#636).
        initialMu: _typedStartMu(quote),
        environment: const [],
      );
      if (!mounted) return;
      setState(() {
        _instance = instance;
        _ports.clear();
        _status = null;
        _answer = null;
        _appInstances = _runningInstances();
      });
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
      if (mounted && e.kind == CelautErrorKind.clientUnknown) {
        await _clientUnknown(quote.address, e);
      }
    } finally {
      if (mounted) setState(() => _startingPeer = null);
    }
  }

  Future<void> _openPort(int slot) async {
    final instance = _instance;
    if (instance == null) return;
    try {
      final port = await celautOpenTunnel(instanceId: instance.instanceId, slot: slot);
      if (mounted) setState(() => _ports[slot] = port);
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _call(int port) async {
    setState(() => _calling = true);
    try {
      final answer = await _http.get(port, _pathCtrl.text.trim());
      if (mounted) {
        setState(() => _answer = '${ServiceStrings.answer(answer.status)}\n${answer.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _answer = ServiceStrings.callFailed('$e'));
    } finally {
      if (mounted) setState(() => _calling = false);
    }
    await _refresh();
  }

  /// The conversation with the instance on [port] (`docs/celaut/chat.md`). It shares
  /// the kept-alive connection of this screen. The user can stop the instance there.
  /// The instance as the database has it, for the bar of the conversation.
  InstanceListView _listed(InstanceView instance) {
    for (final i in _appInstances) {
      if (i.instanceId == instance.instanceId) return i;
    }
    return InstanceListView(
      instanceId: instance.instanceId,
      peerId: instance.peerId,
      address: '',
      serviceId: _serviceCtrl.text.trim().toLowerCase(),
      slots: instance.slots,
      chatSlots: instance.chatSlots,
      cardsSlots: instance.cardsSlots,
      webSlots: instance.webSlots,
      startedAt: 0,
      startChargeMu: '',
      refundMu: '',
      name: '',
      alias: '',
      title: '',
    );
  }

  Future<void> _openChat(int port) async {
    final instance = _instance;
    if (instance == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          instance: _listed(instance),
          port: port,
          wallets: widget.wallets,
        ),
      ),
    );
    if (!mounted) return;
    final running = _runningInstances();
    final stopped = running.every((i) => i.instanceId != instance.instanceId);
    setState(() {
      _appInstances = running;
      if (stopped) {
        _instance = null;
        _ports.clear();
        _status = null;
        _answer = null;
      }
    });
    if (!stopped) await _refresh();
  }

  Future<void> _refresh() async {
    final instance = _instance;
    if (instance == null) return;
    try {
      final status = await celautInstanceStatus(instanceId: instance.instanceId);
      if (mounted) setState(() => _status = status);
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _stop() async {
    final instance = _instance;
    if (instance == null) return;
    if (!await _walletOpen() || !mounted) return;
    setState(() {
      _stopping = true;
      _error = null;
    });
    try {
      final stopped = await celautStopService(instanceId: instance.instanceId);
      // The local ports are closed: drop the kept-alive connection too.
      _http.close();
      if (!mounted) return;
      setState(() {
        _stopped = stopped;
        _launched = null;
        _instance = null;
        _ports.clear();
        _status = null;
        _answer = null;
        _appInstances = _runningInstances();
      });
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotes = _quotes;
    final instance = _instance;
    final stopped = _stopped;
    return SettingsPage(
      title: ServiceStrings.screenTitle,
      children: [
        const SettingsNote(ServiceStrings.intro),
        if (_gate == FullWalletGate.none) ...[
          SoftCard(
            child: Text(
              appL10n.celautNoFullWallet,
              key: const Key('service-no-full-wallet'),
              style: TextStyle(color: rustFor(context)),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_gate == FullWalletGate.locked) ...[
          SoftCard(
            child: Text(
              appL10n.celautOpenFullWalletNeeded,
              key: const Key('service-wallet-locked'),
              style: TextStyle(color: rustFor(context)),
            ),
          ),
          const SizedBox(height: 16),
        ],
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('service-nodes'),
                controller: _nodesCtrl,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 4,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: ServiceStrings.nodesLabel,
                  hintText: ServiceStrings.nodesHint,
                  errorText: _nodesError,
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('service-id'),
                controller: _serviceCtrl,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: ServiceStrings.serviceLabel,
                  hintText: ServiceStrings.serviceHint,
                  errorText: _serviceError,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('service-pick-skill'),
                  onPressed: _pickSkill,
                  child: const Text(ServiceStrings.pickSkill),
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                key: const Key('service-initial'),
                controller: _initialCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: ServiceStrings.initialLabel,
                  hintText: ServiceStrings.initialHint,
                  errorText: _initialError,
                  errorMaxLines: 2,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('service-launch'),
                onPressed: _launching || _quoting || _instance != null || _gate == FullWalletGate.none
                    ? null
                    : _launch,
                child: Text(_launching ? ServiceStrings.launching : ServiceStrings.launch),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('service-quote'),
                onPressed: _quoting ? null : _quote,
                child: Text(_quoting ? ServiceStrings.quoting : ServiceStrings.quote),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_error != null) _errorCard(context, _error!),
        if (stopped != null)
          SoftCard(
            child: Text(
              ServiceStrings.stopped(
                muOrUnknown(stopped.refundMu),
                muOrUnknown(stopped.clientBalanceMu),
              ),
              key: const Key('service-stopped'),
            ),
          ),
        if (_launchFailure != null) ..._launchFailureCard(context, _launchFailure!),
        if (_launched != null && instance != null) ..._launchedCard(context, _launched!),
        if (instance != null) ..._instanceCard(context, instance),
        if (_otherInstances.isNotEmpty) ..._appInstancesCards(context),
        if (quotes != null) ..._quotesCards(context, quotes),
      ],
    );
  }

  Widget _skippedLines(BuildContext context, List<LaunchSkip> skipped) {
    final muted = ArgusColors.of(context).muted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(ServiceStrings.skippedTitle, style: TextStyle(fontSize: 12.5, color: muted)),
        for (final s in skipped)
          Text(
            ServiceStrings.skippedLine(
              '${HostPort(s.quote.address.host, s.quote.address.port)}',
              CelautStrings.errorText(s.error.kind),
            ),
            style: TextStyle(fontSize: 12.5, color: muted),
          ),
      ],
    );
  }

  List<Widget> _launchedCard(BuildContext context, LaunchOutcome outcome) {
    final quote = outcome.quote;
    return [
      SoftCard(
        child: Column(
          key: const Key('service-launched'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ServiceStrings.launched(
                '${HostPort(quote.address.host, quote.address.port)}',
                muOrUnknown(quote.costMu),
              ),
            ),
            if (outcome.skipped.isNotEmpty) _skippedLines(context, outcome.skipped),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _launchFailureCard(BuildContext context, LaunchFailure failure) {
    final message = switch (failure.kind) {
      LaunchFailureKind.noNodes => ServiceStrings.nodesEmpty,
      LaunchFailureKind.noQuotes => ServiceStrings.launchNoQuotes,
      LaunchFailureKind.allFailed => ServiceStrings.launchAllFailed,
    };
    return [
      SoftCard(
        child: Column(
          key: const Key('service-launch-failed'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: TextStyle(color: rustFor(context))),
            if (failure.skipped.isNotEmpty) _skippedLines(context, failure.skipped),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _quotesCards(BuildContext context, QuotesView quotes) {
    final muted = ArgusColors.of(context).muted;
    return [
      const SizedBox(height: 24),
      SectionLabel(ServiceStrings.quotesTitle),
      const SizedBox(height: 10),
      if (quotes.quotes.isEmpty)
        SoftCard(
          child: Text(ServiceStrings.noQuotes, style: TextStyle(color: muted)),
        ),
      for (final q in quotes.quotes) ...[
        SoftCard(
          child: Column(
            key: Key('service-quote-${q.peerId}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                '${HostPort(q.address.host, q.address.port)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              SelectableText(q.peerId, style: TextStyle(fontSize: 12, color: muted)),
              const SizedBox(height: 6),
              Text(ServiceStrings.cost(muOrUnknown(q.costMu))),
              Text(
                ServiceStrings.maintenance(
                  muOrUnknown(q.maxMaintenanceMu),
                  q.maintenanceSecondsLoop,
                ),
              ),
              Text(
                ServiceStrings.compared(q.comparedNanoErg),
                style: TextStyle(fontSize: 12.5, color: muted),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: Key('service-start-${q.peerId}'),
                onPressed: _gate == FullWalletGate.none ||
                        _startingPeer != null ||
                        _instance != null
                    ? null
                    : () => _start(q),
                child: Text(
                  _startingPeer == q.peerId ? ServiceStrings.starting : ServiceStrings.start,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      if (quotes.failures.isNotEmpty) ...[
        const SizedBox(height: 14),
        SectionLabel(ServiceStrings.failuresTitle),
        const SizedBox(height: 10),
        for (final f in quotes.failures)
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${HostPort(f.address.host, f.address.port)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(CelautStrings.errorText(f.kind)),
                SelectableText(
                  CelautStrings.detailLabel(f.message),
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                if (f.kind == CelautErrorKind.clientUnknown)
                  TextButton(
                    key: Key('service-client-unknown-${f.address.host}:${f.address.port}'),
                    onPressed: () => _clientUnknown(
                      f.address,
                      CelautError(kind: f.kind, message: f.message),
                    ),
                    child: Text(appL10n.celautHomeClientUnknownAction),
                  ),
              ],
            ),
          ),
      ],
    ];
  }

  List<Widget> _instanceCard(BuildContext context, InstanceView instance) {
    final muted = ArgusColors.of(context).muted;
    final status = _status;
    return [
      SectionLabel(ServiceStrings.instanceTitle),
      const SizedBox(height: 10),
      SoftCard(
        child: Column(
          key: const Key('service-instance'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(instance.peerId, style: TextStyle(fontSize: 12, color: muted)),
            Text(ServiceStrings.clientBalance(muOrUnknown(instance.clientBalanceMu))),
            if (status != null) ...[
              Text(
                ServiceStrings.instanceBalance(muOrUnknown(status.instanceBalanceMu)),
                key: const Key('service-instance-balance'),
              ),
              Text(
                ServiceStrings.costSoFar(muOrUnknown(status.costSoFarMu)),
                key: const Key('service-cost-so-far'),
              ),
              Text(ServiceStrings.streams(status.streamsOpened), key: const Key('service-streams')),
              if (status.lastTunnelError != null)
                Text(
                  ServiceStrings.tunnelError(status.lastTunnelError!),
                  style: TextStyle(color: rustFor(context)),
                ),
            ],
            const SizedBox(height: 8),
            TextField(
              key: const Key('service-path'),
              controller: _pathCtrl,
              autocorrect: false,
              decoration: const InputDecoration(labelText: ServiceStrings.pathLabel),
            ),
            for (final slot in instance.slots) ...[
              const SizedBox(height: 10),
              Text(ServiceStrings.slot(slot), style: const TextStyle(fontWeight: FontWeight.w600)),
              if (_ports[slot] == null)
                OutlinedButton(
                  key: Key('service-open-$slot'),
                  onPressed: () => _openPort(slot),
                  child: const Text(ServiceStrings.openPort),
                )
              else ...[
                SelectableText(
                  ServiceStrings.localPort(_ports[slot]!),
                  key: Key('service-port-$slot'),
                ),
                OutlinedButton(
                  key: Key('service-call-$slot'),
                  onPressed: _calling ? null : () => _call(_ports[slot]!),
                  child: const Text(ServiceStrings.call),
                ),
                if (instance.chatSlots.contains(slot))
                  OutlinedButton(
                    key: Key('service-chat-$slot'),
                    onPressed: () => _openChat(_ports[slot]!),
                    child: const Text(ServiceStrings.openChat),
                  ),
              ],
            ],
            if (_answer != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                _answer!,
                key: const Key('service-answer'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 8),
            Text(ServiceStrings.keepAliveNote, style: TextStyle(fontSize: 12.5, color: muted)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('service-refresh'),
                    onPressed: _refresh,
                    child: const Text(ServiceStrings.refresh),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('service-stop'),
                    onPressed: _gate == FullWalletGate.none || _stopping ? null : _stop,
                    child: Text(_stopping ? ServiceStrings.stopping : ServiceStrings.stop),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _appInstancesCards(BuildContext context) {
    final muted = ArgusColors.of(context).muted;
    return [
      const SizedBox(height: 24),
      SectionLabel(ServiceStrings.appInstancesTitle),
      const SizedBox(height: 10),
      for (final i in _otherInstances)
        SoftCard(
          child: Column(
            key: Key('service-app-instance-${i.instanceId}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ServiceStrings.appInstance(shorten(i.serviceId, head: 8, tail: 6), i.address)),
              SelectableText(i.peerId, style: TextStyle(fontSize: 12, color: muted)),
              const SizedBox(height: 6),
              FilledButton(
                key: Key('service-app-stop-${i.instanceId}'),
                onPressed: _gate == FullWalletGate.none || _stoppingId != null
                    ? null
                    : () => _stopOther(i),
                child: Text(
                  _stoppingId == i.instanceId ? ServiceStrings.stopping : ServiceStrings.stop,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _errorCard(BuildContext context, CelautError e) {
    return SoftCard(
      child: Column(
        key: const Key('service-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CelautStrings.errorText(e.kind),
            style: TextStyle(fontSize: 14, color: rustFor(context)),
          ),
          if (e.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText(
              CelautStrings.detailLabel(e.message),
              style: TextStyle(fontSize: 12, color: ArgusColors.of(context).muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// The instances of the app that run: the database also keeps the stopped ones until
/// the user deletes them. A hibernated instance does not run, and its service does not
/// answer.
List<InstanceListView> _runningInstances() => [
  for (final i in celautInstances())
    if (i.stoppedAt == null && i.hibernatedAt == null) i,
];
