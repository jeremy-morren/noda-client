// Ported from NodaTime 3.3.0: src/NodaTime/Calendars/CopticYearMonthDayCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { FixedMonthYearMonthDayCalculator } from "../internal.ts";

/** @internal */
export class CopticYearMonthDayCalculator extends FixedMonthYearMonthDayCalculator {
  private constructor() {
    super(1, 9715, -615558);
  }

  static New(): CopticYearMonthDayCalculator {
    return new CopticYearMonthDayCalculator();
  }

  /** @inheritDoc */
  protected override CalculateStartOfYearDays(year: number): number {
    // Unix epoch is 1970-01-01 Gregorian which is 1686-04-23 Coptic.
    // Calculate relative to the nearest leap year and account for the
    // difference later.

    const relativeYear = year - 1687;
    let leapYears: number;
    if (relativeYear <= 0) {
      // Add 3 before shifting right since /4 and >>2 behave differently
      // on negative numbers.
      leapYears = (relativeYear + 3) >> 2;
    } else {
      leapYears = relativeYear >> 2;
      // For post 1687 an adjustment is needed as jan1st is before leap day
      if (!this.IsLeapYear(year)) {
        leapYears++;
      }
    }

    const ret = relativeYear * 365 + leapYears;

    // Adjust to account for difference between 1687-01-01 and 1686-04-23.
    return ret + (365 - 112);
  }
}
