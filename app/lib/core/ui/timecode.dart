import 'file_size.dart';

/// mm:ss.cc of [ticks] at [ticksPerSecond] in the [locale]'s digits, for display only.
String timecode(int ticks, int ticksPerSecond, String locale) {
  String two(int v) => localeDigits(v, locale, width: 2);
  if (ticksPerSecond == 0) return '${two(0)}:${two(0)}.${two(0)}';
  final centis = ticks * 100 ~/ ticksPerSecond;
  return '${two(centis ~/ 6000)}:${two(centis ~/ 100 % 60)}.${two(centis % 100)}';
}

/// A timeline ruler mark, m:ss or m:ss.t, in the [locale]'s digits.
String rulerLabel(double seconds, String locale) {
  final whole = seconds.floor();
  final tenth = ((seconds - whole) * 10).round();
  return '${localeDigits(whole ~/ 60, locale)}:'
      '${localeDigits(whole % 60, locale, width: 2)}'
      '${tenth == 0 ? '' : '.${localeDigits(tenth, locale)}'}';
}
