class AnswerNormalizer {
  static const Map<String, List<String>> synonymGroups = {
    'oop': [
      'objectorientedprogramming',
      'object-orientedprogramming',
      '객체지향프로그래밍',
      '객체지향',
    ],
    'sql': [
      'structuredquerylanguage',
      '구조적질의언어',
    ],
    'db': [
      'database',
      '데이터베이스',
    ],
  };

  static String normalize(String input) {
    var value = input.trim().toLowerCase();

    value = value
        .replaceAll(RegExp(r'[\s\-_]+'), '')
        .replaceAll(RegExp(r'[.,!?;:()\[\]{}"“”‘’`~@#$%^&*+=|\\/<>]'), '');

    value = _removeKoreanParticles(value);
    return _canonicalizeSynonym(value);
  }

  static List<String> normalizeAll(Iterable<String> answers) {
    return answers.map(normalize).where((answer) => answer.isNotEmpty).toSet().toList();
  }

  static bool isSameAnswer(String userAnswer, String expectedAnswer) {
    final user = normalize(userAnswer);
    final expected = normalize(expectedAnswer);
    if (user.isEmpty || expected.isEmpty) return false;

    return user == expected || user.contains(expected) || expected.contains(user);
  }

  static String _removeKoreanParticles(String value) {
    return value.replaceAll(
      RegExp(r'(은|는|이|가|을|를|과|와|로|으로|에|에서|에게|께|의)$'),
      '',
    );
  }

  static String _canonicalizeSynonym(String value) {
    for (final entry in synonymGroups.entries) {
      final normalizedValues = entry.value.map((item) => item.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), ''));
      if (entry.key == value || normalizedValues.contains(value)) {
        return entry.key;
      }
    }
    return value;
  }
}
