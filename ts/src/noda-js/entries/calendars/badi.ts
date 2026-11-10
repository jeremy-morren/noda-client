// noda-js/calendars/badi: the Badíʿ calendar system, which NodaTime has as CalendarSystem.Badi. noda-js exports it here
// instead, under the same name, so that bundles only contain the calendars an app imports (this one's data table
// included). Importing this module also registers it, so CalendarSystem.ForId and CalendarSystem.Ids include it.
// Ported from NodaTime 3.3.7: src/NodaTime/CalendarSystem.cs (that member, and its MiscellaneousCalendars initializer)
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { BadiYearMonthDayCalculator, CalendarOrdinal, CalendarSystem, Era } from "../../internal.ts";

// C#: CalendarSystem's BadiName and BadiId.
const BadiName = "Badi";
const BadiId = BadiName;

/**
 * Returns the Badíʿ (meaning "wondrous" or "unique") calendar, as described at https://en.wikipedia.org/wiki/Badi_calendar.
 * This is a purely solar calendar with years starting at the vernal equinox.
 *
 * The Badíʿ calendar was developed and defined by the founders of the Bahá'í Faith in the mid to late
 * 1800's A.D. The first year in the calendar coincides with 1844 A.D. Years are labeled "B.E." for Bahá'í Era.
 *
 * A year consists of 19 months, each with 19 days. Each day starts at sunset. Years are grouped into sets
 * of 19 "Unities" (Váḥid) and 19 Unities make up 1 "All Things" (Kull-i-Shay’).
 *
 * A period of days (usually 4 or 5, called Ayyám-i-Há) occurs between the 18th and 19th months. The length of this
 * period of intercalary days is solely determined by the date of the following vernal equinox. The vernal equinox is
 * a momentary point in time, so the "date" of the equinox is determined by the date (beginning
 * at sunset) in effect in Tehran, Iran at the moment of the equinox.
 *
 * In this Noda Time implementation, days start at midnight and lookup tables are used to determine vernal equinox dates.
 * Ayyám-i-Há is internally modelled as extra days added to the 18th month. As a result, a few functions will
 * not work as expected for Ayyám-i-Há, such as EndOfMonth.
 *
 * (C#: CalendarSystem.Badi.)
 */
export const Badi: CalendarSystem = CalendarSystem.NewOrdinalIdNameYearMonthDayCalculatorSingleEra(
  CalendarOrdinal.Badi, BadiId, BadiName, BadiYearMonthDayCalculator.New(), Era.Bahai);

CalendarSystem.RegisterCalendar(Badi);
