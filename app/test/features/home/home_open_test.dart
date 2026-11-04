import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'home_page_test.dart' show pumpUntil;

/// Tapping a project that is not the open one opens it (P1-089 review).
void main() {
  testWidgets('tapping the older of two projects opens it', (tester) async {
    final engine = FramixEngine.create();
    final dir = Directory.systemTemp.createTempSync('framix-home-open');
    addTearDown(() {
      engine.dispose();
      dir.deleteSync(recursive: true);
    });
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        locale: const Locale('en'),
        home: HomePage(projectsDir: () async => dir.path),
      ),
    );
    await pumpUntil(tester, find.text(l10n.newProject));

    // No platform is registered in tests, so a platform command fails and the generic
    // snack bar can cover the bottom of the screen; clear it right before tapping there.
    Future<void> clearSnackBars() async {
      tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        ..clearSnackBars()
        ..removeCurrentSnackBar();
      await tester.pump();
    }

    Future<void> newProjectWith(String track) async {
      await tester.pumpAndSettle();
      await clearSnackBars();
      await tester.tap(find.widgetWithText(FilledButton, l10n.newProject));
      await pumpUntil(tester, find.text(l10n.addAudioTrack));
      // Let the route transition finish so the tap lands on the button.
      await tester.pumpAndSettle();
      await tester.tap(find.text(track));
      await pumpUntil(tester, find.textContaining(l10n.clipCount(0)));
      await tester.tap(find.byType(BackButton));
      await pumpUntil(tester, find.text(l10n.newProject));
      await tester.pumpAndSettle();
    }

    // Older: an audio track; newer (and open): a video track.
    await newProjectWith(l10n.addAudioTrack);
    await newProjectWith(l10n.addVideoTrack);
    await pumpUntil(tester, find.text(l10n.recentProjects(2)));

    // Cards are newest first, so the older project is the second card.
    await clearSnackBars();
    await tester.tap(find.text(l10n.clipCount(0)).last);
    await pumpUntil(tester, find.text(l10n.audioTrackName(1)));
    expect(find.text(l10n.videoTrackName(1)), findsNothing);
  });
}
