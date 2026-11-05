// Ported from NodaTime 3.3.0: src/NodaTime.Test/TimeZones/MiscellaneousBugReports.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { Instant, LocalDateTime, Offset, ZonedDateTime } from "../../../src/noda-js/internal.ts";
import { tzdb } from "../../../src/noda-js/entries/tzdb-bundled.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/TimeZones/MiscellaneousBugReports.generated.ts";

/**
 * Fixture for miscellaneous bug reports and oddities which don't really fit anywhere else.
 * Quite often the cause of a problem is nowhere near the test code; it's still useful
 * to have the original test which showed up the problem, as a small contribution
 * to regression testing.
 */
port(fixture, {
  Niue() {
    const niue = tzdb.get("Pacific/Niue");
    const offset = niue.GetUtcOffset(niue.AtStrictly(new LocalDateTime(2010, 1, 1, 0, 0, 0)).ToInstant());
    assertNodaEqual(offset, Offset.FromHours(-11));
  },

  Kiritimati() {
    const kiritimati = tzdb.get("Pacific/Kiritimati");
    const offset = kiritimati.GetUtcOffset(kiritimati.AtStrictly(new LocalDateTime(2010, 1, 1, 0, 0, 0)).ToInstant());
    assertNodaEqual(offset, Offset.FromHours(14));
  },

  Pyongyang() {
    const pyongyang = tzdb.get("Asia/Pyongyang");
    const offset = pyongyang.GetUtcOffset(pyongyang.AtStrictly(new LocalDateTime(2010, 1, 1, 0, 0, 0)).ToInstant());
    assertNodaEqual(offset, Offset.FromHours(9));
  },

  Khartoum() {
    const khartoum = tzdb.get("Africa/Khartoum");
    expect(khartoum).not.toBeNull();
    let utc = Instant.FromUtc(2000, 1, 1, 0, 0, 0);
    let inKhartoum = new ZonedDateTime(utc, khartoum);
    let expectedLocal = new LocalDateTime(2000, 1, 1, 2, 0);
    assertNodaEqual(inKhartoum.LocalDateTime, expectedLocal);

    // Khartoum changed from +2 to +3 on January 15th 2000
    utc = Instant.FromUtc(2000, 1, 16, 0, 0, 0);
    inKhartoum = new ZonedDateTime(utc, khartoum);
    expectedLocal = new LocalDateTime(2000, 1, 16, 3, 0);
    assertNodaEqual(inKhartoum.LocalDateTime, expectedLocal);
  },

  /** Tbilisi used daylight saving time for winter 1996/1997 too. */
  Tbilisi() {
    const zone = tzdb.get("Asia/Tbilisi");
    const summer1996 = Instant.FromUtc(1996, 6, 1, 0, 0);
    const interval = zone.GetZoneInterval(summer1996);
    assertNodaEqual(interval.IsoLocalStart, new LocalDateTime(1996, 3, 31, 1, 0));
    assertNodaEqual(interval.IsoLocalEnd, new LocalDateTime(1997, 10, 26, 0, 0));
  },

  // As of 2018f, Japan's fallback transitions 1948-1951 are at "25:00" on the relevant Saturday.
  // We represent that as 1am on the relevant Sunday instead, because we don't support HourOfDay=24.
  Japan() {
    const zone = tzdb.get("Asia/Tokyo");
    const summer1951 = Instant.FromUtc(1951, 8, 1, 0, 0);
    const interval = zone.GetZoneInterval(summer1951);
    assertNodaEqual(interval.IsoLocalStart, new LocalDateTime(1951, 5, 6, 1, 0));
    assertNodaEqual(interval.IsoLocalEnd, new LocalDateTime(1951, 9, 9, 1, 0));
  },
});
