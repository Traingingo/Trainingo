import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _currentUserKey = 'trainingo_current_user';

  final AuthService _authService = AuthService();

  UserModel? user;
  bool isLoading = false;
  bool isInitialized = false;

  bool get isLoggedIn => user != null;

  Future<void> initialize() async {
    if (isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawUser = prefs.getString(_currentUserKey);

      if (rawUser != null && rawUser.isNotEmpty) {
        final decoded = jsonDecode(rawUser);
        if (decoded is Map<String, dynamic>) {
          user = UserModel.fromJson(decoded);
        } else if (decoded is Map) {
          user = UserModel.fromJson(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (e) {
      user = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserKey);
      debugPrint('저장된 로그인 상태 복원 실패: $e');
    } finally {
      isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    isLoading = true;
    notifyListeners();

    try {
      user = await _authService.login(email, password);
      await _persistUser(user);
    } catch (e) {
      user = null;
      await _clearPersistedUser();
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
      await _persistUser(user);
    } catch (e) {
      user = null;
      await _clearPersistedUser();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    user = null;
    await _clearPersistedUser();
    notifyListeners();
  }

  Future<void> _persistUser(UserModel? currentUser) async {
    if (currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _currentUserKey,
      jsonEncode(currentUser.toJson()),
    );
  }

  Future<void> _clearPersistedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }
}
