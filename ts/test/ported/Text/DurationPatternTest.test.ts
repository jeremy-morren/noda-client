// Ported from NodaTime 3.3.7: src/NodaTime.Test/Text/DurationPatternTest.cs
// Copyright The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { Duration, DurationPattern } from "../../../src/noda-js/internal.ts";
import { scenarioCulture } from "../../helpers/decode.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/DurationPatternTest.generated.ts";
import { assertParseNull, CurrentCultureSkip, patternTestBaseBodies, type PatternTestData } from "./PatternTestSupport.ts";

port(
  fixture,
  {
    ...patternTestBaseBodies<Duration>({
      // Data.CreatePattern()
      createPattern: (data: PatternTestData<Duration>) => DurationPattern.Create(data.pattern!, data.culture!),
    }),

    ParseNull: () => assertParseNull(DurationPattern.Roundtrip),

    WithCulture() {
      const pattern = DurationPattern.CreateWithInvariantCulture("H:mm").WithCulture(scenarioCulture("Cultures.DotTimeSeparator"));
      const text = pattern.Format(Duration.FromMinutes(90));
      expect(text).toBe("1.30");
    },
  },
  {
    skip: {
      CreateWithCurrentCulture: CurrentCultureSkip,
    },
  },
);
