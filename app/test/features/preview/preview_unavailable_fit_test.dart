import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/media/media_importer.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';
import 'package:framix/features/preview/bloc/preview_cubit.dart';
import 'package:framix/features/timeline/bloc/playback_cubit.dart';
import 'package:framix/features/timeline/bloc/playhead_cubit.dart';
import 'package:framix/features/timeline/bloc/thumbnail_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_zoom_cubit.dart';
import 'package:framix/features/timeline/view/aspect_ratio_bar.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/l10n/app_delegates.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../timeline/import_test.dart' show FakeImporter;
import '../../pump_until.dart';

/// UX-035 review: the "preview unavailable" message is never shrunk below its size. In a
/// canvas too narrow for the text (9:16 on a phone), an icon labelled with the message says
/// it instead; text scaling is kept either way.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  Future<void> pumpPage(
    WidgetTester tester,
    Locale locale,
    Size size,
    double textScale,
  ) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final timeline = TimelineCubit(engine);
    addTearDown(timeline.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: framixDarkTheme(),
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: RepositoryProvider<MediaImporter>.value(
          value: FakeImporter(const []),
          child: MultiBlocProvider(
            providers: [
              BlocProvider<TimelineCubit>.value(value: timeline),
              BlocProvider(create: (_) => PreviewCubit(engine)),
              BlocProvider(create: (_) => PlayheadCubit(engine)),
              BlocProvider(create: (_) => PlaybackCubit(engine)),
              BlocProvider(create: (_) => TimelineZoomCubit()),
              BlocProvider(create: (_) => ThumbnailCubit(engine)),
              BlocProvider(create: (_) => ExportCubit(engine)),
            ],
            child: const TimelinePage(),
          ),
        ),
      ),
    );
    timeline.setAspectRatio(9, 16);
  }

  for (final locale in const [Locale('en'), Locale('bn')]) {
    for (final scale in const [1.0, 2.0]) {
      for (final size in const [Size(360, 740), Size(640, 360)]) {
        testWidgets(
          'the message keeps its size in a 9:16 canvas ($locale, x$scale, $size)',
          (tester) async {
            final handle = tester.ensureSemantics();
            await pumpPage(tester, locale, size, scale);
            final message = lookupAppLocalizations(locale).previewUnavailable;
            Finder inCanvas(Finder f) =>
                find.descendant(of: find.byType(CanvasOutline), matching: f);
            final text = inCanvas(find.text(message));
            final icon = inCanvas(find.bySemanticsLabel(message));
            await pumpUntilTrue(
              tester,
              () => text.evaluate().isNotEmpty || icon.evaluate().isNotEmpty,
              () => 'neither text nor labelled icon in the canvas',
            );
            await tester.pump();
            expect(inCanvas(find.byType(FittedBox)), findsNothing);
            if (text.evaluate().isNotEmpty) {
              final context = tester.element(text);
              final style = Theme.of(context).textTheme.bodySmall!;
              final line =
                  TextScaler.linear(scale).scale(style.fontSize!) *
                  (style.height ?? 1);
              expect(
                tester.getRect(text).height,
                greaterThanOrEqualTo(line - 0.01),
              );
            } else {
              expect(inCanvas(find.byType(Icon)), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
            handle.dispose();
          },
        );
      }
    }
  }
}
