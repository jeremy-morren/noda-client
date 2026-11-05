// Ported from NodaTime 3.3.0: src/NodaTime/Calendars/EraCalculator.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import type { Era } from "../internal.ts";

/**
 * Takes responsibility for all era-based calculations for a calendar.
 * YearMonthDay arguments can be assumed to be valid for the relevant calendar,
 * but other arguments should be validated. (Eras should be validated for nullity as well
 * as for the presence of a particular era.)
 * @internal
 */
export abstract class EraCalculator {
  readonly Eras: readonly Era[];

  protected constructor(...eras: Era[]) {
    this.Eras = Object.freeze(eras);
  }

  abstract GetMinYearOfEra(era: Era): number;
  abstract GetMaxYearOfEra(era: Era): number;
  abstract GetEra(absoluteYear: number): Era;
  abstract GetYearOfEra(absoluteYear: number): number;
  abstract GetAbsoluteYear(yearOfEra: number, era: Era): number;
}
