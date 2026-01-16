abstract class AuthRepository {
  Stream<String?> get user;
  Future<void> login(String email, String password);
  Future<void> logout();
}
