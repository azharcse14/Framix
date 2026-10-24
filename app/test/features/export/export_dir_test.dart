import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/media/export_sharer.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';
import 'package:framix/features/export/view/export_buttons.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import 'export_cubit_start_test.dart' show SeededExport;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('framix/media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final l10n = lookupAppLocalizations(const Locale('en'));
  final calls = <MethodCall>[];
  late FramixEngine engine;
  late SeededExport cubit;

  void handle(Future<Object?> Function(MethodCall call) handler) =>
      messenger.setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        return handler(call);
      });

  Widget app() => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<ExportCubit>.value(
      value: cubit,
      child: Scaffold(appBar: AppBar(actions: const [ExportButtons()])),
    ),
  );

  setUp(() {
    engine = FramixEngine.create();
    cubit = SeededExport(engine);
  });
  tearDown(() async {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, null);
    await cubit.close();
    engine.dispose();
  });

  test('the export folder comes from the platform', () async {
    handle((_) async => '/data/user/0/app/cache');
    expect(await ExportSharer.exportDir(), '/data/user/0/app/cache');
    expect(calls.single.method, 'exportDir');
  });

  test('without a platform answer the export folder is Dart temp', () async {
    expect(await ExportSharer.exportDir(), Directory.systemTemp.path);
  });

  testWidgets('the exported file lives in the platform export folder', (
    tester,
  ) async {
    handle(
      (call) async => call.method == 'exportDir' ? '/plat/cache' : 'saved',
    );
    await tester.pumpWidget(app());
    cubit.seed(const ExportDone());
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.saveToGallery));
    await tester.pumpAndSettle();
    final save = calls.lastWhere((c) => c.method == 'saveToGallery');
    expect(save.arguments, {'path': '/plat/cache/framix-export.mp4'});
  });

  testWidgets('export, save and share are off while a save runs', (
    tester,
  ) async {
    final saving = Completer<Object?>();
    handle(
      (call) => call.method == 'saveToGallery'
          ? saving.future
          : Future.value('/plat/cache'),
    );
    await tester.pumpWidget(app());
    cubit.seed(const ExportDone());
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.saveToGallery));
    await tester.pump();

    bool enabled(String tooltip) =>
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip(tooltip),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed !=
        null;
    expect(
      [l10n.export, l10n.saveToGallery, l10n.share].map(enabled),
      everyElement(isFalse),
    );

    saving.complete('saved');
    await tester.pumpAndSettle();
    expect(
      [l10n.export, l10n.saveToGallery, l10n.share].map(enabled),
      everyElement(isTrue),
    );
  });
}
