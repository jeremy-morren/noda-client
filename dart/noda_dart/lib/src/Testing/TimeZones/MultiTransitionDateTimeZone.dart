// Ported from NodaTime 6e024dde: src/NodaTime.Testing/TimeZones/MultiTransitionDateTimeZone.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../../DateTimeZone.dart';
import '../../Instant.dart';
import '../../Offset.dart';
import '../../TimeZones/ZoneInterval.dart';

/// Time zone with multiple transitions, created via a builder.
final class MultiTransitionDateTimeZone extends DateTimeZone {
  /// Gets the zone intervals within this time zone, in chronological order, spanning the whole time line.
  ///
  /// The zone intervals within this time zone, in chronological order, spanning the whole time line.
  final List<ZoneInterval> Intervals;

  /// Gets the transition points between intervals.
  ///
  /// The transition points between intervals.
  final List<Instant> Transitions;

  MultiTransitionDateTimeZone._NewIdIntervals(String id, List<ZoneInterval> intervals)
      : Intervals = List<ZoneInterval>.unmodifiable(intervals),
        Transitions = List<Instant>.unmodifiable(intervals.skip(1).map((x) => x.Start)),
        super(
          id,
          intervals.length == 1,
          intervals.map((x) => x.WallOffset).reduce(Offset.Min),
          intervals.map((x) => x.WallOffset).reduce(Offset.Max),
        );

  /// Returns the zone interval for the given instant.
  @override
  ZoneInterval GetZoneInterval(Instant instant) {
    var lower = 0; // Inclusive
    var upper = Intervals.length; // Exclusive

    while (lower < upper) {
      final current = (lower + upper) ~/ 2;
      final candidate = Intervals[current];
      if (candidate.HasStart && candidate.Start > instant) {
        upper = current;
      } else if (candidate.HasEnd && candidate.End <= instant) {
        lower = current + 1;
      } else {
        return candidate;
      }
    }
    // Note: this would indicate a bug. The time zone is meant to cover the whole of time.
    throw StateError('Instant $instant did not exist in time zone $Id');
  }
}

/// Builder to create instances of [MultiTransitionDateTimeZone]. Each builder
/// can only be built once.
///
/// (NodaTime's nested class `MultiTransitionDateTimeZone.Builder`.)
final class MultiTransitionDateTimeZoneBuilder {
  final List<ZoneInterval> _intervals = <ZoneInterval>[];
  Offset _currentStandardOffset;
  Offset _currentSavings;
  String _currentName;
  bool _built = false;

  /// Gets the ID of the time zone which will be built.
  ///
  /// The ID of the time zone which will be built.
  String Id;

  /// Constructs a builder using the given first name, standard offset, and daylight saving offset.
  /// The ID is initially "MultiZone".
  ///
  /// (NodaTime's `Builder()`, `Builder(int firstStandardOffsetHours, int firstSavingOffsetHours)` and
  /// `Builder(int firstStandardOffsetHours, int firstSavingOffsetHours, string firstName)`, as one constructor: an
  /// initial offset of zero (standard and savings), and an initial name of "First", by default.)
  ///
  /// [firstStandardOffsetHours]: Standard offset in hours in the first zone interval.
  /// [firstSavingOffsetHours]: Daylight saving offset in hours in the first zone interval.
  /// [firstName]: Name of the first zone interval.
  MultiTransitionDateTimeZoneBuilder(
      [int firstStandardOffsetHours = 0, int firstSavingOffsetHours = 0, String firstName = 'First'])
      : Id = 'MultiZone',
        _currentName = firstName,
        _currentStandardOffset = Offset.FromHours(firstStandardOffsetHours),
        _currentSavings = Offset.FromHours(firstSavingOffsetHours);

  /// Constructs a builder using the given first name, standard offset, and a daylight saving
  /// offset of 0. The ID is initially "MultiZone".
  ///
  /// [firstName]: Name of the first zone interval.
  /// [firstOffsetHours]: Standard offset in hours in the first zone interval.
  MultiTransitionDateTimeZoneBuilder.FirstOffsetHoursFirstName(int firstOffsetHours, String firstName)
      : this(firstOffsetHours, 0, firstName);

  /// Adds a transition at the given instant, to the specified new standard offset,
  /// with the new specified daylight saving. The name is generated from the transition.
  ///
  /// (NodaTime's three `Add` overloads, as one method: no daylight saving, and a name generated from the transition,
  /// by default.)
  ///
  /// [transition]: Instant at which the zone changes.
  /// [newStandardOffsetHours]: The new standard offset, in hours.
  /// [newSavingOffsetHours]: The new daylight saving offset, in hours.
  /// [newName]: The new zone interval name.
  void Add(Instant transition, int newStandardOffsetHours, [int newSavingOffsetHours = 0, String? newName]) {
    newName ??= 'Interval from $transition';
    _EnsureNotBuilt();
    final previousStart = _intervals.isEmpty ? null : _intervals.last.End;
    // The ZoneInterval constructor will perform validation.
    _intervals.add(ZoneInterval(_currentName, previousStart, transition, _currentStandardOffset + _currentSavings, _currentSavings));
    _currentName = newName;
    _currentStandardOffset = Offset.FromHours(newStandardOffsetHours);
    _currentSavings = Offset.FromHours(newSavingOffsetHours);
  }

  /// Builds a [MultiTransitionDateTimeZone] from this builder, invalidating it in the process.
  ///
  /// Returns the newly-built zone.
  MultiTransitionDateTimeZone Build() {
    _EnsureNotBuilt();
    _built = true;
    final previousStart = _intervals.isEmpty ? null : _intervals.last.End;
    _intervals.add(ZoneInterval(_currentName, previousStart, null, _currentStandardOffset + _currentSavings, _currentSavings));
    return MultiTransitionDateTimeZone._NewIdIntervals(Id, _intervals);
  }

  void _EnsureNotBuilt() {
    if (_built) {
      throw StateError('Cannot use a builder after building');
    }
  }

  // Not ported: IEnumerable.GetEnumerator (only for C# collection initializers)
}
