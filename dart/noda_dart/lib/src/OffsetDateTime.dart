// Ported from NodaTime 6e024dde: src/NodaTime/OffsetDateTime.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:core' as core;
import 'dart:core' hide Duration;

import 'package:meta/meta.dart';

import 'CalendarSystem.dart';
import 'Calendars/Era.dart' as nt show Era;
import 'DateTimeZone.dart';
import 'Duration.dart';
import 'Globalization/NodaCultureInfo.dart';
import 'Instant.dart';
import 'IsoDayOfWeek.generated.dart';
import 'LocalDate.dart';
import 'LocalDateTime.dart' as nt show LocalDateTime;
import 'LocalTime.dart';
import 'NodaConstants.generated.dart';
import 'Offset.dart' as nt show Offset;
import 'OffsetDate.dart';
import 'OffsetTime.dart';
import 'Text/OffsetDateTimePattern.dart';
import 'Utility/Comparers.dart';
import 'Utility/HashCodeHelper.dart';
import 'Utility/Preconditions.dart';
import 'YearMonthDay.dart' as nt show YearMonthDay;
import 'ZonedDateTime.dart';

// Do not nest type X.
// The rule is somewhat subjective, but more importantly these have been available
// publicly for a while, so we can't change them now anyway.

/// A local date and time in a particular calendar system, combined with an offset from UTC. This is
/// broadly similar to `DateTimeOffset` in the BCL.
///
/// Equality is defined in a component-wise fashion: two values are the same if they represent equal date/time values
/// (including being in the same calendar) and equal offsets from UTC.
/// Ordering between offset date/time values has no natural definition; see [OffsetDateTimeComparer] for built-in comparers.
///
/// A value of this type unambiguously represents both a local time and an instant on the timeline,
/// but does not have a well-defined time zone. This means you cannot reliably know what the local
/// time would be five minutes later, for example. While this doesn't sound terribly useful, it's very common
/// in text representations.
///
/// The default value of this type is 0001-01-01T00:00:00Z (midnight on January 1st, 1 C.E. with a UTC offset of 0) in the ISO calendar.
///
/// This type is an immutable value type. See the thread safety section of the user guide for more information.
final class OffsetDateTime {
  // Not ported: MinBclOffsetMinutes, MaxBclOffsetMinutes (only used by ToDateTimeOffset, which isn't ported)

  // This is effectively a LocalDateTime and an Offset, but by composing it slightly differently, we can save memory.
  final LocalDate _localDate;
  final OffsetTime _offsetTime;

  @internal
  OffsetDateTime.NewLocalDateOffsetTime(LocalDate localDate, OffsetTime offsetTime)
      : _localDate = localDate,
        _offsetTime = offsetTime;

  /// Optimized conversion from an Instant to an OffsetDateTime in the ISO calendar.
  /// This is equivalent to `new OffsetDateTime(new LocalDateTime(instant.Plus(offset)), offset)`
  /// but with less overhead.
  @internal
  factory OffsetDateTime.NewInstantOffset(Instant instant, nt.Offset offset) {
    int days = instant.DaysSinceEpoch;
    int nanoOfDay = instant.NanosecondOfDay + offset.Nanoseconds;
    if (nanoOfDay >= NanosecondsPerDay) {
      days++;
      nanoOfDay -= NanosecondsPerDay;
    } else if (nanoOfDay < 0) {
      days--;
      nanoOfDay += NanosecondsPerDay;
    }
    return OffsetDateTime.NewLocalDateOffsetTime(
        LocalDate.NewDaysSinceEpoch(days),
        OffsetTime.NewNanosecondOfDayOffsetSeconds(nanoOfDay, offset.Seconds));
  }

  /// Optimized conversion from an Instant to an OffsetDateTime in the specified calendar.
  /// This is equivalent to `new OffsetDateTime(new LocalDateTime(instant.Plus(offset), calendar), offset)`
  /// but with less overhead.
  @internal
  factory OffsetDateTime.NewInstantOffsetCalendar(Instant instant, nt.Offset offset, CalendarSystem calendar) {
    int days = instant.DaysSinceEpoch;
    int nanoOfDay = instant.NanosecondOfDay + offset.Nanoseconds;
    if (nanoOfDay >= NanosecondsPerDay) {
      days++;
      nanoOfDay -= NanosecondsPerDay;
    } else if (nanoOfDay < 0) {
      days--;
      nanoOfDay += NanosecondsPerDay;
    }
    return OffsetDateTime.NewLocalDateOffsetTime(
        LocalDate.NewDaysSinceEpochCalendar(days, calendar),
        OffsetTime.NewNanosecondOfDayOffsetSeconds(nanoOfDay, offset.Seconds));
  }

  /// Constructs a new offset date/time with the given local date and time, and the given offset from UTC.
  ///
  /// [localDateTime]: Local date and time to represent
  /// [offset]: Offset from UTC
  OffsetDateTime(nt.LocalDateTime localDateTime, nt.Offset offset)
      : this.NewLocalDateOffsetTime(
            localDateTime.Date, OffsetTime.NewNanosecondOfDayOffsetSeconds(localDateTime.NanosecondOfDay, offset.Seconds));

  /// Gets the calendar system associated with this offset date and time.
  CalendarSystem get Calendar => _localDate.Calendar;

  /// Gets the year of this offset date and time.
  ///
  /// This returns the "absolute year", so, for the ISO calendar,
  /// a value of 0 means 1 BC, for example.
  int get Year => _localDate.Year;

  /// Gets the month of this offset date and time within the year.
  int get Month => _localDate.Month;

  /// Gets the day of this offset date and time within the month.
  int get Day => _localDate.Day;

  @internal
  nt.YearMonthDay get YearMonthDay => _localDate.YearMonthDay;

  /// Gets the week day of this offset date and time expressed as an [IsoDayOfWeek] value.
  IsoDayOfWeek get DayOfWeek => _localDate.DayOfWeek;

  /// Gets the year of this offset date and time within the era.
  int get YearOfEra => _localDate.YearOfEra;

  /// Gets the era of this offset date and time.
  nt.Era get Era => _localDate.Era;

  /// Gets the day of this offset date and time within the year.
  int get DayOfYear => _localDate.DayOfYear;

  /// Gets the hour of day of this offset date and time, in the range 0 to 23 inclusive.
  int get Hour => _offsetTime.Hour;

  /// Gets the hour of the half-day of this offset date and time, in the range 1 to 12 inclusive.
  int get ClockHourOfHalfDay => _offsetTime.ClockHourOfHalfDay;

  /// Gets the minute of this offset date and time, in the range 0 to 59 inclusive.
  int get Minute => _offsetTime.Minute;

  /// Gets the second of this offset date and time within the minute, in the range 0 to 59 inclusive.
  int get Second => _offsetTime.Second;

  /// Gets the millisecond of this offset date and time within the second, in the range 0 to 999 inclusive.
  int get Millisecond => _offsetTime.Millisecond;

  /// Gets the tick of this offset date and time within the second, in the range 0 to 9,999,999 inclusive.
  int get TickOfSecond => _offsetTime.TickOfSecond;

  /// Gets the tick of this offset date and time within the day, in the range 0 to 863,999,999,999 inclusive.
  int get TickOfDay => _offsetTime.TickOfDay;

  /// Gets the nanosecond of this offset date and time within the second, in the range 0 to 999,999,999 inclusive.
  int get NanosecondOfSecond => _offsetTime.NanosecondOfSecond;

  /// Gets the nanosecond of this offset date and time within the day, in the range 0 to 86,399,999,999,999 inclusive.
  int get NanosecondOfDay => _offsetTime.NanosecondOfDay;

  /// Returns the local date and time represented within this offset date and time.
  nt.LocalDateTime get LocalDateTime => nt.LocalDateTime.NewDateTime(Date, TimeOfDay);

  /// Gets the local date represented by this offset date and time.
  ///
  /// The returned [LocalDate]
  /// will have the same calendar system and return the same values for each of the date-based calendar
  /// properties (Year, MonthOfYear and so on), but will not have any offset information.
  LocalDate get Date => _localDate;

  /// Gets the time portion of this offset date and time.
  ///
  /// The returned [LocalTime] will
  /// return the same values for each of the time-based properties (Hour, Minute and so on), but
  /// will not have any offset information.
  LocalTime get TimeOfDay => LocalTime.NewNanoseconds(NanosecondOfDay);

  /// Gets the offset from UTC.
  nt.Offset get Offset => _offsetTime.Offset;

  /// Converts this offset date and time to an instant in time by subtracting the offset from the local date and time.
  ///
  /// Returns the instant represented by this offset date and time
  Instant ToInstant() => Instant.FromUntrustedDuration(_ToElapsedTimeSinceEpoch());

  Duration _ToElapsedTimeSinceEpoch() {
    // Equivalent to LocalDateTime.ToLocalInstant().Minus(offset)
    int days = _localDate.DaysSinceEpoch;
    Duration elapsedTime = Duration.NewDaysNanoOfDay(days, NanosecondOfDay).MinusSmallNanoseconds(_offsetTime.OffsetNanoseconds);
    return elapsedTime;
  }

  /// Returns this value as a [ZonedDateTime].
  ///
  /// This method returns a [ZonedDateTime] with the same local date and time as this value, using a
  /// fixed time zone with the same offset as the offset for this value.
  ///
  /// Note that because the resulting `ZonedDateTime` has a fixed time zone, it is generally not useful to
  /// use this result for arithmetic operations, as the zone will not adjust to account for daylight savings.
  ///
  /// Returns a zoned date/time with the same local time and a fixed time zone using the offset from this value.
  ZonedDateTime InFixedZone() => ZonedDateTime.NewOffsetDateTimeZone(this, DateTimeZone.ForOffset(Offset));

  /// Returns this value in ths specified time zone. This method does not expect
  /// the offset in the zone to be the same as for the current value; it simply converts
  /// this value into an [Instant] and finds the [ZonedDateTime]
  /// for that instant in the specified zone.
  ///
  /// [zone]: The time zone of the new value.
  ///
  /// Returns the instant represented by this value, in the specified time zone.
  ZonedDateTime InZone(DateTimeZone zone) {
    // Dart: null safety checks zone.
    return ToInstant().InZone(zone);
  }

  // Not ported: ToDateTimeOffset, FromDateTimeOffset (DateTimeOffset has no Dart equivalent)

  /// noda_dart: the same instant as a UTC [core.DateTime] (instead of `ToDateTimeOffset()`); the offset is lost.
  ///
  /// Throws [StateError] before the year 1.
  core.DateTime ToDateTimeUtc() => ToInstant().ToDateTimeUtc();

  /// Creates a new OffsetDateTime representing the same physical date, time and offset, but in a different calendar.
  /// The returned OffsetDateTime is likely to have different date field values to this one.
  /// For example, January 1st 1970 in the Gregorian calendar was December 19th 1969 in the Julian calendar.
  ///
  /// [calendar]: The calendar system to convert this offset date and time to.
  ///
  /// Returns the converted OffsetDateTime.
  OffsetDateTime WithCalendar(CalendarSystem calendar) {
    LocalDate newDate = Date.WithCalendar(calendar);
    return OffsetDateTime.NewLocalDateOffsetTime(newDate, _offsetTime);
  }

  /// Returns this offset date/time, with the given date adjuster applied to it, maintaining the existing time of day and offset.
  ///
  /// If the adjuster attempts to construct an
  /// invalid date (such as by trying to set a day-of-month of 30 in February), any exception thrown by
  /// that construction attempt will be propagated through this method.
  ///
  /// [adjuster]: The adjuster to apply.
  ///
  /// Returns the adjusted offset date/time.
  OffsetDateTime With(LocalDate Function(LocalDate) adjuster) =>
      OffsetDateTime.NewLocalDateOffsetTime(_localDate.With(adjuster), _offsetTime);

  /// Returns this date/time, with the given time adjuster applied to it, maintaining the existing date and offset.
  ///
  /// (NodaTime's `With(Func<LocalTime, LocalTime>)`, named as in noda-js: Dart has no overloads.)
  ///
  /// If the adjuster attempts to construct an invalid time, any exception thrown by
  /// that construction attempt will be propagated through this method.
  ///
  /// [adjuster]: The adjuster to apply.
  ///
  /// Returns the adjusted offset date/time.
  OffsetDateTime WithTimeAdjuster(LocalTime Function(LocalTime) adjuster) {
    LocalTime newTime = TimeOfDay.With(adjuster);
    return OffsetDateTime.NewLocalDateOffsetTime(
        _localDate, OffsetTime.NewNanosecondOfDayOffsetSeconds(newTime.NanosecondOfDay, _offsetTime.OffsetSeconds));
  }

  /// Creates a new OffsetDateTime representing the instant in time in the same calendar,
  /// but with a different offset. The local date and time is adjusted accordingly.
  ///
  /// [offset]: The new offset to use.
  ///
  /// Returns the converted OffsetDateTime.
  OffsetDateTime WithOffset(nt.Offset offset) {
    // Slight change to the normal operation, as it's *just* about plausible that we change day
    // twice in one direction or the other.
    int days = 0;
    int nanos = _offsetTime.NanosecondOfDay + offset.Nanoseconds - _offsetTime.OffsetNanoseconds;
    if (nanos >= NanosecondsPerDay) {
      days++;
      nanos -= NanosecondsPerDay;
      if (nanos >= NanosecondsPerDay) {
        days++;
        nanos -= NanosecondsPerDay;
      }
    } else if (nanos < 0) {
      days--;
      nanos += NanosecondsPerDay;
      if (nanos < 0) {
        days--;
        nanos += NanosecondsPerDay;
      }
    }
    return OffsetDateTime.NewLocalDateOffsetTime(
        days == 0 ? _localDate : _localDate.PlusDays(days),
        OffsetTime.NewNanosecondOfDayOffsetSeconds(nanos, offset.Seconds));
  }

  /// Constructs a new [OffsetDate] from the date and offset of this value,
  /// but omitting the time-of-day.
  ///
  /// Returns a value representing the date and offset aspects of this value.
  OffsetDate ToOffsetDate() => OffsetDate(Date, Offset);

  /// Constructs a new [OffsetTime] from the time and offset of this value,
  /// but omitting the date.
  ///
  /// Returns a value representing the time and offset aspects of this value.
  OffsetTime ToOffsetTime() => _offsetTime;

  /// Returns a hash code for this offset date and time.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a hash code for this offset date and time.
  @override
  int get hashCode => HashCodeHelper.HashStatic(_localDate, _offsetTime);

  /// Compares two [OffsetDateTime] values for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The object to compare this date with.
  ///
  /// Returns true if the given value is another offset date/time equal to this one; false otherwise.
  @override
  bool operator ==(Object other) => other is OffsetDateTime && Equals(other);

  /// Compares two [OffsetDateTime] values for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The value to compare this offset date/time with.
  ///
  /// Returns true if the given value is another offset date/time equal to this one; false otherwise.
  bool Equals(OffsetDateTime other) =>
      _localDate == other._localDate && _offsetTime == other._offsetTime;

  /// Deconstruct this [OffsetDateTime] into its components: the [LocalDateTime] component and the [Offset] component.
  ///
  /// (NodaTime's `Deconstruct(out LocalDateTime localDateTime, out Offset offset)`.)
  (nt.LocalDateTime, nt.Offset) get Deconstruct => (LocalDateTime, Offset);

  /// Deconstruct this [OffsetDateTime] into its components: the [LocalDate] component, the [LocalTime] component
  /// and the [Offset] component.
  ///
  /// (NodaTime's `Deconstruct(out LocalDate localDate, out LocalTime localTime, out Offset offset)`.)
  (LocalDate, LocalTime, nt.Offset) get DeconstructLocalDateLocalTimeOffset =>
      (LocalDateTime.Date, LocalDateTime.TimeOfDay, Offset);

  // #region Formatting

  /// Returns a [String] that represents this instance.
  ///
  /// Returns the value of the current instance in the default format pattern ("G"), using the invariant culture
  /// (NodaTime uses the current thread's culture).
  @override
  String toString() => OffsetDateTimePatternPatterns.BclSupport.Format(this, null, NodaCultureInfo.InvariantCulture);

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
      OffsetDateTimePatternPatterns.BclSupport.Format(this, patternText, formatProvider);
  // #endregion Formatting

  // #region Operators

  /// Adds a duration to an offset date and time.
  ///
  /// This is an alternative way of calling the `+` operator.
  ///
  /// [offsetDateTime]: The value to add the duration to.
  /// [duration]: The duration to add
  ///
  /// Returns a new value with the time advanced by the given duration, in the same calendar system and with the same offset.
  static OffsetDateTime Add(OffsetDateTime offsetDateTime, Duration duration) => offsetDateTime + duration;

  /// Returns the result of adding a duration to this offset date and time.
  ///
  /// This is an alternative way of calling the `+` operator.
  ///
  /// [duration]: The duration to add
  ///
  /// Returns a new [OffsetDateTime] representing the result of the addition.
  OffsetDateTime Plus(Duration duration) => this + duration;

  /// Returns the result of adding a increment of hours to this offset date and time
  ///
  /// [hours]: The number of hours to add
  ///
  /// Returns a new [OffsetDateTime] representing the result of the addition.
  OffsetDateTime PlusHours(int hours) => this + Duration.FromHours(hours);

  /// Returns the result of adding an increment of minutes to this offset date and time
  ///
  /// [minutes]: The number of minutes to add
  ///
  /// Returns a new [OffsetDateTime] representing the result of the addition.
  OffsetDateTime PlusMinutes(int minutes) => this + Duration.FromMinutes(minutes);

  /// Returns the result of adding an increment of seconds to this offset date and time
  ///
  /// [seconds]: The number of seconds to add
  ///
  /// Returns a new [OffsetDateTime] representing the result of the addition.
  OffsetDateTime PlusSeconds(int seconds) => this + Duration.FromSeconds(seconds);

  /// Returns the result of adding an increment of milliseconds to this offset date and time
  ///
  /// [milliseconds]: The number of milliseconds to add
  ///
  /// Returns a new [OffsetDateTime] representing the result of the addition.
  OffsetDateTime PlusMilliseconds(int milliseconds) => this + Duration.FromMilliseconds(milliseconds);

  /// Returns the result of adding an increment of ticks to this offset date and time
  ///
  /// [ticks]: The number of ticks to add
  ///
  /// Returns a new [OffsetDateTime] representing the result of the addition.
  OffsetDateTime PlusTicks(int ticks) => this + Duration.FromTicks(ticks);

  /// Returns the result of adding an increment of nanoseconds to this offset date and time
  ///
  /// [nanoseconds]: The number of nanoseconds to add
  ///
  /// Returns a new [OffsetDateTime] representing the result of the addition.
  OffsetDateTime PlusNanoseconds(int nanoseconds) => this + Duration.FromNanoseconds(nanoseconds);

  /// Returns a new [OffsetDateTime] with the time advanced by the given duration.
  ///
  /// The returned value retains the calendar system and offset of this value.
  ///
  /// [duration]: The duration to add.
  ///
  /// Returns a new value with the time advanced by the given duration, in the same calendar system and with the same offset.
  OffsetDateTime operator +(Duration duration) =>
      OffsetDateTime.NewInstantOffset(ToInstant() + duration, Offset);

  /// Subtracts a duration from an offset date and time.
  ///
  /// This is an alternative way of calling the `-` operator.
  ///
  /// [offsetDateTime]: The value to subtract the duration from.
  /// [duration]: The duration to subtract.
  ///
  /// Returns a new value with the time "rewound" by the given duration, in the same calendar system and with the same offset.
  static OffsetDateTime Subtract(OffsetDateTime offsetDateTime, Duration duration) => offsetDateTime - duration;

  /// Returns the result of subtracting a duration from this offset date and time, for a fluent alternative to
  /// the `-` operator.
  ///
  /// [duration]: The duration to subtract
  ///
  /// Returns a new [OffsetDateTime] representing the result of the subtraction.
  OffsetDateTime Minus(Duration duration) => this - duration;

  /// Returns a new [OffsetDateTime] with the duration subtracted.
  ///
  /// The returned value retains the calendar system and offset of this value.
  ///
  /// [duration]: The duration to subtract.
  ///
  /// Returns a new value with the time "rewound" by the given duration, in the same calendar system and with the same offset.
  OffsetDateTime operator -(Duration duration) =>
      // noda_dart: Instant - Duration is MinusDuration.
      OffsetDateTime.NewInstantOffset(ToInstant().MinusDuration(duration), Offset);

  /// Subtracts one offset date and time from another, returning an elapsed duration.
  ///
  /// This is an alternative way of calling [MinusOffsetDateTime]. (NodaTime's `Subtract(OffsetDateTime, OffsetDateTime)`.)
  ///
  /// [end]: The offset date and time value to subtract from; if this is later than [start]
  /// then the result will be positive.
  /// [start]: The offset date and time to subtract from [end].
  ///
  /// Returns the elapsed duration from [start] to [end].
  static Duration SubtractOffsetDateTime(OffsetDateTime end, OffsetDateTime start) => _OperatorMinus(end, start);

  /// Returns the result of subtracting another offset date and time from this one, resulting in the elapsed duration
  /// between the two instants represented in the values.
  ///
  /// (C#'s `Minus(OffsetDateTime)`.)
  ///
  /// [other]: The offset date and time to subtract from this one.
  ///
  /// Returns the elapsed duration from [other] to this value.
  Duration MinusOffsetDateTime(OffsetDateTime other) => _OperatorMinus(this, other);

  /// Subtracts one [OffsetDateTime] from another, resulting in the elapsed time between
  /// the two values.
  ///
  /// (C#'s `operator -(OffsetDateTime, OffsetDateTime)`.)
  ///
  /// This is equivalent to `end.ToInstant() - start.ToInstant()`; in particular:
  /// - The two values can use different calendar systems
  /// - The two values can have different UTC offsets
  ///
  /// [end]: The offset date and time value to subtract from; if this is later than [start]
  /// then the result will be positive.
  /// [start]: The offset date and time to subtract from [end].
  ///
  /// Returns the elapsed duration from [start] to [end].
  static Duration _OperatorMinus(OffsetDateTime end, OffsetDateTime start) => end.ToInstant() - start.ToInstant();

  // operator == and != (static): Dart's == above, and its !=.
  // #endregion

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable.GetSchema/ReadXml/WriteXml (XML serialization)
  // #endregion

  // #region JSON (noda_dart)

  /// Formats this value with [OffsetDateTimePattern.Rfc3339], as NodaTime.Serialization.SystemTextJson does.
  String toJson() => OffsetDateTimePattern.Rfc3339.Format(this);

  /// Parses a value written by [toJson], in [calendar] (default ISO).
  ///
  /// Throws [UnparsableValueException] if the text could not be parsed.
  factory OffsetDateTime.fromJson(String json, [CalendarSystem? calendar]) {
    final pattern = OffsetDateTimePattern.Rfc3339;
    return (calendar == null ? pattern : pattern.WithCalendar(calendar)).Parse(json).Value;
  }
  // #endregion
}

// #region Comparers

/// Base class for [OffsetDateTime] comparers. (NodaTime's `OffsetDateTime.Comparer`.)
///
/// Use the static properties of this class to obtain instances. This type is exposed so that the
/// same value can be used for both equality and ordering comparisons.
abstract class OffsetDateTimeComparer implements IComparer<OffsetDateTime>, IEqualityComparer<OffsetDateTime> {
  // TODO(feature): Should we have a comparer which is calendar-sensitive (so will fail if the calendars are different)
  // but still uses the offset?

  /// Gets a comparer which compares [OffsetDateTime] values by their local date/time, without reference to
  /// the offset. Comparisons between two values of different calendar systems will fail with [ArgumentError].
  ///
  /// For example, this comparer considers 2013-03-04T20:21:00+0100 to be later than 2013-03-04T19:21:00-0700 even though
  /// the second value represents a later instant in time.
  ///
  /// This property will return a reference to the same instance every time it is called.
  static OffsetDateTimeComparer get Local => _OffsetDateTimeLocalComparer.Instance;

  /// Returns a comparer which compares [OffsetDateTime] values by the instant values obtained by applying the offset to
  /// the local date/time, ignoring the calendar system.
  ///
  /// For example, this comparer considers 2013-03-04T20:21:00+0100 to be earlier than 2013-03-04T19:21:00-0700 even though
  /// the second value has a local time which is earlier.
  ///
  /// This property will return a reference to the same instance every time it is called.
  static OffsetDateTimeComparer get Instant => _OffsetDateTimeInstantComparer.Instance;

  /// Internal constructor to prevent external classes from deriving from this.
  /// (That means we can add more abstract members in the future.)
  @internal
  OffsetDateTimeComparer.New();

  /// Compares two [OffsetDateTime] values and returns a value indicating whether one is less than, equal to, or greater than the other.
  ///
  /// [x]: The first value to compare.
  /// [y]: The second value to compare.
  ///
  /// Returns a signed integer that indicates the relative values of [x] and [y]: less than zero if [x] is less than
  /// [y]; zero if [x] is equal to [y]; greater than zero if [x] is greater than [y].
  @override
  int Compare(OffsetDateTime x, OffsetDateTime y);

  /// Determines whether the specified `OffsetDateTime` values are equal.
  ///
  /// [x]: The first `OffsetDateTime` to compare.
  /// [y]: The second `OffsetDateTime` to compare.
  ///
  /// Returns `true` if the specified objects are equal; otherwise, `false`.
  @override
  bool Equals(OffsetDateTime x, OffsetDateTime y);

  /// Returns a hash code for the specified `OffsetDateTime`.
  ///
  /// [obj]: The `OffsetDateTime` for which a hash code is to be returned.
  ///
  /// Returns a hash code for the specified value.
  @override
  int GetHashCode(OffsetDateTime obj);
}

/// Implementation for [OffsetDateTimeComparer.Local]
final class _OffsetDateTimeLocalComparer extends OffsetDateTimeComparer {
  static final OffsetDateTimeComparer Instance = _OffsetDateTimeLocalComparer._New();

  _OffsetDateTimeLocalComparer._New() : super.New();

  @override
  int Compare(OffsetDateTime x, OffsetDateTime y) {
    Preconditions.CheckArgument(x.Calendar == y.Calendar, 'y',
        'Only values with the same calendar system can be compared');
    int dateComparison = x.Calendar.Compare(x.YearMonthDay, y.YearMonthDay);
    if (dateComparison != 0) {
      return dateComparison;
    }
    return x.NanosecondOfDay.compareTo(y.NanosecondOfDay);
  }

  @override
  bool Equals(OffsetDateTime x, OffsetDateTime y) =>
      x._localDate == y._localDate && x.NanosecondOfDay == y.NanosecondOfDay;

  @override
  int GetHashCode(OffsetDateTime obj) => HashCodeHelper.HashStatic(obj._localDate, obj.NanosecondOfDay);
}

/// Implementation for [OffsetDateTimeComparer.Instant].
final class _OffsetDateTimeInstantComparer extends OffsetDateTimeComparer {
  static final OffsetDateTimeComparer Instance = _OffsetDateTimeInstantComparer._New();

  _OffsetDateTimeInstantComparer._New() : super.New();

  @override
  int Compare(OffsetDateTime x, OffsetDateTime y) =>
      // TODO(optimization): Optimize cases which are more than 2 days apart, by avoiding the arithmetic?
      x._ToElapsedTimeSinceEpoch().compareTo(y._ToElapsedTimeSinceEpoch());

  @override
  bool Equals(OffsetDateTime x, OffsetDateTime y) =>
      x._ToElapsedTimeSinceEpoch() == y._ToElapsedTimeSinceEpoch();

  @override
  int GetHashCode(OffsetDateTime obj) => obj._ToElapsedTimeSinceEpoch().hashCode;
}
// #endregion
