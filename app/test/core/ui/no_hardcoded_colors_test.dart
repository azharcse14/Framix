import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The one home for color literals (docs/design-system.md: widgets use tokens only).
const _tokenFile = 'lib/core/ui/framix_theme.dart';

/// Reviewed exceptions: file -> exact trimmed line. Neither is a design color.
const _allowed = {
  // No theme above the error panel yet: draw nothing rather than invent a color.
  'lib/core/ui/error_boundary.dart':
      'color: colors?.surface ?? Colors.transparent,',
  // The user's clip color from the engine (0xRRGGBBAA), only made opaque here.
  'lib/features/timeline/view/timeline_view.dart':
      'Color _rgba(int rgba) => Color(0xff000000 | (rgba >> 8));',
};

final _literal = RegExp(
  r'Color\(0x|Color\.from(ARGB|RGBO)\(|\b(Cupertino)?Colors\.',
);

void main() {
  test('widgets use theme tokens, never color literals', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // Generated code (protobuf, l10n) is not ours to style.
        .where(
          (f) => !f.path.contains('/proto/') && !f.path.endsWith('.g.dart'),
        )
        .where((f) => !f.path.contains('/l10n/'))
        .where((f) => f.path != _tokenFile);
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//') || !_literal.hasMatch(line)) continue;
        if (_allowed[file.path] == line) continue;
        offenders.add('${file.path}:${i + 1}: $line');
      }
    }
    expect(offenders, isEmpty, reason: 'use FramixColors tokens');
  });
}
