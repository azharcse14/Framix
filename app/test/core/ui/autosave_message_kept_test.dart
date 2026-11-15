import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/ui/command_failure_messages.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';
import 'package:framix/features/export/view/export_buttons.dart';
import 'package:framix/l10n/app_delegates.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/export/export_cubit_start_test.dart' show SeededExport;

/// The engine's failures, played by the test.
class _FakeEngine implements FramixEngine {
  final _failures = StreamController<CommandFailed>.broadcast();

  @override
  Stream<CommandFailed> get failures => _failures.stream;

  void fail(CommandFailed failed) => _failures.add(failed);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// UX-037 (review): the engine reports a failed autosave once per streak, so no later message
/// may hide it: not a generic failure after a second streak, not an export message.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final autosave = CommandFailed(kind: FailureKind.FAILURE_KIND_AUTOSAVE);
  final generic = CommandFailed(reason: 'bad clip');

  Future<_FakeEngine> pumpMessages(
    WidgetTester tester, {
    Widget? actions,
  }) async {
    final engine = _FakeEngine();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(actions: [?actions]),
          body: CommandFailureMessages(engine: engine, child: const SizedBox()),
        ),
      ),
    );
    return engine;
  }

  Future<void> seconds(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> secondStreakThenGeneric(WidgetTester tester) async {
    final engine = await pumpMessages(tester);
    engine.fail(autosave);
    await tester.pump();
    await seconds(tester, 2);
    engine.fail(autosave);
    await tester.pump();
    // The old message's hide animation finishes; its close must not unmark the new one.
    await seconds(tester, 2);
    engine.fail(generic);
    await tester.pump();
    await seconds(tester, 1);
    expect(find.text(l10n.autosaveFailed), findsOneWidget);
    expect(find.text(l10n.commandFailed), findsNothing);
  }

  testWidgets(
    'a generic failure does not hide the autosave message of a second streak',
    secondStreakThenGeneric,
  );

  testWidgets('the same with accessible navigation', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await secondStreakThenGeneric(tester);
  });

  testWidgets('at most one generic message waits behind the autosave message', (
    tester,
  ) async {
    final engine = await pumpMessages(tester);
    engine.fail(autosave);
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      engine.fail(generic);
      await tester.pump();
    }
    await seconds(tester, 12);
    expect(find.text(l10n.autosaveFailed), findsNothing);
    expect(find.text(l10n.commandFailed), findsOneWidget);
    // The queued one runs its 4 s and nothing follows it.
    await seconds(tester, 6);
    expect(find.text(l10n.commandFailed), findsNothing);
  });

  testWidgets('an export message does not hide the autosave message', (
    tester,
  ) async {
    final exportEngine = FramixEngine.create();
    final cubit = SeededExport(exportEngine);
    addTearDown(() async {
      await cubit.close();
      exportEngine.dispose();
    });
    final engine = await pumpMessages(
      tester,
      actions: BlocProvider<ExportCubit>.value(
        value: cubit,
        child: const ExportButtons(),
      ),
    );
    engine.fail(autosave);
    await tester.pump();
    cubit.seed(const ExportFailed('encoder'));
    await tester.pump();
    await seconds(tester, 1);
    expect(find.text(l10n.autosaveFailed), findsOneWidget);
    expect(find.text(l10n.exportFailed), findsNothing);
    await seconds(tester, 11);
    expect(find.text(l10n.exportFailed), findsOneWidget);
  });
}
