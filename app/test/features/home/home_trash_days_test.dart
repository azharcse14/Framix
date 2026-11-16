import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/l10n/app_delegates.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class _FakeEngine implements FramixEngine {
  final _events = StreamController<Event>.broadcast();

  @override
  Stream<Event> get events => _events.stream;

  @override
  int send(Command command, {bool reportsFailure = false}) => 1;

  void emit(Event event) => _events.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// L10N-017: the empty Recently deleted names the engine's retention
/// (ProjectList.keep_deleted_days), in the locale's digits.
void main() {
  for (final (locale, text) in const [
    (Locale('en'), 'Nothing deleted. Deleted projects stay here for 7 days.'),
    (Locale('bn'), 'কিছু মোছা হয়নি। মোছা প্রজেক্ট এখানে ৭ দিন থাকে।'),
  ]) {
    testWidgets('empty Recently deleted shows the engine days ($locale)', (
      tester,
    ) async {
      final engine = _FakeEngine();
      await tester.pumpWidget(
        RepositoryProvider<FramixEngine>.value(
          value: engine,
          child: MaterialApp(
            theme: framixDarkTheme(),
            locale: locale,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomePage(projectsDir: () async => '/data/projects'),
          ),
        ),
      );
      await tester.pump();
      final project = ProjectSummary(
        id: 'a1',
        ticksPerSecond: Int64(1000),
        modifiedMs: Int64(DateTime.now().millisecondsSinceEpoch),
      );
      engine.emit(
        Event(
          projectList: ProjectList(
            projects: [project],
            deleted: 1,
            keepDeletedDays: 7,
          ),
        ),
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(locale);
      await tester.tap(find.widgetWithText(ChoiceChip, l10n.recentlyDeleted));
      await tester.pump();
      engine.emit(
        Event(projectList: ProjectList(deleted: 1, keepDeletedDays: 7)),
      );
      await tester.pump();

      expect(find.text(text), findsOneWidget);
    });
  }
}
