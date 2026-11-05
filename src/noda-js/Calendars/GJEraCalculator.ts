// Ported from NodaTime 3.3.7: src/NodaTime/Calendars/GJEraCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Era, EraCalculator, Preconditions, type YearMonthDayCalculator } from "../internal.ts";

/**
 * Era calculator for Gregorian and Julian calendar systems, which use BC and AD.
 * @internal
 */
export class GJEraCalculator extends EraCalculator {
  private readonly _maxYearOfBc: number;
  private readonly _maxYearOfAd: number;

  private constructor(ymdCalculator: YearMonthDayCalculator) {
    super(Era.BeforeCommon, Era.Common);
    this._maxYearOfBc = 1 - ymdCalculator.MinYear; // Convert from absolute to year-of-era
    this._maxYearOfAd = ymdCalculator.MaxYear;
  }

  /** C#: `internal GJEraCalculator(YearMonthDayCalculator ymdCalculator)` */
  static NewYmdCalculator(ymdCalculator: YearMonthDayCalculator): GJEraCalculator {
    return new GJEraCalculator(ymdCalculator);
  }

  private static ValidateEra(era: Era): void {
    if (era !== Era.Common && era !== Era.BeforeCommon) {
      Preconditions.CheckNotNull(era, "era");
      Preconditions.CheckArgument(false, "era", "Era {0} is not supported by this calendar; only BC and AD are supported", era.Name);
    }
  }

  override GetAbsoluteYear(yearOfEra: number, era: Era): number {
    GJEraCalculator.ValidateEra(era);
    if (era === Era.Common) {
      Preconditions.CheckArgumentRange("yearOfEra", yearOfEra, 1, this._maxYearOfAd);
      return yearOfEra;
    }
    Preconditions.CheckArgumentRange("yearOfEra", yearOfEra, 1, this._maxYearOfBc);
    return 1 - yearOfEra;
  }

  override GetYearOfEra(absoluteYear: number): number {
    return absoluteYear > 0 ? absoluteYear : 1 - absoluteYear;
  }

  override GetEra(absoluteYear: number): Era {
    return absoluteYear > 0 ? Era.Common : Era.BeforeCommon;
  }

  override GetMinYearOfEra(era: Era): number {
    GJEraCalculator.ValidateEra(era);
    return 1;
  }

  override GetMaxYearOfEra(era: Era): number {
    GJEraCalculator.ValidateEra(era);
    return era === Era.Common ? this._maxYearOfAd : this._maxYearOfBc;
  }

  override get DefaultEra(): Era {
    return Era.Common;
  }
}
