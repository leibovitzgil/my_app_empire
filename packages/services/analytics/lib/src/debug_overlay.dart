import 'package:analytics/src/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// A screen that displays the logs captured by the [AppLogger].
///
/// This screen uses [TalkerScreen] from `talker_flutter` to show
/// a filterable list of logs, settings, and more.
class LoggerDebugScreen extends StatelessWidget {
  const LoggerDebugScreen({required this.logger, super.key});
  final AppLogger logger;

  @override
  Widget build(BuildContext context) {
    return TalkerScreen(talker: logger.talker);
  }
}
