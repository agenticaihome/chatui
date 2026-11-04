import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_catalog.dart';
import '../../bridge/api/celaut_env.dart';
import '../../bridge/api/celaut_service_info.dart';
import '../../bridge/api/celaut_home.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/background_work.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/conversation_keep_alive.dart';
import '../../celaut/egress.dart';
import '../../celaut/env_store.dart';
import '../../celaut/launcher.dart';
import '../../bridge/api/celaut_package.dart';
import '../../celaut/package_channel.dart';
import '../../celaut/package_library.dart';
import '../../celaut/payers.dart';
import '../../celaut/service_strings.dart';
import '../../celaut/service_transfer.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';
import 'chat_screen.dart';
import 'client_unknown_dialog.dart';
import 'deposit_screen.dart';
import 'env_questions_screen.dart';
import 'instance_list.dart' show instanceOfLaunch;
import 'launch_failure_sheet.dart';
import 'import_rocket.dart';
import 'launch_rocket.dart';
import 'run_confirm_dialog.dart';
import 'service_info_screen.dart';
import 'service_transfer_dialog.dart';
import 'skill_services_sheet.dart';
import 'skill_store.dart';

/// Start a service: the ids and the settings go to the launcher.
typedef LaunchCall = Future<LaunchOutcome> Function({
  required String serviceIdHex,
  String? initialMu,
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

/// "Run a service" on the home screen (`docs/celaut/ui.md`, section 2): the skills of the
/// catalog as a store, with a search field and the fields of the skills as chips
/// ([SkillCard]). The service files on this phone come last, a secondary way to run a
/// service. A skill opens a sheet with its ranked services. Run starts
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
    this.loadSkills,
    this.loadServices,
    this.previewQuote,
    this.launch,
    this.openTunnel,
    this.chatBuilder,
    this.openDeposit,
    this.transfer,
    this.packages,
    this.library,
    this.showTitle = true,
    this.onStarted,
    this.nameInstance,
    this.inspect,
    this.envStore,
    this.trustedNodes,
    this.work,
  });

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

  /// The skills of the catalog. Tests give their own.
  final Future<List<SkillView>> Function()? loadSkills;

  /// The ranked services of a skill. Tests give their own.
  final Future<List<SkillServiceView>> Function(String skillBoxId)? loadServices;

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

  @override
  State<RunServiceSection> createState() => _RunServiceSectionState();
}

class _RunServiceSectionState extends State<RunServiceSection> {
  final _search = TextEditingController();
  List<SkillView>? _skills;

  /// The field that the chips show ([skillCategory]); null for all.
  String? _category;
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

  @override
  void initState() {
    super.initState();
    _readPackages();
    _read();
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
    super.dispose();
  }

  Future<void> _read() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final skills = await (widget.loadSkills ?? celautSkills)();
      if (mounted) setState(() => _skills = skills);
    } catch (_) {
      // Any failure, also one that is not a Celaut error: the section shows the retry.
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<SkillServiceView>> _services(String skillBoxId) =>
      (widget.loadServices ?? (id) => celautSkillServices(skillBoxId: id))(skillBoxId);

  Future<QuoteView?> _preview(String serviceId) async {
    final custom = widget.previewQuote;
    if (custom != null) return custom(serviceId);
    final nodes = knownNodeAddresses(celautKnownNodes());
    if (nodes.isEmpty) return null;
    final quotes = await celautQuoteService(
      nodes: nodes,
      serviceIdHex: serviceId,
      initialMu: ServiceStrings.initialDefault,
    );
    return quotes.quotes.isEmpty ? null : quotes.quotes.first;
  }

  Future<void> _open(SkillView skill) async {
    final serviceId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SkillServicesSheet(
        skill: skill,
        loadServices: _services,
        previewQuote: _preview,
        wallets: widget.wallets,
      ),
    );
    if (serviceId != null && mounted) await _run(serviceId, name: skill.name);
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

  /// Launch [serviceId]. [name] is what the confirmation calls it; with no name the user
  /// has already confirmed (the launch again after a transfer).
  Future<void> _run(String serviceId, {String? name}) async {
    if (name != null) {
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
          ({required serviceIdHex, initialMu, minSurvival, keepAlive = false, budgetMu, environment}) => launchService(
                serviceIdHex: serviceIdHex,
                initialMu: initialMu,
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
          initialMu: ServiceStrings.initialDefault,
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
    return Navigator.of(context).push<List<EnvChoice>>(
      MaterialPageRoute(
        builder: (_) => EnvQuestionsScreen(
          declared: info.environment,
          networks: info.networks,
          nodes: envTargetNodes(quotes.quotes, (widget.trustedNodes ?? _trustedNodes)()),
          store: widget.envStore,
        ),
      ),
    );
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
    await showLaunchFailureSheet(
      context,
      failure,
      libraryPath: _library.find(serviceId)?.path,
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
  Future<LibraryPackageView?> _loadPickedFile() =>
      // The file picker of Android puts the app in the background: the import goes on, and
      // the auto-lock does not close this page meanwhile (`BackgroundWork`).
      (widget.work ?? backgroundWork).run(context, KeepAliveReason.import, _pickAndLoad);

  Future<LibraryPackageView?> _pickAndLoad() async {
    final packages = widget.packages ?? const AndroidPackageChannel();
    final PickedPackage? picked;
    try {
      picked = await packages.pick();
    } catch (_) {
      return null;
    }
    if (picked == null || !mounted) return null;
    final file = picked;
    try {
      final loaded = await runWithImportRocket(
        context,
        work: () => _library.importPicked(file),
        progress: _library.progress,
        cancel: _library.cancel,
      );
      if (mounted) setState(_readPackages);
      return loaded;
    } on ImportCancelled {
      // The user stopped the check: the file stays where it was.
    } on CelautError catch (e) {
      if (mounted) await _showBadFile(e);
    } on PackageRefused {
      if (mounted) await showTransferFailure(context, const PackageRefused(PackageRefusal.noDirectory));
    }
    return null;
  }

  Future<void> _showBadFile(CelautError e) async {
    final l = context.l10n;
    final text = e.kind == CelautErrorKind.invalidInput
        ? l.celautPkgBadFile(e.message)
        : CelautStrings.errorText(e.kind);
    // A browser sometimes saves a .celaut.bee file damaged, so any failure to load one says to
    // download it again.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      key: const Key('pkg-bad-file'),
      duration: const Duration(seconds: 8),
      content: Text('$text\n${l.celautPkgRedownload}'),
    ));
  }

  /// Load a service file into the app, from the "Import" button.
  Future<void> _import() async {
    final loaded = await _loadPickedFile();
    if (loaded == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.celautPkgLoaded(loaded.name))),
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
            ? transfer.fromNode(offer, serviceId, ServiceStrings.initialDefault)
            : transfer.fromLibrary(offer.to, serviceId, ServiceStrings.initialDefault, path!),
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

  /// The skills of [category] (null for all) that match the search.
  List<SkillView> _filtered(String? category) {
    final query = _search.text.trim().toLowerCase();
    final all = _skills ?? const <SkillView>[];
    return [
      for (final s in all)
        if ((category == null || skillCategory(s) == category) && skillMatches(s, query)) s,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final categories = skillCategories(_skills ?? const <SkillView>[]);
    // A field that the catalog no longer has shows all the skills.
    final category = categories.any((c) => c.key == _category) ? _category : null;
    final skills = _filtered(category);
    return Padding(
      key: const Key('run-section'),
      padding: const EdgeInsets.symmetric(horizontal: homeGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showTitle) ...[
            Text(l.celautRunTitle.toUpperCase(), style: t.label),
            const SizedBox(height: 10),
          ],
          TextField(
            key: const Key('run-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: l.celautRunSearchHint,
              isDense: true,
            ),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            SkillCategoryBar(
              categories: categories,
              selected: category,
              allLabel: l.celautRunCategoryAll,
              onSelected: (key) => setState(() => _category = key),
            ),
          ],
          const SizedBox(height: 12),
          if (_loading)
            Text(l.celautRunLoading, key: const Key('run-loading'), style: t.secondary)
          else if (_failed) ...[
            Text(l.celautRunCatalogError, key: const Key('run-error'), style: t.secondary),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const Key('run-retry'),
                onPressed: _read,
                child: Text(l.celautRunRetry),
              ),
            ),
          ] else if (skills.isEmpty)
            Text(l.celautRunEmpty, key: const Key('run-empty'), style: t.secondary)
          else
            for (final skill in skills)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SkillCard(
                  key: Key('run-skill-${skill.boxId}'),
                  skill: skill,
                  onTap: _running ? null : () => _open(skill),
                ),
              ),
          // The service files on this phone: the rare way, after the catalog. The services
          // saved in the app run from here, with no new import.
          const SizedBox(height: 20),
          Text(l.celautRunOnPhone.toUpperCase(), key: const Key('run-on-phone'), style: t.label),
          if (_packages.isEmpty) ...[
            const SizedBox(height: 6),
            Text(l.celautPkgEmpty, key: const Key('pkg-empty'), style: t.secondary),
          ] else
            for (final package in _packages)
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
                        ],
                      ),
                    ),
                    OutlinedButton(
                      key: Key('pkg-run-${package.serviceId}'),
                      // The theme asks for the full width, which a row cannot give.
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: _running || !package.present ? null : () => _runPackage(package),
                      child: Text(l.celautRunButton),
                    ),
                    IconButton(
                      key: Key('pkg-remove-${package.serviceId}'),
                      tooltip: l.celautPkgRemove,
                      onPressed: _running ? null : () => _removePackage(package),
                      icon: const Icon(Icons.delete_outline, size: 20),
                    ),
                  ],
                ),
              ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('pkg-import'),
              onPressed: _running ? null : _import,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(l.celautPkgImport),
            ),
          ),
          // While a launch runs, its rocket is over the screen ([LaunchRocket]).
        ],
      ),
    );
  }
}
