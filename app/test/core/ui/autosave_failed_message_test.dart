import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/ui/command_failure_messages.dart';
import 'package:framix/l10n/app_delegates.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The engine's failures, played by the test.
class _FakeEngine implements FramixEngine {
  final _failures = StreamController<CommandFailed>.broadcast();

  @override
  Stream<CommandFailed> get failures => _failures.stream;

  void fail(CommandFailed failed) => _failures.add(failed);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// P1-121: a failed autosave tells the user their changes are not saved, without technical
/// text; the engine marks it with FAILURE_KIND_AUTOSAVE and command id 0.
void main() {
  test('the engine reports a failed autosave on failures', () async {
    final dir = await Directory.systemTemp.createTemp('framix_autosave');
    final engine = FramixEngine.create();
    addTearDown(() async {
      engine.dispose();
      await dir.delete(recursive: true);
    });
    final failed = engine.failures.firstWhere(
      (f) => f.kind == FailureKind.FAILURE_KIND_AUTOSAVE,
    );
    // The folder does not exist, so every save fails.
    engine.send(
      Command(
        enableAutosave: EnableAutosave(path: '${dir.path}/missing/a.framix'),
      ),
    );
    engine.send(Command(addTrack: AddTrack(kind: TrackKind.TRACK_KIND_AUDIO)));
    final f = await failed.timeout(const Duration(seconds: 10));
    expect(f.commandId.toInt(), 0);
  });

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('a failed autosave shows its own message ($locale)', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(locale);
      final engine = _FakeEngine();
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CommandFailureMessages(
              engine: engine,
              child: const SizedBox(),
            ),
          ),
        ),
      );
      engine.fail(
        CommandFailed(
          reason: 'autosave failed: storage full',
          kind: FailureKind.FAILURE_KIND_AUTOSAVE,
        ),
      );
      await tester.pump();
      expect(find.text(l10n.autosaveFailed), findsOneWidget);
      expect(find.text(l10n.commandFailed), findsNothing);
      expect(find.textContaining('storage full'), findsNothing);
    });
  }

  // UX-037: the engine reports a failed autosave once per streak, so its message must not
  // vanish with the default duration or be hidden by a later generic failure.
  Future<_FakeEngine> pumpMessages(WidgetTester tester) async {
    final engine = _FakeEngine();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CommandFailureMessages(engine: engine, child: const SizedBox()),
        ),
      ),
    );
    return engine;
  }

  final autosave = CommandFailed(kind: FailureKind.FAILURE_KIND_AUTOSAVE);
  final l10n = lookupAppLocalizations(const Locale('en'));

  testWidgets('the autosave message outlasts the default snackbar duration', (
    tester,
  ) async {
    final engine = await pumpMessages(tester);
    engine.fail(autosave);
    await tester.pump();
    for (var i = 0; i < 7; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text(l10n.autosaveFailed), findsOneWidget);
  });

  testWidgets('a later generic failure does not hide the autosave message', (
    tester,
  ) async {
    final engine = await pumpMessages(tester);
    engine.fail(autosave);
    await tester.pump();
    engine.fail(CommandFailed(reason: 'bad clip'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(l10n.autosaveFailed), findsOneWidget);
    // It waits its turn instead of being dropped.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text(l10n.commandFailed), findsOneWidget);
  });
}
