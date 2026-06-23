import 'package:flutter/widgets.dart';
import 'package:showcase/app.dart';
import 'package:showcase/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const ShowcaseApp());
}
