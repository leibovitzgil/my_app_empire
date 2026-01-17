import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  bool deployAll = args.contains('--all');
  String? diffBase;

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--diff' && i + 1 < args.length) {
      diffBase = args[i + 1];
      break;
    }
  }

  stderr.writeln('Deploy all: $deployAll');
  stderr.writeln('Diff base: $diffBase');

  ProcessResult result;
  if (deployAll) {
    stderr.writeln('Running: melos list --json');
    result = await Process.run('melos', ['list', '--json']);
  } else if (diffBase != null) {
    stderr.writeln('Running: melos list --diff $diffBase --include-dependents --json');
    result = await Process.run('melos', ['list', '--diff', diffBase, '--include-dependents', '--json']);
  } else {
    stderr.writeln('Error: Either --all or --diff <base> must be provided.');
    exit(1);
  }

  if (result.exitCode != 0) {
    stderr.writeln('Melos command failed:');
    stderr.writeln(result.stderr);
    exit(result.exitCode);
  }

  String output = result.stdout as String;
  List<dynamic> packages;
  try {
    packages = jsonDecode(output);
  } catch (e) {
    stderr.writeln('Failed to decode melos output: $e');
    stderr.writeln('Output was: $output');
    exit(1);
  }

  List<String> appPaths = [];
  for (var pkg in packages) {
    var path = pkg['relativePath'];
    if (path != null && (path.toString().startsWith('apps/') || path.toString().startsWith('apps\\'))) {
      appPaths.add(path.toString());
    }
  }

  // Print the final JSON array to stdout
  print(jsonEncode(appPaths));
}
