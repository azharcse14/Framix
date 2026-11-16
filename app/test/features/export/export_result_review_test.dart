import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';
import 'package:framix/features/export/view/export_buttons.dart';
import 'package:framix/features/export/view/export_result_page.dart';
import 'package:framix/features/preview/bloc/preview_cubit.dart';
import 'package:framix/features/preview/view/canvas_gestures.dart';
import 'package:framix/features/preview/view/preview_view.dart';
import 'package:framix/features/timeline/bloc/playback_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/l10n/app_delegates.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import 'export_cubit_start_test.dart' show SeededExport;

/// Lets a test show a preview texture the host engine cannot make. The host engine's own
/// answer (preview unavailable) may arrive at any pump, so only seeded states are taken.
class _SeededPreview extends PreviewCubit {
  _SeededPreview(super.engine);

  bool _seeding = false;

  void seed(PreviewState s) {
    _seeding = true;
    emit(s);
    _seeding = false;
  }

  @override
  void emit(PreviewState state) {
    if (_seeding) super.emit(state);
  }
}

/// UX-032 review: Done is not an accent action, a result finished away from the editor can
/// still be reached, and the Result preview is watch-only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('framix/media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final l10n = lookupAppLocalizations(const Locale('en'));
  late FramixEngine engine;
  late SeededExport export;
  late _SeededPreview preview;

  setUp(() {
    engine = FramixEngine.create();
    export = SeededExport(engine);
    preview = _SeededPreview(engine);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'exportDir' ? '/plat/cache' : null,
    );
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await export.close();
    await preview.close();
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
        BlocProvider<PreviewCubit>.value(value: preview),
        BlocProvider(create: (_) => PlaybackCubit(engine)),
        BlocProvider(create: (_) => TimelineCubit(engine)),
      ],
      child: navigator!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(actions: const [ExportButtons()]),
                body: const PreviewView(),
              ),
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

  testWidgets('Done is a plain text action, not the accent', (tester) async {
    await tester.pumpWidget(app());
    await openEditor(tester);
    export.seed(const ExportDone('/plat/cache/framix-export.mp4'));
    await tester.pumpAndSettle();
    final color = tester
        .renderObject<RenderParagraph>(find.text(l10n.done))
        .text
        .style
        ?.color;
    expect(color, isNot(FramixColors.dark.accentFill));
    expect(color, FramixColors.dark.text);
  });

  testWidgets('an export that finishes while the editor is closed can still '
      'be opened', (tester) async {
    await tester.pumpWidget(app());
    await openEditor(tester);
    export.seed(const ExportRunning(1, 10));
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    export.seed(const ExportDone('/plat/cache/framix-export.mp4'));
    await tester.pumpAndSettle();
    expect(find.byType(ExportResultPage), findsNothing);

    await openEditor(tester);
    await tester.tap(find.byTooltip(l10n.showExportResult));
    await tester.pumpAndSettle();
    expect(find.byType(ExportResultPage), findsOneWidget);
  });

  testWidgets('the editor offers the last result again after Back to edit', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await openEditor(tester);
    export.seed(const ExportDone('/plat/cache/framix-export.mp4'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.backToEdit));
    await tester.pumpAndSettle();
    expect(find.byTooltip(l10n.showExportResult), findsOneWidget);
  });

  testWidgets('no result to show before an export finished', (tester) async {
    await tester.pumpWidget(app());
    await openEditor(tester);
    expect(find.byTooltip(l10n.showExportResult), findsNothing);
  });

  testWidgets('the editor preview takes canvas gestures', (tester) async {
    await tester.pumpWidget(app());
    await openEditor(tester);
    preview.seed(const PreviewShown(1));
    await tester.pumpAndSettle();
    expect(find.byType(Texture), findsOneWidget);
    expect(find.byType(CanvasGestures), findsOneWidget);
  });

  testWidgets('the Result preview shows the texture without canvas gestures', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await openEditor(tester);
    preview.seed(const PreviewShown(1));
    export.seed(const ExportDone('/plat/cache/framix-export.mp4'));
    await tester.pumpAndSettle();
    final page = find.byType(ExportResultPage);
    expect(
      find.descendant(of: page, matching: find.byType(Texture)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: page, matching: find.byType(CanvasGestures)),
      findsNothing,
    );
  });
}
