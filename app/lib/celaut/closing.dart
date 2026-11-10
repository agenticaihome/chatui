import '../bridge/api/celaut_service.dart';

/// The activity window of a node (nodo#344), as a quote or the plan of an instance gives
/// it: `closes_at` is the unix time of the next close, in seconds (0: none scheduled), and
/// `on_close` is what the node then does with a running instance. `opens_at` is the unix
/// time of the next opening of a closed node, from the schedule that it announced
/// (`Peer.activity_window`); 0 if the app does not know it.

/// The next close that touches a running instance, as a local time: null when no close
/// is scheduled, or when the node leaves running instances alone (`ON_CLOSE_REFUSE`).
DateTime? closingTime(int closesAt, OnCloseView onClose) =>
    closesAt > 0 && onClose != OnCloseView.refuse ? _local(closesAt) : null;

/// Whether the close at [closesAt] comes before [life] ends, counted from [now]. A null
/// [life] is an instance that runs until the user stops it: every close comes before.
bool closesBefore(int closesAt, Duration? life, DateTime now) =>
    life == null || _local(closesAt).isBefore(now.add(life));

/// The next opening of a closed node, as a local time; null if the app does not know it.
DateTime? openingTime(int opensAt) => opensAt > 0 ? _local(opensAt) : null;

DateTime _local(int unixSeconds) => DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
