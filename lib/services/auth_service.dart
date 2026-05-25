import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  Future<UserModel> login(String email, String password) async {
    final response = await _apiService.post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    
    return UserModel.fromJson(response['user']);
  }

  Future<UserModel> register(String email, String password, String nickname) async {
    final response = await _apiService.post('/api/auth/register', {
      'email': email,
      'password': password,
      'nickname': nickname,
    });
    
    return UserModel.fromJson(response['user']);
  }

  Future<void> logout() async {
    // 로컬 로그아웃만 수행하므로 가벼운 지연 시간 설정
    await Future.delayed(const Duration(milliseconds: 100));
  }
}