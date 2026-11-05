// Ported from NodaTime 3.3.7: src/NodaTime.Test/Utility/TickArithmeticTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: tick values are exact Int64Values (number | Long); they're compared as exact decimal strings.

import { expect } from "vitest";
import { CalendarSystem, Int64, NodaConstants, TickArithmetic } from "../../../src/noda-js/internal.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Utility/TickArithmeticTest.generated.ts";

port(fixture, {
  // ticks arrives as a number (safe integer) or an exact decimal string (beyond 2^53).
  TicksToDaysAndTickOfDayAndBack(ticks: number | string) {
    const exactTicks = Int64.FromArgument(ticks, "ticks");
    const [days, tickOfDay] = TickArithmetic.TicksToDaysAndTickOfDay(exactTicks);

    expect(Int64.ToString(TickArithmetic.DaysAndTickOfDayToTicks(days, tickOfDay))).toBe(Int64.ToString(exactTicks));
  },

  DaysAndTickOfDayToTicksUncheckedBoundaries() {
    // Only a useful test under debug, but this proves that the arithmetic won't overflow when used from
    // LocalDateTime or Instant. (In debug mode, we have
    TickArithmetic.BoundedDaysAndTickOfDayToTicks(CalendarSystem.Iso.MinDays, 0);
    TickArithmetic.BoundedDaysAndTickOfDayToTicks(CalendarSystem.Iso.MaxDays, NodaConstants.TicksPerDay - 1);
  },
});
