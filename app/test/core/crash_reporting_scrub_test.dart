import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/crash_reporting.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Review follow-ups of P1-041: paths with spaces, apostrophes or list brackets, the
/// fields Sentry fills from Flutter and platform errors, and native events.
SentryFlutterOptions configured() {
  final options = SentryFlutterOptions();
  configureCrashReporting(options, dsn: 'https://key@o1.ingest.sentry.io/1');
  return options;
}

Future<String> scrubbedValue(String value) async {
  final sent = await configured().beforeSend!(
    SentryEvent(
      exceptions: [SentryException(type: 'E', value: value)],
    ),
    Hint(),
  );
  return sent!.exceptions!.single.value!;
}

void main() {
  test(
    'a quoted path is cut up to its closing quote, spaces and all',
    () async {
      expect(
        await scrubbedValue(
          "path = '/var/mobile/Library/Application Support/media/x.mov' (OS Error)",
        ),
        "path = '<path>' (OS Error)",
      );
      expect(
        await scrubbedValue("path = '/x/Rina's clip.mov'"),
        "path = '<path>'",
      );
      expect(await scrubbedValue('open "/a b/c.mp4"'), 'open "<path>"');
    },
  );

  test('an unquoted path after a bracket or brace is cut', () async {
    final value = await scrubbedValue(
      '[/storage/emulated/0/a.mp4, /b] {/x/y.mov}',
    );
    expect(value, isNot(contains('storage')));
    expect(value, isNot(contains('a.mp4')));
    expect(value, isNot(contains('y.mov')));
    expect(value, contains('<path>'));
  });

  test('scrubs Flutter error details and platform exception data', () async {
    final event =
        SentryEvent(
            exceptions: [
              SentryException(
                type: 'PlatformException',
                value: 'x',
                mechanism: Mechanism(
                  type: 'platform',
                  data: {'message': 'open /data/user/0/app/cache/x.mp4 failed'},
                ),
              ),
            ],
          )
          ..contexts['flutter_error_details'] = {
            'information': "Image provider: FileImage(\"/var/mobile/a.png\")",
            'library': 'image resource service',
          };

    final sent = (await configured().beforeSend!(event, Hint()))!;

    expect(
      sent.exceptions!.single.mechanism!.data['message'],
      'open <path> failed',
    );
    final details = sent.contexts['flutter_error_details'] as Map;
    expect(details['information'], 'Image provider: FileImage("<path>")');
    expect(details['library'], 'image resource service');
  });

  test('native SDKs stay off: their events would skip the Dart scrub', () {
    expect(configured().autoInitializeNativeSdk, isFalse);
  });
}
