// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/EraCalculator.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'Era.dart';

/// Takes responsibility for all era-based calculations for a calendar.
/// YearMonthDay arguments can be assumed to be valid for the relevant calendar,
/// but other arguments should be validated. (Eras should be validated for nullity as well
/// as for the presence of a particular era.)
@internal
abstract class EraCalculator {
  final List<Era> Eras;

  EraCalculator.NewEras(List<Era> eras) : Eras = List<Era>.unmodifiable(eras);

  // The era to use when a year-of-era is specified without an explicit era.
  Era get DefaultEra;
  int GetMinYearOfEra(Era era);
  int GetMaxYearOfEra(Era era);
  Era GetEra(int absoluteYear);
  int GetYearOfEra(int absoluteYear);
  int GetAbsoluteYear(int yearOfEra, Era era);
}
