// Ported from NodaTime 3.3.0: src/NodaTime.Test/Text/AnnualDatePatternTest.cs
// Copyright The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { AnnualDate, AnnualDatePattern } from "../../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { scenarioCulture } from "../../helpers/decode.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/AnnualDatePatternTest.generated.ts";
import { assertParseNull, CurrentCultureSkip, patternTestBaseBodies, type PatternTestData } from "./PatternTestSupport.ts";

port(
  fixture,
  {
    ...patternTestBaseBodies<AnnualDate>({
      // Data.CreatePattern()
      createPattern: (data: PatternTestData<AnnualDate>) => AnnualDatePattern.CreateWithInvariantCulture(data.pattern!).WithTemplateValue(data.template!).WithCulture(data.culture!),
    }),

    // C#: new CultureInfo(cultureId)
    CreateWithCulture(cultureId: string, expected: string) {
      const date = new AnnualDate(8, 23);
      const culture = scenarioCulture(cultureId);
      const pattern = AnnualDatePattern.Create("MM/dd", culture);
      expect(pattern.Format(date)).toBe(expected);
    },

    CreateWithCultureAndTemplateValue(cultureId: string, expected: string) {
      const date = new AnnualDate(8, 23);
      const template = new AnnualDate(5, 3);
      const culture = scenarioCulture(cultureId);
      // Check the culture is still used
      const pattern1 = AnnualDatePattern.Create("MM/dd", culture, template);
      expect(pattern1.Format(date)).toBe(expected);
      // And the template value
      const pattern2 = AnnualDatePattern.Create("MM", culture, template);
      const parsed = pattern2.Parse("08").Value;
      assertNodaEqual(parsed, new AnnualDate(8, 3));
    },

    ParseNull: () => assertParseNull(AnnualDatePattern.Iso),
  },
  {
    skip: {
      CreateWithCurrentCulture: CurrentCultureSkip,
    },
  },
);
