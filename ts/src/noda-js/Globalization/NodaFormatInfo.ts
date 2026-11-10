// Ported from NodaTime 3.3.7: src/NodaTime/Globalization/NodaFormatInfo.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  AnnualDatePattern,
  AnnualDatePatternParser,
  NodaCultureInfo,
  DateTimeFormatInfo,
  DurationPatternParser,
  Era,
  FixedFormatInfoPatternParser,
  InstantPattern,
  InstantPatternParser,
  LocalDatePattern,
  LocalDatePatternParser,
  LocalDateTimePattern,
  LocalDateTimePatternParser,
  LocalTime,
  LocalTimePatternParser,
  OffsetDatePattern,
  OffsetDatePatternParser,
  OffsetDateTimePattern,
  OffsetDateTimePatternParser,
  OffsetPatternParser,
  OffsetTimePattern,
  OffsetTimePatternParser,
  Preconditions,
  Resolvers,
  YearMonthPattern,
  YearMonthPatternParser,
  ZonedDateTimePattern,
  ZonedDateTimePatternParser,
} from "../internal.ts";
import type {
  AnnualDate,
  CompareInfo,
  Duration,
  IFormatProvider,
  Instant,
  IPatternParser,
  LocalDate,
  LocalDateTime,
  Offset,
  OffsetDate,
  OffsetDateTime,
  OffsetTime,
  YearMonth,
  ZonedDateTime,
} from "../internal.ts";
import { NewArgumentException, type ArgumentException } from "../internal.ts";

// noda-js: no threads, so no lock: pattern parsers are created on first use. The per-culture cache is a WeakMap.
// Fields whose names would clash with the properties exposing them have a "Field" suffix.

// Names that we can use to check for broken Mono behaviour.
// The cloning is *also* to work around a Mono bug, where even read-only cultures can change...
// See https://xamarin.github.io/bugzilla-archives/32/3279/bug.html
// (noda-js: lazily initialized, as they come from another module.)
let shortInvariantMonthNames: readonly string[] | undefined;
let longInvariantMonthNames: readonly string[] | undefined;

let invariantInfo: NodaFormatInfo | undefined;

let cache = new WeakMap<NodaCultureInfo, NodaFormatInfo>();

/** Equivalent of C#'s int.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out _). */
function TryParseInvariantInt32(text: string): boolean {
  if (!/^\s*[+-]?[0-9]+\s*$/.test(text)) {
    return false;
  }
  const value = Number(text.trim());
  return value >= -2147483648 && value <= 2147483647;
}

/**
 * A {@link IFormatProvider} for Noda Time types, usually initialised from a {@link NodaCultureInfo}.
 * This provides a single place defining how NodaTime values are formatted and displayed, depending on the culture.
 *
 * Currently this is "shallow-immutable" - although none of these properties can be changed, the
 * CultureInfo itself may be mutable. If the CultureInfo is mutated after initialization, results are not
 * guaranteed: some aspects of the CultureInfo may be extracted at initialization time, others may be
 * extracted on first demand but cached, and others may be extracted on-demand each time.
 * @internal
 */
export class NodaFormatInfo {
  // #region Patterns
  private _durationPatternParserField: FixedFormatInfoPatternParser<Duration> | null = null;
  private _offsetPatternParserField: FixedFormatInfoPatternParser<Offset> | null = null;
  private _instantPatternParserField: FixedFormatInfoPatternParser<Instant> | null = null;
  private _localTimePatternParserField: FixedFormatInfoPatternParser<LocalTime> | null = null;
  private _localDatePatternParserField: FixedFormatInfoPatternParser<LocalDate> | null = null;
  private _localDateTimePatternParserField: FixedFormatInfoPatternParser<LocalDateTime> | null = null;
  private _offsetDateTimePatternParserField: FixedFormatInfoPatternParser<OffsetDateTime> | null = null;
  private _offsetDatePatternParserField: FixedFormatInfoPatternParser<OffsetDate> | null = null;
  private _offsetTimePatternParserField: FixedFormatInfoPatternParser<OffsetTime> | null = null;
  private _zonedDateTimePatternParserField: FixedFormatInfoPatternParser<ZonedDateTime> | null = null;
  private _annualDatePatternParserField: FixedFormatInfoPatternParser<AnnualDate> | null = null;
  private _yearMonthPatternParserField: FixedFormatInfoPatternParser<YearMonth> | null = null;
  // #endregion

  /** A NodaFormatInfo wrapping the invariant culture. */
  static get InvariantInfo(): NodaFormatInfo {
    return (invariantInfo ??= new NodaFormatInfo(NodaCultureInfo.InvariantCulture, NodaCultureInfo.InvariantCulture.DateTimeFormat, true));
  }

  // Justification for max size: CultureInfo.GetCultures(CultureTypes.AllCultures) returned:
  // - 378 cultures on Windows 8 in mid-2013
  // - 832 cultures on Windows 10 in late-2016
  // - 869 or 888 on Windows 11 in early-2024 (net471 and net60/net80 respectively)
  // It's unlikely that they'll all be used by any particular application,
  // but the cost per entry is very small, so we might as well allow for all non-customized
  // cultures (and if fewer cultures are used, there's no cost anyway).
  // (noda-js: see the WeakMap "cache" above.)

  private _longMonthNamesField: readonly string[] | null = null;
  private _longMonthGenitiveNamesField: readonly string[] | null = null;
  private _longDayNamesField: readonly string[] | null = null;
  private _shortMonthNamesField: readonly string[] | null = null;
  private _shortMonthGenitiveNamesField: readonly string[] | null = null;
  private _shortDayNamesField: readonly string[] | null = null;

  private readonly _eraDescriptions: Map<Era, EraDescription>;

  /**
   * Gets the culture info associated with this format provider. This is used
   * for resource lookups and text comparisons.
   */
  readonly CultureInfo: NodaCultureInfo;

  /**
   * Gets the BCL date time format associated with this formatting information.
   *
   * This is usually the {@link DateTimeFormatInfo} from {@link NodaCultureInfo},
   * but in some cases they're different: if a DateTimeFormatInfo is provided with no
   * CultureInfo, that's used for format strings but the invariant culture is used for
   * text comparisons and culture lookups for non-BCL formats (such as Offset) and for error messages.
   */
  readonly DateTimeFormat: DateTimeFormatInfo;

  /**
   * Initializes a new instance of the {@link NodaFormatInfo} class based on
   * potentially disparate {@link NodaCultureInfo} and {@link DateTimeFormatInfo} instances.
   * @param cultureInfo The culture info to use for text comparisons and resource lookups.
   * @param dateTimeFormat The date/time format to use for format strings etc.
   * @param initializeEagerly Whether or not to fully initialize eagerly. If this is true,
   * more work is done on construction, but avoids locks during usage.
   */
  private constructor(cultureInfo: NodaCultureInfo, dateTimeFormat: DateTimeFormatInfo, initializeEagerly: boolean) {
    Preconditions.CheckNotNull(cultureInfo, "cultureInfo");
    Preconditions.CheckNotNull(dateTimeFormat, "dateTimeFormat");
    this.CultureInfo = cultureInfo;
    this.DateTimeFormat = dateTimeFormat;
    this._eraDescriptions = new Map<Era, EraDescription>();

    if (initializeEagerly) {
      // noda-js: the pattern parsers are created on first use (for tree shaking).
      this.EnsureMonthsInitialized();
      this.EnsureDaysInitialized();
    }
  }

  /**
   * Initializes a new instance of the {@link NodaFormatInfo} class based solely
   * on a {@link NodaCultureInfo}.
   * @param cultureInfo The culture info to use.
   * @param initializeEagerly Whether or not to fully initialize eagerly. If this is true,
   * more work is done on construction, but avoids locks during usage.
   * @internal
   */
  static NewCultureInfoInitializeEagerly(cultureInfo: NodaCultureInfo, initializeEagerly: boolean): NodaFormatInfo {
    // If cultureInfo is null, this will throw before we get to the DateTimeFormatInfo being null.
    Preconditions.CheckNotNull(cultureInfo, "cultureInfo");
    return new NodaFormatInfo(cultureInfo, cultureInfo.DateTimeFormat, initializeEagerly);
  }

  /**
   * Initializes a new instance of the {@link NodaFormatInfo} class based on
   * potentially disparate {@link NodaCultureInfo} and {@link DateTimeFormatInfo} instances.
   * @param cultureInfo The culture info to use for text comparisons and resource lookups.
   * @param dateTimeFormat The date/time format to use for format strings etc.
   * @param initializeEagerly Whether or not to fully initialize eagerly. If this is true,
   * more work is done on construction, but avoids locks during usage.
   * @internal
   */
  static NewCultureInfoDateTimeFormatInitializeEagerly(
    cultureInfo: NodaCultureInfo,
    dateTimeFormat: DateTimeFormatInfo,
    initializeEagerly: boolean,
  ): NodaFormatInfo {
    return new NodaFormatInfo(cultureInfo, dateTimeFormat, initializeEagerly);
  }

  private EnsureMonthsInitialized(): void {
    if (this._longMonthNamesField !== null) {
      return;
    }
    // Turn month names into 1-based read-only lists
    const longMonthNames = NodaFormatInfo.ConvertMonthArray(this.DateTimeFormat.MonthNames);
    const shortMonthNames = NodaFormatInfo.ConvertMonthArray(this.DateTimeFormat.AbbreviatedMonthNames);
    this._longMonthNamesField = longMonthNames;
    this._shortMonthNamesField = shortMonthNames;
    this._longMonthGenitiveNamesField = NodaFormatInfo.ConvertGenitiveMonthArray(
      longMonthNames,
      this.DateTimeFormat.MonthGenitiveNames,
      (longInvariantMonthNames ??= [...NodaCultureInfo.InvariantCulture.DateTimeFormat.MonthNames]),
    );
    this._shortMonthGenitiveNamesField = NodaFormatInfo.ConvertGenitiveMonthArray(
      shortMonthNames,
      this.DateTimeFormat.AbbreviatedMonthGenitiveNames,
      (shortInvariantMonthNames ??= [...NodaCultureInfo.InvariantCulture.DateTimeFormat.AbbreviatedMonthNames]),
    );
  }

  /**
   * The BCL returns arrays of month names starting at 0; we want a read-only list starting at 1 (with 0 as an empty string).
   */
  private static ConvertMonthArray(monthNames: readonly string[]): readonly string[] {
    const list = [...monthNames];
    list.unshift("");
    return list;
  }

  private EnsureDaysInitialized(): void {
    if (this._longDayNamesField !== null) {
      return;
    }
    this._longDayNamesField = NodaFormatInfo.ConvertDayArray(this.DateTimeFormat.DayNames);
    this._shortDayNamesField = NodaFormatInfo.ConvertDayArray(this.DateTimeFormat.AbbreviatedDayNames);
  }

  /**
   * The BCL returns arrays of week names starting at 0 as Sunday; we want a read-only list starting at 1 (with 0 as an empty string)
   * and with 7 as Sunday.
   */
  private static ConvertDayArray(dayNames: readonly string[]): readonly string[] {
    const list = [...dayNames];
    list.push(dayNames[0]!);
    list[0] = "";
    return list;
  }

  /**
   * Checks whether any of the genitive names differ from the non-genitive names, and returns
   * either a reference to the non-genitive names or a converted list as per ConvertMonthArray.
   *
   * Mono uses the invariant month names for the genitive month names by default, so we'll assume that
   * if we see an invariant name, that *isn't* deliberately a genitive month name. A non-invariant culture
   * which decided to have genitive month names exactly matching the invariant ones would be distinctly odd.
   * See https://xamarin.github.io/bugzilla-archives/32/3278/bug.html for more details and progress.
   *
   * Mono 3.0.6 has an exciting and different bug, where all the abbreviated genitive month names are just numbers ("1" etc).
   * So again, if we detect that, we'll go back to the non-genitive version.
   * See https://xamarin.github.io/bugzilla-archives/11/11361/bug.html for more details and progress.
   */
  private static ConvertGenitiveMonthArray(
    nonGenitiveNames: readonly string[],
    bclNames: readonly string[],
    invariantNames: readonly string[],
  ): readonly string[] {
    if (TryParseInvariantInt32(bclNames[0]!)) {
      return nonGenitiveNames;
    }
    for (let i = 0; i < bclNames.length; i++) {
      if (bclNames[i] !== nonGenitiveNames[i + 1] && bclNames[i] !== invariantNames[i]) {
        return NodaFormatInfo.ConvertMonthArray(bclNames);
      }
    }
    return nonGenitiveNames;
  }

  /** Gets the text comparison information associated with this format provider. */
  get CompareInfo(): CompareInfo {
    return this.CultureInfo.CompareInfo;
  }

  // Note: when adding a new property here, it *must* be initialized in the constructor in the "initializeEagerly" branch.
  /** @internal */
  get DurationPatternParser(): FixedFormatInfoPatternParser<Duration> {
    return (this._durationPatternParserField ??= this.EnsureFixedFormatInitialized(() => new DurationPatternParser()));
  }
  /** @internal */
  get OffsetPatternParser(): FixedFormatInfoPatternParser<Offset> {
    return (this._offsetPatternParserField ??= this.EnsureFixedFormatInitialized(() => new OffsetPatternParser()));
  }
  /** @internal */
  get InstantPatternParser(): FixedFormatInfoPatternParser<Instant> {
    return (this._instantPatternParserField ??= this.EnsureFixedFormatInitialized(
      () => InstantPatternParser.NewTemplateValueTwoDigitYearMax(InstantPattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax),
    ));
  }
  /** @internal */
  get LocalTimePatternParser(): FixedFormatInfoPatternParser<LocalTime> {
    return (this._localTimePatternParserField ??= this.EnsureFixedFormatInitialized(() => new LocalTimePatternParser(LocalTime.Midnight)));
  }
  /** @internal */
  get LocalDatePatternParser(): FixedFormatInfoPatternParser<LocalDate> {
    return (this._localDatePatternParserField ??= this.EnsureFixedFormatInitialized(
      () => LocalDatePatternParser.NewTemplateValueTwoDigitYearMax(LocalDatePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax),
    ));
  }
  /** @internal */
  get LocalDateTimePatternParser(): FixedFormatInfoPatternParser<LocalDateTime> {
    return (this._localDateTimePatternParserField ??= this.EnsureFixedFormatInitialized(
      () => LocalDateTimePatternParser.NewTemplateValueTwoDigitYearMax(LocalDateTimePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax),
    ));
  }
  /** @internal */
  get OffsetDateTimePatternParser(): FixedFormatInfoPatternParser<OffsetDateTime> {
    return (this._offsetDateTimePatternParserField ??= this.EnsureFixedFormatInitialized(
      () => OffsetDateTimePatternParser.NewTemplateValueTwoDigitYearMax(OffsetDateTimePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax),
    ));
  }
  /** @internal */
  get OffsetDatePatternParser(): FixedFormatInfoPatternParser<OffsetDate> {
    return (this._offsetDatePatternParserField ??= this.EnsureFixedFormatInitialized(
      () => OffsetDatePatternParser.NewTemplateValueTwoDigitYearMax(OffsetDatePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax),
    ));
  }
  /** @internal */
  get OffsetTimePatternParser(): FixedFormatInfoPatternParser<OffsetTime> {
    return (this._offsetTimePatternParserField ??= this.EnsureFixedFormatInitialized(
      () => OffsetTimePatternParser.NewTemplateValue(OffsetTimePattern.DefaultTemplateValue),
    ));
  }
  /** @internal */
  get ZonedDateTimePatternParser(): FixedFormatInfoPatternParser<ZonedDateTime> {
    return (this._zonedDateTimePatternParserField ??= this.EnsureFixedFormatInitialized(
      () =>
        ZonedDateTimePatternParser.NewTemplateValueResolverZoneProviderTwoDigitYearMax(
          ZonedDateTimePattern.DefaultTemplateValue,
          Resolvers.StrictResolver,
          null,
          LocalDatePattern.DefaultTwoDigitYearMax,
        ),
    ));
  }
  /** @internal */
  get AnnualDatePatternParser(): FixedFormatInfoPatternParser<AnnualDate> {
    return (this._annualDatePatternParserField ??= this.EnsureFixedFormatInitialized(
      () => AnnualDatePatternParser.NewTemplateValue(AnnualDatePattern.DefaultTemplateValue),
    ));
  }
  /** @internal */
  get YearMonthPatternParser(): FixedFormatInfoPatternParser<YearMonth> {
    return (this._yearMonthPatternParserField ??= this.EnsureFixedFormatInitialized(
      () => YearMonthPatternParser.NewTemplateValueTwoDigitYearMax(YearMonthPattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax),
    ));
  }

  // noda-js: the C# version takes the field by reference; here the caller assigns the result to its field.
  private EnsureFixedFormatInitialized<T>(patternParserFactory: () => IPatternParser<T>): FixedFormatInfoPatternParser<T> {
    return new FixedFormatInfoPatternParser<T>(patternParserFactory(), this);
  }

  /**
   * Returns a read-only list of the names of the months for the default calendar for this culture.
   * See the usage guide for caveats around the use of these names for other calendars.
   * Element 0 of the list is null, to allow a more natural mapping from (say) 1 to the string "January".
   */
  get LongMonthNames(): readonly string[] {
    this.EnsureMonthsInitialized();
    return this._longMonthNamesField!;
  }
  /**
   * Returns a read-only list of the abbreviated names of the months for the default calendar for this culture.
   * See the usage guide for caveats around the use of these names for other calendars.
   * Element 0 of the list is null, to allow a more natural mapping from (say) 1 to the string "Jan".
   */
  get ShortMonthNames(): readonly string[] {
    this.EnsureMonthsInitialized();
    return this._shortMonthNamesField!;
  }
  /**
   * Returns a read-only list of the names of the months for the default calendar for this culture.
   * See the usage guide for caveats around the use of these names for other calendars.
   * Element 0 of the list is null, to allow a more natural mapping from (say) 1 to the string "January".
   * The genitive form is used for month text where the day of month also appears in the pattern.
   * If the culture does not use genitive month names, this property will return the same reference as
   * {@link LongMonthNames}.
   */
  get LongMonthGenitiveNames(): readonly string[] {
    this.EnsureMonthsInitialized();
    return this._longMonthGenitiveNamesField!;
  }
  /**
   * Returns a read-only list of the abbreviated names of the months for the default calendar for this culture.
   * See the usage guide for caveats around the use of these names for other calendars.
   * Element 0 of the list is null, to allow a more natural mapping from (say) 1 to the string "Jan".
   * The genitive form is used for month text where the day also appears in the pattern.
   * If the culture does not use genitive month names, this property will return the same reference as
   * {@link ShortMonthNames}.
   */
  get ShortMonthGenitiveNames(): readonly string[] {
    this.EnsureMonthsInitialized();
    return this._shortMonthGenitiveNamesField!;
  }
  /**
   * Returns a read-only list of the names of the days of the week for the default calendar for this culture.
   * See the usage guide for caveats around the use of these names for other calendars.
   * Element 0 of the list is null, and the other elements correspond with the index values returned from
   * {@link LocalDateTime.DayOfWeek} and similar properties.
   */
  get LongDayNames(): readonly string[] {
    this.EnsureDaysInitialized();
    return this._longDayNamesField!;
  }
  /**
   * Returns a read-only list of the abbreviated names of the days of the week for the default calendar for this culture.
   * See the usage guide for caveats around the use of these names for other calendars.
   * Element 0 of the list is null, and the other elements correspond with the index values returned from
   * {@link LocalDateTime.DayOfWeek} and similar properties.
   */
  get ShortDayNames(): readonly string[] {
    this.EnsureDaysInitialized();
    return this._shortDayNamesField!;
  }

  /** Gets the time separator. */
  get TimeSeparator(): string {
    return this.DateTimeFormat.TimeSeparator;
  }

  /** Gets the date separator. */
  get DateSeparator(): string {
    return this.DateTimeFormat.DateSeparator;
  }

  /** Gets the AM designator. */
  get AMDesignator(): string {
    return this.DateTimeFormat.AMDesignator;
  }

  /** Gets the PM designator. */
  get PMDesignator(): string {
    return this.DateTimeFormat.PMDesignator;
  }

  /**
   * Returns the names for the given era in this culture.
   * @param era The era to find the names of.
   * @returns A read-only list of names for the given era, or an empty list if
   * the era is not known in this culture.
   */
  GetEraNames(era: Era): readonly string[] {
    Preconditions.CheckNotNull(era, "era");
    return this.GetEraDescription(era).AllNames;
  }

  /**
   * Returns the primary name for the given era in this culture.
   * @param era The era to find the primary name of.
   * @returns The primary name for the given era, or an empty string if the era name is not known.
   */
  GetEraPrimaryName(era: Era): string {
    Preconditions.CheckNotNull(era, "era");
    return this.GetEraDescription(era).PrimaryName;
  }

  private GetEraDescription(era: Era): EraDescription {
    let description = this._eraDescriptions.get(era);
    if (description === undefined) {
      description = EraDescription.ForEra(era, this.CultureInfo);
      this._eraDescriptions.set(era, description);
    }
    return description;
  }

  // Not ported: CurrentInfo (no current culture in JS)

  /** Gets the {@link Offset} "l" pattern. */
  get OffsetPatternLong(): string {
    return this.CultureInfo.GetPatternResource("OffsetPatternLong")!;
  }

  /** Gets the {@link Offset} "m" pattern. */
  get OffsetPatternMedium(): string {
    return this.CultureInfo.GetPatternResource("OffsetPatternMedium")!;
  }

  /** Gets the {@link Offset} "s" pattern. */
  get OffsetPatternShort(): string {
    return this.CultureInfo.GetPatternResource("OffsetPatternShort")!;
  }

  /** Gets the {@link Offset} "L" pattern. */
  get OffsetPatternLongNoPunctuation(): string {
    return this.CultureInfo.GetPatternResource("OffsetPatternLongNoPunctuation")!;
  }

  /** Gets the {@link Offset} "M" pattern. */
  get OffsetPatternMediumNoPunctuation(): string {
    return this.CultureInfo.GetPatternResource("OffsetPatternMediumNoPunctuation")!;
  }

  /** Gets the {@link Offset} "S" pattern. */
  get OffsetPatternShortNoPunctuation(): string {
    return this.CultureInfo.GetPatternResource("OffsetPatternShortNoPunctuation")!;
  }

  /** Clears the cache. Only used for test purposes. */
  static ClearCache(): void {
    cache = new WeakMap<NodaCultureInfo, NodaFormatInfo>();
  }

  /**
   * Gets the {@link NodaFormatInfo} for the given {@link NodaCultureInfo}.
   *
   * This method maintains a cache of results for read-only cultures.
   * @param cultureInfo The culture info.
   * @returns The {@link NodaFormatInfo}. Will never be null.
   */
  static GetFormatInfo(cultureInfo: NodaCultureInfo): NodaFormatInfo {
    Preconditions.CheckNotNull(cultureInfo, "cultureInfo");
    if (cultureInfo === NodaCultureInfo.InvariantCulture) {
      return NodaFormatInfo.InvariantInfo;
    }
    // Never cache (or consult the cache) for non-read-only cultures.
    // We don't initialize eagerly in this case, to preserve previous behavior -
    // and as we expect such instances to be reused relatively rarely.
    if (!cultureInfo.IsReadOnly) {
      return new NodaFormatInfo(cultureInfo, cultureInfo.DateTimeFormat, false);
    }
    let formatInfo = cache.get(cultureInfo);
    if (formatInfo === undefined) {
      formatInfo = new NodaFormatInfo(cultureInfo, cultureInfo.DateTimeFormat, true);
      cache.set(cultureInfo, formatInfo);
    }
    return formatInfo;
  }

  /**
   * Gets the {@link NodaFormatInfo} for the given {@link IFormatProvider}. If the
   * format provider is null then the format object for the invariant culture is returned (noda-js: NodaTime uses
   * the current thread's culture). If it's a CultureInfo, that's used for everything. If it's a DateTimeFormatInfo,
   * that's used for format strings, day names etc but the invariant culture is used for text comparisons and
   * resource lookups. Otherwise, {@link ArgumentException} is thrown.
   * @param provider The {@link IFormatProvider}.
   * @throws {ArgumentException} The format provider cannot be used for Noda Time.
   * @returns The {@link NodaFormatInfo}. Will never be null.
   */
  static GetInstance(provider: IFormatProvider | null | undefined): NodaFormatInfo {
    if (provider === null || provider === undefined) {
      return NodaFormatInfo.InvariantInfo;
    }
    if (provider instanceof NodaCultureInfo) {
      return NodaFormatInfo.GetFormatInfo(provider);
    }
    // Note: no caching for this case. It's a corner case anyway... we could add a cache later
    // if users notice a problem.
    if (provider instanceof DateTimeFormatInfo) {
      return new NodaFormatInfo(NodaCultureInfo.InvariantCulture, provider, false);
    }
    const typeName = (provider as object).constructor?.name ?? typeof provider;
    throw NewArgumentException(`Cannot use provider of type ${typeName} in Noda Time`, "provider");
  }

  /** Returns a string that represents this instance. */
  toString(): string {
    return `NodaFormatInfo[${this.CultureInfo.Name}]`;
  }
}

/** The description for an era: the primary name and all possible names. */
class EraDescription {
  readonly PrimaryName: string;
  readonly AllNames: readonly string[];

  private constructor(primaryName: string, allNames: readonly string[]) {
    this.PrimaryName = primaryName;
    this.AllNames = allNames;
  }

  static ForEra(era: Era, cultureInfo: NodaCultureInfo): EraDescription {
    let pipeDelimited = cultureInfo.GetPatternResource(era.ResourceIdentifier);
    let primaryName: string;
    let allNames: string[];
    if (pipeDelimited === null) {
      allNames = [];
      primaryName = "";
    } else {
      // If the BCL has provided an era name other than the one we'd consider to be the primary one, make *that*
      // the primary one for formatting.
      // TODO: Achieve the same result without the string allocations.
      const eraNameFromCulture = EraDescription.GetEraNameFromBcl(era, cultureInfo);
      if (eraNameFromCulture !== null && !pipeDelimited.startsWith(eraNameFromCulture + "|")) {
        pipeDelimited = `${eraNameFromCulture}|${pipeDelimited}`;
      }
      allNames = pipeDelimited.split("|");
      primaryName = allNames[0]!;
      // Order by length, descending to avoid early out (e.g. parsing BCE as BC and then having a spare E)
      allNames.sort((x, y) => y.length - x.length);
    }
    return new EraDescription(primaryName, allNames);
  }

  /**
   * Returns the name of the era within a culture according to the BCL, if this is known and we're confident that
   * it's correct. (The selection here seems small, but it covers most cases.) This isn't ideal, but it's better
   * than nothing, and fixes an issue where non-English BCL cultures have "gg" in their patterns.
   */
  private static GetEraNameFromBcl(era: Era, culture: NodaCultureInfo): string | null {
    // noda-js: the calendar is identified by its .NET type name.
    const calendar = culture.DateTimeFormat.Calendar;
    const getEraFromCalendar =
      (era === Era.Common && calendar === "GregorianCalendar") ||
      (era === Era.AnnoPersico && calendar === "PersianCalendar") ||
      (era === Era.AnnoHegirae && (calendar === "HijriCalendar" || calendar === "UmAlQuraCalendar"));
    return getEraFromCalendar ? culture.DateTimeFormat.GetEraName(1) : null;
  }
}
