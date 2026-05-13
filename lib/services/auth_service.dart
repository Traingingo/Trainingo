import '../models/user_model.dart';

class AuthService {
  Future<UserModel> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 700));

    return UserModel(
      id: 1,
      email: email,
      nickname: '건희',
    );
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}