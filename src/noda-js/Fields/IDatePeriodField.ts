// Ported from NodaTime 3.3.0: src/NodaTime/Fields/IDatePeriodField.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import type { LocalDate } from "../internal.ts";

/**
 * General representation of the difference between two dates in a particular time unit,
 * such as "days" or "months".
 * @internal
 */
export interface IDatePeriodField {
  /**
   * Adds a duration value (which may be negative) to the date. This may not
   * be reversible; for example, adding a month to January 30th will result in
   * February 28th or February 29th.
   * @param localDate The local date to add to
   * @param value The value to add, in the units of the field
   * @returns The updated local date
   */
  Add(localDate: LocalDate, value: number): LocalDate;

  /**
   * Computes the difference between two local dates, as measured in the units
   * of this field, rounding towards zero. This rounding means that
   * unit.Add(start, unit.UnitsBetween(start, end)) always ends up with a date
   * between start and end. (Ideally equal to end, but importantly, it never overshoots.)
   * @param start The start date
   * @param end The end date
   * @returns The difference in the units of this field
   */
  UnitsBetween(start: LocalDate, end: LocalDate): number;
}
