// Ported from NodaTime 3.3.7: src/NodaTime/Text/Delegates.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import type { ParseBucket, PatternCursor, SteppedPatternBuilder } from "../internal.ts";

// This file contains all the delegates declared within the NodaTime.Text namespace.
// It's simpler than either nesting them or giving them a file per delegate.

/** @internal */
export type CharacterHandler<TResult, TBucket extends ParseBucket<TResult>> = (
  patternCursor: PatternCursor,
  patternBuilder: SteppedPatternBuilder<TResult, TBucket>,
) => void;
