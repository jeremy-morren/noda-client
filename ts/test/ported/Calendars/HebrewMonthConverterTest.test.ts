// Ported from NodaTime 3.3.7: src/NodaTime.Test/Calendars/HebrewMonthConverterTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { HebrewMonthConverter } from "../../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/HebrewMonthConverterTest.generated.ts";

const SampleLeapYear = 5502;
const SampleNonLeapYear = 5501;

port(fixture, {
  NonLeapYear(scriptural: number, civil: number) {
    assertNodaEqual(HebrewMonthConverter.CivilToScriptural(SampleNonLeapYear, civil), scriptural);
    assertNodaEqual(HebrewMonthConverter.ScripturalToCivil(SampleNonLeapYear, scriptural), civil);
  },

  LeapYear(scriptural: number, civil: number) {
    assertNodaEqual(HebrewMonthConverter.CivilToScriptural(SampleLeapYear, civil), scriptural);
    assertNodaEqual(HebrewMonthConverter.ScripturalToCivil(SampleLeapYear, scriptural), civil);
  },
});
