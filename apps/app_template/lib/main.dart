import 'package:app_template/app.dart';
import 'package:app_template/injection.dart';
import 'package:flutter/material.dart';

void main() {
  configureDependencies();
  runApp(const App());
}
