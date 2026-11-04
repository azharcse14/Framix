import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui show Clip;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/proto/framix/v1/engine.pb.dart';
import '../../../core/media/media_importer.dart';
import '../../../core/ui/framix_theme.dart';
import '../../../core/ui/timecode.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../bloc/clip_selection_cubit.dart';
import '../bloc/playhead_cubit.dart';
import '../bloc/thumbnail_cubit.dart';
import '../bloc/timeline_cubit.dart';
import '../bloc/timeline_zoom_cubit.dart';

/// The tracks on a time axis: headers, a ruler, clip lanes and the playhead. Positions come
/// from engine ticks; the only state here is the zoom (pixels per second).
class TimelineView extends StatefulWidget {
  const TimelineView({super.key, required this.timeline});

  final TimelineChanged timeline;

  /// The ruler; tap or drag it to seek.
  static const rulerKey = ValueKey('timeline-ruler');

  /// The playhead line.
  static const playheadKey = ValueKey('timeline-playhead');

  static const _headerWidth = 176.0;
  // A touch target (48dp), not just the marks.
  static const _rulerHeight = 48.0;

  /// Lane height follows the header: two text lines plus the 48dp switches. Each line's font
  /// size is scaled on its own (system scaling is nonlinear on Android 14+); a Bangla line is
  /// about twice its font size tall.
  static double _laneHeight(BuildContext context) {
    final fontSize = DefaultTextStyle.of(context).style.fontSize ?? 14;
    final line = MediaQuery.textScalerOf(context).scale(fontSize) * 2;
    return 2 * line + 48 + FramixSpace.m;
  }

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  /// The horizontal scroll; lanes build thumbnail tiles only near what it shows.
  final _scroll = ScrollController();

  /// Which half-screen the view starts in; lanes rebuild only when it changes, not per pixel.
  final _window = ValueNotifier<int>(0);
  double _viewport = 1;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_moveWindow);
  }

  /// Sends where a long-press drag left [clip]: the drag's lanes up or down (kept inside the
  /// timeline) and its distance along the time axis. The engine checks the spot.
  void _move(
    Clip clip,
    Track from,
    Offset by,
    double laneHeight,
    int Function(double px) ticks,
  ) {
    final tracks = widget.timeline.tracks;
    final index = tracks.indexWhere((t) => t.id == from.id);
    // The track went away during the drag.
    if (index < 0) return;
    final to = (index + (by.dy / laneHeight).round()).clamp(
      0,
      tracks.length - 1,
    );
    context.read<TimelineCubit>().moveClip(
      clip,
      tracks[to].id,
      clip.start.toInt() + ticks(by.dx),
      snapWithin: ticks(_snapRadius),
    );
  }

  void _moveWindow() =>
      _window.value = (_scroll.offset / (_viewport / 2)).floor();

  @override
  void dispose() {
    _scroll.dispose();
    _window.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const rulerHeight = TimelineView._rulerHeight;
    final timeline = widget.timeline;
    final pps = context.watch<TimelineZoomCubit>().state;
    final ticksPerSecond = timeline.ticksPerSecond.toInt();
    final laneHeight = TimelineView._laneHeight(context);
    final step = timeline.thumbnailStep.toInt();
    double px(int ticks) =>
        ticksPerSecond == 0 ? 0 : ticks / ticksPerSecond * pps;
    int ticks(double px) => _ticksAt(px, pps, ticksPerSecond);

    // The selection is this view's own state: it ends when the view does.
    return BlocProvider(
      create: (_) => ClipSelectionCubit(),
      child: Column(
        children: [
          _Toolbar(ticksPerSecond: ticksPerSecond),
          _ClipActions(timeline: timeline),
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: TimelineView._headerWidth,
                    child: Column(
                      children: [
                        const SizedBox(height: rulerHeight),
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
                        final viewport = box.maxWidth;
                        _viewport = math.max(viewport, 1);
                        return SingleChildScrollView(
                          controller: _scroll,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: width,
                            height:
                                rulerHeight +
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
                                        height: rulerHeight,
                                      ),
                                      // Thumbnails only for one screen either side of the view.
                                      ValueListenableBuilder(
                                        valueListenable: _window,
                                        builder: (context, window, _) {
                                          // The scroll may be clamped (zoom out)
                                          // without a notification; read it here.
                                          final at = _scroll.hasClients
                                              ? (_scroll.offset /
                                                            (viewport / 2))
                                                        .floor() *
                                                    viewport /
                                                    2
                                              : window * viewport / 2;
                                          return Column(
                                            children: [
                                              for (final track
                                                  in timeline.tracks)
                                                _Lane(
                                                  track: track,
                                                  height: laneHeight,
                                                  px: px,
                                                  ticks: ticks,
                                                  onMove: (clip, by) => _move(
                                                    clip,
                                                    track,
                                                    by,
                                                    laneHeight,
                                                    ticks,
                                                  ),
                                                  tiles: _Tiles(
                                                    project: widget
                                                        .timeline
                                                        .project
                                                        .toInt(),
                                                    pps: pps,
                                                    ticksPerSecond:
                                                        ticksPerSecond,
                                                    step: step,
                                                    from: at - viewport,
                                                    to: at + 2 * viewport,
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                // The playhead changes often; only this line rebuilds.
                                BlocBuilder<PlayheadCubit, int>(
                                  builder: (context, playhead) => Positioned(
                                    key: TimelineView.playheadKey,
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
      ),
    );
  }
}

/// Playhead time, previous/next frame, and the zoom buttons (the button path for pinch,
/// docs/design-system.md).
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
              timecode(playhead, ticksPerSecond),
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: l10n.previousFrame,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => context.read<PlayheadCubit>().stepFrames(-1),
          ),
          IconButton(
            tooltip: l10n.nextFrame,
            icon: const Icon(Icons.chevron_right),
            onPressed: () => context.read<PlayheadCubit>().stepFrames(1),
          ),
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

/// What can be done to the selected clip; nothing while no clip is selected. The engine checks
/// every edit (e.g. a split needs the playhead inside the clip).
class _ClipActions extends StatelessWidget {
  const _ClipActions({required this.timeline});

  final TimelineChanged timeline;

  /// One row of icon buttons.
  static const _rowHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TimelineCubit>();
    final selection = context.watch<ClipSelectionCubit>();
    final found = _find(selection.state);
    // The row's height stays reserved, so selecting never moves the lanes under the finger.
    if (found == null) return const SizedBox(height: _rowHeight);
    final (track, clip) = found;
    final end = clip.start + clip.duration;
    // The neighbour that starts where this clip ends, if any.
    final next = track.clips.where((c) => c.start == end).firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FramixSpace.s),
      child: Wrap(
        children: [
          IconButton(
            tooltip: l10n.splitClip,
            icon: const Icon(Icons.content_cut),
            onPressed: () =>
                cubit.splitClip(clip, context.read<PlayheadCubit>().state),
          ),
          IconButton(
            tooltip: l10n.trimStartToPlayhead,
            icon: const Icon(Icons.first_page),
            onPressed: () =>
                cubit.trimToPlayhead(clip, ClipEdge.CLIP_EDGE_START),
          ),
          IconButton(
            tooltip: l10n.trimEndToPlayhead,
            icon: const Icon(Icons.last_page),
            onPressed: () => cubit.trimToPlayhead(clip, ClipEdge.CLIP_EDGE_END),
          ),
          IconButton(
            tooltip: l10n.replaceClip,
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => cubit.replaceClip(
              clip,
              context.read<MediaImporter>().pickFromGallery,
            ),
          ),
          IconButton(
            tooltip: l10n.duplicateClip,
            icon: const Icon(Icons.control_point_duplicate),
            onPressed: () => cubit.duplicateClip(clip),
          ),
          // A locked track's photos keep their length, so tapping there would look dead.
          if (clip.mediaKind == MediaKind.MEDIA_KIND_IMAGE && !track.locked)
            IconButton(
              tooltip: l10n.applyDurationToAllPhotos,
              icon: const Icon(Icons.timer_outlined),
              onPressed: () => cubit.applyDurationToAllPhotos(clip),
            ),
          IconButton(
            tooltip: l10n.mergeClip,
            icon: const Icon(Icons.call_merge),
            onPressed: next == null || !clip.mergeableWithNext
                ? null
                : () => cubit.mergeClips(clip, next),
          ),
          IconButton(
            tooltip: l10n.deleteClip,
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              cubit.removeClip(clip);
              selection.clear();
            },
          ),
        ],
      ),
    );
  }

  /// The selected clip and its track; null if none is selected or it is gone.
  (Track, Clip)? _find(int id) {
    if (id == 0) return null;
    for (final track in timeline.tracks) {
      for (final clip in track.clips) {
        if (clip.id.toInt() == id) return (track, clip);
      }
    }
    return null;
  }
}

/// The engine's 0xRRGGBBAA as an opaque Flutter color, as the renderer draws it.
Color _rgba(int rgba) => Color(0xff000000 | (rgba >> 8));

/// Ticks covered by [px] pixels at [pps] pixels per second.
int _ticksAt(double px, double pps, int ticksPerSecond) =>
    (px / pps * ticksPerSecond).round();

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
      // A touch radius at this zoom; the engine decides what to snap to.
      playhead.seek(
        _ticksAt(dx, pps, ticksPerSecond),
        snapWithin: _ticksAt(_snapRadius, pps, ticksPerSecond),
      );
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
        value: timecode(at, ticksPerSecond),
        increasedValue: timecode(at + ticksPerSecond, ticksPerSecond),
        decreasedValue: timecode(
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
  const _Lane({
    required this.track,
    required this.height,
    required this.px,
    required this.ticks,
    required this.onMove,
    required this.tiles,
  });

  final Track track;
  final double height;
  final double Function(int ticks) px;
  final int Function(double px) ticks;

  /// A clip was long-pressed and dragged by an offset in pixels.
  final void Function(Clip clip, Offset by) onMove;

  /// Smallest touch target (docs/design-system.md).
  static const _minTarget = 48.0;
  final _Tiles tiles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selection = context.watch<ClipSelectionCubit>();
    final cubit = context.read<TimelineCubit>();
    return SizedBox(
      height: height,
      child: Stack(
        // A dragged clip is drawn over the other lanes.
        clipBehavior: ui.Clip.none,
        children: [
          for (final clip in track.clips)
            Positioned(
              left: px(clip.start.toInt()),
              top: FramixSpace.s,
              bottom: FramixSpace.s,
              child: Semantics(
                button: true,
                selected: selection.state == clip.id.toInt(),
                label: l10n.clip,
                child: _MovableClip(
                  onTap: () => selection.toggle(clip.id.toInt()),
                  onMove: (by) => onMove(clip, by),
                  child: ClipBox(
                    width: px(clip.duration.toInt()),
                    audio: track.kind == TrackKind.TRACK_KIND_AUDIO,
                    selected: selection.state == clip.id.toInt(),
                    fill: clip.mediaKind == MediaKind.MEDIA_KIND_COLOR
                        ? _rgba(clip.color)
                        : null,
                    tiles:
                        track.kind == TrackKind.TRACK_KIND_AUDIO ||
                            clip.mediaKind == MediaKind.MEDIA_KIND_COLOR
                        ? const []
                        : tiles.of(clip, left: px(clip.start.toInt())),
                  ),
                ),
              ),
            ),
          // A clip narrower than a touch target at this zoom gets a 48 dp one over it (and over
          // its neighbour's start).
          for (final clip in track.clips)
            if (px(clip.duration.toInt()) < _minTarget)
              Positioned(
                left: px(clip.start.toInt()),
                top: 0,
                bottom: 0,
                width: _minTarget,
                // ponytail: the clip itself does not follow the finger from here; it lands on
                // release. Lift it into an overlay if that shows.
                child: ExcludeSemantics(
                  child: _MovableClip(
                    onTap: () => selection.toggle(clip.id.toInt()),
                    onMove: (by) => onMove(clip, by),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
          // Drawn after the clips so they take touches at the edges.
          for (final clip in track.clips)
            if (selection.state == clip.id.toInt()) ...[
              _TrimHandle(
                // Left of the clip, clamped into the lane for a clip at 0.
                left: math.max(0, px(clip.start.toInt()) - _TrimHandle.size),
                label: l10n.trimStart,
                onTrim: (dx) {
                  final end = (clip.start + clip.duration).toInt();
                  cubit.trimClip(
                    clip,
                    clip.start.toInt() + ticks(dx),
                    end,
                    snapWithin: ticks(_snapRadius),
                  );
                },
              ),
              _TrimHandle(
                left: px((clip.start + clip.duration).toInt()),
                label: l10n.trimEnd,
                onTrim: (dx) {
                  final end = (clip.start + clip.duration).toInt() + ticks(dx);
                  cubit.trimClip(
                    clip,
                    clip.start.toInt(),
                    end,
                    snapWithin: ticks(_snapRadius),
                  );
                },
              ),
            ],
        ],
      ),
    );
  }
}

/// How close (dp) a scrub or a dropped trim edge must come to an edge to snap to it; the engine
/// decides what it snaps to.
const _snapRadius = 12.0;

/// A 48 dp drag target just outside a clip edge (inside it only for a clip at 0, where the
/// lane ends), so it rarely covers the clip; while shown it wins over what lies under it. It follows the
/// finger and reports the drag distance in pixels once on release; the clip moves when the
/// engine answers.
// ponytail: the handle springs back on release and the clip follows on the engine's reply (a
// frame later); a refused trim just springs back. Hold the offset until the reply if it shows.
class _TrimHandle extends StatefulWidget {
  const _TrimHandle({
    required this.left,
    required this.label,
    required this.onTrim,
  });

  final double left;
  final String label;
  final void Function(double dx) onTrim;

  static const size = 48.0;

  @override
  State<_TrimHandle> createState() => _TrimHandleState();
}

class _TrimHandleState extends State<_TrimHandle> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.left + _dx,
      top: 0,
      bottom: 0,
      width: _TrimHandle.size,
      child: Semantics(
        label: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Count the distance from the touch, slop included, so the edge lands under the
          // finger.
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragUpdate: (d) => setState(() => _dx += d.delta.dx),
          onHorizontalDragEnd: (_) => _release(),
          onHorizontalDragCancel: _release,
          child: Center(
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: FramixColors.of(context).accentText,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _release() {
    final dx = _dx;
    setState(() => _dx = 0);
    if (dx != 0) widget.onTrim(dx);
  }
}

/// A clip that is tapped to select it, or long-pressed and dragged to move it: it follows the
/// finger and reports the offset once on release.
// ponytail: like the trim handles it springs back on release and the clip lands on the
// engine's reply; a refused move springs back and shows the generic failure message.
class _MovableClip extends StatefulWidget {
  const _MovableClip({
    required this.onTap,
    required this.onMove,
    required this.child,
  });

  final VoidCallback onTap;
  final void Function(Offset by) onMove;
  final Widget child;

  @override
  State<_MovableClip> createState() => _MovableClipState();
}

class _MovableClipState extends State<_MovableClip> {
  Offset _by = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPressMoveUpdate: (d) => setState(() => _by = d.offsetFromOrigin),
      onLongPressEnd: (_) => _release(),
      onLongPressCancel: () => setState(() => _by = Offset.zero),
      child: Transform.translate(offset: _by, child: widget.child),
    );
  }

  void _release() {
    final by = _by;
    setState(() => _by = Offset.zero);
    if (by != Offset.zero) widget.onMove(by);
  }
}

/// One clip on its lane.
class ClipBox extends StatelessWidget {
  const ClipBox({
    super.key,
    required this.width,
    required this.audio,
    this.selected = false,
    this.tiles = const [],
    this.fill,
  });

  final double width;
  final bool audio;

  /// A color clip's own color, shown instead of thumbnails.
  final Color? fill;

  /// The user selected it; drawn with the accent border.
  final bool selected;

  /// Thumbnail slots, each placed at its own offset inside the clip.
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final colors = FramixColors.of(context);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: fill ?? colors.elevated,
        border: selected
            ? Border.all(color: colors.accentText, width: 2)
            : Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: ui.Clip.hardEdge,
      child: Stack(
        children: [
          ...tiles,
          // Track color always comes with an icon (docs/design-system.md).
          if (width >= 24)
            Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                audio
                    ? Icons.audiotrack
                    : fill != null
                    ? Icons.format_color_fill
                    : Icons.movie,
                size: 16,
              ),
            ),
        ],
      ),
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

/// Which thumbnail slots a clip shows: about [width] px each, only inside [from]..[to] (lane
/// coordinates), at source times snapped to the engine's [step].
class _Tiles {
  const _Tiles({
    required this.project,
    required this.pps,
    required this.ticksPerSecond,
    required this.step,
    required this.from,
    required this.to,
  });

  static const width = 64.0;

  /// The engine's project number: a slot of another project is another tile, even with the
  /// same media id (ids restart), so it asks again.
  final int project;
  final double pps;
  final int ticksPerSecond;
  final int step;
  final double from;
  final double to;

  List<Widget> of(Clip clip, {required double left}) {
    if (ticksPerSecond == 0 || step <= 0) return const [];
    final clipWidth = clip.duration.toInt() / ticksPerSecond * pps;
    final count = (clipWidth / width).ceil();
    final first = math.max(0, ((from - left) / width).floor());
    final last = math.min(count - 1, ((to - left) / width).ceil());
    final photo = clip.mediaKind == MediaKind.MEDIA_KIND_IMAGE;
    return [
      for (var i = first; i <= last; i++)
        Positioned(
          left: i * width,
          top: 0,
          bottom: 0,
          width: width,
          child: ThumbnailTile(
            // A slot keeps its own state only while it shows the same picture.
            key: ValueKey((project, clip.mediaId.toInt(), i)),
            media: clip.mediaId.toInt(),
            // A photo has one picture; a video's tile shows the frame at its left edge.
            time: photo
                ? 0
                : _snap(clip.sourceStart.toInt() + _ticks(i * width)),
          ),
        ),
    ];
  }

  int _ticks(double px) => _ticksAt(px, pps, ticksPerSecond);

  int _snap(int ticks) => ticks - ticks % step;
}

/// One thumbnail slot inside a clip: the image once the engine reports it, a plain fill before.
/// Asks for its thumbnail when first built, so only shown slots are ever made.
class ThumbnailTile extends StatefulWidget {
  const ThumbnailTile({super.key, required this.media, required this.time});

  final int media;
  final int time;

  @override
  State<ThumbnailTile> createState() => _ThumbnailTileState();
}

class _ThumbnailTileState extends State<ThumbnailTile> {
  late int _maxSide;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Device pixels of a slot, inside the engine's 32..512 range.
    _maxSide = (_Tiles.width * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(32, 512);
    context.read<ThumbnailCubit>().request(widget.media, [
      widget.time,
    ], _maxSide);
  }

  @override
  void didUpdateWidget(ThumbnailTile old) {
    super.didUpdateWidget(old);
    if (old.media != widget.media || old.time != widget.time) {
      context.read<ThumbnailCubit>().request(widget.media, [
        widget.time,
      ], _maxSide);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (media: widget.media, time: widget.time, maxSide: _maxSide);
    return BlocSelector<ThumbnailCubit, Map<ThumbnailKey, String>, String?>(
      selector: (files) => files[key],
      builder: (context, path) => path == null
          ? const SizedBox.expand()
          : Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: _maxSide,
              gaplessPlayback: true,
              // The OS may purge the cache while the app runs: show the plain fill.
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
    );
  }
}
