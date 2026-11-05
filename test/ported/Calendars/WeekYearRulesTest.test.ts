// Ported from NodaTime 3.3.0: src/NodaTime.Test/Calendars/WeekYearRulesTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: WeekYearRules.fromCalendarWeekRule takes the BCL enums' numeric values
// (CalendarWeekRule.FirstDay = 0, DayOfWeek.Monday = 1).

import { ArgumentError, WeekYearRules } from "../../../src/noda-js/internal.ts";
import { assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/WeekYearRulesTest.generated.ts";

const CalendarWeekRuleFirstDay = 0;
const DayOfWeekMonday = 1;

port(fixture, {
  UnsupportedCalendarWeekRule() {
    assertThrows(ArgumentError, () => WeekYearRules.FromCalendarWeekRule(CalendarWeekRuleFirstDay + 1000, DayOfWeekMonday));
  },
});
