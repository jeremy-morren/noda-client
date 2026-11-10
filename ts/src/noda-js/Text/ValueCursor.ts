// Ported from NodaTime 3.3.7: src/NodaTime/Text/ValueCursor.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { CompareOptions, Int64, Long, ParseResult, Preconditions, TextCursor } from "../internal.ts";
import type { CompareInfo, Int64Value } from "../internal.ts";

let parseInt64LimitValue: Long | undefined;

/** long.MaxValue / 10 (922337203685477580), the largest value ParseInt64 can multiply by 10 and add any digit to. */
function ParseInt64Limit(): Long {
  return (parseInt64LimitValue ??= Long.fromString("922337203685477580"));
}

/** C#'s string.CompareOrdinal(strA, indexA, strB, indexB, length). */
function CompareOrdinal(strA: string, indexA: number, strB: string, indexB: number, length: number): number {
  const lengthA = Math.min(length, strA.length - indexA);
  const lengthB = Math.min(length, strB.length - indexB);
  const count = Math.min(lengthA, lengthB);
  for (let i = 0; i < count; i++) {
    const diff = strA.charCodeAt(indexA + i) - strB.charCodeAt(indexB + i);
    if (diff !== 0) {
      return diff;
    }
  }
  return lengthA - lengthB;
}

/** @internal */
export class ValueCursor extends TextCursor {
  /**
   * Initializes a new instance of the {@link ValueCursor} class.
   * @param value The string to parse.
   */
  constructor(value: string) {
    super(value);
  }

  /**
   * Initializes a new instance of the {@link ValueCursor} class.
   * @param value The string to parse.
   * @internal
   */
  static NewValue(value: string): ValueCursor {
    return new ValueCursor(value);
  }

  /**
   * Attempts to match the specified string with the current point in the string. If the
   * character matches then the index is moved past the string.
   * (noda-js: this also covers the C# Match(char) overload: a char is a string of length 1.)
   * @param match The string to match.
   * @returns `true` if the string matches.
   */
  Match(match: string): boolean {
    if (match.length === 1) {
      // C#: Match(char character)
      if (this.Current === match) {
        this.MoveNext();
        return true;
      }
      return false;
    }
    if (CompareOrdinal(this.Value, this.Index, match, 0, match.length) === 0) {
      this.Move(this.Index + match.length);
      return true;
    }
    return false;
  }

  /**
   * Attempts to match the specified string with the current point in the string in a case-insensitive
   * manner, according to the given comparison info. The cursor is optionally updated to the end of the match.
   */
  MatchCaseInsensitive(match: string, compareInfo: CompareInfo, moveOnSuccess: boolean): boolean {
    if (match.length > this.Value.length - this.Index) {
      return false;
    }
    // Note: This will fail if the length in the input string is different to the length in the
    // match string for culture-specific reasons. It's not clear how to handle that...
    // See issue 210 for details - we're not intending to fix this, but it's annoying.
    if (compareInfo.Compare(this.Value, this.Index, match.length, match, 0, match.length, CompareOptions.IgnoreCase) === 0) {
      if (moveOnSuccess) {
        this.Move(this.Index + match.length);
      }
      return true;
    }
    return false;
  }

  /**
   * Compares the value from the current cursor position with the given match. If the
   * given match string is longer than the remaining length, the comparison still goes
   * ahead but the result is never 0: if the result of comparing to the end of the
   * value returns 0, the result is -1 to indicate that the value is earlier than the given match.
   * Conversely, if the remaining value is longer than the match string, the comparison only
   * goes as far as the end of the match. So "xabcd" with the cursor at "a" will return 0 when
   * matched with "abc".
   * @returns A negative number if the value (from the current cursor position) is lexicographically
   * earlier than the given match string; 0 if they are equal (as far as the end of the match) and
   * a positive number if the value is lexicographically later than the given match string.
   */
  CompareOrdinal(match: string): number {
    const remaining = this.Value.length - this.Index;
    if (match.length > remaining) {
      const ret = CompareOrdinal(this.Value, this.Index, match, 0, remaining);
      return ret === 0 ? -1 : ret;
    }
    return CompareOrdinal(this.Value, this.Index, match, 0, match.length);
  }

  /**
   * Parses digits at the current point in the string as a signed 64-bit integer value.
   * Currently this method only supports cultures whose negative sign is "-" (and
   * using ASCII digits).
   * (noda-js: the C# out parameter, an exact Int64Value, is the second element of the returned tuple.)
   * @param typeName noda-js: the name of the C# type argument T, used in error messages (e.g. "NodaTime.Period").
   * @returns null if the digits were parsed, or the appropriate parse failure; and the result integer value.
   * The value of this is not guaranteed to be anything specific if the first element is non-null.
   */
  ParseInt64<T>(typeName: string): [failure: ParseResult<T> | null, result: Int64Value] {
    // noda-js: the value is accumulated in a number while that's exact (up to 15 digits), then in a Long.
    let smallResult = 0;
    let result: Long | null = null;
    const startIndex = this.Index;
    const negative = this.Current === "-";
    if (negative) {
      if (!this.MoveNext()) {
        this.Move(startIndex);
        return [ParseResult.EndOfString<T>(this), 0];
      }
    }
    const limit = ParseInt64Limit();
    let count = 0;
    let digit: number;
    while ((result === null || result.lt(limit)) && (digit = this.GetDigit()) !== -1) {
      if (result === null) {
        smallResult = smallResult * 10 + digit;
        if (smallResult >= 100000000000000) {
          result = Long.fromNumber(smallResult);
        }
      } else {
        result = result.mul(10).add(digit);
      }
      count++;
      if (!this.MoveNext()) {
        break;
      }
    }

    if (count === 0) {
      this.Move(startIndex);
      return [ParseResult.MissingNumber<T>(this), 0];
    }

    if (result !== null && result.gte(limit) && (digit = this.GetDigit()) !== -1) {
      if (result.gt(limit)) {
        return [this.BuildNumberOutOfRangeResult<T>(startIndex, typeName), 0];
      }
      if (negative && digit === 8) {
        this.MoveNext();
        return [null, Long.MIN_VALUE];
      }
      if (digit > 7) {
        return [this.BuildNumberOutOfRangeResult<T>(startIndex, typeName), 0];
      }
      // We know we can cope with this digit...
      result = result.mul(10).add(digit);
      this.MoveNext();
      if (this.GetDigit() !== -1) {
        // Too many digits. Die.
        return [this.BuildNumberOutOfRangeResult<T>(startIndex, typeName), 0];
      }
    }
    if (result === null) {
      return [null, negative ? 0 - smallResult : smallResult];
    }
    return [null, Int64.Compact(negative ? result.neg() : result)];
  }

  private BuildNumberOutOfRangeResult<T>(startIndex: number, typeName: string): ParseResult<T> {
    this.Move(startIndex);
    if (this.Current === "-") {
      this.MoveNext();
    }
    // End of string works like not finding a digit.
    while (this.GetDigit() !== -1) {
      this.MoveNext();
    }
    const badValue = this.Value.substring(startIndex, this.Index);
    this.Move(startIndex);
    return ParseResult.ValueOutOfRange<T>(this, badValue, typeName);
  }

  /**
   * Parses digits at the current point in the string, as an Int64 value.
   * If the minimum required
   * digits are not present then the index is unchanged. If there are more digits than
   * the maximum allowed they are ignored.
   * (noda-js: the C# out parameter is the second element of the returned tuple.)
   * @param minimumDigits The minimum allowed digits.
   * @param maximumDigits The maximum allowed digits.
   * @returns `true` if the digits were parsed; and the result integer value. The value of this is not
   * guaranteed to be anything specific if the first element is false.
   */
  ParseInt64Digits(minimumDigits: number, maximumDigits: number): [success: boolean, result: number] {
    let result = 0;
    let localIndex = this.Index;
    let maxIndex = localIndex + maximumDigits;
    if (maxIndex >= this.Length) {
      maxIndex = this.Length;
    }
    for (; localIndex < maxIndex; localIndex++) {
      // Optimized digit handling: rather than checking for the range, returning -1
      // and then checking whether the result is -1, we can do both checks at once.
      const digit = this.Value.charCodeAt(localIndex) - 48;
      if (digit < 0 || digit > 9) {
        break;
      }
      result = result * 10 + digit;
    }
    const count = localIndex - this.Index;
    if (count < minimumDigits) {
      return [false, result];
    }
    this.Move(localIndex);
    return [true, result];
  }

  /**
   * Parses digits at the current point in the string. If the minimum required
   * digits are not present then the index is unchanged. If there are more digits than
   * the maximum allowed they are ignored.
   * (noda-js: the C# out parameter is the second element of the returned tuple.)
   * @param minimumDigits The minimum allowed digits.
   * @param maximumDigits The maximum allowed digits.
   * @returns `true` if the digits were parsed; and the result integer value. The value of this is not
   * guaranteed to be anything specific if the first element is false.
   */
  ParseDigits(minimumDigits: number, maximumDigits: number): [success: boolean, result: number] {
    let result = 0;
    let localIndex = this.Index;
    let maxIndex = localIndex + maximumDigits;
    if (maxIndex >= this.Length) {
      maxIndex = this.Length;
    }
    for (; localIndex < maxIndex; localIndex++) {
      // Optimized digit handling: rather than checking for the range, returning -1
      // and then checking whether the result is -1, we can do both checks at once.
      const digit = this.Value.charCodeAt(localIndex) - 48;
      if (digit < 0 || digit > 9) {
        break;
      }
      // noda-js: unchecked int arithmetic, as in the C#.
      result = (result * 10 + digit) | 0;
    }
    const count = localIndex - this.Index;
    if (count < minimumDigits) {
      return [false, result];
    }
    this.Move(localIndex);
    return [true, result];
  }

  /**
   * Parses digits at the current point in the string as a fractional value.
   * (noda-js: the C# out parameter is the second element of the returned tuple.)
   * @param maximumDigits The maximum allowed digits. Trusted to be less than or equal to scale.
   * @param scale The scale of the fractional value.
   * @param minimumDigits The minimum number of digits that must be specified in the value.
   * @returns `true` if the digits were parsed; and the result value scaled by scale. The value of this is
   * not guaranteed to be anything specific if the first element is false.
   */
  ParseFraction(maximumDigits: number, scale: number, minimumDigits: number): [success: boolean, result: number] {
    Preconditions.DebugCheckArgument(maximumDigits <= scale, "maximumDigits", "Must not allow more maximum digits than scale");

    let result = 0;
    let localIndex = this.Index;
    const minIndex = localIndex + minimumDigits;
    if (minIndex > this.Length) {
      // If we don't have all the digits we're meant to have, we can't possibly succeed.
      return [false, result];
    }
    const maxIndex = Math.min(localIndex + maximumDigits, this.Length);
    for (; localIndex < maxIndex; localIndex++) {
      // Optimized digit handling: rather than checking for the range, returning -1
      // and then checking whether the result is -1, we can do both checks at once.
      const digit = this.Value.charCodeAt(localIndex) - 48;
      if (digit < 0 || digit > 9) {
        break;
      }
      result = result * 10 + digit;
    }
    const count = localIndex - this.Index;
    // Couldn't parse the minimum number of digits required?
    if (count < minimumDigits) {
      return [false, result];
    }
    result = Math.trunc(result * Math.pow(10.0, scale - count));
    this.Move(localIndex);
    return [true, result];
  }

  /**
   * Gets the integer value of the current digit character, or -1 for "not a digit".
   *
   * This currently only handles ASCII digits, which is all we have to parse to stay in line with the BCL.
   */
  private GetDigit(): number {
    const c = this.Current.charCodeAt(0);
    return c < 48 || c > 57 ? -1 : c - 48;
  }
}
