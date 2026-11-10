// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeZones/TzdbDateTimeZoneTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the cases are the zones of NodaTime 3.3.7's embedded tzdb data, looked up in noda-js's bundled data.

import { expect } from "vitest";
import { DateTimeZone, Instant } from "../../../src/noda-js/internal.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/TimeZones/TzdbDateTimeZoneTest.generated.ts";

/** Tests for all TZDB time zones. */
port(fixture, {
  AllZonesStartAndEndOfTime(zone: DateTimeZone) {
    const firstInterval = zone.GetZoneInterval(Instant.MinValue);
    expect(firstInterval.HasStart).toBe(false);
    const lastInterval = zone.GetZoneInterval(Instant.MaxValue);
    expect(lastInterval.HasEnd).toBe(false);
  },
});
