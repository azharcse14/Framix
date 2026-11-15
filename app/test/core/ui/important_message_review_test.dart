import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/ui/command_failure_messages.dart';
import 'package:framix/core/ui/messages.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';
import 'package:framix/features/export/view/export_buttons.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/l10n/app_delegates.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/export/export_cubit_start_test.dart' show SeededExport;
import '../../pump_until.dart';

/// The engine's failures, played by the test.
class _FakeEngine implements FramixEngine {
  final _failures = StreamController<CommandFailed>.broadcast();

  @override
  Stream<CommandFailed> get failures => _failures.stream;

  void fail(CommandFailed failed) => _failures.add(failed);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// UX-038 (review): a waiting notice survives a second autosave failure, and the real
/// callers send their one-time notices as important.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final autosave = CommandFailed(kind: FailureKind.FAILURE_KIND_AUTOSAVE);
  final generic = CommandFailed(reason: 'bad clip');

  Future<void> seconds(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('a waiting notice shows after a second autosave message closes', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    showAutosaveFailed(context, 'autosave');
    await tester.pump();
    showMessage(context, 'notice', important: true);
    await tester.pump();
    await seconds(tester, 2);
    showAutosaveFailed(context, 'autosave');
    await tester.pump();
    await seconds(tester, 5);
    expect(find.text('autosave'), findsOneWidget);
    expect(find.text('notice'), findsNothing);
    // Hide, show and hide again each finish on the next 1 s pump: 13 s in all.
    await seconds(tester, 8);
    expect(find.text('autosave'), findsNothing);
    expect(find.text('notice'), findsOneWidget);
  });

  testWidgets('an export result outranks a generic failure behind autosave', (
    tester,
  ) async {
    final exportEngine = FramixEngine.create();
    final cubit = SeededExport(exportEngine);
    addTearDown(() async {
      await cubit.close();
      exportEngine.dispose();
    });
    final engine = _FakeEngine();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(
            actions: [
              BlocProvider<ExportCubit>.value(
                value: cubit,
                child: const ExportButtons(),
              ),
            ],
          ),
          body: CommandFailureMessages(engine: engine, child: const SizedBox()),
        ),
      ),
    );
    engine.fail(autosave);
    await tester.pump();
    engine.fail(generic);
    await tester.pump();
    cubit.seed(const ExportFailed('encoder'));
    await tester.pump();
    await seconds(tester, 12);
    expect(find.text(l10n.exportFailed), findsOneWidget);
    expect(find.text(l10n.commandFailed), findsNothing);
  });

  testWidgets('Home\'s work-recovered notice outranks a generic failure behind '
      'autosave', (tester) async {
    final dir = Directory.systemTemp.createTempSync('framix-notice-waits');
    final crashed = FramixEngine.create();
    final engine = FramixEngine.create();
    addTearDown(() {
      engine.dispose();
      crashed.dispose();
      dir.deleteSync(recursive: true);
    });
    // A crashed launch with a project open: the next Home says its work was saved.
    crashed
      ..send(Command(openLibrary: OpenLibrary(dir: dir.path)))
      ..send(Command(newProject: NewProject()))
      ..send(Command(addTrack: AddTrack(kind: TrackKind.TRACK_KIND_VIDEO)));
    await pumpUntilTrue(
      tester,
      () => dir.listSync().any((f) => f.path.endsWith('.framix')),
      () => 'the crashed launch never autosaved',
    );

    final failures = _FakeEngine();
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        locale: const Locale('en'),
        home: CommandFailureMessages(
          engine: failures,
          child: HomePage(projectsDir: () async => dir.path),
        ),
      ),
    );
    // Before the engine's reply (it arrives only in real time).
    failures.fail(autosave);
    await tester.pump();
    failures.fail(generic);
    await tester.pump();
    await pumpUntil(tester, find.text(l10n.recentProjects(1)));
    await seconds(tester, 12);
    expect(find.text(l10n.workRecovered), findsOneWidget);
    expect(find.text(l10n.commandFailed), findsNothing);
  });
}
