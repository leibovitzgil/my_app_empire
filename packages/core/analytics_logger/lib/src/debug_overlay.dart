import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'app_logger.dart';

/// A screen that displays the logs captured by the [AppLogger].
///
/// This screen uses [TalkerScreen] from `talker_flutter` to show
/// a filterable list of logs, settings, and more.
class LoggerDebugScreen extends StatelessWidget {
  final AppLogger logger;

  const LoggerDebugScreen({super.key, required this.logger});

  @override
  Widget build(BuildContext context) {
    return TalkerScreen(talker: logger.talker);
  }
}
