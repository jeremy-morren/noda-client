// Ported from NodaTime 6e024dde: src/NodaTime/Text/FormatHelper.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Utility/Int64.dart';
import '../Utility/Preconditions.dart';

// noda_dart: StringBuffer is append-only, so digits written by index go through a list first.

/// The code unit of '0'.
const int _Zero = 0x30;

///   Provides helper methods for formatting values using pattern strings.
@internal
abstract final class FormatHelper {
  /// The maximum number of characters allowed for padded values.
  static const int _MaximumPaddingLength = 16;

  /// Maximum number of digits in a (positive) long.
  static const int _MaximumInt64Length = 19;

  /// Formats the given value to two digits, left-padding with '0' if necessary.
  /// It is assumed that the value is in the range [0, 100). This is usually
  /// used for month, day-of-month, hour, minute, second and year-of-century values.
  static void Format2DigitsNonNegative(int value, StringBuffer outputBuffer) {
    Preconditions.DebugCheckArgumentRange('value', value, 0, 99);
    outputBuffer.write(String.fromCharCode(_Zero + value ~/ 10));
    outputBuffer.write(String.fromCharCode(_Zero + value.remainder(10)));
  }

  /// Formats the given value to two digits, left-padding with '0' if necessary.
  /// It is assumed that the value is in the range [-9999, 10000). This is usually
  /// used for year values. If the value is negative, a '-' character is prepended.
  static void Format4DigitsValueFits(int value, StringBuffer outputBuffer) {
    Preconditions.DebugCheckArgumentRange('value', value, -9999, 10000);
    if (value < 0) {
      value = -value;
      outputBuffer.write('-');
    }
    outputBuffer.write(String.fromCharCode(_Zero + (value ~/ 1000)));
    outputBuffer.write(String.fromCharCode(_Zero + ((value ~/ 100).remainder(10))));
    outputBuffer.write(String.fromCharCode(_Zero + ((value ~/ 10).remainder(10))));
    outputBuffer.write(String.fromCharCode(_Zero + (value.remainder(10))));
  }

  /// Formats the given value left padded with zeros.
  ///
  /// Left pads with zeros the value into a field of [length] characters. If the value
  /// is longer than [length], the entire value is formatted. If the value is negative,
  /// it is preceded by "-" but this does not count against the length.
  ///
  /// [value]: The value to format.
  /// [length]: The length to fill.
  /// [outputBuffer]: The output buffer to add the digits to.
  static void LeftPad(int value, int length, StringBuffer outputBuffer) {
    Preconditions.DebugCheckArgumentRange('length', length, 1, _MaximumPaddingLength);
    if (value >= 0) {
      LeftPadNonNegative(value, length, outputBuffer);
      return;
    }
    outputBuffer.write('-');
    // Special case, as we can't use Math.Abs.
    if (value == Int64.Int32MinValue) {
      if (length > 10) {
        outputBuffer.write('000000'.substring(16 - length));
      }
      outputBuffer.write('2147483648');
      return;
    }
    LeftPadNonNegative(-value, length, outputBuffer);
  }

  /// Formats the given value left padded with zeros. The value is assumed to be non-negative.
  ///
  /// Left pads with zeros the value into a field of [length] characters. If the value
  /// is longer than [length], the entire value is formatted. If the value is negative,
  /// it is preceded by "-" but this does not count against the length.
  ///
  /// [value]: The value to format.
  /// [length]: The length to fill.
  /// [outputBuffer]: The output buffer to add the digits to.
  static void LeftPadNonNegative(int value, int length, StringBuffer outputBuffer) {
    Preconditions.DebugCheckArgumentRange('value', value, 0, Int64.Int32MaxValue);
    Preconditions.DebugCheckArgumentRange('length', length, 1, _MaximumPaddingLength);
    // Special handling for common cases, because we really don't want a heap allocation
    // if we can help it...
    if (length == 1) {
      if (value < 10) {
        outputBuffer.write(String.fromCharCode(_Zero + value));
        return;
      }
      // Handle overflow by a single character manually
      if (value < 100) {
        String digit1 = String.fromCharCode(_Zero + (value ~/ 10));
        String digit2 = String.fromCharCode(_Zero + (value.remainder(10)));
        outputBuffer
          ..write(digit1)
          ..write(digit2);
        return;
      }
    }
    if (length == 2 && value < 100) {
      String digit1 = String.fromCharCode(_Zero + (value ~/ 10));
      String digit2 = String.fromCharCode(_Zero + (value.remainder(10)));
      outputBuffer
        ..write(digit1)
        ..write(digit2);
      return;
    }
    if (length == 3 && value < 1000) {
      String digit1 = String.fromCharCode(_Zero + ((value ~/ 100).remainder(10)));
      String digit2 = String.fromCharCode(_Zero + ((value ~/ 10).remainder(10)));
      String digit3 = String.fromCharCode(_Zero + (value.remainder(10)));
      outputBuffer
        ..write(digit1)
        ..write(digit2)
        ..write(digit3);
      return;
    }
    if (length == 4 && value < 10000) {
      String digit1 = String.fromCharCode(_Zero + (value ~/ 1000));
      String digit2 = String.fromCharCode(_Zero + ((value ~/ 100).remainder(10)));
      String digit3 = String.fromCharCode(_Zero + ((value ~/ 10).remainder(10)));
      String digit4 = String.fromCharCode(_Zero + (value.remainder(10)));
      outputBuffer
        ..write(digit1)
        ..write(digit2)
        ..write(digit3)
        ..write(digit4);
      return;
    }
    if (length == 5 && value < 100000) {
      String digit1 = String.fromCharCode(_Zero + (value ~/ 10000));
      String digit2 = String.fromCharCode(_Zero + ((value ~/ 1000).remainder(10)));
      String digit3 = String.fromCharCode(_Zero + ((value ~/ 100).remainder(10)));
      String digit4 = String.fromCharCode(_Zero + ((value ~/ 10).remainder(10)));
      String digit5 = String.fromCharCode(_Zero + (value.remainder(10)));
      outputBuffer
        ..write(digit1)
        ..write(digit2)
        ..write(digit3)
        ..write(digit4)
        ..write(digit5);
      return;
    }

    // Unfortunate, but never mind - let's go the whole hog...
    var digits = List<String>.filled(_MaximumPaddingLength, '');
    int pos = _MaximumPaddingLength;
    do {
      digits[--pos] = String.fromCharCode(_Zero + (value.remainder(10)));
      value = value ~/ 10;
    } while (value != 0 && pos > 0);
    while ((_MaximumPaddingLength - pos) < length) {
      digits[--pos] = '0';
    }
    outputBuffer.writeAll(digits.getRange(pos, _MaximumPaddingLength));
  }

  /// Formats the given Int64 value left padded with zeros. The value is assumed to be non-negative.
  ///
  /// Left pads with zeros the value into a field of [length] characters. If the value
  /// is longer than [length], the entire value is formatted. If the value is negative,
  /// it is preceded by "-" but this does not count against the length.
  ///
  /// [value]: The value to format.
  /// [length]: The length to fill.
  /// [outputBuffer]: The output buffer to add the digits to.
  static void LeftPadNonNegativeInt64(int value, int length, StringBuffer outputBuffer) {
    Preconditions.DebugCheckArgumentRange('value', value, 0, Int64.MaxValue);
    Preconditions.DebugCheckArgumentRange('length', length, 1, _MaximumPaddingLength);
    // Special handling for common cases, because we really don't want a heap allocation
    // if we can help it...
    if (length == 1) {
      if (value < 10) {
        outputBuffer.write(String.fromCharCode(_Zero + value));
        return;
      }
      // Handle overflow by a single character manually
      if (value < 100) {
        String digit1 = String.fromCharCode(_Zero + (value ~/ 10));
        String digit2 = String.fromCharCode(_Zero + (value.remainder(10)));
        outputBuffer
          ..write(digit1)
          ..write(digit2);
        return;
      }
    }
    if (length == 2 && value < 100) {
      String digit1 = String.fromCharCode(_Zero + (value ~/ 10));
      String digit2 = String.fromCharCode(_Zero + (value.remainder(10)));
      outputBuffer
        ..write(digit1)
        ..write(digit2);
      return;
    }
    if (length == 3 && value < 1000) {
      String digit1 = String.fromCharCode(_Zero + ((value ~/ 100).remainder(10)));
      String digit2 = String.fromCharCode(_Zero + ((value ~/ 10).remainder(10)));
      String digit3 = String.fromCharCode(_Zero + (value.remainder(10)));
      outputBuffer
        ..write(digit1)
        ..write(digit2)
        ..write(digit3);
      return;
    }
    if (length == 4 && value < 10000) {
      String digit1 = String.fromCharCode(_Zero + (value ~/ 1000));
      String digit2 = String.fromCharCode(_Zero + ((value ~/ 100).remainder(10)));
      String digit3 = String.fromCharCode(_Zero + ((value ~/ 10).remainder(10)));
      String digit4 = String.fromCharCode(_Zero + (value.remainder(10)));
      outputBuffer
        ..write(digit1)
        ..write(digit2)
        ..write(digit3)
        ..write(digit4);
      return;
    }
    if (length == 5 && value < 100000) {
      String digit1 = String.fromCharCode(_Zero + (value ~/ 10000));
      String digit2 = String.fromCharCode(_Zero + ((value ~/ 1000).remainder(10)));
      String digit3 = String.fromCharCode(_Zero + ((value ~/ 100).remainder(10)));
      String digit4 = String.fromCharCode(_Zero + ((value ~/ 10).remainder(10)));
      String digit5 = String.fromCharCode(_Zero + (value.remainder(10)));
      outputBuffer
        ..write(digit1)
        ..write(digit2)
        ..write(digit3)
        ..write(digit4)
        ..write(digit5);
      return;
    }

    // Unfortunate, but never mind - let's go the whole hog...
    var digits = List<String>.filled(_MaximumPaddingLength, '');
    int pos = _MaximumPaddingLength;
    do {
      digits[--pos] = String.fromCharCode(_Zero + (value.remainder(10)));
      value = value ~/ 10;
    } while (value != 0 && pos > 0);
    while ((_MaximumPaddingLength - pos) < length) {
      digits[--pos] = '0';
    }
    outputBuffer.writeAll(digits.getRange(pos, _MaximumPaddingLength));
  }

  /// Formats the given value, which is an integer representation of a fraction.
  /// Note: current usage means this never has to cope with negative numbers.
  ///
  /// Example: `AppendFraction(1200, 4, 5, builder)` will result in "0120" being
  /// appended to the builder. The value is treated as effectively 0.01200 because
  /// the scale is 5, but only 4 digits are formatted.
  ///
  /// [value]: The value to format.
  /// [length]: The length to fill. Must be at most [scale].
  /// [scale]: The scale of the value i.e. the number of significant digits is the range of the value. Must be in the range [1, 7].
  /// [outputBuffer]: The output buffer to add the digits to.
  static void AppendFraction(int value, int length, int scale, StringBuffer outputBuffer) {
    int relevantDigits = value;
    while (scale > length) {
      relevantDigits = relevantDigits ~/ 10;
      scale--;
    }

    // (noda_dart: C# appends length '0's and overwrites them from the end; here that's done in a list.)
    var digits = List<String>.filled(length, '0');
    int index = length - 1;
    while (relevantDigits > 0) {
      digits[index--] = String.fromCharCode(_Zero + (relevantDigits.remainder(10)));
      relevantDigits = relevantDigits ~/ 10;
    }
    outputBuffer.writeAll(digits);
  }

  /// Formats the given value, which is an integer representation of a fraction,
  /// truncating any right-most zero digits.
  /// If the entire value is truncated then the preceding decimal separator is also removed.
  /// Note: current usage means this never has to cope with negative numbers.
  ///
  /// Example: `AppendFractionTruncate(1200, 4, 5, builder)` will result in "001" being
  /// appended to the builder. The value is treated as effectively 0.01200 because
  /// the scale is 5; only 4 digits are formatted (leaving "0120") and then the rightmost
  /// 0 digit is truncated.
  ///
  /// [value]: The value to format.
  /// [length]: The length to fill. Must be at most [scale].
  /// [scale]: The scale of the value i.e. the number of significant digits is the range of the value. Must be in the range [1, 7].
  /// [outputBuffer]: The output buffer to add the digits to.
  static void AppendFractionTruncate(int value, int length, int scale, StringBuffer outputBuffer) {
    int relevantDigits = value;
    while (scale > length) {
      relevantDigits = relevantDigits ~/ 10;
      scale--;
    }
    int relevantLength = length;
    while (relevantLength > 0) {
      if ((relevantDigits.remainder(10)) != 0) {
        break;
      }
      relevantDigits = relevantDigits ~/ 10;
      relevantLength--;
    }
    if (relevantLength > 0) {
      // (noda_dart: C# appends relevantLength '0's and overwrites them from the end; here that's done in a list.)
      var digits = List<String>.filled(relevantLength, '0');
      int index = relevantLength - 1;
      while (relevantDigits > 0) {
        digits[index--] = String.fromCharCode(_Zero + (relevantDigits.remainder(10)));
        relevantDigits = relevantDigits ~/ 10;
      }
      outputBuffer.writeAll(digits);
    } else if (outputBuffer.length > 0) {
      // (noda_dart: C#'s `outputBuffer.Length--` if the last character is '.', by rewriting the buffer.)
      String text = outputBuffer.toString();
      if (text[text.length - 1] == '.') {
        outputBuffer
          ..clear()
          ..write(text.substring(0, text.length - 1));
      }
    }
  }

  /// Formats the given value using the invariant culture, with no truncation or padding.
  ///
  /// [value]: The value to format.
  /// [outputBuffer]: The output buffer to add the digits to.
  static void FormatInvariant(int value, StringBuffer outputBuffer) {
    if (value <= 0) {
      if (value == 0) {
        outputBuffer.write('0');
        return;
      }
      if (value == Int64.MinValue) {
        outputBuffer.write('-9223372036854775808');
        return;
      }
      outputBuffer.write('-');
      FormatInvariant(-value, outputBuffer);
      return;
    }
    // Optimize common small cases (particularly for periods)
    if (value < 10) {
      outputBuffer.write(String.fromCharCode(_Zero + value));
      return;
    }
    if (value < 100) {
      String digit1 = String.fromCharCode(_Zero + (value ~/ 10));
      String digit2 = String.fromCharCode(_Zero + (value.remainder(10)));
      outputBuffer
        ..write(digit1)
        ..write(digit2);
      return;
    }
    if (value < 1000) {
      String digit1 = String.fromCharCode(_Zero + ((value ~/ 100).remainder(10)));
      String digit2 = String.fromCharCode(_Zero + ((value ~/ 10).remainder(10)));
      String digit3 = String.fromCharCode(_Zero + (value.remainder(10)));
      outputBuffer
        ..write(digit1)
        ..write(digit2)
        ..write(digit3);
      return;
    }

    var digits = List<String>.filled(_MaximumInt64Length, '');
    int pos = _MaximumInt64Length;
    do {
      digits[--pos] = String.fromCharCode(_Zero + (value.remainder(10)));
      value = value ~/ 10;
    } while (value != 0);
    outputBuffer.writeAll(digits.getRange(pos, _MaximumInt64Length));
  }
}
