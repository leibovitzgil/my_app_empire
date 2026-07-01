import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:tandem/data/tandem_deep_link_parser.dart';

/// An in-memory [DeepLinkService] for tests, mirroring the single-shot
/// [initialLink] latch semantics of [AppLinksDeepLinkService] but wired to
/// [tandemDeepLinkParser] instead of hitting the platform channel.
class FakeDeepLinkService implements DeepLinkService {
  FakeDeepLinkService();

  final _controller = StreamController<Uri>.broadcast();

  /// The link to hand back from the first [getInitialLink] call, if set.
  Uri? initialLink;

  bool _initialLinkConsumed = false;

  @override
  Future<Uri?> getInitialLink() async {
    if (_initialLinkConsumed) return null;
    _initialLinkConsumed = true;
    return initialLink;
  }

  @override
  Stream<Uri> get onLink => _controller.stream;

  @override
  Result<DeepLinkIntent> parse(Uri uri) => tandemDeepLinkParser(uri);

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
    await _controller.close();
  }
}
