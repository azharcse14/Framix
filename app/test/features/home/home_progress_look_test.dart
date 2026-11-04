import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:framix/features/home/bloc/home_cubit.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// P1-095 review: the spinner is visible on the accent button, is announced, and is gone
/// once the engine opened the project.
void main() {
  late _FakeEngine engine;
  final project = ProjectSummary(
    id: 'a1',
    ticksPerSecond: Int64(1000),
    modifiedMs: Int64(DateTime.now().millisecondsSinceEpoch),
  );

  Future<void> pumpHome(WidgetTester tester, Locale locale) async {
    engine = _FakeEngine();
    await tester.pumpWidget(
      RepositoryProvider<FramixEngine>.value(
        value: engine,
        child: MaterialApp(
          theme: framixDarkTheme(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomePage(projectsDir: () async => '/data/projects'),
        ),
      ),
    );
    await tester.pump();
    engine.emit(Event(projectList: ProjectList(projects: [project])));
    await tester.pump();
  }

  testWidgets('the New project spinner contrasts with the button', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await pumpHome(tester, const Locale('en'));
    final button = find.widgetWithText(FilledButton, l10n.newProject);
    await tester.tap(button);
    await tester.pump();

    final spinner = tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: button,
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    final scheme = Theme.of(tester.element(button)).colorScheme;
    expect(spinner.color, scheme.onPrimary);
  });

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('the spinner is announced ($locale)', (tester) async {
      final l10n = lookupAppLocalizations(locale);
      final semantics = tester.ensureSemantics();
      await pumpHome(tester, locale);
      await tester.tap(find.text(l10n.clipCount(0)));
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp(l10n.openingProject)), findsWidgets);
      semantics.dispose();
    });
  }

  test('opening clears once the engine opened the project and stays clear '
      'after the editor closes', () async {
    final engine = _FakeEngine();
    final cubit = HomeCubit(engine, () async => '/data/projects');
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);
    engine.emit(Event(projectList: ProjectList(projects: [project])));
    engine.emit(Event(timelineChanged: TimelineChanged(project: Int64(1))));
    await Future<void>.delayed(Duration.zero);

    final opened = cubit.open('a1');
    expect((cubit.state as HomeProjects).opening, 'a1');
    engine.emit(Event(timelineChanged: TimelineChanged(project: Int64(2))));
    expect(await opened, isTrue);
    expect((cubit.state as HomeProjects).opening, isNull);

    cubit.refresh(); // the editor closed
    engine.emit(Event(projectList: ProjectList(projects: [project])));
    await Future<void>.delayed(Duration.zero);
    expect((cubit.state as HomeProjects).opening, isNull);
  });
}
