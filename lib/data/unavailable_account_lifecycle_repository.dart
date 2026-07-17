import '../domain/account_lifecycle_repository.dart';
import '../domain/auth_repository.dart';

class UnavailableAccountLifecycleRepository
    implements AccountLifecycleRepository {
  @override
  Future<void> deleteAccount() async {
    throw const AuthFailure(
      'A exclusão estará disponível após conectar o servidor.',
    );
  }
}
