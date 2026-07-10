import 'package:pieces/pieces.dart';

/// One audio note entry inside a [ReviewManifest]: the note's metadata plus
/// the filename it was packaged under in the bundle's `audio/` directory.
/// [note]'s `audioAssetId` is meaningless outside the sender's own device
/// (asset ids are local-store-generated, never synced) — the importer must
/// copy the referenced bytes into its own `AudioAssetStore` and substitute a
/// freshly generated id before persisting it.
class ManifestAudioEntry {
  /// Creates a [ManifestAudioEntry].
  const ManifestAudioEntry({required this.note, required this.audioFile});

  /// The note's metadata, as authored on the sender's device.
  final AudioNote note;

  /// The filename this note's audio was packaged under, under `audio/` in
  /// the bundle archive.
  final String audioFile;
}

/// The parsed contents of a `.duet` review bundle's `manifest.json`: one
/// author's ink strokes and audio notes for a single piece, plus enough of
/// the base PDF's identity to detect drift (and, on a first share, the PDF
/// itself).
class ReviewManifest {
  /// Creates a [ReviewManifest].
  const ReviewManifest({
    required this.version,
    required this.pieceId,
    required this.pieceTitle,
    required this.authorId,
    required this.exportedAtMillis,
    required this.basePdfChecksum,
    required this.basePdfFilename,
    required this.strokes,
    required this.audioEntries,
    this.authorName,
  });

  /// Reverses [toJson]. `authorName` is read leniently (absent -> `null`) so
  /// bundles exported before that field existed keep decoding cleanly.
  factory ReviewManifest.fromJson(Map<String, dynamic> json) {
    final basePdf = json['basePdf'] as Map<String, dynamic>?;
    return ReviewManifest(
      version: json['version'] as int,
      pieceId: json['pieceId'] as String,
      pieceTitle: json['pieceTitle'] as String,
      authorId: json['authorId'] as String,
      authorName: json['authorName'] as String?,
      exportedAtMillis: json['exportedAtMillis'] as int,
      basePdfChecksum: basePdf?['checksum'] as String? ?? '',
      basePdfFilename: basePdf?['filename'] as String?,
      strokes: [
        for (final e in json['strokes'] as List<dynamic>)
          _strokeFromJson(e as Map<String, dynamic>),
      ],
      audioEntries: [
        for (final e in json['audioNotes'] as List<dynamic>)
          _audioEntryFromJson(e as Map<String, dynamic>),
      ],
    );
  }

  /// The manifest schema version, for forward compatibility.
  final int version;

  /// The id of the piece this bundle was exported from.
  final String pieceId;

  /// The piece's title, so a receiver without the piece yet can label it.
  final String pieceTitle;

  /// The id of the participant whose slice this bundle contains.
  final String authorId;

  /// The author's display name at export time, if known locally on their
  /// device — carried through so a receiver creating this piece for the
  /// first time (see `FileShareReviewSyncService._importPieceFromBundle`)
  /// can attach a real `Piece.ownerName` instead of leaving it null.
  final String? authorName;

  /// When this bundle was exported, in epoch milliseconds. Doubles as the
  /// per-author monotonic revision: an import is dropped if this value is
  /// less than or equal to the last-applied revision for
  /// ([pieceId], [authorId]).
  final int exportedAtMillis;

  /// The base PDF's content checksum, to detect drift between copies.
  final String basePdfChecksum;

  /// The base PDF's filename, present only on a "first share" bundle (see
  /// `FileShareReviewSyncService`'s `_baseSharedKey` doc for the exact
  /// rule) — otherwise the receiver is assumed to already have it.
  final String? basePdfFilename;

  /// The author's ink strokes at the time of export.
  final List<InkStroke> strokes;

  /// The author's audio notes at the time of export.
  final List<ManifestAudioEntry> audioEntries;

  /// Serializes this manifest to JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'pieceId': pieceId,
    'pieceTitle': pieceTitle,
    'authorId': authorId,
    'authorName': authorName,
    'exportedAtMillis': exportedAtMillis,
    'basePdf': <String, dynamic>{
      'checksum': basePdfChecksum,
      'filename': basePdfFilename,
    },
    'strokes': strokes.map(_strokeToJson).toList(),
    'audioNotes': [
      for (final entry in audioEntries) _audioEntryToJson(entry),
    ],
  };
}

Map<String, dynamic> _strokeToJson(InkStroke stroke) => <String, dynamic>{
  'id': stroke.id,
  'authorId': stroke.authorId,
  'pageIndex': stroke.pageIndex,
  'colorId': stroke.colorId,
  'points': [
    for (final point in stroke.points)
      <String, dynamic>{'x': point.x, 'y': point.y},
  ],
};

InkStroke _strokeFromJson(Map<String, dynamic> json) => InkStroke(
  id: json['id'] as String,
  authorId: json['authorId'] as String,
  pageIndex: json['pageIndex'] as int,
  colorId: json['colorId'] as String,
  points: [
    for (final e in json['points'] as List<dynamic>)
      _pointFromJson(e as Map<String, dynamic>),
  ],
);

InkPoint _pointFromJson(Map<String, dynamic> json) => InkPoint(
  x: (json['x'] as num).toDouble(),
  y: (json['y'] as num).toDouble(),
);

Map<String, dynamic> _regionToJson(Region region) => <String, dynamic>{
  'pageIndex': region.pageIndex,
  'left': region.left,
  'top': region.top,
  'width': region.width,
  'height': region.height,
};

Region _regionFromJson(Map<String, dynamic> json) => Region(
  pageIndex: json['pageIndex'] as int,
  left: (json['left'] as num).toDouble(),
  top: (json['top'] as num).toDouble(),
  width: (json['width'] as num).toDouble(),
  height: (json['height'] as num).toDouble(),
);

Map<String, dynamic> _audioEntryToJson(ManifestAudioEntry entry) =>
    <String, dynamic>{
      'id': entry.note.id,
      'authorId': entry.note.authorId,
      'pageIndex': entry.note.pageIndex,
      'durationMs': entry.note.durationMs,
      'region': _regionToJson(entry.note.region),
      'createdAtMillis': entry.note.createdAt.millisecondsSinceEpoch,
      'audioFile': entry.audioFile,
    };

ManifestAudioEntry _audioEntryFromJson(Map<String, dynamic> json) {
  final note = AudioNote(
    id: json['id'] as String,
    authorId: json['authorId'] as String,
    // Placeholder: asset ids are local-store-generated and never synced.
    // The importer must copy the referenced bytes into its own
    // `AudioAssetStore` and substitute the id it's assigned before this
    // note is persisted.
    audioAssetId: '',
    pageIndex: json['pageIndex'] as int,
    durationMs: json['durationMs'] as int,
    region: _regionFromJson(json['region'] as Map<String, dynamic>),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      json['createdAtMillis'] as int,
    ),
  );
  return ManifestAudioEntry(
    note: note,
    audioFile: json['audioFile'] as String,
  );
}
