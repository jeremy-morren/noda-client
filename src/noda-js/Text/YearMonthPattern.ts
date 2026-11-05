// Ported from NodaTime 3.3.0: src/NodaTime/Text/YearMonthPattern.cs
// Copyright 2019 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { LocalDatePattern, NodaFormatInfo, PatternBclSupport, Preconditions, YearMonth, YearMonthPatternParser } from "../internal.ts";
import type { NodaCultureInfo, IPartialPattern, IPattern, ParseResult, StringBuilder } from "../internal.ts";

let defaultTemplateValue: YearMonth | undefined;
let bclSupport: PatternBclSupport<YearMonth> | undefined;
let isoPatternImpl: YearMonthPattern | undefined;

const IsoFormatPattern = "g"; // General (ISO)

/**
 * Class whose existence is solely to avoid type initialization order issues, most of which stem
 * from needing NodaFormatInfo.InvariantInfo...
 * @internal
 */
export class YearMonthPatternPatterns {
  static get IsoPatternImpl(): YearMonthPattern {
    return (isoPatternImpl ??= YearMonthPattern.CreateWithInvariantCulture("uuuu'-'MM"));
  }
}

/**
 * Represents a pattern for parsing and formatting {@link YearMonth} values.
 *
 * Thread safety: When used with a read-only {@link NodaCultureInfo}, this type is immutable and instances
 * may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
 * not currently enforced.
 */
export class YearMonthPattern implements IPattern<YearMonth> {
  /** @internal */
  static get DefaultTemplateValue(): YearMonth {
    return (defaultTemplateValue ??= new YearMonth(2000, 1));
  }

  /** @internal */
  static readonly CultureDefaultFormatPattern = "G"; // General (culture-specific)

  /** @internal */
  static get BclSupport(): PatternBclSupport<YearMonth> {
    return (bclSupport ??= new PatternBclSupport<YearMonth>(IsoFormatPattern, fi => fi.YearMonthPatternParser));
  }

  /**
   * Gets an invariant year/month pattern which is ISO-8601 compatible.
   * This corresponds to the text pattern "uuuu'-'MM".
   *
   * This pattern corresponds to the 'g' standard pattern.
   */
  static get Iso(): YearMonthPattern {
    return YearMonthPatternPatterns.IsoPatternImpl;
  }

  /** @internal */
  static readonly Patterns = YearMonthPatternPatterns;

  /**
   * Returns the pattern that this object delegates to. Mostly useful to avoid this public class
   * implementing an internal interface.
   * @internal
   */
  readonly UnderlyingPattern: IPartialPattern<YearMonth>;

  private readonly _patternText: string;

  /** Gets the pattern text for this pattern, as supplied on creation. */
  get PatternText(): string {
    return this._patternText;
  }

  /** Returns the localization information used in this pattern. */
  private readonly _formatInfo: NodaFormatInfo;

  private readonly _templateValue: YearMonth;

  /**
   * Gets the value used as a template for parsing: any field values unspecified
   * in the pattern are taken from the template.
   */
  get TemplateValue(): YearMonth {
    return this._templateValue;
  }

  private readonly _twoDigitYearMax: number;

  /**
   * Maximum two-digit-year in the template to treat as the current century.
   * If the value parsed is higher than this, the result is adjusted to the previous century.
   * This value defaults to 30. To create a pattern with a different value, use {@link YearMonthPattern.WithTwoDigitYearMax}.
   * The value is in the range 0-99 inclusive.
   */
  get TwoDigitYearMax(): number {
    return this._twoDigitYearMax;
  }

  private constructor(patternText: string, formatInfo: NodaFormatInfo, templateValue: YearMonth, twoDigitYearMax: number,
    pattern: IPartialPattern<YearMonth>) {
    this._patternText = patternText;
    this._formatInfo = formatInfo;
    this._templateValue = templateValue;
    this._twoDigitYearMax = twoDigitYearMax;
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
  Parse(text: string): ParseResult<YearMonth> {
    return this.UnderlyingPattern.Parse(text);
  }

  /**
   * Formats the given year/month as text according to the rules of this pattern.
   * @param value The year/month to format.
   * @returns The year/month formatted according to this pattern.
   */
  Format(value: YearMonth): string {
    return this.UnderlyingPattern.Format(value);
  }

  /**
   * Formats the given value as text according to the rules of this pattern,
   * appending to the given {@link StringBuilder}.
   * @param value The value to format.
   * @param builder The `StringBuilder` to append to.
   * @returns The builder passed in as `builder`.
   */
  AppendFormat(value: YearMonth, builder: StringBuilder): StringBuilder {
    return this.UnderlyingPattern.AppendFormat(value, builder);
  }

  /**
   * Creates a pattern for the given pattern text, culture, and template value.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @param cultureInfo The culture to use in the pattern
   * @param templateValue Template value to use for unspecified fields
   * @returns A pattern for parsing and formatting year/months.
   * @throws {InvalidPatternError} The pattern text was invalid.
   */
  static Create(patternText: string, cultureInfo: NodaCultureInfo, templateValue: YearMonth): YearMonthPattern;
  /**
   * Creates a pattern for the given pattern text and culture, with a template value of 2000-01.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @param cultureInfo The culture to use in the pattern
   * @returns A pattern for parsing and formatting year/months.
   * @throws {InvalidPatternError} The pattern text was invalid.
   */
  static Create(patternText: string, cultureInfo: NodaCultureInfo): YearMonthPattern;
  /**
   * Creates a pattern for the given pattern text, format info, and template value.
   * @param patternText Pattern text to create the pattern for
   * @param formatInfo The format info to use in the pattern
   * @param templateValue Template value to use for unspecified fields
   * @param twoDigitYearMax Maximum two-digit-year in the template to treat as the current century.
   * @returns A pattern for parsing and formatting year/month values.
   * @throws {InvalidPatternError} The pattern text was invalid.
   * @internal
   */
  static Create(patternText: string, formatInfo: NodaFormatInfo, templateValue: YearMonth, twoDigitYearMax: number): YearMonthPattern;
  static Create(patternText: string, cultureOrFormatInfo: NodaCultureInfo | NodaFormatInfo, templateValue?: YearMonth, twoDigitYearMax?: number): YearMonthPattern {
    if (cultureOrFormatInfo instanceof NodaFormatInfo) {
      const formatInfo = cultureOrFormatInfo;
      Preconditions.CheckNotNull(patternText, "patternText");
      Preconditions.CheckNotNull(formatInfo, "formatInfo");
      // Use the "fixed" parser for the common case of the default template value.
      let pattern: IPattern<YearMonth> = templateValue!.Equals(YearMonthPattern.DefaultTemplateValue) && twoDigitYearMax === LocalDatePattern.DefaultTwoDigitYearMax
        ? formatInfo.YearMonthPatternParser.ParsePattern(patternText)
        : new YearMonthPatternParser(templateValue!, twoDigitYearMax!).ParsePattern(patternText, formatInfo);
      // If ParsePattern returns a standard pattern instance, we need to get the underlying partial pattern.
      pattern = pattern instanceof YearMonthPattern ? pattern.UnderlyingPattern : pattern;
      const partialPattern = pattern as IPartialPattern<YearMonth>;
      return new YearMonthPattern(patternText, formatInfo, templateValue!, twoDigitYearMax!, partialPattern);
    }
    return YearMonthPattern.Create(patternText, NodaFormatInfo.GetFormatInfo(cultureOrFormatInfo),
      templateValue ?? YearMonthPattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);
  }

  // Not ported: CreateWithCurrentCulture (there is no current culture in JavaScript; use create with an explicit culture)

  /**
   * Creates a pattern for the given pattern text in the invariant culture.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @returns A pattern for parsing and formatting year/month values.
   * @throws {InvalidPatternError} The pattern text was invalid.
   */
  static CreateWithInvariantCulture(patternText: string): YearMonthPattern {
    return YearMonthPattern.Create(patternText, NodaFormatInfo.InvariantInfo, YearMonthPattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * localization information.
   * @param formatInfo The localization information to use in the new pattern.
   * @returns A new pattern with the given localization information.
   */
  private WithFormatInfo(formatInfo: NodaFormatInfo): YearMonthPattern {
    return YearMonthPattern.Create(this.PatternText, formatInfo, this.TemplateValue, this.TwoDigitYearMax);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * culture.
   * @param cultureInfo The culture to use in the new pattern.
   * @returns A new pattern with the given culture.
   */
  WithCulture(cultureInfo: NodaCultureInfo): YearMonthPattern {
    return this.WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));
  }

  /**
   * Creates a pattern like this one, but with the specified template value.
   * @param newTemplateValue The template value for the new pattern, used to fill in unspecified fields.
   * @returns A new pattern with the given template value.
   */
  WithTemplateValue(newTemplateValue: YearMonth): YearMonthPattern {
    return YearMonthPattern.Create(this.PatternText, this._formatInfo, newTemplateValue, this.TwoDigitYearMax);
  }

  /**
   * Creates a pattern like this one, but with a different {@link YearMonthPattern.TwoDigitYearMax} value.
   * @param twoDigitYearMax The value to use for {@link YearMonthPattern.TwoDigitYearMax} in the new pattern, in the range 0-99 inclusive.
   * @returns A new pattern with the specified maximum two-digit-year.
   */
  WithTwoDigitYearMax(twoDigitYearMax: number): YearMonthPattern {
    return YearMonthPattern.Create(this.PatternText, this._formatInfo, this.TemplateValue, twoDigitYearMax);
  }
}
