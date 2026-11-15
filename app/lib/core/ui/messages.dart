import 'package:material_ui/material_ui.dart';

/// Longer than the default 4 s: the engine reports a failed autosave only once per streak.
const _autosaveDuration = Duration(seconds: 10);

/// What a messenger is showing that must not be hidden (UX-037).
class _Autosave {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showing;
  bool queued = false;
}

final _autosave = Expando<_Autosave>();

_Autosave _of(ScaffoldMessengerState messenger) =>
    _autosave[messenger] ??= _Autosave();

/// Shows [text], replacing a message still showing. A failed-autosave message is never
/// replaced: one message waits behind it and any more are dropped.
void showMessage(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  final autosave = _of(messenger);
  final snackBar = SnackBar(content: Text(text));
  if (autosave.showing == null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  } else if (!autosave.queued) {
    autosave.queued = true;
    messenger.showSnackBar(snackBar);
  }
}

/// Shows the failed-autosave [text] for longer, replacing every message shown or waiting.
void showAutosaveFailed(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  final autosave = _of(messenger);
  messenger.clearSnackBars();
  final controller = messenger.showSnackBar(
    SnackBar(content: Text(text), duration: _autosaveDuration),
  );
  autosave
    ..showing = controller
    ..queued = false;
  // An older autosave message closes after a newer one shows; only its own close counts.
  controller.closed.then((_) {
    if (identical(autosave.showing, controller)) {
      autosave
        ..showing = null
        ..queued = false;
    }
  });
}
