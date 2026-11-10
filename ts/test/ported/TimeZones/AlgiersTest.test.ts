// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeZones/AlgiersTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { DateTimeZone, Instant, LocalDateTime, NodaConstants, Offset, ZoneInterval } from "../../../src/noda-js/internal.ts";
import { tzdb } from "../../../src/noda-js/entries/tzdb-bundled.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/TimeZones/AlgiersTest.generated.ts";

/**
 * Algiers had DST until May 1st 1981, after which time it didn't have any - so
 * we use that to test a time zone whose transitions run out. (When Algiers
 * decided to stop using DST, it changed its standard offset to be what had previously
 * been its DST offset, i.e. +1.)
 */
const algiers = (): DateTimeZone => tzdb.Get("Africa/Algiers");

port(fixture, {
  GetPeriod_BeforeLast() {
    const april1981 = Instant.FromUtc(1981, 4, 1, 0, 0);
    const actual = algiers().GetZoneInterval(april1981);
    const expected = new ZoneInterval("WET", Instant.FromUnixTimeTicks(3418020000000000), Instant.FromUnixTimeTicks(3575232000000000), Offset.Zero, Offset.Zero);
    assertNodaEqual(actual, expected);
  },

  GetPeriod_AfterLastTransition() {
    const may1981 = DateTimeZone.Utc.AtStrictly(new LocalDateTime(1981, 5, 1, 0, 0, 1)).ToInstant();
    const actual = algiers().GetZoneInterval(may1981);
    const expected = new ZoneInterval("CET", Instant.FromUnixTimeTicks(3575232000000000), null, Offset.FromSeconds(NodaConstants.SecondsPerHour), Offset.Zero);
    assertNodaEqual(actual, expected);
  },
});
