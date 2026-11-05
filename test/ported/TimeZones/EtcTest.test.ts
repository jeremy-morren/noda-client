// Ported from NodaTime 3.3.0: src/NodaTime.Test/TimeZones/EtcTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { FixedDateTimeZone, Offset } from "../../../src/noda-js/internal.ts";
import { tzdb } from "../../../src/noda-js/entries/tzdb-bundled.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/TimeZones/EtcTest.generated.ts";

/**
 * Tests for fixed "Etc/GMT+x" zones. These just test that the time zones are built
 * appropriately; FixedDateTimeZoneTest takes care of the rest.
 */
port(fixture, {
  FixedEasternZone() {
    const id = "Etc/GMT+5";
    const zone = tzdb.get(id);
    expect(zone.Id).toBe(id);
    expect(zone).toBeInstanceOf(FixedDateTimeZone);
    const fixedZone = zone as FixedDateTimeZone;
    assertNodaEqual(fixedZone.Offset, Offset.FromHours(-5));
  },

  FixedWesternZone() {
    const id = "Etc/GMT-4";
    const zone = tzdb.get(id);
    expect(zone.Id).toBe(id);
    expect(zone).toBeInstanceOf(FixedDateTimeZone);
    const fixedZone = zone as FixedDateTimeZone;
    assertNodaEqual(fixedZone.Offset, Offset.FromHours(4));
  },
});
