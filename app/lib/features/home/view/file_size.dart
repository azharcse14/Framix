import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';

/// [bytes] as Home shows a size: B, KB, MB or GB (1024 each), one decimal under 10.
String fileSize(AppLocalizations l10n, String locale, int bytes) {
  const units = ['b', 'kb', 'mb', 'gb'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final pattern = unit > 0 && value < 10 ? '#,##0.#' : '#,##0';
  return l10n.fileSize(_number(pattern, locale).format(value), units[unit]);
}

/// The locale's digits; en_US where intl lacks the locale.
NumberFormat _number(String pattern, String locale) {
  try {
    return NumberFormat(pattern, locale);
  } on ArgumentError {
    return NumberFormat(pattern, 'en_US');
  }
}
