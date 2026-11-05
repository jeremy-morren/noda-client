// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler.Test/Tzdb/RuleLineTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the internal ZoneYearOffset constructor is the static factory NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay.

import { IsoDayOfWeek, LocalTime, Offset, TransitionMode, ZoneRecurrence, ZoneYearOffset } from "../../../../src/noda-js/internal.ts";
import { RuleLine } from "../../../../src/noda-js/TzdbCompiler/internal.ts";
import { assertNodaEqual } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/TzdbCompiler/Tzdb/RuleLineTest.generated.ts";

port(fixture, {
  Equality() {
    const yearOffset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(
      TransitionMode.Utc, 10, 31, IsoDayOfWeek.Wednesday, true, LocalTime.Midnight);
    const recurrence = new ZoneRecurrence("bob", Offset.Zero, yearOffset, 1971, 2009);
    const actual = new RuleLine(recurrence, "D");
    const expected = new RuleLine(recurrence, "D");
    assertNodaEqual(actual, expected);
  },
});
