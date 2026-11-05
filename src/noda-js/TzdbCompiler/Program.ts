// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler/Program.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { TzdbDateTimeZoneSource } from "../internal.ts";
import type { WindowsZones } from "../internal.ts";
import { NameIdMappingSupport, TzdbStreamWriter, TzdbZoneInfoCompiler } from "./internal.ts";
import type { FileSource } from "./internal.ts";

/**
 * The NodaTime.TzdbCompiler program: compiles TZDB data into NodaTime's NZD format.
 *
 * noda-js: just the part of Main that compiles a source, writes the data and reads it back to validate it, as a
 * library function (used by noda-js/tzdb/compiler). Not ported: the command line (CompilerOptions), loading the source
 * from a path (the caller passes a {@link FileSource}), LoadWindowsZones and the Windows override file (the caller
 * passes the mapping), `-z` (GenerateDateTimeZone), `-s` (the XML schema), and the output file (the data stays in
 * memory, so it's always validated, as Main does when it writes a file).
 * @internal
 */
export class Program {
  /**
   * Compiles the source, writes the NZD data, reads it back and validates it.
   *
   * noda-js: takes the source and Windows mapping rather than command-line arguments, logs to `log` rather than the
   * console, and returns the data and the source read back from it rather than an exit code.
   * @param source The tzdata files.
   * @param windowsZones The Windows time zone mapping to include.
   * @param log The function to call with each line of the log, or null for no logging.
   * @returns The NZD data, and the validated source read from it.
   */
  static Main(
    source: FileSource,
    windowsZones: WindowsZones,
    log: ((line: string) => void) | null,
  ): { readonly Nzd: Uint8Array; readonly Source: TzdbDateTimeZoneSource } {
    const tzdbCompiler = new TzdbZoneInfoCompiler(log);
    const tzdb = tzdbCompiler.Compile(source);
    if (log !== null) {
      tzdb.LogCounts(log);
    }
    Program.LogWindowsZonesSummary(windowsZones, log);
    const writer = new TzdbStreamWriter();
    const nzd = writer.Write(tzdb, windowsZones, NameIdMappingSupport.StandardNameToIdMap);

    log?.("Reading generated data and validating...");
    const tzdbSource = TzdbDateTimeZoneSource.FromBytes(nzd);
    tzdbSource.Validate();
    return { Nzd: nzd, Source: tzdbSource };
  }

  // Not ported: LoadWindowsZones(CompilerOptions, string), MergeWindowsZones(WindowsZones, WindowsZones),
  // CreateOutputStream(CompilerOptions), Read(CompilerOptions) (no file system access)

  private static LogWindowsZonesSummary(windowsZones: WindowsZones, log: ((line: string) => void) | null): void {
    if (log === null) {
      return;
    }
    log("Windows Zones:");
    log(`  Version: ${windowsZones.Version}`);
    log(`  TZDB version: ${windowsZones.TzdbVersion}`);
    log(`  Windows version: ${windowsZones.WindowsVersion}`);
    log(`  ${windowsZones.MapZones.length} MapZones`);
    log(`  ${windowsZones.PrimaryMapping.size} primary mappings`);
  }
}
