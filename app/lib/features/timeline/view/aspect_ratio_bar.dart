import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/proto/framix/v1/engine.pb.dart';
import '../../../core/ui/framix_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../bloc/timeline_cubit.dart';

/// Ratios offered to the user; the engine validates and stores them reduced.
const _presets = [(9, 16), (16, 9), (1, 1), (4, 5), (3, 4), (21, 9)];

/// Height of the canvas outline until the real preview Texture replaces it.
const _canvasHeight = 160.0;

/// Canvas outline in the engine's aspect ratio, and the preset chips to change it.
class AspectRatioBar extends StatelessWidget {
  const AspectRatioBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return BlocSelector<TimelineCubit, TimelineChanged, (int, int)>(
      selector: (s) => (s.aspectWidth, s.aspectHeight),
      builder: (context, aspect) {
        final (width, height) = aspect;
        // 0:0 until the engine's first TimelineChanged arrives.
        final known = width > 0 && height > 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _canvasHeight,
              child: known
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: width / height,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            // outline (border token) is ~1.4:1; this boundary must reach 3:1.
                            border: Border.all(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    )
                  : null,
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

/// Same ratio (the engine reduces 21:9 to 7:3).
bool _same((int, int) a, (int, int) b) => a.$1 * b.$2 == a.$2 * b.$1;
