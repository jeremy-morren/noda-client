// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/GJEraCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Utility/Preconditions.dart';
import 'Era.dart';
import 'EraCalculator.dart';
import 'YearMonthDayCalculator.dart';

/// Era calculator for Gregorian and Julian calendar systems, which use BC and AD.
@internal
final class GJEraCalculator extends EraCalculator {
  final int _maxYearOfBc;
  final int _maxYearOfAd;

  GJEraCalculator.NewYmdCalculator(YearMonthDayCalculator ymdCalculator)
      : _maxYearOfBc = 1 - ymdCalculator.MinYear, // Convert from absolute to year-of-era
        _maxYearOfAd = ymdCalculator.MaxYear,
        super.NewEras([Era.BeforeCommon, Era.Common]);

  static void _ValidateEra(Era era) {
    if (era != Era.Common && era != Era.BeforeCommon) {
      // Dart: null safety checks era.
      Preconditions.CheckArgument(false, 'era', 'Era {0} is not supported by this calendar; only BC and AD are supported', era.Name);
    }
  }

  @override
  int GetAbsoluteYear(int yearOfEra, Era era) {
    _ValidateEra(era);
    if (era == Era.Common) {
      Preconditions.CheckArgumentRange('yearOfEra', yearOfEra, 1, _maxYearOfAd);
      return yearOfEra;
    }
    Preconditions.CheckArgumentRange('yearOfEra', yearOfEra, 1, _maxYearOfBc);
    return 1 - yearOfEra;
  }

  @override
  int GetYearOfEra(int absoluteYear) {
    return absoluteYear > 0 ? absoluteYear : 1 - absoluteYear;
  }

  @override
  Era GetEra(int absoluteYear) => absoluteYear > 0 ? Era.Common : Era.BeforeCommon;

  @override
  int GetMinYearOfEra(Era era) {
    _ValidateEra(era);
    return 1;
  }

  @override
  int GetMaxYearOfEra(Era era) {
    _ValidateEra(era);
    return era == Era.Common ? _maxYearOfAd : _maxYearOfBc;
  }

  @override
  Era get DefaultEra => Era.Common;
}
