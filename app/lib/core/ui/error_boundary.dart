import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import 'framix_theme.dart';

/// Keeps a bug from taking a screen or the app down (OVL-024): a widget that fails to build
/// shows [ErrorPanel] in its place, and an uncaught async error is reported through
/// [FlutterError.reportError] (where Sentry hooks in, P1-041) instead of escaping. Build
/// errors are still reported by Flutter as before.
void installErrorBoundary() {
  ErrorWidget.builder = (details) => const ErrorPanel();
  PlatformDispatcher.instance.onError = (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'framix'),
    );
    return true;
  };
}

/// What a widget that failed to build shows: a short "something went wrong" on the surface
/// colour. Above the app's theme or localizations it shows an empty panel.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FramixColors>();
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return ColoredBox(
      color: colors?.surface ?? Colors.transparent,
      child: l10n == null
          ? const SizedBox.expand()
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(FramixSpace.m),
                child: Text(
                  l10n.somethingWentWrong,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors?.textMuted),
                ),
              ),
            ),
    );
  }
}
