// Ported from NodaTime 3.3.7: src/NodaTime/Text/IPartialPattern.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import type { IPattern, ParseResult, ValueCursor } from "../internal.ts";

/**
 * Internal interface supporting partial parsing and formatting. This is used
 * when one pattern is embedded within another.
 * @typeParam T The type of value to be parsed or formatted.
 * @internal
 */
export interface IPartialPattern<T> extends IPattern<T> {
  /**
   * Parses a value from the current position in the cursor. This will
   * not fail if the pattern ends before the cursor does - that's expected
   * in most cases.
   * @param cursor The cursor to parse from.
   * @returns The result of parsing from the cursor.
   */
  ParsePartial(cursor: ValueCursor): ParseResult<T>;
}
