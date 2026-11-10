// noda_dart: new code. C#'s long limits, written so dart2js compiles them. See docs/porting-conventions.md.

/// C#'s `long` (and `int`) limits, and whether this platform's `int` is exact beyond 2^53.
abstract final class Int64 {
  /// `long.MaxValue`: 2^63 - 1 (on dart2js, the nearest double, 2^63).
  static final int MaxValue = int.parse('9223372036854775807');

  /// `long.MinValue`: -2^63.
  static final int MinValue = int.parse('-9223372036854775808');

  /// `int.MaxValue`.
  static const int Int32MaxValue = 2147483647;

  /// `int.MinValue`.
  static const int Int32MinValue = -2147483648;

  /// Whether `int` is 64-bit (not dart2js's doubles).
  static const bool IsExact = !identical(1, 1.0);

  /// The largest integer every platform represents exactly: 2^53 - 1 (JavaScript's `Number.MAX_SAFE_INTEGER`).
  static const int MaxSafeInteger = 9007199254740991;
}
