import 'package:sentry_flutter/sentry_flutter.dart';

/// Sentry DSN from `--dart-define=SENTRY_DSN=...`; empty (the default) leaves Sentry off.
const sentryDsn = String.fromEnvironment('SENTRY_DSN');

/// Sets up crash reporting (P1-041): Dart errors go to Sentry at [dsn]. Nothing personal
/// leaves the device: no PII, screenshots or view tree, and file paths and URIs are cut
/// from the event message, exception values, platform exception data, Flutter error
/// details and breadcrumb messages (.claude/rules: Security). The native SDKs stay off:
/// their crash events would skip this scrub (native crashes with a native scrub: SYS-025).
void configureCrashReporting(
  SentryFlutterOptions options, {
  String dsn = sentryDsn,
}) {
  options
    ..dsn = dsn
    ..autoInitializeNativeSdk = false
    ..sendDefaultPii = false
    ..attachScreenshot = false
    ..attachViewHierarchy = false
    ..beforeSend = _scrubEvent
    ..beforeBreadcrumb = _scrubBreadcrumb;
}

// ponytail: covers the fields Dart errors fill today; extras, tags and breadcrumb data get
// the same scrub when something puts paths there (SYS-030).
SentryEvent _scrubEvent(SentryEvent event, Hint hint) {
  final message = event.message;
  if (message != null) message.formatted = _scrub(message.formatted);
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    exception.value = _scrubOrNull(exception.value);
    final mechanism = exception.mechanism;
    if (mechanism != null) mechanism.data = _scrubValues(mechanism.data);
  }
  final details = event.contexts['flutter_error_details'];
  if (details is Map<String, dynamic>) {
    event.contexts['flutter_error_details'] = _scrubValues(details);
  }
  return event;
}

Breadcrumb? _scrubBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
  breadcrumb?.message = _scrubOrNull(breadcrumb.message);
  return breadcrumb;
}

Map<String, dynamic> _scrubValues(Map<String, dynamic> map) => {
  for (final MapEntry(:key, :value) in map.entries)
    key: value is String ? _scrub(value) : value,
};

/// A quoted absolute path up to its closing quote (spaces and apostrophes inside, as in
/// Dart's `path = '...'`), a URI (`content://...`, `file:///...`), or an unquoted absolute
/// path, which ends at whitespace.
final _path = RegExp(
  "'/.*?'(?!\\w)"
  '|"/.*?"(?!\\w)'
  r'''|[A-Za-z][A-Za-z0-9+.-]*://[^\s'"]+'''
  r'|(?<![\w./])/(?=\S)\S+',
);

String _scrub(String text) => text.replaceAllMapped(_path, (match) {
  final quote = match[0]![0];
  return quote == "'" || quote == '"' ? '$quote<path>$quote' : '<path>';
});

String? _scrubOrNull(String? text) => text == null ? null : _scrub(text);
