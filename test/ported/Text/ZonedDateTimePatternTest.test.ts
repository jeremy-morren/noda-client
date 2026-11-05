// Ported from NodaTime 3.3.0: src/NodaTime.Test/Text/ZonedDateTimePatternTest.cs
// Copyright The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import {
  ArgumentOutOfRangeError,
  CalendarSystem,
  NodaCultureInfo,
  DateTimeZoneCache,
  Duration,
  FakeDateTimeZoneSourceBuilder,
  Instant,
  LocalDateTime,
  NodaConstants,
  Offset,
  Resolvers,
  SingleTransitionDateTimeZone,
  ZonedDateTimePattern,
  type DateTimeZone,
  type IDateTimeZoneProvider,
  type ZonedDateTime,
  type ZoneLocalMappingResolver,
} from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { scenarioCulture, testStatics, testZones } from "../../helpers/decode.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/ZonedDateTimePatternTest.generated.ts";
import { assertParseNull, CurrentCultureSkip, patternTestBaseBodies, type PatternTestData } from "./PatternTestSupport.ts";

// Three zones with a deliberately leading-substring-matching set of names.
// Transition is at 1am local time, going forward an hour.
const TestZone1 = new SingleTransitionDateTimeZone(Instant.FromUtc(2010, 1, 1, 0, 0), Offset.FromHours(1), Offset.FromHours(2), "ab");
// Transition is at 2am local time, going back an hour.
const TestZone2 = new SingleTransitionDateTimeZone(Instant.FromUtc(2010, 1, 1, 0, 0), Offset.FromHours(2), Offset.FromHours(1), "abc");
const TestZone3 = new SingleTransitionDateTimeZone(Instant.FromUtc(2010, 1, 1, 0, 0), Offset.FromHours(1), Offset.FromHours(2), "abcd");
const builder = new FakeDateTimeZoneSourceBuilder();
[TestZone1, TestZone2, TestZone3].forEach(zone => builder.Add(zone));
const TestProvider: IDateTimeZoneProvider = builder.Build().ToProvider();

// Let the scenario decoder resolve references to these, by identity.
testStatics.set("ZonedDateTimePatternTest.TestProvider", () => TestProvider);
for (const zone of [TestZone1, TestZone2, TestZone3]) {
  testZones.set(zone.Id, zone);
}

port(
  fixture,
  {
    ...patternTestBaseBodies<ZonedDateTime>({
      // Data.CreatePattern()
      createPattern: (data: PatternTestData<ZonedDateTime>) =>
        ZonedDateTimePattern.Create(
          data.pattern!,
          data.culture!,
          data["resolver"] as ZoneLocalMappingResolver,
          (data["zoneProvider"] ?? null) as IDateTimeZoneProvider | null,
          data.template!,
        ),
    }),

    WithTemplateValue() {
      const pattern = ZonedDateTimePattern.CreateWithInvariantCulture("uuuu-MM-dd", TestProvider).WithTemplateValue(
        Instant.FromUtc(1970, 1, 1, 11, 30).InZone(TestZone3),
      );
      const parsed = pattern.Parse("2017-08-23").Value;
      expect(parsed.Zone).toBe(TestZone3);
      // TestZone3 is at UTC+1 in 1970, so the template value's *local* time is 12pm.
      // Even though we're parsing a date in 2017, it's the local time from the template value that's used.
      assertNodaEqual(parsed.LocalDateTime, new LocalDateTime(2017, 8, 23, 12, 30, 0));
      assertNodaEqual(parsed.Offset, Offset.FromHours(2));
    },

    WithCalendar() {
      const pattern = ZonedDateTimePattern.CreateWithInvariantCulture("uuuu-MM-dd", TestProvider).WithCalendar(CalendarSystem.Coptic);
      const parsed = pattern.Parse("0284-08-29").Value;
      assertNodaEqual(parsed.LocalDateTime, new LocalDateTime(284, 8, 29, 0, 0, CalendarSystem.Coptic));
    },

    WithPatternText() {
      const pattern = ZonedDateTimePattern.CreateWithInvariantCulture("uuuu", TestProvider).WithPatternText("uuuu-MM-dd");
      const text = pattern.Format(NodaConstants.UnixEpoch.InUtc());
      expect(text).toBe("1970-01-01");
    },

    WithCulture() {
      const pattern = ZonedDateTimePattern.CreateWithInvariantCulture("HH:mm", null).WithCulture(scenarioCulture("Cultures.DotTimeSeparator"));
      const text = pattern.Format(Instant.FromUtc(2000, 1, 1, 19, 30).InUtc());
      expect(text).toBe("19.30");
    },

    // Test to hit each exit condition in the time zone ID parsing part of ZonedDateTimePatternParser
    FindLongestZoneId() {
      const createZone = (id: string): DateTimeZone =>
        new SingleTransitionDateTimeZone(Instant.Subtract(NodaConstants.UnixEpoch, Duration.FromDays(1)), Offset.FromHours(-1), Offset.FromHours(0), id);

      const sourceBuilder = new FakeDateTimeZoneSourceBuilder();
      for (const id of ["ABC", "ABCA", "ABCB", "ABCBX", "ABCD"]) {
        sourceBuilder.Add(createZone(id));
      }
      const source = sourceBuilder.Build();

      const provider = new DateTimeZoneCache(source);
      const pattern = ZonedDateTimePattern.Create("z 'x'", NodaCultureInfo.InvariantCulture, Resolvers.StrictResolver, provider, NodaConstants.UnixEpoch.InUtc());

      for (const id of provider.Ids) {
        const value = pattern.Parse(`${id} x`).Value;
        expect(value.Zone.Id).toBe(id);
      }
    },

    ParseNull: () => assertParseNull(ZonedDateTimePattern.ExtendedFormatOnlyIso.WithZoneProvider(TestProvider)),

    WithTwoDigitYearMax(twoDigitYearMax: number, text: string, expectedYear: number) {
      const pattern = ZonedDateTimePattern.CreateWithInvariantCulture("yy-MM-dd'T'HH:mm:ss z", TestProvider).WithTwoDigitYearMax(twoDigitYearMax);
      const value = pattern.Parse(text).Value;
      expect(value.Year).toBe(expectedYear);
    },

    WithTwoDigitYearMax_Invalid(twoDigitYearMax: number) {
      assertThrows(ArgumentOutOfRangeError, () => ZonedDateTimePattern.GeneralFormatOnlyIso.WithTwoDigitYearMax(twoDigitYearMax));
    },
  },
  {
    skip: {
      CreateWithCurrentCulture: CurrentCultureSkip,
    },
  },
);
