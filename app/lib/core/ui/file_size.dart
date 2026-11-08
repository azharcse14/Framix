import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';

/// Which way [fileSize] rounds at the precision it shows.
enum SizeRounding {
  /// Half up: a size shown for information.
  nearest,

  /// Never shows less than [bytes]: a size that is needed.
  up,

  /// Never shows more than [bytes]: a size that is free.
  down,
}

/// [bytes] as the app shows a size: B, KB, MB or GB, one decimal under 10. 1000 steps (SI), as the
/// iOS and Android storage screens count, so our numbers match theirs. A value that rounds to
/// 1000 shows as 1 of the next unit.
String fileSize(
  AppLocalizations l10n,
  String locale,
  int bytes, {
  SizeRounding rounding = SizeRounding.nearest,
}) {
  const units = ['b', 'kb', 'mb', 'gb'];
  var unit = 0;
  var scale = 1;
  while (bytes >= scale * 1000 && unit < units.length - 1) {
    scale *= 1000;
    unit++;
  }
  // Integer math in steps of the shown precision, so up and down are exact.
  final tenths = unit > 0 && bytes < 10 * scale;
  final step = tenths ? scale ~/ 10 : scale;
  final steps = switch (rounding) {
    SizeRounding.nearest => (bytes + step ~/ 2) ~/ step,
    SizeRounding.up => (bytes + step - 1) ~/ step,
    SizeRounding.down => bytes ~/ step,
  };
  var value = tenths ? steps / 10 : steps.toDouble();
  if (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
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
