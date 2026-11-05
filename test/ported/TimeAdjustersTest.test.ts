// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeAdjustersTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { LocalTime, TimeAdjusters } from "../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { fixture } from "../scenarios/TimeAdjustersTest.generated.ts";

port(fixture, {
  TruncateToSecond() {
    const start = LocalTime.FromHourMinuteSecondMillisecondTick(7, 4, 30, 123, 4567);
    const end = new LocalTime(7, 4, 30);
    assertNodaEqual(TimeAdjusters.TruncateToSecond(start), end);
  },

  TruncateToMinute() {
    const start = LocalTime.FromHourMinuteSecondMillisecondTick(7, 4, 30, 123, 4567);
    const end = new LocalTime(7, 4, 0);
    assertNodaEqual(TimeAdjusters.TruncateToMinute(start), end);
  },

  TruncateToHour() {
    const start = LocalTime.FromHourMinuteSecondMillisecondTick(7, 4, 30, 123, 4567);
    const end = new LocalTime(7, 0, 0);
    assertNodaEqual(TimeAdjusters.TruncateToHour(start), end);
  },
});
