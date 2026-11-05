// noda-js/calendars/islamic: the tabular Islamic (Hijri) calendar systems, which NodaTime has as
// CalendarSystem.GetIslamicCalendar and CalendarSystem.IslamicBcl. noda-js exports them here instead, under the same
// names, so that bundles only contain the calendars an app imports. Importing this module also registers them, so
// CalendarSystem.ForId and CalendarSystem.Ids include them. (The Um Al Qura calendar is separate:
// noda-js/calendars/umalqura.)
// Ported from NodaTime 3.3.7: src/NodaTime/CalendarSystem.cs (those members, GetIslamicId, and the IslamicCalendars
// holder class)
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarOrdinal,
  CalendarSystem,
  Era,
  IslamicEpoch,
  IslamicLeapYearPattern,
  IslamicYearMonthDayCalculator,
  Preconditions,
} from "../../internal.ts";

// C#: CalendarSystem's IslamicName and IslamicIdBase.
const IslamicName = "Hijri";
const IslamicIdBase = IslamicName;

/** C#: CalendarSystem.GetIslamicId (internal). */
function GetIslamicId(leapYearPattern: IslamicLeapYearPattern, epoch: IslamicEpoch): string {
  return `${IslamicIdBase} ${IslamicEpoch[epoch]}-${IslamicLeapYearPattern[leapYearPattern]}`;
}

// C#: CalendarSystem.IslamicCalendars.ByLeapYearPatternAndEpoch, a CalendarSystem[4, 2] (created when this module is
// imported): specifically the calendars implemented by IslamicYearMonthDayCalculator, as opposed to all Islam-based
// calendars (which would include UmAlQura and Persian, for example).
const ByLeapYearPatternAndEpoch: CalendarSystem[][] = [[], [], [], []];
for (let i = 1; i <= 4; i++) {
  for (let j = 1; j <= 2; j++) {
    const leapYearPattern = i as IslamicLeapYearPattern;
    const epoch = j as IslamicEpoch;
    const calculator = IslamicYearMonthDayCalculator.NewLeapYearPatternEpoch(i as IslamicLeapYearPattern, j as IslamicEpoch);
    const ordinal = (CalendarOrdinal.IslamicAstronomicalBase15 + (i - 1) + (j - 1) * 4) as CalendarOrdinal;
    const calendar = CalendarSystem.NewOrdinalIdNameYearMonthDayCalculatorSingleEra(ordinal, GetIslamicId(leapYearPattern, epoch),
      IslamicName, calculator, Era.AnnoHegirae);
    ByLeapYearPatternAndEpoch[i - 1]![j - 1] = calendar;
    CalendarSystem.RegisterCalendar(calendar);
  }
}

/**
 * Returns an Islamic, or Hijri, calendar system.
 *
 * This returns a tabular calendar, rather than one based on lunar observation. This calendar is a
 * lunar calendar with 12 months, each of 29 or 30 days, resulting in a year of 354 days (or 355 on a leap
 * year).
 *
 * Year 1 in the Islamic calendar began on July 15th or 16th, 622 CE (Julian), thus
 * Islamic years do not begin at the same time as Julian years. This calendar
 * is not proleptic, as it does not allow dates before the first Islamic year.
 *
 * There are two basic forms of the Islamic calendar, the tabular and the
 * observed. The observed form cannot easily be used by computers as it
 * relies on human observation of the new moon. The tabular calendar, implemented here, is an
 * arithmetic approximation of the observed form that follows relatively simple rules.
 *
 * You should choose an epoch based on which external system you wish
 * to be compatible with. The epoch beginning on July 16th is the more common
 * one for the tabular calendar, so using {@link IslamicEpoch.Civil}
 * would usually be a logical choice. However, Windows uses July 15th, so
 * if you need to be compatible with other Windows systems, you may wish to use
 * {@link IslamicEpoch.Astronomical}. The fact that the Islamic calendar
 * traditionally starts at dusk, a Julian day traditionally starts at noon,
 * and all calendar systems in Noda Time start their days at midnight adds
 * somewhat inevitable confusion to the mix, unfortunately.
 *
 * The tabular form of the calendar defines 12 months of alternately
 * 30 and 29 days. The last month is extended to 30 days in a leap year.
 * Leap years occur according to a 30 year cycle. There are four recognised
 * patterns of leap years in the 30 year cycle:
 *
 * | Origin | Leap years |
 * |---|---|
 * | Kūshyār ibn Labbān | 2, 5, 7, 10, 13, 15, 18, 21, 24, 26, 29 |
 * | al-Fazārī | 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29 |
 * | Fātimid (also known as Misri or Bohra) | 2, 5, 8, 10, 13, 16, 19, 21, 24, 27, 29 |
 * | Habash al-Hasib | 2, 5, 8, 11, 13, 16, 19, 21, 24, 27, 30 |
 *
 * The leap year pattern to use is determined from the first parameter to this factory method.
 * The second parameter determines which epoch is used - the "astronomical" or "Thursday" epoch
 * (July 15th 622CE) or the "civil" or "Friday" epoch (July 16th 622CE).
 *
 * This implementation defines a day as midnight to midnight exactly as per
 * the ISO calendar. This correct start of day is at sunset on the previous
 * day, however this cannot readily be modelled and has been ignored.
 *
 * (C#: CalendarSystem.GetIslamicCalendar.)
 * @param leapYearPattern The pattern of years in the 30-year cycle to consider as leap years
 * @param epoch The kind of epoch to use (astronomical or civil)
 * @returns A suitable Islamic calendar reference; the same reference may be returned by several
 * calls as the object is immutable and thread-safe.
 */
export function GetIslamicCalendar(leapYearPattern: IslamicLeapYearPattern, epoch: IslamicEpoch): CalendarSystem {
  Preconditions.CheckArgumentRange("leapYearPattern", leapYearPattern, 1, 4);
  Preconditions.CheckArgumentRange("epoch", epoch, 1, 2);
  return ByLeapYearPatternAndEpoch[leapYearPattern - 1]![epoch - 1]!;
}

/**
 * Returns an Islamic calendar system equivalent to the one used by the BCL HijriCalendar.
 *
 * This uses the {@link IslamicLeapYearPattern.Base16} leap year pattern and the
 * {@link IslamicEpoch.Astronomical} epoch. This is equivalent to HijriCalendar
 * when the `HijriCalendar.HijriAdjustment` is 0.
 *
 * (C#: CalendarSystem.IslamicBcl.)
 * @see {@link GetIslamicCalendar}
 */
export const IslamicBcl: CalendarSystem = GetIslamicCalendar(IslamicLeapYearPattern.Base16, IslamicEpoch.Astronomical);
