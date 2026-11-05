// Ported from NodaTime 3.3.7: src/NodaTime/Text/YearMonthPatternParser.cs
// Copyright 2019 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  DatePatternHelper,
  InvalidPatternException,
  LocalDatePatternParserLocalDateParseBucket as LocalDateParseBucket,
  ParseBucket,
  ParseResult,
  PatternFields,
  Preconditions,
  SteppedPatternBuilder,
  TextErrorMessages,
  YearMonthPattern,
} from "../internal.ts";
import type { CharacterHandler, IPattern, IPatternParser, NodaFormatInfo, YearMonth } from "../internal.ts";

let patternCharacterHandlers: Map<string, CharacterHandler<YearMonth, YearMonthPatternParserYearMonthParseBucket>> | undefined;

/**
 * Bucket to put parsed values in, ready for later result calculation.
 * Actually just delegates to a LocalDateParseBucket.
 * @internal
 */
export class YearMonthPatternParserYearMonthParseBucket extends ParseBucket<YearMonth> {
  readonly DateBucket: LocalDateParseBucket;

  constructor(templateValue: YearMonth, twoDigitYearMax: number) {
    super();
    this.DateBucket = new LocalDateParseBucket(templateValue.StartDate, twoDigitYearMax);
  }

  /** @inheritDoc */
  override CalculateValue(usedFields: PatternFields, text: string): ParseResult<YearMonth> {
    const result = this.DateBucket.CalculateValue(usedFields, text, "NodaTime.YearMonth");
    if (!result.Success) {
      return result.ConvertError<YearMonth>();
    }
    return ParseResult.ForValue(result.Value.ToYearMonth());
  }
}

/**
 * Parser for patterns of {@link YearMonth} values.
 * @internal
 */
export class YearMonthPatternParser implements IPatternParser<YearMonth> {
  static readonly YearMonthParseBucket = YearMonthPatternParserYearMonthParseBucket;

  private readonly _templateValue: YearMonth;
  private readonly _twoDigitYearMax: number;

  private static get PatternCharacterHandlers(): Map<string, CharacterHandler<YearMonth, YearMonthPatternParserYearMonthParseBucket>> {
    return (patternCharacterHandlers ??= new Map<string, CharacterHandler<YearMonth, YearMonthPatternParserYearMonthParseBucket>>([
      ["%", SteppedPatternBuilder.HandlePercent],
      ["'", SteppedPatternBuilder.HandleQuote],
      ["\"", SteppedPatternBuilder.HandleQuote],
      ["\\", SteppedPatternBuilder.HandleBackslash],
      ["/", (pattern, builder) => builder.AddLiteral(builder.FormatInfo.DateSeparator, ParseResult.DateSeparatorMismatch)],
      ["y", DatePatternHelper.CreateYearOfEraHandler<YearMonth, YearMonthPatternParserYearMonthParseBucket>(value => value.YearOfEra, (bucket, value) => (bucket.DateBucket.YearOfEra = value))],
      ["u", SteppedPatternBuilder.HandlePaddedField<YearMonth, YearMonthPatternParserYearMonthParseBucket>(
        4, PatternFields.Year, -9998, 9999, value => value.Year, (bucket, value) => (bucket.DateBucket.Year = value))],
      ["M", DatePatternHelper.CreateMonthOfYearHandler<YearMonth, YearMonthPatternParserYearMonthParseBucket>(
        value => value.Month, (bucket, value) => (bucket.DateBucket.MonthOfYearText = value), (bucket, value) => (bucket.DateBucket.MonthOfYearNumeric = value))],
      ["c", DatePatternHelper.CreateCalendarHandler<YearMonth, YearMonthPatternParserYearMonthParseBucket>(value => value.Calendar, (bucket, value) => (bucket.DateBucket.Calendar = value))],
      ["g", DatePatternHelper.CreateEraHandler<YearMonth, YearMonthPatternParserYearMonthParseBucket>(date => date.Era, bucket => bucket.DateBucket)],
    ]));
  }

  constructor(templateValue: YearMonth, twoDigitYearMax: number) {
    Preconditions.CheckArgumentRange("twoDigitYearMax", twoDigitYearMax, 0, 99);
    this._templateValue = templateValue;
    this._twoDigitYearMax = twoDigitYearMax;
  }

  static NewTemplateValueTwoDigitYearMax(templateValue: YearMonth, twoDigitYearMax: number): YearMonthPatternParser {
    return new YearMonthPatternParser(templateValue, twoDigitYearMax);
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  ParsePattern(patternText: string, formatInfo: NodaFormatInfo): IPattern<YearMonth> {
    const parseNoStandardExpansion = (patternTextLocal: string): IPattern<YearMonth> => {
      const templateValue = this._templateValue;
      const twoDigitYearMax = this._twoDigitYearMax;
      const patternBuilder = new SteppedPatternBuilder<YearMonth, YearMonthPatternParserYearMonthParseBucket>(formatInfo,
        () => new YearMonthPatternParserYearMonthParseBucket(templateValue, twoDigitYearMax));
      patternBuilder.ParseCustomPattern(patternTextLocal, YearMonthPatternParser.PatternCharacterHandlers);
      patternBuilder.ValidateUsedFields();
      return patternBuilder.Build(templateValue);
    };

    // Nullity check is performed in YearMonthPattern.
    if (patternText.length === 0) {
      throw new InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    if (patternText.length === 1) {
      switch (patternText[0]) {
        // Invariant standard patterns return cached implementations.
        case "g":
          return YearMonthPattern.Patterns.IsoPatternImpl;
        // Culture-specific default pattern
        case "G":
          return parseNoStandardExpansion(formatInfo.DateTimeFormat.YearMonthPattern);
        // Unknown standard patterns fail.
        default:
          throw new InvalidPatternException(TextErrorMessages.UnknownStandardFormat, patternText, "NodaTime.YearMonth");
      }
    }

    return parseNoStandardExpansion(patternText);
  }
}
