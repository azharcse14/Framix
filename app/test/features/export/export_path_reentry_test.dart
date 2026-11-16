import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';
import 'package:framix/features/export/view/export_buttons.dart';
import 'package:framix/features/export/view/export_result_page.dart';
import 'package:framix/features/preview/bloc/preview_cubit.dart';
import 'package:framix/features/timeline/bloc/playback_cubit.dart';
import 'package:framix/l10n/app_delegates.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The export's engine, played by the test: it records ExportProject and answers on cue.
class _ExportEngine implements FramixEngine {
  final _events = StreamController<Event>.broadcast();
  final exported = <String>[];

  @override
  Stream<Event> get events => _events.stream;

  @override
  int send(Command command, {bool reportsFailure = false}) {
    if (command.hasExportProject()) exported.add(command.exportProject.path);
    return 7;
  }

  void emit(Event event) => _events.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// UX-042: the Result screen opened again from a new editor shows the file the export wrote,
/// even while the export folder is still being asked for.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('framix/media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final l10n = lookupAppLocalizations(const Locale('en'));
  late FramixEngine engine;
  late _ExportEngine exportEngine;
  late ExportCubit export;

  setUp(() {
    engine = FramixEngine.create();
    exportEngine = _ExportEngine();
    export = ExportCubit(exportEngine);
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await export.close();
    engine.dispose();
  });

  /// Home with an "open editor" button; the cubits sit above the Navigator, as in the app.
  Widget app() => MaterialApp(
    theme: framixDarkTheme(),
    locale: const Locale('en'),
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (_, navigator) => MultiBlocProvider(
      providers: [
        BlocProvider<ExportCubit>.value(value: export),
        BlocProvider(create: (_) => PreviewCubit(engine)),
        BlocProvider(create: (_) => PlaybackCubit(engine)),
      ],
      child: navigator!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  Scaffold(appBar: AppBar(actions: const [ExportButtons()])),
            ),
          ),
          child: const Text('open editor'),
        ),
      ),
    ),
  );

  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
  }

  /// Lets the fake engine's events through (its stream lives outside the fake clock).
  Future<void> deliver(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('a reopened editor shows the file the export wrote, before the '
      'export folder answers', (tester) async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'exportDir' ? '/plat/cache' : null,
    );
    await tester.pumpWidget(app());
    await openEditor(tester);
    await tester.tap(find.byTooltip(l10n.export));
    exportEngine
      ..emit(Event(commandAccepted: CommandAccepted(commandId: Int64(7))))
      ..emit(Event(exportFinished: ExportFinished(ok: true)));
    await deliver(tester);
    final written = exportEngine.exported.single;
    expect(
      tester.widget<ExportResultPage>(find.byType(ExportResultPage)).path,
      written,
    );

    // Back to edit, then out of the editor.
    await tester.tap(find.byTooltip(l10n.backToEdit));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // The export folder never answers this time.
    final never = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (_) => never.future);
    await openEditor(tester);
    await tester.tap(find.byTooltip(l10n.showExportResult));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ExportResultPage>(find.byType(ExportResultPage)).path,
      written,
    );
  });
}
