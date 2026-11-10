// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler/Tzdb/TzdbZoneInfoCompiler.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { TzdbZone1970LocationCountry, NewIndexOutOfRangeException } from "../../internal.ts";
import type { DateTimeZone, TzdbDateTimeZoneSource } from "../../internal.ts";
import {
  AddValue,
  ReadLines,
  Trim,
  TzdbDatabase,
  TzdbZoneInfoParser,
  TzdbZoneLocationParser,
} from "../internal.ts";
import type { FileSource } from "../internal.ts";
import { NewInvalidDataException, type IndexOutOfRangeException } from "../../internal.ts";

const Makefile = "Makefile";

const VersionRegex = /\d{2,4}[a-z]/;

/** line.Split('\t'), then bits[1] (which throws IndexOutOfRangeException in .NET if there's no tab). */
function SecondTabSeparatedValue(bits: readonly string[]): string {
  if (bits.length < 2) {
    throw NewIndexOutOfRangeException();
  }
  return bits[1]!;
}

/**
 * Provides a compiler for Olson (TZDB) zone info files into the internal format used by Noda
 * Time for its {@link DateTimeZone} definitions. This read a set of files and generates
 * a resource file with the compiled contents suitable for reading with {@link TzdbDateTimeZoneSource} or one of its variants.
 *
 * noda-js: reads its files from a {@link FileSource} and logs each line to a function.
 */
export class TzdbZoneInfoCompiler {
  // noda-js: these are private in NodaTime; internal here, for noda-js/tzdb/compiler's directory URLs (Input.ts).
  /** @internal */
  static readonly Zone1970TabFile = "zone1970.tab";
  /** @internal */
  static readonly Iso3166TabFile = "iso3166.tab";
  /** @internal */
  static readonly ZoneTabFile = "zone.tab";

  /** @internal */
  static readonly ZoneFiles: readonly string[] = [
    "africa", "antarctica", "asia", "australasia", "europe",
    "northamerica", "southamerica", "pacificnew", "etcetera", "backward", "systemv",
  ];

  private readonly _log: ((line: string) => void) | null;

  /**
   * Initializes a new instance of the {@link TzdbZoneInfoCompiler} class
   * logging to the given function, which may be null.
   * (Merges NodaTime's two constructors: with no argument, the compiler logs to standard output, here `console.log`.)
   * @param log The function to call with each line of the log, or null for no logging.
   */
  constructor(log?: ((line: string) => void) | null) {
    this._log = log === undefined ? (line: string) => console.log(line) : log;
  }

  /**
   * Compiles the contents of a file source to a TzdbDatabase.
   * The version ID is taken from the Makefile, if it exists. Otherwise, an attempt is made to guess
   * it based on the source's origin, to match a regex of \d{2,4}[a-z] (anywhere within the element).
   *
   * noda-js: replaces NodaTime's `CompileAsync(string path)`.
   * @internal
   */
  Compile(source: FileSource): TzdbDatabase {
    const version = this.InferVersion(source);
    const database = new TzdbDatabase(version);
    this.LoadZoneFiles(source, database);
    this.LoadLocationFiles(source, database);
    return database;
  }

  private LoadZoneFiles(source: FileSource, database: TzdbDatabase): void {
    const tzdbParser = new TzdbZoneInfoParser();
    for (const file of TzdbZoneInfoCompiler.ZoneFiles) {
      if (source.Contains(file)) {
        this._log?.(`Parsing file ${file} . . .`);
        const stream = source.Open(file);
        tzdbParser.Parse(stream, database);
      }
    }
  }

  private LoadLocationFiles(source: FileSource, database: TzdbDatabase): void {
    if (!source.Contains(TzdbZoneInfoCompiler.Iso3166TabFile)) {
      return;
    }
    const iso3166 = [...ReadLines(source, TzdbZoneInfoCompiler.Iso3166TabFile)]
      .filter(line => line !== "" && !line.startsWith("#"))
      .map(line => line.split("\t"));
    if (source.Contains(TzdbZoneInfoCompiler.ZoneTabFile)) {
      const iso3166Dict = new Map<string, string>();
      for (const bits of iso3166) {
        AddValue(iso3166Dict, bits[0]!, SecondTabSeparatedValue(bits));
      }
      database.ZoneLocations = [...ReadLines(source, TzdbZoneInfoCompiler.ZoneTabFile)]
        .filter(line => line !== "" && !line.startsWith("#"))
        .map(line => TzdbZoneLocationParser.ParseLocation(line, iso3166Dict));
    }
    if (source.Contains(TzdbZoneInfoCompiler.Zone1970TabFile)) {
      const iso3166Dict = new Map<string, TzdbZone1970LocationCountry>();
      for (const bits of iso3166) {
        AddValue(iso3166Dict, bits[0]!, new TzdbZone1970LocationCountry(SecondTabSeparatedValue(bits), bits[0]!));
      }
      database.Zone1970Locations = [...ReadLines(source, TzdbZoneInfoCompiler.Zone1970TabFile)]
        .filter(line => line !== "" && !line.startsWith("#"))
        .map(line => TzdbZoneLocationParser.ParseEnhancedLocation(line, iso3166Dict));
    }
  }

  // Not ported: LoadSourceAsync(string path) (loading files from a URL, directory or archive file is done outside
  // the compiler, which takes the resulting FileSource)

  private InferVersion(source: FileSource): string {
    if (source.Contains(Makefile)) {
      for (const line of ReadLines(source, Makefile)) {
        if (/VERSION=\d{4}.*/.test(line)) {
          const version = Trim(line.substring(8));
          this._log?.(`Inferred version ${version} from ${Makefile}`);
          return version;
        }
      }
    }
    const match = VersionRegex.exec(source.Origin);
    if (match !== null) {
      const version = match[0];
      this._log?.(`Inferred version ${version} from file/directory name ${source.Origin}`);
      return version;
    }
    throw NewInvalidDataException("Unable to determine TZDB version from source");
  }
}
