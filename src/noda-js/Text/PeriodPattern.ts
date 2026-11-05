// Ported from NodaTime 3.3.0: src/NodaTime/Text/PeriodPattern.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  FormatHelper,
  Int64,
  MillisecondsPerSecond,
  NanosecondsPerMillisecond,
  NanosecondsPerTick,
  ParseResult,
  Period,
  PeriodBuilder,
  PeriodUnits,
  Preconditions,
  StringBuilder,
  TextErrorMessages,
  TicksPerMillisecond,
  ValueCursor,
} from "../internal.ts";
import type { IPattern, Int64Value } from "../internal.ts";
import type { OverflowError } from "../internal.ts";

let roundtrip: PeriodPattern | undefined;
let normalizingIso: PeriodPattern | undefined;

function AppendValue(builder: StringBuilder, value: Int64Value, suffix: string): void {
  // Avoid having a load of conditions in the calling code by checking here
  if (value === 0) {
    return;
  }
  FormatHelper.FormatInvariant(value, builder);
  builder.Append(suffix);
}

function InvalidUnit(cursor: ValueCursor, unitCharacter: string): ParseResult<Period> {
  return ParseResult.ForInvalidValue<Period>(cursor, TextErrorMessages.InvalidUnitSpecifier, unitCharacter);
}

function RepeatedUnit(cursor: ValueCursor, unitCharacter: string): ParseResult<Period> {
  return ParseResult.ForInvalidValue<Period>(cursor, TextErrorMessages.RepeatedUnitSpecifier, unitCharacter);
}

function MisplacedUnit(cursor: ValueCursor, unitCharacter: string): ParseResult<Period> {
  return ParseResult.ForInvalidValue<Period>(cursor, TextErrorMessages.MisplacedUnitSpecifier, unitCharacter);
}

class PeriodPatternRoundtripPatternImpl implements IPattern<Period> {
  /** @inheritDoc */
  Parse(text: string | null): ParseResult<Period> {
    if (text === null || text === undefined) {
      return ParseResult.ArgumentNull<Period>("text");
    }
    if (text.length === 0) {
      return ParseResult.ValueStringEmpty as ParseResult<Period>;
    }

    const valueCursor = new ValueCursor(text);

    valueCursor.MoveNext();
    // noda-js: read into a local so TypeScript doesn't narrow valueCursor.current for the rest of the method.
    const firstCharacter: string = valueCursor.Current;
    if (firstCharacter !== "P") {
      return ParseResult.MismatchedCharacter<Period>(valueCursor, "P");
    }
    let inDate = true;
    const builder = new PeriodBuilder();
    let unitsSoFar: PeriodUnits = 0;
    while (valueCursor.MoveNext()) {
      if (inDate && valueCursor.Current === "T") {
        inDate = false;
        continue;
      }
      const [failure, unitValue] = valueCursor.ParseInt64<Period>("NodaTime.Period");
      if (failure !== null) {
        return failure;
      }
      if (valueCursor.Length === valueCursor.Index) {
        return ParseResult.EndOfString<Period>(valueCursor);
      }
      // Various failure cases:
      // - Repeated unit (e.g. P1M2M)
      // - Time unit is in date part (e.g. P5M)
      // - Date unit is in time part (e.g. PT1D)
      // - Unit is in incorrect order (e.g. P5D1Y)
      // - Unit is invalid (e.g. P5J)
      // - Unit is missing (e.g. P5)
      let unit: PeriodUnits;
      switch (valueCursor.Current) {
        case "Y": unit = PeriodUnits.Years; break;
        case "M": unit = inDate ? PeriodUnits.Months : PeriodUnits.Minutes; break;
        case "W": unit = PeriodUnits.Weeks; break;
        case "D": unit = PeriodUnits.Days; break;
        case "H": unit = PeriodUnits.Hours; break;
        case "S": unit = PeriodUnits.Seconds; break;
        case "s": unit = PeriodUnits.Milliseconds; break;
        case "t": unit = PeriodUnits.Ticks; break;
        case "n": unit = PeriodUnits.Nanoseconds; break;
        default: return InvalidUnit(valueCursor, valueCursor.Current);
      }
      if ((unit & unitsSoFar) !== 0) {
        return RepeatedUnit(valueCursor, valueCursor.Current);
      }

      // This handles putting months before years, for example. Less significant units
      // have higher integer representations.
      if (unit < unitsSoFar) {
        return MisplacedUnit(valueCursor, valueCursor.Current);
      }
      // The result of checking "there aren't any time units in this unit" should be
      // equal to "we're still in the date part".
      if (((unit & PeriodUnits.AllTimeUnits) === 0) !== inDate) {
        return MisplacedUnit(valueCursor, valueCursor.Current);
      }
      builder.set(unit, unitValue);
      unitsSoFar |= unit;
    }
    return ParseResult.ForValue(builder.Build());
  }

  /** @inheritDoc */
  Format(value: Period): string {
    return this.AppendFormat(value, new StringBuilder()).toString();
  }

  /** @inheritDoc */
  AppendFormat(value: Period, builder: StringBuilder): StringBuilder {
    Preconditions.CheckNotNull(value, "value");
    Preconditions.CheckNotNull(builder, "builder");
    // Always ensure we've got *some* unit to ensure the result is valid in ISO-8601; arbitrarily pick days.
    // Note: "P0S" might be nicer here, but NormalizingIsoPatternImpl picked "P0D" a
    // long time ago and we want to be consistent between the two.
    // We might want to make both pattern implementations configurable at some point.
    if (value.Equals(Period.Zero)) {
      builder.Append("P0D");
      return builder;
    }
    builder.Append("P");
    AppendValue(builder, value.Years, "Y");
    AppendValue(builder, value.Months, "M");
    AppendValue(builder, value.Weeks, "W");
    AppendValue(builder, value.Days, "D");
    if (value.HasTimeComponent) {
      builder.Append("T");
      // noda-js: the exact values, as the long-valued properties may exceed 2^53.
      AppendValue(builder, value.ExactHours, "H");
      AppendValue(builder, value.ExactMinutes, "M");
      AppendValue(builder, value.ExactSeconds, "S");
      AppendValue(builder, value.ExactMilliseconds, "s");
      AppendValue(builder, value.ExactTicks, "t");
      AppendValue(builder, value.ExactNanoseconds, "n");
    }
    return builder;
  }
}

class PeriodPatternNormalizingIsoPatternImpl implements IPattern<Period> {
  // TODO(misc): Tidy this up a *lot*.
  /** @inheritDoc */
  Parse(text: string | null): ParseResult<Period> {
    if (text === null || text === undefined) {
      return ParseResult.ArgumentNull<Period>("text");
    }
    if (text.length === 0) {
      return ParseResult.ValueStringEmpty as ParseResult<Period>;
    }

    const valueCursor = new ValueCursor(text);

    valueCursor.MoveNext();
    // noda-js: read into a local so TypeScript doesn't narrow valueCursor.current for the rest of the method.
    const firstCharacter: string = valueCursor.Current;
    if (firstCharacter !== "P") {
      return ParseResult.MismatchedCharacter<Period>(valueCursor, "P");
    }
    let inDate = true;
    const builder = new PeriodBuilder();
    let unitsSoFar: PeriodUnits = 0;
    while (valueCursor.MoveNext()) {
      if (inDate && valueCursor.Current === "T") {
        inDate = false;
        continue;
      }
      const negative = valueCursor.Current === "-";
      const [failure, unitValue] = valueCursor.ParseInt64<Period>("NodaTime.Period");
      if (failure !== null) {
        return failure;
      }
      if (valueCursor.Length === valueCursor.Index) {
        return ParseResult.EndOfString<Period>(valueCursor);
      }
      // Various failure cases:
      // - Repeated unit (e.g. P1M2M)
      // - Time unit is in date part (e.g. P5M)
      // - Date unit is in time part (e.g. PT1D)
      // - Unit is in incorrect order (e.g. P5D1Y)
      // - Unit is invalid (e.g. P5J)
      // - Unit is missing (e.g. P5)
      let unit: PeriodUnits;
      switch (valueCursor.Current) {
        case "Y": unit = PeriodUnits.Years; break;
        case "M": unit = inDate ? PeriodUnits.Months : PeriodUnits.Minutes; break;
        case "W": unit = PeriodUnits.Weeks; break;
        case "D": unit = PeriodUnits.Days; break;
        case "H": unit = PeriodUnits.Hours; break;
        case "S": unit = PeriodUnits.Seconds; break;
        case ",":
        case ".": unit = PeriodUnits.Nanoseconds; break; // Special handling below
        default: return InvalidUnit(valueCursor, valueCursor.Current);
      }
      if ((unit & unitsSoFar) !== 0) {
        return RepeatedUnit(valueCursor, valueCursor.Current);
      }

      // This handles putting months before years, for example. Less significant units
      // have higher integer representations.
      if (unit < unitsSoFar) {
        return MisplacedUnit(valueCursor, valueCursor.Current);
      }

      // The result of checking "there aren't any time units in this unit" should be
      // equal to "we're still in the date part".
      if (((unit & PeriodUnits.AllTimeUnits) === 0) !== inDate) {
        return MisplacedUnit(valueCursor, valueCursor.Current);
      }

      // Seen a . or , which need special handling.
      if (unit === PeriodUnits.Nanoseconds) {
        // Check for already having seen seconds, e.g. PT5S0.5
        if ((unitsSoFar & PeriodUnits.Seconds) !== 0) {
          return MisplacedUnit(valueCursor, valueCursor.Current);
        }
        // noda-js: set() rather than the seconds setter, as the value may be an exact Long.
        builder.set(PeriodUnits.Seconds, unitValue);

        if (!valueCursor.MoveNext()) {
          return ParseResult.MissingNumber<Period>(valueCursor);
        }
        // Can cope with at most 999999999 nanoseconds
        let [parsed, totalNanoseconds] = valueCursor.ParseFraction(9, 9, 1);
        if (!parsed) {
          return ParseResult.MissingNumber<Period>(valueCursor);
        }
        // Use whether or not the seconds value was negative (even if 0)
        // as the indication of whether this value is negative.
        if (negative) {
          totalNanoseconds = -totalNanoseconds;
        }
        builder.Milliseconds = Int64.Div(totalNanoseconds, NanosecondsPerMillisecond) % MillisecondsPerSecond;
        builder.Ticks = Int64.Div(totalNanoseconds, NanosecondsPerTick) % TicksPerMillisecond;
        builder.Nanoseconds = totalNanoseconds % NanosecondsPerTick;

        if (valueCursor.Current !== "S") {
          return ParseResult.MismatchedCharacter<Period>(valueCursor, "S");
        }
        if (valueCursor.MoveNext()) {
          return ParseResult.ExpectedEndOfString<Period>(valueCursor);
        }
        return ParseResult.ForValue(builder.Build());
      }

      builder.set(unit, unitValue);
      unitsSoFar |= unit;
    }
    if (unitsSoFar === 0) {
      return ParseResult.ForInvalidValue<Period>(valueCursor, TextErrorMessages.EmptyPeriod);
    }
    return ParseResult.ForValue(builder.Build());
  }

  /** @inheritDoc */
  Format(value: Period): string {
    return this.AppendFormat(value, new StringBuilder()).toString();
  }

  /** @inheritDoc */
  AppendFormat(value: Period, builder: StringBuilder): StringBuilder {
    Preconditions.CheckNotNull(value, "value");
    Preconditions.CheckNotNull(builder, "builder");
    value = value.Normalize();
    // Always ensure we've got *some* unit; arbitrarily pick days.
    if (value.Equals(Period.Zero)) {
      builder.Append("P0D");
      return builder;
    }
    builder.Append("P");
    AppendValue(builder, value.Years, "Y");
    AppendValue(builder, value.Months, "M");
    AppendValue(builder, value.Weeks, "W");
    AppendValue(builder, value.Days, "D");
    if (value.HasTimeComponent) {
      builder.Append("T");
      AppendValue(builder, value.Hours, "H");
      AppendValue(builder, value.Minutes, "M");
      let nanoseconds = value.Milliseconds * NanosecondsPerMillisecond + value.Ticks * NanosecondsPerTick + value.Nanoseconds;
      let seconds = value.Seconds;
      if (nanoseconds !== 0 || seconds !== 0) {
        if (nanoseconds < 0 || seconds < 0) {
          builder.Append("-");
          nanoseconds = -nanoseconds;
          seconds = -seconds;
        }
        FormatHelper.FormatInvariant(seconds, builder);
        if (nanoseconds !== 0) {
          builder.Append(".");
          FormatHelper.AppendFractionTruncate(nanoseconds, 9, 9, builder);
        }
        builder.Append("S");
      }
    }
    return builder;
  }
}

/**
 * Represents a pattern for parsing and formatting {@link Period} values.
 *
 * Thread safety: This type is immutable reference type. See the thread safety section of the user guide for more information.
 */
export class PeriodPattern implements IPattern<Period> {
  /**
   * Pattern which uses the normal ISO format for all the supported ISO
   * fields, but extends the time part with "s" for milliseconds, "t" for ticks and "n" for nanoseconds.
   * No normalization is carried out, and a period may contain weeks as well as years, months and days.
   * Each element may also be negative, independently of other elements. This pattern round-trips its
   * values: a parse/format cycle will produce an identical period, including units.
   */
  static get Roundtrip(): PeriodPattern {
    return (roundtrip ??= new PeriodPattern(new PeriodPatternRoundtripPatternImpl()));
  }

  /**
   * A "normalizing" pattern which abides by the ISO-8601 duration format as far as possible.
   * Weeks are added to the number of days (after multiplying by 7). Time units are normalized
   * (extending into days where necessary), and fractions of seconds are represented within the
   * seconds part. Unlike ISO-8601, which pattern allows for negative values within a period.
   *
   * Note that normalizing the period when formatting will cause an {@link OverflowError}
   * if the period contains more than Int64.MaxValue ticks when the
   * combined weeks/days/time portions are considered. Such a period could never
   * be useful anyway, however.
   */
  static get NormalizingIso(): PeriodPattern {
    return (normalizingIso ??= new PeriodPattern(new PeriodPatternNormalizingIsoPatternImpl()));
  }

  private readonly _pattern: IPattern<Period>;

  private constructor(pattern: IPattern<Period>) {
    this._pattern = Preconditions.CheckNotNull(pattern, "pattern");
  }

  /**
   * Parses the given text value according to the rules of this pattern.
   *
   * This method never throws an exception (barring a bug in Noda Time itself). Even errors such as
   * the argument being null are wrapped in a parse result.
   * @param text The text value to parse.
   * @returns The result of parsing, which may be successful or unsuccessful.
   */
  Parse(text: string): ParseResult<Period> {
    return this._pattern.Parse(text);
  }

  /**
   * Formats the given period as text according to the rules of this pattern.
   * @param value The period to format.
   * @returns The period formatted according to this pattern.
   */
  Format(value: Period): string {
    return this._pattern.Format(value);
  }

  /**
   * Formats the given value as text according to the rules of this pattern,
   * appending to the given {@link StringBuilder}.
   * @param value The value to format.
   * @param builder The `StringBuilder` to append to.
   * @returns The builder passed in as `builder`.
   */
  AppendFormat(value: Period, builder: StringBuilder): StringBuilder {
    return this._pattern.AppendFormat(value, builder);
  }
}
