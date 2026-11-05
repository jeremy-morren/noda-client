// Ported from NodaTime 3.3.7: src/NodaTime/Text/Patterns/IPatternParser.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import type { IPattern, NodaFormatInfo } from "../../internal.ts";

/**
 * Internal interface used by FixedFormatInfoPatternParser. Unfortunately
 * even though this is internal, implementations must either use public methods
 * or explicit interface implementation.
 * @internal
 */
export interface IPatternParser<T> {
  ParsePattern(pattern: string, formatInfo: NodaFormatInfo): IPattern<T>;
}
