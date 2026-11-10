// Ported from NodaTime 3.3.7: src/NodaTime/Text/ZonedDateTimePattern.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { LocalDatePattern, LocalDateTime, NodaFormatInfo, PatternBclSupport, Preconditions, Resolvers, ZonedDateTimePatternParser } from "../internal.ts";
import type {
  CalendarSystem,
  NodaCultureInfo,
  IDateTimeZoneProvider,
  IPattern,
  ParseResult,
  StringBuilder,
  ZoneLocalMappingResolver,
  ZonedDateTime,
} from "../internal.ts";

let defaultTemplateValue: ZonedDateTime | undefined;
let generalFormatOnlyPatternImpl: ZonedDateTimePattern | undefined;
let extendedFormatOnlyPatternImpl: ZonedDateTimePattern | undefined;
let bclSupport: PatternBclSupport<ZonedDateTime> | undefined;

/**
 * Class whose existence is solely to avoid type initialization order issues, most of which stem
 * from needing NodaFormatInfo.InvariantInfo...
 * @internal
 */
export class ZonedDateTimePatternPatterns {
  static get GeneralFormatOnlyPatternImpl(): ZonedDateTimePattern {
    return (generalFormatOnlyPatternImpl ??= ZonedDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss z '('o<g>')'", null));
  }
  static get ExtendedFormatOnlyPatternImpl(): ZonedDateTimePattern {
    return (extendedFormatOnlyPatternImpl ??= ZonedDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF z '('o<g>')'", null));
  }
  static get BclSupport(): PatternBclSupport<ZonedDateTime> {
    return (bclSupport ??= new PatternBclSupport<ZonedDateTime>("G", fi => fi.ZonedDateTimePatternParser));
  }
}

/**
 * Represents a pattern for parsing and formatting {@link ZonedDateTime} values.
 *
 * Thread safety: When used with a read-only {@link NodaCultureInfo}, this type is immutable and instances
 * may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
 * not currently enforced.
 */
export class ZonedDateTimePattern implements IPattern<ZonedDateTime> {
  /** @internal */
  static get DefaultTemplateValue(): ZonedDateTime {
    return (defaultTemplateValue ??= new LocalDateTime(2000, 1, 1, 0, 0).InUtc());
  }

  /**
   * Gets an zoned local date/time pattern based on ISO-8601 (down to the second) including offset from UTC and zone ID.
   * It corresponds to a custom pattern of "uuuu'-'MM'-'dd'T'HH':'mm':'ss z '('o<g>')'" and is available
   * as the 'G' standard pattern.
   *
   * The calendar system is not formatted as part of this pattern, and it cannot be used for parsing as no time zone
   * provider is included. Call {@link ZonedDateTimePattern.WithZoneProvider} on the value of this property to obtain a
   * pattern which can be used for parsing.
   */
  static get GeneralFormatOnlyIso(): ZonedDateTimePattern {
    return ZonedDateTimePatternPatterns.GeneralFormatOnlyPatternImpl;
  }

  /**
   * Returns an invariant zoned date/time pattern based on ISO-8601 (down to the nanosecond) including offset from UTC and zone ID.
   * It corresponds to a custom pattern of "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF z '('o<g>')'" and is available
   * as the 'F' standard pattern.
   *
   * The calendar system is not formatted as part of this pattern, and it cannot be used for parsing as no time zone
   * provider is included. Call {@link ZonedDateTimePattern.WithZoneProvider} on the value of this property to obtain a
   * pattern which can be used for parsing.
   */
  static get ExtendedFormatOnlyIso(): ZonedDateTimePattern {
    return ZonedDateTimePatternPatterns.ExtendedFormatOnlyPatternImpl;
  }

  private readonly _pattern: IPattern<ZonedDateTime>;

  /** @internal */
  static readonly Patterns = ZonedDateTimePatternPatterns;

  /** @internal Equivalent of ZonedDateTimePattern.Patterns.BclSupport. */
  static get BclSupport(): PatternBclSupport<ZonedDateTime> {
    return ZonedDateTimePatternPatterns.BclSupport;
  }

  private readonly _patternText: string;

  /** Gets the pattern text for this pattern, as supplied on creation. */
  get PatternText(): string {
    return this._patternText;
  }

  /** Gets the localization information used in this pattern. */
  private readonly _formatInfo: NodaFormatInfo;

  private readonly _templateValue: ZonedDateTime;

  /**
   * Gets the value used as a template for parsing: any field values unspecified
   * in the pattern are taken from the template.
   */
  get TemplateValue(): ZonedDateTime {
    return this._templateValue;
  }

  private readonly _resolver: ZoneLocalMappingResolver | null;

  /**
   * Gets the resolver which is used to map local date/times to zoned date/times,
   * handling skipped and ambiguous times appropriately (where the offset isn't specified in the pattern).
   * This may be null, in which case the pattern can only be used for formatting (not parsing).
   */
  get Resolver(): ZoneLocalMappingResolver | null {
    return this._resolver;
  }

  private readonly _zoneProvider: IDateTimeZoneProvider | null;

  /**
   * Gets the provider which is used to look up time zones when parsing a pattern
   * which contains a time zone identifier. This may be null, in which case the pattern can
   * only be used for formatting (not parsing).
   */
  get ZoneProvider(): IDateTimeZoneProvider | null {
    return this._zoneProvider;
  }

  private readonly _twoDigitYearMax: number;

  /**
   * Maximum two-digit-year in the template to treat as the current century.
   * If the value parsed is higher than this, the result is adjusted to the previous century.
   * This value defaults to 30. To create a pattern with a different value, use {@link ZonedDateTimePattern.WithTwoDigitYearMax}.
   * The value is in the range 0-99 inclusive.
   */
  get TwoDigitYearMax(): number {
    return this._twoDigitYearMax;
  }

  private constructor(patternText: string, formatInfo: NodaFormatInfo, templateValue: ZonedDateTime,
    resolver: ZoneLocalMappingResolver | null, zoneProvider: IDateTimeZoneProvider | null, twoDigitYearMax: number, pattern: IPattern<ZonedDateTime>) {
    this._patternText = patternText;
    this._formatInfo = formatInfo;
    this._templateValue = templateValue;
    this._resolver = resolver;
    this._zoneProvider = zoneProvider;
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
  Parse(text: string): ParseResult<ZonedDateTime> {
    return this._pattern.Parse(text);
  }

  /**
   * Formats the given zoned date/time as text according to the rules of this pattern.
   * @param value The zoned date/time to format.
   * @returns The zoned date/time formatted according to this pattern.
   */
  Format(value: ZonedDateTime): string {
    return this._pattern.Format(value);
  }

  /**
   * Formats the given value as text according to the rules of this pattern,
   * appending to the given {@link StringBuilder}.
   * @param value The value to format.
   * @param builder The `StringBuilder` to append to.
   * @returns The builder passed in as `builder`.
   */
  AppendFormat(value: ZonedDateTime, builder: StringBuilder): StringBuilder {
    return this._pattern.AppendFormat(value, builder);
  }

  /**
   * Creates a pattern for the given pattern text, culture, resolver, time zone provider, and template value.
   *
   * See the user guide for the available pattern text options.
   * If `zoneProvider` is null, the resulting pattern can be used for formatting
   * but not parsing.
   * @param patternText Pattern text to create the pattern for
   * @param cultureInfo The culture to use in the pattern
   * @param resolver Resolver to apply when mapping local date/time values into the zone.
   * @param zoneProvider Time zone provider, used when parsing text which contains a time zone identifier.
   * @param templateValue Template value to use for unspecified fields
   * @returns A pattern for parsing and formatting zoned date/times.
   * @throws {InvalidPatternException} The pattern text was invalid.
   */
  static Create(patternText: string, cultureInfo: NodaCultureInfo,
    resolver: ZoneLocalMappingResolver | null, zoneProvider: IDateTimeZoneProvider | null, templateValue: ZonedDateTime): ZonedDateTimePattern;
  /**
   * Creates a pattern for the given pattern text, format info, template value, mapping resolver and time zone provider.
   * @param patternText Pattern text to create the pattern for
   * @param formatInfo The format info to use in the pattern
   * @param resolver Resolver to apply when mapping local date/time values into the zone.
   * @param zoneProvider Time zone provider, used when parsing text which contains a time zone identifier.
   * @param templateValue Template value to use for unspecified fields
   * @param twoDigitYearMax Maximum two-digit-year in the template to treat as the current century.
   * @returns A pattern for parsing and formatting zoned date/times.
   * @throws {InvalidPatternException} The pattern text was invalid.
   * @internal
   */
  static Create(patternText: string, formatInfo: NodaFormatInfo,
    resolver: ZoneLocalMappingResolver | null, zoneProvider: IDateTimeZoneProvider | null, templateValue: ZonedDateTime, twoDigitYearMax: number): ZonedDateTimePattern;
  static Create(patternText: string, cultureOrFormatInfo: NodaCultureInfo | NodaFormatInfo,
    resolver: ZoneLocalMappingResolver | null, zoneProvider: IDateTimeZoneProvider | null, templateValue: ZonedDateTime, twoDigitYearMax?: number): ZonedDateTimePattern {
    if (cultureOrFormatInfo instanceof NodaFormatInfo) {
      const formatInfo = cultureOrFormatInfo;
      Preconditions.CheckNotNull(patternText, "patternText");
      Preconditions.CheckNotNull(formatInfo, "formatInfo");
      const pattern = new ZonedDateTimePatternParser(templateValue, resolver, zoneProvider, twoDigitYearMax!).ParsePattern(patternText, formatInfo);
      return new ZonedDateTimePattern(patternText, formatInfo, templateValue, resolver, zoneProvider, twoDigitYearMax!, pattern);
    }
    return ZonedDateTimePattern.Create(patternText, NodaFormatInfo.GetFormatInfo(cultureOrFormatInfo), resolver, zoneProvider, templateValue, LocalDatePattern.DefaultTwoDigitYearMax);
  }

  /**
   * Creates a pattern for the given pattern text and time zone provider, using a strict resolver, the invariant
   * culture, and a default template value of midnight January 1st 2000 UTC.
   *
   * The resolver is only used if the pattern text doesn't include an offset.
   * If `zoneProvider` is null, the resulting pattern can be used for formatting
   * but not parsing.
   * @param patternText Pattern text to create the pattern for
   * @param zoneProvider Time zone provider, used when parsing text which contains a time zone identifier.
   * @returns A pattern for parsing and formatting zoned date/times.
   */
  static CreateWithInvariantCulture(patternText: string, zoneProvider: IDateTimeZoneProvider | null): ZonedDateTimePattern {
    return ZonedDateTimePattern.Create(patternText, NodaFormatInfo.InvariantInfo, Resolvers.StrictResolver, zoneProvider, ZonedDateTimePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);
  }

  // Not ported: CreateWithCurrentCulture (no current culture in JS)

  /**
   * Creates a pattern for the same original localization information as this pattern, but with the specified
   * pattern text.
   * @param patternText The pattern text to use in the new pattern.
   * @returns A new pattern with the given pattern text.
   */
  WithPatternText(patternText: string): ZonedDateTimePattern {
    return ZonedDateTimePattern.Create(patternText, this._formatInfo, this.Resolver, this.ZoneProvider, this.TemplateValue, this.TwoDigitYearMax);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * localization information.
   * @param formatInfo The localization information to use in the new pattern.
   * @returns A new pattern with the given localization information.
   */
  private WithFormatInfo(formatInfo: NodaFormatInfo): ZonedDateTimePattern {
    return ZonedDateTimePattern.Create(this.PatternText, formatInfo, this.Resolver, this.ZoneProvider, this.TemplateValue, this.TwoDigitYearMax);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * culture.
   * @param cultureInfo The culture to use in the new pattern.
   * @returns A new pattern with the given culture.
   */
  WithCulture(cultureInfo: NodaCultureInfo): ZonedDateTimePattern {
    return this.WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * resolver.
   * @param resolver The new local mapping resolver to use.
   * @returns A new pattern with the given resolver.
   */
  WithResolver(resolver: ZoneLocalMappingResolver | null): ZonedDateTimePattern {
    return this.Resolver === resolver ? this : ZonedDateTimePattern.Create(this.PatternText, this._formatInfo, resolver, this.ZoneProvider, this.TemplateValue, this.TwoDigitYearMax);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * time zone provider.
   *
   * If `newZoneProvider` is null, the resulting pattern can be used for formatting
   * but not parsing.
   * @param newZoneProvider The new time zone provider to use.
   * @returns A new pattern with the given time zone provider.
   */
  WithZoneProvider(newZoneProvider: IDateTimeZoneProvider | null): ZonedDateTimePattern {
    return newZoneProvider === this.ZoneProvider ? this : ZonedDateTimePattern.Create(this.PatternText, this._formatInfo, this.Resolver, newZoneProvider, this.TemplateValue, this.TwoDigitYearMax);
  }

  /**
   * Creates a pattern like this one, but with the specified template value.
   * @param newTemplateValue The template value for the new pattern, used to fill in unspecified fields.
   * @returns A new pattern with the given template value.
   */
  WithTemplateValue(newTemplateValue: ZonedDateTime): ZonedDateTimePattern {
    return newTemplateValue.Equals(this.TemplateValue) ? this : ZonedDateTimePattern.Create(this.PatternText, this._formatInfo, this.Resolver, this.ZoneProvider, newTemplateValue, this.TwoDigitYearMax);
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
  WithCalendar(calendar: CalendarSystem): ZonedDateTimePattern {
    return this.WithTemplateValue(this.TemplateValue.WithCalendar(calendar));
  }

  /**
   * Creates a pattern like this one, but with a different {@link ZonedDateTimePattern.TwoDigitYearMax} value.
   * @param twoDigitYearMax The value to use for {@link ZonedDateTimePattern.TwoDigitYearMax} in the new pattern, in the range 0-99 inclusive.
   * @returns A new pattern with the specified maximum two-digit-year.
   */
  WithTwoDigitYearMax(twoDigitYearMax: number): ZonedDateTimePattern {
    return ZonedDateTimePattern.Create(this.PatternText, this._formatInfo, this.Resolver, this.ZoneProvider, this.TemplateValue, twoDigitYearMax);
  }
}
