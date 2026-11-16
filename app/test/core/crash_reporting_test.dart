import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/crash_reporting.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

SentryFlutterOptions configured({
  String dsn = 'https://key@o1.ingest.sentry.io/1',
}) {
  final options = SentryFlutterOptions();
  configureCrashReporting(options, dsn: dsn);
  return options;
}

void main() {
  test('takes the DSN it is given; an empty one leaves Sentry off', () {
    expect(configured().dsn, 'https://key@o1.ingest.sentry.io/1');
    expect(configured(dsn: '').dsn, '');
  });

  test('never sends personal data, screenshots or the view tree', () {
    final options = configured();
    expect(options.sendDefaultPii, isFalse);
    expect(options.attachScreenshot, isFalse);
    expect(options.attachViewHierarchy, isFalse);
  });

  test('scrubs file paths and URIs from exceptions and the message', () async {
    final options = configured();
    final event = SentryEvent(
      message: SentryMessage(
        'open /var/mobile/Containers/Data/clip.mov failed',
      ),
      exceptions: [
        SentryException(
          type: 'PathNotFoundException',
          value:
              "Cannot open file, path = '/storage/emulated/0/DCIM/me.mp4' "
              'from content://media/external/video/42 or file:///tmp/x.png',
        ),
      ],
    );

    final sent = await options.beforeSend!(event, Hint());

    expect(sent!.message!.formatted, 'open <path> failed');
    expect(
      sent.exceptions!.single.value,
      "Cannot open file, path = '<path>' from <path> or <path>",
    );
    expect(sent.exceptions!.single.type, 'PathNotFoundException');
  });

  test('scrubs file paths and URIs from breadcrumbs', () {
    final options = configured();
    final crumb = options.beforeBreadcrumb!(
      Breadcrumb(message: 'picked content://com.android.providers/document/9'),
      Hint(),
    );
    expect(crumb!.message, 'picked <path>');
  });

  test('keeps text without paths as it is', () async {
    final options = configured();
    final sent = await options.beforeSend!(
      SentryEvent(
        exceptions: [
          SentryException(type: 'StateError', value: 'a/b ratio 3/4'),
        ],
      ),
      Hint(),
    );
    expect(sent!.exceptions!.single.value, 'a/b ratio 3/4');
  });
}
