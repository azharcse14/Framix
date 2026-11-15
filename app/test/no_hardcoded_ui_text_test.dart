import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// L10N-002: every user-visible string comes from AppLocalizations (app/lib/l10n ARB files).
// This scans app/lib for string literals that contain letters; each one must be listed below
// with the reason it is not UI text. A new entry needs that reason, not a copied UI string:
// put UI text in app_en.arb and app_bn.arb instead.
// Keyed by file, then literal (source text): an entry allows that literal in that file only.
const _notUiText = <String, Map<String, String>>{
  'lib/core/crash_reporting.dart': {
    'SENTRY_DSN': 'build-time env key',
    'flutter_error_details': 'Sentry context key',
    r"'/.*?'(?!\\w)": 'scrub regex',
    r'|"/.*?"(?!\\w)': 'scrub regex',
    r'''|[A-Za-z][A-Za-z0-9+.-]*://[^\s'"]+''': 'scrub regex',
    r'$quote<path>$quote': 'scrub placeholder in crash reports',
    '<path>': 'scrub placeholder in crash reports',
  },
  'lib/core/ui/error_boundary.dart': {
    'framix': 'Flutter error library tag (logs only)',
  },
  'lib/core/ui/file_size.dart': {
    'en_US': 'intl fallback locale',
    'b': 'fileSize unit select key (ARB)',
    'kb': 'fileSize unit select key (ARB)',
    'mb': 'fileSize unit select key (ARB)',
    'gb': 'fileSize unit select key (ARB)',
  },
  'lib/features/home/view/edited_label.dart': {'en_US': 'intl fallback locale'},
  'lib/core/engine/framix_engine.dart': {
    r'engine_create failed: $code': 'developer error, never shown',
    'FramixEngine used after dispose': 'developer error, never shown',
    r'engine_send failed: $code': 'developer error, never shown',
  },
  'lib/core/media/channel_media_importer.dart': {
    'framix/media': 'method channel name',
    'projectsDir': 'channel method',
    'cacheDir': 'channel method',
    'pickGallery': 'channel method',
    'pickFiles': 'channel method',
    'uri': 'channel map key',
    'kind': 'channel map key',
    'video': 'channel map value',
    'image': 'channel map value',
    'durationValue': 'channel map key',
    'durationTimescale': 'channel map key',
    'width': 'channel map key',
    'height': 'channel map key',
    'rotation': 'channel map key',
    'codec': 'channel map key',
    r'projects folder unavailable: ${e.runtimeType}': 'debug log',
    r'cache folder unavailable: ${e.runtimeType}': 'debug log',
    r'media pick failed: ${e.code}': 'debug log',
    'media pick: skipped an item with an invalid value': 'debug log',
  },
  'lib/core/media/export_sharer.dart': {
    'exportDir': 'channel method',
    'saveToGallery': 'channel method',
    'share': 'channel method',
    'path': 'channel argument',
    'saved': 'channel answer',
    'denied': 'channel answer',
    r'export folder unavailable: ${e.runtimeType}': 'debug log',
    r'save to gallery failed: ${e.code}': 'debug log',
    r'share failed: ${e.code}': 'debug log',
  },
  'lib/features/export/view/export_buttons.dart': {
    r'$_dir/framix-export.mp4': 'export file path',
  },
  'lib/features/preview/view/canvas_gestures.dart': {
    'canvas-outline': 'widget key',
  },
  'lib/features/timeline/view/timeline_view.dart': {
    'timeline-ruler': 'widget key',
    'timeline-playhead': 'widget key',
    'timeline-loop': 'widget key',
    'target': 'widget key',
    // Ruler tick label m:ss.t; its nested quotes split the literal for this scanner.
    r"${whole ~/ 60}:${(whole % 60).toString().padLeft(2, ": 'number format',
    r'${tenth == 0 ? ': 'number format',
  },
};

/// Generated code (l10n, protobuf, ffigen) is not hand-written UI.
bool _generated(String path) =>
    path.contains('/l10n/generated/') ||
    path.contains('/core/engine/proto/') ||
    path.endsWith('.g.dart');

// Raw and plain, single- and double-quoted, one-line literals. Triple-quoted strings are
// matched first so their inner quotes don't split them.
final _literal = RegExp(
  [
    r"r?'''[\s\S]*?'''",
    r'r?"""[\s\S]*?"""',
    r"r?'(?:\\.|[^'\\\n])*'",
    r'r?"(?:\\.|[^"\\\n])*"',
  ].join('|'),
);

/// Literals in [source] that contain a letter (any script) outside interpolations, as source text without
/// their quotes (so allowlist keys are raw strings copied from the code).
Iterable<String> _wordyLiterals(String source) sync* {
  final code = source
      .split('\n')
      .where((l) => !RegExp(r'^\s*(//|import |export |part )').hasMatch(l))
      .join('\n');
  for (final m in _literal.allMatches(code)) {
    var s = m[0]!;
    if (s.startsWith('r')) s = s.substring(1);
    final q = s.startsWith("'''") || s.startsWith('"""') ? 3 : 1;
    final body = s.substring(q, s.length - q);
    final text = body
        .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
        .replaceAll(RegExp(r'\$\w+'), '')
        .replaceAll(RegExp(r'\\.'), '');
    if (text.contains(RegExp(r'\p{L}', unicode: true))) yield body;
  }
}

void main() {
  test('app/lib has no hard-coded UI text (use AppLocalizations)', () {
    final found = <String>[];
    final used = <String>{};
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !_generated(f.path))
        .toList();
    expect(files, isNotEmpty, reason: 'run from app/');
    for (final f in files) {
      final allowed = _notUiText[f.path] ?? const {};
      for (final s in _wordyLiterals(f.readAsStringSync())) {
        if (allowed.containsKey(s)) {
          used.add('${f.path}: $s');
        } else {
          found.add('${f.path}: $s');
        }
      }
    }
    expect(
      found,
      isEmpty,
      reason: 'move UI text to app/lib/l10n ARB (en + bn)',
    );
    final stale = [
      for (final MapEntry(key: file, value: literals) in _notUiText.entries)
        for (final s in literals.keys)
          if (!used.contains('$file: $s')) '$file: $s',
    ];
    expect(
      stale,
      isEmpty,
      reason: 'remove allowlist entries no longer in app/lib',
    );
  });
}
