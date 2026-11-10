// noda_dart: new code. The .NET library members the tzdb compiler uses, with .NET's semantics.

import '../Utility/Int64.dart';
import '../Utility/SystemExceptions.dart';

/// The characters .NET's NumberStyles.AllowLeadingWhite/AllowTrailingWhite accept: U+0009-U+000D and U+0020.
const String _NumberWhite = r'[\t\n\v\f\r ]*';
final RegExp _IntegerRegex = RegExp('^$_NumberWhite([+-]?)([0-9]+)$_NumberWhite\$');
final RegExp _UnsignedIntegerRegex = RegExp('^$_NumberWhite()([0-9]+)$_NumberWhite\$');
final RegExp _DecimalRegex = RegExp('^$_NumberWhite([0-9]*(?:\\.[0-9]*)?)$_NumberWhite\$');

/// `int.Parse(text, style, CultureInfo.InvariantCulture)`: `NumberStyles.Integer` if [allowSign], else white
/// space only.
int ParseInt32(String text, [bool allowSign = true]) {
  final match = (allowSign ? _IntegerRegex : _UnsignedIntegerRegex).firstMatch(text);
  if (match == null) {
    throw FormatException("The input string '$text' was not in a correct format.");
  }
  // More than 10 significant digits is out of range (and would overflow int.parse).
  final digits = match.group(2)!.replaceFirst(RegExp('^0+(?=.)'), '');
  if (digits.length > 10) {
    throw OverflowException('Value was either too large or too small for an Int32.');
  }
  final value = int.parse(digits) * (match.group(1) == '-' ? -1 : 1);
  if (value < Int64.Int32MinValue || value > Int64.Int32MaxValue) {
    throw OverflowException('Value was either too large or too small for an Int32.');
  }
  return value;
}

/// `int.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out value)`, or null.
int? TryParseInt32(String text) {
  try {
    return ParseInt32(text);
  } on FormatException {
    return null;
  } on OverflowException {
    return null;
  }
}

/// `double.Parse(text, NumberStyles.AllowLeadingWhite | NumberStyles.AllowTrailingWhite |
/// NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture)`.
double ParseDecimalDouble(String text) {
  final match = _DecimalRegex.firstMatch(text);
  if (match == null || !RegExp('[0-9]').hasMatch(match.group(1)!)) {
    throw FormatException("The input string '$text' was not in a correct format.");
  }
  var number = match.group(1)!;
  // Dart's double.parse doesn't accept a leading or trailing '.' without digits on that side; .NET does.
  if (number.startsWith('.')) {
    number = '0$number';
  }
  if (number.endsWith('.')) {
    number = '${number}0';
  }
  return double.parse(number);
}

/// `char.IsWhiteSpace(c)`.
bool IsWhiteSpace(String c) {
  final code = c.codeUnitAt(0);
  return (code >= 0x09 && code <= 0x0d) ||
      code == 0x20 ||
      code == 0x85 ||
      code == 0xa0 ||
      code == 0x1680 ||
      (code >= 0x2000 && code <= 0x200a) ||
      code == 0x2028 ||
      code == 0x2029 ||
      code == 0x202f ||
      code == 0x205f ||
      code == 0x3000;
}

/// `string.TrimEnd()`.
String TrimEnd(String text) {
  var end = text.length;
  while (end > 0 && IsWhiteSpace(text[end - 1])) {
    end--;
  }
  return text.substring(0, end);
}

/// `string.Trim()`.
String Trim(String text) {
  var start = 0;
  while (start < text.length && IsWhiteSpace(text[start])) {
    start++;
  }
  return TrimEnd(text.substring(start));
}

final RegExp _LetterRegex = RegExp(r'^\p{L}$', unicode: true);

/// `char.IsLetter(c)`.
bool IsLetter(String c) => _LetterRegex.hasMatch(c);

/// `text.StartsWith(value, StringComparison.OrdinalIgnoreCase)` (unlike Dart's toUpperCase, "ı" doesn't match "I").
bool StartsWithOrdinalIgnoreCase(String text, String value) {
  if (value.length > text.length) {
    return false;
  }
  for (var i = 0; i < value.length; i++) {
    final a = text[i];
    final b = value[i];
    if (a != b && _ToUpperOrdinal(a) != _ToUpperOrdinal(b)) {
      return false;
    }
  }
  return true;
}

/// The upper case of a UTF-16 code unit, as .NET's ordinal casing gives it.
String _ToUpperOrdinal(String c) {
  final upper = c.toUpperCase();
  return upper.length != 1 || (c.codeUnitAt(0) >= 0x80 && upper.codeUnitAt(0) < 0x80) ? c : upper;
}

/// `Path.GetFileName(path)`.
String GetFileName(String path) {
  final slash = path.lastIndexOf('/');
  final backslash = path.lastIndexOf('\\');
  final index = slash > backslash ? slash : backslash;
  return path.substring(index + 1);
}

/// `dictionary[key]`: throws [ArgumentError] (.NET's `KeyNotFoundException`) if the key is missing.
V GetValue<K, V>(Map<K, V> dictionary, K key) {
  if (!dictionary.containsKey(key)) {
    throw ArgumentError("The given key '$key' was not present in the dictionary.");
  }
  return dictionary[key] as V;
}

/// `Dictionary.Add(key, value)`.
void AddValue<K, V>(Map<K, V> dictionary, K key, V value) {
  if (dictionary.containsKey(key)) {
    throw ArgumentError('An item with the same key has already been added. Key: $key');
  }
  dictionary[key] = value;
}

/// `string.CompareOrdinal(a, b)`.
int CompareOrdinal(String a, String b) => a.compareTo(b);

/// .NET's `System.Net.Http.HttpRequestException`.
class HttpRequestException implements Exception {
  final String message;

  /// The HTTP status code of the response, or null if there was none.
  final int? StatusCode;

  HttpRequestException(this.message, [this.StatusCode]);

  @override
  String toString() => 'HttpRequestException: $message';
}
