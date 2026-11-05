// Ported from NodaTime 3.3.0: src/NodaTime.Test/Text/ValueCursorTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: C# out parameters are the second element of the returned tuples. ParseInt64's result is an
// Int64Value (exact beyond 2^53), compared as a decimal string.

import { expect } from "vitest";
import { NodaCultureInfo, Int64, UnparsableValueError, ValueCursor } from "../../../src/noda-js/internal.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/ValueCursorTest.generated.ts";
import { textCursorTestBaseBodies, validateCurrentCharacter, validateEndOfString } from "./TextCursorTestBase.ts";

/** typeof(string), the type argument of C#'s ParseInt64<string>. */
const StringTypeName = "System.String";

port(fixture, {
  // MakeCursor
  ...textCursorTestBaseBodies(value => new ValueCursor(value)),

  Match_Char() {
    const value = new ValueCursor("abc");
    expect(value.MoveNext(), "GetNext() 1").toBe(true);
    expect(value.Match("a"), "First character").toBe(true);
    expect(value.Match("b"), "Second character").toBe(true);
    expect(value.Match("c"), "Third character").toBe(true);
    expect(value.MoveNext(), "GetNext() end").toBe(false);
  },

  Match_String() {
    const value = new ValueCursor("abc");
    expect(value.MoveNext(), "GetNext() 1").toBe(true);
    expect(value.Match("abc")).toBe(true);
    expect(value.MoveNext(), "GetNext() end").toBe(false);
  },

  Match_StringNotMatched() {
    const value = new ValueCursor("xabcdef");
    expect(value.MoveNext(), "GetNext() 1").toBe(true);
    expect(value.Match("abc")).toBe(false);
    validateCurrentCharacter(value, 0, "x");
  },

  Match_StringOverLongStringToMatch() {
    const value = new ValueCursor("x");
    expect(value.MoveNext()).toBe(true);
    expect(value.Match("long string")).toBe(false);
    validateCurrentCharacter(value, 0, "x");
  },

  MatchCaseInsensitive_MatchAndMove() {
    const value = new ValueCursor("abcd");
    expect(value.MoveNext(), "GetNext() 1").toBe(true);
    expect(value.MatchCaseInsensitive("AbC", NodaCultureInfo.InvariantCulture.CompareInfo, true)).toBe(true);
    validateCurrentCharacter(value, 3, "d");
  },

  MatchCaseInsensitive_MatchWithoutMoving() {
    const value = new ValueCursor("abcd");
    expect(value.MoveNext(), "GetNext() 1").toBe(true);
    expect(value.MatchCaseInsensitive("AbC", NodaCultureInfo.InvariantCulture.CompareInfo, false)).toBe(true);
    // We're still looking at the start
    validateCurrentCharacter(value, 0, "a");
  },

  MatchCaseInsensitive_StringNotMatched() {
    const value = new ValueCursor("xabcdef");
    expect(value.MoveNext(), "GetNext() 1").toBe(true);
    expect(value.MatchCaseInsensitive("abc", NodaCultureInfo.InvariantCulture.CompareInfo, true)).toBe(false);
    validateCurrentCharacter(value, 0, "x");
  },

  MatchCaseInsensitive_StringOverLongStringToMatch() {
    const value = new ValueCursor("x");
    expect(value.MoveNext()).toBe(true);
    expect(value.MatchCaseInsensitive("long string", NodaCultureInfo.InvariantCulture.CompareInfo, true)).toBe(false);
    validateCurrentCharacter(value, 0, "x");
  },

  Match_StringPartial() {
    const value = new ValueCursor("abcdef");
    expect(value.MoveNext(), "GetNext() 1").toBe(true);
    expect(value.Match("abc")).toBe(true);
    validateCurrentCharacter(value, 3, "d");
  },

  ParseDigits_TooFewDigits() {
    const value = new ValueCursor("a12b");
    expect(value.MoveNext()).toBe(true);
    validateCurrentCharacter(value, 0, "a");
    expect(value.MoveNext()).toBe(true);
    expect(value.ParseDigits(3, 3)[0]).toBe(false);
    validateCurrentCharacter(value, 1, "1");
  },

  ParseDigits_NoNumber() {
    const value = new ValueCursor("abc");
    expect(value.MoveNext()).toBe(true);
    expect(value.ParseDigits(1, 2)[0]).toBe(false);
    validateCurrentCharacter(value, 0, "a");
  },

  ParseDigits_Maximum() {
    const value = new ValueCursor("12");
    expect(value.MoveNext()).toBe(true);
    const [success, actual] = value.ParseDigits(1, 2);
    expect(success).toBe(true);
    expect(actual).toBe(12);
  },

  ParseDigits_MaximumMoreDigits() {
    const value = new ValueCursor("1234");
    expect(value.MoveNext()).toBe(true);
    const [success, actual] = value.ParseDigits(1, 2);
    expect(success).toBe(true);
    expect(actual).toBe(12);
    validateCurrentCharacter(value, 2, "3");
  },

  ParseDigits_Minimum() {
    const value = new ValueCursor("1");
    value.MoveNext();
    const [success, actual] = value.ParseDigits(1, 2);
    expect(success).toBe(true);
    expect(actual).toBe(1);
    validateEndOfString(value);
  },

  ParseDigits_MinimumNonDigits() {
    const value = new ValueCursor("1abc");
    expect(value.MoveNext()).toBe(true);
    const [success, actual] = value.ParseDigits(1, 2);
    expect(success).toBe(true);
    expect(actual).toBe(1);
    validateCurrentCharacter(value, 1, "a");
  },

  ParseDigits_NonAscii_NeverMatches() {
    // Arabic-Indic digits 0 and 1. See
    // https://www.unicode.org/charts/PDF/U0600.pdf
    const value = new ValueCursor("٠١");
    expect(value.MoveNext()).toBe(true);
    expect(value.ParseDigits(1, 2)[0]).toBe(false);
  },

  ParseInt64Digits_TooFewDigits() {
    const value = new ValueCursor("a12b");
    expect(value.MoveNext()).toBe(true);
    validateCurrentCharacter(value, 0, "a");
    expect(value.MoveNext()).toBe(true);
    expect(value.ParseInt64Digits(3, 3)[0]).toBe(false);
    validateCurrentCharacter(value, 1, "1");
  },

  ParseInt64Digits_NoNumber() {
    const value = new ValueCursor("abc");
    expect(value.MoveNext()).toBe(true);
    expect(value.ParseInt64Digits(1, 2)[0]).toBe(false);
    validateCurrentCharacter(value, 0, "a");
  },

  ParseInt64Digits_Maximum() {
    const value = new ValueCursor("12");
    expect(value.MoveNext()).toBe(true);
    const [success, actual] = value.ParseInt64Digits(1, 2);
    expect(success).toBe(true);
    expect(actual).toBe(12);
  },

  ParseInt64Digits_MaximumMoreDigits() {
    const value = new ValueCursor("1234");
    expect(value.MoveNext()).toBe(true);
    const [success, actual] = value.ParseInt64Digits(1, 2);
    expect(success).toBe(true);
    expect(actual).toBe(12);
    validateCurrentCharacter(value, 2, "3");
  },

  ParseInt64Digits_Minimum() {
    const value = new ValueCursor("1");
    value.MoveNext();
    const [success, actual] = value.ParseInt64Digits(1, 2);
    expect(success).toBe(true);
    expect(actual).toBe(1);
    validateEndOfString(value);
  },

  ParseInt64Digits_MinimumNonDigits() {
    const value = new ValueCursor("1abc");
    expect(value.MoveNext()).toBe(true);
    const [success, actual] = value.ParseInt64Digits(1, 2);
    expect(success).toBe(true);
    expect(actual).toBe(1);
    validateCurrentCharacter(value, 1, "a");
  },

  ParseInt64Digits_NonAscii_NeverMatches() {
    // Arabic-Indic digits 0 and 1. See
    // http://www.unicode.org/charts/PDF/U0600.pdf
    const value = new ValueCursor("٠١");
    expect(value.MoveNext()).toBe(true);
    expect(value.ParseInt64Digits(1, 2)[0]).toBe(false);
  },

  ParseInt64Digits_LargeNumber() {
    const value = new ValueCursor("9999999999999");
    expect(value.MoveNext()).toBe(true);
    const [success, actual] = value.ParseInt64Digits(1, 13);
    expect(success).toBe(true);
    expect(actual).toBe(9999999999999);
    expect(9999999999999).toBeGreaterThan(2147483647);
  },

  ParseFraction_NonAscii_NeverMatches() {
    // Arabic-Indic digits 0 and 1. See
    // http://www.unicode.org/charts/PDF/U0600.pdf
    const value = new ValueCursor("٠١");
    expect(value.MoveNext()).toBe(true);
    expect(value.ParseFraction(2, 2, 2)[0]).toBe(false);
  },

  ParseInt64_Simple() {
    const value = new ValueCursor("56x");
    expect(value.MoveNext()).toBe(true);
    const [failure, result] = value.ParseInt64<string>(StringTypeName);
    expect(failure).toBeNull();
    expect(Int64.ToString(result)).toBe("56");
    // Cursor ends up post-number
    expect(value.Index).toBe(2);
  },

  ParseInt64_Negative() {
    const value = new ValueCursor("-56x");
    expect(value.MoveNext()).toBe(true);
    const [failure, result] = value.ParseInt64<string>(StringTypeName);
    expect(failure).toBeNull();
    expect(Int64.ToString(result)).toBe("-56");
  },

  ParseInt64_NonNumber() {
    const value = new ValueCursor("xyz");
    expect(value.MoveNext()).toBe(true);
    expect(value.ParseInt64<string>(StringTypeName)[0]).not.toBeNull();
    // Cursor has not moved
    expect(value.Index).toBe(0);
  },

  ParseInt64_DoubleNegativeSign() {
    const value = new ValueCursor("--10xyz");
    expect(value.MoveNext()).toBe(true);
    expect(value.ParseInt64<string>(StringTypeName)[0]).not.toBeNull();
    // Cursor has not moved
    expect(value.Index).toBe(0);
  },

  ParseInt64_NegativeThenNonDigit() {
    const value = new ValueCursor("-x");
    expect(value.MoveNext()).toBe(true);
    expect(value.ParseInt64<string>(StringTypeName)[0]).not.toBeNull();
    // Cursor has not moved
    expect(value.Index).toBe(0);
  },

  ParseInt64_NumberOutOfRange_LowLeadingDigits() {
    const value = new ValueCursor("1000000000000000000000000");
    expect(value.MoveNext()).toBe(true);
    expect(value.ParseInt64<string>(StringTypeName)[0]).not.toBeNull();
    // Cursor has not moved
    expect(value.Index).toBe(0);
  },

  ParseInt64_NumberOutOfRange_HighLeadingDigits() {
    const value = new ValueCursor("999999999999999999999999");
    expect(value.MoveNext()).toBe(true);
    expect(value.ParseInt64<string>(StringTypeName)[0]).not.toBeNull();
    // Cursor has not moved
    expect(value.Index).toBe(0);
  },

  ParseInt64_NumberOutOfRange_MaxValueLeadingDigits() {
    const value = new ValueCursor("9223372036854775808");
    expect(value.MoveNext()).toBe(true);
    expect(value.ParseInt64<string>(StringTypeName)[0]).not.toBeNull();
    // Cursor has not moved
    expect(value.Index).toBe(0);
  },

  ParseInt64_NumberOutOfRange_MinValueLeadingDigits() {
    const value = new ValueCursor("-9223372036854775809");
    expect(value.MoveNext()).toBe(true);
    expect(value.ParseInt64<string>(StringTypeName)[0]).not.toBeNull();
    // Cursor has not moved
    expect(value.Index).toBe(0);
  },

  ParseInt64_MaxValue() {
    const value = new ValueCursor("9223372036854775807");
    expect(value.MoveNext()).toBe(true);
    const [failure, result] = value.ParseInt64<string>(StringTypeName);
    expect(failure).toBeNull();
    expect(Int64.ToString(result)).toBe("9223372036854775807");
  },

  ParseInt64_MinValue() {
    const value = new ValueCursor("-9223372036854775808");
    expect(value.MoveNext()).toBe(true);
    const [failure, result] = value.ParseInt64<string>(StringTypeName);
    expect(failure).toBeNull();
    expect(Int64.ToString(result)).toBe("-9223372036854775808");
  },

  CompareOrdinal_ExactMatchToEndOfValue() {
    const value = new ValueCursor("xabc");
    value.Move(1);
    expect(value.CompareOrdinal("abc")).toBe(0);
    expect(value.Index).toBe(1); // Cursor hasn't moved
  },

  CompareOrdinal_ExactMatchValueContinues() {
    const value = new ValueCursor("xabc");
    value.Move(1);
    expect(value.CompareOrdinal("ab")).toBe(0);
    expect(value.Index).toBe(1); // Cursor hasn't moved
  },

  CompareOrdinal_ValueIsEarlier() {
    const value = new ValueCursor("xabc");
    value.Move(1);
    expect(value.CompareOrdinal("mm")).toBeLessThan(0);
    expect(value.Index).toBe(1); // Cursor hasn't moved
  },

  CompareOrdinal_ValueIsLater() {
    const value = new ValueCursor("xabc");
    value.Move(1);
    expect(value.CompareOrdinal("aa")).toBeGreaterThan(0);
    expect(value.Index).toBe(1); // Cursor hasn't moved
  },

  CompareOrdinal_LongMatch_EqualToEnd() {
    const value = new ValueCursor("xabc");
    value.Move(1);
    expect(value.CompareOrdinal("abcd")).toBeLessThan(0);
    expect(value.Index).toBe(1); // Cursor hasn't moved
  },

  CompareOrdinal_LongMatch_ValueIsEarlier() {
    const value = new ValueCursor("xabc");
    value.Move(1);
    expect(value.CompareOrdinal("cccc")).toBeLessThan(0);
    expect(value.Index).toBe(1); // Cursor hasn't moved
  },

  CompareOrdinal_LongMatch_ValueIsLater() {
    const value = new ValueCursor("xabc");
    value.Move(1);
    expect(value.CompareOrdinal("aaaa")).toBeGreaterThan(0);
    expect(value.Index).toBe(1); // Cursor hasn't moved
  },

  ParseInt64_TooManyDigits() {
    // We can cope as far as 9223372036854775807, but the trailing 1 causes a failure.
    const value = new ValueCursor("92233720368547758071");
    value.Move(0);
    const [parseResult] = value.ParseInt64<string>(StringTypeName);
    expect(parseResult!.Success).toBe(false);
    expect(parseResult!.Exception).toBeInstanceOf(UnparsableValueError);
    expect(value.Index).toBe(0); // Cursor hasn't moved
    expect((parseResult!.Exception as UnparsableValueError).Value).toBe("92233720368547758071");
    expect((parseResult!.Exception as UnparsableValueError).Index).toBe(0);
  },
});
