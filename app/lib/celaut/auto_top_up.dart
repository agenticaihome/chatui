import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bridge/api/celaut.dart';
import '../bridge/api/celaut_service.dart';
import 'maintenance_price.dart';

/// A top-up that the app could not make. Either the credit of the app on the node of the
/// instance is less than the amount ([budget] false), or the instance reached the limit
/// that the user set ([budget] true). The app does not pay a node by itself; the user
/// chooses to make a deposit, which has its own confirmation and unlock.
@immutable
class TopUpNeed {
  const TopUpNeed({
    required this.instanceId,
    required this.address,
    required this.detail,
    this.budget = false,
  });

  final String instanceId;

  /// The node (`host:port`).
  final String address;

  /// The numbers of the node, as the error gives them (credit and amount).
  final String detail;

  /// The limit of the instance was reached, not the credit.
  final bool budget;
}

/// "Run until I stop it" (Josemi, 2026-10-29). The user turns it on for an instance, at
/// the launch or later, and the app keeps the instance running: when its balance would
/// last less than [threshold], the app moves [chunk] of time of the credit that it already
/// has on the node of the instance to the instance (`celaut_top_up_instance`,
/// `ModifyDeposit`). That is not a payment: nothing goes on the blockchain and nothing is
/// signed. The time is turned into MU with the price of the node that the instance keeps
/// ([MaintenancePrice]); an instance without a price uses [fallbackThresholdMu] and
/// [fallbackAmountMu].
///
/// The danger is the credit of the user: the app keeps moving it until the user stops the
/// instance. The limits are the credit of the node, which is all that the app can move, and
/// an optional limit per instance. If the credit is too low, or the limit is reached, the
/// app does not pay: it sets [need], and the list of conversations asks the user, who can make
/// a deposit. A deposit has its own confirmation and asks for the fingerprint or the screen
/// lock, as always. So no transaction ever happens without the user.
///
/// An instance that starts initial children (nodo#538) got their start with its first
/// balance (`launchService`). The top-up does not count those MU as time of the instance
/// while the children did not start ([ownBalance]).
///
/// The app checks when the list of conversations reads the instances ([observe]), and
/// once a minute while the app runs ([start]); only instances that the user asked to keep
/// are read from their nodes. After a top-up of an instance, it waits a minute before the
/// next one; after a failure, ten minutes. The app does not run when it is closed: then
/// nothing tops up, and the node stops the instance when its balance runs out.
class AutoTopUp extends ChangeNotifier {
  AutoTopUp({
    Future<TopUpView> Function(String instanceId, String amountMu)? topUp,
    List<InstanceListView> Function()? instances,
    Future<InstanceStatusView> Function(String instanceId)? status,
    InstancePlanView Function(String instanceId)? plan,
    void Function(String instanceId, bool enabled, String? budgetMu)? setKeepAlive,
    DateTime Function()? now,
    this.periodic = true,
  })  : _topUp = topUp ?? ((id, mu) => celautTopUpInstance(instanceId: id, amountMu: mu)),
        _instances = instances ?? celautInstances,
        _status = status ?? ((id) => celautInstanceStatus(instanceId: id)),
        _plan = plan ?? ((id) => celautInstancePlan(instanceId: id)),
        _setKeepAlive = setKeepAlive ??
            ((id, enabled, budget) => celautSetKeepAlive(instanceId: id, enabled: enabled, budgetMu: budget)),
        _now = now ?? DateTime.now;

  static const keyThreshold = 'celaut_keep_alive_threshold_minutes_v1';
  static const keyChunk = 'celaut_keep_alive_chunk_minutes_v1';

  static const defaultThreshold = Duration(minutes: 15);
  static const defaultChunk = Duration(hours: 1);

  /// The least threshold and chunk.
  static const minTime = Duration(minutes: 1);

  /// The largest threshold: a day.
  static const maxThreshold = Duration(days: 1);

  /// The largest chunk of one top-up: 30 days, as the longest time of a launch.
  static const maxChunk = Duration(days: 30);

  /// For an instance that keeps no price (it started before the app kept it), in MU.
  static final fallbackThresholdMu = BigInt.from(200000);
  static final fallbackAmountMu = BigInt.from(1000000);

  /// The most that one call moves, in MU (`TOP_UP_MAX_MU` of the core).
  static final maxCallMu = BigInt.from(100000000);

  static const _afterTopUp = Duration(minutes: 1);
  static const _afterFailure = Duration(minutes: 10);
  static const _every = Duration(minutes: 1);

  final Future<TopUpView> Function(String instanceId, String amountMu) _topUp;
  final List<InstanceListView> Function() _instances;
  final Future<InstanceStatusView> Function(String instanceId) _status;
  final InstancePlanView Function(String instanceId) _plan;
  final void Function(String instanceId, bool enabled, String? budgetMu) _setKeepAlive;
  final DateTime Function() _now;

  /// Check once a minute. Tests check by hand.
  final bool periodic;

  Duration _threshold = defaultThreshold;
  Duration _chunk = defaultChunk;
  bool _loaded = false;
  TopUpNeed? _need;
  final Map<String, DateTime> _wait = {};
  final Set<String> _busy = {};
  Timer? _timer;

  /// Top up when the balance of an instance would last less than this.
  Duration get threshold => _threshold;

  /// How much time one top-up gives.
  Duration get chunk => _chunk;

  /// A top-up that needs a deposit (or a new limit) first; null if none.
  TopUpNeed? get need => _need;

  /// Read the settings, once.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _threshold = _parse(prefs.getInt(keyThreshold), defaultThreshold, maxThreshold);
      _chunk = _parse(prefs.getInt(keyChunk), defaultChunk, maxChunk);
    } catch (_) {
      // No preferences: the defaults.
    }
    notifyListeners();
  }

  static Duration _parse(int? minutes, Duration fallback, Duration max) {
    if (minutes == null) return fallback;
    final d = Duration(minutes: minutes);
    return d < minTime || d > max ? fallback : d;
  }

  /// Keep new settings. [threshold] and [chunk] must be in their limits.
  Future<void> save({required Duration threshold, required Duration chunk}) async {
    _loaded = true;
    _threshold = threshold;
    _chunk = chunk;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keyThreshold, threshold.inMinutes);
      await prefs.setInt(keyChunk, chunk.inMinutes);
    } catch (_) {
      // Not kept: the settings last for this run only.
    }
  }

  /// The plan of the instance (its price and its keep-alive settings); null if the core
  /// does not know the instance.
  InstancePlanView? planOf(String instanceId) {
    try {
      return _plan(instanceId);
    } on Object {
      return null;
    }
  }

  /// Turn "run until I stop it" on or off for an instance. [budgetMu] is the most that the
  /// app may move from now on; null is no limit. Moves no credit. Throws [CelautError] if
  /// the instance is stopped or unknown.
  void setKeepAlive(String instanceId, {required bool enabled, String? budgetMu}) {
    _setKeepAlive(instanceId, enabled, budgetMu);
    _wait.remove(instanceId);
    if (_need?.instanceId == instanceId) _need = null;
    _schedule();
    notifyListeners();
  }

  /// Add [time] to a running instance, once, from the credit of the app on its node
  /// (Josemi, 2026-10-29). The core takes at most 100,000,000 MU a call, so a long time
  /// goes in several. If the credit is not enough, it throws [CelautError] with
  /// [CelautErrorKind.insufficientCredit]; what was moved before stays. Null if the price
  /// of the node is not known.
  Future<TopUpView?> addTime(String instanceId, Duration time) async {
    final plan = planOf(instanceId);
    final price = plan == null ? null : priceOf(plan);
    if (price == null) return null;
    var left = price.addFor(time);
    TopUpView? last;
    while (left > BigInt.zero) {
      final step = left > maxCallMu ? maxCallMu : left;
      last = await _topUp(instanceId, '$step');
      left -= step;
    }
    return last;
  }

  /// The price of the node of an instance, from its plan; null if the app does not know it.
  static MaintenancePrice? priceOf(InstancePlanView plan) => MaintenancePrice.of(
        perPeriodMu: plan.maintenanceMu,
        periodSeconds: plan.maintenanceSeconds,
        variance: plan.variance,
      );

  /// The part of [balance] that keeps the instance itself (nodo#538). The start also
  /// gave the instance `children_initial_cost` to start its initial children, and the
  /// node takes it from the balance only when the instance starts them. Until then the
  /// app must not count it as time of the instance, or the top-up comes too late and the
  /// instance spends the MU of its children on its own maintenance.
  ///
  /// The rule: while [balance] is at least the balance of the instance itself at the
  /// start plus all the top-ups (`own_start_mu + topped_up_mu`), the children did not
  /// start yet. Then the part of the instance is that sum less the maintenance since the
  /// start, at the price of the node with its margin. When [balance] goes below the sum,
  /// the children started (or the instance used their MU), and the whole balance is the
  /// part of the instance, as before. With no children, or if the app does not know the
  /// balance of the start, it is the whole balance.
  static BigInt ownBalance(InstancePlanView plan, BigInt balance, MaintenancePrice? price, DateTime now) {
    final children = BigInt.tryParse(plan.childrenInitialMu) ?? BigInt.zero;
    final start = BigInt.tryParse(plan.ownStartMu);
    if (children <= BigInt.zero || start == null) return balance;
    final funded = start + (BigInt.tryParse(plan.toppedUpMu) ?? BigInt.zero);
    if (balance < funded) return balance;
    final since = now.difference(DateTime.fromMillisecondsSinceEpoch(plan.startedAt * 1000));
    final used = price == null ? BigInt.zero : price.addFor(since);
    return funded > used ? funded - used : BigInt.zero;
  }

  /// The user saw the [need] and closed it.
  void dismissNeed() {
    if (_need == null) return;
    _need = null;
    notifyListeners();
  }

  /// Read the settings, and check once a minute while the app runs and an instance is kept.
  Future<void> start() async {
    await load();
    _schedule();
  }

  /// A timer only while an instance is kept: with none, nothing polls the nodes.
  void _schedule() {
    if (!periodic) return;
    var kept = false;
    try {
      kept = _instances().any((i) => i.stoppedAt == null && planOf(i.instanceId)?.keepAlive == true);
    } on Object {
      // No list: no timer.
    }
    if (kept) {
      _timer ??= Timer.periodic(_every, (_) => unawaited(check()));
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Read the balance of each running instance that the user asked to keep, and top up the
  /// ones that run low. An instance that is not kept is not asked.
  Future<void> check() async {
    await load();
    List<InstanceListView> all;
    try {
      all = _instances();
    } catch (_) {
      return;
    }
    for (final i in all) {
      if (i.stoppedAt != null || _waiting(i.instanceId) || planOf(i.instanceId)?.keepAlive != true) continue;
      try {
        await observe(i, await _status(i.instanceId));
      } on Object {
        // The node does not answer: the list says so. Ask again after the wait of a
        // failure (ui.md section 4), not every minute.
        _wait[i.instanceId] = _now().add(_afterFailure);
      }
    }
    _schedule();
  }

  bool _waiting(String id) {
    final until = _wait[id];
    return until != null && _now().isBefore(until);
  }

  /// The balance of the running instance [i] is known ([status]): if the user asked to keep
  /// it, top it up when it runs low.
  Future<void> observe(InstanceListView i, InstanceStatusView status) async {
    if (i.stoppedAt != null) return;
    final id = i.instanceId;
    final plan = planOf(id);
    if (plan == null || !plan.keepAlive) return;
    _schedule();
    final balance = BigInt.tryParse(status.instanceBalanceMu);
    if (balance == null) return;
    // A hibernated instance costs its disk only, and the plan has that price. Its balance
    // must also hold the fee of the wake call, which the instance pays. A top-up never
    // wakes it: the keep-alive only keeps its disk (ui.md, section 4b).
    final price = priceOf(plan);
    final reserve = plan.hibernated ? (BigInt.tryParse(plan.wakeFeeMu) ?? BigInt.zero) : BigInt.zero;
    final own = ownBalance(plan, balance, price, _now());
    final spare = own > reserve ? own - reserve : BigInt.zero;
    final low = price == null ? spare < fallbackThresholdMu : price.lasts(spare) < _threshold;
    if (!low || _waiting(id) || !_busy.add(id)) return;
    try {
      var amount = price == null ? fallbackAmountMu : price.addFor(_chunk);
      if (balance < reserve) amount += reserve - balance;
      if (amount > maxCallMu) amount = maxCallMu;
      final limit = BigInt.tryParse(plan.budgetMu);
      if (limit != null) {
        final left = limit - (BigInt.tryParse(plan.spentMu) ?? BigInt.zero);
        if (left <= BigInt.zero) {
          _wait[id] = _now().add(_afterFailure);
          _need = TopUpNeed(
            instanceId: id,
            address: i.address,
            detail: 'limit $limit MU, spent ${plan.spentMu} MU',
            budget: true,
          );
          notifyListeners();
          return;
        }
        if (amount > left) amount = left;
      }
      await _topUp(id, '$amount');
      _wait[id] = _now().add(_afterTopUp);
      if (_need?.instanceId == id) {
        _need = null;
        notifyListeners();
      }
    } on CelautError catch (e) {
      _wait[id] = _now().add(_afterFailure);
      if (e.kind == CelautErrorKind.insufficientCredit) {
        _need = TopUpNeed(instanceId: id, address: i.address, detail: e.message);
        notifyListeners();
      }
    } on Object {
      _wait[id] = _now().add(_afterFailure);
    } finally {
      _busy.remove(id);
    }
  }
}

/// The keep-alive engine of the app.
final autoTopUp = AutoTopUp();
