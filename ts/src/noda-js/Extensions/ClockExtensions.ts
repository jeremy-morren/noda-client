// Ported from NodaTime 3.3.7: src/NodaTime/Extensions/ClockExtensions.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { CalendarSystem, DateTimeZone, ZonedClock } from "../internal.ts";
import type { IClock } from "../internal.ts";

// Extension methods for {@link IClock}. (NodaTime's ClockExtensions static class; the methods are exported functions
// taking the clock as their first argument.)

/**
 * Constructs a {@link ZonedClock} from a clock (the target of the method),
 * a time zone, and a calendar system (the ISO calendar system by default).
 * @param clock Clock to use in the returned object.
 * @param zone Time zone to use in the returned object.
 * @param calendar Calendar to use in the returned object.
 * @returns A {@link ZonedClock} with the given clock, time zone and calendar system.
 */
export function InZone(clock: IClock, zone: DateTimeZone, calendar?: CalendarSystem): ZonedClock {
  return new ZonedClock(clock, zone, calendar ?? CalendarSystem.Iso);
}

/**
 * Constructs a {@link ZonedClock} from a clock (the target of the method),
 * using the UTC time zone and ISO calendar system.
 * @param clock Clock to use in the returned object.
 * @returns A {@link ZonedClock} with the given clock, in the UTC time zone and ISO calendar system.
 */
export function InUtc(clock: IClock): ZonedClock {
  return new ZonedClock(clock, DateTimeZone.Utc, CalendarSystem.Iso);
}

// Not ported: InTzdbSystemDefaultZone (use InZone(clock, tzdb.GetSystemDefault()))

// Not ported: InBclSystemDefaultZone (BCL interop)
