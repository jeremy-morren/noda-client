// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/ZoneInterval.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

// ZoneInterval has a member named Duration, which hides the type inside the class.
import '../Duration.dart' as nt show Duration;
import '../Instant.dart';
import '../LocalDateTime.dart';
import '../LocalInstant.dart';
import '../Offset.dart';
import '../Utility/HashCodeHelper.dart';
import '../Utility/Preconditions.dart';

/// Represents a range of time for which a particular Offset applies.
///
/// Equality is defined component-wise in terms of all properties: the name, the start and end, and the offsets.
/// There is no ordering defined between zone intervals.
final class ZoneInterval {
  /// Returns the underlying start instant of this zone interval. If the zone interval extends to the
  /// beginning of time, the return value will be [Instant.BeforeMinValue]; this value
  /// should *not* be exposed publicly.
  @internal
  final Instant RawStart;

  /// Returns the underlying end instant of this zone interval. If the zone interval extends to the
  /// end of time, the return value will be [Instant.AfterMaxValue]; this value
  /// should *not* be exposed publicly.
  @internal
  final Instant RawEnd;

  final LocalInstant _localStart;
  final LocalInstant _localEnd;

  /// Gets the standard offset for this period. This is the offset without any daylight savings
  /// contributions.
  ///
  /// This is effectively `WallOffset - Savings`.
  Offset get StandardOffset {
    return WallOffset - Savings;
  }

  /// Gets the duration of this zone interval.
  ///
  /// This is effectively `End - Start`.
  ///
  /// Throws [StateError] if this zone extends to the start or end of time.
  nt.Duration get Duration {
    return End - Start;
  }

  /// Returns `true` if this zone interval has a fixed start point, or `false` if it
  /// extends to the beginning of time.
  bool get HasStart => RawStart.IsValid;

  /// Gets the last Instant (exclusive) that the Offset applies.
  ///
  /// Throws [StateError] if the zone interval extends to the end of time
  Instant get End {
    Preconditions.CheckState(RawEnd.IsValid, 'Zone interval extends to the end of time');
    return RawEnd;
  }

  /// Returns `true` if this zone interval has a fixed end point, or `false` if it
  /// extends to the end of time.
  bool get HasEnd => RawEnd.IsValid;

  // TODO(feature): Consider whether we need some way of checking whether IsoLocalStart/End will throw.
  // Clients can check HasStart/HasEnd for infinity, but what about unrepresentable local values?

  /// Gets the local start time of the interval, as a [LocalDateTime]
  /// in the ISO calendar.
  ///
  /// The local start time of the interval in the ISO calendar, with the offset of
  /// this zone interval.
  ///
  /// Throws [OverflowException] if the interval starts too early to represent as a `LocalDateTime`.
  /// Throws [StateError] if the interval extends to the start of time.
  LocalDateTime get IsoLocalStart {
    // Use the Start property to trigger the appropriate end-of-time exception.
    // Call Plus to trigger an appropriate out-of-range exception.
    return LocalDateTime.NewLocalInstant(Start.PlusOffset(WallOffset));
  }

  /// Gets the local end time of the interval, as a [LocalDateTime]
  /// in the ISO calendar.
  ///
  /// The local end time of the interval in the ISO calendar, with the offset
  /// of this zone interval. As the end time is exclusive, by the time this local time
  /// is reached, the next interval will be in effect and the local time will usually
  /// have changed (e.g. by adding or subtracting an hour).
  ///
  /// Throws [OverflowException] if the interval ends too late to represent as a `LocalDateTime`.
  /// Throws [StateError] if the interval extends to the end of time.
  LocalDateTime get IsoLocalEnd {
    // Use the End property to trigger the appropriate end-of-time exception.
    // Call Plus to trigger an appropriate out-of-range exception.
    return LocalDateTime.NewLocalInstant(End.PlusOffset(WallOffset));
  }

  /// Gets the name of this offset period (e.g. PST or PDT).
  final String Name;

  /// Gets the offset from UTC for this period. This includes any daylight savings value.
  final Offset WallOffset;

  /// Gets the daylight savings value for this period.
  final Offset Savings;

  /// Gets the first Instant that the Offset applies.
  ///
  /// Throws [StateError] if the interval extends to the start of time.
  Instant get Start {
    Preconditions.CheckState(RawStart.IsValid, 'Zone interval extends to the beginning of time');
    return RawStart;
  }

  /// Initializes a new instance of the [ZoneInterval] class.
  ///
  /// [name]: The name of this offset period (e.g. PST or PDT).
  /// [start]: The first [Instant] that the [wallOffset] applies,
  /// or `null` to make the zone interval extend to the start of time.
  /// [end]: The last [Instant] (exclusive) that the [wallOffset] applies,
  /// or `null` to make the zone interval extend to the end of time.
  /// [wallOffset]: The [WallOffset] from UTC for this period including any daylight savings.
  /// [savings]: The [WallOffset] daylight savings contribution to the offset.
  ///
  /// Throws [ArgumentError] if `start >= end`.
  ZoneInterval(String name, Instant? start, Instant? end, Offset wallOffset, Offset savings)
      : this.NewNameStartEndWallOffsetSavings(
            name, start ?? Instant.BeforeMinValue, end ?? Instant.AfterMaxValue, wallOffset, savings);

  /// Initializes a new instance of the [ZoneInterval] class.
  ///
  /// [name]: The name of this offset period (e.g. PST or PDT).
  /// [start]: The first [Instant] that the [wallOffset] applies,
  /// or [Instant.BeforeMinValue] to make the zone interval extend to the start of time.
  /// [end]: The last [Instant] (exclusive) that the [wallOffset] applies,
  /// or [Instant.AfterMaxValue] to make the zone interval extend to the end of time.
  /// [wallOffset]: The [WallOffset] from UTC for this period including any daylight savings.
  /// [savings]: The [WallOffset] daylight savings contribution to the offset.
  ///
  /// Throws [ArgumentError] if `start >= end`.
  @internal
  ZoneInterval.NewNameStartEndWallOffsetSavings(String name, Instant start, Instant end, Offset wallOffset, Offset savings)
      : Name = name,
        RawStart = start,
        RawEnd = end,
        WallOffset = wallOffset,
        Savings = savings,
        // Work out the corresponding local instants, taking care to "go infinite" appropriately.
        _localStart = start.SafePlus(wallOffset),
        _localEnd = end.SafePlus(wallOffset) {
    // Dart: null safety checks name.
    // Dart: checked after the fields are initialized (C#: before), as a Dart constructor body runs after its
    // initializer list; the initializers don't throw for any start and end.
    Preconditions.CheckArgument(
        start < end, 'start', 'The start Instant must be less than the end Instant. start: {0}; end: {1}', start, end);
  }

  /// Returns a copy of this zone interval, but with the given start instant.
  @internal
  ZoneInterval WithStart(Instant newStart) {
    return ZoneInterval.NewNameStartEndWallOffsetSavings(Name, newStart, RawEnd, WallOffset, Savings);
  }

  /// Returns a copy of this zone interval, but with the given end instant.
  @internal
  ZoneInterval WithEnd(Instant newEnd) {
    return ZoneInterval.NewNameStartEndWallOffsetSavings(Name, RawStart, newEnd, WallOffset, Savings);
  }

  // #region Contains
  ///   Determines whether this period contains the given Instant in its range.
  ///
  /// Usually this is half-open, i.e. the end is exclusive, but an interval with an end point of "the end of time"
  /// is deemed to be inclusive at the end.
  ///
  /// [instant]: The instant to test.
  ///
  /// Returns `true` if this period contains the given Instant in its range; otherwise, `false`.
  bool Contains(Instant instant) => RawStart <= instant && instant < RawEnd;

  ///   Determines whether this period contains the given LocalInstant in its range.
  ///
  /// [localInstant]: The local instant to test.
  ///
  /// Returns `true` if this period contains the given LocalInstant in its range; otherwise, `false`.
  @internal
  bool ContainsLocalInstant(LocalInstant localInstant) => _localStart <= localInstant && localInstant < _localEnd;

  /// Returns whether this zone interval has the same offsets and name as another.
  @internal
  bool EqualIgnoreBounds(ZoneInterval other) {
    Preconditions.DebugCheckNotNull(other, 'other');
    return other.WallOffset == WallOffset && other.Savings == Savings && other.Name == Name;
  }

  // #endregion // Contains

  // #region IEquatable<ZoneInterval> Members
  /// Indicates whether the current object is equal to another object of the same type.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: An object to compare with this object.
  ///
  /// Returns true if the current object is equal to the [other] parameter; otherwise, false.
  bool Equals(ZoneInterval? other) {
    if (other == null) {
      return false;
    }
    if (identical(this, other)) {
      return true;
    }
    return Name == other.Name && RawStart == other.RawStart && RawEnd == other.RawEnd
        && WallOffset == other.WallOffset && Savings == other.Savings;
  }

  /// Implements the operator == (equality).
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The right hand side of the operator.
  ///
  /// Returns `true` if values are equal to each other, otherwise `false`.
  @override
  bool operator ==(Object other) => identical(this, other) || (other is ZoneInterval && Equals(other));

  // Dart: != is Dart's own (the negation of ==).
  // #endregion

  // #region object Overrides
  /// Returns a hash code for this zone interval.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a hash code for this zone interval.
  @override
  int get hashCode =>
      HashCodeHelper.Initialize()
          .Hash(Name)
          .Hash(RawStart)
          .Hash(RawEnd)
          .Hash(WallOffset)
          .Hash(Savings)
          .Value;

  ///   Returns a [String] that represents this instance.
  ///
  ///   Returns a [String] that represents this instance.
  @override
  String toString() => '$Name: [$RawStart, $RawEnd) $WallOffset ($Savings)';

  // #endregion // object Overrides
}
