import 'package:core_ui/core_ui.dart';
import 'package:feature_library/src/bloc/import_piece_bloc.dart';
import 'package:feature_library/src/data/pdf_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';

/// Entry widget for the Import PDF flow: provides [ImportPieceBloc] and
/// renders [ImportPieceScreen]. Pushed by `LibraryHomeScreen`; pops with the
/// created [Piece] on success (or `null` if the user backs out), so the
/// caller can navigate on to `feature_score`'s viewer.
class ImportPiecePage extends StatelessWidget {
  /// Creates an [ImportPiecePage].
  const ImportPiecePage({
    required this.pieceRepository,
    required this.renderService,
    this.filePicker,
    this.ownerName,
    super.key,
  });

  /// Where the imported piece is created.
  final PieceRepository pieceRepository;

  /// Validates a picked file opens as a real PDF before naming/submitting.
  final PdfRenderService renderService;

  /// See [ImportPieceBloc.new]'s `filePicker` parameter.
  final PdfFilePicker? filePicker;

  /// See [ImportPieceBloc.ownerName].
  final String? ownerName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ImportPieceBloc>(
      create: (_) => ImportPieceBloc(
        pieceRepository: pieceRepository,
        renderService: renderService,
        filePicker: filePicker,
        ownerName: ownerName,
      ),
      child: const ImportPieceScreen(),
    );
  }
}

/// The Import PDF flow's body: pick a file, validate it, name it, submit.
/// Reads [ImportPieceBloc] from context (provided by [ImportPiecePage]).
class ImportPieceScreen extends StatelessWidget {
  /// Creates an [ImportPieceScreen].
  const ImportPieceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ImportPieceBloc, ImportPieceState>(
      listenWhen: (previous, current) =>
          current.status != previous.status ||
          (current.submitError != null &&
              current.submitError != previous.submitError),
      listener: (context, state) {
        final error = state.submitError;
        if (error != null) AppSnackbar.error(context, error);
        if (state.status == ImportStatus.success) {
          Navigator.of(context).pop(state.piece);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Import a sheet')),
          body: switch (state.status) {
            ImportStatus.awaitingPick => const _ChooseFileBody(),
            ImportStatus.validating => const LoadingView(
              label: 'Checking file…',
            ),
            ImportStatus.invalid => ErrorRetryView(
              title: "Couldn't import this PDF",
              message: state.error,
              onRetry: () => context.read<ImportPieceBloc>().add(
                const ImportPickRequested(),
              ),
            ),
            ImportStatus.naming => _NamingBody(initialTitle: state.title),
            ImportStatus.success => const LoadingView(),
          },
        );
      },
    );
  }
}

class _ChooseFileBody extends StatelessWidget {
  const _ChooseFileBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 48),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Choose a PDF to import',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Choose PDF',
              onPressed: () => context.read<ImportPieceBloc>().add(
                const ImportPickRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NamingBody extends StatefulWidget {
  const _NamingBody({required this.initialTitle});

  final String initialTitle;

  @override
  State<_NamingBody> createState() => _NamingBodyState();
}

class _NamingBodyState extends State<_NamingBody> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialTitle,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImportPieceBloc, ImportPieceState>(
      buildWhen: (previous, current) =>
          previous.canSubmit != current.canSubmit ||
          previous.isSubmitting != current.isSubmitting,
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: _controller,
                label: 'Title',
                textInputAction: TextInputAction.done,
                onChanged: (value) => context.read<ImportPieceBloc>().add(
                  ImportTitleChanged(value),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Add sheet',
                isLoading: state.isSubmitting,
                onPressed: state.canSubmit
                    ? () => context.read<ImportPieceBloc>().add(
                        const ImportSubmitted(),
                      )
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
