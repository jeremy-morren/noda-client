// noda-js/calendars/hebrew: the Hebrew calendar systems, which NodaTime has as CalendarSystem.GetHebrewCalendar,
// CalendarSystem.HebrewCivil and CalendarSystem.HebrewScriptural. noda-js exports them here instead, under the same
// names, so that bundles only contain the calendars an app imports. Importing this module also registers them, so
// CalendarSystem.ForId and CalendarSystem.Ids include them.
// Ported from NodaTime 3.3.7: src/NodaTime/CalendarSystem.cs (those members, and the HebrewCalendars holder class)
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { CalendarOrdinal, CalendarSystem, Era, HebrewMonthNumbering, HebrewYearMonthDayCalculator, Preconditions } from "../../internal.ts";

// C#: CalendarSystem's HebrewName, HebrewIdBase, HebrewCivilId and HebrewScripturalId.
const HebrewName = "Hebrew";
const HebrewIdBase = HebrewName;
const HebrewCivilId = HebrewIdBase + " Civil";
const HebrewScripturalId = HebrewIdBase + " Scriptural";

// C#: CalendarSystem.HebrewCalendars.ByMonthNumbering (created when this module is imported).
const ByMonthNumbering: readonly CalendarSystem[] = [
  CalendarSystem.NewOrdinalIdNameYearMonthDayCalculatorSingleEra(CalendarOrdinal.HebrewCivil, HebrewCivilId, HebrewName,
    HebrewYearMonthDayCalculator.NewMonthNumbering(HebrewMonthNumbering.Civil), Era.AnnoMundi),
  CalendarSystem.NewOrdinalIdNameYearMonthDayCalculatorSingleEra(CalendarOrdinal.HebrewScriptural, HebrewScripturalId, HebrewName,
    HebrewYearMonthDayCalculator.NewMonthNumbering(HebrewMonthNumbering.Scriptural), Era.AnnoMundi),
];
for (const calendar of ByMonthNumbering) {
  CalendarSystem.RegisterCalendar(calendar);
}

/**
 * Returns a Hebrew calendar, as described at https://en.wikipedia.org/wiki/Hebrew_calendar. This is a
 * purely mathematical calculator, applied proleptically to the period where the real calendar was observational.
 *
 * Please note that support for the Hebrew calendar is somewhat experimental,
 * particularly in terms of calculations involving adding or subtracting years. Additionally, text formatting
 * and parsing using month names is not currently supported, due to the challenges of handling leap months.
 * It is hoped that this will be improved in future versions.
 *
 * The implementation for this was taken from https://www.cs.tau.ac.il/~nachum/calendar-book/papers/calendar.ps,
 * which is a public domain algorithm presumably equivalent to that given in the Calendrical Calculations book
 * by the same authors (Nachum Dershowitz and Edward Reingold).
 *
 * (C#: CalendarSystem.GetHebrewCalendar.)
 * @param monthNumbering The month numbering system to use
 * @returns A Hebrew calendar system for the given month numbering.
 */
export function GetHebrewCalendar(monthNumbering: HebrewMonthNumbering): CalendarSystem {
  Preconditions.CheckArgumentRange("monthNumbering", monthNumbering, 1, 2);
  return ByMonthNumbering[monthNumbering - 1]!;
}

/**
 * Returns a Hebrew calendar system using the civil month numbering,
 * equivalent to the one used by the BCL HebrewCalendar.
 *
 * (C#: CalendarSystem.HebrewCivil.)
 * @see {@link GetHebrewCalendar}
 */
export const HebrewCivil: CalendarSystem = GetHebrewCalendar(HebrewMonthNumbering.Civil);

/**
 * Returns a Hebrew calendar system using the scriptural month numbering.
 *
 * (C#: CalendarSystem.HebrewScriptural.)
 * @see {@link GetHebrewCalendar}
 */
export const HebrewScriptural: CalendarSystem = GetHebrewCalendar(HebrewMonthNumbering.Scriptural);
