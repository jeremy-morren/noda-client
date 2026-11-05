// Ported from NodaTime 3.3.0: src/NodaTime.Test/Calendars/YearMonthDayCalculatorTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the calculators arrive as NamedWrapper<YearMonthDayCalculator> scenario values. Only the ISO
// (GregorianYearMonthDayCalculator), Julian and Coptic calculators are ported; the cases for the other calculators
// are skipped by the harness.

import type { YearMonthDayCalculator } from "../../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/YearMonthDayCalculatorTest.generated.ts";

interface NamedWrapper<T> {
  readonly value: T;
  readonly name: string;
}

port(fixture, {
  ValidateStartOfYear1Days(calculatorWrapper: NamedWrapper<YearMonthDayCalculator>) {
    const calculator = calculatorWrapper.value;
    // Some calendars (e.g. Um Al Qura) don't support year 1, so the DaysAtStartOfYear1
    // is somewhat theoretical. (It's still used in such calendars, but only to get a guess
    // as to a year number given a day number.)
    if (calculator.MinYear > 1 || calculator.MaxYear < 0) {
      return;
    }
    assertNodaEqual(calculator.DaysAtStartOfYear1, calculator.GetStartOfYearInDays(1));
  },

  GetYearConsistentWithGetYearDays(calculatorWrapper: NamedWrapper<YearMonthDayCalculator>) {
    const calculator = calculatorWrapper.value;
    for (let year = calculator.MinYear; year <= calculator.MaxYear; year++) {
      const startOfYearDays = calculator.GetStartOfYearInDays(year);
      let [actualYear, dayOfYear] = calculator.GetYear(startOfYearDays);
      assertNodaEqual(actualYear, year, `Start of year ${year}`);
      assertNodaEqual(dayOfYear, 0); // Zero-based...
      [actualYear, dayOfYear] = calculator.GetYear(startOfYearDays - 1);
      assertNodaEqual(actualYear, year - 1, `End of year ${year - 1}`);
      assertNodaEqual(dayOfYear, calculator.GetDaysInYear(year - 1) - 1);
    }
  },
});
