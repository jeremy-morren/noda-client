// Ported from NodaTime 3.3.0: src/NodaTime/Text/OffsetDatePatternParser.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  DatePatternHelper,
  InvalidPatternError,
  LocalDatePatternParserLocalDateParseBucket,
  OffsetDatePattern,
  OffsetPattern,
  ParseBucket,
  ParseResult,
  PatternFields,
  Preconditions,
  SteppedPatternBuilder,
  TextErrorMessages,
} from "../internal.ts";
import type { CharacterHandler, IPattern, IPatternParser, LocalDate, NodaFormatInfo, Offset, OffsetDate, PatternCursor } from "../internal.ts";

let patternCharacterHandlers: Map<string, CharacterHandler<OffsetDate, OffsetDatePatternParserOffsetDateParseBucket>> | undefined;

class OffsetDatePatternParserOffsetDateParseBucket extends ParseBucket<OffsetDate> {
  readonly Date: LocalDatePatternParserLocalDateParseBucket;
  Offset: Offset;

  constructor(templateValue: OffsetDate, twoDigitYearMax: number) {
    super();
    this.Date = new LocalDatePatternParserLocalDateParseBucket(templateValue.Date, twoDigitYearMax);
    this.Offset = templateValue.Offset;
  }

  /** @inheritDoc */
  override CalculateValue(usedFields: PatternFields, text: string): ParseResult<OffsetDate> {
    const dateResult: ParseResult<LocalDate> = this.Date.CalculateValue(usedFields & PatternFields.AllDateFields, text, "NodaTime.OffsetDate");
    if (!dateResult.Success) {
      return dateResult.ConvertError<OffsetDate>();
    }
    const date = dateResult.Value;
    return ParseResult.ForValue(date.WithOffset(this.Offset));
  }
}

/** @internal */
export class OffsetDatePatternParser implements IPatternParser<OffsetDate> {
  private readonly _templateValue: OffsetDate;
  private readonly _twoDigitYearMax: number;

  private static get PatternCharacterHandlers(): Map<string, CharacterHandler<OffsetDate, OffsetDatePatternParserOffsetDateParseBucket>> {
    return (patternCharacterHandlers ??= new Map<string, CharacterHandler<OffsetDate, OffsetDatePatternParserOffsetDateParseBucket>>([
      ["%", SteppedPatternBuilder.HandlePercent],
      ["'", SteppedPatternBuilder.HandleQuote],
      ["\"", SteppedPatternBuilder.HandleQuote],
      ["\\", SteppedPatternBuilder.HandleBackslash],
      ["/", (pattern, builder) => builder.AddLiteral(builder.FormatInfo.DateSeparator, ParseResult.DateSeparatorMismatch)],
      ["y", DatePatternHelper.CreateYearOfEraHandler<OffsetDate, OffsetDatePatternParserOffsetDateParseBucket>(value => value.YearOfEra, (bucket, value) => (bucket.Date.YearOfEra = value))],
      ["u", SteppedPatternBuilder.HandlePaddedField<OffsetDate, OffsetDatePatternParserOffsetDateParseBucket>(
        4, PatternFields.Year, -9999, 9999, value => value.Year, (bucket, value) => (bucket.Date.Year = value))],
      ["M", DatePatternHelper.CreateMonthOfYearHandler<OffsetDate, OffsetDatePatternParserOffsetDateParseBucket>(
        value => value.Month, (bucket, value) => (bucket.Date.MonthOfYearText = value), (bucket, value) => (bucket.Date.MonthOfYearNumeric = value))],
      ["d", DatePatternHelper.CreateDayHandler<OffsetDate, OffsetDatePatternParserOffsetDateParseBucket>(
        value => value.Day, value => value.DayOfWeek, (bucket, value) => (bucket.Date.DayOfMonth = value), (bucket, value) => (bucket.Date.DayOfWeek = value))],
      ["c", DatePatternHelper.CreateCalendarHandler<OffsetDate, OffsetDatePatternParserOffsetDateParseBucket>(value => value.Date.Calendar, (bucket, value) => (bucket.Date.Calendar = value))],
      ["g", DatePatternHelper.CreateEraHandler<OffsetDate, OffsetDatePatternParserOffsetDateParseBucket>(value => value.Era, bucket => bucket.Date)],
      ["o", OffsetDatePatternParser.HandleOffset],
      ["l", (cursor, builder) => builder.AddEmbeddedDatePattern(cursor.Current, cursor.GetEmbeddedPattern(), bucket => bucket.Date, value => value.Date)],
    ]));
  }

  constructor(templateValue: OffsetDate, twoDigitYearMax: number) {
    Preconditions.CheckArgumentRange("twoDigitYearMax", twoDigitYearMax, 0, 99);
    this._templateValue = templateValue;
    this._twoDigitYearMax = twoDigitYearMax;
  }

  static NewTemplateValueTwoDigitYearMax(templateValue: OffsetDate, twoDigitYearMax: number): OffsetDatePatternParser {
    return new OffsetDatePatternParser(templateValue, twoDigitYearMax);
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  ParsePattern(patternText: string, formatInfo: NodaFormatInfo): IPattern<OffsetDate> {
    // Nullity check is performed in OffsetDatePattern.
    if (patternText.length === 0) {
      throw new InvalidPatternError(TextErrorMessages.FormatStringEmpty);
    }

    // Handle standard patterns
    if (patternText.length === 1) {
      switch (patternText[0]) {
        case "G":
          return OffsetDatePattern.Patterns.GeneralIsoPatternImpl;
        case "r":
          return OffsetDatePattern.Patterns.FullRoundtripPatternImpl;
        default:
          throw new InvalidPatternError(TextErrorMessages.UnknownStandardFormat, patternText, "NodaTime.OffsetDate");
      }
    }

    const templateValue = this._templateValue;
    const twoDigitYearMax = this._twoDigitYearMax;
    const patternBuilder = new SteppedPatternBuilder<OffsetDate, OffsetDatePatternParserOffsetDateParseBucket>(formatInfo,
      () => new OffsetDatePatternParserOffsetDateParseBucket(templateValue, twoDigitYearMax));
    patternBuilder.ParseCustomPattern(patternText, OffsetDatePatternParser.PatternCharacterHandlers);
    patternBuilder.ValidateUsedFields();
    // Need to reconstruct the template value from the bits...
    return patternBuilder.Build(templateValue);
  }

  private static HandleOffset(pattern: PatternCursor,
    builder: SteppedPatternBuilder<OffsetDate, OffsetDatePatternParserOffsetDateParseBucket>): void {
    builder.AddField(PatternFields.EmbeddedOffset, pattern.Current);
    const embeddedPattern = pattern.GetEmbeddedPattern();
    const offsetPattern = OffsetPattern.Create(embeddedPattern, builder.FormatInfo).UnderlyingPattern;
    builder.AddEmbeddedPattern(offsetPattern, (bucket, offset) => (bucket.Offset = offset), zdt => zdt.Offset);
  }
}
