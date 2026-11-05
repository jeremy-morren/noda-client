// Ported from NodaTime 3.3.7: src/NodaTime/Text/OffsetDateTimePatternParser.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  DatePatternHelper,
  InvalidPatternException,
  LocalDatePatternParserLocalDateParseBucket,
  LocalDateTimePatternParserLocalDateTimeParseBucket,
  LocalTimePatternParserLocalTimeParseBucket,
  OffsetDateTimePattern,
  OffsetPattern,
  ParseBucket,
  ParseResult,
  PatternFields,
  Preconditions,
  SteppedPatternBuilder,
  TextErrorMessages,
  TimePatternHelper,
} from "../internal.ts";
import type { CharacterHandler, IPattern, IPatternParser, NodaFormatInfo, Offset, OffsetDateTime, PatternCursor } from "../internal.ts";

let patternCharacterHandlers: Map<string, CharacterHandler<OffsetDateTime, OffsetDateTimePatternParserOffsetDateTimeParseBucket>> | undefined;

class OffsetDateTimePatternParserOffsetDateTimeParseBucket extends ParseBucket<OffsetDateTime> {
  readonly Date: LocalDatePatternParserLocalDateParseBucket;
  readonly Time: LocalTimePatternParserLocalTimeParseBucket;
  Offset: Offset;

  constructor(templateValue: OffsetDateTime, twoDigitYearMax: number) {
    super();
    this.Date = new LocalDatePatternParserLocalDateParseBucket(templateValue.Date, twoDigitYearMax);
    this.Time = new LocalTimePatternParserLocalTimeParseBucket(templateValue.TimeOfDay);
    this.Offset = templateValue.Offset;
  }

  /** @inheritDoc */
  override CalculateValue(usedFields: PatternFields, text: string): ParseResult<OffsetDateTime> {
    const localResult = LocalDateTimePatternParserLocalDateTimeParseBucket.CombineBuckets(usedFields, this.Date, this.Time, text);
    if (!localResult.Success) {
      return localResult.ConvertError<OffsetDateTime>();
    }

    const localDateTime = localResult.Value;
    return ParseResult.ForValue(localDateTime.WithOffset(this.Offset));
  }
}

/** @internal */
export class OffsetDateTimePatternParser implements IPatternParser<OffsetDateTime> {
  private readonly _templateValue: OffsetDateTime;
  private readonly _twoDigitYearMax: number;

  private static get PatternCharacterHandlers(): Map<string, CharacterHandler<OffsetDateTime, OffsetDateTimePatternParserOffsetDateTimeParseBucket>> {
    type B = OffsetDateTimePatternParserOffsetDateTimeParseBucket;
    return (patternCharacterHandlers ??= new Map<string, CharacterHandler<OffsetDateTime, B>>([
      ["%", SteppedPatternBuilder.HandlePercent],
      ["'", SteppedPatternBuilder.HandleQuote],
      ["\"", SteppedPatternBuilder.HandleQuote],
      ["\\", SteppedPatternBuilder.HandleBackslash],
      ["/", (pattern, builder) => builder.AddLiteral(builder.FormatInfo.DateSeparator, ParseResult.DateSeparatorMismatch)],
      ["T", (pattern, builder) => builder.AddLiteral("T", ParseResult.MismatchedCharacter)],
      ["y", DatePatternHelper.CreateYearOfEraHandler<OffsetDateTime, B>(value => value.YearOfEra, (bucket, value) => (bucket.Date.YearOfEra = value))],
      ["u", SteppedPatternBuilder.HandlePaddedField<OffsetDateTime, B>(
        4, PatternFields.Year, -9998, 9999, value => value.Year, (bucket, value) => (bucket.Date.Year = value))],
      ["M", DatePatternHelper.CreateMonthOfYearHandler<OffsetDateTime, B>(
        value => value.Month, (bucket, value) => (bucket.Date.MonthOfYearText = value), (bucket, value) => (bucket.Date.MonthOfYearNumeric = value))],
      ["d", DatePatternHelper.CreateDayHandler<OffsetDateTime, B>(
        value => value.Day, value => value.DayOfWeek, (bucket, value) => (bucket.Date.DayOfMonth = value), (bucket, value) => (bucket.Date.DayOfWeek = value))],
      [".", TimePatternHelper.CreatePeriodHandler<OffsetDateTime, B>(9, value => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
      [";", TimePatternHelper.CreateCommaDotHandler<OffsetDateTime, B>(9, value => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
      [":", (pattern, builder) => builder.AddLiteral(builder.FormatInfo.TimeSeparator, ParseResult.TimeSeparatorMismatch)],
      ["h", SteppedPatternBuilder.HandlePaddedField<OffsetDateTime, B>(
        2, PatternFields.Hours12, 1, 12, value => value.ClockHourOfHalfDay, (bucket, value) => (bucket.Time.Hours12 = value))],
      ["H", SteppedPatternBuilder.HandlePaddedField<OffsetDateTime, B>(
        2, PatternFields.Hours24, 0, 24, value => value.Hour, (bucket, value) => (bucket.Time.Hours24 = value))],
      ["m", SteppedPatternBuilder.HandlePaddedField<OffsetDateTime, B>(
        2, PatternFields.Minutes, 0, 59, value => value.Minute, (bucket, value) => (bucket.Time.Minutes = value))],
      ["s", SteppedPatternBuilder.HandlePaddedField<OffsetDateTime, B>(
        2, PatternFields.Seconds, 0, 59, value => value.Second, (bucket, value) => (bucket.Time.Seconds = value))],
      ["f", TimePatternHelper.CreateFractionHandler<OffsetDateTime, B>(9, value => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
      ["F", TimePatternHelper.CreateFractionHandler<OffsetDateTime, B>(9, value => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
      ["t", TimePatternHelper.CreateAmPmHandler<OffsetDateTime, B>(time => time.Hour, (bucket, value) => (bucket.Time.AmPm = value))],
      ["c", DatePatternHelper.CreateCalendarHandler<OffsetDateTime, B>(value => value.LocalDateTime.Calendar, (bucket, value) => (bucket.Date.Calendar = value))],
      ["g", DatePatternHelper.CreateEraHandler<OffsetDateTime, B>(value => value.Era, bucket => bucket.Date)],
      ["o", OffsetDateTimePatternParser.HandleOffset],
      ["l", (cursor, builder) => builder.AddEmbeddedLocalPartial(cursor, bucket => bucket.Date, bucket => bucket.Time, value => value.Date, value => value.TimeOfDay, value => value.LocalDateTime)],
    ]));
  }

  constructor(templateValue: OffsetDateTime, twoDigitYearMax: number) {
    Preconditions.CheckArgumentRange("twoDigitYearMax", twoDigitYearMax, 0, 99);
    this._templateValue = templateValue;
    this._twoDigitYearMax = twoDigitYearMax;
  }

  static NewTemplateValueTwoDigitYearMax(templateValue: OffsetDateTime, twoDigitYearMax: number): OffsetDateTimePatternParser {
    return new OffsetDateTimePatternParser(templateValue, twoDigitYearMax);
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  ParsePattern(patternText: string, formatInfo: NodaFormatInfo): IPattern<OffsetDateTime> {
    // Nullity check is performed in OffsetDateTimePattern.
    if (patternText.length === 0) {
      throw new InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    // Handle standard patterns
    if (patternText.length === 1) {
      switch (patternText[0]) {
        case "G":
          return OffsetDateTimePattern.Patterns.GeneralIsoPatternImpl;
        case "o":
          return OffsetDateTimePattern.Patterns.ExtendedIsoPatternImpl;
        case "r":
          return OffsetDateTimePattern.Patterns.FullRoundtripPatternImpl;
        default:
          throw new InvalidPatternException(TextErrorMessages.UnknownStandardFormat, patternText, "NodaTime.OffsetDateTime");
      }
    }

    const templateValue = this._templateValue;
    const twoDigitYearMax = this._twoDigitYearMax;
    const patternBuilder = new SteppedPatternBuilder<OffsetDateTime, OffsetDateTimePatternParserOffsetDateTimeParseBucket>(formatInfo,
      () => new OffsetDateTimePatternParserOffsetDateTimeParseBucket(templateValue, twoDigitYearMax));
    patternBuilder.ParseCustomPattern(patternText, OffsetDateTimePatternParser.PatternCharacterHandlers);
    patternBuilder.ValidateUsedFields();
    // Need to reconstruct the template value from the bits...
    return patternBuilder.Build(templateValue);
  }

  private static HandleOffset(pattern: PatternCursor,
    builder: SteppedPatternBuilder<OffsetDateTime, OffsetDateTimePatternParserOffsetDateTimeParseBucket>): void {
    builder.AddField(PatternFields.EmbeddedOffset, pattern.Current);
    const embeddedPattern = pattern.GetEmbeddedPattern();
    const offsetPattern = OffsetPattern.Create(embeddedPattern, builder.FormatInfo).UnderlyingPattern;
    builder.AddEmbeddedPattern(offsetPattern, (bucket, offset) => (bucket.Offset = offset), zdt => zdt.Offset);
  }
}
