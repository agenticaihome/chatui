import 'dart:math';

/// What a node charges to keep an instance (nodo#636): the node takes [perPeriodMu] once
/// each [periodSeconds], at most `perPeriodMu * (1 + volatility)^k`, where `k` is the
/// volatility period of the tick (`price_bound.tick_period_index`): `k(i) = floor(i *
/// periodSeconds / volatilityPeriodSeconds) + 1` for the tick `i` after the launch, and 1
/// when [volatilityPeriodSeconds] is 0. A quote that is not bounded (`price_bounded`
/// false) promises nothing: its volatility is 0, and each period costs [perPeriodMu].
///
/// It turns time into MU and back, for the start balance, "Add time" and "keep running",
/// as nodo's `funding_sum_mu` does: the sum of the periods, rounded up to a whole MU.
class MaintenancePrice {
  const MaintenancePrice._(
    this.perPeriodMu,
    this.periodSeconds,
    this.volatility,
    this.volatilityPeriodSeconds,
    this.ticksDone,
  );

  /// The price of one period at the start, in MU.
  final BigInt perPeriodMu;
  final int periodSeconds;

  /// The most that the price can rise in one volatility period (`price_volatility`), 0
  /// for a quote that is not bounded.
  final double volatility;

  /// The seconds of one volatility period (`volatility_period_seconds`); 0 is one period
  /// for the whole life.
  final int volatilityPeriodSeconds;

  /// The ticks that the node already charged: the next one is `ticksDone + 1`.
  final int ticksDone;

  /// `(1 + v)^k` above this is too large to fund, as nodo's `_LARGEST_FACTOR_LOG`.
  static final _largestFactorLog = log(1e30);

  /// The most periods that [lasts] counts: about 19 years of one-minute periods.
  static const _maxPeriods = 10000000;

  /// The price from the numbers of a quote or of the record of an instance; null if they
  /// give no price. [elapsed] is the time since the launch of a running instance: its
  /// next periods are in a later volatility period. A volatility that is not a finite
  /// number of at least 0 is 0, as nodo's `price_bound.strict` reads it, and so is a
  /// negative volatility period.
  static MaintenancePrice? of({
    required String perPeriodMu,
    required int periodSeconds,
    double volatility = 0,
    int volatilityPeriodSeconds = 0,
    Duration elapsed = Duration.zero,
  }) {
    final perPeriod = BigInt.tryParse(perPeriodMu);
    if (periodSeconds <= 0 || perPeriod == null || perPeriod <= BigInt.zero) return null;
    final v = volatility.isFinite && volatility > 0 ? _asWritten(volatility) : 0.0;
    final t = volatilityPeriodSeconds > 0 ? volatilityPeriodSeconds : 0;
    final done = elapsed.inSeconds <= 0 ? 0 : elapsed.inSeconds ~/ periodSeconds;
    return MaintenancePrice._(perPeriod, periodSeconds, v, t, done);
  }

  /// A proto `float` as the decimal that it was written as (0.1 arrives as
  /// 0.10000000149011612), as nodo's `price_bound._rounded`.
  static double _asWritten(double value) => double.parse(value.toStringAsPrecision(7));

  /// The same price, for an instance launched [elapsed] ago.
  MaintenancePrice after(Duration elapsed) =>
      MaintenancePrice._(perPeriodMu, periodSeconds, volatility, volatilityPeriodSeconds,
          elapsed.inSeconds <= 0 ? 0 : elapsed.inSeconds ~/ periodSeconds);

  /// `k(i)`, the volatility period of the tick [i] after the launch.
  int _k(int i) => volatilityPeriodSeconds == 0 ? 1 : (i * periodSeconds) ~/ volatilityPeriodSeconds + 1;

  /// The last tick in the volatility period of the tick [i].
  int _lastTickOf(int i) {
    if (volatility == 0 || volatilityPeriodSeconds == 0) return 1 << 62;
    final k = _k(i);
    return (k * volatilityPeriodSeconds - 1) ~/ periodSeconds;
  }

  /// The price of one tick in the volatility period [k], in MU (not rounded); null if
  /// `(1 + v)^k` is too large to fund.
  double? _tick(int k) {
    if (volatility == 0) return perPeriodMu.toDouble();
    if (k * log(1 + volatility) > _largestFactorLog) return null;
    return perPeriodMu.toDouble() * pow(1 + volatility, k);
  }

  /// The sum of [count] ticks after the ticks already done, rounded up to a whole MU;
  /// null if a factor is too large to fund.
  BigInt? _sum(int count) {
    if (count <= 0) return BigInt.zero;
    if (volatility == 0) return perPeriodMu * BigInt.from(count);
    var total = 0.0;
    var i = ticksDone + 1;
    final end = ticksDone + count;
    while (i <= end) {
      final last = min(_lastTickOf(i), end);
      final tick = _tick(_k(i));
      if (tick == null) return null;
      total += tick * (last - i + 1);
      i = last + 1;
    }
    // Rounded up, as nodo's exact sum; a sum within a relative 1e-12 of a whole MU is that MU, so
    // the error of the floating point (1.1 * 1.1 = 1.2100000000000002) adds no MU.
    // ceilToDouble: `ceil()` gives an int, which stops at 2^63 - 1.
    return BigInt.from((total * (1 - 1e-12)).ceilToDouble());
  }

  int _periods(Duration time) {
    final seconds = time.inSeconds < 0 ? 0 : time.inSeconds;
    return (seconds + periodSeconds - 1) ~/ periodSeconds;
  }

  /// The balance that keeps a new instance for at least [time]: the funding of the
  /// periods in [time], plus one for the period that runs at the end. What a start adds
  /// to the `cost` of its quote (nodo#636). Null if a factor is too large to fund.
  BigInt? balanceFor(Duration time) => _sum(_periods(time) + 1);

  /// The MU to add to a running instance so that it lasts [time] longer. Null if a factor
  /// is too large to fund.
  BigInt? addFor(Duration time) => _sum(_periods(time));

  /// How long the balance [balanceMu] keeps an instance, the inverse of [balanceFor]: the
  /// whole periods that it funds, less the one that runs at the end.
  Duration lasts(BigInt balanceMu) {
    var periods = 0;
    if (volatility == 0) {
      final whole = balanceMu ~/ perPeriodMu;
      periods = whole > BigInt.from(_maxPeriods) ? _maxPeriods : whole.toInt();
    } else {
      // The same tolerance as [_sum]: a balance of exactly the funding of n periods lasts n.
      var left = balanceMu.toDouble() * (1 + 1e-12);
      var i = ticksDone + 1;
      while (periods < _maxPeriods) {
        final tick = _tick(_k(i));
        if (tick == null || tick > left) break;
        final last = _lastTickOf(i);
        final room = min(last - i + 1, _maxPeriods - periods);
        final n = min(room, (left / tick).floor());
        periods += n;
        left -= tick * n;
        if (n < room) break;
        i = last + 1;
      }
    }
    periods -= 1;
    if (periods <= 0) return Duration.zero;
    return Duration(seconds: periods * periodSeconds);
  }
}
