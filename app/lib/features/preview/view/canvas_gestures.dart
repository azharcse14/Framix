import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/proto/framix/v1/engine.pb.dart';
import '../../../core/ui/framix_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../timeline/bloc/timeline_cubit.dart';

/// Drag and pinch on the preview move and scale the active clip; an outline shows its frame.
/// Positions are 1/10000 of the canvas from its centre, scale 1/1000 of fit (engine units).
/// The outline is the canvas box times the scale; a clip whose shape differs from the canvas
/// (or is cropped or turned) will not match it until the engine reports the frame rectangle.
class CanvasGestures extends StatefulWidget {
  const CanvasGestures({super.key});

  /// The outline of the active clip's frame.
  static const outlineKey = ValueKey('canvas-outline');

  @override
  State<CanvasGestures> createState() => _CanvasGesturesState();
}

class _CanvasGesturesState extends State<CanvasGestures> {
  int _gesture = 0;

  /// The clip the gesture acts on, its place so far, and the scale `d.scale` is relative to.
  ({int clip, double x, double y, int scale})? _start;

  /// The scale last sent; the base again when the recognizer restarts.
  late int _scale;

  Clip? _active(TimelineChanged t) {
    final id = t.activeClip;
    if (id == 0) return null;
    for (final track in t.tracks) {
      for (final clip in track.clips) {
        if (clip.id == id) return clip;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TimelineCubit>();
    final clip = context.select<TimelineCubit, Clip?>((c) => _active(c.state));
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        return Semantics(
          label: AppLocalizations.of(context).canvasPlaceClip,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) {
              if (clip == null) return;
              final going = _start;
              // A finger landed or lifted mid-gesture: the recognizer restarts. Carry on from
              // what was sent (the engine's reply may not be here yet), as the same undo step.
              if (going != null && going.clip == clip.id.toInt()) {
                _start = (
                  clip: going.clip,
                  x: going.x,
                  y: going.y,
                  scale: _scale,
                );
                return;
              }
              _gesture = cubit.nextGesture();
              _scale = clip.scale;
              _start = (
                clip: clip.id.toInt(),
                x: clip.x.toDouble(),
                y: clip.y.toDouble(),
                scale: clip.scale,
              );
            },
            onScaleUpdate: (d) {
              final start = _start;
              // The active clip can change under a gesture (a seek): stop acting on it.
              if (clip == null ||
                  start == null ||
                  start.clip != clip.id.toInt()) {
                return;
              }
              // Deltas, not the focal point: it jumps when a second finger lands.
              final moved = (
                clip: start.clip,
                x: start.x + d.focalPointDelta.dx / size.width * 10000,
                y: start.y + d.focalPointDelta.dy / size.height * 10000,
                scale: start.scale,
              );
              _start = moved;
              _scale = (moved.scale * d.scale).round();
              // The engine checks the ranges; an out-of-range edit is refused there.
              cubit.placeClip(
                clip,
                x: moved.x.round(),
                y: moved.y.round(),
                scale: _scale,
                gesture: _gesture,
              );
            },
            // Fingers still down: a restart follows, so the gesture is not over.
            onScaleEnd: (d) {
              if (d.pointerCount == 0) _start = null;
            },
            child: Stack(
              children: [if (clip != null) _outline(context, clip, size)],
            ),
          ),
        );
      },
    );
  }

  /// The clip's frame at fit (the whole canvas) times its scale, centred at its offset.
  Widget _outline(BuildContext context, Clip clip, Size canvas) {
    final scale = clip.scale / 1000;
    final width = canvas.width * scale;
    final height = canvas.height * scale;
    final centre = Offset(
      canvas.width / 2 + clip.x / 10000 * canvas.width,
      canvas.height / 2 + clip.y / 10000 * canvas.height,
    );
    return Positioned(
      key: CanvasGestures.outlineKey,
      left: centre.dx - width / 2,
      top: centre.dy - height / 2,
      width: math.max(width, 1),
      height: math.max(height, 1),
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: FramixColors.of(context).accentText,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
