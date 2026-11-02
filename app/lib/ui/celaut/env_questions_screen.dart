import 'package:flutter/material.dart';

import '../../bridge/api/celaut_env.dart';
import '../../bridge/api/celaut_service_info.dart' show NetworkView;
import '../../celaut/egress.dart';
import '../../celaut/env_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../layout.dart';
import 'env_variables_screen.dart' show envProblemText;

/// What the user chose for one declared variable.
sealed class EnvAnswer {
  const EnvAnswer();
}

/// The value of a variable of the container.
class EnvFromContainer extends EnvAnswer {
  const EnvFromContainer(this.name);
  final String name;
}

/// A value that the user typed. [sensitive] is the mark that the user gave it: a typed
/// value is not sensitive unless the user says so (`docs/celaut/env-variables.md`, section
/// 3.2).
class EnvTyped extends EnvAnswer {
  const EnvTyped(this.text, {this.sensitive = false, this.save = false});
  final String text;
  final bool sensitive;

  /// Save the value in the container, under the name of the variable, when the user
  /// confirms (decided 2026-11-01, `docs/celaut/env-variables.md`, section 3).
  final bool save;
}

/// What the questions are for: the variables of a launch, or one secret that a service asks
/// for in the chat (`docs/celaut/chat.md`, section 5.6). Only the texts of the title, the
/// review and its buttons change.
enum EnvQuestionsPurpose { launch, chat }

/// The variable is not given: it is not in the configuration.
class EnvSkipped extends EnvAnswer {
  const EnvSkipped();
}

/// The choices that go to the start, in the order of [declared]. A skipped variable, or
/// one without an answer, is left out.
List<EnvChoice> envChoices(List<DeclaredVariableView> declared, List<EnvAnswer?> answers) {
  final out = <EnvChoice>[];
  for (var i = 0; i < declared.length; i++) {
    switch (answers[i]) {
      case EnvFromContainer(:final name):
        out.add(EnvChoice(name: declared[i].name, container: name));
      case EnvTyped(:final text):
        out.add(EnvChoice(name: declared[i].name, text: text));
      case EnvSkipped() || null:
        break;
    }
  }
  return out;
}

/// The question about the environment variables of a service, one variable at a time,
/// then a review (`docs/celaut/env-variables.md`, section 3). For each variable the user
/// chooses one of the container, types a value, or skips it. Closing the screen cancels
/// the launch: it gives null. Run on the review gives the choices.
///
/// If a sensitive value is given, the review also says where it can go (section 3.2): out
/// of the node by the networks of the service (red, and Deny is the default), to the other
/// services of the node, and to nodes that the user did not mark as trusted. All of it is
/// on the one review page.
class EnvQuestionsScreen extends StatefulWidget {
  const EnvQuestionsScreen({
    super.key,
    required this.declared,
    this.networks = const [],
    this.nodes = const [],
    this.purpose = EnvQuestionsPurpose.launch,
    EnvStore? store,
  }) : _store = store;

  final List<DeclaredVariableView> declared;

  /// The networks that the service declares.
  final List<NetworkView> networks;

  /// The nodes that can get the start request, best first ([envTargetNodes]).
  final List<EnvTargetNode> nodes;
  final EnvQuestionsPurpose purpose;
  final EnvStore? _store;

  @override
  State<EnvQuestionsScreen> createState() => _EnvQuestionsScreenState();
}

class _EnvQuestionsScreenState extends State<EnvQuestionsScreen> {
  late final EnvStore _store = widget._store ?? EnvStore();
  late final List<EnvAnswer?> _answers = List.filled(widget.declared.length, null);
  late final EgressReport _egress = egressOf(widget.networks);
  int _index = 0;
  bool _typing = false;
  bool _hidden = true;
  bool _typedSensitive = false;
  bool _typedSave = false;
  String? _typedError;
  final _typedCtrl = TextEditingController();

  bool get _review => _index >= widget.declared.length;

  @override
  void dispose() {
    _typedCtrl.dispose();
    super.dispose();
  }

  void _go(int index) {
    setState(() {
      _index = index;
      _typing = false;
      _hidden = true;
      _typedSensitive = false;
      _typedSave = false;
      _typedError = null;
      _typedCtrl.clear();
    });
  }

  /// The variables of the container, or none if the database cannot be read.
  List<EnvNameView> _containerViews() {
    try {
      return _store.names();
    } catch (_) {
      return const [];
    }
  }

  /// True if [answer] gives a sensitive value. A variable of the container that is not
  /// there any more counts as sensitive: the start refuses it anyway.
  bool _isSensitive(EnvAnswer? answer, Map<String, bool> marks) => switch (answer) {
        EnvFromContainer(:final name) => marks[name] ?? true,
        EnvTyped(:final sensitive) => sensitive,
        EnvSkipped() || null => false,
      };

  EnvWarnings _warnings(Map<String, bool> marks) => EnvWarnings.of(
        sensitive: _answers.any((a) => _isSensitive(a, marks)),
        report: _egress,
        nodes: widget.nodes,
      );

  void _answer(EnvAnswer answer) {
    _answers[_index] = answer;
    _go(_index + 1);
  }

  List<EnvNameView> _containerNames(String declared) {
    final names = _containerViews();
    // The variables with the same name as the declared one come first.
    return [...names.where((n) => n.name == declared), ...names.where((n) => n.name != declared)];
  }

  Future<void> _pick() async {
    final l = context.l10n;
    final names = _containerNames(widget.declared[_index].name);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          key: const Key('env-pick-sheet'),
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l.celautEnvAskPickTitle, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (names.isEmpty)
              Padding(
                key: const Key('env-pick-empty'),
                padding: const EdgeInsets.all(16),
                child: Text(l.celautEnvAskPickEmpty),
              ),
            for (final n in names)
              ListTile(
                key: Key('env-pick-${n.name}'),
                title: Text(n.name, style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 14)),
                subtitle: Text('••••••••  ·  ${n.sensitive ? l.celautEnvSensitive : l.celautEnvNotSensitive}'),
                onTap: () => Navigator.pop(context, n.name),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) _answer(EnvFromContainer(picked));
  }

  void _useTyped() {
    final problem = envValueProblem(_typedCtrl.text);
    if (problem != null) {
      setState(() => _typedError = envProblemText(context.l10n, problem));
      return;
    }
    _answer(EnvTyped(_typedCtrl.text, sensitive: _typedSensitive, save: _typedSave));
  }

  bool get _chat => widget.purpose == EnvQuestionsPurpose.chat;

  /// Save the typed values that the user asked to keep, then give the choices. A value that
  /// cannot be saved is still used; the user sees that it was not saved.
  void _confirm(List<EnvChoice> choices) {
    var failed = false;
    for (var i = 0; i < widget.declared.length; i++) {
      final answer = _answers[i];
      if (answer is! EnvTyped || !answer.save) continue;
      try {
        _store.set(widget.declared[i].name, answer.text, sensitive: answer.sensitive);
      } catch (_) {
        failed = true;
      }
    }
    if (failed) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.l10n.celautEnvSaveFailed)));
    }
    Navigator.pop(context, choices);
  }

  String _describe(AppLocalizations l, EnvAnswer? a) => switch (a) {
        EnvFromContainer(:final name) => l.celautEnvReviewFromContainer(name),
        EnvTyped() => l.celautEnvReviewTyped,
        EnvSkipped() || null => l.celautEnvReviewSkipped,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final total = widget.declared.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Back goes to the earlier variable; on the first one it cancels the launch.
        if (_index > 0) {
          _go(_index - 1);
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_chat ? l.celautSecretAskTitle : l.celautEnvAskTitle),
          leading: IconButton(
            key: const Key('env-cancel'),
            tooltip: l.commonCancel,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ReadableWidth(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
            children: _review ? _reviewPage(l) : _questionPage(l, _index, total),
          ),
        ),
      ),
    );
  }

  List<Widget> _questionPage(AppLocalizations l, int i, int total) {
    final colors = ArgusColors.of(context);
    final v = widget.declared[i];
    final usable = envNameProblem(v.name) == null;
    final text = v.prose.isNotEmpty ? v.prose : (v.tags.isNotEmpty ? v.tags.join(', ') : l.celautEnvAskNoText);
    final chosen = _answers[i];
    return [
      Text(
        l.celautEnvAskStep(i + 1, total),
        key: const Key('env-step'),
        style: TextStyle(fontSize: 12.5, color: colors.muted),
      ),
      const SizedBox(height: 8),
      Text(v.name, key: const Key('env-var-name'), style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 20)),
      const SizedBox(height: 8),
      Text(text, key: const Key('env-var-text')),
      if (_egress.steered.containsKey(v.name))
        Padding(
          key: const Key('env-egress-steers'),
          padding: const EdgeInsets.only(top: 8),
          child: Text(l.celautEnvEgressSteers, style: TextStyle(fontSize: 12.5, color: colors.muted)),
        ),
      if (chosen != null) ...[
        const SizedBox(height: 8),
        Text(l.celautEnvAskChosen(_describe(l, chosen)), style: TextStyle(fontSize: 12.5, color: colors.muted)),
      ],
      const SizedBox(height: 16),
      if (!usable)
        Padding(
          key: const Key('env-bad-name'),
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(l.celautEnvAskBadName),
        )
      else ...[
        OutlinedButton.icon(
          key: const Key('env-ask-pick'),
          onPressed: _pick,
          icon: const Icon(Icons.inventory_2_outlined),
          label: Text(l.celautEnvAskPick),
        ),
        const SizedBox(height: 8),
        if (!_typing)
          OutlinedButton.icon(
            key: const Key('env-ask-type'),
            onPressed: () => setState(() => _typing = true),
            icon: const Icon(Icons.edit_outlined),
            label: Text(l.celautEnvAskType),
          )
        else ...[
          TextField(
            key: const Key('env-typed'),
            controller: _typedCtrl,
            autofocus: true,
            obscureText: _hidden,
            autocorrect: false,
            enableSuggestions: false,
            // The action key of the keyboard does what "Use this value" does.
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _useTyped(),
            decoration: InputDecoration(
              labelText: l.celautEnvValue,
              errorText: _typedError,
              errorMaxLines: 3,
              suffixIcon: IconButton(
                key: const Key('env-typed-eye'),
                tooltip: _hidden ? l.celautEnvShow : l.celautEnvHide,
                icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
            ),
          ),
          SwitchListTile(
            key: const Key('env-typed-sensitive'),
            contentPadding: EdgeInsets.zero,
            value: _typedSensitive,
            onChanged: (v) => setState(() => _typedSensitive = v),
            title: Text(l.celautEnvSensitive),
            subtitle: Text(l.celautEnvSensitiveHint, style: TextStyle(fontSize: 12.5, color: colors.muted)),
          ),
          SwitchListTile(
            key: const Key('env-typed-save'),
            contentPadding: EdgeInsets.zero,
            value: _typedSave,
            onChanged: (v) => setState(() => _typedSave = v),
            title: Text(l.celautEnvAskSave),
            subtitle: Text(
              _containerViews().any((n) => n.name == v.name)
                  ? l.celautEnvAskSaveReplaces(v.name)
                  : l.celautEnvAskSaveHint(v.name),
              style: TextStyle(fontSize: 12.5, color: colors.muted),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(key: const Key('env-typed-use'), onPressed: _useTyped, child: Text(l.celautEnvAskUse)),
        ],
        const SizedBox(height: 8),
      ],
      OutlinedButton.icon(
        key: const Key('env-ask-skip'),
        onPressed: () => _answer(const EnvSkipped()),
        icon: const Icon(Icons.not_interested),
        label: Text(l.celautEnvAskSkip),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(l.celautEnvAskSkipHint, style: TextStyle(fontSize: 12.5, color: colors.muted)),
      ),
      if (i > 0)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('env-back'),
            onPressed: () => _go(i - 1),
            child: Text(l.celautEnvAskBack),
          ),
        ),
    ];
  }

  /// One block of the review warning: an icon, a title and a text.
  Widget _warningBlock({required Key key, required IconData icon, required Color color, required String title, required String body}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
                const SizedBox(height: 2),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Where the sensitive values can go, in one card: red if they can leave the node.
  Widget _warningCard(AppLocalizations l, EnvWarnings w) {
    final red = rustFor(context);
    // Only egress is red (the notes of Josemi): the other parts are in the colour of the text,
    // so that red keeps its meaning. The accent of the Celaut palettes is close to red.
    final normal = Theme.of(context).colorScheme.onSurface;
    final border = w.egress ? rust : Theme.of(context).colorScheme.outline;
    final exits = [if (w.anyAddress) l.celautEnvEgressAnyAddress, ...w.hosts].join(', ');
    return Container(
      key: Key(w.egress ? 'env-warning-egress' : 'env-warning'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
      decoration: BoxDecoration(
        color: w.egress ? rust.withValues(alpha: 0.10) : null,
        border: Border.all(color: border, width: w.egress ? 2 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (w.egress)
            _warningBlock(
              key: const Key('env-warn-egress'),
              icon: Icons.report_outlined,
              color: red,
              title: l.celautEnvEgressTitle,
              body: l.celautEnvEgressBody(exits),
            ),
          if (w.local.isNotEmpty)
            _warningBlock(
              key: const Key('env-warn-networks'),
              icon: Icons.hub_outlined,
              color: w.egress ? red : normal,
              title: l.celautEnvNetworksTitle,
              body: l.celautEnvNetworksBody(w.local.join(', ')),
            ),
          if (w.untrusted.isNotEmpty)
            _warningBlock(
              key: const Key('env-warn-nodes'),
              icon: Icons.dns_outlined,
              color: w.egress ? red : normal,
              title: l.celautEnvNodesTitle,
              body: l.celautEnvNodesBody(w.untrusted.map((n) => n.address).join(', ')),
            ),
        ],
      ),
    );
  }

  List<Widget> _reviewPage(AppLocalizations l) {
    final colors = ArgusColors.of(context);
    final marks = {for (final n in _containerViews()) n.name: n.sensitive};
    final warnings = _warnings(marks);
    final choices = envChoices(widget.declared, _answers);
    return [
      Text(l.celautEnvReviewTitle, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (warnings.any) _warningCard(l, warnings),
      for (var i = 0; i < widget.declared.length; i++)
        ListTile(
          key: Key('env-review-${widget.declared[i].name}'),
          contentPadding: EdgeInsets.zero,
          title: Text(widget.declared[i].name, style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 14)),
          subtitle: Text(
            _isSensitive(_answers[i], marks)
                ? '${_describe(l, _answers[i])} · ${l.celautEnvSensitive}'
                : _describe(l, _answers[i]),
          ),
        ),
      const SizedBox(height: 8),
      Text(
        _chat ? l.celautSecretReviewNote : l.celautEnvReviewNote,
        key: const Key('env-review-note'),
        style: TextStyle(fontSize: 12.5, color: colors.muted),
      ),
      const SizedBox(height: 16),
      if (warnings.egress) ...[
        // The values can leave the node: Deny is the default, and it sends nothing.
        FilledButton(
          key: const Key('env-deny'),
          autofocus: true,
          onPressed: () => Navigator.pop(context),
          child: Text(l.celautEnvDeny),
        ),
        TextButton(
          key: const Key('env-run'),
          style: TextButton.styleFrom(foregroundColor: rustFor(context)),
          onPressed: () => _confirm(choices),
          child: Text(_chat ? l.celautSecretSendAnyway : l.celautEnvRunAnyway),
        ),
      ] else
        FilledButton(
          key: const Key('env-run'),
          onPressed: () => _confirm(choices),
          child: Text(_chat ? l.celautSecretSend : l.celautEnvRun),
        ),
      TextButton(
        key: const Key('env-back'),
        onPressed: () => _go(widget.declared.length - 1),
        child: Text(l.celautEnvAskBack),
      ),
    ];
  }
}
