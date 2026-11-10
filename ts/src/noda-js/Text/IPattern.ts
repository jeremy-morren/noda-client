// Ported from NodaTime 3.3.7: src/NodaTime/Text/IPattern.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import type { ParseResult, StringBuilder } from "../internal.ts";

/**
 * Generic interface supporting parsing and formatting. Parsing always results in a
 * {@link ParseResult} which can represent success or failure.
 *
 * Idiomatic text handling in Noda Time involves creating a pattern once and reusing it multiple
 * times, rather than specifying the pattern text repeatedly. All patterns are immutable and thread-safe,
 * and include the culture used for localization purposes.
 * @typeParam T Type of value to parse or format.
 */
export interface IPattern<T> {
  /**
   * Parses the given text value according to the rules of this pattern.
   *
   * This method never throws an exception (barring a bug in Noda Time itself). Even errors such as
   * the argument being null are wrapped in a parse result.
   * @param text The text value to parse.
   * @returns The result of parsing, which may be successful or unsuccessful.
   */
  Parse(text: string): ParseResult<T>;

  /**
   * Formats the given value as text according to the rules of this pattern.
   * @param value The value to format.
   * @returns The value formatted according to this pattern.
   */
  Format(value: T): string;

  /**
   * Formats the given value as text according to the rules of this pattern,
   * appending to the given {@link StringBuilder}.
   * @param value The value to format.
   * @param builder The `StringBuilder` to append to.
   * @returns The builder passed in as `builder`.
   */
  AppendFormat(value: T, builder: StringBuilder): StringBuilder;
}
