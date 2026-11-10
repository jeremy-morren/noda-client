// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/ZoneTransition.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../Instant.dart' as nt show Instant;
import '../../Offset.dart';
import '../../TimeZones/ZoneInterval.dart';

/// Represents a transition two different time references.
///
/// Normally this is between standard time and daylight savings time.
///
/// Immutable, thread safe.
@internal
final class ZoneTransition {
  /// Initializes a new instance of the [ZoneTransition] class.
  ///
  /// [instant]: The instant that this transition occurs at.
  /// [name]: The name for the time at this transition e.g. PDT or PST.
  /// [standardOffset]: The standard offset at this transition.
  /// [savings]: The actual offset at this transition.
  ZoneTransition.NewInstantNameStandardOffsetSavings(nt.Instant instant, String name, Offset standardOffset, Offset savings)
      // Dart: null safety checks name.
      : Instant = instant,
        Name = name,
        StandardOffset = standardOffset,
        Savings = savings;

  /// The instant at which the transition occurs.
  final nt.Instant Instant;

  /// The name of the zone interval after this transition.
  final String Name;

  /// The standard offset after this transition.
  final Offset StandardOffset;

  /// The daylight savings after this transition.
  final Offset Savings;

  /// The wall offset (savings + standard) after this transition.
  Offset get WallOffset => StandardOffset + Savings;

  /// Determines whether is a transition from the given transition.
  ///
  /// To be a transition from another the instant at which the transition occurs must be
  /// greater than the given transition's and at least one aspect out of (name, standard
  /// offset, wall offset) must differ. If this is not true then this transition is considered
  /// to be redundant and should not be used. Note that there are a few transitions which
  /// keep the same wall offset and name, but differ in how that wall offset is divided into
  /// daylight saving and standard components. One notable example of this is October 27th 1968, when
  /// the UK went from "British Summer Time" (BST, standard=0, daylight=1) to "British Standard Time"
  /// (BST, standard=1, daylight=0).
  ///
  /// [other]: The [ZoneTransition] to compare to.
  ///
  /// Returns `true` if this is a transition from the given transition; otherwise, `false`.
  bool IsTransitionFrom(ZoneTransition other) {
    // Dart: null safety checks other.
    final later = Instant > other.Instant;
    final different = Name != other.Name || StandardOffset != other.StandardOffset || Savings != other.Savings;
    return later && different;
  }

  /// Creates a new zone interval from this transition to the given end point.
  ///
  /// [end]: The end of the interval.
  ZoneInterval ToZoneInterval(nt.Instant end) =>
      ZoneInterval.NewNameStartEndWallOffsetSavings(Name, Instant, end, StandardOffset + Savings, Savings);

  // #region Object overrides

  /// Returns a [String] that represents this instance.
  ///
  /// Returns a [String] that represents this instance.
  @override
  String toString() => '$Name at $Instant $StandardOffset [$Savings]';
  // #endregion // Object overrides
}
