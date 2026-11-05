// noda-js/calendars/umalqura: the Um Al Qura calendar system, which NodaTime has as CalendarSystem.UmAlQura. noda-js
// exports it here instead, under the same name, so that bundles only contain the calendars an app imports (this one's
// data table included). Importing this module also registers it, so CalendarSystem.ForId and CalendarSystem.Ids
// include it.
// Ported from NodaTime 3.3.7: src/NodaTime/CalendarSystem.cs (that member, and its MiscellaneousCalendars initializer)
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { CalendarOrdinal, CalendarSystem, Era, UmAlQuraYearMonthDayCalculator } from "../../internal.ts";

// C#: CalendarSystem's UmAlQuraName and UmAlQuraId.
const UmAlQuraName = "Um Al Qura";
const UmAlQuraId = UmAlQuraName;

/**
 * Returns an Um Al Qura calendar system - an Islamic calendar system primarily used by
 * Saudi Arabia.
 *
 * This is a tabular calendar, relying on pregenerated data.
 *
 * (C#: CalendarSystem.UmAlQura.)
 */
export const UmAlQura: CalendarSystem = CalendarSystem.NewOrdinalIdNameYearMonthDayCalculatorSingleEra(
  CalendarOrdinal.UmAlQura, UmAlQuraId, UmAlQuraName, UmAlQuraYearMonthDayCalculator.New(), Era.AnnoHegirae);

CalendarSystem.RegisterCalendar(UmAlQura);
