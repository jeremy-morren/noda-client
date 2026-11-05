// Ported from NodaTime 3.3.0: src/NodaTime.Testing/Extensions/LocalDateConstruction.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { LocalDate } from "../../internal.ts";

// Extension methods for constructing {@link LocalDate} values in the ISO calendar.
// (C#: static class LocalDateConstruction. The extension methods on int become exported functions taking
// the day as their first argument: `1.January(2017)` becomes `january(1, 2017)`.)

/**
 * Constructs a {@link LocalDate} in January on the given day and year.
 * @example
 * ```ts
 * const date = january(1, 2017);
 * ```
 * @param day The day of January for the new date
 * @param year The year for the new date
 * @returns The specified date in January.
 */
export function January(day: number, year: number): LocalDate {
  return new LocalDate(year, 1, day);
}

/**
 * Constructs a {@link LocalDate} in February on the given day and year.
 * @example
 * ```ts
 * const date = february(1, 2017);
 * ```
 * @param day The day of February for the new date
 * @param year The year for the new date
 * @returns The specified date in February.
 */
export function February(day: number, year: number): LocalDate {
  return new LocalDate(year, 2, day);
}

/**
 * Constructs a {@link LocalDate} in March on the given day and year.
 * @example
 * ```ts
 * const date = march(1, 2017);
 * ```
 * @param day The day of March for the new date
 * @param year The year for the new date
 * @returns The specified date in March.
 */
export function March(day: number, year: number): LocalDate {
  return new LocalDate(year, 3, day);
}

/**
 * Constructs a {@link LocalDate} in April on the given day and year.
 * @example
 * ```ts
 * const date = april(1, 2017);
 * ```
 * @param day The day of April for the new date
 * @param year The year for the new date
 * @returns The specified date in April.
 */
export function April(day: number, year: number): LocalDate {
  return new LocalDate(year, 4, day);
}

/**
 * Constructs a {@link LocalDate} in May on the given day and year.
 * @example
 * ```ts
 * const date = may(1, 2017);
 * ```
 * @param day The day of May for the new date
 * @param year The year for the new date
 * @returns The specified date in May.
 */
export function May(day: number, year: number): LocalDate {
  return new LocalDate(year, 5, day);
}

/**
 * Constructs a {@link LocalDate} in June on the given day and year.
 * @example
 * ```ts
 * const date = june(1, 2017);
 * ```
 * @param day The day of June for the new date
 * @param year The year for the new date
 * @returns The specified date in June.
 */
export function June(day: number, year: number): LocalDate {
  return new LocalDate(year, 6, day);
}

/**
 * Constructs a {@link LocalDate} in July on the given day and year.
 * @example
 * ```ts
 * const date = july(1, 2017);
 * ```
 * @param day The day of July for the new date
 * @param year The year for the new date
 * @returns The specified date in July.
 */
export function July(day: number, year: number): LocalDate {
  return new LocalDate(year, 7, day);
}

/**
 * Constructs a {@link LocalDate} in August on the given day and year.
 * @example
 * ```ts
 * const date = august(1, 2017);
 * ```
 * @param day The day of August for the new date
 * @param year The year for the new date
 * @returns The specified date in August.
 */
export function August(day: number, year: number): LocalDate {
  return new LocalDate(year, 8, day);
}

/**
 * Constructs a {@link LocalDate} in September on the given day and year.
 * @example
 * ```ts
 * const date = september(1, 2017);
 * ```
 * @param day The day of September for the new date
 * @param year The year for the new date
 * @returns The specified date in September.
 */
export function September(day: number, year: number): LocalDate {
  return new LocalDate(year, 9, day);
}

/**
 * Constructs a {@link LocalDate} in October on the given day and year.
 * @example
 * ```ts
 * const date = october(1, 2017);
 * ```
 * @param day The day of October for the new date
 * @param year The year for the new date
 * @returns The specified date in October.
 */
export function October(day: number, year: number): LocalDate {
  return new LocalDate(year, 10, day);
}

/**
 * Constructs a {@link LocalDate} in November on the given day and year.
 * @example
 * ```ts
 * const date = november(1, 2017);
 * ```
 * @param day The day of November for the new date
 * @param year The year for the new date
 * @returns The specified date in November.
 */
export function November(day: number, year: number): LocalDate {
  return new LocalDate(year, 11, day);
}

/**
 * Constructs a {@link LocalDate} in December on the given day and year.
 * @example
 * ```ts
 * const date = december(1, 2017);
 * ```
 * @param day The day of December for the new date
 * @param year The year for the new date
 * @returns The specified date in December.
 */
export function December(day: number, year: number): LocalDate {
  return new LocalDate(year, 12, day);
}
