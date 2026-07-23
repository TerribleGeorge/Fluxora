class BusinessDocument {
  const BusinessDocument._();

  static final _allowedCharacters = RegExp(r'[A-Za-z0-9]');
  static final _normalizedPattern = RegExp(r'^[A-Z0-9]{12}[0-9]{2}$');

  static String normalize(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune).toUpperCase();
      if (_allowedCharacters.hasMatch(char)) buffer.write(char);
    }
    return buffer.toString();
  }

  static String format(String value) {
    final normalized = normalize(value);
    if (normalized.length != 14) return value.trim();
    return '${normalized.substring(0, 2)}.'
        '${normalized.substring(2, 5)}.'
        '${normalized.substring(5, 8)}/'
        '${normalized.substring(8, 12)}-'
        '${normalized.substring(12, 14)}';
  }

  static bool isValid(String value) {
    final normalized = normalize(value);
    if (!_normalizedPattern.hasMatch(normalized)) return false;
    if (RegExp(r'^(\d)\1{13}$').hasMatch(normalized)) return false;

    final expectedFirst = _checkDigit(normalized.substring(0, 12), const [
      5,
      4,
      3,
      2,
      9,
      8,
      7,
      6,
      5,
      4,
      3,
      2,
    ]);
    final expectedSecond = _checkDigit(
      normalized.substring(0, 12) + expectedFirst.toString(),
      const [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2],
    );

    return normalized.endsWith('$expectedFirst$expectedSecond');
  }

  static int _checkDigit(String base, List<int> weights) {
    var sum = 0;
    for (var i = 0; i < weights.length; i++) {
      sum += _characterValue(base[i]) * weights[i];
    }
    final remainder = sum % 11;
    final digit = 11 - remainder;
    return digit >= 10 ? 0 : digit;
  }

  static int _characterValue(String char) {
    final code = char.codeUnitAt(0);
    if (code >= 48 && code <= 57) return code - 48;
    if (code >= 65 && code <= 90) return code - 48;
    throw FormatException('Caractere inválido no CNPJ: $char');
  }
}
