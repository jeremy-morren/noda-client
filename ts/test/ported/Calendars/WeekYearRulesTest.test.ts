// Ported from NodaTime 3.3.7: src/NodaTime.Test/Calendars/WeekYearRulesTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: FromCalendarWeekRule takes the BCL enums' numeric values (FirstDay = 0, Monday = 1).

import { WeekYearRules } from "../../../src/noda-js/internal.ts";
import { assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/WeekYearRulesTest.generated.ts";

const CalendarWeekRuleFirstDay = 0;
const DayOfWeekMonday = 1;

port(fixture, {
  UnsupportedCalendarWeekRule() {
    assertThrows("ArgumentException", () => WeekYearRules.FromCalendarWeekRule(CalendarWeekRuleFirstDay + 1000, DayOfWeekMonday));
  },
});
