// Ported from NodaTime 3.3.0: src/NodaTime/Text/OffsetTimePatternParser.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  InvalidPatternError,
  LocalTimePatternParserLocalTimeParseBucket,
  OffsetPattern,
  OffsetTimePattern,
  ParseBucket,
  ParseResult,
  PatternFields,
  SteppedPatternBuilder,
  TextErrorMessages,
  TimePatternHelper,
} from "../internal.ts";
import type { CharacterHandler, IPattern, IPatternParser, LocalTime, NodaFormatInfo, Offset, OffsetTime, PatternCursor } from "../internal.ts";

let patternCharacterHandlers: Map<string, CharacterHandler<OffsetTime, OffsetTimePatternParserOffsetTimeParseBucket>> | undefined;

class OffsetTimePatternParserOffsetTimeParseBucket extends ParseBucket<OffsetTime> {
  readonly Time: LocalTimePatternParserLocalTimeParseBucket;
  Offset: Offset;

  constructor(templateValue: OffsetTime) {
    super();
    this.Time = new LocalTimePatternParserLocalTimeParseBucket(templateValue.TimeOfDay);
    this.Offset = templateValue.Offset;
  }

  /** @inheritDoc */
  override CalculateValue(usedFields: PatternFields, text: string): ParseResult<OffsetTime> {
    const timeResult: ParseResult<LocalTime> = this.Time.CalculateValue(usedFields & PatternFields.AllTimeFields, text, "NodaTime.OffsetTime");
    if (!timeResult.Success) {
      return timeResult.ConvertError<OffsetTime>();
    }
    const date = timeResult.Value;
    return ParseResult.ForValue(date.WithOffset(this.Offset));
  }
}

/** @internal */
export class OffsetTimePatternParser implements IPatternParser<OffsetTime> {
  private readonly _templateValue: OffsetTime;

  private static get PatternCharacterHandlers(): Map<string, CharacterHandler<OffsetTime, OffsetTimePatternParserOffsetTimeParseBucket>> {
    return (patternCharacterHandlers ??= new Map<string, CharacterHandler<OffsetTime, OffsetTimePatternParserOffsetTimeParseBucket>>([
      ["%", SteppedPatternBuilder.HandlePercent],
      ["'", SteppedPatternBuilder.HandleQuote],
      ["\"", SteppedPatternBuilder.HandleQuote],
      ["\\", SteppedPatternBuilder.HandleBackslash],
      [".", TimePatternHelper.CreatePeriodHandler<OffsetTime, OffsetTimePatternParserOffsetTimeParseBucket>(9, value => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
      [";", TimePatternHelper.CreateCommaDotHandler<OffsetTime, OffsetTimePatternParserOffsetTimeParseBucket>(9, value => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
      [":", (pattern, builder) => builder.AddLiteral(builder.FormatInfo.TimeSeparator, ParseResult.TimeSeparatorMismatch)],
      ["h", SteppedPatternBuilder.HandlePaddedField<OffsetTime, OffsetTimePatternParserOffsetTimeParseBucket>(
        2, PatternFields.Hours12, 1, 12, value => value.ClockHourOfHalfDay, (bucket, value) => (bucket.Time.Hours12 = value))],
      ["H", SteppedPatternBuilder.HandlePaddedField<OffsetTime, OffsetTimePatternParserOffsetTimeParseBucket>(
        2, PatternFields.Hours24, 0, 24, value => value.Hour, (bucket, value) => (bucket.Time.Hours24 = value))],
      ["m", SteppedPatternBuilder.HandlePaddedField<OffsetTime, OffsetTimePatternParserOffsetTimeParseBucket>(
        2, PatternFields.Minutes, 0, 59, value => value.Minute, (bucket, value) => (bucket.Time.Minutes = value))],
      ["s", SteppedPatternBuilder.HandlePaddedField<OffsetTime, OffsetTimePatternParserOffsetTimeParseBucket>(
        2, PatternFields.Seconds, 0, 59, value => value.Second, (bucket, value) => (bucket.Time.Seconds = value))],
      ["f", TimePatternHelper.CreateFractionHandler<OffsetTime, OffsetTimePatternParserOffsetTimeParseBucket>(9, value => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
      ["F", TimePatternHelper.CreateFractionHandler<OffsetTime, OffsetTimePatternParserOffsetTimeParseBucket>(9, value => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
      ["t", TimePatternHelper.CreateAmPmHandler<OffsetTime, OffsetTimePatternParserOffsetTimeParseBucket>(time => time.Hour, (bucket, value) => (bucket.Time.AmPm = value))],
      ["o", OffsetTimePatternParser.HandleOffset],
      ["l", (cursor, builder) => builder.AddEmbeddedTimePattern(cursor.Current, cursor.GetEmbeddedPattern(), bucket => bucket.Time, value => value.TimeOfDay)],
    ]));
  }

  constructor(templateValue: OffsetTime) {
    this._templateValue = templateValue;
  }

  static NewTemplateValue(templateValue: OffsetTime): OffsetTimePatternParser {
    return new OffsetTimePatternParser(templateValue);
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  ParsePattern(patternText: string, formatInfo: NodaFormatInfo): IPattern<OffsetTime> {
    // Nullity check is performed in OffsetTimePattern.
    if (patternText.length === 0) {
      throw new InvalidPatternError(TextErrorMessages.FormatStringEmpty);
    }

    // Handle standard patterns
    if (patternText.length === 1) {
      switch (patternText[0]) {
        case "G":
          return OffsetTimePattern.Patterns.GeneralIsoPatternImpl;
        case "o":
          return OffsetTimePattern.Patterns.ExtendedIsoPatternImpl;
        default:
          throw new InvalidPatternError(TextErrorMessages.UnknownStandardFormat, patternText[0], "NodaTime.OffsetTime");
      }
    }

    const templateValue = this._templateValue;
    const patternBuilder = new SteppedPatternBuilder<OffsetTime, OffsetTimePatternParserOffsetTimeParseBucket>(formatInfo,
      () => new OffsetTimePatternParserOffsetTimeParseBucket(templateValue));
    patternBuilder.ParseCustomPattern(patternText, OffsetTimePatternParser.PatternCharacterHandlers);
    patternBuilder.ValidateUsedFields();
    // Need to reconstruct the template value from the bits...
    return patternBuilder.Build(templateValue);
  }

  private static HandleOffset(pattern: PatternCursor,
    builder: SteppedPatternBuilder<OffsetTime, OffsetTimePatternParserOffsetTimeParseBucket>): void {
    builder.AddField(PatternFields.EmbeddedOffset, pattern.Current);
    const embeddedPattern = pattern.GetEmbeddedPattern();
    const offsetPattern = OffsetPattern.Create(embeddedPattern, builder.FormatInfo).UnderlyingPattern;
    builder.AddEmbeddedPattern(offsetPattern, (bucket, offset) => (bucket.Offset = offset), zdt => zdt.Offset);
  }
}
