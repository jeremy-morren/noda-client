// Ported from NodaTime 3.3.7: src/NodaTime/Text/OffsetPattern.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { NodaFormatInfo, PatternBclSupport, Preconditions } from "../internal.ts";
import type { NodaCultureInfo, IPartialPattern, IPattern, Offset, ParseResult, StringBuilder } from "../internal.ts";

const DefaultFormatPattern = "g";

let generalInvariant: OffsetPattern | undefined;
let generalInvariantWithZ: OffsetPattern | undefined;
let bclSupport: PatternBclSupport<Offset> | undefined;

/**
 * Represents a pattern for parsing and formatting {@link Offset} values.
 */
export class OffsetPattern implements IPattern<Offset> {
  /** The "general" offset pattern (e.g. +HH, +HH:mm, +HH:mm:ss, +HH:mm:ss.fff) for the invariant culture. */
  static get GeneralInvariant(): OffsetPattern {
    return (generalInvariant ??= OffsetPattern.CreateWithInvariantCulture("g"));
  }

  /**
   * The "general" offset pattern (e.g. +HH, +HH:mm, +HH:mm:ss, +HH:mm:ss.fff) for the invariant culture,
   * but producing (and allowing) Z as a value for a zero offset.
   */
  static get GeneralInvariantWithZ(): OffsetPattern {
    return (generalInvariantWithZ ??= OffsetPattern.CreateWithInvariantCulture("G"));
  }

  /** @internal */
  static get BclSupport(): PatternBclSupport<Offset> {
    return (bclSupport ??= new PatternBclSupport<Offset>(DefaultFormatPattern, (fi) => fi.OffsetPatternParser));
  }

  private readonly _patternText: string;

  /** Gets the pattern text for this pattern, as supplied on creation. */
  get PatternText(): string {
    return this._patternText;
  }

  /**
   * Returns the pattern that this object delegates to. Mostly useful to avoid this public class
   * implementing an internal interface.
   * @internal
   */
  readonly UnderlyingPattern: IPartialPattern<Offset>;

  private constructor(patternText: string, pattern: IPartialPattern<Offset>) {
    this._patternText = patternText;
    this.UnderlyingPattern = pattern;
  }

  /**
   * Parses the given text value according to the rules of this pattern.
   *
   * This method never throws an exception (barring a bug in Noda Time itself). Even errors such as
   * the argument being null are wrapped in a parse result.
   * @param text The text value to parse.
   * @returns The result of parsing, which may be successful or unsuccessful.
   */
  Parse(text: string): ParseResult<Offset> {
    return this.UnderlyingPattern.Parse(text);
  }

  /**
   * Formats the given offset as text according to the rules of this pattern.
   * @param value The offset to format.
   * @returns The offset formatted according to this pattern.
   */
  Format(value: Offset): string {
    return this.UnderlyingPattern.Format(value);
  }

  /**
   * Formats the given value as text according to the rules of this pattern,
   * appending to the given {@link StringBuilder}.
   * @param value The value to format.
   * @param builder The `StringBuilder` to append to.
   * @returns The builder passed in as `builder`.
   */
  AppendFormat(value: Offset, builder: StringBuilder): StringBuilder {
    return this.UnderlyingPattern.AppendFormat(value, builder);
  }

  /**
   * Creates a pattern for the given pattern text and culture.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @param cultureInfo The culture to use in the pattern
   * @returns A pattern for parsing and formatting offsets.
   * @throws {InvalidPatternException} The pattern text was invalid.
   */
  static Create(patternText: string, cultureInfo: NodaCultureInfo): OffsetPattern;
  /**
   * Creates a pattern for the given pattern text and format info.
   * @param patternText Pattern text to create the pattern for
   * @param formatInfo Localization information
   * @returns A pattern for parsing and formatting offsets.
   * @throws {InvalidPatternException} The pattern text was invalid.
   * @internal
   */
  static Create(patternText: string, formatInfo: NodaFormatInfo): OffsetPattern;
  static Create(patternText: string, cultureOrFormatInfo: NodaCultureInfo | NodaFormatInfo): OffsetPattern {
    if (!(cultureOrFormatInfo instanceof NodaFormatInfo)) {
      return OffsetPattern.Create(patternText, NodaFormatInfo.GetFormatInfo(cultureOrFormatInfo));
    }
    const formatInfo = cultureOrFormatInfo;
    Preconditions.CheckNotNull(patternText, "patternText");
    Preconditions.CheckNotNull(formatInfo, "formatInfo");
    const pattern = formatInfo.OffsetPatternParser.ParsePattern(patternText) as IPartialPattern<Offset>;
    return new OffsetPattern(patternText, pattern);
  }

  // Not ported: CreateWithCurrentCulture (there is no current culture in JavaScript)

  /**
   * Creates a pattern for the given pattern text in the invariant culture.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @returns A pattern for parsing and formatting offsets.
   * @throws {InvalidPatternException} The pattern text was invalid.
   */
  static CreateWithInvariantCulture(patternText: string): OffsetPattern {
    return OffsetPattern.Create(patternText, NodaFormatInfo.InvariantInfo);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * culture.
   * @param cultureInfo The culture to use in the new pattern.
   * @returns A new pattern with the given culture.
   */
  WithCulture(cultureInfo: NodaCultureInfo): OffsetPattern {
    return OffsetPattern.Create(this.PatternText, NodaFormatInfo.GetFormatInfo(cultureInfo));
  }
}
