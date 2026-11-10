// Ported from NodaTime 3.3.7: src/NodaTime/Calendars/HebrewYearMonthDayCalculator.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  HebrewMonthConverter,
  HebrewMonthNumbering,
  HebrewScripturalCalculator,
  YearMonthDay,
  YearMonthDayCalculator,
} from "../internal.ts";
import type { CalendarSystem } from "../internal.ts";
import { NewOverflowException } from "../internal.ts";

const UnixEpochDayAtStartOfYear1 = -2092590;
const MonthsPerLeapCycle = 235;
const YearsPerLeapCycle = 19;

/**
 * See `GetHebrewCalendar` (noda-js/calendars/hebrew) for details. This is effectively
 * an adapter around {@link HebrewScripturalCalculator}.
 * @internal
 */
export class HebrewYearMonthDayCalculator extends YearMonthDayCalculator {
  private readonly _monthNumbering: HebrewMonthNumbering;

  private constructor(monthNumbering: HebrewMonthNumbering) {
    super(HebrewScripturalCalculator.MinYear,
      HebrewScripturalCalculator.MaxYear,
      3654, // Average length of 10 years
      UnixEpochDayAtStartOfYear1);
    this._monthNumbering = monthNumbering;
  }

  /** C#: `internal HebrewYearMonthDayCalculator(HebrewMonthNumbering monthNumbering)` */
  static NewMonthNumbering(monthNumbering: HebrewMonthNumbering): HebrewYearMonthDayCalculator {
    return new HebrewYearMonthDayCalculator(monthNumbering);
  }

  private CalendarToCivilMonth(year: number, month: number): number {
    return this._monthNumbering === HebrewMonthNumbering.Civil ? month : HebrewMonthConverter.ScripturalToCivil(year, month);
  }

  private CalendarToScripturalMonth(year: number, month: number): number {
    return this._monthNumbering === HebrewMonthNumbering.Scriptural ? month : HebrewMonthConverter.CivilToScriptural(year, month);
  }

  private CivilToCalendarMonth(year: number, month: number): number {
    return this._monthNumbering === HebrewMonthNumbering.Civil ? month : HebrewMonthConverter.CivilToScriptural(year, month);
  }

  private ScripturalToCalendarMonth(year: number, month: number): number {
    return this._monthNumbering === HebrewMonthNumbering.Scriptural ? month : HebrewMonthConverter.ScripturalToCivil(year, month);
  }

  /**
   * Returns whether or not the given year is a leap year - that is, one with 13 months. This is
   * not quite the same as a leap year in (say) the Gregorian calendar system...
   */
  override IsLeapYear(year: number): boolean {
    return HebrewScripturalCalculator.IsLeapYear(year);
  }

  /** @inheritDoc */
  protected override GetDaysFromStartOfYearToStartOfMonth(year: number, month: number): number {
    const scripturalMonth = this.CalendarToScripturalMonth(year, month);
    return HebrewScripturalCalculator.GetDaysFromStartOfYearToStartOfMonth(year, scripturalMonth);
  }

  /** @inheritDoc */
  protected override CalculateStartOfYearDays(year: number): number {
    // Note that we might get called with a year of 0 here. I think that will still be okay,
    // given how HebrewScripturalCalculator works.
    const daysSinceHebrewEpoch = HebrewScripturalCalculator.ElapsedDays(year) - 1; // ElapsedDays returns 1 for year 1.
    return daysSinceHebrewEpoch + UnixEpochDayAtStartOfYear1;
  }

  /** C#: `internal override YearMonthDay GetYearMonthDay(int year, int dayOfYear)` */
  protected override GetYearMonthDayFromYearAndDayOfYear(year: number, dayOfYear: number): YearMonthDay {
    const scriptural = HebrewScripturalCalculator.GetYearMonthDay(year, dayOfYear);
    return this._monthNumbering === HebrewMonthNumbering.Scriptural ? scriptural : YearMonthDay.NewYearMonthDay(year, HebrewMonthConverter.ScripturalToCivil(year, scriptural.Month), scriptural.Day);
  }

  /** @inheritDoc */
  override GetDaysInYear(year: number): number {
    return HebrewScripturalCalculator.DaysInYear(year);
  }

  override GetMonthsInYear(year: number): number {
    return this.IsLeapYear(year) ? 13 : 12;
  }

  /**
   * Change the year, maintaining month and day as well as possible. This doesn't
   * work in the same way as other calendars; see https://judaism.stackexchange.com/questions/39053
   * for the reasoning behind the rules.
   */
  override SetYear(yearMonthDay: YearMonthDay, year: number): YearMonthDay {
    const currentYear = yearMonthDay.Year;
    const currentMonth = yearMonthDay.Month;
    let targetDay = yearMonthDay.Day;
    let targetScripturalMonth = this.CalendarToScripturalMonth(currentYear, currentMonth);
    if (targetScripturalMonth === 13 && !this.IsLeapYear(year)) {
      // If we were in Adar II and the target year is not a leap year, map to Adar.
      targetScripturalMonth = 12;
    } else if (targetScripturalMonth === 12 && this.IsLeapYear(year) && !this.IsLeapYear(currentYear)) {
      // If we were in Adar (non-leap year), go to Adar II rather than Adar I in a leap year.
      targetScripturalMonth = 13;
    }
    // If we're aiming for the 30th day of Heshvan, Kislev or an Adar, it's possible that the change in year
    // has meant the day becomes invalid. In that case, roll over to the 1st of the subsequent month.
    if (targetDay === 30 && (targetScripturalMonth === 8 || targetScripturalMonth === 9 || targetScripturalMonth === 12)) {
      if (HebrewScripturalCalculator.DaysInMonth(year, targetScripturalMonth) !== 30) {
        targetDay = 1;
        targetScripturalMonth++;
        // From Adar, roll to Nisan.
        if (targetScripturalMonth === 13) {
          targetScripturalMonth = 1;
        }
      }
    }
    const targetCalendarMonth = this.ScripturalToCalendarMonth(year, targetScripturalMonth);
    return YearMonthDay.NewYearMonthDay(year, targetCalendarMonth, targetDay);
  }

  override GetDaysInMonth(year: number, month: number): number {
    return HebrewScripturalCalculator.DaysInMonth(year, this.CalendarToScripturalMonth(year, month));
  }

  override AddMonths(yearMonthDay: YearMonthDay, months: number): YearMonthDay {
    // Note: this method gives the same result regardless of the month numbering used
    // by the instance. The method works in terms of civil month numbers for most of
    // the time in order to simplify the logic.
    if (months === 0) {
      return yearMonthDay;
    }
    let year = yearMonthDay.Year;
    let month = this.CalendarToCivilMonth(year, yearMonthDay.Month);
    // This arithmetic works the same both backwards and forwards.
    year += Math.trunc(months / MonthsPerLeapCycle) * YearsPerLeapCycle;
    months = months % MonthsPerLeapCycle;
    if (months > 0) {
      // Add as many months as we need to in order to act as if we'd begun at the start
      // of the year, for simplicity.
      months += month - 1;
      // Add a year at a time
      while (months >= this.GetMonthsInYear(year)) {
        months -= this.GetMonthsInYear(year);
        year++;
      }
      // However many months we've got left to add tells us the final month.
      month = months + 1;
    } else {
      // Pretend we were given the month at the end of the years.
      months -= this.GetMonthsInYear(year) - month;
      // Subtract a year at a time
      while (months + this.GetMonthsInYear(year) <= 0) {
        months += this.GetMonthsInYear(year);
        year--;
      }
      // However many months we've got left to add (which will still be negative...)
      // tells us the final month.
      month = this.GetMonthsInYear(year) + months;
    }

    // Convert back to calendar month
    month = this.CivilToCalendarMonth(year, month);
    const day = Math.min(this.GetDaysInMonth(year, month), yearMonthDay.Day);
    if (year < this.MinYear || year > this.MaxYear) {
      throw NewOverflowException("Date computation would overflow calendar bounds.");
    }

    return YearMonthDay.NewYearMonthDay(year, month, day);
  }

  /** @inheritDoc */
  override MonthsBetween(start: YearMonthDay, end: YearMonthDay): number {
    // First (quite rough) guess... we could probably be more efficient than this, but it's unlikely to be very far off.
    const startCivilMonth = this.CalendarToCivilMonth(start.Year, start.Month);
    const startTotalMonths = startCivilMonth + (start.Year * MonthsPerLeapCycle) / YearsPerLeapCycle;
    const endCivilMonth = this.CalendarToCivilMonth(end.Year, end.Month);
    const endTotalMonths = endCivilMonth + (end.Year * MonthsPerLeapCycle) / YearsPerLeapCycle;
    let diff = Math.trunc(endTotalMonths - startTotalMonths);

    if (this.Compare(start, end) <= 0) {
      // Go backwards until we've got a tight upper bound...
      while (this.Compare(this.AddMonths(start, diff), end) > 0) {
        diff--;
      }
      // Go forwards until we've overshot
      while (this.Compare(this.AddMonths(start, diff), end) <= 0) {
        diff++;
      }
      // Take account of the overshoot
      return diff - 1;
    } else {
      // Moving backwards, so we need to end up with a result greater than or equal to end...
      // Go forwards until we've got a tight upper bound...
      while (this.Compare(this.AddMonths(start, diff), end) < 0) {
        diff++;
      }
      // Go backwards until we've overshot
      while (this.Compare(this.AddMonths(start, diff), end) >= 0) {
        diff--;
      }
      // Take account of the overshoot
      return diff + 1;
    }
  }

  /** @inheritDoc */
  override Compare(lhs: YearMonthDay, rhs: YearMonthDay): number {
    // The civil month numbering system allows a naive comparison.
    if (this._monthNumbering === HebrewMonthNumbering.Civil) {
      return lhs.CompareTo(rhs);
    }
    // Otherwise, try one component at a time. (We could benchmark this
    // against creating a new pair of YearMonthDay values in the civil month numbering,
    // and comparing them...)
    const yearComparison = CompareInt32(lhs.Year, rhs.Year);
    if (yearComparison !== 0) {
      return yearComparison;
    }
    const lhsCivilMonth = this.CalendarToCivilMonth(lhs.Year, lhs.Month);
    const rhsCivilMonth = this.CalendarToCivilMonth(rhs.Year, rhs.Month);
    const monthComparison = CompareInt32(lhsCivilMonth, rhsCivilMonth);
    if (monthComparison !== 0) {
      return monthComparison;
    }
    return CompareInt32(lhs.Day, rhs.Day);
  }
}

// C#: int.CompareTo(int).
function CompareInt32(x: number, y: number): number {
  return x < y ? -1 : x > y ? 1 : 0;
}
