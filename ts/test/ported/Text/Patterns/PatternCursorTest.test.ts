// Ported from NodaTime 3.3.7: src/NodaTime.Test/Text/Patterns/PatternCursorTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { InvalidPatternException, PatternCursor } from "../../../../src/noda-js/internal.ts";
import { assertThrows } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/Text/Patterns/PatternCursorTest.generated.ts";
import { getNextCharacter, textCursorTestBaseBodies, validateCurrentCharacter } from "../TextCursorTestBase.ts";

port(fixture, {
  // MakeCursor
  ...textCursorTestBaseBodies(value => new PatternCursor(value)),

  GetQuotedString_Invalid(pattern: string) {
    const cursor = new PatternCursor(pattern);
    expect(getNextCharacter(cursor)).toBe("'");
    assertThrows(InvalidPatternException, () => cursor.GetQuotedString("'"));
  },

  GetQuotedString_Valid(pattern: string, expected: string) {
    const cursor = new PatternCursor(pattern);
    expect(getNextCharacter(cursor)).toBe("'");
    const actual = cursor.GetQuotedString("'");
    expect(actual).toBe(expected);
    expect(cursor.MoveNext()).toBe(false);
  },

  GetQuotedString_HandlesOtherQuote() {
    const cursor = new PatternCursor("[abc]");
    getNextCharacter(cursor);
    const actual = cursor.GetQuotedString("]");
    expect(actual).toBe("abc");
    expect(cursor.MoveNext()).toBe(false);
  },

  GetQuotedString_NotAtEnd() {
    const cursor = new PatternCursor("'abc'more");
    const openQuote = getNextCharacter(cursor);
    const actual = cursor.GetQuotedString(openQuote);
    expect(actual).toBe("abc");
    validateCurrentCharacter(cursor, 4, "'");

    expect(getNextCharacter(cursor)).toBe("m");
  },

  GetRepeatCount_Valid(text: string, expectedCount: number) {
    const cursor = new PatternCursor(text);
    expect(cursor.MoveNext()).toBe(true);
    const actual = cursor.GetRepeatCount(10);
    expect(actual).toBe(expectedCount);
    validateCurrentCharacter(cursor, expectedCount - 1, "a");
  },

  GetRepeatCount_ExceedsMax() {
    const cursor = new PatternCursor("aaa");
    expect(cursor.MoveNext()).toBe(true);
    assertThrows(InvalidPatternException, () => cursor.GetRepeatCount(2));
  },

  GetEmbeddedPattern_Valid(pattern: string, expectedEmbedded: string) {
    const cursor = new PatternCursor(pattern);
    cursor.MoveNext();
    const embedded = cursor.GetEmbeddedPattern();
    expect(embedded).toBe(expectedEmbedded);
    validateCurrentCharacter(cursor, expectedEmbedded.length + 2, ">");
  },

  GetEmbeddedPattern_Invalid(text: string) {
    const cursor = new PatternCursor(text);
    cursor.MoveNext();
    assertThrows(InvalidPatternException, () => cursor.GetEmbeddedPattern());
  },
});
