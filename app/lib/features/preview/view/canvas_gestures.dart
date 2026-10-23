import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/proto/framix/v1/engine.pb.dart';
import '../../../core/ui/framix_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../timeline/bloc/timeline_cubit.dart';

/// Drag and pinch on the preview move and scale the active clip; an outline shows its frame.
/// Positions are 1/10000 of the canvas from its centre, scale 1/1000 of fit (engine units).
class CanvasGestures extends StatefulWidget {
  const CanvasGestures({super.key});

  /// The outline of the active clip's frame.
  static const outlineKey = ValueKey('canvas-outline');

  @override
  State<CanvasGestures> createState() => _CanvasGesturesState();
}

class _CanvasGesturesState extends State<CanvasGestures> {
  /// UI guard for the engine's ranges; the engine still validates.
  static const _maxOffset = 20000;
  static const _minScale = 10;
  static const _maxScale = 10000;

  int _gesture = 0;

  /// The clip's place and the finger position when the gesture began.
  ({int x, int y, int scale, Offset focal})? _start;

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
            onScaleStart: (d) {
              if (clip == null) return;
              // Unique per gesture across rebuilds and restarts: edits with one id merge
              // into one undo step.
              _gesture = DateTime.now().microsecondsSinceEpoch;
              _start = (
                x: clip.x,
                y: clip.y,
                scale: _scaleOf(clip),
                focal: d.localFocalPoint,
              );
            },
            onScaleUpdate: (d) {
              final start = _start;
              if (clip == null || start == null) return;
              final moved = d.localFocalPoint - start.focal;
              cubit.placeClip(
                clip,
                x: (start.x + moved.dx / size.width * 10000).round().clamp(
                  -_maxOffset,
                  _maxOffset,
                ),
                y: (start.y + moved.dy / size.height * 10000).round().clamp(
                  -_maxOffset,
                  _maxOffset,
                ),
                scale: (start.scale * d.scale).round().clamp(
                  _minScale,
                  _maxScale,
                ),
                gesture: _gesture,
              );
            },
            onScaleEnd: (_) => _start = null,
            child: Stack(
              children: [if (clip != null) _outline(context, clip, size)],
            ),
          ),
        );
      },
    );
  }

  static int _scaleOf(Clip clip) => clip.scale == 0 ? 1000 : clip.scale;

  /// The clip's frame at fit (the whole canvas) times its scale, centred at its offset.
  Widget _outline(BuildContext context, Clip clip, Size canvas) {
    final scale = _scaleOf(clip) / 1000;
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
