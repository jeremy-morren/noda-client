// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeZones/PartialZoneIntervalMapTest.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  Instant,
  MultiTransitionDateTimeZone,
  PartialZoneIntervalMap,
  type DateTimeZone,
  type IZoneIntervalMap,
  type ZoneInterval,
} from "../../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/TimeZones/PartialZoneIntervalMapTest.generated.ts";

// Arbitrary instants which are useful for the tests. They happen to be a year
// apart, but nothing in these tests actually cares.
// Various tests use a time zone with transitions at C and G.
// Using letter is (IMO) slightly more readable than just having an array and using indexes.
const Instants = new Map<string, Instant>([
  ["A", Instant.FromUtc(2000, 1, 1, 0, 0)],
  ["B", Instant.FromUtc(2001, 1, 1, 0, 0)],
  ["C", Instant.FromUtc(2002, 1, 1, 0, 0)],
  ["D", Instant.FromUtc(2003, 1, 1, 0, 0)],
  ["E", Instant.FromUtc(2004, 1, 1, 0, 0)],
  ["F", Instant.FromUtc(2005, 1, 1, 0, 0)],
  ["G", Instant.FromUtc(2006, 1, 1, 0, 0)],
  ["H", Instant.FromUtc(2007, 1, 1, 0, 0)],
  ["I", Instant.FromUtc(2008, 1, 1, 0, 0)],
]);

const ExpectedZone: DateTimeZone = (() => {
  const builder = new MultiTransitionDateTimeZone.Builder(-2, "Start");
  builder.Add(Instants.get("C")!, 2, 1, "Middle");
  builder.Add(Instants.get("G")!, 1, 0, "End");
  return builder.Build();
})();

// TODO: Consider making this part of the NodaTime assembly.
// It's just a copy from DateTimeZone, with the interval taken out.
// It could be an extension method on IZoneIntervalMap, with optional interval.
// On the other hand, IZoneIntervalMap is internal, so it would only be used by us.
function* getZoneIntervals(map: IZoneIntervalMap): Iterable<ZoneInterval> {
  let current = Instant.MinValue;
  while (current.CompareTo(Instant.AfterMaxValue) < 0) {
    const zoneInterval = map.GetZoneInterval(current);
    yield zoneInterval;
    // If this is the end of time, this will just fail on the next comparison.
    current = zoneInterval.RawEnd;
  }
}

port(fixture, {
  // This is just a variety of interesting tests, hopefully covering everything we need. Imagine a time line,
  // and the letters in the string break it up into partial maps (all based on the original zone). We should
  // be able to break it up anywhere and still get back to something equivalent to the original zone.
  ConvertToFullMap(intervalBreaks: string) {
    const maps: PartialZoneIntervalMap[] = [];
    // We just reuse ExpectedZone as the IZoneIntervalMap; PartialZoneIntervalMap itself will clamp the ends.
    let current = Instant.BeforeMinValue;
    for (const instant of [...intervalBreaks].map(c => Instants.get(c)!)) {
      maps.push(new PartialZoneIntervalMap(current, instant, ExpectedZone));
      current = instant;
    }
    maps.push(new PartialZoneIntervalMap(current, Instant.AfterMaxValue, ExpectedZone));

    const converted = PartialZoneIntervalMap.ConvertToFullMap(maps);
    assertNodaEqual([...getZoneIntervals(converted)], [...getZoneIntervals(ExpectedZone)]);
  },
});
