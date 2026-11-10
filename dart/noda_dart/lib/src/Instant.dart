// Ported from NodaTime 6e024dde: src/NodaTime/Instant.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:core';
import 'dart:core' as core;

import 'package:meta/meta.dart';

import 'CalendarSystem.dart';
import 'DateTimeZone.dart';
import 'Duration.dart';
import 'Globalization/NodaCultureInfo.dart';
import 'LocalDate.dart';
import 'LocalInstant.dart';
import 'LocalTime.dart';
import 'NodaConstants.dart';
import 'Offset.dart';
import 'OffsetDateTime.dart';
import 'OffsetTime.dart';
import 'Text/InstantPattern.dart';
import 'Utility/Preconditions.dart';
import 'Utility/SystemExceptions.dart';
import 'Utility/TickArithmetic.dart';
import 'ZonedDateTime.dart';

const int _MinTicks = Instant.MinDays * NodaConstants.TicksPerDay;
const int _MaxTicks = (Instant.MaxDays + 1) * NodaConstants.TicksPerDay - 1;
const int _MinMilliseconds = Instant.MinDays * NodaConstants.MillisecondsPerDay;
const int _MaxMilliseconds = (Instant.MaxDays + 1) * NodaConstants.MillisecondsPerDay - 1;
const int _MinSeconds = Instant.MinDays * NodaConstants.SecondsPerDay;
const int _MaxSeconds = (Instant.MaxDays + 1) * NodaConstants.SecondsPerDay - 1;

/// Represents an instant on the global timeline, with nanosecond resolution.
///
/// An [Instant] has no concept of a particular time zone or calendar: it simply represents a point in
/// time that can be globally agreed-upon.
///
/// Equality and ordering comparisons are defined in the natural way, with earlier points on the timeline
/// being considered "less than" later points.
///
/// The default value of this type is [NodaConstants.UnixEpoch], i.e. the instant
/// which can be represented as 1970-01-01T00:00:00Z in the ISO calendar.
///
/// This type is an immutable value type. See the thread safety section of the user guide for more information.
final class Instant implements Comparable<Instant> {
  // These correspond to -9998-01-01 and 9999-12-31 respectively.
  @internal
  static const int MinDays = -4371222;
  @internal
  static const int MaxDays = 2932896;

  /// Represents the smallest possible [Instant].
  ///
  /// This value is equivalent to -9998-01-01T00:00:00Z
  static final Instant MinValue = Instant.NewDaysNanoOfDay(MinDays, 0);

  /// Represents the largest possible [Instant].
  ///
  /// This value is equivalent to 9999-12-31T23:59:59.999999999Z
  static final Instant MaxValue = Instant.NewDaysNanoOfDay(MaxDays, NodaConstants.NanosecondsPerDay - 1);

  /// Instant which is invalid *except* for comparison purposes; it is earlier than any valid value.
  /// This must never be exposed.
  @internal
  static final Instant BeforeMinValue = Instant._NewDaysDeliberatelyInvalid(Duration.MinDays, true);

  /// Instant which is invalid *except* for comparison purposes; it is later than any valid value.
  /// This must never be exposed.
  @internal
  static final Instant AfterMaxValue = Instant._NewDaysDeliberatelyInvalid(Duration.MaxDays, true);

  /// Time elapsed since the Unix epoch.
  final Duration _duration;

  /// Constructor which should *only* be used to construct the invalid instances.
  Instant._NewDaysDeliberatelyInvalid(int days, bool deliberatelyInvalid)
      : _duration = Duration.NewDaysNanoOfDay(days, 0);

  /// Constructor which constructs a new instance with the given duration, which
  /// is trusted to be valid. Should only be called from FromTrustedDuration and
  /// FromUntrustedDuration.
  const Instant._NewDuration(Duration duration) : _duration = duration;

  @internal
  factory Instant.NewDaysNanoOfDay(int days, int nanoOfDay) {
    Preconditions.DebugCheckArgumentRange('days', days, MinDays, MaxDays);
    Preconditions.DebugCheckArgumentRange('nanoOfDay', nanoOfDay, 0, NodaConstants.NanosecondsPerDay - 1);
    return Instant._NewDuration(Duration.NewDaysNanoOfDay(days, nanoOfDay));
  }

  /// Creates an Instant with the given duration, with no validation (in release mode).
  @internal
  static Instant FromTrustedDuration(Duration duration) {
    Preconditions.DebugCheckArgumentRange('duration', duration.FloorDays, MinDays, MaxDays);
    return Instant._NewDuration(duration);
  }

  /// Creates an Instant with the given duration, validating that it has a suitable
  /// "day" part. (It is assumed that the nanoOfDay is okay.)
  @internal
  static Instant FromUntrustedDuration(Duration duration) {
    int days = duration.FloorDays;
    if (days < MinDays || days > MaxDays) {
      throw OverflowException('Operation would overflow range of Instant');
    }
    return Instant._NewDuration(duration);
  }

  /// Returns whether or not this is a valid instant. Returns true for all but
  /// [BeforeMinValue] and [AfterMaxValue].
  @internal
  bool get IsValid => DaysSinceEpoch >= MinDays && DaysSinceEpoch <= MaxDays;

  /// Get the elapsed time since the Unix epoch, to nanosecond resolution.
  ///
  /// Returns the elapsed time since the Unix epoch.
  @internal
  Duration get TimeSinceEpoch => _duration;

  /// Number of days since the local unix epoch.
  @internal
  int get DaysSinceEpoch => _duration.FloorDays;

  /// Nanosecond within the day.
  @internal
  int get NanosecondOfDay => _duration.NanosecondOfFloorDay;

  // #region IComparable<Instant> and IComparable Members
  /// Compares the current object with another object of the same type.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [other]: An object to compare with this object.
  ///
  /// Returns a 32-bit signed integer that indicates the relative order of the objects being compared:
  /// less than 0 if this object is less than the [other] parameter, 0 if this object is equal to [other],
  /// and greater than 0 if this object is greater than [other].
  @override
  int compareTo(Instant other) => _duration.compareTo(other._duration);

  /// Implementation of `IComparable.CompareTo` to compare two instants.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// This uses explicit interface implementation to avoid it being called accidentally. The generic implementation should usually be preferred.
  ///
  /// Throws [ArgumentError] if [obj] is non-null but does not refer to an instance of [Instant].
  ///
  /// [obj]: The object to compare this value with.
  ///
  /// Returns the result of comparing this instant with another one; see [compareTo] for general details.
  /// If [obj] is null, this method returns a value greater than 0.
  int CompareTo(Object? obj) {
    if (obj == null) {
      return 1;
    }
    Preconditions.CheckArgument(obj is Instant, 'obj', 'Object must be of type NodaTime.Instant.');
    return compareTo(obj as Instant);
  }
  // #endregion

  // #region Object overrides
  /// Determines whether the specified object is equal to this instance.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The object to compare with this instance.
  ///
  /// Returns `true` if the specified object is equal to this instance;
  /// otherwise, `false`.
  @override
  bool operator ==(Object other) => other is Instant && Equals(other);

  /// Returns a hash code for this instance.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a hash code for this instance, suitable for use in hashing algorithms and data
  /// structures like a hash table.
  @override
  int get hashCode => _duration.hashCode;
  // #endregion  // Object overrides

  /// Returns a new value of this instant with the given number of ticks added to it.
  ///
  /// [ticks]: The ticks to add to this instant to create the return value.
  ///
  /// Returns the result of adding the given number of ticks to this instant.
  Instant PlusTicks(int ticks) => FromUntrustedDuration(_duration + Duration.FromTicks(ticks));

  /// Returns a new value of this instant with the given number of nanoseconds added to it.
  ///
  /// [nanoseconds]: The nanoseconds to add to this instant to create the return value.
  ///
  /// Returns the result of adding the given number of ticks to this instant.
  Instant PlusNanoseconds(int nanoseconds) => FromUntrustedDuration(_duration + Duration.FromNanoseconds(nanoseconds));

  // #region Operators
  /// Implements the operator + (addition) for [Instant] + [Duration].
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Instant] representing the sum of the given values.
  Instant operator +(Duration right) => FromUntrustedDuration(_duration + right);

  /// Adds the given offset to this instant, to return a [LocalInstant].
  /// A positive offset indicates that the local instant represents a "later local time" than the UTC
  /// representation of this instant.
  ///
  /// This was previously an operator+ implementation, but operators can't be internal.
  ///
  /// (C#'s internal `Plus(Offset)`: renamed, so that the public `Plus(Duration)` keeps its name.)
  ///
  /// [offset]: The right hand side of the operator.
  ///
  /// Returns a new [LocalInstant] representing the sum of the given values.
  @internal
  LocalInstant PlusOffset(Offset offset) => LocalInstant.NewNanoseconds(_duration.PlusSmallNanoseconds(offset.Nanoseconds));

  /// Adds the given offset to this instant, either returning a normal LocalInstant,
  /// or [LocalInstant.BeforeMinValue] or [LocalInstant.AfterMaxValue]
  /// if the value would overflow.
  @internal
  LocalInstant SafePlus(Offset offset) {
    int days = _duration.FloorDays;
    // If we can do the arithmetic safely, do so.
    if (days > MinDays && days < MaxDays) {
      return PlusOffset(offset);
    }
    // Handle BeforeMinValue and BeforeMaxValue simply.
    if (days < MinDays) {
      return LocalInstant.BeforeMinValue;
    }
    if (days > MaxDays) {
      return LocalInstant.AfterMaxValue;
    }
    // Okay, do the arithmetic as a Duration, then check the result for overflow, effectively.
    var asDuration = _duration.PlusSmallNanoseconds(offset.Nanoseconds);
    if (asDuration.FloorDays < Instant.MinDays) {
      return LocalInstant.BeforeMinValue;
    }
    if (asDuration.FloorDays > Instant.MaxDays) {
      return LocalInstant.AfterMaxValue;
    }
    return LocalInstant.NewNanoseconds(asDuration);
  }

  /// Adds a duration to an instant. Friendly alternative to `operator+()`.
  ///
  /// [left]: The left hand side of the operator.
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Instant] representing the sum of the given values.
  static Instant Add(Instant left, Duration right) => left + right;

  /// Returns the result of adding a duration to this instant, for a fluent alternative to `operator+()`.
  ///
  /// [duration]: The duration to add
  ///
  /// Returns a new [Instant] representing the result of the addition.
  Instant Plus(Duration duration) => this + duration;

  /// Implements the operator - (subtraction) for [Instant] - [Instant].
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Duration] representing the difference of the given values.
  Duration operator -(Instant right) => _duration - right._duration;

  // C#'s operator -(Instant, Duration) is only a method in Dart (Dart's operator - takes an Instant): MinusDuration.

  /// Subtracts one instant from another. Friendly alternative to `operator-()`.
  ///
  /// [left]: The left hand side of the operator.
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Duration] representing the difference of the given values.
  static Duration Subtract(Instant left, Instant right) => left - right;

  /// Returns the result of subtracting another instant from this one, for a fluent alternative to `operator-()`.
  ///
  /// [other]: The other instant to subtract
  ///
  /// Returns a new [Instant] representing the result of the subtraction.
  Duration Minus(Instant other) => this - other;

  /// Subtracts a duration from an instant. Friendly alternative to `operator-()`.
  ///
  /// (C#'s `Subtract(Instant, Duration)`.)
  ///
  /// [left]: The left hand side of the operator.
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Instant] representing the difference of the given values.
  static Instant SubtractDuration(Instant left, Duration right) => left.MinusDuration(right);

  /// Returns the result of subtracting a duration from this instant, for a fluent alternative to `operator-()`.
  ///
  /// (C#'s `Minus(Duration)`, and `operator -(Instant, Duration)`.)
  ///
  /// [duration]: The duration to subtract
  ///
  /// Returns a new [Instant] representing the result of the subtraction.
  Instant MinusDuration(Duration duration) => FromUntrustedDuration(_duration - duration);

  // C#'s operator == and != are Dart's == (Object overrides, above) and Equals.

  /// Implements the operator &lt; (less than).
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is less than the right value, otherwise `false`.
  bool operator <(Instant right) => _duration < right._duration;

  /// Implements the operator &lt;= (less than or equal).
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is less than or equal to the right value, otherwise `false`.
  bool operator <=(Instant right) => _duration <= right._duration;

  /// Implements the operator &gt; (greater than).
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is greater than the right value, otherwise `false`.
  bool operator >(Instant right) => _duration > right._duration;

  /// Implements the operator &gt;= (greater than or equal).
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is greater than or equal to the right value, otherwise `false`.
  bool operator >=(Instant right) => _duration >= right._duration;
  // #endregion // Operators

  // #region Convenience methods
  /// Returns a new instant corresponding to the given UTC date and time in the ISO calendar.
  /// In most cases applications should use [ZonedDateTime] to represent a date
  /// and time, but this method is useful in some situations where an [Instant] is
  /// required, such as time zone testing.
  ///
  /// (C#'s two overloads, with and without the second.)
  ///
  /// [year]: The year. This is the "absolute year",
  /// so a value of 0 means 1 BC, for example.
  /// [monthOfYear]: The month of year.
  /// [dayOfMonth]: The day of month.
  /// [hourOfDay]: The hour.
  /// [minuteOfHour]: The minute.
  /// [secondOfMinute]: The second.
  ///
  /// Returns an [Instant] value representing the given date and time in UTC and the ISO calendar.
  static Instant FromUtc(int year, int monthOfYear, int dayOfMonth, int hourOfDay, int minuteOfHour,
      [int secondOfMinute = 0]) {
    var days = LocalDate(year, monthOfYear, dayOfMonth).DaysSinceEpoch;
    var nanoOfDay = LocalTime(hourOfDay, minuteOfHour, secondOfMinute).NanosecondOfDay;
    return Instant.NewDaysNanoOfDay(days, nanoOfDay);
  }

  /// Returns the later instant of the given two.
  ///
  /// [x]: The first instant to compare.
  /// [y]: The second instant to compare.
  ///
  /// Returns the later instant of [x] or [y].
  static Instant Max(Instant x, Instant y) {
    return x > y ? x : y;
  }

  /// Returns the earlier instant of the given two.
  ///
  /// [x]: The first instant to compare.
  /// [y]: The second instant to compare.
  ///
  /// Returns the earlier instant of [x] or [y].
  static Instant Min(Instant x, Instant y) => x < y ? x : y;
  // #endregion

  // #region Formatting
  /// Returns a [String] that represents this instance.
  ///
  /// Returns the value of the current instance in the default format pattern ("g"), using the invariant culture.
  /// (NodaTime uses the current thread's culture.)
  @override
  String toString() => InstantPattern.BclSupport.Format(this, null, NodaCultureInfo.InvariantCulture);

  /// Formats the value of the current instance using the specified pattern.
  ///
  /// (C#'s `ToString(string? patternText, IFormatProvider? formatProvider)`: Dart's `toString` takes no parameters.)
  ///
  /// Returns a [String] containing the value of the current instance in the specified format.
  ///
  /// [patternText]: The [String] specifying the pattern to use,
  /// or null to use the default format pattern ("g").
  /// [formatProvider]: The `IFormatProvider` to use when formatting the value,
  /// or null to use the current thread's culture to obtain a format provider.
  String ToStringPattern(String? patternText, [IFormatProvider? formatProvider]) =>
      InstantPattern.BclSupport.Format(this, patternText, formatProvider);
  // #endregion Formatting

  // #region IEquatable<Instant> Members
  /// Indicates whether the value of this instant is equal to the value of the specified instant.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The value to compare with this instance.
  ///
  /// Returns true if the value of this instant is equal to the value of the [other] parameter;
  /// otherwise, false.
  bool Equals(Instant other) => _duration.Equals(other._duration);
  // #endregion

  /// Returns the Julian Date of this instance - the number of days since
  /// [NodaConstants.JulianEpoch] (noon on January 1st, 4713 BCE in the Julian calendar).
  ///
  /// Returns the number of days (including fractional days) since the Julian Epoch.
  double ToJulianDate() => (this - NodaConstants.JulianEpoch).TotalDays;

  /// Constructs a Dart [core.DateTime] from this Instant which is UTC (`isUtc` is true) and represents the same
  /// instant of time as this value.
  ///
  /// (C#'s `ToDateTimeUtc()`, returning a `DateTime` with a `Kind` of `DateTimeKind.Utc`.)
  ///
  /// If the date and time is not on a tick boundary (the unit of granularity of DateTime) the value will be truncated
  /// towards the start of time. (noda_dart: to the microsecond.)
  ///
  /// Throws [StateError] if the final date/time is outside the range of .NET's `DateTime` (before the year 1).
  ///
  /// Returns a [core.DateTime] representing the same instant in time as this value, in UTC.
  core.DateTime ToDateTimeUtc() {
    if (this < NodaConstants.BclEpoch) {
      throw StateError('Instant out of range for DateTime');
    }
    // C#: new DateTime(BclTicksAtUnixEpoch + ToUnixTimeTicks(), DateTimeKind.Utc)
    // (noda_dart: milliseconds, then microseconds, to stay exact beyond 2^53 on the web.)
    int microsecondOfFloorDay = _duration.NanosecondOfFloorDay ~/ NodaConstants.NanosecondsPerMicrosecond;
    return core.DateTime.fromMillisecondsSinceEpoch(
            _duration.FloorDays * NodaConstants.MillisecondsPerDay +
                microsecondOfFloorDay ~/ core.Duration.microsecondsPerMillisecond,
            isUtc: true)
        .add(core.Duration(microseconds: microsecondOfFloorDay % core.Duration.microsecondsPerMillisecond));
  }

  // Not ported: ToDateTimeOffset, FromDateTimeOffset (Dart has no DateTimeOffset)

  /// Converts a Julian Date representing the given number of days
  /// since [NodaConstants.JulianEpoch] (noon on January 1st, 4713 BCE in the Julian calendar)
  /// into an [Instant].
  ///
  /// [julianDate]: The number of days since the Julian Epoch to convert into an [Instant].
  ///
  /// Returns an [Instant] value which is [julianDate] days after the Julian Epoch.
  static Instant FromJulianDate(double julianDate) => NodaConstants.JulianEpoch + Duration.FromDaysDouble(julianDate);

  /// Converts a Dart [core.DateTime] into a new Instant representing the same instant in time.
  ///
  /// (C#'s `FromDateTimeUtc(DateTime)`; `DateTimeKind.Utc` is `isUtc`.)
  ///
  /// Returns an [Instant] value representing the same instant in time as the given UTC [core.DateTime].
  ///
  /// [dateTime]: Date and time value which must be UTC (`isUtc`)
  ///
  /// Throws [ArgumentError] if [dateTime] is not UTC.
  /// Throws [RangeError] if [dateTime] is outside the range of [Instant] (a Dart `DateTime`'s range is wider).
  static Instant FromDateTimeUtc(core.DateTime dateTime) {
    Preconditions.CheckArgument(dateTime.isUtc, 'dateTime', 'Invalid DateTime.Kind for Instant.FromDateTimeUtc');
    // C#: return BclEpoch.PlusTicks(dateTime.Ticks);
    // (noda_dart: seconds, then microseconds, to stay exact beyond 2^53 on the web.)
    int microsecondOfSecond = dateTime.millisecond * core.Duration.microsecondsPerMillisecond + dateTime.microsecond;
    int seconds = core.DateTime.utc(dateTime.year, dateTime.month, dateTime.day, dateTime.hour, dateTime.minute,
                dateTime.second)
            .millisecondsSinceEpoch ~/
        core.Duration.millisecondsPerSecond;
    return FromUnixTimeSeconds(seconds).PlusNanoseconds(microsecondOfSecond * NodaConstants.NanosecondsPerMicrosecond);
  }

  /// Initializes a new instance of the [Instant] struct based
  /// on a number of seconds since the Unix epoch of (ISO) January 1st 1970, midnight, UTC.
  ///
  /// [seconds]: Number of seconds since the Unix epoch. May be negative (for instants before the epoch).
  ///
  /// Returns an [Instant] at exactly the given number of seconds since the Unix epoch.
  ///
  /// Throws [RangeError] if the constructed instant would be out of the range representable in Noda Time.
  static Instant FromUnixTimeSeconds(int seconds) {
    Preconditions.CheckArgumentRange('seconds', seconds, _MinSeconds, _MaxSeconds);
    return Instant.FromTrustedDuration(Duration.FromSeconds(seconds));
  }

  /// Initializes a new instance of the [Instant] struct based
  /// on a number of milliseconds since the Unix epoch of (ISO) January 1st 1970, midnight, UTC.
  ///
  /// [milliseconds]: Number of milliseconds since the Unix epoch. May be negative (for instants before the epoch).
  ///
  /// Returns an [Instant] at exactly the given number of milliseconds since the Unix epoch.
  ///
  /// Throws [RangeError] if the constructed instant would be out of the range representable in Noda Time.
  static Instant FromUnixTimeMilliseconds(int milliseconds) {
    Preconditions.CheckArgumentRange('milliseconds', milliseconds, _MinMilliseconds, _MaxMilliseconds);
    return Instant.FromTrustedDuration(Duration.FromMilliseconds(milliseconds));
  }

  /// Initializes a new instance of the [Instant] struct based
  /// on a number of ticks since the Unix epoch of (ISO) January 1st 1970, midnight, UTC.
  ///
  /// Returns an [Instant] at exactly the given number of ticks since the Unix epoch.
  ///
  /// [ticks]: Number of ticks since the Unix epoch. May be negative (for instants before the epoch).
  static Instant FromUnixTimeTicks(int ticks) {
    Preconditions.CheckArgumentRange('ticks', ticks, _MinTicks, _MaxTicks);
    return Instant.FromTrustedDuration(Duration.FromTicks(ticks));
  }

  /// Gets the number of seconds since the Unix epoch. Negative values represent instants before the Unix epoch.
  ///
  /// If the number of nanoseconds in this instant is not an exact number of seconds, the value is truncated towards the start of time.
  ///
  /// Returns the number of seconds since the Unix epoch.
  int ToUnixTimeSeconds() =>
      _duration.FloorDays * NodaConstants.SecondsPerDay +
      _duration.NanosecondOfFloorDay ~/ NodaConstants.NanosecondsPerSecond;

  /// Gets the number of seconds since the Unix epoch, along with remaining nanoseconds.
  /// Negative values for seconds represent instants before the Unix epoch.
  ///
  /// If the number of nanoseconds in this instant is not an exact number of seconds
  /// the seconds part of the returned value is truncated towards the start of time, ensuring that
  /// the nanoseconds part is always non-negative. The seconds part of the returned value is always
  /// the same as would be returned by [ToUnixTimeSeconds].
  ///
  /// The inverse of this operation is to first call [FromUnixTimeSeconds] and then
  /// call [PlusNanoseconds] on the returned [Instant].
  ///
  /// Returns the number of seconds and remaining nanoseconds since the Unix epoch.
  ({int seconds, int nanoseconds}) ToUnixTimeSecondsAndNanoseconds() {
    var secondOfDay = _duration.NanosecondOfFloorDay ~/ NodaConstants.NanosecondsPerSecond;
    var nanosecondOfSecond = _duration.NanosecondOfFloorDay.remainder(NodaConstants.NanosecondsPerSecond);
    return (
      seconds: (NodaConstants.SecondsPerDay * _duration.FloorDays) + secondOfDay,
      nanoseconds: nanosecondOfSecond
    );
  }

  /// Gets the number of milliseconds since the Unix epoch. Negative values represent instants before the Unix epoch.
  ///
  /// If the number of nanoseconds in this instant is not an exact number of milliseconds, the value is truncated towards the start of time.
  ///
  /// Returns the number of milliseconds since the Unix epoch.
  int ToUnixTimeMilliseconds() =>
      _duration.FloorDays * NodaConstants.MillisecondsPerDay +
      _duration.NanosecondOfFloorDay ~/ NodaConstants.NanosecondsPerMillisecond;

  /// Gets the number of ticks since the Unix epoch. Negative values represent instants before the Unix epoch.
  ///
  /// A tick is equal to 100 nanoseconds. There are 10,000 ticks in a millisecond. If the number of nanoseconds
  /// in this instant is not an exact number of ticks, the value is truncated towards the start of time.
  ///
  /// Returns the number of ticks since the Unix epoch.
  int ToUnixTimeTicks() => TickArithmetic.BoundedDaysAndTickOfDayToTicks(
      _duration.FloorDays, _duration.NanosecondOfFloorDay ~/ NodaConstants.NanosecondsPerTick);

  /// Returns the [ZonedDateTime] representing the same point in time as this instant, in the UTC time
  /// zone and ISO-8601 calendar. This is a shortcut for calling [InZone] with an
  /// argument of [DateTimeZone.Utc].
  ///
  /// Returns a [ZonedDateTime] for the same instant, in the UTC time zone
  /// and the ISO-8601 calendar
  ZonedDateTime InUtc() {
    // Bypass any determination of offset and arithmetic, as we know the offset is zero.
    var offsetDateTime = OffsetDateTime.NewLocalDateOffsetTime(LocalDate.NewDaysSinceEpoch(_duration.FloorDays),
        OffsetTime.NewNanosecondOfDayZeroOffset(_duration.NanosecondOfFloorDay));
    return ZonedDateTime.NewOffsetDateTimeZone(offsetDateTime, DateTimeZone.Utc);
  }

  /// Returns the [ZonedDateTime] representing the same point in time as this instant, in the
  /// specified time zone and calendar system (the ISO-8601 calendar if [calendar] is omitted).
  ///
  /// (C#'s `InZone(DateTimeZone)` and `InZone(DateTimeZone, CalendarSystem)`.)
  ///
  /// [zone]: The time zone in which to represent this instant.
  /// [calendar]: The calendar system in which to represent this instant.
  ///
  /// Returns a [ZonedDateTime] for the same instant, in the given time zone
  /// and calendar
  ZonedDateTime InZone(DateTimeZone zone, [CalendarSystem? calendar]) {
    if (calendar == null) {
      // zone is checked for nullity by the constructor.
      return ZonedDateTime(this, zone);
    }
    // Dart: null safety checks zone and calendar.
    return ZonedDateTime(this, zone, calendar);
  }

  /// Returns the [OffsetDateTime] representing the same point in time as this instant, with
  /// the specified UTC offset and calendar system (the ISO calendar system if [calendar] is omitted).
  ///
  /// (C#'s `WithOffset(Offset)` and `WithOffset(Offset, CalendarSystem)`.)
  ///
  /// [offset]: The offset from UTC with which to represent this instant.
  /// [calendar]: The calendar system in which to represent this instant.
  ///
  /// Returns an [OffsetDateTime] for the same instant, with the given offset
  /// and calendar
  OffsetDateTime WithOffset(Offset offset, [CalendarSystem? calendar]) {
    if (calendar == null) {
      return OffsetDateTime.NewInstantOffset(this, offset);
    }
    // Dart: null safety checks calendar.
    return OffsetDateTime.NewInstantOffsetCalendar(this, offset, calendar);
  }

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable members (XML serialization)
  // #endregion

  // #region JSON (noda_dart)
  /// Formats this value with [InstantPattern.ExtendedIso], as NodaTime.Serialization.SystemTextJson does.
  String toJson() => InstantPattern.ExtendedIso.Format(this);

  /// Parses a value written by [toJson].
  ///
  /// Throws [UnparsableValueException] if the text could not be parsed.
  factory Instant.fromJson(String json) => InstantPattern.ExtendedIso.Parse(json).Value;
  // #endregion
}
