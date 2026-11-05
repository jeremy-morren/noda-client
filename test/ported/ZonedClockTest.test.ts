// Ported from NodaTime 3.3.7: src/NodaTime.Test/ZonedClockTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the ClockExtensions.InZone extension method is the InZone function. Assert.AreSame is toBe.

import { expect } from "vitest";
import {
  CalendarSystem,
  InZone,
  LocalDate,
  LocalDateTime,
  LocalTime,
  NodaConstants,
  Offset,
  SingleTransitionDateTimeZone,
  ZonedDateTime,
  type DateTimeZone,
} from "../../src/noda-js/internal.ts";
import { FakeClock } from "../../src/noda-js/entries/testing.ts";
import { assertNodaEqual } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { fixture } from "../scenarios/ZonedClockTest.generated.ts";

const SampleZone: DateTimeZone = new SingleTransitionDateTimeZone(NodaConstants.UnixEpoch, 1, 2);

port(fixture, {
  GetCurrent() {
    const julian = CalendarSystem.Julian;
    const underlyingClock = new FakeClock(NodaConstants.UnixEpoch);
    const zonedClock = InZone(underlyingClock, SampleZone, julian);
    assertNodaEqual(zonedClock.GetCurrentInstant(), NodaConstants.UnixEpoch);
    assertNodaEqual(zonedClock.GetCurrentZonedDateTime(),
      new ZonedDateTime(underlyingClock.GetCurrentInstant(), SampleZone, julian));
    assertNodaEqual(zonedClock.GetCurrentLocalDateTime(), new LocalDateTime(1969, 12, 19, 2, 0, julian));
    assertNodaEqual(zonedClock.GetCurrentOffsetDateTime(),
      new LocalDateTime(1969, 12, 19, 2, 0, julian).WithOffset(Offset.FromHours(2)));
    assertNodaEqual(zonedClock.GetCurrentDate(), new LocalDate(1969, 12, 19, julian));
    assertNodaEqual(zonedClock.GetCurrentTimeOfDay(), new LocalTime(2, 0, 0));
  },

  Properties() {
    const calendar = CalendarSystem.Julian;
    const clock = new FakeClock(NodaConstants.UnixEpoch);
    const zonedClock = InZone(clock, SampleZone, calendar);
    expect(zonedClock.Clock).toBe(clock);
    expect(zonedClock.Calendar).toBe(calendar);
    expect(zonedClock.Zone).toBe(SampleZone);
  },
});
