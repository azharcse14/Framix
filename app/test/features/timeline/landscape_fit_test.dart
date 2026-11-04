import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/media/media_importer.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';
import 'package:framix/features/export/view/export_buttons.dart';
import 'package:framix/features/preview/bloc/preview_cubit.dart';
import 'package:framix/features/timeline/bloc/playhead_cubit.dart';
import 'package:framix/features/timeline/bloc/thumbnail_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_zoom_cubit.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import 'timeline_page_test.dart' show pumpUntil;

/// A preview cubit the test can hand a texture id, as the engine's PreviewReady would.
class SeededPreview extends PreviewCubit {
  SeededPreview(super.engine);

  void seed(int textureId) => emit(textureId);
}

/// SC-006 review: real phones in landscape (status bar, notch insets, short screens) fit
/// without overflow; rotating keeps the editor's state.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  void setView(WidgetTester tester, Size size, EdgeInsets padding) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1
      ..padding = FakeViewPadding(
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom,
      );
    addTearDown(tester.view.reset);
  }

  final video = MediaItem(
    uri: 'content://media/external/video/1',
    kind: MediaKind.MEDIA_KIND_VIDEO,
    durationValue: Int64(2000),
    durationTimescale: 1000,
    width: 1080,
    height: 1920,
    codec: 'avc1',
  );

  /// A video track with a selected clip (so the clip actions row shows) and an audio track.
  Future<void> twoTracksAndSelection(WidgetTester tester, Locale locale) async {
    final l10n = lookupAppLocalizations(locale);
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([video]),
        locale: locale,
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.byType(ClipBox));
    await tester.tap(find.text(l10n.addAudioTrack));
    await pumpUntil(tester, find.text(l10n.audioTrackName(1)));
    // The lanes scroll vertically; on the shortest phones a Bangla lane needs a nudge.
    await tester.ensureVisible(find.byType(ClipBox));
    await tester.tap(find.byType(ClipBox));
    await pumpUntil(tester, find.byTooltip(l10n.splitClip));
  }

  for (final (name, size, padding) in [
    (
      '640x360 with a status bar',
      const Size(640, 360),
      const EdgeInsets.only(top: 24),
    ),
    (
      '667x375 with a home indicator',
      const Size(667, 375),
      const EdgeInsets.only(bottom: 21),
    ),
    (
      '852x393 with notch insets',
      const Size(852, 393),
      const EdgeInsets.fromLTRB(59, 0, 59, 21),
    ),
  ]) {
    for (final locale in const [Locale('en'), Locale('bn')]) {
      testWidgets('$name (${locale.languageCode}) fits two tracks and a '
          'selected clip', (tester) async {
        setView(tester, size, padding);
        await twoTracksAndSelection(tester, locale);
        // A RenderFlex overflow would have been reported as an exception.
        expect(tester.takeException(), isNull);
        // The lanes keep usable room.
        expect(
          tester.getSize(find.byType(TimelineView)).height,
          greaterThanOrEqualTo(144),
        );
      });
    }
  }

  testWidgets('rotating keeps the export buttons and the timeline state', (
    tester,
  ) async {
    setView(tester, const Size(390, 844), EdgeInsets.zero);
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      FramixApp(engine: engine, locale: const Locale('en')),
    );
    await tester.tap(find.text(l10n.addVideoTrack));
    await pumpUntil(tester, find.byType(TimelineView));
    final export = tester.state(find.byType(ExportButtons));
    final timeline = tester.state(find.byType(TimelineView));

    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    expect(tester.state(find.byType(ExportButtons)), same(export));
    expect(tester.state(find.byType(TimelineView)), same(timeline));

    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(tester.state(find.byType(ExportButtons)), same(export));
    expect(tester.state(find.byType(TimelineView)), same(timeline));
  });

  testWidgets('the engine preview fills the landscape stage', (tester) async {
    setView(tester, const Size(640, 360), const EdgeInsets.only(top: 24));
    final preview = SeededPreview(engine);
    addTearDown(preview.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: framixDarkTheme(),
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepositoryProvider<MediaImporter>.value(
          value: FakeImporter(const []),
          child: MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => TimelineCubit(engine)),
              BlocProvider<PreviewCubit>.value(value: preview),
              BlocProvider(create: (_) => PlayheadCubit(engine)),
              BlocProvider(create: (_) => TimelineZoomCubit()),
              BlocProvider(create: (_) => ThumbnailCubit(engine)),
              BlocProvider(create: (_) => ExportCubit(engine)),
            ],
            child: const TimelinePage(),
          ),
        ),
      ),
    );
    preview.seed(1);
    await tester.pump();
    final texture = tester.getRect(find.byType(Texture));
    expect(tester.takeException(), isNull);
    // Larger than the 112 dp portrait canvas, and inside the screen.
    expect(texture.height, greaterThan(112));
    expect(
      texture.top,
      greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
    );
    expect(texture.right, lessThanOrEqualTo(640));
  });
}
