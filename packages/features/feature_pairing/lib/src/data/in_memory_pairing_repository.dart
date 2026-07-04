import 'package:feature_pairing/src/domain/pairing_repository.dart';

/// A simple in-memory [PairingRepository] for development and tests.
class InMemoryPairingRepository implements PairingRepository {
  String _value = 'Hello from pairing';

  @override
  Future<String> load() async => _value;

  @override
  Future<void> save(String value) async => _value = value;
}
