/// Contract for score data access.
abstract class ScoreRepository {
  /// Loads the current score value.
  Future<String> load();

  /// Persists a new score value.
  Future<void> save(String value);
}
