// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler/Tzdb/TzdbStreamWriter.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CachedDateTimeZone,
  DateTimeZoneWriter,
  FixedDateTimeZone,
  MemoryStream,
  PrecalculatedDateTimeZone,
  TzdbStreamFieldId,
} from "../../internal.ts";
import type {
  DateTimeZone,
  IDateTimeZoneWriter,
  Instant,
  Offset,
  Stream,
  TzdbZone1970Location,
  TzdbZoneLocation,
  WindowsZones,
} from "../../internal.ts";
import { AddValue, GetValue } from "../internal.ts";
import type { TzdbDatabase } from "../internal.ts";
import { NewArgumentException } from "../../internal.ts";

const Version = 0;

/**
 * Writes time zone data to a stream in nzd format.
 *
 * The file format consists of four bytes indicating the file format version/type (mostly for
 * future expansion), followed by a number of fields. Each field is identified by a {@link TzdbStreamFieldId}.
 * The fields are always written in order, and the format of a field consists of its field ID, a 7-bit-encoded
 * integer with the size of the data, and then the data itself.
 *
 * The version number does not need to be increased if new fields are added, as the reader will simply ignore
 * unknown fields. It only needs to be increased for incompatible changes such as a different time zone format,
 * or if old fields are removed.
 * @internal
 */
export class TzdbStreamWriter {
  /**
   * noda-js: returns the NZD data instead of writing it to a Stream passed in.
   * @returns The bytes of the NZD file.
   */
  Write(
    database: TzdbDatabase,
    cldrWindowsZones: WindowsZones,
    additionalWindowsNameToIdMappings: ReadonlyMap<string, string>,
  ): Uint8Array {
    const stream = new MemoryStream();
    const fields = new TzdbStreamWriterFieldCollection();

    const zones = [...database.GenerateDateTimeZones()];
    const stringPool = TzdbStreamWriter.CreateOptimizedStringPool(zones, database.ZoneLocations, database.Zone1970Locations, cldrWindowsZones);

    // First assemble the fields (writing to the string pool as we go)
    for (const zone of zones) {
      const zoneField = fields.AddField(TzdbStreamFieldId.TimeZone, stringPool);
      TzdbStreamWriter.WriteZone(zone, zoneField.Writer);
    }

    fields.AddField(TzdbStreamFieldId.TzdbVersion, null).Writer.WriteString(database.Version);

    // Normalize the aliases
    const timeZoneMap = new Map<string, string>();
    for (const key of database.Aliases.keys()) {
      let value = database.Aliases.get(key)!;
      while (database.Aliases.has(value)) {
        value = database.Aliases.get(value)!;
      }
      AddValue(timeZoneMap, key, value);
    }

    fields.AddField(TzdbStreamFieldId.TzdbIdMap, stringPool).Writer.WriteDictionary(timeZoneMap);

    // Windows mappings
    cldrWindowsZones.Write(fields.AddField(TzdbStreamFieldId.CldrSupplementalWindowsZones, stringPool).Writer);
    // Additional names from Windows Standard Name to canonical ID, used in Noda Time 1.x BclDateTimeZone, when we
    // didn't have access to TimeZoneInfo.Id.
    const additionalMappings = new Map<string, string>();
    additionalWindowsNameToIdMappings.forEach((value, key) => {
      AddValue(additionalMappings, key, GetValue(cldrWindowsZones.PrimaryMapping, value));
    });
    fields.AddField(TzdbStreamFieldId.WindowsAdditionalStandardNameToIdMapping, stringPool).Writer.WriteDictionary(additionalMappings);

    // Zone locations, if any.
    const zoneLocations = database.ZoneLocations;
    if (zoneLocations !== null) {
      const field = fields.AddField(TzdbStreamFieldId.ZoneLocations, stringPool);
      field.Writer.WriteCount(zoneLocations.length);
      for (const zoneLocation of zoneLocations) {
        zoneLocation.Write(field.Writer);
      }
    }

    // Zone 1970 locations, if any.
    const zone1970Locations = database.Zone1970Locations;
    if (zone1970Locations !== null) {
      const field = fields.AddField(TzdbStreamFieldId.Zone1970Locations, stringPool);
      field.Writer.WriteCount(zone1970Locations.length);
      for (const zoneLocation of zone1970Locations) {
        zoneLocation.Write(field.Writer);
      }
    }

    const stringPoolField = fields.AddField(TzdbStreamFieldId.StringPool, null);
    stringPoolField.Writer.WriteCount(stringPool.length);
    for (const value of stringPool) {
      stringPoolField.Writer.WriteString(value);
    }

    // Now write all the fields out, in the right order.
    // new BinaryWriter(stream).Write(Version): a little-endian 32-bit integer.
    stream.Write(new Uint8Array([Version & 0xff, (Version >>> 8) & 0xff, (Version >>> 16) & 0xff, (Version >>> 24) & 0xff]), 0, 4);
    fields.WriteTo(stream);
    return stream.ToArray();
  }

  private static WriteZone(zone: DateTimeZone, writer: IDateTimeZoneWriter): void {
    writer.WriteString(zone.Id);
    // For cached zones, simply uncache first.
    if (zone instanceof CachedDateTimeZone) {
      zone = zone.TimeZone;
    }
    if (zone instanceof FixedDateTimeZone) {
      writer.WriteByte(DateTimeZoneWriter.DateTimeZoneType.Fixed);
      zone.Write(writer);
    } else {
      if (zone instanceof PrecalculatedDateTimeZone) {
        writer.WriteByte(DateTimeZoneWriter.DateTimeZoneType.Precalculated);
        zone.Write(writer);
      } else {
        throw NewArgumentException(`Unserializable DateTimeZone type ${zone.constructor.name}`);
      }
    }
  }

  /**
   * Creates a string pool which contains the most commonly-used strings within the given set
   * of zones first. This will allow them to be more efficiently represented when we write them out for real.
   */
  private static CreateOptimizedStringPool(
    zones: Iterable<DateTimeZone>,
    zoneLocations: Iterable<TzdbZoneLocation> | null,
    zone1970Locations: Iterable<TzdbZone1970Location> | null,
    cldrWindowsZones: WindowsZones,
  ): string[] {
    const optimizingWriter = new TzdbStreamWriterStringPoolOptimizingFakeWriter();
    for (const zone of zones) {
      optimizingWriter.WriteString(zone.Id);
      TzdbStreamWriter.WriteZone(zone, optimizingWriter);
    }
    if (zoneLocations !== null) {
      for (const location of zoneLocations) {
        location.Write(optimizingWriter);
      }
    }
    if (zone1970Locations !== null) {
      for (const location of zone1970Locations) {
        location.Write(optimizingWriter);
      }
    }
    cldrWindowsZones.Write(optimizingWriter);
    return optimizingWriter.CreatePool();
  }
}

/**
 * Writer which only cares about strings. It builds a complete list of all strings written for the given
 * zones, then creates a distinct list in most-prevalent-first order. This allows the most frequently-written
 * strings to be the ones which are cheapest to write.
 * (NodaTime's private nested class TzdbStreamWriter.StringPoolOptimizingFakeWriter.)
 */
class TzdbStreamWriterStringPoolOptimizingFakeWriter implements IDateTimeZoneWriter {
  private readonly _allStrings: string[] = [];

  CreatePool(): string[] {
    // allStrings.GroupBy(x => x).OrderByDescending(g => g.Count()).Select(g => g.Key).ToList():
    // groups in order of first occurrence, then a stable sort by descending count.
    const counts = new Map<string, number>();
    for (const value of this._allStrings) {
      counts.set(value, (counts.get(value) ?? 0) + 1);
    }
    const groups: { key: string; count: number; index: number }[] = [];
    counts.forEach((count, key) => groups.push({ key, count, index: groups.length }));
    return groups
      .sort((x, y) => y.count - x.count || x.index - y.index)
      .map(g => g.key);
  }

  WriteString(value: string): void {
    this._allStrings.push(value);
  }

  WriteMilliseconds(_millis: number): void {}
  WriteOffset(_offset: Offset): void {}
  WriteCount(_count: number): void {}
  WriteByte(_value: number): void {}
  WriteSignedCount(_count: number): void {}
  WriteZoneIntervalTransition(_previous: Instant | null, _value: Instant): void {}

  WriteDictionary(dictionary: ReadonlyMap<string, string>): void {
    dictionary.forEach((value, key) => {
      this.WriteString(key);
      this.WriteString(value);
    });
  }
}

/**
 * The data for a field, including the field number itself.
 * (NodaTime's private nested class TzdbStreamWriter.FieldData.)
 */
class TzdbStreamWriterFieldData {
  private readonly _stream: MemoryStream;

  constructor(fieldId: TzdbStreamFieldId, stringPool: string[] | null) {
    this.FieldId = fieldId;
    this._stream = new MemoryStream();
    this.Writer = DateTimeZoneWriter.NewOutputStringPool(this._stream, stringPool);
  }

  readonly Writer: IDateTimeZoneWriter;
  readonly FieldId: TzdbStreamFieldId;

  WriteTo(output: Stream): void {
    output.WriteByte(this.FieldId);
    const length = this._stream.Length;
    // We've got a 7-bit-encoding routine... might as well use it.
    DateTimeZoneWriter.NewOutputStringPool(output, null).WriteCount(length);
    this._stream.WriteTo(output);
  }
}

/** (NodaTime's private nested class TzdbStreamWriter.FieldCollection.) */
class TzdbStreamWriterFieldCollection {
  private readonly _fields: TzdbStreamWriterFieldData[] = [];

  AddField(fieldNumber: TzdbStreamFieldId, stringPool: string[] | null): TzdbStreamWriterFieldData {
    const ret = new TzdbStreamWriterFieldData(fieldNumber, stringPool);
    this._fields.push(ret);
    return ret;
  }

  WriteTo(stream: Stream): void {
    // fields.OrderBy(field => field.FieldId): a stable sort.
    const ordered = this._fields
      .map((field, index) => ({ field, index }))
      .sort((x, y) => x.field.FieldId - y.field.FieldId || x.index - y.index);
    for (const { field } of ordered) {
      field.WriteTo(stream);
    }
  }
}
