// Ported from NodaTime 3.3.7: src/NodaTime/Text/TextCursor.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

/**
 * Provides a cursor over text being parsed. None of the methods in this class throw exceptions (unless
 * there is a bug in Noda Time, in which case an exception is appropriate) and none of the methods
 * have ref parameters indicating failures, unlike subclasses. This class is used as the basis for both
 * value and pattern parsing, so can make no judgement about what's wrong (i.e. it wouldn't know what
 * type of failure to indicate). Instead, methods return Boolean values to indicate success or failure.
 * @internal
 */
export abstract class TextCursor {
  /** Gets the length of the string being parsed. */
  readonly Length: number;

  /** Gets the string being parsed. */
  readonly Value: string;

  /**
   * A nul character. This character is not allowed in any parsable string and is used to
   * indicate that the current character is not set.
   */
  static readonly Nul: string = "\0";

  /** Initializes a new instance to parse the given value. */
  protected constructor(value: string) {
    // Validated by caller.
    this.Value = value;
    this.Length = value.length;
    this._currentField = TextCursor.Nul;
    this._indexField = -1;
    this.Move(-1);
  }

  private _currentField: string;
  private _indexField: number;

  /** Gets the current character. */
  get Current(): string {
    return this._currentField;
  }

  /**
   * Gets a value indicating whether this instance has more characters.
   * `true` if this instance has more characters; otherwise, `false`.
   */
  get HasMoreCharacters(): boolean {
    return this._indexField + 1 < this.Length;
  }

  /** Gets the current index into the string being parsed. */
  get Index(): number {
    return this._indexField;
  }

  /** Gets the remainder the string that has not been parsed yet. */
  get Remainder(): string {
    return this.Value.substring(this._indexField);
  }

  /** Returns a string that represents this instance. */
  toString(): string {
    return this._indexField <= 0
      ? `^${this.Value}`
      : this._indexField >= this.Length
        ? `${this.Value}^`
        : this.Value.substring(0, this._indexField) + "^" + this.Value.substring(this._indexField);
  }

  /** Returns the next character if there is one or {@link Nul} if there isn't. */
  PeekNext(): string {
    return this.HasMoreCharacters ? this.Value[this._indexField + 1]! : TextCursor.Nul;
  }

  /**
   * Moves the specified target index. If the new index is out of range of the valid indices
   * for this string then the index is set to the beginning or the end of the string whichever
   * is nearest the requested index.
   * @param targetIndex Index of the target.
   * @returns `true` if the requested index is in range.
   */
  Move(targetIndex: number): boolean {
    if (targetIndex >= 0) {
      if (targetIndex < this.Length) {
        this._indexField = targetIndex;
        this._currentField = this.Value[this._indexField]!;
        return true;
      } else {
        this._currentField = TextCursor.Nul;
        this._indexField = this.Length;
        return false;
      }
    }
    this._currentField = TextCursor.Nul;
    this._indexField = -1;
    return false;
  }

  /**
   * Moves to the next character.
   * @returns `true` if the requested index is in range.
   */
  MoveNext(): boolean {
    // Logically this is Move(Index + 1), but it's micro-optimized as we
    // know we'll never hit the lower limit this way.
    const targetIndex = this._indexField + 1;
    if (targetIndex < this.Length) {
      this._indexField = targetIndex;
      this._currentField = this.Value[this._indexField]!;
      return true;
    }
    this._currentField = TextCursor.Nul;
    this._indexField = this.Length;
    return false;
  }

  /**
   * Moves to the previous character.
   * @returns `true` if the requested index is in range.
   */
  MovePrevious(): boolean {
    // Logically this is Move(Index - 1), but it's micro-optimized as we
    // know we'll never hit the upper limit this way.
    if (this._indexField > 0) {
      this._indexField--;
      this._currentField = this.Value[this._indexField]!;
      return true;
    }
    this._currentField = TextCursor.Nul;
    this._indexField = -1;
    return false;
  }
}
