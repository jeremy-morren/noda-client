// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeZones/IO/DateTimeZoneReaderTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { DateTimeZoneReader, InvalidNodaDataException, MemoryStream, NodaConstants } from "../../../../src/noda-js/internal.ts";
import { assertThrows } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/TimeZones/IO/DateTimeZoneReaderTest.generated.ts";

function newReader(stream: MemoryStream): DateTimeZoneReader {
  return DateTimeZoneReader.NewInputStringPool(stream, null);
}

// Tests for DateTimeZoneReader behaviour that isn't already covered by ReadWriteTest.
port(fixture, {
  HasMoreData_Buffers() {
    const stream = new MemoryStream(new Uint8Array([1, 2]));
    const reader = newReader(stream);

    // HasMoreData reads a byte and buffers it
    expect(stream.Position).toBe(0);
    expect(reader.HasMoreData).toBe(true);
    expect(stream.Position).toBe(1);
    expect(reader.HasMoreData).toBe(true);
    expect(stream.Position).toBe(1);

    // Consume the buffered byte
    expect(reader.ReadByte()).toBe(1);
    expect(stream.Position).toBe(1);

    // HasMoreData reads the next byte
    expect(reader.HasMoreData).toBe(true);
    expect(stream.Position).toBe(2);
    expect(reader.HasMoreData).toBe(true);
    expect(stream.Position).toBe(2);

    // Consume the buffered byte
    expect(reader.ReadByte()).toBe(2);
    expect(stream.Position).toBe(2);

    // No more data
    expect(reader.HasMoreData).toBe(false);
  },

  ReadCount_OutOfRange() {
    // Int32.MaxValue + 1 (as a uint) is 10000000_00000000_00000000_00000000
    // So only bit 31 is set.
    // Divided into 7 bit chunks (reverse order), with top bit set for continuation, this is:
    // 10000000 - bits 0-6
    // 10000000 - bits 7-13
    // 10000000 - bits 14-20
    // 10000000 - bits 21-27
    // 00001000 - bits 28-34
    const data = new Uint8Array([0x80, 0x80, 0x80, 0x80, 0b0000_1000]);
    const stream = new MemoryStream(data);
    const reader = newReader(stream);
    assertThrows(InvalidNodaDataException, () => reader.ReadCount());
  },

  ReadMilliseconds_InvalidFlag() {
    // Top 3 bits are the flag. Valid flag values are 0b100 (minutes), 0b101 (seconds)  and 0b110 (milliseconds)
    const data = new Uint8Array([0xe0, 0, 0, 0, 0, 0]); // Invalid flag (followed by 0s to check that it's not just out of data)
    const stream = new MemoryStream(data);
    const reader = newReader(stream);
    assertThrows(InvalidNodaDataException, () => reader.ReadMilliseconds());
  },

  ReadZoneIntervalTransition_InvalidMarkerValue() {
    const data = new Uint8Array([4, 0, 0, 0, 0, 0]); // Marker value of 4 (followed by 0s to check that it's not just out of data)
    const stream = new MemoryStream(data);
    const reader = newReader(stream);
    assertThrows(InvalidNodaDataException, () => reader.ReadZoneIntervalTransition(NodaConstants.UnixEpoch));
  },

  ReadZoneIntervalTransition_NoPreviousValue() {
    // Count value between 1 << 7 and 1 << 21 (followed by 0s to check that it's not just out of data)
    const data = new Uint8Array([0xff, 0x7f, 0, 0, 0, 0]);
    let stream = new MemoryStream(data);
    let reader = newReader(stream);
    assertThrows(InvalidNodaDataException, () => reader.ReadZoneIntervalTransition(null));

    // Validate that when we *do* provide a previous value, it doesn't throw
    // (C#: stream.Position = 0; the shim isn't seekable, so start a new stream over the same data.)
    stream = new MemoryStream(data);
    reader = newReader(stream);
    reader.ReadZoneIntervalTransition(NodaConstants.UnixEpoch);
  },

  ReadString_NotEnoughData() {
    // We say there are 5 bytes, but there are only 4 left...
    const data = new Uint8Array([0x05, 0x40, 0x40, 0x40, 0x40]);
    const stream = new MemoryStream(data);
    const reader = newReader(stream);
    assertThrows(InvalidNodaDataException, () => reader.ReadString());
  },

  ReadByte_NotEnoughData() {
    const data = new Uint8Array([0x05]);
    const stream = new MemoryStream(data);
    const reader = newReader(stream);
    // Just check we can read the first byte, then fail on the second
    expect(reader.ReadByte()).toBe(5);
    assertThrows(InvalidNodaDataException, () => reader.ReadByte());
  },
});
