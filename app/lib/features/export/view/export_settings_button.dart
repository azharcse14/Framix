import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/proto/framix/v1/engine.pb.dart';
import '../../../core/ui/framix_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../timeline/bloc/timeline_cubit.dart';

/// Opens the export settings sheet: resolution, frame rate and bitrate, with the frame size,
/// bitrate and file size the engine works out for them.
class ExportSettingsButton extends StatelessWidget {
  const ExportSettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).exportSettings,
    icon: const Icon(Icons.tune),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Shown at once: the settings are read and changed in place, nothing to reveal.
      sheetAnimationStyle: AnimationStyle.noAnimation,
      builder: (_) => BlocProvider.value(
        value: context.read<TimelineCubit>(),
        child: const _ExportSettingsSheet(),
      ),
    ),
  );
}

class _ExportSettingsSheet extends StatelessWidget {
  const _ExportSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TimelineCubit>();
    return BlocSelector<TimelineCubit, TimelineChanged, ExportInfo>(
      selector: (s) => s.export,
      builder: (context, e) {
        void set({ExportResolution? resolution, ExportFps? fps, int? kbps}) =>
            cubit.setExportSettings(
              resolution ?? e.resolution,
              fps ?? e.fps,
              kbps ?? e.kbps,
            );
        final auto = e.kbps == 0;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(FramixSpace.m),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.exportResolution),
                const SizedBox(height: FramixSpace.s),
                SegmentedButton<ExportResolution>(
                  segments: [
                    for (final (r, label) in [
                      (
                        ExportResolution.EXPORT_RESOLUTION_720P,
                        l10n.exportResolution720p,
                      ),
                      (
                        ExportResolution.EXPORT_RESOLUTION_1080P,
                        l10n.exportResolution1080p,
                      ),
                      (
                        ExportResolution.EXPORT_RESOLUTION_2K,
                        l10n.exportResolution2k,
                      ),
                      (
                        ExportResolution.EXPORT_RESOLUTION_4K,
                        l10n.exportResolution4k,
                      ),
                    ])
                      ButtonSegment(value: r, label: Text(label)),
                  ],
                  selected: {e.resolution},
                  onSelectionChanged: (s) => set(resolution: s.first),
                ),
                const SizedBox(height: FramixSpace.m),
                Text(l10n.exportFrameRate),
                const SizedBox(height: FramixSpace.s),
                SegmentedButton<ExportFps>(
                  segments: [
                    for (final (f, n) in [
                      (ExportFps.EXPORT_FPS_24, 24),
                      (ExportFps.EXPORT_FPS_30, 30),
                      (ExportFps.EXPORT_FPS_60, 60),
                    ])
                      ButtonSegment(
                        value: f,
                        label: Text(l10n.framesPerSecond(n)),
                      ),
                  ],
                  selected: {e.fps},
                  onSelectionChanged: (s) => set(fps: s.first),
                ),
                const SizedBox(height: FramixSpace.m),
                // Turning auto off keeps the bitrate the engine was using.
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.autoBitrate),
                  value: auto,
                  onChanged: (on) => set(kbps: on ? 0 : e.effectiveKbps),
                ),
                if (!auto && e.maxKbps > e.minKbps)
                  _BitrateSlider(
                    kbps: e.kbps,
                    min: e.minKbps,
                    max: e.maxKbps,
                    onDone: (kbps) => set(kbps: kbps),
                  ),
                Text(l10n.bitrateKbps(e.effectiveKbps)),
                Text(l10n.exportFrameSize(e.width, e.height)),
                Text(
                  l10n.exportEstimate(
                    (e.estimatedBytes.toInt() + 999999) ~/ 1000000,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Follows the finger locally and sends one SetExportSettings on release, so a drag is one
/// undo step.
class _BitrateSlider extends StatefulWidget {
  const _BitrateSlider({
    required this.kbps,
    required this.min,
    required this.max,
    required this.onDone,
  });

  final int kbps;
  final int min;
  final int max;
  final void Function(int kbps) onDone;

  @override
  State<_BitrateSlider> createState() => _BitrateSliderState();
}

class _BitrateSliderState extends State<_BitrateSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) => Slider(
    min: widget.min.toDouble(),
    max: widget.max.toDouble(),
    value: _dragging ?? widget.kbps.clamp(widget.min, widget.max).toDouble(),
    label: AppLocalizations.of(context)
        .bitrateKbps((_dragging ?? widget.kbps).round()),
    onChanged: (v) => setState(() => _dragging = v),
    onChangeEnd: (v) {
      setState(() => _dragging = null);
      widget.onDone(v.round());
    },
  );
}
