// Ported from NodaTime 3.3.7: src/NodaTime/IClock.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import type { Instant } from "./internal.ts";
import type { SystemClock } from "./internal.ts";

/**
 * Represents a clock which can return the current time as an {@link Instant}.
 *
 * {@link IClock} is intended for use anywhere you need to have access to the current time.
 * Although it's not strictly incorrect to call `SystemClock.Instance.GetCurrentInstant()` directly,
 * in the same way as you might read the system clock directly, it's strongly discouraged
 * as a matter of style for production code. We recommend providing an instance of {@link IClock}
 * to anything that needs it, which allows you to write tests using the fake clock in noda-js/testing
 * (or your own implementation).
 *
 * All implementations in Noda Time are thread-safe; custom implementations
 * should be thread-safe too. See the thread safety section of the user guide for more information.
 * @see {@link SystemClock}
 */
export interface IClock {
  /**
   * Gets the current {@link Instant} on the time line according to this clock.
   * @returns The current instant on the time line according to this clock.
   */
  GetCurrentInstant(): Instant;
}
