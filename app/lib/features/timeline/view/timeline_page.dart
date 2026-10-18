import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/proto/framix/v1/engine.pb.dart';
import '../../../core/ui/framix_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../preview/view/preview_view.dart';
import '../bloc/timeline_cubit.dart';
import 'aspect_ratio_bar.dart';
import 'import_buttons.dart';

/// The timeline: track list, undo/redo, and add-track actions.
class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TimelineCubit>();
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
        ],
      ),
      body: Column(
        children: [
          const PreviewView(),
          const AspectRatioBar(),
          Expanded(
            child: BlocBuilder<TimelineCubit, TimelineChanged>(
              builder: (context, state) => state.tracks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(FramixSpace.m),
                        child: Text(
                          l10n.timelineEmpty,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: state.tracks.length,
                      itemBuilder: (_, i) => _TrackTile(track: state.tracks[i]),
                    ),
            ),
          ),
        ],
      ),
      // Primary actions in the lower half (docs/design-system.md, touch).
      bottomNavigationBar: SafeArea(
        child: Padding(
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
        ),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAudio = track.kind == TrackKind.TRACK_KIND_AUDIO;
    final cubit = context.read<TimelineCubit>();
    return ListTile(
      leading: Icon(isAudio ? Icons.audiotrack : Icons.videocam),
      title: Text(
        isAudio
            ? l10n.audioTrackName(track.number)
            : l10n.videoTrackName(track.number),
      ),
      subtitle: Text(l10n.clipCount(track.clips.length)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.muteTrack,
            isSelected: track.muted,
            icon: const Icon(Icons.volume_up),
            selectedIcon: const Icon(Icons.volume_off),
            onPressed: () => cubit.setTrackFlags(track, muted: !track.muted),
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
            onPressed: () => cubit.setTrackFlags(track, locked: !track.locked),
          ),
        ],
      ),
    );
  }
}
