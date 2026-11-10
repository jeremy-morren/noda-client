// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeZones/TzdbZone1970LocationTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import {
  DateTimeZoneReader,
  DateTimeZoneWriter,
  InvalidNodaDataException,
  MemoryStream,
  TzdbZone1970Location,
  TzdbZone1970LocationCountry as Country,
} from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { TestHelper } from "../../helpers/TestHelper.ts";
import { fixture } from "../../scenarios/TimeZones/TzdbZone1970LocationTest.generated.ts";

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

    Serialization() {
      const location = new TzdbZone1970Location(
        60 * 3600 + 15 * 60 + 5,
        100 * 3600 + 30 * 60 + 10,
        [SampleCountry],
        "Etc/MadeUpZone",
        "Comment");
      const stream = new MemoryStream();
      const writer = DateTimeZoneWriter.NewOutputStringPool(stream, null);
      location.Write(writer);
      stream.Position = 0;
      const reloaded = TzdbZone1970Location.Read(DateTimeZoneReader.NewInputStringPool(stream, null));
      expect(reloaded.Latitude).toBe(location.Latitude);
      expect(reloaded.Longitude).toBe(location.Longitude);
      assertNodaEqual([...reloaded.Countries], [...location.Countries]);
      expect(reloaded.ZoneId).toBe(location.ZoneId);
      expect(reloaded.Comment).toBe(location.Comment);
    },

    ReadInvalid() {
      const stream = new MemoryStream();
      const writer = DateTimeZoneWriter.NewOutputStringPool(stream, null);
      // Valid latitude/longitude
      writer.WriteSignedCount(0);
      writer.WriteSignedCount(0);
      // But no countries
      writer.WriteCount(0);
      writer.WriteString("Europe/Somewhere");
      writer.WriteString("");
      stream.Position = 0;
      const reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      assertThrows(InvalidNodaDataException, () => TzdbZone1970Location.Read(reader));
    },

    LatitudeRange() {
      assertThrows("ArgumentOutOfRangeException", () => new TzdbZone1970Location(90 * 3600 + 1, 0, [SampleCountry], "Zone", ""));
      assertThrows("ArgumentOutOfRangeException", () => new TzdbZone1970Location(-90 * 3600 - 1, 0, [SampleCountry], "Zone", ""));
      // We'll assume these are built correctly: we're just checking the constructor doesn't throw.
      new TzdbZone1970Location(90 * 3600, 0, [SampleCountry], "Zone", "");
      new TzdbZone1970Location(-90 * 3600, 0, [SampleCountry], "Zone", "");
    },

    LongitudeRange() {
      assertThrows("ArgumentOutOfRangeException", () => new TzdbZone1970Location(0, 180 * 3600 + 1, [SampleCountry], "Zone", ""));
      assertThrows("ArgumentOutOfRangeException", () => new TzdbZone1970Location(0, -180 * 3600 - 1, [SampleCountry], "Zone", ""));
      // We'll assume these are built correctly: we're just checking the constructor doesn't throw.
      new TzdbZone1970Location(0, 180 * 3600, [SampleCountry], "Zone", "");
      new TzdbZone1970Location(0, -180 * 3600, [SampleCountry], "Zone", "");
    },

    Constructor_InvalidArguments() {
      assertThrows("ArgumentNullException", () => new TzdbZone1970Location(0, 0, null!, "Zone", ""));
      TestHelper.assertInvalid(() => new TzdbZone1970Location(0, 0, [SampleCountry, null!], "Zone", ""));
      assertThrows("ArgumentNullException", () => new TzdbZone1970Location(0, 0, [SampleCountry], "Zone", null!));
      assertThrows("ArgumentNullException", () => new TzdbZone1970Location(0, 0, [SampleCountry], null!, ""));
      TestHelper.assertInvalid(() => new TzdbZone1970Location(0, 0, [], null!, ""));
    },

    CountryConstructor_InvalidArguments() {
      // C# named arguments: new Country(code: ..., name: ...); the constructor is Country(name, code).
      assertThrows("ArgumentNullException", () => new Country("Name", null!));
      assertThrows("ArgumentNullException", () => new Country(null!, "CO"));
      TestHelper.assertInvalid(() => new Country("", "CO"));
      TestHelper.assertInvalid(() => new Country("Name", "Long code"));
      TestHelper.assertInvalid(() => new Country("Name", "S"));
    },

    CountryEquality() {
      TestHelper.testEqualsClass(new Country("France", "FR"), new Country("France", "FR"), new Country("Germany", "DE"));
    },
  },
);
