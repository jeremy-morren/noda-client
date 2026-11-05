// Ported from NodaTime 3.3.0: src/NodaTime.Test/TimeZones/TransitionTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { Instant, Offset, Transition } from "../../../src/noda-js/internal.ts";
import { port } from "../../helpers/scenarios.ts";
import { TestHelper } from "../../helpers/TestHelper.ts";
import { fixture } from "../../scenarios/TimeZones/TransitionTest.generated.ts";

port(fixture, {
  Equality() {
    const equal1 = new Transition(Instant.FromUnixTimeSeconds(100), Offset.FromHours(1));
    const equal2 = new Transition(Instant.FromUnixTimeSeconds(100), Offset.FromHours(1));
    const unequal1 = new Transition(Instant.FromUnixTimeSeconds(101), Offset.FromHours(1));
    const unequal2 = new Transition(Instant.FromUnixTimeSeconds(100), Offset.FromHours(2));
    TestHelper.testEqualsStruct(equal1, equal2, unequal1);
    TestHelper.testEqualsStruct(equal1, equal2, unequal2);
    TestHelper.testOperatorEquality(equal1, equal2, unequal1);
    TestHelper.testOperatorEquality(equal1, equal2, unequal2);
  },

  TransitionToString() {
    const transition = new Transition(Instant.FromUtc(2017, 8, 25, 15, 26, 30), Offset.FromHours(1));
    expect(transition.toString()).toBe("Transition to +01 at 2017-08-25T15:26:30Z");
  },
});
