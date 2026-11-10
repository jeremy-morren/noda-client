// Ported from NodaTime 3.3.7: src/NodaTime/Text/OffsetDateTimePattern.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { LocalDatePattern, LocalDateTime, NodaFormatInfo, Offset, OffsetDateTimePatternParser, PatternBclSupport, Preconditions } from "../internal.ts";
import type { CalendarSystem, NodaCultureInfo, IPattern, OffsetDateTime, ParseResult, StringBuilder } from "../internal.ts";

let defaultTemplateValue: OffsetDateTime | undefined;
let generalIsoPatternImpl: OffsetDateTimePattern | undefined;
let extendedIsoPatternImpl: OffsetDateTimePattern | undefined;
let rfc3339PatternImpl: OffsetDateTimePattern | undefined;
let fullRoundtripPatternImpl: OffsetDateTimePattern | undefined;
let bclSupport: PatternBclSupport<OffsetDateTime> | undefined;

/**
 * Class whose existence is solely to avoid type initialization order issues, most of which stem
 * from needing NodaFormatInfo.InvariantInfo...
 * @internal
 */
export class OffsetDateTimePatternPatterns {
  static get GeneralIsoPatternImpl(): OffsetDateTimePattern {
    return (generalIsoPatternImpl ??= OffsetDateTimePattern.Create("uuuu'-'MM'-'dd'T'HH':'mm':'sso<G>", NodaFormatInfo.InvariantInfo, OffsetDateTimePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax));
  }
  static get ExtendedIsoPatternImpl(): OffsetDateTimePattern {
    return (extendedIsoPatternImpl ??= OffsetDateTimePattern.Create("uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G>", NodaFormatInfo.InvariantInfo, OffsetDateTimePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax));
  }
  static get Rfc3339PatternImpl(): OffsetDateTimePattern {
    return (rfc3339PatternImpl ??= OffsetDateTimePattern.Create("uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<Z+HH:mm>", NodaFormatInfo.InvariantInfo, OffsetDateTimePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax));
  }
  static get FullRoundtripPatternImpl(): OffsetDateTimePattern {
    return (fullRoundtripPatternImpl ??= OffsetDateTimePattern.Create("uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G> '('c')'", NodaFormatInfo.InvariantInfo, OffsetDateTimePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax));
  }
  static get BclSupport(): PatternBclSupport<OffsetDateTime> {
    return (bclSupport ??= new PatternBclSupport<OffsetDateTime>("G", fi => fi.OffsetDateTimePatternParser));
  }
}

/**
 * Represents a pattern for parsing and formatting {@link OffsetDateTime} values.
 *
 * Thread safety: When used with a read-only {@link NodaCultureInfo}, this type is immutable and instances
 * may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
 * not currently enforced.
 */
export class OffsetDateTimePattern implements IPattern<OffsetDateTime> {
  /** @internal */
  static get DefaultTemplateValue(): OffsetDateTime {
    return (defaultTemplateValue ??= new LocalDateTime(2000, 1, 1, 0, 0).WithOffset(Offset.Zero));
  }

  /**
   * Gets an invariant offset date/time pattern based on ISO-8601 (down to the second), including offset from UTC.
   *
   * The calendar system is not parsed or formatted as part of this pattern. It corresponds to a custom pattern of
   * "uuuu'-'MM'-'dd'T'HH':'mm':'sso<G>". This pattern is available as the "G"
   * standard pattern (even though it is invariant).
   */
  static get GeneralIso(): OffsetDateTimePattern {
    return OffsetDateTimePatternPatterns.GeneralIsoPatternImpl;
  }

  /**
   * Gets an invariant offset date/time pattern based on ISO-8601 (down to the nanosecond), including offset from UTC.
   *
   * The calendar system is not parsed or formatted as part of this pattern. It corresponds to a custom pattern of
   * "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G>". This will round-trip any values
   * in the ISO calendar, and is available as the "o" standard pattern.
   */
  static get ExtendedIso(): OffsetDateTimePattern {
    return OffsetDateTimePatternPatterns.ExtendedIsoPatternImpl;
  }

  /**
   * Gets an invariant offset date/time pattern based on RFC 3339 (down to the nanosecond), including offset from UTC
   * as hours and minutes only.
   *
   * The minutes part of the offset is always included, but any sub-minute component
   * of the offset is lost. An offset of zero is formatted as 'Z', but all of 'Z', '+00:00' and '-00:00' are parsed
   * the same way. The RFC 3339 meaning of '-00:00' is not supported by Noda Time.
   * Note that parsing is case-sensitive (so 'T' and 'Z' must be upper case).
   * The calendar system is not parsed or formatted as part of this pattern. It corresponds to a custom pattern of
   * "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<Z+HH:mm>".
   */
  static get Rfc3339(): OffsetDateTimePattern {
    return OffsetDateTimePatternPatterns.Rfc3339PatternImpl;
  }

  /**
   * Gets an invariant offset date/time pattern based on ISO-8601 (down to the nanosecond)
   * including offset from UTC and calendar ID.
   *
   * The returned pattern corresponds to a custom pattern of
   * "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G> '('c')'". This will round-trip any value in any calendar,
   * and is available as the "r" standard pattern.
   */
  static get FullRoundtrip(): OffsetDateTimePattern {
    return OffsetDateTimePatternPatterns.FullRoundtripPatternImpl;
  }

  /** @internal */
  static readonly Patterns = OffsetDateTimePatternPatterns;

  /** @internal Equivalent of OffsetDateTimePattern.Patterns.BclSupport. */
  static get BclSupport(): PatternBclSupport<OffsetDateTime> {
    return OffsetDateTimePatternPatterns.BclSupport;
  }

  private readonly _pattern: IPattern<OffsetDateTime>;

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

  private readonly _templateValue: OffsetDateTime;

  /**
   * Gets the value used as a template for parsing: any field values unspecified
   * in the pattern are taken from the template.
   */
  get TemplateValue(): OffsetDateTime {
    return this._templateValue;
  }

  private readonly _twoDigitYearMax: number;

  /**
   * Maximum two-digit-year in the template to treat as the current century.
   * If the value parsed is higher than this, the result is adjusted to the previous century.
   * This value defaults to 30. To create a pattern with a different value, use {@link OffsetDateTimePattern.WithTwoDigitYearMax}.
   * The value is in the range 0-99 inclusive.
   */
  get TwoDigitYearMax(): number {
    return this._twoDigitYearMax;
  }

  private constructor(patternText: string, formatInfo: NodaFormatInfo, templateValue: OffsetDateTime, twoDigitYearMax: number,
    pattern: IPattern<OffsetDateTime>) {
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
  Parse(text: string): ParseResult<OffsetDateTime> {
    return this._pattern.Parse(text);
  }

  /**
   * Formats the given offset date/time as text according to the rules of this pattern.
   * @param value The offset date/time to format.
   * @returns The offset date/time formatted according to this pattern.
   */
  Format(value: OffsetDateTime): string {
    return this._pattern.Format(value);
  }

  /**
   * Formats the given value as text according to the rules of this pattern,
   * appending to the given {@link StringBuilder}.
   * @param value The value to format.
   * @param builder The `StringBuilder` to append to.
   * @returns The builder passed in as `builder`.
   */
  AppendFormat(value: OffsetDateTime, builder: StringBuilder): StringBuilder {
    return this._pattern.AppendFormat(value, builder);
  }

  /**
   * Creates a pattern for the given pattern text, culture, and template value.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @param cultureInfo The culture to use in the pattern
   * @param templateValue Template value to use for unspecified fields
   * @returns A pattern for parsing and formatting local date/times.
   * @throws {InvalidPatternException} The pattern text was invalid.
   */
  static Create(patternText: string, cultureInfo: NodaCultureInfo, templateValue: OffsetDateTime): OffsetDateTimePattern;
  /**
   * Creates a pattern for the given pattern text, format info, and template value.
   * @param patternText Pattern text to create the pattern for
   * @param formatInfo The format info to use in the pattern
   * @param templateValue Template value to use for unspecified fields
   * @param twoDigitYearMax Maximum two-digit-year in the template to treat as the current century.
   * @returns A pattern for parsing and formatting offset date/times.
   * @throws {InvalidPatternException} The pattern text was invalid.
   * @internal
   */
  static Create(patternText: string, formatInfo: NodaFormatInfo, templateValue: OffsetDateTime, twoDigitYearMax: number): OffsetDateTimePattern;
  static Create(patternText: string, cultureOrFormatInfo: NodaCultureInfo | NodaFormatInfo, templateValue: OffsetDateTime, twoDigitYearMax?: number): OffsetDateTimePattern {
    if (cultureOrFormatInfo instanceof NodaFormatInfo) {
      const formatInfo = cultureOrFormatInfo;
      Preconditions.CheckNotNull(patternText, "patternText");
      Preconditions.CheckNotNull(formatInfo, "formatInfo");
      const pattern = new OffsetDateTimePatternParser(templateValue, twoDigitYearMax!).ParsePattern(patternText, formatInfo);
      return new OffsetDateTimePattern(patternText, formatInfo, templateValue, twoDigitYearMax!, pattern);
    }
    return OffsetDateTimePattern.Create(patternText, NodaFormatInfo.GetFormatInfo(cultureOrFormatInfo), templateValue, LocalDatePattern.DefaultTwoDigitYearMax);
  }

  /**
   * Creates a pattern for the given pattern text in the invariant culture, using the default
   * template value of midnight January 1st 2000 at an offset of 0.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @returns A pattern for parsing and formatting local date/times.
   * @throws {InvalidPatternException} The pattern text was invalid.
   */
  static CreateWithInvariantCulture(patternText: string): OffsetDateTimePattern {
    return OffsetDateTimePattern.Create(patternText, NodaFormatInfo.InvariantInfo, OffsetDateTimePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);
  }

  // Not ported: CreateWithCurrentCulture (no current culture in JS)

  /**
   * Creates a pattern for the same original localization information as this pattern, but with the specified
   * pattern text.
   * @param patternText The pattern text to use in the new pattern.
   * @returns A new pattern with the given pattern text.
   */
  WithPatternText(patternText: string): OffsetDateTimePattern {
    return OffsetDateTimePattern.Create(patternText, this.FormatInfo, this.TemplateValue, this.TwoDigitYearMax);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * localization information.
   * @param formatInfo The localization information to use in the new pattern.
   * @returns A new pattern with the given localization information.
   */
  private WithFormatInfo(formatInfo: NodaFormatInfo): OffsetDateTimePattern {
    return OffsetDateTimePattern.Create(this.PatternText, formatInfo, this.TemplateValue, this.TwoDigitYearMax);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * culture.
   * @param cultureInfo The culture to use in the new pattern.
   * @returns A new pattern with the given culture.
   */
  WithCulture(cultureInfo: NodaCultureInfo): OffsetDateTimePattern {
    return this.WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));
  }

  /**
   * Creates a pattern for the same original pattern text and culture as this pattern, but with
   * the specified template value.
   * @param newTemplateValue The template value to use in the new pattern.
   * @returns A new pattern with the given template value.
   */
  WithTemplateValue(newTemplateValue: OffsetDateTime): OffsetDateTimePattern {
    return OffsetDateTimePattern.Create(this.PatternText, this.FormatInfo, newTemplateValue, this.TwoDigitYearMax);
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
  WithCalendar(calendar: CalendarSystem): OffsetDateTimePattern {
    return this.WithTemplateValue(this.TemplateValue.WithCalendar(calendar));
  }

  /**
   * Creates a pattern like this one, but with a different {@link OffsetDateTimePattern.TwoDigitYearMax} value.
   * @param twoDigitYearMax The value to use for {@link OffsetDateTimePattern.TwoDigitYearMax} in the new pattern, in the range 0-99 inclusive.
   * @returns A new pattern with the specified maximum two-digit-year.
   */
  WithTwoDigitYearMax(twoDigitYearMax: number): OffsetDateTimePattern {
    return OffsetDateTimePattern.Create(this.PatternText, this.FormatInfo, this.TemplateValue, twoDigitYearMax);
  }
}
