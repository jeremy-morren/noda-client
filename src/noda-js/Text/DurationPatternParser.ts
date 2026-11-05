// Ported from NodaTime 3.3.0: src/NodaTime/Text/DurationPatternParser.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  Duration,
  DurationPattern,
  FormatHelper,
  HoursPerDay,
  Int64,
  InvalidPatternError,
  MinutesPerDay,
  MinutesPerHour,
  NanosecondsPerDay,
  NanosecondsPerHour,
  NanosecondsPerMinute,
  NanosecondsPerSecond,
  ParseBucket,
  ParseResult,
  PatternFields,
  Preconditions,
  SecondsPerDay,
  SecondsPerMinute,
  SteppedPatternBuilder,
  TextErrorMessages,
  TimePatternHelper,
} from "../internal.ts";
import type { CharacterHandler, IPattern, IPatternParser, NodaFormatInfo, PatternCursor } from "../internal.ts";
import type { Offset } from "../internal.ts";

let patternCharacterHandlers: Map<string, CharacterHandler<Duration, DurationPatternParserDurationParseBucket>> | undefined;

/**
 * Provides a container for the interim parsed pieces of an {@link Offset} value.
 */
class DurationPatternParserDurationParseBucket extends ParseBucket<Duration> {
  // Note: While we *could* try to optimize this to not use BigInteger, this approach is really simple.
  // noda-js: NodaTime accumulates a BigInteger number of nanoseconds. Every value parsed is non-negative and every unit
  // divides a day exactly, so we keep the same total exactly as whole days plus nanoseconds (both safe integers).
  IsNegative: boolean = false;
  private _currentDays = 0;
  private _currentNanos = 0;

  AddNanoseconds(nanoseconds: number): void {
    this._currentNanos += nanoseconds;
  }

  AddDays(days: number): void {
    this._currentDays += days;
  }

  AddUnits(units: number, nanosecondsPerUnit: number): void {
    const unitsPerDay = NanosecondsPerDay / nanosecondsPerUnit;
    const days = Math.trunc(units / unitsPerDay);
    this._currentDays += days;
    this._currentNanos += (units - days * unitsPerDay) * nanosecondsPerUnit;
  }

  /**
   * Calculates the value from the parsed pieces.
   */
  override CalculateValue(usedFields: PatternFields, text: string): ParseResult<Duration> {
    // noda-js: the total as floor days and a non-negative nanosecond of the day.
    const extraDays = Math.trunc(this._currentNanos / NanosecondsPerDay);
    let days = this._currentDays + extraDays;
    let nanoOfDay = this._currentNanos - extraDays * NanosecondsPerDay;
    if (this.IsNegative) {
      if (nanoOfDay === 0) {
        days = -days;
      } else {
        days = -days - 1;
        nanoOfDay = NanosecondsPerDay - nanoOfDay;
      }
    }
    // (Equivalent to checking the total against Duration.MinNanoseconds and Duration.MaxNanoseconds.)
    if (days < Duration.MinDays || days > Duration.MaxDays) {
      return ParseResult.ForInvalidValuePostParse<Duration>(text, TextErrorMessages.OverallValueOutOfRange,
        "NodaTime.Duration");
    }
    return ParseResult.ForValue(Duration.NewDaysNanoOfDay(days, nanoOfDay));
  }
}

/** @internal */
export class DurationPatternParser implements IPatternParser<Duration> {
  private static get PatternCharacterHandlers(): Map<string, CharacterHandler<Duration, DurationPatternParserDurationParseBucket>> {
    return (patternCharacterHandlers ??= new Map<string, CharacterHandler<Duration, DurationPatternParserDurationParseBucket>>([
      ["%", SteppedPatternBuilder.HandlePercent],
      ["'", SteppedPatternBuilder.HandleQuote],
      ["\"", SteppedPatternBuilder.HandleQuote],
      ["\\", SteppedPatternBuilder.HandleBackslash],
      [".", TimePatternHelper.CreatePeriodHandler<Duration, DurationPatternParserDurationParseBucket>(9, DurationPatternParser.GetPositiveNanosecondOfSecond, (bucket, value) => bucket.AddNanoseconds(value))],
      [":", (pattern, builder) => builder.AddLiteral(builder.FormatInfo.TimeSeparator, ParseResult.TimeSeparatorMismatch)],
      ["D", DurationPatternParser.CreateDayHandler()],
      ["H", DurationPatternParser.CreateTotalHandler(PatternFields.Hours24, NanosecondsPerHour, HoursPerDay, 402653184)],
      ["h", DurationPatternParser.CreatePartialHandler(PatternFields.Hours24, NanosecondsPerHour, HoursPerDay)],
      ["M", DurationPatternParser.CreateTotalHandler(PatternFields.Minutes, NanosecondsPerMinute, MinutesPerDay, 24159191040)],
      ["m", DurationPatternParser.CreatePartialHandler(PatternFields.Minutes, NanosecondsPerMinute, MinutesPerHour)],
      ["S", DurationPatternParser.CreateTotalHandler(PatternFields.Seconds, NanosecondsPerSecond, SecondsPerDay, 1449551462400)],
      ["s", DurationPatternParser.CreatePartialHandler(PatternFields.Seconds, NanosecondsPerSecond, SecondsPerMinute)],
      ["f", TimePatternHelper.CreateFractionHandler<Duration, DurationPatternParserDurationParseBucket>(9, DurationPatternParser.GetPositiveNanosecondOfSecond, (bucket, value) => bucket.AddNanoseconds(value))],
      ["F", TimePatternHelper.CreateFractionHandler<Duration, DurationPatternParserDurationParseBucket>(9, DurationPatternParser.GetPositiveNanosecondOfSecond, (bucket, value) => bucket.AddNanoseconds(value))],
      ["+", DurationPatternParser.HandlePlus],
      ["-", DurationPatternParser.HandleMinus],
    ]));
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  ParsePattern(patternText: string, formatInfo: NodaFormatInfo): IPattern<Duration> {
    Preconditions.CheckNotNull(patternText, "patternText");
    if (patternText.length === 0) {
      throw new InvalidPatternError(TextErrorMessages.FormatStringEmpty);
    }

    if (patternText.length === 1) {
      switch (patternText[0]) {
        case "o":
          return DurationPattern.Patterns.RoundtripPatternImpl;
        case "j":
          return DurationPattern.Patterns.JsonRoundtripPatternImpl;
        default:
          throw new InvalidPatternError(TextErrorMessages.UnknownStandardFormat, patternText, "NodaTime.Duration");
      }
    }

    const patternBuilder = new SteppedPatternBuilder<Duration, DurationPatternParserDurationParseBucket>(formatInfo,
      () => new DurationPatternParserDurationParseBucket());
    patternBuilder.ParseCustomPattern(patternText, DurationPatternParser.PatternCharacterHandlers);
    // Somewhat random sample, admittedly...
    return patternBuilder.Build(Duration.FromHours(1).Plus(Duration.FromMinutes(30)).Plus(Duration.FromSeconds(5)).Plus(Duration.FromMilliseconds(500)));
  }

  private static GetPositiveNanosecondOfSecond(duration: Duration): number {
    return Math.abs(duration.NanosecondOfDay) % NanosecondsPerSecond;
  }

  private static CreateTotalHandler(field: PatternFields, nanosecondsPerUnit: number, unitsPerDay: number, maxValue: number): CharacterHandler<Duration, DurationPatternParserDurationParseBucket> {
    return (pattern, builder) => {
      // Needs to be big enough for 1449551462400 seconds
      const count = pattern.GetRepeatCount(13);
      // AddField would throw an inappropriate exception here, so handle it specially.
      if ((builder.UsedFields & PatternFields.TotalDuration) !== 0) {
        throw new InvalidPatternError(TextErrorMessages.MultipleCapitalDurationFields);
      }
      builder.AddField(field, pattern.Current);
      builder.AddField(PatternFields.TotalDuration, pattern.Current);
      builder.AddParseInt64ValueAction(count, 13, pattern.Current, 0, maxValue, (bucket, value) => bucket.AddUnits(value, nanosecondsPerUnit));
      builder.AddFormatAction((value, sb) => FormatHelper.LeftPadNonNegativeInt64(DurationPatternParser.GetPositiveNanosecondUnits(value, nanosecondsPerUnit, unitsPerDay), count, sb));
    };
  }

  private static CreateDayHandler(): CharacterHandler<Duration, DurationPatternParserDurationParseBucket> {
    return (pattern, builder) => {
      const count = pattern.GetRepeatCount(8); // Enough for 16777216
      // AddField would throw an inappropriate exception here, so handle it specially.
      if ((builder.UsedFields & PatternFields.TotalDuration) !== 0) {
        throw new InvalidPatternError(TextErrorMessages.MultipleCapitalDurationFields);
      }
      builder.AddField(PatternFields.DayOfMonth, pattern.Current);
      builder.AddField(PatternFields.TotalDuration, pattern.Current);
      builder.AddParseValueAction(count, 8, pattern.Current, 0, 16777216, (bucket, value) => bucket.AddDays(value));
      builder.AddFormatLeftPad(count, duration => {
        const days = duration.FloorDays;
        if (days >= 0) {
          return days;
        }
        // Round towards 0.
        return duration.NanosecondOfFloorDay === 0 ? -days : -(days + 1);
      },
      /* assumeNonNegative: */ true,
      /* assumeFitsInCount: */ false);
    };
  }

  private static CreatePartialHandler(field: PatternFields, nanosecondsPerUnit: number, unitsPerContainer: number): CharacterHandler<Duration, DurationPatternParserDurationParseBucket> {
    return (pattern, builder) => {
      const count = pattern.GetRepeatCount(2);
      builder.AddField(field, pattern.Current);
      builder.AddParseValueAction(count, 2, pattern.Current, 0, unitsPerContainer - 1,
        (bucket, value) => bucket.AddUnits(value, nanosecondsPerUnit));
      // This is never used for anything larger than a day, so the day part is irrelevant.
      builder.AddFormatLeftPad(count,
        duration => Int64.Div(Math.abs(duration.NanosecondOfDay), nanosecondsPerUnit) % unitsPerContainer,
        /* assumeNonNegative: */ true,
        /* assumeFitsInCount: */ count === 2);
    };
  }

  private static HandlePlus(pattern: PatternCursor, builder: SteppedPatternBuilder<Duration, DurationPatternParserDurationParseBucket>): void {
    builder.AddField(PatternFields.Sign, pattern.Current);
    builder.AddRequiredSign((bucket, positive) => (bucket.IsNegative = !positive), duration => duration.FloorDays >= 0);
  }

  private static HandleMinus(pattern: PatternCursor, builder: SteppedPatternBuilder<Duration, DurationPatternParserDurationParseBucket>): void {
    builder.AddField(PatternFields.Sign, pattern.Current);
    builder.AddNegativeOnlySign((bucket, positive) => (bucket.IsNegative = !positive), duration => duration.FloorDays >= 0);
  }

  private static GetPositiveNanosecondUnits(duration: Duration, nanosecondsPerUnit: number, unitsPerDay: number): number {
    // The property is declared as an int, but we it as a long to force 64-bit arithmetic when multiplying.
    const floorDays = duration.FloorDays;
    if (floorDays >= 0) {
      return floorDays * unitsPerDay + Int64.Div(duration.NanosecondOfFloorDay, nanosecondsPerUnit);
    } else {
      const nanosecondOfDay = duration.NanosecondOfDay;
      // If it's not an exact number of days, FloorDays will overshoot (negatively) by 1.
      const negativeValue = nanosecondOfDay === 0
        ? floorDays * unitsPerDay
        : (floorDays + 1) * unitsPerDay + Int64.Div(nanosecondOfDay, nanosecondsPerUnit);
      return -negativeValue;
    }
  }
}
