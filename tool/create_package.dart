// Scaffolds a new shared package in `packages/<layer>/<name>` (a core building
// block or a service wrapper), with a service class, barrel, and test.
//
// Usage:
//   dart run tool/create_package.dart <name> [--layer core|services]
//       [--description "..."] [--wire <app>]
//
// --wire <app> also adds the package to that app's pubspec and registers the
// service in its get_it injection (before the `// generated:register` marker).
//
// Dependency-free (dart:io only) apart from a sibling helper.
import 'dart:io';

import 'src/wiring.dart';

final _validName = RegExp(r'^[a-z][a-z0-9_]*$');
const _layers = {'core', 'services'};

void main(List<String> args) {
  final positional = <String>[];
  var layer = 'core';
  String? description;
  String? wireApp;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--layer' || '-l':
        layer = args[++i];
      case '--description' || '-d':
        description = args[++i];
      case '--wire' || '-w':
        wireApp = args[++i];
      case '--help' || '-h':
        stdout.writeln(_usage);
        exit(0);
      default:
        positional.add(arg);
    }
  }

  if (positional.length != 1) _fail('Expected exactly one name.\n\n$_usage');
  if (!_layers.contains(layer)) _fail('--layer must be one of $_layers.');

  final name = positional.single;
  if (!_validName.hasMatch(name)) {
    _fail("'$name' is not a valid package name (lowercase_with_underscores).");
  }

  final repoRoot = File(Platform.script.toFilePath()).parent.parent;
  final dir = Directory('${repoRoot.path}/packages/$layer/$name');
  if (dir.existsSync()) _fail('${dir.path} already exists.');

  final pascal = _toPascalCase(name);
  final desc = description ?? 'The $name package.';

  _templates(name, pascal, desc).forEach((path, contents) {
    File('${dir.path}/$path')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(contents);
  });

  stdout.writeln('✓ Created packages/$layer/$name (class: ${pascal}Service)');

  if (wireApp != null) {
    wireIntoApp(
      repoRoot: repoRoot,
      app: wireApp,
      depName: name,
      depPath: '../../packages/$layer/$name',
      importLine: "import 'package:$name/$name.dart';",
      registrationLine:
          '  getIt.registerLazySingleton<${pascal}Service>(${pascal}Service.new);',
    );
  }

  stdout.writeln('\nNext: melos bootstrap && melos run lint && melos run test');
}

String _toPascalCase(String snake) =>
    snake.split('_').map((p) => p[0].toUpperCase() + p.substring(1)).join();

Map<String, String> _templates(String name, String pascal, String desc) => {
      'pubspec.yaml': '''
name: $name
description: $desc
version: 0.0.1
publish_to: 'none'

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: ">=3.0.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^5.1.0
''',
      'analysis_options.yaml': 'include: ../../../analysis_options.yaml\n',
      'lib/$name.dart': "export 'src/${name}_service.dart';\n",
      'lib/src/${name}_service.dart': '''
/// $desc
class ${pascal}Service {
  const ${pascal}Service();

  /// Returns a short description of this service.
  String describe() => '$name service';
}
''',
      'test/${name}_service_test.dart': '''
import 'package:$name/$name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('describe returns a label', () {
    expect(const ${pascal}Service().describe(), '$name service');
  });
}
''',
    };

Never _fail(String message) {
  stderr.writeln('Error: $message');
  exit(1);
}

const _usage = '''
Usage: dart run tool/create_package.dart <name> [--layer core|services]
       [--description "..."] [--wire <app>]

Options:
  -l, --layer          Target layer: core (default) or services.
  -d, --description     pubspec description.
  -w, --wire <app>      Also add + register the package in apps/<app>.
  -h, --help            Show this help.''';
