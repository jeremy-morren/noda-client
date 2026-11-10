// Ported from NodaTime 6e024dde: src/NodaTime/YearMonth.cs
// Copyright 2019 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'CalendarOrdinal.generated.dart';
import 'CalendarSystem.dart';
import 'Calendars/Era.dart' as nt show Era;
import 'Calendars/GregorianYearMonthDayCalculator.dart';
import 'DateInterval.dart';
import 'Globalization/NodaCultureInfo.dart';
import 'LocalDate.dart';
import 'Text/YearMonthPattern.dart';
import 'Utility/Preconditions.dart';
import 'YearMonthDay.dart';
import 'YearMonthDayCalendar.dart';

/// A year and month in a particular calendar. This is effectively
/// [LocalDate] without the day-of-month component.
///
/// Values can freely be compared for equality: a value in a different calendar system is not equal to
/// a value in a different calendar system. However, ordering comparisons
/// fail with [ArgumentError]; attempting to compare values in different calendars
/// almost always indicates a bug in the calling code.
///
/// Thread safety: This type is an immutable value type. See the thread safety section of the user guide for more information.
// Not ported: [XmlSchemaProvider], [TypeConverter(typeof(YearMonthTypeConverter))], IXmlSerializable (not ported, see below)
final class YearMonth implements Comparable<YearMonth> {
  /// The start of month. This is used as our base representation as we already have
  /// plenty of other code that integrates it, and it implements a compact representation
  /// without us having to duplicate any of the logic.
  final YearMonthDayCalendar _startOfMonth;

  /// Gets the calendar system associated with this year/month.
  CalendarSystem get Calendar => CalendarSystem.ForOrdinal(_CalendarOrdinal);

  CalendarOrdinal get _CalendarOrdinal => _startOfMonth.CalendarOrdinal;

  /// Gets the year of this year/month.
  ///
  /// This returns the "absolute year", so, for the ISO calendar,
  /// a value of 0 means 1 BC, for example.
  int get Year => _startOfMonth.Year;

  /// Gets the month of this year/month within the year.
  int get Month => _startOfMonth.Month;

  /// Gets the year of this value within the era.
  int get YearOfEra => Calendar.GetYearOfEra(_startOfMonth.Year);

  /// Gets the era of this year/month.
  nt.Era get Era => Calendar.GetEra(_startOfMonth.Year);

  // Note: we could easily make these properties public later if we wanted.
  /// Returns the date of the start of this year/month.
  @internal
  LocalDate get StartDate => LocalDate.NewYearMonthDayCalendar(_startOfMonth);

  /// Returns the date of the end of this year/month.
  @internal
  LocalDate get EndDate => LocalDate(Year, Month, Calendar.GetDaysInMonth(Year, Month), Calendar);

  YearMonthDay get _YearMonthDay => _startOfMonth.ToYearMonthDay();

  // noda_dart: the field assignment of NodaTime's constructors (Dart's factory constructors call this).
  YearMonth._NewStartOfMonth(YearMonthDayCalendar startOfMonth) : _startOfMonth = startOfMonth;

  /// Constructs an instance for the given year and month in the ISO calendar, or (if [calendar] is given) in the
  /// specified calendar.
  ///
  /// [year]: The year. This is the "absolute year", so, for
  /// the ISO calendar, a value of 0 means 1 BC, for example.
  /// [month]: The month of year.
  /// [calendar]: Calendar system in which to create the year/month.
  ///
  /// Returns the resulting year/month.
  ///
  /// Throws [RangeError] if the parameters do not form a valid year/month.
  // noda_dart: C#'s YearMonth(int year, int month) and YearMonth(int year, int month, CalendarSystem calendar).
  factory YearMonth(int year, int month, [CalendarSystem? calendar]) {
    if (calendar == null) {
      // Note: not delegating to (year, month, calendar) to optimize performance.
      if (year < GregorianYearMonthDayCalculator.MinGregorianYear || year > GregorianYearMonthDayCalculator.MaxGregorianYear || month < 1 || month > 12) {
        Preconditions.CheckArgumentRange('year', year, GregorianYearMonthDayCalculator.MinGregorianYear, GregorianYearMonthDayCalculator.MaxGregorianYear);
        Preconditions.CheckArgumentRange('month', month, 1, 12);
      }
      return YearMonth._NewStartOfMonth(YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(year, month, 1, CalendarOrdinal.Iso));
    }
    // Dart: null safety checks calendar.
    calendar.ValidateYearMonthDay(year, month, 1);
    return YearMonth._NewStartOfMonth(YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(year, month, 1, calendar.Ordinal));
  }

  /// Constructs an instance for the given era, year of era and month in the ISO calendar, or (if [calendar] is given)
  /// in the specified calendar.
  ///
  /// [era]: The era within which to create a year/month. Must be a valid era within the specified calendar.
  /// [yearOfEra]: The year of era.
  /// [month]: The month of year.
  /// [calendar]: Calendar system in which to create the year/month.
  ///
  /// Returns the resulting year/month.
  ///
  /// Throws [RangeError] if the parameters do not form a valid year/month.
  // noda_dart: C#'s YearMonth(Era era, int yearOfEra, int month) and
  // YearMonth(Era era, int yearOfEra, int month, CalendarSystem calendar).
  factory YearMonth.EraYearOfEraMonth(nt.Era era, int yearOfEra, int month, [CalendarSystem? calendar]) {
    calendar ??= CalendarSystem.Iso;
    return YearMonth(calendar.GetAbsoluteYear(yearOfEra, era), month, calendar);
  }

  /// Returns a [DateInterval] covering the month represented by this value.
  ///
  /// Returns a [DateInterval] covering the month represented by this value.
  DateInterval ToDateInterval() => DateInterval(StartDate, EndDate);

  /// Returns a [YearMonth] object which is the result of adding the specified number
  /// of months to this object.
  ///
  /// [months]: The number of months to add to this object.
  ///
  /// Returns the resulting [YearMonth] after adding the specified number of months.
  YearMonth PlusMonths(int months) =>
      OnDayOfMonth(1).PlusMonths(months).ToYearMonth();

  /// Returns a [LocalDate] with the year/month of this value, and the given day of month.
  ///
  /// [day]: The day within the month.
  ///
  /// Throws [RangeError] if [day] does not fall within the
  /// month represented by this value.
  ///
  /// Returns the result of combining this year and month with [day].
  LocalDate OnDayOfMonth(int day) {
    Preconditions.CheckArgumentRange('day', day, 1, Calendar.GetDaysInMonth(Year, Month));
    return LocalDate(Year, Month, day, Calendar);
  }

  /// Indicates whether this year/month is earlier, later or the same as another one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [other]: The other year/month to compare this one with
  ///
  /// Throws [ArgumentError] if the calendar system of [other] is not the
  /// same as the calendar system of this value.
  ///
  /// Returns a value less than zero if this year/month is earlier than [other];
  /// zero if this year/month is the same as [other]; a value greater than zero if this date is
  /// later than [other].
  @override
  int compareTo(YearMonth other) {
    Preconditions.CheckArgument(_CalendarOrdinal == other._CalendarOrdinal, 'other', 'Only values with the same calendar system can be compared');
    return _TrustedCompareTo(other);
  }

  /// Performs a comparison with another YearMonth, trusting that the calendar of the other date is already correct.
  /// This avoids duplicate calendar checks.
  int _TrustedCompareTo(YearMonth other) => Calendar.Compare(_YearMonthDay, other._YearMonthDay);

  /// Implementation of `IComparable.CompareTo` to compare two YearMonth values.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// This uses explicit interface implementation to avoid it being called accidentally. The generic implementation should usually be preferred.
  ///
  /// Throws [ArgumentError] if [obj] is non-null but does not refer to an instance of [YearMonth], or refers
  /// to a value in a different calendar system.
  ///
  /// [obj]: The object to compare this value with.
  ///
  /// Returns the result of comparing this YearMonth with another one.
  /// If [obj] is null, this method returns a value greater than 0.
  int CompareTo(Object? obj) {
    if (obj == null) {
      return 1;
    }
    Preconditions.CheckArgument(obj is YearMonth, 'obj', 'Object must be of type NodaTime.YearMonth.');
    return compareTo(obj as YearMonth);
  }

  /// Compares two YearMonth values to see if the left one is strictly earlier than the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Throws [ArgumentError] if the calendar system of [rhs] is not the same
  /// as the calendar of this value.
  ///
  /// Returns true if this value is strictly earlier than [rhs], false otherwise.
  bool operator <(YearMonth rhs) {
    Preconditions.CheckArgument(_CalendarOrdinal == rhs._CalendarOrdinal, 'rhs', 'Only values in the same calendar can be compared');
    return _TrustedCompareTo(rhs) < 0;
  }

  /// Compares two YearMonth values to see if the left one is earlier than or equal to the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Throws [ArgumentError] if the calendar system of [rhs] is not the same
  /// as the calendar of this value.
  ///
  /// Returns true if this value is earlier than or equal to [rhs], false otherwise.
  bool operator <=(YearMonth rhs) {
    Preconditions.CheckArgument(_CalendarOrdinal == rhs._CalendarOrdinal, 'rhs', 'Only values in the same calendar can be compared');
    return _TrustedCompareTo(rhs) <= 0;
  }

  /// Compares two YearMonth values to see if the left one is strictly later than the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Throws [ArgumentError] if the calendar system of [rhs] is not the same
  /// as the calendar of this value.
  ///
  /// Returns true if this value is strictly later than [rhs], false otherwise.
  bool operator >(YearMonth rhs) {
    Preconditions.CheckArgument(_CalendarOrdinal == rhs._CalendarOrdinal, 'rhs', 'Only values in the same calendar can be compared');
    return _TrustedCompareTo(rhs) > 0;
  }

  /// Compares two YearMonth values to see if the left one is later than or equal to the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Throws [ArgumentError] if the calendar system of [rhs] is not the same
  /// as the calendar of this value.
  ///
  /// Returns true if this value is later than or equal to [rhs], false otherwise.
  bool operator >=(YearMonth rhs) {
    Preconditions.CheckArgument(_CalendarOrdinal == rhs._CalendarOrdinal, 'rhs', 'Only values in the same calendar can be compared');
    return _TrustedCompareTo(rhs) >= 0;
  }

  /// Returns a hash code for this year/month.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a hash code for this value.
  @override
  int get hashCode => _startOfMonth.hashCode;

  // noda_dart: C#'s Equals(object) is operator ==, below.

  /// Compares two [YearMonth] values for equality.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [other]: The value to compare this year/month with.
  ///
  /// Returns true if the given value is another year/month equal to this one; false otherwise.
  bool Equals(YearMonth other) => this == other;

  /// Compares two [YearMonth] values for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns true if the two year/month values are the same and in the same calendar; false otherwise
  // noda_dart: C#'s operator ==(YearMonth, YearMonth) and Equals(object); `!=` is Dart's.
  @override
  bool operator ==(Object other) => other is YearMonth && _startOfMonth == other._startOfMonth;

  /// Formats the value of the current instance using the specified pattern.
  ///
  /// Unlike most `IFormattable` implementations, a [patternText] of null with
  /// the current thread's culture does not yield the same result as the parameterless [toString]
  /// overload, for backward-compatibility reasons. (It uses the ISO format, which is culture-insensitive.)
  ///
  /// Returns a [String] containing the value of the current instance in the specified format.
  ///
  /// [patternText]: The [String] specifying the pattern to use,
  /// or null to use the ISO format pattern ("g").
  /// [formatProvider]: The [IFormatProvider] to use when formatting the value,
  /// or null to use the invariant culture.
  // noda_dart: C#'s ToString(string? patternText, IFormatProvider? formatProvider).
  String ToStringPattern(String? patternText, [IFormatProvider? formatProvider]) =>
      YearMonthPattern.BclSupport.Format(this, patternText, formatProvider);

  /// Returns a [String] that represents this instance.
  ///
  /// Returns the value of the current instance in the culture-specific default format pattern ("G"), using the
  /// invariant culture (NodaTime uses the current thread's culture; Dart has none).
  @override
  String toString() =>
      YearMonthPattern.BclSupport.Format(this, YearMonthPattern.CultureDefaultFormatPattern, NodaCultureInfo.InvariantCulture);

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable.GetSchema, ReadXml, WriteXml (XML serialization)
  // #endregion

  // #region JSON (noda_dart)
  /// Formats this value with [YearMonthPattern.Iso], as NodaTime.Serialization.SystemTextJson does.
  String toJson() => YearMonthPattern.Iso.Format(this);

  /// Parses a value written by [toJson], in [calendar] (default ISO).
  ///
  /// Throws [UnparsableValueException] if the value can't be parsed.
  factory YearMonth.fromJson(String json, [CalendarSystem? calendar]) =>
      (calendar == null
              ? YearMonthPattern.Iso
              : YearMonthPattern.Iso.WithTemplateValue(YearMonthPattern.DefaultTemplateValue.StartDate.WithCalendar(calendar).ToYearMonth()))
          .Parse(json)
          .Value;
  // #endregion
}
