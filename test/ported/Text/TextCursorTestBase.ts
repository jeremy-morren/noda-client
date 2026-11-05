// Ported from NodaTime 3.3.7: src/NodaTime.Test/Text/TextCursorTestBase.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// Base class for tests of classes derived from TextCursor. noda-js: the base class's test methods are returned
// by textCursorTestBaseBodies(makeCursor), for the fixture to spread into its bodies; the helpers are functions.

import { expect } from "vitest";
import { TextCursor } from "../../../src/noda-js/internal.ts";
import type { TestBody } from "../../helpers/scenarios.ts";

/** The test methods TextCursorTestBase gives every cursor fixture; makeCursor is the fixture's MakeCursor. */
export function textCursorTestBaseBodies(makeCursor: (value: string) => TextCursor): Record<string, TestBody> {
  return {
    TestConstructor() {
      const testString = "test";
      const cursor = makeCursor(testString);
      validateContents(cursor, testString);
      validateBeginningOfString(cursor);
    },

    TestMove() {
      const cursor = makeCursor("test");
      validateBeginningOfString(cursor);
      expect(cursor.Move(0)).toBe(true);
      validateCurrentCharacter(cursor, 0, "t");
      expect(cursor.Move(1)).toBe(true);
      validateCurrentCharacter(cursor, 1, "e");
      expect(cursor.Move(2)).toBe(true);
      validateCurrentCharacter(cursor, 2, "s");
      expect(cursor.Move(3)).toBe(true);
      validateCurrentCharacter(cursor, 3, "t");
      expect(cursor.Move(4)).toBe(false);
      validateEndOfString(cursor);
    },

    TestMove_NextPrevious() {
      const cursor = makeCursor("test");
      validateBeginningOfString(cursor);
      expect(cursor.Move(2), "Move(2)").toBe(true);
      validateCurrentCharacter(cursor, 2, "s");
      expect(cursor.MovePrevious(), "MovePrevious()").toBe(true);
      validateCurrentCharacter(cursor, 1, "e");
      expect(cursor.MoveNext(), "MoveNext()").toBe(true);
      validateCurrentCharacter(cursor, 2, "s");
      expect(cursor.MovePrevious()).toBe(true); // 1
      expect(cursor.MovePrevious()).toBe(true); // 0
      expect(cursor.MovePrevious()).toBe(false);
      validateCurrentCharacter(cursor, -1, "\0");
      expect(cursor.MovePrevious()).toBe(false);
      validateCurrentCharacter(cursor, -1, "\0");
    },

    TestMove_invalid() {
      const cursor = makeCursor("test");
      validateBeginningOfString(cursor);
      expect(cursor.Move(-1000)).toBe(false);
      validateBeginningOfString(cursor);
      expect(cursor.Move(1000)).toBe(false);
      validateEndOfString(cursor);
      expect(cursor.Move(-1000)).toBe(false);
      validateBeginningOfString(cursor);
    },
  };
}

export function getNextCharacter(cursor: TextCursor): string {
  expect(cursor.MoveNext()).toBe(true);
  return cursor.Current;
}

export function validateBeginningOfString(cursor: TextCursor): void {
  validateCurrentCharacter(cursor, -1, TextCursor.Nul);
}

export function validateCurrentCharacter(cursor: TextCursor, expectedCurrentIndex: number, expectedCurrentCharacter: string): void {
  expect(cursor.Current).toBe(expectedCurrentCharacter);
  expect(cursor.Index).toBe(expectedCurrentIndex);
}

export function validateEndOfString(cursor: TextCursor): void {
  validateCurrentCharacter(cursor, cursor.Length, TextCursor.Nul);
}

export function validateContents(cursor: TextCursor, value: string, length = -1): void {
  if (length < 0) {
    length = value.length;
  }
  expect(cursor.Value, "Cursor Value mismatch").toBe(value);
  expect(cursor.Length, "Cursor Length mismatch").toBe(length);
}
