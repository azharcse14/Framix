import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';
import 'package:framix/features/export/view/export_buttons.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import 'export_cubit_start_test.dart' show SeededExport;

/// The engine's export pre-flight (P1-040): not enough storage is its own state and message.
void main() {
  test('a refusal with sizes is ExportNoSpace', () {
    final event = Event(
      exportFinished: ExportFinished(
        ok: false,
        reason: 'not enough storage',
        neededBytes: Int64(2500000001),
        freeBytes: Int64(400999999),
      ),
    );
    expect(
      ExportCubit.fromEvent(event),
      const ExportNoSpace(2500000001, 400999999),
    );
  });

  test('a failure without sizes stays ExportFailed', () {
    final event = Event(exportFinished: ExportFinished(reason: 'encoder'));
    expect(ExportCubit.fromEvent(event), const ExportFailed('encoder'));
  });

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('the message says how much is needed and free ($locale)', (
      tester,
    ) async {
      final engine = FramixEngine.create();
      final cubit = SeededExport(engine);
      addTearDown(() async {
        await cubit.close();
        engine.dispose();
      });
      final l10n = lookupAppLocalizations(locale);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<ExportCubit>.value(
            value: cubit,
            child: Scaffold(appBar: AppBar(actions: const [ExportButtons()])),
          ),
        ),
      );
      cubit.seed(const ExportNoSpace(2500000001, 400999999));
      await tester.pump();
      // Needed rounds up, free rounds down, in megabytes.
      expect(find.text(l10n.exportNoSpace(2501, 400)), findsOneWidget);
      expect(find.text(l10n.exportFailed), findsNothing);
    });
  }
}
