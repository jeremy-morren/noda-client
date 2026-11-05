// Ported from NodaTime 3.3.7: src/NodaTime/Calendars/HebrewMonthConverter.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { HebrewScripturalCalculator } from "../internal.ts";

/**
 * Conversions between civil and scriptural month numbers in the Hebrew calendar system.
 * @internal
 */
export class HebrewMonthConverter {
  private constructor() {}

  /**
   * Given a civil month number and a year in which it occurs, this method returns
   * the equivalent scriptural month number.
   *
   * No validation is performed in this method: an input month number of 13 in a non-leap-year
   * will return a result of 7.
   * @param year Year during which the month occurs.
   * @param month Civil month number.
   * @returns The scriptural month number.
   */
  static CivilToScriptural(year: number, month: number): number {
    if (month < 7) {
      return month + 6;
    }
    const leapYear = HebrewScripturalCalculator.IsLeapYear(year);
    if (month === 7) { // Adar II (13) or Nisan (1) depending on whether it's a leap year.
      return leapYear ? 13 : 1;
    }
    return leapYear ? month - 7 : month - 6;
  }

  /**
   * Given an scriptural month number and a year in which it occurs, this method returns
   * the equivalent scriptural month number.
   *
   * No validation is performed in this method: an input month number of 13 in a non-leap-year
   * will return a result of 7.
   * @param year Year during which the month occurs.
   * @param month Civil month number.
   * @returns The scriptural month number.
   */
  static ScripturalToCivil(year: number, month: number): number {
    if (month >= 7) {
      return month - 6;
    }
    return HebrewScripturalCalculator.IsLeapYear(year) ? month + 7 : month + 6;
  }
}
