// Enforces the feature-first boundary that used to be guaranteed by separate
// packages. Now that Duet's domain is flattened into the single `duet` package,
// nothing at the language level stops `lib/features/score/` from importing
// `lib/features/library/` — only this test does. It fails the build on any
// cross-feature import (features must be blind to each other and communicate
// via the domain layer, callbacks, or DI — see CLAUDE.md), and on the domain
// layer importing upward into a feature or review_sync.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  Iterable<File> dartFiles(Directory dir) => dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  List<String> importUris(File file) {
    final directive = RegExp(
      r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    );
    return [
      for (final m in directive.allMatches(file.readAsStringSync()))
        m.group(1)!,
    ];
  }

  /// The feature that a `lib/features/<name>/...` path belongs to, or null.
  String? featureOf(String path) {
    final parts = p.split(p.normalize(path));
    final i = parts.indexOf('features');
    if (i <= 0 || parts[i - 1] != 'lib' || i + 1 >= parts.length) return null;
    return parts[i + 1];
  }

  test('features are blind to each other — no cross-feature imports', () {
    final featuresDir = Directory(p.join('lib', 'features'));
    if (!featuresDir.existsSync()) {
      fail('lib/features not found — run this from apps/duet.');
    }

    final violations = <String>[];
    for (final feature in featuresDir.listSync().whereType<Directory>()) {
      final name = p.basename(feature.path);
      for (final file in dartFiles(feature)) {
        for (final uri in importUris(file)) {
          String? other;
          if (uri.startsWith('package:duet/features/')) {
            other = uri.split('/')[2];
          } else if (!uri.startsWith('package:') && !uri.startsWith('dart:')) {
            // Relative import — resolve it and see which feature it lands in.
            other = featureOf(p.join(p.dirname(file.path), uri));
          }
          if (other != null && other != name) {
            violations.add('${file.path}  ->  $uri');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Cross-feature imports are forbidden. Features communicate via the '
          'domain layer (reactive repositories), UI callbacks, or DI — never '
          'by importing each other. Offenders:\n${violations.join('\n')}',
    );
  });

  test('the domain layer never imports upward (features / review_sync)', () {
    final domainDir = Directory(p.join('lib', 'domain'));
    if (!domainDir.existsSync()) return;

    final violations = <String>[];
    for (final file in dartFiles(domainDir)) {
      for (final uri in importUris(file)) {
        if (uri.startsWith('package:duet/features/') ||
            uri.startsWith('package:duet/review_sync/')) {
          violations.add('${file.path}  ->  $uri');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'The domain layer must not depend on features or app services — '
          'dependencies point inward. Offenders:\n${violations.join('\n')}',
    );
  });
}
