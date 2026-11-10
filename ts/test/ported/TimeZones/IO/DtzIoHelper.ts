// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeZones/IO/DtzIoHelper.cs and IoStream.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: System.IO.Stream is the internal Stream shim (src/noda-js/Utility/Stream.ts); IOException is a plain Error.

import { expect } from "vitest";
import {
  DateTimeZoneReader,
  DateTimeZoneWriter,
  Stream,
  ZoneRecurrence,
  ZoneYearOffset,
} from "../../../../src/noda-js/internal.ts";
import type { IDateTimeZoneReader, IDateTimeZoneWriter, Instant, Offset } from "../../../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../../../helpers/assertions.ts";
import { NewInvalidOperationException, NewNotSupportedException } from "../../../../src/noda-js/internal.ts";

/**
 * Provides a simple, fixed-size, pipe-like stream that has a writer and a reader.
 *
 * When the buffer fills up an exception is thrown and currently the buffer is fixed at 4096. The write
 * pointer does not wrap so only a total of 4096 bytes can ever be written to the stream. This is designed
 * for testing purposes and not real-world uses.
 */
class IoStream {
  readonly buffer = new Uint8Array(4096);
  readIndex = 0;
  private readStream: Stream | null = null;
  writeIndex = 0;
  private writeStream: Stream | null = null;

  /** Returns the next byte from the stream if there is one. */
  getByte(): number {
    if (this.readIndex >= this.writeIndex) {
      throw new Error("IoStream buffer empty in GetByte()");
    }
    return this.buffer[this.readIndex++]!;
  }

  assertEndOfStream(): void {
    expect(this.readIndex).toBe(this.writeIndex);
  }

  assertUnreadContents(expected: number[]): void {
    expect(this.writeIndex - this.readIndex).toBe(expected.length);
    const actual = Array.from(this.buffer.subarray(this.readIndex, this.writeIndex));
    expect(actual).toEqual(expected);
    this.readIndex = this.writeIndex;
  }

  /**
   * Returns a {@link Stream} that can be used to read from the buffer.
   * This can only be called once for each instance i.e. only one reader is permitted per buffer.
   */
  getReadStream(): Stream {
    if (this.readStream !== null) {
      throw NewInvalidOperationException("Cannot call GetReadStream() twice on the same object.");
    }
    this.readStream = new ReadStreamImpl(this);
    return this.readStream;
  }

  /**
   * Returns a {@link Stream} that can be used to write to the buffer.
   * This can only be called once for each instance i.e. only one writer is permitted per buffer.
   */
  getWriteStream(): Stream {
    if (this.writeStream !== null) {
      throw NewInvalidOperationException("Cannot call GetWriteStream() twice on the same object.");
    }
    this.writeStream = new WriteStreamImpl(this);
    return this.writeStream;
  }

  /** Adds a byte to the buffer. */
  putByte(value: number): void {
    if (this.writeIndex >= this.buffer.length) {
      throw new Error(`Exceeded the IoStream buffer size of ${this.buffer.length}`);
    }
    this.buffer[this.writeIndex++] = value;
  }

  /** Resets the stream to be empty. */
  reset(): void {
    this.writeIndex = 0;
    this.readIndex = 0;
  }
}

/** Provides a read-only {@link Stream} implementation for reading from the buffer. */
class ReadStreamImpl extends Stream {
  private readonly ioStream: IoStream;

  constructor(ioStream: IoStream) {
    super();
    this.ioStream = ioStream;
  }

  Read(buffer: Uint8Array, offset: number, count: number): number {
    count = Math.min(count, this.ioStream.writeIndex - this.ioStream.readIndex);
    for (let i = 0; i < count; i++) {
      buffer[i + offset] = this.ioStream.getByte();
    }
    return count;
  }

  Write(): void {
    throw NewNotSupportedException();
  }
}

/** Provides a write-only {@link Stream} implementation for writing to the buffer. */
class WriteStreamImpl extends Stream {
  private readonly ioStream: IoStream;

  constructor(ioStream: IoStream) {
    super();
    this.ioStream = ioStream;
  }

  Read(): number {
    throw NewNotSupportedException();
  }

  Write(buffer: Uint8Array, offset: number, count: number): void {
    if (count > this.ioStream.buffer.length - this.ioStream.writeIndex) {
      throw NewInvalidOperationException("The I/O buffer is full");
    }
    for (let i = 0; i < count; i++) {
      this.ioStream.putByte(buffer[i + offset]!);
    }
  }
}

/**
 * Wrapper around a DateTimeZoneWriter/DateTimeZoneReader pair that reads whatever is
 * written to it.
 */
export class DtzIoHelper {
  private readonly ioStream: IoStream;
  private readonly stringPool: string[] | null;

  /** Gets the reader. */
  readonly reader: IDateTimeZoneReader;

  /** Gets the writer. */
  readonly writer: IDateTimeZoneWriter;

  private constructor(stringPool: string[] | null) {
    this.ioStream = new IoStream();
    this.reader = DateTimeZoneReader.NewInputStringPool(this.ioStream.getReadStream(), stringPool);
    this.writer = DateTimeZoneWriter.NewOutputStringPool(this.ioStream.getWriteStream(), stringPool);
    this.stringPool = stringPool;
  }

  static createNoStringPool(): DtzIoHelper {
    return new DtzIoHelper(null);
  }

  static createWithStringPool(): DtzIoHelper {
    return new DtzIoHelper([]);
  }

  reset(): void {
    this.ioStream.reset();
    if (this.stringPool !== null) {
      this.stringPool.length = 0;
    }
  }

  /** TestCount(int expected) and TestCount(int value, byte[] expected). */
  testCount(value: number, expected?: number[]): void {
    this.reset();
    this.writer.WriteCount(value);
    if (expected === undefined) {
      const actual = this.reader.ReadCount();
      expect(actual).toBe(value);
    } else {
      this.ioStream.assertUnreadContents(expected);
    }
    this.ioStream.assertEndOfStream();
  }

  /** TestSignedCount(int expected) and TestSignedCount(int value, byte[] expected). */
  testSignedCount(value: number, expected?: number[]): void {
    this.reset();
    this.writer.WriteSignedCount(value);
    if (expected === undefined) {
      const actual = this.reader.ReadSignedCount();
      expect(actual).toBe(value);
    } else {
      this.ioStream.assertUnreadContents(expected);
    }
    this.ioStream.assertEndOfStream();
  }

  testDictionary(expected: ReadonlyMap<string, string>): void {
    this.reset();
    this.writer.WriteDictionary(expected);
    const actual = this.reader.ReadDictionary();
    expect(actual).toEqual(expected);
    this.ioStream.assertEndOfStream();
  }

  testZoneIntervalTransition(previous: Instant | null, expected: Instant): void {
    this.reset();
    this.writer.WriteZoneIntervalTransition(previous, expected);
    const actual = this.reader.ReadZoneIntervalTransition(previous);
    assertNodaEqual(actual, expected);
    this.ioStream.assertEndOfStream();
  }

  testOffset(offset: Offset): void {
    this.reset();
    this.writer.WriteOffset(offset);
    const actual = this.reader.ReadOffset();
    assertNodaEqual(actual, offset);
    this.ioStream.assertEndOfStream();
  }

  testString(expected: string): void {
    this.reset();
    this.writer.WriteString(expected);
    const actual = this.reader.ReadString();
    expect(actual).toBe(expected);
    this.ioStream.assertEndOfStream();
  }

  testZoneRecurrence(expected: ZoneRecurrence): void {
    this.reset();
    expected.Write(this.writer);
    const actual = ZoneRecurrence.Read(this.reader);
    assertNodaEqual(actual, expected);
    this.ioStream.assertEndOfStream();
  }

  testZoneYearOffset(expected: ZoneYearOffset): void {
    this.reset();
    expected.Write(this.writer);
    const actual = ZoneYearOffset.Read(this.reader);
    assertNodaEqual(actual, expected);
    this.ioStream.assertEndOfStream();
  }
}
