// Ported from NodaTime 3.3.0: src/NodaTime/Text/LocalDatePatternParser.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarOrdinal,
  CalendarSystem,
  DatePatternHelper,
  InvalidPatternError,
  LocalDate,
  LocalDatePattern,
  ParseBucket,
  ParseResult,
  PatternFields,
  Preconditions,
  SteppedPatternBuilder,
  TextErrorMessages,
  YearMonthDayCalendar,
} from "../internal.ts";
import type { CharacterHandler, Era, IPattern, IPatternParser, NodaFormatInfo, ValueCursor } from "../internal.ts";

/** PatternFieldsExtensions.HasAny */
function HasAny(fields: PatternFields, target: PatternFields): boolean {
  return (fields & target) !== 0;
}

/**
 * Bucket to put parsed values in, ready for later result calculation. This type is also used
 * by LocalDateTimePattern to store and calculate values.
 * (C#: LocalDatePatternParser.LocalDateParseBucket)
 * @internal
 */
export class LocalDatePatternParserLocalDateParseBucket extends ParseBucket<LocalDate> {
  readonly TemplateValue: LocalDate;
  TwoDigitYearMax: number;

  Calendar: CalendarSystem;
  Year = 0;
  private _era: Era | null = null;
  YearOfEra = 0;
  MonthOfYearNumeric = 0;
  MonthOfYearText = 0;
  DayOfMonth = 0;
  DayOfWeek = 0;

  constructor(templateValue: LocalDate, twoDigitYearMax: number) {
    super();
    this.TemplateValue = templateValue;
    // Only fetch this once.
    this.Calendar = templateValue.Calendar;
    this.TwoDigitYearMax = twoDigitYearMax;
  }

  /** @internal */
  static NewTemplateValueTwoDigitYearMax(templateValue: LocalDate, twoDigitYearMax: number): LocalDatePatternParserLocalDateParseBucket {
    return new LocalDatePatternParserLocalDateParseBucket(templateValue, twoDigitYearMax);
  }

  ParseEra<TResult>(formatInfo: NodaFormatInfo, cursor: ValueCursor): ParseResult<TResult> | null {
    const compareInfo = formatInfo.CompareInfo;
    for (const era of this.Calendar.Eras) {
      for (const eraName of formatInfo.GetEraNames(era)) {
        if (cursor.MatchCaseInsensitive(eraName, compareInfo, true)) {
          this._era = era;
          return null;
        }
      }
    }
    return ParseResult.MismatchedText<TResult>(cursor, "g");
  }

  /**
   * (noda-js: this also covers the C# overload with an eventualResultType parameter, which is the name of the
   * type, e.g. "NodaTime.LocalDateTime".)
   */
  override CalculateValue(usedFields: PatternFields, text: string, eventualResultType: string = "NodaTime.LocalDate"): ParseResult<LocalDate> {
    // Optimization for very, very common case.
    if (
      usedFields === (PatternFields.Year | PatternFields.MonthOfYearNumeric | PatternFields.DayOfMonth) &&
      this.Calendar === CalendarSystem.Iso
    ) {
      return this.CalculateSimpleIsoValue(text);
    }

    if (HasAny(usedFields, PatternFields.EmbeddedDate)) {
      return ParseResult.ForValue(new LocalDate(this.Year, this.MonthOfYearNumeric, this.DayOfMonth, this.Calendar));
    }
    // This will set Year if necessary
    let failure = this.DetermineYear(usedFields, text, eventualResultType);
    if (failure !== null) {
      return failure;
    }
    // This will set MonthOfYearNumeric if necessary
    failure = this.DetermineMonth(usedFields, text);
    if (failure !== null) {
      return failure;
    }

    const day = HasAny(usedFields, PatternFields.DayOfMonth) ? this.DayOfMonth : this.TemplateValue.Day;
    if (day > this.Calendar.GetDaysInMonth(this.Year, this.MonthOfYearNumeric)) {
      return ParseResult.DayOfMonthOutOfRange<LocalDate>(text, day, this.MonthOfYearNumeric, this.Year);
    }

    // Avoid further revalidation.
    const value = LocalDate.NewYearMonthDayCalendar(
      YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(this.Year, this.MonthOfYearNumeric, day, this.Calendar.Ordinal),
    );

    if (HasAny(usedFields, PatternFields.DayOfWeek) && this.DayOfWeek !== value.DayOfWeek) {
      return ParseResult.InconsistentDayOfWeekTextValue<LocalDate>(text);
    }

    return ParseResult.ForValue(value);
  }

  /**
   * Optimized computation for a pattern with an ISO calendar template value,
   * and year/month/day fields.
   */
  private CalculateSimpleIsoValue(text: string): ParseResult<LocalDate> {
    const day = this.DayOfMonth;
    const month = this.MonthOfYearNumeric;
    // Note: year is always valid, as it's already validated to be in the range -9999 to 9999.

    if (month > 12) {
      return ParseResult.MonthOutOfRange<LocalDate>(text, this.MonthOfYearNumeric, this.Year);
    }
    // If we've been asked for day 1-28, we're definitely okay regardless of month.
    // If it's 29-31, we need to check.
    // If it's over 31, it's definitely wrong.
    if (day > 31 || (day > 28 && day > this.Calendar.GetDaysInMonth(this.Year, this.MonthOfYearNumeric))) {
      return ParseResult.DayOfMonthOutOfRange<LocalDate>(text, day, this.MonthOfYearNumeric, this.Year);
    }

    const value = LocalDate.NewYearMonthDayCalendar(
      YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(this.Year, month, day, CalendarOrdinal.Iso),
    );
    return ParseResult.ForValue(value);
  }

  /**
   * Work out the year, based on fields of:
   * - Year
   * - YearOfEra
   * - YearTwoDigits (implies YearOfEra)
   * - Era
   *
   * If the year is specified, that trumps everything else - any other fields
   * are just used for checking.
   *
   * If nothing is specified, the year of the template value is used.
   *
   * If just the era is specified, the year of the template value is used,
   * and the specified era is checked against it. (Hopefully no-one will
   * expect to get useful information from a format string with era but no year...)
   *
   * Otherwise, we have the year of era (possibly only two digits) and possibly the
   * era. If the era isn't specified, take it from the template value.
   * Finally, if we only have two digits, then use either the century of the template
   * value or the previous century if the year-of-era is greater than TwoDigitYearMax...
   * and if the template value isn't in the first century already.
   *
   * Phew.
   */
  private DetermineYear(usedFields: PatternFields, text: string, eventualResultType: string): ParseResult<LocalDate> | null {
    if (HasAny(usedFields, PatternFields.Year)) {
      if (this.Year > this.Calendar.MaxYear || this.Year < this.Calendar.MinYear) {
        return ParseResult.FieldValueOutOfRangePostParse<LocalDate>(text, this.Year, "u", eventualResultType);
      }

      if (HasAny(usedFields, PatternFields.Era) && this._era !== this.Calendar.GetEra(this.Year)) {
        return ParseResult.InconsistentValues<LocalDate>(text, "g", "u", eventualResultType);
      }

      if (HasAny(usedFields, PatternFields.YearOfEra)) {
        let yearOfEraFromYear = this.Calendar.GetYearOfEra(this.Year);
        if (HasAny(usedFields, PatternFields.YearTwoDigits)) {
          // We're only checking the last two digits
          yearOfEraFromYear = yearOfEraFromYear % 100;
        }
        if (yearOfEraFromYear !== this.YearOfEra) {
          return ParseResult.InconsistentValues<LocalDate>(text, "y", "u", eventualResultType);
        }
      }
      return null;
    }

    // Use the year from the template value, possibly checking the era.
    if (!HasAny(usedFields, PatternFields.YearOfEra)) {
      this.Year = this.TemplateValue.Year;
      return HasAny(usedFields, PatternFields.Era) && this._era !== this.Calendar.GetEra(this.Year)
        ? ParseResult.InconsistentValues<LocalDate>(text, "g", "u", eventualResultType)
        : null;
    }

    if (!HasAny(usedFields, PatternFields.Era)) {
      this._era = this.TemplateValue.Era;
    }

    // After this point, Era is definitely non-null.

    if (HasAny(usedFields, PatternFields.YearTwoDigits)) {
      let century = Math.trunc(this.TemplateValue.YearOfEra / 100);
      if (this.YearOfEra > this.TwoDigitYearMax && century > 1) {
        century--;
      }
      this.YearOfEra += century * 100;
    }

    if (this.YearOfEra < this.Calendar.GetMinYearOfEra(this._era!) || this.YearOfEra > this.Calendar.GetMaxYearOfEra(this._era!)) {
      return ParseResult.YearOfEraOutOfRange<LocalDate>(text, this.YearOfEra, this._era!, this.Calendar);
    }
    this.Year = this.Calendar.GetAbsoluteYear(this.YearOfEra, this._era!);
    return null;
  }

  private DetermineMonth(usedFields: PatternFields, text: string): ParseResult<LocalDate> | null {
    switch (usedFields & (PatternFields.MonthOfYearNumeric | PatternFields.MonthOfYearText)) {
      case PatternFields.MonthOfYearNumeric:
        // No-op
        break;
      case PatternFields.MonthOfYearText:
        this.MonthOfYearNumeric = this.MonthOfYearText;
        break;
      case PatternFields.MonthOfYearNumeric | PatternFields.MonthOfYearText:
        if (this.MonthOfYearNumeric !== this.MonthOfYearText) {
          return ParseResult.InconsistentMonthValues<LocalDate>(text);
        }
        // No need to change MonthOfYearNumeric - this was just a check
        break;
      case 0:
        this.MonthOfYearNumeric = this.TemplateValue.Month;
        break;
    }
    if (this.MonthOfYearNumeric > this.Calendar.GetMonthsInYear(this.Year)) {
      return ParseResult.MonthOutOfRange<LocalDate>(text, this.MonthOfYearNumeric, this.Year);
    }
    return null;
  }
}

let patternCharacterHandlers: ReadonlyMap<string, CharacterHandler<LocalDate, LocalDatePatternParserLocalDateParseBucket>> | undefined;

function GetPatternCharacterHandlers(): ReadonlyMap<string, CharacterHandler<LocalDate, LocalDatePatternParserLocalDateParseBucket>> {
  type Bucket = LocalDatePatternParserLocalDateParseBucket;
  return (patternCharacterHandlers ??= new Map<string, CharacterHandler<LocalDate, Bucket>>([
    ["%", SteppedPatternBuilder.HandlePercent],
    ["'", SteppedPatternBuilder.HandleQuote],
    ['"', SteppedPatternBuilder.HandleQuote],
    ["\\", SteppedPatternBuilder.HandleBackslash],
    ["/", (pattern, builder) => builder.AddLiteral(builder.FormatInfo.DateSeparator, ParseResult.DateSeparatorMismatch<LocalDate>)],
    ["y", DatePatternHelper.CreateYearOfEraHandler<LocalDate, Bucket>((value) => value.YearOfEra, (bucket, value) => (bucket.YearOfEra = value))],
    [
      "u",
      SteppedPatternBuilder.HandlePaddedField<LocalDate, Bucket>(4, PatternFields.Year, -9999, 9999, (value) => value.Year, (bucket, value) => (bucket.Year = value)),
    ],
    [
      "M",
      DatePatternHelper.CreateMonthOfYearHandler<LocalDate, Bucket>(
        (value) => value.Month,
        (bucket, value) => (bucket.MonthOfYearText = value),
        (bucket, value) => (bucket.MonthOfYearNumeric = value),
      ),
    ],
    [
      "d",
      DatePatternHelper.CreateDayHandler<LocalDate, Bucket>(
        (value) => value.Day,
        (value) => value.DayOfWeek,
        (bucket, value) => (bucket.DayOfMonth = value),
        (bucket, value) => (bucket.DayOfWeek = value),
      ),
    ],
    ["c", DatePatternHelper.CreateCalendarHandler<LocalDate, Bucket>((value) => value.Calendar, (bucket, value) => (bucket.Calendar = value))],
    ["g", DatePatternHelper.CreateEraHandler<LocalDate, Bucket>((date) => date.Era, (bucket) => bucket)],
  ]));
}

/**
 * Parser for patterns of {@link LocalDate} values.
 * @internal
 */
export class LocalDatePatternParser implements IPatternParser<LocalDate> {
  /** @internal */
  static readonly LocalDateParseBucket = LocalDatePatternParserLocalDateParseBucket;

  private readonly _templateValue: LocalDate;
  private readonly _twoDigitYearMax: number;

  constructor(templateValue: LocalDate, twoDigitYearMax: number) {
    Preconditions.CheckArgumentRange("twoDigitYearMax", twoDigitYearMax, 0, 99);
    this._templateValue = templateValue;
    this._twoDigitYearMax = twoDigitYearMax;
  }

  /** @internal */
  static NewTemplateValueTwoDigitYearMax(templateValue: LocalDate, twoDigitYearMax: number): LocalDatePatternParser {
    return new LocalDatePatternParser(templateValue, twoDigitYearMax);
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  ParsePattern(patternText: string, formatInfo: NodaFormatInfo): IPattern<LocalDate> {
    // Nullity check is performed in LocalDatePattern.
    if (patternText.length === 0) {
      throw new InvalidPatternError(TextErrorMessages.FormatStringEmpty);
    }

    const parseNoStandardExpansion = (patternTextLocal: string): IPattern<LocalDate> => {
      const patternBuilder = new SteppedPatternBuilder<LocalDate, LocalDatePatternParserLocalDateParseBucket>(
        formatInfo,
        () => new LocalDatePatternParserLocalDateParseBucket(this._templateValue, this._twoDigitYearMax),
      );
      patternBuilder.ParseCustomPattern(patternTextLocal, GetPatternCharacterHandlers());
      patternBuilder.ValidateUsedFields();
      return patternBuilder.Build(this._templateValue);
    };

    if (patternText.length === 1) {
      switch (patternText[0]) {
        // Invariant standard patterns return cached implementations.
        case "R":
          return LocalDatePattern.Patterns.IsoPatternImpl;
        case "r":
          return LocalDatePattern.Patterns.FullRoundtripPatternImpl;
        // Other standard patterns expand the pattern text to the appropriate custom pattern.
        // Note: we don't just recurse, as otherwise a ShortDatePattern of 'd' (for example) would cause a stack overflow.
        case "d":
          return parseNoStandardExpansion(formatInfo.DateTimeFormat.ShortDatePattern);
        case "D":
          return parseNoStandardExpansion(formatInfo.DateTimeFormat.LongDatePattern);
        case "M":
          return parseNoStandardExpansion(formatInfo.DateTimeFormat.MonthDayPattern);
        // Unknown standard patterns fail.
        default:
          throw new InvalidPatternError(TextErrorMessages.UnknownStandardFormat, patternText, "NodaTime.LocalDate");
      }
    }
    return parseNoStandardExpansion(patternText);
  }
}
