import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';
import 'package:framix/features/export/view/export_buttons.dart';
import 'package:framix/features/export/view/export_result_page.dart';
import 'package:framix/features/preview/bloc/preview_cubit.dart';
import 'package:framix/features/timeline/bloc/playback_cubit.dart';
import 'package:framix/l10n/app_delegates.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import 'export_cubit_start_test.dart' show SeededExport;

/// UX-032: a finished export opens the Result screen (preview, save, share, Back to edit,
/// Done) over the editor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('framix/media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late FramixEngine engine;
  late SeededExport cubit;

  void handle(Future<Object?> Function(MethodCall call) handler) =>
      messenger.setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        return handler(call);
      });

  /// Home (first route) with an editor on top; the editor holds the export buttons. The
  /// cubits sit below the Navigator, so the Result route must carry its own.
  Widget app(Locale locale) => MaterialApp(
    theme: framixDarkTheme(),
    locale: locale,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MultiBlocProvider(
                providers: [
                  BlocProvider<ExportCubit>.value(value: cubit),
                  BlocProvider(create: (_) => PreviewCubit(engine)),
                  BlocProvider(create: (_) => PlaybackCubit(engine)),
                ],
                child: Scaffold(
                  appBar: AppBar(actions: const [ExportButtons()]),
                  body: const Text('editor'),
                ),
              ),
            ),
          ),
          child: const Text('open editor'),
        ),
      ),
    ),
  );

  /// Opens the editor and finishes an export there.
  Future<void> finishExport(WidgetTester tester, [Locale? locale]) async {
    await tester.pumpWidget(app(locale ?? const Locale('en')));
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    cubit.seed(const ExportDone());
    await tester.pumpAndSettle();
  }

  setUp(() {
    engine = FramixEngine.create();
    cubit = SeededExport(engine);
    handle(
      (call) async => call.method == 'exportDir' ? '/plat/cache' : 'saved',
    );
  });
  tearDown(() async {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, null);
    await cubit.close();
    engine.dispose();
  });

  final l10n = lookupAppLocalizations(const Locale('en'));

  testWidgets('a finished export opens the Result screen', (tester) async {
    await finishExport(tester);
    expect(find.byType(ExportResultPage), findsOneWidget);
    expect(find.text(l10n.exportResultTitle), findsOneWidget);
    expect(find.text(l10n.saveToGallery), findsOneWidget);
    expect(find.text(l10n.share), findsOneWidget);
    expect(find.byTooltip(l10n.backToEdit), findsOneWidget);
    expect(find.text(l10n.done), findsOneWidget);
    expect(find.byTooltip(l10n.play), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save and share sit in the lower half of the screen', (
    tester,
  ) async {
    await finishExport(tester);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    for (final label in [l10n.saveToGallery, l10n.share]) {
      expect(
        tester.getCenter(find.text(label)).dy,
        greaterThan(screen.height / 2),
        reason: label,
      );
    }
  });

  testWidgets('save copies the exported file to the gallery', (tester) async {
    await finishExport(tester);
    await tester.tap(find.text(l10n.saveToGallery));
    await tester.pumpAndSettle();
    expect(find.text(l10n.savedToGallery), findsOneWidget);
    final save = calls.lastWhere((c) => c.method == 'saveToGallery');
    expect(save.arguments, {'path': '/plat/cache/framix-export.mp4'});
  });

  testWidgets('a denied save points to share (Files)', (tester) async {
    handle(
      (call) async => call.method == 'exportDir' ? '/plat/cache' : 'denied',
    );
    await finishExport(tester);
    await tester.tap(find.text(l10n.saveToGallery));
    await tester.pumpAndSettle();
    expect(find.text(l10n.saveDenied), findsOneWidget);
  });

  testWidgets('share hands the same file to the platform', (tester) async {
    await finishExport(tester);
    await tester.tap(find.text(l10n.share));
    await tester.pumpAndSettle();
    final share = calls.lastWhere((c) => c.method == 'share');
    expect(share.arguments, {'path': '/plat/cache/framix-export.mp4'});
  });

  testWidgets('a failed share says so', (tester) async {
    handle((call) async {
      if (call.method == 'share') throw PlatformException(code: 'x');
      return '/plat/cache';
    });
    await finishExport(tester);
    await tester.tap(find.text(l10n.share));
    await tester.pumpAndSettle();
    expect(find.text(l10n.shareFailed), findsOneWidget);
  });

  testWidgets('nothing leaves the screen or reads the file again while a save '
      'runs', (tester) async {
    final saving = Completer<Object?>();
    handle(
      (call) => call.method == 'saveToGallery'
          ? saving.future
          : Future.value('/plat/cache'),
    );
    await finishExport(tester);
    await tester.tap(find.text(l10n.saveToGallery));
    await tester.pump();

    bool enabled(String label) =>
        tester
            .widget<ButtonStyleButton>(
              find.ancestor(
                of: find.text(label),
                matching: find.bySubtype<ButtonStyleButton>(),
              ),
            )
            .onPressed !=
        null;
    bool backEnabled() =>
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip(l10n.backToEdit),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed !=
        null;
    expect(
      [l10n.saveToGallery, l10n.share, l10n.done].map(enabled),
      everyElement(isFalse),
    );
    expect(backEnabled(), isFalse);
    // The system back gesture is held too: a new export would overwrite the file.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(ExportResultPage), findsOneWidget);

    saving.complete('saved');
    await tester.pumpAndSettle();
    expect(
      [l10n.saveToGallery, l10n.share, l10n.done].map(enabled),
      everyElement(isTrue),
    );
    expect(backEnabled(), isTrue);
  });

  testWidgets('Back to edit returns to the editor', (tester) async {
    await finishExport(tester);
    await tester.tap(find.byTooltip(l10n.backToEdit));
    await tester.pumpAndSettle();
    expect(find.byType(ExportResultPage), findsNothing);
    expect(find.text('editor'), findsOneWidget);
    // Returning is not a new export: the screen does not open again by itself.
    await tester.pumpAndSettle();
    expect(find.byType(ExportResultPage), findsNothing);
  });

  testWidgets('Done goes back to the first screen (Home)', (tester) async {
    await finishExport(tester);
    await tester.tap(find.text(l10n.done));
    await tester.pumpAndSettle();
    expect(find.text('editor'), findsNothing);
    expect(find.text('open editor'), findsOneWidget);
  });

  testWidgets(
    'the app bar no longer saves or shares (the Result screen does)',
    (tester) async {
      await finishExport(tester);
      await tester.tap(find.byTooltip(l10n.backToEdit));
      await tester.pumpAndSettle();
      expect(find.byTooltip(l10n.saveToGallery), findsNothing);
      expect(find.byTooltip(l10n.share), findsNothing);
      expect(find.byTooltip(l10n.export), findsOneWidget);
    },
  );

  testWidgets(
    'Bangla Result screen renders on a 360 dp phone without overflow',
    (tester) async {
      tester.view
        ..physicalSize = const Size(360, 740)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final bn = lookupAppLocalizations(const Locale('bn'));
      await finishExport(tester, const Locale('bn'));
      expect(tester.takeException(), isNull, reason: 'no overflow');
      for (final text in [
        bn.exportResultTitle,
        bn.saveToGallery,
        bn.share,
        bn.done,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.byTooltip(bn.backToEdit), findsOneWidget);
      // Touch targets at least 48 dp.
      for (final label in [bn.saveToGallery, bn.share, bn.done]) {
        final box = tester.getSize(
          find.ancestor(
            of: find.text(label),
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
        );
        expect(box.height, greaterThanOrEqualTo(48), reason: label);
      }
    },
  );
}
