// Ported from NodaTime 3.3.7: src/NodaTime/Calendars/YearMonthDayCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Preconditions, YearStartCacheEntry, type YearMonthDay } from "../internal.ts";

/**
 * The core of date calculations in Noda Time. This class *only* cares about absolute years, and only
 * dates - it has no time aspects at all, nor era-related aspects.
 * @internal
 */
export abstract class YearMonthDayCalculator {
  /**
   * Cache to speed up working out when a particular year starts.
   * See the {@link YearStartCacheEntry} documentation and {@link GetStartOfYearInDays}
   * for more details.
   */
  private readonly _yearCache: YearStartCacheEntry[] = YearStartCacheEntry.CreateCache();

  readonly MinYear: number;

  readonly MaxYear: number;

  /** [VisibleForTesting] */
  readonly DaysAtStartOfYear1: number;

  private readonly _averageDaysPer10Years: number;

  protected constructor(minYear: number, maxYear: number,
    averageDaysPer10Years: number, daysAtStartOfYear1: number) {
    // We should really check the minimum year as well, but constructing it hurts my brain.
    Preconditions.CheckArgument(maxYear < YearStartCacheEntry.InvalidEntryYear, "maxYear",
      "Calendar year range would invalidate caching.");
    this.MinYear = minYear;
    this.MaxYear = maxYear;
    // We add an extra day to make sure that
    // approximations using days-since-epoch are conservative, to avoid going out of bounds.
    this._averageDaysPer10Years = averageDaysPer10Years + 1;
    this.DaysAtStartOfYear1 = daysAtStartOfYear1;
  }

  // #region Abstract methods
  /**
   * Returns the number of days from the start of the given year to the start of the given month.
   */
  protected abstract GetDaysFromStartOfYearToStartOfMonth(year: number, month: number): number;

  /**
   * Compute the start of the given year in days since 1970-01-01 ISO. The year may be outside
   * the bounds advertised by the calendar, but only by a single year. This method is only
   * called by {@link GetStartOfYearInDays} (unless the calendar chooses to call it itself),
   * so calendars which override that method and don't call the original implementation may leave
   * this unimplemented (e.g. by throwing an exception if it's ever called).
   */
  // TODO(misc): Either hard-code a check that this *is* only called by GetStartOfYearInDays
  // via a Roslyn test, or work out an attribute to indicate that, and write a more general test.
  protected abstract CalculateStartOfYearDays(year: number): number;
  abstract GetMonthsInYear(year: number): number;
  abstract GetDaysInMonth(year: number, month: number): number;
  abstract IsLeapYear(year: number): boolean;
  abstract AddMonths(yearMonthDay: YearMonthDay, months: number): YearMonthDay;

  /**
   * C#: `internal abstract YearMonthDay GetYearMonthDay(int year, int dayOfYear)`.
   * Renamed for subclasses to implement, because TypeScript can't overload an abstract method with a concrete one;
   * callers still use `GetYearMonthDay(year, dayOfYear)`.
   */
  protected abstract GetYearMonthDayFromYearAndDayOfYear(year: number, dayOfYear: number): YearMonthDay;

  /**
   * Returns the number of days in the given year, which will always be within 1 year of
   * the valid range for the calculator.
   */
  abstract GetDaysInYear(year: number): number;

  /**
   * Find the months between `start` and `end`.
   * (If start is earlier than end, the result will be non-negative.)
   */
  abstract MonthsBetween(start: YearMonthDay, end: YearMonthDay): number;

  /**
   * Adjusts the given YearMonthDay to the specified year, potentially adjusting
   * other fields as required.
   */
  abstract SetYear(yearMonthDay: YearMonthDay, year: number): YearMonthDay;
  // #endregion

  // #region Virtual methods (subclasses should check to see whether they could override for performance, or should override for correctness)
  /**
   * Computes the days since the Unix epoch at the start of the given year/month/day.
   * This is the opposite of {@link GetYearMonthDay}.
   * This assumes the parameter have been validated previously.
   */
  GetDaysSinceEpoch(yearMonthDay: YearMonthDay): number {
    const year = yearMonthDay.Year;
    const startOfYear = this.GetStartOfYearInDays(year);
    const startOfMonth = startOfYear + this.GetDaysFromStartOfYearToStartOfMonth(year, yearMonthDay.Month);
    return startOfMonth + yearMonthDay.Day - 1;
  }

  /**
   * Fetches the start of the year (in days since 1970-01-01 ISO) from the cache, or calculates
   * and caches it.
   * @param year The year to fetch the days at the start of. This must be within 1 year of the min/max
   * range, but can exceed it to make week-year calculations simple.
   */
  GetStartOfYearInDays(year: number): number {
    Preconditions.DebugCheckArgumentRange("year", year, this.MinYear - 1, this.MaxYear + 1);
    const cacheIndex = YearStartCacheEntry.GetCacheIndex(year);
    let cacheEntry = this._yearCache[cacheIndex]!;
    if (!cacheEntry.IsValidForYear(year)) {
      const days = this.CalculateStartOfYearDays(year);
      cacheEntry = YearStartCacheEntry.NewYearDays(year, days);
      this._yearCache[cacheIndex] = cacheEntry;
    }
    return cacheEntry.StartOfYearDays;
  }

  /**
   * Compares two YearMonthDay values according to the rules of this calendar.
   * The default implementation simply uses a naive comparison of the values,
   * as this is suitable for most calendars (where the first month of the year is month 1).
   *
   * Although the parameters are trusted (as in, they'll be valid in this calendar),
   * the method being public isn't a problem - this type is never exposed.
   */
  Compare(lhs: YearMonthDay, rhs: YearMonthDay): number {
    return lhs.CompareTo(rhs);
  }

  // Catch-all year/month/day validation. Subclasses can optimize further - currently
  // this is only done for Gregorian/Julian calendars, which are the most performance-critical.
  ValidateYearMonthDay(year: number, month: number, day: number): void {
    Preconditions.CheckArgumentRange("year", year, this.MinYear, this.MaxYear);
    Preconditions.CheckArgumentRange("month", month, 1, this.GetMonthsInYear(year));
    Preconditions.CheckArgumentRange("day", day, 1, this.GetDaysInMonth(year, month));
  }
  // #endregion

  // #region Concrete methods (convenience methods delegating to virtual/abstract ones primarily)

  /**
   * Converts from a YearMonthDay representation to "day of year".
   * This assumes the parameter have been validated previously.
   */
  GetDayOfYear(yearMonthDay: YearMonthDay): number {
    return this.GetDaysFromStartOfYearToStartOfMonth(yearMonthDay.Year, yearMonthDay.Month) + yearMonthDay.Day;
  }

  /**
   * Works out the year/month/day of a given days-since-epoch by first computing the year and day of year,
   * then getting the month and day from those two. This is how almost all calendars are naturally implemented
   * anyway.
   *
   * With two arguments, this is the C# abstract `GetYearMonthDay(int year, int dayOfYear)`, implemented by
   * subclasses as {@link GetYearMonthDayFromYearAndDayOfYear}.
   */
  GetYearMonthDay(daysSinceEpoch: number): YearMonthDay;
  GetYearMonthDay(year: number, dayOfYear: number): YearMonthDay;
  GetYearMonthDay(yearOrDaysSinceEpoch: number, dayOfYear?: number): YearMonthDay {
    if (dayOfYear !== undefined) {
      return this.GetYearMonthDayFromYearAndDayOfYear(yearOrDaysSinceEpoch, dayOfYear);
    }
    const [year, zeroBasedDay] = this.GetYear(yearOrDaysSinceEpoch);
    return this.GetYearMonthDayFromYearAndDayOfYear(year, zeroBasedDay + 1);
  }

  /**
   * Work out the year from the number of days since the epoch, as well as the
   * day of that year (0-based).
   *
   * [VisibleForTesting] // Would be protected otherwise.
   * @returns A tuple of the year and the zero-based day of year (C# out parameter).
   */
  GetYear(daysSinceEpoch: number): [year: number, zeroBasedDayOfYear: number] {
    // Get an initial estimate of the year, and the days-since-epoch value that
    // represents the start of that year. Then verify estimate and fix if
    // necessary. We have the average days per 100 years to avoid getting bad candidates
    // pretty quickly.
    const daysSinceYear1 = daysSinceEpoch - this.DaysAtStartOfYear1;
    let candidate = Math.trunc((daysSinceYear1 * 10) / this._averageDaysPer10Years) + 1;

    // Most of the time we'll get the right year straight away, and we'll almost
    // always get it after one adjustment - but it's safer (and easier to think about)
    // if we just keep going until we know we're right.
    const candidateStart = this.GetStartOfYearInDays(candidate);
    let daysFromCandidateStartToTarget = daysSinceEpoch - candidateStart;
    if (daysFromCandidateStartToTarget < 0) {
      // Our candidate year is later than we want. Keep going backwards until we've got
      // a non-negative result, which must then be correct.
      do {
        candidate--;
        daysFromCandidateStartToTarget += this.GetDaysInYear(candidate);
      }
      while (daysFromCandidateStartToTarget < 0);
      return [candidate, daysFromCandidateStartToTarget];
    }
    // Our candidate year is correct or earlier than the right one. Find out which by
    // comparing it with the length of the candidate year.
    let candidateLength = this.GetDaysInYear(candidate);
    while (daysFromCandidateStartToTarget >= candidateLength) {
      // Our candidate year is earlier than we want, so fast forward a year,
      // removing the current candidate length from the "remaining days" and
      // working out the length of the new candidate.
      candidate++;
      daysFromCandidateStartToTarget -= candidateLength;
      candidateLength = this.GetDaysInYear(candidate);
    }
    return [candidate, daysFromCandidateStartToTarget];
  }
  // #endregion
}
