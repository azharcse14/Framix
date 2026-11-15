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

/// UX-035 review: a canvas wide enough for the "preview unavailable" text (16:9 on a phone)
/// shows the text at full size, not the icon.
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
    timeline.setAspectRatio(16, 9);
  }

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('a wide canvas shows the full-size text ($locale)', (
      tester,
    ) async {
      await pumpPage(tester, locale, const Size(360, 740), 1);
      final message = lookupAppLocalizations(locale).previewUnavailable;
      Finder inCanvas(Finder f) =>
          find.descendant(of: find.byType(CanvasOutline), matching: f);
      final text = inCanvas(find.text(message));
      await pumpUntil(tester, text);
      final style = Theme.of(tester.element(text)).textTheme.bodySmall!;
      expect(
        tester.getRect(text).height,
        greaterThanOrEqualTo(style.fontSize! * (style.height ?? 1) - 0.01),
      );
      expect(inCanvas(find.byType(Icon)), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
