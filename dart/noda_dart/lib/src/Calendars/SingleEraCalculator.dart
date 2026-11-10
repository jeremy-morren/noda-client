// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/SingleEraCalculator.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Utility/Preconditions.dart';
import 'Era.dart';
import 'EraCalculator.dart';
import 'YearMonthDayCalculator.dart';

/// Implementation of [EraCalculator] for calendars which only have a single era.
@internal
final class SingleEraCalculator extends EraCalculator {
  final Era _era;

  final int _minYear;
  final int _maxYear;

  SingleEraCalculator.NewEraYmdCalculator(Era era, YearMonthDayCalculator ymdCalculator)
      : _minYear = ymdCalculator.MinYear,
        _maxYear = ymdCalculator.MaxYear,
        _era = era,
        super.NewEras([era]);

  void _ValidateEra(Era era) {
    if (era != _era) {
      // Dart: null safety checks era.
      Preconditions.CheckArgument(era == _era, 'era', 'Only supported era is {0}; requested era was {1}',
          _era.Name, era.Name);
    }
  }

  @override
  int GetAbsoluteYear(int yearOfEra, Era era) {
    _ValidateEra(era);
    Preconditions.CheckArgumentRange('yearOfEra', yearOfEra, _minYear, _maxYear);
    return yearOfEra;
  }

  @override
  int GetYearOfEra(int absoluteYear) => absoluteYear;

  @override
  int GetMinYearOfEra(Era era) {
    _ValidateEra(era);
    return _minYear;
  }

  @override
  int GetMaxYearOfEra(Era era) {
    _ValidateEra(era);
    return _maxYear;
  }

  @override
  Era GetEra(int absoluteYear) => _era;

  @override
  Era get DefaultEra => _era;
}
