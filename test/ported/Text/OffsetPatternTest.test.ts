// Ported from NodaTime 3.3.0: src/NodaTime.Test/Text/OffsetPatternTest.cs
// Copyright The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { Offset, OffsetPattern } from "../../../src/noda-js/internal.ts";
import { scenarioCulture } from "../../helpers/decode.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/OffsetPatternTest.generated.ts";
import {
  assertParseNull,
  CurrentCultureSkip,
  patternTestBaseBodies,
  testParsePartial,
  type PatternDataSupport,
  type PatternTestData,
} from "./PatternTestSupport.ts";

const support: PatternDataSupport<Offset> = {
  // Data.CreatePattern()
  createPattern: (data: PatternTestData<Offset>) => OffsetPattern.CreateWithInvariantCulture(data.pattern!).WithCulture(data.culture!),
  // Data.CreatePartialPattern()
  createPartialPattern: (data: PatternTestData<Offset>) => OffsetPattern.CreateWithInvariantCulture(data.pattern!).WithCulture(data.culture!).UnderlyingPattern,
};

port(
  fixture,
  {
    ...patternTestBaseBodies(support),
    ParsePartial: (data: PatternTestData<Offset>) => testParsePartial(support, data),

    ParseNull: () => assertParseNull(OffsetPattern.GeneralInvariant),

    NumberFormatIgnored() {
      // C# clones Cultures.EnUs and sets its NumberFormat's PositiveSign to "P" and NegativeSign to "N".
      // noda-js cultures have no NumberFormat (patterns only ever use '+' and '-'), so the culture is used as is.
      const culture = scenarioCulture("Cultures.EnUs");
      const pattern = OffsetPattern.Create("+HH:mm", culture);

      expect(pattern.Format(Offset.FromHours(5))).toBe("+05:00");
      expect(pattern.Format(Offset.FromHours(-5))).toBe("-05:00");
    },
  },
  {
    skip: {
      CreateWithCurrentCulture: CurrentCultureSkip,
    },
  },
);
