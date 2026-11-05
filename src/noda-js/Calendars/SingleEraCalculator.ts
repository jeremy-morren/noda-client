// Ported from NodaTime 3.3.0: src/NodaTime/Calendars/SingleEraCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { EraCalculator, Preconditions, type Era, type YearMonthDayCalculator } from "../internal.ts";

/**
 * Implementation of {@link EraCalculator} for calendars which only have a single era.
 * @internal
 */
export class SingleEraCalculator extends EraCalculator {
  private readonly _era: Era;

  private readonly _minYear: number;
  private readonly _maxYear: number;

  private constructor(era: Era, ymdCalculator: YearMonthDayCalculator) {
    super(era);
    this._minYear = ymdCalculator.MinYear;
    this._maxYear = ymdCalculator.MaxYear;
    this._era = era;
  }

  /** C#: `internal SingleEraCalculator(Era era, YearMonthDayCalculator ymdCalculator)` */
  static NewEraYmdCalculator(era: Era, ymdCalculator: YearMonthDayCalculator): SingleEraCalculator {
    return new SingleEraCalculator(era, ymdCalculator);
  }

  private ValidateEra(era: Era): void {
    if (era !== this._era) {
      Preconditions.CheckNotNull(era, "era");
      Preconditions.CheckArgument(era === this._era, "era", "Only supported era is {0}; requested era was {1}",
        this._era.Name, era.Name);
    }
  }

  override GetAbsoluteYear(yearOfEra: number, era: Era): number {
    this.ValidateEra(era);
    Preconditions.CheckArgumentRange("yearOfEra", yearOfEra, this._minYear, this._maxYear);
    return yearOfEra;
  }

  override GetYearOfEra(absoluteYear: number): number {
    return absoluteYear;
  }

  override GetMinYearOfEra(era: Era): number {
    this.ValidateEra(era);
    return this._minYear;
  }

  override GetMaxYearOfEra(era: Era): number {
    this.ValidateEra(era);
    return this._maxYear;
  }

  override GetEra(absoluteYear: number): Era {
    void absoluteYear;
    return this._era;
  }
}
