import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _effectsEnabledKey = 'settings_effects_enabled';
  static const String _answerSoundsEnabledKey = 'settings_answer_sounds_enabled';
  static const String _backgroundMusicEnabledKey = 'settings_background_music_enabled';

  bool effectsEnabled = true;
  bool answerSoundsEnabled = true;
  bool backgroundMusicEnabled = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    effectsEnabled = prefs.getBool(_effectsEnabledKey) ?? true;
    answerSoundsEnabled = prefs.getBool(_answerSoundsEnabledKey) ?? true;
    backgroundMusicEnabled = prefs.getBool(_backgroundMusicEnabledKey) ?? false;
    notifyListeners();
  }

  Future<void> setEffectsEnabled(bool value) async {
    effectsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_effectsEnabledKey, value);
    notifyListeners();
  }

  Future<void> setAnswerSoundsEnabled(bool value) async {
    answerSoundsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_answerSoundsEnabledKey, value);
    notifyListeners();
  }

  Future<void> setBackgroundMusicEnabled(bool value) async {
    backgroundMusicEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backgroundMusicEnabledKey, value);
    notifyListeners();
  }
}
