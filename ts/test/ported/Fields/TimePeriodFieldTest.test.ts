// Ported from NodaTime 3.3.7: src/NodaTime.Test/Fields/TimePeriodFieldTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: `ref int extraDays` is a { value } holder.

import { Duration, LocalTimePattern, TimePeriodField } from "../../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Fields/TimePeriodFieldTest.generated.ts";

// Just a sample really.
const SampleField = TimePeriodField.Milliseconds;

port(fixture, {
  Add(start: string, units: number, expectedEnd: string, expectedExtraDays: number) {
    const startTime = LocalTimePattern.ExtendedIso.Parse(start).Value;
    const expectedEndTime = LocalTimePattern.ExtendedIso.Parse(expectedEnd).Value;

    const extraDays = { value: 0 };
    assertNodaEqual(SampleField.Add(startTime, units, extraDays), expectedEndTime);
    assertNodaEqual(extraDays.value, expectedExtraDays);
  },

  GetUnitsInDuration(hours: number) {
    const duration = Duration.Add(Duration.FromHours(hours), Duration.FromMinutes(30 * Math.sign(hours)));
    assertNodaEqual(TimePeriodField.Hours.GetUnitsInDuration(duration), hours);
  },

  ToDuration(hours: number) {
    const actual = TimePeriodField.Hours.ToDuration(hours);
    assertNodaEqual(actual, Duration.FromHours(hours));
  },
});
