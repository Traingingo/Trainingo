import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundEffect {
  click,
  correct,
  wrong,
  complete,
  gradingComplete,
  codeSuccess,
  codeFail,
  softAlert,
}

class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  static const String effectsEnabledKey = 'settings_effects_enabled';
  static const String answerSoundsEnabledKey = 'settings_answer_sounds_enabled';

  final AudioPlayer _player = AudioPlayer();

  Future<void> play(SoundEffect effect) async {
    final prefs = await SharedPreferences.getInstance();
    final effectsEnabled = prefs.getBool(effectsEnabledKey) ?? true;
    final answerSoundsEnabled = prefs.getBool(answerSoundsEnabledKey) ?? true;

    if (!effectsEnabled) return;

    final isAnswerSound = effect == SoundEffect.correct || effect == SoundEffect.wrong;
    if (isAnswerSound && !answerSoundsEnabled) return;

    try {
      await _player.stop();
      await _player.play(AssetSource(_assetPathOf(effect)));
    } catch (e) {
      debugPrint('효과음 재생 실패: $e');
    }
  }

  String _assetPathOf(SoundEffect effect) {
    switch (effect) {
      case SoundEffect.click:
        return 'sounds/click.mp3';
      case SoundEffect.correct:
        return 'sounds/correct.mp3';
      case SoundEffect.wrong:
        return 'sounds/wrong.mp3';
      case SoundEffect.complete:
        return 'sounds/complete.mp3';
      case SoundEffect.gradingComplete:
        return 'sounds/grading_complete.mp3';
      case SoundEffect.codeSuccess:
        return 'sounds/code_success.mp3';
      case SoundEffect.codeFail:
        return 'sounds/code_fail.mp3';
      case SoundEffect.softAlert:
        return 'sounds/soft_alert.mp3';
    }
  }
}
