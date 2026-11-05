// Ported from NodaTime 3.3.7: src/NodaTime/Text/InstantPattern.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Instant, InstantPatternParser, LocalDatePattern, NodaFormatInfo, PatternBclSupport, Preconditions } from "../internal.ts";
import type { NodaCultureInfo, IPattern, ParseResult, StringBuilder } from "../internal.ts";

let defaultTemplateValue: Instant | undefined;
let bclSupport: PatternBclSupport<Instant> | undefined;
let extendedIsoPatternImpl: InstantPattern | undefined;
let generalPatternImpl: InstantPattern | undefined;

const DefaultFormatPattern = "g";

/**
 * Class whose existence is solely to avoid type initialization order issues, most of which stem
 * from needing NodaFormatInfo.InvariantInfo...
 */
class InstantPatternPatterns {
  static get ExtendedIsoPatternImpl(): InstantPattern {
    return (extendedIsoPatternImpl ??= InstantPattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF'Z'"));
  }
  static get GeneralPatternImpl(): InstantPattern {
    return (generalPatternImpl ??= InstantPattern.CreateWithInvariantCulture("uuuu-MM-ddTHH:mm:ss'Z'"));
  }
}

/**
 * Represents a pattern for parsing and formatting {@link Instant} values.
 *
 * Thread safety: When used with a read-only {@link NodaCultureInfo}, this type is immutable and instances
 * may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
 * not currently enforced.
 */
export class InstantPattern implements IPattern<Instant> {
  /** @internal */
  static get DefaultTemplateValue(): Instant {
    return (defaultTemplateValue ??= Instant.FromUtc(2000, 1, 1, 0, 0));
  }

  /**
   * Gets the general pattern, which always uses an invariant culture. The general pattern represents
   * an instant as a UTC date/time in ISO-8601 style "uuuu-MM-ddTHH:mm:ss'Z'".
   */
  static get General(): InstantPattern {
    return InstantPatternPatterns.GeneralPatternImpl;
  }

  /**
   * Gets an invariant instant pattern which is ISO-8601 compatible, providing up to 9 decimal places
   * of sub-second accuracy. (These digits are omitted when unnecessary.)
   * This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF'Z'".
   */
  static get ExtendedIso(): InstantPattern {
    return InstantPatternPatterns.ExtendedIsoPatternImpl;
  }

  /** @internal */
  static get BclSupport(): PatternBclSupport<Instant> {
    return (bclSupport ??= new PatternBclSupport<Instant>(DefaultFormatPattern, fi => fi.InstantPatternParser));
  }

  private readonly _pattern: IPattern<Instant>;

  private readonly _patternText: string;

  /** Gets the pattern text for this pattern, as supplied on creation. */
  get PatternText(): string {
    return this._patternText;
  }

  private readonly _templateValue: Instant;

  /**
   * Gets the value used as a template for parsing: any field values unspecified
   * in the pattern are taken from the template.
   */
  get TemplateValue(): Instant {
    return this._templateValue;
  }

  private readonly _twoDigitYearMax: number;

  /**
   * Maximum two-digit-year in the template to treat as the current century.
   * If the value parsed is higher than this, the result is adjusted to the previous century.
   * This value defaults to 30. To create a pattern with a different value, use {@link InstantPattern.WithTwoDigitYearMax}.
   * The value is in the range 0-99 inclusive.
   */
  get TwoDigitYearMax(): number {
    return this._twoDigitYearMax;
  }

  /** Gets the localization information used in this pattern. */
  private readonly _formatInfo: NodaFormatInfo;

  private constructor(patternText: string, formatInfo: NodaFormatInfo, templateValue: Instant, twoDigitYearMax: number, pattern: IPattern<Instant>) {
    this._patternText = patternText;
    this._formatInfo = formatInfo;
    this._templateValue = templateValue;
    this._twoDigitYearMax = twoDigitYearMax;
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
  Parse(text: string): ParseResult<Instant> {
    return this._pattern.Parse(text);
  }

  /**
   * Formats the given instant as text according to the rules of this pattern.
   * @param value The instant to format.
   * @returns The instant formatted according to this pattern.
   */
  Format(value: Instant): string {
    return this._pattern.Format(value);
  }

  /**
   * Formats the given value as text according to the rules of this pattern,
   * appending to the given {@link StringBuilder}.
   * @param value The value to format.
   * @param builder The `StringBuilder` to append to.
   * @returns The builder passed in as `builder`.
   */
  AppendFormat(value: Instant, builder: StringBuilder): StringBuilder {
    return this._pattern.AppendFormat(value, builder);
  }

  /**
   * Creates a pattern for the given pattern text and culture.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @param cultureInfo The culture to use in the pattern
   * @returns A pattern for parsing and formatting instants.
   * @throws {InvalidPatternException} The pattern text was invalid.
   */
  static Create(patternText: string, cultureInfo: NodaCultureInfo): InstantPattern;
  /**
   * Creates a pattern for the given pattern text and format info.
   * @param patternText Pattern text to create the pattern for
   * @param formatInfo The format info to use in the pattern
   * @param templateValue The template value to use in the pattern
   * @param twoDigitYearMax Maximum two-digit-year in the template to treat as the current century.
   * @returns A pattern for parsing and formatting instants.
   * @throws {InvalidPatternException} The pattern text was invalid.
   * @internal
   */
  static Create(patternText: string, formatInfo: NodaFormatInfo, templateValue: Instant, twoDigitYearMax: number): InstantPattern;
  static Create(patternText: string, cultureOrFormatInfo: NodaCultureInfo | NodaFormatInfo, templateValue?: Instant, twoDigitYearMax?: number): InstantPattern {
    if (cultureOrFormatInfo instanceof NodaFormatInfo) {
      const formatInfo = cultureOrFormatInfo;
      Preconditions.CheckNotNull(patternText, "patternText");
      Preconditions.CheckNotNull(formatInfo, "formatInfo");
      // Note: no check for the default template value, as that ends up being done in the
      // underlying LocalDateTimePattern creation.
      const pattern = new InstantPatternParser(templateValue!, twoDigitYearMax!).ParsePattern(patternText, formatInfo);
      return new InstantPattern(patternText, formatInfo, templateValue!, twoDigitYearMax!, pattern);
    }
    return InstantPattern.Create(patternText, NodaFormatInfo.GetFormatInfo(cultureOrFormatInfo), InstantPattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);
  }

  // Not ported: CreateWithCurrentCulture (there is no current culture in JavaScript; use create with an explicit culture)

  /**
   * Creates a pattern for the given pattern text in the invariant culture.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @returns A pattern for parsing and formatting instants.
   * @throws {InvalidPatternException} The pattern text was invalid.
   */
  static CreateWithInvariantCulture(patternText: string): InstantPattern {
    return InstantPattern.Create(patternText, NodaFormatInfo.InvariantInfo, InstantPattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * localization information.
   * @param formatInfo The localization information to use in the new pattern.
   * @returns A new pattern with the given localization information.
   */
  private WithFormatInfo(formatInfo: NodaFormatInfo): InstantPattern {
    return InstantPattern.Create(this.PatternText, formatInfo, this.TemplateValue, this.TwoDigitYearMax);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * culture.
   * @param cultureInfo The culture to use in the new pattern.
   * @returns A new pattern with the given culture.
   */
  WithCulture(cultureInfo: NodaCultureInfo): InstantPattern {
    return this.WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));
  }

  /**
   * Creates a pattern like this one, but with the specified template value.
   * @param newTemplateValue The template value for the new pattern, used to fill in unspecified fields.
   * @returns A new pattern with the given template value.
   */
  WithTemplateValue(newTemplateValue: Instant): InstantPattern {
    return InstantPattern.Create(this.PatternText, this._formatInfo, newTemplateValue, this.TwoDigitYearMax);
  }

  /**
   * Creates a pattern like this one, but with a different {@link InstantPattern.TwoDigitYearMax} value.
   * @param twoDigitYearMax The value to use for {@link InstantPattern.TwoDigitYearMax} in the new pattern, in the range 0-99 inclusive.
   * @returns A new pattern with the specified maximum two-digit-year.
   */
  WithTwoDigitYearMax(twoDigitYearMax: number): InstantPattern {
    return InstantPattern.Create(this.PatternText, this._formatInfo, this.TemplateValue, twoDigitYearMax);
  }
}
