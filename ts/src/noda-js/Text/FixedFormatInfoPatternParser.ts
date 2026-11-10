// Ported from NodaTime 3.3.7: src/NodaTime/Text/FixedFormatInfoPatternParser.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Cache } from "../internal.ts";
import type { IPattern, IPatternParser, NodaFormatInfo } from "../internal.ts";

// It would be unusual to have more than 50 different patterns for a specific culture
// within a real app.
const CacheSize = 50;

/**
 * A pattern parser for a single format info, which caches patterns by text/style.
 * @internal
 */
export class FixedFormatInfoPatternParser<T> {
  private readonly _cache: Cache<string, IPattern<T>>;

  constructor(patternParser: IPatternParser<T>, formatInfo: NodaFormatInfo) {
    // noda-js: Map keys compare ordinally (C#: StringComparer.Ordinal).
    this._cache = Cache.NewSizeValueFactoryKeyComparer<string, IPattern<T>>(CacheSize, (patternText: string) =>
      patternParser.ParsePattern(patternText, formatInfo),
    );
  }

  /** @internal */
  static NewPatternParserFormatInfo<T>(patternParser: IPatternParser<T>, formatInfo: NodaFormatInfo): FixedFormatInfoPatternParser<T> {
    return new FixedFormatInfoPatternParser<T>(patternParser, formatInfo);
  }

  ParsePattern(pattern: string): IPattern<T> {
    return this._cache.GetOrAdd(pattern);
  }
}
