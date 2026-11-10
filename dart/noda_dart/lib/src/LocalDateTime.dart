// Ported from NodaTime 6e024dde: src/NodaTime/LocalDateTime.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:core' as core;
import 'dart:core';

import 'package:meta/meta.dart';

import 'CalendarSystem.dart';
import 'Calendars/Era.dart' as nt show Era;
import 'DateTimeZone.dart';
import 'Fields/TimePeriodField.dart';
import 'Globalization/NodaCultureInfo.dart';
import 'IsoDayOfWeek.generated.dart';
import 'LocalDate.dart';
import 'LocalInstant.dart';
import 'LocalTime.dart';
import 'NodaConstants.dart';
import 'Offset.dart';
import 'OffsetDateTime.dart';
import 'OffsetTime.dart';
import 'Period.dart';
import 'Text/LocalDateTimePattern.dart';
import 'TimeZones/Delegates.dart';
import 'Utility/Checked.dart';
import 'Utility/HashCodeHelper.dart';
import 'Utility/Preconditions.dart';
import 'ZonedDateTime.dart';

// TODO(feature): Calendar-neutral comparer.

/// A date and time in a particular calendar system. A LocalDateTime value does not represent an
/// instant on the global time line, because it has no associated time zone: "November 12th 2009 7pm, ISO calendar"
/// occurred at different instants for different people around the world.
///
/// This type defaults to using the ISO calendar system unless a different calendar system is
/// specified.
///
/// Values can freely be compared for equality: a value in a different calendar system is not equal to
/// a value in a different calendar system. However, ordering comparisons (either via the [compareTo] method
/// or via operators) fail with [ArgumentError]; attempting to compare values in different calendars
/// almost always indicates a bug in the calling code.
///
/// The default value of this type is 0001-01-01T00:00:00 (midnight on January 1st, 1 C.E.) in the ISO calendar.
///
/// Thread safety: This type is an immutable value type. See the thread safety section of the user guide for more information.
// Not ported: [TypeConverter(typeof(LocalDateTimeTypeConverter))], [XmlSchemaProvider], IXmlSerializable (not ported, see below)
final class LocalDateTime implements Comparable<LocalDateTime> {
  /// The maximum (latest) date and time representable in the ISO calendar system.
  /// This is a nanosecond before midnight at the end of [LocalDate.MaxIsoValue].
  static LocalDateTime get MaxIsoValue => LocalDate.MaxIsoValue.At(LocalTime.MaxValue);

  /// The minimum (earliest) date and time representable in the ISO calendar system.
  /// This is midnight at the start of [LocalDate.MinIsoValue].
  static LocalDateTime get MinIsoValue => LocalDate.MinIsoValue.At(LocalTime.MinValue);

  final LocalDate _date;
  final LocalTime _time;

  /// Initializes a new instance of the [LocalDateTime] struct using the ISO
  /// calendar system.
  ///
  /// [localInstant]: The local instant.
  ///
  /// Returns the resulting date/time.
  @internal
  LocalDateTime.NewLocalInstant(LocalInstant localInstant)
      : _date = LocalDate.NewDaysSinceEpoch(localInstant.DaysSinceEpoch),
        _time = LocalTime.NewNanoseconds(localInstant.NanosecondOfDay);

  /// Initializes a new instance of the [LocalDateTime] struct, using the ISO calendar system unless [calendar] is
  /// given.
  ///
  /// [year]: The year. This is the "absolute year", so, for
  /// the ISO calendar, a value of 0 means 1 BC, for example.
  /// [month]: The month of year.
  /// [day]: The day of month.
  /// [hour]: The hour.
  /// [minute]: The minute.
  /// [second]: The second.
  /// [millisecond]: The millisecond.
  /// [calendar]: The calendar.
  ///
  /// Returns the resulting date/time.
  ///
  /// Throws [RangeError] if the parameters do not form a valid date/time.
  // noda_dart: C#'s overloads up to (..., millisecond, calendar); see also YearMonthDayHourMinute(Second)Calendar.
  LocalDateTime(int year, int month, int day, int hour, int minute,
      [int second = 0, int millisecond = 0, CalendarSystem? calendar])
      : this.NewDateTime(LocalDate(year, month, day, calendar),
            LocalTime(hour, minute, second, millisecond));

  /// Initializes a new instance of the [LocalDateTime] struct.
  ///
  /// [year]: The year. This is the "absolute year", so, for
  /// the ISO calendar, a value of 0 means 1 BC, for example.
  /// [month]: The month of year.
  /// [day]: The day of month.
  /// [hour]: The hour.
  /// [minute]: The minute.
  /// [calendar]: The calendar.
  ///
  /// Returns the resulting date/time.
  ///
  /// Throws [RangeError] if the parameters do not form a valid date/time.
  // noda_dart: C#'s LocalDateTime(int year, int month, int day, int hour, int minute, CalendarSystem calendar).
  LocalDateTime.YearMonthDayHourMinuteCalendar(int year, int month, int day, int hour, int minute, CalendarSystem calendar)
      : this.NewDateTime(LocalDate(year, month, day, calendar),
            LocalTime(hour, minute));

  /// Initializes a new instance of the [LocalDateTime] struct.
  ///
  /// [year]: The year. This is the "absolute year", so, for
  /// the ISO calendar, a value of 0 means 1 BC, for example.
  /// [month]: The month of year.
  /// [day]: The day of month.
  /// [hour]: The hour.
  /// [minute]: The minute.
  /// [second]: The second.
  /// [calendar]: The calendar.
  ///
  /// Returns the resulting date/time.
  ///
  /// Throws [RangeError] if the parameters do not form a valid date/time.
  // noda_dart: C#'s LocalDateTime(int year, int month, int day, int hour, int minute, int second, CalendarSystem calendar).
  LocalDateTime.YearMonthDayHourMinuteSecondCalendar(int year, int month, int day, int hour, int minute, int second,
      CalendarSystem calendar)
      : this.NewDateTime(LocalDate(year, month, day, calendar),
            LocalTime(hour, minute, second));

  @internal
  LocalDateTime.NewDateTime(LocalDate date, LocalTime time)
      : _date = date,
        _time = time;

  /// Gets the calendar system associated with this local date and time.
  CalendarSystem get Calendar => _date.Calendar;

  /// Gets the year of this local date and time.
  ///
  /// This returns the "absolute year", so, for the ISO calendar,
  /// a value of 0 means 1 BC, for example.
  int get Year => _date.Year;

  /// Gets the year of this local date and time within its era.
  int get YearOfEra => _date.YearOfEra;

  /// Gets the era of this local date and time.
  nt.Era get Era => _date.Era;

  /// Gets the month of this local date and time within the year.
  int get Month => _date.Month;

  /// Gets the day of this local date and time within the year.
  int get DayOfYear => _date.DayOfYear;

  /// Gets the day of this local date and time within the month.
  int get Day => _date.Day;

  /// Gets the week day of this local date and time expressed as an [IsoDayOfWeek] value.
  IsoDayOfWeek get DayOfWeek => _date.DayOfWeek;

  /// Gets the hour of day of this local date and time, in the range 0 to 23 inclusive.
  int get Hour => _time.Hour;

  /// Gets the hour of the half-day of this local date and time, in the range 1 to 12 inclusive.
  int get ClockHourOfHalfDay => _time.ClockHourOfHalfDay;

  /// Gets the minute of this local date and time, in the range 0 to 59 inclusive.
  int get Minute => _time.Minute;

  /// Gets the second of this local date and time within the minute, in the range 0 to 59 inclusive.
  int get Second => _time.Second;

  /// Gets the millisecond of this local date and time within the second, in the range 0 to 999 inclusive.
  int get Millisecond => _time.Millisecond;

  /// Gets the tick of this local time within the second, in the range 0 to 9,999,999 inclusive.
  int get TickOfSecond => _time.TickOfSecond;

  /// Gets the tick of this local date and time within the day, in the range 0 to 863,999,999,999 inclusive.
  int get TickOfDay => _time.TickOfDay;

  /// Gets the nanosecond of this local time within the second, in the range 0 to 999,999,999 inclusive.
  int get NanosecondOfSecond => _time.NanosecondOfSecond;

  /// Gets the nanosecond of this local date and time within the day, in the range 0 to 86,399,999,999,999 inclusive.
  int get NanosecondOfDay => _time.NanosecondOfDay;

  /// Gets the time portion of this local date and time as a [LocalTime].
  LocalTime get TimeOfDay => _time;

  /// Gets the date portion of this local date and time as a [LocalDate] in the same calendar system as this value.
  LocalDate get Date => _date;

  /// Constructs a [core.DateTime] from this value which has a [core.DateTime.isUtc] of `false` (.NET's
  /// `DateTimeKind.Unspecified`).
  ///
  /// `DateTimeKind.Unspecified` is slightly odd - it can be treated as UTC if you use `DateTime.ToLocalTime`
  /// or as system local time if you use `DateTime.ToUniversalTime`, but it's the only kind which allows
  /// you to construct a `DateTimeOffset` with an arbitrary offset, which makes it as close to
  /// the Noda Time non-system-specific "local" concept as exists in .NET.
  ///
  /// If the date and time is not on a microsecond boundary (the unit of granularity of Dart's DateTime) the value
  /// will be truncated towards the start of time.
  ///
  /// [core.DateTime] uses the Gregorian calendar by definition, so the value is implicitly converted
  /// to the Gregorian calendar first. The result will be on the same physical day,
  /// but the values returned by the year/month/day properties of the [core.DateTime] may not
  /// match the Year/Month/Day properties of this value.
  ///
  /// noda_dart: Dart has no unspecified kind, so the result is a local [core.DateTime].
  ///
  /// Throws [StateError] if the date/time is outside the range of .NET's `DateTime` (before the year 1).
  ///
  /// Returns a [core.DateTime] value for the same date and time as this value.
  core.DateTime ToDateTimeUnspecified() {
    // noda_dart: C#'s ticks check, on the days (the ticks can exceed 2^53).
    int days = _date.DaysSinceEpoch;
    if (days < -NodaConstants.BclDaysAtUnixEpoch) {
      throw StateError('LocalDateTime out of range of DateTime');
    }
    LocalDate isoDate = _date.WithCalendar(CalendarSystem.Iso);
    return core.DateTime(isoDate.Year, isoDate.Month, isoDate.Day, _time.Hour, _time.Minute, _time.Second,
        _time.Millisecond, _time.NanosecondOfSecond.remainder(NodaConstants.NanosecondsPerMillisecond) ~/ NodaConstants.NanosecondsPerMicrosecond);
  }

  @internal
  LocalInstant ToLocalInstant() => LocalInstant.NewDaysNanoOfDay(_date.DaysSinceEpoch, _time.NanosecondOfDay);

  /// Converts a [core.DateTime] of any kind (local or UTC) to a LocalDateTime in the ISO calendar, or (if [calendar]
  /// is given) in the specified calendar. This does not perform any time zone conversions, so a DateTime with a
  /// [core.DateTime.isUtc] of `true` will still have the same day/hour/minute etc - it won't be converted into the
  /// local system time.
  ///
  /// [dateTime]: Value to convert into a Noda Time local date and time
  /// [calendar]: The calendar system to convert into
  ///
  /// Returns a new [LocalDateTime] with the same values as the specified `DateTime`.
  // noda_dart: C#'s FromDateTime(DateTime) and FromDateTime(DateTime, CalendarSystem).
  static LocalDateTime FromDateTime(core.DateTime dateTime, [CalendarSystem? calendar]) {
    // noda_dart: C#'s NonNegativeTicksToDaysAndTickOfDay(DateTime.Ticks), from the DateTime's fields.
    int days = core.DateTime.utc(dateTime.year, dateTime.month, dateTime.day).millisecondsSinceEpoch ~/ NodaConstants.MillisecondsPerDay;
    int nanosecondOfDay =
        dateTime.hour * NodaConstants.NanosecondsPerHour +
        dateTime.minute * NodaConstants.NanosecondsPerMinute +
        dateTime.second * NodaConstants.NanosecondsPerSecond +
        dateTime.millisecond * NodaConstants.NanosecondsPerMillisecond +
        dateTime.microsecond * NodaConstants.NanosecondsPerMicrosecond;
    if (calendar == null) {
      // noda_dart: validated, as Dart's DateTime range is wider than the ISO calendar's.
      return LocalDateTime.NewDateTime(LocalDate.NewDaysSinceEpochCalendar(days, CalendarSystem.Iso), LocalTime.NewNanoseconds(nanosecondOfDay));
    }
    // Dart: null safety checks calendar.
    return LocalDateTime.NewDateTime(LocalDate.NewDaysSinceEpochCalendar(days, calendar), LocalTime.NewNanoseconds(nanosecondOfDay));
  }

  // #region Implementation of IEquatable<LocalDateTime>
  /// Indicates whether the current object is equal to another object of the same type.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: An object to compare with this object.
  ///
  /// Returns true if the current object is equal to the [other] parameter; otherwise, false.
  bool Equals(LocalDateTime other) => _date == other._date && _time == other._time;
  // #endregion

  // #region Operators
  /// Implements the operator == (equality).
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns `true` if values are equal to each other, otherwise `false`.
  // noda_dart: C#'s operator ==(LocalDateTime, LocalDateTime) and Equals(object); `!=` is Dart's.
  @override
  bool operator ==(Object other) => other is LocalDateTime && Equals(other);

  /// Compares two LocalDateTime values to see if the left one is strictly earlier than the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Throws [ArgumentError] if the calendar system of [rhs] is not the same
  /// as the calendar of this value.
  ///
  /// Returns true if this value is strictly earlier than [rhs], false otherwise.
  bool operator <(LocalDateTime rhs) {
    Preconditions.CheckArgument(Calendar == rhs.Calendar, 'rhs', 'Only values in the same calendar can be compared');
    return compareTo(rhs) < 0;
  }

  /// Compares two LocalDateTime values to see if the left one is earlier than or equal to the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Throws [ArgumentError] if the calendar system of [rhs] is not the same
  /// as the calendar of this value.
  ///
  /// Returns true if this value is earlier than or equal to [rhs], false otherwise.
  bool operator <=(LocalDateTime rhs) {
    Preconditions.CheckArgument(Calendar == rhs.Calendar, 'rhs', 'Only values in the same calendar can be compared');
    return compareTo(rhs) <= 0;
  }

  /// Compares two LocalDateTime values to see if the left one is strictly later than the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Throws [ArgumentError] if the calendar system of [rhs] is not the same
  /// as the calendar of this value.
  ///
  /// Returns true if this value is strictly later than [rhs], false otherwise.
  bool operator >(LocalDateTime rhs) {
    Preconditions.CheckArgument(Calendar == rhs.Calendar, 'rhs', 'Only values in the same calendar can be compared');
    return compareTo(rhs) > 0;
  }

  /// Compares two LocalDateTime values to see if the left one is later than or equal to the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Throws [ArgumentError] if the calendar system of [rhs] is not the same
  /// as the calendar of this value.
  ///
  /// Returns true if this value is later than or equal to [rhs], false otherwise.
  bool operator >=(LocalDateTime rhs) {
    Preconditions.CheckArgument(Calendar == rhs.Calendar, 'rhs', 'Only values in the same calendar can be compared');
    return compareTo(rhs) >= 0;
  }

  /// Indicates whether this date/time is earlier, later or the same as another one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [other]: The other local date/time to compare with this value.
  ///
  /// Throws [ArgumentError] if the calendar system of [other] is not the
  /// same as the calendar system of this value.
  ///
  /// Returns a value less than zero if this date/time is earlier than [other];
  /// zero if this date/time is the same as [other]; a value greater than zero if this date/time is
  /// later than [other].
  @override
  int compareTo(LocalDateTime other) {
    // This will check calendars...
    int dateComparison = _date.compareTo(other._date);
    if (dateComparison != 0) {
      return dateComparison;
    }
    return _time.compareTo(other._time);
  }

  /// Implementation of `IComparable.CompareTo` to compare two LocalDateTimes.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// This uses explicit interface implementation to avoid it being called accidentally. The generic implementation should usually be preferred.
  ///
  /// Throws [ArgumentError] if [obj] is non-null but does not refer to an instance of [LocalDateTime],
  /// or refers to a date/time in a different calendar system.
  ///
  /// [obj]: The object to compare this value with.
  ///
  /// Returns the result of comparing this LocalDateTime with another one; see [compareTo] for general details.
  /// If [obj] is null, this method returns a value greater than 0.
  int CompareTo(Object? obj) {
    if (obj == null) {
      return 1;
    }
    Preconditions.CheckArgument(obj is LocalDateTime, 'obj', 'Object must be of type NodaTime.LocalDateTime.');
    return compareTo(obj as LocalDateTime);
  }

  /// Adds a period to a local date/time.
  /// Fields are added in descending order of significance (years first, then months, and so on).
  /// This is a convenience operator over the [Plus] method.
  ///
  /// [period]: Period to add
  ///
  /// Returns the resulting local date and time
  LocalDateTime operator +(Period period) => Plus(period);

  /// Add the specified period to the date and time.
  /// Fields are added in descending order of significance (years first, then months, and so on).
  /// Friendly alternative to `operator+()`.
  ///
  /// [localDateTime]: Initial local date and time
  /// [period]: Period to add
  ///
  /// Returns the resulting local date and time
  static LocalDateTime Add(LocalDateTime localDateTime, Period period) => localDateTime.Plus(period);

  /// Adds a period to this local date/time.
  /// Fields are added in descending order of significance (years first, then months, and so on).
  ///
  /// [period]: Period to add
  ///
  /// Returns the resulting local date and time
  LocalDateTime Plus(Period period) {
    // Dart: null safety checks period.
    int extraDays = 0;
    LocalTime time = TimeOfDay;
    (time, extraDays) = TimePeriodField.Hours.AddLocalTimeExtraDays(time, period.Hours, extraDays);
    (time, extraDays) = TimePeriodField.Minutes.AddLocalTimeExtraDays(time, period.Minutes, extraDays);
    (time, extraDays) = TimePeriodField.Seconds.AddLocalTimeExtraDays(time, period.Seconds, extraDays);
    (time, extraDays) = TimePeriodField.Milliseconds.AddLocalTimeExtraDays(time, period.Milliseconds, extraDays);
    (time, extraDays) = TimePeriodField.Ticks.AddLocalTimeExtraDays(time, period.Ticks, extraDays);
    (time, extraDays) = TimePeriodField.Nanoseconds.AddLocalTimeExtraDays(time, period.Nanoseconds, extraDays);
    LocalDate date = Date.PlusYears(period.Years)
        .PlusMonths(period.Months)
        .PlusWeeks(period.Weeks)
        .PlusDays(Checked.AddInt32(period.Days, extraDays));
    return LocalDateTime.NewDateTime(date, time);
  }

  /// Subtracts a period from a local date/time.
  /// Fields are subtracted in descending order of significance (years first, then months, and so on).
  /// This is a convenience operator over the [Minus] method.
  ///
  /// [period]: Period to subtract
  ///
  /// Returns the resulting local date and time
  LocalDateTime operator -(Period period) => Minus(period);

  /// Subtracts the specified period from the date and time. Friendly alternative to `operator-()`.
  ///
  /// [localDateTime]: Initial local date and time
  /// [period]: Period to subtract
  ///
  /// Returns the resulting local date and time
  static LocalDateTime Subtract(LocalDateTime localDateTime, Period period) => localDateTime.Minus(period);

  /// Subtracts a period from a local date/time.
  /// Fields are subtracted in descending order of significance (years first, then months, and so on).
  ///
  /// [period]: Period to subtract
  ///
  /// Returns the resulting local date and time
  LocalDateTime Minus(Period period) {
    // Dart: null safety checks period.
    int extraDays = 0;
    LocalTime time = TimeOfDay;
    (time, extraDays) = TimePeriodField.Hours.AddLocalTimeExtraDays(time, Checked.Negate(period.Hours), extraDays);
    (time, extraDays) = TimePeriodField.Minutes.AddLocalTimeExtraDays(time, Checked.Negate(period.Minutes), extraDays);
    (time, extraDays) = TimePeriodField.Seconds.AddLocalTimeExtraDays(time, Checked.Negate(period.Seconds), extraDays);
    (time, extraDays) = TimePeriodField.Milliseconds.AddLocalTimeExtraDays(time, Checked.Negate(period.Milliseconds), extraDays);
    (time, extraDays) = TimePeriodField.Ticks.AddLocalTimeExtraDays(time, Checked.Negate(period.Ticks), extraDays);
    (time, extraDays) = TimePeriodField.Nanoseconds.AddLocalTimeExtraDays(time, Checked.Negate(period.Nanoseconds), extraDays);
    LocalDate date = Date.PlusYears(Checked.ToInt32(-period.Years))
        .PlusMonths(Checked.ToInt32(-period.Months))
        .PlusWeeks(Checked.ToInt32(-period.Weeks))
        .PlusDays(Checked.SubtractInt32(extraDays, period.Days));
    return LocalDateTime.NewDateTime(date, time);
  }

  // noda_dart: C#'s operator -(LocalDateTime, LocalDateTime) is SubtractLocalDateTime/MinusLocalDateTime.

  /// Subtracts one date/time from another, returning the result as a [Period].
  ///
  /// This is simply a convenience method for calling [Period.Between].
  /// The calendar systems of the two date/times must be the same.
  ///
  /// [lhs]: The date/time to subtract from
  /// [rhs]: The date/time to subtract
  ///
  /// Returns the result of subtracting one date/time from another.
  // noda_dart: C#'s Subtract(LocalDateTime lhs, LocalDateTime rhs).
  static Period SubtractLocalDateTime(LocalDateTime lhs, LocalDateTime rhs) => Period.Between(rhs, lhs);

  /// Subtracts the specified date/time from this date/time, returning the result as a [Period].
  /// Fluent alternative to `operator-()`.
  ///
  /// The specified date/time must be in the same calendar system as this.
  ///
  /// [localDateTime]: The date/time to subtract from this
  ///
  /// Returns the difference between the specified date/time and this one
  // noda_dart: C#'s Minus(LocalDateTime localDateTime).
  Period MinusLocalDateTime(LocalDateTime localDateTime) => SubtractLocalDateTime(this, localDateTime);
  // #endregion

  // #region object overrides
  // noda_dart: C#'s Equals(object) is operator ==, above.

  /// Returns a hash code for this instance.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a hash code for this instance, suitable for use in hashing algorithms and data
  /// structures like a hash table.
  @override
  int get hashCode => HashCodeHelper.HashStatic(_date, _time, Calendar);
  // #endregion

  /// Returns this date/time, with the given date adjuster applied to it, maintaining the existing time of day.
  ///
  /// If the adjuster attempts to construct an
  /// invalid date (such as by trying to set a day-of-month of 30 in February), any exception thrown by
  /// that construction attempt will be propagated through this method.
  ///
  /// [adjuster]: The adjuster to apply.
  ///
  /// Returns the adjusted date/time.
  LocalDateTime With(LocalDate Function(LocalDate) adjuster) =>
      _date.With(adjuster).At(_time);

  /// Returns this date/time, with the given time adjuster applied to it, maintaining the existing date.
  ///
  /// If the adjuster attempts to construct an invalid time, any exception thrown by
  /// that construction attempt will be propagated through this method.
  ///
  /// [adjuster]: The adjuster to apply.
  ///
  /// Returns the adjusted date/time.
  // noda_dart: C#'s With(Func<LocalTime, LocalTime> adjuster) (noda-js's name).
  LocalDateTime WithTimeAdjuster(LocalTime Function(LocalTime) adjuster) =>
      _date.At(_time.With(adjuster));

  /// Creates a new LocalDateTime representing the same physical date and time, but in a different calendar.
  /// The returned LocalDateTime is likely to have different date field values to this one.
  /// For example, January 1st 1970 in the Gregorian calendar was December 19th 1969 in the Julian calendar.
  ///
  /// [calendar]: The calendar system to convert this local date to.
  ///
  /// Returns the converted LocalDateTime.
  LocalDateTime WithCalendar(CalendarSystem calendar) {
    // Dart: null safety checks calendar.
    return LocalDateTime.NewDateTime(_date.WithCalendar(calendar), _time);
  }

  /// Returns a new LocalDateTime representing the current value with the given number of years added.
  ///
  /// If the resulting date is invalid, lower fields (typically the day of month) are reduced to find a valid value.
  /// For example, adding one year to February 29th 2012 will return February 28th 2013; subtracting one year from
  /// February 29th 2012 will return February 28th 2011.
  ///
  /// [years]: The number of years to add
  ///
  /// Returns the current value plus the given number of years.
  LocalDateTime PlusYears(int years) => LocalDateTime.NewDateTime(_date.PlusYears(years), _time);

  /// Returns a new LocalDateTime representing the current value with the given number of months added.
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
  /// Returns the current value plus the given number of months.
  LocalDateTime PlusMonths(int months) => LocalDateTime.NewDateTime(_date.PlusMonths(months), _time);

  /// Returns a new LocalDateTime representing the current value with the given number of days added.
  ///
  /// This method does not try to maintain the month or year of the current value, so adding 3 days to a value on January 30th
  /// will result in a value on February 2nd.
  ///
  /// [days]: The number of days to add
  ///
  /// Returns the current value plus the given number of days.
  LocalDateTime PlusDays(int days) => LocalDateTime.NewDateTime(_date.PlusDays(days), _time);

  /// Returns a new LocalDateTime representing the current value with the given number of weeks added.
  ///
  /// [weeks]: The number of weeks to add
  ///
  /// Returns the current value plus the given number of weeks.
  LocalDateTime PlusWeeks(int weeks) => LocalDateTime.NewDateTime(_date.PlusWeeks(weeks), _time);

  /// Returns a new LocalDateTime representing the current value with the given number of hours added.
  ///
  /// [hours]: The number of hours to add
  ///
  /// Returns the current value plus the given number of hours.
  LocalDateTime PlusHours(int hours) => TimePeriodField.Hours.Add(this, hours);

  /// Returns a new LocalDateTime representing the current value with the given number of minutes added.
  ///
  /// [minutes]: The number of minutes to add
  ///
  /// Returns the current value plus the given number of minutes.
  LocalDateTime PlusMinutes(int minutes) => TimePeriodField.Minutes.Add(this, minutes);

  /// Returns a new LocalDateTime representing the current value with the given number of seconds added.
  ///
  /// [seconds]: The number of seconds to add
  ///
  /// Returns the current value plus the given number of seconds.
  LocalDateTime PlusSeconds(int seconds) => TimePeriodField.Seconds.Add(this, seconds);

  /// Returns a new LocalDateTime representing the current value with the given number of milliseconds added.
  ///
  /// [milliseconds]: The number of milliseconds to add
  ///
  /// Returns the current value plus the given number of milliseconds.
  LocalDateTime PlusMilliseconds(int milliseconds) =>
      TimePeriodField.Milliseconds.Add(this, milliseconds);

  /// Returns a new LocalDateTime representing the current value with the given number of ticks added.
  ///
  /// [ticks]: The number of ticks to add
  ///
  /// Returns the current value plus the given number of ticks.
  LocalDateTime PlusTicks(int ticks) => TimePeriodField.Ticks.Add(this, ticks);

  /// Returns a new LocalDateTime representing the current value with the given number of nanoseconds added.
  ///
  /// [nanoseconds]: The number of nanoseconds to add
  ///
  /// Returns the current value plus the given number of nanoseconds.
  LocalDateTime PlusNanoseconds(int nanoseconds) => TimePeriodField.Nanoseconds.Add(this, nanoseconds);

  /// Returns the next [LocalDateTime] falling on the specified [IsoDayOfWeek],
  /// at the same time of day as this value.
  /// This is a strict "next" - if this value on already falls on the target
  /// day of the week, the returned value will be a week later.
  ///
  /// [targetDayOfWeek]: The ISO day of the week to return the next date of.
  ///
  /// Returns the next [LocalDateTime] falling on the specified day of the week.
  ///
  /// Throws [StateError] if the underlying calendar doesn't use ISO days of the week.
  /// Throws [RangeError] if [targetDayOfWeek] is not a valid day of the
  /// week (Monday to Sunday).
  LocalDateTime Next(IsoDayOfWeek targetDayOfWeek) => LocalDateTime.NewDateTime(_date.Next(targetDayOfWeek), _time);

  /// Returns the previous [LocalDateTime] falling on the specified [IsoDayOfWeek],
  /// at the same time of day as this value.
  /// This is a strict "previous" - if this value on already falls on the target
  /// day of the week, the returned value will be a week earlier.
  ///
  /// [targetDayOfWeek]: The ISO day of the week to return the previous date of.
  ///
  /// Returns the previous [LocalDateTime] falling on the specified day of the week.
  ///
  /// Throws [StateError] if the underlying calendar doesn't use ISO days of the week.
  /// Throws [RangeError] if [targetDayOfWeek] is not a valid day of the
  /// week (Monday to Sunday).
  LocalDateTime Previous(IsoDayOfWeek targetDayOfWeek) => LocalDateTime.NewDateTime(_date.Previous(targetDayOfWeek), _time);

  /// Returns an [OffsetDateTime] for this local date/time with the given offset.
  ///
  /// This method is purely a convenient alternative to calling the [OffsetDateTime] constructor directly.
  ///
  /// [offset]: The offset to apply.
  ///
  /// Returns the result of this local date/time offset by the given amount.
  OffsetDateTime WithOffset(Offset offset) => OffsetDateTime.NewLocalDateOffsetTime(_date, OffsetTime(_time, offset));

  /// Returns the mapping of this local date/time within [DateTimeZone.Utc].
  ///
  /// As UTC is a fixed time zone, there is no chance that this local date/time is ambiguous or skipped.
  ///
  /// Returns the result of mapping this local date/time in UTC.
  ZonedDateTime InUtc() =>
      // Use the internal constructors to avoid validation. We know it will be fine.
      ZonedDateTime.NewOffsetDateTimeZone(OffsetDateTime.NewLocalDateOffsetTime(_date,
          OffsetTime.NewNanosecondOfDayZeroOffset(_time.NanosecondOfDay)),
          DateTimeZone.Utc);

  /// Returns the mapping of this local date/time within the given [DateTimeZone],
  /// with "strict" rules applied such that an exception is thrown if either the mapping is
  /// ambiguous or the time is skipped.
  ///
  /// See [InZoneLeniently] and [InZone] for alternative ways to map a local time to a
  /// specific instant.
  /// This is solely a convenience method for calling [DateTimeZone.AtStrictly].
  ///
  /// [zone]: The time zone in which to map this local date/time.
  ///
  /// Throws [SkippedTimeException] if this local date/time is skipped in the given time zone.
  /// Throws [AmbiguousTimeException] if this local date/time is ambiguous in the given time zone.
  ///
  /// Returns the result of mapping this local date/time in the given time zone.
  ZonedDateTime InZoneStrictly(DateTimeZone zone) {
    // Dart: null safety checks zone.
    return zone.AtStrictly(this);
  }

  /// Returns the mapping of this local date/time within the given [DateTimeZone],
  /// with "lenient" rules applied such that ambiguous values map to the earlier of the alternatives, and
  /// "skipped" values are shifted forward by the duration of the "gap".
  ///
  /// See [InZoneStrictly] and [InZone] for alternative ways to map a local time to a
  /// specific instant.
  /// This is solely a convenience method for calling [DateTimeZone.AtLeniently].
  ///
  /// Note: The behavior of this method was changed in version 2.0 to fit the most commonly seen real-world
  /// usage pattern.  Previous versions returned the later instance of ambiguous values, and returned the start of
  /// the zone interval after the gap for skipped value.  The previous functionality can still be used if desired,
  /// by using [InZone] and passing a resolver that combines the
  /// [Resolvers.ReturnLater] and [Resolvers.ReturnStartOfIntervalAfter] resolvers.
  ///
  /// [zone]: The time zone in which to map this local date/time.
  ///
  /// Returns the result of mapping this local date/time in the given time zone.
  ZonedDateTime InZoneLeniently(DateTimeZone zone) {
    // Dart: null safety checks zone.
    return zone.AtLeniently(this);
  }

  /// Resolves this local date and time into a [ZonedDateTime] in the given time zone, following
  /// the given [ZoneLocalMappingResolver] to handle ambiguity and skipped times.
  ///
  /// See [InZoneStrictly] and [InZoneLeniently] for alternative ways to map a local time
  /// to a specific instant.
  /// This is a convenience method for calling [DateTimeZone.ResolveLocal].
  ///
  /// [zone]: The time zone to map this local date and time into
  /// [resolver]: The resolver to apply to the mapping.
  ///
  /// Returns the result of resolving the mapping.
  ZonedDateTime InZone(DateTimeZone zone, ZoneLocalMappingResolver resolver) {
    // Dart: null safety checks zone and resolver.
    return zone.ResolveLocal(this, resolver);
  }

  /// Deconstruct this [LocalDateTime] into its components: the date portion and the time portion of the value.
  ///
  /// `final (date, time) = localDateTime.Deconstruct;`
  // noda_dart: C#'s Deconstruct(out LocalDate date, out LocalTime time).
  (LocalDate date, LocalTime time) get Deconstruct => (Date, TimeOfDay);

  /// Returns the later date/time of the given two.
  ///
  /// [x]: The first date/time to compare.
  /// [y]: The second date/time to compare.
  ///
  /// Throws [ArgumentError] if the two date/times have different calendar systems.
  ///
  /// Returns the later date/time of [x] or [y].
  static LocalDateTime Max(LocalDateTime x, LocalDateTime y) {
    Preconditions.CheckArgument(x.Calendar == y.Calendar, 'y', 'Only values with the same calendar system can be compared');
    return x > y ? x : y;
  }

  /// Returns the earlier date/time of the given two.
  ///
  /// [x]: The first date/time to compare.
  /// [y]: The second date/time to compare.
  ///
  /// Throws [ArgumentError] if the two date/times have different calendar systems.
  ///
  /// Returns the earlier date/time of [x] or [y].
  static LocalDateTime Min(LocalDateTime x, LocalDateTime y) {
    Preconditions.CheckArgument(x.Calendar == y.Calendar, 'y', 'Only values with the same calendar system can be compared');
    return x < y ? x : y;
  }

  // #region Formatting
  /// Returns a [String] that represents this instance.
  ///
  /// Returns the value of the current instance in the default format pattern ("G"), using the invariant culture
  /// (NodaTime uses the current thread's culture; Dart has none).
  @override
  String toString() =>
      LocalDateTimePattern.BclSupport.Format(this, null, NodaCultureInfo.InvariantCulture);

  /// Formats the value of the current instance using the specified pattern.
  ///
  /// Returns a [String] containing the value of the current instance in the specified format.
  ///
  /// [patternText]: The [String] specifying the pattern to use,
  /// or null to use the default format pattern ("G").
  /// [formatProvider]: The [IFormatProvider] to use when formatting the value,
  /// or null to use the invariant culture.
  // noda_dart: C#'s ToString(string? patternText, IFormatProvider? formatProvider).
  String ToStringPattern(String? patternText, [IFormatProvider? formatProvider]) =>
      LocalDateTimePattern.BclSupport.Format(this, patternText, formatProvider);
  // #endregion Formatting

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable.GetSchema, ReadXml, WriteXml (XML serialization)
  // #endregion

  // #region JSON (noda_dart)
  /// Formats this value with [LocalDateTimePattern.ExtendedIso], as NodaTime.Serialization.SystemTextJson does.
  String toJson() => LocalDateTimePattern.ExtendedIso.Format(this);

  /// Parses a value written by [toJson], in [calendar] (default ISO).
  ///
  /// Throws [UnparsableValueException] if the value can't be parsed.
  factory LocalDateTime.fromJson(String json, [CalendarSystem? calendar]) =>
      (calendar == null ? LocalDateTimePattern.ExtendedIso : LocalDateTimePattern.ExtendedIso.WithCalendar(calendar))
          .Parse(json)
          .Value;
  // #endregion
}
