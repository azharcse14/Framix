import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/crash_reporting.dart';
// ignore: implementation_imports, NoOpTransport is not exported; sentry is pinned (10.1.0).
import 'package:sentry/src/transport/noop_transport.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Stands in for the native transport SentryFlutter.init sets before our callback runs.
class _NativeTransport implements Transport {
  @override
  Future<SentryId?> send(SentryEnvelope envelope) async => null;
}

void main() {
  test(
    'events go over HTTP, not through the native SDKs that stay off (P1-041 review)',
    () {
      final options = SentryFlutterOptions()..transport = _NativeTransport();

      configureCrashReporting(options, dsn: 'https://key@o1.ingest.sentry.io/1');

      // SentryClient swaps a NoOpTransport for its HttpTransport.
      expect(options.transport, isA<NoOpTransport>());
    },
  );
}
