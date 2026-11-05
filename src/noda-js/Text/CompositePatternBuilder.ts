// Ported from NodaTime 3.3.0: src/NodaTime/Text/CompositePatternBuilder.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { FormatError, ParseResult, Preconditions, ValueCursor } from "../internal.ts";
import type { IPartialPattern, IPattern, StringBuilder } from "../internal.ts";

/**
 * A builder for composite patterns.
 *
 * A composite pattern is a combination of multiple patterns. When parsing, these are checked
 * in the order in which they are added to the builder with the {@link Add}
 * method, by trying to parse and seeing if the result is a successful one. When formatting,
 * the patterns are checked in the reverse order, using the predicate provided along with the pattern
 * when calling `add`. The intention is that patterns are added in "most precise first" order,
 * and the predicate should indicate whether it can fully represent the given value - so the "less precise"
 * (and therefore usually shorter) pattern can be used first.
 * @typeParam T The type of value to be parsed or formatted by the resulting pattern.
 */
export class CompositePatternBuilder<T> implements Iterable<IPattern<T>> {
  private readonly _patterns: IPattern<T>[] = [];
  private readonly _formatPredicates: ((value: T) => boolean)[] = [];

  /**
   * Constructs a new instance which initially has no component patterns. At least one component
   * pattern must be added before {@link Build} is called.
   */
  constructor() {}

  /**
   * Adds a component pattern to this builder.
   * @param pattern The component pattern to use as part of the eventual composite pattern.
   * @param formatPredicate A predicate to determine whether or not this pattern is suitable for
   * formatting the given value.
   */
  Add(pattern: IPattern<T>, formatPredicate: (value: T) => boolean): void {
    this._patterns.push(Preconditions.CheckNotNull(pattern, "pattern"));
    this._formatPredicates.push(Preconditions.CheckNotNull(formatPredicate, "formatPredicate"));
  }

  /**
   * Builds a composite pattern from this builder. Further changes to this builder
   * will have no impact on the returned pattern.
   * @throws {InvalidOperationError} No component patterns have been added.
   * @returns A pattern using the patterns added to this builder.
   */
  Build(): IPattern<T> {
    Preconditions.CheckState(this._patterns.length !== 0, "A composite pattern must have at least one component pattern.");
    return new CompositePattern<T>(this._patterns, this._formatPredicates);
  }

  /** @internal */
  BuildAsPartial(): IPartialPattern<T> {
    Preconditions.DebugCheckState(
      this._patterns.every((p) => "parsePartial" in p),
      "All patterns should be partial",
    );
    return this.Build() as IPartialPattern<T>;
  }

  [Symbol.iterator](): Iterator<IPattern<T>> {
    return this._patterns[Symbol.iterator]();
  }
}

class CompositePattern<T> implements IPartialPattern<T> {
  private readonly _patterns: readonly IPattern<T>[];
  private readonly _formatPredicates: readonly ((value: T) => boolean)[];

  constructor(patterns: readonly IPattern<T>[], formatPredicates: readonly ((value: T) => boolean)[]) {
    this._patterns = [...patterns];
    this._formatPredicates = [...formatPredicates];
  }

  /** @inheritDoc */
  Parse(text: string): ParseResult<T> {
    for (const pattern of this._patterns) {
      const result = pattern.Parse(text);
      if (result.Success || !result.ContinueAfterErrorWithMultipleFormats) {
        return result;
      }
    }
    return ParseResult.NoMatchingFormat<T>(new ValueCursor(text));
  }

  /** @inheritDoc */
  ParsePartial(cursor: ValueCursor): ParseResult<T> {
    const index = cursor.Index;
    for (const pattern of this._patterns as readonly IPartialPattern<T>[]) {
      cursor.Move(index);
      const result = pattern.ParsePartial(cursor);
      if (result.Success || !result.ContinueAfterErrorWithMultipleFormats) {
        return result;
      }
    }
    cursor.Move(index);
    return ParseResult.NoMatchingFormat<T>(cursor);
  }

  /** @inheritDoc */
  Format(value: T): string {
    return this.FindFormatPattern(value).Format(value);
  }

  /** @inheritDoc */
  AppendFormat(value: T, builder: StringBuilder): StringBuilder {
    return this.FindFormatPattern(value).AppendFormat(value, builder);
  }

  private FindFormatPattern(value: T): IPattern<T> {
    for (let i = this._formatPredicates.length - 1; i >= 0; i--) {
      if (this._formatPredicates[i]!(value)) {
        return this._patterns[i]!;
      }
    }
    throw new FormatError("Composite pattern was unable to format value using any of the provided patterns.");
  }
}
