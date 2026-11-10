// Ported from NodaTime 6e024dde: src/NodaTime/LocalInstant.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'Duration.dart';
import 'Instant.dart';
import 'LocalDate.dart';
import 'LocalDateTime.dart';
import 'LocalTime.dart';
import 'Offset.dart';
import 'Text/InstantPatternParser.dart';
import 'Text/LocalDateTimePattern.dart';
import 'Utility/SystemExceptions.dart';

/// Represents a local date and time without reference to a calendar system. Essentially
/// this is a duration since a Unix epoch shifted by an offset (but we don't store what that
/// offset is). This class has been slimmed down considerably over time - it's used much less
/// than it used to be... almost solely for time zones.
@internal
final class LocalInstant {
  static final LocalInstant BeforeMinValue =
      LocalInstant._NewDaysDeliberatelyInvalid(Instant.BeforeMinValue.DaysSinceEpoch, true);
  static final LocalInstant AfterMaxValue =
      LocalInstant._NewDaysDeliberatelyInvalid(Instant.AfterMaxValue.DaysSinceEpoch, true);

  /// Elapsed time since the local 1970-01-01T00:00:00.
  final Duration _duration;

  /// Constructor which should *only* be used to construct the invalid instances.
  LocalInstant._NewDaysDeliberatelyInvalid(int days, bool deliberatelyInvalid)
      : _duration = Duration.NewDaysNanoOfDay(days, 0);

  const LocalInstant._NewDuration(Duration duration) : _duration = duration;

  /// Initializes a new instance of the [LocalInstant] struct.
  factory LocalInstant.NewNanoseconds(Duration nanoseconds) {
    int days = nanoseconds.FloorDays;
    if (days < Instant.MinDays || days > Instant.MaxDays) {
      throw OverflowException('Operation would overflow bounds of local date/time');
    }
    return LocalInstant._NewDuration(nanoseconds);
  }

  /// Initializes a new instance of the [LocalInstant] struct.
  ///
  /// [days]: Number of days since 1970-01-01, in a time zone neutral fashion.
  /// [nanoOfDay]: Nanosecond of the local day.
  LocalInstant.NewDaysNanoOfDay(int days, int nanoOfDay) : _duration = Duration.NewDaysNanoOfDay(days, nanoOfDay);

  /// Returns whether or not this is a valid instant. Returns true for all but
  /// [BeforeMinValue] and [AfterMaxValue].
  bool get IsValid => DaysSinceEpoch >= Instant.MinDays && DaysSinceEpoch <= Instant.MaxDays;

  /// Number of nanoseconds since the local unix epoch.
  Duration get TimeSinceLocalEpoch => _duration;

  /// Number of days since the local unix epoch.
  int get DaysSinceEpoch => _duration.FloorDays;

  /// Nanosecond within the day.
  int get NanosecondOfDay => _duration.NanosecondOfFloorDay;

  // #region Operators
  /// Returns a new instant based on this local instant, as if we'd applied a zero offset.
  /// This is just a slight optimization over calling `localInstant.Minus(Offset.Zero)`.
  Instant MinusZeroOffset() => Instant.FromTrustedDuration(_duration);

  /// Subtracts the given time zone offset from this local instant, to give an [Instant].
  ///
  /// This would normally be implemented as an operator, but as the corresponding "plus" operation
  /// on Instant cannot be written (as Instant is a public type and LocalInstant is an internal type)
  /// it makes sense to keep them both as methods for consistency.
  ///
  /// [offset]: The offset between UTC and a time zone for this local instant
  ///
  /// Returns a new [Instant] representing the difference of the given values.
  Instant Minus(Offset offset) => Instant.FromUntrustedDuration(_duration.MinusSmallNanoseconds(offset.Nanoseconds));

  // C#'s operator == is Dart's == (Object overrides, below) and Equals.

  /// Equivalent to [Instant.SafePlus], but in the opposite direction.
  Instant SafeMinus(Offset offset) {
    int days = _duration.FloorDays;
    // If we can do the arithmetic safely, do so.
    if (days > Instant.MinDays && days < Instant.MaxDays) {
      return Minus(offset);
    }
    // Handle BeforeMinValue and BeforeMaxValue simply.
    if (days < Instant.MinDays) {
      return Instant.BeforeMinValue;
    }
    if (days > Instant.MaxDays) {
      return Instant.AfterMaxValue;
    }
    // Okay, do the arithmetic as a Duration, then check the result for overflow, effectively.
    var asDuration = _duration.MinusSmallNanoseconds(offset.Nanoseconds);
    if (asDuration.FloorDays < Instant.MinDays) {
      return Instant.BeforeMinValue;
    }
    if (asDuration.FloorDays > Instant.MaxDays) {
      return Instant.AfterMaxValue;
    }
    // And now we don't need any more checks.
    return Instant.FromTrustedDuration(asDuration);
  }

  // C#'s operator != is Dart's.

  /// Implements the operator &lt; (less than).
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is less than the right value, otherwise `false`.
  bool operator <(LocalInstant right) => _duration < right._duration;

  /// Implements the operator &lt;= (less than or equal).
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is less than or equal to the right value, otherwise `false`.
  bool operator <=(LocalInstant right) => _duration <= right._duration;

  /// Implements the operator &gt; (greater than).
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is greater than the right value, otherwise `false`.
  bool operator >(LocalInstant right) => _duration > right._duration;

  /// Implements the operator &gt;= (greater than or equal).
  ///
  /// [right]: The right hand side of the operator.
  ///
  /// Returns `true` if the left value is greater than or equal to the right value, otherwise `false`.
  bool operator >=(LocalInstant right) => _duration >= right._duration;
  // #endregion // Operators

  // #region Object overrides
  /// Determines whether the specified object is equal to this instance.
  ///
  /// [other]: The object to compare with this instance.
  ///
  /// Returns `true` if the specified object is equal to this instance;
  /// otherwise, `false`.
  @override
  bool operator ==(Object other) => other is LocalInstant && Equals(other);

  /// Returns a hash code for this instance.
  ///
  /// Returns a hash code for this instance, suitable for use in hashing algorithms and data
  /// structures like a hash table.
  @override
  int get hashCode => _duration.hashCode;

  /// Returns a [String] that represents this instance.
  @override
  String toString() {
    if (this == BeforeMinValue) {
      return InstantPatternParser.BeforeMinValueText;
    }
    if (this == AfterMaxValue) {
      return InstantPatternParser.AfterMaxValueText;
    }
    var date = LocalDate.NewDaysSinceEpoch(_duration.FloorDays);
    var pattern = LocalDateTimePattern.CreateWithInvariantCulture("uuuu-MM-ddTHH:mm:ss.FFFFFFFFF 'LOC'");
    var utc = LocalDateTime.NewDateTime(date, LocalTime.FromNanosecondsSinceMidnight(_duration.NanosecondOfFloorDay));
    return pattern.Format(utc);
  }
  // #endregion  // Object overrides

  // #region IEquatable<LocalInstant> Members
  /// Indicates whether the current object is equal to another object of the same type.
  ///
  /// [other]: An object to compare with this object.
  ///
  /// Returns true if the current object is equal to the [other] parameter;
  /// otherwise, false.
  bool Equals(LocalInstant other) => _duration.Equals(other._duration);
  // #endregion
}
