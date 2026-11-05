// Ported from NodaTime 3.3.0: src/NodaTime/TimeZones/IO/TzdbStreamField.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { DateTimeZoneReader, InvalidNodaDataError, MemoryStream } from "../../internal.ts";
import type { TzdbStreamFieldId } from "../../internal.ts";

/**
 * An unparsed field within a stream.
 * @internal
 */
export class TzdbStreamField {
  private readonly _data: Uint8Array;
  readonly Id: TzdbStreamFieldId;

  static NewIdData(id: TzdbStreamFieldId, data: Uint8Array): TzdbStreamField {
    return new TzdbStreamField(id, data);
  }

  private constructor(id: TzdbStreamFieldId, data: Uint8Array) {
    this.Id = id;
    this._data = data;
  }

  /**
   * Creates a new read-only stream over the data for this field.
   */
  CreateStream(): MemoryStream {
    return new MemoryStream(this._data);
  }

  ExtractSingleValue<T>(readerFunction: (reader: DateTimeZoneReader) => T, stringPool: readonly string[] | null): T {
    const stream = this.CreateStream();
    return readerFunction(DateTimeZoneReader.NewInputStringPool(stream, stringPool));
  }

  static *ReadFields(input: MemoryStream): Iterable<TzdbStreamField> {
    while (true) {
      const fieldId = input.ReadByte();
      if (fieldId === -1) {
        return;
      }
      const id = (fieldId & 0xff) as TzdbStreamFieldId;
      // Read 7-bit-encoded length
      const length = DateTimeZoneReader.NewInputStringPool(input, null).ReadCount();
      const data = new Uint8Array(length);
      let offset = 0;
      while (offset < data.length) {
        const bytesRead = input.Read(data, offset, data.length - offset);
        if (bytesRead === 0) {
          throw new InvalidNodaDataError(`Stream ended after reading ${offset} bytes out of ${data.length}`);
        }
        offset += bytesRead;
      }
      yield new TzdbStreamField(id, data);
    }
  }
}
