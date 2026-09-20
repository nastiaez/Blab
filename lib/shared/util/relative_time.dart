import '../../l10n/generated/app_localizations.dart';

String relativeTime(
  DateTime when,
  AppLocalizations localizations, {
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(when);
  if (diff.inSeconds < 60) return localizations.now;
  if (diff.inMinutes < 60) {
    return localizations.relativeMinutes(diff.inMinutes);
  }
  if (diff.inHours < 24) return localizations.relativeHours(diff.inHours);
  if (diff.inDays < 7) return localizations.relativeDays(diff.inDays);
  return '${when.day}/${when.month}';
}
