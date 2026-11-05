// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeZones/FixedDateTimeZoneTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { DateTimeZone, FixedDateTimeZone, Instant, LocalDateTime, NodaConstants, Offset, ZoneInterval } from "../../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { TestHelper } from "../../helpers/TestHelper.ts";
import { fixture } from "../../scenarios/TimeZones/FixedDateTimeZoneTest.generated.ts";
import { DtzIoHelper } from "./IO/DtzIoHelper.ts";

const ZoneOffset = Offset.FromHours(-8);
const TestZone = new FixedDateTimeZone(ZoneOffset);
const FixedPeriod = new ZoneInterval(TestZone.Id, Instant.BeforeMinValue, Instant.AfterMaxValue, ZoneOffset, Offset.Zero);

port(fixture, {
  IsFixed_ReturnsTrue() {
    expect(TestZone.IsFixed).toBe(true);
  },

  GetZoneIntervalInstant_ZoneInterval() {
    const actual = TestZone.GetZoneInterval(NodaConstants.UnixEpoch);
    assertNodaEqual(actual, FixedPeriod);
  },

  SimpleProperties_ReturnValuesFromConstructor() {
    expect(TestZone.Id, "TestZone.Id").toBe("UTC-08");
    expect(TestZone.GetZoneInterval(NodaConstants.UnixEpoch).Name).toBe("UTC-08");
    assertNodaEqual(TestZone.GetUtcOffset(NodaConstants.UnixEpoch), ZoneOffset);
    assertNodaEqual(TestZone.MinOffset, ZoneOffset);
    assertNodaEqual(TestZone.MaxOffset, ZoneOffset);
  },

  GetZoneIntervals_ReturnsSingleInterval() {
    const mapping = TestZone.MapLocal(new LocalDateTime(2001, 7, 1, 1, 0, 0));
    assertNodaEqual(mapping.EarlyInterval, FixedPeriod);
    assertNodaEqual(mapping.LateInterval, FixedPeriod);
    expect(mapping.Count).toBe(1);
  },

  For_Id_FixedOffset() {
    const id = "UTC+05:30";
    const zone = FixedDateTimeZone.GetFixedZoneOrNull(id)!;
    assertNodaEqual(zone, DateTimeZone.ForOffset(Offset.FromHoursAndMinutes(5, 30)));
    expect(zone.Id).toBe(id);
  },

  For_Id_FixedOffset_NonCanonicalId() {
    const id = "UTC+05:00:00";
    const zone = FixedDateTimeZone.GetFixedZoneOrNull(id)!;
    assertNodaEqual(DateTimeZone.ForOffset(Offset.FromHours(5)), zone);
    expect(zone.Id).toBe("UTC+05");
  },

  For_Id_InvalidFixedOffset() {
    expect(FixedDateTimeZone.GetFixedZoneOrNull("UTC+5Months")).toBeNull();
  },

  ExplicitNameAppearsInZoneInterval() {
    const zone = new FixedDateTimeZone("id", Offset.FromHours(5), "name");
    const interval = zone.GetZoneInterval(NodaConstants.UnixEpoch);
    expect(zone.Id).toBe("id"); // Check we don't get this wrong...
    expect(interval.Name).toBe("name");
    expect(zone.Name).toBe("name");
  },

  Read_NoNameInStream() {
    const ioHelper = DtzIoHelper.createNoStringPool();
    const offset = Offset.FromHours(5);
    ioHelper.writer.WriteOffset(offset);
    const zone = FixedDateTimeZone.Read(ioHelper.reader, "id") as FixedDateTimeZone;

    expect(zone.Id).toBe("id");
    assertNodaEqual(zone.Offset, offset);
    expect(zone.Name).toBe("id");
  },

  Read_WithNameInStream() {
    const ioHelper = DtzIoHelper.createNoStringPool();
    const offset = Offset.FromHours(5);
    ioHelper.writer.WriteOffset(offset);
    ioHelper.writer.WriteString("name");
    const zone = FixedDateTimeZone.Read(ioHelper.reader, "id") as FixedDateTimeZone;

    expect(zone.Id).toBe("id");
    assertNodaEqual(zone.Offset, offset);
    expect(zone.Name).toBe("name");
  },

  Roundtrip() {
    const ioHelper = DtzIoHelper.createNoStringPool();
    const oldZone = new FixedDateTimeZone("id", Offset.FromHours(4), "name");
    oldZone.Write(ioHelper.writer);
    const newZone = FixedDateTimeZone.Read(ioHelper.reader, "id") as FixedDateTimeZone;

    expect(newZone.Id).toBe(oldZone.Id);
    assertNodaEqual(newZone.Offset, oldZone.Offset);
    expect(newZone.Name).toBe(oldZone.Name);
  },

  ZoneIntervalNameDefaultsToZoneId() {
    const zone = new FixedDateTimeZone("id", Offset.FromHours(5));
    const interval = zone.GetZoneInterval(NodaConstants.UnixEpoch);
    expect(interval.Name).toBe("id");
    expect(zone.Name).toBe("id");
  },

  Equals() {
    TestHelper.testEqualsClass(new FixedDateTimeZone(Offset.FromSeconds(300)),
      new FixedDateTimeZone(Offset.FromSeconds(300)),
      new FixedDateTimeZone(Offset.FromSeconds(500)));

    TestHelper.testEqualsClass(new FixedDateTimeZone("Foo", Offset.FromSeconds(300)),
      new FixedDateTimeZone("Foo", Offset.FromSeconds(300)),
      new FixedDateTimeZone("Bar", Offset.FromSeconds(300)));
  },
});
