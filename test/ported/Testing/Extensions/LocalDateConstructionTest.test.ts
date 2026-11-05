// Ported from NodaTime 3.3.7: src/NodaTime.Test/Testing/Extensions/LocalDateConstructionTest.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the extension methods on int are functions taking the day first (`18.January(2017)` is
// `January(18, 2017)`).

import { LocalDate } from "../../../../src/noda-js/internal.ts";
import {
  April,
  August,
  December,
  February,
  January,
  July,
  June,
  March,
  May,
  November,
  October,
  September,
} from "../../../../src/noda-js/entries/testing.ts";
import { assertNodaEqual } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/Testing/Extensions/LocalDateConstructionTest.generated.ts";

port(fixture, {
  Construction() {
    assertNodaEqual(January(18, 2017), new LocalDate(2017, 1, 18));
    assertNodaEqual(February(18, 2017), new LocalDate(2017, 2, 18));
    assertNodaEqual(March(18, 2017), new LocalDate(2017, 3, 18));
    assertNodaEqual(April(18, 2017), new LocalDate(2017, 4, 18));
    assertNodaEqual(May(18, 2017), new LocalDate(2017, 5, 18));
    assertNodaEqual(June(18, 2017), new LocalDate(2017, 6, 18));
    assertNodaEqual(July(18, 2017), new LocalDate(2017, 7, 18));
    assertNodaEqual(August(18, 2017), new LocalDate(2017, 8, 18));
    assertNodaEqual(September(18, 2017), new LocalDate(2017, 9, 18));
    assertNodaEqual(October(18, 2017), new LocalDate(2017, 10, 18));
    assertNodaEqual(November(18, 2017), new LocalDate(2017, 11, 18));
    assertNodaEqual(December(18, 2017), new LocalDate(2017, 12, 18));
  },
});
