// Ported from NodaTime 6e024dde: src/NodaTime.Test/Testing/TimeZones/MultiTransitionDateTimeZoneTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: collection initializers are Add calls.

import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/Testing/TimeZones/MultiTransitionDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/ZoneInterval.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/Testing/TimeZones/MultiTransitionDateTimeZoneTest.generated.dart' as scenarios;

// Test as much to demonstrate a couple of extremes of building as much as anything else...
void main() {
  port(scenarios.fixture, {
    'SimpleBuilding': (args) {
      var transition1 = Instant.FromUnixTimeTicks(0);
      var transition2 = Instant.FromUnixTimeTicks(100000);
      var zone = (MultiTransitionDateTimeZoneBuilder()
            ..Add(transition1, 5)
            ..Add(transition2, 3))
          .Build();
      var intervals = zone.GetZoneIntervals(transition1.MinusDuration(Duration.Epsilon), transition2 + Duration.Epsilon).toList();
      Assert.AreEqual(3, intervals.length);
      Assert.AreEqual(Offset.Zero, intervals[0].WallOffset);
      Assert.AreEqual(Instant.BeforeMinValue, intervals[0].RawStart);
      Assert.AreEqual(transition1, intervals[0].End);

      Assert.AreEqual(Offset.FromHours(5), intervals[1].WallOffset);
      Assert.AreEqual(transition1, intervals[1].Start);
      Assert.AreEqual(transition2, intervals[1].End);

      Assert.AreEqual(Offset.FromHours(3), intervals[2].WallOffset);
      Assert.AreEqual(transition2, intervals[2].Start);
      Assert.AreEqual(Instant.AfterMaxValue, intervals[2].RawEnd);
    },

    'Transitions': (args) {
      var transition1 = Instant.FromUnixTimeTicks(0);
      var transition2 = Instant.FromUnixTimeTicks(100000);
      var zone = (MultiTransitionDateTimeZoneBuilder()
            ..Add(transition1, 5)
            ..Add(transition2, 3))
          .Build();
      CollectionAssert.AreEqual([transition1, transition2], zone.Transitions);
    },

    'ComplexBuilding': (args) {
      var transition1 = Instant.FromUnixTimeTicks(0);
      var transition2 = Instant.FromUnixTimeTicks(100000);
      var zone = (MultiTransitionDateTimeZoneBuilder(2, 1, 'X')
            ..Add(transition1, 2, 0, 'Y')
            ..Add(transition2, 1, 1, 'Z'))
          .Build();
      var actual = zone.GetZoneIntervals(transition1.MinusDuration(Duration.Epsilon), transition2 + Duration.Epsilon).toList();
      // ZoneInterval uses wall offset and savings...
      var expected = [
        ZoneInterval('X', Instant.BeforeMinValue, transition1, Offset.FromHours(3), Offset.FromHours(1)),
        ZoneInterval('Y', transition1, transition2, Offset.FromHours(2), Offset.FromHours(0)),
        ZoneInterval('Z', transition2, Instant.AfterMaxValue, Offset.FromHours(2), Offset.FromHours(1)),
      ];

      CollectionAssert.AreEqual(expected, actual);
    },

    'BuildTwice': (args) {
      var builder = MultiTransitionDateTimeZoneBuilder();
      builder.Build();
      Assert.Throws<StateError>(() => builder.Build());
    },
  }, skip: {
    'BuilderGetEnumerator_Throws':
        "Builder's IEnumerable.GetEnumerator isn't ported (it only exists to enable C# collection initializers)",
  });
}
