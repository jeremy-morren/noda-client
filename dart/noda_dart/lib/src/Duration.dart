// Ported from NodaTime 6e024dde: src/NodaTime/Duration.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:core';
import 'dart:core' as core;

import 'package:meta/meta.dart';

import 'Globalization/NodaCultureInfo.dart';
import 'NodaConstants.dart';
import 'Text/DurationPattern.dart';
import 'Utility/Checked.dart';
import 'Utility/DecimalArithmetic.dart';
import 'Utility/Int64.dart';
import 'Utility/Preconditions.dart';
import 'Utility/SystemExceptions.dart';
import 'Utility/TickArithmetic.dart';

// Implementation note:
// Although we use BigInteger in the public API as it's a better fit for "this could be a large integer"
// we use decimal for computations where we have to. It's more efficient in CPU (and space) than BigInteger,
// and still has plenty of range/precision. The FromNanoseconds(BigInteger) and ToBigIntegerNanoseconds() methods
// should not be called within Noda Time, except for in FromNanoseconds(double), as the double to decimal conversion
// loses information whereas double to BigInteger doesn't.
//
// noda_dart: BigInteger, Int128 and decimal are BigInt; Utility/DecimalArithmetic.dart has decimal's semantics.

/// Represents a fixed (and calendar-independent) length of time.
///
/// A duration is a length of time defined by an integral number of nanoseconds.
/// Although durations are usually used with a positive number of nanoseconds, negative durations are valid, and may occur
/// naturally when e.g. subtracting a later [Instant] from an earlier one.
///
/// Equality and ordering are defined in the natural way, simply comparing the number of nanoseconds contained.
///
/// A duration represents a fixed length of elapsed time along the time line that occupies the same amount of
/// time regardless of when it is applied. In contrast, [Period] represents a period of time in
/// calendrical terms (years, months, days, and so on) that may vary in elapsed time when applied.
///
/// In general, use [Duration] to represent durations applied to global types like [Instant]
/// and [ZonedDateTime]; use `Period` to represent a period applied to local types like
/// [LocalDateTime].
///
/// The range of valid values of a `Duration` is greater than the span of time supported by Noda Time - so for
/// example, subtracting one [Instant] from another will always give a valid `Duration`. The range
/// is also greater than that of `TimeSpan` (`long.MinValue` ticks to `long.MaxValue` ticks).
/// See the user guide for more details of the exact range, but it is not expected that this will ever be exceeded in normal code.
///
/// Various operations accept or return a [double], in-keeping with durations often being natural lengths
/// of time which are imprecisely measured anyway. The implementation of these operations should never result in a not-a-number
/// or infinite value, nor do any operations accept not-a-number or infinite values. Additionally, operations involving
/// `Double` have initially been implemented fairly naively; it's possible that future releases will improve the accuracy
/// or performance (or both) of various operations.
///
/// The default value of this type is [Zero].
///
/// This type is an immutable value type. See the thread safety section of the user guide for more information.
final class Duration implements Comparable<Duration> {
  // This is one more bit than we really need, but it allows Instant.BeforeMinValue and Instant.AfterMaxValue
  // to be easily constructed with valid durations, even though the result is a deliberately-invalid instant.
  @internal
  static const int MaxDays = (1 << 24) - 1;

  /// C#: `~MaxDays` (Dart's `~` is 32-bit unsigned on the web).
  @internal
  static const int MinDays = -MaxDays - 1;

  @internal
  static final BigInt MinNanoseconds = BigInt.from(MinDays) * BigInt.from(NodaConstants.NanosecondsPerDay);

  @internal
  static final BigInt MaxNanoseconds =
      (BigInt.from(MaxDays) + BigInt.one) * BigInt.from(NodaConstants.NanosecondsPerDay) - BigInt.one;

  // Not ported: MinInt128Nanoseconds, MaxInt128Nanoseconds (Dart has no Int128; BigInt covers it)

  /// C#'s `(decimal) MinNanoseconds` (an integral decimal is a BigInt in noda_dart).
  @internal
  static final BigInt MinDecimalNanoseconds = MinNanoseconds;

  /// C#'s `(decimal) MaxNanoseconds` (an integral decimal is a BigInt in noda_dart).
  @internal
  static final BigInt MaxDecimalNanoseconds = MaxNanoseconds;

  static final double _MinDoubleNanoseconds = MinNanoseconds.toDouble();
  static final double _MaxDoubleNanoseconds = MaxNanoseconds.toDouble();

  // The -1 here is to allow for the addition of nearly a whole day in the nanoOfDay field.
  // (C#: (int) (long.MaxValue / NanosecondsPerDay) - 1 and (int) (long.MinValue / NanosecondsPerDay).)
  static const int _MaxDaysForLongNanos = 106751 - 1;
  static const int _MinDaysForLongNanos = -106751;

  // #region Readonly static properties

  /// Gets a zero [Duration] of 0 nanoseconds.
  static const Duration Zero = Duration._NewDaysNanoOfDayNoValidation(0, 0, true);

  /// Gets the additive identity.
  static const Duration AdditiveIdentity = Zero;

  /// Gets a [Duration] value equal to 1 nanosecond; the smallest amount by which an instant can vary.
  static const Duration Epsilon = Duration._NewDaysNanoOfDayNoValidation(0, 1, true);

  /// Gets the maximum value supported by [Duration].
  static const Duration MaxValue =
      Duration._NewDaysNanoOfDayNoValidation(MaxDays, NodaConstants.NanosecondsPerDay - 1, true);

  /// Gets the minimum (largest negative) value supported by [Duration].
  static const Duration MinValue = Duration._NewDaysNanoOfDayNoValidation(MinDays, 0, true);

  /// Represents the [Duration] value equal to the number of nanoseconds in 1 standard week (7 days).
  ///
  /// The value of this property is 604,800,000,000,000 nanoseconds.
  @internal
  static const Duration OneWeek = Duration._NewDaysNanoOfDayNoValidation(7, 0, true);

  /// Represents the [Duration] value equal to the number of nanoseconds in 1 day.
  ///
  /// The value of this property is 86.4 trillion nanoseconds; that is, 86,400,000,000,000 nanoseconds.
  @internal
  static const Duration OneDay = Duration._NewDaysNanoOfDayNoValidation(1, 0, true);
  // #endregion

  // This is effectively a 25 bit value. (It can't be 24 bits, or we can't represent every TimeSpan value.)
  final int _days;
  // Always non-negative; a negative duration will have a negative number of days, but may have a
  // positive nanoOfDay. (A duration of -1ns will have a days value of -1 and a nanoOfDay of
  // NanosecondsPerDay - 1, for example.)
  final int _nanoOfDay;

  // Trusted constructor with no validation. The value of the noValidation parameter is
  // ignored completely; its name is just to be suggestive.
  const Duration._NewDaysNanoOfDayNoValidation(int days, int nanoOfDay, bool noValidation)
      : _days = days,
        _nanoOfDay = nanoOfDay;

  // Implementation note: I've tried making this internal and calling it directly from Instant.FromUnixTimeSeconds etc?
  // That reduces the number of range checks, but doesn't seem to affect the performance in a significant way.
  // Leaving it as it is leaves a cleaner API - this constructor doesn't feel like something that *should*
  // be exposed to other classes.

  /// Constructs an instance from a given number of units. This was previously a method (FromUnits) but making it a
  /// constructor avoids calling the other constructor which validates its "days" parameter.
  /// Note that we could compute various parameters from nanosPerUnit, but we know them as compile-time constants, so
  /// there's no point in recomputing them on each call.
  ///
  /// [units]: Number of units
  /// [paramName]: Name of the parameter, e.g. "hours"
  /// [minValue]: Minimum number of units for a valid duration.
  /// [maxValue]: Maximum number of units for a valid duration.
  /// [unitsPerDay]: Number of units in a day.
  /// [nanosPerUnit]: Number of nanoseconds per unit.
  factory Duration._NewUnitsParamNameMinValueMaxValueUnitsPerDayNanosPerUnit(
      int units, String paramName, int minValue, int maxValue, int unitsPerDay, int nanosPerUnit) {
    Preconditions.CheckArgumentRange(paramName, units, minValue, maxValue);
    // unchecked
    // Note: DivRem appears to make this (significantly) slower, despite helping in Period.
    int days = units ~/ unitsPerDay;
    int unitOfDay = units - (unitsPerDay * days);
    if (unitOfDay < 0) {
      days--;
      unitOfDay += unitsPerDay;
    }
    int nanoOfDay = unitOfDay * nanosPerUnit;
    return Duration._NewDaysNanoOfDayNoValidation(days, nanoOfDay, true);
  }

  @internal
  factory Duration.NewDaysNanoOfDay(int days, int nanoOfDay) {
    // Heavily used: avoid the method call unless it's going to throw.
    // (Benchmarking Duration.FromDays, unconditionally calling CheckArgumentRange
    // raises the call time from ~2ns to ~15ns.)
    if (days < MinDays || days > MaxDays) {
      Preconditions.CheckArgumentRange('days', days, MinDays, MaxDays);
    }
    Preconditions.DebugCheckArgumentRange('nanoOfDay', nanoOfDay, 0, NodaConstants.NanosecondsPerDay - 1);
    return Duration._NewDaysNanoOfDayNoValidation(days, nanoOfDay, true);
  }

  /// Days portion of this duration. The [NanosecondOfFloorDay] is added to this
  /// value, so this effectively Math.Floor(TotalDays).
  @internal
  int get FloorDays => _days;

  /// Nanosecond within the "floor day". This is *always* non-negative, even for
  /// negative durations.
  @internal
  int get NanosecondOfFloorDay => _nanoOfDay;

  /// Gets the whole number of standard (24 hour) days within this duration. This is truncated towards zero;
  /// for example, "-1.75 days" and "1.75 days" would have results of -1 and 1 respectively.
  int get Days => _days >= 0 || _nanoOfDay == 0 ? _days : _days + 1;

  /// Gets the number of nanoseconds within the day of this duration. For negative durations, this
  /// will be negative (or zero).
  int get NanosecondOfDay => _days >= 0
      ? _nanoOfDay
      : _nanoOfDay == 0
          ? 0
          : _nanoOfDay - NodaConstants.NanosecondsPerDay;

  /// The hour component of this duration, in the range [-23, 23], truncated towards zero.
  int get Hours => NanosecondOfDay ~/ NodaConstants.NanosecondsPerHour;

  /// The minute component of this duration, in the range [-59, 59], truncated towards zero.
  int get Minutes => (NanosecondOfDay ~/ NodaConstants.NanosecondsPerMinute).remainder(NodaConstants.MinutesPerHour);

  /// Gets the second component of this duration, in the range [-59, 59], truncated towards zero.
  int get Seconds => (NanosecondOfDay ~/ NodaConstants.NanosecondsPerSecond).remainder(NodaConstants.SecondsPerMinute);

  /// Gets the subsecond component of this duration, expressed in milliseconds, in the range [-999, 999] and truncated towards zero.
  int get Milliseconds =>
      (NanosecondOfDay ~/ NodaConstants.NanosecondsPerMillisecond).remainder(NodaConstants.MillisecondsPerSecond);

  /// Gets the subsecond component of this duration, expressed in ticks, in the range [-9999999, 9999999] and truncated towards zero.
  int get SubsecondTicks => (NanosecondOfDay ~/ NodaConstants.NanosecondsPerTick).remainder(NodaConstants.TicksPerSecond);

  /// Gets the subsecond component of this duration, expressed in nanoseconds, in the range [-999999999, 999999999].
  int get SubsecondNanoseconds => NanosecondOfDay.remainder(NodaConstants.NanosecondsPerSecond);

  /// Gets the total number of ticks in the duration as a 64-bit integer, truncating towards zero where necessary.
  ///
  /// Within the constraints specified below, this property is intended to be equivalent to
  /// `TimeSpan.Ticks`.
  ///
  /// If the number of nanoseconds in a duration is not a whole number of ticks, it is truncated towards zero.
  /// For example, durations in the range [-99ns, 99ns] would all count as 0 ticks.
  ///
  /// Although this method can overflow, it will only do so in very exceptional cases, with durations
  /// with a magnitude of more than 29000 Gregorian years or so.
  ///
  /// Throws [OverflowException] if the number of ticks cannot be represented a signed 64-bit integer.
  ///
  /// See also [TotalTicks].
  int get BclCompatibleTicks {
    int ticks = TickArithmetic.DaysAndTickOfDayToTicks(_days, _nanoOfDay ~/ NodaConstants.NanosecondsPerTick);
    if (_days < 0 && _nanoOfDay.remainder(NodaConstants.NanosecondsPerTick) != 0) {
      ticks = Checked.Add(ticks, 1);
    }
    return ticks;
  }

  // TODO(optimization): Reimplement all of these using TotalNanoseconds?

  /// Gets the total number of days in this duration, as a [double].
  ///
  /// This property is the `Duration` equivalent of `TimeSpan.TotalDays`.
  /// It represents the complete duration in days, rather than only the whole number of
  /// days. For example, for a duration of 36 hours, this property would return 1.5.
  double get TotalDays => _days + _nanoOfDay / NodaConstants.NanosecondsPerDay;

  /// Gets the total number of hours in this duration, as a [double].
  ///
  /// This property is the `Duration` equivalent of `TimeSpan.TotalHours`.
  /// Unlike [Hours], it represents the complete duration in hours rather than the
  /// whole number of hours as part of the day. So for a duration
  /// of 1 day, 2 hours and 30 minutes, the `Hours` property will return 2, but `TotalHours`
  /// will return 26.5.
  double get TotalHours => _days * 24.0 + _nanoOfDay / NodaConstants.NanosecondsPerHour;

  /// Gets the total number of minutes in this duration, as a [double].
  ///
  /// This property is the `Duration` equivalent of `TimeSpan.TotalMinutes`.
  /// Unlike [Minutes], it represents the complete duration in minutes rather than
  /// the whole number of minutes within the hour. So for a duration
  /// of 2 hours, 30 minutes and 45 seconds, the `Minutes` property will return 30, but `TotalMinutes`
  /// will return 150.75.
  double get TotalMinutes =>
      _days * NodaConstants.MinutesPerDay.toDouble() + _nanoOfDay / NodaConstants.NanosecondsPerMinute;

  /// Gets the total number of seconds in this duration, as a [double].
  ///
  /// This property is the `Duration` equivalent of `TimeSpan.TotalSeconds`.
  /// Unlike [Seconds], it represents the complete duration in seconds rather than
  /// the whole number of seconds within the minute. So for a duration
  /// of 10 minutes, 20 seconds and 250 milliseconds, the `Seconds` property will return 20, but `TotalSeconds`
  /// will return 620.25.
  double get TotalSeconds =>
      _days * NodaConstants.SecondsPerDay.toDouble() + _nanoOfDay / NodaConstants.NanosecondsPerSecond;

  /// Gets the total number of milliseconds in this duration, as a [double].
  ///
  /// This property is the `Duration` equivalent of `TimeSpan.TotalMilliseconds`.
  /// Unlike [Milliseconds], it represents the complete duration in milliseconds rather than
  /// the whole number of milliseconds within the second. So for a duration
  /// of 10 minutes, 20 seconds and 250 milliseconds, the `Milliseconds` property will return 250, but `TotalMilliseconds`
  /// will return 620250.
  double get TotalMilliseconds =>
      _days * NodaConstants.MillisecondsPerDay.toDouble() + _nanoOfDay / NodaConstants.NanosecondsPerMillisecond;

  /// Gets the total number of ticks in this duration, as a [double].
  ///
  /// This property is the `Duration` equivalent of `TimeSpan.Ticks`,
  /// except represented as double-precision floating point number instead of a 64-bit integer. This
  /// is because [Duration] has a precision of nanoseconds, and also because the range
  /// of 64-bit integers doesn't cover the number of possible ticks in a [Duration]. (The
  /// latter is only an issue in durations outside the range of `TimeSpan` - in other words,
  /// with magnitudes of over 29,000 years.)
  ///
  /// See also [BclCompatibleTicks].
  double get TotalTicks => _days * NodaConstants.TicksPerDay.toDouble() + _nanoOfDay / NodaConstants.NanosecondsPerTick;

  /// Gets the total number of nanoseconds in this duration, as a [double].
  ///
  /// The result is always an integer, but may not be precise due to the limitations
  /// of the `Double` type. In other works, `Duration.FromNanosecondsDouble(duration.TotalNanoseconds)`
  /// is not guaranteed to round-trip. To guarantee precision and round-tripping,
  /// use [ToBigIntegerNanoseconds] and [FromNanosecondsBigInteger].
  ///
  /// Returns this duration as a number of nanoseconds, represented as a `Double`.
  double get TotalNanoseconds => _days.toDouble() * NodaConstants.NanosecondsPerDay + _nanoOfDay;

  /// Adds a "small" number of nanoseconds to this duration: it is trusted to be less or equal to than 24 hours
  /// in magnitude.
  @internal
  Duration PlusSmallNanoseconds(int smallNanos) {
    // unchecked
    Preconditions.DebugCheckArgumentRange(
        'smallNanos', smallNanos, -NodaConstants.NanosecondsPerDay, NodaConstants.NanosecondsPerDay);
    int newDays = _days;
    int newNanos = _nanoOfDay + smallNanos;
    if (newNanos >= NodaConstants.NanosecondsPerDay) {
      newDays++;
      newNanos -= NodaConstants.NanosecondsPerDay;
    } else if (newNanos < 0) {
      newDays--;
      newNanos += NodaConstants.NanosecondsPerDay;
    }
    return Duration.NewDaysNanoOfDay(newDays, newNanos);
  }

  /// Subtracts a "small" number of nanoseconds from this duration: it is trusted to be less than 24 hours
  /// in magnitude.
  @internal
  Duration MinusSmallNanoseconds(int smallNanos) {
    // unchecked
    Preconditions.DebugCheckArgumentRange(
        'smallNanos', smallNanos, -NodaConstants.NanosecondsPerDay, NodaConstants.NanosecondsPerDay);
    int newDays = _days;
    int newNanos = _nanoOfDay - smallNanos;
    if (newNanos >= NodaConstants.NanosecondsPerDay) {
      newDays++;
      newNanos -= NodaConstants.NanosecondsPerDay;
    } else if (newNanos < 0) {
      newDays--;
      newNanos += NodaConstants.NanosecondsPerDay;
    }
    return Duration.NewDaysNanoOfDay(newDays, newNanos);
  }

  // #region Object overrides
  /// Determines whether the specified object is equal to this instance.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The object to compare with this instance.
  ///
  /// Returns `true` if the specified object is equal to this instance;
  /// otherwise, `false`.
  @override
  bool operator ==(Object other) => other is Duration && Equals(other);

  /// Returns a hash code for this instance.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a hash code for this instance, suitable for use in hashing algorithms and data
  /// structures like a hash table.
  @override
  int get hashCode => _days ^ _nanoOfDay.hashCode;
  // #endregion

  // #region Formatting
  /// Returns a [String] that represents this instance.
  ///
  /// Returns the value of the current instance in the default format pattern ("o"), using the invariant culture.
  /// (NodaTime uses the current thread's culture.)
  @override
  String toString() => DurationPattern.BclSupport.Format(this, null, NodaCultureInfo.InvariantCulture);

  /// Formats the value of the current instance using the specified pattern.
  ///
  /// (C#'s `ToString(string? patternText, IFormatProvider? formatProvider)`: Dart's `toString` takes no parameters.)
  ///
  /// Returns a [String] containing the value of the current instance in the specified format.
  ///
  /// [patternText]: The [String] specifying the pattern to use,
  /// or null to use the default format pattern ("o").
  /// [formatProvider]: The `IFormatProvider` to use when formatting the value,
  /// or null to use the current thread's culture to obtain a format provider.
  String ToStringPattern(String? patternText, [IFormatProvider? formatProvider]) =>
      DurationPattern.BclSupport.Format(this, patternText, formatProvider);
  // #endregion Formatting

  // #region Operators
  /// Implements the operator + (addition).
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Duration] representing the sum of the given values.
  Duration operator +(Duration right) {
    // unchecked
    int newDays = _days + right._days;
    int newNanos = _nanoOfDay + right._nanoOfDay;
    if (newNanos >= NodaConstants.NanosecondsPerDay) {
      newDays++;
      newNanos -= NodaConstants.NanosecondsPerDay;
    }
    // nanoOfDay is always non-negative (and much less than half of long.MaxValue), so adding two
    // of them together will never produce a negative result.
    return Duration.NewDaysNanoOfDay(newDays, newNanos);
  }

  // Not ported: operator +(Duration) (unary plus; Dart has no unary + operator)

  /// Adds one duration to another. Friendly alternative to `operator+()`.
  ///
  /// [left]: The left hand side of the operator.
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Duration] representing the sum of the given values.
  static Duration Add(Duration left, Duration right) => left + right;

  /// Returns the result of adding another duration to this one, for a fluent alternative to `operator+()`.
  ///
  /// [other]: The duration to add
  ///
  /// Returns a new [Duration] representing the result of the addition.
  Duration Plus(Duration other) => this + other;

  /// Implements the operator - (subtraction).
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Duration] representing the difference of the given values.
  Duration operator -(Duration right) {
    // unchecked
    int newDays = _days - right._days;
    int newNanos = _nanoOfDay - right._nanoOfDay;
    if (newNanos < 0) {
      newDays--;
      newNanos += NodaConstants.NanosecondsPerDay;
    }
    return Duration.NewDaysNanoOfDay(newDays, newNanos);
  }

  /// Subtracts one duration from another. Friendly alternative to `operator-()`.
  ///
  /// [left]: The left hand side of the operator.
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Duration] representing the difference of the given values.
  static Duration Subtract(Duration left, Duration right) => left - right;

  /// Returns the result of subtracting another duration from this one, for a fluent alternative to `operator-()`.
  ///
  /// [other]: The duration to subtract
  ///
  /// Returns a new [Duration] representing the result of the subtraction.
  Duration Minus(Duration other) => this - other;

  /// Implements the operator / (division) to divide a duration by an `Int64`.
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Duration] representing the result of dividing this duration by
  /// [right].
  ///
  /// Throws [DivideByZeroException] if [right] is zero.
  Duration operator /(int right) {
    int days = _days;
    // Simplest scenario to handle
    if (days == 0 && right > 0) {
      return Duration.NewDaysNanoOfDay(0, _nanoOfDay ~/ right);
    }
    // (noda_dart: Dart's ~/ throws UnsupportedError, not DivideByZeroException.)
    if (right == 0) {
      throw DivideByZeroException();
    }
    // Now for the ~[-250, +250] year range, where we can do it all as a long.
    if (days >= _MinDaysForLongNanos && days <= _MaxDaysForLongNanos) {
      int nanos = ToInt64Nanoseconds() ~/ right;
      return FromNanoseconds(nanos);
    }
    // Fall back to decimal arithmetic.
    BigInt x = ToDecimalNanoseconds();
    final (mantissa, scale) = DecimalArithmetic.Divide(x, BigInt.from(right));
    return _FromDecimalQuotient(mantissa, scale);
  }

  /// Implements the operator / (division) to divide a duration by a [double].
  ///
  /// (C#'s `operator /(Duration, double)`: Dart's `/` operator takes an `int`.)
  ///
  /// [left]: The left hand side of the operator.
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Duration] representing the result of dividing [left] by
  /// [right].
  static Duration DivideDouble(Duration left, double right) {
    // Exclude infinity and NaN
    Preconditions.CheckArgumentRangeDouble('right', right, -double.maxFinite, double.maxFinite);
    if (right == 0.0) {
      throw DivideByZeroException('Attempt to divide a duration by zero.');
    }
    return FromNanosecondsDouble(left.TotalNanoseconds / right);
  }

  /// Implements the operator / (division) to divide one duration by another.
  ///
  /// (C#'s `operator /(Duration, Duration)`: Dart's `/` operator takes an `int`.)
  ///
  /// [left]: The left hand side of the operator.
  /// [right]: The right hand side of the operator.
  ///
  /// Returns the [double] representing the result of dividing [left] by
  /// [right].
  static double DivideDuration(Duration left, Duration right) {
    double rightNanos = right.TotalNanoseconds;
    if (rightNanos == 0.0) {
      throw DivideByZeroException('Attempt to divide by a zero duration.');
    }
    return left.TotalNanoseconds / rightNanos;
  }

  /// Divides a duration by an `Int64`. Friendly alternative to `operator/()`.
  ///
  /// [left]: The left hand side of the operator.
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Duration] representing the result of dividing [left] by
  /// [right].
  static Duration Divide(Duration left, int right) => left / right;

  // C#'s Divide(Duration, double) and Divide(Duration, Duration) are DivideDouble and DivideDuration (above).

  /// Implements the operator * (multiplication).
  ///
  /// (C#'s `operator *(Duration, double)`: Dart's `*` operator takes an `int`.)
  ///
  /// [left]: The left hand side of the operator.
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Duration] representing the result of multiplying [left] by
  /// [right].
  static Duration MultiplyDouble(Duration left, double right) {
    // Exclude infinity and NaN
    Preconditions.CheckArgumentRangeDouble('right', right, -double.maxFinite, double.maxFinite);
    return FromNanosecondsDouble(left.TotalNanoseconds * right);
  }

  /// Implements the operator * (multiplication).
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Duration] representing the result of multiplying this duration by
  /// [right].
  Duration operator *(int right) {
    // unchecked
    // Optimize very simple cases that require no arithmetic.
    if (right == 0 || this == Zero) {
      return Zero;
    }
    if (right == 1) {
      return this;
    }
    // Attempt to find a sweet spot... rather than detecting whether arithmetic
    // will overflow accurately (which is painful), we just check whether both
    // values are within a common range - durations of more than +/-100 days
    // are rare, and so is multiplication by huge numbers. (The range we get is
    // roughly +/- 1000.) If this changes, tests should change too.
    // Note that this *isn't* a good sweet spot for Integer.FromUnixTime*... so
    // FromSeconds etc are optimized separately.
    const int DaysToOptimize = 100;
    // Almost every real use case will fit in here, I suspect...
    if (_days >= -DaysToOptimize &&
        _days < DaysToOptimize &&
        right > Int64.MinValue ~/ (NodaConstants.NanosecondsPerDay * DaysToOptimize) &&
        right < Int64.MaxValue ~/ (NodaConstants.NanosecondsPerDay * DaysToOptimize)) {
      int nanos = _ToInt64NanosecondsUnchecked();
      // noda_dart: on dart2js a product beyond 2^53 isn't exact: take the decimal path.
      int product = nanos * right;
      if (Int64.IsExact || product.abs() <= Int64.MaxSafeInteger) {
        return FromNanoseconds(product);
      }
    }
    // Fall back to decimal arithmetic
    return FromDecimalNanoseconds(DecimalArithmetic.CheckRange(ToDecimalNanoseconds() * BigInt.from(right)));
  }

  // Not ported: operator *(double, Duration), operator *(long, Duration) (see MultiplyDoubleDuration, MultiplyInt64Duration)

  /// Multiplies a duration by a number. Friendly alternative to `operator*()`.
  ///
  /// [left]: The left hand side of the operator.
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Duration] representing the product of the given values.
  static Duration Multiply(Duration left, int right) => left * right;

  // C#'s Multiply(Duration, double) is MultiplyDouble (above).

  /// Multiplies a duration by a number. Friendly alternative to `operator*()`.
  ///
  /// (C#'s `Multiply(long, Duration)` and `operator *(long, Duration)`.)
  ///
  /// [left]: The left hand side of the operator.
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Duration] representing the product of the given values.
  static Duration MultiplyInt64Duration(int left, Duration right) => right * left;

  /// Multiplies a duration by a number. Friendly alternative to `operator*()`.
  ///
  /// (C#'s `Multiply(double, Duration)` and `operator *(double, Duration)`.)
  ///
  /// [left]: The left hand side of the operator.
  /// [right]: The right hand side of the operator.
  ///
  /// Returns a new [Duration] representing the product of the given values.
  static Duration MultiplyDoubleDuration(double left, Duration right) => MultiplyDouble(right, left);

  // C#'s operator == and != are Dart's == (Object overrides, above) and Equals.

  /// Implements the operator &lt; (less than).
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is less than the right value, otherwise `false`.
  bool operator <(Duration right) => _days < right._days || (_days == right._days && _nanoOfDay < right._nanoOfDay);

  /// Implements the operator &lt;= (less than or equal).
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is less than or equal to the right value, otherwise `false`.
  bool operator <=(Duration right) => _days < right._days || (_days == right._days && _nanoOfDay <= right._nanoOfDay);

  /// Implements the operator &gt; (greater than).
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is greater than the right value, otherwise `false`.
  bool operator >(Duration right) => _days > right._days || (_days == right._days && _nanoOfDay > right._nanoOfDay);

  /// Implements the operator &gt;= (greater than or equal).
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is greater than or equal to the right value, otherwise `false`.
  bool operator >=(Duration right) => _days > right._days || (_days == right._days && _nanoOfDay >= right._nanoOfDay);

  /// Implements the unary negation operator.
  ///
  /// Returns the negative value of this duration
  Duration operator -() {
    int oldDays = _days;
    int oldNanoOfDay = _nanoOfDay;
    if (oldNanoOfDay == 0) {
      return Duration.NewDaysNanoOfDay(-oldDays, 0);
    }
    int newNanoOfDay = NodaConstants.NanosecondsPerDay - oldNanoOfDay;
    return Duration.NewDaysNanoOfDay(-oldDays - 1, newNanoOfDay);
  }

  /// Implements a friendly alternative to the unary negation operator.
  ///
  /// [duration]: Duration to negate
  ///
  /// Returns the negative value of this duration
  static Duration Negate(Duration duration) => -duration;
  // #endregion // Operators

  // #region IComparable<Duration> Members
  /// Implementation of `IComparable<Duration>.CompareTo` to compare two durations.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [other]: An object to compare with this object.
  ///
  /// Returns a 32-bit signed integer that indicates the relative order of the objects being compared:
  /// less than 0 if this object is less than the [other] parameter, 0 if this object is equal to [other],
  /// and greater than 0 if this object is greater than [other].
  @override
  int compareTo(Duration other) {
    int dayComparison = _days.compareTo(other._days);
    return dayComparison != 0 ? dayComparison : _nanoOfDay.compareTo(other._nanoOfDay);
  }

  /// Implementation of `IComparable.CompareTo` to compare two durations.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// This uses explicit interface implementation to avoid it being called accidentally. The generic implementation should usually be preferred.
  ///
  /// Throws [ArgumentError] if [obj] is non-null but does not refer to an instance of [Duration].
  ///
  /// [obj]: The object to compare this value with.
  ///
  /// Returns the result of comparing this instant with another one; see [compareTo] for general details.
  /// If [obj] is null, this method returns a value greater than 0.
  int CompareTo(Object? obj) {
    if (obj == null) {
      return 1;
    }
    Preconditions.CheckArgument(obj is Duration, 'obj', 'Object must be of type NodaTime.Duration.');
    return compareTo(obj as Duration);
  }
  // #endregion

  // #region IEquatable<Duration> Members
  /// Indicates whether the current object is equal to another object of the same type.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: An object to compare with this object.
  ///
  /// Returns true if the current object is equal to the [other] parameter;
  /// otherwise, false.
  bool Equals(Duration other) => _days == other._days && _nanoOfDay == other._nanoOfDay;
  // #endregion

  /// Returns a [Duration] that represents the given number of days, assuming a 'standard' 24-hour
  /// day.
  ///
  /// [days]: The number of days.
  ///
  /// Returns a [Duration] representing the given number of days.
  static Duration FromDays(int days) => Duration.NewDaysNanoOfDay(days, 0);

  /// Returns a [Duration] that represents the given number of days, assuming a 'standard' 24-hour
  /// day.
  ///
  /// (C#'s `FromDays(double)`.)
  ///
  /// [days]: The number of days.
  ///
  /// Returns a [Duration] representing the given number of days.
  static Duration FromDaysDouble(double days) {
    Preconditions.CheckArgumentRangeDouble('days', days, MinDays.toDouble(), MaxDays.toDouble());
    return FromNanosecondsDouble(days * NodaConstants.NanosecondsPerDay);
  }

  /// Returns a [Duration] that represents the given number of hours.
  ///
  /// [hours]: The number of hours.
  ///
  /// Returns a [Duration] representing the given number of hours.
  static Duration FromHours(int hours) => Duration._NewUnitsParamNameMinValueMaxValueUnitsPerDayNanosPerUnit(
      hours,
      'hours',
      MinDays * NodaConstants.HoursPerDay,
      ((MaxDays + 1) * NodaConstants.HoursPerDay) - 1,
      NodaConstants.HoursPerDay,
      NodaConstants.NanosecondsPerHour);

  /// Returns a [Duration] that represents the given number of hours.
  ///
  /// (C#'s `FromHours(double)`.)
  ///
  /// [hours]: The number of hours.
  ///
  /// Returns a [Duration] representing the given number of hours.
  static Duration FromHoursDouble(double hours) {
    Preconditions.CheckArgumentRangeDouble('hours', hours, (MinDays * NodaConstants.HoursPerDay).toDouble(),
        ((MaxDays + 1) * NodaConstants.HoursPerDay - 1).toDouble());
    return FromNanosecondsDouble(hours * NodaConstants.NanosecondsPerHour);
  }

  /// Returns a [Duration] that represents the given number of minutes.
  ///
  /// [minutes]: The number of minutes.
  ///
  /// Returns a [Duration] representing the given number of minutes.
  static Duration FromMinutes(int minutes) => Duration._NewUnitsParamNameMinValueMaxValueUnitsPerDayNanosPerUnit(
      minutes,
      'minutes',
      MinDays * NodaConstants.MinutesPerDay,
      ((MaxDays + 1) * NodaConstants.MinutesPerDay) - 1,
      NodaConstants.MinutesPerDay,
      NodaConstants.NanosecondsPerMinute);

  /// Returns a [Duration] that represents the given number of minutes.
  ///
  /// (C#'s `FromMinutes(double)`.)
  ///
  /// [minutes]: The number of minutes.
  ///
  /// Returns a [Duration] representing the given number of minutes.
  static Duration FromMinutesDouble(double minutes) {
    Preconditions.CheckArgumentRangeDouble('minutes', minutes, (MinDays * NodaConstants.MinutesPerDay).toDouble(),
        ((MaxDays + 1) * NodaConstants.MinutesPerDay - 1).toDouble());
    return FromNanosecondsDouble(minutes * NodaConstants.NanosecondsPerMinute);
  }

  /// Returns a [Duration] that represents the given number of seconds.
  ///
  /// [seconds]: The number of seconds.
  ///
  /// Returns a [Duration] representing the given number of seconds.
  static Duration FromSeconds(int seconds) => Duration._NewUnitsParamNameMinValueMaxValueUnitsPerDayNanosPerUnit(
      seconds,
      'seconds',
      MinDays * NodaConstants.SecondsPerDay,
      ((MaxDays + 1) * NodaConstants.SecondsPerDay) - 1,
      NodaConstants.SecondsPerDay,
      NodaConstants.NanosecondsPerSecond);

  /// Returns a [Duration] that represents the given number of seconds.
  ///
  /// (C#'s `FromSeconds(double)`.)
  ///
  /// [seconds]: The number of seconds.
  ///
  /// Returns a [Duration] representing the given number of seconds.
  static Duration FromSecondsDouble(double seconds) {
    Preconditions.CheckArgumentRangeDouble('seconds', seconds, (MinDays * NodaConstants.SecondsPerDay).toDouble(),
        ((MaxDays + 1) * NodaConstants.SecondsPerDay - 1).toDouble());
    return FromNanosecondsDouble(seconds * NodaConstants.NanosecondsPerSecond);
  }

  /// Returns a [Duration] that represents the given number of milliseconds.
  ///
  /// [milliseconds]: The number of milliseconds.
  ///
  /// Returns a [Duration] representing the given number of milliseconds.
  static Duration FromMilliseconds(int milliseconds) =>
      Duration._NewUnitsParamNameMinValueMaxValueUnitsPerDayNanosPerUnit(
          milliseconds,
          'milliseconds',
          MinDays * NodaConstants.MillisecondsPerDay,
          ((MaxDays + 1) * NodaConstants.MillisecondsPerDay) - 1,
          NodaConstants.MillisecondsPerDay,
          NodaConstants.NanosecondsPerMillisecond);

  /// Returns a [Duration] that represents the given number of milliseconds.
  ///
  /// (C#'s `FromMilliseconds(double)`.)
  ///
  /// [milliseconds]: The number of milliseconds.
  ///
  /// Returns a [Duration] representing the given number of milliseconds.
  static Duration FromMillisecondsDouble(double milliseconds) {
    Preconditions.CheckArgumentRangeDouble(
        'milliseconds',
        milliseconds,
        (MinDays * NodaConstants.MillisecondsPerDay).toDouble(),
        ((MaxDays + 1) * NodaConstants.MillisecondsPerDay - 1).toDouble());
    return FromNanosecondsDouble(milliseconds * NodaConstants.NanosecondsPerMillisecond);
  }

  /// Returns a [Duration] that represents the given number of ticks.
  ///
  /// [ticks]: The number of ticks.
  ///
  /// Returns a [Duration] representing the given number of ticks.
  static Duration FromTicks(int ticks) {
    // No precondition here, as we cover a wider range than Int64 ticks can handle...
    final (days, tickOfDay) = TickArithmetic.TicksToDaysAndTickOfDay(ticks);
    return Duration._NewDaysNanoOfDayNoValidation(days, tickOfDay * NodaConstants.NanosecondsPerTick, true);
  }

  /// Returns a [Duration] that represents the given number of ticks.
  ///
  /// (C#'s `FromTicks(double)`.)
  ///
  /// [ticks]: The number of ticks.
  ///
  /// Returns a [Duration] representing the given number of ticks.
  static Duration FromTicksDouble(double ticks) {
    Preconditions.CheckArgumentRangeDouble('ticks', ticks, MinDays * NodaConstants.TicksPerDay.toDouble(),
        (MaxDays + 1.0) * NodaConstants.TicksPerDay - 1);
    return FromNanosecondsDouble(ticks * NodaConstants.NanosecondsPerTick);
  }

  /// Returns a [Duration] that represents the given number of nanoseconds.
  ///
  /// [nanoseconds]: The number of nanoseconds.
  ///
  /// Returns a [Duration] representing the given number of nanoseconds.
  static Duration FromNanoseconds(int nanoseconds) {
    // Note: both branches call the private constructor overload that performs no validation,
    // as the value is always valid.
    // unchecked
    if (nanoseconds >= 0) {
      // DivRem benchmarked against netcoreapp2.1 on 2019-04-21; definite win.
      int days = nanoseconds ~/ NodaConstants.NanosecondsPerDay;
      int nanoOfDay = nanoseconds.remainder(NodaConstants.NanosecondsPerDay);
      return Duration._NewDaysNanoOfDayNoValidation(days, nanoOfDay, true);
    } else {
      // Work out the "floor days"; division truncates towards zero and
      // nanoseconds is definitely negative by now, hence the addition and subtraction here.
      int days = (nanoseconds + 1) ~/ NodaConstants.NanosecondsPerDay - 1;

      int nanoOfDay = nanoseconds >= Int64.MinValue + NodaConstants.NanosecondsPerDay
          ? nanoseconds - days * NodaConstants.NanosecondsPerDay
          : nanoseconds -
              (days + 1) * NodaConstants.NanosecondsPerDay +
              NodaConstants.NanosecondsPerDay; // Avoid multiplication overflow
      // noda_dart: on dart2js, nanoseconds + 1 is inexact beyond 2^53, so the floor day can be one too low.
      if (nanoOfDay >= NodaConstants.NanosecondsPerDay) {
        days++;
        nanoOfDay -= NodaConstants.NanosecondsPerDay;
      }
      return Duration._NewDaysNanoOfDayNoValidation(days, nanoOfDay, true);
    }
  }

  /// Converts a number of nanoseconds expressed as a [double] into a duration. Any fractional
  /// parts of the value are truncated towards zero.
  ///
  /// (C#'s `FromNanoseconds(double)`.)
  ///
  /// [nanoseconds]: The number of nanoseconds to represent.
  ///
  /// Returns a duration with the given number of nanoseconds.
  static Duration FromNanosecondsDouble(double nanoseconds) {
    Preconditions.CheckArgumentRangeDouble('nanoseconds', nanoseconds, _MinDoubleNanoseconds, _MaxDoubleNanoseconds);
    // (C#'s checked (long) cast throws OverflowException for 2^63, as Checked.DoubleToInt64 does.)
    return nanoseconds >= Int64.MinValue.toDouble() && nanoseconds <= Int64.MaxValue.toDouble()
        ? FromNanoseconds(Checked.DoubleToInt64(nanoseconds))
        : FromNanosecondsBigInteger(BigInt.from(nanoseconds));
  }

  // NOTE: Do not use from internal code - use decimal instead - *unless* you're converting from double.
  /// Converts a number of nanoseconds expressed as a [BigInt] into a duration.
  ///
  /// (C#'s `FromNanoseconds(BigInteger)`, and `FromNanoseconds(Int128)`.)
  ///
  /// [nanoseconds]: The number of nanoseconds to represent.
  ///
  /// Returns a duration with the given number of nanoseconds.
  static Duration FromNanosecondsBigInteger(BigInt nanoseconds) {
    if (nanoseconds < MinNanoseconds || nanoseconds > MaxNanoseconds) {
      throw RangeError(
          'Value should be in range [$MinNanoseconds-$MaxNanoseconds] (Parameter \'nanoseconds\')');
    }

    final nanosecondsPerDay = BigInt.from(NodaConstants.NanosecondsPerDay);
    int days = nanoseconds >= BigInt.zero
        ? (nanoseconds ~/ nanosecondsPerDay).toInt()
        : ((nanoseconds + BigInt.one) ~/ nanosecondsPerDay).toInt() - 1;

    int nanoOfDay = (nanoseconds - BigInt.from(days) * nanosecondsPerDay).toInt();
    return Duration._NewDaysNanoOfDayNoValidation(days, nanoOfDay, true);
  }

  // Not ported: FromNanoseconds(Int128) (Dart has no Int128: see FromNanosecondsBigInteger)

  /// C#'s internal `FromNanoseconds(decimal)`, for an integral decimal (a [BigInt] in noda_dart; see
  /// [DecimalArithmetic]).
  @internal
  static Duration FromDecimalNanoseconds(BigInt nanoseconds) {
    if (nanoseconds < MinDecimalNanoseconds || nanoseconds > MaxDecimalNanoseconds) {
      // Note: use the BigInteger value rather than decimal to avoid decimal points in the message. They're the same values.
      throw RangeError(
          'Value should be in range [$MinNanoseconds-$MaxNanoseconds] (Parameter \'nanoseconds\')');
    }

    final nanosecondsPerDay = BigInt.from(NodaConstants.NanosecondsPerDay);
    int days = nanoseconds >= BigInt.zero
        ? (nanoseconds ~/ nanosecondsPerDay).toInt()
        : ((nanoseconds + BigInt.one) ~/ nanosecondsPerDay).toInt() - 1;

    int nanoOfDay = (nanoseconds - BigInt.from(days) * nanosecondsPerDay).toInt();
    return Duration._NewDaysNanoOfDayNoValidation(days, nanoOfDay, true);
  }

  /// noda_dart: C#'s `FromNanoseconds(decimal)` for `mantissa / 10^scale` (from [DecimalArithmetic.Divide]), floored.
  static Duration _FromDecimalQuotient(BigInt mantissa, int scale) {
    final divisor = BigInt.from(10).pow(scale);
    if (mantissa < MinDecimalNanoseconds * divisor || mantissa > MaxDecimalNanoseconds * divisor) {
      // Note: use the BigInteger value rather than decimal to avoid decimal points in the message. They're the same values.
      throw RangeError(
          'Value should be in range [$MinNanoseconds-$MaxNanoseconds] (Parameter \'nanoseconds\')');
    }
    // Floor division (BigInt's ~/ truncates).
    var floor = mantissa ~/ divisor;
    if (mantissa.isNegative && floor * divisor != mantissa) {
      floor -= BigInt.one;
    }
    return FromDecimalNanoseconds(floor);
  }

  /// Returns a [Duration] that represents the same number of ticks as the
  /// given Dart [core.Duration].
  ///
  /// (C#'s `FromTimeSpan(TimeSpan)`. A Dart `Duration` counts microseconds, each of which is 10 ticks.)
  ///
  /// [timeSpan]: The Dart `Duration` value to convert
  ///
  /// Returns a new Duration with the same length as the given Dart `Duration`.
  ///
  /// Throws [RangeError] if the Dart `Duration` is outside the range of [Duration].
  static Duration FromCoreDuration(core.Duration timeSpan) {
    // C#: return FromTicks(timeSpan.Ticks);
    // (noda_dart: seconds, then microseconds, as a Dart Duration's range is wider than a TimeSpan's.)
    int microseconds = timeSpan.inMicroseconds;
    return FromSeconds(microseconds ~/ core.Duration.microsecondsPerSecond) +
        FromNanoseconds(microseconds.remainder(core.Duration.microsecondsPerSecond) *
            NodaConstants.NanosecondsPerMicrosecond);
  }

  /// Returns a Dart [core.Duration] that represents the same length of time as this [Duration].
  ///
  /// (C#'s `ToTimeSpan()`. A Dart `Duration` counts microseconds, each of which is 10 ticks.)
  ///
  /// If the number of nanoseconds in a duration is not a whole number of ticks, it is truncated towards zero.
  /// For example, durations in the range [-99ns, 99ns] would all count as 0 ticks.
  /// (noda_dart: the ticks are then truncated towards zero to microseconds.)
  ///
  /// Throws [OverflowException] if the number of ticks cannot be represented a signed 64-bit integer.
  ///
  /// Returns a new Dart `Duration` with the same length of time as this Duration.
  core.Duration ToCoreDuration() => core.Duration(microseconds: BclCompatibleTicks ~/ 10);

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable members (XML serialization)
  // #endregion

  /// Conversion to an `Int64` number of nanoseconds. This will fail if the number of nanoseconds is
  /// out of the range of `Int64`, which is approximately 292 years (positive or negative).
  ///
  /// Throws [OverflowException] if the number of nanoseconds is outside the representable range.
  ///
  /// Returns this duration as a number of nanoseconds, represented as an `Int64`.
  int ToInt64Nanoseconds() =>
      // Fast path (common case)
      IsInt64Representable
          ? _ToInt64NanosecondsUnchecked()
          // Need to be careful to avoid overflow in a case where it's actually representable
          : _days < 0
              ? Checked.Subtract(
                  Checked.Add(Checked.Multiply(_days + 1, NodaConstants.NanosecondsPerDay), _nanoOfDay),
                  NodaConstants.NanosecondsPerDay)
              // Either the multiplication or the addition could overflow, so we do it in a checked context.
              : Checked.Add(Checked.Multiply(_days, NodaConstants.NanosecondsPerDay), _nanoOfDay);

  /// A quick check to tell whether this duration is within the range of an Int64 value of nanoseconds
  /// (roughly +/- 292 years). This is conservative as it only checks the days field -
  /// there may be values just within Int64 range for which this property returns true, but they're
  /// unlikely to come up... this property should *only* be used for optimization purposes.
  @internal
  bool get IsInt64Representable => _days >= _MinDaysForLongNanos && _days <= _MaxDaysForLongNanos;

  /// Performs an unchecked conversion from this duration to an Int64 value of nanoseconds.
  /// This should only be called if IsInt64Representable returns true.
  int _ToInt64NanosecondsUnchecked() => _days * NodaConstants.NanosecondsPerDay + _nanoOfDay;

  // NOTE: Do not use from internal code. Use decimal instead. TODO: Add an attribute, and use a Roslyn analyzer to validate.

  /// Conversion to a [BigInt] number of nanoseconds, as a convenient built-in numeric
  /// type which can always represent values in the range we need.
  ///
  /// (C#'s `ToBigIntegerNanoseconds()`, and `ToInt128Nanoseconds()`.)
  ///
  /// Returns this duration as a number of nanoseconds, represented as a `BigInt`.
  // noda_dart: always BigInt on dart2js, where the Int64 nanoseconds aren't exact beyond 2^53.
  BigInt ToBigIntegerNanoseconds() => IsInt64Representable && Int64.IsExact
      ? BigInt.from(_ToInt64NanosecondsUnchecked())
      : BigInt.from(_days) * BigInt.from(NodaConstants.NanosecondsPerDay) + BigInt.from(_nanoOfDay);

  // Not ported: ToInt128Nanoseconds (Dart has no Int128: see ToBigIntegerNanoseconds)

  /// C#'s internal `ToDecimalNanoseconds()`: the number of nanoseconds as an integral decimal (a [BigInt] in
  /// noda_dart; see [DecimalArithmetic]).
  @internal
  // noda_dart: always BigInt on dart2js, where the Int64 nanoseconds aren't exact beyond 2^53.
  BigInt ToDecimalNanoseconds() => IsInt64Representable && Int64.IsExact
      ? BigInt.from(_ToInt64NanosecondsUnchecked())
      : BigInt.from(_days) * BigInt.from(NodaConstants.NanosecondsPerDay) + BigInt.from(_nanoOfDay);

  /// Returns the larger duration of the given two.
  ///
  /// A "larger" duration is one that advances time by more than a "smaller" one. This means
  /// that a positive duration is always larger than a negative one, for example. (This is the same
  /// comparison used by the binary comparison operators.)
  ///
  /// [x]: The first duration to compare.
  /// [y]: The second duration to compare.
  ///
  /// Returns the larger duration of [x] or [y].
  static Duration Max(Duration x, Duration y) {
    return x > y ? x : y;
  }

  /// Returns the smaller duration of the given two.
  ///
  /// A "larger" duration is one that advances time by more than a "smaller" one. This means
  /// that a positive duration is always larger than a negative one, for example. (This is the same
  /// comparison used by the binary comparison operators.)
  ///
  /// [x]: The first duration to compare.
  /// [y]: The second duration to compare.
  ///
  /// Returns the smaller duration of [x] or [y].
  static Duration Min(Duration x, Duration y) => x < y ? x : y;

  // #region JSON (noda_dart)
  /// Formats this value with [DurationPattern.JsonRoundtrip], as NodaTime.Serialization.SystemTextJson does.
  String toJson() => DurationPattern.JsonRoundtrip.Format(this);

  /// Parses a value written by [toJson].
  ///
  /// Throws [UnparsableValueException] if the text could not be parsed.
  factory Duration.fromJson(String json) => DurationPattern.JsonRoundtrip.Parse(json).Value;
  // #endregion
}
