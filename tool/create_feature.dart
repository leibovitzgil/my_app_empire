// Scaffolds a new feature package in `packages/features/feature_<name>`,
// mirroring the structure of the `feature_auth` golden example
// (domain / data / bloc / ui + a bloc test).
//
// Usage:
//   dart run tool/create_feature.dart <name> [--description "..."] [--wire <app>]
//
// <name> is the feature name in snake_case, without the `feature_` prefix
// (e.g. `profile` -> package `feature_profile`, classes `ProfileBloc`, ...).
// --wire <app> also registers the feature's in-memory repository in the app's
// get_it injection (before the `// generated:register` marker).
//
// Intentionally dependency-free (dart:io only) apart from a sibling helper.
import 'dart:io';

import 'src/wiring.dart';

final _validName = RegExp(r'^[a-z][a-z0-9_]*$');

void main(List<String> args) {
  final positional = <String>[];
  String? description;
  String? wireApp;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--description' || arg == '-d') {
      if (i + 1 >= args.length) _fail('Missing value for $arg');
      description = args[++i];
    } else if (arg.startsWith('--description=')) {
      description = arg.substring('--description='.length);
    } else if (arg == '--wire' || arg == '-w') {
      if (i + 1 >= args.length) _fail('Missing value for $arg');
      wireApp = args[++i];
    } else if (arg == '--help' || arg == '-h') {
      stdout.writeln(_usage);
      exit(0);
    } else {
      positional.add(arg);
    }
  }

  if (positional.length != 1) {
    _fail('Expected exactly one feature name.\n\n$_usage');
  }

  var name = positional.single;
  if (name.startsWith('feature_')) name = name.substring('feature_'.length);
  if (!_validName.hasMatch(name)) {
    _fail(
      "'$name' is not a valid feature name. Use lowercase letters, digits and "
      'underscores, starting with a letter (e.g. profile or user_profile).',
    );
  }

  final repoRoot = File(Platform.script.toFilePath()).parent.parent;
  final dir = Directory('${repoRoot.path}/packages/features/feature_$name');
  if (dir.existsSync()) {
    _fail('${dir.path} already exists. Pick a different name or remove it.');
  }

  final pascal = _toPascalCase(name);
  final desc = description ?? 'The $name feature.';

  for (final entry in _templates(name, pascal, desc).entries) {
    final file = File('${dir.path}/${entry.key}')
      ..parent.createSync(recursive: true);
    file.writeAsStringSync(entry.value);
  }

  stdout.writeln('✓ Created packages/features/feature_$name (prefix: $pascal)');

  if (wireApp != null) {
    wireIntoApp(
      repoRoot: repoRoot,
      app: wireApp,
      depName: 'feature_$name',
      depPath: '../../packages/features/feature_$name',
      importLine: "import 'package:feature_$name/feature_$name.dart';",
      registrationLine: '  getIt.registerLazySingleton<${pascal}Repository>'
          '(InMemory${pascal}Repository.new);',
    );
  }

  stdout.writeln('\nNext: melos bootstrap && melos run lint && melos run test');
}

String _toPascalCase(String snake) =>
    snake.split('_').map((p) => p[0].toUpperCase() + p.substring(1)).join();

Map<String, String> _templates(String name, String pascal, String desc) => {
      'pubspec.yaml': '''
name: feature_$name
description: $desc
version: 0.0.1
publish_to: 'none'

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: ">=3.0.0"

dependencies:
  bloc: ^8.1.0
  core_ui:
    path: ../../core/core_ui
  equatable: ^2.0.5
  flutter:
    sdk: flutter
  flutter_bloc: ^8.1.0

dev_dependencies:
  bloc_test: ^9.1.0
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0
  very_good_analysis: ^5.1.0
''',
      'analysis_options.yaml': 'include: ../../../analysis_options.yaml\n',
      'lib/feature_$name.dart': '''
export 'src/bloc/${name}_bloc.dart';
export 'src/data/in_memory_${name}_repository.dart';
export 'src/domain/${name}_repository.dart';
export 'src/ui/${name}_screen.dart';
''',
      'lib/src/domain/${name}_repository.dart': '''
/// Contract for $name data access.
abstract class ${pascal}Repository {
  /// Loads the current $name value.
  Future<String> load();

  /// Persists a new $name value.
  Future<void> save(String value);
}
''',
      'lib/src/data/in_memory_${name}_repository.dart': '''
import 'package:feature_$name/src/domain/${name}_repository.dart';

/// A simple in-memory [${pascal}Repository] for development and tests.
class InMemory${pascal}Repository implements ${pascal}Repository {
  String _value = 'Hello from $name';

  @override
  Future<String> load() async => _value;

  @override
  Future<void> save(String value) async => _value = value;
}
''',
      'lib/src/bloc/${name}_bloc.dart': '''
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_$name/src/domain/${name}_repository.dart';

part '${name}_event.dart';
part '${name}_state.dart';

class ${pascal}Bloc extends Bloc<${pascal}Event, ${pascal}State> {
  ${pascal}Bloc({required ${pascal}Repository repository})
      : _repository = repository,
        super(const ${pascal}State.initial()) {
    on<${pascal}Requested>(_onRequested);
  }

  final ${pascal}Repository _repository;

  Future<void> _onRequested(
    ${pascal}Requested event,
    Emitter<${pascal}State> emit,
  ) async {
    emit(const ${pascal}State.loading());
    try {
      final value = await _repository.load();
      emit(${pascal}State.loaded(value));
    } on Exception catch (error) {
      emit(${pascal}State.failure(error.toString()));
    }
  }
}
''',
      'lib/src/bloc/${name}_event.dart': '''
part of '${name}_bloc.dart';

sealed class ${pascal}Event extends Equatable {
  const ${pascal}Event();

  @override
  List<Object?> get props => [];
}

final class ${pascal}Requested extends ${pascal}Event {
  const ${pascal}Requested();
}
''',
      'lib/src/bloc/${name}_state.dart': '''
part of '${name}_bloc.dart';

enum ${pascal}Status { initial, loading, loaded, failure }

final class ${pascal}State extends Equatable {
  const ${pascal}State._({
    this.status = ${pascal}Status.initial,
    this.value,
    this.error,
  });

  const ${pascal}State.initial() : this._();

  const ${pascal}State.loading() : this._(status: ${pascal}Status.loading);

  const ${pascal}State.loaded(String value)
      : this._(status: ${pascal}Status.loaded, value: value);

  const ${pascal}State.failure(String error)
      : this._(status: ${pascal}Status.failure, error: error);

  final ${pascal}Status status;
  final String? value;
  final String? error;

  @override
  List<Object?> get props => [status, value, error];
}
''',
      'lib/src/ui/${name}_screen.dart': '''
import 'package:feature_$name/src/bloc/${name}_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ${pascal}Screen extends StatelessWidget {
  const ${pascal}Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$pascal')),
      body: BlocBuilder<${pascal}Bloc, ${pascal}State>(
        builder: (context, state) {
          switch (state.status) {
            case ${pascal}Status.initial:
            case ${pascal}Status.loading:
              return const Center(child: CircularProgressIndicator());
            case ${pascal}Status.loaded:
              return Center(child: Text(state.value ?? ''));
            case ${pascal}Status.failure:
              return Center(child: Text(state.error ?? 'Error'));
          }
        },
      ),
    );
  }
}
''',
      'test/${name}_bloc_test.dart': '''
import 'package:bloc_test/bloc_test.dart';
import 'package:feature_$name/feature_$name.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class Mock${pascal}Repository extends Mock implements ${pascal}Repository {}

void main() {
  group('${pascal}Bloc', () {
    late ${pascal}Repository repository;

    setUp(() {
      repository = Mock${pascal}Repository();
    });

    test('initial state is initial', () {
      expect(
        ${pascal}Bloc(repository: repository).state,
        const ${pascal}State.initial(),
      );
    });

    blocTest<${pascal}Bloc, ${pascal}State>(
      'emits [loading, loaded] when load succeeds',
      build: () {
        when(() => repository.load()).thenAnswer((_) async => 'value');
        return ${pascal}Bloc(repository: repository);
      },
      act: (bloc) => bloc.add(const ${pascal}Requested()),
      expect: () => const [
        ${pascal}State.loading(),
        ${pascal}State.loaded('value'),
      ],
    );

    blocTest<${pascal}Bloc, ${pascal}State>(
      'emits [loading, failure] when load throws',
      build: () {
        when(() => repository.load()).thenThrow(Exception('boom'));
        return ${pascal}Bloc(repository: repository);
      },
      act: (bloc) => bloc.add(const ${pascal}Requested()),
      expect: () => [
        const ${pascal}State.loading(),
        isA<${pascal}State>()
            .having((s) => s.status, 'status', ${pascal}Status.failure),
      ],
    );
  });
}
''',
    };

Never _fail(String message) {
  stderr.writeln('Error: $message');
  exit(1);
}

const _usage = '''
Usage: dart run tool/create_feature.dart <name> [--description "..."]

Arguments:
  <name>                Feature name in snake_case, no `feature_` prefix
                        (e.g. profile, user_profile).

Options:
  -d, --description     Description for the new package's pubspec.yaml.
  -h, --help            Show this help.''';
