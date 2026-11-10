// Ported from NodaTime 6e024dde: src/NodaTime/Period.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'CalendarSystem.dart';
import 'Duration.dart';
import 'Fields/DatePeriodFields.dart';
import 'Fields/IDatePeriodField.dart';
import 'Fields/TimePeriodField.dart';
import 'LocalDate.dart';
import 'LocalDateTime.dart';
import 'LocalTime.dart';
import 'NodaConstants.generated.dart';
import 'PeriodBuilder.dart';
import 'PeriodUnits.generated.dart';
import 'Text/PeriodPattern.dart';
import 'Utility/Checked.dart';
import 'Utility/Comparers.dart';
import 'Utility/HashCodeHelper.dart';
import 'Utility/Int64.dart';
import 'Utility/Preconditions.dart';
import 'YearMonth.dart';

/// Represents a period of time expressed in human chronological terms: hours, days,
/// weeks, months and so on.
///
/// A [Period] contains a set of properties such as [Years], [Months], and so on
/// that return the number of each unit contained within this period. Note that these properties are not normalized in
/// any way by default, and so a [Period] may contain values such as "2 hours and 90 minutes". The
/// [Normalize] method will convert equivalent periods into a standard representation.
///
/// Periods can contain negative units as well as positive units ("+2 hours, -43 minutes, +10 seconds"), but do not
/// differentiate between properties that are zero and those that are absent (i.e. a period created as "10 years"
/// and one created as "10 years, zero months" are equal periods; the [Months] property returns zero in
/// both cases).
///
/// [Period] equality is implemented by comparing each property's values individually, without any normalization.
/// (For example, a period of "24 hours" is not considered equal to a period of "1 day".) The static
/// [NormalizingEqualityComparer] comparer provides an equality comparer which performs normalization before comparisons.
///
/// There is no natural ordering for periods, but [CreateComparer] can be used to create a
/// comparer which orders periods according to a reference date, by adding each period to that date and comparing the results.
///
/// Periods operate on calendar-related types such as
/// [LocalDateTime] whereas [Duration] operates on instants
/// on the time line. (Note that although `ZonedDateTime` includes both concepts, it only supports
/// duration-based arithmetic.)
///
/// The complexity of each method in this type is hard to document precisely, and often depends on the calendar system
/// involved in performing the actual calculations. Operations do not depend on the magnitude of the units in the period,
/// other than for optimizations for values of zero or occasionally for particularly small values. For example,
/// adding 10,000 days to a date does not require greater algorithmic complexity than adding 1,000 days to the same date.
///
/// This type is immutable reference type. See the thread safety section of the user guide for more information.
final class Period {
  // General implementation note: operations such as normalization work out the total number of nanoseconds as an Int64
  // value. This can handle +/- 106,751 days, or 292 years. We could move to using BigInteger if we feel that's required,
  // but it's unlikely to be an issue. Ideally, we'd switch to use BigInteger after detecting that it could be a problem,
  // but without the hit of having to catch the exception...

  /// A period containing only zero-valued properties.
  static final Period Zero = Period._NewYearsMonthsWeeksDays(0, 0, 0, 0);

  /// A period containing the maximum value for all properties.
  ///
  /// (On dart2js, the long-valued properties are the nearest double to `long.MaxValue`, 2^63.)
  static final Period MaxValue = Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(
      Int64.Int32MaxValue, Int64.Int32MaxValue, Int64.Int32MaxValue, Int64.Int32MaxValue,
      Int64.MaxValue, Int64.MaxValue, Int64.MaxValue, Int64.MaxValue, Int64.MaxValue, Int64.MaxValue);

  /// A period containing the minimum value for all properties.
  static final Period MinValue = Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(
      Int64.Int32MinValue, Int64.Int32MinValue, Int64.Int32MinValue, Int64.Int32MinValue,
      Int64.MinValue, Int64.MinValue, Int64.MinValue, Int64.MinValue, Int64.MinValue, Int64.MinValue);

  /// Gets the additive identity.
  static Period get AdditiveIdentity => Zero;

  /// Returns an equality comparer which compares periods by first normalizing them - so 24 hours is deemed equal to 1 day, and so on.
  /// Note that as per the [Normalize] method, years and months are unchanged by normalization - so 12 months does not
  /// equal 1 year.
  static IEqualityComparer<Period?> get NormalizingEqualityComparer => _PeriodNormalizingPeriodEqualityComparer.Instance;

  // The fields that make up this period.

  /// Gets the number of nanoseconds within this period.
  ///
  /// This property returns zero both when the property has been explicitly set to zero and when the period does not
  /// contain this property.
  final int Nanoseconds;

  /// Gets the number of ticks within this period.
  ///
  /// This property returns zero both when the property has been explicitly set to zero and when the period does not
  /// contain this property.
  final int Ticks;

  /// Gets the number of milliseconds within this period.
  ///
  /// This property returns zero both when the property has been explicitly set to zero and when the period does not
  /// contain this property.
  final int Milliseconds;

  /// Gets the number of seconds within this period.
  ///
  /// This property returns zero both when the property has been explicitly set to zero and when the period does not
  /// contain this property.
  final int Seconds;

  /// Gets the number of minutes within this period.
  ///
  /// This property returns zero both when the property has been explicitly set to zero and when the period does not
  /// contain this property.
  final int Minutes;

  /// Gets the number of hours within this period.
  ///
  /// This property returns zero both when the property has been explicitly set to zero and when the period does not
  /// contain this property.
  final int Hours;

  /// Gets the number of days within this period.
  ///
  /// This property returns zero both when the property has been explicitly set to zero and when the period does not
  /// contain this property.
  final int Days;

  /// Gets the number of weeks within this period.
  ///
  /// This property returns zero both when the property has been explicitly set to zero and when the period does not
  /// contain this property.
  final int Weeks;

  /// Gets the number of months within this period.
  ///
  /// This property returns zero both when the property has been explicitly set to zero and when the period does not
  /// contain this property.
  final int Months;

  /// Gets the number of years within this period.
  ///
  /// This property returns zero both when the property has been explicitly set to zero and when the period does not
  /// contain this property.
  final int Years;

  /// Creates a period with the given date values.
  Period._NewYearsMonthsWeeksDays(int years, int months, int weeks, int days)
      : Years = years,
        Months = months,
        Weeks = weeks,
        Days = days,
        // noda_dart: C#'s default values of the other fields.
        Hours = 0,
        Minutes = 0,
        Seconds = 0,
        Milliseconds = 0,
        Ticks = 0,
        Nanoseconds = 0;

  /// Creates a period with the given time values.
  Period._NewHoursMinutesSecondsMillisecondsTicksNanoseconds(
      int hours, int minutes, int seconds, int milliseconds, int ticks, int nanoseconds)
      : Hours = hours,
        Minutes = minutes,
        Seconds = seconds,
        Milliseconds = milliseconds,
        Ticks = ticks,
        Nanoseconds = nanoseconds,
        // noda_dart: C#'s default values of the other fields.
        Years = 0,
        Months = 0,
        Weeks = 0,
        Days = 0;

  /// Creates a new period from the given values.
  @internal
  Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(int years, int months, int weeks,
      int days, int hours, int minutes, int seconds, int milliseconds, int ticks, int nanoseconds)
      : Years = years,
        Months = months,
        Weeks = weeks,
        Days = days,
        Hours = hours,
        Minutes = minutes,
        Seconds = seconds,
        Milliseconds = milliseconds,
        Ticks = ticks,
        Nanoseconds = nanoseconds;

  /// Creates a period representing the specified number of years.
  ///
  /// [years]: The number of years in the new period
  ///
  /// Returns a period consisting of the given number of years.
  static Period FromYears(int years) => Period._NewYearsMonthsWeeksDays(years, 0, 0, 0);

  /// Creates a period representing the specified number of months.
  ///
  /// [months]: The number of months in the new period
  ///
  /// Returns a period consisting of the given number of months.
  static Period FromMonths(int months) => Period._NewYearsMonthsWeeksDays(0, months, 0, 0);

  /// Creates a period representing the specified number of weeks.
  ///
  /// [weeks]: The number of weeks in the new period
  ///
  /// Returns a period consisting of the given number of weeks.
  static Period FromWeeks(int weeks) => Period._NewYearsMonthsWeeksDays(0, 0, weeks, 0);

  /// Creates a period representing the specified number of days.
  ///
  /// [days]: The number of days in the new period
  ///
  /// Returns a period consisting of the given number of days.
  static Period FromDays(int days) => Period._NewYearsMonthsWeeksDays(0, 0, 0, days);

  /// Creates a period representing the specified number of hours.
  ///
  /// [hours]: The number of hours in the new period
  ///
  /// Returns a period consisting of the given number of hours.
  static Period FromHours(int hours) => Period._NewHoursMinutesSecondsMillisecondsTicksNanoseconds(hours, 0, 0, 0, 0, 0);

  /// Creates a period representing the specified number of minutes.
  ///
  /// [minutes]: The number of minutes in the new period
  ///
  /// Returns a period consisting of the given number of minutes.
  static Period FromMinutes(int minutes) =>
      Period._NewHoursMinutesSecondsMillisecondsTicksNanoseconds(0, minutes, 0, 0, 0, 0);

  /// Creates a period representing the specified number of seconds.
  ///
  /// [seconds]: The number of seconds in the new period
  ///
  /// Returns a period consisting of the given number of seconds.
  static Period FromSeconds(int seconds) =>
      Period._NewHoursMinutesSecondsMillisecondsTicksNanoseconds(0, 0, seconds, 0, 0, 0);

  /// Creates a period representing the specified number of milliseconds.
  ///
  /// [milliseconds]: The number of milliseconds in the new period
  ///
  /// Returns a period consisting of the given number of milliseconds.
  static Period FromMilliseconds(int milliseconds) =>
      Period._NewHoursMinutesSecondsMillisecondsTicksNanoseconds(0, 0, 0, milliseconds, 0, 0);

  /// Creates a period representing the specified number of ticks.
  ///
  /// [ticks]: The number of ticks in the new period
  ///
  /// Returns a period consisting of the given number of ticks.
  static Period FromTicks(int ticks) => Period._NewHoursMinutesSecondsMillisecondsTicksNanoseconds(0, 0, 0, 0, ticks, 0);

  /// Creates a period representing the specified number of nanoseconds.
  ///
  /// [nanoseconds]: The number of nanoseconds in the new period
  ///
  /// Returns a period consisting of the given number of nanoseconds.
  static Period FromNanoseconds(int nanoseconds) =>
      Period._NewHoursMinutesSecondsMillisecondsTicksNanoseconds(0, 0, 0, 0, 0, nanoseconds);

  /// Adds two periods together, by simply adding the values for each property.
  ///
  /// [right]: The second period to add (this period is the first)
  ///
  /// Returns the sum of the two periods. The units of the result will be the union of those in both
  /// periods.
  Period operator +(Period right) {
    // noda_dart: C#'s static operator; left is this.
    final Period left = this;
    // Dart: null safety checks left and right.
    return Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(
        Checked.AddInt32(left.Years, right.Years),
        Checked.AddInt32(left.Months, right.Months),
        Checked.AddInt32(left.Weeks, right.Weeks),
        Checked.AddInt32(left.Days, right.Days),
        Checked.Add(left.Hours, right.Hours),
        Checked.Add(left.Minutes, right.Minutes),
        Checked.Add(left.Seconds, right.Seconds),
        Checked.Add(left.Milliseconds, right.Milliseconds),
        Checked.Add(left.Ticks, right.Ticks),
        Checked.Add(left.Nanoseconds, right.Nanoseconds));
  }

  /// Adds two periods together, by simply adding the values for each property.
  ///
  /// [left]: The first period to add
  /// [right]: The second period to add
  ///
  /// Returns the sum of the two periods. The units of the result will be the union of those in both
  /// periods.
  static Period Add(Period left, Period right) => left + right;

  /// Creates an [IComparer] for periods, using the given "base" local date/time.
  ///
  /// Certain periods can't naturally be compared without more context - how "one month" compares to
  /// "30 days" depends on where you start. In order to compare two periods, the returned comparer
  /// effectively adds both periods to the "base" specified by [baseDateTime] and compares
  /// the results. In some cases this arithmetic isn't actually required - when two periods can be
  /// converted to durations, the comparer uses that conversion for efficiency.
  ///
  /// [baseDateTime]: The base local date/time to use for comparisons.
  ///
  /// Returns the new comparer.
  static IComparer<Period?> CreateComparer(LocalDateTime baseDateTime) => _PeriodPeriodComparer.New(baseDateTime);

  /// Subtracts one period from another, by simply subtracting each property value.
  ///
  /// [subtrahend]: The period to subtract from this one (the minuend)
  ///
  /// Returns the result of subtracting all the values in the second operand from the values in the first. The
  /// units of the result will be the union of both periods, even if the subtraction caused some properties to
  /// become zero (so "2 weeks, 1 days" minus "2 weeks" is "zero weeks, 1 days", not "1 days").
  Period operator -(Period subtrahend) {
    // noda_dart: C#'s static operator; minuend is this.
    final Period minuend = this;
    // Dart: null safety checks minuend and subtrahend.
    return Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(
        Checked.SubtractInt32(minuend.Years, subtrahend.Years),
        Checked.SubtractInt32(minuend.Months, subtrahend.Months),
        Checked.SubtractInt32(minuend.Weeks, subtrahend.Weeks),
        Checked.SubtractInt32(minuend.Days, subtrahend.Days),
        Checked.Subtract(minuend.Hours, subtrahend.Hours),
        Checked.Subtract(minuend.Minutes, subtrahend.Minutes),
        Checked.Subtract(minuend.Seconds, subtrahend.Seconds),
        Checked.Subtract(minuend.Milliseconds, subtrahend.Milliseconds),
        Checked.Subtract(minuend.Ticks, subtrahend.Ticks),
        Checked.Subtract(minuend.Nanoseconds, subtrahend.Nanoseconds));
  }

  /// Implements the unary negation operator.
  ///
  /// Returns the negative value of this period
  Period operator -() => Zero - this;

  /// Subtracts one period from another, by simply subtracting each property value.
  ///
  /// [minuend]: The period to subtract the second operand from
  /// [subtrahend]: The period to subtract the first operand from
  ///
  /// Returns the result of subtracting all the values in the second operand from the values in the first. The
  /// units of the result will be the union of both periods, even if the subtraction caused some properties to
  /// become zero (so "2 weeks, 1 days" minus "2 weeks" is "zero weeks, 1 days", not "1 days").
  static Period Subtract(Period minuend, Period subtrahend) => minuend - subtrahend;

  /// Returns the number of days between two [LocalDate] values.
  ///
  /// [start]: Start date
  /// [end]: End date
  ///
  /// Throws [ArgumentError] if [start] and [end] use different calendars.
  ///
  /// Returns the number of days between the given dates.
  static int DaysBetween(LocalDate start, LocalDate end) {
    Preconditions.CheckArgument(
        start.Calendar == end.Calendar,
        'end',
        'start and end must use the same calendar system');

    return InternalDaysBetween(start, end);
  }

  /// Returns the number of nanoseconds between two [LocalTime] values.
  ///
  /// If [end] is before [start], the returned value will be negative.
  ///
  /// [start]: Start time
  /// [end]: End time
  ///
  /// Returns the number of nanoseconds between the given times.
  static int NanosecondsBetween(LocalTime start, LocalTime end) =>
      end.NanosecondOfDay - start.NanosecondOfDay;

  /// Returns the period between a start and an end date/time, using only the given units.
  ///
  /// If [end] is before [start], each property in the returned period
  /// will be negative. If the given set of units cannot exactly reach the end point (e.g. finding
  /// the difference between 1am and 3:15am in hours) the result will be such that adding it to [start]
  /// will give a value between [start] and [end]. In other words,
  /// any rounding is "towards start"; this is true whether the resulting period is negative or positive.
  ///
  /// Without [units], returns the exact difference between two date/times, using all units
  /// ([PeriodUnits.DateAndTime]).
  ///
  /// [start]: Start date/time
  /// [end]: End date/time
  /// [units]: Units to use for calculations
  ///
  /// Throws [ArgumentError] if [units] is empty or contained unknown values.
  /// Throws [ArgumentError] if [start] and [end] use different calendars.
  ///
  /// Returns the period between the given date/times, using the given units.
  static Period Between(LocalDateTime start, LocalDateTime end, [PeriodUnits units = PeriodUnits.DateAndTime]) {
    Preconditions.CheckArgument(units.value != 0, 'units', 'Units must not be empty');
    Preconditions.CheckArgument((units & ~PeriodUnits.AllUnits).value == 0, 'units', 'Units contains an unknown value: {0}', units.Name);
    CalendarSystem calendar = start.Calendar;
    Preconditions.CheckArgument(calendar == end.Calendar, 'end', 'start and end must use the same calendar system');

    if (start == end) {
      return Zero;
    }

    // Adjust for situations like "days between 5th January 10am and 7th January 5am" which should be one
    // day, because if we actually reach 7th January with date fields, we've overshot.
    // The date adjustment will always be valid, because it's just moving it towards start.
    // We need this for all date-based period fields. We could potentially optimize by not doing this
    // in cases where we've only got time fields...
    LocalDate endDate = end.Date;
    if (start < end) {
      if (start.TimeOfDay > end.TimeOfDay) {
        endDate = endDate.PlusDays(-1);
      }
    } else if (start.TimeOfDay < end.TimeOfDay) // Implicit start > end, as start == end is covered earlier.
    {
      endDate = endDate.PlusDays(1);
    }

    // Optimization for single field
    switch (units) {
      case PeriodUnits.Years: return FromYears(DatePeriodFields.YearsField.UnitsBetween(start.Date, endDate));
      case PeriodUnits.Months: return FromMonths(DatePeriodFields.MonthsField.UnitsBetween(start.Date, endDate));
      case PeriodUnits.Weeks: return FromWeeks(DatePeriodFields.WeeksField.UnitsBetween(start.Date, endDate));
      case PeriodUnits.Days: return FromDays(InternalDaysBetween(start.Date, endDate));
      case PeriodUnits.Hours: return FromHours(TimePeriodField.Hours.UnitsBetween(start, end));
      case PeriodUnits.Minutes: return FromMinutes(TimePeriodField.Minutes.UnitsBetween(start, end));
      case PeriodUnits.Seconds: return FromSeconds(TimePeriodField.Seconds.UnitsBetween(start, end));
      case PeriodUnits.Milliseconds: return FromMilliseconds(TimePeriodField.Milliseconds.UnitsBetween(start, end));
      case PeriodUnits.Ticks: return FromTicks(TimePeriodField.Ticks.UnitsBetween(start, end));
      case PeriodUnits.Nanoseconds: return FromNanoseconds(TimePeriodField.Nanoseconds.UnitsBetween(start, end));
    }

    // Multiple fields
    LocalDateTime remaining = start;
    int years = 0, months = 0, weeks = 0, days = 0;
    if ((units & PeriodUnits.AllDateUnits).value != 0) {
      LocalDate remainingDate;
      (remainingDate, years, months, weeks, days) = _DateComponentsBetween(
          start.Date, endDate, units);
      remaining = LocalDateTime.NewDateTime(remainingDate, start.TimeOfDay);
    }
    if ((units & PeriodUnits.AllTimeUnits).value == 0) {
      return Period._NewYearsMonthsWeeksDays(years, months, weeks, days);
    }

    // The remainder of the computation is with fixed-length units, so we can do it all with
    // Duration instead of Local* values. We don't know for sure that this is small though - we *could*
    // be trying to find the difference between 9998 BC and 9999 CE in nanoseconds...
    // Where we can optimize, do everything with long arithmetic (as we do for Between(LocalTime, LocalTime)).
    // Otherwise (rare case), use duration arithmetic.
    int hours, minutes, seconds, milliseconds, ticks, nanoseconds;
    var duration = end.ToLocalInstant().TimeSinceLocalEpoch - remaining.ToLocalInstant().TimeSinceLocalEpoch;

    // noda_dart: C#'s local function, declared at the end of the method; Dart needs it before its first use.
    int UnitsBetween(PeriodUnits mask, TimePeriodField timeField) {
      if ((mask & units).value == 0) {
        return 0;
      }
      int value = timeField.GetUnitsInDuration(duration);
      duration -= timeField.ToDuration(value);
      return value;
    }

    if (duration.IsInt64Representable) {
      (hours, minutes, seconds, milliseconds, ticks, nanoseconds) =
          _TimeComponentsBetween(duration.ToInt64Nanoseconds(), units);
    } else {
      hours = UnitsBetween(PeriodUnits.Hours, TimePeriodField.Hours);
      minutes = UnitsBetween(PeriodUnits.Minutes, TimePeriodField.Minutes);
      seconds = UnitsBetween(PeriodUnits.Seconds, TimePeriodField.Seconds);
      milliseconds = UnitsBetween(PeriodUnits.Milliseconds, TimePeriodField.Milliseconds);
      ticks = UnitsBetween(PeriodUnits.Ticks, TimePeriodField.Ticks);
      nanoseconds = UnitsBetween(PeriodUnits.Nanoseconds, TimePeriodField.Nanoseconds);
    }
    return Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(
        years, months, weeks, days, hours, minutes, seconds, milliseconds, ticks, nanoseconds);
  }

  /// Common code to perform the date parts of the Between methods.
  ///
  /// [start]: Start date
  /// [end]: End date
  /// [units]: Units to compute
  ///
  /// Returns the resulting date after adding the result components to [start] (to
  /// allow further computations to be made), then (C#'s out parameters) the year, month, week and day components
  /// of the result.
  static (LocalDate, int years, int months, int weeks, int days) _DateComponentsBetween(
      LocalDate start, LocalDate end, PeriodUnits units) {
    LocalDate result = start;

    // noda_dart: C#'s startDate is a ref parameter, always passed result; the local function updates result directly.
    int UnitsBetween(PeriodUnits maskedUnits, LocalDate endDate, IDatePeriodField dateField) {
      if (maskedUnits.value == 0) {
        return 0;
      }
      int value = dateField.UnitsBetween(result, endDate);
      result = dateField.Add(result, value);
      return value;
    }

    final years = UnitsBetween(units & PeriodUnits.Years, end, DatePeriodFields.YearsField);
    final months = UnitsBetween(units & PeriodUnits.Months, end, DatePeriodFields.MonthsField);
    final weeks = UnitsBetween(units & PeriodUnits.Weeks, end, DatePeriodFields.WeeksField);
    final days = UnitsBetween(units & PeriodUnits.Days, end, DatePeriodFields.DaysField);

    return (result, years, months, weeks, days);
  }

  /// Common code to perform the time parts of the Between methods for long-representable nanos.
  ///
  /// [totalNanoseconds]: Number of nanoseconds to compute the units of
  /// [units]: Units to compute
  ///
  /// Returns (C#'s out parameters) the hours, minutes, seconds, milliseconds, ticks and nanoseconds components of
  /// the result.
  static (int hours, int minutes, int seconds, int milliseconds, int ticks, int nanoseconds) _TimeComponentsBetween(
      int totalNanoseconds, PeriodUnits units) {
    int UnitsBetween(PeriodUnits mask, int nanosecondsPerUnit) {
      if ((mask & units).value == 0) {
        return 0;
      }
      // noda_dart: Math.DivRem(totalNanoseconds, nanosecondsPerUnit, out totalNanoseconds).
      final quotient = totalNanoseconds ~/ nanosecondsPerUnit;
      totalNanoseconds = totalNanoseconds.remainder(nanosecondsPerUnit);
      return quotient;
    }

    final hours = UnitsBetween(PeriodUnits.Hours, NanosecondsPerHour);
    final minutes = UnitsBetween(PeriodUnits.Minutes, NanosecondsPerMinute);
    final seconds = UnitsBetween(PeriodUnits.Seconds, NanosecondsPerSecond);
    final milliseconds = UnitsBetween(PeriodUnits.Milliseconds, NanosecondsPerMillisecond);
    final ticks = UnitsBetween(PeriodUnits.Ticks, NanosecondsPerTick);
    final nanoseconds = UnitsBetween(PeriodUnits.Nanoseconds, 1);
    return (hours, minutes, seconds, milliseconds, ticks, nanoseconds);
  }

  /// Returns the period between a start and an end date, using only the given units.
  ///
  /// If [end] is before [start], each property in the returned period
  /// will be negative. If the given set of units cannot exactly reach the end point (e.g. finding
  /// the difference between 12th February and 15th March in months) the result will be such that adding it to [start]
  /// will give a value between [start] and [end]. In other words,
  /// any rounding is "towards start"; this is true whether the resulting period is negative or positive.
  ///
  /// Without [units], returns the exact difference between two dates, using year, month and day units
  /// ([PeriodUnits.YearMonthDay]). The calendar systems of the two dates must be the same; an exception will be thrown
  /// otherwise.
  ///
  /// (NodaTime's `Between(LocalDate, LocalDate, PeriodUnits)` and `Between(LocalDate, LocalDate)`.)
  ///
  /// [start]: Start date
  /// [end]: End date
  /// [units]: Units to use for calculations
  ///
  /// Throws [ArgumentError] if [units] contains time units, is empty or contains unknown values.
  /// Throws [ArgumentError] if [start] and [end] use different calendars.
  ///
  /// Returns the period between the given dates, using the given units.
  static Period BetweenLocalDate(LocalDate start, LocalDate end, [PeriodUnits units = PeriodUnits.YearMonthDay]) {
    Preconditions.CheckArgument((units & PeriodUnits.AllTimeUnits).value == 0, 'units', 'Units contains time units: {0}', units.Name);
    Preconditions.CheckArgument(units.value != 0, 'units', 'Units must not be empty');
    Preconditions.CheckArgument((units & ~PeriodUnits.AllUnits).value == 0, 'units', 'Units contains an unknown value: {0}', units.Name);
    CalendarSystem calendar = start.Calendar;
    Preconditions.CheckArgument(calendar == end.Calendar, 'end', 'start and end must use the same calendar system');

    if (start == end) {
      return Zero;
    }

    // Optimization for single field
    switch (units) {
      case PeriodUnits.Years: return FromYears(DatePeriodFields.YearsField.UnitsBetween(start, end));
      case PeriodUnits.Months: return FromMonths(DatePeriodFields.MonthsField.UnitsBetween(start, end));
      case PeriodUnits.Weeks: return FromWeeks(DatePeriodFields.WeeksField.UnitsBetween(start, end));
      case PeriodUnits.Days: return FromDays(InternalDaysBetween(start, end));
    }

    // Multiple fields
    final (_, years, months, weeks, days) = _DateComponentsBetween(start, end, units);
    return Period._NewYearsMonthsWeeksDays(years, months, weeks, days);
  }

  /// Returns the period between a start and an end time, using only the given units.
  ///
  /// If [end] is before [start], each property in the returned period
  /// will be negative. If the given set of units cannot exactly reach the end point (e.g. finding
  /// the difference between 3am and 4.30am in hours) the result will be such that adding it to [start]
  /// will give a value between [start] and [end]. In other words,
  /// any rounding is "towards start"; this is true whether the resulting period is negative or positive.
  ///
  /// Without [units], returns the exact difference between two times, using the time period units
  /// ([PeriodUnits.AllTimeUnits]).
  ///
  /// (NodaTime's `Between(LocalTime, LocalTime, PeriodUnits)` and `Between(LocalTime, LocalTime)`.)
  ///
  /// [start]: Start time
  /// [end]: End time
  /// [units]: Units to use for calculations
  ///
  /// Throws [ArgumentError] if [units] contains date units, is empty or contains unknown values.
  /// Throws [ArgumentError] if [start] and [end] use different calendars.
  ///
  /// Returns the period between the given times, using the given units.
  static Period BetweenLocalTime(LocalTime start, LocalTime end, [PeriodUnits units = PeriodUnits.AllTimeUnits]) {
    Preconditions.CheckArgument((units & PeriodUnits.AllDateUnits).value == 0, 'units', 'Units contains date units: {0}', units.Name);
    Preconditions.CheckArgument(units.value != 0, 'units', 'Units must not be empty');
    Preconditions.CheckArgument((units & ~PeriodUnits.AllUnits).value == 0, 'units', 'Units contains an unknown value: {0}', units.Name);

    // We know that the difference is in the range of +/- 1 day, which is a relatively small
    // number of nanoseconds. All the operations can be done with simple long division/remainder ops,
    // so we don't need to delegate to TimePeriodField.

    int remaining = NanosecondsBetween(start, end);

    // Optimization for a single unit
    switch (units) {
      case PeriodUnits.Hours: return FromHours(remaining ~/ NanosecondsPerHour);
      case PeriodUnits.Minutes: return FromMinutes(remaining ~/ NanosecondsPerMinute);
      case PeriodUnits.Seconds: return FromSeconds(remaining ~/ NanosecondsPerSecond);
      case PeriodUnits.Milliseconds: return FromMilliseconds(remaining ~/ NanosecondsPerMillisecond);
      case PeriodUnits.Ticks: return FromTicks(remaining ~/ NanosecondsPerTick);
      case PeriodUnits.Nanoseconds: return FromNanoseconds(remaining);
    }

    final (hours, minutes, seconds, milliseconds, ticks, nanoseconds) = _TimeComponentsBetween(remaining, units);
    return Period._NewHoursMinutesSecondsMillisecondsTicksNanoseconds(hours, minutes, seconds, milliseconds, ticks, nanoseconds);
  }

  /// Returns the number of days between two dates. This allows optimizations in DateInterval,
  /// and for date calculations which just use days - we don't need state or a virtual method invocation.
  @internal
  static int InternalDaysBetween(LocalDate start, LocalDate end) {
    // We already assume the calendars are the same.
    if (start.YearMonthDay == end.YearMonthDay) {
      return 0;
    }
    // Note: I've experimented with checking for the dates being in the same year and optimizing that.
    // It helps a little if they're in the same month, but just that test has a cost for other situations.
    // Being able to find the day of year if they're in the same year but different months doesn't help,
    // somewhat surprisingly.
    int startDays = start.DaysSinceEpoch;
    int endDays = end.DaysSinceEpoch;
    return endDays - startDays;
  }

  /// Returns the period between a start and an end [YearMonth], using only the given units.
  ///
  /// If [end] is before [start], each property in the returned period
  /// will be negative. If the given set of units cannot exactly reach the end point (e.g. finding
  /// the difference between February 2010 and March 2012 in years) the result will be such that adding it to [start]
  /// will give a value between [start] and [end]. In other words,
  /// any rounding is "towards start"; this is true whether the resulting period is negative or positive.
  ///
  /// Without [units] (or with null), returns the exact difference between two [YearMonth] values, using year and month
  /// units. The calendar systems of the two values must be the same; an exception will be thrown otherwise.
  ///
  /// (NodaTime's `Between(YearMonth, YearMonth, PeriodUnits)` and `Between(YearMonth, YearMonth)`.)
  ///
  /// [start]: Start year and month
  /// [end]: End year and month
  /// [units]: Units to use for calculations
  ///
  /// Throws [ArgumentError] if [units] is empty or contains anything other than than PeriodUnits.Years
  /// and/or PeriodUnits.Months.
  /// Throws [ArgumentError] if [start] and [end] use different calendars.
  ///
  /// Returns the period between the given YearMonths, using the given units.
  static Period BetweenYearMonth(YearMonth start, YearMonth end, [PeriodUnits? units]) {
    // noda_dart: the default of the C# overload without units (Dart's defaults must be constant expressions).
    units ??= PeriodUnits.Years | PeriodUnits.Months;
    // noda_dart: PeriodUnits.AllUnits ^ PeriodUnits.Years ^ PeriodUnits.Months, on the underlying values.
    Preconditions.CheckArgument(
        (units & PeriodUnits(PeriodUnits.AllUnits.value ^ PeriodUnits.Years.value ^ PeriodUnits.Months.value)).value == 0,
        'units', 'Units can only contain year and month units: {0}', units.Name);
    Preconditions.CheckArgument(units.value != 0, 'units', 'Units must not be empty');
    Preconditions.CheckArgument((units & ~PeriodUnits.AllUnits).value == 0, 'units', 'Units contains an unknown value: {0}', units.Name);
    CalendarSystem calendar = start.Calendar;
    Preconditions.CheckArgument(calendar == end.Calendar, 'end', 'start and end must use the same calendar system');

    if (start == end) {
      return Zero;
    }

    LocalDate startDate = start.StartDate;
    LocalDate endDate = end.StartDate;

    // Optimization for single field
    switch (units) {
      case PeriodUnits.Years: return FromYears(DatePeriodFields.YearsField.UnitsBetween(startDate, endDate));
      case PeriodUnits.Months: return FromMonths(DatePeriodFields.MonthsField.UnitsBetween(startDate, endDate));
    }

    // Multiple fields
    final (_, years, months, _, _) = _DateComponentsBetween(startDate, endDate, units);
    return Period._NewYearsMonthsWeeksDays(years, months, 0, 0);
  }

  /// Returns whether or not this period contains any non-zero-valued time-based properties (hours or lower).
  bool get HasTimeComponent => Hours != 0 || Minutes != 0 || Seconds != 0 || Milliseconds != 0 || Ticks != 0 || Nanoseconds != 0;

  /// Returns whether or not this period contains any non-zero date-based properties (days or higher).
  bool get HasDateComponent => Years != 0 || Months != 0 || Weeks != 0 || Days != 0;

  /// For periods that do not contain a non-zero number of years or months, returns a duration for this period
  /// assuming a standard 7-day week, 24-hour day, 60-minute hour etc.
  ///
  /// Throws [StateError] if the month or year property in the period is non-zero.
  /// Throws [OverflowException] if the period doesn't have years or months, but the calculation
  /// overflows the bounds of [Duration]. In some cases this may occur even though the theoretical
  /// result would be valid due to balancing positive and negative values, but for simplicity there is
  /// no attempt to work around this - in realistic periods, it shouldn't be a problem.
  ///
  /// Returns the duration of the period.
  Duration ToDuration() {
    if (Months != 0 || Years != 0) {
      throw StateError('Cannot construct duration of period with non-zero months or years.');
    }
    return Duration.FromNanoseconds(_TotalNanoseconds);
  }

  /// Gets the total number of nanoseconds duration for the 'standard' properties (all bar years and months).
  int get _TotalNanoseconds {
    // noda_dart: C#'s checked long expression, term by term.
    int total = Nanoseconds;
    total = Checked.Add(total, Checked.Multiply(Ticks, NanosecondsPerTick));
    total = Checked.Add(total, Checked.Multiply(Milliseconds, NanosecondsPerMillisecond));
    total = Checked.Add(total, Checked.Multiply(Seconds, NanosecondsPerSecond));
    total = Checked.Add(total, Checked.Multiply(Minutes, NanosecondsPerMinute));
    total = Checked.Add(total, Checked.Multiply(Hours, NanosecondsPerHour));
    total = Checked.Add(total, Checked.Multiply(Days, NanosecondsPerDay));
    total = Checked.Add(total, Checked.Multiply(Weeks, NanosecondsPerWeek));
    return total;
  }

  /// Creates a [PeriodBuilder] from this instance. The new builder
  /// is populated with the values from this period, but is then detached from it:
  /// changes made to the builder are not reflected in this period.
  ///
  /// Returns a builder with the same values and units as this period.
  PeriodBuilder ToBuilder() => PeriodBuilder(this);

  /// Returns a normalized version of this period, such that equivalent (but potentially non-equal) periods are
  /// changed to the same representation.
  ///
  /// Months and years are unchanged
  /// (as they can vary in length), but weeks are multiplied by 7 and added to the
  /// Days property, and all time properties are normalized to their natural range.
  /// Subsecond values are normalized to millisecond and "nanosecond within millisecond" values.
  /// So for example, a period of 25 hours becomes a period of 1 day
  /// and 1 hour. A period of 1,500,750,000 nanoseconds becomes 1 second, 500 milliseconds and
  /// 750,000 nanoseconds. Aside from months and years, either all the properties
  /// end up positive, or they all end up negative. "Week" and "tick" units in the returned period are always 0.
  ///
  /// Throws [OverflowException] if the period doesn't have years or months, but it contains more than
  /// `long.MaxValue` nanoseconds when the combined weeks/days/time portions are considered. This is
  /// over 292 years, so unlikely to be a problem in normal usage.
  /// In some cases this may occur even though the theoretical result would be valid due to balancing positive and
  /// negative values, but for simplicity there is no attempt to work around this.
  ///
  /// Returns the normalized period.
  ///
  /// See also [NormalizingEqualityComparer].
  Period Normalize() {
    // Simplest way to normalize: grab all the fields up to "week" and
    // sum them.
    int totalNanoseconds = _TotalNanoseconds;
    int days = totalNanoseconds ~/ NanosecondsPerDay;
    int hours = (totalNanoseconds ~/ NanosecondsPerHour).remainder(HoursPerDay);
    int minutes = (totalNanoseconds ~/ NanosecondsPerMinute).remainder(MinutesPerHour);
    int seconds = (totalNanoseconds ~/ NanosecondsPerSecond).remainder(SecondsPerMinute);
    int milliseconds = (totalNanoseconds ~/ NanosecondsPerMillisecond).remainder(MillisecondsPerSecond);
    int nanoseconds = totalNanoseconds.remainder(NanosecondsPerMillisecond);

    return Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(
        Years, Months, 0 /* weeks */, days, hours, minutes, seconds, milliseconds, 0 /* ticks */, nanoseconds);
  }

  // #region Object overrides

  /// Returns this string formatted according to the [PeriodPattern.Roundtrip].
  ///
  /// Returns a formatted representation of this period.
  @override
  String toString() => PeriodPattern.Roundtrip.Format(this);

  // Not ported: operator +(Period) (unary plus; Dart has no unary + operator)

  /// Compares the given object for equality with this one, as per [Equals].
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The value to compare this one with.
  ///
  /// Returns true if the other object is a period equal to this one, consistent with [Equals]
  @override
  bool operator ==(Object other) => other is Period && Equals(other);

  /// Returns the hash code for this period, consistent with [Equals].
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns the hash code for this period.
  @override
  int get hashCode =>
      HashCodeHelper.Initialize()
          .Hash(Years)
          .Hash(Months)
          .Hash(Weeks)
          .Hash(Days)
          .Hash(Hours)
          .Hash(Minutes)
          .Hash(Seconds)
          .Hash(Milliseconds)
          .Hash(Ticks)
          .Hash(Nanoseconds)
          .Value;

  /// Compares the given period for equality with this one.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The period to compare this one with.
  ///
  /// Returns true if this period has the same values for the same properties as the one specified.
  bool Equals(Period? other) =>
      other != null &&
      Years == other.Years &&
      Months == other.Months &&
      Weeks == other.Weeks &&
      Days == other.Days &&
      Hours == other.Hours &&
      Minutes == other.Minutes &&
      Seconds == other.Seconds &&
      Milliseconds == other.Milliseconds &&
      Ticks == other.Ticks &&
      Nanoseconds == other.Nanoseconds;

  // operator == and != (static, nullable): Dart's == above, and its !=.
  // #endregion

  // #region JSON (noda_dart)

  /// Formats this period with [PeriodPattern.Roundtrip], as NodaTime.Serialization.SystemTextJson does.
  String toJson() => PeriodPattern.Roundtrip.Format(this);

  /// Parses a period written by [toJson], using [PeriodPattern.Roundtrip].
  ///
  /// Throws [UnparsableValueException] if the text could not be parsed.
  factory Period.fromJson(String json) => PeriodPattern.Roundtrip.Parse(json).Value;
  // #endregion
}

/// Equality comparer which simply normalizes periods before comparing them.
final class _PeriodNormalizingPeriodEqualityComparer implements IEqualityComparer<Period?> {
  static final _PeriodNormalizingPeriodEqualityComparer Instance = _PeriodNormalizingPeriodEqualityComparer._New();

  _PeriodNormalizingPeriodEqualityComparer._New();

  @override
  bool Equals(Period? x, Period? y) {
    if (identical(x, y)) {
      return true;
    }
    if (x == null || y == null) {
      return false;
    }
    return x.Normalize().Equals(y.Normalize());
  }

  @override
  int GetHashCode(Period? obj) =>
      Preconditions.CheckNotNull(obj, 'obj').Normalize().hashCode;
}

/// The comparer returned by [Period.CreateComparer].
final class _PeriodPeriodComparer implements IComparer<Period?> {
  final LocalDateTime _baseDateTime;

  _PeriodPeriodComparer.New(LocalDateTime baseDateTime) : _baseDateTime = baseDateTime;

  @override
  int Compare(Period? x, Period? y) {
    if (identical(x, y)) {
      return 0;
    }
    if (x == null) {
      return -1;
    }
    if (y == null) {
      return 1;
    }
    if (x.Months == 0 && y.Months == 0 &&
        x.Years == 0 && y.Years == 0) {
      // Note: this *could* throw an OverflowException when the normal approach
      // wouldn't, but it's highly unlikely
      return x.ToDuration().compareTo(y.ToDuration());
    }
    return (_baseDateTime + x).compareTo(_baseDateTime + y);
  }
}
