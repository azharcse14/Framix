import 'dart:async';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import '../../pump_until.dart';

/// The host engine, except that an export is accepted and finishes at once (the host engine
/// has no platform encoder).
class _ExportingEngine implements FramixEngine {
  _ExportingEngine(this._real) {
    _real.events.listen(_events.add, onDone: _events.close);
  }

  final FramixEngine _real;
  final _events = StreamController<Event>.broadcast();

  /// Far above the real engine's command ids.
  static const _exportId = 1 << 40;

  @override
  Stream<Event> get events => _events.stream;

  @override
  Stream<CommandFailed> get failures => _real.failures;

  @override
  int send(Command command, {bool reportsFailure = false}) {
    if (!command.hasExportProject()) {
      return _real.send(command, reportsFailure: reportsFailure);
    }
    // Delivered after send returns, so the cubit already waits for this id.
    _events
      ..add(
        Event(commandAccepted: CommandAccepted(commandId: Int64(_exportId))),
      )
      ..add(Event(exportFinished: ExportFinished(ok: true)));
    return _exportId;
  }

  @override
  void dispose() => _real.dispose();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// UX-044: through the app, a project opened after another one's export shows no
/// Show-result button. ExportCubit must learn the exported project before the switch: it
/// does from the New's TimelineChanged (`lazy: false`) and, today, also from the GetTimeline
/// reply of the TimelineCubit that the same first editor makes. This fails only once both
/// are gone.
void main() {
  testWidgets('opening another project after an export shows no result', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('framix-export-switch');
    final earlier = FramixEngine.create();
    final engine = _ExportingEngine(FramixEngine.create());
    addTearDown(() {
      engine.dispose();
      earlier.dispose();
      dir.deleteSync(recursive: true);
    });
    final l10n = lookupAppLocalizations(const Locale('en'));

    // The other project, saved before the app starts: one audio track.
    // The earlier engine stops before the app starts, so only one engine writes the
    // library dir and none is still writing when the teardown deletes it.
    var listed = false;
    var stopped = false;
    earlier.events.listen(
      (e) => listed |= e.hasProjectList(),
      onDone: () => stopped = true,
    );
    earlier
      ..send(Command(openLibrary: OpenLibrary(dir: dir.path)))
      ..send(Command(newProject: NewProject()))
      ..send(Command(addTrack: AddTrack(kind: TrackKind.TRACK_KIND_AUDIO)))
      ..send(Command(listProjects: ListProjects()));
    await pumpUntilTrue(tester, () => listed, () => 'never saved');
    earlier.dispose();
    await pumpUntilTrue(tester, () => stopped, () => 'never stopped');

    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        locale: const Locale('en'),
        home: HomePage(projectsDir: () async => dir.path),
      ),
    );
    await pumpUntil(tester, find.text(l10n.recentProjects(1)));

    // New, then export it at once: the Result screen opens; Back to edit shows the button.
    // No edit: an edit's TimelineChanged would reach even a lazily made cubit.
    await tester.tap(find.widgetWithText(FilledButton, l10n.newProject));
    await pumpUntil(tester, find.byTooltip(l10n.export));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.export));
    await pumpUntil(tester, find.byTooltip(l10n.backToEdit));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.backToEdit));
    await pumpUntil(tester, find.byTooltip(l10n.showExportResult));

    // Back to Home, then open the other project (the empty new one is not listed).
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, find.text(l10n.recentProjects(1)));
    await tester.pumpAndSettle();
    // No platform is registered in tests, so a platform command fails and the generic
    // snack bar can cover the bottom of the screen; clear it right before tapping there.
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
      ..clearSnackBars()
      ..removeCurrentSnackBar();
    await tester.pump();
    await tester.tap(find.text(l10n.clipCount(0)));
    await pumpUntil(tester, find.text(l10n.audioTrackName(1)));
    await tester.pumpAndSettle();

    expect(find.byTooltip(l10n.showExportResult), findsNothing);
    expect(find.byTooltip(l10n.export), findsOneWidget);
  });
}
