import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../celaut/auto_top_up.dart';
import '../../l10n/l10n.dart';
import '../home/home_style.dart';
import '../layout.dart';

/// Settings, Compute, "Keep running" (Josemi, 2026-10-29): when the app tops up an instance
/// that the user asked to keep running, and how much time each top-up gives ([AutoTopUp]).
/// The switch is not here: it is per instance, at the launch and on its info page.
///
/// The app never pays a node by itself: a top-up moves credit that the app already has on
/// the node, and with too little credit the app asks the user, who can make a deposit with
/// its own confirmation.
class AutoTopUpScreen extends StatefulWidget {
  const AutoTopUpScreen({super.key, this.topUp});

  /// The keep-alive engine of the app. Tests give their own.
  final AutoTopUp? topUp;

  @override
  State<AutoTopUpScreen> createState() => _AutoTopUpScreenState();
}

class _AutoTopUpScreenState extends State<AutoTopUpScreen> {
  late final AutoTopUp _topUp = widget.topUp ?? autoTopUp;
  final _threshold = TextEditingController();
  final _chunk = TextEditingController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _topUp.load().then((_) {
      if (!mounted) return;
      setState(() {
        _threshold.text = '${_topUp.threshold.inMinutes}';
        _chunk.text = '${_topUp.chunk.inMinutes}';
        _ready = true;
      });
    });
  }

  @override
  void dispose() {
    _threshold.dispose();
    _chunk.dispose();
    super.dispose();
  }

  Duration? _value(TextEditingController c, Duration max) {
    final m = int.tryParse(c.text.trim());
    if (m == null) return null;
    final d = Duration(minutes: m);
    return d < AutoTopUp.minTime || d > max ? null : d;
  }

  String? _error(TextEditingController c, Duration max) => _value(c, max) == null
      ? context.l10n.celautTopUpRange('${AutoTopUp.minTime.inMinutes}', '${max.inMinutes}')
      : null;

  Future<void> _save() async {
    final threshold = _value(_threshold, AutoTopUp.maxThreshold);
    final chunk = _value(_chunk, AutoTopUp.maxChunk);
    if (threshold == null || chunk == null) {
      setState(() {});
      return;
    }
    await _topUp.save(threshold: threshold, chunk: chunk);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.celautTopUpSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.celautTopUpTitle)),
      body: ReadableWidth(
        child: !_ready
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.fromLTRB(homeGutter, 8, homeGutter, 32 + MediaQuery.paddingOf(context).bottom),
                children: [
                  Text(l.celautTopUpIntro, key: const Key('top-up-intro'), style: t.secondary),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('top-up-threshold'),
                    controller: _threshold,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      labelText: l.celautTopUpThreshold,
                      suffixText: 'min',
                      errorText: _error(_threshold, AutoTopUp.maxThreshold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('top-up-amount'),
                    controller: _chunk,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      labelText: l.celautTopUpAmount,
                      suffixText: 'min',
                      errorText: _error(_chunk, AutoTopUp.maxChunk),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      key: const Key('top-up-save'),
                      // The theme asks for the full width; this button is alone in its row.
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: _save,
                      child: Text(l.commonSave),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(l.celautTopUpNote, key: const Key('top-up-note'), style: t.secondary),
                  const SizedBox(height: 12),
                  Text(l.celautTopUpWindowNote, key: const Key('top-up-window-note'), style: t.secondary),
                ],
              ),
      ),
    );
  }
}
