// Ported from NodaTime 6e024dde: src/NodaTime/PeriodBuilder.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'Period.dart';
import 'PeriodUnits.generated.dart';
import 'Utility/Int64.dart';
import 'Utility/Preconditions.dart';

/// A mutable builder class for [Period] values. Each property can
/// be set independently, and then a Period can be created from the result
/// using the [Build] method.
///
/// This type is not thread-safe without extra synchronization, but has no
/// thread affinity.
final class PeriodBuilder {
  // #region Properties
  /// Gets or sets the number of years within the period.
  int Years = 0;

  /// Gets or sets the number of months within the period.
  int Months = 0;

  /// Gets or sets the number of weeks within the period.
  int Weeks = 0;

  /// Gets or sets the number of days within the period.
  int Days = 0;

  /// Gets or sets the number of hours within the period.
  int Hours = 0;

  /// Gets or sets the number of minutes within the period.
  int Minutes = 0;

  /// Gets or sets the number of seconds within the period.
  int Seconds = 0;

  /// Gets or sets the number of milliseconds within the period.
  int Milliseconds = 0;

  /// Gets or sets the number of ticks within the period.
  int Ticks = 0;

  /// Gets or sets the number of nanoseconds within the period.
  int Nanoseconds = 0;
  // #endregion

  /// Creates a new period builder with an initially zero period, or, given [period], with the values from an
  /// existing period. Calling this constructor instead of [Period.ToBuilder]
  /// allows object initializers to be used.
  ///
  /// (NodaTime's `PeriodBuilder()` and `PeriodBuilder(Period)`.)
  ///
  /// [period]: An existing period to copy values from.
  PeriodBuilder([Period? period]) {
    if (period == null) {
      return;
    }
    // Dart: null safety checks period (null is the parameterless constructor).
    Years = period.Years;
    Months = period.Months;
    Weeks = period.Weeks;
    Days = period.Days;
    Hours = period.Hours;
    Minutes = period.Minutes;
    Seconds = period.Seconds;
    Milliseconds = period.Milliseconds;
    Ticks = period.Ticks;
    Nanoseconds = period.Nanoseconds;
  }

  /// Gets the value of a single unit.
  ///
  /// The type of this indexer is `long` (`int`) for uniformity, but any date unit (year, month, week, day) will only
  /// ever have a value in the range of `Int32`.
  ///
  /// For the [PeriodUnits.Nanoseconds] unit, the value is converted to `Int64` when reading from the indexer, causing it to
  /// fail if the value is out of range (around 250 years). To access the values of very large numbers of nanoseconds, use the [Nanoseconds]
  /// property directly.
  ///
  /// [unit]: A single value within the [PeriodUnits] enumeration.
  ///
  /// Returns the value of the given unit within this period builder, or zero if the unit is unset.
  ///
  /// Throws [RangeError] if [unit] is not a single unit.
  int operator [](PeriodUnits unit) => switch (unit) {
        PeriodUnits.Years => Years,
        PeriodUnits.Months => Months,
        PeriodUnits.Weeks => Weeks,
        PeriodUnits.Days => Days,
        PeriodUnits.Hours => Hours,
        PeriodUnits.Minutes => Minutes,
        PeriodUnits.Seconds => Seconds,
        PeriodUnits.Milliseconds => Milliseconds,
        PeriodUnits.Ticks => Ticks,
        PeriodUnits.Nanoseconds => Nanoseconds,
        _ => throw RangeError.value(unit.value, 'unit', 'Indexer for PeriodBuilder only takes a single unit')
      };

  /// Sets the value of a single unit.
  ///
  /// [unit]: A single value within the [PeriodUnits] enumeration.
  /// [value]: The new value of the given unit.
  ///
  /// Throws [RangeError] if [unit] is not a single unit, or a value is provided for a date unit which is outside the
  /// range of `Int32`.
  void operator []=(PeriodUnits unit, int value) {
    if ((unit & PeriodUnits.AllDateUnits).value != 0) {
      Preconditions.CheckArgumentRange('value', value, Int64.Int32MinValue, Int64.Int32MaxValue);
    }
    switch (unit) {
      case PeriodUnits.Years: Years = value; return;
      case PeriodUnits.Months: Months = value; return;
      case PeriodUnits.Weeks: Weeks = value; return;
      case PeriodUnits.Days: Days = value; return;
      case PeriodUnits.Hours: Hours = value; return;
      case PeriodUnits.Minutes: Minutes = value; return;
      case PeriodUnits.Seconds: Seconds = value; return;
      case PeriodUnits.Milliseconds: Milliseconds = value; return;
      case PeriodUnits.Ticks: Ticks = value; return;
      case PeriodUnits.Nanoseconds: Nanoseconds = value; return;
      default: throw RangeError.value(unit.value, 'unit', 'Indexer for PeriodBuilder only takes a single unit');
    }
  }

  /// Builds a period from the properties in this builder.
  ///
  /// Returns a period containing the values from this builder.
  Period Build() =>
      Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(
          Years, Months, Weeks, Days, Hours, Minutes, Seconds, Milliseconds, Ticks, Nanoseconds);

  // Not ported: AddSchema, IXmlSerializable.GetSchema/ReadXml/WriteXml (XML serialization)
}
