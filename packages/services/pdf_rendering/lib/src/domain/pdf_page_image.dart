import 'package:equatable/equatable.dart';

/// A single rendered page, as raw RGBA bytes plus the pixel dimensions
/// needed to interpret them.
class PdfPageImage extends Equatable {
  /// Creates a [PdfPageImage].
  const PdfPageImage({
    required this.pageIndex,
    required this.width,
    required this.height,
    required this.bytes,
  });

  /// The zero-based page index this image was rendered from.
  final int pageIndex;

  /// The rendered image width, in pixels.
  final int width;

  /// The rendered image height, in pixels.
  final int height;

  /// The raw RGBA pixel data.
  final List<int> bytes;

  @override
  List<Object?> get props => [pageIndex, width, height, bytes];
}
