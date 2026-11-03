import 'package:flutter/material.dart';

import '../../bridge/api/celaut_home.dart';
import '../../celaut/balancer_model.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../settings/settings_shared.dart';
import '../widgets/soft_card.dart';

/// What the balancer screen needs. The app uses [AppBalancerWeights]; tests give their own.
abstract class BalancerWeights {
  BalancerWeightsView current();
  BalancerWeightsView defaults();
  void save(BalancerWeightsView weights);
}

class AppBalancerWeights implements BalancerWeights {
  const AppBalancerWeights();

  @override
  BalancerWeightsView current() => celautBalancerWeights();

  @override
  BalancerWeightsView defaults() => celautBalancerDefaultWeights();

  @override
  void save(BalancerWeightsView w) => celautSetBalancerWeights(
    price: w.price,
    reputation: w.reputation,
    onchain: w.onchain,
    donation: w.donation,
    priority: w.priority,
  );
}

/// The terms of the score that the screen lets the user set.
enum BalancerTerm { price, priority, reputation, onchain, donation }

double _get(BalancerWeightsView w, BalancerTerm t) => switch (t) {
  BalancerTerm.price => w.price,
  BalancerTerm.reputation => w.reputation,
  BalancerTerm.onchain => w.onchain,
  BalancerTerm.donation => w.donation,
  BalancerTerm.priority => w.priority,
};

BalancerWeightsView _with(BalancerWeightsView w, BalancerTerm t, double v) => BalancerWeightsView(
  price: t == BalancerTerm.price ? v : w.price,
  reputation: t == BalancerTerm.reputation ? v : w.reputation,
  onchain: t == BalancerTerm.onchain ? v : w.onchain,
  donation: t == BalancerTerm.donation ? v : w.donation,
  priority: t == BalancerTerm.priority ? v : w.priority,
);

/// A weight as text, to one decimal.
String balancerWeightText(double v) => v.toStringAsFixed(1);

double _round(double v) => (v * 10).round() / 10;

/// Settings, Compute, "Balancer weights" (Josemi, 2026-11-03): the parametrization of the
/// balancer that decides on which node a service runs (`docs/celaut/balancer.md`, "Weights
/// of the score").
///
/// Raw numbers say little, so the screen explains the weights three ways:
///
/// 1. **Quick setups** (balanced, cheapest first, my nodes first): a starting point with a
///    name, instead of five numbers.
/// 2. **A sentence** worked out from the real formula: "A node you fully trust can win
///    against one up to 7.4x cheaper". It is what the two main weights mean in practice.
/// 3. **An example** with three nodes that reorder while the user drags a slider, using the
///    same formula ([balancerScore]).
///
/// Only price and the user's priority have data today, so they are the main sliders. The
/// other three terms (local and on-chain reputation, donations) add 0 until the app has
/// their data; they are in a closed section, so they do not look like they do something.
/// A slider saves when the finger lifts and counts from the next quote.
class BalancerScreen extends StatefulWidget {
  const BalancerScreen({super.key, this.weights = const AppBalancerWeights()});

  final BalancerWeights weights;

  @override
  State<BalancerScreen> createState() => _BalancerScreenState();
}

class _BalancerScreenState extends State<BalancerScreen> {
  /// What the sliders and the example show: the saved weights, or the draft while a finger
  /// is on a slider.
  late BalancerWeightsView _live = widget.weights.current();
  late final BalancerWeightsView _defaults = widget.weights.defaults();

  void _save(BalancerWeightsView w) {
    widget.weights.save(w);
    setState(() => _live = widget.weights.current());
  }

  String _presetName(AppLocalizations l, BalancerPreset p) => switch (p) {
    BalancerPreset.balanced => l.balancerPresetBalanced,
    BalancerPreset.cheapest => l.balancerPresetCheapest,
    BalancerPreset.trusted => l.balancerPresetTrusted,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = ArgusColors.of(context);
    final current = presetOf(_live, _defaults);
    return SettingsPage(
      title: l.balancerTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text(l.balancerIntro, style: Theme.of(context).textTheme.bodySmall),
        ),
        SectionLabel(l.balancerPresetsLabel),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in BalancerPreset.values)
              ChoiceChip(
                key: Key('balancer-preset-${p.name}'),
                label: Text(_presetName(l, p)),
                selected: current == p,
                onSelected: (_) => _save(presetWeights(p, _defaults)),
              ),
            if (current == null)
              ChoiceChip(key: const Key('balancer-preset-custom'), label: Text(l.balancerCustom), selected: true, onSelected: null),
          ],
        ),
        const SizedBox(height: 24),
        SectionLabel(l.balancerMainTitle),
        const SizedBox(height: 10),
        for (final term in [BalancerTerm.price, BalancerTerm.priority]) ...[
          _TermCard(
            key: Key('balancer-term-${term.name}'),
            name: _name(l, term),
            description: _desc(l, term),
            value: _get(_live, term),
            defaultValue: _get(_defaults, term),
            muted: colors.muted,
            onChanged: (v) => setState(() => _live = _with(_live, term, _round(v))),
            onChangeEnd: (v) => _save(_with(_live, term, _round(v))),
          ),
          const SizedBox(height: 12),
        ],
        _Reading(weights: _live),
        const SizedBox(height: 24),
        SectionLabel(l.balancerExampleTitle),
        const SizedBox(height: 10),
        _Example(weights: _live),
        const SizedBox(height: 24),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const Key('balancer-advanced'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(l.balancerAdvancedTitle, style: Theme.of(context).textTheme.titleSmall),
            childrenPadding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l.balancerAdvancedNote, style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
              for (final term in [BalancerTerm.reputation, BalancerTerm.onchain, BalancerTerm.donation]) ...[
                _TermCard(
                  key: Key('balancer-term-${term.name}'),
                  name: _name(l, term),
                  description: _desc(l, term),
                  value: _get(_live, term),
                  defaultValue: _get(_defaults, term),
                  muted: colors.muted,
                  onChanged: (v) => setState(() => _live = _with(_live, term, _round(v))),
                  onChangeEnd: (v) => _save(_with(_live, term, _round(v))),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('balancer-reset'),
            onPressed: _live == _defaults ? null : () => _save(_defaults),
            icon: const Icon(Icons.restart_alt),
            label: Text(l.balancerReset),
          ),
        ),
      ],
    );
  }
}

String _name(AppLocalizations l, BalancerTerm t) => switch (t) {
  BalancerTerm.price => l.balancerPriceName,
  BalancerTerm.priority => l.balancerPriorityName,
  BalancerTerm.reputation => l.balancerReputationName,
  BalancerTerm.onchain => l.balancerOnchainName,
  BalancerTerm.donation => l.balancerDonationName,
};

String _desc(AppLocalizations l, BalancerTerm t) => switch (t) {
  BalancerTerm.price => l.balancerPriceDesc,
  BalancerTerm.priority => l.balancerPriorityDesc,
  BalancerTerm.reputation => l.balancerReputationDesc,
  BalancerTerm.onchain => l.balancerOnchainDesc,
  BalancerTerm.donation => l.balancerDonationDesc,
};

/// One term: its name, the value ("Off" at 0), a slider with "Ignore" and "Maximum" at its
/// ends, what the term is, and a button to go back to its default when it differs. While
/// the finger is on the slider the value changes at once ([onChanged]); it is saved when
/// the finger lifts ([onChangeEnd]).
class _TermCard extends StatelessWidget {
  const _TermCard({
    super.key,
    required this.name,
    required this.description,
    required this.value,
    required this.defaultValue,
    required this.muted,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String name;
  final String description;
  final double value;
  final double defaultValue;
  final Color muted;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rounded = _round(value);
    final small = TextStyle(fontSize: 12, color: muted);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: Theme.of(context).textTheme.titleMedium)),
              Text(
                rounded == 0 ? l.balancerOffLabel : balancerWeightText(rounded),
                key: const Key('balancer-value'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          Slider(
            value: value.clamp(0, balancerWeightMax).toDouble(),
            max: balancerWeightMax,
            divisions: 100,
            label: balancerWeightText(rounded),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(l.balancerScaleLow, style: small), Text(l.balancerScaleHigh, style: small)],
            ),
          ),
          const SizedBox(height: 8),
          Text(description, style: small),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text('${l.balancerDefaultLabel}: ${balancerWeightText(defaultValue)}', style: small)),
              if (rounded != _round(defaultValue))
                TextButton(
                  key: const Key('balancer-restore-term'),
                  onPressed: () => onChangeEnd(defaultValue),
                  child: Text(l.balancerRestoreTerm),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the two main weights mean in practice, in one sentence worked out from the real
/// formula ([trustedAdvantage]).
class _Reading extends StatelessWidget {
  const _Reading({required this.weights});

  final BalancerWeightsView weights;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = switch (readingOf(weights)) {
      BalancerReading.nothingCounts => l.balancerReadingNothing,
      BalancerReading.priceIgnored => l.balancerReadingPriceIgnored,
      BalancerReading.priorityIgnored => l.balancerReadingPriorityIgnored,
      BalancerReading.tradeoff => l.balancerReadingTradeoff(factorText(trustedAdvantage(weights) ?? 1)),
    };
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('balancer-reading'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.balance, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Three example nodes in the order that the current weights give them. When a weight
/// changes, the rows slide to their new place, so the user sees what the weight does.
class _Example extends StatelessWidget {
  const _Example({required this.weights});

  final BalancerWeightsView weights;

  static const double _row = 68;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = ArgusColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ranked = rankExamples(weights);
    final scores = [for (final r in ranked) r.$2];
    final low = scores.reduce((a, b) => a < b ? a : b);
    final high = scores.reduce((a, b) => a > b ? a : b);
    String nameOf(ExampleNode n) => switch (n.id) {
      'cheap' => l.balancerExampleCheap,
      'trusted' => l.balancerExampleTrusted,
      _ => l.balancerExampleRisky,
    };
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.balancerExampleIntro, style: TextStyle(fontSize: 12, color: colors.muted)),
          const SizedBox(height: 12),
          Text(
            l.balancerExampleFirst(nameOf(ranked.first.$1)),
            key: const Key('balancer-example-first'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _row * ranked.length,
            child: Stack(
              children: [
                for (var i = 0; i < ranked.length; i++)
                  AnimatedPositioned(
                    key: Key('balancer-example-${ranked[i].$1.id}'),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    top: i * _row,
                    left: 0,
                    right: 0,
                    height: _row,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: i == 0 ? scheme.primary : scheme.surfaceContainerHighest,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(fontSize: 12, color: i == 0 ? scheme.onPrimary : scheme.onSurface),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nameOf(ranked[i].$1), style: Theme.of(context).textTheme.bodyMedium),
                              Text(
                                l.balancerExampleDetail(
                                  factorText(ranked[i].$1.cost),
                                  ranked[i].$1.priority.toString(),
                                ),
                                style: TextStyle(fontSize: 12, color: colors.muted),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: high == low ? 1 : 0.08 + 0.92 * (ranked[i].$2 - low) / (high - low),
                                  minHeight: 6,
                                  color: i == 0 ? scheme.primary : colors.muted,
                                  backgroundColor: scheme.surfaceContainerHighest,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
