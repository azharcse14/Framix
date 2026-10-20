import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/proto/framix/v1/engine.pb.dart';
import '../../../core/ui/framix_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../bloc/playhead_cubit.dart';
import '../bloc/timeline_cubit.dart';
import '../bloc/timeline_zoom_cubit.dart';

/// The tracks on a time axis: headers, a ruler, clip lanes and the playhead. Positions come
/// from engine ticks; the only state here is the zoom (pixels per second).
class TimelineView extends StatelessWidget {
  const TimelineView({super.key, required this.timeline});

  final TimelineChanged timeline;

  /// The ruler; tap or drag it to seek.
  static const rulerKey = ValueKey('timeline-ruler');

  /// The playhead line.
  static const playheadKey = ValueKey('timeline-playhead');

  static const _headerWidth = 176.0;
  // A touch target (48dp), not just the marks.
  static const _rulerHeight = 48.0;

  /// Lane height follows the header: two text lines at the user's text scale (with room for
  /// Bangla's taller lines) plus the 48dp switches.
  static double _laneHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(2 * 26) + 48 + FramixSpace.m;

  @override
  Widget build(BuildContext context) {
    final pps = context.watch<TimelineZoomCubit>().state;
    final ticksPerSecond = timeline.ticksPerSecond.toInt();
    final laneHeight = _laneHeight(context);
    double px(int ticks) =>
        ticksPerSecond == 0 ? 0 : ticks / ticksPerSecond * pps;

    return Column(
      children: [
        _Toolbar(ticksPerSecond: ticksPerSecond),
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _headerWidth,
                  child: Column(
                    children: [
                      const SizedBox(height: _rulerHeight),
                      for (final track in timeline.tracks)
                        SizedBox(
                          height: laneHeight,
                          child: _TrackHeader(track: track),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final end = px(timeline.duration.toInt());
                      // Room to scroll past the end, so the last clip can reach the middle.
                      final width = math.max(
                        box.maxWidth,
                        end + box.maxWidth / 2,
                      );
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: width,
                          height:
                              _rulerHeight +
                              laneHeight * timeline.tracks.length,
                          child: Stack(
                            children: [
                              // Scrubbing repaints only the playhead line, not marks and clips.
                              RepaintBoundary(
                                child: Column(
                                  children: [
                                    _Ruler(
                                      pps: pps,
                                      ticksPerSecond: ticksPerSecond,
                                      height: _rulerHeight,
                                    ),
                                    for (final track in timeline.tracks)
                                      _Lane(
                                        track: track,
                                        height: laneHeight,
                                        px: px,
                                      ),
                                  ],
                                ),
                              ),
                              // The playhead changes often; only this line rebuilds.
                              BlocBuilder<PlayheadCubit, int>(
                                builder: (context, playhead) => Positioned(
                                  key: playheadKey,
                                  left: px(playhead) - 1,
                                  top: 0,
                                  bottom: 0,
                                  width: 2,
                                  child: IgnorePointer(
                                    child: ColoredBox(
                                      color: FramixColors.of(context)
                                          .accentText,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Playhead time and the zoom buttons (the button path for pinch, docs/design-system.md).
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.ticksPerSecond});

  final int ticksPerSecond;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final zoom = context.read<TimelineZoomCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FramixSpace.s),
      child: Row(
        children: [
          BlocBuilder<PlayheadCubit, int>(
            builder: (_, playhead) => Text(
              _timecode(playhead, ticksPerSecond),
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: l10n.zoomOut,
            icon: const Icon(Icons.zoom_out),
            onPressed: zoom.zoomOut,
          ),
          IconButton(
            tooltip: l10n.zoomIn,
            icon: const Icon(Icons.zoom_in),
            onPressed: zoom.zoomIn,
          ),
        ],
      ),
    );
  }
}

/// mm:ss.cc, for display only.
String _timecode(int ticks, int ticksPerSecond) {
  if (ticksPerSecond == 0) return '00:00.00';
  final centis = ticks * 100 ~/ ticksPerSecond;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(centis ~/ 6000)}:${two(centis ~/ 100 % 60)}.${two(centis % 100)}';
}

/// Second marks with labels; tap or drag to seek.
class _Ruler extends StatelessWidget {
  const _Ruler({
    required this.pps,
    required this.ticksPerSecond,
    required this.height,
  });

  final double pps;
  final int ticksPerSecond;
  final double height;

  @override
  Widget build(BuildContext context) {
    final playhead = context.read<PlayheadCubit>();
    void seekTo(double dx) {
      if (ticksPerSecond == 0) return;
      playhead.seek((dx / pps * ticksPerSecond).round());
    }

    final colors = FramixColors.of(context);
    final ruler = GestureDetector(
      key: TimelineView.rulerKey,
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => seekTo(d.localPosition.dx),
      onHorizontalDragUpdate: (d) => seekTo(d.localPosition.dx),
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _RulerPainter(
          pps: pps,
          mark: colors.outline,
          label: colors.textMuted,
        ),
      ),
    );
    // Screen readers seek one second at a time; the value is the playhead timecode.
    return BlocBuilder<PlayheadCubit, int>(
      builder: (context, at) => Semantics(
        label: AppLocalizations.of(context).timelineRuler,
        value: _timecode(at, ticksPerSecond),
        increasedValue: _timecode(at + ticksPerSecond, ticksPerSecond),
        decreasedValue: _timecode(
          math.max(0, at - ticksPerSecond),
          ticksPerSecond,
        ),
        onIncrease: () => playhead.seek(at + ticksPerSecond),
        onDecrease: () => playhead.seek(at - ticksPerSecond),
        child: ruler,
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({required this.pps, required this.mark, required this.label});

  final double pps;
  final Color mark;
  final Color label;

  /// Seconds between labelled marks, so labels stay at least ~64px apart.
  static const _steps = [0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0];

  @override
  void paint(Canvas canvas, Size size) {
    final step = _steps.firstWhere((s) => s * pps >= 64, orElse: () => 60);
    final line = Paint()..color = mark;
    for (var t = 0.0; t * pps <= size.width; t += step) {
      final x = t * pps;
      canvas.drawLine(
        Offset(x, size.height * 0.6),
        Offset(x, size.height),
        line,
      );
      final text = TextPainter(
        text: TextSpan(
          text: _secondsLabel(t),
          style: TextStyle(
            color: label,
            fontSize: 11,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text
        ..paint(canvas, Offset(x + 2, 2))
        ..dispose();
    }
  }

  static String _secondsLabel(double seconds) {
    final whole = seconds.floor();
    final tenth = ((seconds - whole) * 10).round();
    return '${whole ~/ 60}:${(whole % 60).toString().padLeft(2, '0')}'
        '${tenth == 0 ? '' : '.$tenth'}';
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.pps != pps || old.mark != mark || old.label != label;
}

/// One track's clips on the time axis.
class _Lane extends StatelessWidget {
  const _Lane({required this.track, required this.height, required this.px});

  final Track track;
  final double height;
  final double Function(int ticks) px;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          for (final clip in track.clips)
            Positioned(
              left: px(clip.start.toInt()),
              top: FramixSpace.s,
              bottom: FramixSpace.s,
              child: ClipBox(
                width: px(clip.duration.toInt()),
                audio: track.kind == TrackKind.TRACK_KIND_AUDIO,
              ),
            ),
        ],
      ),
    );
  }
}

/// One clip on its lane.
class ClipBox extends StatelessWidget {
  const ClipBox({super.key, required this.width, required this.audio});

  final double width;
  final bool audio;

  @override
  Widget build(BuildContext context) {
    final colors = FramixColors.of(context);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.elevated,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      // Track color always comes with an icon (docs/design-system.md).
      child: width < 24
          ? null
          : Icon(audio ? Icons.audiotrack : Icons.movie, size: 16),
    );
  }
}

/// Name, clip count and the mute/hide/lock switches of one track.
class _TrackHeader extends StatelessWidget {
  const _TrackHeader({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAudio = track.kind == TrackKind.TRACK_KIND_AUDIO;
    final cubit = context.read<TimelineCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FramixSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(isAudio ? Icons.audiotrack : Icons.videocam, size: 18),
              const SizedBox(width: FramixSpace.s),
              Expanded(
                child: Text(
                  isAudio
                      ? l10n.audioTrackName(track.number)
                      : l10n.videoTrackName(track.number),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            l10n.clipCount(track.clips.length),
            style: TextStyle(color: FramixColors.of(context).textMuted),
          ),
          Row(
            children: [
              IconButton(
                tooltip: l10n.muteTrack,
                isSelected: track.muted,
                icon: const Icon(Icons.volume_up),
                selectedIcon: const Icon(Icons.volume_off),
                onPressed: () =>
                    cubit.setTrackFlags(track, muted: !track.muted),
              ),
              if (!isAudio)
                IconButton(
                  tooltip: l10n.hideTrack,
                  isSelected: track.hidden,
                  icon: const Icon(Icons.visibility),
                  selectedIcon: const Icon(Icons.visibility_off),
                  onPressed: () =>
                      cubit.setTrackFlags(track, hidden: !track.hidden),
                ),
              IconButton(
                tooltip: l10n.lockTrack,
                isSelected: track.locked,
                icon: const Icon(Icons.lock_open),
                selectedIcon: const Icon(Icons.lock),
                onPressed: () =>
                    cubit.setTrackFlags(track, locked: !track.locked),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
