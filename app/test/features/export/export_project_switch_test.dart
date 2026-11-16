import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';
import 'package:framix/features/export/view/export_buttons.dart';
import 'package:framix/l10n/app_delegates.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Events come only from the test.
class _Engine implements FramixEngine {
  final _events = StreamController<Event>.broadcast();

  @override
  Stream<Event> get events => _events.stream;

  @override
  int send(Command command, {bool reportsFailure = false}) => 1;

  void emit(Event event) => _events.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Event _project(int project) =>
    Event(timelineChanged: TimelineChanged(project: Int64(project)));

final _done = Event(exportFinished: ExportFinished(ok: true));

/// The engine's reply to the cubit's ExportProject (the fake's send returns id 1).
final _accepted = Event(commandAccepted: CommandAccepted(commandId: Int64(1)));

/// UX-041: project B never shows project A's export.
void main() {
  late _Engine engine;
  late ExportCubit cubit;
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() {
    engine = _Engine();
    cubit = ExportCubit(engine);
  });
  tearDown(() => cubit.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// An export the engine accepted, so its ExportFinished has a file to show.
  void started() {
    cubit.start('/plat/a.mp4');
    engine.emit(_accepted);
  }

  test('opening project B after A exported is idle', () async {
    started();
    engine
      ..emit(_project(1))
      ..emit(Event(exportProgress: ExportProgress(frame: 1, frames: 2)))
      ..emit(_done);
    await settle();
    expect(cubit.state, isA<ExportDone>());

    engine.emit(_project(2));
    await settle();
    expect(cubit.state, isA<ExportIdle>());
  });

  test('an edit in the same project keeps the finished export', () async {
    started();
    engine
      ..emit(_project(1))
      ..emit(_done)
      ..emit(_project(1));
    await settle();
    expect(cubit.state, isA<ExportDone>());
  });

  test('a failure is not shown in the next project either', () async {
    engine
      ..emit(_project(1))
      ..emit(Event(exportFinished: ExportFinished(reason: 'x')))
      ..emit(_project(2));
    await settle();
    expect(cubit.state, isA<ExportIdle>());
  });

  test(
    'an export running at the switch keeps showing, and its end is idle',
    () async {
      started();
      engine
        ..emit(_project(1))
        ..emit(Event(exportProgress: ExportProgress(frame: 1, frames: 4)))
        ..emit(_project(2));
      await settle();
      // Still running in the engine: progress and Cancel stay.
      expect(cubit.state, const ExportRunning(1, 4));

      engine
        ..emit(Event(exportProgress: ExportProgress(frame: 2, frames: 4)))
        ..emit(_done);
      await settle();
      // A's file is not B's result.
      expect(cubit.state, isA<ExportIdle>());

      // B's own export later is shown as usual.
      engine.emit(_done);
      await settle();
      expect(cubit.state, isA<ExportDone>());
    },
  );

  testWidgets('project B shows no Show-result button for A', (tester) async {
    // Finished before the editor shows, as after Back to edit: no Result push here.
    started();
    engine
      ..emit(_project(1))
      ..emit(_done);
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<ExportCubit>.value(
          value: cubit,
          child: Scaffold(appBar: AppBar(actions: const [ExportButtons()])),
        ),
      ),
    );
    expect(find.byTooltip(l10n.showExportResult), findsOneWidget);

    engine.emit(_project(2));
    // The fake engine's stream was made outside the fake clock: let its event through.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.byTooltip(l10n.showExportResult), findsNothing);
    expect(find.byTooltip(l10n.export), findsOneWidget);
  });
}
