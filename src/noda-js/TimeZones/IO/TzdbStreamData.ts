// Ported from NodaTime 3.3.0: src/NodaTime/TimeZones/IO/TzdbStreamData.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CachedDateTimeZone,
  DateTimeZoneReader,
  DateTimeZoneWriterDateTimeZoneType,
  FixedDateTimeZone,
  InvalidNodaDataError,
  MemoryStream,
  PrecalculatedDateTimeZone,
  Preconditions,
  TzdbStreamField,
  TzdbStreamFieldId,
  TzdbZone1970Location,
  TzdbZoneLocation,
  WindowsZones,
} from "../../internal.ts";
import type { DateTimeZone } from "../../internal.ts";
import type { TzdbDateTimeZoneSource } from "../../internal.ts";

/**
 * Mutable builder class used during parsing.
 * (C#: TzdbStreamData.Builder)
 * @internal
 */
export class TzdbStreamDataBuilder {
  _stringPool: readonly string[] | null = null;
  _tzdbVersion: string | null = null;
  // Note: deliberately mutable, as this is useful later when we map the canonical IDs to themselves.
  // This is a mapping of the aliases from TZDB, at this point.
  _tzdbIdMap: Map<string, string> | null = null;
  _zoneLocations: readonly TzdbZoneLocation[] | null = null;
  Zone1970Locations: readonly TzdbZone1970Location[] | null = null;
  _windowsMapping: WindowsZones | null = null;
  readonly _zoneFields = new Map<string, TzdbStreamField>();

  HandleStringPoolField(field: TzdbStreamField): void {
    TzdbStreamDataBuilder.CheckSingleField(field, this._stringPool);
    const stream = field.CreateStream();
    const reader = DateTimeZoneReader.NewInputStringPool(stream, null);
    const count = reader.ReadCount();
    const stringPoolArray = new Array<string>(count);
    for (let i = 0; i < count; i++) {
      stringPoolArray[i] = reader.ReadString();
    }
    this._stringPool = stringPoolArray;
  }

  HandleZoneField(field: TzdbStreamField): void {
    this.CheckStringPoolPresence(field);
    // Just read the ID from the zone - we don't parse the data yet.
    // (We could, but we might as well be lazy.)
    const stream = field.CreateStream();
    const reader = DateTimeZoneReader.NewInputStringPool(stream, this._stringPool);
    const id = reader.ReadString();
    if (this._zoneFields.has(id)) {
      throw new InvalidNodaDataError(`Multiple definitions for zone ${id}`);
    }
    this._zoneFields.set(id, field);
  }

  HandleTzdbVersionField(field: TzdbStreamField): void {
    TzdbStreamDataBuilder.CheckSingleField(field, this._tzdbVersion);
    this._tzdbVersion = field.ExtractSingleValue((reader) => reader.ReadString(), null);
  }

  HandleTzdbIdMapField(field: TzdbStreamField): void {
    TzdbStreamDataBuilder.CheckSingleField(field, this._tzdbIdMap);
    this._tzdbIdMap = field.ExtractSingleValue((reader) => reader.ReadDictionary(), this._stringPool);
  }

  HandleSupplementalWindowsZonesField(field: TzdbStreamField): void {
    TzdbStreamDataBuilder.CheckSingleField(field, this._windowsMapping);
    this._windowsMapping = field.ExtractSingleValue((reader) => WindowsZones.Read(reader), this._stringPool);
  }

  HandleZoneLocationsField(field: TzdbStreamField): void {
    TzdbStreamDataBuilder.CheckSingleField(field, this._zoneLocations);
    this.CheckStringPoolPresence(field);
    const stream = field.CreateStream();
    const reader = DateTimeZoneReader.NewInputStringPool(stream, this._stringPool);
    const count = reader.ReadCount();
    const array = new Array<TzdbZoneLocation>(count);
    for (let i = 0; i < count; i++) {
      array[i] = TzdbZoneLocation.Read(reader);
    }
    this._zoneLocations = array;
  }

  HandleZone1970LocationsField(field: TzdbStreamField): void {
    TzdbStreamDataBuilder.CheckSingleField(field, this.Zone1970Locations);
    this.CheckStringPoolPresence(field);
    const stream = field.CreateStream();
    const reader = DateTimeZoneReader.NewInputStringPool(stream, this._stringPool);
    const count = reader.ReadCount();
    const array = new Array<TzdbZone1970Location>(count);
    for (let i = 0; i < count; i++) {
      array[i] = TzdbZone1970Location.Read(reader);
    }
    this.Zone1970Locations = array;
  }

  private static CheckSingleField(field: TzdbStreamField, expectedNullField: unknown): void {
    if (expectedNullField !== null) {
      throw new InvalidNodaDataError(`Multiple fields of ID ${TzdbStreamFieldId[field.Id] ?? field.Id}`);
    }
  }

  private CheckStringPoolPresence(field: TzdbStreamField): void {
    if (this._stringPool === null) {
      throw new InvalidNodaDataError(`String pool must be present before field ${TzdbStreamFieldId[field.Id] ?? field.Id}`);
    }
  }
}

let fieldHandlers: ReadonlyMap<TzdbStreamFieldId, (builder: TzdbStreamDataBuilder, field: TzdbStreamField) => void> | undefined;

// C#: private static readonly Dictionary<TzdbStreamFieldId, Action<Builder, TzdbStreamField>> FieldHandlers (made lazy).
function GetFieldHandlers(): ReadonlyMap<TzdbStreamFieldId, (builder: TzdbStreamDataBuilder, field: TzdbStreamField) => void> {
  return (fieldHandlers ??= new Map<TzdbStreamFieldId, (builder: TzdbStreamDataBuilder, field: TzdbStreamField) => void>([
    [TzdbStreamFieldId.StringPool, (builder, field) => builder.HandleStringPoolField(field)],
    [TzdbStreamFieldId.TimeZone, (builder, field) => builder.HandleZoneField(field)],
    [TzdbStreamFieldId.TzdbIdMap, (builder, field) => builder.HandleTzdbIdMapField(field)],
    [TzdbStreamFieldId.TzdbVersion, (builder, field) => builder.HandleTzdbVersionField(field)],
    [TzdbStreamFieldId.CldrSupplementalWindowsZones, (builder, field) => builder.HandleSupplementalWindowsZonesField(field)],
    [TzdbStreamFieldId.ZoneLocations, (builder, field) => builder.HandleZoneLocationsField(field)],
    [TzdbStreamFieldId.Zone1970Locations, (builder, field) => builder.HandleZone1970LocationsField(field)],
  ]));
}

const AcceptedVersion = 0;

/**
 * Provides the raw data exposed by {@link TzdbDateTimeZoneSource}.
 * @internal
 */
export class TzdbStreamData {
  /** Nested type: TzdbStreamData.Builder */
  static readonly Builder = TzdbStreamDataBuilder;

  private readonly _stringPool: readonly string[];
  private readonly _zoneFields: ReadonlyMap<string, TzdbStreamField>;

  /**
   * Returns the TZDB version string.
   */
  readonly TzdbVersion: string;

  /**
   * Returns the TZDB ID dictionary (alias to canonical ID).
   */
  readonly TzdbIdMap: ReadonlyMap<string, string>;

  /**
   * Returns the Windows mapping dictionary. (As the type is immutable, it can be exposed directly
   * to callers.)
   */
  readonly WindowsMapping: WindowsZones;

  /**
   * Returns the zone locations for the source, or null if no location data is available.
   */
  readonly ZoneLocations: readonly TzdbZoneLocation[] | null;

  /**
   * Returns the "zone 1970" locations for the source, or null if no such location data is available.
   */
  readonly Zone1970Locations: readonly TzdbZone1970Location[] | null;

  static NewBuilder(builder: TzdbStreamDataBuilder): TzdbStreamData {
    return new TzdbStreamData(builder);
  }

  private constructor(builder: TzdbStreamDataBuilder) {
    this._stringPool = TzdbStreamData.CheckNotNull(builder._stringPool, "string pool");
    const mutableIdMap = TzdbStreamData.CheckNotNull(builder._tzdbIdMap, "TZDB alias map");
    this.TzdbVersion = TzdbStreamData.CheckNotNull(builder._tzdbVersion, "TZDB version");
    this.WindowsMapping = TzdbStreamData.CheckNotNull(builder._windowsMapping, "CLDR Supplemental Windows Zones");
    this._zoneFields = builder._zoneFields;
    this.ZoneLocations = builder._zoneLocations;
    this.Zone1970Locations = builder.Zone1970Locations;

    // Add in the canonical IDs as mappings to themselves.
    for (const id of this._zoneFields.keys()) {
      mutableIdMap.set(id, id);
    }
    this.TzdbIdMap = mutableIdMap;
  }

  /**
   * Creates the {@link DateTimeZone} for the given canonical ID, which will definitely
   * be one of the values of the TzdbAliases dictionary.
   * @param id ID for the returned zone, which may be an alias.
   * @param canonicalId Canonical ID for zone data
   */
  CreateZone(id: string, canonicalId: string): DateTimeZone {
    Preconditions.CheckNotNull(id, "id");
    Preconditions.CheckNotNull(canonicalId, "canonicalId");
    const field = this._zoneFields.get(canonicalId);
    if (field === undefined) {
      // C# would throw KeyNotFoundException from the dictionary indexer.
      throw new InvalidNodaDataError(`No zone data for canonical ID ${canonicalId}`);
    }
    const stream = field.CreateStream();
    const reader = DateTimeZoneReader.NewInputStringPool(stream, this._stringPool);
    // Skip over the ID before the zone data itself
    reader.ReadString();
    const type = reader.ReadByte() as DateTimeZoneWriterDateTimeZoneType;
    switch (type) {
      case DateTimeZoneWriterDateTimeZoneType.Fixed:
        return FixedDateTimeZone.Read(reader, id);
      case DateTimeZoneWriterDateTimeZoneType.Precalculated:
        return CachedDateTimeZone.ForZone(PrecalculatedDateTimeZone.Read(reader, id));
      default:
        throw new InvalidNodaDataError(`Unknown time zone type ${type}`);
    }
  }

  // Like Preconditions.CheckNotNull, but specifically for incomplete data.
  private static CheckNotNull<T>(input: T | null, name: string): T {
    if (input === null) {
      throw new InvalidNodaDataError(`Incomplete TZDB data. Missing field: ${name}`);
    }
    return input;
  }

  /** @internal */
  static FromStream(stream: MemoryStream): TzdbStreamData {
    Preconditions.CheckNotNull(stream, "stream");

    // BinaryReader.ReadInt32: little-endian.
    let version = 0;
    for (let i = 0; i < 4; i++) {
      const b = stream.ReadByte();
      if (b === -1) {
        // C#'s BinaryReader would throw EndOfStreamException.
        throw new InvalidNodaDataError("Unable to read stream version: unexpected end of data");
      }
      version |= b << (8 * i);
    }
    if (version !== AcceptedVersion) {
      throw new InvalidNodaDataError(`Unable to read stream with version ${version}`);
    }
    const builder = new TzdbStreamDataBuilder();
    const handlers = GetFieldHandlers();
    for (const field of TzdbStreamField.ReadFields(stream)) {
      // Only handle fields we know about
      const handler = handlers.get(field.Id);
      if (handler !== undefined) {
        handler(builder, field);
      }
    }
    return new TzdbStreamData(builder);
  }

  /**
   * noda-js: reads the data from a byte array (the whole contents of an NZD file).
   * @internal
   */
  static FromBytes(bytes: Uint8Array): TzdbStreamData {
    Preconditions.CheckNotNull(bytes, "bytes");
    return TzdbStreamData.FromStream(new MemoryStream(bytes));
  }
}
