import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/proto/framix/v1/engine.pb.dart';
import '../../../core/ui/framix_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../preview/view/spike_preview.dart';
import '../bloc/timeline_cubit.dart';

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
          const SpikePreview(), // SPIKE (P1-001)
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
    return ListTile(
      leading: Icon(isAudio ? Icons.audiotrack : Icons.videocam),
      title: Text(
        isAudio
            ? l10n.audioTrackName(track.number)
            : l10n.videoTrackName(track.number),
      ),
      subtitle: Text(l10n.clipCount(track.clips.length)),
    );
  }
}
