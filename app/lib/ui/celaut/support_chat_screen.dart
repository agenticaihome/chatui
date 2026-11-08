import 'dart:async';

import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_service.dart';
import '../../bridge/api/celaut_support.dart';
import '../../celaut/celaut_strings.dart';
import '../../format.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_scene.dart';
import '../layout.dart';

/// What the support chat needs from Rust. The app uses [AppSupportApi]; tests give their own.
abstract class SupportApi {
  Future<SupportThreadView> thread(NodeAddress node, int afterSequence);
  Future<SupportSendView> send(NodeAddress node, String body);
}

class AppSupportApi implements SupportApi {
  const AppSupportApi();

  @override
  Future<SupportThreadView> thread(NodeAddress node, int afterSequence) =>
      celautSupportThread(node: node, afterSequence: BigInt.from(afterSequence));

  @override
  Future<SupportSendView> send(NodeAddress node, String body) => celautSupportSend(node: node, body: body);
}

/// The support chat with the operator of one node (`docs/celaut/support-chat.md`): a plain
/// thread of text messages, for a problem with the node. The node keeps the thread. The
/// screen asks for it when it opens, after each send, and from time to time while it is
/// open. It has no attachments and no streaming.
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({
    super.key,
    required this.node,
    required this.peerId,
    this.api = const AppSupportApi(),
    this.pollInterval = const Duration(seconds: 30),
  });

  final NodeAddress node;
  final String peerId;
  final SupportApi api;
  final Duration pollInterval;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _input = TextEditingController();
  final _messages = <SupportMessageView>[];
  Timer? _timer;
  bool _loading = true;
  bool _supported = true;
  bool _sending = false;
  bool _fetching = false;
  CelautError? _error;

  /// Why the node did not store the last message. Empty if it did.
  String _refused = '';

  int get _last => _messages.isEmpty ? 0 : _messages.last.sequence.toInt();

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(widget.pollInterval, (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (_fetching || !_supported) return;
    _fetching = true;
    try {
      final view = await widget.api.thread(widget.node, _last);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _supported = view.supported;
        // A message already shown has a sequence that is not more than the last one.
        _messages.addAll(view.messages.where((m) => m.sequence.toInt() > _last));
      });
    } on CelautError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    } finally {
      _fetching = false;
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
      _refused = '';
    });
    try {
      final result = await widget.api.send(widget.node, text);
      if (!mounted) return;
      setState(() {
        _supported = result.supported;
        if (result.stored) {
          _input.clear();
        } else if (result.supported) {
          _refused = result.reason;
        }
      });
      if (result.stored) await _fetch();
    } on CelautError catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = ArgusColors.of(context);
    return SceneBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.celautSupportTitle),
              Text(
                shorten(widget.peerId, head: 10, tail: 8),
                style: TextStyle(fontSize: 12, color: colors.muted),
              ),
            ],
          ),
        ),
        body: ReadableWidth(
          child: Column(
            children: [
              Expanded(child: _thread(context)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    '${CelautStrings.errorText(_error!.kind)}\n${_error!.message}',
                    key: const Key('support-error'),
                    style: TextStyle(color: rustFor(context)),
                  ),
                ),
              if (_refused.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    l.celautSupportRefused(_refused),
                    key: const Key('support-refused'),
                    style: TextStyle(color: rustFor(context)),
                  ),
                ),
              if (_supported) _composer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thread(BuildContext context) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(key: Key('support-loading')));
    }
    if (!_supported) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l.celautSupportUnsupported, key: const Key('support-unsupported'), style: TextStyle(color: muted)),
      );
    }
    if (_messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l.celautSupportEmpty, key: const Key('support-empty'), style: TextStyle(color: muted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _bubble(context, _messages[i]),
    );
  }

  Widget _bubble(BuildContext context, SupportMessageView m) {
    final colors = ArgusColors.of(context);
    final mine = !m.fromOperator;
    final when = formatRelativeTime(DateTime.fromMillisecondsSinceEpoch(m.ts.toInt() * 1000));
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        key: Key('support-message-${m.sequence}'),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        decoration: BoxDecoration(
          color: mine ? colors.accent.withValues(alpha: 0.18) : colors.chip,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(m.body),
            const SizedBox(height: 2),
            Text(when, style: TextStyle(fontSize: 11, color: colors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('support-input'),
                controller: _input,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(hintText: l.celautSupportHint),
              ),
            ),
            IconButton(
              key: const Key('support-send'),
              tooltip: l.celautSupportSend,
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
