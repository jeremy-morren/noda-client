// Ported from NodaTime 3.3.0: src/NodaTime.Test/Text/OffsetDateTimePatternTest.cs
// Copyright The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import {
  ArgumentOutOfRangeError,
  CalendarSystem,
  Instant,
  LocalDateTime,
  NodaFormatInfo,
  Offset,
  OffsetDateTimePattern,
  type OffsetDateTime,
} from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { scenarioCulture } from "../../helpers/decode.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/OffsetDateTimePatternTest.generated.ts";
import { assertParseNull, CurrentCultureSkip, patternTestBaseBodies, type PatternTestData } from "./PatternTestSupport.ts";

port(
  fixture,
  {
    ...patternTestBaseBodies<OffsetDateTime>({
      // Data.CreatePattern()
      createPattern: (data: PatternTestData<OffsetDateTime>) => OffsetDateTimePattern.Create(data.pattern!, data.culture!, data.template!),
    }),

    CreateWithInvariantCulture() {
      const pattern = OffsetDateTimePattern.CreateWithInvariantCulture("uuuu-MM-dd'T'HH:mm:sso<g>");
      expect(pattern.FormatInfo).toBe(NodaFormatInfo.InvariantInfo);
      const odt = new LocalDateTime(2017, 8, 23, 12, 34, 56).WithOffset(Offset.FromHours(2));
      expect(pattern.Format(odt)).toBe("2017-08-23T12:34:56+02");
    },

    WithCulture() {
      const pattern = OffsetDateTimePattern.CreateWithInvariantCulture("HH:mm").WithCulture(scenarioCulture("Cultures.DotTimeSeparator"));
      const text = pattern.Format(Instant.FromUtc(2000, 1, 1, 19, 30).WithOffset(Offset.Zero));
      expect(text).toBe("19.30");
    },

    WithPatternText() {
      const pattern = OffsetDateTimePattern.CreateWithInvariantCulture("uuuu-MM-dd").WithPatternText("HH:mm");
      const value = Instant.FromUtc(1970, 1, 1, 11, 30).WithOffset(Offset.FromHours(2));
      const text = pattern.Format(value);
      expect(text).toBe("13:30");
    },

    WithTemplateValue() {
      const pattern = OffsetDateTimePattern.CreateWithInvariantCulture("uuuu-MM-dd").WithTemplateValue(
        Instant.FromUtc(1970, 1, 1, 11, 30).WithOffset(Offset.FromHours(2)),
      );
      const parsed = pattern.Parse("2017-08-23").Value;
      // Local time of template value was 13:30
      assertNodaEqual(parsed.LocalDateTime, new LocalDateTime(2017, 8, 23, 13, 30, 0));
      assertNodaEqual(parsed.Offset, Offset.FromHours(2));
    },

    WithCalendar() {
      const pattern = OffsetDateTimePattern.CreateWithInvariantCulture("uuuu-MM-dd")
        .WithCalendar(CalendarSystem.Coptic);
      const parsed = pattern.Parse("0284-08-29").Value;
      assertNodaEqual(parsed.LocalDateTime, new LocalDateTime(284, 8, 29, 0, 0, CalendarSystem.Coptic));
    },

    ParseNull: () => assertParseNull(OffsetDateTimePattern.ExtendedIso),

    WithTwoDigitYearMax(twoDigitYearMax: number, text: string, expectedYear: number) {
      const pattern = OffsetDateTimePattern.CreateWithInvariantCulture("yy-MM-dd'T'HH:mm:ss o<g>").WithTwoDigitYearMax(twoDigitYearMax);
      const value = pattern.Parse(text).Value;
      expect(value.Year).toBe(expectedYear);
    },

    WithTwoDigitYearMax_Invalid(twoDigitYearMax: number) {
      assertThrows(ArgumentOutOfRangeError, () => OffsetDateTimePattern.GeneralIso.WithTwoDigitYearMax(twoDigitYearMax));
    },
  },
  {
    skip: {
      CreateWithCurrentCulture: CurrentCultureSkip,
    },
  },
);
