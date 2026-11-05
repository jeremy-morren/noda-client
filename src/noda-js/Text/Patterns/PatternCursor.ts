// Ported from NodaTime 3.3.7: src/NodaTime/Text/Patterns/PatternCursor.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { InvalidPatternException, StringBuilder, TextCursor, TextErrorMessages, FormatString } from "../../internal.ts";

/**
 * Extends {@link TextCursor} to simplify parsing patterns such as "uuuu-MM-dd".
 * @internal
 */
export class PatternCursor extends TextCursor {
  /** The character signifying the start of an embedded pattern. */
  static readonly EmbeddedPatternStart: string = "<";
  /** The character signifying the end of an embedded pattern. */
  static readonly EmbeddedPatternEnd: string = ">";

  constructor(pattern: string) {
    super(pattern);
  }

  /** @internal */
  static NewPattern(pattern: string): PatternCursor {
    return new PatternCursor(pattern);
  }

  /**
   * Gets the quoted string.
   *
   * The cursor is left positioned at the end of the quoted region.
   * @param closeQuote The close quote character to match for the end of the quoted string.
   * @returns The quoted string sans open and close quotes. This can be an empty string but will not be null.
   */
  GetQuotedString(closeQuote: string): string {
    const builder = new StringBuilder();
    let endQuoteFound = false;
    while (this.MoveNext()) {
      if (this.Current === closeQuote) {
        this.MoveNext();
        endQuoteFound = true;
        break;
      }
      if (this.Current === "\\") {
        if (!this.MoveNext()) {
          throw new InvalidPatternException(TextErrorMessages.EscapeAtEndOfString);
        }
      }
      builder.Append(this.Current);
    }
    if (!endQuoteFound) {
      throw new InvalidPatternException(TextErrorMessages.MissingEndQuote, closeQuote);
    }
    this.MovePrevious();
    return builder.toString();
  }

  /**
   * Gets the pattern repeat count. The cursor is left on the final character of the
   * repeated sequence.
   * @param maximumCount The maximum number of repetitions allowed.
   * @returns The repetition count which is always at least `1`.
   */
  GetRepeatCount(maximumCount: number): number {
    const patternCharacter = this.Current;
    const startPos = this.Index;
    while (this.MoveNext() && this.Current === patternCharacter) {
      // Empty loop body
    }
    const repeatLength = this.Index - startPos;
    // Move the cursor back to the last character of the repeated pattern
    this.MovePrevious();
    if (repeatLength > maximumCount) {
      throw new InvalidPatternException(TextErrorMessages.RepeatCountExceeded, patternCharacter, maximumCount);
    }
    return repeatLength;
  }

  /**
   * Returns a string containing the embedded pattern within this one.
   *
   * The cursor is expected to be positioned immediately before the {@link EmbeddedPatternStart} character (`<`),
   * and on success the cursor will be positioned on the {@link EmbeddedPatternEnd} character (`>`).
   *
   * Quote characters (' and ") and escaped characters (escaped with a backslash) are handled
   * but not unescaped: the resulting pattern should be ready for parsing as normal. It is assumed that the
   * embedded pattern will itself handle embedded patterns, so if the input is on the first `<`
   * of `"before <outer1 <inner> outer2> after"`
   * this method will return `"outer1 <inner> outer2"` and the cursor will be positioned
   * on the final `>` afterwards.
   * @returns The embedded pattern, not including the start/end pattern characters.
   */
  GetEmbeddedPattern(): string {
    if (!this.MoveNext() || this.Current !== PatternCursor.EmbeddedPatternStart) {
      throw new InvalidPatternException(FormatString(TextErrorMessages.MissingEmbeddedPatternStart, PatternCursor.EmbeddedPatternStart));
    }
    const startIndex = this.Index + 1;
    let depth = 1; // For nesting
    while (this.MoveNext()) {
      const current = this.Current;
      if (current === PatternCursor.EmbeddedPatternEnd) {
        depth--;
        if (depth === 0) {
          return this.Value.substring(startIndex, this.Index);
        }
      } else if (current === PatternCursor.EmbeddedPatternStart) {
        depth++;
      } else if (current === "\\") {
        if (!this.MoveNext()) {
          throw new InvalidPatternException(TextErrorMessages.EscapeAtEndOfString);
        }
      } else if (current === "'" || current === '"') {
        // We really don't care about the value here. It's slightly inefficient to
        // create the substring and then ignore it, but it's unlikely to be significant.
        this.GetQuotedString(current);
      }
    }
    // We've reached the end of the enclosing pattern without reaching the end of the embedded pattern. Oops.
    throw new InvalidPatternException(FormatString(TextErrorMessages.MissingEmbeddedPatternEnd, PatternCursor.EmbeddedPatternEnd));
  }
}
