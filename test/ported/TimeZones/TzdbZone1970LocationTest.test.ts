// Ported from NodaTime 3.3.0: src/NodaTime.Test/TimeZones/TzdbZone1970LocationTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: TzdbZone1970Location.Country is TzdbZone1970LocationCountry. DateTimeZoneWriter isn't ported: ReadInvalid
// feeds the reader the bytes the C# test writes (see IO/DtzIoHelper.ts); Serialization (a write/read round trip) is
// skipped.

import { expect } from "vitest";
import {
  ArgumentNullError,
  ArgumentOutOfRangeError,
  InvalidNodaDataError,
  TzdbZone1970Location,
  TzdbZone1970LocationCountry as Country,
} from "../../../src/noda-js/internal.ts";
import { assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { TestHelper } from "../../helpers/TestHelper.ts";
import { fixture } from "../../scenarios/TimeZones/TzdbZone1970LocationTest.generated.ts";
import { countBytes, readerFor, signedCountBytes, stringBytes } from "./IO/DtzIoHelper.ts";

const SampleCountry = new Country("Country name", "CO");

port(
  fixture,
  {
    Valid() {
      const location = new TzdbZone1970Location(60 * 3600 + 15 * 60 + 5, 100 * 3600 + 30 * 60 + 10, [SampleCountry], "Etc/MadeUpZone", "Comment");
      expect(location.Latitude).toBeCloseTo(60.25 + 5.0 / 3600, 6);
      expect(location.Longitude).toBeCloseTo(100.5 + 10.0 / 3600, 6);
      expect(location.Countries[0]!.Name).toBe("Country name");
      expect(location.Countries[0]!.Code).toBe("CO");
      expect(location.ZoneId).toBe("Etc/MadeUpZone");
      expect(location.Comment).toBe("Comment");
    },

    CountryToString() {
      expect(SampleCountry.toString()).toBe("CO (Country name)");
    },

    ReadInvalid() {
      const bytes = [
        // Valid latitude/longitude
        ...signedCountBytes(0),
        ...signedCountBytes(0),
        // But no countries
        ...countBytes(0),
        ...stringBytes("Europe/Somewhere"),
        ...stringBytes(""),
      ];
      const reader = readerFor(bytes);
      assertThrows(InvalidNodaDataError, () => TzdbZone1970Location.Read(reader));
    },

    LatitudeRange() {
      assertThrows(ArgumentOutOfRangeError, () => new TzdbZone1970Location(90 * 3600 + 1, 0, [SampleCountry], "Zone", ""));
      assertThrows(ArgumentOutOfRangeError, () => new TzdbZone1970Location(-90 * 3600 - 1, 0, [SampleCountry], "Zone", ""));
      // We'll assume these are built correctly: we're just checking the constructor doesn't throw.
      new TzdbZone1970Location(90 * 3600, 0, [SampleCountry], "Zone", "");
      new TzdbZone1970Location(-90 * 3600, 0, [SampleCountry], "Zone", "");
    },

    LongitudeRange() {
      assertThrows(ArgumentOutOfRangeError, () => new TzdbZone1970Location(0, 180 * 3600 + 1, [SampleCountry], "Zone", ""));
      assertThrows(ArgumentOutOfRangeError, () => new TzdbZone1970Location(0, -180 * 3600 - 1, [SampleCountry], "Zone", ""));
      // We'll assume these are built correctly: we're just checking the constructor doesn't throw.
      new TzdbZone1970Location(0, 180 * 3600, [SampleCountry], "Zone", "");
      new TzdbZone1970Location(0, -180 * 3600, [SampleCountry], "Zone", "");
    },

    Constructor_InvalidArguments() {
      assertThrows(ArgumentNullError, () => new TzdbZone1970Location(0, 0, null!, "Zone", ""));
      TestHelper.assertInvalid(() => new TzdbZone1970Location(0, 0, [SampleCountry, null!], "Zone", ""));
      assertThrows(ArgumentNullError, () => new TzdbZone1970Location(0, 0, [SampleCountry], "Zone", null!));
      assertThrows(ArgumentNullError, () => new TzdbZone1970Location(0, 0, [SampleCountry], null!, ""));
      TestHelper.assertInvalid(() => new TzdbZone1970Location(0, 0, [], null!, ""));
    },

    CountryConstructor_InvalidArguments() {
      // C# named arguments: new Country(code: ..., name: ...); the constructor is Country(name, code).
      assertThrows(ArgumentNullError, () => new Country("Name", null!));
      assertThrows(ArgumentNullError, () => new Country(null!, "CO"));
      TestHelper.assertInvalid(() => new Country("", "CO"));
      TestHelper.assertInvalid(() => new Country("Name", "Long code"));
      TestHelper.assertInvalid(() => new Country("Name", "S"));
    },

    CountryEquality() {
      TestHelper.testEqualsClass(new Country("France", "FR"), new Country("France", "FR"), new Country("Germany", "DE"));
    },
  },
  {
    skip: {
      Serialization: "Needs DateTimeZoneWriter (TzdbZone1970Location.Write), which isn't ported",
    },
  },
);
