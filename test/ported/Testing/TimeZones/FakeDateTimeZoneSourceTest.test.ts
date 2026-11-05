// Ported from NodaTime 3.3.0: src/NodaTime.Test/Testing/TimeZones/FakeDateTimeZoneSourceTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: C# collection initializers become builder.add(...) calls (or pushes onto builder.zones /
// builder.bclIdsToZoneIds.set(...) for the property initializers). TimeZoneInfo.Local.Id is replaced by the host's
// default Intl time zone ID, which is what FakeDateTimeZoneSource.getSystemDefaultId matches against in noda-js.

import { expect } from "vitest";
import { ArgumentError, ArgumentNullError, NodaConstants, Offset } from "../../../../src/noda-js/internal.ts";
import type { DateTimeZone } from "../../../../src/noda-js/internal.ts";
import { FakeDateTimeZoneSource, SingleTransitionDateTimeZone } from "../../../../src/noda-js/entries/testing.ts";
import { assertNodaEqual, assertThrows } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/Testing/TimeZones/FakeDateTimeZoneSourceTest.generated.ts";

// We don't care about the details of the time zones, just the IDs
function createZone(id: string): DateTimeZone {
  return new SingleTransitionDateTimeZone(NodaConstants.UnixEpoch, Offset.FromHours(1), Offset.FromHours(2), id);
}

/** C#'s collection initializer: `new FakeDateTimeZoneSource.Builder { zone1, zone2, ... }`. */
function builderWith(...zones: DateTimeZone[]): InstanceType<typeof FakeDateTimeZoneSource.Builder> {
  const builder = new FakeDateTimeZoneSource.Builder();
  for (const zone of zones) {
    builder.Add(zone);
  }
  return builder;
}

/** TimeZoneInfo.Local.Id in noda-js: the host's default Intl time zone ID. */
function localId(): string {
  return Intl.DateTimeFormat().resolvedOptions().timeZone;
}

// We don't really care how it fails - just that an exception is thrown.
// Unfortunately NUnit requires the exact exception type :(
function assertBuildFails(builder: InstanceType<typeof FakeDateTimeZoneSource.Builder>): void {
  let success = false;
  try {
    builder.Build();
    success = true;
  } catch {
    // Expected
  }
  expect(success).toBe(false);
}

port(fixture, {
  Ids() {
    const source = builderWith(createZone("x"), createZone("y"), createZone("a"), createZone("b")).Build();
    // CollectionAssert.AreEquivalent: same elements, in any order.
    expect([...source.GetIds()].sort()).toEqual(["x", "y", "a", "b"].sort());
  },

  ForId_Present() {
    const zone = createZone("x");
    const source = builderWith(
      // The "right" one and some others
      zone, createZone("y"), createZone("a"), createZone("b"),
    ).Build();
    expect(source.ForId("x")).toBe(zone);
  },

  ForId_Missing() {
    const source = builderWith(createZone("x"), createZone("y")).Build();
    assertThrows(ArgumentError, () => source.ForId("missing"));
  },

  DuplicateIds() {
    const builder = builderWith(createZone("x"), createZone("y"), createZone("x"));
    assertBuildFails(builder);
  },

  ValidWindowsMapping() {
    const id = localId();
    const builder = new FakeDateTimeZoneSource.Builder();
    builder.BclIdsToZoneIds.set(id, "x");
    builder.Zones.push(createZone("x"), createZone("y"));
    const source = builder.Build();
    assertNodaEqual(source.GetSystemDefaultId(), "x");
  },

  NullZoneViaCollectionInitializer() {
    assertThrows(ArgumentNullError, () => builderWith(null as unknown as DateTimeZone));
  },

  NullZoneViaProperty() {
    const source = new FakeDateTimeZoneSource.Builder();
    source.Zones.push(null as unknown as DateTimeZone);
    assertBuildFails(source);
  },

  InvalidWindowsMapping_NullCanonicalId() {
    const source = new FakeDateTimeZoneSource.Builder();
    source.BclIdsToZoneIds.set("x", null as unknown as string);
    source.Zones.push(createZone("z"));
    assertBuildFails(source);
  },

  InvalidWindowsMapping_MissingZone() {
    const source = new FakeDateTimeZoneSource.Builder();
    source.BclIdsToZoneIds.set(localId(), "z");
    source.Zones.push(createZone("x"), createZone("y"));
    assertBuildFails(source);
  },

  GetEnumerator() {
    const x = createZone("x");
    const y = createZone("y");
    const source = new FakeDateTimeZoneSource.Builder();
    source.Zones.push(x, y);

    // Tests IEnumerable<T>
    expect([...source]).toEqual([x, y]);
    // Tests IEnumerable
    // noda-js: JS has one iteration protocol, so this checks the same iterator again.
    expect(Array.from(source)).toEqual([x, y]);
  },
});
