// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/PartialZoneIntervalMapTest.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/Testing/TimeZones/MultiTransitionDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/IZoneIntervalMap.dart';
import 'package:noda_dart/src/TimeZones/PartialZoneIntervalMap.dart';
import 'package:noda_dart/src/TimeZones/ZoneInterval.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/TimeZones/PartialZoneIntervalMapTest.generated.dart' as scenarios;

// Arbitrary instants which are useful for the tests. They happen to be a year
// apart, but nothing in these tests actually cares.
// Various tests use a time zone with transitions at C and G.
// Using letter is (IMO) slightly more readable than just having an array and using indexes.
final Map<String, Instant> Instants = <String, Instant>{
  'A': Instant.FromUtc(2000, 1, 1, 0, 0),
  'B': Instant.FromUtc(2001, 1, 1, 0, 0),
  'C': Instant.FromUtc(2002, 1, 1, 0, 0),
  'D': Instant.FromUtc(2003, 1, 1, 0, 0),
  'E': Instant.FromUtc(2004, 1, 1, 0, 0),
  'F': Instant.FromUtc(2005, 1, 1, 0, 0),
  'G': Instant.FromUtc(2006, 1, 1, 0, 0),
  'H': Instant.FromUtc(2007, 1, 1, 0, 0),
  'I': Instant.FromUtc(2008, 1, 1, 0, 0),
};

final DateTimeZone ExpectedZone = (MultiTransitionDateTimeZoneBuilder.FirstOffsetHoursFirstName(-2, 'Start')
      ..Add(Instants['C']!, 2, 1, 'Middle')
      ..Add(Instants['G']!, 1, 0, 'End'))
    .Build();

void main() {
  port(scenarios.fixture, {
    // This is just a variety of interesting tests, hopefully covering everything we need. Imagine a time line,
    // and the letters in the string break it up into partial maps (all based on the original zone). We should
    // be able to break it up anywhere and still get back to something equivalent to the original zone.
    'ConvertToFullMap': (args) {
      final [String intervalBreaks] = args;
      var maps = <PartialZoneIntervalMap>[];
      // We just reuse ExpectedZone as the IZoneIntervalMap; PartialZoneIntervalMap itself will clamp the ends.
      var current = Instant.BeforeMinValue;
      for (var instant in intervalBreaks.split('').map((c) => Instants[c]!)) {
        maps.add(PartialZoneIntervalMap.NewStartEndMap(current, instant, ExpectedZone));
        current = instant;
      }
      maps.add(PartialZoneIntervalMap.NewStartEndMap(current, Instant.AfterMaxValue, ExpectedZone));

      var converted = PartialZoneIntervalMap.ConvertToFullMap(maps);
      CollectionAssert.AreEqual(GetZoneIntervals(ExpectedZone), GetZoneIntervals(converted));
    },
  });
}

// TODO: Consider making this part of the NodaTime assembly.
// It's just a copy from DateTimeZone, with the interval taken out.
// It could be an extension method on IZoneIntervalMap, with optional interval.
// On the other hand, IZoneIntervalMap is internal, so it would only be used by us.
Iterable<ZoneInterval> GetZoneIntervals(IZoneIntervalMap map) sync* {
  var current = Instant.MinValue;
  while (current < Instant.AfterMaxValue) {
    var zoneInterval = map.GetZoneInterval(current);
    yield zoneInterval;
    // If this is the end of time, this will just fail on the next comparison.
    current = zoneInterval.RawEnd;
  }
}
