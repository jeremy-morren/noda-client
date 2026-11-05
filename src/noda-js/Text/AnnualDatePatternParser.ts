// Ported from NodaTime 3.3.7: src/NodaTime/Text/AnnualDatePatternParser.cs
// Copyright 2018 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  AnnualDate,
  AnnualDatePattern,
  CalendarSystem,
  DatePatternHelper,
  InvalidPatternException,
  ParseBucket,
  ParseResult,
  PatternFields,
  SteppedPatternBuilder,
  TextErrorMessages,
} from "../internal.ts";
import type { CharacterHandler, IPattern, IPatternParser, NodaFormatInfo, PatternCursor } from "../internal.ts";
import { NewInvalidOperationException } from "../internal.ts";

let patternCharacterHandlers: Map<string, CharacterHandler<AnnualDate, AnnualDatePatternParserAnnualDateParseBucket>> | undefined;

/**
 * Bucket to put parsed values in, ready for later result calculation. This type is also used
 * by AnnualDateTimePattern to store and calculate values.
 * @internal
 */
export class AnnualDatePatternParserAnnualDateParseBucket extends ParseBucket<AnnualDate> {
  readonly TemplateValue: AnnualDate;
  MonthOfYearNumeric: number = 0;
  MonthOfYearText: number = 0;
  DayOfMonth: number = 0;

  constructor(templateValue: AnnualDate) {
    super();
    this.TemplateValue = templateValue;
  }

  /** @inheritDoc */
  override CalculateValue(usedFields: PatternFields, text: string): ParseResult<AnnualDate> {
    // This will set MonthOfYearNumeric if necessary
    const failure = this.DetermineMonth(usedFields, text);
    if (failure !== null) {
      return failure;
    }

    const day = (usedFields & PatternFields.DayOfMonth) !== 0 ? this.DayOfMonth : this.TemplateValue.Day;
    // Validate for the year 2000, just like the AnnualDate constructor does.
    if (day > CalendarSystem.Iso.GetDaysInMonth(2000, this.MonthOfYearNumeric)) {
      return ParseResult.DayOfMonthOutOfRangeNoYear<AnnualDate>(text, day, this.MonthOfYearNumeric);
    }

    return ParseResult.ForValue(new AnnualDate(this.MonthOfYearNumeric, day));
  }

  private DetermineMonth(usedFields: PatternFields, text: string): ParseResult<AnnualDate> | null {
    switch (usedFields & (PatternFields.MonthOfYearNumeric | PatternFields.MonthOfYearText)) {
      case PatternFields.MonthOfYearNumeric:
        // No-op
        break;
      case PatternFields.MonthOfYearText:
        this.MonthOfYearNumeric = this.MonthOfYearText;
        break;
      case PatternFields.MonthOfYearNumeric | PatternFields.MonthOfYearText:
        if (this.MonthOfYearNumeric !== this.MonthOfYearText) {
          return ParseResult.InconsistentMonthValues<AnnualDate>(text);
        }
        // No need to change MonthOfYearNumeric - this was just a check
        break;
      case 0:
        this.MonthOfYearNumeric = this.TemplateValue.Month;
        break;
    }
    if (this.MonthOfYearNumeric > CalendarSystem.Iso.GetMonthsInYear(2000)) {
      return ParseResult.IsoMonthOutOfRange<AnnualDate>(text, this.MonthOfYearNumeric);
    }
    return null;
  }
}

/**
 * Parser for patterns of {@link AnnualDate} values.
 * @internal
 */
export class AnnualDatePatternParser implements IPatternParser<AnnualDate> {
  static readonly AnnualDateParseBucket = AnnualDatePatternParserAnnualDateParseBucket;

  private readonly _templateValue: AnnualDate;

  private static get PatternCharacterHandlers(): Map<string, CharacterHandler<AnnualDate, AnnualDatePatternParserAnnualDateParseBucket>> {
    return (patternCharacterHandlers ??= new Map<string, CharacterHandler<AnnualDate, AnnualDatePatternParserAnnualDateParseBucket>>([
      ["%", SteppedPatternBuilder.HandlePercent],
      ["'", SteppedPatternBuilder.HandleQuote],
      ["\"", SteppedPatternBuilder.HandleQuote],
      ["\\", SteppedPatternBuilder.HandleBackslash],
      ["/", (pattern, builder) => builder.AddLiteral(builder.FormatInfo.DateSeparator, ParseResult.DateSeparatorMismatch)],
      ["M", DatePatternHelper.CreateMonthOfYearHandler<AnnualDate, AnnualDatePatternParserAnnualDateParseBucket>(
        value => value.Month, (bucket, value) => (bucket.MonthOfYearText = value), (bucket, value) => (bucket.MonthOfYearNumeric = value))],
      ["d", AnnualDatePatternParser.HandleDayOfMonth],
    ]));
  }

  constructor(templateValue: AnnualDate) {
    this._templateValue = templateValue;
  }

  static NewTemplateValue(templateValue: AnnualDate): AnnualDatePatternParser {
    return new AnnualDatePatternParser(templateValue);
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  ParsePattern(patternText: string, formatInfo: NodaFormatInfo): IPattern<AnnualDate> {
    // Nullity check is performed in AnnualDatePattern.
    if (patternText.length === 0) {
      throw new InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    if (patternText.length === 1) {
      switch (patternText[0]) {
        case "G":
          return AnnualDatePattern.Iso;
        default:
          throw new InvalidPatternException(TextErrorMessages.UnknownStandardFormat, patternText, "NodaTime.AnnualDate");
      }
    }

    const templateValue = this._templateValue;
    const patternBuilder = new SteppedPatternBuilder<AnnualDate, AnnualDatePatternParserAnnualDateParseBucket>(formatInfo,
      () => new AnnualDatePatternParserAnnualDateParseBucket(templateValue));
    patternBuilder.ParseCustomPattern(patternText, AnnualDatePatternParser.PatternCharacterHandlers);
    patternBuilder.ValidateUsedFields();
    return patternBuilder.Build(templateValue);
  }

  private static HandleDayOfMonth(pattern: PatternCursor, builder: SteppedPatternBuilder<AnnualDate, AnnualDatePatternParserAnnualDateParseBucket>): void {
    const count = pattern.GetRepeatCount(2);
    let field: PatternFields;
    switch (count) {
      case 1:
      case 2:
        field = PatternFields.DayOfMonth;
        // Handle real maximum value in the bucket
        builder.AddParseValueAction(count, 2, pattern.Current, 1, 99, (bucket, value) => (bucket.DayOfMonth = value));
        builder.AddFormatLeftPad(count, value => value.Day, /* assumeNonNegative: */ true, /* assumeFitsInCount: */ count === 2);
        break;
      default:
        throw NewInvalidOperationException("Invalid count!");
    }
    builder.AddField(field, pattern.Current);
  }
}
