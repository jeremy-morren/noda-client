// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeZones/ZoneEqualityComparerTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: DateTimeZoneProviders.Tzdb is the bundled `tzdb` provider, and its indexer is get(id). The C# collection
// initializers for MultiTransitionDateTimeZone.Builder are calls to add(). ZoneEqualityComparer.GetHashCode isn't
// ported (GetHashCode is omitted throughout noda-js), so AssertEqual/AssertNotEqual only check Equals.

import { expect } from "vitest";
import {
  Duration,
  Instant,
  Interval,
  MultiTransitionDateTimeZone,
  ZoneEqualityComparer,
  type DateTimeZone,
  type ZoneEqualityComparerOptions,
} from "../../../src/noda-js/internal.ts";
import { tzdb } from "../../../src/noda-js/entries/tzdb-bundled.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/TimeZones/ZoneEqualityComparerTest.generated.ts";

// Sample instants for use in tests. They're on January 1st 2000...2009, midnight UTC.
const Instants: readonly Instant[] = Object.freeze(
  Array.from({ length: 10 }, (_, i) => 2000 + i).map(year => Instant.FromUtc(year, 1, 1, 0, 0)));

type BuilderEntry = [Instant, number] | [Instant, number, number, string];

/** A C# collection initializer for MultiTransitionDateTimeZone.Builder. */
function buildZone(...entries: BuilderEntry[]): MultiTransitionDateTimeZone {
  const builder = new MultiTransitionDateTimeZone.Builder();
  for (const entry of entries) {
    if (entry.length === 2) {
      builder.Add(entry[0], entry[1]);
    } else {
      builder.Add(entry[0], entry[1], entry[2], entry[3]);
    }
  }
  return builder.Build();
}

function assertEqual(first: DateTimeZone, second: DateTimeZone,
  start: Instant, end: Instant, options: ZoneEqualityComparerOptions): void {
  const comparer = ZoneEqualityComparer.ForInterval(new Interval(start, end)).WithOptions(options);
  expect(comparer.Equals(first, second)).toBe(true);
  // Not ported: Assert.AreEqual(comparer.GetHashCode(first), comparer.GetHashCode(second)).
}

function assertNotEqual(first: DateTimeZone, second: DateTimeZone,
  start: Instant, end: Instant, options: ZoneEqualityComparerOptions): void {
  const comparer = ZoneEqualityComparer.ForInterval(new Interval(start, end)).WithOptions(options);
  expect(comparer.Equals(first, second)).toBe(false);
  // Not ported: Assert.AreNotEqual(comparer.GetHashCode(first), comparer.GetHashCode(second)).
}

port(fixture, {
  // Various tests using a pair of zones which can demonstrate a number of
  // different features.
  Various() {
    // Names, some offsets, and first transition are all different.
    const zone1 = buildZone(
      [Instants[0]!, 1, 0, "xx"],
      [Instants[2]!, 3, 0, "1b"],
      [Instants[4]!, 2, 1, "1c"],
      [Instants[6]!, 4, 0, "1d"],
    );
    const zone2 = buildZone(
      [Instants[1]!, 1, 0, "xx"],
      [Instants[2]!, 3, 0, "2b"],
      [Instants[4]!, 1, 2, "2c"],
      [Instants[6]!, 5, 0, "2d"],
    );
    // Even though the first transition point is different, by default that's fine if
    // the start point is "inside" both.
    assertEqual(zone1, zone2, Instants[1]!, Instants[5]!, ZoneEqualityComparer.Options.OnlyMatchWallOffset);
    // When we extend backwards a bit, we can see the difference between the two.
    assertNotEqual(zone1, zone2, Instants[1]!.Minus(Duration.Epsilon), Instants[5]!, ZoneEqualityComparer.Options.OnlyMatchWallOffset);
    // Or if we force the start and end transitions to be exact...
    assertNotEqual(zone1, zone2, Instants[1]!, Instants[5]!, ZoneEqualityComparer.Options.MatchStartAndEndTransitions);

    // The first two transitions have the same split between standard and saving...
    assertEqual(zone1, zone2, Instants[1]!, Instants[4]!, ZoneEqualityComparer.Options.MatchOffsetComponents);
    // The third one (at Instants[4]) doesn't...
    assertNotEqual(zone1, zone2, Instants[1]!, Instants[5]!, ZoneEqualityComparer.Options.MatchOffsetComponents);

    // The first transition has the same name for the zone interval...
    assertEqual(zone1, zone2, Instants[1]!, Instants[2]!, ZoneEqualityComparer.Options.MatchNames);
    // The second transition (at Instants[2]) doesn't...
    assertNotEqual(zone1, zone2, Instants[1]!, Instants[3]!, ZoneEqualityComparer.Options.MatchNames);
  },

  ElidedTransitions() {
    const zone1 = buildZone(
      [Instants[3]!, 0, 0, "a"],
      [Instants[4]!, 1, 2, "b"],
      [Instants[5]!, 2, 1, "b"],
      [Instants[6]!, 1, 0, "d"],
      [Instants[7]!, 1, 0, "e"],
      [Instants[8]!, 0, 0, "x"],
    );
    const zone2 = buildZone(
      [Instants[3]!, 0, 0, "a"],
      [Instants[4]!, 3, 0, "b"],
      // Instants[5] isn't included here: wall offset is the same; components change in zone1
      [Instants[6]!, 1, 0, "d"],
      // Instants[7] isn't included here: offset components are the same; names change in zone1
      [Instants[8]!, 0, 0, "x"],
    );

    assertEqual(zone1, zone2, Instant.MinValue, Instant.MaxValue, ZoneEqualityComparer.Options.OnlyMatchWallOffset);
    // BOT-Instants[6] will elide transitions when ignoring components, even if we match names
    assertEqual(zone1, zone2, Instant.MinValue, Instants[6]!, ZoneEqualityComparer.Options.MatchNames);
    assertNotEqual(zone1, zone2, Instant.MinValue, Instants[6]!, ZoneEqualityComparer.Options.MatchOffsetComponents);
    // Instants[6]-EOT will elide transitions when ignoring names, even if we match components
    assertEqual(zone1, zone2, Instants[6]!, Instant.MaxValue, ZoneEqualityComparer.Options.MatchOffsetComponents);
    assertNotEqual(zone1, zone2, Instants[6]!, Instant.MaxValue, ZoneEqualityComparer.Options.MatchNames);

    // But if we require the exact transitions, both fail
    assertNotEqual(zone1, zone2, Instant.MinValue, Instants[6]!, ZoneEqualityComparer.Options.MatchAllTransitions);
    assertNotEqual(zone1, zone2, Instants[6]!, Instant.MaxValue, ZoneEqualityComparer.Options.MatchAllTransitions);
  },

  ForInterval() {
    const interval = new Interval(Instants[3]!, Instants[5]!);
    const comparer = ZoneEqualityComparer.ForInterval(interval);
    expect(comparer.OptionsForTest).toBe(ZoneEqualityComparer.Options.OnlyMatchWallOffset);
    assertNodaEqual(comparer.IntervalForTest, interval);
  },

  WithOptions() {
    const interval = new Interval(Instants[3]!, Instants[5]!);
    const firstComparer = ZoneEqualityComparer.ForInterval(interval);
    const secondComparer = firstComparer.WithOptions(ZoneEqualityComparer.Options.MatchNames);

    expect(secondComparer.OptionsForTest).toBe(ZoneEqualityComparer.Options.MatchNames);
    assertNodaEqual(secondComparer.IntervalForTest, interval);

    // Validate that the first comparer hasn't changed
    expect(firstComparer.OptionsForTest).toBe(ZoneEqualityComparer.Options.OnlyMatchWallOffset);
    assertNodaEqual(firstComparer.IntervalForTest, interval);
  },

  ElidedTransitions_Degenerate() {
    // Transitions with *nothing* that we care about. (Normally
    // these wouldn't even be generated, but we could imagine some
    // sort of zone interval in the future which had another property...)
    const zone1 = buildZone(
      [Instants[3]!, 1, 0, "a"],
      [Instants[4]!, 1, 0, "a"],
      [Instants[5]!, 1, 0, "a"],
      [Instants[6]!, 0],
    );
    const zone2 = buildZone(
      [Instants[3]!, 1, 0, "a"],
      [Instants[6]!, 0],
    );

    // We can match *everything* except exact transitions...
    assertEqual(zone1, zone2, Instant.MinValue, Instant.MaxValue,
      ZoneEqualityComparer.Options.MatchNames | ZoneEqualityComparer.Options.MatchOffsetComponents | ZoneEqualityComparer.Options.MatchStartAndEndTransitions);
    // But not the exact transitions...
    assertNotEqual(zone1, zone2, Instant.MinValue, Instant.MaxValue, ZoneEqualityComparer.Options.MatchAllTransitions);
  },

  ReferenceComparison() {
    const comparer = ZoneEqualityComparer.ForInterval(new Interval(Instants[0]!, Instants[2]!));
    const zone = tzdb.Get("Europe/London");
    expect(comparer.Equals(zone, zone)).toBe(true);
  },

  NullComparison() {
    const comparer = ZoneEqualityComparer.ForInterval(new Interval(Instants[0]!, Instants[2]!));
    const zone = tzdb.Get("Europe/London");
    expect(comparer.Equals(zone, null)).toBe(false);
    expect(comparer.Equals(null, zone)).toBe(false);
  },

  InvalidOptions() {
    const comparer = ZoneEqualityComparer.ForInterval(new Interval(Instants[0]!, Instants[2]!));
    assertThrows("ArgumentOutOfRangeException", () => comparer.WithOptions(9999 as ZoneEqualityComparerOptions));
  },
});
