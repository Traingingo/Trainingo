import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? user;
  bool isLoading = false;

  bool get isLoggedIn => user != null;

  Future<void> login(String email, String password) async {
    isLoading = true;
    notifyListeners();

    try {
      user = await _authService.login(email, password);
    } catch (e) {
      user = null;
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String email, String password, String nickname) async {
    isLoading = true;
    notifyListeners();

    try {
      user = await _authService.register(email, password, nickname);
    } catch (e) {
      user = null;
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    user = null;
    notifyListeners();
  }
}