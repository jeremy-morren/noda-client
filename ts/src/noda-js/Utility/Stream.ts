// noda-js: new code. Minimal System.IO.Stream and MemoryStream, for the NZD reading and writing code.

import { NewArgumentOutOfRangeException, NewNotSupportedException } from "../internal.ts";

/** System.IO.Stream (the members NodaTime's NZD code uses). @internal */
export abstract class Stream {
  /**
   * Reads up to `count` bytes into `buffer` at `offset`, returning the number of bytes read
   * (0 at the end of the stream).
   */
  abstract Read(buffer: Uint8Array, offset: number, count: number): number;

  /** Writes `count` bytes from `buffer`, starting at `offset`, to the stream. */
  abstract Write(buffer: Uint8Array, offset: number, count: number): void;

  /** Reads a byte from the stream, or returns -1 at the end of the stream. */
  ReadByte(): number {
    const oneByteArray = new Uint8Array(1);
    return this.Read(oneByteArray, 0, 1) === 0 ? -1 : oneByteArray[0]!;
  }

  /** Writes a byte (the low 8 bits of `value`) to the stream. */
  WriteByte(value: number): void {
    this.Write(new Uint8Array([value & 0xff]), 0, 1);
  }
}

/** System.IO.MemoryStream: growable when empty, fixed-size over a given buffer. @internal */
export class MemoryStream extends Stream {
  private _data: Uint8Array;
  private _length: number;
  private _position = 0;
  private readonly _expandable: boolean;

  constructor(buffer?: Uint8Array) {
    super();
    if (buffer === undefined) {
      this._data = new Uint8Array(256);
      this._length = 0;
      this._expandable = true;
    } else {
      this._data = buffer;
      this._length = buffer.length;
      this._expandable = false;
    }
  }

  /** The length of the stream in bytes. */
  get Length(): number {
    return this._length;
  }

  /** The current position within the stream. */
  get Position(): number {
    return this._position;
  }

  set Position(value: number) {
    if (value < 0) {
      throw NewArgumentOutOfRangeException("value", value, "Non-negative number required.");
    }
    this._position = value;
  }

  /** Reads a byte from the stream, or returns -1 at the end of the stream. */
  override ReadByte(): number {
    return this._position < this._length ? this._data[this._position++]! : -1;
  }

  /**
   * Reads up to `count` bytes into `buffer` at `offset`, returning the number of bytes read
   * (0 at the end of the stream).
   */
  Read(buffer: Uint8Array, offset: number, count: number): number {
    const n = Math.min(count, this._length - this._position);
    if (n <= 0) {
      return 0;
    }
    buffer.set(this._data.subarray(this._position, this._position + n), offset);
    this._position += n;
    return n;
  }

  /** Writes a byte (the low 8 bits of `value`) to the stream at the current position. */
  override WriteByte(value: number): void {
    this.EnsureCapacity(this._position + 1);
    this._data[this._position++] = value;
    if (this._position > this._length) {
      this._length = this._position;
    }
  }

  /** Writes `count` bytes from `buffer`, starting at `offset`, to the stream at the current position. */
  Write(buffer: Uint8Array, offset: number, count: number): void {
    const end = this._position + count;
    this.EnsureCapacity(end);
    this._data.set(buffer.subarray(offset, offset + count), this._position);
    this._position = end;
    if (end > this._length) {
      this._length = end;
    }
  }

  /** Writes the entire contents of this stream (regardless of its position) to another stream. */
  WriteTo(stream: Stream): void {
    stream.Write(this._data, 0, this._length);
  }

  /** Returns a copy of the stream's contents (regardless of its position). */
  ToArray(): Uint8Array {
    return this._data.slice(0, this._length);
  }

  private EnsureCapacity(capacity: number): void {
    if (capacity <= this._data.length) {
      return;
    }
    if (!this._expandable) {
      throw NewNotSupportedException("Memory stream is not expandable.");
    }
    const newData = new Uint8Array(Math.max(capacity, this._data.length * 2));
    newData.set(this._data.subarray(0, this._length));
    this._data = newData;
  }
}
