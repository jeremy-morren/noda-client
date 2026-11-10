// Ported from NodaTime 6e024dde: src/NodaTime/LocalDate.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:core';
import 'dart:core' as core;

import 'package:meta/meta.dart';

import 'CalendarOrdinal.generated.dart';
import 'CalendarSystem.dart';
import 'Calendars/Era.dart' as nt show Era;
import 'Calendars/GregorianYearMonthDayCalculator.dart';
import 'Calendars/WeekYearRules.dart';
import 'DateTimeZone.dart';
import 'Fields/DatePeriodFields.dart';
import 'Globalization/NodaCultureInfo.dart';
import 'IsoDayOfWeek.generated.dart';
import 'LocalDateTime.dart';
import 'LocalTime.dart';
import 'NodaConstants.dart';
import 'Offset.dart';
import 'OffsetDate.dart';
import 'Period.dart';
import 'Text/LocalDatePattern.dart';
import 'Utility/Checked.dart';
import 'Utility/Preconditions.dart';
import 'YearMonth.dart';
import 'YearMonthDay.dart' as nt show YearMonthDay;
import 'YearMonthDayCalendar.dart';
import 'ZonedDateTime.dart';

// TODO(feature): Calendar-neutral comparer.

/// LocalDate is an immutable struct representing a date within the calendar,
/// with no reference to a particular time zone or time of day.
///
/// Values can freely be compared for equality: a value in a different calendar system is not equal to
/// a value in a different calendar system. However, ordering comparisons (either via the [compareTo] method
/// or via operators) fail with [ArgumentError]; attempting to compare values in different calendars
/// almost always indicates a bug in the calling code.
///
/// The default value of this type is 0001-01-01 (January 1st, 1 C.E.) in the ISO calendar.
///
/// Thread safety: This type is an immutable value type. See the thread safety section of the user guide for more information.
// Not ported: [TypeConverter(typeof(LocalDateTypeConverter))], [XmlSchemaProvider], IXmlSerializable (not ported, see below)
final class LocalDate implements Comparable<LocalDate> {
  final YearMonthDayCalendar _yearMonthDayCalendar;

  /// The maximum (latest) date representable in the ISO calendar system.
  static LocalDate get MaxIsoValue => LocalDate.NewYearMonthDayCalendar(YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(GregorianYearMonthDayCalculator.MaxGregorianYear, 12, 31, CalendarOrdinal.Iso));

  /// The minimum (earliest) date representable in the ISO calendar system.
  static LocalDate get MinIsoValue => LocalDate.NewYearMonthDayCalendar(YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(GregorianYearMonthDayCalculator.MinGregorianYear, 1, 1, CalendarOrdinal.Iso));

  /// Constructs an instance from values which are assumed to already have been validated.
  @internal
  LocalDate.NewYearMonthDayCalendar(YearMonthDayCalendar yearMonthDayCalendar)
      : _yearMonthDayCalendar = yearMonthDayCalendar;

  /// Constructs an instance from the number of days since the unix epoch, in the ISO
  /// calendar system.
  @internal
  factory LocalDate.NewDaysSinceEpoch(int daysSinceEpoch) {
    Preconditions.DebugCheckArgumentRange('daysSinceEpoch', daysSinceEpoch, CalendarSystem.Iso.MinDays, CalendarSystem.Iso.MaxDays);
    return LocalDate.NewYearMonthDayCalendar(GregorianYearMonthDayCalculator.GetGregorianYearMonthDayCalendarFromDaysSinceEpoch(daysSinceEpoch));
  }

  /// Constructs an instance from the number of days since the unix epoch, and a calendar
  /// system. The calendar system is assumed to be non-null, but the days since the epoch are
  /// validated.
  @internal
  factory LocalDate.NewDaysSinceEpochCalendar(int daysSinceEpoch, CalendarSystem calendar) {
    // Dart: null safety checks calendar.
    return LocalDate.NewYearMonthDayCalendar(calendar.GetYearMonthDayCalendarFromDaysSinceEpoch(daysSinceEpoch));
  }

  /// Constructs an instance for the given year, month and day in the ISO calendar, or (if [calendar] is given) in
  /// the specified calendar.
  ///
  /// [year]: The year. This is the "absolute year", so, for
  /// the ISO calendar, a value of 0 means 1 BC, for example.
  /// [month]: The month of year.
  /// [day]: The day of month.
  /// [calendar]: Calendar system in which to create the date.
  ///
  /// Returns the resulting date.
  ///
  /// Throws [RangeError] if the parameters do not form a valid date.
  // noda_dart: C#'s LocalDate(int year, int month, int day) and LocalDate(int year, int month, int day, CalendarSystem calendar).
  factory LocalDate(int year, int month, int day, [CalendarSystem? calendar]) {
    if (calendar == null) {
      GregorianYearMonthDayCalculator.ValidateGregorianYearMonthDay(year, month, day);
      return LocalDate.NewYearMonthDayCalendar(YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(year, month, day, CalendarOrdinal.Iso));
    }
    // Dart: null safety checks calendar.
    calendar.ValidateYearMonthDay(year, month, day);
    return LocalDate.NewYearMonthDayCalendar(YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(year, month, day, calendar.Ordinal));
  }

  /// Constructs an instance for the given era, year of era, month and day in the ISO calendar, or (if [calendar] is
  /// given) in the specified calendar.
  ///
  /// [era]: The era within which to create a date. Must be a valid era within the specified calendar.
  /// [yearOfEra]: The year of era.
  /// [month]: The month of year.
  /// [day]: The day of month.
  /// [calendar]: Calendar system in which to create the date.
  ///
  /// Returns the resulting date.
  ///
  /// Throws [RangeError] if the parameters do not form a valid date.
  // noda_dart: C#'s LocalDate(Era era, int yearOfEra, int month, int day) and
  // LocalDate(Era era, int yearOfEra, int month, int day, CalendarSystem calendar).
  factory LocalDate.EraYearOfEraMonthDay(nt.Era era, int yearOfEra, int month, int day, [CalendarSystem? calendar]) {
    calendar ??= CalendarSystem.Iso;
    return LocalDate(calendar.GetAbsoluteYear(yearOfEra, era), month, day, calendar);
  }

  /// Gets the calendar system associated with this local date.
  CalendarSystem get Calendar => CalendarSystem.ForOrdinal(_CalendarOrdinal);

  CalendarOrdinal get _CalendarOrdinal => _yearMonthDayCalendar.CalendarOrdinal;

  /// Gets the year of this local date.
  ///
  /// This returns the "absolute year", so, for the ISO calendar,
  /// a value of 0 means 1 BC, for example.
  int get Year => _yearMonthDayCalendar.Year;

  /// Gets the month of this local date within the year.
  int get Month => _yearMonthDayCalendar.Month;

  /// Gets the day of this local date within the month.
  int get Day => _yearMonthDayCalendar.Day;

  /// Gets the number of days since the Unix epoch for this date.
  @internal
  int get DaysSinceEpoch => Calendar.GetDaysSinceEpoch(_yearMonthDayCalendar.ToYearMonthDay());

  /// Gets the week day of this local date expressed as an [IsoDayOfWeek] value.
  IsoDayOfWeek get DayOfWeek => Calendar.GetDayOfWeek(_yearMonthDayCalendar.ToYearMonthDay());

  /// Gets the year of this local date within the era.
  int get YearOfEra => Calendar.GetYearOfEra(_yearMonthDayCalendar.Year);

  /// Gets the era of this local date.
  nt.Era get Era => Calendar.GetEra(_yearMonthDayCalendar.Year);

  /// Gets the day of this local date within the year.
  int get DayOfYear => Calendar.GetDayOfYear(_yearMonthDayCalendar.ToYearMonthDay());

  @internal
  nt.YearMonthDay get YearMonthDay => _yearMonthDayCalendar.ToYearMonthDay();

  /// Gets a [LocalDateTime] at midnight on the date represented by this local date.
  ///
  /// Returns the [LocalDateTime] representing midnight on this local date, in the same calendar
  /// system.
  LocalDateTime AtMidnight() => LocalDateTime.NewDateTime(this, LocalTime.Midnight);

  /// Constructs a [core.DateTime] from this value which has a [core.DateTime.isUtc] of `false` (.NET's
  /// `DateTimeKind.Unspecified`). The result is midnight on the day represented by this value.
  ///
  /// `DateTimeKind.Unspecified` is slightly odd - it can be treated as UTC if you use `DateTime.ToLocalTime`
  /// or as system local time if you use `DateTime.ToUniversalTime`, but it's the only kind which allows
  /// you to construct a `DateTimeOffset` with an arbitrary offset, which makes it as close to
  /// the Noda Time non-system-specific "local" concept as exists in .NET.
  ///
  /// [core.DateTime] uses the Gregorian calendar by definition, so the value is implicitly converted
  /// to the Gregorian calendar first. The result will be on the same physical day,
  /// but the values returned by the year/month/day properties of the [core.DateTime] may not
  /// match the Year/Month/Day properties of this value.
  ///
  /// noda_dart: Dart has no unspecified kind, so the result is a local [core.DateTime].
  ///
  /// Returns a [core.DateTime] value for the same date and time as this value.
  core.DateTime ToDateTimeUnspecified() {
    // noda_dart: .NET's DateTime throws before 0001-01-01; Dart's doesn't, so check the days.
    if (DaysSinceEpoch < -NodaConstants.BclDaysAtUnixEpoch) {
      throw RangeError.value(DaysSinceEpoch, 'ticks', 'Ticks must be between DateTime.MinValue.Ticks and DateTime.MaxValue.Ticks.');
    }
    LocalDate isoDate = WithCalendar(CalendarSystem.Iso);
    return core.DateTime(isoDate.Year, isoDate.Month, isoDate.Day);
  }

  // Helper method used by both FromDateTime overloads.
  // noda_dart: C#'s NonNegativeTicksToDays(long ticks), from the DateTime's fields.
  static int _NonNegativeTicksToDays(core.DateTime dateTime) =>
      core.DateTime.utc(dateTime.year, dateTime.month, dateTime.day).millisecondsSinceEpoch ~/ NodaConstants.MillisecondsPerDay;

  /// Converts a [core.DateTime] of any kind (local or UTC) to a LocalDate in the ISO calendar, or (if [calendar] is
  /// given) in the specified calendar, ignoring the time of day.
  /// This does not perform any time zone conversions, so a DateTime with a [core.DateTime.isUtc] of
  /// `true` will still represent the same year/month/day - it won't be converted into the local system time.
  ///
  /// [dateTime]: Value to convert into a Noda Time local date
  /// [calendar]: The calendar system to convert into
  ///
  /// Returns a new [LocalDate] with the same values as the specified `DateTime`.
  // noda_dart: C#'s FromDateTime(DateTime) and FromDateTime(DateTime, CalendarSystem).
  static LocalDate FromDateTime(core.DateTime dateTime, [CalendarSystem? calendar]) {
    int days = _NonNegativeTicksToDays(dateTime);
    if (calendar == null) {
      // noda_dart: validated, as Dart's DateTime range is wider than the ISO calendar's.
      return LocalDate.NewDaysSinceEpochCalendar(days, CalendarSystem.Iso);
    }
    // Dart: null safety checks calendar.
    return LocalDate.NewDaysSinceEpochCalendar(days, calendar);
  }

  /// Returns the local date corresponding to the given "week year", "week of week year", and "day of week"
  /// in the ISO calendar system, using the ISO week-year rules.
  ///
  /// [weekYear]: ISO-8601 week year of value to return
  /// [weekOfWeekYear]: ISO-8601 week of week year of value to return
  /// [dayOfWeek]: ISO-8601 day of week to return
  ///
  /// Returns the date corresponding to the given week year / week of week year / day of week.
  static LocalDate FromWeekYearWeekAndDay(int weekYear, int weekOfWeekYear, IsoDayOfWeek dayOfWeek) =>
      WeekYearRules.Iso.GetLocalDate(weekYear, weekOfWeekYear, dayOfWeek, CalendarSystem.Iso);

  /// Returns the local date corresponding to a particular occurrence of a day-of-week
  /// within a year and month. For example, this method can be used to ask for "the third Monday in April 2012".
  ///
  /// The returned date is always in the ISO calendar. This method is unrelated to week-years and any rules for
  /// "business weeks" and the like - if a month begins on a Friday, then asking for the first Friday will give
  /// that day, for example.
  ///
  /// [year]: The year of the value to return.
  /// [month]: The month of the value to return.
  /// [occurrence]: The occurrence of the value to return, which must be in the range [1, 5]. The value 5 can
  /// be used to always return the last occurrence of the specified day-of-week, even if there are only 4
  /// occurrences of that day-of-week in the month.
  /// [dayOfWeek]: The day-of-week of the value to return.
  ///
  /// Returns the date corresponding to the given year and month, on the given occurrence of the
  /// given day of week.
  static LocalDate FromYearMonthWeekAndDay(int year, int month, int occurrence, IsoDayOfWeek dayOfWeek) {
    // This validates year and month as well as getting us a useful date.
    LocalDate startOfMonth = LocalDate(year, month, 1);
    Preconditions.CheckArgumentRange('occurrence', occurrence, 1, 5);
    Preconditions.CheckArgumentRange('dayOfWeek', dayOfWeek.value, 1, 7);

    // Correct day of week, 1st week of month.
    int week1Day = dayOfWeek.value - startOfMonth.DayOfWeek.value + 1;
    if (week1Day <= 0) {
      week1Day += 7;
    }
    int targetDay = week1Day + (occurrence - 1) * 7;
    if (targetDay > CalendarSystem.Iso.GetDaysInMonth(year, month)) {
      targetDay -= 7;
    }
    return LocalDate(year, month, targetDay);
  }

  /// Creates a [YearMonth] value for the month containing this date.
  ///
  /// Returns a year/month value containing this date.
  YearMonth ToYearMonth() => YearMonth(Year, Month, Calendar);

  /// Adds the specified period to the date.
  /// Fields are added in descending order of significance (years first, then months, and so on).
  ///
  /// [period]: The period to add. Must not contain any (non-zero) time units.
  ///
  /// Returns the sum of the given date and period
  LocalDate operator +(Period period) {
    // Dart: null safety checks period.
    Preconditions.CheckArgument(!period.HasTimeComponent, 'period', 'Cannot add a period with a time component to a date');
    return PlusYears(period.Years)
        .PlusMonths(period.Months)
        .PlusWeeks(period.Weeks)
        .PlusDays(period.Days);
  }

  /// Adds the specified period to the date.
  /// Fields are added in descending order of significance (years first, then months, and so on).
  /// Friendly alternative to `operator+()`.
  ///
  /// [date]: The date to add the period to
  /// [period]: The period to add. Must not contain any (non-zero) time units.
  ///
  /// Returns the sum of the given date and period
  static LocalDate Add(LocalDate date, Period period) => date + period;

  /// Adds the specified period to this date.
  /// Fields are added in descending order of significance (years first, then months, and so on).
  /// Fluent alternative to `operator+()`.
  ///
  /// [period]: The period to add. Must not contain any (non-zero) time units.
  ///
  /// Returns the sum of this date and the given period
  LocalDate Plus(Period period) => this + period;

  // noda_dart: C#'s operator +(LocalDate, LocalTime) is At(LocalTime), as `+` takes a Period.

  /// Subtracts the specified period from the date.
  /// Fields are subtracted in descending order of significance (years first, then months, and so on).
  /// This is a convenience operator over the [Minus] method.
  ///
  /// [period]: The period to subtract. Must not contain any (non-zero) time units.
  ///
  /// Returns the result of subtracting the given period from the date
  LocalDate operator -(Period period) {
    // Dart: null safety checks period.
    Preconditions.CheckArgument(!period.HasTimeComponent, 'period', 'Cannot subtract a period with a time component from a date');
    return PlusYears(Checked.ToInt32(-period.Years))
        .PlusMonths(Checked.ToInt32(-period.Months))
        .PlusWeeks(Checked.ToInt32(-period.Weeks))
        .PlusDays(Checked.ToInt32(-period.Days));
  }

  /// Subtracts the specified period from the date.
  /// Fields are subtracted in descending order of significance (years first, then months, and so on).
  /// Friendly alternative to `operator-()`.
  ///
  /// [date]: The date to subtract the period from
  /// [period]: The period to subtract. Must not contain any (non-zero) time units.
  ///
  /// Returns the result of subtracting the given period from the date.
  static LocalDate Subtract(LocalDate date, Period period) => date - period;

  /// Subtracts the specified period from this date.
  /// Fields are subtracted in descending order of significance (years first, then months, and so on).
  /// Fluent alternative to `operator-()`.
  ///
  /// [period]: The period to subtract. Must not contain any (non-zero) time units.
  ///
  /// Returns the result of subtracting the given period from this date.
  LocalDate Minus(Period period) => this - period;

  // noda_dart: C#'s operator -(LocalDate, LocalDate) is SubtractLocalDate/MinusLocalDate, as `-` takes a Period.

  /// Subtracts one date from another, returning the result as a [Period] with units of years, months and days.
  ///
  /// This is simply a convenience method for calling [Period.BetweenLocalDate].
  /// The calendar systems of the two dates must be the same.
  ///
  /// [lhs]: The date to subtract from
  /// [rhs]: The date to subtract
  ///
  /// Returns the result of subtracting one date from another.
  ///
  /// Throws [ArgumentError] if [lhs] and [rhs] are not in the same calendar system.
  // noda_dart: C#'s Subtract(LocalDate lhs, LocalDate rhs).
  static Period SubtractLocalDate(LocalDate lhs, LocalDate rhs) => Period.BetweenLocalDate(rhs, lhs);

  /// Subtracts the specified date from this date, returning the result as a [Period] with units of years, months and days.
  /// Fluent alternative to `operator-()`.
  ///
  /// The specified date must be in the same calendar system as this.
  ///
  /// [date]: The date to subtract from this
  ///
  /// Returns the difference between the specified date and this one
  // noda_dart: C#'s Minus(LocalDate date).
  Period MinusLocalDate(LocalDate date) => SubtractLocalDate(this, date);

  /// Compares two [LocalDate] values for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns true if the two dates are the same and in the same calendar; false otherwise
  // noda_dart: C#'s operator ==(LocalDate, LocalDate) and Equals(object); `!=` is Dart's.
  @override
  bool operator ==(Object other) => other is LocalDate && _yearMonthDayCalendar == other._yearMonthDayCalendar;

  // Comparison operators: note that we can't use YearMonthDayCalendar.Compare, as only the calendar knows whether it can use
  // naive comparisons.

  /// Compares two dates to see if the left one is strictly earlier than the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Throws [ArgumentError] if the calendar system of [rhs] is not the same
  /// as the calendar of this value.
  ///
  /// Returns true if this value is strictly earlier than [rhs], false otherwise.
  bool operator <(LocalDate rhs) {
    Preconditions.CheckArgument(_CalendarOrdinal == rhs._CalendarOrdinal, 'rhs', 'Only values in the same calendar can be compared');
    return _TrustedCompareTo(rhs) < 0;
  }

  /// Compares two dates to see if the left one is earlier than or equal to the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Throws [ArgumentError] if the calendar system of [rhs] is not the same
  /// as the calendar of this value.
  ///
  /// Returns true if this value is earlier than or equal to [rhs], false otherwise.
  bool operator <=(LocalDate rhs) {
    Preconditions.CheckArgument(_CalendarOrdinal == rhs._CalendarOrdinal, 'rhs', 'Only values in the same calendar can be compared');
    return _TrustedCompareTo(rhs) <= 0;
  }

  /// Compares two dates to see if the left one is strictly later than the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Throws [ArgumentError] if the calendar system of [rhs] is not the same
  /// as the calendar of this value.
  ///
  /// Returns true if this value is strictly later than [rhs], false otherwise.
  bool operator >(LocalDate rhs) {
    Preconditions.CheckArgument(_CalendarOrdinal == rhs._CalendarOrdinal, 'rhs', 'Only values in the same calendar can be compared');
    return _TrustedCompareTo(rhs) > 0;
  }

  /// Compares two dates to see if the left one is later than or equal to the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Throws [ArgumentError] if the calendar system of [rhs] is not the same
  /// as the calendar of this value.
  ///
  /// Returns true if this value is later than or equal to [rhs], false otherwise.
  bool operator >=(LocalDate rhs) {
    Preconditions.CheckArgument(_CalendarOrdinal == rhs._CalendarOrdinal, 'rhs', 'Only values in the same calendar can be compared');
    return _TrustedCompareTo(rhs) >= 0;
  }

  /// Indicates whether this date is earlier, later or the same as another one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [other]: The other date to compare this one with
  ///
  /// Throws [ArgumentError] if the calendar system of [other] is not the
  /// same as the calendar system of this value.
  ///
  /// Returns a value less than zero if this date is earlier than [other];
  /// zero if this date is the same as [other]; a value greater than zero if this date is
  /// later than [other].
  @override
  int compareTo(LocalDate other) {
    Preconditions.CheckArgument(_CalendarOrdinal == other._CalendarOrdinal, 'other', 'Only values with the same calendar system can be compared');
    return _TrustedCompareTo(other);
  }

  /// Performs a comparison with another date, trusting that the calendar of the other date is already correct.
  /// This avoids duplicate calendar checks.
  int _TrustedCompareTo(LocalDate other) => Calendar.Compare(YearMonthDay, other.YearMonthDay);

  /// Implementation of `IComparable.CompareTo` to compare two LocalDates.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// This uses explicit interface implementation to avoid it being called accidentally. The generic implementation should usually be preferred.
  ///
  /// Throws [ArgumentError] if [obj] is non-null but does not refer to an instance of [LocalDate], or refers
  /// to a date in a different calendar system.
  ///
  /// [obj]: The object to compare this value with.
  ///
  /// Returns the result of comparing this LocalDate with another one.
  /// If [obj] is null, this method returns a value greater than 0.
  int CompareTo(Object? obj) {
    if (obj == null) {
      return 1;
    }
    Preconditions.CheckArgument(obj is LocalDate, 'obj', 'Object must be of type NodaTime.LocalDate.');
    return compareTo(obj as LocalDate);
  }

  /// Returns the later date of the given two.
  ///
  /// [x]: The first date to compare.
  /// [y]: The second date to compare.
  ///
  /// Throws [ArgumentError] if the two dates have different calendar systems.
  ///
  /// Returns the later date of [x] or [y].
  static LocalDate Max(LocalDate x, LocalDate y) {
    Preconditions.CheckArgument(x.Calendar == y.Calendar, 'y', 'Only values with the same calendar system can be compared');
    return x > y ? x : y;
  }

  /// Returns the earlier date of the given two.
  ///
  /// [x]: The first date to compare.
  /// [y]: The second date to compare.
  ///
  /// Throws [ArgumentError] if the two dates have different calendar systems.
  ///
  /// Returns the earlier date of [x] or [y].
  static LocalDate Min(LocalDate x, LocalDate y) {
    Preconditions.CheckArgument(x.Calendar == y.Calendar, 'y', 'Only values with the same calendar system can be compared');
    return x < y ? x : y;
  }

  /// Returns a hash code for this local date.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a hash code for this local date.
  @override
  int get hashCode => _yearMonthDayCalendar.hashCode;

  // noda_dart: C#'s Equals(object) is operator ==, above.

  /// Compares two [LocalDate] values for equality.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [other]: The value to compare this date with.
  ///
  /// Returns true if the given value is another local date equal to this one; false otherwise.
  bool Equals(LocalDate other) => this == other;

  /// Resolves this local date into a [ZonedDateTime] in the given time zone representing the
  /// start of this date in the given zone.
  ///
  /// This is a convenience method for calling [DateTimeZone.AtStartOfDay].
  ///
  /// [zone]: The time zone to map this local date into
  ///
  /// Throws [SkippedTimeException] if the entire day was skipped due to a very large time zone transition.
  /// (This is extremely rare.)
  ///
  /// Returns the [ZonedDateTime] representing the earliest time on this date, in the given time zone.
  ZonedDateTime AtStartOfDayInZone(DateTimeZone zone) {
    // Dart: null safety checks zone.
    return zone.AtStartOfDay(this);
  }

  /// Creates a new LocalDate representing the same physical date, but in a different calendar.
  /// The returned LocalDate is likely to have different field values to this one.
  /// For example, January 1st 1970 in the Gregorian calendar was December 19th 1969 in the Julian calendar.
  ///
  /// [calendar]: The calendar system to convert this local date to.
  ///
  /// Returns the converted LocalDate
  LocalDate WithCalendar(CalendarSystem calendar) {
    // Dart: null safety checks calendar.
    return calendar.Ordinal == _CalendarOrdinal
        ? this
        : LocalDate.NewDaysSinceEpochCalendar(DaysSinceEpoch, calendar);
  }

  /// Returns a new LocalDate representing the current value with the given number of years added.
  ///
  /// If the resulting date is invalid, lower fields (typically the day of month) are reduced to find a valid value.
  /// For example, adding one year to February 29th 2012 will return February 28th 2013; subtracting one year from
  /// February 29th 2012 will return February 28th 2011.
  ///
  /// [years]: The number of years to add
  ///
  /// Returns the current value plus the given number of years.
  LocalDate PlusYears(int years) => DatePeriodFields.YearsField.Add(this, years);

  /// Returns a new LocalDate representing the current value with the given number of months added.
  ///
  /// This method does not try to maintain the year of the current value, so adding four months to a value in
  /// October will result in a value in the following February.
  ///
  /// If the resulting date is invalid, the day of month is reduced to find a valid value.
  /// For example, adding one month to January 30th 2011 will return February 28th 2011; subtracting one month from
  /// March 30th 2011 will return February 28th 2011.
  ///
  /// [months]: The number of months to add
  ///
  /// Returns the current date plus the given number of months
  LocalDate PlusMonths(int months) => DatePeriodFields.MonthsField.Add(this, months);

  /// Returns a new LocalDate representing the current value with the given number of days added.
  ///
  /// This method does not try to maintain the month or year of the current value, so adding 3 days to a value of January 30th
  /// will result in a value of February 2nd.
  ///
  /// [days]: The number of days to add
  ///
  /// Returns the current value plus the given number of days.
  LocalDate PlusDays(int days) => DatePeriodFields.DaysField.Add(this, days);

  /// Returns a new LocalDate representing the current value with the given number of weeks added.
  ///
  /// [weeks]: The number of weeks to add
  ///
  /// Returns the current value plus the given number of weeks.
  LocalDate PlusWeeks(int weeks) => DatePeriodFields.WeeksField.Add(this, weeks);

  /// Returns the next [LocalDate] falling on the specified [IsoDayOfWeek].
  /// This is a strict "next" - if this date on already falls on the target
  /// day of the week, the returned value will be a week later.
  ///
  /// [targetDayOfWeek]: The ISO day of the week to return the next date of.
  ///
  /// Returns the next [LocalDate] falling on the specified day of the week.
  ///
  /// Throws [StateError] if the underlying calendar doesn't use ISO days of the week.
  /// Throws [RangeError] if [targetDayOfWeek] is not a valid day of the
  /// week (Monday to Sunday).
  LocalDate Next(IsoDayOfWeek targetDayOfWeek) {
    // Avoids boxing...
    if (targetDayOfWeek.value < IsoDayOfWeek.Monday.value || targetDayOfWeek.value > IsoDayOfWeek.Sunday.value) {
      throw RangeError.value(targetDayOfWeek.value, 'targetDayOfWeek', 'Specified argument was out of the range of valid values.');
    }
    // This will throw the desired exception for calendars with different week systems.
    IsoDayOfWeek thisDay = DayOfWeek;
    int difference = targetDayOfWeek.value - thisDay.value;
    if (difference <= 0) {
      difference += 7;
    }
    return PlusDays(difference);
  }

  /// Returns the previous [LocalDate] falling on the specified [IsoDayOfWeek].
  /// This is a strict "previous" - if this date on already falls on the target
  /// day of the week, the returned value will be a week earlier.
  ///
  /// [targetDayOfWeek]: The ISO day of the week to return the previous date of.
  ///
  /// Returns the previous [LocalDate] falling on the specified day of the week.
  ///
  /// Throws [StateError] if the underlying calendar doesn't use ISO days of the week.
  /// Throws [RangeError] if [targetDayOfWeek] is not a valid day of the
  /// week (Monday to Sunday).
  LocalDate Previous(IsoDayOfWeek targetDayOfWeek) {
    // Avoids boxing...
    if (targetDayOfWeek.value < IsoDayOfWeek.Monday.value || targetDayOfWeek.value > IsoDayOfWeek.Sunday.value) {
      throw RangeError.value(targetDayOfWeek.value, 'targetDayOfWeek', 'Specified argument was out of the range of valid values.');
    }
    // This will throw the desired exception for calendars with different week systems.
    IsoDayOfWeek thisDay = DayOfWeek;
    int difference = targetDayOfWeek.value - thisDay.value;
    if (difference >= 0) {
      difference -= 7;
    }
    return PlusDays(difference);
  }

  /// Returns an [OffsetDate] for this local date with the given offset.
  ///
  /// This method is purely a convenient alternative to calling the [OffsetDate] constructor directly.
  ///
  /// [offset]: The offset to apply.
  ///
  /// Returns the result of this date offset by the given amount.
  OffsetDate WithOffset(Offset offset) => OffsetDate(this, offset);

  /// Combines this [LocalDate] with the given [LocalTime]
  /// into a single [LocalDateTime].
  /// Fluent alternative to `operator+()`.
  ///
  /// [time]: The time to combine with this date.
  ///
  /// Returns the [LocalDateTime] representation of the given time on this date
  // noda_dart: C#'s operator +(LocalDate, LocalTime).
  LocalDateTime At(LocalTime time) => LocalDateTime.NewDateTime(this, time);

  /// Returns this date, with the given adjuster applied to it.
  ///
  /// If the adjuster attempts to construct an invalid date (such as by trying
  /// to set a day-of-month of 30 in February), any exception thrown by
  /// that construction attempt will be propagated through this method.
  ///
  /// [adjuster]: The adjuster to apply.
  ///
  /// Returns the adjusted date.
  LocalDate With(LocalDate Function(LocalDate) adjuster) {
    // Dart: null safety checks adjuster.
    return adjuster(this);
  }

  /// Deconstructs the current instance into its components: the year, month and day.
  ///
  /// `final (year, month, day) = date.Deconstruct;`
  // noda_dart: C#'s Deconstruct(out int year, out int month, out int day).
  (int year, int month, int day) get Deconstruct => (Year, Month, Day);

  /// Deconstructs the current instance into its components: the year, month and day, and the [CalendarSystem]
  /// associated with the date.
  ///
  /// `final (year, month, day, calendar) = date.DeconstructCalendarSystem;`
  // noda_dart: C#'s Deconstruct(out int year, out int month, out int day, out CalendarSystem calendar).
  (int year, int month, int day, CalendarSystem calendar) get DeconstructCalendarSystem => (Year, Month, Day, Calendar);

  // #region Formatting
  /// Returns a [String] that represents this instance.
  ///
  /// Returns the value of the current instance in the default format pattern ("D"), using the invariant culture
  /// (NodaTime uses the current thread's culture; Dart has none).
  @override
  String toString() => LocalDatePattern.BclSupport.Format(this, null, NodaCultureInfo.InvariantCulture);

  /// Formats the value of the current instance using the specified pattern.
  ///
  /// Returns a [String] containing the value of the current instance in the specified format.
  ///
  /// [patternText]: The [String] specifying the pattern to use,
  /// or null to use the default format pattern ("D").
  /// [formatProvider]: The [IFormatProvider] to use when formatting the value,
  /// or null to use the invariant culture.
  // noda_dart: C#'s ToString(string? patternText, IFormatProvider? formatProvider).
  String ToStringPattern(String? patternText, [IFormatProvider? formatProvider]) =>
      LocalDatePattern.BclSupport.Format(this, patternText, formatProvider);
  // #endregion Formatting

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable.GetSchema, ReadXml, WriteXml (XML serialization)
  // #endregion

  // #region DateOnly conversions (.NET 6 only)
  // Not ported: ToDateOnly(), FromDateOnly(DateOnly) (Dart has no DateOnly type)
  // #endregion

  // #region JSON (noda_dart)
  /// Formats this value with [LocalDatePattern.Iso], as NodaTime.Serialization.SystemTextJson does.
  String toJson() => LocalDatePattern.Iso.Format(this);

  /// Parses a value written by [toJson], in [calendar] (default ISO).
  ///
  /// Throws [UnparsableValueException] if the value can't be parsed.
  factory LocalDate.fromJson(String json, [CalendarSystem? calendar]) =>
      (calendar == null ? LocalDatePattern.Iso : LocalDatePattern.Iso.WithCalendar(calendar)).Parse(json).Value;
  // #endregion
}
