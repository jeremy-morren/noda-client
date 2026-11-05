// Ported from NodaTime 3.3.0: src/NodaTime/Text/DurationPattern.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { NodaFormatInfo, PatternBclSupport, Preconditions } from "../internal.ts";
import type { NodaCultureInfo, Duration, IPattern, ParseResult, StringBuilder } from "../internal.ts";

let bclSupport: PatternBclSupport<Duration> | undefined;
let roundtripPatternImpl: DurationPattern | undefined;
let jsonRoundtripPatternImpl: DurationPattern | undefined;

// Nested class for ease of type initialization
/** @internal */
export class DurationPatternPatterns {
  static get RoundtripPatternImpl(): DurationPattern {
    return (roundtripPatternImpl ??= DurationPattern.CreateWithInvariantCulture("-D:hh:mm:ss.FFFFFFFFF"));
  }
  static get JsonRoundtripPatternImpl(): DurationPattern {
    return (jsonRoundtripPatternImpl ??= DurationPattern.CreateWithInvariantCulture("-H:mm:ss.FFFFFFFFF"));
  }
}

/**
 * Represents a pattern for parsing and formatting {@link Duration} values.
 *
 * Thread safety: When used with a read-only {@link NodaCultureInfo}, this type is immutable and instances
 * may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
 * not currently enforced.
 */
export class DurationPattern implements IPattern<Duration> {
  /**
   * Gets the general pattern for durations using the invariant culture, with a format string of "-D:hh:mm:ss.FFFFFFFFF".
   * This pattern round-trips. This corresponds to the "o" standard pattern.
   */
  static get Roundtrip(): DurationPattern {
    return DurationPatternPatterns.RoundtripPatternImpl;
  }

  /**
   * Gets a pattern for durations using the invariant culture, with a format string of "-H:mm:ss.FFFFFFFFF".
   * This pattern round-trips, and is the pattern that NodaTime.Serialization.JsonNet uses by default.
   * This corresponds to the "j" standard pattern.
   */
  static get JsonRoundtrip(): DurationPattern {
    return DurationPatternPatterns.JsonRoundtripPatternImpl;
  }

  /** @internal */
  static get BclSupport(): PatternBclSupport<Duration> {
    return (bclSupport ??= new PatternBclSupport<Duration>("o", fi => fi.DurationPatternParser));
  }

  /** @internal */
  static readonly Patterns = DurationPatternPatterns;

  private readonly _pattern: IPattern<Duration>;

  private readonly _patternText: string;

  /** Gets the pattern text for this pattern, as supplied on creation. */
  get PatternText(): string {
    return this._patternText;
  }

  private constructor(patternText: string, pattern: IPattern<Duration>) {
    this._patternText = patternText;
    this._pattern = pattern;
  }

  /**
   * Parses the given text value according to the rules of this pattern.
   *
   * This method never throws an exception (barring a bug in Noda Time itself). Even errors such as
   * the argument being null are wrapped in a parse result.
   * @param text The text value to parse.
   * @returns The result of parsing, which may be successful or unsuccessful.
   */
  Parse(text: string): ParseResult<Duration> {
    return this._pattern.Parse(text);
  }

  /**
   * Formats the given duration as text according to the rules of this pattern.
   * @param value The duration to format.
   * @returns The duration formatted according to this pattern.
   */
  Format(value: Duration): string {
    return this._pattern.Format(value);
  }

  /**
   * Formats the given value as text according to the rules of this pattern,
   * appending to the given {@link StringBuilder}.
   * @param value The value to format.
   * @param builder The `StringBuilder` to append to.
   * @returns The builder passed in as `builder`.
   */
  AppendFormat(value: Duration, builder: StringBuilder): StringBuilder {
    return this._pattern.AppendFormat(value, builder);
  }

  /**
   * Creates a pattern for the given pattern text and culture.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @param cultureInfo The culture to use in the pattern
   * @returns A pattern for parsing and formatting offsets.
   * @throws {InvalidPatternError} The pattern text was invalid.
   */
  static Create(patternText: string, cultureInfo: NodaCultureInfo): DurationPattern;
  /**
   * Creates a pattern for the given pattern text and format info.
   * @param patternText Pattern text to create the pattern for
   * @param formatInfo Localization information
   * @returns A pattern for parsing and formatting offsets.
   * @throws {InvalidPatternError} The pattern text was invalid.
   * @internal
   */
  static Create(patternText: string, formatInfo: NodaFormatInfo): DurationPattern;
  static Create(patternText: string, cultureOrFormatInfo: NodaCultureInfo | NodaFormatInfo): DurationPattern {
    if (cultureOrFormatInfo instanceof NodaFormatInfo) {
      const formatInfo = cultureOrFormatInfo;
      Preconditions.CheckNotNull(patternText, "patternText");
      Preconditions.CheckNotNull(formatInfo, "formatInfo");
      const pattern = formatInfo.DurationPatternParser.ParsePattern(patternText);
      return new DurationPattern(patternText, pattern);
    }
    return DurationPattern.Create(patternText, NodaFormatInfo.GetFormatInfo(cultureOrFormatInfo));
  }

  // Not ported: CreateWithCurrentCulture (there is no current culture in JavaScript; use create with an explicit culture)

  /**
   * Creates a pattern for the given pattern text in the invariant culture.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @returns A pattern for parsing and formatting offsets.
   * @throws {InvalidPatternError} The pattern text was invalid.
   */
  static CreateWithInvariantCulture(patternText: string): DurationPattern {
    return DurationPattern.Create(patternText, NodaFormatInfo.InvariantInfo);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * culture.
   * @param cultureInfo The culture to use in the new pattern.
   * @returns A new pattern with the given culture.
   */
  WithCulture(cultureInfo: NodaCultureInfo): DurationPattern {
    return DurationPattern.Create(this.PatternText, NodaFormatInfo.GetFormatInfo(cultureInfo));
  }
}
