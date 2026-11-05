// Ported from NodaTime 3.3.7: src/NodaTime/Text/LocalDateTimePattern.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CompositePatternBuilder,
  LocalDatePattern,
  LocalDateTime,
  LocalDateTimePatternParser,
  NodaFormatInfo,
  PatternBclSupport,
  Preconditions,
} from "../internal.ts";
import type { CalendarSystem, NodaCultureInfo, IPartialPattern, IPattern, ParseResult, StringBuilder } from "../internal.ts";

const DefaultFormatPattern = "G"; // General (long time)

let defaultTemplateValue: LocalDateTime | undefined;
let bclSupport: PatternBclSupport<LocalDateTime> | undefined;
let generalIsoPatternImpl: LocalDateTimePattern | undefined;
let extendedIsoPatternImpl: LocalDateTimePattern | undefined;
let bclRoundtripPatternImpl: LocalDateTimePattern | undefined;
let fullRoundtripWithoutCalendarImpl: LocalDateTimePattern | undefined;
let fullRoundtripPatternImpl: LocalDateTimePattern | undefined;
let dateHourIsoPatternImpl: LocalDateTimePattern | undefined;
let dateHourMinuteIsoPatternImpl: LocalDateTimePattern | undefined;
let variablePrecisionIsoPatternImpl: IPattern<LocalDateTime> | undefined;

/**
 * Class whose existence is solely to avoid type initialization order issues, most of which stem
 * from needing NodaFormatInfo.InvariantInfo...
 * (C#: LocalDateTimePattern.Patterns)
 * @internal
 */
export class LocalDateTimePatternPatterns {
  private constructor() {}

  static get GeneralIsoPatternImpl(): LocalDateTimePattern {
    return (generalIsoPatternImpl ??= LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss"));
  }
  static get ExtendedIsoPatternImpl(): LocalDateTimePattern {
    return (extendedIsoPatternImpl ??= LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF"));
  }
  static get BclRoundtripPatternImpl(): LocalDateTimePattern {
    return (bclRoundtripPatternImpl ??= LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss'.'fffffff"));
  }
  static get FullRoundtripWithoutCalendarImpl(): LocalDateTimePattern {
    return (fullRoundtripWithoutCalendarImpl ??= LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss'.'fffffffff"));
  }
  static get FullRoundtripPatternImpl(): LocalDateTimePattern {
    return (fullRoundtripPatternImpl ??= LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss'.'fffffffff '('c')'"));
  }
  static get DateHourIsoPatternImpl(): LocalDateTimePattern {
    return (dateHourIsoPatternImpl ??= LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH"));
  }
  static get DateHourMinuteIsoPatternImpl(): LocalDateTimePattern {
    return (dateHourMinuteIsoPatternImpl ??= LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm"));
  }
  static get VariablePrecisionIsoPatternImpl(): IPattern<LocalDateTime> {
    if (variablePrecisionIsoPatternImpl === undefined) {
      const builder = new CompositePatternBuilder<LocalDateTime>();
      builder.Add(LocalDateTimePatternPatterns.ExtendedIsoPatternImpl, (time) => true);
      builder.Add(LocalDateTimePatternPatterns.DateHourMinuteIsoPatternImpl, (time) => time.Second === 0 && time.NanosecondOfSecond === 0);
      builder.Add(LocalDateTimePatternPatterns.DateHourIsoPatternImpl, (time) => time.Minute === 0 && time.Second === 0 && time.NanosecondOfSecond === 0);
      variablePrecisionIsoPatternImpl = builder.Build();
    }
    return variablePrecisionIsoPatternImpl;
  }
}

/**
 * Represents a pattern for parsing and formatting {@link LocalDateTime} values.
 */
export class LocalDateTimePattern implements IPattern<LocalDateTime> {
  /** @internal */
  static get DefaultTemplateValue(): LocalDateTime {
    return (defaultTemplateValue ??= new LocalDateTime(2000, 1, 1, 0, 0));
  }

  /** @internal */
  static get BclSupport(): PatternBclSupport<LocalDateTime> {
    return (bclSupport ??= new PatternBclSupport<LocalDateTime>(DefaultFormatPattern, (fi) => fi.LocalDateTimePatternParser));
  }

  /**
   * Gets an invariant local date/time pattern which is ISO-8601 compatible, down to the second.
   * This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH':'mm':'ss".
   *
   * This pattern corresponds to the 's' standard pattern ("shorter sortable").
   */
  static get GeneralIso(): LocalDateTimePattern {
    return LocalDateTimePatternPatterns.GeneralIsoPatternImpl;
  }

  /**
   * Gets an invariant local date/time pattern which is ISO-8601 compatible, providing up to 9 decimal places
   * of sub-second accuracy. (These digits are omitted when unnecessary.)
   * This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF".
   *
   * This pattern corresponds to the 'S' standard pattern ("longer sortable").
   */
  static get ExtendedIso(): LocalDateTimePattern {
    return LocalDateTimePatternPatterns.ExtendedIsoPatternImpl;
  }

  /**
   * Gets an invariant local date/time pattern which is ISO-8601 compatible, providing up to 7 decimal places
   * of sub-second accuracy which are always present (including trailing zeroes). This is compatible with the
   * BCL round-trip formatting of DateTime values with a kind of "unspecified".
   * This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH':'mm':'ss'.'fffffff". It does not necessarily
   * round-trip all `LocalDateTime` values as it will lose sub-tick information. Use
   * {@link FullRoundtripWithoutCalendar} for full precision.
   *
   * This pattern corresponds to the 'o' and 'O' standard patterns.
   */
  static get BclRoundtrip(): LocalDateTimePattern {
    return LocalDateTimePatternPatterns.BclRoundtripPatternImpl;
  }

  /**
   * Gets an invariant local date/time pattern which round trips values, but doesn't include the calendar system.
   * It provides up to 9 decimal places of sub-second accuracy which are always present (including trailing zeroes).
   * This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH':'mm':'ss'.'fffffffff". It will
   * round-trip all {@link LocalDateTime} values if the calendar system of the template value is the same
   * as the calendar system of the original value.
   *
   * This pattern corresponds to the 'r' standard pattern.
   */
  static get FullRoundtripWithoutCalendar(): LocalDateTimePattern {
    return LocalDateTimePatternPatterns.FullRoundtripWithoutCalendarImpl;
  }

  /**
   * Gets an invariant local date/time pattern which round trips values including the calendar system.
   * This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH':'mm':'ss'.'fffffffff '('c')'".
   *
   * This pattern corresponds to the 'R' standard pattern.
   */
  static get FullRoundtrip(): LocalDateTimePattern {
    return LocalDateTimePatternPatterns.FullRoundtripPatternImpl;
  }

  /**
   * Gets an invariant local date/time pattern which is ISO-8601 compatible, with precision of just minutes.
   * This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH':'mm".
   */
  static get DateHourMinuteIso(): LocalDateTimePattern {
    return LocalDateTimePatternPatterns.DateHourMinuteIsoPatternImpl;
  }

  /**
   * Gets an invariant local date/time pattern which is ISO-8601 compatible, with a precision of just hours.
   * This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH".
   */
  static get DateHourIso(): LocalDateTimePattern {
    return LocalDateTimePatternPatterns.DateHourIsoPatternImpl;
  }

  /**
   * Gets an invariant local date/time pattern which can parse any ISO-8601 compatible value with a calendar date
   * (in extended format, that is, with separators), regardless of precision in the time part.
   * Valid values for time include "just hours", "hours and minutes", "hours, minutes and seconds",
   * and values with fractions of seconds (as far as nanoseconds). The time part must be present, however; this pattern
   * will not parse date-only values. (It will also not parse ordinal dates or week dates, as described in ISO-8601.)
   *
   * This is expressed as an {@link IPattern} rather than a {@link LocalDateTimePattern},
   * as it has no single pattern text.
   */
  static get VariablePrecisionIso(): IPattern<LocalDateTime> {
    return LocalDateTimePatternPatterns.VariablePrecisionIsoPatternImpl;
  }

  /**
   * Class whose existence is solely to avoid type initialization order issues.
   * @internal
   */
  static readonly Patterns = LocalDateTimePatternPatterns;

  private readonly _patternText: string;

  /** Gets the pattern text for this pattern, as supplied on creation. */
  get PatternText(): string {
    return this._patternText;
  }

  /** Gets the localization information used in this pattern. */
  private readonly _formatInfo: NodaFormatInfo;

  private readonly _templateValue: LocalDateTime;

  /**
   * Gets the value used as a template for parsing: any field values unspecified
   * in the pattern are taken from the template.
   */
  get TemplateValue(): LocalDateTime {
    return this._templateValue;
  }

  private readonly _twoDigitYearMax: number;

  /**
   * Maximum two-digit-year in the template to treat as the current century.
   * If the value parsed is higher than this, the result is adjusted to the previous century.
   * This value defaults to 30. To create a pattern with a different value, use {@link WithTwoDigitYearMax}.
   * The value is in the range 0-99 inclusive.
   */
  get TwoDigitYearMax(): number {
    return this._twoDigitYearMax;
  }

  /**
   * Returns the pattern that this object delegates to. Mostly useful to avoid this public class
   * implementing an internal interface.
   * @internal
   */
  readonly UnderlyingPattern: IPartialPattern<LocalDateTime>;

  private constructor(
    patternText: string,
    formatInfo: NodaFormatInfo,
    templateValue: LocalDateTime,
    twoDigitYearMax: number,
    pattern: IPartialPattern<LocalDateTime>,
  ) {
    this._patternText = patternText;
    this._formatInfo = formatInfo;
    this.UnderlyingPattern = pattern;
    this._templateValue = templateValue;
    this._twoDigitYearMax = twoDigitYearMax;
  }

  /**
   * Parses the given text value according to the rules of this pattern.
   *
   * This method never throws an exception (barring a bug in Noda Time itself). Even errors such as
   * the argument being null are wrapped in a parse result.
   * @param text The text value to parse.
   * @returns The result of parsing, which may be successful or unsuccessful.
   */
  Parse(text: string): ParseResult<LocalDateTime> {
    return this.UnderlyingPattern.Parse(text);
  }

  /**
   * Formats the given local date/time as text according to the rules of this pattern.
   * @param value The local date/time to format.
   * @returns The local date/time formatted according to this pattern.
   */
  Format(value: LocalDateTime): string {
    return this.UnderlyingPattern.Format(value);
  }

  /**
   * Formats the given value as text according to the rules of this pattern,
   * appending to the given {@link StringBuilder}.
   * @param value The value to format.
   * @param builder The `StringBuilder` to append to.
   * @returns The builder passed in as `builder`.
   */
  AppendFormat(value: LocalDateTime, builder: StringBuilder): StringBuilder {
    return this.UnderlyingPattern.AppendFormat(value, builder);
  }

  /**
   * Creates a pattern for the given pattern text, culture, and template value.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @param cultureInfo The culture to use in the pattern
   * @param templateValue Template value to use for unspecified fields; defaults to midnight on 2000-01-01.
   * @returns A pattern for parsing and formatting local date/times.
   * @throws {InvalidPatternException} The pattern text was invalid.
   */
  static Create(patternText: string, cultureInfo: NodaCultureInfo, templateValue?: LocalDateTime): LocalDateTimePattern;
  /**
   * Creates a pattern for the given pattern text, format info, template value and maximum two-digit-year.
   * @param patternText Pattern text to create the pattern for
   * @param formatInfo The format info to use in the pattern
   * @param templateValue Template value to use for unspecified fields
   * @param twoDigitYearMax Maximum two-digit-year in the template to treat as the current century.
   * @returns A pattern for parsing and formatting local date/times.
   * @throws {InvalidPatternException} The pattern text was invalid.
   * @internal
   */
  static Create(patternText: string, formatInfo: NodaFormatInfo, templateValue: LocalDateTime, twoDigitYearMax: number): LocalDateTimePattern;
  static Create(
    patternText: string,
    cultureOrFormatInfo: NodaCultureInfo | NodaFormatInfo,
    templateValue?: LocalDateTime,
    twoDigitYearMax?: number,
  ): LocalDateTimePattern {
    if (!(cultureOrFormatInfo instanceof NodaFormatInfo)) {
      return LocalDateTimePattern.Create(
        patternText,
        NodaFormatInfo.GetFormatInfo(cultureOrFormatInfo),
        templateValue ?? LocalDateTimePattern.DefaultTemplateValue,
        LocalDatePattern.DefaultTwoDigitYearMax,
      );
    }
    const formatInfo = cultureOrFormatInfo;
    Preconditions.CheckNotNull(patternText, "patternText");
    Preconditions.CheckNotNull(formatInfo, "formatInfo");
    // Use the "fixed" parser for the common case of the default template value.
    let pattern: IPattern<LocalDateTime> =
      templateValue!.Equals(LocalDateTimePattern.DefaultTemplateValue) && twoDigitYearMax === LocalDatePattern.DefaultTwoDigitYearMax
        ? formatInfo.LocalDateTimePatternParser.ParsePattern(patternText)
        : new LocalDateTimePatternParser(templateValue!, twoDigitYearMax!).ParsePattern(patternText, formatInfo);
    // If ParsePattern returns a standard pattern instance, we need to get the underlying partial pattern.
    pattern = pattern instanceof LocalDateTimePattern ? pattern.UnderlyingPattern : pattern;
    const partialPattern = pattern as IPartialPattern<LocalDateTime>;
    return new LocalDateTimePattern(patternText, formatInfo, templateValue!, twoDigitYearMax!, partialPattern);
  }

  // Not ported: CreateWithCurrentCulture (there is no current culture in JavaScript)

  /**
   * Creates a pattern for the given pattern text in the invariant culture.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @returns A pattern for parsing and formatting local date/times.
   * @throws {InvalidPatternException} The pattern text was invalid.
   */
  static CreateWithInvariantCulture(patternText: string): LocalDateTimePattern {
    return LocalDateTimePattern.Create(
      patternText,
      NodaFormatInfo.InvariantInfo,
      LocalDateTimePattern.DefaultTemplateValue,
      LocalDatePattern.DefaultTwoDigitYearMax,
    );
  }

  /**
   * Creates a pattern for the same original localization information as this pattern, but with the specified
   * pattern text.
   * @param formatInfo The localization information to use in the new pattern.
   * @returns A new pattern with the given localization information.
   */
  private WithFormatInfo(formatInfo: NodaFormatInfo): LocalDateTimePattern {
    return LocalDateTimePattern.Create(this.PatternText, formatInfo, this.TemplateValue, this.TwoDigitYearMax);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * culture.
   * @param cultureInfo The culture to use in the new pattern.
   * @returns A new pattern with the given culture.
   */
  WithCulture(cultureInfo: NodaCultureInfo): LocalDateTimePattern {
    return this.WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));
  }

  /**
   * Creates a pattern like this one, but with the specified template value.
   * @param newTemplateValue The template value for the new pattern, used to fill in unspecified fields.
   * @returns A new pattern with the given template value.
   */
  WithTemplateValue(newTemplateValue: LocalDateTime): LocalDateTimePattern {
    return LocalDateTimePattern.Create(this.PatternText, this._formatInfo, newTemplateValue, this.TwoDigitYearMax);
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
  WithCalendar(calendar: CalendarSystem): LocalDateTimePattern {
    return this.WithTemplateValue(this.TemplateValue.WithCalendar(calendar));
  }

  /**
   * Creates a pattern like this one, but with a different {@link TwoDigitYearMax} value.
   * @param twoDigitYearMax The value to use for {@link TwoDigitYearMax} in the new pattern, in the range 0-99 inclusive.
   * @returns A new pattern with the specified maximum two-digit-year.
   */
  WithTwoDigitYearMax(twoDigitYearMax: number): LocalDateTimePattern {
    return LocalDateTimePattern.Create(this.PatternText, this._formatInfo, this.TemplateValue, twoDigitYearMax);
  }
}
