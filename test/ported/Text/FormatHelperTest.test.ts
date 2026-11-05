// Ported from NodaTime 3.3.0: src/NodaTime.Test/Text/FormatHelperTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { FormatHelper, Int64, StringBuilder } from "../../../src/noda-js/internal.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/FormatHelperTest.generated.ts";

port(fixture, {
  TestLeftPad(value: number, length: number, expected: string) {
    const builder = new StringBuilder();
    FormatHelper.LeftPad(value, length, builder);
    expect(builder.toString()).toBe(expected);
  },

  TestLeftPadNonNegativeInt64(value: number | string, length: number, expected: string) {
    const builder = new StringBuilder();
    FormatHelper.LeftPadNonNegativeInt64(Int64.FromArgument(value, "value"), length, builder);
    expect(builder.toString()).toBe(expected);
  },

  TestAppendFraction(value: number, length: number, scale: number, expected: string) {
    const builder = new StringBuilder();
    FormatHelper.AppendFraction(value, length, scale, builder);
    expect(builder.toString()).toBe(expected);
  },

  TestAppendFractionTruncate(initial: string, value: number, length: number, scale: number, expected: string) {
    const builder = new StringBuilder(initial);
    FormatHelper.AppendFractionTruncate(value, length, scale, builder);
    expect(builder.toString()).toBe(expected);
  },

  // value arrives as a number (safe integer) or an exact decimal string (beyond 2^53, e.g. long.MinValue).
  FormatInvariant(value: number | string, expected: string) {
    const builder = new StringBuilder("x");
    FormatHelper.FormatInvariant(Int64.FromArgument(value, "value"), builder);
    expect(builder.toString()).toBe(expected);
  },
});
