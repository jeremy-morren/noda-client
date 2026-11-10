// Ported from NodaTime 6e024dde: src/NodaTime/LocalTime.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'Fields/TimePeriodField.dart';
import 'Globalization/NodaCultureInfo.dart';
import 'LocalDate.dart';
import 'LocalDateTime.dart';
import 'NodaConstants.generated.dart';
import 'Offset.dart';
import 'OffsetTime.dart';
import 'Period.dart';
import 'Text/LocalTimePattern.dart';
import 'Utility/Checked.dart';
import 'Utility/Preconditions.dart';

// Note: documentation that refers to the LocalDateTime type within this class must use the fully-qualified
// reference to avoid being resolved to the LocalDateTime property instead.

/// LocalTime is an immutable struct representing a time of day, with no reference
/// to a particular calendar, time zone or date.
///
/// Ordering and equality are defined in the natural way, simply comparing the number of "nanoseconds since midnight".
///
/// The default value of this type is [Midnight].
///
/// Thread safety: This type is an immutable value type. See the thread safety section of the user guide for more information.
// Not ported: [TypeConverter(typeof(LocalTimeTypeConverter))], [XmlSchemaProvider], IXmlSerializable (not ported, see below)
final class LocalTime implements Comparable<LocalTime> {
  /// Local time at midnight, i.e. 0 hours, 0 minutes, 0 seconds.
  static final LocalTime Midnight = LocalTime(0, 0, 0);

  /// The minimum value of this type; equivalent to [Midnight].
  static LocalTime get MinValue => Midnight;

  /// Local time at noon, i.e. 12 hours, 0 minutes, 0 seconds.
  static final LocalTime Noon = LocalTime(12, 0, 0);

  /// The maximum value of this type, one nanosecond before midnight.
  ///
  /// This is useful if you have to use an inclusive upper bound for some reason.
  /// In general, it's better to use an exclusive upper bound, in which case use midnight of
  /// the following day.
  static final LocalTime MaxValue = LocalTime.NewNanoseconds(NanosecondsPerDay - 1);

  /// Nanoseconds since midnight, in the range [0, 86,400,000,000,000).
  final int _nanoseconds;

  /// Creates a local time at the given hour and minute, and optionally second and millisecond, with the other values
  /// (second, millisecond-of-second and tick-of-millisecond) zero.
  ///
  /// [hour]: The hour of day.
  /// [minute]: The minute of the hour.
  /// [second]: The second of the minute.
  /// [millisecond]: The millisecond of the second.
  ///
  /// Throws [RangeError] if the parameters do not form a valid time.
  ///
  /// Returns the resulting time.
  // noda_dart: C#'s LocalTime(hour, minute[, second[, millisecond]]).
  factory LocalTime(int hour, int minute, [int second = 0, int millisecond = 0]) {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (hour < 0 || hour > HoursPerDay - 1 ||
        minute < 0 || minute > MinutesPerHour - 1 ||
        second < 0 || second > SecondsPerMinute - 1 ||
        millisecond < 0 || millisecond > MillisecondsPerSecond - 1) {
      Preconditions.CheckArgumentRange('hour', hour, 0, HoursPerDay - 1);
      Preconditions.CheckArgumentRange('minute', minute, 0, MinutesPerHour - 1);
      Preconditions.CheckArgumentRange('second', second, 0, SecondsPerMinute - 1);
      Preconditions.CheckArgumentRange('millisecond', millisecond, 0, MillisecondsPerSecond - 1);
    }
    return LocalTime._NewNanosecondsUnchecked(
        hour * NanosecondsPerHour +
        minute * NanosecondsPerMinute +
        second * NanosecondsPerSecond +
        millisecond * NanosecondsPerMillisecond);
  }

  /// Factory method to create a local time at the given hour, minute, second, millisecond and tick within millisecond.
  ///
  /// [hour]: The hour of day.
  /// [minute]: The minute of the hour.
  /// [second]: The second of the minute.
  /// [millisecond]: The millisecond of the second.
  /// [tickWithinMillisecond]: The tick within the millisecond.
  ///
  /// Throws [RangeError] if the parameters do not form a valid time.
  ///
  /// Returns the resulting time.
  static LocalTime FromHourMinuteSecondMillisecondTick(int hour, int minute, int second, int millisecond, int tickWithinMillisecond) {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (hour < 0 || hour > HoursPerDay - 1 ||
        minute < 0 || minute > MinutesPerHour - 1 ||
        second < 0 || second > SecondsPerMinute - 1 ||
        millisecond < 0 || millisecond > MillisecondsPerSecond - 1 ||
        tickWithinMillisecond < 0 || tickWithinMillisecond > TicksPerMillisecond - 1) {
      Preconditions.CheckArgumentRange('hour', hour, 0, HoursPerDay - 1);
      Preconditions.CheckArgumentRange('minute', minute, 0, MinutesPerHour - 1);
      Preconditions.CheckArgumentRange('second', second, 0, SecondsPerMinute - 1);
      Preconditions.CheckArgumentRange('millisecond', millisecond, 0, MillisecondsPerSecond - 1);
      Preconditions.CheckArgumentRange('tickWithinMillisecond', tickWithinMillisecond, 0, TicksPerMillisecond - 1);
    }
    int nanoseconds =
        hour * NanosecondsPerHour +
        minute * NanosecondsPerMinute +
        second * NanosecondsPerSecond +
        millisecond * NanosecondsPerMillisecond +
        tickWithinMillisecond * NanosecondsPerTick;
    return LocalTime.NewNanoseconds(nanoseconds);
  }

  /// Factory method for creating a local time from the hour of day, minute of hour, second of minute, and tick of second.
  ///
  /// This is not a constructor overload as it would have the same signature as the one taking millisecond of second.
  ///
  /// [hour]: The hour of day in the desired time, in the range [0, 23].
  /// [minute]: The minute of hour in the desired time, in the range [0, 59].
  /// [second]: The second of minute in the desired time, in the range [0, 59].
  /// [tickWithinSecond]: The tick within the second in the desired time, in the range [0, 9999999].
  ///
  /// Throws [RangeError] if the parameters do not form a valid time.
  ///
  /// Returns the resulting time.
  static LocalTime FromHourMinuteSecondTick(int hour, int minute, int second, int tickWithinSecond) {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (hour < 0 || hour > HoursPerDay - 1 ||
        minute < 0 || minute > MinutesPerHour - 1 ||
        second < 0 || second > SecondsPerMinute - 1 ||
        tickWithinSecond < 0 || tickWithinSecond > TicksPerSecond - 1) {
      Preconditions.CheckArgumentRange('hour', hour, 0, HoursPerDay - 1);
      Preconditions.CheckArgumentRange('minute', minute, 0, MinutesPerHour - 1);
      Preconditions.CheckArgumentRange('second', second, 0, SecondsPerMinute - 1);
      Preconditions.CheckArgumentRange('tickWithinSecond', tickWithinSecond, 0, TicksPerSecond - 1);
    }
    return LocalTime.NewNanoseconds(
        hour * NanosecondsPerHour +
        minute * NanosecondsPerMinute +
        second * NanosecondsPerSecond +
        tickWithinSecond * NanosecondsPerTick);
  }

  /// Factory method for creating a local time from the hour of day, minute of hour, second of minute, and nanosecond of second.
  ///
  /// This is not a constructor overload as it would have the same signature as the one taking millisecond of second.
  ///
  /// [hour]: The hour of day in the desired time, in the range [0, 23].
  /// [minute]: The minute of hour in the desired time, in the range [0, 59].
  /// [second]: The second of minute in the desired time, in the range [0, 59].
  /// [nanosecondWithinSecond]: The nanosecond within the second in the desired time, in the range [0, 999999999].
  ///
  /// Throws [RangeError] if the parameters do not form a valid time.
  ///
  /// Returns the resulting time.
  static LocalTime FromHourMinuteSecondNanosecond(int hour, int minute, int second, int nanosecondWithinSecond) {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (hour < 0 || hour > HoursPerDay - 1 ||
        minute < 0 || minute > MinutesPerHour - 1 ||
        second < 0 || second > SecondsPerMinute - 1 ||
        nanosecondWithinSecond < 0 || nanosecondWithinSecond > NanosecondsPerSecond - 1) {
      Preconditions.CheckArgumentRange('hour', hour, 0, HoursPerDay - 1);
      Preconditions.CheckArgumentRange('minute', minute, 0, MinutesPerHour - 1);
      Preconditions.CheckArgumentRange('second', second, 0, SecondsPerMinute - 1);
      Preconditions.CheckArgumentRange('nanosecondWithinSecond', nanosecondWithinSecond, 0, NanosecondsPerSecond - 1);
    }
    return FromHourMinuteSecondNanosecondTrusted(hour, minute, second, nanosecondWithinSecond);
  }

  /// Factory method for creating a local time from the hour of day, minute of hour, second of minute, and nanosecond of second
  /// where the values have already been validated.
  @internal
  static LocalTime FromHourMinuteSecondNanosecondTrusted(int hour, int minute, int second, int nanosecondWithinSecond) =>
      LocalTime.NewNanoseconds(
          hour * NanosecondsPerHour +
          minute * NanosecondsPerMinute +
          second * NanosecondsPerSecond +
          nanosecondWithinSecond);

  /// Constructor only called from other parts of Noda Time - trusted to be the range [0, NanosecondsPerDay).
  @internal
  factory LocalTime.NewNanoseconds(int nanoseconds) {
    Preconditions.DebugCheckArgumentRange('nanoseconds', nanoseconds, 0, NanosecondsPerDay - 1);
    return LocalTime._NewNanosecondsUnchecked(nanoseconds);
  }

  // noda_dart: the field assignment of NodaTime's constructors (Dart's factory constructors call this).
  LocalTime._NewNanosecondsUnchecked(int nanoseconds) : _nanoseconds = nanoseconds;

  /// Factory method for creating a local time from the number of nanoseconds which have elapsed since midnight.
  ///
  /// [nanoseconds]: The number of nanoseconds, in the range [0, 86,399,999,999,999]
  ///
  /// Returns the resulting time.
  static LocalTime FromNanosecondsSinceMidnight(int nanoseconds) {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (nanoseconds < 0 || nanoseconds > NanosecondsPerDay - 1) {
      Preconditions.CheckArgumentRange('nanoseconds', nanoseconds, 0, NanosecondsPerDay - 1);
    }
    return LocalTime.NewNanoseconds(nanoseconds);
  }

  /// Factory method for creating a local time from the number of ticks which have elapsed since midnight.
  ///
  /// [ticks]: The number of ticks, in the range [0, 863,999,999,999]
  ///
  /// Returns the resulting time.
  static LocalTime FromTicksSinceMidnight(int ticks) {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (ticks < 0 || ticks > TicksPerDay - 1) {
      Preconditions.CheckArgumentRange('ticks', ticks, 0, TicksPerDay - 1);
    }
    return LocalTime.NewNanoseconds(ticks * NanosecondsPerTick);
  }

  /// Factory method for creating a local time from the number of milliseconds which have elapsed since midnight.
  ///
  /// [milliseconds]: The number of milliseconds, in the range [0, 86,399,999]
  ///
  /// Returns the resulting time.
  static LocalTime FromMillisecondsSinceMidnight(int milliseconds) {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (milliseconds < 0 || milliseconds > MillisecondsPerDay - 1) {
      Preconditions.CheckArgumentRange('milliseconds', milliseconds, 0, MillisecondsPerDay - 1);
    }
    return LocalTime.NewNanoseconds(milliseconds * NanosecondsPerMillisecond);
  }

  /// Factory method for creating a local time from the number of seconds which have elapsed since midnight.
  ///
  /// [seconds]: The number of seconds, in the range [0, 86,399]
  ///
  /// Returns the resulting time.
  static LocalTime FromSecondsSinceMidnight(int seconds) {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (seconds < 0 || seconds > SecondsPerDay - 1) {
      Preconditions.CheckArgumentRange('seconds', seconds, 0, SecondsPerDay - 1);
    }
    return LocalTime.NewNanoseconds(seconds * NanosecondsPerSecond);
  }

  /// Factory method for creating a local time from the number of minutes which have elapsed since midnight.
  ///
  /// [minutes]: The number of minutes, in the range [0, 1439]
  ///
  /// Returns the resulting time.
  static LocalTime FromMinutesSinceMidnight(int minutes) {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (minutes < 0 || minutes > MinutesPerDay - 1) {
      Preconditions.CheckArgumentRange('minutes', minutes, 0, MinutesPerDay - 1);
    }
    return LocalTime.NewNanoseconds(minutes * NanosecondsPerMinute);
  }

  /// Factory method for creating a local time from the number of hours which have elapsed since midnight.
  ///
  /// [hours]: The number of hours, in the range [0, 23]
  ///
  /// Returns the resulting time.
  static LocalTime FromHoursSinceMidnight(int hours) {
    // Avoid the method calls which give a decent exception unless we're actually going to fail.
    if (hours < 0 || hours > HoursPerDay - 1) {
      Preconditions.CheckArgumentRange('hours', hours, 0, HoursPerDay - 1);
    }
    return LocalTime.NewNanoseconds(hours * NanosecondsPerHour);
  }

  /// Gets the hour of day of this local time, in the range 0 to 23 inclusive.
  int get Hour =>
      // Effectively nanoseconds / NanosecondsPerHour, but apparently rather more efficient.
      // noda_dart: divides directly, as dart2js's shifts are 32-bit.
      _nanoseconds ~/ NanosecondsPerHour;

  /// Gets the hour of the half-day of this local time, in the range 1 to 12 inclusive.
  int get ClockHourOfHalfDay {
    int hourOfHalfDay = Hour.remainder(12);
    return hourOfHalfDay == 0 ? 12 : hourOfHalfDay;
  }

  /// Gets the minute of this local time, in the range 0 to 59 inclusive.
  int get Minute {
    // Effectively nanoseconds / NanosecondsPerMinute, but apparently rather more efficient.
    // noda_dart: divides directly, as dart2js's shifts are 32-bit.
    int minuteOfDay = _nanoseconds ~/ NanosecondsPerMinute;
    return minuteOfDay.remainder(MinutesPerHour);
  }

  /// Gets the second of this local time within the minute, in the range 0 to 59 inclusive.
  int get Second {
    int secondOfDay = _nanoseconds ~/ NanosecondsPerSecond;
    return secondOfDay.remainder(SecondsPerMinute);
  }

  /// Gets the millisecond of this local time within the second, in the range 0 to 999 inclusive.
  int get Millisecond {
    int milliSecondOfDay = _nanoseconds ~/ NanosecondsPerMillisecond;
    return milliSecondOfDay.remainder(MillisecondsPerSecond);
  }

  // TODO(optimization): Rewrite for performance?
  /// Gets the tick of this local time within the second, in the range 0 to 9,999,999 inclusive.
  int get TickOfSecond => TickOfDay.remainder(TicksPerSecond);

  /// Gets the tick of this local time within the day, in the range 0 to 863,999,999,999 inclusive.
  ///
  /// If the value does not fall on a tick boundary, it will be truncated towards zero.
  int get TickOfDay => _nanoseconds ~/ NanosecondsPerTick;

  /// Gets the nanosecond of this local time within the second, in the range 0 to 999,999,999 inclusive.
  int get NanosecondOfSecond => _nanoseconds.remainder(NanosecondsPerSecond);

  /// Gets the nanosecond of this local time within the day, in the range 0 to 86,399,999,999,999 inclusive.
  int get NanosecondOfDay => _nanoseconds;

  /// Creates a new local time by adding a period to an existing time. The period must not contain
  /// any date-related units (days etc) with non-zero values.
  ///
  /// [period]: The period to add
  ///
  /// Returns the result of adding the period to the time, wrapping via midnight if necessary
  LocalTime operator +(Period period) {
    // Dart: null safety checks period.
    Preconditions.CheckArgument(!period.HasDateComponent, 'period', 'Cannot add a period with a date component to a time');
    return PlusHours(period.Hours)
        .PlusMinutes(period.Minutes)
        .PlusSeconds(period.Seconds)
        .PlusMilliseconds(period.Milliseconds)
        .PlusTicks(period.Ticks)
        .PlusNanoseconds(period.Nanoseconds);
  }

  /// Adds the specified period to the time. Friendly alternative to `operator+()`.
  ///
  /// [time]: The time to add the period to
  /// [period]: The period to add. Must not contain any (non-zero) date units.
  ///
  /// Returns the sum of the given time and period
  static LocalTime Add(LocalTime time, Period period) => time + period;

  /// Adds the specified period to this time. Fluent alternative to `operator+()`.
  ///
  /// [period]: The period to add. Must not contain any (non-zero) date units.
  ///
  /// Returns the sum of this time and the given period
  LocalTime Plus(Period period) => this + period;

  /// Creates a new local time by subtracting a period from an existing time. The period must not contain
  /// any date-related units (days etc) with non-zero values.
  /// This is a convenience operator over the [Minus] method.
  ///
  /// [period]: The period to subtract
  ///
  /// Returns the result of subtract the period from the time, wrapping via midnight if necessary
  LocalTime operator -(Period period) {
    // Dart: null safety checks period.
    Preconditions.CheckArgument(!period.HasDateComponent, 'period', 'Cannot subtract a period with a date component from a time');
    return PlusHours(Checked.Negate(period.Hours))
        .PlusMinutes(Checked.Negate(period.Minutes))
        .PlusSeconds(Checked.Negate(period.Seconds))
        .PlusMilliseconds(Checked.Negate(period.Milliseconds))
        .PlusTicks(Checked.Negate(period.Ticks))
        .PlusNanoseconds(Checked.Negate(period.Nanoseconds));
  }

  /// Subtracts the specified period from the time. Friendly alternative to `operator-()`.
  ///
  /// [time]: The time to subtract the period from
  /// [period]: The period to subtract. Must not contain any (non-zero) date units.
  ///
  /// Returns the result of subtracting the given period from the time.
  static LocalTime Subtract(LocalTime time, Period period) => time - period;

  /// Subtracts the specified period from this time. Fluent alternative to `operator-()`.
  ///
  /// [period]: The period to subtract. Must not contain any (non-zero) date units.
  ///
  /// Returns the result of subtracting the given period from this time.
  LocalTime Minus(Period period) => this - period;

  // noda_dart: C#'s operator -(LocalTime, LocalTime) is SubtractLocalTime/MinusLocalTime, as `-` takes a Period.

  /// Subtracts one time from another, returning the result as a [Period] with units of years, months and days.
  ///
  /// This is simply a convenience method for calling [Period.BetweenLocalTime].
  ///
  /// [lhs]: The time to subtract from
  /// [rhs]: The time to subtract
  ///
  /// Returns the result of subtracting one time from another.
  // noda_dart: C#'s Subtract(LocalTime lhs, LocalTime rhs).
  static Period SubtractLocalTime(LocalTime lhs, LocalTime rhs) => Period.BetweenLocalTime(rhs, lhs);

  /// Subtracts the specified time from this time, returning the result as a [Period].
  /// Fluent alternative to `operator-()`.
  ///
  /// [time]: The time to subtract from this
  ///
  /// Returns the difference between the specified time and this one
  // noda_dart: C#'s Minus(LocalTime time).
  Period MinusLocalTime(LocalTime time) => SubtractLocalTime(this, time);

  /// Compares two local times for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns true if the two times are the same; false otherwise
  // noda_dart: C#'s operator ==(LocalTime, LocalTime) and Equals(object); `!=` is Dart's.
  @override
  bool operator ==(Object other) => other is LocalTime && _nanoseconds == other._nanoseconds;

  /// Compares two LocalTime values to see if the left one is strictly earlier than the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Returns true if this value is strictly earlier than [rhs], false otherwise.
  bool operator <(LocalTime rhs) => _nanoseconds < rhs._nanoseconds;

  /// Compares two LocalTime values to see if the left one is earlier than or equal to the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Returns true if this value is earlier than or equal to [rhs], false otherwise.
  bool operator <=(LocalTime rhs) => _nanoseconds <= rhs._nanoseconds;

  /// Compares two LocalTime values to see if the left one is strictly later than the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Returns true if this value is strictly later than [rhs], false otherwise.
  bool operator >(LocalTime rhs) => _nanoseconds > rhs._nanoseconds;

  /// Compares two LocalTime values to see if the left one is later than or equal to the right one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [rhs]: Second operand of the comparison
  ///
  /// Returns true if this value is later than or equal to [rhs], false otherwise.
  bool operator >=(LocalTime rhs) => _nanoseconds >= rhs._nanoseconds;

  /// Indicates whether this time is earlier, later or the same as another one.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [other]: The other date/time to compare this one with
  ///
  /// Returns a value less than zero if this time is earlier than [other];
  /// zero if this time is the same as [other]; a value greater than zero if this time is
  /// later than [other].
  @override
  int compareTo(LocalTime other) => _nanoseconds.compareTo(other._nanoseconds);

  /// Implementation of `IComparable.CompareTo` to compare two LocalTimes.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// This uses explicit interface implementation to avoid it being called accidentally. The generic implementation should usually be preferred.
  ///
  /// Throws [ArgumentError] if [obj] is non-null but does not refer to an instance of [LocalTime].
  ///
  /// [obj]: The object to compare this value with.
  ///
  /// Returns the result of comparing this LocalTime with another one; see [compareTo] for general details.
  /// If [obj] is null, this method returns a value greater than 0.
  int CompareTo(Object? obj) {
    if (obj == null) {
      return 1;
    }
    Preconditions.CheckArgument(obj is LocalTime, 'obj', 'Object must be of type NodaTime.LocalTime.');
    return compareTo(obj as LocalTime);
  }

  /// Returns a hash code for this local time.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a hash code for this local time.
  @override
  int get hashCode => _nanoseconds.hashCode;

  /// Compares this local time with the specified one for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The other local time to compare this one with
  ///
  /// Returns true if the specified time is equal to this one; false otherwise
  bool Equals(LocalTime other) => this == other;

  // noda_dart: C#'s Equals(object) is operator ==, above.

  /// Returns a new LocalTime representing the current value with the given number of hours added.
  ///
  /// If the value goes past the start or end of the day, it wraps - so 11pm plus two hours is 1am, for example.
  ///
  /// [hours]: The number of hours to add
  ///
  /// Returns the current value plus the given number of hours.
  LocalTime PlusHours(int hours) => TimePeriodField.Hours.AddLocalTime(this, hours);

  /// Returns a new LocalTime representing the current value with the given number of minutes added.
  ///
  /// If the value goes past the start or end of the day, it wraps - so 11pm plus 120 minutes is 1am, for example.
  ///
  /// [minutes]: The number of minutes to add
  ///
  /// Returns the current value plus the given number of minutes.
  LocalTime PlusMinutes(int minutes) => TimePeriodField.Minutes.AddLocalTime(this, minutes);

  /// Returns a new LocalTime representing the current value with the given number of seconds added.
  ///
  /// If the value goes past the start or end of the day, it wraps - so 11:59pm plus 120 seconds is 12:01am, for example.
  ///
  /// [seconds]: The number of seconds to add
  ///
  /// Returns the current value plus the given number of seconds.
  LocalTime PlusSeconds(int seconds) => TimePeriodField.Seconds.AddLocalTime(this, seconds);

  /// Returns a new LocalTime representing the current value with the given number of milliseconds added.
  ///
  /// [milliseconds]: The number of milliseconds to add
  ///
  /// Returns the current value plus the given number of milliseconds.
  LocalTime PlusMilliseconds(int milliseconds) => TimePeriodField.Milliseconds.AddLocalTime(this, milliseconds);

  /// Returns a new LocalTime representing the current value with the given number of ticks added.
  ///
  /// [ticks]: The number of ticks to add
  ///
  /// Returns the current value plus the given number of ticks.
  LocalTime PlusTicks(int ticks) => TimePeriodField.Ticks.AddLocalTime(this, ticks);

  /// Returns a new LocalTime representing the current value with the given number of nanoseconds added.
  ///
  /// [nanoseconds]: The number of nanoseconds to add
  ///
  /// Returns the current value plus the given number of ticks.
  LocalTime PlusNanoseconds(int nanoseconds) => TimePeriodField.Nanoseconds.AddLocalTime(this, nanoseconds);

  /// Returns this time, with the given adjuster applied to it.
  ///
  /// If the adjuster attempts to construct an invalid time, any exception thrown by
  /// that construction attempt will be propagated through this method.
  ///
  /// [adjuster]: The adjuster to apply.
  ///
  /// Returns the adjusted time.
  LocalTime With(LocalTime Function(LocalTime) adjuster) {
    // Dart: null safety checks adjuster.
    return adjuster(this);
  }

  /// Returns an [OffsetTime] for this time-of-day with the given offset.
  ///
  /// This method is purely a convenient alternative to calling the [OffsetTime] constructor directly.
  ///
  /// [offset]: The offset to apply.
  ///
  /// Returns the result of this time-of-day offset by the given amount.
  OffsetTime WithOffset(Offset offset) => OffsetTime(this, offset);

  /// Combines this [LocalTime] with the given [LocalDate]
  /// into a single [LocalDateTime].
  /// Fluent alternative to `operator+()`.
  ///
  /// [date]: The date to combine with this time
  ///
  /// Returns the [LocalDateTime] representation of the given time on this date
  // noda_dart: C#'s operator +(LocalDate, LocalTime).
  LocalDateTime On(LocalDate date) => date.At(this);

  /// Deconstruct this time into its components: the hour of the time, the minute of the hour and the second within
  /// the minute.
  ///
  /// `final (hour, minute, second) = time.Deconstruct;`
  // noda_dart: C#'s Deconstruct(out int hour, out int minute, out int second).
  (int hour, int minute, int second) get Deconstruct => (Hour, Minute, Second);

  /// Returns the later time of the given two.
  ///
  /// [x]: The first time to compare.
  /// [y]: The second time to compare.
  ///
  /// Returns the later instant of [x] or [y].
  static LocalTime Max(LocalTime x, LocalTime y) {
    return x > y ? x : y;
  }

  /// Returns the earlier time of the given two.
  ///
  /// [x]: The first time to compare.
  /// [y]: The second time to compare.
  ///
  /// Returns the earlier time of [x] or [y].
  static LocalTime Min(LocalTime x, LocalTime y) => x < y ? x : y;

  // #region Formatting
  /// Returns a [String] that represents this instance.
  ///
  /// Returns the value of the current instance in the default format pattern ("T"), using the invariant culture
  /// (NodaTime uses the current thread's culture; Dart has none).
  @override
  String toString() => LocalTimePattern.BclSupport.Format(this, null, NodaCultureInfo.InvariantCulture);

  /// Formats the value of the current instance using the specified pattern.
  ///
  /// Returns a [String] containing the value of the current instance in the specified format.
  ///
  /// [patternText]: The [String] specifying the pattern to use,
  /// or null to use the default format pattern ("T").
  /// [formatProvider]: The [IFormatProvider] to use when formatting the value,
  /// or null to use the invariant culture.
  // noda_dart: C#'s ToString(string? patternText, IFormatProvider? formatProvider).
  String ToStringPattern(String? patternText, [IFormatProvider? formatProvider]) =>
      LocalTimePattern.BclSupport.Format(this, patternText, formatProvider);
  // #endregion Formatting

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable.GetSchema, ReadXml, WriteXml (XML serialization)
  // #endregion

  // #region TimeOnly conversions (.NET 6 only)
  // Not ported: ToTimeOnly(), FromTimeOnly(TimeOnly) (Dart has no TimeOnly type)
  // #endregion

  // #region JSON (noda_dart)
  /// Formats this value with [LocalTimePattern.ExtendedIso], as NodaTime.Serialization.SystemTextJson does.
  String toJson() => LocalTimePattern.ExtendedIso.Format(this);

  /// Parses a value written by [toJson].
  ///
  /// Throws [UnparsableValueException] if the value can't be parsed.
  factory LocalTime.fromJson(String json) => LocalTimePattern.ExtendedIso.Parse(json).Value;
  // #endregion
}
