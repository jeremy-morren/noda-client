// Ported from NodaTime 3.3.0: src/NodaTime.Test/NodaConstantsTest.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: `new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc).Ticks` (the BCL's ticks since 0001-01-01) is
// computed from JS Date instead. C# long results are numbers; these values are exact doubles.

import { CalendarSystem, DateTimeZone, LocalDateTime, NodaConstants } from "../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { fixture } from "../scenarios/NodaConstantsTest.generated.ts";

/** The BCL's DateTime ticks at 1970-01-01T00:00:00Z: milliseconds since 0001-01-01 (proleptic Gregorian) * 10000. */
function bclTicksAtUnixEpoch(): bigint {
  const bclEpoch = new Date(0);
  bclEpoch.setUTCFullYear(1, 0, 1);
  return BigInt(-bclEpoch.getTime()) * 10000n;
}

port(fixture, {
  JulianEpoch() {
    // Compute the Julian epoch using the Julian calendar, instead of the
    // Gregorian version.
    const localEpoch = new LocalDateTime(-4712, 1, 1, 12, 0, CalendarSystem.Julian);
    const epoch = localEpoch.InZoneStrictly(DateTimeZone.Utc).ToInstant();
    assertNodaEqual(NodaConstants.JulianEpoch, epoch);
  },

  BclTicksAtEpoch() {
    assertNodaEqual(NodaConstants.BclTicksAtUnixEpoch, bclTicksAtUnixEpoch());
  },

  BclDaysAtEpoch() {
    assertNodaEqual(NodaConstants.TicksPerDay * NodaConstants.BclDaysAtUnixEpoch, bclTicksAtUnixEpoch());
  },
});
