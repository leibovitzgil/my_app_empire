import 'dart:async';

import 'package:duet/app.dart';
import 'package:duet/injection.dart';
import 'package:flutter/material.dart';
import 'package:review_prompter/review_prompter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  // Count this open toward the review-prompt threshold (M7.6). Real entry
  // points only — the headless gate never runs `main` — and fire-and-forget:
  // review bookkeeping must never delay (or be able to fail) first frame.
  unawaited(
    getIt.getAsync<ReviewPrompter>().then(
      (prompter) => prompter.incrementAppOpenCount(),
    ),
  );
  runApp(const App());
}
