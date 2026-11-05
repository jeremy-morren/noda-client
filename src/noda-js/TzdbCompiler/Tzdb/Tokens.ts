// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler/Tzdb/Tokens.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Preconditions, StringBuilder } from "../../internal.ts";
import { IsWhiteSpace, MissingTokenException, TrimEnd } from "../internal.ts";
import { NewInvalidDataException } from "../../internal.ts";

/**
 * Represents an empty token list.
 */
const NoTokens: readonly string[] = [];

/**
 * Provides a simple string tokenizer that breaks the string into words that are separated by
 * white space.
 *
 * Multiple white spaces in a row are treated as one separator. White space at the beginning of
 * the line cause an empty token to be returned as the first token. White space at the end of
 * the line are ignored.
 * @internal
 */
export class Tokens {
  /**
   * The list of words. This will never be null but may be empty.
   */
  private readonly _words: readonly string[];

  /**
   * The current index into the words list.
   */
  private _index = 0;

  /**
   * Initializes a new instance of the {@link Tokens} class.
   * @param words The words list.
   */
  private constructor(words: readonly string[]) {
    this._words = words;
  }

  /**
   * Gets a value indicating whether this instance has another token.
   */
  get HasNextToken(): boolean {
    return this._index < this._words.length;
  }

  /**
   * Returns the next token.
   * @param name The name of the token. Used in the exception to identify the missing token.
   * @returns The next token.
   * @throws {MissingTokenException} Thrown if there is no next token.
   */
  NextToken(name: string): string {
    const [success, result] = this.TryNextToken();
    if (success) {
      return result;
    }
    throw new MissingTokenException(name);
  }

  /**
   * Returns an object that contains the list of the whitespace separated words in the given
   * string. The string is assumed to be culture invariant.
   * @param text The text to break into words.
   * @returns The tokenized text.
   */
  static Tokenize(text: string): Tokens {
    Preconditions.CheckNotNull(text, "text");
    text = TrimEnd(text);
    if (text === "") {
      return new Tokens(NoTokens);
    }
    // Primitive parser, but we need to handle double quotes.
    const list: string[] = [];
    const currentWord = new StringBuilder();
    let inQuotes = false;
    let lastCharacterWasWhitespace = false;
    for (let i = 0; i < text.length; i++) {
      const c = text.charAt(i);
      if (c === "\"") {
        inQuotes = !inQuotes;
        lastCharacterWasWhitespace = false;
        continue;
      }
      if (IsWhiteSpace(c) && !inQuotes) {
        if (!lastCharacterWasWhitespace) {
          list.push(currentWord.toString());
          lastCharacterWasWhitespace = true;
          currentWord.Clear();
        }
        // Otherwise, we're just collapsing multiple whitespace
      } else {
        currentWord.Append(c);
        lastCharacterWasWhitespace = false;
      }
    }
    if (!lastCharacterWasWhitespace) {
      list.push(currentWord.toString());
    }
    if (inQuotes) {
      throw NewInvalidDataException("Line has unterminated quotes");
    }
    return new Tokens(list);
  }

  /**
   * Tries to get the next token.
   * @returns A tuple: true if there was a next token, false otherwise; and the next token ("" if there was none).
   */
  TryNextToken(): [boolean, string] {
    if (this.HasNextToken) {
      return [true, this._words[this._index++]!];
    }
    return [false, ""];
  }
}
