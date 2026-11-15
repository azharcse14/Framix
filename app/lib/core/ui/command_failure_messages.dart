import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../engine/framix_engine.dart';
import '../engine/proto/framix/v1/engine.pb.dart';
import 'messages.dart';

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
  late final StreamSubscription<void> _failures;

  @override
  void initState() {
    super.initState();
    _failures = widget.engine.failures.listen((failed) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      if (failed.kind == FailureKind.FAILURE_KIND_AUTOSAVE) {
        showAutosaveFailed(context, l10n.autosaveFailed);
      } else {
        showMessage(context, l10n.commandFailed);
      }
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
