// Ported from NodaTime 3.3.7: src/NodaTime/Extensions/IsoDayOfWeekExtensions.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { IsoDayOfWeek } from "../internal.ts";
import { NewArgumentOutOfRangeException, type ArgumentOutOfRangeException } from "../internal.ts";

/**
 * Converts a {@link IsoDayOfWeek} into the corresponding `System.DayOfWeek` value.
 *
 * This is a convenience method which calls `BclConversions.ToDayOfWeek` (inlined here).
 *
 * noda-js: `System.DayOfWeek` is represented by its numeric value (0 = Sunday to 6 = Saturday), which is
 * also the numbering used by `Date.prototype.getDay()`.
 *
 * @param isoDayOfWeek The `IsoDayOfWeek` to convert.
 * @returns The `DayOfWeek` equivalent to `isoDayOfWeek`
 * @throws {ArgumentOutOfRangeException} The `isoDayOfWeek` parameter is not a valid day of the week.
 */
export function ToDayOfWeek(isoDayOfWeek: IsoDayOfWeek): number {
  // C#: BclConversions.ToDayOfWeek(IsoDayOfWeek)
  if (!(isoDayOfWeek >= IsoDayOfWeek.Monday && isoDayOfWeek <= IsoDayOfWeek.Sunday)) {
    throw NewArgumentOutOfRangeException("isoDayOfWeek");
  }
  return isoDayOfWeek === IsoDayOfWeek.Sunday ? 0 : isoDayOfWeek;
}
