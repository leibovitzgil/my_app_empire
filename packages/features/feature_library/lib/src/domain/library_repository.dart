/// Contract for library data access.
abstract class LibraryRepository {
  /// Loads the current library value.
  Future<String> load();

  /// Persists a new library value.
  Future<void> save(String value);
}
