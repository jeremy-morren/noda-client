// Ported from NodaTime 3.3.0: src/NodaTime.Test/Testing/FakeClockTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Duration, Instant, NodaConstants } from "../../../src/noda-js/internal.ts";
import { FakeClock } from "../../../src/noda-js/entries/testing.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Testing/FakeClockTest.generated.ts";

// Tests for the FakeClock class in the Testing assembly.
port(fixture, {
  DirectConstruction() {
    const instant = Instant.FromUnixTimeTicks(100);
    const clock = new FakeClock(instant);
    assertNodaEqual(clock.GetCurrentInstant(), instant);
  },

  ConstructionWithAdvance() {
    const instant = Instant.FromUnixTimeTicks(100);
    const advance = Duration.FromTicks(5);
    const clock = new FakeClock(instant, advance);
    assertNodaEqual(clock.AutoAdvance, advance);
    assertNodaEqual(clock.GetCurrentInstant(), instant);
    assertNodaEqual(clock.GetCurrentInstant(), Instant.Add(instant, advance));
    assertNodaEqual(clock.GetCurrentInstant(), Instant.Add(Instant.Add(instant, advance), advance));
  },

  ConstructionThenAdvance() {
    const instant = Instant.FromUnixTimeTicks(100);
    const clock = new FakeClock(instant);
    assertNodaEqual(clock.GetCurrentInstant(), instant);
    assertNodaEqual(clock.GetCurrentInstant(), instant);
    const advance = Duration.FromTicks(5);
    clock.AutoAdvance = advance;
    // Setting auto-advance doesn't actually change the clock...
    // but this call will.
    assertNodaEqual(clock.GetCurrentInstant(), instant);
    assertNodaEqual(clock.GetCurrentInstant(), Instant.Add(instant, advance));
    assertNodaEqual(clock.GetCurrentInstant(), Instant.Add(Instant.Add(instant, advance), advance));
  },

  UtcDateConstruction() {
    const instant = Instant.FromUtc(2010, 1, 1, 0, 0);
    const clock = FakeClock.FromUtc(2010, 1, 1);
    assertNodaEqual(clock.GetCurrentInstant(), instant);
  },

  UtcDateTimeConstruction() {
    const instant = Instant.FromUtc(2010, 1, 1, 10, 30, 25);
    const clock = FakeClock.FromUtc(2010, 1, 1, 10, 30, 25);
    assertNodaEqual(clock.GetCurrentInstant(), instant);
  },

  Advance() {
    const clock = new FakeClock(Instant.FromUnixTimeTicks(100));
    const d = Duration.FromTicks(25);
    clock.Advance(d);
    assertNodaEqual(clock.GetCurrentInstant().ToUnixTimeTicks(), 125);
  },

  AdvanceNanoseconds() {
    const clock = new FakeClock(Instant.FromUnixTimeSeconds(1));
    clock.AdvanceNanoseconds(3);
    assertNodaEqual(clock.GetCurrentInstant().TimeSinceEpoch.ToInt64Nanoseconds(), 1_000_000_003);
  },

  AdvanceTicks() {
    const clock = new FakeClock(Instant.FromUnixTimeTicks(100));
    clock.AdvanceTicks(3);
    assertNodaEqual(clock.GetCurrentInstant().ToUnixTimeTicks(), 103);
  },

  AdvanceMilliseconds() {
    const clock = new FakeClock(Instant.FromUnixTimeTicks(100));
    clock.AdvanceMilliseconds(3);
    assertNodaEqual(clock.GetCurrentInstant().ToUnixTimeTicks(), 100 + 3 * NodaConstants.TicksPerMillisecond);
  },

  AdvanceSeconds() {
    const clock = new FakeClock(Instant.FromUnixTimeTicks(100));
    clock.AdvanceSeconds(3);
    assertNodaEqual(clock.GetCurrentInstant().ToUnixTimeTicks(), 100 + 3 * NodaConstants.TicksPerSecond);
  },

  AdvanceMinutes() {
    const clock = new FakeClock(Instant.FromUnixTimeTicks(100));
    clock.AdvanceMinutes(3);
    assertNodaEqual(clock.GetCurrentInstant().ToUnixTimeTicks(), 100 + 3 * NodaConstants.TicksPerMinute);
  },

  AdvanceHours() {
    const clock = new FakeClock(Instant.FromUnixTimeTicks(100));
    clock.AdvanceHours(3);
    assertNodaEqual(clock.GetCurrentInstant().ToUnixTimeTicks(), 100 + 3 * NodaConstants.TicksPerHour);
  },

  AdvanceDays() {
    const clock = new FakeClock(Instant.FromUnixTimeTicks(100));
    clock.AdvanceDays(3);
    assertNodaEqual(clock.GetCurrentInstant().ToUnixTimeTicks(), 100 + 3 * NodaConstants.TicksPerDay);
  },

  Reset() {
    const instant1 = Instant.FromUnixTimeTicks(100);
    const instant2 = Instant.FromUnixTimeTicks(500);
    const clock = new FakeClock(instant1);
    assertNodaEqual(clock.GetCurrentInstant(), instant1);
    clock.Reset(instant2);
    assertNodaEqual(clock.GetCurrentInstant(), instant2);
  },
});
