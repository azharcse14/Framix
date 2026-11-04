import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/proto/framix/v1/engine.pb.dart';
import '../../../core/ui/framix_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../preview/bloc/preview_cubit.dart';
import '../../preview/view/preview_view.dart';
import '../bloc/timeline_cubit.dart';
import 'aspect_ratio_bar.dart';
import 'import_buttons.dart';
import 'timeline_view.dart';

/// The timeline: tracks on a time axis, undo/redo, and add-track actions.
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  /// Width of the timeline pane beside the canvas in phone landscape: the timeline toolbar
  /// (timecode and four 48 dp buttons) and a video clip's seven 48 dp actions in one row.
  static const sidePaneWidth = 360.0;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  // Rotating moves these between the two layouts; the keys keep their state (export guard,
  // timeline scroll) instead of building them anew.
  final _bar = GlobalKey();
  final _timeline = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TimelineCubit>();
    // A phone on its side: compact height (< 480 dp) and at least medium width (600 dp,
    // Material window size classes), so the canvas keeps room beside the timeline pane.
    // Tablets keep the stacked layout.
    final size = MediaQuery.sizeOf(context);
    final landscape = size.height < 480 && size.width >= 600;
    return Scaffold(
      appBar: AppBar(
        // Material's landscape app bar height: the timeline needs every row.
        toolbarHeight: landscape ? kMinInteractiveDimension : null,
        title: Text(l10n.appTitle),
        actions: [
          const ImportButtons(),
          BlocSelector<TimelineCubit, TimelineChanged, bool>(
            selector: (s) => s.canUndo,
            builder: (_, canUndo) => IconButton(
              icon: const Icon(Icons.undo),
              tooltip: l10n.undo,
              onPressed: canUndo ? cubit.undo : null,
            ),
          ),
          BlocSelector<TimelineCubit, TimelineChanged, bool>(
            selector: (s) => s.canRedo,
            builder: (_, canRedo) => IconButton(
              icon: const Icon(Icons.redo),
              tooltip: l10n.redo,
              onPressed: canRedo ? cubit.redo : null,
            ),
          ),
          // The export actions sit with the platform presets (AspectRatioBar): nine 48 dp
          // actions don't fit a phone's app bar, and a second row costs timeline height.
        ],
      ),
      body: landscape
          // Phone landscape: the canvas takes the free height, the timeline and the add-track
          // actions sit beside it.
          ? SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Expanded(child: _Stage()),
                        AspectRatioBar(key: _bar, canvas: false),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: TimelinePage.sidePaneWidth,
                    child: Column(
                      children: [
                        Expanded(child: _Timeline(key: _timeline)),
                        const _AddTrackButtons(padding: FramixSpace.s),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                const PreviewView(),
                AspectRatioBar(key: _bar),
                Expanded(child: _Timeline(key: _timeline)),
              ],
            ),
      // Primary actions in the lower half (docs/design-system.md, touch).
      bottomNavigationBar: landscape
          ? null
          : const SafeArea(child: _AddTrackButtons()),
    );
  }
}

/// The engine's preview once it reports a texture; the canvas outline until then.
class _Stage extends StatelessWidget {
  const _Stage();

  @override
  Widget build(BuildContext context) =>
      context.select((PreviewCubit c) => c.state == null)
      ? const CanvasOutline()
      : const Center(child: PreviewView());
}

/// The tracks, or a hint while there are none.
class _Timeline extends StatelessWidget {
  const _Timeline({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimelineCubit, TimelineChanged>(
      builder: (context, state) => state.tracks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(FramixSpace.m),
                child: Text(
                  AppLocalizations.of(context).timelineEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : TimelineView(timeline: state),
    );
  }
}

/// Add a video or an audio track.
class _AddTrackButtons extends StatelessWidget {
  const _AddTrackButtons({this.padding = FramixSpace.m});

  /// Around the row; tighter beside the canvas, where height is short.
  final double padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TimelineCubit>();
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => cubit.addTrack(TrackKind.TRACK_KIND_VIDEO),
              icon: const Icon(Icons.videocam),
              label: Text(l10n.addVideoTrack),
            ),
          ),
          const SizedBox(width: FramixSpace.s),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => cubit.addTrack(TrackKind.TRACK_KIND_AUDIO),
              icon: const Icon(Icons.audiotrack),
              label: Text(l10n.addAudioTrack),
            ),
          ),
        ],
      ),
    );
  }
}
