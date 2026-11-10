// Ported from NodaTime 3.3.7: src/NodaTime/Calendars/JulianYearMonthDayCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { GJYearMonthDayCalculator } from "../internal.ts";

const AverageDaysPer10JulianYears = 3653; // Ideally 365.25 per year

/** @internal */
export class JulianYearMonthDayCalculator extends GJYearMonthDayCalculator {
  private constructor() {
    super(-9997, 9998, AverageDaysPer10JulianYears, -719164);
  }

  static New(): JulianYearMonthDayCalculator {
    return new JulianYearMonthDayCalculator();
  }

  override IsLeapYear(year: number): boolean {
    return (year & 3) === 0;
  }

  /** @inheritDoc */
  protected override CalculateStartOfYearDays(year: number): number {
    // Unix epoch is 1970-01-01 Gregorian which is 1969-12-19 Julian.
    // Calculate relative to the nearest leap year and account for the
    // difference later.

    const relativeYear = year - 1968;
    let leapYears: number;
    if (relativeYear <= 0) {
      // Add 3 before shifting right since /4 and >>2 behave differently
      // on negative numbers.
      leapYears = (relativeYear + 3) >> 2;
    } else {
      leapYears = relativeYear >> 2;
      // For post 1968 an adjustment is needed as jan1st is before leap day
      if (!this.IsLeapYear(year)) {
        leapYears++;
      }
    }

    // Accounts for the difference between January 1st 1968 and December 19th 1969.
    return relativeYear * 365 + leapYears - (366 + 352);
  }
}
