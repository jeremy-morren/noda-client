// Ported from NodaTime 3.3.7: src/NodaTime/Text/FormatHelper.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Int64, Preconditions, PadStart } from "../internal.ts";
import type { Int64Value, StringBuilder } from "../internal.ts";

// noda-js: NodaTime avoids heap allocations here with hand-unrolled digit arithmetic for small values.
// In JavaScript the number-to-string conversion is both simpler and faster, so those fast paths are
// replaced by String(value) where the result is identical.

/** The maximum number of characters allowed for padded values. */
const MaximumPaddingLength = 16;

/** Returns the digit character for a value in the range [0, 9]. */
function DigitChar(value: number): string {
  return String.fromCharCode(48 + value);
}

/**
 * Provides helper methods for formatting values using pattern strings.
 * @internal
 */
export class FormatHelper {
  private constructor() {}

  /**
   * Formats the given value to two digits, left-padding with '0' if necessary.
   * It is assumed that the value is in the range [0, 100). This is usually
   * used for month, day-of-month, hour, minute, second and year-of-century values.
   */
  static Format2DigitsNonNegative(value: number, outputBuffer: StringBuilder): void {
    Preconditions.DebugCheckArgumentRange("value", value, 0, 99);
    outputBuffer.Append(DigitChar(Math.trunc(value / 10)));
    outputBuffer.Append(DigitChar(value % 10));
  }

  /**
   * Formats the given value to two digits, left-padding with '0' if necessary.
   * It is assumed that the value is in the range [-9999, 10000). This is usually
   * used for year values. If the value is negative, a '-' character is prepended.
   */
  static Format4DigitsValueFits(value: number, outputBuffer: StringBuilder): void {
    Preconditions.DebugCheckArgumentRange("value", value, -9999, 10000);
    if (value < 0) {
      value = -value;
      outputBuffer.Append("-");
    }
    outputBuffer.Append(DigitChar(Math.trunc(value / 1000)));
    outputBuffer.Append(DigitChar(Math.trunc(value / 100) % 10));
    outputBuffer.Append(DigitChar(Math.trunc(value / 10) % 10));
    outputBuffer.Append(DigitChar(value % 10));
  }

  /**
   * Formats the given value left padded with zeros.
   *
   * Left pads with zeros the value into a field of `length` characters. If the value
   * is longer than `length`, the entire value is formatted. If the value is negative,
   * it is preceded by "-" but this does not count against the length.
   * @param value The value to format.
   * @param length The length to fill.
   * @param outputBuffer The output buffer to add the digits to.
   */
  static LeftPad(value: number, length: number, outputBuffer: StringBuilder): void {
    Preconditions.DebugCheckArgumentRange("length", length, 1, MaximumPaddingLength);
    if (value >= 0) {
      FormatHelper.LeftPadNonNegative(value, length, outputBuffer);
      return;
    }
    outputBuffer.Append("-");
    // (noda-js: no special case is needed for int.MinValue, as -value can't overflow.)
    FormatHelper.LeftPadNonNegative(-value, length, outputBuffer);
  }

  /**
   * Formats the given value left padded with zeros. The value is assumed to be non-negative.
   *
   * Left pads with zeros the value into a field of `length` characters. If the value
   * is longer than `length`, the entire value is formatted. If the value is negative,
   * it is preceded by "-" but this does not count against the length.
   * @param value The value to format.
   * @param length The length to fill.
   * @param outputBuffer The output buffer to add the digits to.
   */
  static LeftPadNonNegative(value: number, length: number, outputBuffer: StringBuilder): void {
    Preconditions.DebugCheckArgumentRange("value", value, 0, 2147483647);
    Preconditions.DebugCheckArgumentRange("length", length, 1, MaximumPaddingLength);
    outputBuffer.Append(PadStart(String(value), length, "0"));
  }

  /**
   * Formats the given Int64 value left padded with zeros. The value is assumed to be non-negative.
   *
   * Left pads with zeros the value into a field of `length` characters. If the value
   * is longer than `length`, the entire value is formatted. If the value is negative,
   * it is preceded by "-" but this does not count against the length.
   * @param value The value to format.
   * @param length The length to fill.
   * @param outputBuffer The output buffer to add the digits to.
   */
  static LeftPadNonNegativeInt64(value: Int64Value, length: number, outputBuffer: StringBuilder): void {
    Preconditions.DebugCheckArgumentRange("value", value, 0, Int64.MaxValue);
    Preconditions.DebugCheckArgumentRange("length", length, 1, MaximumPaddingLength);
    outputBuffer.Append(PadStart(Int64.ToString(value), length, "0"));
  }

  /**
   * Formats the given value, which is an integer representation of a fraction.
   * Note: current usage means this never has to cope with negative numbers.
   *
   * Example: `AppendFraction(1200, 4, 5, builder)` will result in "0120" being
   * appended to the builder. The value is treated as effectively 0.01200 because
   * the scale is 5, but only 4 digits are formatted.
   * @param value The value to format.
   * @param length The length to fill. Must be at most `scale`.
   * @param scale The scale of the value i.e. the number of significant digits is the range of the value. Must be in the range [1, 7].
   * @param outputBuffer The output buffer to add the digits to.
   */
  static AppendFraction(value: number, length: number, scale: number, outputBuffer: StringBuilder): void {
    let relevantDigits = value;
    while (scale > length) {
      relevantDigits = Math.trunc(relevantDigits / 10);
      scale--;
    }

    outputBuffer.Append("0", length);
    let index = outputBuffer.Length - 1;
    while (relevantDigits > 0) {
      outputBuffer.SetCharAt(index--, DigitChar(relevantDigits % 10));
      relevantDigits = Math.trunc(relevantDigits / 10);
    }
  }

  /**
   * Formats the given value, which is an integer representation of a fraction,
   * truncating any right-most zero digits.
   * If the entire value is truncated then the preceding decimal separator is also removed.
   * Note: current usage means this never has to cope with negative numbers.
   *
   * Example: `AppendFractionTruncate(1200, 4, 5, builder)` will result in "001" being
   * appended to the builder. The value is treated as effectively 0.01200 because
   * the scale is 5; only 4 digits are formatted (leaving "0120") and then the rightmost
   * 0 digit is truncated.
   * @param value The value to format.
   * @param length The length to fill. Must be at most `scale`.
   * @param scale The scale of the value i.e. the number of significant digits is the range of the value. Must be in the range [1, 7].
   * @param outputBuffer The output buffer to add the digits to.
   */
  static AppendFractionTruncate(value: number, length: number, scale: number, outputBuffer: StringBuilder): void {
    let relevantDigits = value;
    while (scale > length) {
      relevantDigits = Math.trunc(relevantDigits / 10);
      scale--;
    }
    let relevantLength = length;
    while (relevantLength > 0) {
      if (relevantDigits % 10 !== 0) {
        break;
      }
      relevantDigits = Math.trunc(relevantDigits / 10);
      relevantLength--;
    }
    if (relevantLength > 0) {
      outputBuffer.Append("0", relevantLength);
      let index = outputBuffer.Length - 1;
      while (relevantDigits > 0) {
        outputBuffer.SetCharAt(index--, DigitChar(relevantDigits % 10));
        relevantDigits = Math.trunc(relevantDigits / 10);
      }
    } else if (outputBuffer.Length > 0 && outputBuffer.CharAt(outputBuffer.Length - 1) === ".") {
      outputBuffer.Length--;
    }
  }

  /**
   * Formats the given value using the invariant culture, with no truncation or padding.
   * @param value The value to format.
   * @param outputBuffer The output buffer to add the digits to.
   */
  static FormatInvariant(value: Int64Value, outputBuffer: StringBuilder): void {
    // (noda-js: String() of a safe integer, and Long.toString(), are exactly the invariant format, including long.MinValue.)
    outputBuffer.Append(Int64.ToString(value));
  }
}
