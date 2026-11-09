import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/auto_top_up.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/maintenance_price.dart';
import '../../celaut/payers.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';
import 'deposit_screen.dart';
import 'run_confirm_dialog.dart' show formatSurvival;

/// "Time and credit" on the info page of a running instance (Josemi, 2026-10-29): how long
/// the instance lasts, the credit of the user on its node (what is left to spend), the
/// switch "keep it running until I stop it", and "Add time" for an instance that is not
/// kept. Nothing shows if the app does not know the instance (no plan).
///
/// The switch is the dangerous one: the app moves the credit of the user to the instance
/// until the user stops it. Turning it on asks again, with the warning and an optional
/// limit, and needs the wallet open. Turning it off moves nothing: the instance runs on
/// what it has.
class InstanceTimeSection extends StatefulWidget {
  const InstanceTimeSection({
    super.key,
    required this.instanceId,
    this.topUp,
    this.wallets = const AppFullWallets(),
    this.loadStatus,
    this.loadCredit,
    this.openDeposit,
  });

  final String instanceId;

  /// The keep-alive engine. Tests give their own.
  final AutoTopUp? topUp;

  final FullWallets wallets;

  /// Read the balance of the instance and the credit of the user on its node. Tests give
  /// their own.
  final Future<InstanceStatusView> Function(String instanceId)? loadStatus;
  final Future<String> Function(String instanceId)? loadCredit;

  /// Open the deposit screen. Tests give their own.
  final VoidCallback? openDeposit;

  @override
  State<InstanceTimeSection> createState() => _InstanceTimeSectionState();
}

class _InstanceTimeSectionState extends State<InstanceTimeSection> {
  late final AutoTopUp _engine = widget.topUp ?? autoTopUp;
  InstancePlanView? _plan;
  BigInt? _balance;
  BigInt? _credit;

  @override
  void initState() {
    super.initState();
    _plan = _engine.planOf(widget.instanceId);
    unawaited(_reload());
  }

  /// Read the plan and ask the node for the balance and the credit.
  Future<void> _reload() async {
    final plan = _engine.planOf(widget.instanceId);
    if (mounted) setState(() => _plan = plan);
    final id = widget.instanceId;
    try {
      final status = await (widget.loadStatus ?? (id) => celautInstanceStatus(instanceId: id))(id);
      if (mounted) setState(() => _balance = BigInt.tryParse(status.instanceBalanceMu));
    } on Object {
      // The node does not answer: the page says what it knows.
    }
    try {
      final credit = await (widget.loadCredit ?? (id) => celautInstanceCredit(instanceId: id))(id);
      if (mounted) setState(() => _credit = BigInt.tryParse(credit));
    } on Object {
      // Unknown credit.
    }
  }

  MaintenancePrice? get _price => _plan == null ? null : AutoTopUp.priceOf(_plan!);

  Future<void> _toggle(bool on) async {
    final l = context.l10n;
    if (!on) {
      try {
        _engine.setKeepAlive(widget.instanceId, enabled: false);
      } on CelautError catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CelautStrings.errorText(e.kind))));
        }
      }
      await _reload();
      return;
    }
    final limit = await showDialog<_Limit>(context: context, builder: (_) => const _KeepDialog());
    if (limit == null || !mounted) return;
    if (!await ensureOpenFullWallet(context, widget.wallets) || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.celautOpenFullWalletNeeded)));
      }
      return;
    }
    try {
      _engine.setKeepAlive(widget.instanceId, enabled: true, budgetMu: limit.mu);
    } on CelautError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CelautStrings.errorText(e.kind))));
      }
    }
    await _reload();
  }

  Future<void> _add() async {
    final price = _price;
    if (price == null) return;
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddTimeSheet(
        instanceId: widget.instanceId,
        engine: _engine,
        price: price,
        credit: _credit,
        openDeposit: widget.openDeposit,
      ),
    );
    if (added == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    if (plan == null) return const SizedBox.shrink();
    final l = context.l10n;
    final t = HomeText.of(context);
    final price = _price;
    final left = price == null || _balance == null ? null : price.lasts(_balance!);
    final creditTime = price == null || _credit == null ? null : price.lasts(_credit!);
    final keep = plan.keepAlive;
    final limit = plan.budgetMu;
    Widget row(String label, String value, Key key) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: t.label),
              const SizedBox(height: 2),
              SelectableText(value, key: key, style: t.primary),
            ],
          ),
        );
    return Column(
      key: const Key('info-time'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.celautTimeTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (_balance != null)
          row(
            l.celautTimeBalance,
            left == null
                ? muOrUnknown('$_balance')
                : '${muOrUnknown('$_balance')} (${l.celautTimeAbout(formatSurvival(left))})',
            const Key('info-time-balance'),
          ),
        row(
          l.celautTimeCredit,
          _credit == null
              ? l.celautUnknown
              : creditTime == null
                  ? muOrUnknown('$_credit')
                  : '${muOrUnknown('$_credit')} (${l.celautTimeAbout(formatSurvival(creditTime))})',
          const Key('info-time-credit'),
        ),
        SwitchListTile(
          key: const Key('info-keep-switch'),
          contentPadding: EdgeInsets.zero,
          title: Text(l.celautKeepSwitch),
          subtitle: Text(
            keep
                ? (limit.isEmpty
                    ? l.celautKeepOnNoLimit(muOrUnknown(plan.spentMu))
                    : l.celautKeepOnLimit(muOrUnknown(plan.spentMu), muOrUnknown(limit)))
                : l.celautKeepOff,
            key: const Key('info-keep-note'),
          ),
          value: keep,
          onChanged: _toggle,
        ),
        if (!keep && price != null)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('info-add-time'),
              onPressed: _add,
              icon: const Icon(Icons.more_time),
              label: Text(l.celautAddTime),
            ),
          ),
      ],
    );
  }
}

/// What the user chose in the question to turn keep-alive on: the limit in MU, null for none.
class _Limit {
  const _Limit(this.mu);
  final String? mu;
}

/// The warning and the optional limit, before keep-alive turns on.
class _KeepDialog extends StatefulWidget {
  const _KeepDialog();

  @override
  State<_KeepDialog> createState() => _KeepDialogState();
}

class _KeepDialogState extends State<_KeepDialog> {
  final _limit = TextEditingController();

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  BigInt? get _value {
    final text = _limit.text.trim();
    if (text.isEmpty) return null;
    final v = BigInt.tryParse(text);
    return v == null || v <= BigInt.zero ? BigInt.zero : v;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final wrong = _value == BigInt.zero;
    return AlertDialog(
      key: const Key('keep-dialog'),
      title: Text(l.celautKeepEnableTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.celautKeepWarning,
                      key: const Key('keep-dialog-warning'),
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('keep-dialog-limit'),
              controller: _limit,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.celautKeepLimitLabel,
                hintText: l.celautKeepLimitHint,
                suffixText: 'MU',
                errorText: wrong ? l.celautKeepLimitWrong : null,
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('keep-dialog-cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(l.celautSendCancel),
        ),
        FilledButton(
          key: const Key('keep-dialog-ok'),
          onPressed: wrong ? null : () => Navigator.pop(context, _Limit(_value?.toString())),
          child: Text(l.celautKeepEnableConfirm),
        ),
      ],
    );
  }
}

/// "Add time": the chips, a field for minutes, the cost, and the credit that is left. If the
/// credit is not enough, it says so and offers a deposit.
class _AddTimeSheet extends StatefulWidget {
  const _AddTimeSheet({
    required this.instanceId,
    required this.engine,
    required this.price,
    required this.credit,
    this.openDeposit,
  });

  final String instanceId;
  final AutoTopUp engine;
  final MaintenancePrice price;
  final BigInt? credit;
  final VoidCallback? openDeposit;

  @override
  State<_AddTimeSheet> createState() => _AddTimeSheetState();
}

class _AddTimeSheetState extends State<_AddTimeSheet> {
  final _minutes = TextEditingController(text: '60');
  bool _busy = false;
  bool _noCredit = false;
  String? _error;

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  /// The time typed; null if it is empty or over 30 days.
  Duration? get _time {
    final m = int.tryParse(_minutes.text.trim());
    if (m == null || m <= 0) return null;
    final d = Duration(minutes: m);
    return d > AutoTopUp.maxChunk ? null : d;
  }

  BigInt? get _cost => _time == null ? null : widget.price.addFor(_time!);

  bool get _short {
    final cost = _cost, credit = widget.credit;
    return cost != null && credit != null && credit < cost;
  }

  Future<void> _add() async {
    final time = _time;
    if (time == null) return;
    setState(() {
      _busy = true;
      _noCredit = false;
      _error = null;
    });
    try {
      await widget.engine.addTime(widget.instanceId, time);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.celautAddTimeDone)));
        Navigator.pop(context, true);
      }
    } on CelautError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _noCredit = e.kind == CelautErrorKind.insufficientCredit;
        _error = _noCredit ? null : CelautStrings.errorText(e.kind);
      });
    }
  }

  void _deposit() {
    Navigator.pop(context, true);
    final open = widget.openDeposit;
    if (open != null) {
      open();
    } else {
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const DepositScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final cost = _cost;
    final credit = widget.credit;
    final short = _short || _noCredit;
    final lasts = credit == null || cost == null || credit < cost ? null : widget.price.lasts(credit - cost);
    return Padding(
      key: const Key('add-time-sheet'),
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.celautAddTime, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final d in const [Duration(minutes: 30), Duration(hours: 1), Duration(days: 1)])
                  ActionChip(
                    key: Key('add-time-chip-${d.inMinutes}'),
                    label: Text('+${formatSurvival(d)}'),
                    onPressed: () => setState(() => _minutes.text = '${d.inMinutes}'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('add-time-minutes'),
              controller: _minutes,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 5,
              onChanged: (_) => setState(() => _noCredit = false),
              decoration: InputDecoration(
                labelText: l.celautAddTimeMinutes,
                suffixText: 'min',
                errorText: _time == null ? l.celautRunSurvivalWrong : null,
                counterText: '',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            if (cost != null)
              Text(
                short
                    ? l.celautAddTimeNoCredit(muOrUnknown('$cost'), muOrUnknown(credit?.toString()))
                    : credit == null
                        ? l.celautAddTimeCostOnly(muOrUnknown('$cost'))
                        : l.celautAddTimeCost(
                            muOrUnknown('$cost'),
                            muOrUnknown('${credit - cost}'),
                            formatSurvival(lasts ?? Duration.zero),
                          ),
                key: const Key('add-time-note'),
                style: short ? t.secondary.copyWith(color: rustFor(context)) : t.secondary,
              ),
            if (_error != null) Text(_error!, style: t.secondary.copyWith(color: rustFor(context))),
            const SizedBox(height: 12),
            Row(
              children: [
                if (short)
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('add-time-deposit'),
                      onPressed: _deposit,
                      child: Text(l.celautTopUpNeedDeposit),
                    ),
                  ),
                if (short) const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const Key('add-time-ok'),
                    onPressed: _busy || _time == null || _short ? null : _add,
                    child: Text(l.celautAddTimeConfirm),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
