import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Records sent commands; the test plays the engine's events.
class _FakeEngine implements FramixEngine {
  final sent = <Command>[];
  final _events = StreamController<Event>.broadcast();

  @override
  Stream<Event> get events => _events.stream;

  @override
  int send(Command command, {bool reportsFailure = false}) {
    sent.add(command..id = Int64(sent.length + 1));
    return sent.length;
  }

  void emit(Event event) => _events.add(event);

  int idOf(bool Function(Command) test) => sent.lastWhere(test).id.toInt();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// P1-095: while the engine saves and loads, the tapped button or card shows progress.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  late _FakeEngine engine;

  Future<void> pumpHome(
    WidgetTester tester,
    List<ProjectSummary> projects,
  ) async {
    engine = _FakeEngine();
    await tester.pumpWidget(
      RepositoryProvider<FramixEngine>.value(
        value: engine,
        child: MaterialApp(
          theme: framixDarkTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomePage(projectsDir: () async => '/data/projects'),
        ),
      ),
    );
    await tester.pump();
    engine.emit(Event(projectList: ProjectList(projects: projects)));
    await tester.pump();
  }

  Finder spinnerIn(Finder parent) => find.descendant(
    of: parent,
    matching: find.byType(CircularProgressIndicator),
  );

  void refuse(bool Function(Command) command) => engine.emit(
    Event(
      commandFailed: CommandFailed(
        commandId: Int64(engine.idOf(command)),
        reason: 'x',
      ),
    ),
  );

  testWidgets('New project shows progress until the engine answers', (
    tester,
  ) async {
    await pumpHome(tester, []);
    final button = find.widgetWithText(FilledButton, l10n.newProject);
    expect(spinnerIn(button), findsNothing);

    await tester.tap(button);
    await tester.pump();
    expect(spinnerIn(button), findsOneWidget);

    refuse((c) => c.hasNewProject());
    await tester.pump();
    await tester.pump();
    expect(spinnerIn(button), findsNothing);
  });

  testWidgets('a tapped card shows progress, and keeps it across a new list', (
    tester,
  ) async {
    final project = ProjectSummary(
      id: 'a1',
      ticksPerSecond: Int64(1000),
      modifiedMs: Int64(DateTime.now().millisecondsSinceEpoch),
    );
    await pumpHome(tester, [project]);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text(l10n.clipCount(0)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    engine.emit(Event(projectList: ProjectList(projects: [project])));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    refuse((c) => c.hasOpenProject());
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
