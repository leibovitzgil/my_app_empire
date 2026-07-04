import 'package:feature_library/src/domain/library_repository.dart';

/// A simple in-memory [LibraryRepository] for development and tests.
class InMemoryLibraryRepository implements LibraryRepository {
  String _value = 'Hello from library';

  @override
  Future<String> load() async => _value;

  @override
  Future<void> save(String value) async => _value = value;
}
