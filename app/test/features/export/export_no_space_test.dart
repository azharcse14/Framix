import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/ui/file_size.dart';
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

  // Needed rounds up and free rounds down at the shown precision, so needed always reads as
  // more than free (the engine refuses only when needed > free). P1-110.
  const cases = [
    (2500000001, 400999999, '2.6 GB', '400 MB'),
    (400600000, 400500000, '401 MB', '400 MB'),
  ];
  for (final locale in const [Locale('en'), Locale('bn')]) {
    for (final (needed, free, enNeeded, enFree) in cases) {
      testWidgets('the message says how much is needed and free '
          '($locale, $needed > $free)', (tester) async {
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
            // As in FramixApp: material_ui's delegates know bn.
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<ExportCubit>.value(
              value: cubit,
              child: Scaffold(appBar: AppBar(actions: const [ExportButtons()])),
            ),
          ),
        );
        cubit.seed(ExportNoSpace(needed, free));
        await tester.pump();
        final neededText = fileSize(
          l10n,
          '$locale',
          needed,
          rounding: SizeRounding.up,
        );
        final freeText = fileSize(
          l10n,
          '$locale',
          free,
          rounding: SizeRounding.down,
        );
        expect(neededText, isNot(freeText));
        if (locale.languageCode == 'en') {
          expect((neededText, freeText), (enNeeded, enFree));
        }
        expect(
          find.text(l10n.exportNoSpace(neededText, freeText)),
          findsOneWidget,
        );
        expect(find.text(l10n.exportFailed), findsNothing);
      });
    }
  }
}
