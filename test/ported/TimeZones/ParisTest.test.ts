// Ported from NodaTime 3.3.0: src/NodaTime.Test/TimeZones/ParisTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { CachedDateTimeZone, DateTimeZone, Duration, Instant, Offset } from "../../../src/noda-js/internal.ts";
import { tzdb } from "../../../src/noda-js/entries/tzdb-bundled.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/TimeZones/ParisTest.generated.ts";

/** TzTestHelper.Uncached: the uncached version of the given zone. */
function uncached(zone: DateTimeZone): DateTimeZone {
  return zone instanceof CachedDateTimeZone ? zone.TimeZone : zone;
}

/**
 * Tests for the Paris time zone. This exercises functionality within various classes.
 * Paris varies between +1 (standard) and +2 (DST); transitions occur at 2am or 3am wall time,
 * which is always 1am UTC.
 */
port(fixture, {
  FirstTransitions() {
    // Make sure we deal with the uncached time zone
    const paris = uncached(tzdb.Get("Europe/Paris"));
    // Until 1911, Paris was 9 minutes and 21 seconds off UTC.
    const initialOffset = Offset.FromSeconds(9 * 60 + 21); // TestObjects.CreatePositiveOffset(0, 9, 21)

    // Paris had a name change in 1891, and then moved from +0:09:21 to UTC in 1911
    const nameChangeInstant = Instant.FromUtc(1891, 3, 15, 23, 50, 39);
    const utcChangeInstant = Instant.FromUtc(1911, 3, 10, 23, 50, 39);

    const beforeNameChange = paris.GetZoneInterval(Instant.Subtract(nameChangeInstant, Duration.Epsilon));
    const afterNameChange = paris.GetZoneInterval(nameChangeInstant);
    const afterSmallChange = paris.GetZoneInterval(utcChangeInstant);

    expect(beforeNameChange.Name).toBe("LMT");
    assertNodaEqual(beforeNameChange.WallOffset, initialOffset);

    expect(afterNameChange.Name).toBe("PMT");
    assertNodaEqual(afterNameChange.WallOffset, initialOffset);

    expect(afterSmallChange.Name).toBe("WET");
    assertNodaEqual(afterSmallChange.WallOffset, Offset.Zero);
  },
});
