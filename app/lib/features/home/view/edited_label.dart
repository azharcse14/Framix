import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';

/// When a project was last edited, as Home shows it: just now, minutes or hours ago,
/// yesterday, then the date. A time after [now] (the clock moved) reads as just now.
String editedLabel(
  AppLocalizations l10n,
  String locale,
  DateTime now,
  DateTime edited,
) {
  final ago = now.difference(edited);
  if (ago.inMinutes < 1) return l10n.editedJustNow;
  if (ago.inHours < 1) return l10n.editedMinutesAgo(ago.inMinutes);
  if (ago.inDays < 1) return l10n.editedHoursAgo(ago.inHours);
  if (ago.inDays < 2) return l10n.editedYesterday;
  return l10n.projectEdited(_date(locale).format(edited));
}

/// The app loads date data for its locales (GlobalMaterialLocalizations); without it (plain
/// unit tests) intl throws, so fall back to en_US, which is built in.
DateFormat _date(String locale) {
  try {
    return DateFormat.yMMMd(locale);
  } on Exception {
    return DateFormat.yMMMd('en_US');
  }
}
