import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../bridge/api/celaut_service.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/launcher.dart';
import '../../celaut/service_strings.dart';
import '../../l10n/l10n.dart';
import '../home/home_style.dart';

/// What the user chose in the confirmation of a launch.
class RunChoice {
  const RunChoice({this.minSurvival, this.keepAlive = false, this.budgetMu});

  /// The least time that the instance must run; null for the default start balance.
  final Duration? minSurvival;

  /// The instance runs until the user stops it: the app tops it up (Josemi, 2026-10-29).
  final bool keepAlive;

  /// With [keepAlive], the most that the app may move to the instance, in MU; null is no
  /// limit.
  final String? budgetMu;
}

/// The last minimum time that the user typed, in minutes, for the next confirmation.
const minSurvivalKey = 'celaut_min_survival_minutes_v1';

/// "5 min", "2 h 10 min", "3 d 4 h".
String formatSurvival(Duration d) {
  final days = d.inDays, hours = d.inHours % 24, minutes = d.inMinutes % 60;
  if (days > 0) return hours > 0 ? '$days d $hours h' : '$days d';
  if (hours > 0) return minutes > 0 ? '$hours h $minutes min' : '$hours h';
  return '${d.inMinutes} min';
}

/// Ask before a launch: an instance uses credit until it stops. The dialog shows the node
/// that the balancer would use now, with its start cost, and a field for the least time
/// that the instance must run (Josemi, 2026-10-23). With a time, the estimate is the start
/// cost with the balance for that time on that node ([survivalBalanceMu]); without one,
/// the app uses its default start balance, and the dialog says how long it lasts there.
/// A second mode, "until I stop it" (Josemi, 2026-10-29), has no time: the app tops the
/// instance up while the user does not stop it. The dialog warns that this uses the credit
/// of the user on the node, and has an optional limit. Never remembered: each launch starts
/// in the mode by time.
/// Gives the choice of the user, or null if the user cancelled.
Future<RunChoice?> showRunConfirmation(
  BuildContext context, {
  required String name,
  required Future<QuoteView?> quote,
  required void Function(QuoteView? best) onDetails,
}) async {
  String initial = '';
  try {
    final prefs = await SharedPreferences.getInstance();
    final kept = prefs.getInt(minSurvivalKey);
    if (kept != null && kept > 0) initial = '$kept';
  } catch (_) {
    // No preferences (a test): the field starts empty.
  }
  if (!context.mounted) return null;
  final choice = await showDialog<RunChoice>(
    context: context,
    builder: (_) => _RunConfirmDialog(name: name, quote: quote, onDetails: onDetails, initial: initial),
  );
  if (choice != null) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final minutes = choice.minSurvival?.inMinutes;
      // The mode "until I stop it" has no time: the time that was kept stays.
      if (choice.keepAlive) {
        // Nothing to keep.
      } else if (minutes == null) {
        await prefs.remove(minSurvivalKey);
      } else {
        await prefs.setInt(minSurvivalKey, minutes);
      }
    } catch (_) {
      // Not kept: the next confirmation starts empty.
    }
  }
  return choice;
}

class _RunConfirmDialog extends StatefulWidget {
  const _RunConfirmDialog({
    required this.name,
    required this.quote,
    required this.onDetails,
    required this.initial,
  });

  final String name;
  final Future<QuoteView?> quote;
  final void Function(QuoteView? best) onDetails;
  final String initial;

  @override
  State<_RunConfirmDialog> createState() => _RunConfirmDialogState();
}

class _RunConfirmDialogState extends State<_RunConfirmDialog> {
  late final _minutes = TextEditingController(text: widget.initial);
  final _budget = TextEditingController();

  /// The mode "until I stop it".
  bool _keepAlive = false;

  @override
  void dispose() {
    _minutes.dispose();
    _budget.dispose();
    super.dispose();
  }

  /// The limit typed, in MU: null if empty (no limit), `BigInt.zero` marks a wrong value.
  BigInt? get _limit {
    final text = _budget.text.trim();
    if (text.isEmpty) return null;
    final v = BigInt.tryParse(text);
    return v == null || v <= BigInt.zero ? BigInt.zero : v;
  }

  /// The time typed, null if the field is empty; [Duration.zero] marks a wrong value.
  Duration? get _survival {
    final text = _minutes.text.trim();
    if (text.isEmpty) return null;
    final minutes = int.tryParse(text);
    if (minutes == null || minutes <= 0) return Duration.zero;
    final d = Duration(minutes: minutes);
    return d > maxMinSurvival ? Duration.zero : d;
  }

  /// The price per hour of the node and the credit of the user there, for the mode "until
  /// I stop it".
  String _keepEstimate(BuildContext context, QuoteView best) {
    final l = context.l10n;
    final price = quotePrice(best);
    final credit = BigInt.tryParse(best.clientBalanceMu);
    if (price == null) return l.celautKeepCredit(muOrUnknown(best.clientBalanceMu));
    final perHour = price.addFor(const Duration(hours: 1));
    final lasts = credit == null ? null : price.lasts(credit);
    if (lasts == null) return l.celautKeepRateOnly(muOrUnknown('$perHour'));
    final low = lasts < const Duration(hours: 6);
    return '${l.celautKeepRate(muOrUnknown('$perHour'), muOrUnknown(best.clientBalanceMu), formatSurvival(lasts))}'
        '${low ? '\n${l.celautKeepLowCredit}' : ''}';
  }

  String _estimate(BuildContext context, QuoteView best) {
    final l = context.l10n;
    final survival = _survival;
    final defaultBalance = BigInt.parse(ServiceStrings.initialDefault);
    if (survival == null) {
      final lasts = survivalOf(best, defaultBalance);
      return lasts == null
          ? l.celautRunDefaultBalance(muOrUnknown(ServiceStrings.initialDefault))
          : l.celautRunDefaultBalanceLasts(muOrUnknown(ServiceStrings.initialDefault), formatSurvival(lasts));
    }
    final need = survivalBalanceMu(best, survival);
    if (need == null) return l.celautRunSurvivalNoPrice;
    final cost = startCostWith(best, defaultBalance, need);
    return l.celautRunSurvivalEstimate(
      muOrUnknown(cost?.toString()),
      muOrUnknown(need.toString()),
      formatSurvival(survival),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final survival = _survival;
    final wrong = survival == Duration.zero;
    return AlertDialog(
      key: const Key('run-confirm'),
      title: Text(l.celautRunConfirmTitle(widget.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.celautRunConfirmBody),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              key: const Key('run-confirm-mode'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(l.celautRunModeTime)),
                ButtonSegment(value: true, label: Text(l.celautRunModeKeep)),
              ],
              selected: {_keepAlive},
              onSelectionChanged: (v) => setState(() => _keepAlive = v.first),
            ),
            const SizedBox(height: 12),
            if (!_keepAlive)
              TextField(
                key: const Key('run-confirm-minutes'),
                controller: _minutes,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 5,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l.celautRunSurvivalLabel,
                  hintText: l.celautRunSurvivalHint,
                  suffixText: 'min',
                  errorText: wrong ? l.celautRunSurvivalWrong : null,
                  counterText: '',
                  isDense: true,
                ),
              )
            else ...[
              _KeepWarning(text: l.celautKeepWarning),
              const SizedBox(height: 12),
              TextField(
                key: const Key('run-confirm-limit'),
                controller: _budget,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l.celautKeepLimitLabel,
                  hintText: l.celautKeepLimitHint,
                  suffixText: 'MU',
                  errorText: _limit == BigInt.zero ? l.celautKeepLimitWrong : null,
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 8),
            FutureBuilder<QuoteView?>(
              future: widget.quote,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Text(l.celautRunPreviewLoading, style: t.secondary);
                }
                final best = snapshot.hasError ? null : snapshot.data;
                if (best == null) {
                  return Text(l.celautRunConfirmNoQuote, key: const Key('run-confirm-quote'), style: t.secondary);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.celautRunPreview('${best.address.host}:${best.address.port}', muOrUnknown(best.costMu)),
                      key: const Key('run-confirm-quote'),
                      style: t.secondary,
                    ),
                    if (_keepAlive) ...[
                      const SizedBox(height: 4),
                      Text(_keepEstimate(context, best), key: const Key('run-confirm-keep'), style: t.secondary),
                    ] else if (!wrong) ...[
                      const SizedBox(height: 4),
                      Text(_estimate(context, best), key: const Key('run-confirm-survival'), style: t.secondary),
                    ],
                  ],
                );
              },
            ),
            // The details are a link of the content, not a third action: three actions
            // took three rows on a small screen, and left one line for the content.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('run-confirm-details'),
                onPressed: () async {
                  QuoteView? best;
                  try {
                    best = await widget.quote;
                  } catch (_) {
                    // No quote: the details read the library file, or say that there is none.
                  }
                  widget.onDetails(best);
                },
                icon: const Icon(Icons.info_outline),
                label: Text(l.celautRunConfirmDetails),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('run-confirm-cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(l.celautSendCancel),
        ),
        FilledButton(
          key: const Key('run-confirm-ok'),
          // The theme gives a filled button the full width, which puts each action on a
          // row of its own. Here Run is next to Cancel, as in a dialog of Material.
          style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
          onPressed: _keepAlive
              ? (_limit == BigInt.zero ? null : () => Navigator.pop(context, RunChoice(keepAlive: true, budgetMu: _limit?.toString())))
              : (wrong ? null : () => Navigator.pop(context, RunChoice(minSurvival: survival))),
          child: Text(_keepAlive ? l.celautRunButtonKeep : l.celautRunButton),
        ),
      ],
    );
  }
}

/// The warning of the mode "until I stop it": it uses the credit of the user, and it is
/// always on screen in that mode.
class _KeepWarning extends StatelessWidget {
  const _KeepWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('run-confirm-warning'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: scheme.onErrorContainer))),
        ],
      ),
    );
  }
}
