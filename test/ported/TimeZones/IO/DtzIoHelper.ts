// Test support for the NZD reader tests (NodaTime 3.3.0: src/NodaTime.Test/TimeZones/IO/DtzIoHelper.cs, IoStream.cs).
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: DateTimeZoneWriter isn't ported, so the DtzIoHelper round trips (write, then read back) can't be.
// Tests that write a few primitive values only to feed hand-made (often invalid) data to the reader use these
// functions instead: each returns the bytes the corresponding DateTimeZoneWriter method writes (a base-128 varint
// for counts, zigzag-encoded for signed counts; a count then the UTF-8 bytes for strings without a string pool).

import { DateTimeZoneReader, MemoryStream } from "../../../../src/noda-js/internal.ts";

/** The bytes of DateTimeZoneWriter.WriteVarint (via WriteCount) for a non-negative int. */
export function countBytes(value: number): number[] {
  const bytes: number[] = [];
  let unsigned = value >>> 0;
  while (unsigned >= 0x80) {
    bytes.push((unsigned & 0x7f) | 0x80);
    unsigned >>>= 7;
  }
  bytes.push(unsigned);
  return bytes;
}

/** The bytes of DateTimeZoneWriter.WriteSignedCount (zigzag encoding, then a varint). */
export function signedCountBytes(value: number): number[] {
  return countBytes(((value << 1) ^ (value >> 31)) >>> 0);
}

/** The bytes of DateTimeZoneWriter.WriteString with no string pool. */
export function stringBytes(value: string): number[] {
  const utf8 = new TextEncoder().encode(value);
  return [...countBytes(utf8.length), ...utf8];
}

/** C# `new DateTimeZoneReader(new MemoryStream(bytes), stringPool)`. */
export function readerFor(bytes: readonly number[] | Uint8Array, stringPool: readonly string[] | null = null): DateTimeZoneReader {
  return DateTimeZoneReader.NewInputStringPool(new MemoryStream(Uint8Array.from(bytes)), stringPool);
}
