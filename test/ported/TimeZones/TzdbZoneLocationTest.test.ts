// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeZones/TzdbZoneLocationTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import {
  DateTimeZoneReader,
  DateTimeZoneWriter,
  InvalidNodaDataException,
  MemoryStream,
  TzdbZoneLocation,
} from "../../../src/noda-js/internal.ts";
import { assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { TestHelper } from "../../helpers/TestHelper.ts";
import { fixture } from "../../scenarios/TimeZones/TzdbZoneLocationTest.generated.ts";

port(
  fixture,
  {
    Valid() {
      const location = new TzdbZoneLocation(60 * 3600 + 15 * 60 + 5, 100 * 3600 + 30 * 60 + 10, "Country name", "CO", "Etc/MadeUpZone", "Comment");
      expect(location.Latitude).toBeCloseTo(60.25 + 5.0 / 3600, 6);
      expect(location.Longitude).toBeCloseTo(100.5 + 10.0 / 3600, 6);
      expect(location.CountryName).toBe("Country name");
      expect(location.CountryCode).toBe("CO");
      expect(location.ZoneId).toBe("Etc/MadeUpZone");
      expect(location.Comment).toBe("Comment");
    },

    LatitudeRange() {
      assertThrows("ArgumentOutOfRangeException", () => new TzdbZoneLocation(90 * 3600 + 1, 0, "Name", "CO", "Zone", ""));
      assertThrows("ArgumentOutOfRangeException", () => new TzdbZoneLocation(-90 * 3600 - 1, 0, "Name", "CO", "Zone", ""));
      // We'll assume these are built correctly: we're just checking the constructor doesn't throw.
      new TzdbZoneLocation(90 * 3600, 0, "Name", "CO", "Zone", "");
      new TzdbZoneLocation(-90 * 3600, 0, "Name", "CO", "Zone", "");
    },

    LongitudeRange() {
      assertThrows("ArgumentOutOfRangeException", () => new TzdbZoneLocation(0, 180 * 3600 + 1, "Name", "CO", "Zone", ""));
      assertThrows("ArgumentOutOfRangeException", () => new TzdbZoneLocation(0, -180 * 3600 - 1, "Name", "CO", "Zone", ""));
      // We'll assume these are built correctly: we're just checking the constructor doesn't throw.
      new TzdbZoneLocation(0, 180 * 3600, "Name", "CO", "Zone", "");
      new TzdbZoneLocation(0, -180 * 3600, "Name", "CO", "Zone", "");
    },

    Constructor_InvalidArguments() {
      assertThrows("ArgumentNullException", () => new TzdbZoneLocation(0, 0, null!, "CO", "Zone", ""));
      assertThrows("ArgumentNullException", () => new TzdbZoneLocation(0, 0, "Name", null!, "Zone", ""));
      assertThrows("ArgumentNullException", () => new TzdbZoneLocation(0, 0, "Name", "CO", null!, ""));
      assertThrows("ArgumentNullException", () => new TzdbZoneLocation(0, 0, "Name", "CO", "Zone", null!));
      TestHelper.assertInvalid(() => new TzdbZoneLocation(0, 0, "", "CO", "Zone", ""));
      TestHelper.assertInvalid(() => new TzdbZoneLocation(0, 0, "Name", "Long code", "Zone", ""));
      TestHelper.assertInvalid(() => new TzdbZoneLocation(0, 0, "Name", "S", "Zone", ""));
    },

    Serialization() {
      const location = new TzdbZoneLocation(
        60 * 3600 + 15 * 60 + 5,
        100 * 3600 + 30 * 60 + 10,
        "Country name",
        "CO",
        "Etc/MadeUpZone",
        "Comment");

      const stream = new MemoryStream();
      const writer = DateTimeZoneWriter.NewOutputStringPool(stream, null);
      location.Write(writer);
      stream.Position = 0;

      const reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      const location2 = TzdbZoneLocation.Read(reader);

      expect(location2.Latitude).toBeCloseTo(60.25 + 5.0 / 3600, 6);
      expect(location2.Longitude).toBeCloseTo(100.5 + 10.0 / 3600, 6);
      expect(location2.CountryName).toBe("Country name");
      expect(location2.CountryCode).toBe("CO");
      expect(location2.ZoneId).toBe("Etc/MadeUpZone");
      expect(location2.Comment).toBe("Comment");
    },

    ReadInvalid() {
      const stream = new MemoryStream();
      const writer = DateTimeZoneWriter.NewOutputStringPool(stream, null);
      // This is invalid
      writer.WriteSignedCount(90 * 3600 + 1);
      writer.WriteSignedCount(0);
      writer.WriteString("name");
      writer.WriteString("co");
      writer.WriteString("Europe/Somewhere");
      writer.WriteString("");
      stream.Position = 0;
      const reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      assertThrows(InvalidNodaDataException, () => TzdbZoneLocation.Read(reader));
    },
  },
);
