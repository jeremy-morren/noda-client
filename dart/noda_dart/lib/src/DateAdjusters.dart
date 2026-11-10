// Ported from NodaTime 6e024dde: src/NodaTime/DateAdjusters.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

// C#'s get-only static properties holding one delegate each are static final fields.
// ignore_for_file: prefer_function_declarations_over_variables

import 'IsoDayOfWeek.generated.dart';
import 'LocalDate.dart';
import 'Period.dart';
import 'Utility/Preconditions.dart';

/// Factory class for date adjusters: functions from [LocalDate] to `LocalDate`,
/// which can be applied to [LocalDate], `LocalDateTime`, and `OffsetDateTime`.
abstract final class DateAdjusters {
  /// A date adjuster to move to the first day of the current month.
  static final LocalDate Function(LocalDate) StartOfMonth =
      (date) => LocalDate(date.Year, date.Month, 1, date.Calendar);

  /// A date adjuster to move to the last day of the current month.
  static final LocalDate Function(LocalDate) EndOfMonth =
      (date) => LocalDate(date.Year, date.Month, date.Calendar.GetDaysInMonth(date.Year, date.Month), date.Calendar);

  /// A date adjuster to move to the specified day of the current month.
  ///
  /// The returned adjuster will throw an exception if it is applied to a date
  /// that would create an invalid result.
  ///
  /// [day]: The day of month to adjust dates to.
  ///
  /// Returns an adjuster which changes the day to [day],
  /// retaining the same year and month.
  static LocalDate Function(LocalDate) DayOfMonth(int day) =>
      (date) => LocalDate(date.Year, date.Month, day, date.Calendar);

  /// A date adjuster to move to the same day of the specified month.
  ///
  /// The returned adjuster will throw an exception if it is applied to a date
  /// that would create an invalid result.
  ///
  /// [month]: The month to adjust dates to.
  ///
  /// Returns an adjuster which changes the month to [month],
  /// retaining the same year and day of month.
  static LocalDate Function(LocalDate) Month(int month) =>
      (date) => LocalDate(date.Year, month, date.Day, date.Calendar);

  /// A date adjuster to move to the next specified day-of-week, but return the
  /// original date if the day is already correct.
  ///
  /// [dayOfWeek]: The day-of-week to adjust dates to.
  ///
  /// Returns an adjuster which advances a date to the next occurrence of the
  /// specified day-of-week, or the original date if the day is already correct.
  static LocalDate Function(LocalDate) NextOrSame(IsoDayOfWeek dayOfWeek) {
    // Avoids boxing...
    if (dayOfWeek.value < IsoDayOfWeek.Monday.value || dayOfWeek.value > IsoDayOfWeek.Sunday.value) {
      throw RangeError.value(dayOfWeek.value, 'dayOfWeek', 'Specified argument was out of the range of valid values.');
    }
    return (date) => date.DayOfWeek == dayOfWeek ? date : date.Next(dayOfWeek);
  }

  /// A date adjuster to move to the previous specified day-of-week, but return the
  /// original date if the day is already correct.
  ///
  /// [dayOfWeek]: The day-of-week to adjust dates to.
  ///
  /// Returns an adjuster which advances a date to the previous occurrence of the
  /// specified day-of-week, or the original date if the day is already correct.
  static LocalDate Function(LocalDate) PreviousOrSame(IsoDayOfWeek dayOfWeek) {
    // Avoids boxing...
    if (dayOfWeek.value < IsoDayOfWeek.Monday.value || dayOfWeek.value > IsoDayOfWeek.Sunday.value) {
      throw RangeError.value(dayOfWeek.value, 'dayOfWeek', 'Specified argument was out of the range of valid values.');
    }
    return (date) => date.DayOfWeek == dayOfWeek ? date : date.Previous(dayOfWeek);
  }

  /// A date adjuster to move to the next specified day-of-week, adding
  /// a week if the day is already correct.
  ///
  /// This is the adjuster equivalent of [LocalDate.Next].
  ///
  /// [dayOfWeek]: The day-of-week to adjust dates to.
  ///
  /// Returns an adjuster which advances a date to the next occurrence of the
  /// specified day-of-week.
  static LocalDate Function(LocalDate) Next(IsoDayOfWeek dayOfWeek) {
    // Avoids boxing...
    if (dayOfWeek.value < IsoDayOfWeek.Monday.value || dayOfWeek.value > IsoDayOfWeek.Sunday.value) {
      throw RangeError.value(dayOfWeek.value, 'dayOfWeek', 'Specified argument was out of the range of valid values.');
    }
    return (date) => date.Next(dayOfWeek);
  }

  /// A date adjuster to move to the previous specified day-of-week, subtracting
  /// a week if the day is already correct.
  ///
  /// This is the adjuster equivalent of [LocalDate.Previous].
  ///
  /// [dayOfWeek]: The day-of-week to adjust dates to.
  ///
  /// Returns an adjuster which advances a date to the previous occurrence of the
  /// specified day-of-week.
  static LocalDate Function(LocalDate) Previous(IsoDayOfWeek dayOfWeek) {
    // Avoids boxing...
    if (dayOfWeek.value < IsoDayOfWeek.Monday.value || dayOfWeek.value > IsoDayOfWeek.Sunday.value) {
      throw RangeError.value(dayOfWeek.value, 'dayOfWeek', 'Specified argument was out of the range of valid values.');
    }
    return (date) => date.Previous(dayOfWeek);
  }

  /// Creates a date adjuster to add the specified period to the date.
  ///
  /// This is the adjuster equivalent of [LocalDate.Plus].
  ///
  /// [period]: The period to add when the adjuster is invoked. Must not contain any (non-zero) time units.
  ///
  /// Returns an adjuster which adds the specified period.
  static LocalDate Function(LocalDate) AddPeriod(Period period) {
    // Dart: null safety checks period.
    // Perform this validation eagerly. It will be performed on each invocation as well,
    // but it's good to throw an exception now rather than waiting for the first invocation.
    Preconditions.CheckArgument(!period.HasTimeComponent, 'period', 'Cannot add a period with a time component to a date');
    return (date) => date + period;
  }
}
