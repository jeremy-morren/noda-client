// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/ValueCursorTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: out parameters are record fields; chars are one-character strings.

import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';
import 'package:noda_dart/src/Text/ParseResult.dart';
import 'package:noda_dart/src/Text/TextCursor.dart';
import 'package:noda_dart/src/Text/UnparsableValueException.dart';
import 'package:noda_dart/src/Text/ValueCursor.dart';
import 'package:noda_dart/src/Utility/Int64.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/ValueCursorTest.generated.dart' as scenarios;
import 'TextCursorTestBase.dart';

const int _IntMaxValue = 2147483647;

void main() {
  port(scenarios.fixture, {
    ...TextCursorTestBase.Bodies(MakeCursor),

    'Match_Char': (args) {
      var value = ValueCursor.NewValue('abc');
      Assert.True(value.MoveNext(), 'GetNext() 1');
      Assert.True(value.Match('a'), 'First character');
      Assert.True(value.Match('b'), 'Second character');
      Assert.True(value.Match('c'), 'Third character');
      Assert.False(value.MoveNext(), 'GetNext() end');
    },

    'Match_String': (args) {
      var value = ValueCursor.NewValue('abc');
      Assert.True(value.MoveNext(), 'GetNext() 1');
      Assert.True(value.Match('abc'));
      Assert.False(value.MoveNext(), 'GetNext() end');
    },

    'Match_StringNotMatched': (args) {
      var value = ValueCursor.NewValue('xabcdef');
      Assert.True(value.MoveNext(), 'GetNext() 1');
      Assert.False(value.Match('abc'));
      TextCursorTestBase.ValidateCurrentCharacter(value, 0, 'x');
    },

    'Match_StringOverLongStringToMatch': (args) {
      var value = ValueCursor.NewValue('x');
      Assert.True(value.MoveNext());
      Assert.False(value.Match('long string'));
      TextCursorTestBase.ValidateCurrentCharacter(value, 0, 'x');
    },

    'MatchCaseInsensitive_MatchAndMove': (args) {
      var value = ValueCursor.NewValue('abcd');
      Assert.True(value.MoveNext(), 'GetNext() 1');
      Assert.True(value.MatchCaseInsensitive('AbC', NodaCultureInfo.InvariantCulture.CompareInfo, true));
      TextCursorTestBase.ValidateCurrentCharacter(value, 3, 'd');
    },

    'MatchCaseInsensitive_MatchWithoutMoving': (args) {
      var value = ValueCursor.NewValue('abcd');
      Assert.True(value.MoveNext(), 'GetNext() 1');
      Assert.True(value.MatchCaseInsensitive('AbC', NodaCultureInfo.InvariantCulture.CompareInfo, false));
      // We're still looking at the start
      TextCursorTestBase.ValidateCurrentCharacter(value, 0, 'a');
    },

    'MatchCaseInsensitive_StringNotMatched': (args) {
      var value = ValueCursor.NewValue('xabcdef');
      Assert.True(value.MoveNext(), 'GetNext() 1');
      Assert.False(value.MatchCaseInsensitive('abc', NodaCultureInfo.InvariantCulture.CompareInfo, true));
      TextCursorTestBase.ValidateCurrentCharacter(value, 0, 'x');
    },

    'MatchCaseInsensitive_StringOverLongStringToMatch': (args) {
      var value = ValueCursor.NewValue('x');
      Assert.True(value.MoveNext());
      Assert.False(value.MatchCaseInsensitive('long string', NodaCultureInfo.InvariantCulture.CompareInfo, true));
      TextCursorTestBase.ValidateCurrentCharacter(value, 0, 'x');
    },

    'Match_StringPartial': (args) {
      var value = ValueCursor.NewValue('abcdef');
      Assert.True(value.MoveNext(), 'GetNext() 1');
      Assert.True(value.Match('abc'));
      TextCursorTestBase.ValidateCurrentCharacter(value, 3, 'd');
    },

    'ParseDigits_TooFewDigits': (args) {
      var value = ValueCursor.NewValue('a12b');
      Assert.True(value.MoveNext());
      TextCursorTestBase.ValidateCurrentCharacter(value, 0, 'a');
      Assert.True(value.MoveNext());
      Assert.False(value.ParseDigits(3, 3).$1);
      TextCursorTestBase.ValidateCurrentCharacter(value, 1, '1');
    },

    'ParseDigits_NoNumber': (args) {
      var value = ValueCursor.NewValue('abc');
      Assert.True(value.MoveNext());
      Assert.False(value.ParseDigits(1, 2).$1);
      TextCursorTestBase.ValidateCurrentCharacter(value, 0, 'a');
    },

    'ParseDigits_Maximum': (args) {
      var value = ValueCursor.NewValue('12');
      Assert.True(value.MoveNext());
      final (bool success, int actual) = value.ParseDigits(1, 2);
      Assert.True(success);
      Assert.AreEqual(12, actual);
    },

    'ParseDigits_MaximumMoreDigits': (args) {
      var value = ValueCursor.NewValue('1234');
      Assert.True(value.MoveNext());
      final (bool success, int actual) = value.ParseDigits(1, 2);
      Assert.True(success);
      Assert.AreEqual(12, actual);
      TextCursorTestBase.ValidateCurrentCharacter(value, 2, '3');
    },

    'ParseDigits_Minimum': (args) {
      var value = ValueCursor.NewValue('1');
      value.MoveNext();
      final (bool success, int actual) = value.ParseDigits(1, 2);
      Assert.True(success);
      Assert.AreEqual(1, actual);
      TextCursorTestBase.ValidateEndOfString(value);
    },

    'ParseDigits_MinimumNonDigits': (args) {
      var value = ValueCursor.NewValue('1abc');
      Assert.True(value.MoveNext());
      final (bool success, int actual) = value.ParseDigits(1, 2);
      Assert.True(success);
      Assert.AreEqual(1, actual);
      TextCursorTestBase.ValidateCurrentCharacter(value, 1, 'a');
    },

    'ParseDigits_NonAscii_NeverMatches': (args) {
      // Arabic-Indic digits 0 and 1. See
      // https://www.unicode.org/charts/PDF/U0600.pdf
      var value = ValueCursor.NewValue('٠١');
      Assert.True(value.MoveNext());
      Assert.False(value.ParseDigits(1, 2).$1);
    },

    'ParseInt64Digits_TooFewDigits': (args) {
      var value = ValueCursor.NewValue('a12b');
      Assert.True(value.MoveNext());
      TextCursorTestBase.ValidateCurrentCharacter(value, 0, 'a');
      Assert.True(value.MoveNext());
      Assert.False(value.ParseInt64Digits(3, 3).$1);
      TextCursorTestBase.ValidateCurrentCharacter(value, 1, '1');
    },

    'ParseInt64Digits_NoNumber': (args) {
      var value = ValueCursor.NewValue('abc');
      Assert.True(value.MoveNext());
      Assert.False(value.ParseInt64Digits(1, 2).$1);
      TextCursorTestBase.ValidateCurrentCharacter(value, 0, 'a');
    },

    'ParseInt64Digits_Maximum': (args) {
      var value = ValueCursor.NewValue('12');
      Assert.True(value.MoveNext());
      final (bool success, int actual) = value.ParseInt64Digits(1, 2);
      Assert.True(success);
      Assert.AreEqual(12, actual);
    },

    'ParseInt64Digits_MaximumMoreDigits': (args) {
      var value = ValueCursor.NewValue('1234');
      Assert.True(value.MoveNext());
      final (bool success, int actual) = value.ParseInt64Digits(1, 2);
      Assert.True(success);
      Assert.AreEqual(12, actual);
      TextCursorTestBase.ValidateCurrentCharacter(value, 2, '3');
    },

    'ParseInt64Digits_Minimum': (args) {
      var value = ValueCursor.NewValue('1');
      value.MoveNext();
      final (bool success, int actual) = value.ParseInt64Digits(1, 2);
      Assert.True(success);
      Assert.AreEqual(1, actual);
      TextCursorTestBase.ValidateEndOfString(value);
    },

    'ParseInt64Digits_MinimumNonDigits': (args) {
      var value = ValueCursor.NewValue('1abc');
      Assert.True(value.MoveNext());
      final (bool success, int actual) = value.ParseInt64Digits(1, 2);
      Assert.True(success);
      Assert.AreEqual(1, actual);
      TextCursorTestBase.ValidateCurrentCharacter(value, 1, 'a');
    },

    'ParseInt64Digits_NonAscii_NeverMatches': (args) {
      // Arabic-Indic digits 0 and 1. See
      // http://www.unicode.org/charts/PDF/U0600.pdf
      var value = ValueCursor.NewValue('٠١');
      Assert.True(value.MoveNext());
      Assert.False(value.ParseInt64Digits(1, 2).$1);
    },

    'ParseInt64Digits_LargeNumber': (args) {
      var value = ValueCursor.NewValue('9999999999999');
      Assert.True(value.MoveNext());
      final (bool success, int actual) = value.ParseInt64Digits(1, 13);
      Assert.True(success);
      Assert.AreEqual(actual, 9999999999999);
      Assert.Greater(9999999999999, _IntMaxValue);
    },

    'ParseFraction_NonAscii_NeverMatches': (args) {
      // Arabic-Indic digits 0 and 1. See
      // http://www.unicode.org/charts/PDF/U0600.pdf
      var value = ValueCursor.NewValue('٠١');
      Assert.True(value.MoveNext());
      Assert.False(value.ParseFraction(2, 2, 2).$1);
    },

    'ParseInt64_Simple': (args) {
      var value = ValueCursor.NewValue('56x');
      Assert.True(value.MoveNext());
      final (ParseResult<String>? failure, int result) = value.ParseInt64<String>();
      Assert.IsNull(failure);
      Assert.AreEqual(56, result);
      // Cursor ends up post-number
      Assert.AreEqual(2, value.Index);
    },

    'ParseInt64_Negative': (args) {
      var value = ValueCursor.NewValue('-56x');
      Assert.True(value.MoveNext());
      final (ParseResult<String>? failure, int result) = value.ParseInt64<String>();
      Assert.IsNull(failure);
      Assert.AreEqual(-56, result);
    },

    'ParseInt64_NonNumber': (args) {
      var value = ValueCursor.NewValue('xyz');
      Assert.True(value.MoveNext());
      Assert.IsNotNull(value.ParseInt64<String>().$1);
      // Cursor has not moved
      Assert.AreEqual(0, value.Index);
    },

    'ParseInt64_DoubleNegativeSign': (args) {
      var value = ValueCursor.NewValue('--10xyz');
      Assert.True(value.MoveNext());
      Assert.IsNotNull(value.ParseInt64<String>().$1);
      // Cursor has not moved
      Assert.AreEqual(0, value.Index);
    },

    'ParseInt64_NegativeThenNonDigit': (args) {
      var value = ValueCursor.NewValue('-x');
      Assert.True(value.MoveNext());
      Assert.IsNotNull(value.ParseInt64<String>().$1);
      // Cursor has not moved
      Assert.AreEqual(0, value.Index);
    },

    'ParseInt64_NumberOutOfRange_LowLeadingDigits': (args) {
      var value = ValueCursor.NewValue('1000000000000000000000000');
      Assert.True(value.MoveNext());
      Assert.IsNotNull(value.ParseInt64<String>().$1);
      // Cursor has not moved
      Assert.AreEqual(0, value.Index);
    },

    'ParseInt64_NumberOutOfRange_HighLeadingDigits': (args) {
      var value = ValueCursor.NewValue('999999999999999999999999');
      Assert.True(value.MoveNext());
      Assert.IsNotNull(value.ParseInt64<String>().$1);
      // Cursor has not moved
      Assert.AreEqual(0, value.Index);
    },

    'ParseInt64_NumberOutOfRange_MaxValueLeadingDigits': (args) {
      var value = ValueCursor.NewValue('9223372036854775808');
      Assert.True(value.MoveNext());
      Assert.IsNotNull(value.ParseInt64<String>().$1);
      // Cursor has not moved
      Assert.AreEqual(0, value.Index);
    },

    'ParseInt64_NumberOutOfRange_MinValueLeadingDigits': (args) {
      var value = ValueCursor.NewValue('-9223372036854775809');
      Assert.True(value.MoveNext());
      Assert.IsNotNull(value.ParseInt64<String>().$1);
      // Cursor has not moved
      Assert.AreEqual(0, value.Index);
    },

    'ParseInt64_MaxValue': (args) {
      var value = ValueCursor.NewValue('9223372036854775807');
      Assert.True(value.MoveNext());
      final (ParseResult<String>? failure, int result) = value.ParseInt64<String>();
      Assert.IsNull(failure);
      Assert.AreEqual(Int64.MaxValue, result);
    },

    'ParseInt64_MinValue': (args) {
      var value = ValueCursor.NewValue('-9223372036854775808');
      Assert.True(value.MoveNext());
      final (ParseResult<String>? failure, int result) = value.ParseInt64<String>();
      Assert.IsNull(failure);
      Assert.AreEqual(Int64.MinValue, result);
    },

    'CompareOrdinal_ExactMatchToEndOfValue': (args) {
      var value = ValueCursor.NewValue('xabc');
      value.Move(1);
      Assert.AreEqual(0, value.CompareOrdinal('abc'));
      Assert.AreEqual(1, value.Index); // Cursor hasn't moved
    },

    'CompareOrdinal_ExactMatchValueContinues': (args) {
      var value = ValueCursor.NewValue('xabc');
      value.Move(1);
      Assert.AreEqual(0, value.CompareOrdinal('ab'));
      Assert.AreEqual(1, value.Index); // Cursor hasn't moved
    },

    'CompareOrdinal_ValueIsEarlier': (args) {
      var value = ValueCursor.NewValue('xabc');
      value.Move(1);
      Assert.Less(value.CompareOrdinal('mm'), 0);
      Assert.AreEqual(1, value.Index); // Cursor hasn't moved
    },

    'CompareOrdinal_ValueIsLater': (args) {
      var value = ValueCursor.NewValue('xabc');
      value.Move(1);
      Assert.Greater(value.CompareOrdinal('aa'), 0);
      Assert.AreEqual(1, value.Index); // Cursor hasn't moved
    },

    'CompareOrdinal_LongMatch_EqualToEnd': (args) {
      var value = ValueCursor.NewValue('xabc');
      value.Move(1);
      Assert.Less(value.CompareOrdinal('abcd'), 0);
      Assert.AreEqual(1, value.Index); // Cursor hasn't moved
    },

    'CompareOrdinal_LongMatch_ValueIsEarlier': (args) {
      var value = ValueCursor.NewValue('xabc');
      value.Move(1);
      Assert.Less(value.CompareOrdinal('cccc'), 0);
      Assert.AreEqual(1, value.Index); // Cursor hasn't moved
    },

    'CompareOrdinal_LongMatch_ValueIsLater': (args) {
      var value = ValueCursor.NewValue('xabc');
      value.Move(1);
      Assert.Greater(value.CompareOrdinal('aaaa'), 0);
      Assert.AreEqual(1, value.Index); // Cursor hasn't moved
    },

    'ParseInt64_TooManyDigits': (args) {
      // We can cope as far as 9223372036854775807, but the trailing 1 causes a failure.
      var value = ValueCursor.NewValue('92233720368547758071');
      value.Move(0);
      var (parseResult, _) = value.ParseInt64<String>();
      Assert.IsFalse(parseResult!.Success);
      Assert.IsInstanceOf<UnparsableValueException>(parseResult.Exception);
      Assert.AreEqual(0, value.Index); // Cursor hasn't moved
      Assert.AreEqual('92233720368547758071', (parseResult.Exception as UnparsableValueException).Value);
      Assert.AreEqual(0, (parseResult.Exception as UnparsableValueException).Index);
    },
  }, skip: {
    // On dart2js, long.MaxValue and long.MinValue aren't exact, so ParseInt64 can't parse them.
    if (isDart2js) 'ParseInt64_MaxValue': SkipReasons.Dart2jsInt,
    if (isDart2js) 'ParseInt64_MinValue': SkipReasons.Dart2jsInt,
  });
}

TextCursor MakeCursor(String value) {
  return ValueCursor.NewValue(value);
}
