// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler.Test/Tzdb/DateTimeZoneBuilderTest.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the internal ZoneRuleSet constructor is the static factory NewNameStandardOffsetSavingsUpperYearUpperYearOffset.

import { expect } from "vitest";
import { FixedDateTimeZone, Int32, Offset } from "../../../../src/noda-js/internal.ts";
import { DateTimeZoneBuilder, ZoneRuleSet } from "../../../../src/noda-js/TzdbCompiler/internal.ts";
import { assertNodaEqual } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/TzdbCompiler/Tzdb/DateTimeZoneBuilderTest.generated.ts";

port(fixture, {
  FixedZone_Western() {
    const offset = Offset.FromHours(-5);
    const rules = [ZoneRuleSet.NewNameStandardOffsetSavingsUpperYearUpperYearOffset("GMT+5", offset, Offset.Zero, Int32.MaxValue, null)];
    const zone = DateTimeZoneBuilder.Build("GMT+5", rules);
    expect(zone).toBeInstanceOf(FixedDateTimeZone);
    const fixedZone = zone as FixedDateTimeZone;
    assertNodaEqual(fixedZone.Offset, offset);
  },

  FixedZone_Eastern() {
    const offset = Offset.FromHours(5);
    const rules = [ZoneRuleSet.NewNameStandardOffsetSavingsUpperYearUpperYearOffset("GMT-5", offset, Offset.Zero, Int32.MaxValue, null)];
    const zone = DateTimeZoneBuilder.Build("GMT-5", rules);
    expect(zone).toBeInstanceOf(FixedDateTimeZone);
    const fixedZone = zone as FixedDateTimeZone;
    assertNodaEqual(fixedZone.Offset, offset);
  },
});
