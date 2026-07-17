import 'package:analytics/analytics.dart';

/// One recorded `logEvent` call: its name and parameters.
typedef RecordedEvent = ({String name, Map<String, Object>? parameters});

/// An [AppLogger] that records every event instead of sending it anywhere —
/// the fake the M7.2 funnel tests assert against.
class RecordingAppLogger extends AppLogger {
  /// Every `logEvent` call, in order.
  final List<RecordedEvent> events = [];

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    events.add((name: name, parameters: parameters));
  }

  /// The recorded events with [name], in order.
  List<RecordedEvent> named(String name) => [
    for (final event in events)
      if (event.name == name) event,
  ];
}
