// Ported from NodaTime 6e024dde: src/NodaTime.Test/LocalInstantTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { Duration, Instant, InstantPatternParser, LocalInstant, NodaConstants, Offset } from "../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/LocalInstantTest.generated.ts";

port(fixture, {
  Equality() {
    const equal = LocalInstant.NewDaysNanoOfDay(1, 100);
    const different1 = LocalInstant.NewDaysNanoOfDay(1, 200);
    const different2 = LocalInstant.NewDaysNanoOfDay(2, 100);

    // noda-js: C# passes the same struct value twice (copied); here a distinct equal instance is needed.
    const equal2 = LocalInstant.NewDaysNanoOfDay(1, 100);

    TestHelper.testEqualsStruct(equal, equal2, different1);
    TestHelper.testOperatorEquality(equal, equal2, different1);

    TestHelper.testEqualsStruct(equal, equal2, different2);
    TestHelper.testOperatorEquality(equal, equal2, different2);
  },

  MinusOffset_Zero_IsNeutralElement() {
    const sampleInstant = Instant.NewDaysNanoOfDay(1, 23456);
    const sampleLocalInstant = LocalInstant.NewDaysNanoOfDay(1, 23456);
    assertNodaEqual(sampleLocalInstant.Minus(Offset.Zero), sampleInstant);
    assertNodaEqual(sampleLocalInstant.MinusZeroOffset(), sampleInstant);
  },

  ToString_Valid(day: number, nanoOfDay: number, expectedText: string) {
    expect(LocalInstant.NewDaysNanoOfDay(day, nanoOfDay).toString()).toBe(expectedText);
  },

  ToString_Extremes() {
    expect(LocalInstant.BeforeMinValue.toString()).toBe(InstantPatternParser.BeforeMinValueText);
    expect(LocalInstant.AfterMaxValue.toString()).toBe(InstantPatternParser.AfterMaxValueText);
  },

  SafeMinus_NormalTime() {
    const start = LocalInstant.NewDaysNanoOfDay(0, 0);
    const end = start.SafeMinus(Offset.FromHours(1));
    assertNodaEqual(end.TimeSinceEpoch, Duration.FromHours(-1));
  },

  // A null offset indicates "BeforeMinValue". Otherwise, MinValue.Plus(offset)
  SafeMinus_NearStartOfTime(initialOffset: number | null, offsetToSubtract: number, finalOffset: number | null) {
    const start = initialOffset === null
      ? LocalInstant.BeforeMinValue
      : Instant.MinValue.Plus(Offset.FromHours(initialOffset));
    const expected = finalOffset === null
      ? Instant.BeforeMinValue
      : Instant.Add(Instant.MinValue, Duration.FromHours(finalOffset));
    const actual = start.SafeMinus(Offset.FromHours(offsetToSubtract));
    assertNodaEqual(actual, expected);
  },

  // A null offset indicates "AfterMaxValue". Otherwise, MaxValue.Plus(offset)
  SafeMinus_NearEndOfTime(initialOffset: number | null, offsetToSubtract: number, finalOffset: number | null) {
    const start = initialOffset === null
      ? LocalInstant.AfterMaxValue
      : Instant.MaxValue.Plus(Offset.FromHours(initialOffset));
    const expected = finalOffset === null
      ? Instant.AfterMaxValue
      : Instant.Add(Instant.MaxValue, Duration.FromHours(finalOffset));
    const actual = start.SafeMinus(Offset.FromHours(offsetToSubtract));
    assertNodaEqual(actual, expected);
  },

  IsValid() {
    expect(LocalInstant.BeforeMinValue.IsValid).toBe(false);
    expect(LocalInstant.NewNanoseconds(Instant.Subtract(Instant.MinValue, NodaConstants.UnixEpoch)).IsValid).toBe(true);
    expect(LocalInstant.NewNanoseconds(Instant.Subtract(Instant.MaxValue, NodaConstants.UnixEpoch)).IsValid).toBe(true);
    expect(LocalInstant.AfterMaxValue.IsValid).toBe(false);
  },
});
