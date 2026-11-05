// Ported from NodaTime 3.3.0: src/NodaTime/SystemClock.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Duration, Instant } from "./internal.ts";
import type { IClock } from "./internal.ts";
import { NanosecondsPerMillisecond } from "./NodaConstants.generated.ts";

let instance: SystemClock | undefined;
/** noda-js: the last value returned, so that results never decrease. */
let lastInstant: Instant | undefined;

/**
 * Singleton implementation of {@link IClock} which reads the current system time.
 * It is recommended that for anything other than throwaway code, this is only referenced
 * in a single place in your code: where you provide a value to inject into the rest of
 * your application, which should only depend on the interface.
 *
 * noda-js: this is the only place in noda-js which reads the real time. The current instant is built from
 * `Date.now()`, refined to sub-millisecond precision with `performance.timeOrigin + performance.now()` where
 * available (and where that agrees with `Date.now()`, as the high-resolution clock doesn't follow adjustments to the
 * system clock). The values returned never decrease.
 *
 * This type has no state, and is thread-safe. See the thread safety section of the user guide for more information.
 */
export class SystemClock implements IClock {
  /** The singleton instance of {@link SystemClock}. */
  static get Instance(): SystemClock {
    return (instance ??= new SystemClock());
  }

  /** Constructor present to prevent external construction. */
  private constructor() {
  }

  /**
   * Gets the current time as an {@link Instant}.
   * @returns The current time as an {@link Instant}.
   */
  GetCurrentInstant(): Instant {
    // Not ported: NodaConstants.BclEpoch.PlusTicks(DateTime.UtcNow.Ticks) (BCL); see the class documentation.
    const dateNow = Date.now();
    let milliseconds = dateNow;
    let nanosecondOfMillisecond = 0;
    if (typeof performance !== "undefined" && typeof performance.now === "function" &&
      typeof performance.timeOrigin === "number") {
      // Split off the whole milliseconds of the origin first, to keep as much precision as possible.
      const origin = performance.timeOrigin;
      const originWhole = Math.floor(origin);
      const fraction = (origin - originWhole) + performance.now();
      const fractionWhole = Math.floor(fraction);
      const highResolutionMilliseconds = originWhole + fractionWhole;
      if (Math.abs(highResolutionMilliseconds - dateNow) <= 1) {
        milliseconds = highResolutionMilliseconds;
        nanosecondOfMillisecond = Math.min(Math.floor((fraction - fractionWhole) * NanosecondsPerMillisecond), NanosecondsPerMillisecond - 1);
      }
    }
    let result = Instant.FromUnixTimeMilliseconds(milliseconds);
    if (nanosecondOfMillisecond !== 0) {
      result = result.Plus(Duration.FromNanoseconds(nanosecondOfMillisecond));
    }
    if (lastInstant !== undefined && result.CompareTo(lastInstant) < 0) {
      return lastInstant;
    }
    lastInstant = result;
    return result;
  }
}
