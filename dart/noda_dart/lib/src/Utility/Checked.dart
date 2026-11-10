// noda_dart: new code. C#'s checked arithmetic (Dart's int wraps silently). See docs/porting-conventions.md.

import 'Int64.dart';
import 'SystemExceptions.dart';

/// Checked `long` and `int` arithmetic: each throws [OverflowException] where checked C# would.
abstract final class Checked {
  /// `checked(a + b)` for `long`s.
  static int Add(int a, int b) {
    final result = a + b;
    if (Int64.IsExact) {
      // Overflow iff both operands have the same sign and the result's sign differs.
      if (((a ^ result) & (b ^ result)) < 0) throw OverflowException();
    } else if (!_InRange(a.toDouble() + b.toDouble())) {
      throw OverflowException();
    }
    return result;
  }

  /// `checked(a - b)` for `long`s.
  static int Subtract(int a, int b) {
    final result = a - b;
    if (Int64.IsExact) {
      // Overflow iff the operands have different signs and the result's sign differs from a's.
      if (((a ^ b) & (a ^ result)) < 0) throw OverflowException();
    } else if (!_InRange(a.toDouble() - b.toDouble())) {
      throw OverflowException();
    }
    return result;
  }

  /// `checked(a * b)` for `long`s.
  static int Multiply(int a, int b) {
    if (a == 0 || b == 0) return 0;
    if (Int64.IsExact) {
      final result = a * b;
      // -1 * long.MinValue wraps to itself; otherwise dividing back recovers b exactly unless it overflowed.
      if ((a == -1 && b == Int64.MinValue) || (b == -1 && a == Int64.MinValue) || result ~/ b != a) {
        throw OverflowException();
      }
      return result;
    }
    final product = a.toDouble() * b.toDouble();
    if (!_InRange(product)) throw OverflowException();
    return a * b;
  }

  /// `checked(-a)` for a `long`.
  static int Negate(int a) {
    if (Int64.IsExact && a == Int64.MinValue) throw OverflowException();
    return -a;
  }

  /// `checked((int) x)`: [x] as a C# `int` (32-bit).
  static int ToInt32(int x) {
    if (x < Int64.Int32MinValue || x > Int64.Int32MaxValue) throw OverflowException();
    return x;
  }

  /// `checked(a + b)` for `int`s (32-bit).
  static int AddInt32(int a, int b) => ToInt32(a + b);

  /// `checked(a - b)` for `int`s (32-bit).
  static int SubtractInt32(int a, int b) => ToInt32(a - b);

  /// `checked(a * b)` for `int`s (32-bit).
  static int MultiplyInt32(int a, int b) => ToInt32(a * b);

  /// `checked((long) d)`: [d] truncated towards zero, or [OverflowException] if it's NaN or outside the `long` range.
  static int DoubleToInt64(double d) {
    if (d.isNaN || !_InRange(d.truncateToDouble())) throw OverflowException();
    return d.truncate();
  }

  /// `checked((int) d)`: [d] truncated towards zero, or [OverflowException] if it's NaN or outside the `int` range.
  static int DoubleToInt32(double d) {
    if (d.isNaN) throw OverflowException();
    final t = d.truncateToDouble();
    if (t < Int64.Int32MinValue || t > Int64.Int32MaxValue) throw OverflowException();
    return t.toInt();
  }

  // Whether a double is within the long range [-2^63, 2^63).
  static bool _InRange(double d) => d >= -9223372036854775808.0 && d < 9223372036854775808.0;
}
