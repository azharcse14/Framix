import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import '../../pump_until.dart';

/// P1-082: quick edits in the export settings sheet don't undo each other; a slider drag is one
/// step; auto back on is kbps 0.
void main() {
  late FramixEngine engine;
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  TimelineCubit cubit(WidgetTester tester) =>
      tester.element(find.byType(TimelinePage)).read<TimelineCubit>();

  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(done(), isTrue);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(FramixApp(engine: engine));
    await until(tester, () => cubit(tester).state.export.width > 0);
    await tester.tap(find.byTooltip(l10n.exportSettings));
    await pumpUntil(tester, find.text(l10n.exportResolution4k));
  }

  testWidgets('two taps without waiting both stick', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text(l10n.exportResolution4k));
    await tester.tap(find.text(l10n.framesPerSecond(60)));
    await until(
      tester,
      () => cubit(tester).state.export.fps == ExportFps.EXPORT_FPS_60,
    );
    // Let any late reply land too.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(
      cubit(tester).state.export.resolution,
      ExportResolution.EXPORT_RESOLUTION_4K,
    );
  });

  testWidgets('a slider drag is one undo step; auto back on is 0', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.byType(Switch));
    await until(tester, () => cubit(tester).state.export.kbps != 0);
    final before = cubit(tester).state.export.kbps;

    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await until(tester, () => cubit(tester).state.export.kbps != before);
    cubit(tester).undo();
    await until(tester, () => cubit(tester).state.export.kbps == before);

    await tester.tap(find.byType(Switch));
    await until(tester, () => cubit(tester).state.export.kbps == 0);
  });
}
