// noda-js/calendars/persian: the Persian (Solar Hijri) calendar systems, which NodaTime has as
// CalendarSystem.PersianSimple, CalendarSystem.PersianArithmetic and CalendarSystem.PersianAstronomical. noda-js exports
// them here instead, under the same names, so that bundles only contain the calendars an app imports (the astronomical
// calendar's leap year table included). Importing this module also registers them, so CalendarSystem.ForId and
// CalendarSystem.Ids include them.
// Ported from NodaTime 3.3.7: src/NodaTime/CalendarSystem.cs (those members, and the PersianCalendars holder class)
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarOrdinal,
  CalendarSystem,
  Era,
  PersianYearMonthDayCalculatorArithmetic,
  PersianYearMonthDayCalculatorAstronomical,
  PersianYearMonthDayCalculatorSimple,
} from "../../internal.ts";

// C#: CalendarSystem's PersianName, PersianIdBase, PersianSimpleId, PersianAstronomicalId and PersianArithmeticId.
const PersianName = "Persian";
const PersianIdBase = PersianName;
const PersianSimpleId = PersianIdBase + " Simple";
const PersianAstronomicalId = PersianIdBase + " Algorithmic";
const PersianArithmeticId = PersianIdBase + " Arithmetic";

/**
 * Returns a Persian (also known as Solar Hijri) calendar system implementing the behaviour of the
 * BCL `PersianCalendar` before .NET 4.6, and the sole Persian calendar in Noda Time 1.3.
 *
 * This implementation uses a simple 33-year leap cycle, where years  1, 5, 9, 13, 17, 22, 26, and 30
 * in each cycle are leap years.
 *
 * (C#: CalendarSystem.PersianSimple, from the PersianCalendars holder class.)
 */
export const PersianSimple: CalendarSystem = CalendarSystem.NewOrdinalIdNameYearMonthDayCalculatorSingleEra(
  CalendarOrdinal.PersianSimple, PersianSimpleId, PersianName, PersianYearMonthDayCalculatorSimple.New(), Era.AnnoPersico);

/**
 * Returns a Persian (also known as Solar Hijri) calendar system implementing the behaviour
 * proposed by Ahmad Birashk with nested cycles of years determining which years are leap years.
 *
 * This calendar is also known as the algorithmic Solar Hijri calendar.
 *
 * (C#: CalendarSystem.PersianArithmetic, from the PersianCalendars holder class.)
 */
export const PersianArithmetic: CalendarSystem = CalendarSystem.NewOrdinalIdNameYearMonthDayCalculatorSingleEra(
  CalendarOrdinal.PersianArithmetic, PersianArithmeticId, PersianName, PersianYearMonthDayCalculatorArithmetic.New(), Era.AnnoPersico);

/**
 * Returns a Persian (also known as Solar Hijri) calendar system implementing the behaviour of the
 * BCL `PersianCalendar` from .NET 4.6 onwards (and Windows 10), and the astronomical
 * system described in Wikipedia and Calendrical Calculations.
 *
 * This implementation uses data derived from the .NET 4.6 implementation (with the data built into Noda Time, so there's
 * no BCL dependency) for simplicity; the actual implementation involves computing the time of noon in Iran, and
 * is complex.
 *
 * (C#: CalendarSystem.PersianAstronomical, from the PersianCalendars holder class.)
 */
export const PersianAstronomical: CalendarSystem = CalendarSystem.NewOrdinalIdNameYearMonthDayCalculatorSingleEra(
  CalendarOrdinal.PersianAstronomical, PersianAstronomicalId, PersianName, PersianYearMonthDayCalculatorAstronomical.New(), Era.AnnoPersico);

CalendarSystem.RegisterCalendar(PersianSimple);
CalendarSystem.RegisterCalendar(PersianArithmetic);
CalendarSystem.RegisterCalendar(PersianAstronomical);
