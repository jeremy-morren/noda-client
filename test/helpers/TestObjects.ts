// Ported from NodaTime 3.3.0: src/NodaTime.Test/TestObjects.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { NodaConstants, Offset, Preconditions } from "../../src/noda-js/internal.ts";

/** Helper methods for creating objects of various kinds. */
export const TestObjects = {
  /**
   * Creates a positive offset from the given values.
   * @param hours The number of hours, in the range [0, 24).
   * @param minutes The number of minutes, in the range [0, 60).
   * @param seconds The number of seconds, in the range [0, 60).
   * @returns A new {@link Offset} representing the given values.
   * @throws {ArgumentOutOfRangeError} The result of the operation is outside the range of Offset.
   */
  createPositiveOffset(hours: number, minutes: number, seconds: number): Offset {
    Preconditions.CheckArgumentRange("hours", hours, 0, 23);
    Preconditions.CheckArgumentRange("minutes", minutes, 0, 59);
    Preconditions.CheckArgumentRange("seconds", seconds, 0, 59);
    seconds += minutes * NodaConstants.SecondsPerMinute;
    seconds += hours * NodaConstants.SecondsPerHour;
    return Offset.FromSeconds(seconds);
  },

  /**
   * Creates a negative offset from the given values.
   * @param hours The number of hours, in the range [0, 24).
   * @param minutes The number of minutes, in the range [0, 60).
   * @param seconds The number of seconds, in the range [0, 60).
   * @returns A new {@link Offset} representing the given values.
   * @throws {ArgumentOutOfRangeError} The result of the operation is outside the range of Offset.
   */
  createNegativeOffset(hours: number, minutes: number, seconds: number): Offset {
    return Offset.FromSeconds(-TestObjects.createPositiveOffset(hours, minutes, seconds).Seconds);
  },
} as const;
