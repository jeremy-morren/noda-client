// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/IO/DateTimeZoneWriter.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Instant, Int32, Int64, NodaConstants, Preconditions } from "../../internal.ts";
import type { IDateTimeZoneWriter, Int64Value, Offset, Stream } from "../../internal.ts";
import { EncodeUtf8 } from "../../Utility/Encoding.ts";
import { DateTimeZoneWriterDateTimeZoneType } from "./DateTimeZoneWriter.DateTimeZoneType.generated.ts";
import { DateTimeZoneWriterZoneIntervalConstants } from "./DateTimeZoneWriter.ZoneIntervalConstants.ts";

/**
 * Implementation of {@link IDateTimeZoneWriter} for the most recent version
 * of the "blob" format of time zone data. If the format changes, this class will be
 * renamed (e.g. to DateTimeZoneWriterV0) and the new implementation will replace it.
 * @internal
 */
export class DateTimeZoneWriter implements IDateTimeZoneWriter {
  static readonly DateTimeZoneType = DateTimeZoneWriterDateTimeZoneType;

  static readonly ZoneIntervalConstants = DateTimeZoneWriterZoneIntervalConstants;

  private readonly _output: Stream;
  private readonly _stringPool: string[] | null;

  /**
   * Constructs a DateTimeZoneWriter.
   * @param output Where to send the serialized output.
   * @param stringPool String pool to add strings to, or null for no pool
   */
  static NewOutputStringPool(output: Stream, stringPool: string[] | null): DateTimeZoneWriter {
    return new DateTimeZoneWriter(output, stringPool);
  }

  private constructor(output: Stream, stringPool: string[] | null) {
    this._output = output;
    this._stringPool = stringPool;
  }

  /**
   * Writes the given non-negative integer value to the stream.
   * @param value The value to write.
   */
  WriteCount(value: number): void {
    Preconditions.CheckArgumentRange("value", value, 0, Int32.MaxValue);
    this.WriteVarint(value >>> 0);
  }

  /**
   * Writes the given (possibly-negative) integer value to the stream.
   *
   * Unlike {@link WriteCount}, this can encode negative numbers. It does, however, use a slightly less
   * efficient encoding for positive numbers.
   * @param count The value to write.
   */
  WriteSignedCount(count: number): void {
    // unchecked
    this.WriteVarint(((count >> 31) ^ (count << 1)) >>> 0); // zigzag encoding
  }

  /**
   * Writes the given integer value to the stream as a base-128 varint.
   *
   * The format is a simple 7-bit encoding: while the value is greater than 127 (i.e.
   * has more than 7 significant bits) we repeatedly write the least-significant 7 bits
   * with the top bit of the byte set as a continuation bit, then shift the value right
   * 7 bits.
   * @param value The value to write (as a C# uint).
   */
  private WriteVarint(value: number): void {
    // unchecked uint arithmetic
    while (value > 0x7f) {
      this._output.WriteByte(0x80 | (value & 0x7f));
      value = value >>> 7;
    }
    this._output.WriteByte(value & 0x7f);
  }

  /** @inheritDoc */
  WriteMilliseconds(millis: number): void {
    Preconditions.CheckArgumentRange("millis", millis,
      -NodaConstants.MillisecondsPerDay + 1,
      NodaConstants.MillisecondsPerDay - 1);
    millis += NodaConstants.MillisecondsPerDay;
    /*
     * First, add 24 hours to the number of milliseconds, to get a value in the range (0, 172800000).
     * (It's exclusive at both ends, but that's insignificant.)
     * Check whether it's an exact multiple of half-hours or minutes, and encode
     * appropriately. In every case, if it's an exact multiple, we know that we'll be able to fit
     * the value into the number of bits available.
     *
     * first byte      units       max data value (+1)   field length
     * --------------------------------------------------------------
     * 0xxxxxxx        30 minutes  96                    1 byte  (7 data bits)
     * 100xxxxx        minutes     2880                  2 bytes (14 data bits)
     * 101xxxxx        seconds     172800                3 bytes (21 data bits)
     * 110xxxxx        millis      172800000             4 bytes (29 data bits)
     */
    // unchecked
    if (millis % (30 * NodaConstants.MillisecondsPerMinute) === 0) {
      const units = Int32.Div(millis, 30 * NodaConstants.MillisecondsPerMinute);
      this.WriteByte(units & 0xff);
    } else if (millis % NodaConstants.MillisecondsPerMinute === 0) {
      const minutes = Int32.Div(millis, NodaConstants.MillisecondsPerMinute);
      this.WriteByte((0x80 | (minutes >> 8)) & 0xff);
      this.WriteByte(minutes & 0xff);
    } else if (millis % NodaConstants.MillisecondsPerSecond === 0) {
      const seconds = Int32.Div(millis, NodaConstants.MillisecondsPerSecond);
      this.WriteByte((0xa0 | ((seconds >> 16) & 0xff)) & 0xff);
      this.WriteInt16(seconds & 0xffff);
    } else {
      this.WriteInt32(0xc0000000 | millis);
    }
  }

  /**
   * Writes the offset value to the stream.
   * @param offset The value to write.
   */
  WriteOffset(offset: Offset): void {
    this.WriteMilliseconds(offset.Milliseconds);
  }

  /**
   * Writes the given dictionary of string to string to the stream.
   * @param dictionary The `IDictionary<TKey,TValue>` to write.
   */
  WriteDictionary(dictionary: ReadonlyMap<string, string>): void {
    Preconditions.CheckNotNull(dictionary, "dictionary");
    this.WriteCount(dictionary.size);
    dictionary.forEach((value, key) => {
      this.WriteString(key);
      this.WriteString(value);
    });
  }

  /** @inheritDoc */
  WriteZoneIntervalTransition(previous: Instant | null, value: Instant): void {
    if (previous !== null) {
      Preconditions.CheckArgument(value.CompareTo(previous) >= 0, "value", "Transition must move forward in time");
    }

    // unchecked
    if (value.Equals(Instant.BeforeMinValue)) {
      this.WriteCount(DateTimeZoneWriterZoneIntervalConstants.MarkerMinValue);
      return;
    }
    if (value.Equals(Instant.AfterMaxValue)) {
      this.WriteCount(DateTimeZoneWriterZoneIntervalConstants.MarkerMaxValue);
      return;
    }

    // In practice, most zone interval transitions will occur within 4000-6000 hours of the previous one
    // (i.e. about 5-8 months), and at an integral number of hours difference. We therefore gain a
    // significant reduction in output size by encoding transitions as the whole number of hours since the
    // previous, if possible.
    // If the previous value was "the start of time" then there's no point in trying to use it.
    if (previous !== null && !previous.Equals(Instant.BeforeMinValue)) {
      // Note that the difference might exceed the range of a long, so we can't use a Duration here.
      // (noda-js: the difference is non-negative, and within the range of a long for any two valid instants.)
      const ticks: Int64Value = Int64.Subtract(value.ToUnixTimeTicksExact(), previous.ToUnixTimeTicksExact());
      if (Int64.Equals(Int64.Remainder(ticks, NodaConstants.TicksPerHour), 0)) {
        const hours = Int64.ToNumber(Int64.Divide(ticks, NodaConstants.TicksPerHour));
        // As noted above, this will generally fall within the 4000-6000 range, although values up to
        // ~700,000 exist in TZDB.
        if (DateTimeZoneWriterZoneIntervalConstants.MinValueForHoursSincePrevious <= hours &&
          hours < DateTimeZoneWriterZoneIntervalConstants.MinValueForMinutesSinceEpoch) {
          this.WriteCount(hours);
          return;
        }
      }
    }

    // We can't write the transition out relative to the previous transition, so let's next try writing it
    // out as a whole number of minutes since an (arbitrary, known) epoch.
    if (value.CompareTo(DateTimeZoneWriterZoneIntervalConstants.EpochForMinutesSinceEpoch) >= 0) {
      const ticks: Int64Value = Int64.Subtract(value.ToUnixTimeTicksExact(),
        DateTimeZoneWriterZoneIntervalConstants.EpochForMinutesSinceEpoch.ToUnixTimeTicksExact());
      if (Int64.Equals(Int64.Remainder(ticks, NodaConstants.TicksPerMinute), 0)) {
        const minutes = Int64.ToNumber(Int64.Divide(ticks, NodaConstants.TicksPerMinute));
        // We typically have a count on the order of 80M here.
        if (DateTimeZoneWriterZoneIntervalConstants.MinValueForMinutesSinceEpoch < minutes && minutes <= Int32.MaxValue) {
          this.WriteCount(minutes);
          return;
        }
      }
    }
    // Otherwise, just write out a marker followed by the instant as a 64-bit number of ticks.  Note that
    // while most of the values we write here are actually whole numbers of _seconds_, optimising for that
    // case will save around 2KB (with tzdb 2012j), so doesn't seem worthwhile.
    this.WriteCount(DateTimeZoneWriterZoneIntervalConstants.MarkerRaw);
    this.WriteInt64(value.ToUnixTimeTicksExact());
  }

  /**
   * Writes the string value to the stream.
   * @param value The value to write.
   */
  WriteString(value: string): void {
    if (this._stringPool === null) {
      const data = EncodeUtf8(value);
      const length = data.length;
      this.WriteCount(length);
      this._output.Write(data, 0, data.length);
    } else {
      let index = this._stringPool.indexOf(value);
      if (index === -1) {
        index = this._stringPool.length;
        this._stringPool.push(value);
      }
      this.WriteCount(index);
    }
  }

  /**
   * Writes the given 16 bit integer value to the stream.
   * @param value The value to write.
   */
  private WriteInt16(value: number): void {
    // unchecked
    this.WriteByte((value >> 8) & 0xff);
    this.WriteByte(value & 0xff);
  }

  /**
   * Writes the given 32 bit integer value to the stream.
   * @param value The value to write.
   */
  private WriteInt32(value: number): void {
    // unchecked
    this.WriteInt16(value >> 16);
    this.WriteInt16(value);
  }

  /**
   * Writes the given 64 bit integer value to the stream.
   * (noda-js: the value is an exact C# long, as it can exceed 2^53.)
   * @param value The value to write.
   */
  private WriteInt64(value: Int64Value): void {
    // unchecked
    const long = Int64.ToLong(value);
    this.WriteInt32(long.high);
    this.WriteInt32(long.low);
  }

  /** @inheritDoc */
  WriteByte(value: number): void {
    // unchecked
    this._output.WriteByte(value);
  }
}
