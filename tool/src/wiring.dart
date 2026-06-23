// Shared helpers for the `--wire <app>` flag: insert a path dependency and a
// get_it registration into an app, so generated packages are wired, not just
// created. Dependency-free (dart:io only).
import 'dart:io';

/// Wires [depName] (at [depPath] relative to the app) into `apps/<app>`:
/// adds the path dependency to its pubspec and inserts [importLine] +
/// [registrationLine] into its `lib/injection.dart` (before the
/// `// generated:register` marker).
void wireIntoApp({
  required Directory repoRoot,
  required String app,
  required String depName,
  required String depPath,
  required String importLine,
  required String registrationLine,
}) {
  final appDir = Directory('${repoRoot.path}/apps/$app');
  if (!appDir.existsSync()) {
    stderr.writeln('Warning: app "$app" not found; skipping --wire.');
    return;
  }
  _addPathDependency('${appDir.path}/pubspec.yaml', depName, depPath);
  _addRegistration(
    '${appDir.path}/lib/injection.dart',
    importLine,
    registrationLine,
  );
  stdout.writeln('✓ Wired $depName into apps/$app');
}

/// Inserts a `name:\n  path: ...` entry into the pubspec `dependencies:` block,
/// keeping the block alphabetically sorted.
void _addPathDependency(String pubspecPath, String name, String path) {
  final file = File(pubspecPath);
  final lines = file.readAsLinesSync();
  final start = lines.indexOf('dependencies:');
  if (start == -1) return;
  if (lines.any((l) => l.trimRight() == '  $name:')) return; // already present.

  // Find the insertion index: before the first dependency whose key sorts
  // after `name`, or at the end of the block.
  var insertAt = lines.length;
  for (var i = start + 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty || !line.startsWith('  ')) {
      insertAt = i;
      break;
    }
    final match = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(line);
    if (match != null && match.group(1)!.compareTo(name) > 0) {
      insertAt = i;
      break;
    }
  }
  lines.insertAll(insertAt, ['  $name:', '    path: $path']);
  file.writeAsStringSync('${lines.join('\n')}\n');
}

/// Inserts [importLine] (sorted among existing imports) and [registrationLine]
/// (before the `// generated:register` marker) into an injection file.
void _addRegistration(
  String injectionPath,
  String importLine,
  String registrationLine,
) {
  final file = File(injectionPath);
  if (!file.existsSync()) {
    stderr.writeln('Warning: ${file.path} not found; skipping registration.');
    return;
  }
  final lines = file.readAsLinesSync();

  if (!lines.contains(importLine)) {
    final imports = <int>[
      for (var i = 0; i < lines.length; i++)
        if (lines[i].startsWith("import '")) i,
    ];
    var importAt = imports.isEmpty ? 0 : imports.last + 1;
    for (final i in imports) {
      if (lines[i].compareTo(importLine) > 0) {
        importAt = i;
        break;
      }
    }
    lines.insert(importAt, importLine);
  }

  final marker = lines.indexWhere((l) => l.contains('generated:register'));
  if (marker == -1) {
    stderr.writeln('Warning: no generated:register marker; skipping.');
  } else if (!lines.contains(registrationLine)) {
    lines.insertAll(marker, _wrap(registrationLine));
  }
  file.writeAsStringSync('${lines.join('\n')}\n');
}

/// Returns the registration as one line, or wrapped to match `dart format`'s
/// output when a single line would exceed the 80-character limit.
List<String> _wrap(String line) {
  if (line.length <= 80) return [line];
  final match = RegExp(r'^(\s*)(.+\()(.+)\);$').firstMatch(line);
  if (match == null) return [line];
  final indent = match.group(1)!;
  return [
    '$indent${match.group(2)}',
    '$indent  ${match.group(3)},',
    '$indent);',
  ];
}
