import 'package:feature_score/src/domain/score_repository.dart';

/// A simple in-memory [ScoreRepository] for development and tests.
class InMemoryScoreRepository implements ScoreRepository {
  String _value = 'Hello from score';

  @override
  Future<String> load() async => _value;

  @override
  Future<void> save(String value) async => _value = value;
}
