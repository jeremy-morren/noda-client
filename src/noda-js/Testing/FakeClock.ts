// Ported from NodaTime 3.3.0: src/NodaTime.Testing/FakeClock.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Duration, Instant } from "../internal.ts";
import type { IClock } from "../internal.ts";

/**
 * Clock which can be constructed with an initial instant, and then advanced programmatically (and optionally,
 * automatically advanced on each read).
 * This class is designed to be used when testing classes which take an {@link IClock} as a dependency.
 *
 * This class is somewhere between a fake and a stub, depending on how it's used - if it's set to
 * {@link FakeClock.AutoAdvance} then time will pass, but in a pretty odd way (i.e. dependent on how
 * often it's consulted).
 *
 * This type is thread-safe, primarily in order to allow {@link IClock} to be documented as
 * "thread safe in all built-in implementations".
 */
export class FakeClock implements IClock {
  // (C#'s lock object isn't needed: JS is single-threaded.)
  private _now: Instant;
  private _autoAdvance: Duration;

  /**
   * Creates a fake clock initially set to the given instant, with no auto-advance.
   * @param initial The initial instant.
   */
  constructor(initial: Instant);
  /**
   * Creates a fake clock initially set to the given instant. The clock will advance by the given duration on
   * each read.
   * @param initial The initial instant.
   * @param autoAdvance The duration to advance the clock on each read.
   * @see {@link FakeClock.AutoAdvance}
   */
  constructor(initial: Instant, autoAdvance: Duration);
  constructor(initial: Instant, autoAdvance?: Duration) {
    this._now = initial;
    this._autoAdvance = autoAdvance ?? Duration.Zero;
  }

  /**
   * Returns a fake clock initially set to midnight of the given year/month/day in UTC in the ISO calendar.
   * The value of the {@link FakeClock.AutoAdvance} property will be initialised to zero.
   * @param year The year. This is the "absolute year",
   * so a value of 0 means 1 BC, for example.
   * @param monthOfYear The month of year.
   * @param dayOfMonth The day of month.
   * @returns A {@link FakeClock} initialised to the given instant, with no auto-advance.
   */
  static FromUtc(year: number, monthOfYear: number, dayOfMonth: number): FakeClock;
  /**
   * Returns a fake clock initially set to the given year/month/day/time in UTC in the ISO calendar.
   * The value of the {@link FakeClock.AutoAdvance} property will be initialised to zero.
   * @param year The year. This is the "absolute year",
   * so a value of 0 means 1 BC, for example.
   * @param monthOfYear The month of year.
   * @param dayOfMonth The day of month.
   * @param hourOfDay The hour.
   * @param minuteOfHour The minute.
   * @param secondOfMinute The second.
   * @returns A {@link FakeClock} initialised to the given instant, with no auto-advance.
   */
  static FromUtc(year: number, monthOfYear: number, dayOfMonth: number, hourOfDay: number, minuteOfHour: number, secondOfMinute: number): FakeClock;
  static FromUtc(
    year: number,
    monthOfYear: number,
    dayOfMonth: number,
    hourOfDay?: number,
    minuteOfHour?: number,
    secondOfMinute?: number,
  ): FakeClock {
    if (hourOfDay === undefined) {
      return new FakeClock(Instant.FromUtc(year, monthOfYear, dayOfMonth, 0, 0));
    }
    return new FakeClock(Instant.FromUtc(year, monthOfYear, dayOfMonth, hourOfDay, minuteOfHour!, secondOfMinute!));
  }

  /**
   * Advances the clock by the given duration.
   * @param duration The duration to advance the clock by (or if negative, the duration to move it back
   * by).
   */
  Advance(duration: Duration): void {
    this._now = this._now.Plus(duration);
  }

  /**
   * Advances the clock by the given number of nanoseconds.
   * @param nanoseconds The number of nanoseconds to advance the clock by (or if negative, the number to move it back
   * by).
   */
  AdvanceNanoseconds(nanoseconds: number | string): void {
    this.Advance(Duration.FromNanoseconds(nanoseconds));
  }

  /**
   * Advances the clock by the given number of ticks.
   * @param ticks The number of ticks to advance the clock by (or if negative, the number to move it back
   * by).
   */
  AdvanceTicks(ticks: number | string): void {
    this.Advance(Duration.FromTicks(ticks));
  }

  /**
   * Advances the clock by the given number of milliseconds.
   * @param milliseconds The number of milliseconds to advance the clock by (or if negative, the number
   * to move it back by).
   */
  AdvanceMilliseconds(milliseconds: number): void {
    this.Advance(Duration.FromMilliseconds(milliseconds));
  }

  /**
   * Advances the clock by the given number of seconds.
   * @param seconds The number of seconds to advance the clock by (or if negative, the number to move it
   * back by).
   */
  AdvanceSeconds(seconds: number): void {
    this.Advance(Duration.FromSeconds(seconds));
  }

  /**
   * Advances the clock by the given number of minutes.
   * @param minutes The number of minutes to advance the clock by (or if negative, the number to move it
   * back by).
   */
  AdvanceMinutes(minutes: number): void {
    this.Advance(Duration.FromMinutes(minutes));
  }

  /**
   * Advances the clock by the given number of hours.
   * @param hours The number of hours to advance the clock by (or if negative, the number to move it
   * back by).
   */
  AdvanceHours(hours: number): void {
    this.Advance(Duration.FromHours(hours));
  }

  /**
   * Advances the clock by the given number of standard (24-hour) days.
   * @param days The number of days to advance the clock by (or if negative, the number to move it
   * back by).
   */
  AdvanceDays(days: number): void {
    this.Advance(Duration.FromDays(days));
  }

  /**
   * Resets the clock to the given instant.
   * The value of the {@link FakeClock.AutoAdvance} property will be unchanged.
   * @param instant The instant to set the clock to.
   */
  Reset(instant: Instant): void {
    this._now = instant;
  }

  /**
   * Returns the "current time" for this clock. Unlike a normal clock, this
   * property may return the same value from repeated calls until one of the methods
   * to change the time is called.
   *
   * If the value of the {@link FakeClock.AutoAdvance} property is non-zero, then every
   * call to this method will advance the current time by that value.
   * @returns The "current time" from this (fake) clock.
   */
  GetCurrentInstant(): Instant {
    const then = this._now;
    this._now = this._now.Plus(this._autoAdvance);
    return then;
  }

  /**
   * Gets the amount of time to advance the clock by on each call to read the current time.
   *
   * This defaults to zero, with the exception of the `FakeClock(Instant, Duration)` constructor,
   * which takes the initial value directly.  If this is zero, the current time as reported by this clock will
   * not change other than by calls to {@link FakeClock.Reset} or to one of the {@link FakeClock.Advance} methods.
   *
   * The value could even be negative, to simulate particularly odd system clock effects.
   * @see {@link FakeClock.GetCurrentInstant}
   */
  get AutoAdvance(): Duration {
    return this._autoAdvance;
  }

  set AutoAdvance(value: Duration) {
    this._autoAdvance = value;
  }
}
