import 'package:flutter/widgets.dart';
import 'package:tandem/app.dart';
import 'package:tandem/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const TandemApp());
}
