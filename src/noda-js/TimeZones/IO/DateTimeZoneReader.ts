// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/IO/DateTimeZoneReader.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { DateTimeZoneWriterZoneIntervalConstants, Duration, Instant, InvalidNodaDataException, Long, NodaConstants, Offset, PadStart } from "../../internal.ts";
import type { IDateTimeZoneReader, Stream } from "../../internal.ts";
import { DecodeUtf8 } from "../../Utility/Encoding.ts";
import { NewArgumentException, type ArgumentOutOfRangeException } from "../../internal.ts";

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
  private readonly _input: Stream;

  /**
   * String pool to use, or null if no string pool is in use.
   */
  private readonly _stringPool: readonly string[] | null;

  /**
   * Sometimes we need to buffer a byte in memory, e.g. to check if there is any
   * more data. Anything reading directly from the stream should check here first.
   */
  private _bufferedByte: number | null = null;

  static NewInputStringPool(input: Stream, stringPool: readonly string[] | null): DateTimeZoneReader {
    return new DateTimeZoneReader(input, stringPool);
  }

  private constructor(input: Stream, stringPool: readonly string[] | null) {
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
      throw new InvalidNodaDataException("Count value greater than Int32.MaxValue");
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
          throw new InvalidNodaDataException(`Invalid flag in offset: ${PadStart(flag.toString(16), 2, "0")}`);
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
        throw NewArgumentException(`An item with the same key has already been added. Key: ${key}`);
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
    if (value < DateTimeZoneWriterZoneIntervalConstants.MinValueForHoursSincePrevious) {
      switch (value) {
        case DateTimeZoneWriterZoneIntervalConstants.MarkerMinValue:
          return Instant.BeforeMinValue;
        case DateTimeZoneWriterZoneIntervalConstants.MarkerMaxValue:
          return Instant.AfterMaxValue;
        case DateTimeZoneWriterZoneIntervalConstants.MarkerRaw:
          return Instant.FromUnixTimeTicks(this.ReadInt64());
        default:
          throw new InvalidNodaDataException(`Unrecognised marker value: ${value}`);
      }
    }
    if (value < DateTimeZoneWriterZoneIntervalConstants.MinValueForMinutesSinceEpoch) {
      if (previous === null) {
        throw new InvalidNodaDataException(`No previous value, so can't interpret value encoded as delta-since-previous: ${value}`);
      }
      return previous.Plus(Duration.FromHours(value));
    }
    return DateTimeZoneWriterZoneIntervalConstants.EpochForMinutesSinceEpoch.Plus(Duration.FromMinutes(value));
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
          throw new InvalidNodaDataException(`Unexpectedly reached end of data with ${length - offset} bytes still to read`);
        }
        offset += bytesRead;
      }
      return DecodeUtf8(data);
    } else {
      const index = this.ReadCount();
      const result = this._stringPool[index];
      if (result === undefined) {
        // C# would throw ArgumentOutOfRangeException from the list indexer.
        throw new InvalidNodaDataException(`String pool index ${index} out of range`);
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
   * @throws {InvalidNodaDataException} The data in the stream has been exhausted.
   */
  ReadByte(): number {
    if (this._bufferedByte !== null) {
      const ret = this._bufferedByte;
      this._bufferedByte = null;
      return ret;
    }
    const value = this._input.ReadByte();
    if (value === -1) {
      throw new InvalidNodaDataException("Unexpected end of data stream");
    }
    return value;
  }
}
