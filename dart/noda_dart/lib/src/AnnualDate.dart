// Ported from NodaTime 6e024dde: src/NodaTime/AnnualDate.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'CalendarOrdinal.generated.dart';
import 'CalendarSystem.dart';
import 'Calendars/GregorianYearMonthDayCalculator.dart';
import 'Globalization/NodaCultureInfo.dart';
import 'LocalDate.dart';
import 'Text/AnnualDatePattern.dart';
import 'Utility/Preconditions.dart';
import 'YearMonthDay.dart';

/// Represents an annual date (month and day) in the ISO calendar but without a specific year,
/// typically for recurrent events such as birthdays, anniversaries, and deadlines.
///
/// Equality and comparison order are defined in the natural way. Two values are equal if they
/// represent the same month and the same day-of-month. One value is earlier than another if it
/// has a smaller month, or the same month but an earlier day-of-month.
///
/// In the future, this struct may be expanded to support other calendar systems,
/// but this does not generalize terribly cleanly, particularly to the Hebrew calendar system
/// with its leap month.
///
/// The default value of this type is January 1st.
// Not ported: [TypeConverter(typeof(AnnualDateTypeConverter))], [XmlSchemaProvider], IXmlSerializable (not ported, see below)
final class AnnualDate implements Comparable<AnnualDate> {
  // The underlying value. We only care about the month and day, but for the sake of
  // compatibility with the default value, this ends up being in year 1. This would
  // be an invalid date, but we only actually use it as an argument to SetYear,
  // which we know ignores the year in the ISO calendar. If we ever allow other calendar
  // systems, we can have a YearMonthDayCalendar which would still be in year 1 for the
  // ISO calendar, but would probably be in a more suitable year for other calendars.
  final YearMonthDay _value;

  /// Constructs an instance for the given month and day in the ISO calendar.
  ///
  /// [month]: The month of year.
  /// [day]: The day of month.
  ///
  /// Throws [RangeError] if the parameters do not form a valid date.
  /// (February 29th is considered valid.)
  factory AnnualDate(int month, int day) {
    // The year 2000 is a leap year, so this is fine for all valid dates.
    GregorianYearMonthDayCalculator.ValidateGregorianYearMonthDay(2000, month, day);
    // See comment above for why this is using year 1, and why that's okay even for February 29th.
    return AnnualDate._NewValue(YearMonthDay.NewYearMonthDay(1, month, day));
  }

  // noda_dart: the field assignment of NodaTime's constructor (Dart's factory constructor calls this).
  AnnualDate._NewValue(YearMonthDay value) : _value = value;

  /// Gets the month of year.
  int get Month => _value.Month;

  /// Gets the day of month.
  int get Day => _value.Day;

  /// Returns this annual date in a particular year, as a [LocalDate].
  ///
  /// If this value represents February 29th, and the specified year is not a leap
  /// year, the returned value will be February 28th of that year. To see whether the
  /// original month and day is valid without truncation in a particular year,
  /// use [IsValidYear]
  ///
  /// [year]: The year component of the required date.
  ///
  /// Returns a date in the given year, suitable for this annual date.
  LocalDate InYear(int year) {
    Preconditions.CheckArgumentRange('year', year,
        GregorianYearMonthDayCalculator.MinGregorianYear,
        GregorianYearMonthDayCalculator.MaxGregorianYear);
    var ymd = CalendarSystem.Iso.YearMonthDayCalculator.SetYear(_value, year);
    return LocalDate.NewYearMonthDayCalendar(ymd.WithCalendarOrdinal(CalendarOrdinal(0))); // ISO calendar
  }

  /// Checks whether the specified year forms a valid date with the month/day in this
  /// value, without any truncation. This will always return `true` except
  /// for values representing February 29th, where the specified year is a non leap year.
  ///
  /// [year]: The year to test for validity
  ///
  /// Returns `true` if the current value occurs within the given year;
  /// `false` otherwise.
  bool IsValidYear(int year) => Month != 2 || Day != 29 || CalendarSystem.Iso.IsLeapYear(year);

  /// Compares this annual date with the specified reference.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns true if the specified value is an annual date which is equal to this one; false otherwise
  // noda_dart: C#'s Equals(object) and operator ==(AnnualDate, AnnualDate); `!=` is Dart's.
  @override
  bool operator ==(Object other) => other is AnnualDate && Equals(other);

  /// Returns a hash code for this annual date.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a hash code for this annual date.
  @override
  int get hashCode => _value.hashCode;

  /// Returns a [String] that represents this instance.
  ///
  /// Returns the value of the current instance in the default format pattern ("G"), using the invariant culture
  /// (NodaTime uses the current thread's culture; Dart has none).
  @override
  String toString() => AnnualDatePattern.BclSupport.Format(this, null, NodaCultureInfo.InvariantCulture);

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
      AnnualDatePattern.BclSupport.Format(this, patternText, formatProvider);

  /// Compares this annual date with the specified one for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The other annual date to compare this one with
  ///
  /// Returns true if the specified annual date is equal to this one; false otherwise
  bool Equals(AnnualDate other) => _value == other._value;

  /// Indicates whether this annual date is earlier, later or the same as another one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [other]: The other annual date to compare this one with
  ///
  /// Returns a value less than zero if this annual date is earlier than [other];
  /// zero if this time is the same as [other]; a value greater than zero if this annual date is
  /// later than [other].
  @override
  int compareTo(AnnualDate other) => _value.compareTo(other._value);

  /// Implementation of `IComparable.CompareTo` to compare two AnnualDates.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// This uses explicit interface implementation to avoid it being called accidentally. The generic implementation should usually be preferred.
  ///
  /// Throws [ArgumentError] if [obj] is non-null but does not refer to an instance of [AnnualDate]
  ///
  /// [obj]: The object to compare this value with.
  ///
  /// Returns the result of comparing this AnnualDate with another one.
  /// If [obj] is null, this method returns a value greater than 0.
  int CompareTo(Object? obj) {
    if (obj == null) {
      return 1;
    }
    Preconditions.CheckArgument(obj is AnnualDate, 'obj', 'Object must be of type NodaTime.AnnualDate.');
    return compareTo(obj as AnnualDate);
  }

  // noda_dart: C#'s operator ==(AnnualDate, AnnualDate) is operator ==, above.

  /// Compares two annual dates to see if the left one is strictly earlier than the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Returns true if this value is strictly earlier than [rhs], false otherwise.
  bool operator <(AnnualDate rhs) => compareTo(rhs) < 0;

  /// Compares two annual dates to see if the left one is earlier than or equal to the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Returns true if this value is earlier than or equal to [rhs], false otherwise.
  bool operator <=(AnnualDate rhs) => compareTo(rhs) <= 0;

  /// Compares two annual dates to see if the left one is strictly later than the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Returns true if this value is strictly later than [rhs], false otherwise.
  bool operator >(AnnualDate rhs) => compareTo(rhs) > 0;

  /// Compares two annual dates to see if the left one is later than or equal to the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Returns true if this value is later than or equal to [rhs], false otherwise.
  bool operator >=(AnnualDate rhs) => compareTo(rhs) >= 0;

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable.GetSchema, ReadXml, WriteXml (XML serialization)
  // #endregion

  // #region JSON (noda_dart)
  /// Formats this value with [AnnualDatePattern.Iso], as NodaTime.Serialization.SystemTextJson does.
  String toJson() => AnnualDatePattern.Iso.Format(this);

  /// Parses a value written by [toJson].
  ///
  /// Throws [UnparsableValueException] if the value can't be parsed.
  factory AnnualDate.fromJson(String json) => AnnualDatePattern.Iso.Parse(json).Value;
  // #endregion
}
