part of 'library_bloc.dart';

enum LibraryStatus { initial, loading, loaded, failure }

final class LibraryState extends Equatable {
  const LibraryState._({
    this.status = LibraryStatus.initial,
    this.value,
    this.error,
  });

  const LibraryState.initial() : this._();

  const LibraryState.loading() : this._(status: LibraryStatus.loading);

  const LibraryState.loaded(String value)
    : this._(status: LibraryStatus.loaded, value: value);

  const LibraryState.failure(String error)
    : this._(status: LibraryStatus.failure, error: error);

  final LibraryStatus status;
  final String? value;
  final String? error;

  @override
  List<Object?> get props => [status, value, error];
}
