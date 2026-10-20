import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import 'timeline_page_test.dart' show pumpUntil;

void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  testWidgets('track headers fit in Bangla at twice the text size', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final bn = lookupAppLocalizations(const Locale('bn'));
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([
          MediaItem(
            uri: 'content://media/external/video/1',
            kind: MediaKind.MEDIA_KIND_VIDEO,
            durationValue: Int64(4000),
            durationTimescale: 1000,
            width: 1080,
            height: 1920,
            codec: 'avc1',
          ),
        ]),
        locale: const Locale('bn'),
      ),
    );
    await tester.tap(find.byTooltip(bn.importFromGallery));
    await pumpUntil(tester, find.byType(ClipBox));
    // A RenderFlex overflow would have been reported as an exception.
    expect(tester.takeException(), isNull);
    expect(find.text(bn.videoTrackName(1)), findsOneWidget);
  });
}
