import 'dart:async';

import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_catalog.dart';
import '../../bridge/api/celaut_env.dart';
import '../../bridge/api/celaut_service_info.dart';
import '../../bridge/api/celaut_home.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/background_work.dart';
import '../../celaut/catalog_types.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/conversation_keep_alive.dart';
import '../../celaut/egress.dart';
import '../../celaut/incoming_package.dart';
import '../../celaut/env_store.dart';
import '../../celaut/launcher.dart';
import '../../bridge/api/celaut_package.dart';
import '../../celaut/package_channel.dart';
import '../../celaut/package_library.dart';
import '../../celaut/payers.dart';
import '../../celaut/service_presets.dart';
import '../../celaut/service_transfer.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';
import '../scan_screen.dart';
import 'chat_screen.dart';
import 'client_unknown_dialog.dart';
import 'deposit_screen.dart';
import 'env_questions_screen.dart';
import 'instance_list.dart' show instanceOfLaunch;
import 'launch_failure_sheet.dart';
import 'import_rocket.dart';
import 'import_sheet.dart';
import 'launch_rocket.dart';
import 'run_confirm_dialog.dart';
import 'service_info_screen.dart';
import 'service_transfer_dialog.dart';
import 'objective_detail_screen.dart';
import 'objective_store.dart';
import 'objective_type_missing.dart';

/// Start a service: the ids and the settings go to the launcher.
typedef LaunchCall = Future<LaunchOutcome> Function({
  required String serviceIdHex,
  Duration? minSurvival,
  bool keepAlive,
  String? budgetMu,
  EnvironmentStep? environment,
});

/// What the picker calls after a start, instead of opening the conversation itself:
/// the outcome, the service id, and the name that the user saw.
typedef StartedCall = Future<void> Function(
  LaunchOutcome outcome,
  String serviceId,
  String? name,
);

/// "Run a service" (`docs/celaut/ui.md`, section 2): the objectives of the catalog as a store.
/// At the top, at all times: the search and two small actions for the service files on this
/// phone (import one, run the saved ones). Under them the store home (the featured objective,
/// the shelves by field and "Top objectives"; see `objective_store.dart`), or the objectives that match
/// the search. An objective opens its page with its ranked services ([ObjectiveDetailScreen]); the
/// Run pill of a row runs its recommended service. Run starts
/// the best node by the balancer (`launchService`) after the user confirms it, with the
/// best node and its start cost. If the service has a chat slot, the
/// conversation opens; if not, the instance shows in the list of the home screen.
/// If no node starts it, a sheet says why for each node.
class RunServiceSection extends StatefulWidget {
  const RunServiceSection({
    super.key,
    this.wallets = const AppFullWallets(),
    this.onChanged,
    this.newClient,
    this.loadObjectives,
    this.types,
    this.loadServices,
    this.previewQuote,
    this.launch,
    this.openTunnel,
    this.chatBuilder,
    this.openDeposit,
    this.transfer,
    this.packages,
    this.library,
    this.importFile,
    this.incoming,
    this.showTitle = true,
    this.onStarted,
    this.nameInstance,
    this.inspect,
    this.envStore,
    this.trustedNodes,
    this.work,
    this.scan,
    this.preset,
    this.presets,
    this.onPresetDone,
  });

  /// A preset of the wheel of the pencil button (`docs/celaut/presets.md`): the section
  /// shows nothing and starts it at once, by the same steps as Run on an objective (the
  /// confirmation with the cost, the wallet, the questions about the variables, filled from
  /// the preset). [onPresetDone] is called when the launch ends without a start (cancelled
  /// or failed); after a start, [onStarted] is.
  final ServicePreset? preset;

  /// The presets, where a start keeps the variables that it used. Tests give their own.
  final ServicePresets? presets;

  /// The launch of [preset] ended without a start.
  final VoidCallback? onPresetDone;

  /// Read a QR code for the import from a link. Tests give their own.
  final Future<String?> Function(BuildContext context)? scan;

  /// The launch, the transfer and the import run as background work. Tests give their own.
  final BackgroundWork? work;

  /// What a service says about itself (`docs/celaut/service-info.md`): from the file in the
  /// library, or from the node of the best quote. The launch reads it once, for the check of
  /// the interface and for the environment variables. Tests give their own.
  final ServiceInfoLoader? inspect;

  /// The container of environment variables. Tests give their own.
  final EnvStore? envStore;

  /// The peer ids (lower case) of the nodes that the user marked as fully trusted. The
  /// questions about the variables warn of the others. Tests give their own.
  final Set<String> Function()? trustedNodes;

  /// What to do after a start. The list of conversations gives it: it goes back to the
  /// list and opens the conversation (`docs/celaut/ui-chat-first.md`). Without it the
  /// section opens the conversation on top of itself.
  final StartedCall? onStarted;

  /// Keep the name of a started instance in the database. Tests give their own.
  final void Function(String instanceId, String name)? nameInstance;

  /// Show the title of the section. Off on its own screen, where the app bar has it.
  final bool showTitle;

  /// The full wallets: Run needs one that is open. Tests give their own.
  final FullWallets wallets;

  /// Called when an instance started, so that the home screen loads its data again.
  final VoidCallback? onChanged;

  /// Make a new client on a node that forgot the client id. Tests give their own.
  final Future<NewClientView> Function(NodeAddress node)? newClient;

  /// The objectives of the catalog. Tests give their own.
  final Future<List<ObjectiveView>> Function()? loadObjectives;

  /// The type ids of the registry (Settings). Tests give their own.
  final CatalogTypes? types;

  /// The ranked services of an objective. Tests give their own.
  final Future<List<ObjectiveServiceView>> Function(String objectiveBoxId)? loadServices;

  /// The best quote of a service on the nodes of the list. Tests give their own.
  final Future<QuoteView?> Function(String serviceId)? previewQuote;

  /// Start the service. Tests give their own.
  final LaunchCall? launch;

  /// A local port for a slot of an instance. Tests give their own.
  final Future<int> Function(String instanceId, int slot)? openTunnel;

  /// The conversation screen. Tests give their own.
  final Widget Function(String instanceId, int port)? chatBuilder;

  /// Open the deposit screen. Tests give their own.
  final VoidCallback? openDeposit;

  /// The transfer of a service to a node that does not have it. Tests give their own.
  final ServiceTransfer? transfer;

  /// The file picker and the metered check of Android. Tests give their own.
  final PackageChannel? packages;

  /// The service files that the user loaded into the app. Tests give their own.
  final PackageLibrary? library;

  /// A file that the user opened in a file manager: its import starts at once.
  final ChosenFile? importFile;

  /// The files that the user opens in a file manager; an import marks it busy, so that the
  /// next file waits. Tests give their own.
  final IncomingPackages? incoming;

  @override
  State<RunServiceSection> createState() => _RunServiceSectionState();
}

class _RunServiceSectionState extends State<RunServiceSection> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<ObjectiveView>? _objectives;
  late final CatalogTypes _types = widget.types ?? catalogTypes;

  /// The app has no type id of an objective yet: the store says so (Settings).
  bool get _typeMissing => widget.loadObjectives == null && !_types.hasObjective;

  /// The whole of "Top objectives" is shown, not only its first [storeShortList] rows.
  bool _showAll = false;

  /// The box id of the objective whose Run pill reads its services now.
  String? _quick;
  bool _loading = true;
  bool _failed = false;
  bool _running = false;

  /// The name of the last service that the user confirmed: the launch again after a
  /// transfer has no confirmation, and keeps it.
  String? _lastName;

  /// The least time that the user asked for in that confirmation; null for the default
  /// start balance.
  Duration? _lastSurvival;
  bool _lastKeepAlive = false;
  String? _lastBudget;
  List<LibraryPackageView> _packages = const [];
  late final PackageLibrary _library = widget.library ?? PackageLibrary();

  /// The variables of the last launch, as a preset keeps them; null until the questions
  /// (or their absence) are known.
  List<PresetVariable>? _lastEnv;

  @override
  void initState() {
    super.initState();
    _readPackages();
    final preset = widget.preset;
    if (preset != null) {
      // Only the launch: the catalog is not read.
      _loading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_runPreset(preset));
      });
      return;
    }
    _read();
    final file = widget.importFile;
    if (file != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_importAndTell(() async => file));
      });
    }
  }

  void _readPackages() {
    try {
      _packages = _library.list();
    } catch (_) {
      // The library is not there (no database yet): the section shows no service.
      _packages = const [];
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    if (_typeMissing) {
      setState(() {
        _objectives = null;
        _loading = false;
        _failed = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final objectives = await (widget.loadObjectives ?? () => celautObjectives(types: _types.ids))();
      if (mounted) setState(() => _objectives = objectives);
    } catch (_) {
      // Any failure, also one that is not a Celaut error: the section shows the retry.
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<ObjectiveServiceView>> _services(String objectiveBoxId) =>
      (widget.loadServices ?? (id) => celautObjectiveServices(types: _types.ids, objectiveBoxId: id))(objectiveBoxId);

  Future<QuoteView?> _preview(String serviceId) async {
    final custom = widget.previewQuote;
    if (custom != null) return custom(serviceId);
    final nodes = knownNodeAddresses(celautKnownNodes());
    if (nodes.isEmpty) return null;
    // No initial_mu: the cost of a quote is the builds (nodo#636), and the start adds
    // the balance (issue #119).
    final quotes = await celautQuoteService(nodes: nodes, serviceIdHex: serviceId);
    return quotes.quotes.isEmpty ? null : quotes.quotes.first;
  }

  /// The page of [objective]; Run there runs the service that it returns. [heroTag] is the tag
  /// of the mark of the card that the user tapped, which flies to the page.
  Future<void> _open(ObjectiveView objective, {Object? heroTag, int? rank}) async {
    final serviceId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ObjectiveDetailScreen(
          objective: objective,
          loadServices: _services,
          previewQuote: _preview,
          wallets: widget.wallets,
          heroTag: heroTag,
          rank: rank,
        ),
      ),
    );
    if (serviceId != null && mounted) await _run(serviceId, name: objective.name);
  }

  /// The Run pill of an objective, as "Get" in a store: its recommended service (the first of
  /// the ranking) goes to the usual confirmation. If the services cannot be read, or the
  /// objective has none, its page opens and says why.
  Future<void> _quickRun(ObjectiveView objective, {Object? heroTag, int? rank}) async {
    setState(() => _quick = objective.boxId);
    List<ObjectiveServiceView>? services;
    try {
      services = await _services(objective.boxId);
    } catch (_) {
      services = null;
    }
    if (!mounted) return;
    setState(() => _quick = null);
    if (services == null || services.isEmpty) {
      await _open(objective, heroTag: heroTag, rank: rank);
      return;
    }
    await _run(services.first.serviceId, name: objective.name);
  }

  /// Ask before a launch: an instance uses credit until it stops. The dialog shows the
  /// node that the balancer would use now, with its start cost, and asks for the least
  /// time that the instance must run ([showRunConfirmation]).
  Future<RunChoice?> _confirm(String serviceId, String name) => showRunConfirmation(
        context,
        name: name,
        quote: _preview(serviceId),
        onDetails: (best) {
          if (mounted) _details(serviceId, node: best?.address, name: name);
        },
      );

  /// Start a preset by the steps of Run: the confirmation with the cost is never skipped.
  Future<void> _runPreset(ServicePreset preset) async {
    await _run(preset.serviceId, name: preset.name);
    // After a start, the list has closed this page already.
    if (mounted) widget.onPresetDone?.call();
  }

  /// Launch [serviceId]. [name] is what the confirmation calls it; with no name the user
  /// has already confirmed (the launch again after a transfer).
  Future<void> _run(String serviceId, {String? name}) async {
    if (name != null) {
      _lastEnv = null;
      final choice = await _confirm(serviceId, name);
      if (choice == null || !mounted) return;
      _lastName = name;
      _lastSurvival = choice.minSurvival;
      _lastKeepAlive = choice.keepAlive;
      _lastBudget = choice.budgetMu;
    }
    if (!await ensureOpenFullWallet(context, widget.wallets) || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.celautOpenFullWalletNeeded)),
        );
      }
      return;
    }
    setState(() => _running = true);
    _showRocket(serviceId);
    try {
      final launch = widget.launch ??
          ({required serviceIdHex, minSurvival, keepAlive = false, budgetMu, environment}) => launchService(
                serviceIdHex: serviceIdHex,
                minSurvival: minSurvival,
                keepAlive: keepAlive,
                budgetMu: budgetMu,
                environment: environment,
              );
      // The launch goes on with the screen off or the app in the background, and the
      // auto-lock does not close this page meanwhile (`BackgroundWork`).
      final outcome = await (widget.work ?? backgroundWork).run(context, KeepAliveReason.launch, () async {
        final outcome = await launch(
          serviceIdHex: serviceId,
          minSurvival: _lastSurvival,
          keepAlive: _lastKeepAlive,
          budgetMu: _lastBudget,
          environment: (quotes) => _inspectBeforeRun(serviceId, quotes),
        );
        // The rocket lifts off before the next screen.
        await _rocket?.liftOff();
        _rocket = null;
        return outcome;
      });
      if (!mounted) return;
      // The progress stops before the next screen or sheet, which can stay open.
      setState(() => _running = false);
      await _started(outcome, serviceId);
    } on LaunchCancelled {
      // The user cancelled in the question about the variables: nothing to show.
    } on LaunchFailure catch (failure) {
      _hideRocket();
      if (!mounted) return;
      setState(() => _running = false);
      await _showFailure(failure, serviceId);
    } on CelautError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(CelautStrings.errorText(e.kind))),
        );
      }
    } finally {
      _hideRocket();
      if (mounted) setState(() => _running = false);
    }
  }

  /// What the app asks before it starts the service, after the quotes (a quote is free) and
  /// before the first start:
  ///
  /// 1. If the interface of the service is not the chat convention of Chatui
  ///    (`docs/celaut/chat.md`), an alert says so, and the user can run it anyway or cancel.
  /// 2. The environment variables that the service declares, one at a time
  ///    (`docs/celaut/env-variables.md`).
  ///
  /// The service is read once, as a stream, so its filesystem is never in memory. If the app
  /// cannot read it (an error, or a service too large to read from a node), the user chooses:
  /// run it anyway, or cancel. Null cancels the launch.
  Future<List<EnvChoice>?> _inspectBeforeRun(String serviceId, QuotesView quotes) async {
    // The rocket stays while the app reads the service: that takes a while, and the user
    // must see that something goes on. A question hides it (the rocket is not over a
    // question), and it comes back for the start.
    if (mounted) _showRocket(serviceId, LaunchStep.readingService);
    final answer = await _askBeforeRun(serviceId, quotes);
    if (answer != null && mounted) _showRocket(serviceId, LaunchStep.starting);
    return answer;
  }

  /// The rocket of the launch, while the app asks the nodes or starts the service.
  LaunchRocket? _rocket;

  /// Show the rocket at [step]. If it shows already, it only goes to that step (it does
  /// not start again).
  void _showRocket(String serviceId, [LaunchStep step = LaunchStep.askingNodes]) {
    final shown = _rocket;
    if (shown != null && shown.isActive) {
      shown.step.value = step;
      return;
    }
    _rocket = LaunchRocket.show(context, name: _lastName ?? serviceId.substring(0, 8), step: step);
  }

  void _hideRocket() {
    _rocket?.dismiss();
    _rocket = null;
  }

  Future<List<EnvChoice>?> _askBeforeRun(String serviceId, QuotesView quotes) async {
    if (!mounted) return null;
    final ServiceInfoView info;
    _lastEnv = const [];
    try {
      info = await (widget.inspect ?? readServiceInfo)(serviceId, quotes.quotes.first.address);
    } on CelautError {
      if (!mounted) return null;
      _hideRocket();
      return await _confirmUnreadable(serviceId) ? const [] : null;
    }
    // The service was cut, or its interface was too large to decode: the app cannot tell if
    // Chatui supports it, which is not the same as "unsupported".
    if (info.truncated || info.chat == ChatSupportView.unknown) {
      if (!mounted) return null;
      _hideRocket();
      return await _confirmUnreadable(serviceId, info: info) ? const [] : null;
    }
    if (info.chat == ChatSupportView.unsupported) {
      if (!mounted) return null;
      _hideRocket();
      if (!await _confirmUnsupported(serviceId, info)) return null;
    }
    if (info.environment.isEmpty) return const [];
    if (!mounted) return null;
    _hideRocket();
    final declared = info.environment;
    return Navigator.of(context).push<List<EnvChoice>>(
      MaterialPageRoute(
        builder: (_) => EnvQuestionsScreen(
          declared: declared,
          networks: info.networks,
          nodes: envTargetNodes(quotes.quotes, (widget.trustedNodes ?? _trustedNodes)()),
          store: widget.envStore,
          initial: _presetAnswers(serviceId, declared),
          onConfirmed: (answers) => _lastEnv = presetVariablesOf(declared, answers),
        ),
      ),
    );
  }

  /// The answers of the preset that this section starts, if it knows the variables of its
  /// instance; null asks for each variable, as for a new service.
  List<EnvAnswer?>? _presetAnswers(String serviceId, List<DeclaredVariableView> declared) {
    final preset = widget.preset;
    if (preset == null || !preset.known || preset.serviceId != serviceId.toLowerCase()) return null;
    Set<String> names;
    try {
      names = {for (final n in (widget.envStore ?? EnvStore()).names()) n.name};
    } catch (_) {
      // No container: its variables are asked for.
      names = const {};
    }
    return envAnswersOfPreset(declared, preset.variables, names);
  }

  static Set<String> _trustedNodes() {
    try {
      return {for (final n in celautKnownNodes()) if (n.trusted) n.peerId.toLowerCase()};
    } catch (_) {
      // No database: no node is trusted, so the questions warn of every node.
      return const {};
    }
  }

  void _details(String serviceId, {ServiceInfoView? info, NodeAddress? node, String? name}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ServiceInfoScreen(
          serviceIdHex: serviceId,
          name: name,
          node: node,
          info: info,
          load: widget.inspect ?? readServiceInfo,
        ),
      ),
    );
  }

  /// The alert of an interface that Chatui does not support. True to run it anyway.
  Future<bool> _confirmUnsupported(String serviceId, ServiceInfoView info) async {
    final l = context.l10n;
    final run = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('chat-unsupported'),
        icon: Icon(Icons.warning_amber_rounded, color: rustFor(context)),
        title: Text(l.celautChatUnsupportedTitle),
        content: Text(l.celautChatUnsupportedBody),
        actions: [
          TextButton(
            key: const Key('chat-unsupported-details'),
            onPressed: () => _details(serviceId, info: info),
            child: Text(l.celautChatDetails),
          ),
          TextButton(
            key: const Key('chat-unsupported-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('chat-unsupported-run'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.celautChatRunAnyway),
          ),
        ],
      ),
    );
    return run == true;
  }

  /// The service could not be read: the user cannot be told if Chatui supports it or if it
  /// needs variables. True to run it anyway.
  Future<bool> _confirmUnreadable(String serviceId, {ServiceInfoView? info}) async {
    final l = context.l10n;
    final run = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('env-unreadable'),
        title: Text(l.celautEnvDeclUnreadableTitle),
        content: Text(l.celautEnvDeclUnreadableBody),
        actions: [
          if (info != null)
            TextButton(
              key: const Key('env-unreadable-details'),
              onPressed: () => _details(serviceId, info: info),
              child: Text(l.celautChatDetails),
            ),
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
          TextButton(
            key: const Key('env-run-without'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.celautEnvRunWithout),
          ),
        ],
      ),
    );
    return run == true;
  }

  void _name(String instanceId, String? name) {
    if (name == null || name.trim().isEmpty) return;
    try {
      (widget.nameInstance ??
          (id, n) => celautNameInstance(instanceId: id, name: n))(instanceId, name);
    } catch (_) {
      // Without the name, the list shows the short service id.
    }
  }

  Future<void> _started(LaunchOutcome outcome, String serviceId) async {
    final instance = outcome.instance;
    final name = _lastName;
    _name(instance.instanceId, name);
    final env = _lastEnv;
    if (env != null) {
      // What the instance was started with, so that it can be pinned as a preset. No
      // secret: a typed sensitive value is only "ask".
      unawaited((widget.presets ?? servicePresets).recordLaunch(instance.instanceId, env));
    }
    widget.onChanged?.call();
    final onStarted = widget.onStarted;
    if (onStarted != null) {
      await onStarted(outcome, serviceId, name);
      return;
    }
    if (instance.chatSlots.isNotEmpty) {
      final slot = instance.chatSlots.first;
      try {
        final port = await (widget.openTunnel ??
            (id, s) => celautOpenTunnel(instanceId: id, slot: s))(instance.instanceId, slot);
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => widget.chatBuilder?.call(instance.instanceId, port) ??
                ChatScreen(
                  instance: instanceOfLaunch(outcome, serviceId, name),
                  port: port,
                  wallets: widget.wallets,
                  starting: true,
                ),
          ),
        );
        // The user may have stopped the instance in the conversation.
        widget.onChanged?.call();
        return;
      } on CelautError catch (e) {
        // No conversation: the instance runs, so the home screen shows it.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(CelautStrings.errorText(e.kind))),
          );
        }
        return;
      }
    }
    final quote = outcome.quote;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.celautRunStarted(
            '${quote.address.host}:${quote.address.port}',
            muOrUnknown(quote.costMu),
          ),
        ),
      ),
    );
  }

  Future<void> _showFailure(LaunchFailure failure, String serviceId) async {
    TransferOffer? chosen;
    // A file kept without its filesystem cannot be given to a node: the user loads it again.
    final libraryFile = _library.find(serviceId);
    await showLaunchFailureSheet(
      context,
      failure,
      libraryPath: libraryFile != null && libraryFile.filesystemKept ? libraryFile.path : null,
      onDeposit: widget.openDeposit ??
          () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const DepositScreen()),
          ),
      onSendService: (offer) => chosen = offer,
    );
    final offer = chosen;
    if (offer != null && mounted) {
      await _sendService(offer, serviceId);
      return;
    }
    // A node that forgot the client id: the user chooses. The app never makes a new
    // client by itself.
    final forgot = failure.clientUnknown;
    if (forgot.isNotEmpty && mounted) {
      await showClientUnknownChoice(
        context,
        node: forgot.first.quote.address,
        error: forgot.first.error.message,
        newClient: widget.newClient,
      );
    }
  }

  /// Pick a `.celaut.bee` file and load it into the library of the app. Gives the loaded
  /// service, or null if the user did not pick a file or the file is refused (the user
  /// has been told).
  Future<LibraryPackageView?> _loadPickedFile() => _loadFile(_pick);

  Future<ChosenFile?> _pick() async {
    try {
      return await (widget.packages ?? const AndroidPackageChannel()).pick();
    } catch (_) {
      return null;
    }
  }

  /// Load the file that [choose] gives (the picker, or a file that the user opened in a
  /// file manager) into the library, as [_loadPickedFile] does.
  Future<LibraryPackageView?> _loadFile(Future<ChosenFile?> Function() choose) async {
    final incoming = widget.incoming ?? incomingPackages;
    incoming.setBusy(true);
    try {
      // The file picker of Android puts the app in the background: the import goes on, and
      // the auto-lock does not close this page meanwhile (`BackgroundWork`).
      return await (widget.work ?? backgroundWork).run(
        context,
        KeepAliveReason.import,
        () async {
          final chosen = await choose();
          if (chosen == null || !mounted) return null;
          return _loadChosen(chosen);
        },
      );
    } finally {
      incoming.setBusy(false);
    }
  }

  /// True if the library has a file of this name and size: the user is asked before the
  /// app reads it again. The check of the file tells the service only after the read.
  bool _seemsLoaded(ChosenFile file) {
    final name = libraryNameOf(file.name);
    final bytes = file.bytes;
    if (name == null || bytes == null) return false;
    return _library.list().any((p) => p.present && p.name == name && p.bytes.toInt() == bytes);
  }

  Future<bool> _confirmAgain(ChosenFile file) async {
    final l = context.l10n;
    final again = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('pkg-again-dialog'),
        title: Text(l.celautPkgAgainTitle),
        content: Text(l.celautPkgAgainBody(libraryNameOf(file.name) ?? file.name)),
        actions: [
          TextButton(
            key: const Key('pkg-again-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.celautSendCancel),
          ),
          FilledButton(
            key: const Key('pkg-again-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.celautPkgAgainImport),
          ),
        ],
      ),
    );
    return again == true;
  }

  Future<LibraryPackageView?> _loadChosen(ChosenFile file) async {
    if (file.isLink) return _loadLink(file.uri);
    final packages = widget.packages ?? const AndroidPackageChannel();
    if (_seemsLoaded(file) && !await _confirmAgain(file)) return null;
    if (!mounted) return null;
    try {
      // The card shows before the copy of the file: a large file takes a while to read.
      final loaded = await runWithImportRocket(
        context,
        work: () => _library.importChosen(file, packages),
        progress: _library.importProgress,
        cancel: _library.cancelImport,
      );
      if (mounted) setState(_readPackages);
      return loaded;
    } on ImportCancelled {
      // The user stopped the import: the chosen file stays where it was.
    } on CopyCancelled {
      // The same, when the cancel came between the copy and the check.
    } on CopyFailed catch (e) {
      if (mounted) _showFileProblem(context.l10n.celautPkgUnreadable(e.message));
    } on CelautError catch (e) {
      if (mounted) await _showBadFile(e);
    } on PackageRefused {
      if (mounted) await showTransferFailure(context, const PackageRefused(PackageRefusal.noDirectory));
    }
    return null;
  }

  Future<void> _showBadFile(CelautError e) async {
    final l = context.l10n;
    _showFileProblem(e.kind == CelautErrorKind.invalidInput
        ? l.celautPkgBadFile(e.message)
        : CelautStrings.errorText(e.kind));
  }

  void _showFileProblem(String text) {
    // A browser sometimes saves a .celaut.bee file damaged, so any failure to load one says to
    // download it again.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      key: const Key('pkg-bad-file'),
      duration: const Duration(seconds: 8),
      content: Text('$text\n${context.l10n.celautPkgRedownload}'),
    ));
  }

  /// Load a service file into the app, from the "Import a service file" button.
  Future<void> _importPicked() => _importAndTell(_pick);

  /// The "Import" button: a file on the phone, or a link (issue #135).
  Future<void> _import({String? link}) async {
    final library = _library;
    final request = await showModalBottomSheet<ImportRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ImportSheet(
        pending: library.pendingLink,
        discard: library.discardLink,
        scan: widget.scan ?? _scanCode,
        initialLink: link,
      ),
    );
    if (!mounted || request == null) return;
    switch (request) {
      case ImportFileRequest():
        await _importPicked();
      case ImportLinkRequest(:final url):
        await _importAndTell(() async => ChosenFile.link(url));
    }
  }

  static Future<String?> _scanCode(BuildContext context) =>
      Navigator.push<String>(context, fadeRoute(const ScanScreen()));

  /// Download the service at [url] into the library, under the card of the import, with the
  /// warning for `http://` first. Gives the loaded service, or null (the user was told).
  Future<LibraryPackageView?> _loadLink(String url) async {
    final l = context.l10n;
    final LinkView link;
    try {
      link = _library.checkLink(url);
    } on CelautError catch (e) {
      _showLinkProblem(l.celautLinkImportInvalid(e.message));
      return null;
    }
    if (link.insecure && !await _confirmHttp(link.url)) return null;
    if (!mounted) return null;
    try {
      final loaded = await runWithImportRocket(
        context,
        work: () => _library.importLink(link.url, allowHttp: link.insecure),
        progress: _library.importProgress,
        cancel: _library.cancelImport,
      );
      if (mounted) setState(_readPackages);
      return loaded;
    } on ImportCancelled {
      if (mounted) _showLinkProblem(l.celautLinkCancelled);
    } on CelautError catch (e) {
      if (!mounted) return null;
      switch (e.kind) {
        case CelautErrorKind.unreachable || CelautErrorKind.timeout:
          _showLinkProblem(
            l.celautLinkStopped(e.message),
            action: SnackBarAction(
              key: const Key('link-retry'),
              label: l.celautLinkPendingContinue,
              onPressed: () => unawaited(_importAndTell(() async => ChosenFile.link(link.url))),
            ),
          );
        case CelautErrorKind.limitReached:
          _showLinkProblem(l.celautLinkTooLarge(CelautStrings.bytes(maxLinkBytes)));
        case CelautErrorKind.noSpace:
          await _showNoSpace(e, link.url);
        case CelautErrorKind.invalidInput:
          _showLinkProblem(l.celautLinkBadFile(e.message));
        case CelautErrorKind.transferFailed:
          _showLinkProblem(l.celautLinkCancelled);
        default:
          _showLinkProblem(l.celautLinkFailed(CelautStrings.errorText(e.kind), e.message));
      }
    } on PackageRefused {
      if (mounted) await showTransferFailure(context, const PackageRefused(PackageRefusal.noDirectory));
    }
    return null;
  }

  /// The phone has not enough free space for the download of [url] (issue #151). Continue
  /// is offered only when the bytes that arrived stay on the phone: a download refused
  /// before its first byte keeps nothing.
  Future<void> _showNoSpace(CelautError e, String url) async {
    final sizes = noSpaceOf(e);
    final kept = (await _library.pendingLink())?.url == url;
    if (!mounted) return;
    final l = context.l10n;
    if (sizes == null) {
      _showLinkProblem(CelautStrings.errorText(CelautErrorKind.noSpace));
      return;
    }
    final needed = CelautStrings.bytes(sizes.needed);
    final available = CelautStrings.bytes(sizes.available);
    if (!kept) {
      _showLinkProblem(l.celautLinkNoSpaceRetry(needed, available));
      return;
    }
    _showLinkProblem(
      l.celautLinkNoSpace(needed, available),
      action: SnackBarAction(
        key: const Key('link-retry'),
        label: l.celautLinkPendingContinue,
        onPressed: () => unawaited(_importAndTell(() async => ChosenFile.link(url))),
      ),
    );
  }

  Future<bool> _confirmHttp(String url) async {
    final l = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('link-http-dialog'),
        title: Text(l.celautLinkHttpTitle),
        content: Text(l.celautLinkHttpBody(url)),
        actions: [
          TextButton(
            key: const Key('link-http-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.celautSendCancel),
          ),
          FilledButton(
            key: const Key('link-http-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.celautLinkHttpConfirm),
          ),
        ],
      ),
    );
    return yes == true;
  }

  void _showLinkProblem(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      key: const Key('link-problem'),
      duration: const Duration(seconds: 8),
      content: Text(text),
      action: action,
    ));
  }

  /// Load the file that [choose] gives, and say that it is loaded, or that it replaced the
  /// file of the same service.
  Future<void> _importAndTell(Future<ChosenFile?> Function() choose) async {
    final before = {for (final p in _packages) p.serviceId};
    final loaded = await _loadFile(choose);
    if (loaded == null || !mounted) return;
    final l = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('pkg-loaded'),
        content: Text(before.contains(loaded.serviceId)
            ? l.celautPkgReplaced(loaded.name)
            : l.celautPkgLoaded(loaded.name)),
      ),
    );
  }

  Future<void> _removePackage(LibraryPackageView package) async {
    final l = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.celautPkgRemoveTitle),
        content: Text(l.celautPkgRemoveBody(package.name)),
        actions: [
          TextButton(
            key: const Key('pkg-remove-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.celautSendCancel),
          ),
          FilledButton(
            key: const Key('pkg-remove-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.celautPkgRemove),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    try {
      await _library.remove(package.serviceId);
    } on CelautError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(CelautStrings.errorText(e.kind))),
        );
      }
    }
    if (mounted) setState(_readPackages);
  }

  Future<void> _runPackage(LibraryPackageView package) async {
    if (!package.present) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.celautPkgMissing)),
      );
      return;
    }
    await _run(package.serviceId, name: package.name);
  }

  /// Give the service to the node of [offer] that does not have it, then launch again: the
  /// balancer now sees that node (`docs/celaut/package.md`). The service comes from a file
  /// of the library, from another node (a copy that is deleted after the send), or from a
  /// file that the user picks now (it is loaded into the library first).
  Future<void> _sendService(TransferOffer offer, String serviceId) async {
    final packages = widget.packages ?? const AndroidPackageChannel();
    final transfer = widget.transfer ?? ServiceTransfer();
    final metered = await packages.isMetered();
    if (!mounted) return;
    if (!await confirmServiceTransfer(context, metered: metered) || !mounted) return;
    String? path = offer.libraryPath;
    if (offer.source == TransferSource.file) {
      final loaded = await _loadPickedFile();
      if (loaded == null || !mounted) return;
      if (loaded.serviceId != serviceId.toLowerCase()) {
        // The file holds another service: it stays in the library, but it is not this one.
        await showTransferFailure(context, const PackageRefused(PackageRefusal.otherService));
        return;
      }
      path = loaded.path;
    }
    // The transfer goes on with the screen off or the app in the background.
    final result = await (widget.work ?? backgroundWork).run(
      context,
      KeepAliveReason.transfer,
      () => showServiceTransfer(
        context,
        transfer: transfer,
        work: () => offer.source == TransferSource.node
            ? transfer.fromNode(offer, serviceId, null)
            : transfer.fromLibrary(offer.to, serviceId, null, path!),
      ),
    );
    if (!mounted) return;
    final error = result.error;
    if (error != null) {
      await showTransferFailure(context, error);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.celautSendDone)),
    );
    await _run(serviceId);
  }

  /// The objectives that match the search, the most backed first ([rankObjectives]).
  List<ObjectiveView> _filtered() {
    final query = _search.text.trim().toLowerCase();
    return [for (final s in rankObjectives(_objectives ?? const <ObjectiveView>[])) if (objectiveMatches(s, query)) s];
  }

  /// A new search shows its objectives from the start.
  void _filter(VoidCallback change) {
    setState(change);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// The saved service files, in a sheet: Run or Remove each one, or import another.
  Future<void> _openPhone() async {
    final package = await showModalBottomSheet<LibraryPackageView>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PhoneServicesSheet(
        list: () {
          _readPackages();
          return _packages;
        },
        import: _importPicked,
        importLink: () => _import(),
        remove: _removePackage,
      ),
    );
    if (!mounted) return;
    setState(_readPackages);
    if (package != null) await _runPackage(package);
  }

  @override
  Widget build(BuildContext context) {
    // A preset: only the dialogs and the rocket of the launch show, over the list.
    if (widget.preset != null) return const SizedBox.shrink(key: Key('run-preset'));
    final l = context.l10n;
    final t = HomeText.of(context);
    final browsing = _search.text.trim().isEmpty;
    final objectives = _filtered();
    Widget gutter(Widget child) =>
        Padding(padding: const EdgeInsets.symmetric(horizontal: homeGutter), child: child);
    return Column(
      key: const Key('run-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // At the top at all times: the search and the two actions of this phone.
        Padding(
          key: const Key('run-top'),
          padding: const EdgeInsets.fromLTRB(homeGutter, 8, homeGutter, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showTitle) ...[
                Text(l.celautRunTitle.toUpperCase(), style: t.label),
                const SizedBox(height: 10),
              ],
              _topBar(context),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => ListView(
              key: const Key('run-list'),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(0, 4, 0, 32 + MediaQuery.paddingOf(context).bottom),
              children: [
                if (_typeMissing)
                  gutter(ObjectiveTypeMissing(onBack: _read))
                else if (_loading)
                  gutter(StoreSkeleton(key: const Key('run-loading'), featured: browsing))
                else if (_failed)
                  gutter(
                    StoreMessage(
                      icon: Icons.cloud_off_outlined,
                      text: l.celautRunCatalogError,
                      textKey: const Key('run-error'),
                      action: OutlinedButton(
                        key: const Key('run-retry'),
                        // The theme asks for the full width, which a column of text does not need.
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), shape: const StadiumBorder()),
                        onPressed: _read,
                        child: Text(l.celautRunRetry),
                      ),
                    ),
                  )
                else if (objectives.isEmpty)
                  gutter(
                    StoreMessage(
                      icon: browsing ? Icons.storefront_outlined : Icons.search_off,
                      text: browsing ? l.celautStoreCatalogEmpty : l.celautRunEmpty,
                      textKey: const Key('run-empty'),
                    ),
                  )
                else if (browsing)
                  ..._home(context, objectives, box.maxWidth)
                else
                  ..._results(context, objectives),
                // While a launch runs, its rocket is over the screen ([LaunchRocket]).
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The search and the two actions of this phone. On a narrow screen the actions are
  /// icons with a tooltip; on a wide one they have their text too.
  Widget _topBar(BuildContext context) {
    final l = context.l10n;
    final count = _packages.length;
    final phoneIcon = Badge.count(
      count: count,
      isLabelVisible: count > 0,
      child: const Icon(Icons.phone_android_outlined, size: 20),
    );
    const importIcon = Icon(Icons.upload_file_outlined, size: 20);
    final onImport = _running ? null : _import;
    final onPhone = _running ? null : _openPhone;
    return LayoutBuilder(
      builder: (context, box) {
        final labels = box.maxWidth >= 560;
        // The theme asks for the full width, which a row cannot give.
        final style = OutlinedButton.styleFrom(minimumSize: const Size(0, 48));
        return Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('run-search'),
                controller: _search,
                onChanged: (_) => _filter(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: l.celautRunSearchHint,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: l.celautLinkSheetTitle,
              child: labels
                  ? OutlinedButton.icon(
                      key: const Key('run-import'),
                      style: style,
                      onPressed: onImport,
                      icon: importIcon,
                      label: Text(l.celautRunImport),
                    )
                  : IconButton.outlined(
                      key: const Key('run-import'),
                      onPressed: onImport,
                      icon: importIcon,
                    ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: l.celautRunPhoneServices,
              child: labels
                  ? OutlinedButton.icon(
                      key: const Key('run-phone'),
                      style: style,
                      onPressed: onPhone,
                      icon: phoneIcon,
                      label: Text(l.celautRunOnPhone),
                    )
                  : IconButton.outlined(
                      key: const Key('run-phone'),
                      onPressed: onPhone,
                      icon: phoneIcon,
                    ),
            ),
          ],
        );
      },
    );
  }

  /// The store home, from [ranked] (all the objectives, most backed first): the featured
  /// objective, the shelves by field, and "Top objectives" with its first [storeShortList] rows
  /// and "Show more".
  List<Widget> _home(BuildContext context, List<ObjectiveView> ranked, double width) {
    final l = context.l10n;
    final top = ranked.first;
    final rankOf = {for (var i = 0; i < ranked.length; i++) ranked[i].boxId: i + 1};
    final cut = !_showAll && ranked.length > storeShortList;
    final rows = cut ? ranked.take(storeShortList).toList() : ranked;
    Widget gutter(Widget child, {Key? key}) =>
        Padding(key: key, padding: const EdgeInsets.symmetric(horizontal: homeGutter), child: child);
    final featuredTag = objectiveHeroTag('featured', top);
    final shelves = storeShelves(ranked);
    return [
      const SizedBox(height: 4),
      gutter(
        ObjectiveFeatureCard(
          key: const Key('store-featured'),
          runKey: const Key('store-featured-run'),
          objective: top,
          heroTag: featuredTag,
          busy: _quick == top.boxId,
          onTap: _running ? null : () => _open(top, heroTag: featuredTag, rank: 1),
          onRun: _running || _quick != null ? null : () => _quickRun(top, heroTag: featuredTag, rank: 1),
        ),
      ),
      for (final shelf in shelves) ...[
        const SizedBox(height: 26),
        gutter(
          StoreSectionTitle(
            shelf.key == mixedShelfKey
                ? (shelves.length == 1 ? l.celautStoreByField : l.celautStoreMoreFields)
                : shelf.title,
          ),
          key: Key('store-shelf-${shelf.key}'),
        ),
        const SizedBox(height: 12),
        _shelf(shelf, rankOf),
      ],
      const SizedBox(height: 26),
      gutter(StoreSectionTitle(l.celautStoreTopObjectives), key: const Key('store-top')),
      const SizedBox(height: 4),
      gutter(_rows(rows, width, rankOf: rankOf, place: 'top', showField: true)),
      if (ranked.length > storeShortList)
        gutter(
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('store-more'),
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(_showAll ? l.celautStoreShowFewer : l.celautStoreShowMore(ranked.length - storeShortList)),
            ),
          ),
        ),
    ];
  }

  /// A shelf: its tiles in a row that scrolls sideways, all of one height.
  Widget _shelf(ObjectiveShelf shelf, Map<String, int> rankOf) {
    final mixed = shelf.key == mixedShelfKey;
    return SingleChildScrollView(
      key: Key('store-shelf-list-${shelf.key}'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: homeGutter),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, s) in shelf.objectives.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              Builder(
                builder: (context) {
                  final tag = objectiveHeroTag('shelf-${shelf.key}', s);
                  return ObjectiveTile(
                    key: Key('store-tile-${s.boxId}'),
                    objective: s,
                    showField: mixed,
                    heroTag: tag,
                    onTap: _running ? null : () => _open(s, heroTag: tag, rank: rankOf[s.boxId]),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// [objectives] as ranked rows, with their rank when [rankOf] is given: one column on a phone,
  /// two on a wide screen.
  Widget _rows(
    List<ObjectiveView> objectives,
    double width, {
    Map<String, int>? rankOf,
    required String place,
    bool showField = false,
  }) {
    Widget row(ObjectiveView s, {required bool divider}) {
      final tag = objectiveHeroTag(place, s);
      final rank = rankOf?[s.boxId];
      return ObjectiveRow(
        key: Key('run-objective-${s.boxId}'),
        runKey: Key('run-objective-run-${s.boxId}'),
        objective: s,
        rank: rank,
        heroTag: tag,
        divider: divider,
        showField: showField,
        busy: _quick == s.boxId,
        onTap: _running ? null : () => _open(s, heroTag: tag, rank: rank),
        onRun: _running || _quick != null ? null : () => _quickRun(s, heroTag: tag, rank: rank),
      );
    }

    final columns = width >= 600 ? 2 : 1;
    final lines = (objectives.length + columns - 1) ~/ columns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var line = 0; line < lines; line++)
          columns == 1
              ? row(objectives[line], divider: line < lines - 1)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var c = 0; c < columns; c++) ...[
                      if (c > 0) const SizedBox(width: 20),
                      Expanded(
                        child: line * columns + c < objectives.length
                            ? row(objectives[line * columns + c], divider: line < lines - 1)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
      ],
    );
  }

  /// The objectives that match a search, as rows in groups by field (issue #122): all of
  /// them, most backed first in each group, with no rank.
  List<Widget> _results(BuildContext context, List<ObjectiveView> objectives) {
    final l = context.l10n;
    final t = HomeText.of(context);
    return [
      for (final g in objectiveGroups(objectives))
        Padding(
          key: Key('store-group-${g.key}'),
          padding: const EdgeInsets.fromLTRB(homeGutter, 8, homeGutter, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text((g.title.isEmpty ? l.celautStoreOtherField : g.title).toUpperCase(), style: t.label),
              const SizedBox(height: 4),
              _rows(g.objectives, 0, place: 'search'),
            ],
          ),
        ),
    ];
  }
}

/// The service files saved in the app, as a bottom sheet: Run and Remove for each, and the
/// import of another file, which then shows in the list. It returns the file to run; the
/// section runs it.
class _PhoneServicesSheet extends StatefulWidget {
  const _PhoneServicesSheet({
    required this.list,
    required this.import,
    required this.importLink,
    required this.remove,
  });

  final List<LibraryPackageView> Function() list;

  /// Pick and load a file. The sheet reads the list again after it.
  final Future<void> Function() import;

  /// The import sheet: a file or a link. The sheet reads the list again after it.
  final Future<void> Function() importLink;

  /// Ask, then remove a file. The sheet reads the list again after it.
  final Future<void> Function(LibraryPackageView package) remove;

  @override
  State<_PhoneServicesSheet> createState() => _PhoneServicesSheetState();
}

class _PhoneServicesSheetState extends State<_PhoneServicesSheet> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final packages = widget.list();
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('phone-sheet'),
        padding: const EdgeInsets.fromLTRB(homeGutter, 0, homeGutter, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.celautRunOnPhone, key: const Key('run-on-phone'), style: t.title),
            const SizedBox(height: 6),
            if (packages.isEmpty)
              Text(l.celautPkgEmpty, key: const Key('pkg-empty'), style: t.secondary)
            else
              for (final package in packages)
                Padding(
                  key: Key('pkg-${package.serviceId}'),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(package.name, style: t.primary),
                            Text(
                              package.present
                                  ? '${CelautStrings.bytes(package.bytes.toInt())} · '
                                      '${package.serviceId.substring(0, 8)}'
                                  : l.celautPkgMissing,
                              style: t.secondary,
                            ),
                            if (package.present && !package.filesystemKept)
                              Text(
                                l.celautPkgNoFilesystem,
                                key: Key('pkg-no-filesystem-${package.serviceId}'),
                                style: t.secondary,
                              ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        key: Key('pkg-run-${package.serviceId}'),
                        // The theme asks for the full width, which a row cannot give.
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: package.present
                            ? () => Navigator.of(context).pop(package)
                            : null,
                        child: Text(l.celautRunButton),
                      ),
                      IconButton(
                        key: Key('pkg-remove-${package.serviceId}'),
                        tooltip: l.celautPkgRemove,
                        onPressed: () async {
                          await widget.remove(package);
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('pkg-import'),
                onPressed: () async {
                  await widget.import();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: Text(l.celautPkgImport),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('pkg-import-link'),
                onPressed: () async {
                  await widget.importLink();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.link, size: 18),
                label: Text(l.celautLinkFromLink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
