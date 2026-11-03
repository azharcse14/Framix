import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import '../timeline/timeline_page_test.dart' show pumpUntil;

/// P1-083: 4K then automatic bitrate off, without waiting, keeps 4K's bitrate.
void main() {
  late FramixEngine engine;
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  testWidgets('auto off right after 4K fixes the 4K bitrate', (tester) async {
    await tester.pumpWidget(FramixApp(engine: engine));
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
    final hd = export().effectiveKbps;
    await tester.tap(find.byTooltip(l10n.exportSettings));
    await pumpUntil(tester, find.text(l10n.exportResolution4k));
    await tester.tap(find.text(l10n.exportResolution4k));
    await tester.tap(find.byType(Switch));
    await until(() => export().kbps != 0);
    expect(export().resolution, ExportResolution.EXPORT_RESOLUTION_4K);
    expect(export().kbps, export().effectiveKbps);
    expect(export().kbps, isNot(hd), reason: '4K needs more than 1080p');
  });
}
