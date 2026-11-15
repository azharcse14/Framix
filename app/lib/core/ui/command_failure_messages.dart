import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../engine/framix_engine.dart';
import '../engine/proto/framix/v1/engine.pb.dart';

/// Shows a short generic message whenever the engine refuses a command that no feature
/// reports itself (P1-049), or that an autosave failed (P1-121). The reason is for logs,
/// never shown.
class CommandFailureMessages extends StatefulWidget {
  const CommandFailureMessages({
    super.key,
    required this.engine,
    required this.child,
  });

  final FramixEngine engine;
  final Widget child;

  @override
  State<CommandFailureMessages> createState() => _CommandFailureMessagesState();
}

class _CommandFailureMessagesState extends State<CommandFailureMessages> {
  /// Longer than the default 4 s: the engine reports a failed autosave only once per streak.
  static const _autosaveDuration = Duration(seconds: 10);

  late final StreamSubscription<void> _failures;
  bool _autosaveShowing = false;

  @override
  void initState() {
    super.initState();
    _failures = widget.engine.failures.listen((failed) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);
      if (failed.kind == FailureKind.FAILURE_KIND_AUTOSAVE) {
        messenger.hideCurrentSnackBar();
        _autosaveShowing = true;
        messenger
            .showSnackBar(
              SnackBar(
                content: Text(l10n.autosaveFailed),
                duration: _autosaveDuration,
              ),
            )
            .closed
            .then((_) => _autosaveShowing = false);
        return;
      }
      // UX-037: the engine reports a failed autosave once per streak, so a generic failure
      // waits behind it instead of hiding it.
      if (!_autosaveShowing) messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(l10n.commandFailed)));
    });
  }

  @override
  void dispose() {
    _failures.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
