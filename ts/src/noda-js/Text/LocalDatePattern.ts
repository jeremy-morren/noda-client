// Ported from NodaTime 3.3.7: src/NodaTime/Text/LocalDatePattern.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { LocalDate, LocalDatePatternParser, NodaFormatInfo, PatternBclSupport, Preconditions } from "../internal.ts";
import type { CalendarSystem, NodaCultureInfo, IPartialPattern, IPattern, ParseResult, StringBuilder } from "../internal.ts";

const DefaultFormatPattern = "D"; // Long

let defaultTemplateValue: LocalDate | undefined;
let bclSupport: PatternBclSupport<LocalDate> | undefined;
let isoPatternImpl: LocalDatePattern | undefined;
let fullRoundtripPatternImpl: LocalDatePattern | undefined;

/**
 * Class whose existence is solely to avoid type initialization order issues, most of which stem
 * from needing NodaFormatInfo.InvariantInfo...
 * (C#: LocalDatePattern.Patterns)
 * @internal
 */
export class LocalDatePatternPatterns {
  private constructor() {}

  static get IsoPatternImpl(): LocalDatePattern {
    return (isoPatternImpl ??= LocalDatePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd"));
  }

  static get FullRoundtripPatternImpl(): LocalDatePattern {
    return (fullRoundtripPatternImpl ??= LocalDatePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd '('c')'"));
  }
}

/**
 * Represents a pattern for parsing and formatting {@link LocalDate} values.
 */
export class LocalDatePattern implements IPattern<LocalDate> {
  /**
   * Default value for {@link TwoDigitYearMax}.
   * @internal
   */
  static readonly DefaultTwoDigitYearMax = 30;

  /** @internal */
  static get DefaultTemplateValue(): LocalDate {
    return (defaultTemplateValue ??= new LocalDate(2000, 1, 1));
  }

  /** @internal */
  static get BclSupport(): PatternBclSupport<LocalDate> {
    return (bclSupport ??= new PatternBclSupport<LocalDate>(DefaultFormatPattern, (fi) => fi.LocalDatePatternParser));
  }

  /**
   * Gets an invariant local date pattern which is ISO-8601 compatible and which round trips values, but doesn't include the calendar system.
   * This corresponds to the text pattern "uuuu'-'MM'-'dd".
   *
   * This pattern corresponds to the 'R' standard pattern.
   */
  static get Iso(): LocalDatePattern {
    return LocalDatePatternPatterns.IsoPatternImpl;
  }

  /**
   * Gets an invariant local date pattern which round trips values including the calendar system.
   * This corresponds to the text pattern "uuuu'-'MM'-'dd '('c')'".
   *
   * This pattern corresponds to the 'r' standard pattern.
   */
  static get FullRoundtrip(): LocalDatePattern {
    return LocalDatePatternPatterns.FullRoundtripPatternImpl;
  }

  /**
   * Class whose existence is solely to avoid type initialization order issues.
   * @internal
   */
  static readonly Patterns = LocalDatePatternPatterns;

  /**
   * Returns the pattern that this object delegates to. Mostly useful to avoid this public class
   * implementing an internal interface.
   * @internal
   */
  readonly UnderlyingPattern: IPartialPattern<LocalDate>;

  private readonly _patternText: string;

  /** Gets the pattern text for this pattern, as supplied on creation. */
  get PatternText(): string {
    return this._patternText;
  }

  /** Returns the localization information used in this pattern. */
  private readonly _formatInfo: NodaFormatInfo;

  private readonly _templateValue: LocalDate;

  /**
   * Gets the value used as a template for parsing: any field values unspecified
   * in the pattern are taken from the template.
   */
  get TemplateValue(): LocalDate {
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

  private constructor(
    patternText: string,
    formatInfo: NodaFormatInfo,
    templateValue: LocalDate,
    twoDigitYearMax: number,
    pattern: IPartialPattern<LocalDate>,
  ) {
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
  Parse(text: string): ParseResult<LocalDate> {
    return this.UnderlyingPattern.Parse(text);
  }

  /**
   * Formats the given local date as text according to the rules of this pattern.
   * @param value The local date to format.
   * @returns The local date formatted according to this pattern.
   */
  Format(value: LocalDate): string {
    return this.UnderlyingPattern.Format(value);
  }

  /**
   * Formats the given value as text according to the rules of this pattern,
   * appending to the given {@link StringBuilder}.
   * @param value The value to format.
   * @param builder The `StringBuilder` to append to.
   * @returns The builder passed in as `builder`.
   */
  AppendFormat(value: LocalDate, builder: StringBuilder): StringBuilder {
    return this.UnderlyingPattern.AppendFormat(value, builder);
  }

  /**
   * Creates a pattern for the given pattern text, culture, and template value.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @param cultureInfo The culture to use in the pattern
   * @param templateValue Template value to use for unspecified fields; defaults to 2000-01-01.
   * @returns A pattern for parsing and formatting local dates.
   * @throws {InvalidPatternException} The pattern text was invalid.
   */
  static Create(patternText: string, cultureInfo: NodaCultureInfo, templateValue?: LocalDate): LocalDatePattern;
  /**
   * Creates a pattern for the given pattern text, format info, and template value.
   * @param patternText Pattern text to create the pattern for
   * @param formatInfo The format info to use in the pattern
   * @param templateValue Template value to use for unspecified fields
   * @param twoDigitYearMax Maximum two-digit-year in the template to treat as the current century.
   * @returns A pattern for parsing and formatting local dates.
   * @throws {InvalidPatternException} The pattern text was invalid.
   * @internal
   */
  static Create(patternText: string, formatInfo: NodaFormatInfo, templateValue: LocalDate, twoDigitYearMax: number): LocalDatePattern;
  static Create(
    patternText: string,
    cultureOrFormatInfo: NodaCultureInfo | NodaFormatInfo,
    templateValue?: LocalDate,
    twoDigitYearMax?: number,
  ): LocalDatePattern {
    if (!(cultureOrFormatInfo instanceof NodaFormatInfo)) {
      return LocalDatePattern.Create(
        patternText,
        NodaFormatInfo.GetFormatInfo(cultureOrFormatInfo),
        templateValue ?? LocalDatePattern.DefaultTemplateValue,
        LocalDatePattern.DefaultTwoDigitYearMax,
      );
    }
    const formatInfo = cultureOrFormatInfo;
    Preconditions.CheckNotNull(patternText, "patternText");
    Preconditions.CheckNotNull(formatInfo, "formatInfo");
    // Use the "fixed" parser for the common case of the default template value.
    let pattern: IPattern<LocalDate> =
      templateValue!.Equals(LocalDatePattern.DefaultTemplateValue) && twoDigitYearMax === LocalDatePattern.DefaultTwoDigitYearMax
        ? formatInfo.LocalDatePatternParser.ParsePattern(patternText)
        : LocalDatePatternParser.NewTemplateValueTwoDigitYearMax(templateValue!, twoDigitYearMax!).ParsePattern(patternText, formatInfo);
    // If ParsePattern returns a standard pattern instance, we need to get the underlying partial pattern.
    pattern = pattern instanceof LocalDatePattern ? pattern.UnderlyingPattern : pattern;
    const partialPattern = pattern as IPartialPattern<LocalDate>;
    return new LocalDatePattern(patternText, formatInfo, templateValue!, twoDigitYearMax!, partialPattern);
  }

  // Not ported: CreateWithCurrentCulture (no current culture in JS)

  /**
   * Creates a pattern for the given pattern text in the invariant culture.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @returns A pattern for parsing and formatting local dates.
   * @throws {InvalidPatternException} The pattern text was invalid.
   */
  static CreateWithInvariantCulture(patternText: string): LocalDatePattern {
    return LocalDatePattern.Create(
      patternText,
      NodaFormatInfo.InvariantInfo,
      LocalDatePattern.DefaultTemplateValue,
      LocalDatePattern.DefaultTwoDigitYearMax,
    );
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * localization information.
   * @param formatInfo The localization information to use in the new pattern.
   * @returns A new pattern with the given localization information.
   */
  private WithFormatInfo(formatInfo: NodaFormatInfo): LocalDatePattern {
    return LocalDatePattern.Create(this.PatternText, formatInfo, this.TemplateValue, this.TwoDigitYearMax);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * culture.
   * @param cultureInfo The culture to use in the new pattern.
   * @returns A new pattern with the given culture.
   */
  WithCulture(cultureInfo: NodaCultureInfo): LocalDatePattern {
    return this.WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));
  }

  /**
   * Creates a pattern like this one, but with the specified template value.
   * @param newTemplateValue The template value for the new pattern, used to fill in unspecified fields.
   * @returns A new pattern with the given template value.
   */
  WithTemplateValue(newTemplateValue: LocalDate): LocalDatePattern {
    return LocalDatePattern.Create(this.PatternText, this._formatInfo, newTemplateValue, this.TwoDigitYearMax);
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
  WithCalendar(calendar: CalendarSystem): LocalDatePattern {
    return this.WithTemplateValue(this.TemplateValue.WithCalendar(calendar));
  }

  /**
   * Creates a pattern like this one, but with a different {@link TwoDigitYearMax} value.
   * @param twoDigitYearMax The value to use for {@link TwoDigitYearMax} in the new pattern, in the range 0-99 inclusive.
   * @returns A new pattern with the specified maximum two-digit-year.
   */
  WithTwoDigitYearMax(twoDigitYearMax: number): LocalDatePattern {
    return LocalDatePattern.Create(this.PatternText, this._formatInfo, this.TemplateValue, twoDigitYearMax);
  }
}
