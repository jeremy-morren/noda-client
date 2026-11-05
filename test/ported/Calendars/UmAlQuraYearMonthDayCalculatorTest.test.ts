// Ported from NodaTime 3.3.7: src/NodaTime.Test/Calendars/UmAlQuraYearMonthDayCalculatorTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  UmAlQuraYearMonthDayCalculator,
  YearMonthDay,
} from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/UmAlQuraYearMonthDayCalculatorTest.generated.ts";

const BclNotPorted = "compares with the BCL's UmAlQuraCalendar, which JS doesn't have; "
  + "test/golden/calendars.test.ts covers every year of every calendar against NodaTime's own data";

port(fixture, {
  GetYearMonthDay_DaysSinceEpoch() {
    const calculator = UmAlQuraYearMonthDayCalculator.New();
    let daysSinceEpoch = calculator.GetStartOfYearInDays(calculator.MinYear);
    for (let year = calculator.MinYear; year <= calculator.MaxYear; year++) {
      for (let month = 1; month <= 12; month++) {
        for (let day = 1; day <= calculator.GetDaysInMonth(year, month); day++) {
          const actual = calculator.GetYearMonthDay(daysSinceEpoch);
          const expected = YearMonthDay.NewYearMonthDay(year, month, day);
          assertNodaEqual(actual, expected, `daysSinceEpoch=${daysSinceEpoch}`);
          daysSinceEpoch++;
        }
      }
    }
  },

  GetYearMonthDay_YearAndDayOfYear() {
    const calculator = UmAlQuraYearMonthDayCalculator.New();
    for (let year = calculator.MinYear; year <= calculator.MaxYear; year++) {
      let dayOfYear = 1;
      for (let month = 1; month <= 12; month++) {
        for (let day = 1; day <= calculator.GetDaysInMonth(year, month); day++) {
          const actual = calculator.GetYearMonthDay(year, dayOfYear);
          const expected = YearMonthDay.NewYearMonthDay(year, month, day);
          assertNodaEqual(actual, expected, `year=${year}; dayOfYear=${dayOfYear}`);
          dayOfYear++;
        }
      }
    }
  },

  GetDaysFromStartOfYearToStartOfMonth() {
    const calculator = UmAlQuraYearMonthDayCalculator.New();
    for (let year = calculator.MinYear; year <= calculator.MaxYear; year++) {
      let dayOfYear = 1;
      for (let month = 1; month <= 12; month++) {
        // This delegates to GetDaysFromStartOfYearToStartOfMonth (which is protected).
        assertNodaEqual(dayOfYear, calculator.GetDayOfYear(YearMonthDay.NewYearMonthDay(year, month, 1)), `year=${year}; month=${month}`);
        dayOfYear += calculator.GetDaysInMonth(year, month);
      }
    }
  },

  GetYearMonthDay_InvalidValueForCoverage() {
    const calculator = UmAlQuraYearMonthDayCalculator.New();
    assertThrows("ArgumentOutOfRangeException", () => calculator.GetYearMonthDay(calculator.MinYear, 1000));
  },

  // Not ported: GenerateData (#if DEBUG, Explicit; generates the C# GeneratedData from the BCL's UmAlQuraCalendar,
  // which tools/NodaJs.Tools (calendars) replaces with UmAlQuraYearMonthDayCalculatorData.generated.ts)
}, {
  skip: {
    BclEquivalence: BclNotPorted,
    GetStartOfYearInDays: BclNotPorted,
  },
});
