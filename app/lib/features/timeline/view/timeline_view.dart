import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui show Clip;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/proto/framix/v1/engine.pb.dart';
import '../../../core/ui/framix_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
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

    return Column(
      children: [
        _Toolbar(ticksPerSecond: ticksPerSecond),
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
                              rulerHeight + laneHeight * timeline.tracks.length,
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
                                            ? (_scroll.offset / (viewport / 2))
                                                      .floor() *
                                                  viewport /
                                                  2
                                            : window * viewport / 2;
                                        return Column(
                                          children: [
                                            for (final track in timeline.tracks)
                                              _Lane(
                                                track: track,
                                                height: laneHeight,
                                                px: px,
                                                tiles: _Tiles(
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
  const _Lane({
    required this.track,
    required this.height,
    required this.px,
    required this.tiles,
  });

  final Track track;
  final double height;
  final double Function(int ticks) px;
  final _Tiles tiles;

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
                tiles: track.kind == TrackKind.TRACK_KIND_AUDIO
                    ? const []
                    : tiles.of(clip, left: px(clip.start.toInt())),
              ),
            ),
        ],
      ),
    );
  }
}

/// One clip on its lane.
class ClipBox extends StatelessWidget {
  const ClipBox({
    super.key,
    required this.width,
    required this.audio,
    this.tiles = const [],
  });

  final double width;
  final bool audio;

  /// Thumbnail slots, each placed at its own offset inside the clip.
  final List<Widget> tiles;

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
      clipBehavior: ui.Clip.hardEdge,
      child: Stack(
        children: [
          ...tiles,
          // Track color always comes with an icon (docs/design-system.md).
          if (width >= 24)
            Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(audio ? Icons.audiotrack : Icons.movie, size: 16),
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
    required this.pps,
    required this.ticksPerSecond,
    required this.step,
    required this.from,
    required this.to,
  });

  static const width = 64.0;

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
            key: ValueKey((clip.mediaId.toInt(), i)),
            media: clip.mediaId.toInt(),
            // A photo has one picture; a video's tile shows the frame at its left edge.
            time: photo
                ? 0
                : _snap(clip.sourceStart.toInt() + _ticks(i * width)),
          ),
        ),
    ];
  }

  int _ticks(double px) => (px / pps * ticksPerSecond).round();

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
