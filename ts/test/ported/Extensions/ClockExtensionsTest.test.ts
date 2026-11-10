// Ported from NodaTime 3.3.7: src/NodaTime.Test/Extensions/ClockExtensionsTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { CalendarSystem, InUtc, InZone, NodaConstants } from "../../../src/noda-js/internal.ts";
import { FakeClock } from "../../../src/noda-js/entries/testing.ts";
import { tzdb } from "../../../src/noda-js/entries/tzdb-bundled.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Extensions/ClockExtensionsTest.generated.ts";

const NewYork = tzdb.Get("America/New_York");

port(fixture, {
  InZone_NoCalendar() {
    const clock = new FakeClock(NodaConstants.UnixEpoch);
    const zoned = InZone(clock, NewYork);
    const zonedEpoch = NodaConstants.UnixEpoch.InZone(NewYork);
    assertNodaEqual(zoned.GetCurrentZonedDateTime(), zonedEpoch);
  },

  InZone_WithCalendar() {
    const clock = new FakeClock(NodaConstants.UnixEpoch);
    const zoned = InZone(clock, NewYork, CalendarSystem.Julian);
    const zonedEpoch = NodaConstants.UnixEpoch.InZone(NewYork, CalendarSystem.Julian);
    assertNodaEqual(zoned.GetCurrentZonedDateTime(), zonedEpoch);
  },

  InUtc() {
    const clock = new FakeClock(NodaConstants.UnixEpoch);
    const zoned = InUtc(clock);
    const zonedEpoch = NodaConstants.UnixEpoch.InUtc();
    assertNodaEqual(zoned.GetCurrentZonedDateTime(), zonedEpoch);
  },
}, {
  skip: {
    InTzdbSystemDefaultZone: "Not ported: ClockExtensions.InTzdbSystemDefaultZone (and TimeZoneInfo, which the test replaces)",
    InBclSystemDefaultZone: "Not ported: ClockExtensions.InBclSystemDefaultZone (BCL interop)",
  },
});
