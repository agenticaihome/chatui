import 'package:flutter/material.dart';

import '../../bridge/api/celaut_service.dart';
import '../../celaut/closing.dart';
import '../../l10n/l10n.dart';

/// A local time for the user: the hour and the minute, and the day too when it is not
/// [now]'s day.
String clockText(BuildContext context, DateTime time, {DateTime? now}) {
  final m = MaterialLocalizations.of(context);
  final today = now ?? DateTime.now();
  final clock = m.formatTimeOfDay(
    TimeOfDay.fromDateTime(time),
    alwaysUse24HourFormat: MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ?? false,
  );
  final sameDay = time.year == today.year && time.month == today.month && time.day == today.day;
  return sameDay ? clock : '${m.formatShortMonthDay(time)} $clock';
}

/// What the node does at its next close (nodo#344), for the user; null when nothing
/// happens to a running instance.
String? closingNote(BuildContext context, int closesAt, OnCloseView onClose, {DateTime? now}) {
  final time = closingTime(closesAt, onClose);
  if (time == null) return null;
  final l = context.l10n;
  final at = clockText(context, time, now: now);
  return onClose == OnCloseView.stop ? l.celautCloseStop(at) : l.celautCloseHibernate(at);
}

/// The warning of an instance that the app keeps running on a node that stops it at its
/// next close; null when the node does not stop it.
String? keepStopNote(BuildContext context, int closesAt, OnCloseView onClose, {DateTime? now}) {
  if (onClose != OnCloseView.stop) return null;
  final time = closingTime(closesAt, onClose);
  if (time == null || !time.isAfter(now ?? DateTime.now())) return null;
  return context.l10n.celautKeepStopsAtClose(clockText(context, time, now: now));
}

/// When a closed node opens again, for the user; null if the app does not know it.
String? openingNote(BuildContext context, int opensAt, {DateTime? now}) {
  final time = openingTime(opensAt);
  if (time == null) return null;
  return context.l10n.celautNodeOpensAt(clockText(context, time, now: now));
}
