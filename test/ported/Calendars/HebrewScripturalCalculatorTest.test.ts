// Ported from NodaTime 3.3.7: src/NodaTime.Test/Calendars/HebrewEcclesiasticalCalculatorTest.cs
// (class HebrewScripturalCalculatorTest)
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/HebrewScripturalCalculatorTest.generated.ts";

const BclReason = "uses the BCL's System.Globalization.HebrewCalendar as the oracle; " +
  "test/golden/calendars.test.ts checks every year and month of both Hebrew calendars against NodaTime's own data instead";

port(fixture, {}, {
  skip: {
    DaysInYear: BclReason,
    DaysInMonth: BclReason,
  },
});
