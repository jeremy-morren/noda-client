// Ported from NodaTime 3.3.7: src/NodaTime/Calendars/SimpleWeekYearRule.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  LocalDate,
  Preconditions,
  type CalendarSystem,
  type IsoDayOfWeek,
  type IWeekYearRule,
  type YearMonthDayCalculator,
} from "../internal.ts";
import { NewArgumentOutOfRangeException } from "../internal.ts";

/**
 * Implements {@link IWeekYearRule} for a rule where weeks are regular:
 * every week has exactly 7 days, which means that some week years straddle
 * the calendar year boundary. (So the start of a week can occur in one calendar
 * year, and the end of the week in the following calendar year, but the whole
 * week is in the same week-year.)
 * @internal
 */
export class SimpleWeekYearRule implements IWeekYearRule {
  private readonly _minDaysInFirstWeek: number;
  private readonly _firstDayOfWeek: IsoDayOfWeek;

  /**
   * If true, the boundary of a calendar year sometimes splits a week in half. The
   * last day of the calendar year is *always* in the last week of the same week-year, but
   * the first day of the calendar year *may* be in the last week of the previous week-year.
   * (Basically, the rule works out when the first day of the week-year would be logically,
   * and then cuts it off so that it's never in the previous calendar year.)
   *
   * If false, all weeks are 7 days long, including across calendar-year boundaries.
   * This is the state for ISO-like rules.
   */
  private readonly _irregularWeeks: boolean;

  private constructor(minDaysInFirstWeek: number, firstDayOfWeek: IsoDayOfWeek, irregularWeeks: boolean) {
    Preconditions.DebugCheckArgumentRange("minDaysInFirstWeek", minDaysInFirstWeek, 1, 7);
    Preconditions.CheckArgumentRange("firstDayOfWeek", firstDayOfWeek, 1, 7);
    this._minDaysInFirstWeek = minDaysInFirstWeek;
    this._firstDayOfWeek = firstDayOfWeek;
    this._irregularWeeks = irregularWeeks;
  }

  /** C#: `internal SimpleWeekYearRule(int minDaysInFirstWeek, IsoDayOfWeek firstDayOfWeek, bool irregularWeeks)` */
  static NewMinDaysInFirstWeekFirstDayOfWeekIrregularWeeks(minDaysInFirstWeek: number, firstDayOfWeek: IsoDayOfWeek, irregularWeeks: boolean): SimpleWeekYearRule {
    return new SimpleWeekYearRule(minDaysInFirstWeek, firstDayOfWeek, irregularWeeks);
  }

  /** @inheritDoc */
  GetLocalDate(weekYear: number, weekOfWeekYear: number, dayOfWeek: IsoDayOfWeek, calendar: CalendarSystem): LocalDate {
    Preconditions.CheckNotNull(calendar, "calendar");
    this.ValidateWeekYear(weekYear, calendar);

    // The actual message for this won't be ideal, but it's clear enough.
    Preconditions.CheckArgumentRange("dayOfWeek", dayOfWeek, 1, 7);

    const yearMonthDayCalculator = calendar.YearMonthDayCalculator;
    const maxWeeks = this.GetWeeksInWeekYear(weekYear, calendar);
    if (weekOfWeekYear < 1 || weekOfWeekYear > maxWeeks) {
      throw NewArgumentOutOfRangeException("weekOfWeekYear");
    }

    // unchecked
    const startOfWeekYear = this.GetWeekYearDaysSinceEpoch(yearMonthDayCalculator, weekYear);
    // 0 for "already on the first day of the week" up to 6 "it's the last day of the week".
    const daysIntoWeek = ((dayOfWeek - this._firstDayOfWeek) + 7) % 7;
    const days = startOfWeekYear + (weekOfWeekYear - 1) * 7 + daysIntoWeek;
    if (days < calendar.MinDays || days > calendar.MaxDays) {
      throw NewArgumentOutOfRangeException("weekYear", undefined,
        "The combination of weekYear, weekOfWeekYear and dayOfWeek is invalid");
    }
    const ret = LocalDate.NewYearMonthDayCalendar(yearMonthDayCalculator.GetYearMonthDay(days).WithCalendar(calendar));

    // For rules with irregular weeks, the calculation so far may end up computing a date which isn't
    // in the right week-year. This will happen if the caller has specified a "short" week (i.e. one
    // at the start or end of the week-year which is not seven days long due to the week year changing
    // part way through a week) and a day-of-week which corresponds to the "missing" part of the week.
    // Examples are in SimpleWeekYearRuleTest.GetLocalDate_Invalid.
    // The simplest way to find out is just to check what the week year is, but we only need to do
    // the full check if the requested week-year is different to the calendar year of the result.
    // We don't need to check for this in regular rules, because the computation we've already performed
    // will always be right.
    if (this._irregularWeeks && weekYear !== ret.Year) {
      if (this.GetWeekYear(ret) !== weekYear) {
        throw NewArgumentOutOfRangeException("weekYear", undefined,
          "The combination of weekYear, weekOfWeekYear and dayOfWeek is invalid");
      }
    }
    return ret;
  }

  /** @inheritDoc */
  GetWeekOfWeekYear(date: LocalDate): number {
    const yearMonthDay = date.YearMonthDay;
    const yearMonthDayCalculator = date.Calendar.YearMonthDayCalculator;
    // This is a bit inefficient, as we'll be converting forms several times. However, it's
    // understandable... we might want to optimize in the future if it's reported as a bottleneck.
    const weekYear = this.GetWeekYear(date);
    // Even if this is before the *real* start of the week year due to the rule
    // having short weeks, that doesn't change the week-of-week-year, as we've definitely
    // got the right week-year to start with.
    const startOfWeekYear = this.GetWeekYearDaysSinceEpoch(yearMonthDayCalculator, weekYear);
    const daysSinceEpoch = yearMonthDayCalculator.GetDaysSinceEpoch(yearMonthDay);
    const zeroBasedDayOfWeekYear = daysSinceEpoch - startOfWeekYear;
    const zeroBasedWeek = Math.trunc(zeroBasedDayOfWeekYear / 7);
    return zeroBasedWeek + 1;
  }

  /** @inheritDoc */
  GetWeeksInWeekYear(weekYear: number, calendar: CalendarSystem): number {
    Preconditions.CheckNotNull(calendar, "calendar");
    const yearMonthDayCalculator = calendar.YearMonthDayCalculator;
    this.ValidateWeekYear(weekYear, calendar);
    // unchecked
    const startOfWeekYear = this.GetWeekYearDaysSinceEpoch(yearMonthDayCalculator, weekYear);
    const startOfCalendarYear = yearMonthDayCalculator.GetStartOfYearInDays(weekYear);
    // The number of days gained or lost in the week year compared with the calendar year.
    // So if the week year starts on December 31st of the previous calendar year, this will be +1.
    // If the week year starts on January 2nd of this calendar year, this will be -1.
    const extraDaysAtStart = startOfCalendarYear - startOfWeekYear;

    // At the end of the year, we may have some extra days too.
    // In a non-regular rule, we just round up, so assume we effectively have 6 extra days.
    // In a regular rule, there can be at most minDaysInFirstWeek - 1 days "borrowed"
    // from the following year - because if there were any more, those days would be in the
    // the following year instead.
    const extraDaysAtEnd = this._irregularWeeks ? 6 : this._minDaysInFirstWeek - 1;

    const daysInThisYear = yearMonthDayCalculator.GetDaysInYear(weekYear);

    // We can have up to "minDaysInFirstWeek - 1" days of the next year, too.
    return Math.trunc((daysInThisYear + extraDaysAtStart + extraDaysAtEnd) / 7);
  }

  /** @inheritDoc */
  GetWeekYear(date: LocalDate): number {
    const yearMonthDay = date.YearMonthDay;
    const yearMonthDayCalculator = date.Calendar.YearMonthDayCalculator;
    // unchecked
    // Let's guess that it's in the same week year as calendar year, and check that.
    const calendarYear = yearMonthDay.Year;
    const startOfWeekYear = this.GetWeekYearDaysSinceEpoch(yearMonthDayCalculator, calendarYear);
    const daysSinceEpoch = yearMonthDayCalculator.GetDaysSinceEpoch(yearMonthDay);
    if (daysSinceEpoch < startOfWeekYear) {
      // No, the week-year hadn't started yet. For example, we've been given January 1st 2011...
      // and the first week of week-year 2011 starts on January 3rd 2011. Therefore the date
      // must belong to the last week of the previous week-year.
      return calendarYear - 1;
    }

    // By now, we know it's either calendarYear or calendarYear + 1.

    // In irregular rules, a day can belong to the *previous* week year, but never the *next* week year.
    // So at this point, we're done.
    if (this._irregularWeeks) {
      return calendarYear;
    }

    // Otherwise, check using the number of
    // weeks in the year. Note that this will fetch the start of the calendar year and the week year
    // again, so could be optimized by copying some logic here - but only when we find we need to.
    const weeksInWeekYear = this.GetWeeksInWeekYear(calendarYear, date.Calendar);

    // We assume that even for the maximum year, we've got just about enough leeway to get to the
    // start of the week year. (If not, we should adjust the maximum.)
    const startOfNextWeekYear = startOfWeekYear + weeksInWeekYear * 7;
    return daysSinceEpoch < startOfNextWeekYear ? calendarYear : calendarYear + 1;
  }

  /**
   * Validate that at least one day in the calendar falls in the given week year.
   */
  private ValidateWeekYear(weekYear: number, calendar: CalendarSystem): void {
    if (weekYear > calendar.MinYear && weekYear < calendar.MaxYear) {
      return;
    }
    const minCalendarYearDays = this.GetWeekYearDaysSinceEpoch(calendar.YearMonthDayCalculator, calendar.MinYear);
    // If week year X started after calendar year X, then the first days of the calendar year are in the
    // previous week year.
    const minWeekYear = minCalendarYearDays > calendar.MinDays ? calendar.MinYear - 1 : calendar.MinYear;
    const maxCalendarYearDays = this.GetWeekYearDaysSinceEpoch(calendar.YearMonthDayCalculator, calendar.MaxYear + 1);
    // If week year X + 1 started after the last day in the calendar, then everything is within week year X.
    // For irregular rules, we always just use calendar.MaxYear.
    const maxWeekYear = this._irregularWeeks || (maxCalendarYearDays > calendar.MaxDays) ? calendar.MaxYear : calendar.MaxYear + 1;
    Preconditions.CheckArgumentRange("weekYear", weekYear, minWeekYear, maxWeekYear);
  }

  /**
   * Returns the days at the start of the given week-year. The week-year may be
   * 1 higher or lower than the max/min calendar year. For non-regular rules (i.e. where some weeks
   * can be short) it returns the day when the week-year *would* have started if it were regular.
   * So this *always* returns a date on firstDayOfWeek.
   */
  private GetWeekYearDaysSinceEpoch(yearMonthDayCalculator: YearMonthDayCalculator, weekYear: number): number {
    // unchecked
    // Need to be slightly careful here, as the week-year can reasonably be (just) outside the calendar year range.
    // However, YearMonthDayCalculator.GetStartOfYearInDays already handles min/max -/+ 1.
    const startOfCalendarYear = yearMonthDayCalculator.GetStartOfYearInDays(weekYear);
    const startOfYearDayOfWeek = startOfCalendarYear >= -3 ? 1 + ((startOfCalendarYear + 3) % 7)
      : 7 + ((startOfCalendarYear + 4) % 7);

    // How many days have there been from the start of the week containing
    // the first day of the year, until the first day of the year? To put it another
    // way, how many days in the week *containing* the start of the calendar year were
    // in the previous calendar year.
    // (For example, if the start of the calendar year is Friday and the first day of the week is Monday,
    // this will be 4.)
    const daysIntoWeek = ((startOfYearDayOfWeek - this._firstDayOfWeek) + 7) % 7;
    const startOfWeekContainingStartOfCalendarYear = startOfCalendarYear - daysIntoWeek;

    const startOfYearIsInWeek1 = (7 - daysIntoWeek >= this._minDaysInFirstWeek);
    return startOfYearIsInWeek1
      ? startOfWeekContainingStartOfCalendarYear
      : startOfWeekContainingStartOfCalendarYear + 7;
  }
}
