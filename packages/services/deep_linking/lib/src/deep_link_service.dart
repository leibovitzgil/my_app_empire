import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/src/deep_link_exception.dart';
import 'package:deep_linking/src/deep_link_intent.dart';

/// Parses a raw [Uri] into an app-defined [DeepLinkIntent]. The package
/// defines this type and the failure vocabulary; the app that supplies the
/// function owns route matching.
typedef DeepLinkParser = Result<DeepLinkIntent> Function(Uri uri);

/// Intakes deep links (app_links, push notifications, ...) and exposes both
/// the raw [Uri] surface and an app-parsed [DeepLinkIntent] surface, so most
/// consumers never need to touch a raw [Uri] directly for routing.
abstract class DeepLinkService {
  /// The link that launched the app, if any. Returns `null` on every call
  /// after the first (there is only ever one "initial" link per process).
  Future<Uri?> getInitialLink();

  /// A broadcast stream of raw links received while the app is running.
  Stream<Uri> get onLink;

  /// Parses [uri] using the app-supplied [DeepLinkParser].
  Result<DeepLinkIntent> parse(Uri uri);

  /// Parses a raw string, first attempting to turn it into a [Uri].
  Result<DeepLinkIntent> parseRaw(String rawValue);

  /// The parsed form of [getInitialLink], or `null` if there was none.
  Future<Result<DeepLinkIntent>?> getInitialIntent();

  /// [onLink], parsed via [parse].
  Stream<Result<DeepLinkIntent>> get onIntent;

  /// Feeds an externally-sourced [uri] (e.g. from a push notification
  /// payload) into the same pipeline as [onLink]/[onIntent].
  void ingest(Uri uri);

  /// Releases underlying resources (stream subscriptions/controllers).
  Future<void> dispose();
}

/// [DeepLinkService] backed by `package:app_links`.
class AppLinksDeepLinkService implements DeepLinkService {
  AppLinksDeepLinkService({required DeepLinkParser parser, AppLinks? appLinks})
    : _parser = parser,
      _appLinks = appLinks ?? AppLinks() {
    _controller = StreamController<Uri>.broadcast(
      onListen: _startListening,
      onCancel: _stopListening,
    );
  }

  final DeepLinkParser _parser;
  final AppLinks _appLinks;
  late final StreamController<Uri> _controller;
  StreamSubscription<Uri>? _linkSubscription;
  bool _initialLinkConsumed = false;

  // Subscribing lazily (only once something actually listens to [onLink] or
  // [onIntent]) means merely constructing/registering this service in DI
  // never touches the platform channel.
  void _startListening() {
    _linkSubscription ??= _appLinks.uriLinkStream.listen(_controller.add);
  }

  void _stopListening() {
    unawaited(_linkSubscription?.cancel());
    _linkSubscription = null;
  }

  @override
  Future<Uri?> getInitialLink() async {
    if (_initialLinkConsumed) return null;
    _initialLinkConsumed = true;
    return _appLinks.getInitialLink();
  }

  @override
  Stream<Uri> get onLink => _controller.stream;

  @override
  Result<DeepLinkIntent> parse(Uri uri) {
    try {
      return _parser(uri);
    } on Object catch (error, stackTrace) {
      return ResultFailure<DeepLinkIntent>(
        UnrecognizedLinkException(uri, reason: error.toString()),
        stackTrace,
      );
    }
  }

  @override
  Result<DeepLinkIntent> parseRaw(String rawValue) {
    final uri = Uri.tryParse(rawValue);
    if (uri == null) {
      return ResultFailure<DeepLinkIntent>(InvalidLinkException(rawValue));
    }
    return parse(uri);
  }

  @override
  Future<Result<DeepLinkIntent>?> getInitialIntent() async {
    final uri = await getInitialLink();
    if (uri == null) return null;
    return parse(uri);
  }

  @override
  Stream<Result<DeepLinkIntent>> get onIntent => onLink.map(parse);

  @override
  void ingest(Uri uri) => _controller.add(uri);

  @override
  Future<void> dispose() async {
    await _linkSubscription?.cancel();
    await _controller.close();
  }
}
