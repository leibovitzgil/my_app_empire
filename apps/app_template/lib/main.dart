import 'package:flutter/material.dart';
import 'injection.dart';
import 'app.dart';

void main() {
  configureDependencies();
  runApp(const App());
}
