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

/// P1-064: the export settings sheet shows and changes what the engine reports.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('resolution, fps and bitrate go to the engine ($locale)', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(locale);
      await tester.pumpWidget(FramixApp(engine: engine, locale: locale));
      ExportInfo export() => tester
          .element(find.byType(TimelinePage))
          .read<TimelineCubit>()
          .state
          .export;
      Future<void> until(bool Function() done) async {
        for (var i = 0; i < 100 && !done(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(done(), isTrue);
      }

      await until(() => export().width > 0);
      await tester.tap(find.byTooltip(l10n.exportSettings));
      await pumpUntil(tester, find.text(l10n.exportResolution4k));
      // The engine's numbers for the default 9:16 1080p.
      expect(find.text(l10n.exportFrameSize(1080, 1920)), findsOneWidget);

      await tester.tap(find.text(l10n.exportResolution4k));
      await until(
        () => export().resolution == ExportResolution.EXPORT_RESOLUTION_4K,
      );
      await pumpUntil(tester, find.text(l10n.exportFrameSize(2160, 3840)));

      await tester.tap(find.text(l10n.framesPerSecond(60)));
      await until(() => export().fps == ExportFps.EXPORT_FPS_60);

      // Auto off keeps the bitrate the engine was using, now set by hand.
      final auto = export().effectiveKbps;
      expect(export().kbps, 0);
      await tester.tap(find.byType(Switch));
      await until(() => export().kbps != 0);
      expect(export().kbps, auto);
      expect(find.byType(Slider), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
