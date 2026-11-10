// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/YearMonthDayCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Utility/Comparers.dart';
import '../Utility/Preconditions.dart';
import '../YearMonthDay.dart';
import 'YearStartCacheEntry.dart';

/// The core of date calculations in Noda Time. This class *only* cares about absolute years, and only
/// dates - it has no time aspects at all, nor era-related aspects.
@internal
abstract class YearMonthDayCalculator implements IComparer<YearMonthDay> {
  /// Cache to speed up working out when a particular year starts.
  /// See the [YearStartCacheEntry] documentation and [GetStartOfYearInDays]
  /// for more details.
  final List<YearStartCacheEntry> _yearCache = YearStartCacheEntry.CreateCache();

  final int MinYear;

  final int MaxYear;

  // C#: [VisibleForTesting]
  final int DaysAtStartOfYear1;

  final int _averageDaysPer10Years;

  YearMonthDayCalculator.NewMinYearMaxYearAverageDaysPer10YearsDaysAtStartOfYear1(int minYear, int maxYear,
      int averageDaysPer10Years, int daysAtStartOfYear1)
      : MinYear = minYear,
        MaxYear = maxYear,
        // We add an extra day to make sure that
        // approximations using days-since-epoch are conservative, to avoid going out of bounds.
        _averageDaysPer10Years = averageDaysPer10Years + 1,
        DaysAtStartOfYear1 = daysAtStartOfYear1 {
    // We should really check the minimum year as well, but constructing it hurts my brain.
    // (noda_dart: checked after the fields are initialized, as Dart initializes final fields before the body runs.)
    Preconditions.CheckArgument(maxYear < YearStartCacheEntry.InvalidEntryYear, 'maxYear',
        'Calendar year range would invalidate caching.');
  }

  // #region Abstract methods
  /// Returns the number of days from the start of the given year to the start of the given month.
  int GetDaysFromStartOfYearToStartOfMonth(int year, int month);

  /// Compute the start of the given year in days since 1970-01-01 ISO. The year may be outside
  /// the bounds advertised by the calendar, but only by a single year. This method is only
  /// called by [GetStartOfYearInDays] (unless the calendar chooses to call it itself),
  /// so calendars which override that method and don't call the original implementation may leave
  /// this unimplemented (e.g. by throwing an exception if it's ever called).
  // TODO(misc): Either hard-code a check that this *is* only called by GetStartOfYearInDays
  // via a Roslyn test, or work out an attribute to indicate that, and write a more general test.
  int CalculateStartOfYearDays(int year);
  int GetMonthsInYear(int year);
  int GetDaysInMonth(int year, int month);
  bool IsLeapYear(int year);
  YearMonthDay AddMonths(YearMonthDay yearMonthDay, int months);

  YearMonthDay GetYearMonthDay(int year, int dayOfYear);

  /// Returns the number of days in the given year, which will always be within 1 year of
  /// the valid range for the calculator.
  int GetDaysInYear(int year);

  /// Find the months between [start] and [end].
  /// (If start is earlier than end, the result will be non-negative.)
  int MonthsBetween(YearMonthDay start, YearMonthDay end);

  /// Adjusts the given YearMonthDay to the specified year, potentially adjusting
  /// other fields as required.
  YearMonthDay SetYear(YearMonthDay yearMonthDay, int year);
  // #endregion

  // #region Virtual methods (subclasses should check to see whether they could override for performance, or should override for correctness)
  /// Computes the days since the Unix epoch at the start of the given year/month/day.
  /// This is the opposite of [GetYearMonthDayDaysSinceEpoch].
  /// This assumes the parameter have been validated previously.
  int GetDaysSinceEpoch(YearMonthDay yearMonthDay) {
    int year = yearMonthDay.Year;
    int startOfYear = GetStartOfYearInDays(year);
    int startOfMonth = startOfYear + GetDaysFromStartOfYearToStartOfMonth(year, yearMonthDay.Month);
    return startOfMonth + yearMonthDay.Day - 1;
  }

  /// Fetches the start of the year (in days since 1970-01-01 ISO) from the cache, or calculates
  /// and caches it.
  ///
  /// [year]: The year to fetch the days at the start of. This must be within 1 year of the min/max
  /// range, but can exceed it to make week-year calculations simple.
  int GetStartOfYearInDays(int year) {
    Preconditions.DebugCheckArgumentRange('year', year, MinYear - 1, MaxYear + 1);
    int cacheIndex = YearStartCacheEntry.GetCacheIndex(year);
    YearStartCacheEntry cacheEntry = _yearCache[cacheIndex];
    if (!cacheEntry.IsValidForYear(year)) {
      int days = CalculateStartOfYearDays(year);
      cacheEntry = YearStartCacheEntry.NewYearDays(year, days);
      _yearCache[cacheIndex] = cacheEntry;
    }
    return cacheEntry.StartOfYearDays;
  }

  /// Compares two YearMonthDay values according to the rules of this calendar.
  /// The default implementation simply uses a naive comparison of the values,
  /// as this is suitable for most calendars (where the first month of the year is month 1).
  ///
  /// Although the parameters are trusted (as in, they'll be valid in this calendar),
  /// the method being public isn't a problem - this type is never exposed.
  @override
  int Compare(YearMonthDay lhs, YearMonthDay rhs) => lhs.compareTo(rhs);

  // Catch-all year/month/day validation. Subclasses can optimize further - currently
  // this is only done for Gregorian/Julian calendars, which are the most performance-critical.
  void ValidateYearMonthDay(int year, int month, int day) {
    Preconditions.CheckArgumentRange('year', year, MinYear, MaxYear);
    Preconditions.CheckArgumentRange('month', month, 1, GetMonthsInYear(year));
    Preconditions.CheckArgumentRange('day', day, 1, GetDaysInMonth(year, month));
  }
  // #endregion

  // #region Concrete methods (convenience methods delegating to virtual/abstract ones primarily)

  /// Converts from a YearMonthDay representation to "day of year".
  /// This assumes the parameter have been validated previously.
  int GetDayOfYear(YearMonthDay yearMonthDay) => GetDaysFromStartOfYearToStartOfMonth(yearMonthDay.Year, yearMonthDay.Month) + yearMonthDay.Day;

  /// Works out the year/month/day of a given days-since-epoch by first computing the year and day of year,
  /// then getting the month and day from those two. This is how almost all calendars are naturally implemented
  /// anyway.
  ///
  /// (C#: the `GetYearMonthDay(int daysSinceEpoch)` overload.)
  YearMonthDay GetYearMonthDayDaysSinceEpoch(int daysSinceEpoch) {
    var (year, zeroBasedDay) = GetYear(daysSinceEpoch);
    return GetYearMonthDay(year, zeroBasedDay + 1);
  }

  /// Work out the year from the number of days since the epoch, as well as the
  /// day of that year (0-based).
  ///
  /// (C#'s `out int zeroBasedDayOfYear` is the second element of the returned record.)
  // C#: [VisibleForTesting] // Would be protected otherwise.
  (int, int) GetYear(int daysSinceEpoch) {
    int zeroBasedDayOfYear;
    // Get an initial estimate of the year, and the days-since-epoch value that
    // represents the start of that year. Then verify estimate and fix if
    // necessary. We have the average days per 100 years to avoid getting bad candidates
    // pretty quickly.
    int daysSinceYear1 = daysSinceEpoch - DaysAtStartOfYear1;
    int candidate = ((daysSinceYear1 * 10) ~/ _averageDaysPer10Years) + 1;

    // Most of the time we'll get the right year straight away, and we'll almost
    // always get it after one adjustment - but it's safer (and easier to think about)
    // if we just keep going until we know we're right.
    int candidateStart = GetStartOfYearInDays(candidate);
    int daysFromCandidateStartToTarget = daysSinceEpoch - candidateStart;
    if (daysFromCandidateStartToTarget < 0) {
      // Our candidate year is later than we want. Keep going backwards until we've got
      // a non-negative result, which must then be correct.
      do {
        candidate--;
        daysFromCandidateStartToTarget += GetDaysInYear(candidate);
      } while (daysFromCandidateStartToTarget < 0);
      zeroBasedDayOfYear = daysFromCandidateStartToTarget;
      return (candidate, zeroBasedDayOfYear);
    }
    // Our candidate year is correct or earlier than the right one. Find out which by
    // comparing it with the length of the candidate year.
    int candidateLength = GetDaysInYear(candidate);
    while (daysFromCandidateStartToTarget >= candidateLength) {
      // Our candidate year is earlier than we want, so fast forward a year,
      // removing the current candidate length from the "remaining days" and
      // working out the length of the new candidate.
      candidate++;
      daysFromCandidateStartToTarget -= candidateLength;
      candidateLength = GetDaysInYear(candidate);
    }
    zeroBasedDayOfYear = daysFromCandidateStartToTarget;
    return (candidate, zeroBasedDayOfYear);
  }
  // #endregion
}
