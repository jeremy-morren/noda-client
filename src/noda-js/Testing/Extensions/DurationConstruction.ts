// Ported from NodaTime 3.3.0: src/NodaTime.Testing/Extensions/DurationConstruction.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Duration } from "../../internal.ts";

// Extension methods for constructing {@link Duration} values.
// (C#: static class DurationConstruction. The extension methods become exported functions; NodaTime's
// double/int/long overloads of each method are merged into one function taking a number.)

/**
 * Constructs a duration with the specified number of days.
 * @param days The desired number of days.
 * @returns A duration with the specified number of days.
 */
export function Days(days: number): Duration {
  return Duration.FromDays(days);
}

/**
 * Constructs a duration with the specified number of hours.
 * @param hours The desired number of hours.
 * @returns A duration with the specified number of hours.
 */
export function Hours(hours: number): Duration {
  return Duration.FromHours(hours);
}

/**
 * Constructs a duration with the specified number of minutes.
 * @param minutes The desired number of minutes.
 * @returns A duration with the specified number of minutes.
 */
export function Minutes(minutes: number): Duration {
  return Duration.FromMinutes(minutes);
}

/**
 * Constructs a duration with the specified number of seconds.
 * @param seconds The desired number of seconds.
 * @returns A duration with the specified number of seconds.
 */
export function Seconds(seconds: number): Duration {
  return Duration.FromSeconds(seconds);
}

/**
 * Constructs a duration with the specified number of milliseconds.
 * @param milliseconds The desired number of milliseconds.
 * @returns A duration with the specified number of milliseconds.
 */
export function Milliseconds(milliseconds: number): Duration {
  return Duration.FromMilliseconds(milliseconds);
}

/**
 * Constructs a duration with the specified number of ticks.
 * @param ticks The desired number of ticks.
 * @returns A duration with the specified number of ticks.
 */
export function Ticks(ticks: number | string): Duration {
  return Duration.FromTicks(ticks);
}

/**
 * Constructs a duration with the specified number of nanoseconds.
 * @param nanoseconds The desired number of nanoseconds.
 * @returns A duration with the specified number of nanoseconds.
 */
export function Nanoseconds(nanoseconds: number | string): Duration {
  return Duration.FromNanoseconds(nanoseconds);
}
