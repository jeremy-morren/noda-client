// Ported from NodaTime 3.3.7: src/NodaTime.Test/Testing/TimeZones/MultiTransitionDateTimeZoneTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: C# collection initializers (`new Builder { { transition, 5 } }`) become builder.add(...) calls.

import { Duration, Instant, Offset, ZoneInterval } from "../../../../src/noda-js/internal.ts";
import { MultiTransitionDateTimeZone } from "../../../../src/noda-js/entries/testing.ts";
import { assertNodaEqual, assertThrows } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/Testing/TimeZones/MultiTransitionDateTimeZoneTest.generated.ts";

// Test as much to demonstrate a couple of extremes of building as much as anything else...
port(fixture, {
  SimpleBuilding() {
    const transition1 = Instant.FromUnixTimeTicks(0);
    const transition2 = Instant.FromUnixTimeTicks(100000);
    const builder = new MultiTransitionDateTimeZone.Builder();
    builder.Add(transition1, 5);
    builder.Add(transition2, 3);
    const zone = builder.Build();
    const intervals = [...zone.GetZoneIntervals(Instant.Subtract(transition1, Duration.Epsilon), Instant.Add(transition2, Duration.Epsilon))];
    assertNodaEqual(intervals.length, 3);
    assertNodaEqual(intervals[0]!.WallOffset, Offset.Zero);
    assertNodaEqual(intervals[0]!.RawStart, Instant.BeforeMinValue);
    assertNodaEqual(intervals[0]!.End, transition1);

    assertNodaEqual(intervals[1]!.WallOffset, Offset.FromHours(5));
    assertNodaEqual(intervals[1]!.Start, transition1);
    assertNodaEqual(intervals[1]!.End, transition2);

    assertNodaEqual(intervals[2]!.WallOffset, Offset.FromHours(3));
    assertNodaEqual(intervals[2]!.Start, transition2);
    assertNodaEqual(intervals[2]!.RawEnd, Instant.AfterMaxValue);
  },

  Transitions() {
    const transition1 = Instant.FromUnixTimeTicks(0);
    const transition2 = Instant.FromUnixTimeTicks(100000);
    const builder = new MultiTransitionDateTimeZone.Builder();
    builder.Add(transition1, 5);
    builder.Add(transition2, 3);
    const zone = builder.Build();
    assertNodaEqual(zone.Transitions, [transition1, transition2]);
  },

  ComplexBuilding() {
    const transition1 = Instant.FromUnixTimeTicks(0);
    const transition2 = Instant.FromUnixTimeTicks(100000);
    const builder = new MultiTransitionDateTimeZone.Builder(2, 1, "X");
    builder.Add(transition1, 2, 0, "Y");
    builder.Add(transition2, 1, 1, "Z");
    const zone = builder.Build();
    const actual = [...zone.GetZoneIntervals(Instant.Subtract(transition1, Duration.Epsilon), Instant.Add(transition2, Duration.Epsilon))];
    // ZoneInterval uses wall offset and savings...
    const expected = [
      new ZoneInterval("X", Instant.BeforeMinValue, transition1, Offset.FromHours(3), Offset.FromHours(1)),
      new ZoneInterval("Y", transition1, transition2, Offset.FromHours(2), Offset.FromHours(0)),
      new ZoneInterval("Z", transition2, Instant.AfterMaxValue, Offset.FromHours(2), Offset.FromHours(1)),
    ];

    assertNodaEqual(actual, expected);
  },

  BuildTwice() {
    const builder = new MultiTransitionDateTimeZone.Builder();
    builder.Build();
    assertThrows("InvalidOperationException", () => builder.Build());
  },
}, {
  skip: {
    BuilderGetEnumerator_Throws: "Not ported: Builder's IEnumerable.GetEnumerator (it only exists to enable C# collection initializers)",
  },
});
