import 'package:material_ui/material_ui.dart';

/// The tracks on a time axis: headers, a ruler, clip lanes and the playhead.
class TimelineView extends StatelessWidget {
  const TimelineView({super.key});

  /// The ruler; tap or drag it to seek.
  static const rulerKey = ValueKey('timeline-ruler');

  /// The playhead line.
  static const playheadKey = ValueKey('timeline-playhead');

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// One clip on its lane.
class ClipBox extends StatelessWidget {
  const ClipBox({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
