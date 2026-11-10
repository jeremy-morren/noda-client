// Ported from NodaTime 6e024dde: src/NodaTime/Text/ValueCursor.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../Globalization/NodaCultureInfo.dart';
import '../Utility/Int64.dart';
import '../Utility/Preconditions.dart';
import 'ParseResult.dart';
import 'TextCursor.dart';

// noda_dart: long.MaxValue / 10, parsed as dart2js can't compile the literal.
final int _ParseInt64Limit = int.parse('922337203685477580');

/// noda_dart: C#'s `string.CompareOrdinal(strA, indexA, strB, indexB, length)`.
int _CompareOrdinal(String strA, int indexA, String strB, int indexB, int length) {
  int lengthA = math.min(length, strA.length - indexA);
  int lengthB = math.min(length, strB.length - indexB);
  int count = math.min(lengthA, lengthB);
  for (int i = 0; i < count; i++) {
    int diff = strA.codeUnitAt(indexA + i) - strB.codeUnitAt(indexB + i);
    if (diff != 0) {
      return diff;
    }
  }
  return lengthA - lengthB;
}

@internal
final class ValueCursor extends TextCursor {
  /// Initializes a new instance of the [ValueCursor] class.
  ///
  /// [value]: The string to parse.
  @internal
  ValueCursor.NewValue(super.value) : super.NewValue();

  /// Attempts to match the specified character (C#'s `Match(char)`) or string (C#'s `Match(string)`) with the current
  /// point in the string. If it matches then the index is moved past it.
  ///
  /// noda_dart: one method for both C# overloads, as a C# `char` is a [String] of length 1 here.
  ///
  /// [match]: The character or string to match.
  ///
  /// Returns `true` if the character or string matches.
  bool Match(String match) {
    if (match.length == 1) {
      // C#: Match(char character)
      if (Current == match) {
        MoveNext();
        return true;
      }
      return false;
    }
    if (_CompareOrdinal(Value, Index, match, 0, match.length) == 0) {
      Move(Index + match.length);
      return true;
    }
    return false;
  }

  /// Attempts to match the specified string with the current point in the string in a case-insensitive
  /// manner, according to the given comparison info. The cursor is optionally updated to the end of the match.
  bool MatchCaseInsensitive(String match, CompareInfo compareInfo, bool moveOnSuccess) {
    if (match.length > Value.length - Index) {
      return false;
    }
    // Note: This will fail if the length in the input string is different to the length in the
    // match string for culture-specific reasons. It's not clear how to handle that...
    // See issue 210 for details - we're not intending to fix this, but it's annoying.
    if (compareInfo.CompareSubstrings(Value, Index, match.length, match, 0, match.length, CompareOptions.IgnoreCase) ==
        0) {
      if (moveOnSuccess) {
        Move(Index + match.length);
      }
      return true;
    }
    return false;
  }

  /// Compares the value from the current cursor position with the given match. If the
  /// given match string is longer than the remaining length, the comparison still goes
  /// ahead but the result is never 0: if the result of comparing to the end of the
  /// value returns 0, the result is -1 to indicate that the value is earlier than the given match.
  /// Conversely, if the remaining value is longer than the match string, the comparison only
  /// goes as far as the end of the match. So "xabcd" with the cursor at "a" will return 0 when
  /// matched with "abc".
  ///
  /// Returns a negative number if the value (from the current cursor position) is lexicographically
  /// earlier than the given match string; 0 if they are equal (as far as the end of the match) and
  /// a positive number if the value is lexicographically later than the given match string.
  int CompareOrdinal(String match) {
    int remaining = Value.length - Index;
    if (match.length > remaining) {
      int ret = _CompareOrdinal(Value, Index, match, 0, remaining);
      return ret == 0 ? -1 : ret;
    }
    return _CompareOrdinal(Value, Index, match, 0, match.length);
  }

  /// Parses digits at the current point in the string as a signed 64-bit integer value.
  /// Currently this method only supports cultures whose negative sign is "-" (and
  /// using ASCII digits).
  ///
  /// noda_dart: the C# `out` parameter is the second element of the returned record.
  ///
  /// Returns null if the digits were parsed, or the appropriate parse failure; and the result integer value. The value
  /// of this is not guaranteed to be anything specific if the first element is non-null.
  (ParseResult<T>?, int) ParseInt64<T>() {
    // (C#: unchecked. Dart's int wraps as C#'s unchecked long does.)
    int result = 0;
    int startIndex = Index;
    bool negative = Current == '-';
    if (negative) {
      if (!MoveNext()) {
        Move(startIndex);
        return (ParseResult.EndOfString<T>(this), result);
      }
    }
    int count = 0;
    int digit;
    while (result < _ParseInt64Limit && (digit = _GetDigit()) != -1) {
      result = result * 10 + digit;
      count++;
      if (!MoveNext()) {
        break;
      }
    }

    if (count == 0) {
      Move(startIndex);
      return (ParseResult.MissingNumber<T>(this), result);
    }

    if (result >= _ParseInt64Limit && (digit = _GetDigit()) != -1) {
      if (result > _ParseInt64Limit) {
        return (_BuildNumberOutOfRangeResult<T>(startIndex), result);
      }
      if (negative && digit == 8) {
        MoveNext();
        result = Int64.MinValue;
        return (null, result);
      }
      if (digit > 7) {
        return (_BuildNumberOutOfRangeResult<T>(startIndex), result);
      }
      // We know we can cope with this digit...
      result = result * 10 + digit;
      MoveNext();
      if (_GetDigit() != -1) {
        // Too many digits. Die.
        return (_BuildNumberOutOfRangeResult<T>(startIndex), result);
      }
    }
    if (negative) {
      result = -result;
    }
    return (null, result);
  }

  ParseResult<T> _BuildNumberOutOfRangeResult<T>(int startIndex) {
    Move(startIndex);
    if (Current == '-') {
      MoveNext();
    }
    // End of string works like not finding a digit.
    while (_GetDigit() != -1) {
      MoveNext();
    }
    String badValue = Value.substring(startIndex, Index);
    Move(startIndex);
    return ParseResult.ValueOutOfRange<T>(this, badValue);
  }

  /// Parses digits at the current point in the string, as an Int64 value.
  /// If the minimum required
  /// digits are not present then the index is unchanged. If there are more digits than
  /// the maximum allowed they are ignored.
  ///
  /// noda_dart: the C# `out` parameter is the second element of the returned record.
  ///
  /// [minimumDigits]: The minimum allowed digits.
  /// [maximumDigits]: The maximum allowed digits.
  ///
  /// Returns `true` if the digits were parsed; and the result integer value. The value of this is not guaranteed
  /// to be anything specific if the first element is false.
  (bool, int) ParseInt64Digits(int minimumDigits, int maximumDigits) {
    // (C#: unchecked.)
    int result = 0;
    int localIndex = Index;
    int maxIndex = localIndex + maximumDigits;
    if (maxIndex >= Length) {
      maxIndex = Length;
    }
    for (; localIndex < maxIndex; localIndex++) {
      // Optimized digit handling: rather than checking for the range, returning -1
      // and then checking whether the result is -1, we can do both checks at once.
      int digit = Value.codeUnitAt(localIndex) - 0x30;
      if (digit < 0 || digit > 9) {
        break;
      }
      result = result * 10 + digit;
    }
    int count = localIndex - Index;
    if (count < minimumDigits) {
      return (false, result);
    }
    Move(localIndex);
    return (true, result);
  }

  /// Parses digits at the current point in the string. If the minimum required
  /// digits are not present then the index is unchanged. If there are more digits than
  /// the maximum allowed they are ignored.
  ///
  /// noda_dart: the C# `out` parameter is the second element of the returned record.
  ///
  /// [minimumDigits]: The minimum allowed digits.
  /// [maximumDigits]: The maximum allowed digits.
  ///
  /// Returns `true` if the digits were parsed; and the result integer value. The value of this is not guaranteed
  /// to be anything specific if the first element is false.
  (bool, int) ParseDigits(int minimumDigits, int maximumDigits) {
    // (C#: unchecked int arithmetic, hence toSigned(32).)
    int result = 0;
    int localIndex = Index;
    int maxIndex = localIndex + maximumDigits;
    if (maxIndex >= Length) {
      maxIndex = Length;
    }
    for (; localIndex < maxIndex; localIndex++) {
      // Optimized digit handling: rather than checking for the range, returning -1
      // and then checking whether the result is -1, we can do both checks at once.
      int digit = Value.codeUnitAt(localIndex) - 0x30;
      if (digit < 0 || digit > 9) {
        break;
      }
      result = (result * 10 + digit).toSigned(32);
    }
    int count = localIndex - Index;
    if (count < minimumDigits) {
      return (false, result);
    }
    Move(localIndex);
    return (true, result);
  }

  /// Parses digits at the current point in the string as a fractional value.
  ///
  /// noda_dart: the C# `out` parameter is the second element of the returned record.
  ///
  /// [maximumDigits]: The maximum allowed digits. Trusted to be less than or equal to scale.
  /// [scale]: The scale of the fractional value.
  /// [minimumDigits]: The minimum number of digits that must be specified in the value.
  ///
  /// Returns `true` if the digits were parsed; and the result value scaled by scale. The value of this is not
  /// guaranteed to be anything specific if the first element is false.
  (bool, int) ParseFraction(int maximumDigits, int scale, int minimumDigits) {
    // (C#: unchecked.)
    Preconditions.DebugCheckArgument(maximumDigits <= scale, 'maximumDigits',
        'Must not allow more maximum digits than scale');

    int result = 0;
    int localIndex = Index;
    int minIndex = localIndex + minimumDigits;
    if (minIndex > Length) {
      // If we don't have all the digits we're meant to have, we can't possibly succeed.
      return (false, result);
    }
    int maxIndex = math.min(localIndex + maximumDigits, Length);
    for (; localIndex < maxIndex; localIndex++) {
      // Optimized digit handling: rather than checking for the range, returning -1
      // and then checking whether the result is -1, we can do both checks at once.
      int digit = Value.codeUnitAt(localIndex) - 0x30;
      if (digit < 0 || digit > 9) {
        break;
      }
      result = result * 10 + digit;
    }
    int count = localIndex - Index;
    // Couldn't parse the minimum number of digits required?
    if (count < minimumDigits) {
      return (false, result);
    }
    result = (result * math.pow(10.0, scale - count)).truncate();
    Move(localIndex);
    return (true, result);
  }

  /// Gets the integer value of the current digit character, or -1 for "not a digit".
  ///
  /// This currently only handles ASCII digits, which is all we have to parse to stay in line with the BCL.
  int _GetDigit() {
    int c = Current.codeUnitAt(0);
    return c < 0x30 || c > 0x39 ? -1 : c - 0x30;
  }
}
