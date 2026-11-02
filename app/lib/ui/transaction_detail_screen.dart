import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../services/activity_classifier.dart';
import '../services/network_controller.dart';
import '../services/session_lock.dart';
import '../services/token_metadata.dart';
import '../services/wallet_service.dart';
import '../theme/argus_theme.dart';
import 'layout.dart';
import 'widgets/soft_card.dart';

class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key});

  /// Tokens are named and scaled by the one token lookup, like the row this
  /// screen was opened from, and repaint when it learns something.
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: walletService.metadataChanges,
    builder: (context, _, _) => _screen(context),
  );

  Widget _tokenLine(BuildContext context, ({String id, BigInt amount}) t) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          tokenAmountText(t.amount, t.id),
          style: monoStyle(context, size: 12),
        ),
      );

  /// One amount of the wallet-level breakdown: "100 Test Asset 3",
  /// "2.0925 ERG".
  Widget _legLine(BuildContext context, ActivityLeg leg) => _tokenLine(
        context,
        (id: leg.tokenId ?? '', amount: leg.amount.abs()),
      );

  Widget _ergLine(BuildContext context, BigInt nano) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(formatErg(nano.toInt()), style: monoStyle(context, size: 12)),
      );

  List<Widget> _section(BuildContext context, String label, List<Widget> lines) => [
        SectionLabel(label),
        const SizedBox(height: 8),
        ...lines,
        const SizedBox(height: 12),
      ];

  Widget _address(BuildContext context, String address) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SoftCard(
          padding: const EdgeInsets.all(12),
          child: SelectableText(address, style: monoStyle(context, size: 12)),
        ),
      );

  /// What the wallet gave, got, paid and kept, as the row summarised it.
  List<Widget> _breakdown(BuildContext context, WalletActivity a) {
    Widget leg(ActivityLeg l) => l.isErg ? _ergLine(context, l.amount.abs()) : _legLine(context, l);
    // ERG that went to someone else, fees apart.
    final ergOut = a.erg.isNegative ? -a.erg - a.feesPaid : BigInt.zero;
    final left = [
      for (final t in a.sent) leg(t),
      if (ergOut > BigInt.zero) _ergLine(context, ergOut),
    ];
    final arrived = [
      for (final t in a.received) leg(t),
      if (a.erg > BigInt.zero) _ergLine(context, a.erg),
    ];
    final l = context.l10n;
    final fees = [
      if (a.minerFee > BigInt.zero) _feeLine(context, l.commonMinerFee, a.minerFee),
      if (a.appFee > BigInt.zero) _feeLine(context, l.txArgusFee, a.appFee),
    ];
    return [
      if (left.isNotEmpty) ..._section(context, l.txLeftWallet, left),
      if (a.burned.isNotEmpty)
        ..._section(context, l.txBurned, [
          for (final t in a.burned) leg(t),
          Text(
            l.txBurnedNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ]),
      if (a.minted.isNotEmpty) ..._section(context, l.txIssued, [for (final t in a.minted) leg(t)]),
      if (arrived.isNotEmpty) ..._section(context, l.txArrived, arrived),
      if (fees.isNotEmpty) ..._section(context, l.txFees, fees),
      if (a.internalNano > BigInt.zero)
        ..._section(context, l.txMovedBetween, [
          _ergLine(context, a.internalNano),
          Text(
            l.txMovedNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ]),
      if (a.category == ActivityCategory.sent && a.recipients.isNotEmpty)
          ..._section(context, l.txTo, [for (final r in a.recipients) _address(context, r)]),
      if (a.category == ActivityCategory.received && a.senders.isNotEmpty)
        ..._section(context, l.txFrom, [for (final s in a.senders.take(5)) _address(context, s)]),
      if (a.contract case final c?) ..._section(context, l.txContract, [_address(context, c)]),
      if (!a.flows.complete)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            l.txIncompleteInputs,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ];
  }

  Widget _feeLine(BuildContext context, String label, BigInt nano) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text('$label ${formatErg(nano.toInt())}', style: Theme.of(context).textTheme.bodyMedium),
      );

  Widget _screen(BuildContext context) {
    final args = WalletRouteArgs.of(context);
    final tx = args.transaction ?? const {};
    final txId = tx['tx_id']?.toString() ?? '';
    final height = (tx['height'] as num?)?.toInt();
    final ts = (tx['timestamp'] as num?)?.toInt();
    final nano = (tx['value_nano_erg'] as num?)?.toInt();
    final rawTokens = tx['token_ids'];
    final tokens = rawTokens is List ? rawTokens.map((e) => e.toString()).toList() : const <String>[];
    final received = (tx['tokens_received'] as List?)
            ?.whereType<Map>()
            .map((m) => (
                  id: m['token_id']?.toString() ?? '',
                  amount: BigInt.from((m['amount'] as num?)?.toInt() ?? 0),
                ))
            .toList() ??
        const <({String id, BigInt amount})>[];
    final confirmed = height != null && height > 0;
    // The wallet-level reading, when the row carries its flows.
    final view = describeActivity(tx, name: (id) => tokenName(id));
    final activity = view.activity;
    final outgoing = activity != null
        ? view.kind == ActivityKind.sent || (activity.erg.isNegative && view.kind != ActivityKind.received)
        : nano != null && nano < 0;
    final fee = (tx['fee_nano_erg'] as num?)?.toInt();
    final counterparty = tx['counterparty']?.toString();
    final sent = (tx['tokens_sent'] as List?)
            ?.whereType<Map>()
            .map((m) => (
                  id: m['token_id']?.toString() ?? '',
                  amount: BigInt.from((m['amount'] as num?)?.toInt() ?? 0),
                ))
            .toList() ??
        const <({String id, BigInt amount})>[];
    // Compare identities, not lengths: token_ids may repeat and arrivals
    // cover a subset of the unique ids.
    final missingTokenIds =
        tokens.toSet().difference(received.map((r) => r.id).toSet());
    final tint = activity != null && view.kind != ActivityKind.sent && view.kind != ActivityKind.received
        ? accentTextOf(context)
        : outgoing
            ? rust
            : moss;
    final icon = switch (view.kind) {
      ActivityKind.received => Icons.arrow_downward,
      ActivityKind.sent => Icons.arrow_upward,
      ActivityKind.selfTransfer => Icons.sync_alt,
      ActivityKind.contract => Icons.code,
    };
    String figure(ActivityFigure f) =>
        figureText(f, name: (id) => tokenName(id), decimals: (id) => tokenDecimals(id));
    final headline = activity != null
        ? view.title
        : outgoing
            ? context.l10n.txSentAmount(formatErg(nano?.abs()))
            : context.l10n.txReceivedAmount(formatErg(nano?.abs()));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.txTitle)),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    activity != null
                        ? icon
                        : outgoing
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                    size: 20,
                    color: tint,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(headline, style: Theme.of(context).textTheme.headlineSmall),
                ),
              ],
            ),
            if (activity != null) ...[
              const SizedBox(height: 6),
              Text(figure(view.primary), style: Theme.of(context).textTheme.titleMedium),
              if (view.secondary case final s?)
                Text(figure(s), style: Theme.of(context).textTheme.bodyMedium),
              if (view.who case final who?)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(who, style: Theme.of(context).textTheme.bodySmall),
                ),
            ] else if (networkController.fiatText(nano?.abs()) != null) ...[
              const SizedBox(height: 4),
              Text(
                networkController.fiatText(nano?.abs())!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              confirmed
                  ? context.l10n.txConfirmedAt(formatHeight(height))
                  : tx['confirmed'] == true
                      ? context.l10n.txConfirmed
                      : context.l10n.txNotInBlock,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (formatTxTime(ts).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(formatTxTime(ts), style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 24),
            if (activity != null)
              ..._breakdown(context, activity)
            else ...[
              if (counterparty != null && counterparty.isNotEmpty) ...[
                SectionLabel(outgoing ? context.l10n.txTo : context.l10n.txFrom),
                const SizedBox(height: 8),
                SoftCard(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(counterparty, style: monoStyle(context, size: 12)),
                ),
                const SizedBox(height: 16),
              ],
              if (fee != null && fee > 0) ...[
                SectionLabel(context.l10n.commonMinerFee),
                const SizedBox(height: 8),
                Text(formatErg(fee), style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
              ],
              if (sent.isNotEmpty) ...[
                SectionLabel(context.l10n.txTokensSent),
                const SizedBox(height: 8),
                for (final t in sent) _tokenLine(context, t),
                const SizedBox(height: 10),
              ],
            ],
            SectionLabel(context.l10n.txIdLabel),
            const SizedBox(height: 8),
            SelectableText(txId, style: monoStyle(context, size: 12)),
            const SizedBox(height: 16),
            if (activity == null)
              if (received.isNotEmpty) ...[
                SectionLabel(context.l10n.txTokensReceived),
                const SizedBox(height: 8),
                for (final t in received) _tokenLine(context, t),
                // Compare identities, not lengths: token_ids may repeat and
                // arrivals cover a subset of the unique ids.
                if (missingTokenIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 6),
                    child: Text(
                      context.l10n.txFurtherTokenIds('${missingTokenIds.length}'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 8),
              ] else if (tokens.isNotEmpty) ...[
                SectionLabel(context.l10n.commonTokens),
                const SizedBox(height: 8),
                ...tokens.map((id) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        tokenName(id) == null
                            ? shorten(id, head: 12, tail: 10)
                            : '${tokenName(id)} · ${shorten(id, head: 8, tail: 6)}',
                        style: monoStyle(context, size: 12),
                      ),
                    )),
                const SizedBox(height: 8),
              ],
            FilledButton(
              onPressed: txId.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: txId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.txIdCopied)),
                      );
                    },
              child: Text(context.l10n.commonCopyId),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: txId.isEmpty
                  ? null
                  : () async {
                      try {
                        final ok = await sessionLock.run(
                          () => launchUrl(
                            Uri.parse(networkController.explorerTx(txId)),
                            mode: LaunchMode.externalApplication,
                          ),
                        );
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.l10n.txExplorerFailed)),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.l10n.txExplorerFailed)),
                          );
                        }
                      }
                    },
              child: Text(context.l10n.txOpenExplorer),
            ),
          ],
        ),
      ),
    );
  }
}
