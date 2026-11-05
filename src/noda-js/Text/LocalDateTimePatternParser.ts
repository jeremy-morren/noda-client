// Ported from NodaTime 3.3.0: src/NodaTime/Text/LocalDateTimePatternParser.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  DatePatternHelper,
  InvalidPatternError,
  LocalDatePatternParserLocalDateParseBucket,
  LocalDateTime,
  LocalDateTimePattern,
  LocalTime,
  LocalTimePatternParserLocalTimeParseBucket,
  ParseBucket,
  ParseResult,
  PatternFields,
  Preconditions,
  SteppedPatternBuilder,
  TextErrorMessages,
  TimePatternHelper,
} from "../internal.ts";
import type { CharacterHandler, IPattern, IPatternParser, LocalDate, NodaFormatInfo } from "../internal.ts";
import type { OffsetDateTime, ZonedDateTime } from "../internal.ts";

/**
 * (C#: LocalDateTimePatternParser.LocalDateTimeParseBucket)
 * @internal
 */
export class LocalDateTimePatternParserLocalDateTimeParseBucket extends ParseBucket<LocalDateTime> {
  readonly Date: LocalDatePatternParserLocalDateParseBucket;
  readonly Time: LocalTimePatternParserLocalTimeParseBucket;

  constructor(templateValueDate: LocalDate, templateValueTime: LocalTime, twoDigitYearMax: number) {
    super();
    this.Date = new LocalDatePatternParserLocalDateParseBucket(templateValueDate, twoDigitYearMax);
    this.Time = new LocalTimePatternParserLocalTimeParseBucket(templateValueTime);
  }

  /** @internal */
  static NewTemplateValueDateTemplateValueTimeTwoDigitYearMax(
    templateValueDate: LocalDate,
    templateValueTime: LocalTime,
    twoDigitYearMax: number,
  ): LocalDateTimePatternParserLocalDateTimeParseBucket {
    return new LocalDateTimePatternParserLocalDateTimeParseBucket(templateValueDate, templateValueTime, twoDigitYearMax);
  }

  /**
   * Combines the values in a date bucket with the values in a time bucket.
   *
   * This would normally be the {@link CalculateValue} method, but we want
   * to be able to use the same logic when parsing an {@link OffsetDateTime}
   * and {@link ZonedDateTime}.
   */
  static CombineBuckets(
    usedFields: PatternFields,
    dateBucket: LocalDatePatternParserLocalDateParseBucket,
    timeBucket: LocalTimePatternParserLocalTimeParseBucket,
    text: string,
  ): ParseResult<LocalDateTime> {
    // Handle special case of hour = 24
    let hour24 = false;
    if (timeBucket.Hours24 === 24) {
      timeBucket.Hours24 = 0;
      hour24 = true;
    }

    const dateResult = dateBucket.CalculateValue(usedFields & PatternFields.AllDateFields, text, "NodaTime.LocalDateTime");
    if (!dateResult.Success) {
      return dateResult.ConvertError<LocalDateTime>();
    }
    const timeResult = timeBucket.CalculateValue(usedFields & PatternFields.AllTimeFields, text, "NodaTime.LocalDateTime");
    if (!timeResult.Success) {
      return timeResult.ConvertError<LocalDateTime>();
    }

    let date = dateResult.Value;
    const time = timeResult.Value;

    if (hour24) {
      if (!time.Equals(LocalTime.Midnight)) {
        return ParseResult.InvalidHour24<LocalDateTime>(text);
      }
      date = date.PlusDays(1);
    }
    // C#: date + time
    return ParseResult.ForValue(date.At(time));
  }

  /** @inheritDoc */
  override CalculateValue(usedFields: PatternFields, text: string): ParseResult<LocalDateTime> {
    return LocalDateTimePatternParserLocalDateTimeParseBucket.CombineBuckets(usedFields, this.Date, this.Time, text);
  }
}

let patternCharacterHandlers: ReadonlyMap<string, CharacterHandler<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>> | undefined;

function GetPatternCharacterHandlers(): ReadonlyMap<string, CharacterHandler<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>> {
  type Bucket = LocalDateTimePatternParserLocalDateTimeParseBucket;
  return (patternCharacterHandlers ??= new Map<string, CharacterHandler<LocalDateTime, Bucket>>([
    ["%", SteppedPatternBuilder.HandlePercent],
    ["'", SteppedPatternBuilder.HandleQuote],
    ['"', SteppedPatternBuilder.HandleQuote],
    ["\\", SteppedPatternBuilder.HandleBackslash],
    ["/", (pattern, builder) => builder.AddLiteral(builder.FormatInfo.DateSeparator, ParseResult.DateSeparatorMismatch<LocalDateTime>)],
    ["T", (pattern, builder) => builder.AddLiteral("T", ParseResult.MismatchedCharacter<LocalDateTime>)],
    ["y", DatePatternHelper.CreateYearOfEraHandler<LocalDateTime, Bucket>((value) => value.YearOfEra, (bucket, value) => (bucket.Date.YearOfEra = value))],
    [
      "u",
      SteppedPatternBuilder.HandlePaddedField<LocalDateTime, Bucket>(4, PatternFields.Year, -9999, 9999, (value) => value.Year, (bucket, value) => (bucket.Date.Year = value)),
    ],
    [
      "M",
      DatePatternHelper.CreateMonthOfYearHandler<LocalDateTime, Bucket>(
        (value) => value.Month,
        (bucket, value) => (bucket.Date.MonthOfYearText = value),
        (bucket, value) => (bucket.Date.MonthOfYearNumeric = value),
      ),
    ],
    [
      "d",
      DatePatternHelper.CreateDayHandler<LocalDateTime, Bucket>(
        (value) => value.Day,
        (value) => value.DayOfWeek,
        (bucket, value) => (bucket.Date.DayOfMonth = value),
        (bucket, value) => (bucket.Date.DayOfWeek = value),
      ),
    ],
    [".", TimePatternHelper.CreatePeriodHandler<LocalDateTime, Bucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
    [";", TimePatternHelper.CreateCommaDotHandler<LocalDateTime, Bucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
    [":", (pattern, builder) => builder.AddLiteral(builder.FormatInfo.TimeSeparator, ParseResult.TimeSeparatorMismatch<LocalDateTime>)],
    [
      "h",
      SteppedPatternBuilder.HandlePaddedField<LocalDateTime, Bucket>(
        2,
        PatternFields.Hours12,
        1,
        12,
        (value) => value.ClockHourOfHalfDay,
        (bucket, value) => (bucket.Time.Hours12 = value),
      ),
    ],
    [
      "H",
      SteppedPatternBuilder.HandlePaddedField<LocalDateTime, Bucket>(2, PatternFields.Hours24, 0, 24, (value) => value.Hour, (bucket, value) => (bucket.Time.Hours24 = value)),
    ],
    [
      "m",
      SteppedPatternBuilder.HandlePaddedField<LocalDateTime, Bucket>(2, PatternFields.Minutes, 0, 59, (value) => value.Minute, (bucket, value) => (bucket.Time.Minutes = value)),
    ],
    [
      "s",
      SteppedPatternBuilder.HandlePaddedField<LocalDateTime, Bucket>(2, PatternFields.Seconds, 0, 59, (value) => value.Second, (bucket, value) => (bucket.Time.Seconds = value)),
    ],
    ["f", TimePatternHelper.CreateFractionHandler<LocalDateTime, Bucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
    ["F", TimePatternHelper.CreateFractionHandler<LocalDateTime, Bucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
    ["t", TimePatternHelper.CreateAmPmHandler<LocalDateTime, Bucket>((time) => time.Hour, (bucket, value) => (bucket.Time.AmPm = value))],
    ["c", DatePatternHelper.CreateCalendarHandler<LocalDateTime, Bucket>((value) => value.Calendar, (bucket, value) => (bucket.Date.Calendar = value))],
    ["g", DatePatternHelper.CreateEraHandler<LocalDateTime, Bucket>((value) => value.Era, (bucket) => bucket.Date)],
    [
      "l",
      (cursor, builder) =>
        builder.AddEmbeddedLocalPartial(
          cursor,
          (bucket) => bucket.Date,
          (bucket) => bucket.Time,
          (value) => value.Date,
          (value) => value.TimeOfDay,
          null,
        ),
    ],
  ]));
}

/**
 * Parser for patterns of {@link LocalDateTime} values.
 * @internal
 */
export class LocalDateTimePatternParser implements IPatternParser<LocalDateTime> {
  /** @internal */
  static readonly LocalDateTimeParseBucket = LocalDateTimePatternParserLocalDateTimeParseBucket;

  // Split the template value into date and time once, to avoid doing it every time we parse.
  private readonly _templateValueDate: LocalDate;
  private readonly _templateValueTime: LocalTime;
  private readonly _twoDigitYearMax: number;

  constructor(templateValue: LocalDateTime, twoDigitYearMax: number) {
    Preconditions.CheckArgumentRange("twoDigitYearMax", twoDigitYearMax, 0, 99);
    this._templateValueDate = templateValue.Date;
    this._templateValueTime = templateValue.TimeOfDay;
    this._twoDigitYearMax = twoDigitYearMax;
  }

  /** @internal */
  static NewTemplateValueTwoDigitYearMax(templateValue: LocalDateTime, twoDigitYearMax: number): LocalDateTimePatternParser {
    return new LocalDateTimePatternParser(templateValue, twoDigitYearMax);
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  ParsePattern(patternText: string, formatInfo: NodaFormatInfo): IPattern<LocalDateTime> {
    // Nullity check is performed in LocalDateTimePattern.
    if (patternText.length === 0) {
      throw new InvalidPatternError(TextErrorMessages.FormatStringEmpty);
    }

    const parseNoStandardExpansion = (patternTextLocal: string): IPattern<LocalDateTime> => {
      const patternBuilder = new SteppedPatternBuilder<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>(
        formatInfo,
        () => new LocalDateTimePatternParserLocalDateTimeParseBucket(this._templateValueDate, this._templateValueTime, this._twoDigitYearMax),
      );
      patternBuilder.ParseCustomPattern(patternTextLocal, GetPatternCharacterHandlers());
      patternBuilder.ValidateUsedFields();
      return patternBuilder.Build(this._templateValueDate.At(this._templateValueTime));
    };

    if (patternText.length === 1) {
      switch (patternText[0]) {
        // Invariant standard patterns return cached implementations.
        case "o":
          return LocalDateTimePattern.Patterns.BclRoundtripPatternImpl;
        case "O":
          return LocalDateTimePattern.Patterns.BclRoundtripPatternImpl;
        case "r":
          return LocalDateTimePattern.Patterns.FullRoundtripPatternImpl;
        case "R":
          return LocalDateTimePattern.Patterns.FullRoundtripWithoutCalendarImpl;
        case "s":
          return LocalDateTimePattern.Patterns.GeneralIsoPatternImpl;
        case "S":
          return LocalDateTimePattern.Patterns.ExtendedIsoPatternImpl;
        // Other standard patterns expand the pattern text to the appropriate custom pattern.
        // Note: we don't just recurse, as otherwise a FullDateTimePattern of 'F' would cause a stack overflow.
        case "f":
          return parseNoStandardExpansion(`${formatInfo.DateTimeFormat.LongDatePattern} ${formatInfo.DateTimeFormat.ShortTimePattern}`);
        case "F":
          return parseNoStandardExpansion(formatInfo.DateTimeFormat.FullDateTimePattern);
        case "g":
          return parseNoStandardExpansion(`${formatInfo.DateTimeFormat.ShortDatePattern} ${formatInfo.DateTimeFormat.ShortTimePattern}`);
        case "G":
          return parseNoStandardExpansion(`${formatInfo.DateTimeFormat.ShortDatePattern} ${formatInfo.DateTimeFormat.LongTimePattern}`);
        // Unknown standard patterns fail.
        default:
          throw new InvalidPatternError(TextErrorMessages.UnknownStandardFormat, patternText, "NodaTime.LocalDateTime");
      }
    }
    return parseNoStandardExpansion(patternText);
  }
}
