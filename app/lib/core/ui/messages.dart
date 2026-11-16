import 'package:material_ui/material_ui.dart';

/// Longer than the default 4 s: the engine reports a failed autosave only once per streak.
const _autosaveDuration = Duration(seconds: 10);

/// What a messenger is showing that must not be hidden (UX-037), and the one message
/// waiting behind it (UX-038).
class _Autosave {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showing;
  SnackBar? waiting;
  bool waitingImportant = false;
}

final _autosave = Expando<_Autosave>();

_Autosave _of(ScaffoldMessengerState messenger) =>
    _autosave[messenger] ??= _Autosave();

/// Shows [text], replacing a message still showing. A failed-autosave message is never
/// replaced: one message waits behind it. An [important] one-time notice takes the waiting
/// place from a generic one; any other message is dropped, including a second important
/// notice while one already waits (accepted limit: one slot).
void showMessage(BuildContext context, String text, {bool important = false}) {
  final messenger = ScaffoldMessenger.of(context);
  final autosave = _of(messenger);
  final snackBar = SnackBar(content: Text(text));
  if (autosave.showing == null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  } else if (autosave.waiting == null ||
      (important && !autosave.waitingImportant)) {
    autosave
      ..waiting = snackBar
      ..waitingImportant = important;
  }
}

/// Shows the failed-autosave [text] for longer, replacing every message shown. A message
/// waiting behind an earlier autosave message keeps waiting.
void showAutosaveFailed(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  final autosave = _of(messenger);
  messenger.clearSnackBars();
  final controller = messenger.showSnackBar(
    SnackBar(content: Text(text), duration: _autosaveDuration),
  );
  autosave.showing = controller;
  // An older autosave message closes after a newer one shows; only its own close counts.
  controller.closed.then((_) {
    if (!identical(autosave.showing, controller)) return;
    final waiting = autosave.waiting;
    autosave
      ..showing = null
      ..waiting = null
      ..waitingImportant = false;
    if (waiting != null && messenger.mounted) messenger.showSnackBar(waiting);
  });
}
