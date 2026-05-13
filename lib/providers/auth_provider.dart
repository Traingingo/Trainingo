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

    user = await _authService.login(email, password);

    isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.logout();
    user = null;
    notifyListeners();
  }
}