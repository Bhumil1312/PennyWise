/// INR amounts use integer paise. The bound also stays exact on Flutter Web.
const maxMinor = 9000000000000;

int parseMoney(String input, {bool allowNegative = false}) {
  final cleaned = input.trim().replaceFirst(
    RegExp(r'^(?:₹|INR\s*|Rs\.?\s*)', caseSensitive: false),
    '',
  );
  if (!RegExp(
    r'^-?(?:\d+|\d{1,3}(?:,\d{3})+|\d{1,2}(?:,\d{2})*,\d{3})(?:\.\d{1,2})?$',
  ).hasMatch(cleaned)) {
    throw const FormatException(
      'Enter a rupee amount with at most two decimal places.',
    );
  }
  final value = cleaned.replaceAll(',', '');
  final negative = value.startsWith('-');
  final parts = value.replaceFirst('-', '').split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > maxMinor ~/ 100) {
    throw const FormatException('Amount is too large.');
  }
  final result =
      whole * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  if (result > maxMinor || (negative && !allowNegative)) {
    throw const FormatException('Enter a valid positive amount.');
  }
  return negative ? -result : result;
}

String moneyInput(int minor) =>
    '${minor < 0 ? '-' : ''}${minor.abs() ~/ 100}.${(minor.abs() % 100).toString().padLeft(2, '0')}';

/// Allocate the remainder deterministically; no paise disappears.
List<int> splitEqually(int total, int count) {
  if (total < 0 || total > maxMinor || count <= 0) {
    throw ArgumentError('Invalid split.');
  }
  return List.generate(
    count,
    (i) => total ~/ count + (i < total % count ? 1 : 0),
  );
}

int checkedAmount(int value) {
  if (value.abs() > maxMinor) {
    throw const FormatException('Amount exceeds the supported limit.');
  }
  return value;
}
