// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/HebrewMonthConverter.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'HebrewScripturalCalculator.dart';

/// Conversions between civil and scriptural month numbers in the Hebrew calendar system.
@internal
abstract final class HebrewMonthConverter {
  /// Given a civil month number and a year in which it occurs, this method returns
  /// the equivalent scriptural month number.
  ///
  /// No validation is performed in this method: an input month number of 13 in a non-leap-year
  /// will return a result of 7.
  ///
  /// [year]: Year during which the month occurs.
  /// [month]: Civil month number.
  ///
  /// Returns the scriptural month number.
  static int CivilToScriptural(int year, int month) {
    if (month < 7) {
      return month + 6;
    }
    bool leapYear = HebrewScripturalCalculator.IsLeapYear(year);
    if (month == 7) // Adar II (13) or Nisan (1) depending on whether it's a leap year.
    {
      return leapYear ? 13 : 1;
    }
    return leapYear ? month - 7 : month - 6;
  }

  /// Given an scriptural month number and a year in which it occurs, this method returns
  /// the equivalent scriptural month number.
  ///
  /// No validation is performed in this method: an input month number of 13 in a non-leap-year
  /// will return a result of 7.
  ///
  /// [year]: Year during which the month occurs.
  /// [month]: Civil month number.
  ///
  /// Returns the scriptural month number.
  static int ScripturalToCivil(int year, int month) {
    if (month >= 7) {
      return month - 6;
    }
    return HebrewScripturalCalculator.IsLeapYear(year) ? month + 7 : month + 6;
  }
}
