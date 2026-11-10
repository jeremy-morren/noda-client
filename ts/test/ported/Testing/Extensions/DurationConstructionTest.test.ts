// Ported from NodaTime 3.3.7: src/NodaTime.Test/Testing/Extensions/DurationConstructionTest.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: `2.Days()` and `2L.Days()` are both `Days(2)`.

import { Duration } from "../../../../src/noda-js/internal.ts";
import { Days, Hours, Milliseconds, Minutes, Nanoseconds, Seconds, Ticks } from "../../../../src/noda-js/entries/testing.ts";
import { assertNodaEqual } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/Testing/Extensions/DurationConstructionTest.generated.ts";

port(fixture, {
  Days() {
    assertNodaEqual(Days(2), Duration.FromDays(2));
    assertNodaEqual(Days(2.5), Duration.FromDays(2.5));
  },

  Hours() {
    assertNodaEqual(Hours(2), Duration.FromHours(2));
    assertNodaEqual(Hours(2.5), Duration.FromHours(2.5));
  },

  Minutes() {
    assertNodaEqual(Minutes(2), Duration.FromMinutes(2));
    assertNodaEqual(Minutes(2), Duration.FromMinutes(2));
    assertNodaEqual(Minutes(2.5), Duration.FromMinutes(2.5));
  },

  Seconds() {
    assertNodaEqual(Seconds(2), Duration.FromSeconds(2));
    assertNodaEqual(Seconds(2), Duration.FromSeconds(2));
    assertNodaEqual(Seconds(2.5), Duration.FromSeconds(2.5));
  },

  Milliseconds() {
    assertNodaEqual(Milliseconds(2), Duration.FromMilliseconds(2));
    assertNodaEqual(Milliseconds(2), Duration.FromMilliseconds(2));
    assertNodaEqual(Milliseconds(2.5), Duration.FromMilliseconds(2.5));
  },

  Ticks() {
    assertNodaEqual(Ticks(2), Duration.FromTicks(2));
    assertNodaEqual(Ticks(2), Duration.FromTicks(2));
    assertNodaEqual(Ticks(2.5), Duration.FromTicks(2.5));
  },

  Nanoseconds() {
    assertNodaEqual(Nanoseconds(2), Duration.FromNanoseconds(2));
    assertNodaEqual(Nanoseconds(2), Duration.FromNanoseconds(2));
    assertNodaEqual(Nanoseconds(2.5), Duration.FromNanoseconds(2.5));
  },
});
