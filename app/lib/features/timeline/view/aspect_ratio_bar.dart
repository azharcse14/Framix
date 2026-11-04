import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/proto/framix/v1/engine.pb.dart';
import '../../../core/ui/framix_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../export/view/export_buttons.dart';
import '../../export/view/export_settings_button.dart';
import '../bloc/timeline_cubit.dart';

/// Ratios offered to the user; the engine validates and stores them reduced.
const _presets = [(9, 16), (16, 9), (1, 1), (4, 5), (3, 4), (21, 9)];

/// Height of the canvas outline until the real preview Texture replaces it: 160 dp less the
/// platform preset row (one 48 dp chip row), so the bar keeps its height.
const _canvasHeight = 112.0;

/// Canvas outline in the engine's aspect ratio, platform preset chips with the export actions,
/// and the ratio chips.
class AspectRatioBar extends StatelessWidget {
  const AspectRatioBar({super.key, this.canvas = true});

  /// Whether the bar shows the [CanvasOutline] itself; false when the page gives the outline
  /// its own space (phone landscape).
  final bool canvas;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocSelector<TimelineCubit, TimelineChanged, (int, int)>(
      selector: (s) => (s.aspectWidth, s.aspectHeight),
      builder: (context, aspect) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canvas)
              const SizedBox(height: _canvasHeight, child: CanvasOutline()),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: l10n.exportPresets,
                    container: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: FramixSpace.s,
                      ),
                      child: Row(
                        children: [
                          for (final (preset, label) in [
                            (
                              ExportPreset.EXPORT_PRESET_SHORT_VIDEO,
                              l10n.presetShortVideo,
                            ),
                            (
                              ExportPreset.EXPORT_PRESET_YOUTUBE,
                              l10n.presetYouTube,
                            ),
                            (
                              ExportPreset.EXPORT_PRESET_INSTAGRAM_FEED,
                              l10n.presetInstagramFeed,
                            ),
                          ])
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: FramixSpace.s / 2,
                              ),
                              child: ActionChip(
                                label: Text(label),
                                onPressed: () => context
                                    .read<TimelineCubit>()
                                    .applyExportPreset(preset),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Export settings and export (save and share once done) go with the presets.
                const ExportSettingsButton(),
                const ExportButtons(),
              ],
            ),
            Semantics(
              label: l10n.aspectRatio,
              container: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(FramixSpace.s),
                child: Row(
                  children: [
                    for (final (w, h) in _presets)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FramixSpace.s / 2,
                        ),
                        child: ChoiceChip(
                          label: Text(l10n.aspectRatioLabel(w, h)),
                          selected: _same((w, h), aspect),
                          onSelected: (_) => context
                              .read<TimelineCubit>()
                              .setAspectRatio(w, h),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The canvas outline in the engine's aspect ratio, as large as fits; empty until the engine's
/// first TimelineChanged arrives.
class CanvasOutline extends StatelessWidget {
  const CanvasOutline({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BlocSelector<TimelineCubit, TimelineChanged, (int, int)>(
      selector: (s) => (s.aspectWidth, s.aspectHeight),
      builder: (context, aspect) {
        final (width, height) = aspect;
        // 0:0 until the engine's first TimelineChanged arrives.
        if (width <= 0 || height <= 0) return const SizedBox.shrink();
        return Center(
          child: AspectRatio(
            aspectRatio: width / height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.all(color: scheme.outline),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Same ratio (the engine reduces 21:9 to 7:3).
bool _same((int, int) a, (int, int) b) => a.$1 * b.$2 == a.$2 * b.$1;
