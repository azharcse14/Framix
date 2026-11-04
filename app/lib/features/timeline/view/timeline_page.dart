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
class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TimelineCubit>();
    // A phone on its side: wider than tall, and a compact height (Material window size
    // class, < 480 dp). Tablets in landscape keep the stacked layout.
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height && size.height < 480;
    return Scaffold(
      appBar: AppBar(
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
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Expanded(child: _Stage()),
                        AspectRatioBar(canvas: false),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Expanded(child: _Timeline()),
                        _AddTrackButtons(),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const Column(
              children: [
                PreviewView(),
                AspectRatioBar(),
                Expanded(child: _Timeline()),
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
  const _Timeline();

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
  const _AddTrackButtons();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TimelineCubit>();
    return Padding(
      padding: const EdgeInsets.all(FramixSpace.m),
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
