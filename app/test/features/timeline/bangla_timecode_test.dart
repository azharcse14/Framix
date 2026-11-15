import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import '../../pump_until.dart';

/// L10N-018: the bn editor shows the playhead timecode in Bengali digits.
void main() {
  late FramixEngine engine;
  final l10n = lookupAppLocalizations(const Locale('bn'));

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  testWidgets('bn playhead timecode uses Bengali digits', (tester) async {
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([
          MediaItem(
            uri: 'content://media/external/video/1',
            kind: MediaKind.MEDIA_KIND_VIDEO,
            durationValue: Int64(2000),
            durationTimescale: 1000,
            width: 1080,
            height: 1920,
            codec: 'avc1',
          ),
        ]),
        locale: const Locale('bn'),
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.text(l10n.clipCount(1)));

    expect(find.text('০০:০০.০০'), findsOneWidget);
    expect(find.text('00:00.00'), findsNothing);
  });
}
