// Scaffolds a new app in `apps/<name>` by cloning `apps/app_template`.
//
// Usage:
//   dart run tool/create_app.dart <app_name> [--description "..."]
//   melos run create_app -- <app_name> [--description "..."]
//
// `app_template` is the composed reference app (auth + DI + routing); cloning it
// gives a working starting point rather than an empty shell. <app_name> must be
// a valid Dart package name (lowercase letters, digits and underscores, starting
// with a letter). The generator copies the template, rewrites the package name,
// and prints next steps.
//
// Intentionally dependency-free (dart:io only) so it runs without bootstrapping.
import 'dart:io';

const _templateName = 'app_template';

final _validName = RegExp(r'^[a-z][a-z0-9_]*$');

// Generated / transient artifacts that must never be copied into a new app.
const _skipDirs = {'.dart_tool', 'build', '.melos_tool', '.idea', '.vscode'};
const _skipFiles = {
  'pubspec.lock',
  'pubspec_overrides.yaml',
  '.flutter-plugins',
  '.flutter-plugins-dependencies',
  '.packages',
  '.DS_Store',
};
// Generated artifacts identified by suffix (e.g. IntelliJ `*.iml` files Melos
// emits, named after the source package).
const _skipSuffixes = {'.iml'};

void main(List<String> args) {
  final positional = <String>[];
  String? description;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--description' || arg == '-d') {
      if (i + 1 >= args.length) {
        _fail('Missing value for $arg');
      }
      description = args[++i];
    } else if (arg.startsWith('--description=')) {
      description = arg.substring('--description='.length);
    } else if (arg == '--help' || arg == '-h') {
      stdout.writeln(_usage);
      exit(0);
    } else {
      positional.add(arg);
    }
  }

  if (positional.length != 1) {
    _fail('Expected exactly one app name.\n\n$_usage');
  }

  final name = positional.single;
  if (!_validName.hasMatch(name)) {
    _fail(
      "'$name' is not a valid Dart package name. Use lowercase letters, "
      'digits and underscores, starting with a letter (e.g. my_cool_app).',
    );
  }
  if (name == _templateName) {
    _fail("Choose a name other than '$_templateName'.");
  }

  // Resolve repo root from this script's location (tool/create_app.dart).
  final repoRoot = File(Platform.script.toFilePath()).parent.parent;
  final templateDir = Directory('${repoRoot.path}/apps/$_templateName');
  final targetDir = Directory('${repoRoot.path}/apps/$name');

  if (!templateDir.existsSync()) {
    _fail('Template not found at ${templateDir.path}');
  }
  if (targetDir.existsSync()) {
    _fail('apps/$name already exists. Pick a different name or remove it.');
  }

  final desc = description ?? 'The $name application.';

  _copyTree(templateDir, targetDir, name: name, description: desc);

  stdout.writeln('''
✓ Created apps/$name from $_templateName

Next steps:
  melos bootstrap
  cd apps/$name && dart run build_runner build --delete-conflicting-outputs
  melos run lint && melos run test
''');
}

void _copyTree(
  Directory source,
  Directory target, {
  required String name,
  required String description,
}) {
  target.createSync(recursive: true);

  for (final entity in source.listSync()) {
    final basename = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;

    if (entity is Directory) {
      if (_skipDirs.contains(basename)) continue;
      _copyTree(
        entity,
        Directory('${target.path}/$basename'),
        name: name,
        description: description,
      );
    } else if (entity is File) {
      if (_skipFiles.contains(basename)) continue;
      if (_skipSuffixes.any(basename.endsWith)) continue;
      final dest = File('${target.path}/$basename');

      if (basename == 'pubspec.yaml') {
        dest.writeAsStringSync(
          _rewritePubspec(entity.readAsStringSync(), name, description),
        );
      } else if (basename.endsWith('.dart')) {
        // Rewrite any self-referential package imports.
        dest.writeAsStringSync(
          entity
              .readAsStringSync()
              .replaceAll('package:$_templateName/', 'package:$name/'),
        );
      } else {
        entity.copySync(dest.path);
      }
    }
  }
}

String _rewritePubspec(String contents, String name, String description) {
  final lines = contents.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('name:')) {
      lines[i] = 'name: $name';
    } else if (lines[i].startsWith('description:')) {
      lines[i] = 'description: ${_yamlString(description)}';
    }
  }
  return lines.join('\n');
}

/// Encodes [value] as a double-quoted YAML scalar so descriptions containing
/// colons, quotes, or other YAML-significant characters can't produce an
/// invalid `pubspec.yaml`. Double-quoted YAML accepts JSON-style escapes.
String _yamlString(String value) {
  final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

Never _fail(String message) {
  stderr.writeln('Error: $message');
  exit(1);
}

const _usage = '''
Usage: dart run tool/create_app.dart <app_name> [--description "..."]

Arguments:
  <app_name>            Valid Dart package name (lowercase_with_underscores).

Options:
  -d, --description     Description for the new app's pubspec.yaml.
  -h, --help            Show this help.''';
