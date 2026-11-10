// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeZones/CachedDateTimeZoneTest.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { CachedDateTimeZone, DateTimeZone, Duration, Instant, NodaConstants, Offset } from "../../../src/noda-js/internal.ts";
import { tzdb } from "../../../src/noda-js/entries/tzdb-bundled.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/TimeZones/CachedDateTimeZoneTest.generated.ts";

/** TzTestHelper.Uncached: the uncached version of the given zone. */
function uncached(zone: DateTimeZone): DateTimeZone {
  return zone instanceof CachedDateTimeZone ? zone.TimeZone : zone;
}

// Note that this tests CachingZoneIntervalMap as much as CachedDateTimeZone...
let timeZoneValue: CachedDateTimeZone | undefined;
function timeZone(): CachedDateTimeZone {
  if (timeZoneValue === undefined) {
    const zone = tzdb.Get("America/Los_Angeles");
    // C#: a cast, which throws if the zone isn't a CachedDateTimeZone.
    expect(zone).toBeInstanceOf(CachedDateTimeZone);
    timeZoneValue = zone as CachedDateTimeZone;
  }
  return timeZoneValue;
}
const summer = Instant.FromUtc(2010, 6, 1, 0, 0);

port(fixture, {
  GetZoneIntervalInstant_NotNull() {
    const actual = timeZone().GetZoneInterval(summer);
    expect(actual).not.toBeNull();
    expect(actual).toBeDefined();
  },

  GetZoneIntervalInstant_RepeatedCallsReturnSameObject() {
    const actual = timeZone().GetZoneInterval(summer);
    for (let i = 0; i < 100; i++) {
      const newPeriod = timeZone().GetZoneInterval(summer);
      expect(newPeriod).toBe(actual);
    }
  },

  GetZoneIntervalInstant_RepeatedCallsReturnSameObjectWithOthersInterspersed() {
    const actual = timeZone().GetZoneInterval(summer);
    expect(timeZone().GetZoneInterval(NodaConstants.UnixEpoch)).not.toBeNull();
    expect(timeZone().GetZoneInterval(NodaConstants.UnixEpoch.Plus(Duration.FromDays(2000 * 7)))).not.toBeNull();
    expect(timeZone().GetZoneInterval(NodaConstants.UnixEpoch.Plus(Duration.FromDays(3000 * 7)))).not.toBeNull();
    expect(timeZone().GetZoneInterval(NodaConstants.UnixEpoch.Plus(Duration.FromDays(4000 * 7)))).not.toBeNull();
    const newPeriod = timeZone().GetZoneInterval(summer);
    expect(newPeriod).toBe(actual);
  },

  MinMaxOffsets() {
    assertNodaEqual(timeZone().MinOffset, uncached(timeZone()).MinOffset);
    assertNodaEqual(timeZone().MaxOffset, uncached(timeZone()).MaxOffset);
  },

  ForZone_Fixed() {
    const zone = DateTimeZone.ForOffset(Offset.FromHours(1));
    expect(CachedDateTimeZone.ForZone(zone)).toBe(zone);
  },

  ForZone_AlreadyCached() {
    expect(CachedDateTimeZone.ForZone(timeZone())).toBe(timeZone());
  },
});
