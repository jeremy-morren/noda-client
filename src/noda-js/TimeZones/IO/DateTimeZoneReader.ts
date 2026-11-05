// Ported from NodaTime 3.3.0: src/NodaTime/TimeZones/IO/DateTimeZoneReader.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { ArgumentError, Duration, Instant, InvalidNodaDataError, Long, NodaConstants, Offset, PadStart } from "../../internal.ts";
import type { IDateTimeZoneReader } from "../../internal.ts";
import { DecodeUtf8 } from "../../Utility/Encoding.ts";

/**
 * noda-js: minimal equivalent of a read-only System.IO.MemoryStream over a byte array, so that the
 * stream-based reading code can stay close to the C#.
 * @internal
 */
export class MemoryStream {
  private readonly _data: Uint8Array;
  private _position = 0;

  constructor(data: Uint8Array) {
    this._data = data;
  }

  /** Reads a byte from the stream, or returns -1 at the end of the stream. */
  ReadByte(): number {
    return this._position < this._data.length ? this._data[this._position++]! : -1;
  }

  /**
   * Reads up to `count` bytes into `buffer` at `offset`, returning the number of bytes read
   * (0 at the end of the stream).
   */
  Read(buffer: Uint8Array, offset: number, count: number): number {
    const n = Math.min(count, this._data.length - this._position);
    if (n <= 0) {
      return 0;
    }
    buffer.set(this._data.subarray(this._position, this._position + n), offset);
    this._position += n;
    return n;
  }
}

// noda-js: DateTimeZoneWriter isn't ported, but the reader needs the constants from its nested
// ZoneIntervalConstants class (NodaTime 3.3.0: src/NodaTime/TimeZones/IO/DateTimeZoneWriter.cs).
let epochForMinutesSinceEpoch: Instant | undefined;
const ZoneIntervalConstants = {
  /** The instant to use as an 'epoch' when writing out a number of minutes-since-epoch. */
  get EpochForMinutesSinceEpoch(): Instant {
    return (epochForMinutesSinceEpoch ??= Instant.FromUtc(1800, 1, 1, 0, 0));
  },
  /** The marker value representing the beginning of time. */
  MarkerMinValue: 0,
  /** The marker value representing the end of time. */
  MarkerMaxValue: 1,
  /** The marker value representing an instant as a fixed 64-bit number of ticks. */
  MarkerRaw: 2,
  /**
   * The minimum varint value that represents an number of hours-since-previous.
   * Values below this are reserved for markers.
   */
  MinValueForHoursSincePrevious: 1 << 7,
  /**
   * The minimum varint value that represents an number of minutes since an epoch.
   * Values below this are interpreted as hours-since-previous (for a range of about 240 years),
   * rather than minutes-since-epoch (for a range of about 4000 years)
   * This choice is somewhat arbitrary, though it results in hour values always taking 2 (or
   * occasionally 3) bytes when encoded as a varint, while minute values take 4 (or conceivably 5).
   */
  MinValueForMinutesSinceEpoch: 1 << 21,
} as const;


/**
 * Implementation of {@link IDateTimeZoneReader} for the most recent version
 * of the "blob" format of time zone data. If the format changes, this class will be
 * renamed (e.g. to DateTimeZoneReaderV0) and the new implementation will replace it.
 * @internal
 */
export class DateTimeZoneReader implements IDateTimeZoneReader {
  /**
   * Raw stream to read from. Be careful before reading from this - you need to take
   * account of bufferedByte as well.
   */
  private readonly _input: MemoryStream;

  /**
   * String pool to use, or null if no string pool is in use.
   */
  private readonly _stringPool: readonly string[] | null;

  /**
   * Sometimes we need to buffer a byte in memory, e.g. to check if there is any
   * more data. Anything reading directly from the stream should check here first.
   */
  private _bufferedByte: number | null = null;

  static NewInputStringPool(input: MemoryStream, stringPool: readonly string[] | null): DateTimeZoneReader {
    return new DateTimeZoneReader(input, stringPool);
  }

  private constructor(input: MemoryStream, stringPool: readonly string[] | null) {
    this._input = input;
    this._stringPool = stringPool;
  }

  /** @inheritDoc */
  get HasMoreData(): boolean {
    if (this._bufferedByte !== null) {
      return true;
    }
    const nextByte = this._input.ReadByte();
    if (nextByte === -1) {
      return false;
    }
    // Okay, we got a byte - remember it for the next call to ReadByte.
    this._bufferedByte = nextByte;
    return true;
  }

  /**
   * Reads a non-negative integer value from the stream.
   *
   * The value must have been written by `DateTimeZoneWriter.WriteCount`.
   * @returns The integer value from the stream.
   */
  ReadCount(): number {
    const unsigned = this.ReadVarint();
    if (unsigned > 2147483647) {
      throw new InvalidNodaDataError("Count value greater than Int32.MaxValue");
    }
    return unsigned;
  }

  /**
   * Reads a (possibly-negative) integer value from the stream.
   *
   * The value must have been written by `DateTimeZoneWriter.WriteSignedCount`.
   * @returns The integer value from the stream.
   */
  ReadSignedCount(): number {
    const value = this.ReadVarint();
    return (value >>> 1) ^ -(value & 1); // zigzag encoding
  }

  /**
   * Reads a base-128 varint value from the stream.
   *
   * The value must have been written by DateTimeZoneWriter.WriteVarint, which
   * documents the format.
   * @returns The integer value from the stream (as a C# uint).
   */
  private ReadVarint(): number {
    // unchecked uint arithmetic
    let ret = 0;
    let shift = 0;
    while (true) {
      const nextByte = this.ReadByte();
      ret = (ret + (((nextByte & 0x7f) << shift) >>> 0)) >>> 0;
      shift += 7;
      if (nextByte < 0x80) {
        return ret;
      }
    }
  }

  /**
   * Reads a number of milliseconds from the stream.
   *
   * The value must have been written by `DateTimeZoneWriter.WriteMilliseconds`.
   * @returns The offset value from the stream.
   */
  ReadMilliseconds(): number {
    const firstByte = this.ReadByte();

    let millis: number;

    if ((firstByte & 0x80) === 0) {
      millis = firstByte * (30 * NodaConstants.MillisecondsPerMinute);
    } else {
      const flag = firstByte & 0xe0; // The flag parts of the first byte
      const firstData = firstByte & 0x1f; // The data parts of the first byte
      switch (flag) {
        case 0x80: {
          // Minutes
          const minutes = (firstData << 8) + this.ReadByte();
          millis = minutes * NodaConstants.MillisecondsPerMinute;
          break;
        }
        case 0xa0: {
          // Seconds
          const seconds = (firstData << 16) + (this.ReadInt16() & 0xffff);
          millis = seconds * NodaConstants.MillisecondsPerSecond;
          break;
        }
        case 0xc0: // Milliseconds
          millis = (firstData << 24) + (this.ReadByte() << 16) + (this.ReadInt16() & 0xffff);
          break;
        default:
          throw new InvalidNodaDataError(`Invalid flag in offset: ${PadStart(flag.toString(16), 2, "0")}`);
      }
    }
    millis -= NodaConstants.MillisecondsPerDay;
    return millis;
  }

  /**
   * Reads an offset value from the stream.
   *
   * The value must have been written by `DateTimeZoneWriter.WriteOffset`.
   * @returns The offset value from the stream.
   */
  ReadOffset(): Offset {
    const millis = this.ReadMilliseconds();
    return Offset.FromMilliseconds(millis);
  }

  /**
   * Reads a string to string dictionary value from the stream.
   *
   * The value must have been written by `DateTimeZoneWriter.WriteDictionary`.
   * @returns The dictionary value from the stream.
   */
  ReadDictionary(): Map<string, string> {
    const results = new Map<string, string>();
    const count = this.ReadCount();
    for (let i = 0; i < count; i++) {
      const key = this.ReadString();
      const value = this.ReadString();
      // Dictionary.Add throws on duplicate keys.
      if (results.has(key)) {
        throw new ArgumentError(`An item with the same key has already been added. Key: ${key}`);
      }
      results.set(key, value);
    }
    return results;
  }

  /**
   * Reads an instant representing a zone interval transition from the stream.
   *
   * The value must have been written by `DateTimeZoneWriter.WriteZoneIntervalTransition`.
   * @param previous The previous transition written (usually for a given timezone), or null if there is
   * no previous transition.
   * @returns The instant read from the stream
   */
  ReadZoneIntervalTransition(previous: Instant | null): Instant {
    const value = this.ReadCount();
    if (value < ZoneIntervalConstants.MinValueForHoursSincePrevious) {
      switch (value) {
        case ZoneIntervalConstants.MarkerMinValue:
          return Instant.BeforeMinValue;
        case ZoneIntervalConstants.MarkerMaxValue:
          return Instant.AfterMaxValue;
        case ZoneIntervalConstants.MarkerRaw:
          return Instant.FromUnixTimeTicks(this.ReadInt64());
        default:
          throw new InvalidNodaDataError(`Unrecognised marker value: ${value}`);
      }
    }
    if (value < ZoneIntervalConstants.MinValueForMinutesSinceEpoch) {
      if (previous === null) {
        throw new InvalidNodaDataError(`No previous value, so can't interpret value encoded as delta-since-previous: ${value}`);
      }
      return previous.Plus(Duration.FromHours(value));
    }
    return ZoneIntervalConstants.EpochForMinutesSinceEpoch.Plus(Duration.FromMinutes(value));
  }

  /**
   * Reads a string value from the stream.
   *
   * The value must have been written by `DateTimeZoneWriter.WriteString`.
   * @returns The string value from the stream.
   */
  ReadString(): string {
    if (this._stringPool === null) {
      // This will flush the buffered byte if there is one, so we don't need to worry about that
      // when reading the actual data.
      const length = this.ReadCount();
      const data = new Uint8Array(length);
      let offset = 0;
      while (offset < length) {
        const bytesRead = this._input.Read(data, offset, length - offset);
        if (bytesRead <= 0) {
          throw new InvalidNodaDataError(`Unexpectedly reached end of data with ${length - offset} bytes still to read`);
        }
        offset += bytesRead;
      }
      return DecodeUtf8(data);
    } else {
      const index = this.ReadCount();
      const result = this._stringPool[index];
      if (result === undefined) {
        // C# would throw ArgumentOutOfRangeException from the list indexer.
        throw new InvalidNodaDataError(`String pool index ${index} out of range`);
      }
      return result;
    }
  }

  /**
   * Reads a signed 16 bit integer value from the stream and returns it as an int.
   * @returns The 16 bit int value.
   */
  private ReadInt16(): number {
    const high = this.ReadByte();
    const low = this.ReadByte();
    return (high << 8) | low;
  }

  /**
   * Reads a signed 32 bit integer value from the stream and returns it as an int.
   * @returns The 32 bit int value.
   */
  private ReadInt32(): number {
    const high = this.ReadInt16() & 0xffff;
    const low = this.ReadInt16() & 0xffff;
    return (high << 16) | low;
  }

  /**
   * Reads a signed 64 bit integer value from the stream and returns it as an long.
   * (noda-js: as an exact Long, as the value can exceed 2^53.)
   * @returns The 64 bit long value.
   */
  private ReadInt64(): Long {
    const high = this.ReadInt32();
    const low = this.ReadInt32();
    return Long.fromBits(low, high);
  }

  /**
   * Reads a signed 8 bit integer value from the stream and returns it as an int.
   * @returns The 8 bit int value.
   * @throws {InvalidNodaDataError} The data in the stream has been exhausted.
   */
  ReadByte(): number {
    if (this._bufferedByte !== null) {
      const ret = this._bufferedByte;
      this._bufferedByte = null;
      return ret;
    }
    const value = this._input.ReadByte();
    if (value === -1) {
      throw new InvalidNodaDataError("Unexpected end of data stream");
    }
    return value;
  }
}
