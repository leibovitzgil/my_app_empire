/// Contract for pairing data access.
abstract class PairingRepository {
  /// Loads the current pairing value.
  Future<String> load();

  /// Persists a new pairing value.
  Future<void> save(String value);
}
