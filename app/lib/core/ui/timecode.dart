/// mm:ss.cc of [ticks] at [ticksPerSecond], for display only.
String timecode(int ticks, int ticksPerSecond) {
  if (ticksPerSecond == 0) return '00:00.00';
  final centis = ticks * 100 ~/ ticksPerSecond;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(centis ~/ 6000)}:${two(centis ~/ 100 % 60)}.${two(centis % 100)}';
}
