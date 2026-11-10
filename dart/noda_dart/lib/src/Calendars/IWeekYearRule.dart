// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/IWeekYearRule.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../CalendarSystem.dart';
import '../IsoDayOfWeek.generated.dart';
import '../LocalDate.dart';

/// A rule determining how "week years" are arranged, including the weeks within the week year.
/// Implementations provided by Noda Time itself can be obtained via the [WeekYearRules]
/// class.
///
/// Dates are usually identified within a calendar system by a calendar year, a month within that
/// calendar year, and a day within that month. For example, the date of birth of Ada Lovelace can be identified
/// within the Gregorian calendar system as the year 1815, the month December (12), and the day 10. However,
/// dates can also be identified (again within a calendar system) by week-year, week and day-of-week. How
/// that identification occurs depends on which rule you use - but again as an example, within the Gregorian
/// calendar system, using the ISO-8601 week year rule, the date of Ada Lovelace's birth is week-year 1815,
/// week 49, day-of-week Sunday.
///
/// The calendar year of a date and the week-year of a date are the same in most rules for most dates, but aren't
/// always. When they differ, it is usually because a day near the start of the calendar year is deemed to belong
/// to the last week of the previous week-year - or conversely because a day near the end of the calendar year is
/// deemed to belong to the first week of the following week-year. Some rules may be more radical -
/// a UK tax year rule could number weeks from April 6th onwards, such that any date earlier than that in the calendar
/// year would belong to the previous week-year.
///
/// The mapping of dates into week-year, week and day-of-week is always relative to a specific calendar system.
/// For example, years in the Hebrew calendar system vary very significantly in length due to leap months, and this
/// is reflected in the number of weeks within the week-years - as low as 50, and as high as 55.
///
/// This class allows conversions between the two schemes of identifying dates: [GetWeekYear]
/// and [GetWeekOfWeekYear] allow the week-year and week to be obtained for a date, and
/// [GetLocalDate] allows the reverse mapping. Note that
/// the calendar system does not need to be specified in the former methods as a [LocalDate] already
/// contains calendar information, and there is no method to obtain the day-of-week as that is not affected by the
/// week year rule being used.
///
/// All implementations within Noda Time are immutable, and it is advised that any external implementations
/// should be immutable too.
abstract interface class IWeekYearRule {
  /// Creates a [LocalDate] from a given week-year, week within that week-year,
  /// and day-of-week, for the specified calendar system.
  ///
  /// Wherever reasonable, implementations should ensure that all valid dates
  /// can be constructed via this method. In other words, given a [LocalDate] `date`,
  /// `rule.GetLocalDate(rule.GetWeekYear(date), rule.GetWeekOfWeekYear(date), date.IsoDayOfWeek, date.Calendar)`
  /// should always return `date`. This is true for all rules within Noda Time, but third party
  /// implementations may choose to simplify their implementations by restricting them to appropriate portions
  /// of time.
  ///
  /// Implementations may restrict which calendar systems supplied here, but the implementations provided by
  /// Noda Time work with all available calendar systems.
  ///
  /// [weekYear]: The week-year of the new date. Implementations provided by Noda Time allow any
  /// year which is a valid calendar year, and sometimes one less than the minimum calendar year
  /// and/or one more than the maximum calendar year, to allow for dates near the start of a calendar
  /// year to fall in the previous week year, and similarly for dates near the end of a calendar year.
  /// [weekOfWeekYear]: The week of week-year of the new date. Valid values for this parameter
  /// may vary depending on [weekYear], as the length of a year in weeks varies.
  /// [dayOfWeek]: The day-of-week of the new date. Valid values for this parameter may vary
  /// depending on [weekYear] and [weekOfWeekYear].
  /// [calendar]: The calendar system for the date.
  ///
  /// Throws [RangeError] if the parameters do not combine to form a valid date.
  ///
  /// Returns a [LocalDate] corresponding to the specified values.
  LocalDate GetLocalDate(int weekYear, int weekOfWeekYear, IsoDayOfWeek dayOfWeek, CalendarSystem calendar);

  /// Calculates the week-year in which the given date occurs, according to this rule.
  ///
  /// [date]: The date to compute the week-year of.
  ///
  /// Returns the week-year of [date], according to this rule.
  int GetWeekYear(LocalDate date);

  /// Calculates the week of the week-year in which the given date occurs, according to this rule.
  ///
  /// [date]: The date to compute the week of.
  ///
  /// Returns the week of the week-year of [date], according to this rule.
  int GetWeekOfWeekYear(LocalDate date);

  /// Returns the number of weeks in the given week-year, within the specified calendar system.
  ///
  /// [weekYear]: The week-year to find the range of.
  /// [calendar]: The calendar system the calculation is relative to.
  ///
  /// Returns the number of weeks in the given week-year within the given calendar.
  int GetWeeksInWeekYear(int weekYear, CalendarSystem calendar);
}

/// Extension methods on [IWeekYearRule].
///
/// noda_dart: hidden by the interface's members; call `WeekYearRuleExtensions(rule).GetLocalDate(...)`.
extension WeekYearRuleExtensions on IWeekYearRule {
  /// Convenience method to call [IWeekYearRule.GetLocalDate]
  /// passing in the ISO calendar system.
  ///
  /// [weekYear]: The week-year of the new date. Implementations provided by Noda Time allow any
  /// year which is a valid calendar year, and sometimes one less than the minimum calendar year
  /// and/or one more than the maximum calendar year, to allow for dates near the start of a calendar
  /// year to fall in the previous week year, and similarly for dates near the end of a calendar year.
  /// [weekOfWeekYear]: The week of week-year of the new date. Valid values for this parameter
  /// may vary depending on [weekYear], as the length of a year in weeks varies.
  /// [dayOfWeek]: The day-of-week of the new date. Valid values for this parameter may vary
  /// depending on [weekYear] and [weekOfWeekYear].
  ///
  /// Throws [RangeError] if the parameters do not combine to form a valid date.
  ///
  /// Returns a [LocalDate] corresponding to the specified values.
  LocalDate GetLocalDate(int weekYear, int weekOfWeekYear, IsoDayOfWeek dayOfWeek) =>
      // Dart: null safety checks rule (this).
      this.GetLocalDate(weekYear, weekOfWeekYear, dayOfWeek, CalendarSystem.Iso);

  /// Convenience overload to call [IWeekYearRule.GetWeeksInWeekYear] with
  /// the ISO calendar system.
  ///
  /// [weekYear]: The week year to calculate the number of contained weeks.
  ///
  /// Returns the number of weeks in the given week year.
  int GetWeeksInWeekYear(int weekYear) =>
      // Dart: null safety checks rule (this).
      this.GetWeeksInWeekYear(weekYear, CalendarSystem.Iso);
}
