// Ported from NodaTime 3.3.7: src/NodaTime/Utility/TickArithmetic.cs

// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

// Leaf module: imported directly (not via the barrel) because it's used at evaluation time.
import { TicksPerDay } from "../NodaConstants.generated.ts";
import Long from "long";
import { Int64 } from "./Numbers.ts";
import type { Int64Value } from "./Numbers.ts";
import { Preconditions } from "./Preconditions.ts";
import type { Duration } from "../internal.ts";
import type { OverflowException } from "../internal.ts";

// noda-js: tick values can exceed 2^53, so (as per the porting conventions) they are Int64Value: a number when it's a
// safe integer, otherwise an exact Long. Safe integers take a plain number path.

/**
 * Common operations on ticks.
 * @internal
 */
export class TickArithmetic {
  private constructor() {}

  /**
   * Cautiously converts a number of ticks (which can have any value) into a number of
   * days and a tick within that day.
   *
   * Used by {@link Duration.FromTicks}.
   *
   * @returns A tuple of the number of days, and the tick within that day (C# out parameter).
   */
  static TicksToDaysAndTickOfDay(ticks: Int64Value): [days: number, tickOfDay: number] {
    // unchecked
    if (typeof ticks === "number") {
      // noda-js: a safe integer: floor division with doubles, corrected in case the quotient was rounded.
      let days = Math.floor(ticks / TicksPerDay);
      let tickOfDay = ticks - days * TicksPerDay;
      if (tickOfDay < 0) {
        days--;
        tickOfDay += TicksPerDay;
      } else if (tickOfDay >= TicksPerDay) {
        days++;
        tickOfDay -= TicksPerDay;
      }
      return [days, tickOfDay];
    }
    // First work out the number of days, always rounding down (so that ticks * TicksPerDay is always the
    // start of the day).
    // The shift approach here is equivalent to dividing by NodaConstants.TicksPerDay, but appears to be
    // very significantly faster under the x64 JIT (and no slower under the x86 JIT).
    // See https://stackoverflow.com/questions/22258070 for the inspiration.
    if (!ticks.isNegative()) {
      const days = ticks.shr(14).div(52734375).toInt();
      const tickOfDay = ticks.sub(Long.fromInt(days).mul(TicksPerDay));
      return [days, tickOfDay.toNumber()];
    } else {
      // Note: while this *could* be optimized with shifting at some point, it's probably not worth it.
      // Note that this must *not* subtract from ticks, as it could already be long.MinValue.
      const days = ticks.add(1).div(TicksPerDay).toInt() - 1;
      // We need to be careful as ticks might be close to long.MinValue, at which point
      // days * TicksPerDay would overflow. We could validate that, but it only
      // saves two additions, and introduces a branch.
      const tickOfDay = ticks.sub(Long.fromInt(days + 1).mul(TicksPerDay)).add(TicksPerDay);
      return [days, tickOfDay.toNumber()];
    }
  }

  /**
   * Similar to {@link TicksToDaysAndTickOfDay} but
   * trusting that the input is non-negative, which can be proved in certain cases.
   *
   * Used by LocalDateTime.FromDateTime(System.DateTime) and
   * LocalDateTime.FromDateTime(System.DateTime, CalendarSystem).
   *
   * @returns A tuple of the number of days, and the tick within that day (C# out parameter).
   */
  static NonNegativeTicksToDaysAndTickOfDay(ticks: Int64Value): [days: number, tickOfDay: number] {
    // unchecked
    Preconditions.DebugCheckArgument(Int64.Compare(ticks, 0) >= 0, "ticks", "Ticks must be non-negative");
    return TickArithmetic.TicksToDaysAndTickOfDay(ticks);
  }

  /**
   * Cautiously computes a number of ticks from day/tick-of-day value. This may overflow,
   * but will only do so if it has to.
   * @throws {OverflowException} The result is outside the range of a C# long.
   */
  static DaysAndTickOfDayToTicks(days: number, tickOfDay: number): Int64Value {
    // (Checked arithmetic, as NodaTime is compiled with overflow checking.)
    return days >= MinDaysForLongTicks
      ? Int64.Add(Int64.Multiply(days, TicksPerDay), tickOfDay)
      : Int64.Subtract(Int64.Add(Int64.Multiply(days + 1, TicksPerDay), tickOfDay), TicksPerDay);
  }

  /**
   * Computes a number of ticks from a day/tick-of-day value which is trusted not to overflow,
   * even when computed in the simplest way. Only call this method from places where there
   * are suitable constraints on the input.
   */
  static BoundedDaysAndTickOfDayToTicks(days: number, tickOfDay: number): Int64Value {
    Preconditions.DebugCheckArgumentRange("days", days, MinDaysForLongTicks, MaxDaysForLongTicks);
    // unchecked (noda-js: the inputs are trusted, so checked arithmetic gives the same result)
    return Int64.Add(Int64.Multiply(days, TicksPerDay), tickOfDay);
  }
}

/** (int) (long.MinValue / TicksPerDay) */
const MinDaysForLongTicks = -10675199;
/** (int) (long.MaxValue / TicksPerDay) */
const MaxDaysForLongTicks = 10675199;
