// Ported from NodaTime 3.3.0: src/NodaTime/Text/Patterns/PatternBclSupport.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { NodaFormatInfo } from "../../internal.ts";
import type { FixedFormatInfoPatternParser, IFormatProvider, IPattern } from "../../internal.ts";

/**
 * Class providing simple support for the various Parse/TryParse/ParseExact/TryParseExact/Format overloads
 * provided by individual types.
 * @internal
 */
export class PatternBclSupport<T> {
  private readonly _patternParser: (formatInfo: NodaFormatInfo) => FixedFormatInfoPatternParser<T>;
  private readonly _defaultFormatPattern: string;

  constructor(defaultFormatPattern: string, patternParser: (formatInfo: NodaFormatInfo) => FixedFormatInfoPatternParser<T>) {
    this._patternParser = patternParser;
    this._defaultFormatPattern = defaultFormatPattern;
  }

  /** @internal */
  static NewDefaultFormatPatternPatternParser<T>(
    defaultFormatPattern: string,
    patternParser: (formatInfo: NodaFormatInfo) => FixedFormatInfoPatternParser<T>,
  ): PatternBclSupport<T> {
    return new PatternBclSupport<T>(defaultFormatPattern, patternParser);
  }

  /**
   * Formats a value; this backs each value type's `toString(patternText, formatProvider)`.
   * (noda-js: a null or undefined format provider means the invariant culture, not the current culture.)
   */
  Format(value: T, patternText?: string | null, formatProvider?: IFormatProvider | null): string {
    if (patternText === null || patternText === undefined || patternText.length === 0) {
      patternText = this._defaultFormatPattern;
    }
    const formatInfo = NodaFormatInfo.GetInstance(formatProvider);
    const pattern: IPattern<T> = this._patternParser(formatInfo).ParsePattern(patternText);
    return pattern.Format(value);
  }
}
