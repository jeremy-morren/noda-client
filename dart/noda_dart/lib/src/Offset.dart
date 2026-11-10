// Ported from NodaTime 6e024dde: src/NodaTime/Offset.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:core';
import 'dart:core' as core;

import 'package:meta/meta.dart';

import 'Globalization/NodaCultureInfo.dart';
import 'NodaConstants.dart';
import 'Text/OffsetPattern.dart';
import 'Utility/Checked.dart';
import 'Utility/Preconditions.dart';

const int _MinHours = -18;
const int _MaxHours = 18;
const int _MinMilliseconds = -18 * NodaConstants.MillisecondsPerHour;
const int _MaxMilliseconds = 18 * NodaConstants.MillisecondsPerHour;
const int _MinTicks = -18 * NodaConstants.TicksPerHour;
const int _MaxTicks = 18 * NodaConstants.TicksPerHour;
const int _MinNanoseconds = -18 * NodaConstants.NanosecondsPerHour;
const int _MaxNanoseconds = 18 * NodaConstants.NanosecondsPerHour;

/// An offset from UTC in seconds. A positive value means that the local time is
/// ahead of UTC (e.g. for Europe); a negative value means that the local time is behind
/// UTC (e.g. for America).
///
/// Offsets are always in the range of [-18, +18] hours. (Note that the ends are inclusive,
/// so an offset of 18 hours can be represented, but an offset of 18 hours and one second cannot.)
/// This allows all offsets within TZDB to be represented. The BCL `DateTimeOffset` type
/// only allows offsets up to 14 hours, which means some historical data within TZDB could not be
/// represented.
///
/// Offsets are represented with a granularity of one second. This allows all offsets within TZDB
/// to be represented. It is possible that it could present issues to some other time zone data sources,
/// but only in very rare historical cases (or fictional ones).
///
/// Equality and ordering are defined in the natural way by comparing the underlying number
/// of seconds. For example, this means that offsets for America are ordered before offsets in Europe.
///
/// The default value of this type is [Zero].
///
/// This type is an immutable value type. See the thread safety section of the user guide for more information.
final class Offset implements Comparable<Offset> {
  // Note: these public fields are unfortunate; they really should be properties, like all other public constants.
  // Unfortunately that would now be a breaking change.

  /// An offset of zero seconds - effectively the permanent offset for UTC.
  static final Offset Zero = FromSeconds(0);

  /// The minimum permitted offset; 18 hours before UTC.
  static final Offset MinValue = FromHours(-18);

  /// The maximum permitted offset; 18 hours after UTC.
  static final Offset MaxValue = FromHours(18);

  /// Gets the additive identity.
  static Offset get AdditiveIdentity => Zero;

  @internal
  static const int MinSeconds = -18 * NodaConstants.SecondsPerHour;
  @internal
  static const int MaxSeconds = 18 * NodaConstants.SecondsPerHour;

  final int _seconds;

  /// Initializes a new instance of the [Offset] struct.
  ///
  /// [seconds]: The number of seconds in the offset.
  @internal
  Offset.NewSeconds(int seconds) : _seconds = seconds {
    Preconditions.DebugCheckArgumentRange('seconds', seconds, MinSeconds, MaxSeconds);
  }

  /// Gets the number of seconds represented by this offset, which may be negative.
  int get Seconds => _seconds;

  /// Gets the number of milliseconds represented by this offset, which may be negative.
  ///
  /// Offsets are only accurate to second precision; the number of seconds is simply multiplied
  /// by 1,000 to give the number of milliseconds.
  int get Milliseconds => _seconds * NodaConstants.MillisecondsPerSecond;

  /// Gets the number of ticks represented by this offset, which may be negative.
  ///
  /// Offsets are only accurate to second precision; the number of seconds is simply multiplied
  /// by 10,000,000 to give the number of ticks.
  int get Ticks => _seconds * NodaConstants.TicksPerSecond;

  /// Gets the number of nanoseconds represented by this offset, which may be negative.
  ///
  /// Offsets are only accurate to second precision; the number of seconds is simply multiplied
  /// by 1,000,000,000 to give the number of nanoseconds.
  int get Nanoseconds => _seconds * NodaConstants.NanosecondsPerSecond;

  /// Returns the greater offset of the given two, i.e. the one which will give a later local
  /// time when added to an instant.
  ///
  /// [x]: The first offset
  /// [y]: The second offset
  ///
  /// Returns the greater offset of [x] and [y].
  static Offset Max(Offset x, Offset y) => x > y ? x : y;

  /// Returns the lower offset of the given two, i.e. the one which will give an earlier local
  /// time when added to an instant.
  ///
  /// [x]: The first offset
  /// [y]: The second offset
  ///
  /// Returns the lower offset of [x] and [y].
  static Offset Min(Offset x, Offset y) => x < y ? x : y;

  // #region Operators
  /// Implements the unary operator - (negation).
  ///
  /// Returns a new [Offset] instance with a negated value.
  Offset operator -() =>
      // Guaranteed to still be in range.
      Offset.NewSeconds(-Seconds);

  /// Returns the negation of the specified offset. This is the method form of the unary minus operator.
  ///
  /// [offset]: The offset to negate.
  ///
  /// Returns the negation of the specified offset.
  static Offset Negate(Offset offset) => -offset;

  // Not ported: operator +(Offset) (unary plus; Dart has no unary + operator)

  /// Implements the operator + (addition).
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Throws [RangeError] if the result of the operation is outside the range of Offset.
  ///
  /// Returns a new [Offset] representing the sum of the given values.
  Offset operator +(Offset right) => FromSeconds(Seconds + right.Seconds);

  /// Adds one Offset to another. Friendly alternative to `operator+()`.
  ///
  /// [left]: The left hand side of the operator.
  /// [right]: The right hand side of the operator.
  ///
  /// Throws [RangeError] if the result of the operation is outside the range of Offset.
  ///
  /// Returns a new [Offset] representing the sum of the given values.
  static Offset Add(Offset left, Offset right) => left + right;

  /// Returns the result of adding another Offset to this one, for a fluent alternative to `operator+()`.
  ///
  /// [other]: The offset to add
  ///
  /// Throws [RangeError] if the result of the operation is outside the range of Offset.
  ///
  /// Returns the result of adding the other offset to this one.
  Offset Plus(Offset other) => this + other;

  /// Implements the operator - (subtraction).
  ///
  /// [subtrahend]: The right hand side of the operator.
  ///
  /// Throws [RangeError] if the result of the operation is outside the range of Offset.
  ///
  /// Returns a new [Offset] representing the difference of the given values.
  Offset operator -(Offset subtrahend) => FromSeconds(Seconds - subtrahend.Seconds);

  /// Subtracts one Offset from another. Friendly alternative to `operator-()`.
  ///
  /// [minuend]: The left hand side of the operator.
  /// [subtrahend]: The right hand side of the operator.
  ///
  /// Throws [RangeError] if the result of the operation is outside the range of Offset.
  ///
  /// Returns a new [Offset] representing the difference of the given values.
  static Offset Subtract(Offset minuend, Offset subtrahend) => minuend - subtrahend;

  /// Returns the result of subtracting another Offset from this one, for a fluent alternative to `operator-()`.
  ///
  /// [other]: The offset to subtract
  ///
  /// Throws [RangeError] if the result of the operation is outside the range of Offset.
  ///
  /// Returns the result of subtracting the other offset from this one.
  Offset Minus(Offset other) => this - other;

  // C#'s operator == and != are Dart's == (Object overrides, below) and Equals.

  /// Implements the operator &lt; (less than).
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is less than the right value, otherwise `false`.
  bool operator <(Offset right) => compareTo(right) < 0;

  /// Implements the operator &lt;= (less than or equal).
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is less than or equal to the right value, otherwise `false`.
  bool operator <=(Offset right) => compareTo(right) <= 0;

  /// Implements the operator &gt; (greater than).
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is greater than the right value, otherwise `false`.
  bool operator >(Offset right) => compareTo(right) > 0;

  /// Implements the operator &gt;= (greater than or equal).
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is greater than or equal to the right value, otherwise `false`.
  bool operator >=(Offset right) => compareTo(right) >= 0;
  // #endregion // Operators

  // #region IComparable<Offset> Members
  /// Compares the current object with another object of the same type.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// [other]: An object to compare with this object.
  ///
  /// Returns a 32-bit signed integer that indicates the relative order of the objects being compared:
  /// less than 0 if this object is less than the [other] parameter, 0 if this object is equal to [other],
  /// and greater than 0 if this object is greater than [other].
  @override
  int compareTo(Offset other) => Seconds.compareTo(other.Seconds);

  /// Implementation of `IComparable.CompareTo` to compare two offsets.
  /// See the type documentation for a description of ordering semantics.
  ///
  /// This uses explicit interface implementation to avoid it being called accidentally. The generic implementation should usually be preferred.
  ///
  /// Throws [ArgumentError] if [obj] is non-null but does not refer to an instance of [Offset].
  ///
  /// [obj]: The object to compare this value with.
  ///
  /// Returns the result of comparing this instant with another one; see [compareTo] for general details.
  /// If [obj] is null, this method returns a value greater than 0.
  int CompareTo(Object? obj) {
    if (obj == null) {
      return 1;
    }
    Preconditions.CheckArgument(obj is Offset, 'obj', 'Object must be of type NodaTime.Offset.');
    return compareTo(obj as Offset);
  }
  // #endregion

  // #region IEquatable<Offset> Members
  /// Indicates whether the current object is equal to another object of the same type.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: An object to compare with this object.
  ///
  /// Returns true if the current object is equal to the [other] parameter;
  /// otherwise, false.
  bool Equals(Offset other) => Seconds == other.Seconds;
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
  bool operator ==(Object other) => other is Offset && Equals(other);

  /// Returns a hash code for this instance.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a hash code for this instance, suitable for use in hashing algorithms and data
  /// structures like a hash table.
  @override
  int get hashCode => Seconds.hashCode;
  // #endregion  // Object overrides

  // #region Formatting
  /// Returns a [String] that represents this instance.
  ///
  /// Returns the value of the current instance in the default format pattern ("g"), using the invariant culture.
  /// (NodaTime uses the current thread's culture.)
  @override
  String toString() => OffsetPattern.BclSupport.Format(this, null, NodaCultureInfo.InvariantCulture);

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
      OffsetPattern.BclSupport.Format(this, patternText, formatProvider);
  // #endregion Formatting

  // #region Construction
  /// Returns an offset for the given seconds value, which may be negative.
  ///
  /// [seconds]: The int seconds value.
  ///
  /// Returns an offset representing the given number of seconds.
  ///
  /// Throws [RangeError] if the specified number of seconds is outside the range of
  /// [-18, +18] hours.
  static Offset FromSeconds(int seconds) {
    Preconditions.CheckArgumentRange('seconds', seconds, MinSeconds, MaxSeconds);
    return Offset.NewSeconds(seconds);
  }

  /// Returns an offset for the given milliseconds value, which may be negative.
  ///
  /// Offsets are only accurate to second precision; the given number of milliseconds is simply divided
  /// by 1,000 to give the number of seconds - any remainder is truncated.
  ///
  /// [milliseconds]: The int milliseconds value.
  ///
  /// Returns an offset representing the given number of milliseconds, to the (truncated) second.
  ///
  /// Throws [RangeError] if the specified number of milliseconds is outside the range of
  /// [-18, +18] hours.
  static Offset FromMilliseconds(int milliseconds) {
    Preconditions.CheckArgumentRange('milliseconds', milliseconds, _MinMilliseconds, _MaxMilliseconds);
    return Offset.NewSeconds(milliseconds ~/ NodaConstants.MillisecondsPerSecond);
  }

  /// Returns an offset for the given number of ticks, which may be negative.
  ///
  /// Offsets are only accurate to second precision; the given number of ticks is simply divided
  /// by 10,000,000 to give the number of seconds - any remainder is truncated.
  ///
  /// [ticks]: The number of ticks specifying the length of the new offset.
  ///
  /// Returns an offset representing the given number of ticks, to the (truncated) second.
  ///
  /// Throws [RangeError] if the specified number of ticks is outside the range of
  /// [-18, +18] hours.
  static Offset FromTicks(int ticks) {
    Preconditions.CheckArgumentRange('ticks', ticks, _MinTicks, _MaxTicks);
    return Offset.NewSeconds(ticks ~/ NodaConstants.TicksPerSecond);
  }

  /// Returns an offset for the given number of nanoseconds, which may be negative.
  ///
  /// Offsets are only accurate to second precision; the given number of nanoseconds is simply divided
  /// by 1,000,000,000 to give the number of seconds - any remainder is truncated towards zero.
  ///
  /// [nanoseconds]: The number of nanoseconds specifying the length of the new offset.
  ///
  /// Returns an offset representing the given number of nanoseconds, to the (truncated) second.
  ///
  /// Throws [RangeError] if the specified number of nanoseconds is outside the range of
  /// [-18, +18] hours.
  static Offset FromNanoseconds(int nanoseconds) {
    Preconditions.CheckArgumentRange('nanoseconds', nanoseconds, _MinNanoseconds, _MaxNanoseconds);
    return Offset.NewSeconds(nanoseconds ~/ NodaConstants.NanosecondsPerSecond);
  }

  /// Returns an offset for the specified number of hours, which may be negative.
  ///
  /// [hours]: The number of hours to represent in the new offset.
  ///
  /// Returns an offset representing the given value.
  ///
  /// Throws [RangeError] if the specified number of hours is outside the range of
  /// [-18, +18].
  static Offset FromHours(int hours) {
    Preconditions.CheckArgumentRange('hours', hours, _MinHours, _MaxHours);
    return Offset.NewSeconds(hours * NodaConstants.SecondsPerHour);
  }

  /// Returns an offset for the specified number of hours and minutes.
  ///
  /// The result simply takes the hours and minutes and converts each component into milliseconds
  /// separately. As a result, a negative offset should usually be obtained by making both arguments
  /// negative. For example, to obtain "three hours and ten minutes behind UTC" you might call
  /// `Offset.FromHoursAndMinutes(-3, -10)`.
  ///
  /// [hours]: The number of hours to represent in the new offset.
  /// [minutes]: The number of minutes to represent in the new offset.
  ///
  /// Returns an offset representing the given value.
  ///
  /// Throws [RangeError] if the result of the operation is outside the range of Offset.
  static Offset FromHoursAndMinutes(int hours, int minutes) => FromSeconds(Checked.AddInt32(
      Checked.MultiplyInt32(hours, NodaConstants.SecondsPerHour),
      Checked.MultiplyInt32(minutes, NodaConstants.SecondsPerMinute)));
  // #endregion

  // #region Conversion
  /// Converts this offset to a Dart [core.Duration] value.
  ///
  /// (C#'s `ToTimeSpan()`.)
  ///
  /// Returns an equivalent Dart `Duration` to this value.
  core.Duration ToCoreDuration() => core.Duration(seconds: _seconds);

  /// Converts the given Dart [core.Duration] to an offset, with fractional seconds truncated.
  ///
  /// (C#'s `FromTimeSpan(TimeSpan)`. A Dart `Duration` counts microseconds, each of which is 10 ticks.)
  ///
  /// [timeSpan]: The Dart `Duration` to convert
  ///
  /// Throws [RangeError] if the given Dart `Duration` falls outside the range of +/- 18 hours.
  ///
  /// Returns an offset for the same time as the given Dart `Duration`.
  static Offset FromCoreDuration(core.Duration timeSpan) {
    // C#: long ticks = timeSpan.Ticks; (noda_dart: checked as microseconds so the conversion can't overflow.)
    int microseconds = timeSpan.inMicroseconds;
    Preconditions.CheckArgumentRange('timeSpan', microseconds, _MinTicks ~/ 10, _MaxTicks ~/ 10);
    return FromTicks(microseconds * 10);
  }
  // #endregion

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable members (XML serialization)
  // #endregion

  // #region JSON (noda_dart)
  /// Formats this value with [OffsetPattern.GeneralInvariant], as NodaTime.Serialization.SystemTextJson does.
  String toJson() => OffsetPattern.GeneralInvariant.Format(this);

  /// Parses a value written by [toJson].
  ///
  /// Throws [UnparsableValueException] if the text could not be parsed.
  factory Offset.fromJson(String json) => OffsetPattern.GeneralInvariant.Parse(json).Value;
  // #endregion
}
