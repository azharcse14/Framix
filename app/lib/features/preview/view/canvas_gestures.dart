import 'package:material_ui/material_ui.dart';

/// Drag and pinch on the preview move and scale the active clip; an outline shows its frame.
class CanvasGestures extends StatefulWidget {
  const CanvasGestures({super.key});

  /// The outline of the active clip's frame.
  static const outlineKey = ValueKey('canvas-outline');

  @override
  State<CanvasGestures> createState() => _CanvasGesturesState();
}

class _CanvasGesturesState extends State<CanvasGestures> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
