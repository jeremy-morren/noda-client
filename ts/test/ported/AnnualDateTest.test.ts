// Ported from NodaTime 6e024dde: src/NodaTime.Test/AnnualDateTest.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { AnnualDate, LocalDate } from "../../src/noda-js/internal.ts";
import { frCA } from "../../src/noda-js/Cultures/fr-CA.generated.ts";
import { frFR } from "../../src/noda-js/Cultures/fr-FR.generated.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/AnnualDateTest.generated.ts";

port(fixture, {
  Feb29() {
    const date = new AnnualDate(2, 29);
    assertNodaEqual(date.Day, 29);
    assertNodaEqual(date.Month, 2);
    assertNodaEqual(date.InYear(2016), new LocalDate(2016, 2, 29));
    expect(date.IsValidYear(2016)).toBe(true);
    assertNodaEqual(date.InYear(2015), new LocalDate(2015, 2, 28));
    expect(date.IsValidYear(2015)).toBe(false);
  },

  June19() {
    const date = new AnnualDate(6, 19);
    assertNodaEqual(date.Day, 19);
    assertNodaEqual(date.Month, 6);
    assertNodaEqual(date.InYear(2016), new LocalDate(2016, 6, 19));
    expect(date.IsValidYear(2016)).toBe(true);
    assertNodaEqual(date.InYear(2015), new LocalDate(2015, 6, 19));
    expect(date.IsValidYear(2015)).toBe(true);
  },

  Validation() {
    // Feb 30th is invalid, but January 30th is fine
    assertThrows("ArgumentOutOfRangeException", () => new AnnualDate(2, 30));
    TestHelper.consume(new AnnualDate(1, 30));

    // 13th month is invalid
    assertThrows("ArgumentOutOfRangeException", () => new AnnualDate(13, 1));
  },

  EqualityAndComparision() {
    const value = new AnnualDate(6, 19);
    const equalValue = new AnnualDate(6, 19);
    const greaterValue1 = new AnnualDate(6, 20);
    const greaterValue2 = new AnnualDate(7, 1);

    TestHelper.testEqualsStruct(value, equalValue, greaterValue1, greaterValue2);
    TestHelper.testCompareToStruct(value, equalValue, greaterValue1, greaterValue2);
    TestHelper.testNonGenericCompareTo(value, equalValue, greaterValue1, greaterValue2);
    TestHelper.testOperatorComparisonEquality(value, equalValue, greaterValue1, greaterValue2);
    TestHelper.testOperatorComparison(value, equalValue, greaterValue1, greaterValue2);
  },

  ToStringTest() {
    assertNodaEqual(new AnnualDate(2, 1).toString(), "02-01");
    assertNodaEqual(new AnnualDate(2, 10).toString(), "02-10");
    assertNodaEqual(new AnnualDate(12, 1).toString(), "12-01");
    assertNodaEqual(new AnnualDate(12, 20).toString(), "12-20");
  },

  ToString_WithFormat() {
    assertNodaEqual(new AnnualDate(2, 1).toString("G", frFR), "02-01");
    assertNodaEqual(new AnnualDate(2, 1).toString(null, frFR), "02-01");
    assertNodaEqual(new AnnualDate(2, 1).toString("MM/dd", frFR), "02/01");
    assertNodaEqual(new AnnualDate(2, 1).toString("MM/dd", frCA), "02-01");
  },
}, {
  skip: {
    DefaultValueIsJanuary1st: "C# default(AnnualDate) struct construction; AnnualDate has no parameterless constructor in noda-js",
    XmlSerialization: "XML serialization isn't ported",
    XmlSerialization_Invalid: "XML serialization isn't ported",
  },
});
