// noda_dart: new code. The C# `decimal` arithmetic NodaTime uses, on BigInt: 96-bit overflow and quotient rounding.

import 'package:meta/meta.dart';

import 'SystemExceptions.dart';

/// C#'s `decimal` arithmetic on exact integers ([BigInt]).
@internal
abstract final class DecimalArithmetic {
  /// `decimal.MaxValue`: 2^96 - 1. (`decimal.MinValue` is its negation.)
  static final BigInt MaxValue = (BigInt.one << 96) - BigInt.one;

  /// The largest scale (number of digits after the decimal point) a decimal has.
  static const int MaxScale = 28;

  static final BigInt _Ten = BigInt.from(10);
  static final BigInt _Two = BigInt.two;

  /// Returns [value], or throws [OverflowException] if it's outside the range of a decimal.
  static BigInt CheckRange(BigInt value) {
    if (value.abs() > MaxValue) {
      throw OverflowException('Value was either too large or too small for a Decimal.');
    }
    return value;
  }

  /// `(decimal) dividend / (decimal) divisor`, rounded half to even to what a decimal holds.
  static (BigInt mantissa, int scale) Divide(BigInt dividend, BigInt divisor) {
    if (divisor == BigInt.zero) {
      throw DivideByZeroException();
    }
    if (divisor.isNegative) {
      dividend = -dividend;
      divisor = -divisor;
    }
    // A quotient with d integer digits leaves room for at most 29 - d digits after the point (2^96 has 29 digits).
    final integerPart = dividend.abs() ~/ divisor;
    final integerDigits = integerPart == BigInt.zero ? 0 : integerPart.toString().length;
    var scale = 29 - integerDigits < MaxScale ? 29 - integerDigits : MaxScale;
    for (; scale >= 0; scale--) {
      final mantissa = _RoundHalfEvenDivide(dividend * _Ten.pow(scale), divisor);
      if (mantissa.abs() <= MaxValue) {
        return (mantissa, scale);
      }
    }
    throw OverflowException('Value was either too large or too small for a Decimal.');
  }

  /// Divides by a positive [divisor], rounding half to even (as decimal division does).
  static BigInt _RoundHalfEvenDivide(BigInt numerator, BigInt divisor) {
    var quotient = numerator ~/ divisor;
    final remainder = numerator.remainder(divisor);
    final comparison = (remainder.abs() * _Two).compareTo(divisor);
    if (comparison > 0 || (comparison == 0 && quotient.isOdd)) {
      quotient += numerator.isNegative ? BigInt.from(-1) : BigInt.one;
    }
    return quotient;
  }
}
