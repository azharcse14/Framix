import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';
import 'package:framix/features/export/view/export_buttons.dart';
import 'package:framix/l10n/app_delegates.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import 'export_cubit_start_test.dart' show SeededExport;
import '../../pump_until.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('framix/media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final l10n = lookupAppLocalizations(const Locale('en'));
  final calls = <MethodCall>[];
  late FramixEngine engine;
  late SeededExport cubit;

  Widget app() => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: appLocalizationsDelegates,
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

  testWidgets('export on an empty project reports the failure', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byTooltip(l10n.export));
    await pumpUntil(tester, find.text(l10n.exportFailed));
  });

  testWidgets('a running export shows its progress and can be cancelled', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    cubit.seed(const ExportRunning(5, 10));
    await tester.pump();
    final progress = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(progress.value, 0.5);
    expect(find.byTooltip(l10n.cancelExport), findsOneWidget);
    expect(find.byTooltip(l10n.export), findsNothing);
  });

  testWidgets('progress before the first frame count is indeterminate', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    cubit.seed(const ExportRunning(0, 0));
    await tester.pump();
    final progress = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(progress.value, isNull);
  });
}
