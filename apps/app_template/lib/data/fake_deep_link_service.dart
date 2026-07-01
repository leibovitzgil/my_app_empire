import 'dart:async';

import 'package:app_template/routing/app_deep_link_parser.dart';
import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:injectable/injectable.dart';

/// An in-memory [DeepLinkService] for local development, mirroring the
/// single-shot [initialLink] latch semantics of [AppLinksDeepLinkService].
@LazySingleton(as: DeepLinkService)
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
  Result<DeepLinkIntent> parse(Uri uri) => appTemplateDeepLinkParser(uri);

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
