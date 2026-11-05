// Ported from NodaTime 3.3.0: src/NodaTime/Text/OffsetDatePattern.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { LocalDate, LocalDatePattern, NodaFormatInfo, Offset, OffsetDatePatternParser, PatternBclSupport, Preconditions } from "../internal.ts";
import type { CalendarSystem, NodaCultureInfo, IPattern, OffsetDate, ParseResult, StringBuilder } from "../internal.ts";

let defaultTemplateValue: OffsetDate | undefined;
let generalIsoPatternImpl: OffsetDatePattern | undefined;
let fullRoundtripPatternImpl: OffsetDatePattern | undefined;
let bclSupport: PatternBclSupport<OffsetDate> | undefined;

/**
 * Class whose existence is solely to avoid type initialization order issues, most of which stem
 * from needing NodaFormatInfo.InvariantInfo...
 * @internal
 */
export class OffsetDatePatternPatterns {
  static get GeneralIsoPatternImpl(): OffsetDatePattern {
    return (generalIsoPatternImpl ??= OffsetDatePattern.Create("uuuu'-'MM'-'ddo<G>", NodaFormatInfo.InvariantInfo, OffsetDatePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax));
  }
  static get FullRoundtripPatternImpl(): OffsetDatePattern {
    return (fullRoundtripPatternImpl ??= OffsetDatePattern.Create("uuuu'-'MM'-'ddo<G> '('c')'", NodaFormatInfo.InvariantInfo, OffsetDatePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax));
  }
  static get BclSupport(): PatternBclSupport<OffsetDate> {
    return (bclSupport ??= new PatternBclSupport<OffsetDate>("G", fi => fi.OffsetDatePatternParser));
  }
}

/**
 * Represents a pattern for parsing and formatting {@link OffsetDate} values.
 *
 * Thread safety: When used with a read-only {@link NodaCultureInfo}, this type is immutable and instances
 * may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
 * not currently enforced.
 */
export class OffsetDatePattern implements IPattern<OffsetDate> {
  /** @internal */
  static get DefaultTemplateValue(): OffsetDate {
    return (defaultTemplateValue ??= new LocalDate(2000, 1, 1).WithOffset(Offset.Zero));
  }

  /**
   * Gets an invariant offset date pattern based on ISO-8601, including offset from UTC.
   *
   * The calendar system is not parsed or formatted as part of this pattern. It corresponds to a custom pattern of
   * "uuuu'-'MM'-'ddo<G>". This pattern is available as the "G" standard pattern (even though it is invariant).
   */
  static get GeneralIso(): OffsetDatePattern {
    return OffsetDatePatternPatterns.GeneralIsoPatternImpl;
  }

  /**
   * Gets an invariant offset date pattern based on ISO-8601
   * including offset from UTC and calendar ID.
   *
   * The returned pattern corresponds to a custom pattern of
   * "uuuu'-'MM'-'dd'o<G> '('c')'". This will round-trip any value in any calendar,
   * and is available as the "r" standard pattern.
   */
  static get FullRoundtrip(): OffsetDatePattern {
    return OffsetDatePatternPatterns.FullRoundtripPatternImpl;
  }

  /** @internal */
  static readonly Patterns = OffsetDatePatternPatterns;

  /** @internal Equivalent of OffsetDatePattern.Patterns.BclSupport. */
  static get BclSupport(): PatternBclSupport<OffsetDate> {
    return OffsetDatePatternPatterns.BclSupport;
  }

  private readonly _pattern: IPattern<OffsetDate>;

  private readonly _patternText: string;

  /** Gets the pattern text for this pattern, as supplied on creation. */
  get PatternText(): string {
    return this._patternText;
  }

  // Visible for testing
  /**
   * Gets the localization information used in this pattern.
   * @internal
   */
  readonly FormatInfo: NodaFormatInfo;

  private readonly _templateValue: OffsetDate;

  /**
   * Gets the value used as a template for parsing: any field values unspecified
   * in the pattern are taken from the template.
   */
  get TemplateValue(): OffsetDate {
    return this._templateValue;
  }

  private readonly _twoDigitYearMax: number;

  /**
   * Maximum two-digit-year in the template to treat as the current century.
   * If the value parsed is higher than this, the result is adjusted to the previous century.
   * This value defaults to 30. To create a pattern with a different value, use {@link OffsetDatePattern.WithTwoDigitYearMax}.
   * The value is in the range 0-99 inclusive.
   */
  get TwoDigitYearMax(): number {
    return this._twoDigitYearMax;
  }

  private constructor(patternText: string, formatInfo: NodaFormatInfo, templateValue: OffsetDate, twoDigitYearMax: number,
    pattern: IPattern<OffsetDate>) {
    this._patternText = patternText;
    this.FormatInfo = formatInfo;
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
  Parse(text: string): ParseResult<OffsetDate> {
    return this._pattern.Parse(text);
  }

  /**
   * Formats the given offset date as text according to the rules of this pattern.
   * @param value The offset date to format.
   * @returns The offset date formatted according to this pattern.
   */
  Format(value: OffsetDate): string {
    return this._pattern.Format(value);
  }

  /**
   * Formats the given value as text according to the rules of this pattern,
   * appending to the given {@link StringBuilder}.
   * @param value The value to format.
   * @param builder The `StringBuilder` to append to.
   * @returns The builder passed in as `builder`.
   */
  AppendFormat(value: OffsetDate, builder: StringBuilder): StringBuilder {
    return this._pattern.AppendFormat(value, builder);
  }

  /**
   * Creates a pattern for the given pattern text, culture, and template value.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @param cultureInfo The culture to use in the pattern
   * @param templateValue Template value to use for unspecified fields
   * @returns A pattern for parsing and formatting local dates.
   * @throws {InvalidPatternError} The pattern text was invalid.
   */
  static Create(patternText: string, cultureInfo: NodaCultureInfo, templateValue: OffsetDate): OffsetDatePattern;
  /**
   * Creates a pattern for the given pattern text, format info, and template value.
   * @param patternText Pattern text to create the pattern for
   * @param formatInfo The format info to use in the pattern
   * @param templateValue Template value to use for unspecified fields
   * @param twoDigitYearMax Maximum two-digit-year in the template to treat as the current century.
   * @returns A pattern for parsing and formatting offset dates.
   * @throws {InvalidPatternError} The pattern text was invalid.
   * @internal
   */
  static Create(patternText: string, formatInfo: NodaFormatInfo, templateValue: OffsetDate, twoDigitYearMax: number): OffsetDatePattern;
  static Create(patternText: string, cultureOrFormatInfo: NodaCultureInfo | NodaFormatInfo, templateValue: OffsetDate, twoDigitYearMax?: number): OffsetDatePattern {
    if (cultureOrFormatInfo instanceof NodaFormatInfo) {
      const formatInfo = cultureOrFormatInfo;
      Preconditions.CheckNotNull(patternText, "patternText");
      Preconditions.CheckNotNull(formatInfo, "formatInfo");
      const pattern = new OffsetDatePatternParser(templateValue, twoDigitYearMax!).ParsePattern(patternText, formatInfo);
      return new OffsetDatePattern(patternText, formatInfo, templateValue, twoDigitYearMax!, pattern);
    }
    return OffsetDatePattern.Create(patternText, NodaFormatInfo.GetFormatInfo(cultureOrFormatInfo), templateValue, LocalDatePattern.DefaultTwoDigitYearMax);
  }

  /**
   * Creates a pattern for the given pattern text in the invariant culture, using the default
   * template value of midnight January 1st 2000 at an offset of 0.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @returns A pattern for parsing and formatting local dates.
   * @throws {InvalidPatternError} The pattern text was invalid.
   */
  static CreateWithInvariantCulture(patternText: string): OffsetDatePattern {
    return OffsetDatePattern.Create(patternText, NodaFormatInfo.InvariantInfo, OffsetDatePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);
  }

  // Not ported: CreateWithCurrentCulture (there is no current culture in JavaScript; use create with an explicit culture)

  /**
   * Creates a pattern for the same original localization information as this pattern, but with the specified
   * pattern text.
   * @param patternText The pattern text to use in the new pattern.
   * @returns A new pattern with the given pattern text.
   */
  WithPatternText(patternText: string): OffsetDatePattern {
    return OffsetDatePattern.Create(patternText, this.FormatInfo, this.TemplateValue, this.TwoDigitYearMax);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * localization information.
   * @param formatInfo The localization information to use in the new pattern.
   * @returns A new pattern with the given localization information.
   */
  private WithFormatInfo(formatInfo: NodaFormatInfo): OffsetDatePattern {
    return OffsetDatePattern.Create(this.PatternText, formatInfo, this.TemplateValue, this.TwoDigitYearMax);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * culture.
   * @param cultureInfo The culture to use in the new pattern.
   * @returns A new pattern with the given culture.
   */
  WithCulture(cultureInfo: NodaCultureInfo): OffsetDatePattern {
    return this.WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));
  }

  /**
   * Creates a pattern for the same original pattern text and culture as this pattern, but with
   * the specified template value.
   * @param newTemplateValue The template value to use in the new pattern.
   * @returns A new pattern with the given template value.
   */
  WithTemplateValue(newTemplateValue: OffsetDate): OffsetDatePattern {
    return OffsetDatePattern.Create(this.PatternText, this.FormatInfo, newTemplateValue, this.TwoDigitYearMax);
  }

  /**
   * Creates a pattern like this one, but with the template value modified to use
   * the specified calendar system.
   *
   * Care should be taken in two (relatively rare) scenarios. Although the default template value
   * is supported by all Noda Time calendar systems, if a pattern is created with a different
   * template value and then this method is called with a calendar system which doesn't support that
   * date, an exception will be thrown. Additionally, if the pattern only specifies some date fields,
   * it's possible that the new template value will not be suitable for all values.
   * @param calendar The calendar system to convert the template value into.
   * @returns A new pattern with a template value in the specified calendar system.
   */
  WithCalendar(calendar: CalendarSystem): OffsetDatePattern {
    return this.WithTemplateValue(this.TemplateValue.WithCalendar(calendar));
  }

  /**
   * Creates a pattern like this one, but with a different {@link OffsetDatePattern.TwoDigitYearMax} value.
   * @param twoDigitYearMax The value to use for {@link OffsetDatePattern.TwoDigitYearMax} in the new pattern, in the range 0-99 inclusive.
   * @returns A new pattern with the specified maximum two-digit-year.
   */
  WithTwoDigitYearMax(twoDigitYearMax: number): OffsetDatePattern {
    return OffsetDatePattern.Create(this.PatternText, this.FormatInfo, this.TemplateValue, twoDigitYearMax);
  }
}
