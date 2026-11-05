// Ported from NodaTime 3.3.0: src/NodaTime.Test/TimeZones/IO/TzdbStreamDataTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: TzdbStreamData.Builder is TzdbStreamDataBuilder; the internal constructors are TzdbStreamData.newBuilder,
// TzdbStreamField.newIdData and WindowsZones.newVersionTzdbVersionWindowsVersionMapZones. The C# tests invoke the
// builder's handler methods by reflection (so errors arrive wrapped in TargetInvocationException); here they're
// called by their C# name, and the error is thrown directly.

import { expect } from "vitest";
import {
  InvalidNodaDataError,
  MemoryStream,
  TzdbStreamData,
  TzdbStreamDataBuilder,
  TzdbStreamField,
  TzdbStreamFieldId,
  WindowsZones,
} from "../../../../src/noda-js/internal.ts";
import { assertThrows } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/TimeZones/IO/TzdbStreamDataTest.generated.ts";

function createMinimalBuilder(): TzdbStreamDataBuilder {
  const builder = new TzdbStreamDataBuilder();
  builder._stringPool = [];
  builder._tzdbIdMap = new Map<string, string>();
  builder._tzdbVersion = "tzdb-version";
  builder._windowsMapping = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones("cldr-version", "tzdb-version", "windows-version", []);
  return builder;
}

/** typeof(TzdbStreamData.Builder).GetMethod(handlerMethodName): the builder's handler method, bound to the builder. */
function handlerMethod(builder: TzdbStreamDataBuilder, handlerMethodName: string): (field: TzdbStreamField) => void {
  const method = (builder as unknown as Record<string, unknown>)[handlerMethodName];
  if (typeof method !== "function") {
    throw new Error(`Can't find method ${handlerMethodName}`);
  }
  return (method as (field: TzdbStreamField) => void).bind(builder);
}

port(fixture, {
  Minimal() {
    const data = TzdbStreamData.NewBuilder(createMinimalBuilder());
    expect(data.TzdbVersion).not.toBeNull();
  },

  "MissingStringPool()"() {
    const builder = createMinimalBuilder();
    builder._stringPool = null;
    assertThrows(InvalidNodaDataError, () => TzdbStreamData.NewBuilder(builder));
  },

  MissingTzdbAliasMap() {
    const builder = createMinimalBuilder();
    builder._tzdbIdMap = null;
    assertThrows(InvalidNodaDataError, () => TzdbStreamData.NewBuilder(builder));
  },

  MissingTzdbVersion() {
    const builder = createMinimalBuilder();
    builder._tzdbVersion = null;
    assertThrows(InvalidNodaDataError, () => TzdbStreamData.NewBuilder(builder));
  },

  MissingWindowsMapping() {
    const builder = createMinimalBuilder();
    builder._windowsMapping = null;
    assertThrows(InvalidNodaDataError, () => TzdbStreamData.NewBuilder(builder));
  },

  InvalidVersion() {
    // It's hard to create a stream that's valid apart from the version, so we'll just
    // give one with an invalid version and check that it looks like the right message.
    const stream = new MemoryStream(new Uint8Array([0, 0, 0, 1]));
    const exception = assertThrows(InvalidNodaDataError, () => TzdbStreamData.FromStream(stream));
    expect(exception.message).toContain("version");
  },

  "MissingStringPool(object, string)"(fieldIdObject: TzdbStreamFieldId, handlerMethodName: string) {
    const fieldId = fieldIdObject;
    const field = TzdbStreamField.NewIdData(fieldId, new Uint8Array(1));
    const builder = new TzdbStreamDataBuilder();
    const method = handlerMethod(builder, handlerMethodName);

    assertThrows(InvalidNodaDataError, () => method(field));
  },

  // Note: we don't test this with a CldrSupplementalWindowsZones field, as they're both awkward to build.
  // All other fields are valid with a single byte of 0, which is usually a count. This is very convenient.
  DuplicateField(fieldIdObject: TzdbStreamFieldId, handlerMethodName: string) {
    const fieldId = fieldIdObject;

    const field = TzdbStreamField.NewIdData(fieldId, new Uint8Array(1));
    const builder = new TzdbStreamDataBuilder();
    const method = handlerMethod(builder, handlerMethodName);
    // Provide an empty string pool if we're not checking for a duplicate string pool.
    if (fieldId !== TzdbStreamFieldId.StringPool) {
      builder._stringPool = [];
    }

    // First call should be okay
    method(field);

    // Second call should throw
    assertThrows(InvalidNodaDataError, () => method(field));
  },

  DuplicateTimeZoneField() {
    // This isn't really a valid field, but we don't parse the data yet anyway - it's
    // enough to give the ID.
    const zoneField = TzdbStreamField.NewIdData(TzdbStreamFieldId.StringPool, new Uint8Array(1));

    const builder = new TzdbStreamDataBuilder();
    builder._stringPool = ["zone1"];
    builder.HandleZoneField(zoneField);
    assertThrows(InvalidNodaDataError, () => builder.HandleZoneField(zoneField));
  },
});
