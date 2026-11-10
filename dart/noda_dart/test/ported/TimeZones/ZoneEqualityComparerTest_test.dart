// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/ZoneEqualityComparerTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/Interval.dart';
import 'package:noda_dart/src/Testing/TimeZones/MultiTransitionDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/ZoneEqualityComparer.Options.generated.dart';
import 'package:noda_dart/src/TimeZones/ZoneEqualityComparer.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/TimeZones/ZoneEqualityComparerTest.generated.dart' as scenarios;

// Sample instants for use in tests. They're on January 1st 2000...2009, midnight UTC.
final List<Instant> Instants = List<Instant>.unmodifiable(
    List<int>.generate(10, (i) => 2000 + i).map((year) => Instant.FromUtc(year, 1, 1, 0, 0)).toList());

void main() {
  port(scenarios.fixture, {
    // Various tests using a pair of zones which can demonstrate a number of
    // different features.
    'Various': (args) {
      // Names, some offsets, and first transition are all different.
      var zone1 = (MultiTransitionDateTimeZoneBuilder()
            ..Add(Instants[0], 1, 0, 'xx')
            ..Add(Instants[2], 3, 0, '1b')
            ..Add(Instants[4], 2, 1, '1c')
            ..Add(Instants[6], 4, 0, '1d'))
          .Build();
      var zone2 = (MultiTransitionDateTimeZoneBuilder()
            ..Add(Instants[1], 1, 0, 'xx')
            ..Add(Instants[2], 3, 0, '2b')
            ..Add(Instants[4], 1, 2, '2c')
            ..Add(Instants[6], 5, 0, '2d'))
          .Build();
      // Even though the first transition point is different, by default that's fine if
      // the start point is "inside" both.
      AssertEqual(zone1, zone2, Instants[1], Instants[5], ZoneEqualityComparerOptions.OnlyMatchWallOffset);
      // When we extend backwards a bit, we can see the difference between the two.
      AssertNotEqual(zone1, zone2, Instants[1].MinusDuration(Duration.Epsilon), Instants[5], ZoneEqualityComparerOptions.OnlyMatchWallOffset);
      // Or if we force the start and end transitions to be exact...
      AssertNotEqual(zone1, zone2, Instants[1], Instants[5], ZoneEqualityComparerOptions.MatchStartAndEndTransitions);

      // The first two transitions have the same split between standard and saving...
      AssertEqual(zone1, zone2, Instants[1], Instants[4], ZoneEqualityComparerOptions.MatchOffsetComponents);
      // The third one (at Instants[4]) doesn't...
      AssertNotEqual(zone1, zone2, Instants[1], Instants[5], ZoneEqualityComparerOptions.MatchOffsetComponents);

      // The first transition has the same name for the zone interval...
      AssertEqual(zone1, zone2, Instants[1], Instants[2], ZoneEqualityComparerOptions.MatchNames);
      // The second transition (at Instants[2]) doesn't...
      AssertNotEqual(zone1, zone2, Instants[1], Instants[3], ZoneEqualityComparerOptions.MatchNames);
    },

    'ElidedTransitions': (args) {
      var zone1 = (MultiTransitionDateTimeZoneBuilder()
            ..Add(Instants[3], 0, 0, 'a')
            ..Add(Instants[4], 1, 2, 'b')
            ..Add(Instants[5], 2, 1, 'b')
            ..Add(Instants[6], 1, 0, 'd')
            ..Add(Instants[7], 1, 0, 'e')
            ..Add(Instants[8], 0, 0, 'x'))
          .Build();
      var zone2 = (MultiTransitionDateTimeZoneBuilder()
            ..Add(Instants[3], 0, 0, 'a')
            ..Add(Instants[4], 3, 0, 'b')
            // Instants[5] isn't included here: wall offset is the same; components change in zone1
            ..Add(Instants[6], 1, 0, 'd')
            // Instants[7] isn't included here: offset components are the same; names change in zone1
            ..Add(Instants[8], 0, 0, 'x'))
          .Build();

      AssertEqual(zone1, zone2, Instant.MinValue, Instant.MaxValue, ZoneEqualityComparerOptions.OnlyMatchWallOffset);
      // BOT-Instants[6] will elide transitions when ignoring components, even if we match names
      AssertEqual(zone1, zone2, Instant.MinValue, Instants[6], ZoneEqualityComparerOptions.MatchNames);
      AssertNotEqual(zone1, zone2, Instant.MinValue, Instants[6], ZoneEqualityComparerOptions.MatchOffsetComponents);
      // Instants[6]-EOT will elide transitions when ignoring names, even if we match components
      AssertEqual(zone1, zone2, Instants[6], Instant.MaxValue, ZoneEqualityComparerOptions.MatchOffsetComponents);
      AssertNotEqual(zone1, zone2, Instants[6], Instant.MaxValue, ZoneEqualityComparerOptions.MatchNames);

      // But if we require the exact transitions, both fail
      AssertNotEqual(zone1, zone2, Instant.MinValue, Instants[6], ZoneEqualityComparerOptions.MatchAllTransitions);
      AssertNotEqual(zone1, zone2, Instants[6], Instant.MaxValue, ZoneEqualityComparerOptions.MatchAllTransitions);
    },

    'ForInterval': (args) {
      var interval = Interval(Instants[3], Instants[5]);
      var comparer = ZoneEqualityComparer.ForInterval(interval);
      Assert.AreEqual(ZoneEqualityComparerOptions.OnlyMatchWallOffset, comparer.OptionsForTest);
      Assert.AreEqual(interval, comparer.IntervalForTest);
    },

    'WithOptions': (args) {
      var interval = Interval(Instants[3], Instants[5]);
      var firstComparer = ZoneEqualityComparer.ForInterval(interval);
      var secondComparer = firstComparer.WithOptions(ZoneEqualityComparerOptions.MatchNames);

      Assert.AreEqual(ZoneEqualityComparerOptions.MatchNames, secondComparer.OptionsForTest);
      Assert.AreEqual(interval, secondComparer.IntervalForTest);

      // Validate that the first comparer hasn't changed
      Assert.AreEqual(ZoneEqualityComparerOptions.OnlyMatchWallOffset, firstComparer.OptionsForTest);
      Assert.AreEqual(interval, firstComparer.IntervalForTest);
    },

    'ElidedTransitions_Degenerate': (args) {
      // Transitions with *nothing* that we care about. (Normally
      // these wouldn't even be generated, but we could imagine some
      // sort of zone interval in the future which had another property...)
      var zone1 = (MultiTransitionDateTimeZoneBuilder()
            ..Add(Instants[3], 1, 0, 'a')
            ..Add(Instants[4], 1, 0, 'a')
            ..Add(Instants[5], 1, 0, 'a')
            ..Add(Instants[6], 0))
          .Build();
      var zone2 = (MultiTransitionDateTimeZoneBuilder()
            ..Add(Instants[3], 1, 0, 'a')
            ..Add(Instants[6], 0))
          .Build();

      // We can match *everything* except exact transitions...
      AssertEqual(zone1, zone2, Instant.MinValue, Instant.MaxValue, ZoneEqualityComparerOptions.MatchNames | ZoneEqualityComparerOptions.MatchOffsetComponents | ZoneEqualityComparerOptions.MatchStartAndEndTransitions);
      // But not the exact transitions...
      AssertNotEqual(zone1, zone2, Instant.MinValue, Instant.MaxValue, ZoneEqualityComparerOptions.MatchAllTransitions);
    },

    'ReferenceComparison': (args) {
      var comparer = ZoneEqualityComparer.ForInterval(Interval(Instants[0], Instants[2]));
      var zone = DateTimeZoneProviders.Tzdb['Europe/London'];
      Assert.IsTrue(comparer.Equals(zone, zone));
    },

    'NullComparison': (args) {
      var comparer = ZoneEqualityComparer.ForInterval(Interval(Instants[0], Instants[2]));
      var zone = DateTimeZoneProviders.Tzdb['Europe/London'];
      Assert.IsFalse(comparer.Equals(zone, null));
      Assert.IsFalse(comparer.Equals(null, zone));
    },

    'InvalidOptions': (args) {
      var comparer = ZoneEqualityComparer.ForInterval(Interval(Instants[0], Instants[2]));
      Assert.Throws<RangeError>(() => comparer.WithOptions(ZoneEqualityComparerOptions(9999)));
    },
  });
}

void AssertEqual(DateTimeZone first, DateTimeZone second,
    Instant start, Instant end, ZoneEqualityComparerOptions options) {
  var comparer = ZoneEqualityComparer.ForInterval(Interval(start, end)).WithOptions(options);
  Assert.IsTrue(comparer.Equals(first, second));
  Assert.AreEqual(comparer.GetHashCode(first), comparer.GetHashCode(second));
}

void AssertNotEqual(DateTimeZone first, DateTimeZone second,
    Instant start, Instant end, ZoneEqualityComparerOptions options) {
  var comparer = ZoneEqualityComparer.ForInterval(Interval(start, end)).WithOptions(options);
  Assert.IsFalse(comparer.Equals(first, second));
  // If this fails, the code *could* still be correct - but it's unlikely...
  Assert.AreNotEqual(comparer.GetHashCode(first), comparer.GetHashCode(second));
}
