import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import 'timeline_page_test.dart' show pumpUntil;

/// A refused command shows a short generic message (P1-049), unless the feature that sent it
/// reports the failure itself (export).
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  test(
    'failures lists refused commands, not the ones a feature handles',
    () async {
      final failures = <int>[];
      final sub = engine.failures.listen(
        (f) => failures.add(f.commandId.toInt()),
      );
      final plain = engine.send(
        Command(removeClip: RemoveClip(clipId: Int64(999))),
      );
      final owned = engine.send(
        Command(removeClip: RemoveClip(clipId: Int64(998))),
        reportsFailure: true,
      );
      final last = engine.send(
        Command(removeClip: RemoveClip(clipId: Int64(997))),
      );
      while (!failures.contains(last)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await sub.cancel();
      expect(failures, [plain, last]);
      expect(failures, isNot(contains(owned)));
    },
  );

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('a refused edit shows a message ($locale)', (tester) async {
      final l10n = lookupAppLocalizations(locale);
      await tester.pumpWidget(
        FramixApp(
          engine: engine,
          mediaImporter: FakeImporter(const []),
          locale: locale,
        ),
      );
      await tester.pump();
      engine.send(Command(removeClip: RemoveClip(clipId: Int64(999))));
      await pumpUntil(tester, find.text(l10n.commandFailed));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a failed export shows only its own message', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter(const []),
        locale: const Locale('en'),
      ),
    );
    await tester.tap(find.byTooltip(l10n.export));
    await pumpUntil(tester, find.text(l10n.exportFailed));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(l10n.commandFailed), findsNothing);
  });

  test('a refused cancel stays quiet (P1-049 review)', () async {
    final failures = <int>[];
    final sub = engine.failures.listen(
      (f) => failures.add(f.commandId.toInt()),
    );
    final cubit = ExportCubit(engine);
    // No export runs: the engine refuses the cancel.
    cubit.cancel();
    final last = engine.send(
      Command(removeClip: RemoveClip(clipId: Int64(997))),
    );
    while (!failures.contains(last)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await sub.cancel();
    await cubit.close();
    expect(failures, [last]);
  });
}
