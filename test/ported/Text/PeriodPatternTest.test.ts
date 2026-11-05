// Ported from NodaTime 3.3.0: src/NodaTime.Test/Text/PeriodPatternTest.cs (+ .NormalizingIso.cs, .Roundtrip.cs)
// Copyright The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { PeriodPattern, type Period } from "../../../src/noda-js/internal.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture as normalizingIso } from "../../scenarios/Text/PeriodPatternTest.PeriodPatternNormalizingIsoTest.generated.ts";
import { fixture as roundtrip } from "../../scenarios/Text/PeriodPatternTest.PeriodPatternRoundtripTest.generated.ts";
import { assertParseNull, patternTestBaseBodies, type PatternTestData } from "./PatternTestSupport.ts";

// Data.CreatePattern() => StandardPattern
const bodies = patternTestBaseBodies<Period>({ createPattern: (data: PatternTestData<Period>) => data.standardPattern! });

port(normalizingIso, {
  ...bodies,
  ParseNull: () => assertParseNull(PeriodPattern.NormalizingIso),
});

port(roundtrip, {
  ...bodies,
  ParseNull: () => assertParseNull(PeriodPattern.Roundtrip),
});
