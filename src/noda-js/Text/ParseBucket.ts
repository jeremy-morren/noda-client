// Ported from NodaTime 3.3.7: src/NodaTime/Text/ParseBucket.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import type { ParseResult, PatternFields } from "../internal.ts";

/**
 * Base class for "buckets" of parse data - as field values are parsed, they are stored in a bucket,
 * then the final value is calculated at the end.
 * @internal
 */
export abstract class ParseBucket<T> {
  /**
   * Performs the final conversion from fields to a value. The parse can still fail here, if there
   * are incompatible field values.
   * @param usedFields Indicates which fields were part of the original text pattern.
   * @param value Complete value being parsed
   */
  abstract CalculateValue(usedFields: PatternFields, value: string): ParseResult<T>;
}
