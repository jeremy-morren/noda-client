// Ported from NodaTime 3.3.7: src/NodaTime/Text/LocalTimePatternParser.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  InvalidPatternException,
  LocalTime,
  LocalTimePattern,
  ParseBucket,
  ParseResult,
  PatternFields,
  SteppedPatternBuilder,
  TextErrorMessages,
  TimePatternHelper,
} from "../internal.ts";
import type { CharacterHandler, IPattern, IPatternParser, NodaFormatInfo } from "../internal.ts";

/** PatternFieldsExtensions.HasAny */
function HasAny(fields: PatternFields, target: PatternFields): boolean {
  return (fields & target) !== 0;
}

/** PatternFieldsExtensions.HasAll */
function HasAll(fields: PatternFields, target: PatternFields): boolean {
  return (fields & target) === target;
}

const Hour24MinuteSecond = PatternFields.Hours24 | PatternFields.Minutes | PatternFields.Seconds;
const AllTimeFieldsExceptFractionalSeconds = PatternFields.AllTimeFields ^ PatternFields.FractionalSeconds;

/**
 * Bucket to put parsed values in, ready for later result calculation. This type is also used
 * by LocalDateTimePattern to store and calculate values.
 * (C#: LocalTimePatternParser.LocalTimeParseBucket)
 * @internal
 */
export class LocalTimePatternParserLocalTimeParseBucket extends ParseBucket<LocalTime> {
  readonly TemplateValue: LocalTime;

  /** The fractions of a second in nanoseconds, in the range [0, 999999999] */
  FractionalSeconds: number;

  /** The hours in the range [0, 23]. */
  Hours24 = 0;

  /** The hours in the range [1, 12]. */
  Hours12 = 0;

  /** The minutes in the range [0, 59]. */
  Minutes: number;

  /** The seconds in the range [0, 59]. */
  Seconds: number;

  /**
   * AM (0) or PM (1) - or "take from the template" (2). The latter is used in situations
   * where we're parsing but there is no AM or PM designator.
   */
  AmPm = 0;

  constructor(templateValue: LocalTime) {
    super();
    this.TemplateValue = templateValue;
    // By copying these out of the template value now, we don't have to use any conditional
    // logic later on.
    this.Minutes = templateValue.Minute;
    this.Seconds = templateValue.Second;
    this.FractionalSeconds = templateValue.NanosecondOfSecond;
  }

  /** @internal */
  static NewTemplateValue(templateValue: LocalTime): LocalTimePatternParserLocalTimeParseBucket {
    return new LocalTimePatternParserLocalTimeParseBucket(templateValue);
  }

  /**
   * Calculates the value from the parsed pieces.
   * (noda-js: also the overload with an eventualResultType parameter: a type name, e.g. "NodaTime.LocalDateTime".)
   */
  override CalculateValue(usedFields: PatternFields, text: string, eventualResultType: string = "NodaTime.LocalTime"): ParseResult<LocalTime> {
    // Optimize common situation for ISO values.
    if ((usedFields & AllTimeFieldsExceptFractionalSeconds) === Hour24MinuteSecond) {
      return ParseResult.ForValue(LocalTime.FromHourMinuteSecondNanosecondTrusted(this.Hours24, this.Minutes, this.Seconds, this.FractionalSeconds));
    }

    // If this bucket was created from an embedded pattern, it's already been computed.
    if (HasAny(usedFields, PatternFields.EmbeddedTime)) {
      return ParseResult.ForValue(LocalTime.FromHourMinuteSecondNanosecondTrusted(this.Hours24, this.Minutes, this.Seconds, this.FractionalSeconds));
    }

    if (this.AmPm === 2) {
      this.AmPm = Math.trunc(this.TemplateValue.Hour / 12);
    }
    const [failure, hour] = this.DetermineHour(usedFields, text, eventualResultType);
    if (failure !== null) {
      return failure;
    }
    return ParseResult.ForValue(LocalTime.FromHourMinuteSecondNanosecondTrusted(hour, this.Minutes, this.Seconds, this.FractionalSeconds));
  }

  // noda-js: the C# out parameter (hour) is the second element of the returned tuple.
  private DetermineHour(usedFields: PatternFields, text: string, eventualResultType: string): [ParseResult<LocalTime> | null, number] {
    let hour = 0;
    if (HasAny(usedFields, PatternFields.Hours24)) {
      if (HasAll(usedFields, PatternFields.Hours12 | PatternFields.Hours24)) {
        if (this.Hours12 % 12 !== this.Hours24 % 12) {
          return [ParseResult.InconsistentValues<LocalTime>(text, "H", "h", eventualResultType), hour];
        }
      }
      if (HasAny(usedFields, PatternFields.AmPm)) {
        if (Math.trunc(this.Hours24 / 12) !== this.AmPm) {
          return [ParseResult.InconsistentValues<LocalTime>(text, "H", "t", eventualResultType), hour];
        }
      }
      hour = this.Hours24;
      return [null, hour];
    }
    // Okay, it's definitely valid - but we've still got 8 possibilities for what's been specified.
    switch (usedFields & (PatternFields.Hours12 | PatternFields.AmPm)) {
      case PatternFields.Hours12 | PatternFields.AmPm:
        hour = (this.Hours12 % 12) + this.AmPm * 12;
        break;
      case PatternFields.Hours12:
        // Preserve AM/PM from template value
        hour = (this.Hours12 % 12) + Math.trunc(this.TemplateValue.Hour / 12) * 12;
        break;
      case PatternFields.AmPm:
        // Preserve 12-hour hour of day from template value, use specified AM/PM
        hour = (this.TemplateValue.Hour % 12) + this.AmPm * 12;
        break;
      case 0:
        hour = this.TemplateValue.Hour;
        break;
    }
    return [null, hour];
  }
}

let patternCharacterHandlers: ReadonlyMap<string, CharacterHandler<LocalTime, LocalTimePatternParserLocalTimeParseBucket>> | undefined;

function GetPatternCharacterHandlers(): ReadonlyMap<string, CharacterHandler<LocalTime, LocalTimePatternParserLocalTimeParseBucket>> {
  type Bucket = LocalTimePatternParserLocalTimeParseBucket;
  return (patternCharacterHandlers ??= new Map<string, CharacterHandler<LocalTime, Bucket>>([
    ["%", SteppedPatternBuilder.HandlePercent],
    ["'", SteppedPatternBuilder.HandleQuote],
    ['"', SteppedPatternBuilder.HandleQuote],
    ["\\", SteppedPatternBuilder.HandleBackslash],
    [".", TimePatternHelper.CreatePeriodHandler<LocalTime, Bucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => (bucket.FractionalSeconds = value))],
    [";", TimePatternHelper.CreateCommaDotHandler<LocalTime, Bucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => (bucket.FractionalSeconds = value))],
    [":", (pattern, builder) => builder.AddLiteral(builder.FormatInfo.TimeSeparator, ParseResult.TimeSeparatorMismatch<LocalTime>)],
    [
      "h",
      SteppedPatternBuilder.HandlePaddedField<LocalTime, Bucket>(2, PatternFields.Hours12, 1, 12, (value) => value.ClockHourOfHalfDay, (bucket, value) => (bucket.Hours12 = value)),
    ],
    ["H", SteppedPatternBuilder.HandlePaddedField<LocalTime, Bucket>(2, PatternFields.Hours24, 0, 23, (value) => value.Hour, (bucket, value) => (bucket.Hours24 = value))],
    ["m", SteppedPatternBuilder.HandlePaddedField<LocalTime, Bucket>(2, PatternFields.Minutes, 0, 59, (value) => value.Minute, (bucket, value) => (bucket.Minutes = value))],
    ["s", SteppedPatternBuilder.HandlePaddedField<LocalTime, Bucket>(2, PatternFields.Seconds, 0, 59, (value) => value.Second, (bucket, value) => (bucket.Seconds = value))],
    ["f", TimePatternHelper.CreateFractionHandler<LocalTime, Bucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => (bucket.FractionalSeconds = value))],
    ["F", TimePatternHelper.CreateFractionHandler<LocalTime, Bucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => (bucket.FractionalSeconds = value))],
    ["t", TimePatternHelper.CreateAmPmHandler<LocalTime, Bucket>((time) => time.Hour, (bucket, value) => (bucket.AmPm = value))],
  ]));
}

/**
 * Pattern parser for {@link LocalTime} values.
 * @internal
 */
export class LocalTimePatternParser implements IPatternParser<LocalTime> {
  /** @internal */
  static readonly LocalTimeParseBucket = LocalTimePatternParserLocalTimeParseBucket;

  private readonly _templateValue: LocalTime;

  constructor(templateValue: LocalTime) {
    this._templateValue = templateValue;
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  ParsePattern(patternText: string, formatInfo: NodaFormatInfo): IPattern<LocalTime> {
    // Nullity check is performed in LocalTimePattern.
    if (patternText.length === 0) {
      throw new InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    const parseNoStandardExpansion = (patternTextLocal: string): IPattern<LocalTime> => {
      const patternBuilder = new SteppedPatternBuilder<LocalTime, LocalTimePatternParserLocalTimeParseBucket>(
        formatInfo,
        () => new LocalTimePatternParserLocalTimeParseBucket(this._templateValue),
      );
      patternBuilder.ParseCustomPattern(patternTextLocal, GetPatternCharacterHandlers());
      patternBuilder.ValidateUsedFields();
      return patternBuilder.Build(this._templateValue);
    };

    if (patternText.length === 1) {
      switch (patternText[0]) {
        // Invariant standard patterns return cached implementations.
        case "o":
          return LocalTimePattern.Patterns.ExtendedIsoPatternImpl;
        case "O":
          return LocalTimePattern.Patterns.LongExtendedIsoPatternImpl;
        // Other standard patterns expand the pattern text to the appropriate custom pattern.
        // Note: we don't just recurse, as otherwise a ShortTimePattern of 't' (for example) would cause a stack overflow.
        case "t":
          return parseNoStandardExpansion(formatInfo.DateTimeFormat.ShortTimePattern);
        case "T":
          return parseNoStandardExpansion(formatInfo.DateTimeFormat.LongTimePattern);
        case "r":
          return parseNoStandardExpansion("HH:mm:ss.FFFFFFFFF");
        // Unknown standard patterns fail.
        default:
          throw new InvalidPatternException(TextErrorMessages.UnknownStandardFormat, patternText, "NodaTime.LocalTime");
      }
    }
    return parseNoStandardExpansion(patternText);
  }
}
