import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/proto/framix/v1/engine.pb.dart';
import '../../../core/ui/framix_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../export/view/export_buttons.dart';
import '../../export/view/export_settings_button.dart';
import '../../preview/bloc/preview_cubit.dart';
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
            // Same slot either way, so the rows below keep their state on rotation.
            SizedBox(
              height: canvas ? _canvasHeight : 0,
              child: canvas ? const CanvasOutline() : null,
            ),
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
                // Export settings and export (and the last result once done) go with the presets.
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
              child: const _PreviewUnavailable(),
            ),
          ),
        );
      },
    );
  }
}

/// Says so inside the canvas when the engine has no preview to show (UX-035); nothing otherwise.
/// The text keeps its size (and the user's text scale); a canvas too small for it gets an icon
/// labelled with the message instead.
class _PreviewUnavailable extends StatelessWidget {
  const _PreviewUnavailable();

  @override
  Widget build(BuildContext context) {
    if (!context.select((PreviewCubit c) => c.state is PreviewUnavailable)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final message = AppLocalizations.of(context).previewUnavailable;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.all(FramixSpace.s),
      child: LayoutBuilder(
        builder: (context, box) {
          final painter = TextPainter(
            text: TextSpan(
              text: message,
              style: DefaultTextStyle.of(context).style.merge(style),
            ),
            textAlign: TextAlign.center,
            textDirection: Directionality.of(context),
            locale: Localizations.localeOf(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: box.maxWidth);
          // The longest word must fit unbroken, and all lines in the height.
          final fits =
              painter.minIntrinsicWidth <= box.maxWidth &&
              painter.height <= box.maxHeight;
          painter.dispose();
          return Center(
            child: fits
                ? Text(message, textAlign: TextAlign.center, style: style)
                // The label is read; the tooltip is for sight only, not read twice.
                : Tooltip(
                    message: message,
                    excludeFromSemantics: true,
                    child: Semantics(
                      label: message,
                      child: Icon(
                        Icons.videocam_off_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

/// Same ratio (the engine reduces 21:9 to 7:3).
bool _same((int, int) a, (int, int) b) => a.$1 * b.$2 == a.$2 * b.$1;
