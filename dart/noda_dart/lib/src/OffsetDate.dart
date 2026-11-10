// Ported from NodaTime 6e024dde: src/NodaTime/OffsetDate.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'CalendarSystem.dart';
import 'Calendars/Era.dart' as nt show Era;
import 'Globalization/NodaCultureInfo.dart';
import 'IsoDayOfWeek.generated.dart';
import 'LocalDate.dart';
import 'LocalTime.dart';
import 'Offset.dart' as nt show Offset;
import 'OffsetDateTime.dart';
import 'Text/OffsetDatePattern.dart';
import 'Utility/HashCodeHelper.dart';

/// A combination of a [LocalDate] and an [Offset], to represent
/// a date at a specific offset from UTC but without any time-of-day information.
///
/// Equality is defined in a component-wise fashion: two values are the same if they represent equal dates
/// (including being in the same calendar) and equal offsets from UTC.
/// Ordering between offset dates is not defined.
///
/// The default value of this type is 0001-01-01 (January 1st, 1 C.E.) in the ISO calendar with a UTC offset of zero.
///
/// This type is an immutable value type. See the thread safety section of the user guide for more information.
final class OffsetDate {
  final LocalDate _date;
  final nt.Offset _offset;

  /// Constructs an instance of the specified date and offset.
  ///
  /// [date]: The date part of the value.
  /// [offset]: The offset part of the value.
  OffsetDate(LocalDate date, nt.Offset offset)
      : _date = date,
        _offset = offset;

  /// Gets the local date represented by this value.
  LocalDate get Date => _date;

  /// Gets the offset from UTC of this value.
  nt.Offset get Offset => _offset;

  /// Gets the calendar system associated with this offset date.
  CalendarSystem get Calendar => _date.Calendar;

  /// Gets the year of this offset date.
  ///
  /// This returns the "absolute year", so, for the ISO calendar,
  /// a value of 0 means 1 BC, for example.
  int get Year => _date.Year;

  /// Gets the month of this offset date within the year.
  int get Month => _date.Month;

  /// Gets the day of this offset date within the month.
  int get Day => _date.Day;

  /// Gets the week day of this offset date expressed as an [IsoDayOfWeek] value.
  IsoDayOfWeek get DayOfWeek => _date.DayOfWeek;

  /// Gets the year of this offset date within the era.
  int get YearOfEra => _date.YearOfEra;

  /// Gets the era of this offset date.
  nt.Era get Era => _date.Era;

  /// Gets the day of this offset date within the year.
  int get DayOfYear => _date.DayOfYear;

  /// Creates a new [OffsetDate] for the same date, but with the specified UTC offset.
  ///
  /// [offset]: The new UTC offset.
  ///
  /// Returns a new `OffsetDate` for the same date, but with the specified UTC offset.
  OffsetDate WithOffset(nt.Offset offset) => OffsetDate(_date, offset);

  /// Returns this offset date, with the given date adjuster applied to it, maintaining the existing offset.
  ///
  /// If the adjuster attempts to construct an
  /// invalid date (such as by trying to set a day-of-month of 30 in February), any exception thrown by
  /// that construction attempt will be propagated through this method.
  ///
  /// [adjuster]: The adjuster to apply.
  ///
  /// Returns the adjusted offset date.
  OffsetDate With(LocalDate Function(LocalDate) adjuster) =>
      OffsetDate(_date.With(adjuster), _offset);

  /// Creates a new [OffsetDate] representing the same physical date and offset, but in a different calendar.
  /// The returned value is likely to have different date field values to this one.
  /// For example, January 1st 1970 in the Gregorian calendar was December 19th 1969 in the Julian calendar.
  ///
  /// [calendar]: The calendar system to convert this offset date to.
  ///
  /// Returns the converted `OffsetDate`.
  OffsetDate WithCalendar(CalendarSystem calendar) =>
      OffsetDate(_date.WithCalendar(calendar), _offset);

  /// Combines this [OffsetDate] with the given [LocalTime]
  /// into an [OffsetDateTime].
  ///
  /// [time]: The time to combine with this date.
  ///
  /// Returns the [OffsetDateTime] representation of the given time on this date.
  OffsetDateTime At(LocalTime time) => OffsetDateTime(_date.At(time), _offset);

  /// Returns a hash code for this offset date.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a hash code for this offset date.
  @override
  int get hashCode => HashCodeHelper.HashStatic(_date, _offset);

  /// Compares two [OffsetDate] values for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The object to compare this offset date with.
  ///
  /// Returns true if the given value is another offset date equal to this one; false otherwise.
  @override
  bool operator ==(Object other) => other is OffsetDate && Equals(other);

  /// Compares two [OffsetDate] values for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The value to compare this offset date with.
  ///
  /// Returns true if the given value is another offset date equal to this one; false otherwise.
  bool Equals(OffsetDate other) => _date == other._date && _offset == other._offset;

  // operator == and != (static): Dart's == above, and its !=.

  /// Returns a [String] that represents this instance.
  ///
  /// Returns the value of the current instance in the default format pattern ("G"), using the invariant culture
  /// (NodaTime uses the current thread's culture).
  @override
  String toString() => OffsetDatePatternPatterns.BclSupport.Format(this, null, NodaCultureInfo.InvariantCulture);

  /// Formats the value of the current instance using the specified pattern.
  ///
  /// (NodaTime's `ToString(string?, IFormatProvider?)`.)
  ///
  /// [patternText]: The [String] specifying the pattern to use,
  /// or null to use the default format pattern ("G").
  /// [formatProvider]: The [IFormatProvider] to use when formatting the value,
  /// or null to use the current thread's culture to obtain a format provider.
  ///
  /// Returns a [String] containing the value of the current instance in the specified format.
  String ToStringPattern(String? patternText, [IFormatProvider? formatProvider]) =>
      OffsetDatePatternPatterns.BclSupport.Format(this, patternText, formatProvider);

  /// Deconstruct this value into its components: the [LocalDate] component and the [Offset] component.
  ///
  /// (NodaTime's `Deconstruct(out LocalDate localDate, out Offset offset)`.)
  (LocalDate, nt.Offset) get Deconstruct => (_date, _offset);

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable.GetSchema/ReadXml/WriteXml (XML serialization)
  // #endregion

  // #region JSON (noda_dart)

  /// Formats this value with [OffsetDatePattern.GeneralIso], as NodaTime.Serialization.SystemTextJson does.
  String toJson() => OffsetDatePattern.GeneralIso.Format(this);

  /// Parses a value written by [toJson], in [calendar] (default ISO).
  ///
  /// Throws [UnparsableValueException] if the text could not be parsed.
  factory OffsetDate.fromJson(String json, [CalendarSystem? calendar]) {
    final pattern = OffsetDatePattern.GeneralIso;
    return (calendar == null ? pattern : pattern.WithCalendar(calendar)).Parse(json).Value;
  }
  // #endregion
}
