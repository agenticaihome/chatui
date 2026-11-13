import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_service.dart';
import '../../bridge/api/celaut_spending.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/maintenance_price.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';
import 'run_confirm_dialog.dart' show formatSurvival;

/// Move MU between the credit of the user on a node and an instance (issue #136).
typedef MoveMu = Future<TopUpView> Function(String instanceId, String amountMu, bool takeBack);

Future<TopUpView> _moveMu(String instanceId, String amountMu, bool takeBack) =>
    celautMoveInstanceMu(instanceId: instanceId, amountMu: amountMu, takeBack: takeBack);

/// The sheet of "Add MU" or "Take back MU" ([takeBack]) for a running instance: an amount
/// (typed, or a quick value), the balance of the instance and the credit of the user on the
/// node before and after, the fee, and a note when the automatic top-up is on. The move
/// needs a second yes in a dialog: it moves money. Gives the balances after the move, or
/// null if nothing moved.
Future<TopUpView?> showMoveMuSheet(
  BuildContext context, {
  required String instanceId,
  required bool takeBack,
  required String node,
  required BigInt? balance,
  required BigInt? credit,
  required bool autoTopUp,
  MaintenancePrice? price,
  MoveMu? move,
  VoidCallback? openDeposit,
}) =>
    showModalBottomSheet<TopUpView>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MoveMuSheet(
        instanceId: instanceId,
        takeBack: takeBack,
        node: node,
        balance: balance,
        credit: credit,
        autoTopUp: autoTopUp,
        price: price,
        move: move ?? _moveMu,
        openDeposit: openDeposit,
      ),
    );

/// The body of [showMoveMuSheet].
class MoveMuSheet extends StatefulWidget {
  const MoveMuSheet({
    super.key,
    required this.instanceId,
    required this.takeBack,
    required this.node,
    required this.balance,
    required this.credit,
    required this.autoTopUp,
    required this.move,
    this.price,
    this.openDeposit,
  });

  final String instanceId;
  final bool takeBack;

  /// The node of the instance, as the user knows it (`host:port`).
  final String node;

  /// The balance of the instance and the credit of the user on the node, in MU; null if
  /// the app could not read them.
  final BigInt? balance;
  final BigInt? credit;

  /// The automatic top-up is on for this instance.
  final bool autoTopUp;

  /// The price of the node, to say how long the balance lasts after the move.
  final MaintenancePrice? price;
  final MoveMu move;
  final VoidCallback? openDeposit;

  @override
  State<MoveMuSheet> createState() => _MoveMuSheetState();
}

class _MoveMuSheetState extends State<MoveMuSheet> {
  final _amount = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  BigInt? get _value => BigInt.tryParse(_amount.text.trim());

  /// What the move is limited by: the credit to add, the balance of the instance to take back.
  BigInt? get _limit => widget.takeBack ? widget.balance : widget.credit;

  /// Why the amount cannot move; null if it can.
  String? _problem(AppLocalizations l) {
    final v = _value;
    if (_amount.text.trim().isEmpty) return null;
    if (v == null || v <= BigInt.zero) return l.celautMoveZero;
    final limit = _limit;
    if (limit != null && v > limit) {
      return widget.takeBack
          ? l.celautMoveOverBalance(muOrUnknown('$limit'))
          : l.celautMoveOverCredit(muOrUnknown('$limit'));
    }
    return null;
  }

  bool get _ready {
    final v = _value;
    return v != null && v > BigInt.zero && _problem(context.l10n) == null && _limit != null;
  }

  /// "before → after", or the value before if the amount is not valid.
  String _change(BigInt? before, BigInt sign) {
    if (before == null) return context.l10n.celautUnknown;
    final v = _value;
    if (v == null || v <= BigInt.zero) return muOrUnknown('$before');
    return '${muOrUnknown('$before')} → ${muOrUnknown('${before + sign * v}')}';
  }

  void _quick(BigInt value) {
    setState(() {
      _amount.text = '$value';
      _error = null;
    });
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final v = _value;
    if (v == null || !_ready) return;
    final amount = muOrUnknown('$v');
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('move-mu-confirm'),
        title: Text(widget.takeBack ? l.celautMoveConfirmTakeBackTitle : l.celautMoveConfirmAddTitle),
        content: Text(
          widget.takeBack
              ? l.celautMoveConfirmTakeBackBody(amount, widget.node)
              : l.celautMoveConfirmAddBody(amount, widget.node),
        ),
        actions: [
          TextButton(
            key: const Key('move-mu-confirm-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.celautSendCancel),
          ),
          FilledButton(
            key: const Key('move-mu-confirm-ok'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.celautMoveConfirm),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final after = await widget.move(widget.instanceId, '$v', widget.takeBack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.celautMoveDone(muOrUnknown(after.instanceBalanceMu), muOrUnknown(after.clientBalanceMu)),
          ),
        ),
      );
      Navigator.pop(context, after);
    } on CelautError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (e.kind) {
          CelautErrorKind.protocol => l.celautMoveRefused(e.message),
          CelautErrorKind.insufficientCredit => l.celautMoveOverCredit(muOrUnknown(widget.credit?.toString())),
          CelautErrorKind.invalidInput => e.message,
          _ => CelautStrings.errorText(e.kind),
        };
      });
    }
  }

  void _deposit() {
    Navigator.pop(context);
    widget.openDeposit?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final take = widget.takeBack;
    final problem = _problem(l);
    final limit = _limit;
    final v = _value;
    // How long the instance lasts after the move, at the price of the node now.
    String? lasts;
    final price = widget.price;
    final balance = widget.balance;
    if (price != null && balance != null && v != null && v > BigInt.zero && problem == null) {
      final after = take ? balance - v : balance + v;
      final d = price.lasts(after);
      lasts = d == Duration.zero ? l.celautMoveStops : l.celautMoveLasts(formatSurvival(d));
    }
    final quick = <(String, BigInt)>[
      if (take && balance != null && balance > BigInt.one) (l.celautMoveHalf, balance ~/ BigInt.two),
      if (take && balance != null && balance > BigInt.zero) (l.celautMoveAll, balance),
      if (!take)
        for (final n in [100000, 1000000, 10000000])
          if (widget.credit == null || BigInt.from(n) <= widget.credit!)
            ('+${groupMu('$n')}', BigInt.from(n)),
    ];
    final short = !take && limit != null && v != null && v > limit;
    Widget row(String label, String value, Key key) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: t.label),
              const SizedBox(height: 2),
              Text(value, key: key, style: t.primary),
            ],
          ),
        );
    return Padding(
      key: Key(take ? 'move-mu-sheet-back' : 'move-mu-sheet-add'),
      // The keyboard, or else the navigation bar of the system: the button must stay
      // above both (a tap under the bar is a tap on Home).
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + max(MediaQuery.viewInsetsOf(context).bottom, MediaQuery.paddingOf(context).bottom),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(take ? l.celautMoveTakeBack : l.celautMoveAdd, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (quick.isNotEmpty)
              Wrap(
                spacing: 8,
                children: [
                  for (final (label, value) in quick)
                    ActionChip(
                      key: Key('move-mu-chip-$value'),
                      label: Text(label),
                      onPressed: _busy ? null : () => _quick(value),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('move-mu-amount'),
              controller: _amount,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 24,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: l.celautMoveAmount,
                suffixText: 'MU',
                errorText: problem,
                errorMaxLines: 3,
                counterText: '',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            row(l.celautMoveInstanceRow, _change(widget.balance, take ? BigInt.from(-1) : BigInt.one),
                const Key('move-mu-balance')),
            row(l.celautMoveCreditRow, _change(widget.credit, take ? BigInt.one : BigInt.from(-1)),
                const Key('move-mu-credit')),
            if (widget.balance == null || widget.credit == null)
              Text(l.celautMoveNoBalance, key: const Key('move-mu-no-balance'),
                  style: t.secondary.copyWith(color: rustFor(context))),
            if (lasts != null) Text(lasts, key: const Key('move-mu-lasts'), style: t.secondary),
            const SizedBox(height: 4),
            Text(l.celautMoveFee, key: const Key('move-mu-fee'), style: t.secondary),
            if (widget.autoTopUp) ...[
              const SizedBox(height: 8),
              Text(
                take ? l.celautMoveAutoOnTakeBack : l.celautMoveAutoOnAdd,
                key: const Key('move-mu-auto'),
                style: t.secondary.copyWith(color: take ? rustFor(context) : null),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, key: const Key('move-mu-error'), style: t.secondary.copyWith(color: rustFor(context))),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (short && widget.openDeposit != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('move-mu-deposit'),
                      onPressed: _deposit,
                      child: Text(l.celautTopUpNeedDeposit),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton(
                    key: const Key('move-mu-ok'),
                    onPressed: _busy || !_ready ? null : _submit,
                    child: Text(take ? l.celautMoveTakeBack : l.celautMoveAdd),
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
