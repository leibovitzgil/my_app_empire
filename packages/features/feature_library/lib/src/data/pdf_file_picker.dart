import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// A minimal, platform-agnostic view of a PDF the user picked to import.
///
/// Decouples `ImportPieceBloc` (see `bloc/import_piece_bloc.dart`) from
/// `package:file_picker`'s richer `PlatformFile`, so the bloc stays testable
/// with a plain fake instead of a platform channel.
class PickedPdfFile extends Equatable {
  /// Creates a [PickedPdfFile].
  const PickedPdfFile({required this.path, required this.suggestedTitle});

  /// The on-device path to the picked PDF.
  final String path;

  /// A default title derived from the file name, pre-filled (and editable)
  /// in the naming step.
  final String suggestedTitle;

  @override
  List<Object?> get props => [path, suggestedTitle];
}

/// Picks a single PDF file, or `null` if the user cancels.
typedef PdfFilePicker = Future<PickedPdfFile?> Function();

/// The default [PdfFilePicker]: opens the OS file picker restricted to PDFs.
Future<PickedPdfFile?> pickPdfFile() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  final path = file.path;
  if (path == null) return null;
  return PickedPdfFile(
    path: path,
    suggestedTitle: p.basenameWithoutExtension(file.name),
  );
}
